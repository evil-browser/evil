const send = (message) => chrome.runtime.sendMessage(message);

const currentHost = async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.url) return null;
  try {
    const url = new URL(tab.url);
    if (!/^https?:$/.test(url.protocol)) return null;
    return url.hostname.replace(/^www\./, '');
  } catch (e) {
    return null;
  }
};

const render = (settings, host) => {
  document.getElementById('enabled').checked = settings.enabled;
  document.getElementById('profile').value = settings.profile;
  document.getElementById('state').textContent = settings.enabled ? settings.profile : 'off';
  const exception = document.getElementById('exception');
  const hostLabel = document.getElementById('host');
  if (host) {
    hostLabel.textContent = host;
    exception.checked = (settings.exceptions || []).includes(host);
    exception.disabled = false;
  } else {
    hostLabel.textContent = 'not a web page';
    exception.checked = false;
    exception.disabled = true;
  }
};

const init = async () => {
  const host = await currentHost();
  let settings = await send({ type: 'getSettings' });
  render(settings, host);

  document.getElementById('enabled').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { enabled: e.target.checked } });
    render(settings, host);
  });

  document.getElementById('profile').addEventListener('change', async (e) => {
    settings = await send({ type: 'setSettings', patch: { profile: e.target.value } });
    render(settings, host);
  });

  document.getElementById('exception').addEventListener('change', async (e) => {
    if (!host) return;
    const set = new Set(settings.exceptions || []);
    if (e.target.checked) set.add(host); else set.delete(host);
    settings = await send({ type: 'setSettings', patch: { exceptions: [...set] } });
    render(settings, host);
  });

  document.getElementById('options').addEventListener('click', () => {
    chrome.runtime.openOptionsPage();
  });

  document.getElementById('reload').addEventListener('click', async () => {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab) chrome.tabs.reload(tab.id);
    window.close();
  });
};

init();
