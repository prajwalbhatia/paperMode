const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

test('menu can start during a persistent shortcut conflict; retries recover without extra starts', async () => {
  for (const automatic of [false, true]) {
    let available = false, callback, menu, refresh, starts = 0, registrations = 0, controller, guide, notices = 0;
    class Controller extends EventEmitter {
      constructor() { super(); controller = this; }
      snapshot = { state: 'ready' };
      async refresh() {}
      start() { starts++; }
    }
    class Tray {
      isDestroyed() { return false; }
      setToolTip() {}
      setTitle() {}
      setContextMenu(value) { menu = value; }
    }
    const app = Object.assign(new EventEmitter(), {
      getPath: () => '/unused-test-profile', setName() {}, requestSingleInstanceLock: () => true,
      whenReady: () => Promise.resolve(), dock: { hide() {} }
    });
    const electron = { app, Tray, Menu: { buildFromTemplate: x => x },
      nativeImage: { createFromPath: () => ({ isEmpty: () => false, setTemplateImage() {} }) },
      globalShortcut: { register: (_key, handler) => { registrations++; if (available) callback = handler; return available; } },
      powerMonitor: new EventEmitter() };
    vm.runInNewContext(readFileSync(join(__dirname, '../src/main/index.js'), 'utf8'), {
      require: id => ({ electron, 'node:path': require('node:path'), '../../package.json': require('../package.json'),
        './updates': { checkForUpdates: async () => null }, './helper': { helperPath: () => 'helper' },
        './guide': { UsageGuide: class { constructor() { guide = this; } async show() {} notifyStartBlocked() { notices++; } } },
        './guide-window': { GuideWindow: class {} },
        './controller': { SessionController: Controller }, './session': { HelperSession: class {} } })[id],
      __dirname, process: { argv: [] }, console,
      setInterval: fn => { refresh = fn; }, clearInterval() {}, setTimeout, clearTimeout
    });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(registrations, 1);
    assert.ok(menu.some(x => x.label === 'Retry start shortcut'));
    // Keep registration unavailable: the menu must still offer an independent start.
    const start = menu.find(x => x.label === 'Start PaperMode');
    assert.equal(start.enabled, true);
    start.click();
    assert.equal(starts, 1);
    assert.equal(available, false);
    assert.equal(callback, undefined);
    controller.busy = true;
    controller.emit('change');
    assert.equal(menu.find(x => x.label === 'Start PaperMode').enabled, false);
    controller.busy = false;
    controller.session = {};
    controller.emit('change');
    assert.equal(menu.find(x => x.label === 'Start PaperMode').enabled, false);
    controller.session = null;
    controller.emit('change');
    available = true;
    if (automatic) refresh();
    else menu.find(x => x.label === 'Retry start shortcut').click();
    assert.equal(registrations, 2);
    assert.equal(starts, 1);
    assert.ok(!menu.some(x => x.label === 'Retry start shortcut'));
    assert.ok(menu.some(x => x.label === 'Start: ⌃⌥⌘P'));
    callback();
    assert.equal(starts, 2);
    guide.isOpen = true;
    controller.emit('change');
    assert.equal(menu.find(x => x.label === 'Start PaperMode').enabled, false);
    callback();
    menu.find(x => x.label === 'Start PaperMode').click();
    assert.equal(starts, 2);
    assert.equal(notices, 2);
    guide.isOpen = false;
    refresh();
    assert.equal(registrations, 2);
  }
});
