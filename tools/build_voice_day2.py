"""v31 day 2 morning voice lines -> voice/voice_008.bin + entries merged into data/voice_index.json (same format: norm key ->
[chunk, offset, length, ""]). Narrator / player lines: Piper en_US-ljspeech-medium (public domain). Family replies:
"v_<voice> <line>" clips in the family voices used by livingroom.gd voice_of() (Piper amy/kristin/hfc_female/lessac/ryan/joe/hfc_male,
child_f = kristin + girl pitch filter, child_m = joe + boy pitch filter, as tools/narrator_voices/render_voices.py).
Only lines without a clip are rendered. Re-run after editing data/day2_morning.json."""
import json, re, os, io, wave, subprocess, sys
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "/workspace/build_assets/piper/"
CHUNK = 8   # black bot's v31 work lines use voice_007.bin
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
D = json.load(open(f"{R}/data/day2_morning.json", encoding="utf8"))
narr = []
for st in D["lesson"]: narr += st["say"]
for d in D["dialogue"]:
    if d["who"] == "me" and d["en"] != "{have_to}": narr.append(d["en"])
narr += [h["en"] for h in D["have_to"].values()]
for k in ("quiz", "quiz_b", "quiz_c"): narr += [q["say"] for q in D[k]]
narr += list(D["lines"].keys())
fam = [d["en"] for d in D["dialogue"] if d["who"] != "me"]
VOICES = {"amy": ("amy", ""), "kristin": ("kristin", ""), "hfc_female": ("hfc_female", ""), "lessac": ("lessac", ""), "ryan": ("ryan", ""),
          "joe": ("joe", ""), "hfc_male": ("hfc_male", ""),
          "child_f": ("kristin", "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"),
          "child_m": ("joe", "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,")}
idx = json.load(open(f"{R}/data/voice_index.json"))
todo = []   # (key, text, model, filter)
seen = set()
for t in narr:
    k = norm(t)
    if k in idx or k in seen: continue
    seen.add(k); todo.append((k, t, "ljspeech", ""))
for v, (model, flt) in VOICES.items():
    for t in fam:
        k = f"v_{v} {norm(t)}"
        if k in idx or k in seen: continue
        seen.add(k); todo.append((k, t, model, flt))
binp = f"{R}/voice/voice_{CHUNK:03d}.bin"
out = bytearray(open(binp, "rb").read()) if os.path.exists(binp) else bytearray()
from piper import PiperVoice
models = {}
made = []
for k, t, model, flt in todo:
    if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
    with wave.open("/tmp/d2v.wav", "wb") as w: models[model].synthesize_wav(t, w)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/d2v.wav", "-af", flt + "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/d2v.ogg"], check=True)
    data = open("/tmp/d2v.ogg", "rb").read()
    idx[k] = [CHUNK, len(out), len(data), ""]; out += data; made.append(k)
open(binp, "wb").write(out)
json.dump(idx, open(f"{R}/data/voice_index.json", "w"))
json.dump(made, open(f"{R}/tools/day2_new_voice_keys.json", "w"), indent=0)
print(len(made), "new clips;", len(out), "bytes in", binp)
