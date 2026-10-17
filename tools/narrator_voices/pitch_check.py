"""Listen-proxy: median F0 (autocorrelation, voiced frames) and duration of orig wav vs shifted ogg."""
import sys, glob, os, subprocess, numpy as np
def load(p):
    r = subprocess.run(["ffmpeg","-loglevel","error","-i",p,"-f","f32le","-ac","1","-ar","22050","-"],capture_output=True).stdout
    return np.frombuffer(r, np.float32)
def f0(x, sr=22050):
    out=[]
    for i in range(0, len(x)-1024, 512):
        fr = x[i:i+1024]*np.hanning(1024)
        if np.sqrt((fr**2).mean()) < 0.02: continue
        ac = np.correlate(fr, fr, "full")[1023:]; lo, hi = sr//500, sr//70
        lag = lo+np.argmax(ac[lo:hi])
        if ac[lag] > 0.4*ac[0]: out.append(sr/lag)
    return np.median(out) if out else 0
H = "/workspace/voices_blue/cache"
hs = sorted(os.path.basename(p)[:-4] for p in glob.glob(H+"/g/*.ogg"))[:int(sys.argv[1]) if len(sys.argv)>1 else 8]
for h in hs:
    w, wg = load(f"{H}/wav/{h}.wav"), load(f"{H}/wav/{h}_g.wav"); m, c, g = (load(f"{H}/{v}/{h}.ogg") for v in "mcg")
    print(h[:8], "male %.0fHz %.2fs | boy %.0fHz %.2fs (src %.2fs) | kristin %.0fHz -> girl %.0fHz %.2fs (src %.2fs)" % (f0(m), len(m)/22050, f0(c), len(c)/22050, len(w)/22050, f0(wg), f0(g), len(g)/22050, len(wg)/22050))
