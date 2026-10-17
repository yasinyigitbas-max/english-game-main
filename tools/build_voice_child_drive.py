"""v33 child-drive (red): render the few NEW lines into res://voice_drive/<voice>/<md5(text)[:12]>.ogg.
Separate folder (no shared voice_index / bank edits, so it merges cleanly). Narrator: f (ljspeech), m (joe), c (boy), g (girl),
same filters as tools/narrator_voices/render_voices.py. Parent lines: amy / ryan (Piper, as the family v_<voice> clips).
Run: /tmp/pvd/bin/python tools/build_voice_child_drive.py   (pip install piper-tts; models in /workspace/build_assets/piper/)"""
import os, wave, subprocess, hashlib
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "/workspace/build_assets/piper/"
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]
BOY = "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,loudnorm=I=-18"
GIRL = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse,asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,loudnorm=I=-18"
CHILD = ["Add a mom or a dad first.", "We are here."] + ["My %s is driving me %s." % (w, d) for w in ("mom", "dad") for d in ("to school", "to the hospital", "to work", "home", "to the shop")]
PARENT = ["Let's go!", "Get in the car, please.", "Put on your seat belt.", "We are here. Let's go in.", "We are home."]
VOICES = {"f": ("ljspeech", "loudnorm=I=-18", CHILD), "m": ("joe", "loudnorm=I=-18", CHILD), "c": ("joe", BOY, CHILD),
          "g": ("kristin", GIRL, CHILD), "amy": ("amy", "loudnorm=I=-18", PARENT), "ryan": ("ryan", "loudnorm=I=-18", PARENT)}
from piper import PiperVoice
models = {}
for v, (model, flt, lines) in VOICES.items():
    os.makedirs(f"{R}/voice_drive/{v}", exist_ok=True)
    for t in lines:
        out = f"{R}/voice_drive/{v}/{hashlib.md5(t.encode()).hexdigest()[:12]}.ogg"
        if os.path.exists(out): continue
        if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
        with wave.open("/tmp/cdv.wav", "wb") as w: models[model].synthesize_wav(t, w)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/cdv.wav", "-af", flt] + ENC + [out], check=True)
        print(v, t, out)
