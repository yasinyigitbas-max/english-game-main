"""house.17: ONE narrator voice for the whole game. Re-renders every narration clip (bedroom/living voice_00x.bin,
bathroom_voice.bin, bk_voice.bin) with Piper en_US-ljspeech-medium and identical settings (loudnorm -18 LUFS, 22.05 kHz mono, vorbis q2).
Indexes keep their format; original sentence text is recovered from the scripts/data so punctuation/intonation is right."""
import json, re, os, io, wave, subprocess, glob, sys
from piper import PiperVoice
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = PiperVoice.load("/workspace/build_assets/piper/en_US-ljspeech-medium.onnx")
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
texts = {}
for f in glob.glob(ROOT + "/scripts/*.gd") + glob.glob(ROOT + "/data/*.json"):
    src = open(f, encoding="utf8").read()
    for t in re.findall(r'"((?:[^"\\]|\\.)*)"', src):
        if len(t) > 1 and re.search(r"[A-Za-z]", t): texts.setdefault(norm(t), t.replace('\\"', '"').replace("\\n", " "))
def render(text):
    if text.startswith("letter "): text = text[7:].upper() + "."
    b = io.BytesIO()
    with wave.open(b, "wb") as w: V.synthesize_wav(text, w)
    open("/tmp/va.wav", "wb").write(b.getvalue())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/va.wav", "-af", "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/va.ogg"], check=True)
    return open("/tmp/va.ogg", "rb").read()
# 1) main index (norm key -> [chunk, off, len, env]); envelope kept empty (lip envelope not used for these)
idx = json.load(open(ROOT + "/data/voice_index.json"))
chunks = [bytearray()]; new = {}
for i, k in enumerate(sorted(idx)):
    d = render(texts.get(k, k))
    if len(chunks[-1]) + len(d) > 20_000_000: chunks.append(bytearray())
    new[k] = [len(chunks) - 1, len(chunks[-1]), len(d), idx[k][3] if len(idx[k]) > 3 else ""]; chunks[-1] += d
    if i % 100 == 0: print("main", i, len(idx), flush=True)
for f in glob.glob(ROOT + "/voice/voice_*.bin"): os.remove(f)
for c, b in enumerate(chunks): open(ROOT + "/voice/voice_%03d.bin" % c, "wb").write(b)
json.dump(new, open(ROOT + "/data/voice_index.json", "w"))
# 2) bank indexes ("en:Text" -> [off, len])
for ix, bn in [("bathroom_voice_index.json", "bathroom_voice.bin"), ("bk_voice_index.json", "bk_voice.bin")]:
    bi = json.load(open(ROOT + "/data/" + ix)); out = bytearray(); nb = {}
    for k in bi:
        if not k.startswith("en:"): continue   # Turkish clips are not narration in the English voice; drop none silently
        d = render(k[3:]); nb[k] = [len(out), len(d)]; out += d
    for k in bi:
        if k not in nb: nb[k] = bi[k]   # (non-English keys kept as they are)
    open(ROOT + "/voice/" + bn, "wb").write(out); json.dump(nb, open(ROOT + "/data/" + ix, "w"))
    print(ix, len(nb), flush=True)
print("DONE", sum(len(c) for c in chunks))
