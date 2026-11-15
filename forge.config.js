const path = require('node:path');
module.exports = {
  packagerConfig: {
    asar: true,
    icon: path.join(__dirname, 'assets/PaperMode.icns'),
    appBundleId: 'app.papermode.desktop',
    appCategoryType: 'public.app-category.utilities',
    extendInfo: { LSUIElement: true, LSMinimumSystemVersion: '13.0' },
    extraResource: [path.join(__dirname, '.build/native/papermode-helper'), path.join(__dirname, 'assets/PaperMode.png')],
    ignore: [/^\/\.build($|\/)/, /^\/native($|\/)/, /^\/scripts($|\/)/, /^\/docs($|\/)/, /^\/out($|\/)/]
  }
};
