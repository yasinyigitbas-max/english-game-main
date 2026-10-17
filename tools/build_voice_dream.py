"""v30.5: slower dream narration. Every dream sentence gets its own clip under key "dream <norm(sentence)>":
default ljspeech + Male joe (Piper length_scale 1.2), Boy/Girl Kokoro (speed 0.87, same pitch chains as the packs).
Narrator caches use text = sentence + two spaces (own md5, so the normal-speed clip of the same sentence is untouched).
Writes voice/voice_007.bin + data/voice_index.json, tools/cache/{m,c,g}, /tmp/kcache/{c,g}, tools/dream_lines.json."""
import json, re, io, wave, subprocess, os, hashlib, sys
from piper import PiperVoice, SynthesisConfig
P = "/workspace/build_assets/piper/"
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
def sents(t): return [x.strip() for x in re.findall(r"[^.!?]+[.!?]", t)]
LINES = ["I am dreaming about yesterday.", "I woke up. I washed my face. I brushed my teeth.",
	"I had breakfast.", "I saw a cat.", "A bus hit me.", "I went to the hospital.", "I was fine in the end.",
	"This is the past simple. Have becomes had. Go becomes went. Am and is become was."]
S = []; [S.append(s) for t in LINES for s in sents(t) if s not in S]
ENC = ["-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "2"]
SLOW = SynthesisConfig(length_scale=1.2)
idx = json.load(open("data/voice_index.json")); CH = 7; BIN = "voice/voice_%03d.bin" % CH; buf = bytearray(open(BIN, "rb").read())
lj = PiperVoice.load(P + "en_US-ljspeech-medium.onnx"); joe = PiperVoice.load(P + "en_US-joe-medium.onnx")
def dur(f): return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f], capture_output=True, text=True).stdout)
def piper(v, t, out, af="loudnorm=I=-18"):
	with wave.open("/tmp/dr.wav", "wb") as w: v.synthesize_wav(t, w, syn_config=SLOW)
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/dr.wav", "-af", af] + ENC + [out], check=True)
dl = {}
for s in S:
	k = "dream " + norm(s); mk = s + "  "; h = hashlib.md5(mk.encode()).hexdigest(); dl[k] = mk
	if k not in idx:
		piper(lj, s, "/tmp/dr.ogg"); d = open("/tmp/dr.ogg", "rb").read(); idx[k] = [CH, len(buf), len(d), ""]; buf += d
		print("%5.2fs default %s" % (dur("/tmp/dr.ogg"), s))
	m = "tools/cache/m/%s.ogg" % h
	if not os.path.exists(m): piper(joe, s, m)
open(BIN, "wb").write(buf); json.dump(idx, open("data/voice_index.json", "w")); json.dump(dl, open("tools/dream_lines.json", "w"), indent=1)
# Kokoro (Boy af_sky x1.35, Girl af_heart x1.25) at speed 0.87, via the Kokoro venv
K = r'''
import json,hashlib,subprocess,os,soundfile as sf
from kokoro_onnx import Kokoro
K=Kokoro('/tmp/kmodel/kokoro.onnx','/tmp/kmodel/voices.bin')
for k,mk in json.load(open('tools/dream_lines.json')).items():
  h=hashlib.md5(mk.encode()).hexdigest()
  for v,(vo,r) in {"c":("af_sky",1.35),"g":("af_heart",1.25)}.items():
    out=f"/tmp/kcache/{v}/{h}.ogg"
    if os.path.exists(out): continue
    a,sr=K.create(mk.strip(),voice=vo,speed=0.87,lang='en-us'); w=out+".wav"; sf.write(w,a,sr)
    af=f"aresample=24000,asetrate=24000*{r},aresample=24000,atempo={round(1/r*1.05,4)},loudnorm=I=-18,aresample=22050"
    subprocess.run(["ffmpeg","-y","-loglevel","error","-i",w,"-af",af,"-ar","22050","-ac","1","-c:a","libvorbis","-q:a","2",out],check=True); os.remove(w)
    subprocess.run(["cp",out,f"tools/cache/{v}/{h}.ogg"],check=True)
print("KOK DONE")
'''
open("/tmp/dr_k.py", "w").write(K)
subprocess.run(["/tmp/cv/bin/python", "/tmp/dr_k.py"], check=True)
print("dream sentences", len(S))
