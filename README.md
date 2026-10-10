# GLOWLINE – Neon Run & Gun

2D-Roguelite-Run-and-Gun im Neon-Vektor-Look, gebaut mit **Godot 4.4** (GDScript, Compatibility-Renderer).

## Features
- **Look:** leuchtende Linien mit Bloom, weißer Neonröhren-Kern, Partikel, Sternblitze, zerspringende Gegner
- **Zerstörbares Gelände:** jeder Treffer stanzt treppenförmige Löcher, Splitter fliegen
- **Movement:** Coyote-Time, Sprungpuffer, halbe Schwerkraft am Scheitel, Schnellfall, Wall-Slide und Walljump,
  Rutschen (bergab mit Beschleunigung), 8-Richtungs-Dash, Super-Sprung, Ground-Slam, Ecken-Korrektur, Kanten-Hochziehen
- **Level:** prozedural aus Bausteinen: Berge, Schluchten, Wall-Jump-Schächte, Rutsch-Tunnel, Dash-Lücken,
  Sprungfelder, Schanzen, Säulen, brüchige Böden mit Geheimfach, Dächer, Plattformen
- **Roguelite:** 3 Welten × (3 Abschnitte + Boss), Kartenwahl nach jedem Abschnitt (23 Karten),
  Werkstatt mit dauerhaften Upgrades, 5 Waffen, 7 Leuchtfarben, Hitze-Stufen, Modifikatoren, Endlos-Modus
- **Tägliche Herausforderung** mit festem Seed und Serien-Zähler
- **Multiplayer:** Koop (2–4) und Versus über Steam-Lobby-Code oder LAN
- **Controller-Support** mit Vibration und Zielhilfe, Deutsch/Englisch, 16 Erfolge (Steam-fähig)

## Starten
1. Godot **4.4.1** (oder neuer 4.x) installieren: https://godotengine.org
2. Ordner in Godot öffnen (`project.godot`), Play (F5).

## Steuerung
| Aktion | Tastatur/Maus | Controller |
|---|---|---|
| Laufen | A / D | Linker Stick |
| Springen / Walljump | Leertaste | A |
| Zielen / Schießen | Maus / Linksklick | Rechter Stick / RT |
| Dash (8 Richtungen) | Shift oder Rechtsklick | B / LB |
| Rutschen | S beim Laufen | Stick runter beim Laufen |
| Ground-Slam | in der Luft S + Shift | Stick runter + B |
| Durch Plattform | S + Leertaste | Stick runter + A |
| Pause | Esc | Start |

## Projektstruktur
```
scenes/main.tscn            Einstieg (alles andere wird im Code gebaut)
scripts/autoload/           Save, Loc (L), Controls, Audio (Sfx), SteamService, Run, Net
scripts/core/               Daten (Waffen, Karten, Erfolge …), Neon-Zeichenhilfen, Strichfiguren
scripts/world/              Levelgenerator, zerstörbares Gelände, Hintergrund, Requisiten
scripts/game/               Spielszene, Kugeln, Effekte, Pickups, Post-Shader
scripts/player/             Spieler, Mitspieler im Netz
scripts/enemies/            Läufer, Koloss, Schütze, Scharfschütze, Geschütz, Drohne, Boss
scripts/ui/                 HUD, Menüs, Karten, Ergebnis, Optionen
scripts/dev/autotest.gd     Testbot
tools/gen_audio.py          erzeugt alle Sounds und Musik (numpy)
```

## Tests mit dem Bot
```bash
# Einzelspieler, 60 s, unverwundbar, Screenshots alle 3 s
godot --path . -- --autotest --time=60 --god --every=3 --shots=/tmp/shots
# bestimmte Level-Bausteine erzwingen
godot --path . -- --autotest --god --chunks=shaft,tunnel,dash_gap,pad_cliff,downhill,pillars,weak
# Boss direkt
godot --path . -- --autotest --section=3 --god
# Menüs durchklicken
godot --path . -- --autotest --mode=menu --shots=/tmp/menu
# Multiplayer lokal: zwei Instanzen
godot --headless --path . -- --autotest --net=host --netmode=coop --god &
godot --headless --path . -- --autotest --net=join --god
```

## Sounds neu erzeugen
```bash
python3 tools/gen_audio.py
```
Alle Klänge sind selbst synthetisiert (keine Lizenzfragen). Eigene CC0-Sounds kann man einfach unter gleichem Namen
in `assets/audio/sfx/` bzw. `assets/audio/music/` ablegen.

## Exportieren
Godot → Editor → Exportvorlagen verwalten → herunterladen. Dann Projekt → Exportieren → „Windows“ oder „Linux“
(Presets liegen in `export_presets.cfg`, Ausgabe nach `build/`).

## Steam
Siehe [STEAM.md](STEAM.md) (Spacewar-Test-App 480, Lobby-Codes, eigene App-ID, Upload, Store-Checkliste).

## Lizenzen
- Schriften: Inter (SIL OFL 1.1), DejaVu Sans Mono (Bitstream Vera License) – Lizenztexte in `assets/fonts/`
- Sounds und Musik: selbst erzeugt mit `tools/gen_audio.py`
