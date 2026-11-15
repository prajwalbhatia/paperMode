const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const { join } = require('node:path');
const execute = promisify(execFile);
function helperPath(app) {
  return app.isPackaged
    ? join(process.resourcesPath, 'papermode-helper')
    : join(__dirname, '../../.build/native/papermode-helper');
}
async function diagnose(path) {
  const { stdout } = await execute(path, ['--diagnose'], { timeout: 5000, maxBuffer: 16384 });
  const result = JSON.parse(stdout);
  if (result.name !== 'papermode-helper' || result.protocolVersion !== 1 || result.inputLockImplemented !== true ||
      typeof result.accessibilityTrusted !== 'boolean' || typeof result.unlockLayoutSupported !== 'boolean') {
    throw new Error('Unsupported native helper response');
  }
  return result;
}
async function requestPermission(path) {
  const { stdout } = await execute(path, ['--request-permission'], { timeout: 5000, maxBuffer: 16384 });
  const report = JSON.parse(stdout);
  if (typeof report.accessibilityTrusted !== 'boolean') throw new Error('Invalid permission response');
  return report;
}
module.exports = { helperPath, diagnose, requestPermission };
