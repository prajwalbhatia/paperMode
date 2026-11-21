const { mkdirSync, mkdtempSync, copyFileSync, writeFileSync, readFileSync, renameSync, rmSync } = require('node:fs');
const { join } = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const { checkPackage } = require('./check-package');
const root = join(__dirname, '..');
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status})`);
}
function artifactName(version, prerelease = false) {
  if (typeof version !== 'string' || version !== version.trim() || !/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version)) throw new Error('Unsafe release version');
  return `PaperMode-${version}-macos-arm64-${prerelease ? 'unnotarized-preview' : 'local-qa'}.zip`;
}
async function prepare() {
  const prerelease = process.argv.includes('--prerelease');
  const pkg = JSON.parse(readFileSync(join(root, 'package.json')));
  const name = artifactName(pkg.version, prerelease);
  if (prerelease && (!pkg.paperModeReleaseTag || !new RegExp(`^v${pkg.version.replaceAll('.', '\\.')}-preview\\.\\d+$`).test(pkg.paperModeReleaseTag))) {
    throw new Error('Set paperModeReleaseTag to the matching preview tag before public prerelease packaging');
  }
  if (prerelease && execFileSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' }).trim()) {
    throw new Error('Prerelease packaging requires a clean committed source tree');
  }
  run(process.execPath, [join(__dirname, 'package.js')]);
  const bundleRoot = join(root, 'out/PaperMode-darwin-arm64');
  const sourceCommit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim();
  const sourceTreeDirty = Boolean(execFileSync('git', ['status', '--porcelain'], { cwd: root, encoding: 'utf8' }).trim());
  const work = mkdtempSync(join(root, 'out/release-local-'));
  const staging = join(work, 'staging');
  const extracted = join(work, 'verification');
  mkdirSync(staging); mkdirSync(extracted);
  run('ditto', [join(bundleRoot, 'PaperMode.app'), join(staging, 'PaperMode.app')]);
  copyFileSync(join(root, 'LICENSE'), join(staging, 'LICENSE-PaperMode.txt'));
  copyFileSync(join(bundleRoot, 'LICENSE'), join(staging, 'LICENSE-Electron.txt'));
  copyFileSync(join(bundleRoot, 'LICENSES.chromium.html'), join(staging, 'LICENSES.chromium.html'));
  copyFileSync(join(root, 'docs/INSTALL.md'), join(staging, 'INSTALL.md'));
  writeFileSync(join(staging, prerelease ? 'UNNOTARIZED-PREVIEW.txt' : 'LOCAL-QA.txt'), prerelease
    ? 'Preview build for early testing. Ad-hoc signed; not Developer ID signed or notarized by Apple.\nRead INSTALL.md for the per-app macOS approval flow and known limitations. Normal sessions have no timeout.\n'
    : 'Local QA candidate only. Ad-hoc signed; not Developer ID signed or notarized.\nDo not treat this artifact as an approved public release. Packaged sessions have no timeout.\n');
  const pending = join(work, `${name}.pending`);
  run('ditto', ['-c', '-k', '--sequesterRsrc', staging, pending]);
  run('ditto', ['-x', '-k', pending, extracted]);
  await checkPackage(join(extracted, 'PaperMode.app'));
  const signed = spawnSync('codesign', ['-dv', join(extracted, 'PaperMode.app')], { encoding: 'utf8' });
  if (signed.status !== 0 || !/^Signature=adhoc$/m.test(signed.stderr)) throw new Error('Local release workflow expects the current ad-hoc signing configuration');
  const sha256 = createHash('sha256').update(readFileSync(pending)).digest('hex');
  renameSync(pending, join(work, name));
  writeFileSync(join(work, 'SHA256SUMS.txt'), `${sha256}  ${name}\n`);
  writeFileSync(join(work, 'manifest.json'), JSON.stringify({ version: pkg.version, artifact: name, sha256, architecture: 'arm64', sourceCommit, sourceTreeDirty, signing: 'ad-hoc', notarized: false, channel: prerelease ? 'unnotarized-preview' : 'local-qa', publicReleaseApproved: false, archiveVerification: 'passed', runtimeAcceptance: 'not performed by this command' }, null, 2) + '\n');
  rmSync(staging, { recursive: true }); rmSync(extracted, { recursive: true });
  console.log(`Local QA artifacts: ${work}`);
}
if (require.main === module) prepare().catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = { artifactName };
