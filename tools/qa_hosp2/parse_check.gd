extends SceneTree
## v33 (red): parse check of every script this branch touches (godot --headless --path . -s res://tools/qa_hosp2/parse_check.gd)
const FILES := ["res://scripts/main.gd", "res://scripts/story/bedtime.gd", "res://scripts/story/story_home.gd", "res://scripts/story/work_summary.gd",
	"res://scripts/world/street_object.gd", "res://scripts/story/hospital_day2.gd", "res://scripts/story/hospital.gd", "res://scripts/story/day3_evening.gd",
	"res://tools/qa_hosp2/qa_hosp2.gd", "res://scripts/audio.gd", "res://scripts/core/voice.gd", "res://scripts/bathroom.gd", "res://scripts/phone.gd",
	"res://scripts/story/child_drive.gd", "res://scripts/world/world_exterior.gd", "res://scripts/story/d2_night_test.gd", "res://scripts/story/d3_night_test.gd",
	"res://scripts/story/test_bank.gd", "res://tools/qa_v32int/qa_v32int.gd", "res://tools/qa_child_drive/qa_child_drive.gd"]
func _initialize() -> void:
	var bad := 0
	for f in FILES:
		var s = load(f)
		var ok: bool = s is GDScript and (s as GDScript).can_instantiate()
		print("PARSE ", "OK  " if ok else "FAIL", " ", f)
		if not ok: bad += 1
	for j in ["res://data/day3_evening.json", "res://data/extra_lines.json"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string(j))
		print("JSON ", "OK  " if d is Dictionary else "FAIL", " ", j)
	print("PARSE_DONE bad=", bad)
	quit(bad)
