extends Node
## skip-test QA: day-2 resume -> living room; autoplays the lesson, taps "Skip test" on the day-2 10-question test,
## checks the story continues (mission -> car); then skips the vocab test and a phone.gd quiz (past-simple engine).
var fails := 0
func ok(c: bool, m: String) -> void: print("SKIPQA ", "PASS " if c else "FAIL ", m); if not c: fails += 1
func w(s: float) -> void: await get_tree().create_timer(s).timeout
func _ready() -> void:
	if name != "QASkipRoot":   # survive change_scene: run from a node parented to the root
		var n = (get_script() as Script).new(); n.name = "QASkipRoot"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS; print("SKIPQA start")
	await w(1.0); WorldState.load_game()
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://livingroom.tscn")
	var t := 0
	while (get_tree().current_scene == null or get_tree().current_scene.scene_file_path != "res://livingroom.tscn") and t < 200: await w(0.2); t += 1
	var lr = get_tree().current_scene; print("SKIPQA living ", lr); await w(2.0)
	var ph = lr.room_phone.phone
	var skipped := false; t = 0
	while t < 1500:
		await w(0.2); t += 1
		if t % 25 == 0: print("SKIPQA t=", t, " page=", ph.page, " vis=", ph.visible, " mission=", lr.mission)
		if lr.mission == "Go outside to the car." and lr.mode == "play": break
		if ph.visible and ph.page == "lesson" and not Audio.is_speaking():
			var nb = ph.find_child("LessonNext", true, false)
			if nb and not nb.disabled: nb.pressed.emit(); continue
		var sk = ph.find_child("SkipTest", true, false)
		if sk and not skipped and sk.is_visible_in_tree():
			await w(1.0)
			get_viewport().get_texture().get_image().save_png("/workspace/story_blue_skip/docs/skip_test_button.png")
			var r: Rect2 = sk.get_global_rect(); print("SKIPQA button rect ", r, " text=", sk.text)
			var overl := false
			for b in ph.find_children("*", "Button", true, false):
				if b != sk and b.is_visible_in_tree() and b.get_global_rect().intersects(r): overl = true
			ok(not overl, "Skip button overlaps no other button")
			ok(r.size.x >= 150 and r.size.y >= 48, "Skip button phone-size touch target %s" % str(r.size))
			sk.pressed.emit(); skipped = true
	ok(skipped, "day-2 test: Skip test pressed")
	ok(lr.mission == "Go outside to the car.", "day-2 story continued after skip (mission '%s')" % lr.mission)
	var sv: Dictionary = App.load_save()
	ok(str(sv.get("story", {}).get("day2_score", "")) != "", "day2_score saved %s" % str(sv.get("story", {}).get("day2_score", "")))
	ok(ph.find_child("GrammarTip", true, false) == null, "no grammar tip after skip")
	# vocab test engine
	var res := [null]
	var job := func(): res[0] = await load("res://scripts/story/vocab_test.gd").new().run(lr, ph)
	job.call(); t = 0
	while ph.find_child("SkipTest", true, false) == null and t < 100: await w(0.2); t += 1
	var sk2 = ph.find_child("SkipTest", true, false); ok(sk2 != null, "vocab test shows Skip test")
	if sk2: sk2.pressed.emit()
	t = 0
	while res[0] == null and t < 50: await w(0.2); t += 1
	ok(res[0] != null and res[0][0] == res[0][1], "vocab test skipped -> finished %s" % str(res[0]))
	# phone.gd quiz engine (past simple / pre-sleep / family / hospital tests)
	var past: Dictionary = App.load_json("res://data/past_simple.json") if FileAccess.file_exists("res://data/past_simple.json") else {}
	var set := {"label": "SkipQA", "quiz_after": true, "lesson": [], "quiz": [{"q": "I ___ breakfast.", "opts": ["had", "have"], "a": 0, "say": "I had breakfast."}, {"q": "I ___ home.", "opts": ["went", "go"], "a": 0, "say": "I went home."}]}
	var qd := [null]
	ph.quiz_done.connect(func(s, tt): qd[0] = [s, tt], CONNECT_ONE_SHOT)
	ph.visible = true; ph.start_set(set, "quiz"); await w(1.0)
	var sk3 = ph.find_child("SkipTest", true, false); ok(sk3 != null, "phone quiz shows Skip test (text '%s')" % (sk3.text if sk3 else ""))
	if sk3: sk3.pressed.emit()
	await w(0.5)
	ok(qd[0] != null and qd[0][0] == qd[0][1], "phone quiz skipped -> quiz_done %s" % str(qd[0]))
	ok(App.load_save().get("tests_skipped", {}).size() >= 3, "tests_skipped recorded %s" % str(App.load_save().get("tests_skipped")))
	print("SKIPQA DONE fails=", fails); get_tree().quit()
