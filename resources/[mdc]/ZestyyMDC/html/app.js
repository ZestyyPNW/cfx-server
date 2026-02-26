const root = document.getElementById('mdcRoot');
const frame = document.getElementById('mdcFrame');
const topbar = document.getElementById('topbar');
const resizeHandle = document.getElementById('resizeHandle');
const btnClose = document.getElementById('btnClose');
const btnReload = document.getElementById('btnReload');
const ENABLE_RESIZE_HANDLE = false;

let lastUrl = null;
let initialized = false;

const WINDOW_STORAGE_KEY = 'zestyy_mdc_wrapper_window_v1';

function getResourceName() {
  try {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : null;
  } catch (_) {
    return null;
  }
}

function nuiFetch(name, data) {
  const r = getResourceName();
  if (!r) return Promise.resolve(null);
  return fetch(`https://${r}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {})
  }).then(res => res.json()).catch(() => null);
}

let consoleForwardWindow = [];
let lastConsoleSignature = null;
let lastConsoleAt = 0;

function canForwardConsoleNow(signature) {
  const now = Date.now();
  consoleForwardWindow = consoleForwardWindow.filter((t) => (now - t) < 5000);
  if (consoleForwardWindow.length >= 15) return false; // 15 errors / 5s
  if (signature && signature === lastConsoleSignature && (now - lastConsoleAt) < 1000) return false;
  consoleForwardWindow.push(now);
  lastConsoleSignature = signature || null;
  lastConsoleAt = now;
  return true;
}

function getMdcOrigin() {
  if (!lastUrl) return null;
  try {
    return new URL(lastUrl).origin;
  } catch (_) {
    return null;
  }
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function loadWindowState() {
  try {
    const raw = localStorage.getItem(WINDOW_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return null;
    return parsed;
  } catch (_) {
    return null;
  }
}

function saveWindowState(state) {
  try {
    localStorage.setItem(WINDOW_STORAGE_KEY, JSON.stringify(state));
  } catch (_) {
    // ignore
  }
}

function applyWindowState() {
  const state = loadWindowState();
  if (!state) return;

  const minW = 640;
  const minH = 400;
  const maxW = Math.max(minW, window.innerWidth - 20);
  const maxH = Math.max(minH, window.innerHeight - 20);

  if (typeof state.w === 'number') root.style.width = `${clamp(state.w, minW, maxW)}px`;
  if (typeof state.h === 'number') root.style.height = `${clamp(state.h, minH, maxH)}px`;

  if (typeof state.x === 'number' && typeof state.y === 'number') {
    root.style.left = `${clamp(state.x, 10, window.innerWidth - 10)}px`;
    root.style.top = `${clamp(state.y, 10, window.innerHeight - 10)}px`;
    root.style.transform = 'translate(0, 0)';
  }
}

function resetWindowState() {
  try {
    localStorage.removeItem(WINDOW_STORAGE_KEY);
  } catch (_) {
    // ignore
  }
  root.style.left = '';
  root.style.top = '';
  root.style.width = '';
  root.style.height = '';
  root.style.transform = '';
}

function show() {
  root.classList.remove('hidden');
  root.style.display = 'flex';
  applyWindowState();
}

function hide(persist) {
  root.classList.add('hidden');
  root.style.display = 'none';
  // Persist iframe state by not touching src.
  // If persist is false, wipe the iframe.
  if (!persist) {
    frame.src = 'about:blank';
    initialized = false;
  }
}

function loadUrl(url, cacheBust) {
  lastUrl = url;
  // Save last URL for next open
  nuiFetch('setLastUrl', { url: lastUrl });

  const currentLoadedUrl = frame?.dataset?.loadedUrl || '';
  const shouldReload =
    !initialized ||
    frame.src === 'about:blank' ||
    frame.src === '' ||
    currentLoadedUrl !== url ||
    !!cacheBust;

  if (!shouldReload) {
    console.log('[MDC] loadUrl skipped (persisted)', { url });
    return;
  }

  // Always add cache buster to prevent caching issues
  const finalUrl = `${url}${url.includes('?') ? '&' : '?'}t=${Date.now()}_FORCE`;
  frame.src = finalUrl;
  frame.dataset.loadedUrl = url;
  initialized = true;
  console.log('[MDC] loadUrl with cache buster:', finalUrl);
}

btnClose.addEventListener('click', () => nuiFetch('close', {}));
btnReload.addEventListener('click', () => {
  if (!lastUrl) return;
  // Force clear cache by setting src to empty first, then reload with cache buster
  frame.src = 'about:blank';
  setTimeout(() => {
    const u = `${lastUrl}${lastUrl.includes('?') ? '&' : '?'}t=${Date.now()}_FORCE`;
    frame.src = u;
    frame.dataset.loadedUrl = lastUrl;
    initialized = true;
    console.log('[MDC] Force reload with cache cleared:', u);
  }, 100);
});

// Never flash the UI on resource restart (even if CSS fails to load momentarily).
hide(true);

// Drag-move the wrapper by the topbar (ignores clicks on buttons)
if (topbar && root) {
  topbar.addEventListener('dblclick', (e) => {
    const target = e.target;
    if (target && (target.closest('#controls') || target.closest('button'))) return;
    resetWindowState();
  });

  topbar.addEventListener('mousedown', (e) => {
    const target = e.target;
    if (target && (target.closest('#controls') || target.closest('button'))) return;
    if (e.button !== 0) return;

    const rect = root.getBoundingClientRect();
    const startX = e.clientX;
    const startY = e.clientY;
    const offsetX = startX - rect.left;
    const offsetY = startY - rect.top;

    root.style.transform = 'translate(0, 0)';

    const onMove = (ev) => {
      const x = clamp(ev.clientX - offsetX, 10, window.innerWidth - 10);
      const y = clamp(ev.clientY - offsetY, 10, window.innerHeight - 10);
      root.style.left = `${x}px`;
      root.style.top = `${y}px`;
      saveWindowState({
        x,
        y,
        w: root.getBoundingClientRect().width,
        h: root.getBoundingClientRect().height
      });
    };

    const onUp = () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };

    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  });
}

// Resize via bottom-right handle (disabled by default for stability)
if (ENABLE_RESIZE_HANDLE && resizeHandle && root) {
  resizeHandle.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    e.preventDefault();

    const rect = root.getBoundingClientRect();
    const startW = rect.width;
    const startH = rect.height;
    const startX = e.clientX;
    const startY = e.clientY;

    const minW = 640;
    const minH = 400;

    const onMove = (ev) => {
      const maxW = Math.max(minW, window.innerWidth - rect.left - 10);
      const maxH = Math.max(minH, window.innerHeight - rect.top - 10);
      const w = clamp(startW + (ev.clientX - startX), minW, maxW);
      const h = clamp(startH + (ev.clientY - startY), minH, maxH);
      root.style.width = `${w}px`;
      root.style.height = `${h}px`;
      saveWindowState({
        x: root.getBoundingClientRect().left,
        y: root.getBoundingClientRect().top,
        w,
        h
      });
    };

    const onUp = () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onUp);
    };

    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onUp);
  });
}

window.addEventListener('resize', () => applyWindowState());

window.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    e.preventDefault();
    nuiFetch('close', {});
  }
});

// Receive open/close from Lua
window.addEventListener('message', (event) => {
  const data = event.data || {};
  // Avoid spamming the FiveM console; log only high-signal events.
  if (data && typeof data === 'object' && data.action) {
    console.log('[MDC] action', data.action, {
      url: data.url,
      firstLoad: data.firstLoad,
      cacheBust: data.cacheBust,
      persist: data.persist
    });
  }
  if (data.action === 'open') {
    show();
    if (typeof data.url === 'string' && data.url.length) {
      loadUrl(data.url, !!data.cacheBust && !!data.firstLoad);
    }
    return;
  }

  if (data.action === 'close') {
    hide(!!data.persist);
    return;
  }

  if (data.action === 'reload') {
    if (!lastUrl) return;
    // Force clear cache by setting src to empty first, then reload with cache buster
    frame.src = 'about:blank';
    setTimeout(() => {
      frame.src = `${lastUrl}${lastUrl.includes('?') ? '&' : '?'}t=${Date.now()}_FORCE`;
      console.log('[MDC] Force reload from NUI command (cache cleared):', frame.src);
    }, 100);
    return;
  }

  const expectedOrigin = getMdcOrigin();
  
  // Handle messages from FiveM (RID, mileage, character name, etc.) - forward to iframe
  if (data.type === 'setRID' || data.type === 'setMileageData' || data.type === 'setCurrentMileage' || data.type === 'setCharacterName') {
    if (frame && frame.contentWindow && expectedOrigin) {
      frame.contentWindow.postMessage(data, expectedOrigin);
    }
    return;
  }

  const fromIframe = frame && (event.source === frame.contentWindow || (expectedOrigin && event.origin === expectedOrigin));
  if (!fromIframe) return;

  if (data.type === 'mdcRequestRID') {
    nuiFetch('getPlayerRID', {}).catch(() => null);
    return;
  }

  if (data.type === 'mdcRequestCharacterName') {
    nuiFetch('getCharacterName', {})
      .then((payload) => {
        if (payload && payload.name) {
          frame.contentWindow.postMessage(
            { type: 'setCharacterName', name: payload.name },
            getMdcOrigin() || '*'
          );
        }
      })
      .catch(() => null);
    return;
  }

  if (data.type === 'mdcConsole') {
    const level = (data.level || 'error').toString();
    const message = (data.message || '').toString();
    const signature = `${level}|${message}`.slice(0, 250);
    if (!canForwardConsoleNow(signature)) return;
    console.log('[MDC] forwarded web console', { level, message });
    nuiFetch('console', {
      level,
      message,
      stack: data.stack || null,
      source: data.source || null,
      line: data.line || null,
      column: data.column || null,
      href: data.href || null,
      user: data.user || null,
      ts: data.ts || Date.now()
    }).catch(() => null);
    return;
  }

  if (data.type === 'mdcRequestLocation') {
    const requestId = data.requestId;
    nuiFetch('getLocation', { postal: data.postal || '', location: data.location || '' })
      .then((payload) => {
        const reply = payload && typeof payload === 'object' ? payload : { error: 'no_payload' };
        frame.contentWindow.postMessage(
          { type: 'mdcLocation', requestId, ...reply },
          getMdcOrigin() || '*'
        );
      })
      .catch(() => {
        frame.contentWindow.postMessage(
          { type: 'mdcLocation', requestId, error: 'fetch_failed' },
          getMdcOrigin() || '*'
        );
      });
    return;
  }

  if (data.type === 'mdcUnit') {
    nuiFetch('setUnit', {
      unit: data.unit || '',
      name: data.name || ''
    }).catch(() => null);
    return;
  }

  if (data.type === 'mdcUnreadCount') {
    nuiFetch('updateUnread', {
      count: data.count || 0
    }).catch(() => null);
    return;
  }

  if (data.type === 'mdcChat') {
    nuiFetch('chat', {
      channel: data.channel || 'MDC',
      text: data.text || ''
    }).catch(() => null);
  }
});
