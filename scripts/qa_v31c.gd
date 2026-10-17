extends "res://scripts/qa_flow.gd"
## v31c QA (red): day-2 evening couch talk -> bedtime (polaroids, test, sleep) -> day-3 morning (shower, living room, outside).
## godot ... res://scripts/qa_v31c_boot.tscn -- --save-path=<prepared day-2 save> [--skip-test]
var said_c := []
var tag := ""
var lying_bad := 0
var lying_n := 0
var sdir2: = "/workspace/qa_v31/strip/"
var obj_seen := []

func snap(n: String) -> void:
	await shot(tag + "_" + n)
	var img := get_viewport().get_texture().get_image()
	img.save_png(sdir2 + tag + "_" + n + ".png")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = "/workspace/qa_v31/";DirAccess.make_dir_recursive_absolute(shot_dir);DirAccess.make_dir_recursive_absolute(sdir2)
	tag = "tr" if App.tr_on() else "en"
	Audio.spoke.connect(func(t): said_c.append(t); print("V31C SAY ", "OK  " if _voiced(t) else "MISS", " | ", t))
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := "%s|%s" % [it.id, it.en]
			if not s in obj_seen: obj_seen.append(s); print("V31C OBJ ", s))
	if "--day1" in OS.get_cmdline_user_args(): run_d1.call_deferred()
	else: run_c.call_deferred()

func _solve_puzzles() -> void:
	var box := get_tree().root.find_child("D2Puzzle", true, false)
	if box == null: return
	for b in box.find_children("*", "Button", true, false):
		if is_instance_valid(b) and not b.disabled: b.pressed.emit()
		await w(0.05)

func _phone_play(skip: bool) -> void:
	var r := get_tree().root
	var sk := r.find_child("SkipTest", true, false) as Button
	if skip and sk and sk.is_visible_in_tree() and not sk.disabled: sk.pressed.emit(); return
	for i in 3:
		var o := r.find_child("Opt%d" % i, true, false) as Button
		if o and o.is_visible_in_tree() and not o.disabled: o.pressed.emit(); return
	var c := r.find_child("ScoreContinue", true, false) as Button
	if c and c.is_visible_in_tree(): c.pressed.emit()

func _lying_check(m) -> void:
	var b = m.get_node_or_null("Bedtime")
	if b and b.bed_lock:
		lying_n += 1
		if not m.breathing or absf(m.hero.model.rotation.x) < 1.2: lying_bad += 1

