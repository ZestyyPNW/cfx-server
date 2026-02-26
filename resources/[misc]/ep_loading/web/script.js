const config = window.LOADING_CONFIG || {};
const toggles = config.toggles || {};
const sections = config.sections || {};
const tips = Array.isArray(config.tips) ? config.tips : [];
const locales = Object.assign({
    players: "Players",
    status: "Status",
    ping: "Ping",
    loading: "Loading",
    music: "Music",
    video: "Video"
}, config.locales || {});

const state = {
    progress: 0,
    currentSection: "news",
    tipIndex: 0,
    galleryIndex: 0,
    musicIndex: 0,
    isYouTube: false,
    videoPlaying: true,
    videoMuted: true,
    musicPlaying: false
};

const el = {
    progressBar: document.getElementById("progress-bar"),
    progressPercent: document.getElementById("progress-percent"),
    status: document.getElementById("status"),
    serverTitle: document.getElementById("server-title"),
    serverSubtitle: document.getElementById("server-subtitle"),
    centerLogo: document.getElementById("center-logo"),
    loadingLabel: document.getElementById("loading-label"),
    playerCount: document.getElementById("player-count"),
    serverStatus: document.getElementById("server-status"),
    serverPing: document.getElementById("server-ping"),
    labelPlayers: document.getElementById("label-players"),
    labelStatus: document.getElementById("label-status"),
    labelPing: document.getElementById("label-ping"),
    serverInfoPanel: document.getElementById("server-info-panel"),
    socialProfilePanel: document.getElementById("social-profile-panel"),
    socialLinks: document.getElementById("social-links"),
    discordLink: document.getElementById("discord-link"),
    websiteLink: document.getElementById("website-link"),
    profileWrap: document.getElementById("user-profile"),
    profileAvatar: document.getElementById("profile-avatar"),
    profileName: document.getElementById("profile-name"),
    leftRail: document.querySelector(".left-rail"),
    railButtons: Array.from(document.querySelectorAll(".rail-btn")),
    leftContent: document.getElementById("left-content"),
    tipText: document.getElementById("tip-text"),
    tipsPanel: document.getElementById("tips-panel"),
    videoContainer: document.getElementById("video-container"),
    loadingVideo: document.getElementById("loading-video"),
    youtubeContainer: document.getElementById("youtube-container"),
    youtubeFrame: document.getElementById("youtube-frame"),
    galleryOverlay: document.getElementById("gallery-overlay"),
    videoToggle: document.getElementById("video-toggle"),
    videoMute: document.getElementById("video-mute"),
    musicToggle: document.getElementById("music-toggle"),
    musicNext: document.getElementById("music-next"),
    musicAudio: document.getElementById("music-audio"),
    trackTitle: document.getElementById("track-title"),
    mediaControls: document.getElementById("media-controls")
};

function clamp(val, min, max) {
    return Math.min(max, Math.max(min, val));
}

function toUpperSafe(value) {
    return String(value || "").toUpperCase();
}

function setText(node, value) {
    if (node) node.textContent = value;
}

function hide(node) {
    if (node) node.classList.add("is-hidden");
}

function show(node) {
    if (node) node.classList.remove("is-hidden");
}

function setProgress(value) {
    state.progress = clamp(Math.floor(value), 0, 100);
    el.progressBar.style.width = `${state.progress}%`;
    el.progressPercent.textContent = `${state.progress}%`;
}

function updateStatus(message) {
    if (!message) return;
    el.status.textContent = toUpperSafe(message);
}

function parseYouTubeId(url) {
    const raw = String(url || "").trim();
    if (!raw) return "";
    const shortMatch = raw.match(/youtu\.be\/([a-zA-Z0-9_-]{6,})/);
    if (shortMatch) return shortMatch[1];
    const longMatch = raw.match(/[?&]v=([a-zA-Z0-9_-]{6,})/);
    if (longMatch) return longMatch[1];
    const embedMatch = raw.match(/embed\/([a-zA-Z0-9_-]{6,})/);
    if (embedMatch) return embedMatch[1];
    return "";
}

function sendYouTubeCommand(command) {
    if (!el.youtubeFrame || !el.youtubeFrame.contentWindow) return;
    el.youtubeFrame.contentWindow.postMessage(
        JSON.stringify({
            event: "command",
            func: command,
            args: []
        }),
        "*"
    );
}

