# speaker similarity (wespeaker resnet34 embeddings, cosine) of the v32-added clips vs OLD clips of the same pack / same family voice.
# ref = centroid of 12 old clips (chunks 0/1 for packs, chunks <9 for family voices); baseline = 12 other old clips vs that centroid.
import json, os, sys, subprocess, random, numpy as np, sherpa_onnx
R = sys.argv[1]; tag = sys.argv[2]
ext = sherpa_onnx.SpeakerEmbeddingExtractor(sherpa_onnx.SpeakerEmbeddingExtractorConfig(model='/tmp/tts_models/spk.onnx', num_threads=4))
def clip(binp, e):
    f = open(binp, 'rb'); f.seek(e[1]); d = f.read(e[2])
    x = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', '-', '-f', 'f32le', '-ac', '1', '-ar', '16000', '-'], input=d, capture_output=True).stdout
    return np.frombuffer(x, np.float32).copy()
def emb(x):
    s = ext.create_stream(); s.accept_waveform(16000, x); s.input_finished(); e = np.array(ext.compute(s)); return e / np.linalg.norm(e)
def bp(v, c): return f'{R}/voice/voice_{c:03d}.bin' if v == 'f' else f'{R}/voice_{v}/voice_{v}_{c:03d}.bin'
def cen(E): m = np.mean(E, 0); return m / np.linalg.norm(m)
def group(v, idx, old, new, label):
    random.seed(1); old = random.sample(old, min(24, len(old)))
    Eo = [emb(clip(bp(v, idx[k][0]), idx[k])) for k in old]; c = cen(Eo[:12])
    base = [float(e @ c) for e in Eo[12:]]
    sims = {k: round(float(emb(clip(bp(v, idx[k][0]), idx[k])) @ c), 3) for k in new}
    s = list(sims.values())
    r = dict(n_new=len(new), new_mean=round(np.mean(s), 3), new_min=round(min(s), 3), old_baseline_mean=round(np.mean(base), 3), old_baseline_min=round(min(base), 3))
    print(tag, label, r, flush=True); r['per_clip'] = sims; return r
res = {}
for v in 'fmcg':
    idx = json.load(open(f'{R}/data/voice_index.json' if v == 'f' else f'{R}/data/voice_index_{v}.json'))
    nc = 9 if v == 'f' else 2
    old = [k for k, e in idx.items() if e[0] < nc and not k.startswith('v_') and not k.startswith('letter') and len(k) > 12]
    new = [k for k, e in idx.items() if e[0] == nc and not k.startswith('v_')]
    res[f'pack_{v}'] = group(v, idx, old, new, f'pack {v}')
fi = json.load(open(f'{R}/data/voice_index.json'))
for fv in ['amy', 'kristin', 'hfc_female', 'lessac', 'ryan', 'joe', 'hfc_male', 'child_f', 'child_m']:
    old = [k for k, e in fi.items() if e[0] < 9 and k.startswith(f'v_{fv} ')]
    new = [k for k, e in fi.items() if e[0] == 9 and k.startswith(f'v_{fv} ')]
    res[f'family_{fv}'] = group('f', fi, old, new, f'family {fv}')
json.dump(res, open(f'{R}/qa/v32_clips/similarity_{tag}.json', 'w'), indent=1)
