const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { webcrypto } = require('node:crypto');
const code = fs.readFileSync(`${__dirname}/extension/player.js`, 'utf8').replace('export async function', 'async function');
function fixture() {
  let calls = 0;
  const video = { paused: false, ended: false, currentTime: 12, readyState: 4,
    currentSrc: 'blob:original', isConnected: true,
    getBoundingClientRect: () => ({ width: 640, height: 360 }),
    pause() { calls++; this.paused = true; },
    async play() { calls++; this.paused = false; }
  };
  const context = vm.createContext({ crypto: webcrypto, setTimeout: callback => { /* timeout not used for resolved test promises */ },
    location: { href: 'https://www.youtube.com/watch?v=one', origin: 'https://www.youtube.com' },
    document: { querySelectorAll: () => [video], visibilityState: 'visible' }
  });
  vm.runInContext(code, context);
  return { probe: context.playerProbe, video, context, calls: () => calls };
}
test('only an explicitly bound token can pause/resume', async () => {
  const f = fixture();
  assert.equal((await f.probe('pause', 'unknown')).ok, false);
  assert.equal(f.calls(), 0);
  const { candidates } = await f.probe('scan');
  assert.equal((await f.probe('pause', candidates[0].token)).paused, true);
  assert.equal((await f.probe('play', candidates[0].token)).paused, false);
});
for (const change of ['navigate', 'replace-source', 'detach']) {
  test(`refuses stale binding after ${change}`, async () => {
    const f = fixture();
    const { candidates } = await f.probe('scan');
    if (change === 'navigate') f.context.location.href += '&new-document';
    if (change === 'replace-source') f.video.currentSrc = 'blob:replacement';
    if (change === 'detach') f.video.isConnected = false;
    assert.equal((await f.probe('pause', candidates[0].token)).ok, false);
    assert.equal(f.calls(), 0);
  });
}
test('rejected resume reports failure instead of claiming playback', async () => {
  const f = fixture();
  f.video.paused = true;
  f.video.play = async () => { const e = new Error(); e.name = 'NotAllowedError'; throw e; };
  const { candidates } = await f.probe('scan');
  const result = await f.probe('play', candidates[0].token);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'play-denied');
  assert.equal(result.paused, true);
});
