const { test } = require('node:test');
const assert = require('node:assert/strict');
const { assertDeveloperIdMetadata, assertNoDebugEntitlement } = require('../scripts/check-developer-id');

const developerDetails = [
  'Authority=Developer ID Application: Example (ABCDE12345)',
  'TeamIdentifier=ABCDE12345',
  'Timestamp=Nov 18, 2026 at 11:00:00 PM',
  'CodeDirectory v=20500 flags=0x10000(runtime) hashes=7+2 location=embedded'
].join('\n');

test('Developer ID checker requires authority, team and hardened runtime', () => {
  assert.doesNotThrow(() => assertDeveloperIdMetadata(developerDetails, 'PaperMode.app'));
  assert.throws(() => assertDeveloperIdMetadata(developerDetails.replace('Developer ID Application', 'Apple Development'), 'PaperMode.app'), /Developer ID/);
  assert.throws(() => assertDeveloperIdMetadata(developerDetails.replace('runtime', 'adhoc'), 'PaperMode.app'), /Hardened Runtime/);
  assert.throws(() => assertDeveloperIdMetadata(developerDetails.replace(/^Timestamp=.*\n/m, ''), 'PaperMode.app'), /timestamp/);
});

test('Developer ID checker rejects the debug entitlement only when it is enabled', () => {
  assert.doesNotThrow(() => assertNoDebugEntitlement('<plist><dict/></plist>', 'PaperMode.app'));
  assert.throws(() => assertNoDebugEntitlement('<key>com.apple.security.get-task-allow</key>\n<true/>', 'PaperMode.app'), /Debug entitlement/);
});
