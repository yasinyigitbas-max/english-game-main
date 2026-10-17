## v33 (red): DAY 7 ROUTINE = day4_routine.gd with the day-7 data. Stage story.d7 (same stages as day 4).
## Day 7 starts from whatever blue's day 6 leaves: WorldState.day == 7 and story.d7 "" / "start" -> "shower"
## (Day4Routine.start, called from bedtime.gd hook_bedroom, main.gd _advance and livingroom.gd _intro).
## The wake-up itself ("I'm waking up." / "I'm getting up.") is the day-6 bedtime's (blue), like day 4 -> 5 here.
## Outing: "Go to the shop." for a bottle of milk (the family needs the player out of the house) -> home -> the living
## room is dark -> SURPRISE PARTY (day7_party.gd) -> "Go to bed." -> day7_bedtime.gd.
extends "res://scripts/story/day4_routine.gd"

func _init() -> void:
	day_n = 7; key = "d7"; data_path = "res://data/day7.json"
	evening_script = "res://scripts/story/day7_party.gd"
	out_goal = ["Go to the shop.", "Dükkâna git."]
