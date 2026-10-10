# Neon Run & Gun – Plan und Master-Prompt (Godot 4)

## Stand: umgesetzt (Projekt GLOWLINE)
- [x] Neon-Look wie Vorlage: Bloom, Neonröhren-Kern, zackige Leuchtlinien, Sternblitze, Konfetti-Funken
- [x] Zerstörbares Gelände (treppenförmige Löcher, Splitter), Bruchböden
- [x] Movement: Wall-Slide/Walljump, Rutschen, 8-Richtungs-Dash, Super-Sprung, Ground-Slam, Ecken-Korrektur
- [x] Level-Bausteine für das Movement: Schächte, Tunnel, Dash-Lücken, Sprungfelder, Schanzen, Säulen, Berge
- [x] Spielbares Tutorial mit 12 Stationen
- [x] 6 Gegnertypen + Boss mit 2 Phasen, 3 Welten + Endlos-Modus
- [x] Roguelite: 23 Karten, Werkstatt, 5 Waffen, Skins, Hitze, Modifikatoren, tägliche Herausforderung
- [x] Multiplayer: Koop 2–4 und Versus, Steam-Lobby per Code (Spacewar 480) oder LAN
- [x] Controller-Support, Vibration, Zielhilfe, Deutsch/Englisch, 16 Erfolge
- [x] Synthetische Sounds und Musik, Export-Presets, Doku (README.md, STEAM.md)
- [ ] Offen: eigene App-ID, Store-Grafiken, Trailer, Feinschliff nach Spieltests

## Was die Screenshots zeigen
- Seitlich scrollender 2D-Run-and-Gun, Spieler läuft, springt, schießt (Maus zielt, Fadenkreuz)
- Alles im **Neon-Vektor-Look**: leuchtende Umrisse auf schwarzem Hintergrund, kein gefülltes Sprite
- Level aus **gezackten Leuchtlinien** (Hügel, Stufen, Plattformen, Gebäude mit leuchtenden Fenstern)
- Gegner als rote/pinke Strichfiguren, auch Türme und Schützen auf Plattformen
- Starkes Feedback: Bloom, Funken-Partikel, Explosionen, Schussspuren, Bewegungs-Nachbilder
- HUD: Punktzahl oben links (+25 Popups), Geld oben rechts, "CHECKPOINT"-Einblendung
- Hintergrund: Sterne/Glut-Partikel, Lichtsäule am Levelziel, wechselnde Farbstimmung pro Level

## Technik
- Godot 4.x, GDScript, 2D, Export für Windows (Steam)
- Look über `WorldEnvironment` mit Glow/Bloom, `Line2D` für Umrisse, `GPUParticles2D`
- Level aus `Line2D` + `StaticBody2D` mit `CollisionPolygon2D` / `SegmentShape2D`
- Spieler als Strichfigur aus `Line2D`-Gliedern, animiert per Code oder `AnimationPlayer`
- Speicherstand per `FileAccess` in `user://`

## Phasen
1. **Look-Prototyp:** schwarzer Hintergrund, Glow, Spieler als Leuchtfigur, Boden aus Leuchtlinie
2. **Bewegung:** Laufen, Springen, Coyote-Time, Zielen mit Maus, Schießen mit Schussspur
3. **Gegner:** Läufer, Schütze, Turm; Trefferfeedback, Explosion, Punkte (+25), Geld
4. **Level:** Checkpoints, Plattformen, Lichtsäule als Ziel, 3 Level mit anderer Farbe
5. **Meta:** Shop (Waffen, Leben, Tempo), Speichern, Highscores, Menüs, Pause, Optionen
6. **Politur:** Sounds/Musik, Screen-Shake, Nachbilder, Bossgegner, Erfolge
7. **Steam:** Windows-Export, GodotSteam, Erfolge, Cloud-Saves, Store-Seite, Demo

## Bindung ("noch ein Run") und Verdienst – Design-Ergänzung
**Kernidee:** Roguelite-Loop statt fixer Level. Kurze Runs (5–10 Min), nach Tod oder Sieg bleibt Fortschritt erhalten.

Bindung durch gutes Design:
- **Roguelite-Runs:** zufällig erzeugte Abschnitte, nach jedem Abschnitt Wahl aus 3 Upgrades (Build-Vielfalt, Synergien)
- **Meta-Fortschritt:** Geld aus Runs kauft dauerhafte Upgrades, neue Waffen, neue Charaktere
- **Spielgefühl:** sehr direkte Steuerung, Treffer-Feedback, Kombo-Zähler, Screen-Shake, Soundtreppen bei Serien
- **Ziele:** tägliche Herausforderung mit Bestenliste, Missionen, Erfolge, Freischaltungen
- **Flow:** Neustart in unter 2 Sekunden, kein Ladebildschirm
- **Schwierigkeit:** faire Kurve, Tod soll sich nach eigenem Fehler anfühlen, Hilfsoptionen
- **Wiederspielwert:** Endlos-Modus, Mutatoren (Run-Modifikatoren), Seeds zum Teilen

