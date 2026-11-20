'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const {
  TOC_FILES,
  DEV_VERSION_STRING,
  DEFAULT_CHANGELOG_PATH,
} = require('./release_distribution');
const {
  extractChangelogNotes,
  writeReleaseNotesFiles,
} = require('./curseforge_deployment');

const repoRoot = path.resolve(__dirname, '..');

function runNodeScript(relScript) {
  execFileSync(process.execPath, [path.join(__dirname, relScript)], {
    cwd: repoRoot,
    stdio: 'inherit',
  });
}

function updateTocVersion(newVersion) {
  for (const rel of TOC_FILES) {
    const abs = path.join(repoRoot, rel);
    const content = fs.readFileSync(abs, 'utf8');
    const updated = content.replace(/^##\s*Version:.*$/m, `## Version: ${newVersion}`);
    if (updated === content && !content.includes(`## Version: ${newVersion}`)) {
      throw new Error(`Could not find ## Version header in ${rel}`);
    }
    fs.writeFileSync(abs, updated, 'utf8');
  }
  console.log(`Updated ${TOC_FILES.length} TOC files to Version: ${newVersion}`);
}

function ensureChangelogSection(version, customNotes) {
  const cleanVer = version.replace(/^v/i, '');
  const today = new Date().toISOString().slice(0, 10);
  const heading = `## [${cleanVer}] - ${today}`;
  const defaultBody = customNotes || `- Release v${cleanVer}`;

  const rootClPath = path.join(repoRoot, DEFAULT_CHANGELOG_PATH);
  let rootCl = fs.existsSync(rootClPath) ? fs.readFileSync(rootClPath, 'utf8') : '# Changelog\n\n';
  if (!rootCl.includes(`[${cleanVer}]`) && !rootCl.includes(`[v${cleanVer}]`) && !rootCl.includes(` ${cleanVer}`)) {
    const marker = '# Changelog';
    const insertion = `\n\n${heading}\n${defaultBody}\n`;
    if (rootCl.includes(marker)) {
      rootCl = rootCl.replace(marker, marker + insertion);
    } else {
      rootCl = `${marker}${insertion}\n${rootCl}`;
    }
    fs.writeFileSync(rootClPath, rootCl.replace(/\n{3,}/g, '\n\n'), 'utf8');
    console.log(`Updated ${DEFAULT_CHANGELOG_PATH} with section ${heading}`);
  }
}

function parseFlags(argv) {
  const flags = {};
  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    const tok = argv[i];
    if (tok.startsWith('--')) {
      const k = tok.slice(2);
      const next = argv[i + 1];
      if (next && !next.startsWith('--')) {
        flags[k] = next;
        i += 1;
      } else {
        flags[k] = true;
      }
    } else {
      positional.push(tok);
    }
  }
  return { positional, flags };
}

function validateVersionForChannel(channel, rawVersion) {
  const version = (rawVersion || '').replace(/^v/i, '');
  if (!/^\d+\.\d+(?:\.\d+)?(-[0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error(`Invalid version '${rawVersion}'. Expected X.Y, X.Y.Z, or X.Y.Z-beta.N.`);
  }
  if (channel === 'stable' && version.includes('-')) {
    throw new Error(`Stable releases cannot include a prerelease suffix: '${version}'.`);
  }
  return version;
}

function main() {
  const { positional, flags } = parseFlags(process.argv.slice(2));
  const cmd = positional[0];

  if (cmd === 'reset') {
    updateTocVersion(DEV_VERSION_STRING);
    runNodeScript('check_lua.js');
    runNodeScript('check_addon_structure.js');
    return;
  }

  if (cmd === 'prepare') {
    const channel = positional[1];
    if (!['beta', 'stable'].includes(channel)) {
      throw new Error('Usage: create_release.js prepare <beta|stable> <version> [--notes "..."]');
    }
    const version = validateVersionForChannel(channel, positional[2]);
    updateTocVersion(version);
    ensureChangelogSection(version, typeof flags.notes === 'string' ? flags.notes : null);
    runNodeScript('check_lua.js');
    runNodeScript('check_addon_structure.js');
    return;
  }

  if (cmd === 'build') {
    const channel = positional[1];
    if (!['beta', 'stable'].includes(channel)) {
      throw new Error('Usage: create_release.js build <beta|stable> <version> [--ref <ref>]');
    }
    const version = validateVersionForChannel(channel, positional[2]);
    const ref = typeof flags.ref === 'string' ? flags.ref : 'HEAD';

    execFileSync(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        path.join(__dirname, 'build_release_dev.ps1'),
        '-Version',
        version,
        '-Ref',
        ref,
        '-Channel',
        channel,
        '-RepoRoot',
        repoRoot,
      ],
      { cwd: repoRoot, stdio: 'inherit' }
    );

    const outDir = path.join(repoRoot, '.versions', version);
    const notes = extractChangelogNotes(path.join(repoRoot, DEFAULT_CHANGELOG_PATH), version);
    writeReleaseNotesFiles({ outDir, version, channel, changelog: notes });
    console.log(`Release artifacts written to .versions/${version}`);
    return;
  }

  console.error('Usage:');
  console.error('  node .tools/create_release.js prepare <beta|stable> <version> [--notes "..."]');
  console.error('  node .tools/create_release.js build <beta|stable> <version> [--ref <ref>]');
  console.error('  node .tools/create_release.js reset');
  process.exit(1);
}

main();
