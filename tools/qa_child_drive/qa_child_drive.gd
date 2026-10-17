extends "res://tools/qa_v32int/qa_v32int.gd"
## v33 child-drive QA (red). Modes (-- --mode=...):
##   fam_child / fam_adult : bedroom family screen - every exit path blocked for a child without a mom / dad
##   child_d2              : day-2 child: escort -> car -> parent drive -> hospital -> work (school) -> home
##   d2h                   : adult regression (qa_v32int run_d2, hospital first) - v32 behaviour
func snap(n: String) -> void: await shot("cd_" + n); print("SHOT cd_", n)
func _ready() -> void:
	if name != "QAV32INT":
		var n = (get_script() as Script).new(); n.name = "QAV32INT"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = "/workspace/red_drive_qa/"; DirAccess.make_dir_recursive_absolute(shot_dir)
	Audio.spoke.connect(_on_spoke)
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := "%s|%s|%s" % [it.id, it.en, it.get("tr", "")]
			if not s in obj_seen: obj_seen.append(s); print("QOBJ ", s))
	var mode := ""
	for a in OS.get_cmdline_user_args(): if a.begins_with("--mode="): mode = a.substr(7)
	if mode.begins_with("fam"): run_fam.call_deferred(mode == "fam_child")
	elif mode == "child_d2": run_child_d2.call_deferred()
	else: run_d2.call_deferred("d2h")

func _cap_text() -> String:
	for c in get_tree().root.find_children("*", "Control", true, false):
		if String(c.name) in ["Caption", "StoryCaption"] and c.is_visible_in_tree() and c.size.y > 4:
			var ls := c.find_children("*", "Label", true, false).filter(func(l): return l.visible and l.text != "")
			return " / ".join(ls.map(func(l): return l.text))
	var m2 = get_tree().current_scene
	if m2 and m2.get("cap_panel") and m2.cap_panel.visible: return String(m2.cap_text)
	return ""

# ------------------------------------------------------------------ family screen
func run_fam(child: bool) -> void:
	var tag := "child" if child else "adult"
	Audio.set_narrator("g" if child else "f")
	await w(1.0)
	App.continue_requested = true
	get_tree().change_scene_to_file("res://main.tscn")
	await _scene_is("res://main.tscn")
	m = get_tree().current_scene
	await w(6.0)
	var ph = m.phone
	print("QFAM mode=", m.mode, " child=", m.is_child(), " family=", m.S.family)
	m.phone.open(Rect2(), "family"); await w(1.0)
	ok(ph.visible and ph.page == "family", "%s: phone on the family page" % tag)
	await w(3.0)
	print("QFAM caption after enter: ", _cap_text())
	if child: ok(_cap_text().contains("Add a mom or a dad first."), "child: hint shown on entering the family page")
	await snap("fam_%s_01_empty" % tag)
	# a sister only (not a parent)
	m.S.family.append({"name": "Sue", "role": "sister", "adj": ["kind"], "col": 0, "skin": 1, "hair": 0, "hcol": 1, "cloth": 1, "pron": "she", "child": true})
	ph._family(); await w(0.5)
	var paths := {}
	var done = ph.find_child("FamilyDone", true, false)
	ChildDrive._hint_t = -10.0; done.pressed.emit(); await w(0.6); paths["done"] = ph.visible and ph.page == "family"
	await w(0.8); var cap_done := _cap_text(); print("QFAM caption after Done: ", cap_done)
	if child: await snap("fam_child_02_done_blocked")
	if child:
		ok(cap_done.contains("Add a mom or a dad first."), "child: Done -> hint in the caption box")
		ok(App.tr_on() == false or cap_done.contains("Önce bir anne"), "child: TR line present when TR is on")
		m.S.tr = true; App.save_tr(true); m._refresh_text(); await w(0.3); await snap("fam_child_03_hint_tr"); print("QFAM caption TR: ", _cap_text())
		ok(_cap_text().contains("Önce bir anne ya da baba ekle."), "child: hint TR 'Önce bir anne ya da baba ekle.'")
		m.S.tr = false; App.save_tr(false); m._refresh_text()
	ChildDrive._hint_t = -10.0; ph.back(); await w(0.6); paths["back"] = ph.visible and ph.page == "family"
	ChildDrive._hint_t = -10.0; ph.show_page("home"); await w(0.6); paths["home"] = ph.visible and ph.page == "family"
	ChildDrive._hint_t = -10.0; ph.close(); await w(0.6); paths["close"] = ph.visible and ph.page == "family"
	ChildDrive._hint_t = -10.0; ph.close(true); await w(0.6); paths["close_force"] = ph.visible and ph.page == "family"
	ph.new_member(); await w(0.4); ChildDrive._hint_t = -10.0; ph.close(); await w(0.6); paths["member_close"] = ph.visible and ph.page == "member"
	ph.back(); await w(0.4); paths["member_back_to_family"] = ph.page == "family"
	ChildDrive._hint_t = -10.0; ph.family_done(); await w(0.6); paths["family_done_direct"] = ph.visible and ph.page == "family"
	var ev := InputEventAction.new(); ev.action = "ui_cancel"; ev.pressed = true; Input.parse_input_event(ev); await w(0.6)
	paths["ui_cancel"] = ph.visible and ph.page == "family"
	print("QFAM paths ", paths, " door_rule=", m.door_rule(), " objective=", m.objective())
	if child:
		for k in paths: ok(paths[k] if k == "member_back_to_family" else paths[k], "child: exit path '%s' blocked" % k)
		ok(m.door_rule() == true, "child: bedroom door stays locked without a parent")
		ok(m.objective()[0] == "Add your family.", "child: objective stays 'Add your family.'")
		# add a mom -> Done works
		m.S.family.append({"name": "Mia", "role": "mother", "adj": ["kind"], "col": 0, "skin": 1, "hair": 0, "hcol": 1, "cloth": 1, "pron": "she", "child": false})
		ph._family(); await w(0.4)
		ph.find_child("FamilyDone", true, false).pressed.emit(); await w(1.0)
		ok(ph.page == "home", "child: with a mom, Done -> home page (%s)" % ph.page)
		ok(m.door_rule() == false, "child: with a mom the door unlocks")
		await snap("fam_child_04_with_mom")
	else:
		ok(not paths["done"], "adult: Done with a sister only still works (v32)")
		ok(m.door_rule() == false, "adult: door rule unchanged (unlocked with any family)")
	_end()

