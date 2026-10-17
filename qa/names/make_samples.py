# v32.1 desktop samples: typed names in each narrator's FINAL model + the device chain (VoiceFx via FxCli), same params as SherpaTts.java
import sys, numpy as np, sherpa_onnx
sys.path.insert(0, '/workspace/voices_qa'); from qa import fx, save_wav
T = '/workspace/v321/tts'; E = T + '/espeak-ng-data'; O = '/workspace/v321/qa/names'
def vits(m, tok, nw):
    c = sherpa_onnx.OfflineTtsVitsModelConfig(model=f'{T}/{m}', tokens=f'{T}/{tok}', data_dir=E, noise_scale=0.667, noise_scale_w=nw, length_scale=1.0)
    return sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(vits=c, num_threads=4)))
kc = sherpa_onnx.OfflineTtsKokoroModelConfig(model=f'{T}/kokoro/model.onnx', voices=f'{T}/kokoro/voices.bin', tokens=f'{T}/kokoro/tokens.txt', data_dir=E, lang='en-us', length_scale=1.0)
kok = sherpa_onnx.OfflineTts(sherpa_onnx.OfflineTtsConfig(model=sherpa_onnx.OfflineTtsModelConfig(kokoro=kc, num_threads=4)))
M = {'f': (vits('en_US-ljspeech-medium.onnx', 'tokens.txt', 0.333), 0), 'm': (vits('en_US-joe-medium.onnx', 'tokens_joe.txt', 0.8), 0), 'c': (kok, 10), 'g': (kok, 3)}
N = {'f': ('Zandor', 'Brixley'), 'm': ('Quorin', 'Velmora'), 'c': ('Jaxtyn', 'Orvella'), 'g': ('Tamsyn', 'Krellan')}
for v, (tts, sid) in M.items():
    for lead, nm, tag in [('My name is', N[v][0], 'player'), ('This is', N[v][1], 'family')]:
        a = tts.generate(f'{lead} {nm}.', sid=sid, speed=1.0)
        x = fx(v, np.array(a.samples, np.float32), a.sample_rate)
        p = f'{O}/{v}_{tag}_{nm.lower()}.wav'; save_wav(x, p); print(p, round(len(x) / 22050, 2), 's')
