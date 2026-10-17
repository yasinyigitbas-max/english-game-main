import json, subprocess, numpy as np, sherpa_onnx, sys
R = "/workspace/v33_int"
ext = sherpa_onnx.SpeakerEmbeddingExtractor(sherpa_onnx.SpeakerEmbeddingExtractorConfig(model='/tmp/tts_models/spk.onnx', num_threads=4))
def clip(e):
    f = open(f"{R}/voice/voice_{e[0]:03d}.bin", 'rb'); f.seek(e[1]); d = f.read(e[2])
    x = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', '-', '-f', 'f32le', '-ac', '1', '-ar', '16000', '-'], input=d, capture_output=True).stdout
    return np.frombuffer(x, np.float32).copy()
def emb(x):
    s = ext.create_stream(); s.accept_waveform(16000, x); s.input_finished(); e = np.array(ext.compute(s)); return e / np.linalg.norm(e)
old = json.load(open("/tmp/v33/vi_old.json")); new = json.load(open(f"{R}/data/voice_index.json"))
for v in ["v_child_f", "v_child_m"]:
    d2 = [k for k, e in new.items() if k.startswith(v + " ") and e[0] in (8, 9)]
    E = [emb(clip(new[k])) for k in d2]; c = np.mean(E[:6], 0); c /= np.linalg.norm(c)
    base = [float(e @ c) for e in E[6:]]
    ks = [k for k, e in new.items() if k.startswith(v + " ") and e[0] == 10]
    sn = [float(emb(clip(new[k])) @ c) for k in ks]; so = [float(emb(clip(old[k])) @ c) for k in ks]
    print(v, f"day2 baseline mean {np.mean(base):.3f} min {min(base):.3f} | re-voiced mean {np.mean(sn):.3f} min {min(sn):.3f} | old clips mean {np.mean(so):.3f} min {min(so):.3f} (n={len(ks)})")
