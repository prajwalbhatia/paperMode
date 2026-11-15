const { spawn } = require('node:child_process');
const { EventEmitter } = require('node:events');
const { randomUUID } = require('node:crypto');

// A disposable helper connection. Never reuse a process across lock sessions.
class HelperSession extends EventEmitter {
  constructor(path, { spawnHelper = spawn, mode = 'normal', startupTimeout = 12000, stopTimeout = 1000 } = {}) {
    super();
    this.path = path;
    this.spawnHelper = spawnHelper;
    this.mode = mode;
    this.startupTimeout = startupTimeout;
    this.stopTimeout = stopTimeout;
    this.requestID = randomUUID();
    this.phase = 'new';
    this.stopping = false;
    this.buffer = '';
    this.closed = new Promise(resolve => { this.resolveClosed = resolve; });
  }

  start() {
    if (this.phase !== 'new') return;
    this.phase = 'connecting';
    this.deadline = setTimeout(() => this.fail('helper-start-timeout'), this.startupTimeout);
    try {
      const flag = { normal: '--ipc', bounded: '--ipc-test', preview: '--ipc-preview' }[this.mode];
      if (!flag) throw new Error('Invalid helper mode');
      this.child = this.spawnHelper(this.path, [flag], { stdio: ['pipe', 'pipe', 'pipe'] });
      this.child.stdout.setEncoding('utf8');
      this.child.stdout.on('data', chunk => this.receive(chunk));
      this.child.stdout.on('error', () => this.fail('helper-output-failed'));
      this.child.stdout.on('end', () => {
        if (!this.stopping && !['unlocked', 'closed'].includes(this.phase)) this.fail('helper-connection-lost');
      });
      this.child.stdin.on('error', () => { if (!this.stopping) this.fail('helper-connection-lost'); });
      // Drain native diagnostics without retaining or exposing arbitrary output.
      this.child.stderr.resume();
      this.child.on('error', () => this.fail('helper-launch-failed'));
      this.child.once('close', (code, signal) => this.didClose(code, signal));
    } catch {
      this.fail('helper-launch-failed');
      this.didClose(null, null);
    }
  }

  receive(chunk) {
    if (this.phase === 'closed' || this.stopping) return;
    this.buffer += chunk;
    if (Buffer.byteLength(this.buffer) > 16384) return this.fail('helper-protocol-error');
    let index;
    while ((index = this.buffer.indexOf('\n')) !== -1) {
      const line = this.buffer.slice(0, index);
      this.buffer = this.buffer.slice(index + 1);
      let value;
      try { value = JSON.parse(line); } catch { return this.fail('helper-protocol-error'); }
      if (!value || value.protocolVersion !== 1 || value.preview !== (this.mode === 'preview')) {
        return this.fail('helper-protocol-error');
      }
      if (this.phase === 'connecting' && value.event === 'ready' && value.requestID === null) {
        if (value.testSession !== (this.mode === 'bounded')) return this.fail('helper-protocol-error');
        this.phase = 'requested';
        this.write('start', this.requestID);
        continue;
      }
      if (value.requestID !== this.requestID) return this.fail('helper-protocol-error');
      if (value.event === 'starting' && this.phase === 'requested' && value.delaySeconds === 5) {
        this.phase = 'starting';
      } else if (value.event === (this.mode === 'preview' ? 'preview' : 'locked') && this.phase === 'starting') {
        if (value.testSession !== (this.mode !== 'normal')) return this.fail('helper-protocol-error');
        this.phase = 'locked';
        clearTimeout(this.deadline);
      } else if (value.event === 'unlocked' && typeof value.reason === 'string' && ['starting', 'locked', 'requested'].includes(this.phase)) {
        this.phase = 'unlocked';
        this.unlockReason = value.reason;
        clearTimeout(this.deadline);
        this.exitDeadline = setTimeout(() => this.fail('helper-exit-timeout'), this.stopTimeout);
      } else if (value.event === 'error' && typeof value.reason === 'string') {
        return this.fail(value.reason);
      } else {
        return this.fail('helper-protocol-error');
      }
      this.emit('event', value);
    }
  }

  write(command, requestID = randomUUID()) {
    if (!this.child?.stdin.writable) return this.fail('helper-connection-lost');
    this.child.stdin.write(JSON.stringify({ protocolVersion: 1, requestID, command }) + '\n');
  }

  fail(reason) {
    if (this.phase === 'closed' || this.fault) return;
    this.fault = reason;
    this.emit('fault', reason);
    this.stop();
  }

  stop() {
    if (this.phase === 'closed') return this.closed;
    if (!this.stopping) {
      this.stopping = true;
      clearTimeout(this.deadline);
      clearTimeout(this.exitDeadline);
      if (this.child?.stdin.writable) {
        this.write('shutdown');
        this.child.stdin.end();
      }
      if (this.child) this.killDeadline = setTimeout(() => this.child.kill('SIGKILL'), this.stopTimeout);
      else this.didClose(null, null);
    }
    return this.closed;
  }

  didClose(code, signal) {
    if (this.phase === 'closed') return;
    const expected = this.phase === 'unlocked' || this.stopping;
    this.phase = 'closed';
    clearTimeout(this.deadline);
    clearTimeout(this.exitDeadline);
    clearTimeout(this.killDeadline);
    const result = { reason: this.fault || this.unlockReason || (expected ? 'app-quit' : 'helper-exited'), code, signal };
    this.resolveClosed(result);
    this.emit('closed', result);
  }
}
module.exports = { HelperSession };
