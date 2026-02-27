# Ped Director - R* Editor Video Tool

Quick resource for spawning AI peds with animations for Rockstar Editor videos.

## Commands

### Basic Controls
- `/peddirector` - Show help menu with all commands
- `/spawnped [model]` - Spawn a ped at your location (default: a_m_m_skater_01)
- `/deleteped` - Delete the nearest ped (within 5m)
- `/clearallpeds` - Delete all spawned peds

### Animation Controls
- `/pedemote [emote]` - Play emote animation - **USE THIS!** (1636 emotes!)
  - Example: `/pedemote dance`, `/pedemote smoke`, `/pedemote guard`
- `/listemotes` - Show popular emotes (1636 total available!)
- `/pedanim [dict] [anim]` - Play animation directly using dict/anim
  - Example: `/pedanim amb@world_human_smoking@male@male_a@idle_a idle_c`
- `/pedscenario [scenario]` - Play GTA scenario
  - Example: `/pedscenario WORLD_HUMAN_COP_IDLES`
- `/stopanimp` - Stop ped animation

### Positioning
- `/moveped` - Move nearest ped to your current location
- `/freezeped` - Toggle freeze on nearest ped

### Driving & Patrol (Phase 1)
- `/pedvehicle [model]` - Spawn a vehicle and seat nearest ped as driver
- `/pedrouteadd` - Add your current location as a patrol route node
- `/pedrouteclear` - Clear all patrol nodes
- `/pedrouteinfo` - Show current patrol node count
- `/peddrive [wander|towp|patrol|stop] [speed]` - Set nearest ped driving/walking behavior
  - `wander`: random roaming (drives if in vehicle)
  - `towp`: move/drive to current map waypoint
  - `patrol`: loops through nodes made with `/pedrouteadd`
  - `stop`: clears current drive behavior

### Factions & Combat (Phase 1)
- `/pedfaction [civilian|police|gang|guard]` - Apply combat/relationship profile to nearest ped
- `/pedcombat [player|nearest|faction|stop] [factionName]` - Force nearest ped into combat behavior
  - `player`: attack player
  - `nearest`: attack nearest spawned ped
  - `faction [name]`: attack nearest ped of that faction
  - `stop`: clear combat task

## Usage for R* Editor

1. Spawn peds where you want them: `/spawnped s_m_y_cop_01`
2. Move them if needed: `/moveped`
3. Set animations (EASY WAY): `/pedemote dance`
   - Or use full command: `/pedanim [dict] [anim]`
4. Start recording with R* Editor (Alt+F1)
5. When done, clean up: `/clearallpeds`

**Quick Example:**
```
/spawnped s_m_y_cop_01
/pedemote guard
/spawnped a_f_y_bevhills_01
/pedemote phone
Start recording!
```

## Popular Ped Models

- `a_m_m_skater_01` - Skater
- `a_f_y_bevhills_01` - Beverly Hills Girl
- `s_m_y_cop_01` - Police Officer
- `s_m_y_sheriff_01` - Sheriff
- `a_m_y_business_01` - Business Man
- `a_f_m_beach_01` - Beach Girl
- `g_m_y_mexgoon_01` - Gang Member
- `s_m_m_paramedic_01` - Paramedic
- `s_m_y_fireman_01` - Firefighter

## 1636 Available Emotes! (Use with /pedemote)

Type `/listemotes` in-game for popular emotes! Here are some examples:

**ALL rpemotes-reborn animations are included!** Try any emote name from rpemotes.

**Dance:**
- `dance`, `dance2`, `dance3`, `dance4`, `danceslow`, `dancesilly`, `djing`

**Smoking & Drinking:**
- `smoke`, `smoke2`, `cigarette`, `cigar`
- `drink`, `beer`, `coffee`, `wine`, `drinking`, `drinkwhiskey`

**Phone:**
- `phone`, `phonecall`, `phonetext`, `text`, `selfie`

**Sitting:**
- `sit`, `sitchair`, `sit2`, `sitground`, `sitknees`, `sitdrunk`, `sitscared`

**Leaning:**
- `lean`, `lean2`, `leanbar`

**Emotions:**
- `clap`, `slowclap`, `salute`, `wave`, `point`, `shrug`, `facepalm`, `cry`

**Standing Poses:**
- `crossarms`, `crossarms2`, `guard`, `clipboard`, `idle`, `idle2`, `idle3`

**Actions:**
- `pushup`, `situp`, `yoga`, `stretch`, `camera`, `photo`, `film`, `fishing`

**Work:**
- `mechanic`, `workout`, `argue`, `inspect`, `cop`, `cop2`, `traffic`

**Fun:**
- `dab`, `thumbsup`, `peace`, `rock`, `nervous`, `flex`, `knock`

**Special:**
- `mindcontrol`, `cough`, `warmth`, `wait`, `jog`, `jumpingjacks`

## Common Animation Examples

### Smoking
```
/pedanim amb@world_human_smoking@male@male_a@idle_a idle_c
```

### Drinking Beer
```
/pedanim amb@world_human_drinking@beer@male@idle_a idle_c
```

### Phone Call
```
/pedanim cellphone@ cellphone_call_listen_base
```

### Sitting
```
/pedanim anim@heists@prison_heiststation@cop_reactions cop_b_idle
```

### Dance
```
/pedanim anim@amb@nightclub@dancers@podium_dancers@ hi_dance_facedj_17_v2_male^5
```

## Common Scenarios

```
/pedscenario WORLD_HUMAN_COP_IDLES          - Cop standing
/pedscenario WORLD_HUMAN_SMOKING            - Smoking cigarette
/pedscenario WORLD_HUMAN_AA_COFFEE          - Drinking coffee
/pedscenario WORLD_HUMAN_CLIPBOARD          - Holding clipboard
/pedscenario WORLD_HUMAN_CHEERING           - Cheering
/pedscenario WORLD_HUMAN_BINOCULARS         - Using binoculars
/pedscenario WORLD_HUMAN_GUARD_STAND        - Security guard stance
```

## Tips

- **USE /pedemote!** It's way easier - 1636 emotes available!
- Type `/listemotes` to see popular emotes
- Any emote from rpemotes-reborn works (dance, dance2, dance3, etc.)
- Peds are frozen by default to prevent movement
- Use `/freezeped` to unfreeze if you want them to move naturally
- All peds spawn 1 meter in front of you
- Nearest ped detection works up to 10m for animations, 5m for deletion
- Can't find an emote? Try variations like: cop, cop2, cop3 or dance, dance2, dance3
- ALL 1636 rpemotes-reborn animations are included!
