"""Procedural (original, CC0) cafe/shop music loops + sfx -> music/cafe_lofi.ogg, music/shop_pop.ogg, sfx/place_*.ogg"""
import numpy as np, subprocess
SR = 22050
rng = np.random.default_rng(7)
def note(f, dur, kind="ep", amp=0.2):
    t = np.arange(int(dur * SR)) / SR
    if kind == "ep":   # electric-piano-ish: sine + soft 2nd harmonic + tine, exp decay
        env = np.exp(-t * 2.2) * (1 - np.exp(-t * 200))
        s = np.sin(2*np.pi*f*t) + 0.25*np.sin(2*np.pi*2*f*t)*np.exp(-t*6) + 0.08*np.sin(2*np.pi*7*f*t)*np.exp(-t*30)
    elif kind == "bass":
        env = np.exp(-t * 3.0) * (1 - np.exp(-t * 300)); s = np.sin(2*np.pi*f*t) + 0.3*np.sin(2*np.pi*2*f*t)
    elif kind == "pluck":
        env = np.exp(-t * 5.0) * (1 - np.exp(-t * 400)); s = np.sign(np.sin(2*np.pi*f*t)) * 0.3 + np.sin(2*np.pi*f*t)
    return s * env * amp
def mtof(m): return 440 * 2 ** ((m - 69) / 12)
def put(buf, x, at):
    i = int(at * SR); buf[i:i+len(x)] += x[:max(0, len(buf)-i)]
def song(chords, bpm, bars_per, loops, kind, melody, swing=0.0, drums="brush"):
    beat = 60 / bpm; bar = beat * 4; total = bar * bars_per * len(chords) * loops
    buf = np.zeros(int(total * SR) + SR)
    for L in range(loops):
        for ci, ch in enumerate(chords):
            t0 = (L * len(chords) + ci) * bar * bars_per
            for b in range(bars_per):
                tb = t0 + b * bar
                for k, m in enumerate(ch[1:]): put(buf, note(mtof(m), bar * 1.1, kind, 0.07), tb + k * 0.012 + (beat * 2 if b % 2 else 0) * 0)
                put(buf, note(mtof(ch[0] - 12), beat * 1.8, "bass", 0.16), tb); put(buf, note(mtof(ch[0] - 12 + 7), beat * 1.8, "bass", 0.12), tb + beat * 2)
                for i in range(8):   # hats / brushes
                    tt = tb + i * beat / 2 + (swing * beat / 2 if i % 2 else 0)
                    n = rng.standard_normal(int(0.06 * SR)) * np.exp(-np.arange(int(0.06 * SR)) / SR * (60 if drums == "brush" else 90))
                    put(buf, n * (0.025 if i % 2 else 0.04), tt)
                for i in (0, 2):   # soft kick
                    tk = np.arange(int(0.25 * SR)) / SR; put(buf, np.sin(2*np.pi*(50 + 80*np.exp(-tk*25))*tk) * np.exp(-tk*12) * 0.22, tb + i * beat)
                for i in (1, 3):   # snare / rim
                    n = rng.standard_normal(int(0.12 * SR)) * np.exp(-np.arange(int(0.12 * SR)) / SR * 30); put(buf, n * (0.05 if drums == "brush" else 0.08), tb + i * beat)
            for j, (off, m, d) in enumerate(melody[ci % len(melody)]):
                put(buf, note(mtof(m), d * beat + 0.3, "pluck" if kind == "pluck" else "ep", 0.09), t0 + off * beat + (swing * beat / 2 if (off * 2) % 2 else 0))
    buf = buf[:int(total * SR)]
    # light room reverb (comb)
    out = buf.copy()
    for d, g in ((0.031, 0.25), (0.047, 0.2), (0.071, 0.15)): k = int(d * SR); out[k:] += buf[:-k] * g
    return out / (np.max(np.abs(out)) + 1e-9) * 0.7
