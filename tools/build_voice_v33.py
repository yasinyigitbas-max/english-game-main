"""v33 voice clips for red's days 4 + 7 (MERGE_NOTES_days_4_7.md section 5 + test_bank 'say' lines of days 4/7) -> only lines
without a clip are rendered, existing chunks untouched.
  narrator f  : Piper en_US-ljspeech-medium, loudnorm            -> voice/voice_011.bin + data/voice_index.json
  family      : "v_<voice> <line>" for the 9 family voices (Piper amy/kristin/hfc_female/lessac/ryan/joe/hfc_male,
                child_f = kristin + girl chain, child_m = joe + boy chain, as build_voice_day2.py) -> voice/voice_011.bin
  shop        : "v_joe <line>" (the shop assistant)              -> voice/voice_011.bin
  narrator m  : Piper en_US-joe-medium, loudnorm                  -> voice_m/voice_m_003.bin + data/voice_index_m.json
  narrator c/g: FULL Kokoro v1.0 fp32 af_sky x1.35 / af_heart x1.25 (as tools/rerender_v32_cg.py) -> voice_<v>/voice_<v>_003.bin
Usage: python3 build_voice_v33.py piper     (system python: f, family, shop, m)
       <venv with sherpa_onnx>/python build_voice_v33.py kokoro   (c, g)"""
import json, re, os, sys, wave, subprocess
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "/workspace/build_assets/piper/"
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
notes = open(f"{R}/MERGE_NOTES_days_4_7.md", encoding="utf8").read()
sec = notes[notes.index("## 5."):notes.index("## 6.")]
cats = {}; cur = None
for ln in sec.splitlines():
    if ln.startswith("### "): cur = ln[4:].lower(); continue
    if cur and ln.startswith("- "): cats.setdefault(cur, []).append(ln[2:].strip())
narr, fam, shop = [], [], []
for c, ls in cats.items():
    if c.startswith("narrator") or c.startswith("test bank"): narr += ls
    elif c.startswith("family"): fam += ls
    elif c.startswith("shop"): shop += ls
tb = json.load(open(f"{R}/data/test_bank.json", encoding="utf8"))
narr += [q["say"] for q in tb["questions"] if q.get("day") in (4, 7) and q.get("say")]
narr = [t for t in dict.fromkeys(narr) if t.strip()]; fam = [t for t in dict.fromkeys(fam) if t.strip()]; shop = list(dict.fromkeys(shop))
FAMV = {"amy": ("amy", ""), "kristin": ("kristin", ""), "hfc_female": ("hfc_female", ""), "lessac": ("lessac", ""), "ryan": ("ryan", ""),
        "joe": ("joe", ""), "hfc_male": ("hfc_male", ""),
        "child_f": ("kristin", "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"),
        "child_m": ("joe", "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,")}
report = {}
def append_chunk(binp, items):   # items: [(key, oggbytes)] -> offsets
    out = bytearray(open(binp, "rb").read()) if os.path.exists(binp) else bytearray(); res = {}
    for k, d in items: res[k] = [len(out), len(d)]; out += d
    open(binp, "wb").write(out); return res
if sys.argv[1] == "piper":
    from piper import PiperVoice
    models = {}
    def piper(model, text, flt):
        if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
        with wave.open("/tmp/v33/pv.wav", "wb") as w: models[model].synthesize_wav(text, w)
        return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", "/tmp/v33/pv.wav", "-af", flt + "loudnorm=I=-18"] + ENC + ["-f", "ogg", "-"], capture_output=True, check=True).stdout
    idx = json.load(open(f"{R}/data/voice_index.json")); todo = []; seen = set()
    for t in narr:
        k = norm(t)
        if k not in idx and k not in seen: seen.add(k); todo.append((k, t, "ljspeech", ""))
    for v, (m, f) in FAMV.items():
        for t in fam:
            k = f"v_{v} {norm(t)}"
            if k not in idx and k not in seen: seen.add(k); todo.append((k, t, m, f))
    for t in shop:
        k = f"v_joe {norm(t)}"
        if k not in idx and k not in seen: seen.add(k); todo.append((k, t, "joe", ""))
    items = [(k, piper(m, t, f)) for k, t, m, f in todo]
    off = append_chunk(f"{R}/voice/voice_011.bin", items)
    for k, (o, n) in off.items(): idx[k] = [11, o, n, ""]
    json.dump(idx, open(f"{R}/data/voice_index.json", "w"))
    report["f+family+shop"] = len(items)
    ai = json.load(open(f"{R}/data/voice_index_m.json")); todo = [(norm(t), t) for t in narr if norm(t) not in ai]
    todo = list(dict(todo).items())
    items = [(k, piper("joe", t, "")) for k, t in todo]
    off = append_chunk(f"{R}/voice_m/voice_m_003.bin", items)
    for k, (o, n) in off.items(): ai[k] = [3, o, n, ""]
    json.dump(ai, open(f"{R}/data/voice_index_m.json", "w")); report["m"] = len(items)
else:
    import numpy as np, sherpa_onnx
    K = f"{R}/tts/kokoro"
    kc = sherpa_onnx.OfflineTtsKokoroModelConfig(model=f"{K}/model.onnx", voices=f"{K}/voices.bin", tokens=f"{K}/tokens.txt", data_dir=f"{R}/tts/espeak-ng-data", lang="en-us", length_scale=1.0)
    tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=kc, num_threads=8)))
    for v, sid, r in [("c", 10, 1.35), ("g", 3, 1.25)]:
        ip = f"{R}/data/voice_index_{v}.json"; ai = json.load(open(ip))
        todo = list(dict((norm(t), t) for t in narr if norm(t) not in ai).items()); items = []
        for k, t in todo:
            a = tts.generate(t, sid=sid, speed=1.0); pcm = np.array(a.samples, np.float32).tobytes()
            af = f"aresample=24000,asetrate=24000*{r},aresample=24000,atempo={1 / r * 1.05:.6f},loudnorm=I=-18,aresample=22050"
            items.append((k, subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(a.sample_rate), "-ac", "1", "-i", "-", "-af", af] + ENC + ["-f", "ogg", "-"], input=pcm, capture_output=True, check=True).stdout))
        off = append_chunk(f"{R}/voice_{v}/voice_{v}_003.bin", items)
        for k, (o, n) in off.items(): ai[k] = [3, o, n, ""]
        json.dump(ai, open(ip, "w")); report[v] = len(items)
print("v33 voices", sys.argv[1], report, "| narrator lines", len(narr), "family lines", len(fam), "shop", len(shop))
