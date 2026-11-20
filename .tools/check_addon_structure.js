'use strict';

const fs = require('fs');
const path = require('path');
const { TOC_FILES } = require('./release_distribution');

const repoRoot = path.resolve(__dirname, '..');
const errors = [];

function parseTocMetadata(content) {
  const meta = {};
  const files = [];
  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith('##')) {
      const m = line.match(/^##\s*([^:]+?):\s*(.*)$/);
      if (m) {
        meta[m[1].trim()] = m[2].trim();
      }
      continue;
    }
    if (line.startsWith('#')) continue;
    files.push(line);
  }
  return { meta, files };
}

const versions = new Map();

for (const tocRel of TOC_FILES) {
  const tocAbs = path.join(repoRoot, tocRel);
  if (!fs.existsSync(tocAbs)) {
    errors.push(`Missing TOC file: ${tocRel}`);
    continue;
  }

  const content = fs.readFileSync(tocAbs, 'utf8');
  const { meta, files } = parseTocMetadata(content);

  for (const requiredTag of ['Interface', 'Title', 'Author', 'Version']) {
    if (!meta[requiredTag]) {
      errors.push(`${tocRel}: missing required tag ## ${requiredTag}`);
    }
  }

  if (meta.Version) {
    versions.set(tocRel, meta.Version);
  }

  const tocDir = path.dirname(tocAbs);
  if (files.length === 0) {
    errors.push(`${tocRel}: lists zero Lua/XML files`);
  }

  for (const fileEntry of files) {
    const normalized = fileEntry.replace(/[\\/]+/g, path.sep);
    const targetAbs = path.join(tocDir, normalized);
    if (!fs.existsSync(targetAbs)) {
      errors.push(`${tocRel}: missing referenced file ${fileEntry}`);
    }
  }
}

const uniqueVersions = new Set(versions.values());
if (uniqueVersions.size > 1) {
  const summary = Array.from(versions.entries())
    .map(([k, v]) => `${k}=${v}`)
    .join(', ');
  errors.push(`TOC version mismatch across files: ${summary}`);
}

for (const docRel of ['README.md', 'CHANGELOG.md', '.pkgmeta']) {
  const docAbs = path.join(repoRoot, docRel);
  if (!fs.existsSync(docAbs)) {
    errors.push(`Missing repository file: ${docRel}`);
  }
}

if (errors.length > 0) {
  console.error('Addon structure validation failed:');
  for (const e of errors) {
    console.error(' - ' + e);
  }
  process.exit(1);
}

const currentVersion = uniqueVersions.values().next().value || 'unknown';
console.log(`Addon structure check passed (${TOC_FILES.length} TOCs, version=${currentVersion}).`);