function updateVideoControlIcons() {
    el.videoToggle.innerHTML = state.videoPlaying
        ? '<i class="fas fa-pause"></i>'
        : '<i class="fas fa-play"></i>';
    el.videoMute.innerHTML = state.videoMuted
        ? '<i class="fas fa-volume-xmark"></i>'
        : '<i class="fas fa-volume-high"></i>';
}

function setupBackground() {
    const background = config.background || {};
    const useYouTube = Boolean(toggles.youtubeBackground);
    const videoFile = background.localVideo || "yt_priv.mp4";

    if (useYouTube) {
        const id = parseYouTubeId(background.youtubeUrl);
        if (id) {
            state.isYouTube = true;
            show(el.youtubeContainer);
            hide(el.videoContainer);
            el.youtubeFrame.src = `https://www.youtube.com/embed/${id}?autoplay=1&mute=1&controls=0&loop=1&playlist=${id}&modestbranding=1&rel=0&playsinline=1&enablejsapi=1`;
        }
    }

    if (!state.isYouTube) {
        show(el.videoContainer);
        hide(el.youtubeContainer);
        const source = el.loadingVideo.querySelector("source");
        source.src = videoFile;
        el.loadingVideo.load();
        el.loadingVideo.muted = true;
        el.loadingVideo.play().catch(() => {});
    }

    updateVideoControlIcons();
}

function setupBackgroundGallery() {
    const background = config.background || {};
    const images = Array.isArray(background.galleryImages) ? background.galleryImages : [];
    const enabled = Boolean(toggles.backgroundGallery && images.length > 0);
    if (!enabled) {
        hide(el.galleryOverlay);
        return;
    }

    show(el.galleryOverlay);
    el.galleryOverlay.classList.add("active");

    const rotate = () => {
        const image = images[state.galleryIndex % images.length];
        if (image) {
            el.galleryOverlay.style.backgroundImage = `url("${image}")`;
        }
        state.galleryIndex = (state.galleryIndex + 1) % images.length;
    };

    rotate();
    setInterval(rotate, Math.max(2500, Number(background.galleryIntervalMs) || 9000));
}

function renderFeedItems(items) {
    const wrap = document.createElement("div");
    wrap.className = "feed-scroll";

    if (!Array.isArray(items) || items.length === 0) {
        const empty = document.createElement("div");
        empty.className = "feed-item";
        empty.textContent = "No entries configured.";
        wrap.appendChild(empty);
        return wrap;
    }

    items.forEach((item) => {
        const card = document.createElement("article");
        card.className = "feed-item";

        const title = document.createElement("h3");
        title.className = "feed-title";
        title.textContent = item.title || "Untitled";

        const date = document.createElement("span");
        date.className = "feed-date";
        date.textContent = item.date || "No date";

        const text = document.createElement("p");
        text.className = "feed-text";
        text.textContent = item.text || "";

        card.append(title, date, text);
        wrap.appendChild(card);
    });

    return wrap;
}

function renderGalleryItems(items) {
    const wrap = document.createElement("div");
    wrap.className = "feed-scroll";

    const grid = document.createElement("div");
    grid.className = "gallery-grid";

    if (!Array.isArray(items) || items.length === 0) {
        const empty = document.createElement("div");
        empty.className = "feed-item";
        empty.textContent = "No gallery images configured.";
        wrap.appendChild(empty);
        return wrap;
    }

    items.forEach((item) => {
        const card = document.createElement("article");
        card.className = "gallery-card";

        const img = document.createElement("img");
        img.src = item.image || "";
        img.alt = item.title || "Gallery image";

        const cap = document.createElement("div");
        cap.className = "gallery-caption";
        cap.textContent = item.title || "Screenshot";

        card.append(img, cap);
        grid.appendChild(card);
    });

    wrap.appendChild(grid);
    return wrap;
}

function renderSection(sectionName) {
    state.currentSection = sectionName;
    el.leftContent.innerHTML = "";

    if (sectionName === "gallery") {
        el.leftContent.appendChild(renderGalleryItems(sections.gallery));
    } else if (sectionName === "events") {
        el.leftContent.appendChild(renderFeedItems(sections.events));
    } else {
        el.leftContent.appendChild(renderFeedItems(sections.news));
    }

    el.railButtons.forEach((button) => {
        button.classList.toggle("active", button.dataset.section === sectionName);
    });
}

