# SCRP Chat Commands - Updates & Improvements

## 🎨 Font & Visual Improvements

### New Font: Inter
The chat now uses **Inter**, a modern, highly-readable font designed specifically for UI/UX.

**Benefits:**
- ✓ Superior readability at all sizes
- ✓ Better letter spacing and kerning
- ✓ Modern, clean aesthetic
- ✓ Optimized for digital screens
- ✓ Excellent bold weight clarity

### Enhanced Text Rendering
- **Text Shadow:** Improved readability with double-layer shadow for better contrast
- **Font Weight:** Medium (500) for regular text, Bold (700) for prefixes
- **Line Height:** Increased to 1.4 for better spacing
- **Letter Spacing:** 0.015em for improved legibility
- **Optimized Rendering:** antialiased with optimizeLegibility

---

## 🎭 Improved `/try` Command

**Old Format:**
```
* John Doe tries to pick the lock... (Successful)
* John Doe tries to pick the lock... (Failed)
```

**New Format:**
```
* John Doe would successfully pick the lock and succeed.
* John Doe would pick the lock and fail.
```

The new format is more natural, narrative, and immersive!

---

## 🗣️ NEW Speech Commands (Lively RP!)

### `/whisper` or `/w` - Whisper (5m range)
**Color:** Gray (169, 169, 169)  
**Format:** `John Doe whispers: message`  
**Range:** 5 meters

Perfect for quiet, secretive conversations.

**Example:**
```
/whisper I have the package
/w Meet me behind the building
```
**Output:**
```
John Doe whispers: I have the package
```

---

### `/low` or `/q` - Quiet Speech (8m range)
**Color:** Light Steel Blue (176, 196, 222)  
**Format:** `John Doe says quietly: message`  
**Range:** 8 meters

For speaking in a normal but quiet tone.

**Example:**
```
/low We should be careful here
/q I think someone is watching
```
**Output:**
```
John Doe says quietly: We should be careful here
```

---

### `/shout` or `/s` - Shout (30m range)
**Color:** Tomato Red (255, 99, 71)  
**Format:** `John Doe shouts: MESSAGE` (auto-caps)  
**Range:** 30 meters

For yelling, emergencies, or getting attention.

**Example:**
```
/shout Stop right there!
/s Help! Someone call the police!
```
**Output:**
```
John Doe shouts: STOP RIGHT THERE!
John Doe shouts: HELP! SOMEONE CALL THE POLICE!
```

---

### `/emote` or `/em` - Visual Emotes (15m range)
**Color:** Light Pink (255, 182, 193)  
**Format:** `* John Doe action`  
**Range:** 15 meters

Alternative to `/me` for describing actions and expressions.

**Example:**
```
/emote laughs nervously
/em nods in agreement
```
**Output:**
```
* John Doe laughs nervously
* John Doe nods in agreement
```

---

## 📊 Complete Command Reference

### Roleplay Actions (Proximity)
| Command | Alias | Range | Color | Description |
|---------|-------|-------|-------|-------------|
| `/me` | - | 15m | Light Purple | First-person action |
| `/emote` | `/em` | 15m | Light Pink | Visual emote |
| `/do` | - | 15m | Orange | Scene description |
| `/try` | - | 15m | Light Blue | Success/failure action |

### Speech Commands (Proximity)
| Command | Alias | Range | Color | Description |
|---------|-------|-------|-------|-------------|
| `/whisper` | `/w` | 5m | Gray | Quiet whisper |
| `/low` | `/q` | 8m | Light Steel Blue | Quiet speech |
| Normal chat | - | 15m | Default | Regular speech |
| `/shout` | `/s` | 30m | Tomato Red | Loud yelling (CAPS) |

### Global Commands
| Command | Range | Color | Description |
|---------|-------|-------|-------------|
| `/ooc` | Global | Blue | Out of character |
| `/twt` | Global | Twitter Blue | Twitter post |
| `/ad` | Global | Yellow | Advertisement |
| `/news` | Global | Red | News broadcast |
| `/anon` | Global | Dark Gray | Anonymous message |

---

## 🎯 Usage Examples

### Immersive RP Scenario

