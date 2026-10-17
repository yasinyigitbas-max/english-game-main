"""v31 cafe/shop voice: narrator/player lines -> Piper ljspeech (key norm(text)); NPC lines -> their Piper voice
(key "v_<voice> " + norm(text)); all into voice/voice_015.bin + data/voice_index.json. Then the m/c/g narrator packs:
renders via tools/narrator_voices/render_voices.py job() and appends voice_<v>/voice_<v>_002.bin + data/voice_index_<v>.json.
Voices used are commercial-OK only: ljspeech (PD), amy, joe, kristin, hfc_female (no ryan / hfc_male / lessac)."""
import json, re, io, wave, subprocess, os, sys, hashlib
sys.path.insert(0, "tools/narrator_voices")
from piper import PiperVoice
P = "/workspace/build_assets/piper/"
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
D = json.load(open("data/cafe_shop.json")); idx = json.load(open("data/voice_index.json"))
NPCV = {"cafe": {"barista": "amy", "c1": "kristin", "c2": "joe", "c3": "hfc_female"}, "shop": {"assistant": "joe", "c1": "kristin", "c2": "hfc_female"}}
lines = []
for place in ("cafe", "shop"):
    for st in D[place]["lesson"]: lines += [(s, "ljspeech") for s in st["say"]]
    for k in ("quiz", "quiz_b", "quiz_c"): lines += [(q["say"], "ljspeech") for q in D[place][k]]
    for b in list(D["beats"][place].values()) + list(D["npc"][place].values()):
        for who, en, _ in b: lines.append((en, "ljspeech" if who in ("me", "narr") else NPCV[place][who]))
    for v in NPCV[place].values(): lines.append(("Nice to see you again!", v))
for en in ["Go to the counter.", "Sit at a table.", "Take a basket.", "Get six apples.", "Get a bottle of milk.", "Get a loaf of bread.", "Pay at the checkout.", "Go outside.",
           "Now a short lesson and test on your phone.", "I'm taking a basket.", "Well done! You finished the cafe.", "Well done! You finished the shop.", "Talk to the customers."]:
    lines.append((en, "ljspeech"))
CH = 15; BIN = "voice/voice_%03d.bin" % CH
buf = bytearray(open(BIN, "rb").read()) if os.path.exists(BIN) else bytearray()
V = {}; n = 0; narr = {}
for text, voice in lines:
    k = norm(text) if voice == "ljspeech" else "v_%s %s" % (voice, norm(text))
    if voice == "ljspeech": narr[k] = text
    if k in idx: continue
    if voice not in V: V[voice] = PiperVoice.load(P + "en_US-%s-medium.onnx" % voice)
    b = io.BytesIO()
    with wave.open(b, "wb") as w: V[voice].synthesize_wav(text, w)
    open("/tmp/vp.wav", "wb").write(b.getvalue())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/vp.wav", "-af", "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/vp.ogg"], check=True)
    d = open("/tmp/vp.ogg", "rb").read(); idx[k] = [CH, len(buf), len(d), ""]; buf += d; n += 1
open(BIN, "wb").write(buf); json.dump(idx, open("data/voice_index.json", "w"))
print("main: new", n, "chunk", CH, len(buf), "bytes; narrator lines", len(narr))
json.dump(narr, open("/tmp/places_narr.json", "w"))
# ---- m/c/g packs
import render_voices as RV
from multiprocessing import Pool
todo = sorted(set(narr.values()))
with Pool(6) as p: r = sum(p.map(RV.job, todo))
print("packs rendered", r)
H = os.path.dirname(os.path.abspath("tools/narrator_voices/x"))
for v in "mcg":
    vi = json.load(open(f"data/voice_index_{v}.json"))
    chunks = sorted(int(f[-7:-4]) for f in os.listdir(f"voice_{v}") if f.endswith(".bin"))
    ch = chunks[-1] + 1 if not any(e[0] == chunks[-1] and False for e in vi.values()) else chunks[-1]
    path = f"voice_{v}/voice_{v}_{ch:03d}.bin"; b = bytearray(open(path, "rb").read()) if os.path.exists(path) else bytearray(); add = 0
    for k, t in narr.items():
        if k in vi: continue
        f = f"tools/cache/{v}/{hashlib.md5(t.encode()).hexdigest()}.ogg"
        if not os.path.exists(f): continue
        d = open(f, "rb").read(); vi[k] = [ch, len(b), len(d), ""]; b += d; add += 1
    if add: open(path, "wb").write(b); json.dump(vi, open(f"data/voice_index_{v}.json", "w"))
    print(v, "added", add, "->", path)
