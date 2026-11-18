const path = require('node:path');

const root = path.join(__dirname, '..');
const helperEntitlements = path.join(root, 'entitlements', 'papermode-helper.plist');
const electronMainEntitlements = path.join(root, 'entitlements', 'electron-main.plist');
const electronLocalEntitlements = path.join(root, 'entitlements', 'electron-local.plist');
const electronRendererEntitlements = path.join(root, 'entitlements', 'electron-renderer.plist');
const electronPluginEntitlements = path.join(root, 'entitlements', 'electron-plugin.plist');

function releaseSigningMode(env = process.env) {
  const mode = env.PAPERMODE_SIGNING_MODE || 'adhoc-preview';
  if (!['adhoc-preview', 'hardened-local', 'developer-id'].includes(mode)) {
    throw new Error('PAPERMODE_SIGNING_MODE must be "adhoc-preview", "hardened-local", or "developer-id".');
  }
  return mode;
}

function developerIdIdentity(env = process.env) {
  const identity = env.PAPERMODE_DEVELOPER_ID_IDENTITY;
  if (!identity) {
    throw new Error('Developer ID packaging requires PAPERMODE_DEVELOPER_ID_IDENTITY, for example "Developer ID Application: Your Name (TEAMID)".');
  }
  if (!/^Developer ID Application: [^\r\n()]+ \([A-Z0-9]{10}\)$/.test(identity)) {
    throw new Error('PAPERMODE_DEVELOPER_ID_IDENTITY must be a full Developer ID Application certificate name with a 10-character Team ID.');
  }
  return identity;
}

function osxSignConfig(env = process.env) {
  const mode = releaseSigningMode(env);
  if (mode === 'adhoc-preview') {
    return {
      // Local QA identity: seal the renamed Electron bundles after packaging.
      // This is ad-hoc signing, not Developer ID signing or notarization.
      identity: '-',
      identityValidation: false,
      preAutoEntitlements: false,
      preEmbedProvisioningProfile: false,
      optionsForFile: () => ({ hardenedRuntime: false }),
      // The Swift build emits a valid ad-hoc signature; preserve exact preview bytes.
      ignore: file => file.endsWith('/papermode-helper')
    };
  }

  if (mode === 'hardened-local') {
    return hardenedSignConfig('-', false, true);
  }

  const identity = developerIdIdentity(env);
  return hardenedSignConfig(identity, true);
}

function hardenedSignConfig(identity, identityValidation, local = false) {
  return {
    identity,
    identityValidation,
    // Direct-download apps do not need a provisioning profile. Avoid generating
    // profile-only entitlement values in this reproducible distribution build.
    preAutoEntitlements: false,
    preEmbedProvisioningProfile: false,
    optionsForFile: file => {
      // The helper has no JIT or Electron runtime needs. Give it no exceptions,
      // but retain Hardened Runtime, which notarization requires for every target.
      if (file.endsWith('/papermode-helper')) {
        // `codesign` otherwise derives an identifier from this resource path.
        // Keep the helper's stable identity so TCC and package verification see
        // the same nested executable across signed releases.
        return {
          entitlements: helperEntitlements,
          hardenedRuntime: true,
          additionalArguments: ['--identifier', 'papermode-helper']
        };
      }
      // Keep Electron's own documented JIT/runtime exceptions, but do not carry
      // unrelated camera, microphone, location, USB, Bluetooth or Photos access.
      if (file.includes('(Plugin).app')) {
        return { entitlements: electronPluginEntitlements, hardenedRuntime: true };
      }
      if (file.includes('(Renderer).app') || file.includes('(GPU).app')) {
        return { entitlements: electronRendererEntitlements, hardenedRuntime: true };
      }
      if (file.endsWith('/PaperMode.app')) {
        return { entitlements: local ? electronLocalEntitlements : electronMainEntitlements, hardenedRuntime: true };
      }
      if (file.endsWith(' Helper.app')) {
        return { entitlements: electronRendererEntitlements, hardenedRuntime: true };
      }
      return { entitlements: helperEntitlements, hardenedRuntime: true };
    }
  };
}

module.exports = { developerIdIdentity, osxSignConfig, releaseSigningMode };
