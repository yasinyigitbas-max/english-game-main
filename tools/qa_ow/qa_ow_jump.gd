## red QA: start world.tscn and jump straight to one scripted event. godot ... res://tools/qa_ow/qa_ow_jump.tscn -- --qa-ow=<ev>
## ev: bk1 bk2 couch2 d4cut d7party hosp2 cafe. Screenshots -> /workspace/red_ow_shots/<ev>_<n>.png
extends Node
var ev := "bk1"
func _ready() -> void:
	for a in OS.get_cmdline_user_args(): if a.begins_with("--qa-ow="): ev = a.substr(8)
	add_child(load("res://scenes/world.tscn").instantiate())
	await _t(6.0)
	var day: int = {"bk1": 1, "bk2": 2, "couch2": 2, "d4cut": 4, "d7party": 7, "hosp2": 2, "cafe": 3, "mirror2": 2, "hosp1": 1, "street": 1, "towel": 1}.get(ev, 1)
	var st: Dictionary = App.load_save().get("story", {}).duplicate() if App.load_save().get("story", {}) is Dictionary else {}
	match ev:
		"bk2": st["day2"] = "living"
		"couch2": st.merge({"day2": "done", "day2_work_done": true, "day2_hospital_done": true, "d2_couch_done": false}, true)
		"d4cut": st["d4"] = "evening"
		"d7party": st["d7"] = "evening"
		"mirror2": st.merge({"day1_done": true, "day2": "living"}, true)
	var sv: Dictionary = App.load_save(); var state: Dictionary = (sv.get("state", {}) if sv.get("state", {}) is Dictionary else {}).duplicate()
	state["family"] = [{"role": "mother", "name": "Ayse", "skin": 1, "hair": 0, "hcol": 1, "cloth": 0},
		{"role": "father", "name": "Mehmet", "skin": 2, "hair": 2, "hcol": 0, "cloth": 1},
		{"role": "sister", "name": "Elif", "skin": 1, "hair": 2, "hcol": 2, "cloth": 3, "child": true}, {"role": "dog", "name": "Karabas", "col": 0}]
	if ev == "mirror2": state.merge({"created": true, "job": "doctor", "lesson_done": true, "calendar_seen": true, "has_phone": true, "name": "Yasin"}, true)
	WorldState.day = day; App.day = day; App.patch_save({"story": st, "day": day, "state": state, "family_breakfast": true, "has_phone": ev == "mirror2"})
	var shots: Array = [8.0, 20.0] if not ev in ["d4cut", "d7party"] else [10.0, 40.0]
	match ev:
		"hosp2": await OwLink.enter("hospital_day2", ""); shots = [20.0, 45.0]
		"hosp1": await OwLink.enter("hospital", ""); shots = [15.0, 40.0]
		"street":
			WorldState.flags.erase("story_accident"); OwLink.to_street("front"); shots = [8.0, 18.0, 28.0]
		"mirror2":
			var w = OwLink.inst.world; var bed = w.places.get("bedroom")
			for k in state: if bed.S.has(k): bed.S[k] = state[k]   # the bedroom as a real day-1 left it
			var stale: Dictionary = state.duplicate(); stale["created"] = false; stale["lesson_done"] = false
			App.patch_save({"state": stale})   # a room phone built at world start writes its stale S (build 3.2 bug)
			await OwLink.enter("livingroom", "bedroom"); await _t(3.0)
			await OwLink.enter("bedroom", "livingroom"); await _t(6.0); _shot(0)
			print("RED_MISSION ", bed.mission, " created=", bed.S.created)
			await OwLink.enter("livingroom", "bedroom"); await _t(14.0); _shot(1); get_tree().quit(); return
		"cafe":
			await OwLink.enter("cafe", ""); await _t(12.0); _shot(0)
			var c = get_tree().current_scene
			if c and c.has_method("qa_use"): c.qa_use("counter")
			await _t(14.0); _shot(1); get_tree().quit(); return
		_: await OwLink.enter("livingroom", "bedroom")
	if ev == "couch2": await _t(3.0); load("res://scripts/story/day2_evening.gd").start(get_tree())
	var t0 := 0.0
	for i in shots.size():
		await _t(shots[i] - t0); t0 = shots[i]; _shot(i)
	get_tree().quit()
func _t(s: float) -> void: await get_tree().create_timer(s).timeout
func _shot(i: int) -> void:
	get_viewport().get_texture().get_image().save_png("/workspace/red_ow_shots/%s_%d.png" % [ev, i])
	var cs = get_tree().current_scene; print("RED_SHOT ", ev, " ", i, " ", cs.name if cs else "-")
	if cs is Node3D:
		for n in cs.find_children("*", "", true, false):
			if n is DemoCharacter and n.visible: print("RED_POS ", n.name, " local=", (cs as Node3D).to_local(n.global_position).snapped(Vector3.ONE * 0.01))
