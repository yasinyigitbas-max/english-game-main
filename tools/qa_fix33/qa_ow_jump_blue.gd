## red QA: start world.tscn and jump straight to one scripted event. godot ... res://tools/qa_ow/qa_ow_jump.tscn -- --qa-ow=<ev>
## ev: bk1 bk2 couch2 d4cut d7party hosp2 cafe. Screenshots -> /workspace/red_ow_shots/<ev>_<n>.png
extends Node
var ev := "bk1"
func _ready() -> void:
	for a in OS.get_cmdline_user_args(): if a.begins_with("--qa-ow="): ev = a.substr(8)
	add_child(load("res://scenes/world.tscn").instantiate())
	await _t(6.0)
	var day: int = {"bk1": 1, "bk2": 2, "couch2": 2, "d4cut": 4, "d7party": 7, "hosp2": 2, "cafe": 3, "mirror2": 2, "hosp1": 1, "street": 1, "towel": 1, "d4bk": 4, "work4": 4, "liedown": 4}.get(ev, 1)
	var st: Dictionary = App.load_save().get("story", {}).duplicate() if App.load_save().get("story", {}) is Dictionary else {}
	if day >= 3: st["day2"] = "done"
	match ev:
		"bk2": st["day2"] = "living"
		"couch2": st.merge({"day2": "done", "day2_work_done": true, "day2_hospital_done": true, "d2_couch_done": false}, true)
		"d4cut": st["d4"] = "evening"
		"d4bk": st["d4"] = "breakfast"
		"work4": st["d4"] = "outing"
		"liedown": st["d4"] = "bed"
		"d7party": st["d7"] = "evening"
		"mirror2": st.merge({"day1_done": true, "day2": "living"}, true)
	var sv: Dictionary = App.load_save(); var state: Dictionary = (sv.get("state", {}) if sv.get("state", {}) is Dictionary else {}).duplicate()
	state["family"] = [{"role": "mother", "name": "Ayse", "skin": 1, "hair": 0, "hcol": 1, "cloth": 0},
		{"role": "father", "name": "Mehmet", "skin": 2, "hair": 2, "hcol": 0, "cloth": 1},
		{"role": "sister", "name": "Elif", "skin": 1, "hair": 2, "hcol": 2, "cloth": 3, "child": true}, {"role": "dog", "name": "Karabas", "col": 0}]
	state.merge({"created": true, "job": "doctor", "lesson_done": true, "calendar_seen": true, "has_phone": true, "name": "Yasin"}, true)
	WorldState.day = day; App.day = day; App.patch_save({"story": st, "day": day, "state": state, "family_breakfast": true, "has_phone": true})
	var shots: Array = [8.0, 20.0] if not ev in ["d4cut", "d7party", "d4bk"] else [6.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0, 30.0, 34.0, 38.0, 42.0, 46.0, 50.0]
	match ev:
		"hosp2": await OwLink.enter("hospital_day2", ""); shots = [20.0, 45.0]
		"hosp1": await OwLink.enter("hospital", ""); shots = [15.0, 40.0]
		"street":
			WorldState.flags.erase("story_accident")
			await OwLink.enter("livingroom", "bedroom"); await _t(4.0)
			var lr = OwLink.inst.world.places.get("livingroom"); lr.hero.position = Vector3(2.35, 0, 2.55); lr.hero.rotation.y = 0.0
			OwLink.to_street("front"); shots = [8.0, 18.0, 28.0, 38.0]
		"mirror2":
			var w = OwLink.inst.world; var bed = w.places.get("bedroom")
			for k in state: if bed.S.has(k): bed.S[k] = state[k]   # the bedroom as a real day-1 left it
			var stale: Dictionary = state.duplicate(); stale["created"] = false; stale["lesson_done"] = false
			App.patch_save({"state": stale})   # a room phone built at world start writes its stale S (build 3.2 bug)
			await OwLink.enter("livingroom", "bedroom"); await _t(3.0)
			await OwLink.enter("bedroom", "livingroom"); await _t(6.0); _shot(0)
			print("RED_MISSION ", bed.mission, " created=", bed.S.created)
			await OwLink.enter("livingroom", "bedroom"); await _t(14.0); _shot(1); get_tree().quit(); return
		"liedown":
			WorldState.minutes = 22.0 * 60.0; App.patch_save({"alarm_off_day": 4})   # a real bedtime: evening, today's alarm long done
			await OwLink.enter("bedroom", ""); await _t(6.0)
			var bm = OwLink.inst.world.places.get("bedroom"); bm.mode = "busy"
			# blue: no QA cam_shot - the shoulder camera's own bed framing is under test
			await bm.walk_to(bm.OBJ.bed.spot, 0.0); await _t(1.0)
			bm.lie_down()
			for i in 26:
				await _t(0.25 if i > 0 else 1.5); _shot(i)
			await _t(3.0); _shot(26)
			get_tree().quit(); return
		"work4":
			App.patch_save({"work_due_day": 4, "work_done_day": 0})
			await OwLink.enter("livingroom", "bedroom"); await _t(4.0)
			var lr4 = OwLink.inst.world.places.get("livingroom"); lr4.hero.position = Vector3(2.35, 0, 2.55)
			OwLink.to_street("front"); await _t(7.0); _shot(0)
			var w4 = OwLink.inst.world; var car4: Node3D = null
			for o in w4.find_children("*", "StreetObject", true, false):
				if String(o.get("kind")) == "car" and (car4 == null or o.global_position.distance_to(w4.player.global_position) < car4.global_position.distance_to(w4.player.global_position)): car4 = o
			print("RED_CAR ", car4.global_position if car4 else "none", " player=", w4.player.global_position)
			load("res://scripts/story/day_work.gd").gate(w4)   # (QA: World is not the root scene here, so the day director never sees "outside")
			await _t(5.0)
			if car4: w4.player.global_position = car4.global_position + Vector3(2.5, 0, 0)
			await _t(3.0); _shot(1); await _t(8.0); _shot(2); await _t(14.0); _shot(3); get_tree().quit(); return
		"cafe":
			await OwLink.travel("cafe", "cafe"); await _t(16.0); _shot(0)
			var c = get_tree().current_scene
			if c and c.has_method("qa_use"): c.qa_use("counter")
			await _t(14.0); _shot(1); get_tree().quit(); return
		_: await OwLink.enter("livingroom", "bedroom")
	if ev == "couch2":
		await _t(3.0); load("res://scripts/story/day2_evening.gd").start(get_tree())
		var lr2 = OwLink.inst.world.places.get("livingroom"); lr2.hero.position = Vector3(lr2.SOFA_X - 1.2, 0, 0.0)   # the player walks up to the couch
	var t0 := 0.0
	for i in shots.size():
		await _t(shots[i] - t0); t0 = shots[i]; _shot(i)
	get_tree().quit()