function setupSections() {
    const enabledMap = {
        news: Boolean(toggles.news),
        events: Boolean(toggles.events),
        gallery: Boolean(toggles.gallery)
    };

    const enabledSections = [];
    el.railButtons.forEach((button) => {
        const sec = button.dataset.section;
        const enabled = enabledMap[sec];
        button.classList.toggle("is-hidden", !enabled);
        if (enabled) enabledSections.push(sec);
    });

    if (enabledSections.length === 0) {
        hide(el.leftRail);
        hide(el.leftContent);
        return;
    }

    show(el.leftRail);
    show(el.leftContent);

    const initial = enabledSections.includes(state.currentSection)
        ? state.currentSection
        : enabledSections[0];
    renderSection(initial);

    el.railButtons.forEach((button) => {
        button.addEventListener("click", () => {
            const section = button.dataset.section;
            if (enabledMap[section]) {
                renderSection(section);
            }
        });
    });
}

function setupTips() {
    if (!toggles.tips || tips.length === 0) {
        hide(el.tipsPanel);
        return;
    }

    show(el.tipsPanel);
    el.tipText.textContent = tips[0];

    setInterval(() => {
        state.tipIndex = (state.tipIndex + 1) % tips.length;
        el.tipText.textContent = tips[state.tipIndex];
    }, 6500);
}

function updateMusicUI() {
    el.musicToggle.innerHTML = state.musicPlaying
        ? '<i class="fas fa-circle-pause"></i>'
        : '<i class="fas fa-music"></i>';

    const tracks = (config.music && config.music.tracks) || [];
    const track = tracks[state.musicIndex] || {};
    el.trackTitle.textContent = track.title || "No track";
}

function loadTrack(index, autoplay = true) {
    const tracks = (config.music && config.music.tracks) || [];
    if (!tracks.length) return;

    state.musicIndex = ((index % tracks.length) + tracks.length) % tracks.length;
    const track = tracks[state.musicIndex];
    el.musicAudio.src = track.url;
    el.musicAudio.load();

    if (autoplay) {
        el.musicAudio.play().then(() => {
            state.musicPlaying = true;
            updateMusicUI();
        }).catch(() => {
            state.musicPlaying = false;
            updateMusicUI();
        });
    } else {
        state.musicPlaying = false;
        updateMusicUI();
    }
}

function setupMusic() {
    const tracks = (config.music && config.music.tracks) || [];
    if (!toggles.music || tracks.length === 0) {
        el.musicToggle.disabled = true;
        el.musicNext.disabled = true;
        el.trackTitle.textContent = "Music disabled";
        return;
    }

    el.musicAudio.volume = 0.45;
    loadTrack(0, true);

    el.musicToggle.addEventListener("click", () => {
        if (state.musicPlaying) {
            el.musicAudio.pause();
            state.musicPlaying = false;
            updateMusicUI();
            return;
        }
        el.musicAudio.play().then(() => {
            state.musicPlaying = true;
            updateMusicUI();
        }).catch(() => {});
    });

    el.musicNext.addEventListener("click", () => {
        loadTrack(state.musicIndex + 1, true);
    });

    el.musicAudio.addEventListener("ended", () => {
        loadTrack(state.musicIndex + 1, true);
    });
}

function setupVideoControls() {
    el.videoToggle.addEventListener("click", () => {
        if (state.isYouTube) {
            if (state.videoPlaying) {
                sendYouTubeCommand("pauseVideo");
            } else {
                sendYouTubeCommand("playVideo");
            }
        } else if (el.loadingVideo) {
            if (state.videoPlaying) {
                el.loadingVideo.pause();
            } else {
                el.loadingVideo.play().catch(() => {});
            }
        }

        state.videoPlaying = !state.videoPlaying;
        updateVideoControlIcons();
    });

    el.videoMute.addEventListener("click", () => {
        if (state.isYouTube) {
            if (state.videoMuted) {
                sendYouTubeCommand("unMute");
            } else {
                sendYouTubeCommand("mute");
            }
        } else if (el.loadingVideo) {
            el.loadingVideo.muted = !el.loadingVideo.muted;
        }

        state.videoMuted = !state.videoMuted;
        updateVideoControlIcons();
    });
}

