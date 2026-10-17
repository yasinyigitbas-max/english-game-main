"""QA save for red's days 4 / 7: start of the day (story.dN = "start"), a created player, 2-person family, shop beats done."""
import json, sys, os
p = sys.argv[1]; day = int(sys.argv[2])
os.makedirs(os.path.dirname(p), exist_ok=True)
fam = [{"role": "mother", "name": "Ayşe", "skin": 1, "hcol": 1, "cloth": 2, "hair": 1},
       {"role": "father", "name": "Mehmet", "skin": 1, "hcol": 0, "cloth": 1, "hair": 0}]
st = {"age": "adult", "created": True, "door_locked": False, "door_opened": True, "family": fam, "has_phone": True, "job": "teacher",
      "lesson_done": True, "name": "Deniz", "tr": True, "voice": True, "calendar_seen": True}
story = {"day1_done": True, "day2": "day3", "d2_bedtime_done": True, "d3": "done", "d3_bedtime_done": True, "d%d" % day: "start"}
if day == 7:
    story.update({"d4": "done", "d4_bedtime_done": True, "d5": "done", "d6": "done"})
d = {"day": day, "family_breakfast": True, "has_phone": True, "breakfast_done": False, "state": st, "story": story,
     "places": {"shop": {k: True for k in ["enter", "teach", "shopping", "lesson", "done"]}},
     "world": {"day": day, "minutes": 420.0, "flags": {"story_accident": True}, "scene": "res://main.tscn", "player_pos": [0, 0, 0],
               "economy": {"inventory": {}, "log": [], "wallet": 2000.0}, "transit": {"tickets": 0.0}, "version": 1.0}}
json.dump(d, open(p, "w"), ensure_ascii=False, indent=1); print("save", p, "day", day)
