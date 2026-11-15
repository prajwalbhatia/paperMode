const test = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { GuideWindow } = require('../src/main/guide-window');
function setup() {
  let window;
  const ipcMain = new EventEmitter();
  class Window extends EventEmitter {
    constructor(options) {
      super(); window = this; this.options = options;
      this.webContents = Object.assign(new EventEmitter(), {
        setWindowOpenHandler() {}, send: (...args) => { this.sent = args; }
      });
    }
    loadFile() { return Promise.resolve(); }
    show() {} focus() {}
    isDestroyed() { return Boolean(this.destroyed); }
    close() { this.destroy(); }
    destroy() { this.destroyed = true; this.emit('closed'); }
  }
  const guide = new GuideWindow({ BrowserWindow: Window, ipcMain,
    screen: { getPrimaryDisplay: () => ({workAreaSize: {height: 800}}) } });
  return { guide, ipcMain, window: () => window };
}
test('blocked shortcut updates the open guide without closing or choosing permission', async () => {
  const { guide, ipcMain, window } = setup();
  const result = guide.showMessageBox({ message: 'Guide', detail: 'Help', buttons: ['Enable', 'Not now'], cancelId: 1 });
  let prevented = false;
  window().webContents.emit('before-input-event', {preventDefault: () => { prevented = true; }},
    {type: 'keyDown', control: true, alt: true, meta: true, key: 'p'});
  assert.equal(prevented, true);
  guide.notifyStartBlocked();
  assert.deepEqual(window().sent, ['papermode:guide-blocked']);
  assert.equal(window().isDestroyed(), false);
  let content;
  ipcMain.emit('papermode:guide-ready', { sender: window().webContents, reply: (_channel, data) => { content = data; } });
  assert.equal(content.blocked, true); // Preserved if attempted before the page was ready.
  ipcMain.emit('papermode:guide-choice', {sender: {}}, 0);
  assert.equal(window().isDestroyed(), false);
  ipcMain.emit('papermode:guide-choice', {sender: window().webContents}, 99);
  assert.equal(window().isDestroyed(), false);
  ipcMain.emit('papermode:guide-choice', {sender: window().webContents}, 1);
  assert.deepEqual(await result, {response: 1});
  assert.equal(ipcMain.listenerCount('papermode:guide-choice'), 0);
  assert.equal(ipcMain.listenerCount('papermode:guide-ready'), 0);
});
test('window close cancels and renderer failure rejects', async () => {
  const { guide, window } = setup();
  const options = {buttons: ['Enable', 'Not now'], cancelId: 1};
  let result = guide.showMessageBox(options);
  window().close();
  assert.deepEqual(await result, {response: 1});
  result = guide.showMessageBox(options);
  window().webContents.emit('render-process-gone');
  await assert.rejects(result, /Guide unavailable/);
});
