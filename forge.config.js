const path = require('node:path');
const { osxSignConfig } = require('./scripts/signing-config');
module.exports = {
  packagerConfig: {
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
