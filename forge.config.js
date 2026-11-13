const path = require('node:path');
module.exports = {
  packagerConfig: {
    asar: true,
    appBundleId: 'app.papermode.desktop',
    appCategoryType: 'public.app-category.utilities',
    extendInfo: { LSUIElement: true, LSMinimumSystemVersion: '13.0' },
    extraResource: [path.join(__dirname, '.build/native/papermode-helper')],
    ignore: [/^\/\.build($|\/)/, /^\/native($|\/)/, /^\/scripts($|\/)/, /^\/docs($|\/)/, /^\/out($|\/)/]
  }
};
