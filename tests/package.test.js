const { test } = require('node:test');
const assert = require('node:assert/strict');
const { validateHost } = require('../scripts/package');

test('accepts native ARM64 macOS packaging', () => {
  assert.doesNotThrow(() => validateHost('darwin', 'arm64'));
});
test('rejects Rosetta/x64 Node before building or packaging', () => {
  assert.throws(() => validateHost('darwin', 'x64'), /ARM64 Node/);
});
test('rejects other packaging platforms', () => {
  assert.throws(() => validateHost('linux', 'arm64'), /macOS/);
});
