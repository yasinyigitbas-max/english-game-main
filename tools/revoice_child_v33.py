"""v33: the old breakfast / day-1 child family clips (v_child_f / v_child_m in voice chunks 6 and 7, made with the older
ryan/kristin + asetrate 1.25 chain) are re-rendered with the day-2 child voices (tools/build_voice_day2.py: child_f = kristin,
child_m = joe, same pitch/formant chain) so a child sounds the same on every day. New chunk voice/voice_010.bin; the index
entries of those keys are repointed (keys unchanged). Source text: the original line found in data/ + scripts/ (normalised match)."""
import json, re, os, glob, wave, subprocess
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "/workspace/build_assets/piper/"
CHUNK = 10
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
VOICES = {"child_f": ("kristin", "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"),
          "child_m": ("joe", "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,")}
texts = {}
def walk(o):
    if isinstance(o, str): texts.setdefault(norm(o), o)
    elif isinstance(o, dict):
        for k, v in o.items(): walk(k); walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for f in glob.glob(f"{R}/data/*.json"):
    if "voice_index" in f: continue
    try: walk(json.load(open(f, encoding="utf8")))
    except Exception: pass
for f in glob.glob(f"{R}/scripts/**/*.gd", recursive=True):
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', open(f, encoding="utf8").read()): texts.setdefault(norm(m.group(1)), m.group(1).replace('\\"', '"'))
idx = json.load(open(f"{R}/data/voice_index.json"))
keys = sorted([k for k, e in idx.items() if k.split(" ", 1)[0] in ("v_child_f", "v_child_m") and e[0] in (6, 7)], key=lambda k: (idx[k][0], idx[k][1]))
from piper import PiperVoice
models = {}; out = bytearray(); log = []
for k in keys:
    v, nk = k.split(" ", 1); v = v[2:]
    t = texts.get(nk) or (nk[:1].upper() + nk[1:] + ".")
    model, flt = VOICES[v]
    if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
    with wave.open("/tmp/v33/cv.wav", "wb") as w: models[model].synthesize_wav(t, w)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/v33/cv.wav", "-af", flt + "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/v33/cv.ogg"], check=True)
    d = open("/tmp/v33/cv.ogg", "rb").read()
    log.append([k, idx[k][0], t, nk in texts])
    idx[k] = [CHUNK, len(out), len(d), idx[k][3]]; out += d
open(f"{R}/voice/voice_{CHUNK:03d}.bin", "wb").write(out)
json.dump(idx, open(f"{R}/data/voice_index.json", "w"))
json.dump(log, open(f"{R}/tools/revoice_child_v33.json", "w"), indent=1)
print("re-voiced", len(keys), "child clips ->", f"voice_{CHUNK:03d}.bin", len(out), "bytes; source text found for", sum(1 for l in log if l[3]))
