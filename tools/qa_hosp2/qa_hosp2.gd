extends "res://scripts/qa_flow.gd"
## v33 (red): day-2 hospital visit, frame by frame. Both entry orders through the real car on the home lot:
##   --mode=home : home first -> car 'Go to the hospital' -> hospital_day2 -> 'Now I'm going to work.' -> work summary
##   --mode=work : car 'Go to work' -> work summary -> 'Now I'm going to the hospital.' -> hospital_day2 -> home_car
## godot --path . res://tools/qa_hosp2/qa_hosp2.tscn -- --save-path=/tmp/red_hosp2/save.json --mode=home --out=/workspace/red_hosp2_qa/home/
## Every ~0.4 s: a JPEG frame + one LOG line (camera, anims, caption, TR, boxes, objectives, part label, phone page).
var out := "/workspace/red_hosp2_qa/"
var mode := "home"
var fi := 0
var t0 := 0
var hsaid := []
func _ready() -> void:
	if name != "QAHOSP2":
		var n = (get_script() as Script).new(); n.name = "QAHOSP2"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="): mode = a.substr(7)
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	Audio.set_narrator("m")   # the fixture player is an adult man -> narrator m (must never change)
	Audio.spoke.connect(_on_spoke)
	Objectives.changed.connect(func(): print("QOBJ ", Objectives.items.map(func(it): return "%s|%s" % [it.id, it.en])))
	_run.call_deferred()
func _on_spoke(t: String) -> void:
	hsaid.append(t)
	var sc0 = get_tree().current_scene
	print("QSAYSCENE %s | %s" % [String(sc0.scene_file_path).get_file() if sc0 else "-", t])
	var alt_ok: bool = Audio.narrator == "f" or Audio._alt_clip(Audio.norm(t)) != null
	print("QSAY t=%.1f narr=%s %s | %s" % [_t(), Audio.narrator, "OK" if alt_ok else "NOALT", t])
func _t() -> float: return (Time.get_ticks_msec() - t0) / 1000.0
func frame(tag := "") -> void:
	await RenderingServer.frame_post_draw
	var im := get_viewport().get_texture().get_image(); im.resize(800, 360, Image.INTERPOLATE_BILINEAR)
	im.save_jpg(out + "f%04d%s.jpg" % [fi, tag], 0.8); fi += 1
func _boxes() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("caption_box"): if b is Control and b.is_visible_in_tree(): n += 1
	return n
func log_line(sc: Node) -> void:
	var s := "LOG f%04d t=%.2f scene=%s" % [fi, _t(), sc.scene_file_path.get_file() if sc else "-"]
	var cam := get_viewport().get_camera_3d()
	if cam: s += " cam=(%.2f,%.2f,%.2f) rot=(%.0f,%.0f)" % [cam.global_position.x, cam.global_position.y, cam.global_position.z, cam.global_rotation_degrees.x, cam.global_rotation_degrees.y]
	if sc and sc.get("body") is DemoCharacter:
		var b: DemoCharacter = sc.body
		s += " body=%s@(%.2f,%.2f,%.2f)" % [b.player.current_animation if b.player else "?", b.global_position.x, b.global_position.y, b.global_position.z]
	if sc and sc.get("doctor") is DemoCharacter:
		var d: DemoCharacter = sc.doctor
		s += " doc=%s%s@(%.2f,%.2f)" % [d.player.current_animation if d.player else "?", "" if d.visible else "(hid)", d.global_position.x, d.global_position.z]
	var ui = sc.get("ui") if sc else null
	if ui and ui.get("panel") and ui.panel.visible: s += " CAP='%s' TR(%s)='%s'" % [ui.en_l.text, "on" if ui.tr_l.visible else "off", ui.tr_l.text]
	var lw = sc.find_child("PartWord", true, false) if sc else null
	if lw and lw.is_visible_in_tree(): s += " PART=" + lw.text
	var bx := _boxes(); if bx != 1: s += " BOXES=%d" % bx
	var ph = sc.get("phone") if sc else null
	if ph and ph.visible: s += " PHONE=" + String(ph.page)
	if not Objectives.items.is_empty(): s += " OBJ=" + str(Objectives.items.map(func(it): return it.en))
	print(s)
