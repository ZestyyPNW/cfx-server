// ============================================================
// tcp_drugs — dialogue.js
// Retro RPG-style NPC dialogue for NUI
// ============================================================

// Reliable resource name for NUI callbacks in FiveM.
const RESOURCE_NAME = (typeof GetParentResourceName === 'function' && GetParentResourceName())
    || window.location.hostname
    || 'tcp_drugs';
const MAX_VISIBLE   = 6;
const TYPE_DELAY    = 28; // ms per character

let currentOptions  = [];
let selectedIndex   = 0;
let scrollOffset    = 0;
let isTyping        = false;
let typingTimer     = null;
let pendingFullText = '';

// ── DOM refs ────────────────────────────────────────────────
const wrapper    = document.getElementById('dialogue-wrapper');
const npcNameEl  = document.getElementById('npc-name');
const textEl     = document.getElementById('dialogue-text');
const dividerEl  = document.getElementById('options-divider');
const scrollUpEl = document.getElementById('scroll-up');
const listEl     = document.getElementById('options-list');
const scrollDnEl = document.getElementById('scroll-down');
const skipHintEl = document.getElementById('skip-hint');

// ── NUI message listener ─────────────────────────────────────
window.addEventListener('message', function (e) {
    const d = e.data;
    if (!d || !d.action) return;

    if (d.action === 'openDialogue') {
        openDialogue(d.npcName || '???', d.text || '', d.options || []);
    } else if (d.action === 'closeDialogue') {
        closeDialogue(false);
    }
});

// ── Open ─────────────────────────────────────────────────────
function openDialogue(name, text, options) {
    // Reset state
    clearTimeout(typingTimer);
    isTyping       = false;
    currentOptions = options;
    selectedIndex  = 0;
    scrollOffset   = 0;

    npcNameEl.textContent = name.toUpperCase();
    textEl.textContent    = '';
    listEl.innerHTML      = '';
    listEl.style.display  = 'none';
    dividerEl.style.display   = 'none';
    scrollUpEl.style.display  = 'none';
    scrollDnEl.style.display  = 'none';

    wrapper.style.display = 'block';
    wrapper.classList.remove('visible');
    void wrapper.offsetWidth; // force reflow for animation
    wrapper.classList.add('visible');

    startTyping(text);
}

// ── Typewriter ────────────────────────────────────────────────
function startTyping(text) {
    pendingFullText   = text;
    isTyping          = true;
    skipHintEl.style.display = 'block';
    let i = 0;

    function tick() {
        if (i < text.length) {
            textEl.textContent += text[i++];
            typingTimer = setTimeout(tick, TYPE_DELAY);
        } else {
            finishTyping();
        }
    }
    tick();
}

function finishTyping() {
    isTyping                 = false;
    skipHintEl.style.display = 'none';
    textEl.textContent       = pendingFullText;
    clearTimeout(typingTimer);

    if (currentOptions.length > 0) {
        dividerEl.style.display = 'block';
        listEl.style.display    = 'block';
        renderOptions();
    }
}

// ── Options render ────────────────────────────────────────────
function renderOptions() {
    listEl.innerHTML = '';

    const end     = Math.min(scrollOffset + MAX_VISIBLE, currentOptions.length);
    const visible = currentOptions.slice(scrollOffset, end);

    visible.forEach(function (opt, i) {
        const actualIdx = i + scrollOffset;
        const div = document.createElement('div');
        div.className = 'opt' + (actualIdx === selectedIndex ? ' selected' : '');
        div.textContent = opt.label;
        div.dataset.index = actualIdx;

        div.addEventListener('mouseenter', function () {
            selectedIndex = actualIdx;
            renderOptions();
        });
        div.addEventListener('click', function () {
            selectedIndex = actualIdx;
            confirmSelection();
        });

        listEl.appendChild(div);
    });

    scrollUpEl.style.display = scrollOffset > 0 ? 'block' : 'none';
    scrollDnEl.style.display = (scrollOffset + MAX_VISIBLE < currentOptions.length) ? 'block' : 'none';
}

// ── Navigation ────────────────────────────────────────────────
function navigate(dir) {
    selectedIndex = Math.max(0, Math.min(currentOptions.length - 1, selectedIndex + dir));

    if (selectedIndex < scrollOffset) {
        scrollOffset = selectedIndex;
    } else if (selectedIndex >= scrollOffset + MAX_VISIBLE) {
        scrollOffset = selectedIndex - MAX_VISIBLE + 1;
    }

    renderOptions();
}

// ── Confirm / Cancel ─────────────────────────────────────────
function confirmSelection() {
    const opt = currentOptions[selectedIndex];
    if (!opt) return;

    // Capture index BEFORE closeDialogue resets selectedIndex to 0
    const capturedIndex = selectedIndex + 1; // 1-indexed for Lua

    closeDialogue(false);

    fetch('https://' + RESOURCE_NAME + '/dialogueSelect', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({ index: capturedIndex }),
    }).catch(function (err) {
        console.error('[tcp_drugs dialogue] fetch failed:', err);
    });
}

function cancelDialogue() {
    closeDialogue(false);

    fetch('https://' + RESOURCE_NAME + '/dialogueCancel', {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({}),
    }).catch(function (err) {
        console.error('[tcp_drugs dialogue] cancel fetch failed:', err);
    });
}

function closeDialogue(notify) {
    clearTimeout(typingTimer);
    isTyping       = false;
    currentOptions = [];
    selectedIndex  = 0;
    scrollOffset   = 0;

    wrapper.classList.remove('visible');
    wrapper.style.display = 'none';
    skipHintEl.style.display = 'none';
}

// ── Keyboard ─────────────────────────────────────────────────
document.addEventListener('keydown', function (e) {
    if (wrapper.style.display === 'none') return;

    // Skip typewriter animation
    if (isTyping) {
        if (e.key === 'Enter' || e.key === ' ') {
            finishTyping();
        }
        return;
    }

    if (e.key === 'ArrowUp'   || e.key === 'w' || e.key === 'W') { e.preventDefault(); navigate(-1); }
    if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') { e.preventDefault(); navigate(1);  }
    if (e.key === 'Enter')     { e.preventDefault(); confirmSelection(); }
    if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); cancelDialogue(); }
});
