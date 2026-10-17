"""v32.1: the 43 v32-added narrator clips of the Boy (c) and Girl (g) packs (voice_<v>/voice_<v>_002.bin) were rendered with
Piper (joe / kristin + pitch) instead of the packs' real voices. Re-render them with the packs' own chain:
  c: Kokoro v1.0 (FULL fp32) af_sky sid 10 -> aresample=24000,asetrate=24000*1.35,aresample=24000,atempo=1/1.35*1.05,loudnorm=I=-18,aresample=22050
  g: same with af_heart sid 3, r = 1.25;  encoding -ar 22050 -ac 1 -c:a libvorbis -q:a 2 (as every pack clip).
Keys/order unchanged; only chunk 002 of c/g + their index offsets are rewritten. Usage: python rerender_v32_cg.py (voices_qa venv)."""
import json, os, re, subprocess, sys, numpy as np, sherpa_onnx
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
src = open(f"{R}/tools/build_voice_v32.py").read(); src = src[src.index("HOSP ="):src.index("VOICES =")]
g = {"json": json, "R": R, "norm": norm}; exec(src, g)
texts = {norm(t): t for t in g["narr"]}
K = f"{R}/tts/kokoro"
kc = sherpa_onnx.OfflineTtsKokoroModelConfig(model=f"{K}/model.onnx", voices=f"{K}/voices.bin", tokens=f"{K}/tokens.txt",
                                             data_dir=f"{R}/tts/espeak-ng-data", lang="en-us", length_scale=1.0)
tts = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=kc, num_threads=4)))
for v, sid, r in [("c", 10, 1.35), ("g", 3, 1.25)]:
    ip = f"{R}/data/voice_index_{v}.json"; idx = json.load(open(ip))
    keys = sorted([k for k, e in idx.items() if e[0] == 2], key=lambda k: idx[k][1])
    miss = [k for k in keys if k not in texts]
    if miss: sys.exit(f"{v}: no source text for {miss}")
    out = bytearray()
    for k in keys:
        a = tts.generate(texts[k], sid=sid, speed=1.0)
        pcm = np.array(a.samples, np.float32).tobytes()
        af = f"aresample=24000,asetrate=24000*{r},aresample=24000,atempo={1 / r * 1.05:.6f},loudnorm=I=-18,aresample=22050"
        d = subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "f32le", "-ar", str(a.sample_rate), "-ac", "1", "-i", "-", "-af", af,
                            "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2", "-f", "ogg", "-"], input=pcm, capture_output=True, check=True).stdout
        idx[k] = [2, len(out), len(d), idx[k][3]]; out += d
    open(f"{R}/voice_{v}/voice_{v}_002.bin", "wb").write(out); json.dump(idx, open(ip, "w"))
    print(v, "re-rendered", len(keys), "clips,", len(out), "bytes")
