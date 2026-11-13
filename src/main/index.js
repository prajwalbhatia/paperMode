const { app, Tray, Menu, nativeImage, dialog } = require('electron');
const { join } = require('node:path');
const { helperPath, diagnose } = require('./helper');
let tray;
const smokeTest = process.argv.includes('--smoke-test');
app.setName('PaperMode');
if (!app.requestSingleInstanceLock()) app.exit(smokeTest ? 1 : 0);
else {
  app.whenReady().then(async () => {
    app.dock?.hide();
    const icon = nativeImage.createFromPath(join(__dirname, '../../assets/paperTemplate.png'));
    if (icon.isEmpty()) throw new Error('Menu bar icon could not be loaded');
    icon.setTemplateImage(true);
    tray = new Tray(icon);
    tray.setToolTip('PaperMode');
    tray.setContextMenu(Menu.buildFromTemplate([
      { label: 'PaperMode — development', enabled: false },
      { label: 'Input lock arrives in milestone 2', enabled: false },
      { type: 'separator' },
      { label: 'Check native helper', click: async () => {
        try {
          const report = await diagnose(helperPath(app));
          await dialog.showMessageBox({ message: 'Native helper is ready', detail: report.osVersion });
        } catch (error) { dialog.showErrorBox('Helper check failed', error.message); }
      } },
      { type: 'separator' },
      { label: 'Quit PaperMode', click: () => app.quit() }
    ]));
    if (smokeTest) {
      const report = await diagnose(helperPath(app));
      console.log(JSON.stringify({ menuBarCreated: !tray.isDestroyed(), native: report }));
      app.quit();
    }
  }).catch(error => { console.error(error); app.exit(1); });
  app.on('window-all-closed', () => {});
  app.on('before-quit', () => tray?.destroy());
}
