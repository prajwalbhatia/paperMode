const { readFileSync, writeFileSync, renameSync, mkdirSync } = require('node:fs');
const { dirname } = require('node:path');
const { version, paperModeReleaseTag } = require('../../package.json');

const DAY = 24 * 60 * 60 * 1000;
const HOUR = 60 * 60 * 1000;
const MINUTE = 60 * 1000;

class AutomaticUpdateAlerts {
  constructor(path, { check, notify, canNotify, now = Date.now,
    setTimer = setTimeout, clearTimer = clearTimeout,
    buildIdentity = paperModeReleaseTag || `local-${version}` } = {}) {
    Object.assign(this, { path, check, notify, canNotify, now, setTimer, clearTimer });
    this.state = { buildIdentity, lastCheckedAt: 0, lastAlertedTag: null };
    try {
      const saved = JSON.parse(readFileSync(path, 'utf8'));
      if (saved.buildIdentity === buildIdentity) {
        if (Number.isFinite(saved.lastCheckedAt) && saved.lastCheckedAt >= 0) this.state.lastCheckedAt = saved.lastCheckedAt;
        if (typeof saved.lastAlertedTag === 'string') this.state.lastAlertedTag = saved.lastAlertedTag;
      }
    } catch { /* A missing or corrupt preference should not prevent checking. */ }
    this.pending = null;
    this.timer = null;
    this.active = false;
    this.delivering = false;
  }
  save() {
    try {
      mkdirSync(dirname(this.path), { recursive: true });
      writeFileSync(`${this.path}.tmp`, JSON.stringify(this.state) + '\n', { mode: 0o600 });
      renameSync(`${this.path}.tmp`, this.path);
    } catch { /* A read-only profile only affects alert deduplication. */ }
  }
  schedule(delay) {
    if (!this.active) return;
    if (this.timer !== null) this.clearTimer(this.timer);
    this.timer = this.setTimer(() => { this.timer = null; void this.tick(); }, delay);
  }
  start() {
    if (this.active) return;
    this.active = true;
    this.schedule(30 * 1000);
  }
  stop() {
    this.active = false;
    if (this.timer !== null) this.clearTimer(this.timer);
    this.timer = null;
  }
  async deliver() {
    if (!this.active || !this.pending || this.delivering || !this.canNotify()) return;
    this.delivering = true;
    const release = this.pending;
    try {
      await this.notify(release);
      if (this.active) {
        this.state.lastAlertedTag = release.tag;
        this.pending = null;
        this.save();
      }
    } catch { /* Keep the release pending for the next idle opportunity. */ }
    finally { this.delivering = false; }
  }
  async tick() {
    if (!this.active) return;
    if (this.pending) {
      await this.deliver();
      this.schedule(this.pending ? MINUTE : DAY);
      return;
    }
    if (!this.canNotify()) { this.schedule(MINUTE); return; }
    const elapsed = this.now() - this.state.lastCheckedAt;
    if (elapsed >= 0 && elapsed < DAY) { this.schedule(DAY - elapsed); return; }
    try {
      const release = await this.check();
      if (!this.active) return;
      this.state.lastCheckedAt = this.now();
      if (release && release.tag !== this.state.lastAlertedTag) this.pending = release;
      await this.deliver();
      if (!this.pending) this.save();
      this.schedule(this.pending ? MINUTE : DAY);
    } catch { this.schedule(HOUR); }
  }
  onStateChange() {
    if (this.pending) void this.deliver();
  }
  recordManualResult(release) {
    this.state.lastCheckedAt = this.now();
    if (release) {
      this.state.lastAlertedTag = release.tag;
      if (this.pending?.tag === release.tag) this.pending = null;
    }
    this.save();
  }
}

module.exports = { AutomaticUpdateAlerts, DAY, HOUR, MINUTE };
