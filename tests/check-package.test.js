const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, mkdirSync, writeFileSync, symlinkSync, rmSync } = require('node:fs');
const { join } = require('node:path');
const { tmpdir } = require('node:os');
const { verifySignature, machoFiles, verifyArchitectures, verifySourceInventory } = require('../scripts/check-package');

test('helper verification rejects an invalid signature even with the expected identifier', () => {
  const calls = [];
  const run = (_command, args) => {
    calls.push(args);
    return args[0] === '--verify'
      ? { status: 1, stderr: 'invalid code signature' }
      : { status: 0, stderr: 'Identifier=papermode-helper\n' };
  };
  assert.throws(() => verifySignature('/app/Contents/Resources/papermode-helper', 'papermode-helper', false, run), /Invalid signature/);
  assert.deepEqual(calls, [['--verify', '--strict', '/app/Contents/Resources/papermode-helper']]);
});

test('helper verification rejects a valid signature with the wrong identifier', () => {
  const run = () => ({ status: 0, stderr: 'Identifier=other-helper\n' });
  assert.throws(() => verifySignature('/helper', 'papermode-helper', false, run), /Unexpected signing identity/);
  assert.doesNotThrow(() => verifySignature('/helper', 'papermode-helper', false,
    () => ({ status: 0, stderr: 'Identifier=papermode-helper\n' })));
});

test('architecture scan reaches nested frameworks and helpers and rejects x64 code', t => {
  const root = mkdtempSync(join(tmpdir(), 'papermode-mach-o-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const framework = join(root, 'Frameworks/Example.framework/Versions/A');
  const helper = join(root, 'Frameworks/Helper.app/Contents/MacOS');
  mkdirSync(framework, { recursive: true }); mkdirSync(helper, { recursive: true });
  const frameworkBinary = join(framework, 'Example');
  const helperBinary = join(helper, 'Helper');
  writeFileSync(frameworkBinary, Buffer.from('cffaedfe00000000', 'hex'));
  writeFileSync(helperBinary, Buffer.from('cafebabe00000000', 'hex'));
  writeFileSync(join(root, 'icon.png'), 'not executable');
  symlinkSync('A', join(framework, '../Current'));
  const binaries = machoFiles(root);
  assert.deepEqual(binaries.sort(), [frameworkBinary, helperBinary].sort());
  for (const wrong of binaries) {
    assert.throws(() => verifyArchitectures(binaries, (_command, args) => args[1] === wrong ? 'x86_64\n' : 'arm64\n'), /Unexpected architecture/);
  }
  assert.doesNotThrow(() => verifyArchitectures(binaries, () => 'arm64\n'));
});

test('source inventory rejects both obsolete packaged modules and missing current modules', () => {
  const current = ['src/main/index.js', 'src/guide/preload.js'];
  assert.throws(() => verifySourceInventory(current, [...current, 'src/main/obsolete.js']), /stale files/);
  assert.throws(() => verifySourceInventory(current, current.slice(1)), /missing/);
  assert.doesNotThrow(() => verifySourceInventory(current, [...current].reverse()));
});
