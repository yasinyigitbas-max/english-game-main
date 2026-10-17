"""List lines whose clip length differs a lot between packs (ogg duration via vorbis granule, fast)."""
import json, hashlib, subprocess, sys
L = json.load(open(sys.argv[1]))
def dur(p): return float(subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",p],capture_output=True,text=True).stdout or 0)
out = []
for k, t in L.items():
    h = hashlib.md5(t.encode()).hexdigest(); m, g = dur(f"cache/m/{h}.ogg"), dur(f"cache/g/{h}.ogg")
    if g > 1.5 * m and g - m > 0.35: out.append((k, round(m, 2), round(g, 2)))
print(len(out)); [print(o) for o in out]
