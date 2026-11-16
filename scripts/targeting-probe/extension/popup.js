import { playerProbe } from './player.js';
const api = globalThis.browser ?? chrome;
const result = document.querySelector('#result');
const label = document.querySelector('#target');
const display = value => { result.textContent = JSON.stringify(value, null, 2); };
const invoke = (tabId, frameIds, operation, token) => api.scripting.executeScript({
  target: { tabId, frameIds }, func: playerProbe, args: [operation, token ?? null]
});
async function target() {
  const { binding } = await api.storage.local.get('binding');
  label.textContent = binding ? `Bound: tab ${binding.tabId}, frame ${binding.frameId}, video ${binding.index + 1} (${binding.origin})` : 'No target selected';
  return binding;
}
async function command(operation) {
  const binding = await target();
  if (!binding) throw new Error('Bind a video first.');
  if (Date.now() - binding.createdAt > 30 * 60 * 1000) throw new Error('Binding expired; inspect and bind again.');
  const [top] = await invoke(binding.tabId, [0], 'document');
  if (top?.result?.documentToken !== binding.topDocumentToken) throw new Error('Page changed; bind again. No playback command sent.');
  const [reply] = await invoke(binding.tabId, [binding.frameId], operation, binding.token);
  display(reply?.result ?? { ok: false, reason: 'no-frame-response' });
}
document.querySelector('#scan').onclick = async () => {
  try {
    const [tab] = await api.tabs.query({ active: true, currentWindow: true });
    const [top] = await invoke(tab.id, [0], 'document');
    const frames = await api.scripting.executeScript({ target: { tabId: tab.id, allFrames: true }, func: playerProbe, args: ['scan', null] });
    const container = document.querySelector('#candidates');
    container.replaceChildren();
    let count = 0;
    for (const frame of frames) {
      for (const candidate of frame.result?.candidates ?? []) {
        count++;
        const button = document.createElement('button');
        button.textContent = `Bind ${frame.result.origin}, video ${candidate.index + 1} (${candidate.paused ? 'paused' : 'playing'}, ${Math.round(candidate.width)}×${Math.round(candidate.height)})`;
        button.onclick = async () => {
          await api.storage.local.set({ binding: {
            tabId: tab.id, frameId: frame.frameId, token: candidate.token,
            origin: frame.result.origin, index: candidate.index,
            topDocumentToken: top.result.documentToken, createdAt: Date.now()
          } });
          await target();
          display({ bound: true, note: 'No playback action performed.' });
        };
        container.append(button);
      }
    }
    display({ candidates: count, note: count ? 'Select the intended video explicitly.' : 'No accessible video; do not fall back to a media key.' });
  } catch {
    display({ ok: false, reason: 'inspection-failed-check-site-access' });
  }
};
for (const operation of ['status', 'pause', 'play']) {
  document.querySelector(`#${operation}`).onclick = () => command(operation).catch(error => display({ ok: false, reason: error.message }));
}
document.querySelector('#clear').onclick = async () => {
  await api.storage.local.remove('binding');
  await target();
  display({ cleared: true });
};
target().catch(() => display({ ok: false, reason: 'storage-unavailable' }));
