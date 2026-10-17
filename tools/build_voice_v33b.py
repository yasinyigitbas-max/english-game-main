"""v33 (pass 2): EVERY narrator / family / shop line of days 4-7 gets a real pre-rendered clip, so nothing plays through
generic live Piper or another voice.
  sources : data/day4.json + day7.json (every step "en" by who: me/nar/guide/puzzle -> narrator, fam*/all -> 9 family
            voices, assistant -> v_joe; every "lines" key), data/test_bank.json "say" of days 4-7, blue's days 5/6 narrator
            list (tools/days56/build_voice_days56.py collect()).
  f       : Piper ljspeech-medium -> voice/voice_012.bin (skips lines already in voice_index.json or blue's day56 index)
  family  : "v_<voice> <line>" (9 voices, child chains as day 2) + shop v_joe -> voice/voice_012.bin
  m       : Piper joe-medium -> voice_m/voice_m_004.bin (skips lines in voice_index_m.json or blue's day56 m index: same model)
  c / g   : FULL Kokoro v1.0 af_sky x1.35 / af_heart x1.25 -> voice_<v>/voice_<v>_004.bin for every line not in the MAIN
            c/g index. Blue's day56 c/g clips were Piper joe/kristin + filters (wrong model); the main pack index wins over
            the day56 alt index at runtime (day5_common.ensure_voice skips keys already in Audio.alt_index), so the Kokoro
            clips replace them.
Usage: python3 build_voice_v33b.py piper ; /workspace/v321_venv/bin/python build_voice_v33b.py kokoro ; ... check"""
import json, re, os, sys, wave, subprocess
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = "/workspace/build_assets/piper/"
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
def clean(t): t = str(t).strip(); return t[4:].strip() if t.startswith("Me: ") else t
narr, fam, shop = [], [], []
for d in (4, 7):
    j = json.load(open(f"{R}/data/day{d}.json", encoding="utf8"))
    def walk(o):
        if isinstance(o, dict):
            w = str(o.get("who", ""))
            if "en" in o and isinstance(o["en"], str):
                if w.startswith("fam") or w in ("all", "everybody"): fam.append(o["en"])
                elif w == "assistant": shop.append(o["en"])
                else: narr.append(o["en"])
            if isinstance(o.get("puzzle"), str): narr.append(o["puzzle"])
            for k, v in o.items():
                if k != "lines": walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(j)
    famset = set(fam) | set(shop)
    narr += [k for k in j.get("lines", {}) if not k.startswith("Day ") and k not in famset]
    for r in j.get("recap", []):
        if isinstance(r, list) and len(r) > 1: narr.append(r[1])
    if isinstance(j.get("dream_line"), str): narr.append(j["dream_line"])
tb = json.load(open(f"{R}/data/test_bank.json", encoding="utf8"))
narr += [q["say"] for q in tb["questions"] if q.get("day") in (4, 5, 6, 7) and q.get("say")]
g = {"__file__": f"{R}/tools/days56/build_voice_days56.py", "__name__": "x"}
src = open(g["__file__"], encoding="utf8").read(); exec(src[:src.index("def collect():")] + src[src.index("def collect():"):src.index("    return narr, voiced") + len("    return narr, voiced")], g)
narr += g["collect"]()[0]
narr += ["I had a hot chocolate.", "Now I'm going to school.", "Now I'm going shopping."]   # red hospital2 (fe7fe58) lines
narr = [t for t in dict.fromkeys(clean(t) for t in narr) if norm(t) and t not in ("...",)]
fam = [t for t in dict.fromkeys(clean(t) for t in fam) if norm(t)]; shop = [t for t in dict.fromkeys(clean(t) for t in shop) if norm(t)]
FAMV = {"amy": ("amy", ""), "kristin": ("kristin", ""), "hfc_female": ("hfc_female", ""), "lessac": ("lessac", ""), "ryan": ("ryan", ""),
        "joe": ("joe", ""), "hfc_male": ("hfc_male", ""),
        "child_f": ("kristin", "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"),
        "child_m": ("joe", "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,")}
