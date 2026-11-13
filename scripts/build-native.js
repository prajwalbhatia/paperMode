const { mkdirSync } = require('node:fs');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');
const root = join(__dirname, '..');
if (process.platform !== 'darwin') throw new Error('The native helper requires macOS.');
const output = join(root, '.build/native');
const cache = join(root, '.build/module-cache');
mkdirSync(output, { recursive: true });
mkdirSync(cache, { recursive: true });
const arch = process.arch === 'arm64' ? 'arm64' : 'x86_64';
const result = spawnSync('xcrun', [
  'swiftc', '-O', '-target', `${arch}-apple-macosx13.0`,
  '-module-cache-path', cache,
  ...['InputPolicy.swift', 'KeyboardLayout.swift', 'UnlockChord.swift', 'Reminder.swift', 'LockSession.swift', 'main.swift'].map(file => join(root, 'native/PaperMode', file)), '-o', join(output, 'papermode-helper')
], { stdio: 'inherit' });
if (result.error) throw result.error;
process.exit(result.status ?? 1);
