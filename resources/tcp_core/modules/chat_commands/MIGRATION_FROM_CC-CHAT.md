# Migration from CC-Chat & CC-RP Chat to SCRP_Core

## Overview

SCRP_Core now **completely replaces** both CC-Chat and CC-RP Chat. All functionality has been integrated directly into SCRP_Core's chat commands module with improved security, performance, and features.

---

## What Has Been Migrated

### ✅ From CC-Chat

1. **Custom Chat Theme**
   - Custom message template with color boxes and icons
   - Modern Source Sans 3 font styling
   - Noisy background texture
   - Notification-style message boxes
   - **Location:** `SCRP_Core/modules/chat_commands/theme/style.css`

2. **Timestamp Function**
   - 12-hour format with AM/PM
   - Exported as `exports.SCRP_Core:getTimestamp()`
   - **Location:** `SCRP_Core/modules/chat_commands/client/main.lua`

3. **Chat Logging** (Optional)
   - Saves all chat messages to file with timestamps
   - Configurable via `ENABLE_CHAT_LOGGING` flag
   - **Location:** `SCRP_Core/modules/chat_commands/server/main.lua`

4. **Anti-Spam System**
   - Enhanced to include rate limiting (1 message per second)
   - Server-side validation and duplicate detection
   - **Location:** `SCRP_Core/modules/chat_commands/server/main.lua`

### ✅ From CC-RP Chat

1. **All RP Commands**
   - `/me` - Describe actions (purple, 15m range)
   - `/do` - Describe surroundings/situations (orange, 15m range)
   - `/try` - Attempt actions with 50/50 success (light blue, 15m range)
   - `/whisper` or `/w` - Quiet voice (5m range)
   - `/low` or `/q` - Low voice (10m range)
   - `/shout` or `/s` - Loud voice (30m range)
   - `/emote` or `/em` - Physical actions (15m range)

2. **Global Commands**
   - `/ooc` - Out of character chat (blue, global)
   - `/twt` - Twitter/social media (twitter blue, global)
   - `/ad` - Advertisements (yellow, global)
   - `/news` - Breaking news broadcasts (red, global)
   - `/anon` - Anonymous messages (dark, global, logged separately)

3. **Help System**
   - `/rp` - Comprehensive command list with descriptions

---

## New Features (Not in CC-Chat/CC-RP Chat)

### Enhanced Security
- **Input Validation:** All messages validated for type, length, and content
- **Rate Limiting:** 1 message per second per player
- **Color Validation:** RGB values checked to prevent exploits
- **Range Validation:** Distance checks prevent abuse

### Better UX
- **Text Shadows:** Multi-layer shadows for better readability
- **Smooth Animations:** Fade-in/slide-down for new messages, fade-out/slide-up for expiring messages
- **Native Formatting:** Uses FiveM's `^*` bold codes (no HTML/BBCode exposed)
- **Improved /try:** Natural language success/failure messages

### Performance
- **No Middleware:** Direct event handling (faster than cc-rpchat)
- **Optimized Proximity:** Efficient distance calculations
- **Clean Code:** No redundant checks or unused functions

---

## Architecture

```
FiveM Default Chat (resources/chat/)
    └── Handles: UI rendering, input, display
    └── Your customizations: Custom CSS in index.css

SCRP_Core/modules/chat_commands/
    ├── client/main.lua          → All RP commands, timestamp export
    ├── server/main.lua          → Message routing, validation, logging
    ├── theme/style.css          → Chat theme (replaces cc-chat)
    └── README.md                → Documentation

SCRP_Core/fxmanifest.lua
    └── Registers 'scrpChat' theme (replaces cc-chat theme)
```

---

## Configuration

### Enable Chat Logging

Edit `SCRP_Core/modules/chat_commands/server/main.lua`:

```lua
local ENABLE_CHAT_LOGGING = true  -- Set to true to enable chat logging to file
```

Logs will be saved to: `SCRP_Core/modules/chat_commands/chat_log.log`

### Adjust Rate Limiting

Edit `SCRP_Core/modules/chat_commands/server/main.lua`:

```lua
local RATE_LIMIT_TIME = 1000  -- Time in milliseconds (1000 = 1 second)
```

### Change Message Ranges

Edit the command in `SCRP_Core/modules/chat_commands/client/main.lua`:

```lua
-- Example: Change /me range from 15m to 20m
TriggerServerEvent('scrp:chat:sendProximityMessage', formattedMessage, Colors.me, 20.0)
```

---

## Removing CC-Chat & CC-RP Chat

### Step 1: Stop the Resources

If they're running, stop them:
```
stop cc-chat
stop cc-rpchat
```

### Step 2: Remove from server.cfg

Remove or comment out these lines:
```cfg
# ensure cc-chat
# ensure cc-rpchat
```

### Step 3: Delete the Folders

You can safely delete:
- `resources/[chat]/cc-chat/`
- `resources/[chat]/cc-rpchat/`

### Step 4: Restart SCRP_Core

```
restart SCRP_Core
```

---

## Exports

### Get Timestamp
```lua
-- From any resource
local timestamp = exports.SCRP_Core:getTimestamp()
-- Returns: "3:45 PM"
```

---

## Comparison

| Feature | CC-Chat + CC-RP Chat | SCRP_Core |
|---------|---------------------|-----------|
| Custom Theme | ✅ | ✅ |
| RP Commands | ✅ | ✅ + More |
| Global Commands | ❌ | ✅ |
| Input Validation | ⚠️ Basic | ✅ Comprehensive |
| Rate Limiting | ⚠️ Basic | ✅ Advanced |
| Animations | ❌ | ✅ |
| Text Shadows | ❌ | ✅ |
| Natural /try Output | ❌ | ✅ |
| Dependencies | 2 Resources | 0 (built-in) |
| Maintenance | External | Internal |

---

## Troubleshooting

### Chat theme not showing?
1. Ensure `chat` resource is started before SCRP_Core
2. Check `server.cfg` has: `ensure chat` before `ensure SCRP_Core`
3. Restart both: `restart chat` then `restart SCRP_Core`

### Commands not working?
1. Check console for errors
2. Ensure SCRP_Core is fully started
3. Try: `restart SCRP_Core`

### Messages not logging?
1. Check `ENABLE_CHAT_LOGGING = true` in server/main.lua
2. Ensure SCRP_Core has write permissions
3. Check `SCRP_Core/modules/chat_commands/chat_log.log`

---

## Summary

**SCRP_Core is now a complete, standalone chat system.** You no longer need CC-Chat or CC-RP Chat. Everything they provided (and more) is now built directly into your core framework with better security, performance, and features.

**Restart:** `restart SCRP_Core`
**Delete:** CC-Chat and CC-RP Chat folders (optional, but recommended)

---

*Last Updated: October 24, 2025*
*SCRP_Core Version: 1.0.0*

