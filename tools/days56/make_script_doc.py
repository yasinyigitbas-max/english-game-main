"""Writes docs/DAYS_5_6_SCRIPT.md from data/day5.json + data/day6.json (the files the game reads)."""
import json
out = ["# Days 5-6 — full English script (v33 blue)", "",
       "Generated from `data/day5.json` / `data/day6.json` by `tools/days56/make_script_doc.py`; edit `tools/days56/days56_content.py`, then re-run the content, voice and doc scripts.",
       "Turkish (TR toggle, text only) is shown in *italics*. **Objective** = top-left Objectives entry + camera pan + spoken line. ✔ = the right answer (wrong answers show feedback and get greyed out). `[action]` = stage direction.", ""]
WHO = {"me": "Me", "narr": "Narrator", "fam0": "Family member 1", "fam1": "Family member 2"}
def who(d, w):
    if w in WHO: return WHO[w]
    sp = d["speakers"].get(w)
    return f"{sp[0]} ({sp[2]} voice)" if sp else w
def steps(d, ss, ind=""):
    for s in ss:
        if "do" in s and len(s) == 1: out.append(f"{ind}- `[{s['do']}]`")
        elif "obj" in s: out.append(f"{ind}- **Objective:** {s['en']}  *{s['tr']}*")
        elif "choice" in s:
            c = s["choice"]
            out.append(f"{ind}- **Choice:** {c['prompt']}  *{c.get('prompt_tr','')}*" + ("  (wrong answers disappear)" if c.get("remove_wrong") else ""))
            for o in c["opts"]:
                line = f"{ind}  - {'✔' if o.get('ok') else '✘'} \"{o['en']}\"  *{o.get('tr','')}*"
                if o.get("fb"): line += f" → Not quite. {o['fb']}  *{o.get('fb_tr','')}*"
                if o.get("do"): line += f"  `[{o['do']}]`"
                out.append(line)
                if o.get("then"): steps(d, o["then"], ind + "    ")
        elif "en" in s: out.append(f"{ind}- **{who(d, s.get('who','narr'))}:** {s['en']}  *{s.get('tr','')}*" + (f"  `[{s['do']}]`" if s.get("do") else ""))
def quiz(qs):
    for i, q in enumerate(qs, 1):
        out.append(f"{i}. {q['q']} — ({' / '.join(q['opts'])}) ✔ **{q['opts'][q.get('a',0)]}** — read: \"{q['say']}\"  *{q['tr']}*")
for n in (5, 6):
    d = json.load(open(f"data/day{n}.json"))
    out += [f"## Day {n}", "", "### 1. Alarm (bedroom)",
            "- **Narrator:** It is a new day. / My alarm is ringing. (caption, present continuous)",
            "- **Objective:** Turn off the alarm.  *Alarmı kapat.*",
            f"- **Me:** {d['alarm_after']['en']}  *{d['alarm_after']['tr']}*",
            "- **Objective:** Go to the bathroom.  *Banyoya git.*", "", "### 2. Bathroom",
            f"- **Objective:** {d['bath']['en']}  *{d['bath']['tr']}*",
            f"- **Me:** {d['bath']['done']['en']}  *{d['bath']['done']['tr']}*",
            "- **Objective:** Go to the living room.  *Oturma odasına git.*", "", "### 3. Breakfast (living-room table)",
            "- **Objective:** Have breakfast with your family.  *Ailenle kahvaltı yap.*"]
    steps(d, d["breakfast"])
    out += ["", "**Grammar review at the table** (narrator reads; first try counts):"]
    quiz(d["review"])
    out += ["- **Objective:** Go outside.  *Dışarı çık.*", "", f"### 4. Outing — {'the corner shop (lost child)' if n == 5 else 'the bus stop (storm + broken-down bus)'}",
            f"- **Objective:** {d['outing']['en']}  *{d['outing']['tr']}*"]
    steps(d, d["event"])
    if d.get("taxi"):
        out += ["", "**If the player picks “Call a taxi” (the taxi line is busy):**"]; steps(d, d["taxi"])
    out += ["- **Objective:** Go home.  *Eve git.* / Go inside.  *İçeri gir.*", "", "### 5. Evening couch talk",
            "- **Objective:** Talk to your family.  *Ailenle konuş.*"]
    steps(d, d["couch"])
    out += ["- **Objective:** Go to bed.  *Yatağa git.*", "", "### 6. Polaroids (in bed)",
            "- **Objective:** Look at the photos of your day.  *Gününün fotoğraflarına bak.*"]
    for k, t in d["recap"]: out.append(f"- `[{k}]` {t}  *{d['lines'].get(t,'')}*")
    out.append(f"- **Narrator:** {d['recap_end']['en']}  *{d['recap_end']['tr']}*")
    out += ["", "### 7. Bedtime test (10 questions, 3 rotating versions, answers shuffled, narrator reads)",
            "- **Objective:** Take the bedtime test.  *Yatmadan önce testi çöz.*",
            f"- Questions come from red's shared no-repeat bank (topics {', '.join(d['bank_topics'])}) once it exists; until then from these local versions:"]
    for name, k in (("A", "quiz"), ("B", "quiz_b"), ("C", "quiz_c")):
        out += ["", f"**Version {name}**"]; quiz(d[k])
    out += ["", "- Then sleep → " + ("Day 6 alarm." if n == 5 else "Day 7 (red's `day7_morning.gd`)."), ""]
open("docs/DAYS_5_6_SCRIPT.md", "w").write("\n".join(out) + "\n")
print("lines", len(out))