func run_c() -> void:
	var skip := "--skip-test" in OS.get_cmdline_user_args()
	await w(1.0)
	ok(Day2Evening.ready_to_run(), "save: day 2, work + hospital done, couch not done")
	App.came_from = "outside"; get_tree().change_scene_to_file("res://livingroom.tscn")
	await _scene_is("res://livingroom.tscn")
	var lr = get_tree().current_scene
	ok(await wait_until(func(): return lr.has_node("Day2Evening"), 40.0), "Day2After -> day2_family_talk -> Day2Evening.start attached")
	await snap("01_talk_objective")
	ok(Objectives.has("Talk to your family."), "objective Talk to your family. listed")
	await wait_until(func(): return lr.mode == "play", 20.0)
	lr.hero.global_position = Vector3(lr.SOFA_X - 1.3, 0, 0.9)
	var t := 0; var shots := 0
	while not Objectives.has("Go to bed.") and t < 900:
		await w(0.3); t += 1
		await _solve_puzzles()
		if t % 12 == 0 and shots < 12: shots += 1; await snap("02_couch_%02d" % shots)
		if t == 60: await tr_or_check("couch")
	ok(Objectives.has("Go to bed."), "couch talk finished -> 'Go to bed.' objective (%ds)" % int(t * 0.3))
	ok(said_c.has("How was your day?"), "family asked How was your day?")
	ok(bool(Day2Evening.story().get("d2_couch_done", false)), "flag d2_couch_done saved")
	print("V31C TOLD ", Day2Evening.story().get("d2_couch_told"))
	await w(3.5); await snap("03_bed_objective")
	# ---- to the bedroom
	App.came_from = "livingroom"; get_tree().change_scene_to_file("res://main.tscn")
	await _scene_is("res://main.tscn")
	m = get_tree().current_scene
	ok(await wait_until(func(): return m.has_node("Bedtime"), 20.0), "bedroom: Bedtime started")
	t = 0; shots = 0
	var phase_shot := {}
	while m.has_node("Bedtime") and t < 1500:
		await w(0.3); t += 1
		_lying_check(m)
		var b = m.get_node_or_null("Bedtime")
		_phone_play(skip)
		var row = get_tree().root.find_child("D2Polaroids", true, false)
		if row and row.get_child_count() >= 2 and not phase_shot.has("pol" + str(row.get_child_count())): phase_shot["pol" + str(row.get_child_count())] = 1; await w(0.8); await snap("04_polaroids_%d" % row.get_child_count())
		if m.phone.visible and not phase_shot.has("test"): phase_shot["test"] = 1; await w(2.5); await snap("05_test"); await tr_or_check("test")
		if m.phone.visible and get_tree().root.find_child("ScoreContinue", true, false) and not phase_shot.has("score"): phase_shot["score"] = 1; await snap("06_score")
		if t % 15 == 0 and shots < 20: shots += 1; await snap("07_bed_%02d" % shots)
	ok(not m.has_node("Bedtime"), "bedtime finished (%ds)" % int(t * 0.3))
	ok(lying_n > 20 and lying_bad == 0, "player lying the whole bedtime (%d samples, %d bad)" % [lying_n, lying_bad])
	ok(WorldState.day == 3, "day advanced to 3 (clock %s)" % WorldState.clock_text())
	ok(bool(Day2Evening.story().get("d2_bedtime_done", false)), "flag d2_bedtime_done saved")
	print("V31C NIGHT ", Day2Evening.story().get("d2_night_score"))
	for k in ["d2_breakfast", "d2_work", "d2_hospital", "d2_couch"]: ok(Life.photo(k) != null, "polaroid %s exists" % k)
	# ---- day 3
	ok(await wait_until(func(): return Objectives.has("Take a shower."), 30.0), "day 3: Take a shower. objective")
	await w(2.0); await snap("08_d3_shower_obj")
	await wait_until(func(): return m.mode == "play", 20.0)
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn")
	await _scene_is("res://bathroom.tscn")
	var bt = get_tree().current_scene
	await w(4.0); await snap("09_bath_obj")
	await wait_until(func(): return bt.mode == "play", 30.0)
	for v in bt.verbs("bath"):
		if v[2] == "takeshower": bt.do_verb("bath", v); break
	ok(await wait_until(func(): return Objectives.has("Go to the living room."), 120.0), "after the shower: Go to the living room. objective")
	await w(2.0); await snap("10_after_shower")
	await wait_until(func(): return bt.mode == "play", 30.0)
	App.came_from = "bathroom"; get_tree().change_scene_to_file("res://livingroom.tscn")
	await _scene_is("res://livingroom.tscn")
	ok(await wait_until(func(): return Objectives.has("Go outside."), 40.0), "living room day 3: Go outside. objective")
	ok(not Objectives.has("Talk to your family."), "no repeated family talk on day 3")
	await w(2.0); await snap("11_living_out"); await tr_or_check("living_d3")
	App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home")
	ok(await wait_until(func(): return Objectives.has("Explore the town."), 60.0), "outside: Explore the town. objective")
	await w(2.0); await snap("12_outside")
	ok(await wait_until(func(): return Day3Morning.stage() == "town", 40.0), "d3 stage town (after the cafe -> shop pan)")   # v32 (red): was "done"
	# v32 (red): town cues. Simulate blue's PlaceBase.leave() (App.came_from + spawn lot:<id>) without the interiors.
	App.came_from = "cafe"; Game.go_to(Game.WORLD_SCENE, "lot:cafe")
	ok(await wait_until(func(): return Objectives.has("Go to the shop."), 60.0), "after the cafe: Go to the shop. objective")
	ok(Day3Morning.flag("d3_cafe"), "story.d3_cafe set")
	await w(14.0); await snap("13_go_shop")
	App.came_from = "shop"; Game.go_to(Game.WORLD_SCENE, "lot:corner_shop")
	ok(await wait_until(func(): return Objectives.has("Go back home."), 60.0), "after the shop: Go back home. objective")
	ok(Day3Morning.flag("d3_shop") and Day3Morning.stage() == "home", "story.d3_shop set, d3 stage home")
	await w(14.0); await snap("14_go_home")
	App.came_from = "outside"; get_tree().change_scene_to_file("res://livingroom.tscn")
	ok(await wait_until(func(): return Day3Morning.stage() == "done", 40.0), "home again: d3 stage done")
	ok(await wait_until(func(): return Objectives.has("Talk to my family."), 40.0), "v32c: day-3 evening: Talk to my family. objective")   # couch talk needs the family seated + puzzles (not driven here)
	var miss := []
	for s in said_c: if not _voiced(s) and not s in miss: miss.append(s)
	print("V31C MISSING_VOICE ", JSON.stringify(miss))
	print("V31C ALLSAID ", JSON.stringify(said_c))
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("V31C TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()

func tr_or_check(where: String) -> void:
	if App.tr_on(): await ovl_check(where)
	else: await tr_check(where)

## day 1 bedtime: the player must stay lying (story_home.gd bed_lock) through review, tests, dream polaroids and sleep
func run_d1() -> void:
	tag = "d1_" + tag
	await w(1.0)
	App.came_from = "hospital"; get_tree().change_scene_to_file("res://main.tscn")
	await _scene_is("res://main.tscn")
	m = get_tree().current_scene
	var t := 0; var n := 0; var bad := 0; var shots := 0
	await w(3.0)
	while t < 1500:
		await w(0.3); t += 1
		var sh = m.find_child("*", false, false)
		var home = null
		for c in m.get_children(): if c.get_script() and String(c.get_script().resource_path).ends_with("story_home.gd"): home = c
		if home == null: break
		if home.bed_lock:
			n += 1
			if not m.breathing or absf(m.hero.model.rotation.x) < 1.2: bad += 1
		var r := get_tree().root   # skip every test (shared SkipTest), skip the review, continue lessons - never guess answers
		var pressed := false
		for b in r.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.disabled and (b.name == "SkipTest" or b.name == "ScoreContinue" or b.text.begins_with("Skip the review") or b.text in ["Continue", "Next", "Check"]): b.pressed.emit(); pressed = true; break
		await _solve_puzzles()
		if t % 40 == 0 and shots < 25: shots += 1; await snap("bed_%02d" % shots)
		if t % 100 == 0: print("V31C D1 lying samples=%d bad=%d t=%ds" % [n, bad, int(t * 0.3)])
	ok(n > 50 and bad == 0, "day 1: lying during bedtime (%d samples, %d bad, %ds)" % [n, bad, int(t * 0.3)])
	print("V31C TOTAL d1"); get_tree().quit()
