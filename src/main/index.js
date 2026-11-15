const { app, Tray, Menu, nativeImage, dialog, globalShortcut, shell, powerMonitor } = require('electron');
const { join } = require('node:path');
const { helperPath, diagnose } = require('./helper');
const { SessionController } = require('./controller');
const { HelperSession } = require('./session');
const START_SHORTCUT = 'Control+Alt+Command+P';
const smokeTest = process.argv.includes('--smoke-test');
const bounded = !app.isPackaged && process.argv.includes('--bounded-locks');
let tray, controller, refreshTimer;
let quitting = false;
let exitCode = 0;
let canExit = false;
let shortcutRegistered = false;

const messages = {
  shortcut: 'Unlocked with the shortcut.',
  'system-sleep': 'Session ended when your Mac went to sleep.',
  'session-inactive': 'Session ended when your Mac was locked.',
  'app-quit': 'Session ended.',
  'development-test-ended': 'Development safety limit reached.',
  'accessibility-required': 'Enable Accessibility, then check permission again.',
  'permission-revoked': 'Accessibility permission was removed. Input has been released.',
  'unsupported-keyboard-layout': 'Select a layout with L at the standard keyboard position.',
  'keyboard-layout-changed': 'The keyboard layout changed. Check permission and layout before restarting.',
  'helper-start-timeout': 'The helper did not start in time. Try again.',
  'helper-exited': 'The helper stopped unexpectedly. Input has been released.',
  'helper-launch-failed': 'Could not launch the native helper. Check the installation.',
  'helper-check-failed': 'Could not check the native helper. Check the installation.',
  'permission-check-failed': 'Permission could not be verified, so the session ended.',
  'helper-protocol-error': 'The helper connection returned an invalid response.',
};
function registerStartShortcut() {
  if (quitting || shortcutRegistered) return;
  shortcutRegistered = globalShortcut.register(START_SHORTCUT, () => {
    if (!quitting && !smokeTest) void controller.start();
  });
}
function render() {
  if (!tray || tray.isDestroyed()) return;
  const { state, reason } = controller.snapshot;
  const labels = { checking: 'Checking permission…', ready: 'Ready', 'permission-required': 'Permission required', starting: 'Starting — prepare your notebook', locked: 'Locked', error: 'Needs attention' };
  tray.setToolTip(`PaperMode — ${labels[state]}`);
  tray.setTitle(state === 'locked' ? 'Locked' : state === 'starting' ? 'Starting…' : '');
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: `PaperMode — ${labels[state]}`, enabled: false },
    ...(bounded ? [{ label: 'Development mode: 30-second safety limit', enabled: false }] : []),
    { label: shortcutRegistered ? 'Start: ⌃⌥⌘P' : 'Start shortcut unavailable — another app may be using it', enabled: false },
    ...(!shortcutRegistered ? [{ label: 'Release ⌃⌥⌘P in the other app, then retry', enabled: false },
      { label: 'Retry start shortcut', click: () => { registerStartShortcut(); render(); } }] : []),
    { label: 'Unlock: hold ⌃⌥⌘L for 2 seconds', enabled: false },
    ...(reason ? [{ label: messages[reason] || 'Could not maintain the session. Check permission and try again.', enabled: false }] : []),
    { type: 'separator' },
    { label: 'Enable Accessibility…', enabled: !controller.session && !controller.busy, click: async () => {
      await controller.requestPermission();
      if (!quitting) await shell.openExternal('x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility');
    } },
    { label: 'Check permission and layout', enabled: !controller.session && !controller.busy, click: () => void controller.refresh() },
    { label: 'How to use PaperMode', enabled: !controller.session && !controller.busy, click: () => void dialog.showMessageBox({
      message: 'Watch your course and take paper notes',
      detail: 'Enable Accessibility for the app macOS identifies. Start your video, then press Control + Option + Command + P. You have five seconds to release the keys and position your notebook.\n\nTo unlock, lift the notebook and hold Control + Option + Command + L for two seconds. The reminder shows your progress. Normal sessions have no automatic time limit.'
    }) },
    { type: 'separator' },
    { label: 'Quit PaperMode', click: () => app.quit() }
  ]));
}

app.setName('PaperMode');
if (!app.requestSingleInstanceLock()) app.exit(smokeTest ? 1 : 0);
else {
  app.whenReady().then(async () => {
    app.dock?.hide();
    const icon = nativeImage.createFromPath(join(__dirname, '../../assets/paperTemplate.png'));
    if (icon.isEmpty()) throw new Error('Menu bar icon could not be loaded');
    icon.setTemplateImage(true);
    tray = new Tray(icon);
    controller = new SessionController(helperPath(app), {
      createSession: path => new HelperSession(path, { mode: bounded ? 'bounded' : 'normal' })
    });
    controller.on('change', render);
    registerStartShortcut();
    render();
    await controller.refresh();
    if (quitting) return;
    if (smokeTest) {
      const report = await diagnose(helperPath(app));
      console.log(JSON.stringify({ menuBarCreated: !tray.isDestroyed(), shortcutRegistered, state: controller.snapshot.state, native: report }));
      if (!shortcutRegistered) throw new Error('Start shortcut registration failed');
      app.quit();
      return;
    }
    // Fresh diagnostics while idle detect settings changes without caching AX state in Electron.
    refreshTimer = setInterval(() => {
      if (!shortcutRegistered) { registerStartShortcut(); render(); }
      if (['ready', 'permission-required'].includes(controller.snapshot.state)) void controller.refresh();
    }, 3000);
    powerMonitor.on('suspend', () => void controller.cancel());
    powerMonitor.on('lock-screen', () => void controller.cancel());
    powerMonitor.on('resume', () => void controller.refresh());
  }).catch(error => { console.error(error.message); exitCode = 1; app.quit(); });
  app.on('window-all-closed', () => {});
  app.on('before-quit', event => {
    if (canExit) return;
    event.preventDefault();
    if (quitting) return;
    quitting = true;
    clearInterval(refreshTimer);
    globalShortcut.unregisterAll();
    // Native parent-exit/EOF recovery remains independent if Electron is killed.
    const deadline = setTimeout(() => app.exit(1), 2500);
    Promise.resolve(controller?.dispose()).finally(() => {
      clearTimeout(deadline);
      tray?.destroy();
      canExit = true;
      app.exit(exitCode);
    });
  });
}
