const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, rmSync, readFileSync, writeFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { UsageGuide } = require('../src/main/guide');
function setup(t, overrides = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'papermode-guide-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'welcome.json');
  const shown = []; let requests = 0;
  const guide = new UsageGuide(path, {
    dialog: { showMessageBox: async options => { shown.push(options); return { response: 1 }; } },
    canShow: () => true, needsPermission: () => true,
    requestPermission: async () => { requests++; }, ...overrides
  });
  return { guide, path, shown, requests: () => requests };
}
test('Not now acknowledges first use without requesting permission; Help remains available', async t => {
  const { guide, path, shown, requests } = setup(t);
  await guide.show({ firstUse: true });
  assert.equal(requests(), 0);
  assert.deepEqual(JSON.parse(readFileSync(path)), { welcomeVersion: 1 });
  await guide.show({ firstUse: true });
  assert.equal(shown.length, 1);
  await guide.show();
  assert.equal(shown.length, 2);
  assert.equal(guide.isOpen, false);
});
test('explicit Enable choice requests permission once', async t => {
  const { guide, requests } = setup(t, { dialog: { showMessageBox: async () => ({ response: 0 }) } });
  await guide.show();
  assert.equal(requests(), 1);
});
test('granted permission offers Got it and never requests again', async t => {
  const { guide, shown, requests } = setup(t, { needsPermission: () => false });
  await guide.show();
  assert.deepEqual(shown[0].buttons, ['Got it']);
  assert.equal(requests(), 0);
});
test('guide deduplicates and ignores permission action after quit or session start', async t => {
  let resolve, allowed = true, count = 0;
  const { guide, requests } = setup(t, {
    canShow: () => allowed,
    dialog: { showMessageBox: () => { count++; return new Promise(r => { resolve = r; }); } }
  });
  const pending = guide.show();
  assert.equal(guide.isOpen, true);
  await guide.show();
  assert.equal(count, 1);
  allowed = false;
  resolve({ response: 0 });
  await pending;
  assert.equal(requests(), 0);
  assert.equal(guide.isOpen, false);
  await guide.show();
  assert.equal(count, 1);
});
test('corrupt preference shows welcome again', async t => {
  const { guide, path, shown } = setup(t);
  writeFileSync(path, '{');
  await guide.show({ firstUse: true });
  assert.equal(shown.length, 1);
});
test('dialog failure releases UI gate and does not acknowledge welcome', async t => {
  let errors = 0;
  const { guide } = setup(t, {
    dialog: { showMessageBox: async () => { throw new Error('unavailable'); } },
    onError: () => errors++
  });
  await guide.show({ firstUse: true });
  assert.equal(errors, 1);
  assert.equal(guide.isOpen, false);
  assert.equal(guide.hasBeenSeen(), false);
});
