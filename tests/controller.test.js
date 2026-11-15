const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { SessionController } = require('../src/main/controller');
const good = { accessibilityTrusted: true, unlockLayoutSupported: true };
function deferred() { let resolve; const promise = new Promise(r => { resolve = r; }); return { promise, resolve }; }
function setup(options = {}) {
  const sessions = [];
  const controller = new SessionController('/fixture', {
    inspect: async () => good,
    createSession: () => {
      const session = new EventEmitter();
      session.start = () => { session.started = true; };
      session.stop = async () => session.emit('closed', { reason: 'app-quit' });
      sessions.push(session);
      return session;
    }, ...options
  });
  return { controller, sessions };
}
test('duplicate starts cannot create competing locks', async () => {
  const check = deferred();
  const { controller, sessions } = setup({ inspect: () => check.promise });
  const first = controller.start();
  await controller.start();
  assert.equal(controller.snapshot.state, 'starting');
  assert.equal(sessions.length, 0);
  check.resolve(good);
  await first;
  assert.equal(sessions.length, 1);
  await controller.start();
  assert.equal(sessions.length, 1);
  sessions[0].emit('event', { event: 'locked' });
  assert.equal(controller.snapshot.state, 'locked');
  sessions[0].emit('event', { event: 'unlocked', reason: 'shortcut' });
  await controller.start();
  assert.equal(sessions.length, 1, 'must wait for old process to exit');
  sessions[0].emit('closed', { reason: 'shortcut' });
  await controller.start();
  assert.equal(sessions.length, 2);
});
for (const [report, state] of [[{ ...good, accessibilityTrusted: false }, 'permission-required'], [{ ...good, unlockLayoutSupported: false }, 'error']]) {
  test(`preflight prevents start for ${state}`, async () => {
    const { controller, sessions } = setup({ inspect: async () => report });
    await controller.start();
    assert.equal(sessions.length, 0);
    assert.equal(controller.snapshot.state, state);
  });
}
test('permission revocation moves to permission-required after cleanup', async () => {
  const { controller, sessions } = setup();
  await controller.start();
  sessions[0].emit('closed', { reason: 'permission-revoked' });
  assert.equal(controller.snapshot.state, 'permission-required');
});
test('helper failure is an error and stale session events cannot change a new session', async () => {
  const { controller, sessions } = setup();
  await controller.start();
  sessions[0].emit('closed', { reason: 'helper-exited' });
  assert.equal(controller.snapshot.state, 'error');
  await controller.start();
  sessions[0].emit('event', { event: 'locked' });
  assert.equal(controller.snapshot.state, 'starting');
});
test('quit during preflight cannot launch a late helper', async () => {
  const check = deferred();
  const { controller, sessions } = setup({ inspect: () => check.promise });
  const start = controller.start();
  await controller.dispose();
  check.resolve(good);
  await start;
  assert.equal(sessions.length, 0);
});
test('sleep during preflight cancels the pending start', async () => {
  const check = deferred();
  const { controller, sessions } = setup({ inspect: () => check.promise });
  const start = controller.start();
  await controller.cancel();
  check.resolve(good);
  await start;
  assert.equal(sessions.length, 0);
});
test('stale idle diagnostic cannot overwrite session state', async () => {
  const check = deferred(); let calls = 0;
  const { controller } = setup({ inspect: () => ++calls === 1 ? check.promise : Promise.resolve(good) });
  const refresh = controller.refresh();
  await controller.start();
  check.resolve({ ...good, accessibilityTrusted: false });
  await refresh;
  assert.equal(controller.snapshot.state, 'starting');
});

test('failed preflight re-enables permission controls after busy clears', async () => {
  const { controller } = setup({ inspect: async () => ({ ...good, unlockLayoutSupported: false }) });
  const updates = [];
  controller.on('change', value => updates.push({ state: value.state, busy: controller.busy }));
  await controller.start();
  assert.deepEqual(updates.at(-1), { state: 'error', busy: false });
});
