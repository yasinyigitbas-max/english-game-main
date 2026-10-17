"""Days 5-6 voice coverage: every narrator / player line in f (ljspeech) + m / c / g, every family line in all 9 family voice ids,
every NPC line in its speaker's voice. Prints a per-voice table; exit 1 if anything is missing."""
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from build_voice_days56 import collect, norm, FAMILY, R
narr, voiced = collect()
main = json.load(open(f"{R}/data/voice_index.json")); mine = json.load(open(f"{R}/data/day56_voice_index.json"))
have = set(main) | set(mine)
rows, miss = {}, []
def chk(voice, key, t):
    r = rows.setdefault(voice, [0, 0]); r[1] += 1
    if key in have_v[voice]: r[0] += 1
    else: miss.append((voice, t))
have_v = {v: have for v in ["f"] + FAMILY + ["joe_deep", "lessac", "hfc_male", "hfc_female", "child_m"]}
for n in ("m", "c", "g"):
    have_v[n] = set(json.load(open(f"{R}/data/voice_index_{n}.json"))) | set(json.load(open(f"{R}/data/day56_voice_index_{n}.json")))
for t in sorted(set(narr)):
    for n in ("f", "m", "c", "g"): chk(n, norm(t), t)
fam_lines = sorted({t for v, t in voiced if v == "amy"} )
npc = sorted({(v, t) for v, t in voiced if t not in fam_lines})
for t in fam_lines:
    for v in FAMILY: chk("family:" + v if False else v, f"v_{v} {norm(t)}", t)
for v, t in npc: rows.setdefault("npc:" + v, [0, 0]); r = rows["npc:" + v]; r[1] += 1; (r.__setitem__(0, r[0] + 1) if f"v_{v} {norm(t)}" in have else miss.append((v, t)))
print(f"narrator/player lines {len(set(narr))}, family lines {len(fam_lines)}, NPC lines {len(npc)}")
for k, (a, b) in rows.items(): print(f"  {k:14s} {a}/{b}")
print("MISSING", len(miss), miss[:10])
sys.exit(1 if miss else 0)
