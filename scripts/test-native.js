const { spawnSync } = require('node:child_process');
const { mkdirSync } = require('node:fs');
const { join } = require('node:path');
const root = join(__dirname, '..');
mkdirSync(join(root, '.build/tests'), { recursive: true });
const binary = join(root, '.build/tests/unlock-chord');
for (const [command, args] of [
  ['xcrun', ['swiftc', '-module-cache-path', join(root, '.build/module-cache'), join(root, 'native/PaperMode/UnlockChord.swift'), join(root, 'native/PaperMode/InputPolicy.swift'), join(root, 'tests/native/main.swift'), '-o', binary]],
  [binary, []]
]) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status || 1);
}
