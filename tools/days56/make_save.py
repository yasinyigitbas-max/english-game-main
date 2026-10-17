"""QA save for days 5-6: day 5 morning (story.d5 = alarm), a created player, a 2-person family, the shop's own beats done."""
import json, sys, os
p = sys.argv[1] if len(sys.argv) > 1 else "/tmp/qa_d56/save.json"
day = int(sys.argv[2]) if len(sys.argv) > 2 else 5
os.makedirs(os.path.dirname(p), exist_ok=True)
fam = [{"role": "mother", "name": "Ayşe", "skin": 1, "hcol": 1, "cloth": 2, "hair": 1},
       {"role": "father", "name": "Mehmet", "skin": 1, "hcol": 0, "cloth": 1, "hair": 0}]
st = {"age": "adult", "created": True, "door_locked": False, "door_opened": True, "family": fam, "has_phone": True, "job": "teacher",
      "lesson_done": True, "name": "Deniz", "tr": "--tr" in sys.argv, "voice": True, "calendar_seen": True}
story = {"day1_done": True, "day2": "day3", "d2_bedtime_done": True, "d3": "done", "d%d" % day: "alarm", "d56_lying": False}
d = {"day": day, "family_breakfast": True, "has_phone": True, "breakfast_done": True, "state": st, "story": story,
     "places": {"shop": {k: True for k in ["enter", "teach", "shopping", "lesson", "done"]}},
     "world": {"day": day, "minutes": 420.0, "flags": {"story_accident": True}, "scene": "res://main.tscn", "player_pos": [0, 0, 0],
               "economy": {"inventory": {}, "log": [], "wallet": 2000.0}, "transit": {"tickets": 0.0}, "version": 1.0}}
json.dump(d, open(p, "w"), ensure_ascii=False, indent=1); print("save", p, "day", day)
