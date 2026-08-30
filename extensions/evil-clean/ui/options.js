const TYPES = [
  ['cookies', 'Cookies and site data', 'Session cookies and per-site storage'],
  ['cache', 'HTTP cache', 'Cached pages, scripts and images'],
  ['cacheStorage', 'Cache Storage', 'Caches held by service workers'],
  ['serviceWorkers', 'Service workers', 'Registered background workers'],
  ['localStorage', 'Local storage', 'localStorage and sessionStorage'],
  ['indexedDB', 'IndexedDB', 'Structured site databases'],
  ['webSQL', 'WebSQL', 'Legacy site databases'],
  ['fileSystems', 'File systems', 'Sandboxed site file systems'],
  ['history', 'Browsing history', 'Visited pages and typed URLs'],
  ['downloads', 'Download history', 'The list, not the files on disk'],
  ['formData', 'Form data', 'Autofill entries typed into forms'],
  ['passwords', 'Saved passwords', 'Off by default. This cannot be undone.']
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

const renderTypes = () => {
  const host = document.getElementById('types');
  host.textContent = '';
  TYPES.forEach(([key, title, description]) => {
    const row = document.createElement('div');
    row.className = 'row';
    const label = document.createElement('span');
    label.className = 'label';
    const b = document.createElement('b');
    b.textContent = title;
    const span = document.createElement('span');
    span.textContent = description;
    label.append(b, span);
    const toggle = document.createElement('label');
    toggle.className = 'switch';
    const input = document.createElement('input');
    input.type = 'checkbox';
    input.checked = Boolean(settings.types[key]);
    input.addEventListener('change', async () => {
      settings = await send({ type: 'setSettings', patch: { types: { [key]: input.checked } } });
    });
    toggle.append(input, document.createElement('i'));
    row.append(label, toggle);
    host.append(row);
  });
};

const renderKeep = () => {
  const host = document.getElementById('keep');
  host.textContent = '';
  const list = settings.keepOrigins || [];
  if (!list.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'No exceptions. A burn clears every site.';
    host.append(empty);
    return;
  }
  list.forEach((entry) => {
    const row = document.createElement('div');
    row.className = 'row';
    const label = document.createElement('span');
    label.className = 'label';
    const b = document.createElement('b');
    b.textContent = entry;
    label.append(b);
    const remove = document.createElement('button');
    remove.className = 'btn';
    remove.textContent = 'Remove';
    remove.addEventListener('click', async () => {
      settings = await send({ type: 'setSettings', patch: { keepOrigins: list.filter((x) => x !== entry) } });
      renderKeep();
    });
    row.append(label, remove);
    host.append(row);
  });
};

const renderTop = () => {
  document.getElementById('last').textContent = ago(settings.lastBurn);
  document.getElementById('cleanOnStartup').checked = settings.cleanOnStartup;
  document.getElementById('notify').checked = settings.notify;
  document.getElementById('intervalMinutes').value = String(settings.intervalMinutes);
};

const init = async () => {
  settings = await send({ type: 'getSettings' });
  renderTop();
  renderTypes();
  renderKeep();

  document.getElementById('burn').addEventListener('click', async (e) => {
    e.target.disabled = true;
    e.target.textContent = 'Burning';
    await send({ type: 'burn' });
    settings = await send({ type: 'getSettings' });
    renderTop();
    e.target.textContent = 'Burned';
    setTimeout(() => {
      e.target.disabled = false;
      e.target.textContent = 'Burn everything now';
    }, 1400);
  });

  document.getElementById('cleanOnStartup').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { cleanOnStartup: e.target.checked } });
  });
  document.getElementById('notify').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { notify: e.target.checked } });
  });
  document.getElementById('intervalMinutes').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { intervalMinutes: Number(e.target.value) } });
  });

  const add = async () => {
    const input = document.getElementById('keepInput');
    const value = input.value.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '');
    if (!value) return;
    const set = new Set(settings.keepOrigins || []);
    set.add(value);
    settings = await send({ type: 'setSettings', patch: { keepOrigins: [...set] } });
    input.value = '';
    renderKeep();
  };
  document.getElementById('addKeep').addEventListener('click', add);
  document.getElementById('keepInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') add();
  });

  document.getElementById('reset').addEventListener('click', async () => {
    settings = await send({ type: 'reset' });
    renderTop();
    renderTypes();
    renderKeep();
  });
};

init();
