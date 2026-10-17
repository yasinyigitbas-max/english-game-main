extends "res://scripts/qa_flow.gd"
## v31 QA: day-2 morning end to end. godot ... res://qa_boot.tscn -- --qa-day2m [--tr-on] --save-path=/tmp/x.json --shots=/tmp/dir/
## wake (lying -> get up) -> boss/teacher call -> living-room prompt -> living room scripted breakfast (lesson, dialogue,
## test: all wrong -> grammar tip -> Retake (next version) -> all right -> Continue) -> table clears -> car prompt ->
## front door -> outside -> car prompt -> walk to the car -> hook day2_reached_car.
var said3 := []
var _fix_checked := false
var tr_on := false
func run_day2m() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tr_on = "--tr-on" in OS.get_cmdline_user_args()
	shot_dir = "/tmp/d2shots/"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--shots="): shot_dir = a.substr(8)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	Audio.spoke.connect(func(t): said3.append(t); print("D2 SAY ", "OK  " if (Audio._clip(Audio.norm(t)) != null or Voice.has_clip(t)) else "MISS", " | ", t))
	App.save_tr(tr_on)
	await w(1.0)
	WorldState.load_game()
	if "--resume" in OS.get_cmdline_user_args():   # v30.4: continued day-2 game with no story.day2 yet -> living room directly
		ok(String(App.load_save().get("story", {}).get("day2", "")) == "", "resume fixture: story.day2 empty on day %d" % WorldState.day)
		App.came_from = "bedroom"; get_tree().change_scene_to_file("res://livingroom.tscn")
		await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://livingroom.tscn", 40.0)
		await _d2m_living(get_tree().current_scene); return
	# ---- bedroom: wake up, the call, the living-room prompt
	App.continue_requested = true; App.came_from = ""
	get_tree().change_scene_to_file("res://main.tscn"); await w(1.5)
	m = get_tree().current_scene
	await wait_until(func(): return m.mode == "play", 30.0)
	m.S.tr = tr_on; m._refresh_text()
	m.mode = "busy"; m._pose_sleep(); await w(1.0)
	await m.get_up_sequence()
	ok(m.mode == "play", "wake: lying -> standing")
	await shot("01_awake"); await _trc("01_awake")
	var sh = load("res://scripts/story/story_home.gd").new(); sh.m = m; m.add_child(sh)
	sh.ui = StoryUI.new(); sh.add_child(sh.ui); sh.cl = CanvasLayer.new(); sh.cl.layer = 30; sh.add_child(sh.cl)
	var fin := [false]
	var job := func(): await sh._call(); fin[0] = true
	job.call()
	var t := 0
	while not fin[0] and t < 400: await w(0.3); t += 1; await _autoplay(m)
	ok(fin[0], "day-2 call finished")
	var pr := [false]
	var job2 := func(): await sh.day2_start(); pr[0] = true
	job2.call()
	await w(1.6); await shot("02_living_prompt_pan")
	ok(m.cam_shot.size() > 0, "living-room prompt: camera pan active")
	ok(m.mission == "Go to the living room.", "top-left mission = 'Go to the living room.' (%s)" % m.mission)
	ok(not tr_on or m.mission_tr.visible, "TR on -> mission TR visible '%s'" % m.mission_tr.text)
	ok(tr_on or not m.mission_tr.visible, "TR off -> no mission TR")
	await wait_until(func(): return pr[0], 30.0)
	ok(m.mode == "play" and m.cam_shot.is_empty(), "prompt done, free play")
	ok(not m.s_locked(), "living-room door unlocked on day 2 without the bathroom")
	await shot("03_after_prompt"); await _trc("03_after_prompt")
	m.do_verb("door_s", ["Go to the living room", "I am opening the door.", "go"])
	await wait_until(func(): return get_tree().current_scene != m and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://livingroom.tscn", 40.0)
	await _d2m_living(get_tree().current_scene)

func _d2m_living(lr) -> void:
	ok(lr.scene_file_path == "res://livingroom.tscn", "living room loaded")
	await w(2.0)
	ok(lr.has_node("Node") or lr.find_children("*", "Node", false, false).any(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("day2_morning.gd")), "day-2 scripted sequence started")
	ok(not lr.breakfast_pending(), "day-1 breakfast not repeated")
	# ---- scripted sequence: autoplay lesson, check the test
	var ph = lr.room_phone.phone
	var phase := "lesson"; var t2 := 0; var first_ver := -1; var tip_seen := false; var retook := false; var lock_ok := true; var shuffled := {}
	var lesson_pages := 0; var test_shots := 0
	while t2 < 3000:
		await w(0.2); t2 += 1
		if lr.mission == "Go outside to the car." and lr.mode == "play": break
		var tst = lr.find_children("*", "Node", true, false).filter(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("day2_test.gd"))
		if tst.is_empty():
			if ph.visible and ph.page == "lesson" and not Audio.is_speaking():
				var nb = ph.find_child("LessonNext", true, false)
				if nb and not nb.disabled:
					if lesson_pages < 8: await shot("10_lesson_%d" % ph.lesson_i)
					if ph.lesson_i == 1 and not _fix_checked:
						_fix_checked = true
						var trl: Array = ph._tr_lbls.filter(func(x): return is_instance_valid(x))
						ok(not trl.is_empty() and trl.all(func(x): return x.visible == tr_on), "fix1: lesson TR column visible == TR toggle (%d labels, tr=%s)" % [trl.size(), str(tr_on)])
						ok(not Life._lbl.visible, "fix2: clock strip hidden while the phone is open")
						ok(not (lr.cap_panel.visible and lr.cap_text.begins_with("Get a notebook")), "fix3: notebook caption gone on lesson page 2 ('%s' visible=%s)" % [lr.cap_text, str(lr.cap_panel.visible)])
					lesson_pages += 1; nb.pressed.emit()
			if t2 % 25 == 0 and not ph.visible: await shot("15_table_t%04d" % t2)
			continue
		var T = tst[0]
		if ph.page != "quiz" and ph.find_child("Options", true, false) != null: lock_ok = false
		if ph.page == "quiz":   # phone must not close during the test
			ph.close(); await w(0.4)
			if not ph.visible: lock_ok = false
		if first_ver < 0: first_ver = T.version; print("D2 test version ", T.version)
		var row = ph.find_child("Options", true, false)
		var sc = ph.find_child("ScoreContinue", true, false)
		if sc and sc.is_visible_in_tree():
			await w(0.3)
			if not retook:
				tip_seen = ph.find_child("GrammarTip", true, false) != null
				await shot("30_score_all_wrong")
				ok(T.score == 0, "all-wrong pass scored 0 / 10 (got %d)" % T.score)
				ok(tip_seen, "grammar tip shown at >= half wrong")
				await Audio.wait_idle(15.0)
				var rb = ph.find_child("Retake", true, false); rb.pressed.emit(); retook = true; await w(0.5)
				ok(T.version != first_ver, "Retake loads the next version (%d -> %d)" % [first_ver, T.version])
				ok(T._note, "notebook reminder not repeated on retake")
			else:
				await shot("31_score_all_right")
				ok(T.score == 10, "all-right pass 10 / 10 (got %d)" % T.score)
				ok(ph.find_child("GrammarTip", true, false) == null, "no grammar tip at 10 / 10")
				await Audio.wait_idle(15.0); sc.pressed.emit()
			continue
		if row == null or Audio.is_speaking() or T._busy: continue
		var q = T.Q[T.qi]
		var b0: Button = row.get_child(0)
		if b0.disabled: continue
		shuffled[str(q.opts)] = true
		var pick: int = int(q.a) if retook else (int(q.a) + 1) % q.opts.size()
		if test_shots < 3 or (retook and test_shots < 5): await shot("20_q%d_%s" % [T.qi, "r" if retook else "w"])
		test_shots += 1
		(row.get_child(pick) as Button).pressed.emit()
		await w(0.4)
		var fbt = ph.find_child("FeedbackTR", true, false)
		if fbt and T.qi == 0: ok(fbt.visible == tr_on, "feedback TR visible == TR toggle (%s)" % str(tr_on)); await shot("21_feedback_%s" % ("right" if retook else "wrong"))
		# the next question must wait for the narrator
		var qi0: int = T.qi
		while Audio.is_speaking(): 
			if T.qi != qi0: ok(false, "question advanced while the narrator was speaking"); break
			await w(0.05)
	ok(lock_ok, "phone stays open/locked during the whole test")
	ok(retook, "retake path done")
	ok(lr.table_clean, "table cleared itself")
	ok(lr.mission == "Go outside to the car.", "car prompt mission '%s'" % lr.mission)
	ok(not tr_on or lr.mission_tr.visible, "TR on: car mission TR visible '%s'" % lr.mission_tr.text)
	var st = App.load_save().get("story", {})
	ok(String(st.get("day2", "")) == "car", "save story.day2 = car (%s)" % str(st))
	await shot("40_table_clear_car_prompt")
	var said_have := said3.filter(func(x): return String(x).begins_with("I have to "))
	ok(not said_have.is_empty(), "job-based have-to line spoken: %s" % str(said_have))
	# ---- outside: car prompt + hook
	lr.do_verb("front", ["Go outside", "", "go"])
	await wait_until(func(): var s = get_tree().current_scene; return s != null and s.scene_file_path.ends_with("world_exterior.tscn"), 40.0)
	var wx = get_tree().current_scene
	await w(1.5)
	var d2 = wx.get_node_or_null("Day2Car")
	ok(d2 != null, "outside: day-2 car prompt node running")
	ok(get_tree().get_nodes_in_group("x").is_empty() and not wx.find_children("*", "Node", false, false).any(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("story_accident.gd")), "day-1 accident not replayed")
	await shot("50_outside_car_pan")
	await wait_until(func(): return wx.mode == "play", 20.0)
	ok(d2 and d2.car != null, "car found on the home driveway")
	ok(wx.hud.mission == "Go to the car.", "outside mission '%s'" % wx.hud.mission)
	var fired := [false]
	if d2: d2.day2_car_reached.connect(func(_c): fired[0] = true)
	await shot("51_outside_prompt_done")
	if d2 and d2.car:
		var tgt: Vector3 = d2.car.to_global(Vector3(-1.9, 0, 0.3)); tgt.y = wx.player.global_position.y
		wx.player.global_position = tgt
	await wait_until(func(): return fired[0], 10.0)
	ok(fired[0], "hook day2_reached_car fired at the car")
	ok(String(App.load_save().get("story", {}).get("day2", "")) == "at_car", "save story.day2 = at_car")
	await w(1.0); await shot("52_at_car")
	var miss := said3.filter(func(x): return Audio._clip(Audio.norm(x)) == null and not Voice.has_clip(x))
	ok(miss.is_empty(), "all spoken lines have a clip %s" % str(miss))
	print("D2 TR=", tr_on, " RESULT fails=", log.filter(func(l): return l.begins_with("FAIL")).size())
	print("D2 END"); get_tree().quit()

## v30.5: TR off -> no Turkish letters in any visible UI
func _trs(nd: Node, out: Array) -> void:
	if nd is CanvasItem and not nd.visible: return
	if (nd is Label or nd is Button or nd is Label3D) and Objectives.has_tr(nd.text): out.append(nd.text.replace("\n", " | "))
	for c in nd.get_children(): _trs(c, out)
func _trc(where: String) -> void:
	await get_tree().create_timer(0.6).timeout; var out := []; _trs(get_tree().root, out)
	ok(App.tr_on() or out.is_empty(), "D2 TR off, no Turkish visible @%s %s" % [where, str(out.slice(0, 4))])
