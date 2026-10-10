# GLOWLINE – Neon Run & Gun

A fast 2D roguelite run & gun in a glowing neon vector style, made with **Godot 4.4** (GDScript, Compatibility renderer).
Play solo, in online co-op with up to 4 players, or against your friends in versus.

**[Download the latest Windows build](../../releases/latest)**: unzip it, start Steam, then run `Glowline.exe`.

## Features
- **Neon look:** glowing lines with bloom, white-hot tube cores, particles, star flashes, enemies that shatter into pieces
- **Destructible terrain:** every hit punches stair-shaped holes into the ground, and debris flies
- **Movement:** coyote time, jump buffering, half gravity at the apex, fast fall, wall slide and wall jump,
  slide (it speeds up downhill), slide jump, 8-way dash, super jump, ground slam, corner correction, ledge pop-up, launch pads
- **Levels:** generated from hand-made building blocks: mountains, canyons, wall-jump shafts, slide tunnels, dash gaps,
  launch pads, ramps, pillars, breakable floors with secret stashes, rooftops and platforms
- **Roguelite:** 3 worlds (3 sections + a boss each), a card pick after every section (23 cards),
  a workshop with permanent upgrades, 5 weapons, 7 glow colors, heat levels, mutators and an endless mode
- **Daily challenge** with a fixed seed and a streak counter
- **Playable tutorial** that teaches every move
- **Multiplayer:** co-op (2–4 players) and versus over a Steam lobby code (or LAN)
- **Full controller support** in game and menus, with vibration and aim assist
- German and English, 16 achievements (Steam ready)

## Controls
| Action | Keyboard / mouse | Controller |
|---|---|---|
| Move | A / D | Left stick |
| Jump / wall jump | Space | A |
| Aim / shoot | Mouse / left click | Right stick / RT |
| Dash (8 directions) | Shift or right click | B / LB |
| Slide | S while running | Stick down while running |
| Ground slam | S + Shift in the air | Stick down + B in the air |
| Drop through a platform | S + Space | Stick down + A |
| Pause | Esc | Start |
| Menus | Mouse / arrow keys, Enter, Esc | D-pad or stick, A = confirm, B = back |

## Play with a friend (Steam)
1. Both players: start Steam and log in, then start `Glowline.exe`.
2. Host: **MULTIPLAYER** → choose **CO-OP** or **VERSUS** → **CREATE LOBBY** → **COPY** the 6-letter code and send it to your friend.
3. Friend: **MULTIPLAYER** → type the code or press **PASTE** → **JOIN** → **GET READY**.
4. Host presses **START**.

Your Steam name is used as your player name. Until the game has its own Steam App ID, it runs through Valve's test app
**Spacewar** (App ID 480), so Steam shows "Spacewar" while you play. That is expected. See [STEAM.md](STEAM.md).

## Run from source
1. Install Godot **4.4.1** (or a newer 4.x): https://godotengine.org
2. Open the folder in Godot (`project.godot`) and press Play (F5).

## Project layout
```
scenes/main.tscn            entry point (everything else is built in code)
scripts/autoload/           Save, Loc (L), Controls, Audio (Sfx), SteamService, Run, Net
scripts/core/               data (weapons, cards, achievements …), neon drawing helpers, stick figures
scripts/world/              level generator, destructible terrain, background, props
scripts/game/               game scene, bullets, effects, pickups, post shader
scripts/player/             player, network players
scripts/enemies/            walker, brute, gunner, sniper, turret, drone, boss, training dummy
scripts/ui/                 HUD, menus, cards, results, options, credits
scripts/dev/autotest.gd     test bot
tools/build_audio.py        downloads and converts the free sounds and music
addons/godotsteam/          GodotSteam 4.23 (GDExtension, includes SteamMultiplayerPeer)
```

## Testing with the bot
```bash
# single player, 60 s, invincible, screenshot every 3 s
godot --path . -- --autotest --time=60 --god --every=3 --shots=/tmp/shots
# force specific level blocks
godot --path . -- --autotest --god --chunks=shaft,tunnel,dash_gap,pad_cliff,downhill,pillars,weak
# go straight to the boss
godot --path . -- --autotest --section=3 --god
# click through the menus / test menu navigation with a simulated controller
godot --path . -- --autotest --mode=menu --shots=/tmp/menu
godot --headless --path . -- --autotest --mode=pad
# local multiplayer: two instances
godot --headless --path . -- --autotest --net=host --netmode=coop --god &
godot --headless --path . -- --autotest --net=join --god
```

## Sounds and music
Sound effects by **Kenney** (CC0) and music by **Kevin MacLeod** (CC BY 4.0). Full attribution is in [CREDITS.md](CREDITS.md)
and in the game under **CREDITS**. To download and rebuild all audio files:
```bash
python3 tools/build_audio.py    # needs ffmpeg and numpy
```

## Export and releases
Every push to the development branch builds the Windows version with GitHub Actions
(`.github/workflows/release.yml`) and publishes it as a new [release](../../releases).
To export by hand: Godot → Editor → Manage Export Templates → download, then Project → Export → "Windows" or "Linux"
(presets are in `export_presets.cfg`, output goes to `build/`).

## Licenses
- Code and graphics: made for this project
- Music: Kevin MacLeod (incompetech.com), CC BY 4.0
- Sound effects: Kenney (www.kenney.nl), CC0
- Fonts: Inter (SIL OFL 1.1), DejaVu Sans Mono (Bitstream Vera license). The license texts are in `assets/fonts/`
- Godot Engine and GodotSteam: MIT

Details: [CREDITS.md](CREDITS.md)
