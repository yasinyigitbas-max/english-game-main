"""v33 (red) UNIVERSAL NARRATOR - clips in the chosen narrator's OWN model/speaker only (the packs' real chains):
  f: Piper en_US-ljspeech-medium, loudnorm   m: Piper en_US-joe-medium, loudnorm
  c: Kokoro v1.0 fp32 af_sky (sid 10), asetrate x1.35 chain   g: Kokoro v1.0 fp32 af_heart (sid 3), x1.25 chain
  (encoding -ar 22050 -ac 1 libvorbis q2, as every pack clip; c/g chain = blue's rerender_v32_cg.py / CREDITS house.30.2)
Steps:  A) re-render chunk 002 of the c / g packs (v32 + v33 lines were rendered with Piper joe / kristin = a different voice)
        B) re-render voice_drive/c, voice_drive/g (same problem)
        C) lines with no clip in a narrator (days 4 / 7 lines etc., list in tools/v33_own_lines.json) ->
           voice_own/<v>/<md5(norm(text))[:12]>.ogg (Audio.own_clip looks there)
Usage: python3 tools/build_voice_v33_own.py piper   (f, m)  and  /workspace/v321_venv/bin/python tools/build_voice_v33_own.py kokoro"""
import json, os, re, sys, glob, hashlib, subprocess, wave
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]
LINES = json.load(open(f"{R}/tools/v33_own_lines.json"))
DRIVE = ["Add a mom or a dad first.", "We are here."] + ["My %s is driving me %s." % (w, d) for w in ("mom", "dad") for d in ("to school", "to the hospital", "to work", "home", "to the shop")]
def own(v, t): return f"{R}/voice_own/{v}/{hashlib.md5(norm(t).encode()).hexdigest()[:12]}.ogg"
def has(v, t):
    idx = json.load(open(f"{R}/data/voice_index.json" if v == "f" else f"{R}/data/voice_index_{v}.json"))
    return norm(t) in idx
mode = sys.argv[1]
if mode == "piper":
    from piper import PiperVoice
    for v, model in (("f", "ljspeech"), ("m", "joe")):
        pv = PiperVoice.load(f"/workspace/build_assets/piper/en_US-{model}-medium.onnx")
        idx = json.load(open(f"{R}/data/voice_index.json" if v == "f" else f"{R}/data/voice_index_{v}.json"))
        os.makedirs(f"{R}/voice_own/{v}", exist_ok=True); n = 0
        for t in LINES:
            o = own(v, t)
            if norm(t) in idx or os.path.exists(o): continue
            with wave.open("/tmp/vown.wav", "wb") as w: pv.synthesize_wav(t, w)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/vown.wav", "-af", "loudnorm=I=-18"] + ENC + [o], check=True); n += 1
        print(v, "rendered", n)
else:
    import numpy as np, sherpa_onnx
    K = "/tmp/tts_models/kokoro-multi-lang-v1_0"
    kc = sherpa_onnx.OfflineTtsKokoroModelConfig(model=f"{K}/model.onnx", voices=f"{K}/voices.bin", tokens=f"{K}/tokens.txt",
                                                 data_dir=f"{K}/espeak-ng-data", lexicon=f"{K}/lexicon-us-en.txt", lang="en-us", length_scale=1.0)
    tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=kc, num_threads=6)))
    def kok(t, sid, r):
        a = tts.generate(t, sid=sid, speed=1.0); pcm = np.array(a.samples, np.float32).tobytes()
        af = f"aresample=24000,asetrate=24000*{r},aresample=24000,atempo={1 / r * 1.05:.6f},loudnorm=I=-18,aresample=22050"
        return subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(a.sample_rate), "-ac", "1", "-i", "-", "-af", af] + ENC + ["-f", "ogg", "-"],
                              input=pcm, capture_output=True, check=True).stdout
    texts = {}
    for fn in glob.glob(f"{R}/scripts/**/*.gd", recursive=True) + glob.glob(f"{R}/data/**/*.json", recursive=True) + glob.glob(f"{R}/tools/*.py"):
        if "voice_index" in fn: continue
        for t in re.findall(r'"((?:[^"\\]|\\.)*)"', open(fn, encoding="utf8").read()): texts.setdefault(norm(t), t.replace('\\"', '"'))
    for v, sid, r in (("c", 10, 1.35), ("g", 3, 1.25)):
        ip = f"{R}/data/voice_index_{v}.json"; idx = json.load(open(ip))
        keys = sorted([k for k, e in idx.items() if e[0] == 2], key=lambda k: idx[k][1])
        out = bytearray()
        for k in keys:
            d = kok(texts.get(k, k), sid, r); idx[k] = [2, len(out), len(d), idx[k][3]]; out += d
        open(f"{R}/voice_{v}/voice_{v}_002.bin", "wb").write(out); json.dump(idx, open(ip, "w"))
        print(v, "A chunk 002 re-rendered", len(keys), [k for k in keys if k not in texts])
        for t in DRIVE:
            open(f"{R}/voice_drive/{v}/{hashlib.md5(t.encode()).hexdigest()[:12]}.ogg", "wb").write(kok(t, sid, r))
        print(v, "B voice_drive re-rendered", len(DRIVE))
        os.makedirs(f"{R}/voice_own/{v}", exist_ok=True); n = 0
        for t in LINES:
            o = own(v, t)
            if norm(t) in idx or os.path.exists(o): continue
            open(o, "wb").write(kok(t, sid, r)); n += 1
        print(v, "C rendered", n)
