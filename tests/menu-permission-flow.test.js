const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { readFileSync, mkdtempSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const vm = require('node:vm');
const { SessionController } = require('../src/main/controller');
const { UsageGuide } = require('../src/main/guide');

test('menu denial, Not now, explicit permission recovery and start under persistent shortcut conflict', async t => {
  const profile = mkdtempSync(join(tmpdir(), 'papermode-menu-'));
  t.after(() => rmSync(profile, {recursive: true, force: true}));
  let trusted = false, checkFails = false, menu, shortcut, choice = 1, guideOptions;
  let requests = 0, sessions = 0, settingsOpened = 0;
  const flush = () => new Promise(resolve => setImmediate(resolve));
  class Controller extends SessionController {
    constructor(path) {
      super(path, {
        inspect: async () => {
          if (checkFails) throw new Error('diagnostic failed');
          return { accessibilityTrusted: trusted, unlockLayoutSupported: true };
        },
        askPermission: async () => { requests++; trusted = true; },
        createSession: () => {
          sessions++;
          const session = new EventEmitter();
          session.start = () => session.emit('event', {event: 'locked'});
          return session;
        }
      });
    }
  }
  const app = Object.assign(new EventEmitter(), {
    getPath: () => profile, setName() {}, requestSingleInstanceLock: () => true,
    whenReady: () => Promise.resolve(), dock: {hide() {}}
  });
  class Tray {
    isDestroyed() { return false; } setToolTip() {} setTitle() {}
    setContextMenu(items) { menu = items; }
  }
  const electron = {app, Tray, Menu: {buildFromTemplate: x => x},
    nativeImage: {createFromPath: () => ({isEmpty: () => false, setTemplateImage() {}})},
    globalShortcut: {register: (_chord, callback) => { shortcut = callback; return false; }},
    shell: {openExternal: async url => { assert.match(url, /^x-apple\.systempreferences:/); settingsOpened++; }},
    powerMonitor: new EventEmitter()};
  vm.runInNewContext(readFileSync(join(__dirname, '../src/main/index.js'), 'utf8'), {
    require: id => ({electron, 'node:path': require('node:path'), '../../package.json': require('../package.json'),
      './updates': { checkForUpdates: async () => null },
      './automatic-updates': { AutomaticUpdateAlerts: class { start() {} stop() {} onStateChange() {} recordManualResult() {} } },
      './helper': {helperPath: () => 'unused'},
      './controller': {SessionController: Controller}, './session': {}, './guide': {UsageGuide},
      './guide-window': {GuideWindow: class {async showMessageBox(options) {guideOptions = options; return {response: choice};}}}
    })[id],
    __dirname, process: {argv: ['--bounded-locks']}, console,
    setInterval() {}, clearInterval() {}, setTimeout, clearTimeout
  });
  await flush();
  const item = label => menu.find(x => x.label === label);
  assert.ok(item('PaperMode — Permission required'));
  assert.equal(item('Start PaperMode').enabled, false);
  shortcut(); await flush();
  assert.equal(sessions, 0);
  item('How to use PaperMode').click(); await flush();
  assert.deepEqual(guideOptions.buttons, ['Enable Accessibility…', 'Not now']);
  assert.match(guideOptions.detail, /If PaperMode is already enabled/);
  assert.equal(requests, 0); assert.equal(settingsOpened, 0); assert.equal(sessions, 0);
  choice = 0;
  item('How to use PaperMode').click(); await flush();
  assert.equal(requests, 1); assert.equal(settingsOpened, 1);
  assert.ok(item('PaperMode — Ready'));
  assert.ok(item('Retry start shortcut')); // Registration has never succeeded.
  assert.equal(item('Start PaperMode').enabled, true);
  checkFails = true;
  await item('Check permission and layout').click(); await flush();
  assert.ok(item('PaperMode — Needs attention'));
  assert.equal(item('Start PaperMode').enabled, false);
  choice = 1;
  item('How to use PaperMode').click(); await flush();
  assert.deepEqual(guideOptions.buttons, ['Enable Accessibility…', 'Not now']);
  assert.equal(requests, 1, 'opening recovery guidance must not request permission');
  checkFails = false;
  await item('Check permission and layout').click(); await flush();
  assert.ok(item('PaperMode — Ready'));
  item('Start PaperMode').click(); await flush();
  assert.equal(sessions, 1);
  assert.ok(item('PaperMode — Locked'));
});
