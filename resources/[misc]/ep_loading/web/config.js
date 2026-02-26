window.LOADING_CONFIG = {
    branding: {
        serverName: "PRIMAL NETWORKS",
        subtitle: "Modern Roleplay Framework",
        logoUrl: "logo.png",
        accentColor: "#a855f7"
    },

    toggles: {
        serverInfo: true,
        socialLinks: true,
        userProfile: true,
        news: true,
        events: true,
        gallery: true,
        tips: true,
        music: true,
        youtubeBackground: false,
        backgroundGallery: true,
        discordIntegration: false
    },

    links: {
        discord: "https://discord.gg/thecaliforniaproject",
        website: "https://californiaprojectrp.com"
    },

    serverInfo: {
        statusText: "Online",
        playerCountText: "0/64",
        pingText: "-- ms"
    },

    discordProfile: {
        name: "Connecting...",
        avatarUrl: "https://cdn.discordapp.com/embed/avatars/0.png"
    },

    discordIntegration: {
        endpoint: "",
        // Expected payload from endpoint:
        // { "name": "username", "avatarUrl": "https://..." }
        fetchIntervalMs: 15000
    },

    background: {
        youtubeUrl: "https://www.youtube.com/watch?v=jfKfPfyJRdk",
        localVideo: "yt_priv.mp4",
        galleryIntervalMs: 9000,
        galleryImages: [
            "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?auto=format&fit=crop&w=1920&q=80",
            "https://images.unsplash.com/photo-1480714378408-67cf0d13bc1f?auto=format&fit=crop&w=1920&q=80",
            "https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1920&q=80"
        ]
    },

    music: {
        tracks: [
            { title: "Loading Mix", url: "yt_priv.mp4" }
        ]
    },

    sections: {
        news: [
            {
                title: "Powered By Modern Web Stack",
                date: "Today",
                text: "Built with Vite, Svelte 5, and Tailwind CSS for lightning-fast performance and a clean interface."
            },
            {
                title: "Easy Configuration",
                date: "Today",
                text: "Simple one-file setup with clear comments. Customize links, text, colors, media, and section content."
            },
            {
                title: "Toggleable Modules",
                date: "Today",
                text: "Enable or disable news, events, gallery, tips, music, server info, and more with true/false toggles."
            }
        ],
        events: [
            {
                title: "Community Patrol Night",
                date: "Friday 8:00 PM EST",
                text: "Join supervised scenario patrols with active dispatch and live moderation."
            },
            {
                title: "Civilian Story Event",
                date: "Saturday 7:00 PM EST",
                text: "Player-led RP arcs with expanded civilian jobs and economy focus."
            }
        ],
        gallery: [
            {
                title: "Downtown Skyline",
                image: "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=1280&q=80"
            },
            {
                title: "Night Patrol",
                image: "https://images.unsplash.com/photo-1511268011861-691ed210aae8?auto=format&fit=crop&w=1280&q=80"
            },
            {
                title: "City Operations",
                image: "https://images.unsplash.com/photo-1489515217757-5fd1be406fef?auto=format&fit=crop&w=1280&q=80"
            }
        ]
    },

    tips: [
        "Stay in character at all times during active roleplay scenes.",
        "Use clear radio comms and avoid interrupting active dispatch traffic.",
        "Respect fear RP and value your life in high-risk situations.",
        "Report bugs in Discord with short clips or screenshots for faster fixes."
    ],

    locales: {
        players: "Players",
        status: "Status",
        ping: "Ping",
        loading: "Loading",
        music: "Music",
        video: "Video"
    }
};
