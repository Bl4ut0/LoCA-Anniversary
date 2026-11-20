'use strict';

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

const repoRoot = path.resolve(__dirname, '..');
const addonRoot = path.join(repoRoot, 'LoCA');

function collectLuaFiles(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      collectLuaFiles(full, out);
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.lua')) {
      out.push(full);
    }
  }
  return out;
}

if (!fs.existsSync(addonRoot)) {
  console.error('Addon folder not found:', addonRoot);
  process.exit(1);
}

const files = collectLuaFiles(addonRoot).sort();
if (files.length === 0) {
  console.error('No Lua files found under', addonRoot);
  process.exit(1);
}

let failures = 0;
for (const file of files) {
  const rel = path.relative(repoRoot, file).replace(/\\/g, '/');
  const src = fs.readFileSync(file, 'utf8');
  try {
    luaparse.parse(src, {
      luaVersion: '5.1',
      comments: false,
      scope: false,
      locations: true,
    });
  } catch (err) {
    failures += 1;
    console.error(`LUA SYNTAX ERROR in ${rel}: ${err.message}`);
  }
}

if (failures > 0) {
  console.error(`Lua syntax validation failed (${failures} file(s)).`);
  process.exit(1);
}

console.log(`Lua syntax check passed (${files.length} files).`);
