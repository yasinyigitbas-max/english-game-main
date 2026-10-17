#!/bin/bash
# v32-voices: put the narrator TTS models into res://tts (packed into speech.pck by tools/build_packs.gd; NOT in the APK).
# Too big for git (Kokoro 311 MB), so they are fetched from the sherpa-onnx tts-models release and checked by sha256.
#   f  Female : Piper en_US-ljspeech-medium (fp32, the model that rendered voice/ clips)     -> tts/en_US-ljspeech-medium.onnx + tokens.txt
#   m  Male   : Piper en_US-joe-medium (fp32, voice_m/)                                      -> tts/en_US-joe-medium.onnx + tokens_joe.txt
#   c  Boy    : Kokoro v1.0 af_sky  (sid 10, voice_c/) } one model                          -> tts/kokoro/{model.onnx,voices.bin,tokens.txt}
#   g  Girl   : Kokoro v1.0 af_heart (sid 3,  voice_g/) }
# tts/espeak-ng-data (tracked, trimmed) is shared by all three models.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd); T="$ROOT/tts"; TMP=${TMP:-/tmp/tts_models}; mkdir -p "$TMP" "$T/kokoro"
REL=https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models
get() { [ -f "$TMP/$1.tar.bz2" ] || curl -fL -o "$TMP/$1.tar.bz2" "$REL/$1.tar.bz2"; python3 -c "import tarfile,sys;tarfile.open(sys.argv[1],'r:bz2').extractall(sys.argv[2],filter='data')" "$TMP/$1.tar.bz2" "$TMP"; }
get vits-piper-en_US-ljspeech-medium; get vits-piper-en_US-joe-medium; get kokoro-multi-lang-v1_0
cp "$TMP/vits-piper-en_US-ljspeech-medium/en_US-ljspeech-medium.onnx" "$T/"
cp "$TMP/vits-piper-en_US-joe-medium/en_US-joe-medium.onnx" "$T/"
cp "$TMP/vits-piper-en_US-joe-medium/tokens.txt" "$T/tokens_joe.txt"
cp "$TMP/kokoro-multi-lang-v1_0/"{model.onnx,voices.bin,tokens.txt} "$T/kokoro/"
cd "$T" && sha256sum -c <<'SUM'
8ceba58a4b540d4e7e7e24ad079cf0d92762a4fd334e059f12940787c6c37b3d  en_US-ljspeech-medium.onnx
5c262f54364ad8c75e5c536c2fba9a54a7375b605fcb14a3876013247a1caa6c  en_US-joe-medium.onnx
da19d3f9a439574f66c072baafced1d1c79f42d8c5981619ea9274a7ab0dbba5  tokens_joe.txt
ef3a7e4a8d1af0c9d4dc45aaae1a6242ebe24a7ed6f3d025a49eb29682784c6d  tokens.txt
b40f62b166ac8164b0627ef48a0b358eda0985e272fb03ef5252e7206305da11  kokoro/model.onnx
1c5a5b983d3d50d8586d437a51f3faa2da7919ce76a013c081e65671a3447c29  kokoro/voices.bin
6ebb6bb288f20f3ae8d004d3c2ca27697da27c037d75e81a60e2a6a663f95425  kokoro/tokens.txt
SUM
