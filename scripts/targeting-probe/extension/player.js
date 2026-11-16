// Serialized by scripting.executeScript; must not depend on module scope.
export async function playerProbe(operation, token) {
  const key = '__paperModeIsolatedTargetProbe_v1';
  let state = globalThis[key];
  if (!state || state.href !== location.href) {
    state = { href: location.href, documentToken: crypto.randomUUID(), players: new Map() };
    globalThis[key] = state;
  }
  const snapshot = video => ({
    paused: video.paused, ended: video.ended, time: video.currentTime,
    readyState: video.readyState, width: video.getBoundingClientRect().width,
    height: video.getBoundingClientRect().height,
    visibleDocument: document.visibilityState === 'visible'
  });
  if (operation === 'document') return { documentToken: state.documentToken };
  if (operation === 'scan') {
    state.players.clear();
    const videos = [...document.querySelectorAll('video')];
    return { origin: location.origin, candidates: videos.map((video, index) => {
      const id = crypto.randomUUID();
      state.players.set(id, { video, source: video.currentSrc });
      return { token: id, index, ...snapshot(video) };
    }) };
  }
  const entry = state.players.get(token);
  if (!entry || !entry.video.isConnected || entry.source !== entry.video.currentSrc) {
    return { ok: false, reason: 'target-lost-rebind-required' };
  }
  const video = entry.video;
  if (operation === 'status') return { ok: true, ...snapshot(video) };
  if (!['pause', 'play'].includes(operation)) return { ok: false, reason: 'invalid-operation' };
  try {
    if (operation === 'pause') video.pause();
    else await Promise.race([
      video.play(),
      new Promise((_, reject) => setTimeout(() => reject(new Error('play-timeout')), 3000))
    ]);
    // A resolved call is not sufficient: check the resulting element state.
    const expected = operation === 'pause';
    return { ok: video.paused === expected, operation, ...snapshot(video) };
  } catch (error) {
    return { ok: false, reason: error.name === 'NotAllowedError' ? 'play-denied' : 'play-failed-or-timed-out', ...snapshot(video) };
  }
}
