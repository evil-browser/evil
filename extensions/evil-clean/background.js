const ORIGIN_SCOPED = ['cache', 'cacheStorage', 'cookies', 'fileSystems', 'indexedDB', 'localStorage', 'serviceWorkers', 'webSQL'];
const GLOBAL_SCOPED = ['downloads', 'formData', 'history', 'passwords'];

const DEFAULTS = {
  types: {
    cache: true,
    cacheStorage: true,
    cookies: true,
    downloads: true,
    fileSystems: true,
    formData: true,
    history: true,
    indexedDB: true,
    localStorage: true,
    passwords: false,
    serviceWorkers: true,
    webSQL: true
  },
  keepOrigins: [],
  cleanOnStartup: false,
  intervalMinutes: 0,
  notify: true,
  lastBurn: 0
};

const getSettings = async () => {
  const stored = await chrome.storage.local.get('settings');
  const settings = Object.assign({}, DEFAULTS, stored.settings);
  settings.types = Object.assign({}, DEFAULTS.types, (stored.settings || {}).types);
  return settings;
};

const setSettings = async (patch) => {
  const current = await getSettings();
  const next = Object.assign({}, current, patch);
  if (patch.types) next.types = Object.assign({}, current.types, patch.types);
  await chrome.storage.local.set({ settings: next });
  return next;
};

const expandOrigins = (hosts) => {
  const out = [];
  hosts.forEach((host) => {
    out.push(`https://${host}`, `http://${host}`, `https://www.${host}`, `http://www.${host}`);
  });
  return out;
};

const burn = async () => {
  const settings = await getSettings();
  const selected = Object.keys(settings.types).filter((key) => settings.types[key]);
  const originTypes = { unprotectedWeb: true };
  const keep = expandOrigins(settings.keepOrigins || []);

  const originSet = {};
  const globalSet = {};
  selected.forEach((key) => {
    if (ORIGIN_SCOPED.includes(key)) originSet[key] = true;
    if (GLOBAL_SCOPED.includes(key)) globalSet[key] = true;
  });

  if (Object.keys(originSet).length) {
    const options = { since: 0, originTypes };
    if (keep.length) options.excludeOrigins = keep;
    await chrome.browsingData.remove(options, originSet);
  }
  if (Object.keys(globalSet).length) {
    await chrome.browsingData.remove({ since: 0, originTypes }, globalSet);
  }

  const now = Date.now();
  await setSettings({ lastBurn: now });

  if (settings.notify) {
    chrome.notifications.create({
      type: 'basic',
      iconUrl: chrome.runtime.getURL('icons/128.png'),
      title: 'Burned',
      message: `${selected.length} categories cleared${keep.length ? ', exceptions kept' : ''}.`,
      silent: true
    });
  }
  return now;
};

const scheduleAlarm = async () => {
  await chrome.alarms.clear('scheduled-burn');
  const settings = await getSettings();
  if (settings.intervalMinutes > 0) {
    chrome.alarms.create('scheduled-burn', {
      periodInMinutes: settings.intervalMinutes,
      delayInMinutes: settings.intervalMinutes
    });
  }
};

chrome.runtime.onInstalled.addListener(async (details) => {
  if (details.reason === 'install') await chrome.storage.local.set({ settings: DEFAULTS });
  await scheduleAlarm();
});

chrome.runtime.onStartup.addListener(async () => {
  const settings = await getSettings();
  if (settings.cleanOnStartup) await burn();
  await scheduleAlarm();
});

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'scheduled-burn') burn();
});

chrome.commands.onCommand.addListener((command) => {
  if (command === 'burn') burn();
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.settings) {
    const before = changes.settings.oldValue || {};
    const after = changes.settings.newValue || {};
    if (before.intervalMinutes !== after.intervalMinutes) scheduleAlarm();
  }
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'getSettings') {
    getSettings().then(sendResponse);
    return true;
  }
  if (message.type === 'setSettings') {
    setSettings(message.patch).then(sendResponse);
    return true;
  }
  if (message.type === 'burn') {
    burn().then((at) => sendResponse({ at }));
    return true;
  }
  if (message.type === 'reset') {
    chrome.storage.local.set({ settings: DEFAULTS }).then(() => sendResponse(DEFAULTS));
    return true;
  }
  return false;
});
