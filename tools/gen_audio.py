#!/usr/bin/env python3
"""Erzeugt alle Sounds und Musikstücke für GLOWLINE per Synthese (numpy).

Ergebnis: assets/audio/sfx/*.wav und assets/audio/music/*.wav
Alle Klänge sind selbst erzeugt -> keine Lizenzfragen.
Aufruf: python3 tools/gen_audio.py
"""
import os
import wave

import numpy as np

SR = 32000
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(1234)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    """ADSR-Hüllkurve mit n Samples."""
    out = np.zeros(n)
    ai, di, hi, ri = int(a * SR), int(d * SR), int(hold * SR), int(r * SR)
    i = 0
    seg = min(ai, n - i)
    out[i:i + seg] = np.linspace(0, 1, max(seg, 1))[:seg]
    i += seg
    seg = min(di, n - i)
    out[i:i + seg] = np.linspace(1, s, max(seg, 1))[:seg]
    i += seg
    seg = min(hi, n - i)
    out[i:i + seg] = s
    i += seg
    seg = min(ri, n - i)
    out[i:i + seg] = np.linspace(s, 0, max(seg, 1))[:seg]
    return out


def exp_env(n, k):
    return np.exp(-np.arange(n) / SR * k)


def osc(freq, n, kind="sine", phase=0.0):
    """freq kann Zahl oder Array sein (Frequenzverlauf)."""
    f = np.full(n, freq, dtype=float) if np.isscalar(freq) else freq
    ph = phase + 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "square":
        return np.sign(np.sin(ph))
    if kind == "saw":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if kind == "tri":
        return 2.0 * np.abs(2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, cutoff):
    """Einpoliger Tiefpass; cutoff Zahl oder Array."""
    c = np.full(len(x), cutoff, dtype=float) if np.isscalar(cutoff) else cutoff
    a = 1.0 - np.exp(-2 * np.pi * np.clip(c, 10, SR * 0.45) / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_fast(x, cutoff):
    """Feste Grenzfrequenz, per FFT (schnell für lange Signale)."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / np.sqrt(1.0 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(f, 1e-3)) ** 4)
    return np.fft.irfft(X, len(x))


def echo(x, delay, fb=0.35, mix=0.35, taps=4):
    d = int(delay * SR)
    out = np.concatenate([x, np.zeros(d * taps)])
    for k in range(1, taps + 1):
        out[d * k:d * k + len(x)] += x * (fb ** k) * mix
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x / m * peak


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sweep(f0, f1, n, curve=2.0):
    k = np.linspace(0, 1, n) ** (1 / curve)
    return f0 * (f1 / f0) ** k


# ---------------------------------------------------------------- SFX
def sfx():
    S = {}
    n = int(0.14 * SR)
    S["shoot_blaster"] = norm(osc(sweep(1500, 380, n, 1.5), n, "square") * exp_env(n, 28) * 0.5 +
                              osc(sweep(800, 200, n), n, "sine") * exp_env(n, 30), 0.6)
    n = int(0.3 * SR)
    x = lowpass(noise(n), sweep(5000, 400, n)) * exp_env(n, 14) + osc(sweep(160, 50, n), n) * exp_env(n, 18) * 0.8
    S["shoot_scatter"] = norm(x, 0.8)
    n = int(0.07 * SR)
    S["shoot_pulse"] = norm(osc(sweep(1900, 700, n), n, "square") * exp_env(n, 50) * 0.6, 0.45)
    n = int(0.5 * SR)
    whine = osc(sweep(400, 3000, n, 0.6), n, "saw") * env(n, 0.01, 0.1, 0.4, 0.3)
    crack = lowpass(noise(n), 6000) * exp_env(n, 20)
    S["shoot_rail"] = norm(lowpass(whine, 3500) * 0.4 + crack + osc(sweep(120, 40, n), n) * exp_env(n, 8) * 0.8, 0.8)
    n = int(0.4 * SR)
    S["shoot_rocket"] = norm(lowpass(noise(n), sweep(800, 3000, n)) * env(n, 0.02, 0.3, 0.2, 0.08) +
                             osc(sweep(200, 90, n), n, "saw") * exp_env(n, 10) * 0.3, 0.7)
    n = int(0.16 * SR)
    S["enemy_shoot"] = norm(osc(sweep(700, 220, n), n, "square") * exp_env(n, 20) * 0.5 +
                            lowpass(noise(n), 2000) * exp_env(n, 40) * 0.3, 0.55)
    n = int(0.6 * SR)
    S["sniper_shot"] = norm(lowpass(noise(n), 7000) * exp_env(n, 12) + osc(sweep(900, 60, n), n, "saw") * exp_env(n, 9) * 0.5, 0.8)
    n = int(0.06 * SR)
    S["hit"] = norm(osc(sweep(900, 400, n), n, "tri") * exp_env(n, 60) + noise(n) * exp_env(n, 120) * 0.4, 0.5)
    n = int(0.12 * SR)
    S["crit"] = norm(osc(sweep(1800, 900, n), n, "square") * exp_env(n, 35) * 0.5 + osc(2400, n) * exp_env(n, 40) * 0.4, 0.55)
    n = int(0.45 * SR)
    x = lowpass(noise(n), sweep(6000, 300, n)) * exp_env(n, 9) + osc(sweep(300, 40, n), n, "square") * exp_env(n, 14) * 0.25
    S["enemy_die"] = norm(x, 0.75)
    n = int(0.9 * SR)
    x = lowpass(noise(n), sweep(4000, 120, n, 0.7)) * exp_env(n, 5) + osc(sweep(90, 30, n), n) * exp_env(n, 5)
    S["explosion"] = norm(x, 0.9)
    n = int(2.0 * SR)
    x = lowpass(noise(n), sweep(5000, 80, n, 0.6)) * exp_env(n, 2.4) + osc(sweep(70, 25, n), n) * exp_env(n, 2.0) * 1.2
    x += lowpass(noise(n), 9000) * exp_env(n, 14) * 0.6
    S["big_explosion"] = norm(echo(x, 0.11, 0.3, 0.25), 0.95)
    n = int(0.16 * SR)
    S["jump"] = norm(osc(sweep(260, 700, n), n, "tri") * env(n, 0.004, 0.14), 0.45)
    n = int(0.08 * SR)
    S["land"] = norm(lowpass(noise(n), 900) * exp_env(n, 50) + osc(80, n) * exp_env(n, 50), 0.5)
    n = int(0.25 * SR)
    S["dash"] = norm(lowpass(noise(n), sweep(800, 6000, n)) * env(n, 0.01, 0.2, 0.0, 0.03) +
                     osc(sweep(300, 900, n), n, "sine") * exp_env(n, 15) * 0.3, 0.6)
    n = int(0.16 * SR)
    a = osc(1320, n, "square") * env(n, 0.002, 0.05, 0.0, 0.01)
    b = np.zeros(n)
    k = int(0.05 * SR)
    b[k:] = osc(1980, n - k, "square") * exp_env(n - k, 25)
    S["coin"] = norm(lowpass(a + b, 6000), 0.4)
    n = int(0.45 * SR)
    x = np.zeros(n)
    for i, f in enumerate([523, 659, 784, 1047]):
        s0 = int(i * 0.06 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "tri") * exp_env(m, 9)
    S["heal"] = norm(x, 0.5)
    n = int(0.35 * SR)
    S["hurt"] = norm(lowpass(osc(sweep(220, 70, n), n, "saw") * exp_env(n, 9) + noise(n) * exp_env(n, 30) * 0.6, 2500), 0.8)
    n = int(0.5 * SR)
    x = sum(osc(f, n, "sine") * exp_env(n, 7) for f in [1200, 1730, 2410]) + highpass_fast(noise(n), 4000) * exp_env(n, 12) * 0.5
    S["shield"] = norm(x, 0.6)
    n = int(1.0 * SR)
    x = np.zeros(n)
    for i, f in enumerate([660, 880, 1320]):
        s0 = int(i * 0.09 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "sine") * exp_env(m, 5) + osc(f * 2, m, "sine") * exp_env(m, 9) * 0.3
    S["checkpoint"] = norm(echo(x, 0.13, 0.35, 0.3)[:int(1.3 * SR)], 0.55)
    n = int(0.35 * SR)
    S["card"] = norm(osc(sweep(600, 1800, n), n, "tri") * env(n, 0.005, 0.3) + highpass_fast(noise(n), 5000) * exp_env(n, 15) * 0.3, 0.5)
    n = int(0.03 * SR)
    S["ui_move"] = norm(osc(1400, n, "sine") * exp_env(n, 120), 0.3)
    n = int(0.08 * SR)
    S["ui_select"] = norm(osc(sweep(900, 1500, n), n, "tri") * exp_env(n, 40), 0.4)
    n = int(0.1 * SR)
    S["ui_back"] = norm(osc(sweep(1100, 600, n), n, "tri") * exp_env(n, 35), 0.4)
    n = int(2.2 * SR)
    x = lowpass(osc(sweep(55, 41, n), n, "saw") + osc(sweep(55.5, 41.3, n), n, "saw"), sweep(200, 1200, n, 0.5))
    x *= env(n, 0.3, 1.0, 0.6, 0.9)
    S["boss_intro"] = norm(x + lowpass(noise(n), 300) * env(n, 0.5, 1.5) * 0.5, 0.85)
    n = int(1.4 * SR)
    x = np.zeros(n)
    for i, f in enumerate([523, 659, 784, 1047, 1319]):
        s0 = int(i * 0.08 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "square") * exp_env(m, 4) * 0.4
    S["clear"] = norm(lowpass(echo(x, 0.12, 0.3, 0.3)[:n], 5000), 0.55)
    n = int(1.8 * SR)
    x = np.zeros(n)
    for i, f in enumerate([392, 330, 262, 196]):
        s0 = int(i * 0.25 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "saw") * exp_env(m, 3)
    S["game_over"] = norm(lowpass(x, 1800), 0.6)
    n = int(0.3 * SR)
    crackle = noise(n) * (rng.uniform(0, 1, n) > 0.92) * 1.0
    S["lightning"] = norm(highpass_fast(crackle, 1500) * exp_env(n, 10) + osc(sweep(2000, 300, n), n, "saw") * exp_env(n, 20) * 0.3, 0.6)
    n = int(0.6 * SR)
    S["charge"] = norm(osc(sweep(200, 1400, n, 0.7), n, "saw") * env(n, 0.05, 0.5, 0.3, 0.05) * 0.6, 0.5)
    n = int(1.5 * SR)
    x = lowpass(osc(110, n, "saw") + osc(111.5, n, "saw") + osc(220.7, n, "square") * 0.5, 2500) * env(n, 0.02, 0.2, 0.8, 0.3, 0.9)
    S["laser"] = norm(x + highpass_fast(noise(n), 3000) * env(n, 0.01, 0.3, 0.3, 0.3, 0.8) * 0.3, 0.75)
    n = int(0.4 * SR)
    x = np.zeros(n)
    for i, f in enumerate([880, 1320]):
        s0 = int(i * 0.07 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "square") * exp_env(m, 10)
    S["buy"] = norm(lowpass(x, 5000), 0.45)
    n = int(1.2 * SR)
    x = np.zeros(n)
    for i, f in enumerate([784, 988, 1175, 1568]):
        s0 = int(i * 0.07 * SR)
        m = n - s0
        x[s0:] += osc(f, m, "tri") * exp_env(m, 5)
    S["achievement"] = norm(echo(x, 0.1, 0.3, 0.3)[:n], 0.5)
    n = int(0.3 * SR)
    S["combo"] = norm(osc(sweep(800, 1600, n), n, "square") * env(n, 0.005, 0.25) * 0.4 + osc(1600, n, "sine") * exp_env(n, 10) * 0.3, 0.45)
    for k, v in S.items():
        save(os.path.join(ROOT, "sfx", k + ".wav"), v)
    print("SFX:", len(S))


# ---------------------------------------------------------------- Musik
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def note(name, octave):
    return NOTE[name] + 12 * (octave + 1)


def place(buf, x, start):
    s = int(start * SR)
    e = min(len(buf), s + len(x))
    if s < len(buf):
        buf[s:e] += x[:e - s]


def kick(n=None):
    n = n or int(0.35 * SR)
    return osc(sweep(150, 42, n, 0.4), n) * exp_env(n, 9) + noise(n) * exp_env(n, 300) * 0.2


def snare():
    n = int(0.25 * SR)
    return highpass_fast(noise(n), 900) * exp_env(n, 18) * 0.7 + osc(sweep(260, 180, n), n) * exp_env(n, 25) * 0.4


def hat(open_=False):
    n = int((0.18 if open_ else 0.05) * SR)
    return highpass_fast(noise(n), 7000) * exp_env(n, 14 if open_ else 70) * 0.35


def synth_note(freq, dur, kind="saw", cutoff=2000, a=0.005, d=0.2, s=0.6, r=0.1, detune=0.0):
    n = int((dur + r) * SR)
    x = osc(freq, n, kind)
    if detune:
        x = x * 0.5 + osc(freq * (1 + detune), n, kind) * 0.5
    x = lowpass(x, cutoff)
    return x * env(n, a, d, s, r, hold=max(0.0, dur - a - d))


def track(bpm, bars, chords, style):
    """chords: Liste von (Grundton, Moll?) pro Takt."""
    beat = 60.0 / bpm
    total = bars * 4 * beat
    n = int(total * SR) + 1
    drums = np.zeros(n)
    bass = np.zeros(n)
    arp = np.zeros(n)
    pad = np.zeros(n)
    lead = np.zeros(n)
    k_samp = kick()
    s_samp = snare()
    h_c = hat()
    h_o = hat(True)
    for bar in range(bars):
        root, minor = chords[bar % len(chords)]
        third = 3 if minor else 4
        chord = [root, root + third, root + 7]
        t0 = bar * 4 * beat
        # Schlagzeug
        if style != "menu":
            for b in range(4):
                if style == "boss" or b in (0, 2) or (bar % 2 == 1 and b == 3):
                    place(drums, k_samp, t0 + b * beat)
                if b in (1, 3):
                    place(drums, s_samp, t0 + b * beat)
                for h in range(2):
                    place(drums, h_o if (h == 1 and b == 3) else h_c, t0 + b * beat + h * beat / 2)
                if style == "boss":
                    for h in range(4):
                        place(drums, h_c * 0.6, t0 + b * beat + h * beat / 4)
        else:
            if bar % 2 == 0:
                place(drums, kick() * 0.5, t0)
            for b in range(4):
                place(drums, h_c * 0.5, t0 + b * beat + beat / 2)
        # Bass: Achtel mit Oktavsprung
        for e in range(8):
            m = root - 24 + (12 if (e % 2 == 1 and style != "menu") else 0)
            if style == "menu" and e % 2 == 1:
                continue
            place(bass, synth_note(mtof(m), beat / 2 * 0.9, "saw", 500 if style != "boss" else 750, d=0.1, s=0.5, r=0.03),
                  t0 + e * beat / 2)
        # Arpeggio in Sechzehnteln
        pattern = [0, 1, 2, 1, 0, 2, 1, 2] if style != "boss" else [0, 2, 1, 2, 0, 1, 2, 1]
        steps = 16 if style != "menu" else 8
        for st in range(steps):
            idx = pattern[st % len(pattern)]
            m = chord[idx] + (12 if st >= steps // 2 and style != "menu" else 0)
            dur = beat / 4 if style != "menu" else beat / 2
            place(arp, synth_note(mtof(m), dur * 0.7, "square", 2600, d=0.08, s=0.3, r=0.04), t0 + st * dur)
        # Flächen
        for m in chord:
            place(pad, synth_note(mtof(m - 12), 4 * beat * 0.98, "saw", 1100, a=0.4, d=0.5, s=0.7, r=0.3, detune=0.006), t0)
        # Melodie in jeder zweiten Hälfte
        if style != "menu" and (bar // 4) % 2 == 1:
            mel = [chord[2] + 12, chord[1] + 12, chord[0] + 12, chord[1] + 12]
            for i, m in enumerate(mel):
                place(lead, synth_note(mtof(m), beat * 0.9, "saw", 3000, d=0.2, s=0.5, r=0.1, detune=0.004), t0 + i * beat)
    arp = echo(arp, beat * 0.75, 0.4, 0.4, 3)[:n]
    lead = echo(lead, beat * 0.5, 0.35, 0.3, 3)[:n]
    if style == "menu":
        mix = drums * 0.5 + bass * 0.45 + arp * 0.22 + pad * 0.32
    elif style == "boss":
        mix = drums * 0.8 + bass * 0.6 + arp * 0.18 + pad * 0.18 + lead * 0.2
    else:
        mix = drums * 0.7 + bass * 0.5 + arp * 0.2 + pad * 0.22 + lead * 0.18
    mix = np.tanh(mix * 1.3)
    # Nahtloser Loop: Ausklang auf den Anfang falten
    loop_n = int(total * SR)
    out = mix[:loop_n].copy()
    tail = mix[loop_n:]
    out[:len(tail)] += tail
    return norm(out, 0.85)


def music():
    A, F, C, G, E, D = note("A", 2), note("F", 2), note("C", 3), note("G", 2), note("E", 2), note("D", 2)
    save(os.path.join(ROOT, "music", "menu.wav"), track(92, 8, [(A, True), (F, False), (C, False), (G, False)], "menu"))
    print("menu")
    save(os.path.join(ROOT, "music", "run.wav"), track(118, 16, [(A, True), (F, False), (C, False), (G, False),
                                                                  (A, True), (F, False), (D, True), (E, False)], "run"))
    print("run")
    Ds = note("D#", 2)
    save(os.path.join(ROOT, "music", "boss.wav"), track(140, 16, [(E, True), (E, True), (C, False), (D, False),
                                                                   (E, True), (Ds + 1, False), (C, False), (D, False)], "boss"))
    print("boss")


if __name__ == "__main__":
    sfx()
    music()
