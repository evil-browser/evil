import { assess, summarize, isWebStore } from './risk.js';

const SELF_ID = chrome.runtime.id;

const loadSnapshot = async () => {
  const stored = await chrome.storage.local.get('snapshot');
  return stored.snapshot || {};
};

const saveSnapshot = async (extensions) => {
  const snapshot = {};
  extensions.forEach((info) => {
    snapshot[info.id] = {
      permissions: info.permissions || [],
      hostPermissions: info.hostPermissions || [],
      version: info.version
    };
  });
  await chrome.storage.local.set({ snapshot });
};

export const scan = async () => {
  const all = await chrome.management.getAll();
  const snapshot = await loadSnapshot();
  const extensions = all.filter((info) => info.type === 'extension' && info.id !== SELF_ID);

  const results = extensions.map((info) => {
    const verdict = assess(info, snapshot[info.id]);
    return {
      id: info.id,
      name: info.name,
      version: info.version,
      enabled: info.enabled,
      installType: info.installType,
      mayDisable: info.mayDisable,
      fromStore: isWebStore(info.updateUrl) || info.installType === 'normal',
      permissions: info.permissions || [],
      hostPermissions: info.hostPermissions || [],
      homepageUrl: info.homepageUrl || '',
      score: verdict.score,
      band: verdict.band,
      reasons: verdict.reasons
    };
  });

  results.sort((a, b) => b.score - a.score);
  const stats = summarize(results);

  await chrome.storage.local.set({ results, stats, scannedAt: Date.now() });
  await saveSnapshot(extensions);

  const flagged = stats.high + stats.review;
  await chrome.action.setBadgeBackgroundColor({ color: '#1a1a1a' });
  await chrome.action.setBadgeTextColor({ color: '#ffffff' });
  await chrome.action.setBadgeText({ text: flagged ? String(flagged) : '' });

  return { results, stats };
};

const notifyAbout = (result) => {
  chrome.notifications.create(`guard-${result.id}`, {
    type: 'basic',
    iconUrl: chrome.runtime.getURL('icons/128.png'),
    title: result.band === 'high' ? 'High-risk extension installed' : 'Extension needs review',
    message: `${result.name}: ${result.reasons.slice(0, 2).map((r) => r.text).join('. ')}`,
    priority: result.band === 'high' ? 2 : 0
  });
};

chrome.management.onInstalled.addListener(async (info) => {
  if (info.id === SELF_ID || info.type !== 'extension') return;
  const { results } = await scan();
  const match = results.find((r) => r.id === info.id);
  if (match && match.band !== 'low') notifyAbout(match);
});

chrome.management.onUninstalled.addListener(() => scan());
chrome.management.onEnabled.addListener(() => scan());
chrome.management.onDisabled.addListener(() => scan());

chrome.runtime.onInstalled.addListener(() => {
  scan();
  chrome.alarms.create('rescan', { periodInMinutes: 720 });
});
chrome.runtime.onStartup.addListener(() => scan());
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'rescan') scan();
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'scan') {
    scan().then(sendResponse);
    return true;
  }
  if (message.type === 'getResults') {
    chrome.storage.local.get(['results', 'stats', 'scannedAt']).then(sendResponse);
    return true;
  }
  if (message.type === 'setEnabled') {
    chrome.management.setEnabled(message.id, message.enabled)
      .then(() => scan())
      .then(sendResponse)
      .catch((e) => sendResponse({ error: String(e) }));
    return true;
  }
  if (message.type === 'uninstall') {
    chrome.management.uninstall(message.id, { showConfirmDialog: true })
      .then(() => scan())
      .then(sendResponse)
      .catch((e) => sendResponse({ error: String(e) }));
    return true;
  }
  return false;
});
