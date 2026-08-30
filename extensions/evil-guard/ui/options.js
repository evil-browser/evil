const send = (message) => chrome.runtime.sendMessage(message);

const ago = (timestamp) => {
  if (!timestamp) return 'never';
  const seconds = Math.round((Date.now() - timestamp) / 1000);
  if (seconds < 60) return 'scanned just now';
  if (seconds < 3600) return `scanned ${Math.round(seconds / 60)}m ago`;
  return `scanned ${Math.round(seconds / 3600)}h ago`;
};

const card = (result) => {
  const ext = document.createElement('div');
  ext.className = 'ext';

  const top = document.createElement('div');
  top.className = 'ext__top';
  const name = document.createElement('span');
  name.className = 'ext__name';
  name.textContent = result.name;
  const meta = document.createElement('span');
  meta.className = 'ext__meta';
  meta.textContent = `${result.version} · ${result.installType}${result.fromStore ? '' : ' · off-store'}${result.enabled ? '' : ' · disabled'}`;
  const score = document.createElement('span');
  score.className = 'ext__score';
  score.textContent = result.score;
  top.append(name, meta, score);

  const bar = document.createElement('div');
  bar.className = 'bar';
  const fill = document.createElement('i');
  fill.style.width = `${Math.min(100, result.score)}%`;
  bar.append(fill);

  const tags = document.createElement('div');
  tags.className = 'pillrow';
  const band = document.createElement('span');
  band.className = result.band === 'high' ? 'tag tag--bad' : 'tag';
  band.textContent = `${result.band} risk`;
  tags.append(band);
  const hosts = document.createElement('span');
  hosts.className = 'tag';
  hosts.textContent = `${result.hostPermissions.length} host rules`;
  tags.append(hosts);
  const perms = document.createElement('span');
  perms.className = 'tag';
  perms.textContent = `${result.permissions.length} permissions`;
  tags.append(perms);

  const reasons = document.createElement('div');
  reasons.style.marginTop = '12px';
  if (!result.reasons.length) {
    const none = document.createElement('p');
    none.className = 'empty';
    none.textContent = 'No risky capabilities.';
    reasons.append(none);
  }
  result.reasons.forEach((reason) => {
    const line = document.createElement('div');
    line.className = 'reason';
    const weight = document.createElement('span');
    weight.className = 'w';
    weight.textContent = `+${reason.weight}`;
    const text = document.createElement('span');
    text.textContent = reason.text;
    line.append(weight, text);
    reasons.append(line);
  });

  const actions = document.createElement('div');
  actions.className = 'ext__actions';
  const toggle = document.createElement('button');
  toggle.className = 'btn';
  toggle.textContent = result.enabled ? 'Disable' : 'Enable';
  toggle.disabled = !result.mayDisable;
  toggle.addEventListener('click', async () => {
    toggle.disabled = true;
    await send({ type: 'setEnabled', id: result.id, enabled: !result.enabled });
    load();
  });
  const remove = document.createElement('button');
  remove.className = 'btn';
  remove.textContent = 'Remove';
  remove.disabled = !result.mayDisable;
  remove.addEventListener('click', async () => {
    await send({ type: 'uninstall', id: result.id });
    load();
  });
  actions.append(toggle, remove);
  if (result.homepageUrl) {
    const link = document.createElement('a');
    link.href = result.homepageUrl;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = 'Listing';
    link.style.alignSelf = 'center';
    link.style.marginLeft = '6px';
    actions.append(link);
  }

  ext.append(top, bar, tags, reasons, actions);
  return ext;
};

const load = async () => {
  const data = await send({ type: 'getResults' });
  const stats = data.stats || { total: 0, high: 0, review: 0, low: 0 };
  document.getElementById('total').textContent = stats.total;
  document.getElementById('high').textContent = stats.high;
  document.getElementById('review').textContent = stats.review;
  document.getElementById('low').textContent = stats.low;
  document.getElementById('scanned').textContent = ago(data.scannedAt);

  const host = document.getElementById('list');
  host.textContent = '';
  const results = data.results || [];
  if (!results.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'No other extensions installed.';
    host.append(empty);
    return;
  }
  results.forEach((result) => host.append(card(result)));
};

document.getElementById('rescan').addEventListener('click', async () => {
  await send({ type: 'scan' });
  load();
});

load();
