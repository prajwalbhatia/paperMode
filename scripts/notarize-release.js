const { existsSync, mkdirSync, mkdtempSync, copyFileSync, linkSync, rmSync } = require('node:fs');
const { join, dirname } = require('node:path');
const { spawnSync } = require('node:child_process');
const { checkDeveloperId } = require('./check-developer-id');
const { checkPackage } = require('./check-package');

const root = join(__dirname, '..');
const defaultBundle = join(root, 'out', 'PaperMode-darwin-arm64', 'PaperMode.app');

function notaryProfile(env = process.env) {
  const profile = env.PAPERMODE_NOTARY_PROFILE;
  if (!profile) {
    throw new Error('Set PAPERMODE_NOTARY_PROFILE to the Keychain profile created with xcrun notarytool store-credentials.');
  }
  if (!/^[A-Za-z0-9._-]+$/.test(profile)) {
    throw new Error('PAPERMODE_NOTARY_PROFILE may contain only letters, numbers, dot, underscore and hyphen.');
  }
  return profile;
}

function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.signal || result.status}): ${result.stderr || result.stdout}`);
  return result.stdout;
}

function notarizedArchivePath(bundle, version) {
  return join(root, 'out', 'notarized', `PaperMode-${version}-macos-arm64.zip`);
}

function packageForNotarization(stage, archive) {
  run('ditto', ['-c', '-k', '--sequesterRsrc', stage, archive]);
}

function assertAccepted(output) {
  const response = JSON.parse(output);
  if (response.status !== 'Accepted') throw new Error(`Apple notarization status: ${response.status || 'unknown'}`);
  return response;
}

function publishWithoutReplace(candidate, finalPath) {
  // Both files live beneath out/notarized on the same filesystem. Creating a
  // hard link is atomic and fails with EEXIST if another run published first.
  linkSync(candidate, finalPath);
}

async function notarize(bundle = defaultBundle) {
  const profile = notaryProfile();
  const packageJson = require(join(root, 'package.json'));
  if (!existsSync(bundle)) throw new Error(`Signed app bundle not found: ${bundle}`);
  checkDeveloperId(bundle);
  const outputDir = join(root, 'out', 'notarized');
  mkdirSync(outputDir, { recursive: true });
  const archive = notarizedArchivePath(bundle, packageJson.version);
  if (existsSync(archive)) throw new Error(`Final archive already exists: ${archive}. Use a new version for a new release.`);
  const work = mkdtempSync(join(outputDir, 'pending-'));
  const stage = join(work, 'stage');
  const extracted = join(work, 'extracted');
  const pending = join(work, 'candidate.zip');
  mkdirSync(stage);
  mkdirSync(extracted);
  try {
    run('ditto', [bundle, join(stage, 'PaperMode.app')]);
    for (const [source, name] of [
      [join(root, 'LICENSE'), 'LICENSE-PaperMode.txt'],
      [join(dirname(bundle), 'LICENSE'), 'LICENSE-Electron.txt'],
      [join(dirname(bundle), 'LICENSES.chromium.html'), 'LICENSES.chromium.html'],
      [join(root, 'docs', 'INSTALL-DEVELOPER-ID.md'), 'INSTALL.md']
    ]) copyFileSync(source, join(stage, name));
    packageForNotarization(stage, pending);
    assertAccepted(run('xcrun', ['notarytool', 'submit', pending, '--keychain-profile', profile, '--wait', '--output-format', 'json']));
    run('xcrun', ['stapler', 'staple', join(stage, 'PaperMode.app')]);
    run('xcrun', ['stapler', 'validate', join(stage, 'PaperMode.app')]);
    run('spctl', ['--assess', '--type', 'execute', '--verbose=4', join(stage, 'PaperMode.app')]);
    rmSync(pending);
    packageForNotarization(stage, pending);
    run('ditto', ['-x', '-k', pending, extracted]);
    for (const name of ['LICENSE-PaperMode.txt', 'LICENSE-Electron.txt', 'LICENSES.chromium.html', 'INSTALL.md']) {
      if (!existsSync(join(extracted, name))) throw new Error(`Final ZIP is missing ${name}`);
    }
    await checkPackage(join(extracted, 'PaperMode.app'), { helperResigned: true });
    checkDeveloperId(join(extracted, 'PaperMode.app'));
    run('xcrun', ['stapler', 'validate', join(extracted, 'PaperMode.app')]);
    publishWithoutReplace(pending, archive);
    console.log(run('shasum', ['-a', '256', archive]).trim());
    console.log(`Notarized archive: ${archive}`);
  } finally {
    rmSync(work, { recursive: true, force: true });
  }
}

if (require.main === module) notarize(process.argv[2]).catch(error => { console.error(error); process.exitCode = 1; });
module.exports = { assertAccepted, notaryProfile, notarizedArchivePath, publishWithoutReplace };
