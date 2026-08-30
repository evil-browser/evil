const send = (message) => chrome.runtime.sendMessage(message);

const ago = (timestamp) => {
  if (!timestamp) return 'never';
  const seconds = Math.round((Date.now() - timestamp) / 1000);
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return `${Math.round(seconds / 60)}m ago`;
  return `${Math.round(seconds / 3600)}h ago`;
};

const render = (data) => {
  const stats = data.stats || { high: 0, review: 0, low: 0 };
  document.getElementById('high').textContent = stats.high;
  document.getElementById('review').textContent = stats.review;
  document.getElementById('low').textContent = stats.low;
  document.getElementById('scanned').textContent = ago(data.scannedAt);

  const host = document.getElementById('top');
  host.textContent = '';
  const flagged = (data.results || []).filter((r) => r.band !== 'low').slice(0, 4);
  if (!flagged.length) {
    const empty = document.createElement('p');
    empty.className = 'empty';
    empty.textContent = 'Nothing flagged. Every installed extension scored low.';
    host.append(empty);
    return;
  }
  flagged.forEach((result) => {
    const row = document.createElement('div');
    row.className = 'row';
    const label = document.createElement('span');
    label.className = 'label';
    const b = document.createElement('b');
    b.textContent = result.name;
    const span = document.createElement('span');
    span.textContent = result.reasons.length ? result.reasons[0].text : '';
    label.append(b, span);
    const tag = document.createElement('span');
    tag.className = result.band === 'high' ? 'tag tag--bad' : 'tag';
    tag.textContent = result.band;
    row.append(label, tag);
    host.append(row);
  });
};

const init = async () => {
  render(await send({ type: 'getResults' }));
  document.getElementById('rescan').addEventListener('click', async () => {
    await send({ type: 'scan' });
    render(await send({ type: 'getResults' }));
  });
  document.getElementById('options').addEventListener('click', () => chrome.runtime.openOptionsPage());
};

init();
