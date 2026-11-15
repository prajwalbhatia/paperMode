const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

test('shortcut conflict can recover through menu retry or automatic retry without starting a session', async () => {
  for (const automatic of [false, true]) {
    let available = false, callback, menu, refresh, starts = 0, registrations = 0;
    class Controller extends EventEmitter {
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
      setName() {}, requestSingleInstanceLock: () => true,
      whenReady: () => Promise.resolve(), dock: { hide() {} }
    });
    const electron = { app, Tray, Menu: { buildFromTemplate: x => x },
      nativeImage: { createFromPath: () => ({ isEmpty: () => false, setTemplateImage() {} }) },
      globalShortcut: { register: (_key, handler) => { registrations++; if (available) callback = handler; return available; } },
      powerMonitor: new EventEmitter() };
    vm.runInNewContext(readFileSync(join(__dirname, '../src/main/index.js'), 'utf8'), {
      require: id => ({ electron, 'node:path': require('node:path'), './helper': { helperPath: () => 'helper' },
        './controller': { SessionController: Controller }, './session': { HelperSession: class {} } })[id],
      __dirname, process: { argv: [] }, console,
      setInterval: fn => { refresh = fn; }, clearInterval() {}, setTimeout, clearTimeout
    });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(registrations, 1);
    assert.ok(menu.some(x => x.label === 'Retry start shortcut'));
    available = true;
    if (automatic) refresh();
    else menu.find(x => x.label === 'Retry start shortcut').click();
    assert.equal(registrations, 2);
    assert.equal(starts, 0);
    assert.ok(!menu.some(x => x.label === 'Retry start shortcut'));
    assert.ok(menu.some(x => x.label === 'Start: ⌃⌥⌘P'));
    callback();
    assert.equal(starts, 1);
    refresh();
    assert.equal(registrations, 2);
  }
});
