"""v31: voice clips for the day-2 work routines (data/work.json) + car labels -> voice/voice_007.bin + data/voice_index.json.
Narrator / player lines: Piper ljspeech (key = norm(text)); colleague / customer / pupil lines: their Piper voice
(key = "v_<voice> " + norm(text)); child voices get the same pitch chain as tools/regen_child (chunk 6). Existing keys are kept.
Run from the game root:  python3 tools/build_voice_work.py   (then tools/narrator_voices/* for the m/c/g packs)"""
import json, re, io, wave, subprocess, os
from piper import PiperVoice
P = "/workspace/build_assets/piper/"
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
idx = json.load(open("data/voice_index.json")); W = json.load(open("data/work.json"))
jobs = {j["id"]: j for j in json.load(open("data/jobs.json"))["jobs"]}
CH = 7; BIN = "voice/voice_%03d.bin" % CH
assert all(e[0] != CH for e in idx.values()) or os.path.exists(BIN)
buf = bytearray(open(BIN, "rb").read()) if os.path.exists(BIN) else bytearray()
lines = []   # (text, voice)
for c in W["categories"].values():
    lines += [(c["label"], "ljspeech"), (c["end"], "ljspeech")]
    for t in c["tasks"]:
        lines += [(t[0], "ljspeech"), (t[2], "ljspeech")]
        if t[6]: lines.append((t[6], c["people"][t[5]][2]))
    for j in c["jobs"]:
        if j and jobs.get(j, {}).get("start"): lines.append((jobs[j]["start"], "ljspeech"))
for v in W["common"].values(): lines.append((v[0], "ljspeech"))
lines += [(t, "ljspeech") for t in ["I am getting in my car.", "I am driving to work.", "I am driving to school.", "I am driving to the shop.", "I am driving to the hospital.", "Go to work", "Go to the hospital"]]
if os.path.exists("tools/voice_extra_v31.json"): lines += [tuple(x) for x in json.load(open("tools/voice_extra_v31.json"))]   # red day-2 hospital VOICE NEEDS + gaps found in QA
PIPER = {"child_m": "ryan", "child_f": "kristin"}
V = {}; n = 0
for text, voice in lines:
    k = norm(text) if voice == "ljspeech" else "v_%s %s" % (voice, norm(text))
    if k in idx: continue
    pv = PIPER.get(voice, voice)
    if pv not in V: V[pv] = PiperVoice.load(P + "en_US-%s-medium.onnx" % pv)
    b = io.BytesIO()
    with wave.open(b, "wb") as w: V[pv].synthesize_wav(text, w)
    open("/tmp/vw.wav", "wb").write(b.getvalue())
    af = "loudnorm=I=-18,aresample=22050,asetrate=22050*1.25,aresample=22050,atempo=0.85" if voice.startswith("child_") else "loudnorm=I=-18"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/vw.wav", "-af", af, "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/vw.ogg"], check=True)
    d = open("/tmp/vw.ogg", "rb").read(); idx[k] = [CH, len(buf), len(d), ""]; buf += d; n += 1
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", "/tmp/vw.ogg"], capture_output=True, text=True).stdout)
    print("%5.2fs %-10s %s" % (dur, voice, text))
open(BIN, "wb").write(buf); json.dump(idx, open("data/voice_index.json", "w"))
print("new", n, "chunk", CH, len(buf), "bytes")
