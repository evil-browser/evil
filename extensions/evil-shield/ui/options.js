const FEATURES = [
  ['platform', 'Platform identity', 'User agent, navigator.platform, client hints'],
  ['hardware', 'Hardware', 'CPU cores, device memory, touch points'],
  ['locale', 'Locale and time zone', 'Languages and reported time zone'],
  ['screen', 'Screen metrics', 'Resolution rounded to common values'],
  ['canvas', 'Canvas', 'Per-site noise on readback'],
  ['webgl', 'WebGL', 'Generic vendor and renderer strings'],
  ['audio', 'Audio', 'Sub-audible jitter on the audio pipeline'],
  ['webrtc', 'WebRTC', 'Hide local network addresses from scripts'],
  ['devices', 'Device APIs', 'Deny battery, USB, serial, HID and Bluetooth'],
  ['plugins', 'Plugins', 'Report an empty plugin list']
];

const send = (message) => chrome.runtime.sendMessage(message);
let settings = null;

const renderFeatures = () => {
  const host = document.getElementById('features');
  host.textContent = '';
  FEATURES.forEach(([key, title, description]) => {
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
    input.checked = Boolean(settings.features[key]);
    input.disabled = !settings.enabled;
    input.addEventListener('change', async () => {
      settings = await send({ type: 'setSettings', patch: { features: { [key]: input.checked } } });
    });
    const knob = document.createElement('i');
    toggle.append(input, knob);
    row.append(label, toggle);
    host.append(row);
  });
};

const renderExceptions = () => {
  const host = document.getElementById('exceptions');
  host.textContent = '';
  const list = settings.exceptions || [];
  if (!list.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'No exceptions. The shield is active everywhere.';
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
      settings = await send({
        type: 'setSettings',
        patch: { exceptions: list.filter((x) => x !== entry) }
      });
      renderExceptions();
    });
    row.append(label, remove);
    host.append(row);
  });
};

const renderTop = () => {
  document.getElementById('enabled').checked = settings.enabled;
  document.getElementById('profile').value = settings.profile;
  document.getElementById('spoofHeaders').checked = settings.spoofHeaders;
  document.getElementById('state').textContent = settings.enabled ? settings.profile : 'off';
};

const init = async () => {
  settings = await send({ type: 'getSettings' });
  renderTop();
  renderFeatures();
  renderExceptions();

  document.getElementById('enabled').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { enabled: e.target.checked } });
    renderTop();
    renderFeatures();
  });
  document.getElementById('profile').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { profile: e.target.value } });
    renderTop();
  });
  document.getElementById('spoofHeaders').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { spoofHeaders: e.target.checked } });
  });

  const add = async () => {
    const input = document.getElementById('exceptionInput');
    const value = input.value.trim().toLowerCase().replace(/^https?:\/\//, '').replace(/^www\./, '').replace(/\/.*$/, '');
    if (!value) return;
    const set = new Set(settings.exceptions || []);
    set.add(value);
    settings = await send({ type: 'setSettings', patch: { exceptions: [...set] } });
    input.value = '';
    renderExceptions();
  };
  document.getElementById('addException').addEventListener('click', add);
  document.getElementById('exceptionInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') add();
  });

  document.getElementById('reset').addEventListener('click', async () => {
    settings = await send({ type: 'reset' });
    renderTop();
    renderFeatures();
    renderExceptions();
  });
};

init();