def write(name, x):
    raw = (np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes()
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis", "-q:a", "3", name], input=raw, check=True)
# cafe: lo-fi jazz ii-V-I-vi in F, 78 bpm, swing
cafe = song([[67, 64, 67, 70, 74], [72, 64, 67, 70, 72], [65, 64, 69, 72, 76], [62, 65, 69, 72, 76]], 78, 2, 2, "ep",
            [[(0, 76, 1), (1.5, 74, 0.5), (2, 72, 1), (3, 69, 1), (4.5, 72, 1), (6, 74, 2)], [(0, 76, 1.5), (2, 79, 1), (3.5, 76, 0.5), (4, 74, 2)],
             [(0, 72, 1), (1, 76, 1), (2, 77, 1), (3, 76, 1), (4, 72, 3)], [(0, 74, 1), (1.5, 72, 0.5), (2, 69, 2), (5, 72, 1), (6, 74, 1)]], swing=0.33)
write("music/cafe_lofi.ogg", cafe)
# shop: light pop I-V-vi-IV in C, 112 bpm
shop = song([[60, 64, 67, 72], [67, 62, 67, 71], [69, 64, 69, 72], [65, 65, 69, 72]], 112, 2, 3, "pluck",
            [[(0, 79, 0.5), (0.5, 76, 0.5), (1, 72, 1), (2, 74, 0.5), (2.5, 76, 0.5), (3, 79, 1), (5, 77, 0.5), (5.5, 76, 0.5), (6, 74, 1.5)],
             [(0, 74, 1), (1, 79, 1), (2, 78, 0.5), (2.5, 79, 0.5), (3, 74, 2), (6, 71, 1)], [(0, 76, 0.5), (0.5, 79, 0.5), (1, 81, 1.5), (3, 79, 1), (4, 76, 2)],
             [(0, 77, 1), (1, 76, 0.5), (1.5, 74, 0.5), (2, 72, 2), (5, 74, 1), (6, 76, 1.5)]], drums="pop")
write("music/shop_pop.ogg", shop)
def sfx(name, x): write("sfx/%s.ogg" % name, x / (np.max(np.abs(x)) + 1e-9) * 0.8)
t = np.arange(int(0.18 * SR)) / SR; sfx("place_beep", np.sin(2*np.pi*1850*t) * (t < 0.12) * np.exp(-t * 4))
t = np.arange(int(1.2 * SR)) / SR; sfx("place_till", sum(np.sin(2*np.pi*f*t) * np.exp(-t * d) for f, d in ((2093, 3), (2637, 4), (3136, 5))) + 0.3 * rng.standard_normal(len(t)) * np.exp(-t * 40))
t = np.arange(int(1.4 * SR)) / SR; sfx("place_bell", sum(np.sin(2*np.pi*f*t) * np.exp(-t * 2.5) * (t >= o) for f, o in ((1568, 0), (1319, 0.18))))
t = np.arange(int(0.4 * SR)) / SR; sfx("place_clink", (np.sin(2*np.pi*3400*t) + 0.6 * np.sin(2*np.pi*5100*t)) * np.exp(-t * 18))
t = np.arange(int(2.2 * SR)) / SR; n = rng.standard_normal(len(t)); sfx("place_steam", np.convolve(n, np.ones(6)/6, "same") * np.minimum(1, t * 4) * np.exp(-np.maximum(0, t - 1.6) * 6) * (0.6 + 0.4 * np.sin(2*np.pi*7*t)))
t = np.arange(int(0.35 * SR)) / SR; sfx("place_coins", sum(np.sin(2*np.pi*f*t) * np.exp(-(t - o) * 25) * (t >= o) for f, o in ((4200, 0), (3700, 0.07), (4600, 0.13), (3900, 0.2))))
t = np.arange(int(0.6 * SR)) / SR; n = rng.standard_normal(len(t)); sfx("place_bag", np.convolve(n, np.ones(3)/3, "same") * np.exp(-t * 6) * (0.5 + 0.5 * np.abs(np.sin(2*np.pi*9*t))))
print("audio ok")
