const test = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const { readdirSync, mkdirSync } = require('node:fs');
const { join } = require('node:path');
const root = join(__dirname, '../..');

test('native preparation cancels on sleep and session deactivation', { timeout: 60000 }, () => {
  const source = join(root, 'native/PaperMode');
  const binary = join(root, '.build/tests/preparation');
  mkdirSync(join(root, '.build/tests'), { recursive: true });
  const files = readdirSync(source).filter(x => x.endsWith('.swift') && x !== 'main.swift').map(x => join(source, x));
  const build = spawnSync('xcrun', ['swiftc', '-module-cache-path', join(root, '.build/module-cache'), ...files,
    join(root, 'tests/native-preparation/main.swift'), '-o', binary], { encoding: 'utf8', timeout: 45000 });
  assert.equal(build.status, 0, build.stderr);
  for (const [mode, reason] of [['sleep', 'system-sleep'], ['inactive', 'session-inactive']]) {
    const run = spawnSync(binary, [mode], { encoding: 'utf8', timeout: 10000 });
    assert.equal(run.status, 0, run.stderr);
    const events = run.stdout.trim().split('\n').map(JSON.parse);
    assert.equal(events.length, 1);
    assert.equal(events[0].event, 'unlocked');
    assert.equal(events[0].reason, reason);
    assert.equal(events[0].elapsedMilliseconds, 0);
  }
});
