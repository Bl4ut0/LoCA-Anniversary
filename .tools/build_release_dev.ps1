param(
    [string]$Version = '',
    [string]$Ref = 'HEAD',
    [ValidateSet('beta', 'stable')]
    [string]$Channel = 'beta',
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-VersionFromToc {
    param([string]$TocPath)
    if (-not (Test-Path $TocPath)) {
        throw "Primary TOC not found at '$TocPath'."
    }
    $match = Select-String -Path $TocPath -Pattern '^##\s*Version:\s*(.+)$' | Select-Object -First 1
    if (-not $match) {
        throw "Missing ## Version tag in '$TocPath'."
    }
    return $match.Matches[0].Groups[1].Value.Trim()
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-VersionFromToc -TocPath (Join-Path $RepoRoot 'LoCA\LoCA.toc')
}
$Version = $Version.TrimStart('v', 'V')
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'Version must not be empty.'
}

$commitSha = (& git -C $RepoRoot rev-parse --verify "$Ref^{commit}" 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commitSha)) {
    throw "Unable to resolve git commit for Ref='$Ref'."
}
$commitSha = $commitSha.Trim()

$versionsDir = Join-Path $RepoRoot ".versions\$Version"
New-Item -ItemType Directory -Path $versionsDir -Force | Out-Null

$zipName = "LoCA-v$Version.zip"
$zipPath = Join-Path $versionsDir $zipName
if (Test-Path $zipPath) {
    Remove-Item -Path $zipPath -Force
}

& git -C $RepoRoot -c core.autocrlf=false archive --format=zip --prefix="LoCA/" --output="$zipPath" "$($commitSha):LoCA"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $zipPath)) {
    throw "git archive failed for $commitSha:LoCA."
}

$treeLines = & git -C $RepoRoot ls-tree -r --full-tree "$($commitSha):LoCA"
if ($LASTEXITCODE -ne 0) {
    throw "git ls-tree failed for $commitSha:LoCA."
}

$expectedEntries = New-Object System.Collections.Generic.List[string]
foreach ($line in $treeLines) {
    if ($line -match '^\d+\s+blob\s+[0-9a-f]+\s+(.+)$') {
        $rel = $Matches[1].Replace('\', '/')
        $expectedEntries.Add("LoCA/$rel")
    }
}

$sha256 = [System.Security.Cryptography.SHA256]::Create()
$fileHashes = New-Object System.Collections.Generic.List[string]
$archiveEntries = New-Object System.Collections.Generic.List[string]

$zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName.EndsWith('/')) { continue }
        $archiveEntries.Add($entry.FullName)
        $stream = $entry.Open()
        try {
            $hashBytes = $sha256.ComputeHash($stream)
            $hashHex = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
            $fileHashes.Add("$hashHex  $($entry.FullName)")
        }
        finally {
            $stream.Dispose()
        }
    }
}
finally {
    $zip.Dispose()
}

$sortedExpected = ($expectedEntries | Sort-Object) -join "`n"
$sortedActual = ($archiveEntries | Sort-Object) -join "`n"
if ($sortedExpected -ne $sortedActual) {
    throw "Archive entry mismatch against git ls-tree for $commitSha:LoCA."
}
if (-not ($archiveEntries -contains 'LoCA/LoCA.toc')) {
    throw 'Archive verification failed: LoCA/LoCA.toc missing at archive root.'
}

$zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
$zipHashBytes = $sha256.ComputeHash($zipBytes)
$zipHashHex = ([BitConverter]::ToString($zipHashBytes)).Replace('-', '').ToLowerInvariant()

Set-Content -Path (Join-Path $versionsDir 'SOURCE_COMMIT.txt') -Value $commitSha -Encoding UTF8
Set-Content -Path (Join-Path $versionsDir 'SOURCE_TREE.txt') -Value ($treeLines -join "`n") -Encoding UTF8
Set-Content -Path (Join-Path $versionsDir 'SOURCE_FILES.sha256') -Value (($fileHashes | Sort-Object) -join "`n") -Encoding UTF8
Set-Content -Path "$zipPath.sha256" -Value "$zipHashHex  $zipName" -Encoding UTF8

Write-Output "Built verified release archive ($Channel):"
Write-Output "  Commit : $commitSha"
Write-Output "  Archive: $zipPath"
Write-Output "  SHA256 : $zipHashHex"
Write-Output "  Files  : $($archiveEntries.Count)"
