## v33 (red): DAY 7 BEDTIME = day4_bedtime.gd with the day-7 data (dream polaroids of day 7, TestBank day-7 test:
## past simple + party words) -> sleep -> DAY 8: silent "Day 8" title, the standard wake lines, story.d8 = "start" and the
## placeholder first objective "Start your day." (main.gd objective() keeps it via Day4Routine.main_objective()).
extends "res://scripts/story/day4_bedtime.gd"

func _init() -> void:
	day_n = 7; data_path = "res://data/day7.json"

func _handoff() -> void:
	for p in ["res://scripts/story/day8_routine.gd", "res://scripts/story/day8_morning.gd"]:
		if ResourceLoader.exists(p):
			var s: Script = load(p)
			for fn in ["start", "attach"]:
				if s and _has_static(s, fn): s.call(fn, get_tree()); return
	await Audio.wait_idle(8.0)
	var f: Vector3 = m.OBJ.door_s.focus
	await Life.guide_to({"pos": f + Vector3(0.4, 1.0, -2.4), "at": f}, "Start your day.", {"tr": "Gününe başla.", "id": "Start your day.",
		"list": [{"id": "Start your day.", "en": "Start your day.", "tr": "Gününe başla."}]})
