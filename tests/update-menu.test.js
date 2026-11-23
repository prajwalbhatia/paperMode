const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

test('manual update check shows notes, opens the selected release, and never starts a lock', async () => {
  let menu, resolveCheck, starts = 0, opened, options, controller, alerts;
  const app = Object.assign(new EventEmitter(), {
    getPath: () => '/unused-test-profile', setName() {}, requestSingleInstanceLock: () => true,
    whenReady: () => Promise.resolve(), dock: { hide() {} }
  });
  class Controller extends EventEmitter {
    constructor() { super(); controller = this; }
    snapshot = { state: 'ready' };
    async refresh() {}
    start() { starts++; }
  }
  class Tray {
    isDestroyed() { return false; } setToolTip() {} setTitle() {}
    setContextMenu(value) { menu = value; }
  }
  const electron = {
    app, Tray, Menu: { buildFromTemplate: value => value },
    nativeImage: { createFromPath: () => ({ isEmpty: () => false, setTemplateImage() {} }) },
    globalShortcut: { register: () => true }, powerMonitor: new EventEmitter(),
    shell: { openExternal: async url => { opened = url; } },
    dialog: { showMessageBox: async value => { options = value; return { response: 0 }; } }
  };
  vm.runInNewContext(readFileSync(join(__dirname, '../src/main/index.js'), 'utf8'), {
    require: id => ({ electron, 'node:path': require('node:path'), '../../package.json': require('../package.json'),
      './helper': { helperPath: () => 'helper' }, './controller': { SessionController: Controller },
      './session': {}, './guide': { UsageGuide: class { async show() {} } },
      './guide-window': { GuideWindow: class {} },
      './automatic-updates': { AutomaticUpdateAlerts: class {
        constructor(_path, settings) { alerts = this; this.settings = settings; }
        start() { this.started = true; }
        stop() {} onStateChange() {} recordManualResult() {}
      } },
      './updates': { checkForUpdates: () => new Promise(resolve => { resolveCheck = resolve; }) }
    })[id],
    __dirname, process: { argv: [] }, console,
    setInterval() {}, clearInterval() {}, setTimeout, clearTimeout
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(alerts.started, true);
  controller.session = {};
  assert.equal(alerts.settings.canNotify(), false, 'automatic alerts must not interrupt a lock');
  controller.session = null;
  menu.find(item => item.label === 'Check for Updates…').click();
  assert.ok(menu.some(item => item.label === 'Checking for updates…'));
  assert.equal(menu.find(item => item.label === 'Start PaperMode').enabled, false);
  resolveCheck({ tag: 'v0.1.3-preview.1', notes: 'Future preview notes',
    url: 'https://github.com/prajwalbhatia/paperMode/releases/tag/v0.1.3-preview.1' });
  await new Promise(resolve => setImmediate(resolve));
  assert.match(options.detail, /Future preview notes/);
  assert.equal(opened, 'https://github.com/prajwalbhatia/paperMode/releases/tag/v0.1.3-preview.1');
  assert.equal(starts, 0);
  assert.equal(menu.find(item => item.label === 'Start PaperMode').enabled, true);
  menu.find(item => item.label === 'Check for Updates…').click();
  resolveCheck(null);
  await new Promise(resolve => setImmediate(resolve));
  assert.ok(options.detail.includes(`Current release: ${require('../package.json').paperModeReleaseTag}`));
});
