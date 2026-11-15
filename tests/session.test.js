const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { PassThrough } = require('node:stream');
const { HelperSession } = require('../src/main/session');

function setup(t, options = {}) {
  const child = new EventEmitter();
  Object.assign(child, { stdin: new PassThrough(), stdout: new PassThrough(), stderr: new PassThrough(), kills: [] });
  child.kill = signal => { child.kills.push(signal); setImmediate(() => child.emit('close', null, signal)); };
  const requests = [];
  child.stdin.on('data', data => requests.push(JSON.parse(data.toString())));
  const session = new HelperSession('/fixture', { spawnHelper: () => child, startupTimeout: 200, stopTimeout: 20, ...options });
  t.after(() => child.emit('close', 0, null));
  const send = (event, fields = {}) => child.stdout.write(JSON.stringify({ protocolVersion: 1, requestID: event === 'ready' ? null : session.requestID, preview: false, event, ...fields }) + '\n');
  session.start();
  return { child, session, requests, send };
}
test('correlates fragmented handshake and waits for confirmed lock', async t => {
  const { child, session, requests, send } = setup(t);
  const ready = JSON.stringify({ protocolVersion: 1, requestID: null, event: 'ready', preview: false, testSession: false })+'\n';
  child.stdout.write(ready.slice(0, 12));
  assert.equal(requests.length, 0);
  child.stdout.write(ready.slice(12));
  assert.equal(requests[0].command, 'start');
  assert.equal(requests[0].requestID, session.requestID);
  send('starting', { delaySeconds: 5 });
  assert.equal(session.phase, 'starting');
  send('locked', { testSession: false });
  assert.equal(session.phase, 'locked');
  send('unlocked', { reason: 'shortcut' });
  child.emit('close', 0, null);
  assert.equal((await session.closed).reason, 'shortcut');
});
for (const [name, frame] of [
  ['wrong version', { protocolVersion: 2, requestID: null, event: 'ready', preview: false }],
  ['preview cannot masquerade as a lock', { protocolVersion: 1, requestID: null, event: 'ready', preview: true }],
  ['wrong request ID', { protocolVersion: 1, requestID: 'other', event: 'locked', preview: false }]
]) test(name, async t => {
  const { child, session } = setup(t);
  child.stdout.write(JSON.stringify(frame)+'\n');
  assert.equal((await session.closed).reason, 'helper-protocol-error');
  assert.deepEqual(child.kills, ['SIGKILL']);
});
test('malformed JSON closes the connection', async t => {
  const { child, session } = setup(t);
  child.stdout.write('not json\n');
  assert.equal((await session.closed).reason, 'helper-protocol-error');
});
test('oversized unterminated frame is bounded', async t => {
  const { child, session } = setup(t);
  child.stdout.write('x'.repeat(16385));
  assert.equal((await session.closed).reason, 'helper-protocol-error');
});
test('locked before starting is rejected', async t => {
  const { session, send } = setup(t);
  send('ready', { testSession: false });
  send('locked', { testSession: false });
  assert.equal((await session.closed).reason, 'helper-protocol-error');
});
test('startup timeout releases an unresponsive helper', async t => {
  const { session } = setup(t, { startupTimeout: 10 });
  assert.equal((await session.closed).reason, 'helper-start-timeout');
});
test('shutdown is idempotent and escalates if helper ignores it', async t => {
  const { session, child, requests } = setup(t);
  const first = session.stop();
  const second = session.stop();
  await Promise.all([first, second]);
  assert.equal(requests.filter(x => x.command === 'shutdown').length, 1);
  assert.deepEqual(child.kills, ['SIGKILL']);
});
test('unexpected child exit never claims a successful unlock', async t => {
  const { child, session } = setup(t);
  child.emit('close', 1, null);
  assert.equal((await session.closed).reason, 'helper-exited');
});
test('launch errors are surfaced and cleanup completes', async t => {
  const { child, session } = setup(t);
  child.emit('error', new Error('ENOENT'));
  child.emit('close', -2, null);
  assert.equal((await session.closed).reason, 'helper-launch-failed');
});
test('native permission failure keeps its reason', async t => {
  const { session, send } = setup(t);
  send('ready', { testSession: false });
  send('error', { reason: 'accessibility-required' });
  assert.equal((await session.closed).reason, 'accessibility-required');
});

test('stdout loss during a lock stops the helper', async t => {
  const { child, session, send } = setup(t);
  send('ready', { testSession: false });
  send('starting', { delaySeconds: 5 });
  send('locked', { testSession: false });
  child.stdout.end();
  assert.equal((await session.closed).reason, 'helper-connection-lost');
});
