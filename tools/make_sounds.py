"""
Gera os efeitos sonoros e a música ambiente por síntese (sem arquivos externos).
Rode:  python tools/make_sounds.py      (precisa de numpy e scipy)
Saída: audio/*.wav  (44,1 kHz, 16 bits, mono)
"""
import os

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=None, curve=3.0):
    x = np.linspace(0, 1, n)
    e = np.minimum(1.0, x * (n / SR) / max(a, 1e-4))
    e *= (1 - x) ** curve if r is None else np.exp(-x * (n / SR) / r)
    return e


def lp(x, f):
    b, a = butter(2, min(f / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def hp(x, f):
    b, a = butter(2, min(f / (SR / 2), 0.99), "high")
    return lfilter(b, a, x)


def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def sweep(f0, f1, d, wave="sin"):
    tt = t(d)
    f = f0 * (f1 / f0) ** (tt / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if wave == "sq":
        return np.sign(np.sin(ph))
    return np.sin(ph)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def save(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = min(len(x), 200)
    x[-fade:] *= np.linspace(1, 0, fade)
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def whoosh(d=0.28, lo=400, hi=3000):
    n = noise(d)
    e = env(len(n), a=d * 0.35, curve=2)
    return bp(n, lo, hi) * e


def boom(d=0.9, f0=110, f1=35):
    s = sweep(f0, f1, d) * env(int(SR * d), a=0.004, r=d * 0.3)
    n = lp(noise(d), 500) * env(int(SR * d), a=0.002, r=d * 0.18)
    return s * 1.0 + n * 0.9


def music_track(name, chords, bpm, bars_per_chord=1, wave_bass=0.35, mel_decay=3.0, bells=False, drums=False, seed=0):
    beat = 60 / bpm
    bar = beat * 4 * bars_per_chord
    n = int(SR * bar * len(chords))
    music = np.zeros(n)

    def mf(m):
        return 440 * 2 ** ((m - 69) / 12)

    for i, ch in enumerate(chords):
        st = int(SR * bar * i)
        L = int(SR * bar)
        tt = np.arange(L) / SR
        pad = sum(np.sin(2 * np.pi * mf(m) * tt) + 0.3 * np.sin(2 * np.pi * mf(m) * 2.003 * tt) for m in ch)
        e = np.minimum(1, tt / 1.2) * np.minimum(1, (tt[-1] - tt) / 1.0 + 0.05)
        music[st:st + L] += lp(pad, 1600) * e * 0.16
        music[st:st + L] += np.sin(2 * np.pi * mf(ch[0] - 12) * tt) * np.exp(-tt * 0.8) * wave_bass
        r = np.random.default_rng(seed + i)
        scale = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
        steps = int(bars_per_chord * 8)
        for k in range(steps):
            if r.random() < 0.5:
                ns = st + int(SR * beat * 0.5 * k)
                nl = int(SR * beat * (1.5 if bells else 0.9))
                tn = np.arange(nl) / SR
                f = mf(scale[r.integers(0, 4)])
                if bells:
                    note = (np.sin(2 * np.pi * f * tn) + 0.5 * np.sin(2 * np.pi * f * 2.76 * tn) + 0.25 * np.sin(2 * np.pi * f * 5.4 * tn)) * np.exp(-tn * 2.2) * 0.12
                else:
                    note = (np.sin(2 * np.pi * f * tn) + 0.25 * np.sin(4 * np.pi * f * tn)) * np.exp(-tn * mel_decay) * 0.16
                end = min(n, ns + nl)
                music[ns:end] += note[: end - ns]
        if drums:
            for k in range(int(4 * bars_per_chord)):
                ns = st + int(SR * beat * k)
                d = boom(0.4, 70, 35) * (0.5 if k % 2 == 0 else 0.25)
                end = min(n, ns + len(d))
                music[ns:end] += d[: end - ns] * 0.5
    d = int(SR * beat * 0.75)
    echo = np.zeros(n)
    echo[d:] = music[:-d] * 0.3
    music = music + echo
    x = music / (np.max(np.abs(music)) + 1e-9) * 0.6
    wavfile.write(os.path.join(OUT, name + ".wav"), SR, (x * 32767).astype(np.int16))


def main():
    # golpes básicos
    save("swing", whoosh(0.22, 600, 4000), 0.6)
    save("hit", mix(lp(noise(0.12), 2200) * env(int(SR * 0.12), a=0.001, r=0.03), sweep(220, 90, 0.12) * env(int(SR * 0.12), a=0.001, r=0.04) * 0.8), 0.8)
    save("crit", mix(lp(noise(0.2), 3000) * env(int(SR * 0.2), a=0.001, r=0.05), sweep(900, 300, 0.2, "sq") * env(int(SR * 0.2), a=0.001, r=0.06) * 0.4, sweep(180, 60, 0.2) * env(int(SR * 0.2), a=0.001, r=0.08)), 0.85)
    save("arrow", mix(sweep(900, 500, 0.12, "saw") * env(int(SR * 0.12), a=0.001, r=0.03) * 0.3, whoosh(0.2, 1500, 6000)), 0.6)
    save("hurt", mix(sweep(260, 120, 0.25, "saw") * env(int(SR * 0.25), a=0.002, r=0.08) * 0.5, lp(noise(0.25), 900) * env(int(SR * 0.25), a=0.001, r=0.06)), 0.7)
    save("slime_die", mix(sweep(500, 90, 0.35) * env(int(SR * 0.35), a=0.002, r=0.12), lp(noise(0.35), 700) * env(int(SR * 0.35), a=0.001, r=0.05) * 0.6), 0.7)
    # tipos de skill
    save("sk_slash", mix(whoosh(0.35, 500, 5000), sweep(1200, 300, 0.3, "saw") * env(int(SR * 0.3), a=0.01, r=0.08) * 0.2), 0.8)
    save("sk_dash", mix(whoosh(0.45, 200, 2500), sweep(80, 200, 0.45) * env(int(SR * 0.45), a=0.05) * 0.5), 0.8)
    save("sk_slam", boom(1.1, 120, 30), 0.95)
    save("sk_buff", mix(*[np.pad(np.sin(2 * np.pi * f * t(0.5)) * env(int(SR * 0.5), a=0.01, r=0.25), (int(SR * 0.07 * i), 0)) for i, f in enumerate([392, 494, 587, 784])]), 0.7)
    fire_n = noise(0.9)
    crackle = (rng.random(len(fire_n)) > 0.996) * rng.uniform(-1, 1, len(fire_n))
    save("sk_fire", mix(lp(fire_n, 1200) * env(len(fire_n), a=0.08, curve=1.5), hp(crackle, 2000) * 2.0, sweep(150, 60, 0.9) * env(len(fire_n), a=0.02, r=0.3) * 0.6), 0.85)
    save("sk_ice", mix(*[np.sin(2 * np.pi * f * t(0.7)) * env(int(SR * 0.7), a=0.002, r=0.18) * 0.4 for f in (1760, 2217, 2637, 3520)], hp(noise(0.7), 4000) * env(int(SR * 0.7), a=0.002, r=0.1) * 0.6), 0.75)
    zap = noise(0.6) * (rng.random(int(SR * 0.6)) > 0.7)
    save("sk_thunder", mix(hp(zap, 1500) * env(len(zap), a=0.001, r=0.15), boom(0.8, 90, 30) * 0.8), 0.9)
    save("sk_magic", mix(sweep(300, 1400, 0.4) * env(int(SR * 0.4), a=0.01, r=0.15) * 0.6, sweep(450, 2100, 0.4) * env(int(SR * 0.4), a=0.01, r=0.15) * 0.3, bp(noise(0.4), 2000, 8000) * env(int(SR * 0.4), a=0.05) * 0.4), 0.7)
    save("sk_explosion", mix(boom(1.2, 90, 25), lp(noise(1.2), 2500) * env(int(SR * 1.2), a=0.002, r=0.25) * 0.8), 0.95)
    save("sk_shield", mix(np.sin(2 * np.pi * 220 * t(0.9)) * env(int(SR * 0.9), a=0.1, curve=1) * 0.5, np.sin(2 * np.pi * 330.5 * t(0.9)) * env(int(SR * 0.9), a=0.1, curve=1) * 0.4, sweep(600, 1200, 0.9) * env(int(SR * 0.9), a=0.2, curve=1) * 0.2), 0.7)
    save("sk_multi_arrow", mix(*[np.pad(whoosh(0.18, 1500, 7000), (int(SR * 0.05 * i), 0)) for i in range(5)]), 0.7)
    # interface e progresso
    save("levelup", mix(*[np.pad(np.sin(2 * np.pi * f * t(0.6)) * env(int(SR * 0.6), a=0.005, r=0.22) + 0.3 * np.sin(4 * np.pi * f * t(0.6)) * env(int(SR * 0.6), a=0.005, r=0.1), (int(SR * 0.09 * i), 0)) for i, f in enumerate([523, 659, 784, 1046])]), 0.75)
    save("quest", mix(*[np.pad(np.sin(2 * np.pi * f * t(0.5)) * env(int(SR * 0.5), a=0.005, r=0.2), (int(SR * 0.12 * i), 0)) for i, f in enumerate([440, 554, 659])]), 0.7)
    save("coin", mix(np.sin(2 * np.pi * 1975 * t(0.25)) * env(int(SR * 0.25), a=0.001, r=0.06), np.pad(np.sin(2 * np.pi * 2637 * t(0.3)) * env(int(SR * 0.3), a=0.001, r=0.08), (int(SR * 0.06), 0))), 0.5)
    save("click", np.sin(2 * np.pi * 1200 * t(0.05)) * env(int(SR * 0.05), a=0.001, r=0.01), 0.4)
    save("boss", mix(sweep(70, 45, 2.0, "saw") * env(int(SR * 2.0), a=0.3, curve=1) * 0.5, boom(1.5, 60, 25)), 0.9)

    # música ambiente do campo (loop de ~32 s)
    bpm = 72
    beat = 60 / bpm
    dur = beat * 4 * 10
    n = int(SR * dur)
    music = np.zeros(n)
    chords = [(57, 60, 64), (53, 57, 60), (48, 52, 55), (55, 59, 62), (57, 60, 64), (53, 57, 60), (50, 53, 57), (52, 56, 59), (57, 60, 64), (57, 60, 64)]
    def mf(m):
        return 440 * 2 ** ((m - 69) / 12)
    for i, ch in enumerate(chords):
        st = int(SR * beat * 4 * i)
        L = int(SR * beat * 4)
        tt = np.arange(L) / SR
        pad = sum(np.sin(2 * np.pi * mf(m) * tt) + 0.3 * np.sin(2 * np.pi * mf(m) * 2.003 * tt) for m in ch)
        e = np.minimum(1, tt / 1.2) * np.minimum(1, (tt[-1] - tt) / 1.0 + 0.05)
        music[st:st + L] += lp(pad, 1800) * e * 0.18
        bass = np.sin(2 * np.pi * mf(ch[0] - 12) * tt) * np.exp(-tt * 0.8) * 0.35
        music[st:st + L] += bass
        mel_rng = np.random.default_rng(i)
        scale = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
        for k in range(8):
            if mel_rng.random() < 0.55:
                ns = st + int(SR * beat * 0.5 * k)
                nl = int(SR * beat * 0.9)
                tn = np.arange(nl) / SR
                f = mf(scale[mel_rng.integers(0, 4)])
                note = (np.sin(2 * np.pi * f * tn) + 0.25 * np.sin(4 * np.pi * f * tn)) * np.exp(-tn * 3.0) * 0.16
                end = min(n, ns + nl)
                music[ns:end] += note[: end - ns]
    # leve eco
    d = int(SR * beat * 0.75)
    echo = np.zeros(n)
    echo[d:] = music[:-d] * 0.35
    music = music + echo
    x = music / (np.max(np.abs(music)) + 1e-9) * 0.6
    wavfile.write(os.path.join(OUT, "music_field.wav"), SR, (x * 32767).astype(np.int16))
    # trilhas dos novos mapas (escalas diferentes para cada clima)
    music_track("music_desert", [(50, 51, 57), (50, 53, 57), (48, 51, 55), (50, 51, 57), (46, 50, 53), (48, 51, 55), (50, 54, 57), (50, 51, 57)], 84, 1, seed=10)
    music_track("music_snow", [(52, 55, 59), (48, 52, 55), (53, 57, 60), (55, 59, 62), (52, 55, 59), (57, 60, 64), (53, 57, 60), (55, 59, 62)], 60, 1, bells=True, seed=20)
    music_track("music_volcano", [(45, 48, 52), (44, 48, 51), (45, 48, 52), (41, 45, 48), (43, 46, 50), (44, 47, 51), (45, 48, 52), (40, 44, 47)], 76, 1, drums=True, mel_decay=4.0, seed=30)
    save("portal", mix(sweep(200, 1200, 1.0) * env(int(SR * 1.0), a=0.3, curve=1.5) * 0.4, bp(noise(1.0), 400, 3000) * env(int(SR * 1.0), a=0.4, curve=2) * 0.6), 0.75)
    save("equip", mix(lp(noise(0.15), 3000) * env(int(SR * 0.15), a=0.001, r=0.04), np.sin(2 * np.pi * 880 * t(0.3)) * env(int(SR * 0.3), a=0.001, r=0.1) * 0.5), 0.6)
    save("legendary", mix(*[np.pad(np.sin(2 * np.pi * f * t(0.9)) * env(int(SR * 0.9), a=0.01, r=0.35) + 0.4 * np.sin(2 * np.pi * f * 2 * t(0.9)) * env(int(SR * 0.9), a=0.01, r=0.2), (int(SR * 0.08 * i), 0)) for i, f in enumerate([523, 659, 784, 1046, 1318, 1568])]), 0.8)
    print("sons ok")


if __name__ == "__main__":
    main()
