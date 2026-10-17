"""Pack cached clips into voice_<v>/voice_<v>_NNN.bin (< 20 MB chunks) + data/voice_index_<v>.json (norm key -> [chunk, off, len, ""]).
Usage: build_narrator_packs.py <game_root> lines.json   (lines without a cached clip are left out -> default clip at run time)"""
import json, sys, os, hashlib, glob
R, L = sys.argv[1], json.load(open(sys.argv[2]))
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# lines where Piper kristin drags/garbles a short line (girl clip > 1.5x the male one and +0.35 s): left out of voice_g -> default clip
SKIP_G = set(json.load(open(sys.argv[3]))) if len(sys.argv) > 3 else set()
for v in "mcg":
    chunks = [bytearray()]; idx = {}; miss = 0
    for k in sorted(L):
        p = f"{H}/cache/{v}/{hashlib.md5(L[k].encode()).hexdigest()}.ogg"
        if not os.path.exists(p) or (v == "g" and k in SKIP_G): miss += 1; continue
        d = open(p, "rb").read()
        if len(chunks[-1]) + len(d) > 20_000_000: chunks.append(bytearray())
        idx[k] = [len(chunks) - 1, len(chunks[-1]), len(d), ""]; chunks[-1] += d
    os.makedirs(f"{R}/voice_{v}", exist_ok=True)
    for f in glob.glob(f"{R}/voice_{v}/voice_{v}_*.bin"): os.remove(f)
    for c, b in enumerate(chunks): open(f"{R}/voice_{v}/voice_{v}_{c:03d}.bin", "wb").write(b)
    json.dump(idx, open(f"{R}/data/voice_index_{v}.json", "w"))
    print(v, len(idx), "lines,", miss, "missing,", round(sum(map(len, chunks)) / 1e6, 2), "MB")