async function fetchDiscordProfile() {
    if (!toggles.discordIntegration) return;

    const endpoint = config.discordIntegration && config.discordIntegration.endpoint;
    if (!endpoint) return;

    try {
        const response = await fetch(endpoint, { cache: "no-store" });
        if (!response.ok) return;
        const data = await response.json();
        if (data.name) setText(el.profileName, data.name);
        if (data.avatarUrl) el.profileAvatar.src = data.avatarUrl;
    } catch (error) {
        // Keep fallback profile on request failure.
    }
}

function setupTopPanels() {
    setText(el.labelPlayers, locales.players);
    setText(el.labelStatus, locales.status);
    setText(el.labelPing, locales.ping);
    setText(el.loadingLabel, locales.loading);

    const brand = config.branding || {};
    setText(el.serverTitle, brand.serverName || "PRIMAL NETWORKS");
    setText(el.serverSubtitle, brand.subtitle || "Roleplay Server");
    if (brand.logoUrl) {
        el.centerLogo.src = brand.logoUrl;
    }
    if (brand.accentColor) {
        document.documentElement.style.setProperty("--accent", brand.accentColor);
    }

    const serverInfo = config.serverInfo || {};
    setText(el.playerCount, serverInfo.playerCountText || "0/0");
    setText(el.serverStatus, serverInfo.statusText || "Online");
    setText(el.serverPing, serverInfo.pingText || "-- ms");

    if (!toggles.serverInfo) {
        hide(el.serverInfoPanel);
    } else if (String(serverInfo.pingText || "").includes("--")) {
        setInterval(() => {
            const ping = Math.floor(18 + Math.random() * 31);
            el.serverPing.textContent = `${ping} ms`;
        }, 4500);
    }

    const links = config.links || {};
    el.discordLink.href = links.discord || "#";
    el.websiteLink.href = links.website || "#";

    if (!toggles.socialLinks) {
        hide(el.socialLinks);
    }

    const profile = config.discordProfile || {};
    setText(el.profileName, profile.name || "Connecting...");
    if (profile.avatarUrl) {
        el.profileAvatar.src = profile.avatarUrl;
    }
    if (!toggles.userProfile) {
        hide(el.profileWrap);
    }

    if (!toggles.socialLinks && !toggles.userProfile) {
        hide(el.socialProfilePanel);
    }
}

function applyHandoverProfile() {
    const handover = window.nuiHandoverData || {};
    const discord = handover.discord || (handover.loadscreen && handover.loadscreen.discord);
    if (!discord || typeof discord !== "object") return;

    if (discord.name) {
        setText(el.profileName, discord.name);
    }
    if (discord.avatarUrl) {
        el.profileAvatar.src = discord.avatarUrl;
    }
}

const handlers = {
    startInitFunctionOrder(data) {
        updateStatus("Loading assets...");
        if (data && data.count > 0) setProgress(3);
    },

    initFunctionInvoked(data) {
        if (!data || !data.count) return;
        const pct = (data.idx / data.count) * 100;
        setProgress(pct);
    },

    startDataFileEntries() {
        updateStatus("Parsing data files...");
        if (state.progress < 30) setProgress(30);
    },

    performMapLoadFunction() {
        updateStatus("Loading map...");
        if (state.progress < 60) setProgress(60);
    },

    onLogLine(data) {
        if (data && data.message) updateStatus(data.message);
        if (state.progress < 95) setProgress(state.progress + 0.25);
    }
};

window.addEventListener("message", (event) => {
    const data = event.data || {};
    const fn = handlers[data.eventName];
    if (fn) fn(data);

    if (typeof data.playerCount !== "undefined") {
        setText(el.playerCount, String(data.playerCount));
    }
    if (typeof data.serverStatus !== "undefined") {
        setText(el.serverStatus, String(data.serverStatus));
    }
    if (typeof data.ping !== "undefined") {
        setText(el.serverPing, `${data.ping} ms`);
    }
});

function boot() {
    setupTopPanels();
    applyHandoverProfile();
    setupBackground();
    setupBackgroundGallery();
    setupSections();
    setupTips();
    setupVideoControls();
    setupMusic();
    fetchDiscordProfile();

    const interval = Number(config.discordIntegration && config.discordIntegration.fetchIntervalMs) || 15000;
    if (toggles.discordIntegration && interval > 0) {
        setInterval(fetchDiscordProfile, interval);
    }
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
} else {
    boot();
}
