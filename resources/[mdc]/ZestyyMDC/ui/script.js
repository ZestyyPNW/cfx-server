const mdcWindow = document.getElementById('mdc-window');
const mdcHeader = document.getElementById('mdc-header');
const mdcFrame = document.getElementById('mdc-frame');
const notifyRoot = document.getElementById('mdc-notify-root');

let isDragging = false;
let offsetX, offsetY;
let audioEnabled = false;
let activeAudioCtx = null;
const defaultMdcUrl = "https://mdc.zestyy.dev";
let lastMdcUrl = mdcFrame ? (mdcFrame.getAttribute('src') || defaultMdcUrl) : defaultMdcUrl;
const allowedOrigin = new URL(defaultMdcUrl).origin;
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : null;
const nuiOrigin = resourceName ? `https://${resourceName}` : null;
const nuiAltOrigin = resourceName ? `nui://${resourceName}` : null;
const nuiInternalOrigins = new Set([
    'https://nui-game-internal',
    'http://nui-game-internal'
]);

// NUI Messages
window.addEventListener('message', function(event) {
    if (
        event.origin &&
        event.origin !== 'null' &&
        event.origin !== allowedOrigin &&
        event.origin !== nuiOrigin &&
        event.origin !== nuiAltOrigin &&
        !nuiInternalOrigins.has(event.origin)
    ) {
        return;
    }
    if (event.data.action === 'open') {
        if (!mdcWindow || !mdcFrame) {
            console.log('[MDC] Missing DOM nodes', {
                mdcWindow: !!mdcWindow,
                mdcFrame: !!mdcFrame,
                origin: event.origin || ''
            });
            return;
        }
        console.log('[MDC] Open message received', { origin: event.origin || '' });
        mdcWindow.style.display = "flex";
        if (mdcFrame && (!mdcFrame.src || mdcFrame.src === "about:blank")) {
            mdcFrame.src = `${lastMdcUrl}?t=${Date.now()}`;
        }
        if (event.data.openObs) {
            mdcFrame.contentWindow.postMessage({
                action: 'renderObs',
                data: event.data.openObs
            }, '*');
        }
    } else if (event.data.action === 'runUR') {
        mdcFrame.contentWindow.postMessage({
            type: 'runUR',
            unit: event.data.unit || ''
        }, '*');
    } else if (event.data.type === 'mdcChat') {
        fetch(`https://${GetParentResourceName()}/chat`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                channel: event.data.channel || 'MDC',
                text: event.data.text || ''
            })
        });
    } else if (event.data.action === 'close') {
        mdcWindow.style.display = 'none';
        if (mdcFrame) {
            lastMdcUrl = mdcFrame.src || lastMdcUrl;
            mdcFrame.src = "about:blank";
        }
    } else if (event.data.action === 'setAudio') {
        audioEnabled = !!event.data.enabled;
        if (!audioEnabled && activeAudioCtx) {
            try {
                activeAudioCtx.close();
            } catch (_) {
                // Ignore audio close failures in CEF
            }
            activeAudioCtx = null;
        }
    } else if (event.data.type === 'mdcUnreadCount') {
        // Message from MDC iframe - update HUD with unread count
        fetch(`https://${GetParentResourceName()}/updateUnread`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ count: event.data.count || 0 })
        });
    } else if (event.data.type === 'mdcRequestLocation') {
        const requestId = event.data.requestId;
        fetch(`https://${GetParentResourceName()}/getLocation`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        })
            .then(res => res.text())
            .then(text => {
                let payload = null;
                try {
                    payload = text ? JSON.parse(text) : {};
                } catch (_) {
                    payload = { error: 'bad_response' };
                }
                mdcFrame.contentWindow.postMessage({
                    type: 'mdcLocation',
                    requestId: requestId,
                    ...payload
                }, '*');
            })
            .catch(() => {
                mdcFrame.contentWindow.postMessage({
                    type: 'mdcLocation',
                    requestId: requestId,
                    error: 'fetch_failed'
                }, '*');
            });
    } else if (event.data.type === 'mdcUnit') {
        // Message from MDC iframe - update unit/callsign
        fetch(`https://${GetParentResourceName()}/setUnit`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({
                unit: event.data.unit || '',
                name: event.data.name || ''
            })
        });
    } else if (event.data.type === 'mdcCallNotification') {
        const title = event.data.title || 'New Call';
        const body = event.data.body || '';
        showNotification(title, body);
    }
});

// Draggable Logic
mdcHeader.onmousedown = (e) => {
    isDragging = true;
    mdcWindow.classList.add('dragging');
    const rect = mdcWindow.getBoundingClientRect();
    offsetX = e.clientX - rect.left;
    offsetY = e.clientY - rect.top;
};

document.onmousemove = (e) => {
    if (!isDragging) return;
    let x = e.clientX - offsetX;
    let y = e.clientY - offsetY;
    x = Math.max(0, Math.min(window.innerWidth - mdcWindow.offsetWidth, x));
    y = Math.max(0, Math.min(window.innerHeight - mdcWindow.offsetHeight, y));
    mdcWindow.style.left = x + 'px';
    mdcWindow.style.top = y + 'px';
    mdcWindow.style.transform = 'none';
};

document.onmouseup = () => {
    isDragging = false;
    mdcWindow.classList.remove('dragging');
};

// Controls
function closeMDC() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

document.getElementById('close-btn').onclick = closeMDC;
document.getElementById('minimize-btn').onclick = closeMDC;

document.getElementById('reload-btn').onclick = () => {
    lastMdcUrl = defaultMdcUrl;
    mdcFrame.src = `${defaultMdcUrl}?t=${Date.now()}`;
};

window.addEventListener('keyup', (e) => {
    if (e.key === "Escape") closeMDC();
});

function showNotification(title, body) {
    if (!notifyRoot) return;
    const toast = document.createElement('div');
    toast.className = 'mdc-toast';
    toast.innerHTML = `
        <div class="mdc-toast-title">${escapeHtml(title)}</div>
        <div class="mdc-toast-body">${escapeHtml(body)}</div>
    `;
    notifyRoot.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('show'));
    if (audioEnabled) {
        playChime();
    }
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 200);
    }, 6500);
}

function playChime() {
    if (!audioEnabled) {
        return;
    }
    try {
        if (activeAudioCtx) {
            try {
                activeAudioCtx.close();
            } catch (_) {
                // Ignore audio close failures in CEF
            }
        }
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        activeAudioCtx = ctx;
        const now = ctx.currentTime;
        const osc1 = ctx.createOscillator();
        const osc2 = ctx.createOscillator();
        const gain = ctx.createGain();
        osc1.type = 'sine';
        osc2.type = 'triangle';
        osc1.frequency.value = 880;
        osc2.frequency.value = 1320;
        gain.gain.setValueAtTime(0.0001, now);
        gain.gain.exponentialRampToValueAtTime(0.12, now + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, now + 0.8);
        osc1.connect(gain);
        osc2.connect(gain);
        gain.connect(ctx.destination);
        osc1.start(now);
        osc2.start(now + 0.03);
        osc1.stop(now + 0.8);
        osc2.stop(now + 0.8);
        setTimeout(() => {
            if (activeAudioCtx === ctx) {
                try {
                    ctx.close();
                } catch (_) {
                    // Ignore audio close failures in CEF
                }
                if (activeAudioCtx === ctx) {
                    activeAudioCtx = null;
                }
            }
        }, 900);
    } catch (_) {
        // Ignore audio failures in CEF
    }
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}
