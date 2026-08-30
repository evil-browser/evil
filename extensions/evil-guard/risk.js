export const PERMISSION_RISK = {
  debugger: [45, 'Can attach a debugger to any page and read or rewrite everything on it'],
  nativeMessaging: [35, 'Can talk to a program installed outside the browser'],
  desktopCapture: [30, 'Can capture your screen'],
  pageCapture: [28, 'Can save the full contents of any page'],
  proxy: [28, 'Can route all of your traffic through a server it chooses'],
  management: [25, 'Can enable, disable or remove your other extensions'],
  privacy: [20, 'Can change privacy and security settings'],
  tabCapture: [20, 'Can capture tab audio and video'],
  cookies: [18, 'Can read and write cookies, including session tokens'],
  webRequest: [18, 'Can observe every request the browser makes'],
  webRequestBlocking: [12, 'Can block or rewrite requests before they are sent'],
  declarativeNetRequestWithHostAccess: [10, 'Can rewrite requests and headers'],
  history: [15, 'Can read your full browsing history'],
  contentSettings: [14, 'Can change per-site permissions'],
  downloads: [12, 'Can start downloads and read the download list'],
  clipboardRead: [12, 'Can read the clipboard'],
  scripting: [12, 'Can inject scripts into pages'],
  bookmarks: [8, 'Can read and change bookmarks'],
  geolocation: [8, 'Can read your location'],
  tabs: [8, 'Can see the URL and title of every tab'],
  sessions: [6, 'Can read recently closed tabs'],
  storage: [0, 'Local storage for its own settings'],
  alarms: [0, 'Scheduling'],
  notifications: [0, 'Desktop notifications']
};

export const HOST_RISK = {
  all: [25, 'Runs on every website you visit'],
  wide: [12, 'Runs on a broad set of websites'],
  narrow: [0, 'Runs only on specific sites']
};

const ALL_HOSTS = ['<all_urls>', '*://*/*', 'http://*/*', 'https://*/*', '*://*/', 'file:///*'];

export const classifyHosts = (hostPermissions) => {
  if (!hostPermissions || !hostPermissions.length) return 'narrow';
  if (hostPermissions.some((h) => ALL_HOSTS.includes(h))) return 'all';
  if (hostPermissions.some((h) => /^\*:\/\/\*\./.test(h)) && hostPermissions.length > 6) return 'wide';
  return 'narrow';
};

export const isWebStore = (updateUrl) =>
  typeof updateUrl === 'string' && /clients2\.google\.com\/service\/update2\/crx/.test(updateUrl);

export const assess = (info, previous) => {
  const reasons = [];
  let score = 0;

  (info.permissions || []).forEach((permission) => {
    const entry = PERMISSION_RISK[permission];
    if (!entry) return;
    if (entry[0] > 0) {
      score += entry[0];
      reasons.push({ weight: entry[0], text: entry[1], tag: permission });
    }
  });

  const hostClass = classifyHosts(info.hostPermissions);
  const hostEntry = HOST_RISK[hostClass];
  if (hostEntry[0] > 0) {
    score += hostEntry[0];
    reasons.push({ weight: hostEntry[0], text: hostEntry[1], tag: 'host access' });
  }

  if (info.installType === 'development') {
    score += 25;
    reasons.push({ weight: 25, text: 'Loaded unpacked from disk, not from a store', tag: 'unpacked' });
  } else if (info.installType === 'sideload') {
    score += 30;
    reasons.push({ weight: 30, text: 'Installed by another program on this machine', tag: 'sideloaded' });
  } else if (!isWebStore(info.updateUrl) && info.installType !== 'admin') {
    score += 20;
    reasons.push({ weight: 20, text: 'Updates from a server that is not the Chrome Web Store', tag: 'off-store' });
  }

  if (!info.homepageUrl) {
    score += 5;
    reasons.push({ weight: 5, text: 'No listing or homepage to identify the publisher', tag: 'unlisted' });
  }

  if (previous) {
    const before = new Set(previous.permissions || []);
    const added = (info.permissions || []).filter((p) => !before.has(p) && (PERMISSION_RISK[p] || [0])[0] > 0);
    if (added.length) {
      score += 15;
      reasons.push({
        weight: 15,
        text: `Asked for new permissions after install: ${added.join(', ')}`,
        tag: 'escalated'
      });
    }
    if (classifyHosts(previous.hostPermissions) !== 'all' && hostClass === 'all') {
      score += 15;
      reasons.push({ weight: 15, text: 'Widened its access to every website after install', tag: 'escalated' });
    }
  }

  reasons.sort((a, b) => b.weight - a.weight);
  const band = score >= 55 ? 'high' : score >= 25 ? 'review' : 'low';
  return { score, band, reasons, hostClass };
};

export const summarize = (assessments) => ({
  total: assessments.length,
  high: assessments.filter((a) => a.band === 'high').length,
  review: assessments.filter((a) => a.band === 'review').length,
  low: assessments.filter((a) => a.band === 'low').length
});
