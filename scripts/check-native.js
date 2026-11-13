const assert = require('node:assert/strict');
const { join } = require('node:path');
const { diagnose } = require('../src/main/helper');
diagnose(join(__dirname, '../.build/native/papermode-helper')).then(report => {
  assert.equal(report.inputLockImplemented, true);
  assert.equal(report.version, '0.1.0');
  console.log(JSON.stringify(report, null, 2));
}).catch(error => { console.error(error); process.exitCode = 1; });
