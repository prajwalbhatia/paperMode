const assert = require('node:assert/strict');
const { readFileSync, readdirSync, accessSync, constants } = require('node:fs');
const { join, resolve } = require('node:path');
const { execFileSync } = require('node:child_process');
const root = join(__dirname, '..');

// Structural checks only: never launch the app, request permission, or lock input.
async function checkPackage(bundle = join(root, 'out/PaperMode-darwin-arm64/PaperMode.app')) {
  const { extractFile } = await import('@electron/asar'); // Installed by Forge; pinned in the lockfile.
  const contents = join(resolve(bundle), 'Contents');
  const resources = join(contents, 'Resources');
  const plist = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', join(contents, 'Info.plist')], { encoding: 'utf8' }));
  const pkg = JSON.parse(readFileSync(join(root, 'package.json')));
  assert.equal(plist.CFBundleIdentifier, 'app.papermode.desktop');
  assert.equal(plist.CFBundleExecutable, 'PaperMode');
  assert.equal(plist.CFBundleShortVersionString, pkg.version);
  assert.equal(plist.LSUIElement, true);
  assert.equal(plist.LSMinimumSystemVersion, '13.0');
  for (const binary of [join(contents, 'MacOS', plist.CFBundleExecutable), join(resources, 'papermode-helper')]) {
    accessSync(binary, constants.X_OK);
    assert.equal(execFileSync('lipo', ['-archs', binary], { encoding: 'utf8' }).trim(), 'arm64');
  }
  for (const [source, bundled] of [
    ['assets/PaperMode.icns', plist.CFBundleIconFile],
    ['assets/PaperMode.png', 'PaperMode.png'],
    ['.build/native/papermode-helper', 'papermode-helper']
  ]) {
    assert.deepEqual(readFileSync(join(resources, bundled)), readFileSync(join(root, source)), `Outdated or incorrect packaged ${bundled}`);
  }
  const archive = join(resources, 'app.asar');
  const packagedManifest = JSON.parse(extractFile(archive, 'package.json'));
  assert.equal(packagedManifest.version, pkg.version);
  assert.equal(packagedManifest.main, pkg.main);
  let sourceFiles = 0;
  function checkTree(relative) {
    for (const entry of readdirSync(join(root, relative), { withFileTypes: true })) {
      const file = `${relative}/${entry.name}`;
      if (entry.isDirectory()) checkTree(file);
      else {
        assert.deepEqual(extractFile(archive, file), readFileSync(join(root, file)), `Outdated or missing packaged ${file}`);
        sourceFiles++;
      }
    }
  }
  checkTree('src');
  for (const file of ['PaperMode.png', 'paperTemplate.png', 'paperTemplate@2x.png']) {
    assert.deepEqual(extractFile(archive, `assets/${file}`), readFileSync(join(root, 'assets', file)));
  }
  console.log(JSON.stringify({ bundle: resolve(bundle), version: pkg.version, architecture: 'arm64', sourceFiles, structuralChecks: 'passed', runtimeAcceptance: 'not tested by this command' }, null, 2));
}
if (require.main === module) checkPackage(process.argv[2]).catch(error => { console.error(error); process.exitCode = 1; });
module.exports = { checkPackage };
