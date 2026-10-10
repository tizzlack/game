#!/usr/bin/env python3
"""Downloads the free sound packs and music used by GLOWLINE and converts them for the game.

Sources (licenses: see CREDITS.md):
  - Kenney sound packs (CC0): Sci-Fi Sounds, Digital Audio, Interface Sounds, Impact Sounds, UI Audio, Music Jingles
  - Music by Kevin MacLeod, incompetech.com (CC BY 4.0)

Usage:  python3 tools/build_audio.py [CACHE_DIR]
Needs:  ffmpeg (with libvorbis), numpy
Output: assets/audio/sfx/<name>.wav (mono 16 bit) and assets/audio/music/<name>.ogg
"""
import os
import subprocess
import sys
import urllib.request
import zipfile

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SR = 44100

KENNEY = {
    "scifi": "https://kenney.nl/media/pages/assets/sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip",
    "digital": "https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip",
    "interface": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "impact": "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "ui": "https://kenney.nl/media/pages/assets/ui-audio/490d233f68-1677590494/kenney_ui-audio.zip",
    "jingles": "https://kenney.nl/media/pages/assets/music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip",
}

# game name -> list of layers (pack, file, start s, max length s, gain dB), loudness target in dB RMS (active part)
# The targets match the loudness of the earlier synthesized sounds, so the mix in the game stays the same.
SFX = {
    "shoot_blaster": ([("scifi", "laserSmall_000.ogg", 0.0, 0.16, 0)], -16.5),
    "shoot_scatter": ([("scifi", "laserRetro_002.ogg", 0.0, 0.26, 0), ("impact", "impactPunch_medium_000.ogg", 0.0, 0.2, -6)], -15.8),
    "shoot_pulse": ([("digital", "phaserDown2.ogg", 0.0, 0.12, 0)], -14.5),
    "shoot_rail": ([("scifi", "laserLarge_000.ogg", 0.0, 0.6, 0)], -16.2),
    "shoot_rocket": ([("scifi", "thrusterFire_000.ogg", 0.0, 0.45, 0), ("scifi", "laserRetro_004.ogg", 0.0, 0.25, -6)], -15.8),
    "enemy_shoot": ([("scifi", "laserRetro_000.ogg", 0.0, 0.24, 0)], -14.8),
    "sniper_shot": ([("scifi", "laserLarge_003.ogg", 0.0, 0.7, 0)], -16.1),
    "hit": ([("impact", "impactGeneric_light_000.ogg", 0.0, 0.1, 0)], -20.1),
    "crit": ([("impact", "impactGlass_light_000.ogg", 0.0, 0.2, 0)], -16.1),
    "enemy_die": ([("impact", "impactGlass_heavy_000.ogg", 0.0, 0.24, 0), ("scifi", "explosionCrunch_000.ogg", 0.0, 0.5, -7)], -16.6),
    "explosion": ([("scifi", "explosionCrunch_002.ogg", 0.0, 1.0, 0)], -13.5),
    "big_explosion": ([("scifi", "lowFrequency_explosion_000.ogg", 0.0, 2.0, 0), ("scifi", "explosionCrunch_004.ogg", 0.0, 1.8, -3)], -14.5),
    "jump": ([("digital", "phaseJump1.ogg", 0.0, 0.2, 0)], -17.5),
    "land": ([("impact", "impactSoft_medium_000.ogg", 0.0, 0.12, 0)], -18.9),
    "dash": ([("scifi", "thrusterFire_001.ogg", 0.0, 0.28, 0), ("digital", "phaserDown3.ogg", 0.0, 0.22, -8)], -17.2),
    "coin": ([("digital", "pepSound3.ogg", 0.0, 0.2, 0)], -15.5),
    "heal": ([("digital", "powerUp2.ogg", 0.0, 0.47, 0)], -18.2),
    "hurt": ([("impact", "impactPunch_heavy_000.ogg", 0.0, 0.4, 0), ("digital", "lowDown.ogg", 0.0, 0.35, -8)], -14.9),
    "shield": ([("scifi", "forceField_001.ogg", 0.0, 0.6, 0)], -19.0),
    "checkpoint": ([("jingles", "jingles_NES09.ogg", 0.0, 1.0, 0)], -18.2),
    "card": ([("interface", "maximize_004.ogg", 0.0, 0.42, 0)], -16.3),
    "ui_move": ([("ui", "rollover2.ogg", 0.0, 0.06, 0)], -20.7),
    "ui_select": ([("interface", "click_001.ogg", 0.0, 0.1, 0)], -19.7),
    "ui_back": ([("interface", "back_001.ogg", 0.0, 0.1, 0)], -19.4),
    "boss_intro": ([("scifi", "lowFrequency_explosion_000.ogg", 0.0, 2.0, 0), ("jingles", "jingles_HIT11.ogg", 0.0, 1.0, -4)], -12.5),
    "clear": ([("jingles", "jingles_NES12.ogg", 0.0, 1.2, 0)], -16.8),
    "game_over": ([("jingles", "jingles_NES11.ogg", 0.0, 1.2, 0)], -17.2),
    "lightning": ([("digital", "zap1.ogg", 0.0, 0.4, 0)], -22.0),
    "charge": ([("digital", "phaserUp1.ogg", 0.0, 0.5, 0)], -14.4),
    "laser": ([("scifi", "forceField_000.ogg", 0.0, 0.95, 0), ("scifi", "laserLarge_001.ogg", 0.0, 0.72, -3)], -12.5),
    "buy": ([("interface", "confirmation_001.ogg", 0.0, 0.3, 0)], -15.7),
    "achievement": ([("jingles", "jingles_NES08.ogg", 0.0, 1.2, 0)], -19.0),
    "combo": ([("interface", "pluck_001.ogg", 0.0, 0.12, 0)], -15.3),
}

