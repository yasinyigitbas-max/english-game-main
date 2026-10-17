"""v33 (red, hospital2 branch): render ONLY the given new narrator/player lines that have no clip yet, exactly like
build_voice_v32.py: f narrator (Piper ljspeech) -> voice/voice_009.bin + data/voice_index.json; m/c/g narrator packs
(tools/narrator_voices/render_voices.py job) -> voice_<v>/voice_<v>_002.bin + data/voice_index_<v>.json (appended).
Also adds the EN -> TR line to data/extra_lines.json. Usage: python3 tools/build_voice_v33_hosp2.py"""
import json, re, os, sys, wave, subprocess, hashlib, collections
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, f"{R}/tools/narrator_voices")
import render_voices
P = "/workspace/build_assets/piper/"
CHUNK, ALT_CHUNK = 9, 2
LINES = {"I had a hot chocolate.": "Sıcak çikolata içtim.",   # day-3 evening couch talk (was the ordering phrase)
         "Now I'm going to school.": "Şimdi okula gidiyorum.", "Now I'm going shopping.": "Şimdi alışverişe gidiyorum."}   # day-2 hospital -> school / shop
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
made = {"f": [], "m": [], "c": [], "g": []}
idx = json.load(open(f"{R}/data/voice_index.json"))
binp = f"{R}/voice/voice_{CHUNK:03d}.bin"
out = bytearray(open(binp, "rb").read())
from piper import PiperVoice
pv = None
for t in LINES:
    k = norm(t)
    if k in idx: continue
    pv = pv or PiperVoice.load(f"{P}en_US-ljspeech-medium.onnx")
    with wave.open("/tmp/v33v.wav", "wb") as w: pv.synthesize_wav(t, w)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/v33v.wav", "-af", "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/v33v.ogg"], check=True)
    data = open("/tmp/v33v.ogg", "rb").read()
    idx[k] = [CHUNK, len(out), len(data), ""]; out += data; made["f"].append(k)
if made["f"]:
    open(binp, "wb").write(out); json.dump(idx, open(f"{R}/data/voice_index.json", "w"))
for t in LINES: render_voices.job(t)
for v in "mcg":
    ai = json.load(open(f"{R}/data/voice_index_{v}.json"))
    bp = f"{R}/voice_{v}/voice_{v}_{ALT_CHUNK:03d}.bin"
    ob = bytearray(open(bp, "rb").read())
    for t in LINES:
        k = norm(t)
        if k in ai: continue
        d = open(f"{R}/tools/cache/{v}/{hashlib.md5(t.encode()).hexdigest()}.ogg", "rb").read()
        ai[k] = [ALT_CHUNK, len(ob), len(d), ""]; ob += d; made[v].append(k)
    if made[v]: open(bp, "wb").write(ob); json.dump(ai, open(f"{R}/data/voice_index_{v}.json", "w"))
ex = json.load(open(f"{R}/data/extra_lines.json", encoding="utf8"), object_pairs_hook=collections.OrderedDict)
for t, tr in LINES.items(): ex[t] = tr
open(f"{R}/data/extra_lines.json", "w", encoding="utf8").write(json.dumps(ex, ensure_ascii=False, indent=1) + "\n")
print("made", made)
