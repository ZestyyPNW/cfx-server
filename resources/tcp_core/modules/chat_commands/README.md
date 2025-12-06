# SCRP Roleplay Chat Commands

Complete chat command system for immersive roleplay experiences, migrated from CC Chat/CC RP Chat.

## Proximity Commands (15 meters)

### `/me` - First-Person Actions
**Color:** Light Purple (186, 85, 211)  
**Format:** `* PlayerName action.`  
**Range:** 15 meters

**Example:**
```
/me pulls out a glock and aims it
```
**Output:**
```
* John Doe pulls out a glock and aims it.
```

---

### `/do` - Third-Person Descriptions
**Color:** Orange (255, 140, 0)  
**Format:** `* description.`  
**Range:** 15 meters

**Example:**
```
/do The car is red
```
**Output:**
```
* The car is red.
```

Use `/do` for describing the environment, objects, or situations that aren't directly your character's actions.

---

### `/try` - Random Success/Failure Actions
**Color:** Light Blue (100, 200, 255)  
**Format:** `* PlayerName tries to action... (Successful/Failed)`  
**Range:** 15 meters  
**Success Rate:** 50%

**Example:**
```
/try to pick the lock
```
**Possible Outputs:**
```
* John Doe tries to pick the lock... (Successful)
* John Doe tries to pick the lock... (Failed)
```

Use `/try` for actions that have a chance of failure, like lockpicking, jumping gaps, or convincing someone.

---

## Global Commands

### `/ooc` - Out of Character Chat
**Color:** Blue (52, 152, 219)  
**Range:** Global (all players)

**Example:**
```
/ooc Hey, is anyone available for RP?
```
**Output:**
```
[OOC] John Doe: Hey, is anyone available for RP?
```

Use `/ooc` for out-of-character communication with all players on the server.

---

### `/twt` - Twitter Messages
**Color:** Twitter Blue (41, 128, 185)  
**Range:** Global (all players)

**Example:**
```
/twt Just saw the most amazing sunset at the pier!
```
**Output:**
```
[Twitter] @John Doe: Just saw the most amazing sunset at the pier!
```

Use `/twt` for in-character social media posts that all players can see.

---

### `/ad` - Advertisements
**Color:** Yellow (241, 196, 15)  
**Range:** Global (all players)

**Example:**
```
/ad Selling 2015 Honda Civic, low miles, great condition. Call 555-0123
```
**Output:**
```
[Advertisement] John Doe: Selling 2015 Honda Civic, low miles, great condition. Call 555-0123
```

Use `/ad` for in-character advertisements and business promotions.

---

### `/news` - News Broadcasts
**Color:** Red (192, 57, 43)  
**Range:** Global (all players)

**Example:**
```
/news Multiple vehicle collision reported on Route 68, avoid the area
```
**Output:**
```
[Breaking News] Multiple vehicle collision reported on Route 68, avoid the area
```

Use `/news` for breaking news headlines and important announcements.

---

### `/anon` - Anonymous Messages
**Color:** Dark Gray (44, 62, 80)  
**Range:** Global (all players)  
**Note:** Server logs the real sender

**Example:**
```
/anon I witnessed illegal activity at the docks last night
```
**Output:**
```
[Anonymous] I witnessed illegal activity at the docks last night
```

Use `/anon` for anonymous tips or messages. Note: Server admins can see who sent it in logs.

---

## Help Command

Type `/rp` in chat to see a quick reference of all available commands organized by type.

---

## Technical Details

### Proximity Commands
- **Range:** 15 meters
- **Character Names:** Automatically pulled from SCRP_Characters
- **Fallback:** Uses player name if no character loaded
- **Formatting:** Messages use FiveM's built-in `^*` bold formatting

### Global Commands
- **Range:** All players on server
- **Rate Limiting:** 1 second cooldown between messages
- **Max Length:** 256 characters per message
- **Logging:** All messages logged to server console

### Security Features
- Comprehensive input validation
- SQL injection protection
- XSS protection
- Rate limiting to prevent spam
- Anonymous message tracking in server logs

---

## Complete Color Reference

| Command | RGB Color | Hex Color | Description |
|---------|-----------|-----------|-------------|
| **Proximity Commands** |
| `/me` | (186, 85, 211) | #BA55D3 | Light Purple |
| `/do` | (255, 140, 0) | #FF8C00 | Orange |
| `/try` | (100, 200, 255) | #64C8FF | Light Blue |
| **Global Commands** |
| `/ooc` | (52, 152, 219) | #3498DB | Blue |
| `/twt` | (41, 128, 185) | #2980B9 | Twitter Blue |
| `/ad` | (241, 196, 15) | #F1C40F | Yellow |
| `/news` | (192, 57, 43) | #C0392B | Red |
| `/anon` | (44, 62, 80) | #2C3E50 | Dark Gray |

---

## Examples in Action

### Scenario: Meeting someone
```
/me extends hand for a handshake
* John Doe extends hand for a handshake.

/do The person seems nervous
* The person seems nervous.

/try to read their body language
* John Doe tries to read their body language... (Successful)
```

### Scenario: Breaking into a building
```
/me approaches the door quietly
* Sarah Smith approaches the door quietly.

/try to pick the lock
* Sarah Smith tries to pick the lock... (Failed)

/do The lock is rusted and difficult to work with
* The lock is rusted and difficult to work with.

/try to pick the lock again
* Sarah Smith tries to pick the lock... (Successful)
```

### Scenario: Using global commands
```
/ooc Does anyone want to do a car meet at the pier?
[OOC] John Doe: Does anyone want to do a car meet at the pier?

/twt Car meet starting at the pier in 10 minutes! #LosSantos #Cars
[Twitter] @John Doe: Car meet starting at the pier in 10 minutes! #LosSantos #Cars

/ad Custom car mechanic available! Upgrades, repairs, and more. Visit us at Route 68.
[Advertisement] Jane Smith: Custom car mechanic available! Upgrades, repairs, and more. Visit us at Route 68.
```

---

## Migration from CC Chat/CC RP Chat

This system replaces CC Chat and CC RP Chat with native SCRP_Core functionality.

**What's different:**
- No external dependencies required
- Integrated with SCRP_Characters for automatic name detection
- Enhanced security with input validation and rate limiting
- Cleaner formatting using FiveM's native formatting codes
- Better performance with optimized server-side handling

**Compatible commands:**
- ✓ `/me` - Same functionality
- ✓ `/do` - Same functionality  
- ✓ `/ooc` - Same functionality
- ✓ `/twt` - Same functionality (was `/twt` in CC RP Chat)
- ✓ `/ad` - Same functionality
- ✓ `/news` - Same functionality
- ✓ `/anon` - Same functionality (was `/anon` in CC RP Chat)
- ✓ `/try` - NEW: Added success/failure mechanic

**No longer needed:**
- CC Chat dependency
- CC RP Chat resource
- ESX RP Chat
- Any other third-party chat scripts

Simply ensure `SCRP_Core` and remove the old chat resources from your `server.cfg`.

---

## Source

Based on commands from [Concept-Collective/cc-rpchat](https://github.com/Concept-Collective/cc-rpchat) and enhanced for SCRP Framework.
