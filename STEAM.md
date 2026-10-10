# Steam guide for GLOWLINE

## 1. Testing right now: Spacewar (App ID 480)
Until the game has its own App ID, it uses **Spacewar** (App ID 480), Valve's official test app.
Steam lobbies, lobby codes, friend invites and the Steam relay network (online play without port forwarding)
all work through it. Every Steam account can use Spacewar.

Setting: `scripts/autoload/steam_service.gd` → `const APP_ID := 480`, and the file `steam_appid.txt` (content `480`).

### GodotSteam
GodotSteam 4.23 (GDExtension, includes `SteamMultiplayerPeer`) is already in `addons/godotsteam/`
for Windows, Linux and macOS. Nothing needs to be installed. Docs: https://godotsteam.com

Without Steam running, the game still works. Multiplayer then only runs over LAN (codes that start with `L`).

### Play online with friends
1. Start the Steam client and log in (both players).
2. Start the game → **MULTIPLAYER** → choose a mode (co-op/versus) → **CREATE LOBBY**.
3. A code appears, for example `QX7K2M` → **COPY** it and send it to your friend.
4. Friend: **MULTIPLAYER** → type the code or press **PASTE** → **JOIN**. You can also use **INVITE FRIENDS** (Steam overlay).
5. Everyone else presses **GET READY** → the host presses **START**.

Your Steam name is used automatically as your player name.

Notes on Spacewar: achievements are not set on the test app, because it does not have them.
Leaderboards get the prefix `GLOWLINE_`, so they do not mix with other test games.

## 2. Your own App ID (for the real release)
1. Create a Steamworks partner account: https://partner.steamgames.com (tax and bank details, identity check).
2. Pay the **Steam Direct** fee (USD 100 per game, refunded after USD 1,000 in revenue). You then get an App ID.
3. Enter the App ID: `const APP_ID := <your ID>` in `steam_service.gd` and in `steam_appid.txt`.
4. In Steamworks, under **Stats & Achievements**, create these achievements with exactly these API names:

| API name | Meaning |
|---|---|
| ACH_FIRST_BLOOD | First enemy defeated |
| ACH_KILLS_100 | 100 enemies defeated |
| ACH_KILLS_1000 | 1000 enemies defeated |
| ACH_COMBO_15 | 15 combo |
| ACH_COMBO_40 | 40 combo |
| ACH_WORLD_1 | Neon City boss defeated |
| ACH_WORLD_2 | Dust Sector boss defeated |
| ACH_WIN | Run won |
| ACH_HEAT_3 | Run won on heat 3+ |
| ACH_LOOP | World cleared in endless mode |
| ACH_DAILY | Daily challenge finished |
| ACH_UNTOUCHED | Section without taking damage |
| ACH_RICH | 10,000 credits earned |
| ACH_ARSENAL | All weapons unlocked |
| ACH_BUILD | 12 cards in one run |
| ACH_BOSS_FAST | Boss in under 90 seconds |

5. The game creates the leaderboards (`highscore`, `daily_YYYYMMDD`) automatically.
6. **Steam Input / controller:** in Steamworks, declare "full controller support". The game supports Xbox,
   PlayStation and Switch Pro layouts through Godot, in game and in all menus.
7. **Steam Deck:** 1280×800 is supported (the aspect ratio expands automatically), and controller prompts adapt.
   Text fields open the Steam on-screen keyboard.

## 3. Uploading a build
1. Godot → **Editor → Manage Export Templates** → download.
2. **Project → Export → Windows** → `build/windows/Glowline.exe`.
   GodotSteam adds `steam_api64.dll` automatically. `steam_appid.txt` does **not** belong in a build that you upload to Steam.
3. Download the Steamworks SDK → `tools/ContentBuilder` → fill in the depot scripts with your App ID and depot ID.
4. `steamcmd +login <user> +run_app_build ..\scripts\app_build_<appid>.vdf +quit`
5. In Steamworks, set the build live on a branch (first `beta`, after testing `default`).

## 4. Store page and launch checklist
- **Put a Coming Soon page online early** (months before release). Wishlists are the most important factor for visibility at launch.
- Graphics: header capsule 920×430, small capsule 462×174, main capsule 1232×706, vertical capsule 748×896,
  library capsule 600×900, library hero 3840×1240, logo (transparent PNG). At least 5 screenshots (1920×1080).
- **Trailer** (30–60 s): show gameplay in the first 5 seconds (movement, explosions, destructible terrain, co-op).
- Tags: Action Roguelike, Run and Gun, Platformer, 2D, Neon, Fast-Paced, Co-op, Online Co-Op, PvP, Controller.
- Price: 7–10 € is common for an indie roguelite of this size, with a 10–20 % launch discount.
- Release a **demo** and take part in **Steam Next Fest** (it brings many wishlists).
- Short clips (TikTok, YouTube Shorts, Reddit r/IndieGaming, r/roguelites), a Discord server, and reaching out to streamers and YouTubers.
- Updates after launch (new worlds, weapons, cards) keep the game visible in the Steam lists.
- Credits: the music is CC BY 4.0, so keep the attribution from `CREDITS.md` in the game and on the store page.

**Honest note:** How much a game earns depends mostly on marketing, wishlists and quality.
Many Steam games earn little, while a good indie game with strong marketing can earn much more.
There is no guarantee.
