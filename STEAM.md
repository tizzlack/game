# Steam-Anleitung für GLOWLINE

## 1. Jetzt sofort testen: Spacewar (App-ID 480)
Solange du keine eigene App-ID hast, nutzt das Spiel **Spacewar** (App-ID 480), die offizielle Test-App von Valve.
Damit funktionieren Steam-Lobbys, Lobby-Codes, Freundes-Einladungen und das Steam-Relay-Netzwerk
(Online-Spiel ohne Portfreigabe). Jeder Steam-Account kann Spacewar nutzen.

Einstellung: `scripts/autoload/steam_service.gd` → `const APP_ID := 480` und die Datei `steam_appid.txt` (Inhalt `480`).

### GodotSteam installieren
1. Godot öffnen → **AssetLib** → nach **GodotSteam** suchen.
2. **GodotSteam GDExtension** (passend zu Godot 4.4) installieren.
3. Zusätzlich **GodotSteam MultiplayerPeer** installieren (liefert `SteamMultiplayerPeer` für das Online-Spiel).
4. Editor neu starten. Doku: https://godotsteam.com

Ohne GodotSteam läuft das Spiel trotzdem. Der Multiplayer funktioniert dann nur im LAN (Code mit `L…`).

### Online mit Freunden testen
1. Steam-Client starten und einloggen (bei beiden Spielern).
2. Spiel starten → **MULTIPLAYER** → Modus wählen (Koop/Versus) → **LOBBY ERSTELLEN**.
3. Es erscheint ein Code, z. B. `QX7K2M` → **KOPIEREN** und an den Freund schicken.
4. Freund: **MULTIPLAYER** → Code eingeben → **BEITRETEN**. Alternativ: **FREUNDE EINLADEN** (Steam-Overlay).
5. Alle auf **BEREIT** → Host drückt **START**.

Hinweise zu Spacewar: Erfolge werden auf der Test-App nicht gesetzt (die gibt es dort nicht).
Bestenlisten bekommen das Präfix `GLOWLINE_`, damit sie sich nicht mit anderen Test-Spielen überschneiden.

## 2. Eigene App-ID (für den echten Release)
1. Steamworks-Partnerkonto anlegen: https://partner.steamgames.com (Steuer- und Bankdaten, Identitätsprüfung).
2. **Steam Direct**-Gebühr bezahlen (100 USD pro Spiel, wird ab 1.000 USD Umsatz zurückerstattet) → du bekommst eine App-ID.
3. App-ID eintragen: `const APP_ID := <deine ID>` in `steam_service.gd` und in `steam_appid.txt`.
4. In Steamworks unter **Stats & Achievements** diese Erfolge mit genau diesen API-Namen anlegen:

| API-Name | Bedeutung |
|---|---|
| ACH_FIRST_BLOOD | Ersten Gegner besiegt |
| ACH_KILLS_100 | 100 Gegner besiegt |
| ACH_KILLS_1000 | 1000 Gegner besiegt |
| ACH_COMBO_15 | 15er-Kombo |
| ACH_COMBO_40 | 40er-Kombo |
| ACH_WORLD_1 | Boss von Neon City besiegt |
| ACH_WORLD_2 | Boss des Staubsektors besiegt |
| ACH_WIN | Run gewonnen |
| ACH_HEAT_3 | Run auf Hitze 3+ gewonnen |
| ACH_LOOP | Welt im Endlos-Modus geschafft |
| ACH_DAILY | Tägliche Herausforderung beendet |
| ACH_UNTOUCHED | Abschnitt ohne Schaden |
| ACH_RICH | 10.000 Credits verdient |
| ACH_ARSENAL | Alle Waffen freigeschaltet |
| ACH_BUILD | 12 Karten in einem Run |
| ACH_BOSS_FAST | Boss in unter 90 Sekunden |

5. Bestenlisten (`highscore`, `daily_JJJJMMTT`) werden vom Spiel automatisch angelegt.
6. **Steam Input / Controller:** In Steamworks „volle Controller-Unterstützung“ angeben. Das Spiel unterstützt Xbox-, PlayStation- und Switch-Pro-Layouts über Godot.
7. **Steam Deck:** 1280×800 wird unterstützt (Seitenverhältnis wird automatisch erweitert), Controller-Hinweise passen sich an.

## 3. Build hochladen
1. Godot → **Editor → Exportvorlagen verwalten** → herunterladen.
2. **Projekt → Exportieren → Windows** → `build/windows/Glowline.exe`.
   GodotSteam legt `steam_api64.dll` automatisch dazu. `steam_appid.txt` gehört **nicht** in den Release-Build.
3. Steamworks-SDK herunterladen → `tools/ContentBuilder` → Depot-Skripte mit deiner App-ID und Depot-ID füllen.
4. `steamcmd +login <user> +run_app_build ..\scripts\app_build_<appid>.vdf +quit`
5. In Steamworks den Build auf einen Branch setzen (erst `beta`, nach Test `default`).

## 4. Store-Seite und Launch-Checkliste
- **Coming-Soon-Seite früh online stellen** (Monate vor Release). Wunschlisten sind der wichtigste Faktor für die Sichtbarkeit zum Start.
- Grafiken: Header-Kapsel 920×430, kleine Kapsel 462×174, Hauptkapsel 1232×706, vertikale Kapsel 748×896,
  Bibliothek 600×900, Bibliothek-Hero 3840×1240, Logo (PNG, transparent). Mindestens 5 Screenshots (1920×1080).
- **Trailer** (30–60 s): in den ersten 5 Sekunden Gameplay zeigen (Movement, Explosionen, zerstörbares Gelände, Koop).
- Tags: Action Roguelike, Run and Gun, Platformer, 2D, Neon, Fast-Paced, Co-op, Online Co-Op, PvP, Controller.
- Preis: Für ein Indie-Roguelite dieser Größe sind 7–10 € üblich, Launch-Rabatt 10–20 %.
- **Demo** veröffentlichen und beim **Steam Next Fest** mitmachen (bringt viele Wunschlisten).
- Kurzclips (TikTok, YouTube Shorts, Reddit r/IndieGaming, r/roguelites), Discord-Server, Streamer und YouTuber anschreiben.
- Updates nach dem Launch (neue Welten, Waffen, Karten) halten das Spiel in den Steam-Listen.

**Ehrlicher Hinweis:** Wie viel ein Spiel verdient, hängt vor allem von Marketing, Wunschlisten und Qualität ab.
Viele Steam-Spiele verdienen wenig, ein gutes Indie-Spiel mit starker Vermarktung kann aber deutlich mehr erreichen.
Eine Garantie gibt es nicht.