```
/whisper Stay close to me
John Doe whispers: Stay close to me

/low I hear something up ahead
John Doe says quietly: I hear something up ahead

/me draws weapon slowly
* John Doe draws weapon slowly

/try to peek around the corner without being seen
* John Doe would successfully peek around the corner without being seen and succeed.

/do Footsteps can be heard approaching from the left
* Footsteps can be heard approaching from the left

/shout Police! Put your hands up!
John Doe shouts: POLICE! PUT YOUR HANDS UP!

/emote takes cover behind a car
* John Doe takes cover behind a car
```

### Social RP Scenario

```
/me walks into the bar
* John Doe walks into the bar

/low Anyone seen the bartender?
John Doe says quietly: Anyone seen the bartender?

/emote waves at a friend across the room
* John Doe waves at a friend across the room

/do The music is loud and the place is crowded
* The music is loud and the place is crowded

/shout Hey! Over here!
John Doe shouts: HEY! OVER HERE!

/twt Great night at the Downtown Bar! #LosSantos #Nightlife
[Twitter] @John Doe: Great night at the Downtown Bar! #LosSantos #Nightlife
```

---

## 🔧 Technical Changes

### Files Modified
- `client/main.lua` - Added 4 new proximity commands with shorthand aliases
- `server/main.lua` - No changes needed (uses existing proximity handler)
- `README.md` - Updated with new commands
- `/resources/chat/html/index.css` - Changed font to Inter, improved styling

### Font Files
- Added Google Fonts import for Inter font family
- Font weights: 400 (regular), 500 (medium), 600 (semi-bold), 700 (bold)
- Fallback fonts: System UI fonts for instant loading

### Performance
- ✓ Zero linter errors
- ✓ No performance impact (commands are client-triggered, server-validated)
- ✓ Efficient range checking with existing proximity system
- ✓ Font loads asynchronously without blocking

---

## 🎨 Why These Changes Make RP More "Lively"

### 1. **Realistic Speech Ranges**
Real conversations have different volumes:
- Whisper (5m) - For secrets and close talks
- Quiet (8m) - For normal quiet conversation
- Normal (15m) - Standard RP range
- Shout (30m) - For emergencies and getting attention

### 2. **Visual Variety**
Different colors and formats help players quickly identify:
- What type of action is happening
- How far the message travels
- The tone/mood of the interaction

### 3. **Shorthand Aliases**
Quick typing for faster RP:
- `/w` instead of `/whisper`
- `/q` instead of `/low`
- `/s` instead of `/shout`
- `/em` instead of `/emote`

### 4. **Auto-Capitalization for Shouts**
Shouted messages automatically convert to CAPS, making them visually distinct and more impactful.

### 5. **Better `/try` Narration**
The new format reads like a story: "would successfully... and succeed" or "would... and fail" - much more immersive than "(Successful)" or "(Failed)".

### 6. **Modern, Readable Font**
Inter font provides:
- Better readability at small sizes
- Clearer distinction between similar characters
- Professional, modern appearance
- Excellent bold weight for emphasis

---

## 🚀 How to Use

Simply restart the chat and SCRP_Core resources:
```
restart chat
restart SCRP_Core
```

All commands are immediately available. Type `/rp` in chat to see the complete command list!

---

## 📈 Summary of Improvements

**Before:**
- 3 proximity commands
- 5 global commands
- Standard Lato font
- Basic `/try` format

**After:**
- 8 proximity commands (3 original + 4 new speech + 1 new emote)
- 5 global commands (unchanged)
- Modern Inter font with enhanced styling
- Narrative `/try` format
- Shorthand aliases for quick RP
- Varied speech ranges for realism

---

## 💡 Tips for Better RP

1. **Use appropriate ranges:**
   - Secrets? Use `/whisper`
   - Normal conversation? Use `/low` or regular chat
   - Emergency? Use `/shout`

2. **Combine commands:**
   - Mix `/me`, `/do`, and `/emote` for rich storytelling
   - Use `/try` for uncertain actions

3. **Consider context:**
   - Don't whisper in a loud nightclub (use `/shout`)
   - Don't shout in a library (use `/whisper` or `/low`)

4. **Experiment with narration:**
   - `/try` creates interesting story moments
   - `/do` adds environmental detail
   - `/emote` shows non-verbal communication

---

Created with attention to perfection for SCRP Framework 🎯

