"""Render narrator lines for the Male (Piper en_US-joe-medium, CC0) and Boy (joe, pitch x1.6 + formants x1.15, same duration) packs.
Usage: render_voices.py lines.json [workers]   lines.json = {norm_key: original_text}. Cache: cache/{m,c}/<md5(text)>.ogg"""
import json, sys, os, io, wave, subprocess, hashlib
from multiprocessing import Pool
H = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL = "/workspace/build_assets/piper/en_US-joe-medium.onnx"
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]   # same as tools/build_voice_all.py
BOY = "asetrate=22050*1.18,aresample=22050,atempo=0.847458,rubberband=pitch=1.6949:formant=preserved,loudnorm=I=-18"
GMODEL = "/workspace/build_assets/piper/en_US-kristin-medium.onnx"   # LibriVox reader, public domain
GIRL = "asetrate=22050*1.15,aresample=22050,atempo=0.869565,rubberband=pitch=1.4348:formant=preserved,loudnorm=I=-18"
GTRIM = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse,"
V = None; VG = None
def job(text):
    global V, VG
    h = hashlib.md5(text.encode()).hexdigest()
    m, c, g = f"{H}/cache/m/{h}.ogg", f"{H}/cache/c/{h}.ogg", f"{H}/cache/g/{h}.ogg"
    if os.path.exists(m) and os.path.exists(c) and os.path.exists(g): return 0
    from piper import PiperVoice
    if V is None: V = PiperVoice.load(MODEL); VG = PiperVoice.load(GMODEL)
    t = text[7:].upper() + "." if text.startswith("letter ") else text
    w = f"{H}/cache/wav/{h}.wav"; wg = f"{H}/cache/wav/{h}_g.wav"
    if not os.path.exists(wg):
        with wave.open(w, "wb") as f: V.synthesize_wav(t, f)
        with wave.open(wg + ".tmp", "wb") as f: VG.synthesize_wav(t, f)
        os.replace(wg + ".tmp", wg)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wg, "-af", GTRIM + GIRL] + ENC + [g + ".tmp.ogg"], check=True)
    os.replace(g + ".tmp.ogg", g)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-af", "loudnorm=I=-18"] + ENC + [m + ".tmp.ogg"], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", w, "-af", BOY] + ENC + [c + ".tmp.ogg"], check=True)
    os.replace(m + ".tmp.ogg", m); os.replace(c + ".tmp.ogg", c)
    return 1
if __name__ == "__main__":
    texts = sorted(set(json.load(open(sys.argv[1])).values()))
    n = 0
    with Pool(int(sys.argv[2]) if len(sys.argv) > 2 else 6) as p:
        for i, r in enumerate(p.imap_unordered(job, texts, chunksize=4)):
            n += r
            if i % 100 == 0: print(i, len(texts), flush=True)
    print("DONE", len(texts), "rendered", n)
