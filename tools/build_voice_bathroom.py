"""Builds voice/bathroom_voice.bin + data/bathroom_voice_index.json from the TR table in scripts/bathroom.gd.
English: Piper en_US-ljspeech-medium (same voice as the bedroom, LJSpeech = public domain).
English only (no Turkish voice; the TR button shows Turkish text).
Index: {"en:<English>": [offset, length]}  (Ogg Vorbis 22.05 kHz)
Run: /tmp/pv/bin/python tools/build_voice_bathroom.py   (needs piper-tts in that venv, ffmpeg)"""
import json, re, os, io, wave, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "scripts/bathroom.gd"), encoding="utf8").read()
block = src[src.index("const TR := {"):src.index("\n}\n", src.index("const TR := {"))]
pairs = re.findall(r'"([^"]+)":\s*"([^"]+)"', block)
from piper import PiperVoice
en_voice = PiperVoice.load("/workspace/build_assets/piper/en_US-ljspeech-medium.onnx")
def ogg(wav_path):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-af", "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "/tmp/bv.ogg"], check=True)
    return open("/tmp/bv.ogg", "rb").read()
out = bytearray(); idx = {}
for en, tr in pairs:
    with wave.open("/tmp/bv_en.wav", "wb") as w: en_voice.synthesize_wav(en, w)
    d = ogg("/tmp/bv_en.wav"); idx["en:" + en] = [len(out), len(d)]; out += d
open(os.path.join(ROOT, "voice/bathroom_voice.bin"), "wb").write(out)
json.dump(idx, open(os.path.join(ROOT, "data/bathroom_voice_index.json"), "w", encoding="utf8"), ensure_ascii=False, indent=0)
print(len(pairs), "pairs,", len(out), "bytes")
