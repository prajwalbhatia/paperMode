const path = require('node:path');
module.exports = {
  packagerConfig: {
    asar: true,
    icon: path.join(__dirname, 'assets/PaperMode.icns'),
    appBundleId: 'app.papermode.desktop',
    // Local QA identity: seal the renamed Electron bundles after packaging.
    // This is ad-hoc signing, not Developer ID signing or notarization.
    osxSign: {
      identity: '-', identityValidation: false,
      preAutoEntitlements: false, preEmbedProvisioningProfile: false,
      optionsForFile: () => ({ hardenedRuntime: false }),
      // Swift already emits a valid ad-hoc signature; preserve exact build bytes.
      ignore: file => file.endsWith('/papermode-helper')
    },
    appCategoryType: 'public.app-category.utilities',
    extendInfo: { LSUIElement: true, LSMinimumSystemVersion: '13.0' },
    extraResource: [path.join(__dirname, '.build/native/papermode-helper'), path.join(__dirname, 'assets/PaperMode.png')],
    ignore: [/^\/\.build($|\/)/, /^\/native($|\/)/, /^\/scripts($|\/)/, /^\/docs($|\/)/, /^\/out($|\/)/]
  }
};
