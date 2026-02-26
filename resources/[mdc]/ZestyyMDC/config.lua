Config = Config or {}

-- Put any website here (your MDC web app)
Config.DefaultUrl = "https://mdc.zestyy.dev"

-- MDC API base URL for server-side calls (OBS, duty logs, etc.)
Config.MdcApiBase = "http://172.17.0.1:3002"
-- Optional shared secret for MDC API requests
Config.MdcApiKey = ""

-- Access control
-- If true, MDC can only be opened from inside a vehicle.
Config.RequireInVehicle = true
-- If true, vehicle must be in `Config.AllowedVehicles` (from `shared.lua`).
Config.RequireAllowedVehicle = true
-- If true, MDC auto-closes if you exit/leave an allowed vehicle while open.
Config.AutoCloseWhenNotAllowed = true
-- Chat message when blocked.
Config.DenyOpenMessage = "MDC can only be opened from an allowed unit vehicle."

-- Keybind to toggle (optional). If nil, only the registered key mapping (F11) is used.
Config.ToggleKey = nil

-- If true, we NEVER destroy/reload the iframe on close; we only hide it.
-- This preserves website session/state.
Config.PersistIframe = true

-- If true, add a cache-buster on first load (helps if CEF caches weirdly)
Config.CacheBustOnFirstLoad = true

-- Force cache busting on every reload (not just first load)
Config.ForceCacheBust = true

-- NUI focus behavior
Config.FocusOnOpen = true
Config.FocusOnClose = true  -- set false if you want mouse to keep working in game immediately

-- Debug
Config.Debug = true

-- Forward MDC web/CEF console errors to the FiveM server console too.
-- (They always print to the client console; this controls server-side printing.)
Config.ForwardConsoleErrorsToServer = true