func _t(s: float) -> void: await get_tree().create_timer(s).timeout
func _shot(i: int) -> void:
	get_viewport().get_texture().get_image().save_png("/workspace/blue_fix33/redjump/%s_%02d.png" % [ev, i])
	var vc := get_viewport().get_camera_3d()
	if vc: print("BLUE_CAM ", ev, " ", i, " cam=", vc.get_path(), " pos=", vc.global_position, " fwd=", -vc.global_transform.basis.z, " hero=", OwLink.the_hero().global_position, " sh=", get_tree().root.get_node_or_null("ShoulderCam").get("dbg") if get_tree().root.get_node_or_null("ShoulderCam") else "-")
	var cs = get_tree().current_scene; print("RED_SHOT ", ev, " ", i, " ", cs.name if cs else "-", " cam=", get_viewport().get_camera_3d().get_path() if get_viewport().get_camera_3d() else "none", " obj=", Objectives.items)
	if cs: print("RED_STATE mode=", cs.get("mode"), " speaking=", Audio.is_speaking(), " cam_shot=", cs.get("cam_shot"), " hero_l=", (cs as Node3D).to_local(OwLink.the_hero().global_position) if cs is Node3D else "")
	if cs and cs.get("hero"): print("RED_HERO par=", cs.hero.get_parent().get_path(), " pos=", cs.hero.position, " same=", cs.hero == OwLink.the_hero(), " canproc=", cs.can_process(), " dt=", cs.get_process_delta_time(), " paused=", get_tree().paused, " anim=", cs.hero.get("current") if true else "")
	for n in get_tree().root.get_children():
		if String(n.name).begins_with("Day"): print("RED_DIR ", n.name, " busy=", n.get("_busy"), " dbg=", n.get("_dbg"))
	if ev == "street" and OwLink.active():
		var wk = OwLink.inst.world
		for c in wk.get_children().slice(-6): if c is Node3D: print("RED_W ", c.name, " ", (c as Node3D).global_position, " vis=", (c as Node3D).is_visible_in_tree())
		print("RED_HERO ", OwLink.the_hero().global_position)
	if cs is Node3D:
		for n in cs.find_children("*", "", true, false):
			if n is DemoCharacter and n.visible: print("RED_POS ", n.name, " local=", (cs as Node3D).to_local(n.global_position).snapped(Vector3.ONE * 0.01))
