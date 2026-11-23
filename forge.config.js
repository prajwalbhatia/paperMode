const path = require('node:path');
const { osxSignConfig } = require('./scripts/signing-config');
module.exports = {
  packagerConfig: {
    ...(process.env.PAPERMODE_ELECTRON_ZIP_DIR ? { electronZipDir: process.env.PAPERMODE_ELECTRON_ZIP_DIR } : {}),
    asar: true,
    icon: path.join(__dirname, 'assets/PaperMode.icns'),
    appBundleId: 'app.papermode.desktop',
    osxSign: osxSignConfig(),
    appCategoryType: 'public.app-category.utilities',
    extendInfo: { LSUIElement: true, LSMinimumSystemVersion: '13.0' },
    extraResource: [path.join(__dirname, '.build/native/papermode-helper'), path.join(__dirname, 'assets/PaperMode.png')],
    ignore: [/^\/\.build($|\/)/, /^\/native($|\/)/, /^\/scripts($|\/)/, /^\/docs($|\/)/, /^\/out($|\/)/]
  }
};
