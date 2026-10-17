"""Builds voice/voice_000.bin + data/voice_index.json with only the bedroom lines.
Reuses the 2D game's Piper clips (en_US-ljspeech-medium, LJSpeech = public domain); renders missing lines with Piper."""
import json, re, sys, os, io, wave, subprocess, base64, numpy as np
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = "/workspace/english_game_2d"
src = open(os.path.join(ROOT, "scripts/main.gd"), encoding="utf8").read()
block = src[src.index("const TR := {"):src.index("}\n", src.index("const TR := {"))]
lines = re.findall(r'"([^"]+)":', block) + ["letter " + chr(97 + i) for i in range(26)]
def norm(s):
    s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
lines += list(json.load(open(os.path.join(ROOT, "data/extra_lines.json"), encoding="utf8")).keys())   # v9: jobs, routine, family, lesson
seen = set(); lines = [l for l in lines if not (norm(l) in seen or seen.add(norm(l)))]
old = json.load(open(f"{OLD}/data/voice_index.json"))
files = {}
out = bytearray(); idx = {}; voice = None; made = []
for l in lines:
    k = norm(l)
    if k in old:
        c, off, ln, env = old[k]
        f = files.setdefault(c, open(f"{OLD}/voice/voice_{c:03d}.bin", "rb")); f.seek(off); data = f.read(ln)
    else:
        if voice is None:
            from piper import PiperVoice
            voice = PiperVoice.load("/workspace/build_assets/piper/en_US-ljspeech-medium.onnx")
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w: voice.synthesize_wav(l, w)
        open("/tmp/v.wav", "wb").write(buf.getvalue())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/v.wav", "-ar", "22050", "-c:a", "libvorbis", "-q:a", "1", "/tmp/v.ogg"], check=True)
        data = open("/tmp/v.ogg", "rb").read(); env = ""; made.append(l)
    idx[k] = [0, len(out), len(data), env]; out += data
open(os.path.join(ROOT, "voice/voice_000.bin"), "wb").write(out)
json.dump(idx, open(os.path.join(ROOT, "data/voice_index.json"), "w"))
print(len(lines), "lines,", len(made), "new:", made, len(out), "bytes")
