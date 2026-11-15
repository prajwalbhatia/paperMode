const { ipcRenderer } = require('electron');
let pendingBlocked = false;
function showBlocked() {
  pendingBlocked = true;
  const hint = document.getElementById('start-hint');
  if (!hint) return;
  hint.classList.add('blocked');
  hint.textContent = 'Close this guide to start PaperMode. Then press Control + Option + Command + P again.';
}
ipcRenderer.on('papermode:guide-blocked', showBlocked);
window.addEventListener('DOMContentLoaded', () => {
  ipcRenderer.on('papermode:guide-content', (_event, data) => {
    document.getElementById('title').textContent = data.message;
    const content = document.getElementById('instructions');
    content.replaceChildren();
    for (const paragraph of data.detail.split('\n\n')) {
      const section = document.createElement('section');
      const lines = paragraph.split('\n');
      if (lines.length > 1) {
        const heading = document.createElement('h2');
        heading.textContent = lines.shift(); section.append(heading);
      }
      const text = document.createElement('p');
      text.textContent = lines.join('\n'); section.append(text); content.append(section);
    }
    const actions = document.getElementById('actions');
    actions.replaceChildren();
    data.buttons.forEach((label, index) => {
      const button = document.createElement('button');
      button.textContent = label;
      if (index === 0) button.className = 'primary';
      button.addEventListener('click', () => ipcRenderer.send('papermode:guide-choice', index));
      actions.append(button);
    });
    if (pendingBlocked || data.blocked) showBlocked();
  });
  ipcRenderer.send('papermode:guide-ready');
});
