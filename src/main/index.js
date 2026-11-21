const { app, Tray, Menu, nativeImage, BrowserWindow, ipcMain, screen, globalShortcut, shell, powerMonitor, dialog } = require('electron');
const { join } = require('node:path');
const { helperPath, diagnose } = require('./helper');
const { SessionController } = require('./controller');
const { HelperSession } = require('./session');
const { UsageGuide } = require('./guide');
const { GuideWindow } = require('./guide-window');
const { checkForUpdates } = require('./updates');
const { paperModeReleaseTag } = require('../../package.json');
const START_SHORTCUT = 'Control+Alt+Command+P';
const smokeTest = process.argv.includes('--smoke-test');
const bounded = !app.isPackaged && process.argv.includes('--bounded-locks');
let tray, controller, refreshTimer, guide;
let quitting = false;
let exitCode = 0;
let canExit = false;
let shortcutRegistered = false;
let checkingUpdates = false;

const messages = {
  shortcut: 'Unlocked with the shortcut.',
  'system-sleep': 'Session ended when your Mac went to sleep.',
  'session-inactive': 'Session ended when your Mac was locked.',
  'app-quit': 'Session ended.',
  'development-test-ended': 'Development safety limit reached.',
  'accessibility-required': 'Enable Accessibility. If it is already on, open the guide for recovery steps.',
  'permission-revoked': 'Accessibility permission was removed. Input has been released.',
  'unsupported-keyboard-layout': 'Select a layout with L at the standard keyboard position.',
  'keyboard-layout-changed': 'The keyboard layout changed. Check permission and layout before restarting.',
  'helper-start-timeout': 'The helper did not start in time. Try again.',
  'helper-exited': 'The helper stopped unexpectedly. Input has been released.',
  'helper-launch-failed': 'Could not launch the native helper. Check the installation.',
  'helper-check-failed': 'Could not check the native helper. Check the installation.',
  'permission-check-failed': 'Permission could not be verified, so the session ended.',
  'help-unavailable': 'Could not open the guide. Use Enable Accessibility, then Start PaperMode. Hold ⌃⌥⌘L to unlock.',
  'permission-request-failed': 'Could not request permission. Open macOS Privacy & Security settings and try again.',
  'reminder-unavailable': 'The unlock reminder could not stay visible. Input has been released.',
  'event-tap-unavailable': 'macOS could not block input. Check Accessibility permission and try again.',
  'event-source-unavailable': 'Input blocking could not start. Try again.',
  'event-tap-timeout': 'macOS stopped input blocking. Input has been released; try again.',
  'event-tap-disabled-by-user-input': 'macOS stopped input blocking. Input has been released.',
  'event-tap-observed-disabled': 'Input blocking stopped. Input has been released.',
  'helper-connection-lost': 'Connection to PaperMode’s input helper was lost. The session has ended.',
  'helper-protocol-error': 'The helper connection returned an invalid response.',
};
async function enableAccessibility() {
  if (quitting || controller.session || controller.busy) return;
  await controller.requestPermission();
  if (!quitting) {
    try { await shell.openExternal('x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'); }
    catch { controller.update('error', 'permission-request-failed'); }
  }
}
async function checkUpdates() {
  if (quitting || smokeTest || guide?.isOpen || controller.session || controller.busy || checkingUpdates) return;
  checkingUpdates = true;
  render();
  let openingRelease = false;
  try {
    const release = await checkForUpdates();
    if (quitting || controller.session || guide?.isOpen) return;
    const result = await dialog.showMessageBox(release ? {
      type: 'info', title: 'PaperMode', message: `PaperMode ${release.tag} is available`,
      detail: `${release.notes || 'See the release page for details.'}\n\nQuit PaperMode before replacing the app.`,
      buttons: ['View release', 'Later'], defaultId: 0, cancelId: 1, noLink: true
    } : {
      type: 'info', title: 'PaperMode', message: 'No newer PaperMode release found',
      detail: `Current release: ${paperModeReleaseTag}. Check again later.`,
      buttons: ['OK'], noLink: true
    });
    if (release && result.response === 0 && !quitting) {
      openingRelease = true;
      await shell.openExternal(release.url);
    }
  } catch {
    if (!quitting && !controller.session) await dialog.showMessageBox({
      type: 'warning', title: 'PaperMode',
      message: openingRelease ? 'Could not open the release page' : 'Could not check for updates',
      detail: openingRelease ? 'Open PaperMode’s GitHub Releases page in your browser.' :
        'GitHub may be unavailable or your internet connection may be offline. Try again later.',
      buttons: ['OK'], noLink: true
    });
  } finally { checkingUpdates = false; if (!quitting) render(); }
}
function startSession() {
  if (quitting || smokeTest || checkingUpdates) return;
  if (guide?.isOpen) { guide.notifyStartBlocked(); return; }
  void controller.start();
}
function registerStartShortcut() {
  if (quitting || shortcutRegistered) return;
  shortcutRegistered = globalShortcut.register(START_SHORTCUT, startSession);
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
    { label: 'Start PaperMode', enabled: !quitting && !smokeTest && !guide?.isOpen && !checkingUpdates && state === 'ready' && !controller.session && !controller.busy,
      click: startSession },
    { label: 'Enable Accessibility…', enabled: !guide?.isOpen && !controller.session && !controller.busy, click: enableAccessibility },
    { label: 'Check permission and layout', enabled: !guide?.isOpen && !controller.session && !controller.busy, click: () => void controller.refresh() },
    { label: 'How to use PaperMode', enabled: !guide?.isOpen && !controller.session && !controller.busy, click: () => void guide.show() },
    { label: checkingUpdates ? 'Checking for updates…' : 'Check for Updates…', enabled: !quitting && !smokeTest && !guide?.isOpen && !controller.session && !controller.busy && !checkingUpdates,
      click: () => void checkUpdates() },
    { type: 'separator' },
    { label: 'Quit PaperMode', click: () => app.quit() }
  ]));
}

app.setName('PaperMode');
if (!app.requestSingleInstanceLock()) app.exit(smokeTest ? 1 : 0);
else {
  app.whenReady().then(async () => {
    app.dock?.setIcon?.(nativeImage.createFromPath(join(__dirname, '../../assets/PaperMode.png')));
    app.dock?.hide();
    const icon = nativeImage.createFromPath(join(__dirname, '../../assets/paperTemplate.png'));
    if (icon.isEmpty()) throw new Error('Menu bar icon could not be loaded');
    icon.setTemplateImage(true);
    tray = new Tray(icon);
    controller = new SessionController(helperPath(app), {
      createSession: path => new HelperSession(path, { mode: bounded ? 'bounded' : 'normal' })
    });
    guide = new UsageGuide(join(app.getPath('userData'), 'welcome.json'), {
      dialog: new GuideWindow({ BrowserWindow, ipcMain, screen }),
      canShow: () => !quitting && !controller.session && !controller.busy,
      needsPermission: () => controller.report?.accessibilityTrusted !== true,
      requestPermission: enableAccessibility,
      onVisibilityChange: render,
      onError: () => { if (!quitting) controller.update('error', 'help-unavailable'); }
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
    if (!bounded) await guide.show({ firstUse: true });
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
