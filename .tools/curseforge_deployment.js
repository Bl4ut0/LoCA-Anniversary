'use strict';

const fs = require('fs');
const path = require('path');

function extractChangelogNotes(changelogPath, version) {
  if (!fs.existsSync(changelogPath)) {
    return `Release v${version}`;
  }
  const text = fs.readFileSync(changelogPath, 'utf8');
  const cleanVer = version.replace(/^v/i, '');
  const lines = text.split(/\r?\n/);
  const out = [];
  let capturing = false;

  for (const line of lines) {
    if (/^##\s+/.test(line)) {
      if (capturing) break;
      if (line.includes(cleanVer)) {
        capturing = true;
        continue;
      }
    } else if (capturing) {
      out.push(line);
    }
  }

  const trimmed = out.join('\n').trim();
  return trimmed || `Release v${cleanVer}`;
}

function buildCurseForgeMetadata({ version, releaseType, changelog, gameVersions }) {
  return {
    changelog: changelog || `Release v${version}`,
    changelogType: 'markdown',
    displayName: `LoCA v${version}`,
    gameVersions: Array.isArray(gameVersions) ? gameVersions : [],
    releaseType: releaseType === 'release' ? 'release' : 'beta',
  };
}

function writeReleaseNotesFiles({ outDir, version, channel, changelog }) {
  fs.mkdirSync(outDir, { recursive: true });
  const label = channel === 'stable' ? 'Release' : 'Beta';
  const ghNotes = `# LoCA v${version} (${label})\n\n${changelog}\n`;
  const cfNotes = changelog + '\n';
  fs.writeFileSync(path.join(outDir, 'GITHUB_RELEASE.md'), ghNotes, 'utf8');
  fs.writeFileSync(path.join(outDir, 'CURSEFORGE_RELEASE.md'), cfNotes, 'utf8');
}

module.exports = {
  extractChangelogNotes,
  buildCurseForgeMetadata,
  writeReleaseNotesFiles,
};
