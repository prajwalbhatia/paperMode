const { readFileSync, mkdirSync, writeFileSync, renameSync } = require('node:fs');
const { dirname } = require('node:path');

const instructions = [
  '1. Allow access\nEnable Accessibility for the app macOS identifies. In development this may be Visual Studio Code; the installed app may have a different name. Return to the paper icon in your menu bar and wait for Ready.',
  '2. Start your course\nPress Control + Option + Command + P or choose Start PaperMode. A five-second countdown gives you time to release the keys and position your notebook. Your video stays visible and keeps playing.',
  '3. Unlock deliberately\nLift the notebook and hold Control + Option + Command + L together for two seconds. Releasing early resets the hold. The reminder stays visible while input is locked.',
  'All connected keyboards and pointing devices are blocked. Normal sessions have no time limit. Hardware power/Touch ID and macOS security controls are outside PaperMode’s guarantee.'
].join('\n\n');

class UsageGuide {
  constructor(path, { dialog, canShow, needsPermission, requestPermission, onVisibilityChange = () => {}, onError = () => {} }) {
    Object.assign(this, { path, dialog, canShow, needsPermission, requestPermission, onVisibilityChange, onError });
    this.isOpen = false;
  }
  hasBeenSeen() {
    try { return JSON.parse(readFileSync(this.path, 'utf8')).welcomeVersion === 1; }
    catch { return false; }
  }
  remember() {
    // Only onboarding acknowledgement is persisted, never lock state or input.
    try {
      mkdirSync(dirname(this.path), { recursive: true });
      writeFileSync(`${this.path}.tmp`, JSON.stringify({ welcomeVersion: 1 }) + '\n', { mode: 0o600 });
      renameSync(`${this.path}.tmp`, this.path);
    } catch { /* A read-only profile must not prevent use of the app. */ }
  }
  async show({ firstUse = false } = {}) {
    if (this.isOpen || !this.canShow() || (firstUse && this.hasBeenSeen())) return;
    this.isOpen = true;
    this.onVisibilityChange();
    try {
      const permission = this.needsPermission();
      const { response } = await this.dialog.showMessageBox({
        type: 'info', title: 'PaperMode',
        message: firstUse ? 'Welcome to PaperMode' : 'Watch your course. Take paper notes.',
        detail: instructions,
        buttons: permission ? ['Enable Accessibility…', 'Not now'] : ['Got it'],
        defaultId: 0, cancelId: permission ? 1 : 0, noLink: true
      });
      this.remember();
      if (permission && response === 0 && this.canShow()) await this.requestPermission();
    } catch (error) { this.onError(error); }
    finally { this.isOpen = false; this.onVisibilityChange(); }
  }
}
module.exports = { UsageGuide };
