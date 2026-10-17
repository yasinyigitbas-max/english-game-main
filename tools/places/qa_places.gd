extends Node
## cafe/shop QA: --place=cafe|shop  --tr  --mode=retake_skip|skip   shots -> /workspace/story_blue_cafe/docs/
var fails := 0
var shots := 0
var place := "cafe"; var tr := false; var qmode := "retake_skip"
func ok(c: bool, m: String) -> void: print("PLACEQA ", "PASS " if c else "FAIL ", m); if not c: fails += 1
func w(s: float) -> void: await get_tree().create_timer(s).timeout
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "/workspace/story_blue_cafe/docs/%s_%s%s.png" % [place, n, "_tr" if tr else ""]
	get_viewport().get_texture().get_image().save_png(p); print("PLACEQA SHOT ", p)
func _ready() -> void:
	if name != "QAPlaceRoot":
		var n = (get_script() as Script).new(); n.name = "QAPlaceRoot"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--place="): place = a.substr(8)
		if a.begins_with("--mode="): qmode = a.substr(7)
	tr = "--tr" in OS.get_cmdline_user_args()
	App.save_tr(tr); DirAccess.make_dir_recursive_absolute("/workspace/story_blue_cafe/docs")
	var errs := [0]
	await w(0.8); WorldState.load_game()
	get_tree().change_scene_to_file("res://scenes/places/%s.tscn" % place)
	await w(1.5)
	var sc = get_tree().current_scene
	ok(sc != null and sc.scene_file_path.ends_with(place + ".tscn"), "scene loaded")
	await w(1.0); await shot("01_enter")
	sc._start()
	var ph = sc.room_phone.phone
	var t := 0; var seen := {}; var lesson_shot := false; var quiz_shot := false; var score_shot := false; var retook := false; var skipped := false; var cine_shots := 0
	var tip := false; var exit_used := false
	while t < 2400:
		await w(0.25); t += 1
		if sc._cine_cam != null and cine_shots < 4 and t % 12 == 0: cine_shots += 1; await shot("02_cine_%d" % cine_shots)
		if ph.visible and ph.page == "lesson" and not Audio.is_speaking():
			var nb = ph.find_child("LessonNext", true, false)
			if nb and not nb.disabled:
				if not lesson_shot: lesson_shot = true; await w(0.3); await shot("04_lesson")
				nb.pressed.emit(); continue
		if ph.visible and ph.page == "quiz":
			var sk = ph.find_child("SkipTest", true, false)
			if not quiz_shot and sk: quiz_shot = true; await w(0.5); await shot("05_test_skipbtn")
			if qmode == "skip" or retook:
				if sk and not skipped: skipped = true; await w(0.4); ok(sk.text == ("Testi geç" if tr else "Skip test"), "skip label '%s' (tr=%s)" % [sk.text, tr]); sk.pressed.emit()
				continue
			var row = ph.find_child("Options", true, false)
			if row and not Audio.is_speaking() and not ph._answering:
				var q: Dictionary = ph._qz()[ph.quiz_i]
				var btns: Array = row.get_children().filter(func(b): return b is Button and not b.disabled)
				if btns.size() == row.get_child_count():
					var wrong: int = 1 - int(q.a) if q.opts.size() == 2 else (int(q.a) + 1) % q.opts.size()
					if not ph.quiz_wrong: (row.get_child(wrong) as Button).pressed.emit()
					else: (row.get_child(int(q.a)) as Button).pressed.emit()
			continue
		if ph.visible and ph.page == "score":
			if not score_shot: score_shot = true; await w(1.0); await shot("06_score_tip"); tip = ph.find_children("*", "Label", true, false).any(func(l): return "study the grammar" in l.text)
			ok(tip, "grammar suggestion shown at >= half wrong")
			if not retook:
				await Audio.wait_idle(10.0)
				for b in ph.find_children("*", "Button", true, false):
					if "Retake" in b.text: retook = true; b.pressed.emit(); break
				ok(retook, "Retake pressed"); await w(1.0)
			continue
		if sc.mode == "play" and sc._mark_target != null:
			var id := ""
			for k in sc.its: if sc.its[k] == sc._mark_target: id = k
			if id != "" and not seen.has(id):
				seen[id] = true
				if id in ["seat", "pay", "exit"]: await shot("03_obj_" + id)
				if id == "exit": exit_used = true
				sc.qa_use(id)
				if id == "exit": await w(2.0); break
	ok(exit_used, "reached the exit objective")
	var pl = App.load_save().get("places", {}).get(place, {})
	ok(pl is Dictionary and pl.get("lesson", false) and pl.get("done", false), "beats saved once: %s" % str(pl))
	ok(skipped, "Skip test pressed (mode %s)" % qmode)
	if qmode != "skip": ok(retook, "retake then skip")
	ok(lesson_shot and quiz_shot, "lesson + test pages seen")
	ok(sc.find_children("*", "CollisionShape3D", true, false).size() > 10, "room has colliders")
	print("PLACEQA objectives seen ", seen.keys())
	print("PLACEQA DONE place=", place, " tr=", tr, " fails=", fails)
	get_tree().quit()
