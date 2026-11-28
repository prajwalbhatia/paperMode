const { readFileSync, mkdirSync, writeFileSync, renameSync } = require('node:fs');
const { dirname, join } = require('node:path');

const instructions = [
  '1. Allow access\nEnable Accessibility for the app macOS identifies. In development this may be Visual Studio Code; the installed app may have a different name. Return to the paper icon in your menu bar and wait for Ready.',
  '2. Start your course\nClose this guide to start PaperMode. Press Control + Option + Command + P or choose Start PaperMode. A five-second countdown gives you time to release the keys and position your notebook. Your video stays visible and keeps playing.',
  '3. Unlock deliberately\nLift the notebook and hold Control + Option + Command + L together for two seconds. Releasing early resets the hold. The reminder stays visible while input is locked.',
  'Play/pause while locked\nPaperMode can lock input over any browser. Playback controls work in Chrome, Safari, and Firefox when macOS Accessibility exposes one recognizable player. Bring your course video to the front before starting. Lift the notebook and press Control + Option + Command + Space once to pause or resume. Release the keys before pressing again. PaperMode controls the player selected when the session started. If the video does not respond or play/pause is unavailable, unlock and use the player normally.',
  'Skip while locked\nOn a compatible player, press Control + Option + Command + Left Arrow to go back about five seconds, or Right Arrow to go forward. Release the arrow before pressing again. Some course players need you to click the video before locking so it has focus. Check the video after each request. If seeking is unavailable, unlock and use the player normally.',
  'All connected keyboards and pointing devices are blocked. Normal sessions have no time limit. Hardware power/Touch ID and macOS security controls are outside PaperMode’s guarantee.'
];
const permissionRecovery = 'Permission still required?\nIf PaperMode is already enabled in System Settings → Privacy & Security → Accessibility, close this guide and quit PaperMode. Remove only PaperMode’s entry from the Accessibility list, then reopen the copy in Applications. Add it with + if it is missing, enable it, and choose Check permission and layout from the menu. Do not remove other apps’ permissions.';

class UsageGuide {
  constructor(path, { dialog, canShow, needsPermission, requestPermission, onVisibilityChange = () => {}, onError = () => {} }) {
    Object.assign(this, { path, dialog, canShow, needsPermission, requestPermission, onVisibilityChange, onError });
    this.isOpen = false;
  }
  notifyStartBlocked() {
    if (this.isOpen) this.dialog.notifyStartBlocked?.();
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
        icon: join(__dirname, '../../assets/PaperMode.png'),
        message: firstUse ? 'Welcome to PaperMode' : 'Watch your course. Take paper notes.',
        detail: (permission ? [instructions[0], permissionRecovery, ...instructions.slice(1)] : instructions).join('\n\n'),
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
