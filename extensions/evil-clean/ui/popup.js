const QUICK = [
  ['cookies', 'Cookies and site data'],
  ['cache', 'Cache'],
  ['history', 'History'],
  ['formData', 'Form data']
];

const send = (message) => chrome.runtime.sendMessage(message);
let settings = null;

const ago = (timestamp) => {
  if (!timestamp) return 'never';
  const seconds = Math.round((Date.now() - timestamp) / 1000);
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.round(seconds / 60)}m ago`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)}h ago`;
  return `${Math.round(seconds / 86400)}d ago`;
};

const render = () => {
  document.getElementById('last').textContent = ago(settings.lastBurn);
  document.getElementById('keep').textContent = `${(settings.keepOrigins || []).length} kept`;
  const host = document.getElementById('types');
  host.textContent = '';
  QUICK.forEach(([key, title]) => {
    const row = document.createElement('div');
    row.className = 'row';
    const label = document.createElement('span');
    label.className = 'label';
    const b = document.createElement('b');
    b.textContent = title;
    label.append(b);
    const toggle = document.createElement('label');
    toggle.className = 'switch';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = Boolean(settings.types[key]);
    input.addEventListener('change', async () => {
      settings = await send({ type: 'setSettings', patch: { types: { [key]: input.checked } } });
      render();
    });
    toggle.append(input, document.createElement('i'));
    row.append(label, toggle);
    host.append(row);
  });
};

const init = async () => {
  settings = await send({ type: 'getSettings' });
  render();
  document.getElementById('burn').addEventListener('click', async (e) => {
    e.target.disabled = true;
    e.target.textContent = 'Burning';
    await send({ type: 'burn' });
    settings = await send({ type: 'getSettings' });
    e.target.textContent = 'Burned';
    render();
    setTimeout(() => {
      e.target.disabled = false;
      e.target.textContent = 'Burn everything';
    }, 1400);
  });
  document.getElementById('options').addEventListener('click', () => chrome.runtime.openOptionsPage());
};

init();
