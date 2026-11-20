param(
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$WowRoot = 'C:\Program Files (x86)\World of Warcraft',
    [string]$Ref = '',
    [string[]]$Flavors = @('_anniversary_', '_classic_', '_classic_beta_', '_classic_era_', '_classic_era_ptr_', '_forever_', '_retail_'),
    [switch]$NoConfirm
)

$ErrorActionPreference = 'Stop'

function Get-RelativeFileHashes {
    param([string]$RootDir)
    $resolvedRoot = (Resolve-Path $RootDir).Path
    $map = [ordered]@{}
    $files = Get-ChildItem -Path $resolvedRoot -Recurse -File | Sort-Object FullName
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $hash = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $map[$rel] = $hash
    }
    return $map
}

function Assert-DirectoryMirror {
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )

    $srcMap = Get-RelativeFileHashes -RootDir $SourceDir
    $dstMap = Get-RelativeFileHashes -RootDir $TargetDir

    $missing = @($srcMap.Keys | Where-Object { -not $dstMap.Contains($_) })
    $extra = @($dstMap.Keys | Where-Object { -not $srcMap.Contains($_) })
    $mismatch = @($srcMap.Keys | Where-Object { $dstMap.Contains($_) -and $srcMap[$_] -ne $dstMap[$_] })

    if ($missing.Count -gt 0 -or $extra.Count -gt 0 -or $mismatch.Count -gt 0) {
        $msg = "Directory mirror verification failed between '$SourceDir' and '$TargetDir'."
        if ($missing.Count -gt 0) { $msg += " Missing: $($missing -join ', ')." }
        if ($extra.Count -gt 0) { $msg += " Extra: $($extra -join ', ')." }
        if ($mismatch.Count -gt 0) { $msg += " SHA-256 mismatch: $($mismatch -join ', ')." }
        throw $msg
    }

    return $srcMap.Count
}

$resolvedSourceRoot = (Resolve-Path $SourceRoot).Path
$stagingTemp = $null
$addonSourceDir = Join-Path $resolvedSourceRoot 'LoCA'

try {
    if (-not [string]::IsNullOrWhiteSpace($Ref)) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $commitSha = (& git -C $resolvedSourceRoot rev-parse --verify "$Ref^{commit}" 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($commitSha)) {
            throw "Unable to resolve git commit for Ref='$Ref'."
        }
        $commitSha = $commitSha.Trim()
        $stagingTemp = Join-Path ([System.IO.Path]::GetTempPath()) ("loca-deploy-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stagingTemp -Force | Out-Null
        $tempZip = Join-Path $stagingTemp 'archive.zip'
        & git -C $resolvedSourceRoot -c core.autocrlf=false archive --format=zip --prefix="LoCA/" --output="$tempZip" "$($commitSha):LoCA"
        if ($LASTEXITCODE -ne 0) {
            throw "git archive failed for $commitSha:LoCA."
        }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $stagingTemp)
        Remove-Item -Path $tempZip -Force
        $addonSourceDir = Join-Path $stagingTemp 'LoCA'
    }

    if (-not (Test-Path (Join-Path $addonSourceDir 'LoCA.toc'))) {
        throw "Addon source folder '$addonSourceDir' does not contain LoCA.toc."
    }

    $targetClients = New-Object System.Collections.Generic.List[object]
    foreach ($flavor in $Flavors) {
        $flavorRoot = Join-Path $WowRoot $flavor
        if (Test-Path $flavorRoot) {
            $addonsDir = Join-Path $flavorRoot 'Interface\AddOns'
            $destDir = Join-Path $addonsDir 'LoCA'
            $targetClients.Add([pscustomobject]@{
                Flavor = $flavor
                AddOnsDir = $addonsDir
                DestDir = $destDir
            })
        }
    }

    if ($targetClients.Count -eq 0) {
        throw "No World of Warcraft client directories found under '$WowRoot'."
    }

    Write-Output "Source addon directory: $addonSourceDir"
    Write-Output "Target WoW installations ($($targetClients.Count)):"
    foreach ($t in $targetClients) {
        Write-Output "  - $($t.Flavor): $($t.DestDir)"
    }

    if (-not $NoConfirm) {
        $reply = Read-Host 'Proceed with local deployment to all listed clients? (y/N)'
        if ($reply -notin @('y', 'Y', 'yes', 'YES')) {
            Write-Output 'Deployment cancelled.'
            exit 0
        }
    }

    foreach ($t in $targetClients) {
        if (-not (Test-Path $t.AddOnsDir)) {
            New-Item -ItemType Directory -Path $t.AddOnsDir -Force | Out-Null
        }
        if (Test-Path $t.DestDir) {
            Remove-Item -Path $t.DestDir -Recurse -Force
        }
        Copy-Item -Path $addonSourceDir -Destination $t.DestDir -Recurse -Force
        $verifiedCount = Assert-DirectoryMirror -SourceDir $addonSourceDir -TargetDir $t.DestDir
        Write-Output "Verified [$($t.Flavor)] -> $($t.DestDir) ($verifiedCount files, SHA-256 matched)"
    }

    Write-Output "Local deployment completed across all $($targetClients.Count) WoW clients."
}
finally {
    if ($stagingTemp -and (Test-Path $stagingTemp)) {
        Remove-Item -Path $stagingTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