func _run() -> void:
	await w(1.0)
	if mode in ["end", "d3eve"]: await _run_end(); return
	if mode == "d1": await _run_d1(); return
	var gender := "men"; var age := "adult"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gender="): gender = a.substr(9)
		if a.begins_with("--age="): age = a.substr(6)
	_patch_state({"tr": false, "gender": gender, "age": age})
	Audio.set_narrator(App.narrator_for(gender, age)); print("QA body ", gender, "/", age, " narrator ", Audio.narrator)
	WorldState.load_game(); WorldState.day = 2; App.day = 2
	App.came_from = "outside"
	if mode == "direct":   # --mode=direct : straight into the day-2 visit (home-first save state), no world load
		t0 = Time.get_ticks_msec(); HospitalScene.start_day2_visit(get_tree())
	else:
		Game.go_to(Game.WORLD_SCENE, "lot:home"); await _scene_is(Game.WORLD_SCENE, 40.0); await w(3.0)
		await _car_pick()
	await _follow()
func _car_pick() -> void:
	var wx = get_tree().current_scene
	var car: StreetObject = null
	for n in _all_nodes(wx, []): if n is StreetObject and n.kind == "car": car = n; break
	car.S.locked = false; car.S.open = true
	var vb: Array = car._v_car()
	print("QA car verbs: ", vb.map(func(v): return v[0]))
	t0 = Time.get_ticks_msec()
	var pick := 1 if mode == "home" else 0
	vb[pick][1].call()
func _follow() -> void:
	var hosp_seen := false; var tick := 0
	while _t() < 820.0:
		await w(0.4); tick += 1
		var sc = get_tree().current_scene
		var in_h: bool = sc != null and String(sc.scene_file_path).ends_with("hospital_day2.tscn")
		if in_h: hosp_seen = true
		if hosp_seen and not in_h and _t() > 5:
			# after the hospital: follow 12 s more (work summary / home_car) then stop
			for k in 30: log_line(get_tree().current_scene); await frame(); await w(0.4)
			break
		if in_h or tick % 3 == 0: log_line(sc); await frame()
		if in_h: await _autoplay(sc)
	print("QA hsaid: ", hsaid)
	print("QA DONE hosp_seen=", hosp_seen, " t=", _t())
	get_tree().quit()

## --mode=end : day-2 ending. Fixture: work + hospital done. home_car spawn -> pan to the door -> front door -> living room
## "Talk to your family." -> couch chat (puzzles) -> "Go to bed." -> bedroom -> bedtime (dream, test, "I am sleeping.") -> day 3.
## Logs every spoken line with the scene it was spoken in (the stale "Go to the living room." check) + frames.
## --mode=d1 : day 1 back home from the hospital (story_home): lying in bed (standard sleep clip from the start), review
## skipped, big test autoplayed, "I am tired. I should rest." -> night -> day 2 get-up. Frames + LOG (body anim).
func _run_d1() -> void:
	var gender := "men"; var age := "adult"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gender="): gender = a.substr(9)
		if a.begins_with("--age="): age = a.substr(6)
	_patch_state({"tr": false, "gender": gender, "age": age})
	Audio.set_narrator(App.narrator_for(gender, age))
	App.patch_save({"story": {}, "day": 1}); WorldState.load_game(); WorldState.day = 1; App.day = 1
	t0 = Time.get_ticks_msec()
	App.came_from = "hospital"; App.continue_requested = true; get_tree().change_scene_to_file("res://main.tscn")
	var tick := 0; var tired := -1.0
	while _t() < 420.0:
		await w(0.4); tick += 1
		var sc = get_tree().current_scene
		if sc == null or not sc.has_method("objective"): continue
		var b: DemoCharacter = sc.hero
		print("LOGD1 t=%.1f anim=%s sleep_clip=%s rot=%s pos=%s" % [_t(), b.player.current_animation, str(sc.get("sleep_clip")), str(b.rotation), str(b.global_position)])
		if tick % 3 == 0 or (tired > 0 and _t() - tired < 10.0): await frame("_d1")
		for bt in sc.find_children("*", "Button", true, false):
			if bt.is_visible_in_tree() and String(bt.text).begins_with("Skip the review"): bt.pressed.emit(); print("QA skip review")
		await _autoplay(sc)
		if tired < 0 and hsaid.size() > 0 and hsaid[-1] == "I am tired. I should rest.": tired = _t(); print("QA tired t=", tired)
		if tired > 0 and _t() - tired > 30.0: break
	print("QA DONE d1 t=", _t()); get_tree().quit()