INCOMPETECH = "https://incompetech.com/music/royalty-free/mp3-royaltyfree/"
# game name -> track title (Kevin MacLeod). "run" plays the run_* tracks one after another.
MUSIC = {
    "menu": "Mesmerizing Galaxy Loop",
    "run_1": "Darkling",
    "run_2": "Voltaic",
    "run_3": "Ouroboros",
    "run_4": "Cyborg Ninja",
    "boss": "Exit the Premises",
}


def fetch(url, path):
    if os.path.exists(path):
        return
    print("download", url)
    with urllib.request.urlopen(url, timeout=120) as r, open(path + ".part", "wb") as f:
        f.write(r.read())
    os.replace(path + ".part", path)


def find(folder, name):
    for d, _, files in os.walk(folder):
        if name in files:
            return os.path.join(d, name)
    raise FileNotFoundError(name + " in " + folder)


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "s16le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def active_rms_db(x):
    w = 1024
    fr = x[: len(x) // w * w].reshape(-1, w)
    if len(fr) == 0:
        return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-9)
    r = np.sqrt((fr ** 2).mean(1))
    act = r[r > r.max() * 0.1]
    return 20 * np.log10(np.sqrt((act ** 2).mean()) + 1e-9)


def build_sfx(name, layers, target_db, packs):
    mix = None
    for pack, fname, start, length, gain in layers:
        x = load(find(packs[pack], fname))
        x = x[int(start * SR): int((start + length) * SR)]
        # Click-freie Ränder: 3 ms Einblenden, 30 % (max. 80 ms) Ausblenden
        n = len(x)
        fi = min(int(0.003 * SR), n)
        fo = min(int(min(0.08, length * 0.3) * SR), n)
        env = np.ones(n, dtype=np.float32)
        env[:fi] = np.linspace(0, 1, fi)
        if fo > 0:
            env[n - fo:] *= np.linspace(1, 0, fo)
        x = x * env * (10 ** (gain / 20))
        if mix is None:
            mix = x
        else:
            if len(x) > len(mix):
                mix = np.pad(mix, (0, len(x) - len(mix)))
            mix[: len(x)] += x
    g = 10 ** ((target_db - active_rms_db(mix)) / 20)
    mix = mix * g
    peak = np.abs(mix).max()
    if peak > 0.97:
        # sanfter Limiter statt hartem Clipping
        mix = np.tanh(mix / 0.97 * 1.2) / np.tanh(1.2) * 0.97
    out = os.path.join(SFX_DIR, name + ".wav")
    pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", out],
                   input=pcm.tobytes(), check=True)


def build_music(name, title, cache):
    src = os.path.join(cache, title + ".mp3")
    fetch(INCOMPETECH + urllib.request.quote(title) + ".mp3", src)
    out = os.path.join(MUSIC_DIR, name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-af", "loudnorm=I=-14:TP=-1.0:LRA=11",
                    "-ar", str(SR), "-ac", "2", "-c:a", "libvorbis", "-q:a", "3", out], check=True)


def main():
    cache = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".audio_cache")
    os.makedirs(cache, exist_ok=True)
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(MUSIC_DIR, exist_ok=True)
    packs = {}
    for key, url in KENNEY.items():
        z = os.path.join(cache, key + ".zip")
        fetch(url, z)
        d = os.path.join(cache, key)
        if not os.path.isdir(d):
            with zipfile.ZipFile(z) as zf:
                zf.extractall(d)
        packs[key] = d
    for name, (layers, target) in SFX.items():
        build_sfx(name, layers, target, packs)
        print("sfx", name)
    for name, title in MUSIC.items():
        build_music(name, title, cache)
        print("music", name, "<-", title)


if __name__ == "__main__":
    main()
