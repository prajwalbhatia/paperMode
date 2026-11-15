const { join } = require('node:path');

// A local, sandboxed guide window supports inline feedback while it is open.
class GuideWindow {
  constructor({ BrowserWindow, ipcMain, screen }) {
    Object.assign(this, { BrowserWindow, ipcMain, screen });
    this.window = null;
    this.blocked = false;
  }
  notifyStartBlocked() {
    this.blocked = true;
    if (this.window && !this.window.isDestroyed()) {
      this.window.webContents.send('papermode:guide-blocked');
      this.window.show();
      this.window.focus();
    }
  }
  showMessageBox(options) {
    this.blocked = false;
    return new Promise((resolve, reject) => {
      const window = new this.BrowserWindow({
        title: 'PaperMode', width: 540,
        height: Math.min(740, this.screen.getPrimaryDisplay().workAreaSize.height - 40),
        minWidth: 420, minHeight: 420, show: false, minimizable: false,
        fullscreenable: false, autoHideMenuBar: true, backgroundColor: '#191d23',
        webPreferences: { preload: join(__dirname, '../guide/preload.js'),
          contextIsolation: true, nodeIntegration: false, sandbox: true }
      });
      this.window = window;
      let response = options.cancelId;
      let failure;
      const initialize = event => {
        if (event.sender === window.webContents) event.reply('papermode:guide-content', {
          message: options.message, detail: options.detail, buttons: options.buttons, blocked: this.blocked
        });
      };
      const choose = (event, choice) => {
        if (event.sender !== window.webContents || !Number.isInteger(choice) || choice < 0 || choice >= options.buttons.length) return;
        response = choice;
        window.close();
      };
      this.ipcMain.on('papermode:guide-ready', initialize);
      this.ipcMain.on('papermode:guide-choice', choose);
      window.webContents.on('before-input-event', (event, input) => {
        if (input.type === 'keyDown' && input.control && input.alt && input.meta && input.key.toLowerCase() === 'p') {
          event.preventDefault();
          this.notifyStartBlocked();
        }
      });
      window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
      window.webContents.on('will-navigate', event => event.preventDefault());
      const fail = () => { failure = new Error('Guide unavailable'); window.destroy(); };
      window.webContents.on('render-process-gone', fail);
      window.once('closed', () => {
        this.ipcMain.removeListener('papermode:guide-ready', initialize);
        this.ipcMain.removeListener('papermode:guide-choice', choose);
        this.window = null;
        if (failure) reject(failure); else resolve({ response });
      });
      window.once('ready-to-show', () => { window.show(); window.focus(); });
      window.loadFile(join(__dirname, '../guide/index.html')).catch(fail);
    });
  }
}
module.exports = { GuideWindow };
