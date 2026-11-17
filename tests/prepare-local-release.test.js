const test = require('node:test');
const assert = require('node:assert/strict');
const { artifactName } = require('../scripts/prepare-local-release');
test('local artifacts identify version, architecture and QA status', () => {
  assert.equal(artifactName('0.1.0'), 'PaperMode-0.1.0-macos-arm64-local-qa.zip');
  assert.equal(artifactName('0.1.0-rc.1'), 'PaperMode-0.1.0-rc.1-macos-arm64-local-qa.zip');
});
test('version cannot escape artifact directory', () => {
  for (const version of ['../0.1.0', '/tmp/release', '0.1.0/name', '0.1.0\n']) {
    assert.throws(() => artifactName(version));
  }
});

test('preview artifacts clearly identify their unnotarized status', () => {
  assert.equal(artifactName('0.1.0', true), 'PaperMode-0.1.0-macos-arm64-unnotarized-preview.zip');
});