# ------------------------------------------------------------------ day 2, child
func run_child_d2() -> void:
	Audio.set_narrator("g")
	await w(1.0)
	App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home")
	ok(await _scene_is(Game.WORLD_SCENE, 40.0), "c: street from the front door")
	await w(4.0)
	var wsc = get_tree().current_scene
	ok(wsc.has_node("ChildDrive") and wsc.get_node("ChildDrive").par != null, "c: mom comes outside with the child (escort)")
	await snap("c01_escort")
	var car = null
	for o in wsc.find_children("*", "StreetObject", true, false): if o.kind == "car": car = o; break
	await wait_until(func(): return wsc.player != null and not wsc.player.busy and wsc.mode == "play", 30.0)
	# walk to the car (scripted stick-free walk at walking speed; the parent follows)
	var pl = wsc.player; var to: Vector3 = car.it.global_position + Vector3(-1.2, 0, 1.5); to.y = pl.global_position.y
	pl.hero.play("walk", 0.2)
	var shot_mid := false
	while pl.global_position.distance_to(to) > 0.2 and not wsc.get_node("Day2Car").fired:
		var d: Vector3 = to - pl.global_position; d.y = 0
		pl.global_position += d.normalized() * minf(d.length(), 1.6 * get_process_delta_time()); pl.hero.rotation.y = atan2(d.x, d.z)
		if not shot_mid and pl.global_position.distance_to(to) < 6.0: shot_mid = true; await snap("c02_walk_together")
		await get_tree().process_frame
	pl.hero.play("idle", 0.2)
	await wait_until(func(): return wsc.hud.chips.get_child_count() > 1 or car.S.open, 30.0); await w(3.0)
	var vs: Array = car._v_car(); print("QCAR verbs ", vs.map(func(v): return v[0]))
	for _i in 3:   # locked / closed car: unlock + open first (timing-dependent)
		if vs.size() > 0 and String(vs[0][0]) in ["Unlock the car", "Open the car door"]:
			vs[0][1].call(); await w(2.0); vs = car._v_car(); print("QCAR verbs ", vs.map(func(v): return v[0]))
	for v in vs: if v[0] == "Go to the hospital": v[1].call(); break
	var t := 0.0; var seen := {}; var last := ""; var scenes := []
	var cd_world = wsc.get_node("ChildDrive")
	while t < 880.0:
		await w(0.25); t += 0.25
		var sc = get_tree().current_scene
		if sc == null: continue
		var p := String(sc.scene_file_path)
		if scenes.is_empty() or scenes[-1] != p: scenes.append(p); print("QC scene ", p, " at ", t)
		var cap := _cap_text()
		if cap != last: last = cap; print("QCAP ", cap)
		if p == Game.WORLD_SCENE and sc.has_node("ChildDrive"):
			var cd = sc.get_node("ChildDrive")
			var k := "home" if scenes.size() > 2 else "dep"
			if cd.riding and not seen.has(k + "_ride"): seen[k + "_ride"] = t; await w(0.3); await snap("c03_%s_seated" % k)
			if cd.riding and seen.has(k + "_ride") and t - seen[k + "_ride"] > 3.0 and not seen.has(k + "_drive"): seen[k + "_drive"] = t; await snap("c04_%s_driving" % k)
			if k == "dep" and not seen.has("dep_doors") and car.has_meta("pass_door") and absf(car.get_meta("pass_door").rotation.y) > 0.9: seen["dep_doors"] = t; await snap("c03_dep_doors_open")
			if k == "home" and not cd.riding and cd.following and not seen.has("home_out"): seen["home_out"] = t; await w(0.5); await snap("c05_home_out")
			if k == "home" and Objectives.has("Go inside and talk to my family.") and not seen.has("go_inside"):
				seen["go_inside"] = t; await w(3.0); await snap("c06_home_go_inside"); break
		if p.ends_with("child_drive_stop.tscn"):
			var n := scenes.count(p)
			var cd = sc.cd
			var k2 := "s%d_%s" % [n, sc.sign_en.text.to_lower()]
			if cd.riding and not seen.has(k2 + "_r"): seen[k2 + "_r"] = t; await w(1.0); await snap(k2 + "_riding")
			if not cd.riding and cd.par and Objectives.items.size() > 0 and String(Objectives.items[0].en).begins_with("Go to") and not seen.has(k2 + "_obj"):
				seen[k2 + "_obj"] = t; await w(1.2); await snap(k2 + "_objective")
			if not cd.riding and cap.contains("Let's go in") and not seen.has(k2 + "_in"): seen[k2 + "_in"] = t; await w(1.5); await snap(k2 + "_walk_in")
		if p.ends_with("hospital_day2.tscn") and sc.get("ui") != null:
			if cap.begins_with("Now I'm going") and not seen.has("now"): seen["now"] = 1; await snap("c_hosp_now_going")
			await _hosp_step(sc)
	print("QC scenes ", scenes); print("QC seen ", seen)
	var stop := "res://scenes/child_drive_stop.tscn"
	ok(scenes.count(stop) >= 2, "c: drive scenes used for the trips (%d)" % scenes.count(stop))
	ok(scenes.has("res://scenes/hospital_day2.tscn"), "c: reached the hospital")
	var sv: Dictionary = App.load_save().get("story", {})
	ok(bool(sv.get("day2_work_done", false)) and bool(sv.get("day2_hospital_done", false)), "c: both visits done")
	for l in ["My mom is driving me to the hospital.", "My mom is driving me to school.", "My mom is driving me home."]: ok(qsaid.has(l), "c: said '%s'" % l)
	ok(not qsaid.any(func(s): return String(s).begins_with("I am driving") or String(s).begins_with("I'm driving") or String(s) == "I am getting in my car."), "c: the child never says 'I am driving ...'")
	ok(seen.has("go_inside"), "c: home -> 'Go inside and talk to my family.'")
	var tr_ok := true
	for s in obj_seen:
		var parts := String(s).split("|")
		if parts.size() >= 3 and parts[2] == "": tr_ok = false; print("QOBJ no TR: ", s)
	ok(tr_ok, "c: every objective has TR")
	_end()
