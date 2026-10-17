# v32.1: Kokoro v1.0 fp32 vs int8 (sherpa-onnx kokoro-int8-multi-lang-v1_0) for c = af_sky (sid 10) and g = af_heart (sid 3).
# Both go through the SAME device chain (VoiceFx via FxCli), then: speaker-embedding cosine (wespeaker resnet34),
# DTW log-mel distance (dB) and LTAS cosine, plus f0 median; reference: fp32 vs itself is 1.0 / 0 dB.
import sys, json, numpy as np, sherpa_onnx, librosa
sys.path.insert(0, '/workspace/voices_qa'); from qa import fx, save_wav, ltas_cos
T = '/tmp/tts_models'; OUT = '/workspace/v321/qa/kokoro_int8'
def kok(model):
    k = sherpa_onnx.OfflineTtsKokoroModelConfig(model=model, voices=f'{T}/kokoro-multi-lang-v1_0/voices.bin',
        tokens=f'{T}/kokoro-multi-lang-v1_0/tokens.txt', data_dir='/workspace/v321/tts/espeak-ng-data', lang='en-us', length_scale=1.0)
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=k, num_threads=4)))
full = kok(f'{T}/kokoro-multi-lang-v1_0/model.onnx'); q8 = kok(f'{T}/kokoro-int8-multi-lang-v1_0/model.int8.onnx')
ext = sherpa_onnx.SpeakerEmbeddingExtractor(sherpa_onnx.SpeakerEmbeddingExtractorConfig(model=f'{T}/spk.onnx', num_threads=4))
def emb(x):
    s = ext.create_stream(); s.accept_waveform(22050, x); s.input_finished(); e = np.array(ext.compute(s)); return e / np.linalg.norm(e)
def lm(x): return librosa.power_to_db(librosa.feature.melspectrogram(y=x, sr=22050, n_fft=1024, hop_length=256, n_mels=64), ref=1.0)
def dtw_db(a, b):
    A, B = lm(a), lm(b); D, wp = librosa.sequence.dtw(A, B, metric='euclidean')
    return float(np.mean([np.sqrt(np.mean((A[:, i] - B[:, j]) ** 2)) for i, j in wp]))
def f0(x):
    f, v, _ = librosa.pyin(x.astype(np.float64), fmin=80, fmax=800, sr=22050, frame_length=1024); f = f[v]; return float(np.nanmedian(f)) if len(f) else 0
LINES = ['My name is Zandor.', 'This is Brixley.', 'My name is Jaxtyn.', 'This is Orvella.', 'Good morning! It is time to brush your teeth.']
res = {}
for v, sid in [('c', 10), ('g', 3)]:
    rows = []; Ef = []; Eq = []
    for i, t in enumerate(LINES):
        a = full.generate(t, sid=sid, speed=1.0); b = q8.generate(t, sid=sid, speed=1.0)
        xa = fx(v, np.array(a.samples, np.float32), a.sample_rate); xb = fx(v, np.array(b.samples, np.float32), b.sample_rate)
        save_wav(xa, f'{OUT}/{v}_{i}_fp32.wav'); save_wav(xb, f'{OUT}/{v}_{i}_int8.wav')
        ea, eb = emb(xa), emb(xb); Ef.append(ea); Eq.append(eb)
        r = dict(line=t, spk_cos=round(float(ea @ eb), 4), dtw_logmel_db=round(dtw_db(xa, xb), 2), ltas_cos=round(float(ltas_cos(xa, xb)), 4),
                 f0_fp32=round(f0(xa), 1), f0_int8=round(f0(xb), 1), dur_fp32=round(len(xa) / 22050, 2), dur_int8=round(len(xb) / 22050, 2))
        rows.append(r); print(v, r, flush=True)
    # context: how far apart two DIFFERENT voices are (c vs g, fp32) and fp32 line-to-line spread of the same voice
    res[v] = dict(lines=rows, mean_spk_cos=round(float(np.mean([r['spk_cos'] for r in rows])), 4),
                  mean_dtw_db=round(float(np.mean([r['dtw_logmel_db'] for r in rows])), 2),
                  voice_centroid_cos=round(float((np.mean(Ef, 0) / np.linalg.norm(np.mean(Ef, 0))) @ (np.mean(Eq, 0) / np.linalg.norm(np.mean(Eq, 0)))), 4), _E=np.mean(Ef, 0))
cE, gE = res['c'].pop('_E'), res['g'].pop('_E')
res['reference_c_vs_g_fp32_spk_cos'] = round(float(cE @ gE / np.linalg.norm(cE) / np.linalg.norm(gE)), 4)
a = full.generate(LINES[0], sid=10, speed=1.0); b = full.generate(LINES[0], sid=3, speed=1.0)
res['reference_c_vs_g_same_line_dtw_db'] = round(dtw_db(fx('c', np.array(a.samples, np.float32), 24000), fx('g', np.array(b.samples, np.float32), 24000)), 2)
json.dump(res, open(f'{OUT}/similarity.json', 'w'), indent=1); print(json.dumps({k: v for k, v in res.items() if not isinstance(v, dict)}), res['c']['mean_spk_cos'], res['g']['mean_spk_cos'], res['c']['mean_dtw_db'], res['g']['mean_dtw_db'])
