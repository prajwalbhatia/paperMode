const { spawnSync } = require('node:child_process');
const { join } = require('node:path');
const root = join(__dirname, '..');
const targetArch = 'arm64';

function validateHost(platform, arch) {
  if (platform !== 'darwin' || arch !== targetArch) {
    throw new Error('Packaging currently requires macOS with ARM64 Node.js. Use native ARM64 Node, not x64 Node under Rosetta.');
  }
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.signal || result.status})`);
  return result;
}

function packageApp() {
  validateHost(process.platform, process.arch);
  run(process.execPath, [join(__dirname, 'build-native.js')]);
  // Inspect the actual binary before allowing Forge to include it.
  const result = run('lipo', ['-archs', join(root, '.build/native/papermode-helper')], { encoding: 'utf8', stdio: 'pipe' });
  if (result.stdout.trim() !== targetArch) {
    throw new Error(`Expected an ${targetArch} helper, got: ${result.stdout.trim()}`);
  }
  run(join(root, 'node_modules/.bin/electron-forge'), ['package', '--platform=darwin', `--arch=${targetArch}`]);
  run(process.execPath, [join(__dirname, 'check-package.js')]);
}

if (require.main === module) {
  try { packageApp(); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = { validateHost };
