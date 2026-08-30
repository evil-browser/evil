const DEFAULTS = {
  enabled: true,
  profile: 'windows',
  features: {
    platform: true,
    hardware: true,
    locale: true,
    screen: true,
    canvas: true,
    webgl: true,
    audio: true,
    webrtc: true,
    devices: true,
    plugins: true
  },
  spoofHeaders: true,
  exceptions: []
};

const RULESETS = ['linux', 'windows', 'macos'];
const SCRIPT_ID = 'evil-shield-page';

const getSettings = async () => {
  const stored = await chrome.storage.local.get('settings');
  return Object.assign({}, DEFAULTS, stored.settings, {
    features: Object.assign({}, DEFAULTS.features, (stored.settings || {}).features)
  });
};

const setSettings = async (patch) => {
  const current = await getSettings();
  const next = Object.assign({}, current, patch);
  if (patch.features) next.features = Object.assign({}, current.features, patch.features);
  await chrome.storage.local.set({ settings: next });
  return next;
};

const profileFile = (profile) => {
  if (profile === 'linux') return 'page/profile-linux.js';
  if (profile === 'macos') return 'page/profile-macos.js';
  if (profile === 'native') return 'page/profile-native.js';
  return 'page/profile-windows.js';
};

const excludeMatches = (exceptions) =>
  exceptions.flatMap((host) => [`*://${host}/*`, `*://*.${host}/*`]);

const applyScripts = async (settings) => {
  try {
    await chrome.scripting.unregisterContentScripts({ ids: [SCRIPT_ID] });
  } catch (e) {}
  if (!settings.enabled) return;
  const registration = {
    id: SCRIPT_ID,
    js: [profileFile(settings.profile), 'page/core.js'],
    matches: ['<all_urls>'],
    runAt: 'document_start',
    allFrames: true,
    world: 'MAIN'
  };
  const excluded = excludeMatches(settings.exceptions || []);
  if (excluded.length) registration.excludeMatches = excluded;
  try {
    await chrome.scripting.registerContentScripts([registration]);
  } catch (e) {
    await chrome.storage.local.set({ lastError: String(e) });
  }
};

const applyRules = async (settings) => {
  const wanted = settings.enabled && settings.spoofHeaders && RULESETS.includes(settings.profile)
    ? [settings.profile]
    : [];
  const disable = RULESETS.filter((id) => !wanted.includes(id));
  try {
    await chrome.declarativeNetRequest.updateEnabledRulesets({
      enableRulesetIds: wanted,
      disableRulesetIds: disable
    });
  } catch (e) {
    await chrome.storage.local.set({ lastError: String(e) });
  }
};

const updateBadge = async (settings) => {
  await chrome.action.setBadgeBackgroundColor({ color: '#1a1a1a' });
  await chrome.action.setBadgeTextColor({ color: '#ffffff' });
  const label = !settings.enabled ? 'off' : settings.profile.slice(0, 3);
  await chrome.action.setBadgeText({ text: label });
};

const apply = async () => {
  const settings = await getSettings();
  await applyScripts(settings);
  await applyRules(settings);
  await updateBadge(settings);
  return settings;
};

chrome.runtime.onInstalled.addListener(async (details) => {
  if (details.reason === 'install') {
    await chrome.storage.local.set({ settings: DEFAULTS });
  }
  await apply();
});

chrome.runtime.onStartup.addListener(apply);

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.settings) apply();
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
  if (message.type === 'reset') {
    chrome.storage.local.set({ settings: DEFAULTS }).then(() => sendResponse(DEFAULTS));
    return true;
  }
  return false;
});

apply();
