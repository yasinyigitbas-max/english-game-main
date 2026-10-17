"""Days 5 + 6 voice bank (own files, nothing shared is rewritten):
  voice/voice_025.bin + data/day56_voice_index.json        narrator (Piper en_US-ljspeech-medium, public domain) + "v_<voice> <line>" NPC/family clips
  voice_<n>/voice_<n>_d56.bin + data/day56_voice_index_<n>.json   narrator packs m (joe, CC0), c (joe + boy filter), g (kristin + girl filter)
Index format = data/voice_index.json: norm key -> [chunk, offset, length, "", seconds]. scripts/story/day5_common.gd merges these into
Audio.index / Audio.alt_index at runtime (chunk 25 is opened by Audio.reopen_banks, which scans voice_000..031).
NPC / family voices: CC0 / public-domain Piper voices only (amy, kristin, joe + pitch variants). ryan / lessac / hfc_male are NOT used:
day5_common.gd maps a family member who has one of those voices to joe_deep / kristin / joe for these lines.
Only lines that are not in the bank yet are rendered. Run: python3 tools/days56/build_voice_days56.py"""
import json, re, os, wave, subprocess, sys
from multiprocessing import Pool
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = "/workspace/build_assets/piper/"
CHUNK = 25
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
BOY = "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,"
GIRL = "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,"
GTRIM = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse,"
DEEP = "asetrate=22050*0.9,aresample=22050,atempo=1.111111,"
VOICES = {"ljspeech": ("ljspeech", ""), "amy": ("amy", ""), "kristin": ("kristin", ""), "joe": ("joe", ""), "joe_deep": ("joe", DEEP),
          "child_f": ("kristin", GIRL), "child_m": ("joe", BOY),
          "m": ("joe", ""), "c": ("joe", BOY), "g": ("kristin", GTRIM + GIRL)}
FAMILY = ["amy", "kristin", "joe", "joe_deep", "child_f", "child_m"]   # + hfc_female below (existing family voice of black's livingroom.gd)
FAMILY_EXTRA = ["hfc_female"]

def collect():
    narr, voiced = [], []   # voiced: (voice, text)
    for day in (5, 6):
        d = json.load(open(f"{R}/data/day{day}.json", encoding="utf8"))
        sp = d["speakers"]
        def walk(steps):
            for s in steps:
                if "who" in s:
                    w = s["who"]
                    if w in ("me", "narr"): narr.append(s["en"])
                    elif w in ("fam0", "fam1", "famcall"): voiced.extend([(v, s["en"]) for v in FAMILY + FAMILY_EXTRA])
                    else: voiced.append((sp[w][2], s["en"]))
                if "obj" in s: narr.append(s["en"])
                if "choice" in s:
                    c = s["choice"]; narr.append(c["prompt"])
                    for o in c["opts"]:
                        if o.get("ok") or o.get("do"): narr.append(o["en"])
                        if o.get("fb"): narr.append(o["fb"])
        walk([d["alarm_after"], d["bath"]["done"], d["outing"], d["recap_end"]])
        for k in ("breakfast", "event", "couch", "taxi"): walk(d.get(k, []))
        narr.append(d["bath"]["en"])
        for q in d["review"]: narr.append(q["say"])
        for k in ("quiz", "quiz_b", "quiz_c"): narr += [q["say"] for q in d[k]]
        narr += [r[1] for r in d["recap"]]
        narr += [k for k in d["lines"] if not k.startswith("Day ") and k != "Me"]
    return narr, voiced

def render(job):
    key, text, voice, out = job
    model, flt = VOICES[voice]
    from piper import PiperVoice
    global _M
    try: _M
    except NameError: _M = {}
    if model not in _M: _M[model] = PiperVoice.load(f"{P}en_US-{model}-medium.onnx")
    w = out + ".wav"
    with wave.open(w, "wb") as f: _M[model].synthesize_wav(text, f)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-af", flt + "loudnorm=I=-18", "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", out], check=True)
    dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", out], capture_output=True, text=True).stdout.strip() or 2.0)
    os.remove(w)
    return key, out, dur

def build(name, binp, idxp, jobs_src, chunk, skip_idx):
    idx = json.load(open(idxp)) if os.path.exists(idxp) else {}
    blob = bytearray(open(binp, "rb").read()) if os.path.exists(binp) and idx else bytearray()
    if not idx: blob = bytearray()
    tmp = f"/tmp/d56v/{name}"; os.makedirs(tmp, exist_ok=True)
    jobs, seen = [], set()
    for key, text, voice in jobs_src:
        if key in idx or key in seen or key in skip_idx: continue
        seen.add(key); jobs.append((key, text, voice, f"{tmp}/{len(jobs):04d}.ogg"))
    print(name, "render", len(jobs), flush=True)
    with Pool(6) as p:
        res = p.map(render, jobs, chunksize=4)
    for key, out, dur in res:
        data = open(out, "rb").read()
        idx[key] = [chunk, len(blob), len(data), "", round(dur, 2)]; blob += data
    os.makedirs(os.path.dirname(binp), exist_ok=True)
    open(binp, "wb").write(blob); json.dump(idx, open(idxp, "w"))
    print(name, len(idx), "clips", len(blob), "bytes", flush=True)
    return idx

if __name__ == "__main__":
    narr, voiced = collect()
    main_idx = json.load(open(f"{R}/data/voice_index.json"))
    src = [(norm(t), t, "ljspeech") for t in narr] + [(f"v_{v} {norm(t)}", t, v) for v, t in voiced]
    # hfc_female family clips: model exists on the box (existing family voice); skip if missing
    src = [s for s in src if s[2] != "hfc_female" or os.path.exists(P + "en_US-hfc_female-medium.onnx")]
    VOICES["hfc_female"] = ("hfc_female", "")
    idx = build("main", f"{R}/voice/voice_{CHUNK:03d}.bin", f"{R}/data/day56_voice_index.json", src, CHUNK, main_idx)
    if "--no-packs" in sys.argv: sys.exit()
    for n in ("m", "c", "g"):
        alt = json.load(open(f"{R}/data/voice_index_{n}.json"))
        build(n, f"{R}/voice_{n}/voice_{n}_d56.bin", f"{R}/data/day56_voice_index_{n}.json", [(norm(t), t, n) for t in narr], 0, alt)
