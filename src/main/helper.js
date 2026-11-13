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
  const { stdout } = await execute(path, ['--diagnose'], { timeout: 5000 });
  const result = JSON.parse(stdout);
  if (result.name !== 'papermode-helper' || result.protocolVersion !== 1) {
    throw new Error('Unsupported native helper response');
  }
  return result;
}
module.exports = { helperPath, diagnose };