func _run_end() -> void:
	var gender := "men"; var age := "adult"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gender="): gender = a.substr(9)
		if a.begins_with("--age="): age = a.substr(6)
	_patch_state({"tr": false, "gender": gender, "age": age})
	Audio.set_narrator(App.narrator_for(gender, age)); print("QA body ", gender, "/", age, " narrator ", Audio.narrator)
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	for k in ["day2_work_done", "day2_hospital_done", "hospital_day2_done"]: sv[k] = true
	var day := 2
	if mode == "d3eve":
		day = 3
		for k in ["d2_couch_done", "d2_bedtime_done", "d3_cafe", "d3_shop"]: sv[k] = true
		sv["d2_bed_pending"] = false; sv["d3"] = "home"; sv["day2"] = "day3"
	App.patch_save({"story": sv, "day": day})
	WorldState.load_game(); WorldState.day = day; App.day = day
	t0 = Time.get_ticks_msec()
	var stage := "world"; var tick := 0; var sleep_t := -1.0
	if mode == "d3eve":
		App.came_from = "outside"; Game.go_to(Game.HOUSE_FRONT_DOOR_SCENE, "front_door"); stage = "door"
	else:
		App.came_from = "outside"; Game.go_to(Game.WORLD_SCENE, "home_car")
		await _scene_is(Game.WORLD_SCENE, 40.0)
	while _t() < 840.0:
		await w(0.4); tick += 1
		var sc = get_tree().current_scene
		var p: String = String(sc.scene_file_path) if sc else ""
		var dense := stage in ["sleep"] or (sleep_t > 0 and _t() - sleep_t < 14.0)
		if dense or tick % 3 == 0: log_line(sc); await frame("_" + stage)
		if stage == "world" and _t() > 9.0 and not Audio.is_speaking():
			var lot = sc.grid.find_lot("home") if sc.get("grid") else null
			if lot == null:
				for n in _all_nodes(sc, []): if n is Lot and n.kind == "home": lot = n; break
			if lot: print("QA enter home lot"); stage = "door"; lot._on_enter()
		elif p.ends_with("livingroom.tscn") and stage in ["world", "door"]:
			stage = "living"; print("QA in living room t=", _t())
		elif stage == "living":
			if (sc.has_node("Day2Evening") or sc.has_node("Day3Evening")) and String(sc.S.seat) == "" and sc.mode != "busy" and (Objectives.has("Talk to your family.") or Objectives.has("Talk to my family.")) and not hsaid.has("How was your day?"):
				sc.hero.global_position = Vector3(sc.SOFA_X - 1.2, 0, 0.8); print("QA hero to the couch")
			await _autoplay(sc)
			if Objectives.has("Go to bed.") and sc.mode == "play" and not Audio.is_speaking():
				await w(6.0)   # listen for a stale objective line after the chat
				stage = "tobed"; print("QA go to the bedroom t=", _t()); sc.do_verb("door_bed", ["Go to the bedroom", "I am opening the door.", "go"])
		elif stage == "tobed" and p.ends_with("main.tscn"):
			stage = "bedroom"; print("QA in bedroom t=", _t())
		elif stage == "bedroom":
			await _autoplay(sc)
			if hsaid.size() > 0 and hsaid[-1] == "Good night!": stage = "sleep"
		elif stage == "sleep":
			if hsaid[-1] == "I am sleeping." and sleep_t < 0: sleep_t = _t(); print("QA sleeping t=", sleep_t)
			if sleep_t > 0 and _t() - sleep_t > 14.0: stage = "day3"
		elif stage == "day3":
			await _autoplay(sc)
			if sc.get("mode") == "play" and not Audio.is_speaking(): await w(5.0); break
	print("QA hsaid: ", hsaid)
	print("QA DONE end stage=", stage, " t=", _t())
	get_tree().quit()