J = lambda p: json.load(open(f"{R}/data/{p}"))
def append_chunk(binp, items):
    out = bytearray(open(binp, "rb").read()) if os.path.exists(binp) else bytearray(); res = {}
    for k, d in items: res[k] = [len(out), len(d)]; out += d
    open(binp, "wb").write(out); return res
def want_f():
    idx = J("voice_index.json"); d56 = J("day56_voice_index.json"); todo = {}
    for t in narr:
        k = norm(t)
        if k not in idx and k not in d56: todo.setdefault(k, (t, "ljspeech", ""))
    for v, (m, f) in FAMV.items():
        for t in fam:
            k = f"v_{v} {norm(t)}"
            if k not in idx and k not in d56: todo.setdefault(k, (t, m, f))
    for t in shop:
        k = f"v_joe {norm(t)}"
        if k not in idx and k not in d56: todo.setdefault(k, (t, "joe", ""))
    return todo
def want_alt(v):
    ai = J(f"voice_index_{v}.json"); d56 = J(f"day56_voice_index_{v}.json") if v == "m" else {}
    return {norm(t): t for t in narr if norm(t) not in ai and norm(t) not in d56}
mode = sys.argv[1]; report = {}
if mode == "piper":
    from piper import PiperVoice
    from concurrent.futures import ThreadPoolExecutor
    models = {}
    def piper(job):
        k, (text, model, flt) = job
        if model not in models: models[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
        tmp = f"/tmp/v33/pv_{abs(hash(k))}.wav"
        with wave.open(tmp, "wb") as w: models[model].synthesize_wav(text, w)
        o = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", tmp, "-af", flt + "loudnorm=I=-18"] + ENC + ["-f", "ogg", "-"], capture_output=True, check=True).stdout
        os.remove(tmp); return k, o
    todo = want_f(); items = [piper(j) for j in todo.items()]
    idx = J("voice_index.json"); off = append_chunk(f"{R}/voice/voice_012.bin", items)
    for k, (o, n) in off.items(): idx[k] = [12, o, n, ""]
    json.dump(idx, open(f"{R}/data/voice_index.json", "w")); report["f+family+shop"] = len(items)
    todo = want_alt("m"); items = [piper((k, (t, "joe", ""))) for k, t in todo.items()]
    ai = J("voice_index_m.json"); off = append_chunk(f"{R}/voice_m/voice_m_004.bin", items)
    for k, (o, n) in off.items(): ai[k] = [4, o, n, ""]
    json.dump(ai, open(f"{R}/data/voice_index_m.json", "w")); report["m"] = len(items)
elif mode == "kokoro":
    import numpy as np, sherpa_onnx
    K = f"{R}/tts/kokoro"
    kc = sherpa_onnx.OfflineTtsKokoroModelConfig(model=f"{K}/model.onnx", voices=f"{K}/voices.bin", tokens=f"{K}/tokens.txt", data_dir=f"{R}/tts/espeak-ng-data", lang="en-us", length_scale=1.0)
    tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=kc, num_threads=8)))
    for v, sid, r in [("c", 10, 1.35), ("g", 3, 1.25)]:
        todo = want_alt(v); items = []
        for k, t in todo.items():
            a = tts.generate(t, sid=sid, speed=1.0); pcm = np.array(a.samples, np.float32).tobytes()
            af = f"aresample=24000,asetrate=24000*{r},aresample=24000,atempo={1 / r * 1.05:.6f},loudnorm=I=-18,aresample=22050"
            items.append((k, subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(a.sample_rate), "-ac", "1", "-i", "-", "-af", af] + ENC + ["-f", "ogg", "-"], input=pcm, capture_output=True, check=True).stdout))
        ip = f"{R}/data/voice_index_{v}.json"; ai = json.load(open(ip)); off = append_chunk(f"{R}/voice_{v}/voice_{v}_004.bin", items)
        for k, (o, n) in off.items(): ai[k] = [4, o, n, ""]
        json.dump(ai, open(ip, "w")); report[v] = len(items)
else:
    report = {"f+family+shop missing": len(want_f()), **{v + " missing": len(want_alt(v)) for v in "mcg"}}
print("v33b voices", mode, report, "| narrator", len(narr), "family", len(fam), "shop", len(shop))
