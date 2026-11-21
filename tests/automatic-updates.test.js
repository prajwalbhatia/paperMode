const test = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, readFileSync, writeFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { AutomaticUpdateAlerts, DAY, HOUR, MINUTE } = require('../src/main/automatic-updates');

function setup(t, overrides = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'papermode-update-alerts-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, 'update-alerts.json');
  let clock = 1_000_000_000, scheduled;
  const timers = {
    setTimer: (callback, delay) => { scheduled = { callback, delay }; return scheduled; },
    clearTimer: () => { scheduled = null; }
  };
  const config = { path, now: () => clock, ...timers, ...overrides };
  return { config, path, scheduled: () => scheduled, advance: ms => { clock += ms; } };
}

test('checks after startup, alerts once, and remembers a release across restarts', async t => {
  const { config, path, scheduled, advance } = setup(t);
  let checks = 0, alerts = 0;
  const release = { tag: 'v0.2.0-preview.1' };
  const options = { ...config, check: async () => { checks++; return release; },
    notify: async () => { alerts++; }, canNotify: () => true };
  const first = new AutomaticUpdateAlerts(path, options);
  first.start();
  assert.equal(scheduled().delay, 30_000);
  await first.tick();
  assert.equal(checks, 1);
  assert.equal(alerts, 1);
  assert.equal(JSON.parse(readFileSync(path)).highestAlertedTag, release.tag);
  first.stop();

  const second = new AutomaticUpdateAlerts(path, options);
  second.start();
  await second.tick();
  assert.equal(checks, 1, 'a restart within a day does not repeat the request');
  assert.equal(alerts, 1);
  advance(DAY);
  await second.tick();
  assert.equal(checks, 2);
  assert.equal(alerts, 1, 'a known release is not announced again');
  second.stop();
});

test('a release found during a lock waits until the app is idle', async t => {
  let idle = true, resolveCheck, alerts = 0;
  const { config, scheduled } = setup(t);
  const watcher = new AutomaticUpdateAlerts(config.path, {
    ...config, canNotify: () => idle,
    check: () => new Promise(resolve => { resolveCheck = resolve; }),
    notify: async () => { alerts++; }
  });
  watcher.start();
  const checking = watcher.tick();
  idle = false;
  resolveCheck({ tag: 'v0.2.0-preview.1' });
  await checking;
  assert.equal(alerts, 0);
  assert.equal(scheduled().delay, MINUTE);
  assert.throws(() => readFileSync(config.path), { code: 'ENOENT' }, 'a pending alert must be checked again after restart');
  idle = true;
  watcher.onStateChange();
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(alerts, 1);
  watcher.stop();
});

test('a newly installed build checks again even if the old build checked recently', async t => {
  const { config, path } = setup(t);
  let checks = 0;
  const options = { ...config, canNotify: () => true, check: async () => { checks++; return null; }, notify: async () => {} };
  const oldBuild = new AutomaticUpdateAlerts(path, { ...options, buildIdentity: 'v0.1.0-preview.1' });
  oldBuild.start(); await oldBuild.tick(); oldBuild.stop();
  const newBuild = new AutomaticUpdateAlerts(path, { ...options, buildIdentity: 'v0.1.1-preview.1' });
  newBuild.start(); await newBuild.tick(); newBuild.stop();
  assert.equal(checks, 2);
});

test('network failure retries later and a manual result prevents duplicate alerts', async t => {
  const { config, scheduled, path } = setup(t);
  const watcher = new AutomaticUpdateAlerts(path, {
    ...config, canNotify: () => true,
    check: async () => { throw new Error('offline'); }, notify: async () => {}
  });
  watcher.start();
  await watcher.tick();
  assert.equal(scheduled().delay, HOUR);
  watcher.recordManualResult({ tag: 'v0.2.0-preview.1' });
  assert.equal(JSON.parse(readFileSync(path)).highestAlertedTag, 'v0.2.0-preview.1');
  watcher.stop();
});

test('withdrawing a newer release does not announce an older release again', async t => {
  const { config, path, advance } = setup(t);
  let current = { tag: 'v0.2.0-preview.1' };
  const shown = [];
  const watcher = new AutomaticUpdateAlerts(path, {
    ...config, canNotify: () => true, check: async () => current,
    notify: async release => { shown.push(release.tag); }
  });
  watcher.start();
  await watcher.tick();
  advance(DAY);
  current = { tag: 'v0.2.0-preview.2' };
  await watcher.tick();
  advance(DAY);
  current = { tag: 'v0.2.0-preview.1' };
  await watcher.tick();
  assert.deepEqual(shown, ['v0.2.0-preview.1', 'v0.2.0-preview.2']);
  assert.equal(JSON.parse(readFileSync(path)).highestAlertedTag, 'v0.2.0-preview.2');
  watcher.stop();
});

test('manual checks cannot lower the highest announced release', async t => {
  const { config, path } = setup(t);
  const watcher = new AutomaticUpdateAlerts(path, {
    ...config, canNotify: () => true, check: async () => null, notify: async () => {}
  });
  watcher.recordManualResult({ tag: 'v0.2.0-preview.2' });
  watcher.recordManualResult({ tag: 'v0.2.0-preview.1' });
  assert.equal(JSON.parse(readFileSync(path)).highestAlertedTag, 'v0.2.0-preview.2');
});

test('existing alert preferences migrate without repeating the old release', async t => {
  const { config, path } = setup(t);
  writeFileSync(path, JSON.stringify({ buildIdentity: 'local-0.1.0', lastCheckedAt: 0,
    lastAlertedTag: 'v0.2.0-preview.2' }));
  const shown = [];
  const watcher = new AutomaticUpdateAlerts(path, {
    ...config, buildIdentity: 'local-0.1.0', canNotify: () => true,
    check: async () => ({ tag: 'v0.2.0-preview.1' }),
    notify: async release => { shown.push(release.tag); }
  });
  watcher.start(); await watcher.tick(); watcher.stop();
  assert.deepEqual(shown, []);
  assert.equal(JSON.parse(readFileSync(path)).highestAlertedTag, 'v0.2.0-preview.2');
});
