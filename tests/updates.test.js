const test = require('node:test');
const assert = require('node:assert/strict');
const { checkForUpdates, compareTags, newestRelease } = require('../src/main/updates');
const { version, paperModeReleaseTag } = require('../package.json');

test('installed release tag matches the packaged app version', () => {
  assert.match(paperModeReleaseTag, new RegExp(`^v${version.replaceAll('.', '\\.')}(?:-preview\\.\\d+)?$`));
});

test('release order handles preview and stable versions', () => {
  assert.equal(compareTags('v0.1.0-preview.2', 'v0.1.0-preview.1'), 1);
  assert.equal(compareTags('v0.1.0', 'v0.1.0-preview.9'), 1);
  assert.equal(compareTags('v0.2.0-preview.1', 'v0.1.9'), 1);
  assert.equal(compareTags('v0.1.0-preview.1', 'v0.1.0-preview.1'), 0);
});

test('check selects the newest published release and constructs a trusted URL', async () => {
  const request = async (url, options) => {
    assert.match(url, /^https:\/\/api\.github\.com\/repos\/prajwalbhatia\/paperMode\/releases\?/);
    assert.equal(options.headers['User-Agent'], 'PaperMode');
    return { ok: true, json: async () => [
      { tag_name: 'v0.2.0-preview.1', draft: true },
      { tag_name: 'other-tag', draft: false },
      { tag_name: 'v0.1.0-preview.2', draft: false, body: 'Preview notes' },
      { tag_name: 'v0.1.0', draft: false, body: 'Stable notes' }
    ] };
  };
  assert.deepEqual(await checkForUpdates({ request }), {
    tag: 'v0.1.0', notes: 'Stable notes',
    url: 'https://github.com/prajwalbhatia/paperMode/releases/tag/v0.1.0'
  });
});

test('current preview reports no newer release and invalid responses fail', async () => {
  assert.equal(newestRelease([{ tag_name: 'v0.1.0-preview.1' }]), null);
  await assert.rejects(checkForUpdates({ request: async () => ({ ok: false }) }), /GitHub release check failed/);
  await assert.rejects(checkForUpdates({ request: async () => ({ ok: true, json: async () => ({}) }) }), /Invalid release information/);
});
