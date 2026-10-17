"""Plain list of every cafe/shop voice line (exact text + voice) for black's re-render pipeline.
Mirrors the line collection in build_voice_places.py. Writes data/cafe_shop_voice_lines.json and prints markdown."""
import json
D = json.load(open("data/cafe_shop.json"))
NPCV = {"cafe": {"barista": "amy", "c1": "kristin", "c2": "joe", "c3": "hfc_female"}, "shop": {"assistant": "joe", "c1": "kristin", "c2": "hfc_female"}}
out = {}   # section -> [(text, voice)]
seen = set()
def add(sec, text, voice):
    if (text, voice) in seen: return
    seen.add((text, voice)); out.setdefault(sec, []).append([text, voice])
N = "narrator/player"
for en in ["Go to the counter.", "Sit at a table.", "Take a basket.", "Get six apples.", "Get a bottle of milk.", "Get a loaf of bread.", "Pay at the checkout.", "Go outside.",
           "Now a short lesson and test on your phone.", "I'm taking a basket.", "Well done! You finished the cafe.", "Well done! You finished the shop."]:
    add("Objectives and script lines (both places)", en, N)
for place in ("cafe", "shop"):
    P = place.capitalize()
    for name, b in D["beats"][place].items():
        for who, en, _ in b: add(f"{P} story beats", en, N if who in ("me", "narr") else "NPC " + NPCV[place][who] + f" ({who})")
    for name, b in D["npc"][place].items():
        for who, en, _ in b: add(f"{P} NPC chats", en, N if who in ("me", "narr") else "NPC " + NPCV[place][who] + f" ({who})")
    for who, v in NPCV[place].items(): add(f"{P} NPC chats", "Nice to see you again!", f"NPC {v} ({who}, repeat visits)")
    for st in D[place]["lesson"]:
        for s in st["say"]: add(f"{P} phone lesson", s, N)
    for k in ("quiz", "quiz_b", "quiz_c"):
        for q in D[place][k]: add(f"{P} test ({k})", q["say"], N)
json.dump(out, open("data/cafe_shop_voice_lines.json", "w"), ensure_ascii=False, indent=1)
tot = sum(len(v) for v in out.values())
print(f"Total: {tot} lines ({sum(1 for v in out.values() for t in v if t[1]==N)} narrator/player, {sum(1 for v in out.values() for t in v if t[1]!=N)} NPC).\n")
for sec, L in out.items():
    print(f"**{sec}**\n")
    for t, v in L: print(f"- \"{t}\" ({v})")
    print()
