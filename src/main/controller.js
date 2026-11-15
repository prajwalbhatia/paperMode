const { EventEmitter } = require('node:events');
const { diagnose, requestPermission } = require('./helper');
const { HelperSession } = require('./session');

class SessionController extends EventEmitter {
  constructor(path, { inspect = diagnose, askPermission = requestPermission, createSession = path => new HelperSession(path) } = {}) {
    super();
    Object.assign(this, { path, inspect, askPermission, createSession });
    this.snapshot = { state: 'checking', reason: null };
    this.generation = 0;
    this.disposed = false;
    this.session = null;
    this.busy = false;
  }
  update(state, reason = null) {
    this.snapshot = { state, reason };
    this.emit('change', this.snapshot);
  }
  applyReport(report) {
    this.report = report;
    if (!report.accessibilityTrusted) this.update('permission-required', 'accessibility-required');
    else if (!report.unlockLayoutSupported) this.update('error', 'unsupported-keyboard-layout');
    else this.update('ready');
  }
  async refresh() {
    if (this.disposed || this.busy || this.session) return;
    const generation = ++this.generation;
    try {
      const report = await this.inspect(this.path);
      if (generation === this.generation && !this.disposed) this.applyReport(report);
    } catch {
      if (generation === this.generation && !this.disposed) {
        this.report = null;
        this.update('error', 'helper-check-failed');
      }
    }
  }
  async requestPermission() {
    if (this.disposed || this.busy || this.session) return;
    this.busy = true;
    ++this.generation;
    try { await this.askPermission(this.path); }
    catch { if (!this.disposed) this.update('error', 'permission-request-failed'); }
    finally { this.busy = false; if (!this.disposed) this.emit('change', this.snapshot); }
    await this.refresh();
  }
  async start() {
    if (this.disposed || this.busy || this.session) return;
    this.busy = true;
    const generation = ++this.generation;
    this.update('starting');
    try {
      const report = await this.inspect(this.path);
      if (generation !== this.generation || this.disposed) return;
      if (!report.accessibilityTrusted || !report.unlockLayoutSupported) {
        this.applyReport(report);
        return;
      }
      const session = this.createSession(this.path);
      this.session = session;
      session.on('event', value => {
        if (this.session !== session || this.disposed) return;
        if (value.event === 'locked') this.update('locked');
      });
      session.on('fault', reason => {
        if (this.session === session && !this.disposed) this.update('error', reason);
      });
      session.once('closed', ({ reason }) => {
        if (this.session !== session) return;
        this.session = null;
        if (this.disposed) return;
        if (reason === 'accessibility-required' || reason === 'permission-revoked') this.update('permission-required', reason);
        else if (['shortcut', 'system-sleep', 'session-inactive', 'app-quit', 'development-test-ended'].includes(reason)) {
          this.update('ready', reason);
          void this.refresh();
        } else this.update('error', reason);
      });
      session.start();
    } catch { if (!this.disposed) this.update('error', 'helper-launch-failed'); }
    finally { this.busy = false; if (!this.disposed) this.emit('change', this.snapshot); }
  }
  async cancel() {
    ++this.generation;
    if (this.session) await this.session.stop();
    else if (!this.disposed) this.update('ready');
  }
  async dispose() {
    this.disposed = true;
    ++this.generation;
    if (this.session) await this.session.stop();
  }
}
module.exports = { SessionController };
