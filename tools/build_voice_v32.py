"""v32 voice lines (red hospital-fine + day-3 morning/town/evening) -> only lines without a clip are rendered.
f narrator (Piper ljspeech) + family "v_<voice> <line>" clips -> voice/voice_009.bin + data/voice_index.json (as build_voice_day2.py).
m/c/g narrator packs (joe / boy / girl, tools/narrator_voices/render_voices.py job + tools/cache) -> voice_<v>/voice_<v>_002.bin
+ data/voice_index_<v>.json (appended chunk; existing chunks untouched). Writes tools/v32_new_voice_keys.json."""
import json, re, os, sys, wave, subprocess
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, f"{R}/tools/narrator_voices")
import render_voices
P = "/workspace/build_assets/piper/"
CHUNK, ALT_CHUNK = 9, 2
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
HOSP = ["My legs are strong.", "My chest is okay.", "My ears are good.", "My eyes are perfect.", "My head is okay.", "My neck is all right.",
        "My shoulders are strong.", "My stomach is not hurting.", "My hands and fingers are perfect.", "My knees are healthy.",
        "My feet are great.", "My nose is good."]
TOWN = ["Here is the café.", "Here is the shop.", "Go to the café.", "Go to the shop.", "Go back home."]
ROUTE = ["Now I'm going to the hospital.", "Now I'm going to work.", "Go inside and talk to my family."]   # red v32-polish 12-13 (day-2 routing)
FAM = ["How was your day?", "Thank you for the shopping! Well done.", "You must be tired. Go to bed."]
D = json.load(open(f"{R}/data/day3_evening.json", encoding="utf8"))
fam = list(dict.fromkeys(FAM + [t[0] for t in D["talk"] if t[0].strip()]))
narr = HOSP + TOWN + ROUTE + [t[1] for t in D["talk"]] + [r[1] for r in D["recap"]]
for k in ("quiz", "quiz_b", "quiz_c"): narr += [q["say"] for q in D[k]]
narr += [k for k in D["lines"] if k not in fam and k != "Day 4"]
narr += ["Talk to my family.", "It was a good day.", "Apples are countable, so we ask: How many apples?", "Milk is uncountable, so we ask: How much milk?",
         "I am standing next to the sofa.", "Went, ordered, bought: this is the past simple.", "I'm waking up.", "I'm getting up.", "Start your day.",
         "Good night!", "I am dreaming about my day.", "Now a short test about my day.", "I am sleeping.", "I talked to my family.",
         "Put the words in the right order.", "I am sitting on the sofa.", "Go to bed.", "I am going to bed.", "I am lying in bed.",
         "That is right!", "Not quite."]
narr = [t for t in dict.fromkeys(narr) if t.strip()]
VOICES = {"amy": ("amy", ""), "kristin": ("kristin", ""), "hfc_female": ("hfc_female", ""), "lessac": ("lessac", ""), "ryan": ("ryan", ""),
          "joe": ("joe", ""), "hfc_male": ("hfc_male", ""),
          "child_f": ("kristin", "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"),
          "child_m": ("joe", "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,")}
made = {"f": [], "fam": [], "m": [], "c": [], "g": []}
# ---- f narrator + family
idx = json.load(open(f"{R}/data/voice_index.json"))
todo, seen = [], set()
for t in narr:
    k = norm(t)
    if k not in idx and k not in seen: seen.add(k); todo.append((k, t, "ljspeech", "", "f"))
for v, (model, flt) in VOICES.items():
    for t in fam:
        k = f"v_{v} {norm(t)}"
        if k not in idx and k not in seen: seen.add(k); todo.append((k, t, model, flt, "fam"))
binp = f"{R}/voice/voice_{CHUNK:03d}.bin"
out = bytearray(open(binp, "rb").read()) if os.path.exists(binp) else bytearray()
from piper import PiperVoice
models = {}
for k, t, model, flt, kind in todo:
    if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
    with wave.open("/tmp/v32v.wav", "wb") as w: models[model].synthesize_wav(t, w)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/v32v.wav", "-af", flt + "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/v32v.ogg"], check=True)
    data = open("/tmp/v32v.ogg", "rb").read()
    idx[k] = [CHUNK, len(out), len(data), ""]; out += data; made[kind].append(k)
if out: open(binp, "wb").write(out)
json.dump(idx, open(f"{R}/data/voice_index.json", "w"))
# ---- m/c/g narrator packs
import hashlib
for t in narr: render_voices.job(t)
for v in "mcg":
    ai = json.load(open(f"{R}/data/voice_index_{v}.json"))
    bp = f"{R}/voice_{v}/voice_{v}_{ALT_CHUNK:03d}.bin"
    ob = bytearray(open(bp, "rb").read()) if os.path.exists(bp) else bytearray()
    for t in narr:
        k = norm(t)
        if k in ai: continue
        d = open(f"{R}/tools/cache/{v}/{hashlib.md5(t.encode()).hexdigest()}.ogg", "rb").read()
        ai[k] = [ALT_CHUNK, len(ob), len(d), ""]; ob += d; made[v].append(k)
    if ob: open(bp, "wb").write(ob)
    json.dump(ai, open(f"{R}/data/voice_index_{v}.json", "w"))
json.dump(made, open(f"{R}/tools/v32_new_voice_keys.json", "w"), indent=0)
print({k: len(v) for k, v in made.items()}, "narr lines considered:", len(narr), "family lines:", len(fam))
