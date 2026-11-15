const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { join } = require('node:path');
const { HelperSession } = require('../../src/main/session');
const path = join(__dirname, '../../.build/native/papermode-helper');
async function server(t, mode = '--ipc') {
  const child = spawn(path, [mode], { stdio: ['pipe', 'pipe', 'pipe'] });
  t.after(() => { if (child.exitCode === null) child.kill('SIGKILL'); });
  const frames = []; let buffer = '';
  child.stderr.resume();
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', data => {
    buffer += data;
    let end;
    while ((end = buffer.indexOf('\n')) >= 0) {
      frames.push(JSON.parse(buffer.slice(0, end)));
      buffer = buffer.slice(end + 1);
    }
  });
  const closed = new Promise(resolve => child.once('close', resolve));
  const waitFor = async event => {
    const until = Date.now() + 8000;
    while (!frames.some(x => x.event === event)) {
      if (Date.now() >= until || child.exitCode !== null) throw new Error(`Missing ${event}: ${JSON.stringify(frames)}`);
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    return frames.find(x => x.event === event);
  };
  const send = (command, requestID) => child.stdin.write(JSON.stringify({ protocolVersion: 1, requestID, command })+'\n');
  await waitFor('ready');
  return { child, frames, closed, waitFor, send };
}
test('native protocol status is correlated; EOF exits without locking', { timeout: 10000 }, async t => {
  const s = await server(t);
  s.send('status', 'check-1');
  const status = await s.waitFor('status');
  assert.equal(status.requestID, 'check-1');
  assert.equal(typeof status.accessibilityTrusted, 'boolean');
  s.child.stdin.end();
  await s.closed;
  assert.equal(s.frames.at(-1).reason, 'connection-lost');
  assert.ok(!s.frames.some(x => x.event === 'locked'));
});
for (const input of ['not-json\n', JSON.stringify({ protocolVersion: true, requestID: 'bad', command: 'status' })+'\n', 'x'.repeat(17000)]) {
  test(`native rejects invalid input (${input.length} bytes)`, { timeout: 10000 }, async t => {
    const s = await server(t);
    s.child.stdin.write(input);
    await s.closed;
    assert.ok(s.frames.some(x => x.reason === 'protocol-error'));
    assert.ok(!s.frames.some(x => x.event === 'locked'));
  });
}
test('native refuses reused request IDs', { timeout: 10000 }, async t => {
  const s = await server(t);
  s.send('status', 'same'); s.send('status', 'same');
  await s.closed;
  assert.ok(s.frames.some(x => x.reason === 'protocol-error'));
});
test('shutdown cancels a pending preview before its delayed start', { timeout: 10000 }, async t => {
  const s = await server(t, '--ipc-preview');
  s.send('start', 'session');
  await s.waitFor('starting');
  s.send('shutdown', 'quit');
  await s.closed;
  assert.ok(!s.frames.some(x => x.event === 'preview'));
  assert.equal(s.frames.at(-1).reason, 'app-quit');
});
test('real transport receives preview confirmation and cleans up on shutdown', { timeout: 15000 }, async t => {
  const session = new HelperSession(path, { mode: 'preview' });
  t.after(() => session.stop());
  const events = [];
  const preview = new Promise((resolve, reject) => {
    session.on('event', value => { events.push(value); if (value.event === 'preview') resolve(); });
    session.on('fault', reason => reject(new Error(reason)));
  });
  session.start();
  await preview;
  assert.equal(session.phase, 'locked');
  await session.stop();
  assert.equal(session.phase, 'closed');
  assert.deepEqual(events.map(x => x.event), ['starting', 'preview']);
});

test('duplicate native start fails closed before input can be intercepted', { timeout: 10000 }, async t => {
  const s = await server(t, '--ipc-preview');
  s.send('start', 'one'); s.send('start', 'two');
  await s.closed;
  assert.ok(s.frames.some(x => x.reason === 'protocol-error'));
  assert.ok(!s.frames.some(x => x.event === 'preview'));
});
test('EOF during an active preview tears down the session', { timeout: 15000 }, async t => {
  const s = await server(t, '--ipc-preview');
  s.send('start', 'session');
  await s.waitFor('preview');
  s.child.stdin.end();
  await s.closed;
  assert.equal(s.frames.at(-1).reason, 'connection-lost');
  assert.equal(s.frames.at(-1).requestID, 'session');
});
