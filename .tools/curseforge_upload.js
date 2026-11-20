'use strict';

const fs = require('fs');
const path = require('path');
const { buildCurseForgeMetadata } = require('./curseforge_deployment');

const CURSEFORGE_API_BASE = 'https://wow.curseforge.com/api';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token.startsWith('--')) {
      const key = token.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        args[key] = next;
        i += 1;
      } else {
        args[key] = 'true';
      }
    }
  }
  return args;
}

async function fetchGameVersionIds(token) {
  const res = await fetch(`${CURSEFORGE_API_BASE}/game/wow/versions`, {
    headers: { 'X-Api-Token': token },
  });
  if (!res.ok) {
    throw new Error(`CurseForge game versions query failed (${res.status}): ${await res.text()}`);
  }
  const list = await res.json();
  // Classic Era, Forever, TBC Anniversary, MoP Classic, Retail
  const wanted = new Set(['1.15.9', '1.60.1', '2.5.6', '5.5.4', '12.1.7']);
  const ids = list.filter((v) => wanted.has(v.name)).map((v) => v.id);
  if (ids.length > 0) return ids;

  throw new Error('Could not resolve expected Classic/Progression CurseForge game version IDs.');
}

async function main() {
  const args = parseArgs(process.argv);
  const projectId = args['project-id'] || process.env.CURSEFORGE_PROJECT_ID || '1441462';
  const token = process.env.CURSEFORGE_API_TOKEN || process.env.CF_UPLOAD_TOKEN;
  const filePath = args.file;
  const version = args.version;
  const channel = args.channel || 'beta';
  const notesPath = args.notes;

  if (!projectId || !token) {
    throw new Error('CURSEFORGE_PROJECT_ID and CURSEFORGE_API_TOKEN (or CF_UPLOAD_TOKEN) must be configured.');
  }
  if (!filePath || !fs.existsSync(filePath)) {
    throw new Error(`Archive file not found: ${filePath}`);
  }
  if (!version) {
    throw new Error('Missing --version argument.');
  }

  const changelog = notesPath && fs.existsSync(notesPath)
    ? fs.readFileSync(notesPath, 'utf8')
    : `Release v${version}`;

  const gameVersions = await fetchGameVersionIds(token);
  const metadata = buildCurseForgeMetadata({
    version,
    releaseType: channel === 'stable' ? 'release' : 'beta',
    changelog,
    gameVersions,
  });

  const form = new FormData();
  form.append('metadata', JSON.stringify(metadata));
  const buffer = fs.readFileSync(filePath);
  const blob = new Blob([buffer], { type: 'application/zip' });
  form.append('file', blob, path.basename(filePath));

  const uploadUrl = `${CURSEFORGE_API_BASE}/projects/${projectId}/upload-file`;
  const res = await fetch(uploadUrl, {
    method: 'POST',
    headers: { 'X-Api-Token': token },
    body: form,
  });

  if (!res.ok) {
    throw new Error(`CurseForge upload failed (${res.status}): ${await res.text()}`);
  }

  const json = await res.json();
  console.log('CurseForge upload succeeded:', JSON.stringify(json));
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
