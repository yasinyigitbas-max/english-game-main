"""Narrator/player lines = main voice index keys except character clips ("v_<voice> ..."). Text recovered like tools/build_voice_all.py.
Usage: collect_lines.py <game_root> out.json"""
import json, re, glob, sys
R = sys.argv[1]
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
texts = {}
for f in glob.glob(R + "/scripts/*.gd") + glob.glob(R + "/data/*.json"):
    for t in re.findall(r'"((?:[^"\\]|\\.)*)"', open(f, encoding="utf8").read()):
        if len(t) > 1 and re.search(r"[A-Za-z]", t): texts.setdefault(norm(t), t.replace('\\"', '"').replace("\\n", " "))
idx = json.load(open(R + "/data/voice_index.json"))
out = {k: texts.get(k, k) for k in idx if not k.startswith("v_")}
# v31: narrator lines that live in other banks (bathroom, bk extras, word clips, outdoor res://voice/<md5>.ogg) - so the setting is universal
import hashlib, os
for b in ("bathroom_voice_index", "bk_voice_index"):
    for k in json.load(open(f"{R}/data/{b}.json")): t = k[3:] if k.startswith("en:") else k; out.setdefault(norm(t), t)
for k in json.load(open(f"{R}/data/word_voice_index.json")): out.setdefault(norm(k), k)
for f in glob.glob(R + "/scripts/**/*.gd", recursive=True) + glob.glob(R + "/data/**/*.json", recursive=True):
    for t in re.findall(r'"((?:[^"\\]|\\.)*)"', open(f, encoding="utf8").read()):
        if os.path.exists(f"{R}/voice/{hashlib.md5(t.encode()).hexdigest()[:12]}.ogg"): out.setdefault(norm(t), t)
json.dump(out, open(sys.argv[2], "w"), indent=0); print(len(out), "narrator lines;", sum(1 for k in out if out[k] == k), "without original text")
