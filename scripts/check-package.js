const assert = require('node:assert/strict');
const { readFileSync, readdirSync, accessSync, constants, openSync, readSync, closeSync } = require('node:fs');
const { join, resolve } = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const root = join(__dirname, '..');

function verifySignature(target, identifier, deep = false, run = spawnSync) {
  for (const args of [
    ['--verify', '--strict', ...(deep ? ['--deep'] : []), target],
    ['-dv', target]
  ]) {
    const result = run('codesign', args, { encoding: 'utf8' });
    if (result.error) throw result.error;
    assert.equal(result.status, 0, `Invalid signature for ${target}: ${result.stderr}`);
    if (args[0] === '-dv') {
      assert.equal(result.stderr.match(/^Identifier=(.+)$/m)?.[1], identifier, `Unexpected signing identity for ${target}`);
    }
  }
}

// Walk real files only: framework symlinks alias binaries already under Versions.
function machoFiles(directory) {
  const files = [];
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...machoFiles(path));
    else if (entry.isFile()) {
      const fd = openSync(path, 'r');
      const magic = Buffer.alloc(4);
      try {
        if (readSync(fd, magic, 0, 4, 0) === 4 &&
            ['feedface', 'cefaedfe', 'feedfacf', 'cffaedfe', 'cafebabe', 'bebafeca', 'cafebabf', 'bfbafeca'].includes(magic.toString('hex'))) files.push(path);
      } finally { closeSync(fd); }
    }
  }
  return files;
}

function verifyArchitectures(binaries, run = execFileSync) {
  for (const binary of binaries) {
    assert.equal(run('lipo', ['-archs', binary], { encoding: 'utf8' }).trim(), 'arm64', `Unexpected architecture for ${binary}`);
  }
}

function verifySourceInventory(current, packaged) {
  assert.deepEqual([...packaged].sort(), [...current].sort(), 'Packaged src inventory differs from checkout (missing or stale files)');
}

// Structural checks only: never launch the app, request permission, or lock input.
async function checkPackage(bundle = join(root, 'out/PaperMode-darwin-arm64/PaperMode.app')) {
  const { extractFile, listPackage, statFile } = await import('@electron/asar'); // Installed by Forge; pinned in the lockfile.
  const contents = join(resolve(bundle), 'Contents');
  const resources = join(contents, 'Resources');
  const plist = JSON.parse(execFileSync('plutil', ['-convert', 'json', '-o', '-', join(contents, 'Info.plist')], { encoding: 'utf8' }));
  const pkg = JSON.parse(readFileSync(join(root, 'package.json')));
  assert.equal(plist.CFBundleIdentifier, 'app.papermode.desktop');
  assert.equal(plist.CFBundleExecutable, 'PaperMode');
  assert.equal(plist.CFBundleShortVersionString, pkg.version);
  assert.equal(plist.LSUIElement, true);
  assert.equal(plist.LSMinimumSystemVersion, '13.0');
  verifySignature(resolve(bundle), 'app.papermode.desktop', true);
  verifySignature(join(resources, 'papermode-helper'), 'papermode-helper');
  const binaries = machoFiles(contents);
  for (const binary of [join(contents, 'MacOS', plist.CFBundleExecutable), join(resources, 'papermode-helper')]) {
    accessSync(binary, constants.X_OK);
    assert.ok(binaries.includes(binary), `Missing Mach-O executable: ${binary}`);
  }
  verifyArchitectures(binaries);
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
  const sourceFiles = [];
  function checkTree(relative) {
    for (const entry of readdirSync(join(root, relative), { withFileTypes: true })) {
      const file = `${relative}/${entry.name}`;
      if (entry.isDirectory()) checkTree(file);
      else {
        assert.deepEqual(extractFile(archive, file), readFileSync(join(root, file)), `Outdated or missing packaged ${file}`);
        sourceFiles.push(file);
      }
    }
  }
  checkTree('src');
  const packagedSources = listPackage(archive).map(file => file.replace(/^\//, ''))
    .filter(file => file.startsWith('src/') && !statFile(archive, file).files);
  verifySourceInventory(sourceFiles, packagedSources);
  for (const file of ['PaperMode.png', 'paperTemplate.png', 'paperTemplate@2x.png']) {
    assert.deepEqual(extractFile(archive, `assets/${file}`), readFileSync(join(root, 'assets', file)));
  }
  console.log(JSON.stringify({ bundle: resolve(bundle), version: pkg.version, architecture: 'arm64', machOBinaries: binaries.length, sourceFiles: sourceFiles.length, structuralChecks: 'passed', runtimeAcceptance: 'not tested by this command' }, null, 2));
}
if (require.main === module) checkPackage(process.argv[2]).catch(error => { console.error(error); process.exitCode = 1; });
module.exports = { checkPackage, verifySignature, machoFiles, verifyArchitectures, verifySourceInventory };
