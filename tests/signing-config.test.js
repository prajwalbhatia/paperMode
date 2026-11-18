const { test } = require('node:test');
const assert = require('node:assert/strict');
const { developerIdIdentity, osxSignConfig, releaseSigningMode } = require('../scripts/signing-config');

test('the preview mode retains its isolated ad-hoc configuration', () => {
  const config = osxSignConfig({});
  assert.equal(releaseSigningMode({}), 'adhoc-preview');
  assert.equal(config.identity, '-');
  assert.equal(config.identityValidation, false);
  assert.equal(config.optionsForFile('/tmp/PaperMode.app').hardenedRuntime, false);
  assert.equal(config.ignore('/tmp/papermode-helper'), true);
});

test('Developer ID mode requires a Developer ID Application identity', () => {
  assert.throws(() => osxSignConfig({ PAPERMODE_SIGNING_MODE: 'developer-id' }), /PAPERMODE_DEVELOPER_ID_IDENTITY/);
  assert.throws(() => developerIdIdentity({ PAPERMODE_DEVELOPER_ID_IDENTITY: 'Apple Development: Example' }), /Developer ID Application/);
});

test('local hardened mode mirrors the release hardening without requiring a certificate', () => {
  const config = osxSignConfig({ PAPERMODE_SIGNING_MODE: 'hardened-local' });
  assert.equal(config.identity, '-');
  assert.equal(config.identityValidation, false);
  assert.equal(config.ignore, undefined);
  assert.equal(config.optionsForFile('/tmp/papermode-helper').hardenedRuntime, true);
  assert.match(config.optionsForFile('/tmp/PaperMode.app').entitlements, /electron-local\.plist$/);
});

test('Developer ID mode signs every target with hardened runtime and narrow entitlements', () => {
  const config = osxSignConfig({
    PAPERMODE_SIGNING_MODE: 'developer-id',
    PAPERMODE_DEVELOPER_ID_IDENTITY: 'Developer ID Application: Example (ABCDE12345)'
  });
  assert.equal(config.identityValidation, true);
  assert.equal(config.ignore, undefined);
  const helper = config.optionsForFile('/tmp/papermode-helper');
  assert.match(helper.entitlements, /papermode-helper\.plist$/);
  assert.deepEqual(helper.additionalArguments, ['--identifier', 'papermode-helper']);
  assert.match(config.optionsForFile('/tmp/PaperMode Helper (Renderer).app').entitlements, /electron-renderer\.plist$/);
  assert.match(config.optionsForFile('/tmp/PaperMode Helper (GPU).app').entitlements, /electron-renderer\.plist$/);
  assert.match(config.optionsForFile('/tmp/PaperMode Helper (Plugin).app').entitlements, /electron-plugin\.plist$/);
  assert.match(config.optionsForFile('/tmp/PaperMode.app').entitlements, /electron-main\.plist$/);
  assert.equal(config.optionsForFile('/tmp/PaperMode.app').hardenedRuntime, true);
});

test('unknown signing modes fail closed', () => {
  assert.throws(() => releaseSigningMode({ PAPERMODE_SIGNING_MODE: 'anything-else' }), /PAPERMODE_SIGNING_MODE/);
});
