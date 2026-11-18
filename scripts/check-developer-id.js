const assert = require('node:assert/strict');
const { join } = require('node:path');
const { spawnSync } = require('node:child_process');
const { machoFiles } = require('./check-package');

function command(command, args, run = spawnSync) {
  const result = run(command, args, { encoding: 'utf8' });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${command} ${args.join(' ')} failed: ${result.stderr}`);
  return `${result.stdout || ''}${result.stderr || ''}`;
}

function assertDeveloperIdMetadata(details, target) {
  const authority = details.match(/^Authority=Developer ID Application: [^\r\n()]+ \(([A-Z0-9]{10})\)$/m);
  assert.ok(authority, `Missing Developer ID Application signature: ${target}`);
  assert.match(details, new RegExp(`^TeamIdentifier=${authority[1]}$`, 'm'), `Signing team mismatch: ${target}`);
  assert.match(details, /^CodeDirectory .*flags=.*runtime/m, `Hardened Runtime is disabled: ${target}`);
  assert.match(details, /^Timestamp=.+$/m, `Missing secure timestamp: ${target}`);
  return authority[1];
}

function assertNoDebugEntitlement(entitlements, target) {
  assert.doesNotMatch(
    entitlements,
    /<key>com\.apple\.security\.get-task-allow<\/key>\s*<true\/>/,
    `Debug entitlement is enabled: ${target}`
  );
}

function checkDeveloperId(bundle = join(__dirname, '..', 'out/PaperMode-darwin-arm64/PaperMode.app'), run = spawnSync) {
  const contents = join(bundle, 'Contents');
  const helper = join(contents, 'Resources', 'papermode-helper');
  const binaries = machoFiles(contents);
  assert.ok(binaries.includes(helper), `Missing helper: ${helper}`);
  let expectedTeam;
  for (const target of binaries) {
    command('codesign', ['--verify', '--strict', target], run);
    const team = assertDeveloperIdMetadata(command('codesign', ['-dvvv', target], run), target);
    if (expectedTeam) assert.equal(team, expectedTeam, `Signing team mismatch: ${target}`);
    else expectedTeam = team;
    assertNoDebugEntitlement(command('codesign', ['-d', '--entitlements', ':-', target], run), target);
  }
  const helperDetails = command('codesign', ['-dvvv', helper], run);
  assert.match(helperDetails, /^Identifier=papermode-helper$/m, 'Unexpected native helper identifier');
  console.log(JSON.stringify({ bundle, machOBinaries: binaries.length, signing: 'Developer ID', hardenedRuntime: true, debugEntitlement: false, status: 'passed' }, null, 2));
}

if (require.main === module) checkDeveloperId(process.argv[2]);
module.exports = { assertDeveloperIdMetadata, assertNoDebugEntitlement, checkDeveloperId };
