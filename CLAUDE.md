# Pebbleford Hub - Project Instructions

## What This Is
A collection of Roblox exploit/hub scripts for various games, built by **pebbleford**. Each script creates a custom GUI (dark themed) with toggles, sliders, action buttons, and chat commands. All scripts are protected by a shared key system and XOR-obfuscated before pushing to GitHub.

**GitHub repo:** `pebbleford/roblox-scripts` (public, main branch)

## Repository Structure

```
C:\myrobloxgamescripts\
├── src/                    # SOURCE FILES (edit these)
│   ├── synapsex.lua        # Main admin/universal hub (v2.3)
│   ├── rivals.lua          # RIVALS FPS hub (v1.4)
│   ├── mm2.lua             # Murder Mystery 2 hub (v1.1)
│   ├── brookhaven.lua      # Brookhaven hub (v1.0)
│   ├── sharkbite.lua       # SharkBite 2 hub (v1.0)
│   ├── nbtf.lua            # Nuclear Blast Testing Facility hub
│   ├── 99nights.lua        # 99 Nights in the Forest hub
│   ├── elected.lua         # Elected hub
│   └── keysystem.lua       # Shared key system (validates whitelist)
├── obfuscate.py            # XOR obfuscation script
├── *.lua (root)            # OBFUSCATED OUTPUT (auto-generated, don't edit)
├── spinfling.lua           # Standalone spin fling (not obfuscated)
├── esp.lua                 # Standalone ESP loader (not obfuscated)
├── stealabrainrot.lua      # Standalone SAB script
├── stealabrainrot-admin.lua# Standalone SAB admin
├── loader.lua              # Loader script
├── whitelist.txt           # Key whitelist
└── SynapseXApp/            # WPF .NET desktop app (C#)
```

## Workflow: Edit -> Check -> Obfuscate -> Commit -> Push

1. **Edit source files** in `src/` (NEVER edit root .lua files directly)
2. **Syntax check**: `npx luaparse src/FILENAME.lua --no-scope` (output is AST JSON = pass, error = fail)
3. **Obfuscate**: `python obfuscate.py` (reads src/, writes obfuscated to root)
4. **Commit & push**: Stage both `src/FILE.lua` and `FILE.lua`, commit, push

## Adding a New Script
1. Create `src/newscript.lua`
2. Add `"newscript.lua"` to the `SCRIPTS` list in `obfuscate.py`
3. Follow the standard workflow above

## Loadstring Format
All scripts are loaded via:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/pebbleford/roblox-scripts/main/SCRIPTNAME.lua"))()
```

## Key System
All hub scripts start by loading `keysystem.lua` which validates the user's key against `whitelist.txt` on GitHub. The key system uses a Discord webhook for notifications.

## GUI Architecture (all scripts follow this pattern)
- **Color themes**: Each script has its own theme (synapsex=blue, rivals=green, mm2=crimson, brookhaven=orange, sharkbite=blue)
- **COLORS table** at top of each script defines the theme
- **Helper functions** (identical across scripts): `createToggle()`, `createSlider()`, `createSectionLabel()`, `createActionButton()`, `createInfoLabel()`
- **Tab system**: Tabs at top, content frames below, one visible at a time
- **Chat commands**: All start with `!` prefix (e.g., `!speed 50`, `!god`, `!noclip`)
- **Respawn hooks**: `CharacterAdded` connection that re-enables active features after death
- **Log system**: Scrolling log panel at the bottom of the GUI

## Script Versions & Features

### synapsex.lua (v2.3) - Universal Admin Hub
Main hub with: Speed, Fly, Noclip, God Mode (Heartbeat loop), Infinite Jump, ESP, Hitbox Expander, Aimbot, Triggerbot, Car Noclip, Car Fling, Car Speed Boost, Spin Fling, Walk Fling, Emotes, FE Invisible (seat trick), Anti-AFK, Seizure, Headless, plus script loader buttons

### rivals.lua (v1.4) - RIVALS FPS Hub
FPS-specific: Aimbot (with sensitivity multiplier + min movement), Triggerbot, FOV Circle, Kill Aura, Auto Fire, ESP, Hitbox Expander, Chams, No Fog, Speed, Fly, Noclip, God Mode, FE Invisible, Bunny Hop, Gravity, Anti-AFK, Player List with Teleport/Spectate, Walk Fling, Seizure, Headless
- **Team check**: Uses `isActualTeamMode()` that counts teams with players - only filters teammates if 2+ distinct teams exist (handles FFA modes correctly)

### mm2.lua (v1.1) - Murder Mystery 2 Hub
MM2-specific: Role Detection (Murderer/Sheriff/Innocent via backpack scanning), Murderer ESP, Murderer Alert, Auto Shoot Murderer, Gun Drop Detection, Auto Grab Gun, Coin ESP, Auto Coin Farm, Gun ESP, Kill All (Murderer), TP Behind Player, Bring Gun, X-Ray, Trapdoor ESP, Bring Coins, Auto Collect, Player List, Anti-Void, Rainbow Character
- **Flings use Assembly properties** (`AssemblyAngularVelocity`/`AssemblyLinearVelocity`) instead of BodyMovers because MM2 servers detect and remove BodyMover instances
- **Density re-applied every frame** via Heartbeat to counter server physics resets

### brookhaven.lua (v1.0) - Brookhaven Hub
Brookhaven-specific features plus standard movement suite

### sharkbite.lua (v1.0) - SharkBite 2 Hub
SharkBite-specific features plus standard movement suite

## Important Technical Patterns

### FE (Filtering Enabled) Invisibility
Client-side transparency doesn't work for other players. All scripts use the "seat trick":
1. Create invisible Seat at player position
2. Sit humanoid in seat
3. Set `LocalPlayer.Character = nil` (server stops replicating)
4. Reassign character back
5. Undo requires respawn (kill character)

### God Mode
Must use Heartbeat loop continuously setting `MaxHealth`/`Health = math.huge` because servers reset health. One-shot doesn't persist.

### Aimbot (rivals.lua)
- `mousemoverel` pixel values need a sensitivity multiplier (1.5x) because mouse sensitivity varies
- Minimum movement threshold of 1 pixel prevents micro-jitter
- Default smoothing = 2 (lower = more responsive)

### Fling Physics
- For strict games (MM2): Use `AssemblyAngularVelocity`/`AssemblyLinearVelocity` (BasePart properties, can't be instance-removed)
- For lenient games: `BodyAngularVelocity` instances work fine
- Always re-apply `CustomPhysicalProperties` density=100 every frame via Heartbeat

### Team Detection
In FFA modes all players share the same team. `isActualTeamMode()` counts distinct teams with players - only filters if 2+ teams exist.

## Version Bumping
When bumping versions, update ALL locations where the version string appears (usually 4-5 places: title bar, window title, log messages, chat help response).
