const { test } = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, writeFileSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { assertAccepted, notaryProfile, notarizedArchivePath, publishWithoutReplace } = require('../scripts/notarize-release');

test('notarization only accepts an explicit safe Keychain profile name', () => {
  assert.throws(() => notaryProfile({}), /PAPERMODE_NOTARY_PROFILE/);
  assert.throws(() => notaryProfile({ PAPERMODE_NOTARY_PROFILE: 'profile; rm -rf /' }), /may contain only/);
  assert.equal(notaryProfile({ PAPERMODE_NOTARY_PROFILE: 'papermode-notary' }), 'papermode-notary');
});

test('notarized archive has a fixed product and architecture name', () => {
  assert.match(notarizedArchivePath('/tmp/PaperMode.app', '0.1.0'), /out\/notarized\/PaperMode-0\.1\.0-macos-arm64\.zip$/);
});

test('notarization requires an explicit accepted response', () => {
  assert.equal(assertAccepted('{"status":"Accepted"}').status, 'Accepted');
  assert.throws(() => assertAccepted('{"status":"Invalid"}'), /Invalid/);
  assert.throws(() => assertAccepted('{"id":"123"}'), /unknown/);
});

test('a second notarization run cannot replace an already published ZIP', () => {
  const dir = mkdtempSync(join(tmpdir(), 'papermode-publish-'));
  try {
    const first = join(dir, 'first.zip');
    const second = join(dir, 'second.zip');
    const finalPath = join(dir, 'PaperMode.zip');
    writeFileSync(first, 'accepted first build');
    writeFileSync(second, 'accepted second build');
    publishWithoutReplace(first, finalPath);
    assert.throws(() => publishWithoutReplace(second, finalPath), { code: 'EEXIST' });
    assert.equal(readFileSync(finalPath, 'utf8'), 'accepted first build');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