Verdienst (fair, Steam-tauglich):
- **Einmalkauf** 5–10 $, kein Pay-to-Win, keine Lootboxen
- **Kostenlose Demo** plus Wunschlisten sammeln (wichtigster Hebel auf Steam)
- **DLC** später: neue Charaktere, Welten, Soundtrack
- **Updates** nach Launch, Community pflegen (Discord), Trailer und Kurzvideos für TikTok/YouTube
- **Streamer-Tauglichkeit:** Seeds, Daily Run, übersichtliche Effekte

Hinweis: Keine Garantie auf Einnahmen. Die meisten Steam-Spiele verdienen wenig, Erfolg hängt stark von Qualität und Marketing ab.

## Hinweis zum Geld
Verdienst auf Steam hängt von Qualität, Marketing und Wunschlisten ab. Es gibt keine Garantie auf Einnahmen.

---

## MASTER-PROMPT

Du bist ein erfahrener Godot-4-Entwickler (GDScript). Baue in diesem Repository ein 2D-PC-Spiel im Stil eines **Neon-Vektor-Run-and-Gun**.

### Look (sehr wichtig)
- Schwarzer Hintergrund, alles besteht aus **leuchtenden Linien** (Line2D) mit Bloom/Glow (WorldEnvironment, Glow aktiviert, HDR 2D an).
- Spieler: weiße/hellblaue Strichfigur mit Glow. Gegner: rot/pink. Plattformen und Boden: grüne oder weiße Leuchtlinien mit leicht gezacktem, handgezeichnetem Rand (leichtes Rauschen auf den Linienpunkten).
- Hintergrundpartikel (Sterne/Glut), pro Level andere Farbstimmung (Blau, Orange, Grün).
- Gebäude als Umrisse mit kleinen leuchtenden Fenstern, am Levelziel eine Lichtsäule.
- Effekte: Funkenpartikel bei Treffern, Explosionen mit Lichtblitz, Schussspuren, Nachbilder beim Dash/Sprung, Screen-Shake.

### Gameplay
- Seitlich scrollend, Kamera folgt dem Spieler mit Glättung.
- Steuerung: A/D oder Pfeile laufen, Leertaste springen (Coyote-Time + Sprungpuffer), Maus zielt, Linksklick schießt, Shift Dash, Esc Pause.
- Gegner: Läufer (rennt auf Spieler zu), Schütze (schießt von Plattformen), Turm (stationär), später ein Boss.
- Punkte: +25 pro Gegner mit Popup-Text, Geld als Währung oben rechts.
- Checkpoints mit Einblendung "CHECKPOINT"; Respawn dort bei Tod.
- Level enden an der Lichtsäule. Mindestens 3 Level in Phase 1–4.
- Shop zwischen Levels: Waffenschaden, Feuerrate, Leben, Tempo. Preise steigen exponentiell.
- Speicherstand in `user://save.json`.

### Bindung und Progression (neu, wichtig)
- Roguelite-Aufbau: Run = 5–10 Minuten, prozedural zusammengesetzte Abschnitte aus handgebauten Bausteinen.
- Nach jedem Abschnitt Auswahl aus 3 zufälligen Upgrades (mit Synergien, Seltenheit, Build-Vielfalt).
- Dauerhafter Meta-Fortschritt: Geld aus Runs kauft Waffen, Charaktere und Passiv-Upgrades (Preise steigen exponentiell).
- Kombo-System mit Multiplikator, Soundtreppe und Effekten bei Serien.
- Tägliche Herausforderung mit festem Seed und lokaler Bestenliste (später Steam-Leaderboard), Missionen, Erfolge, Mutatoren.
- Neustart nach Tod in unter 2 Sekunden, keine Ladebildschirme.
- Faire Schwierigkeit mit Hilfsoptionen, keine Pay-to-Win-Mechanik, keine Lootboxen, keine künstlichen Wartezeiten.
- Spiel soll sich für Streamer gut lesen lassen (klare Effekte, Seeds zum Teilen).

### HUD
- Oben links Punktzahl (große, leicht transparente Neonschrift), oben rechts Geld, unten links Zeit, Gesundheit als Neonleiste.

### Technische Vorgaben
- Godot 4.x, nur GDScript, keine externen Plugins außer später GodotSteam.
- Saubere Struktur: `scenes/` (player, enemies, levels, ui), `scripts/`, `assets/`, `autoload/` (GameState, SaveSystem, AudioManager).
- Alle Texte auf Deutsch, Code und Kommentare knapp.
- Levels datengetrieben: Terrain als Punktlisten, die zu Line2D und Kollision werden.
- Keine Assets mit unklarer Lizenz; Sounds zunächst generiert oder Platzhalter.
- Stabil bei 60 FPS auf durchschnittlichen PCs.

### Arbeitsweise
1. Arbeite Phase für Phase (siehe Plan), nach jeder Phase muss das Projekt in Godot 4 startbar sein.
2. Erkläre am Ende jeder Phase kurz, was funktioniert und wie man es testet.
3. Committe nach jeder Phase mit klarer Nachricht.
4. Frage nur nach, wenn eine Entscheidung wirklich vom Nutzer abhängt.

Starte mit **Phase 1 (Look-Prototyp)**.
