extends Node
## v33 (blue) QA: walks day 5 (+ day 6) start to end through Day56Routine, playing the player's part:
## alarm -> bathroom -> breakfast review -> outing + dramatic event -> couch -> polaroids -> bedtime test -> next day.
## godot --path . res://tools/days56/qa_days56.tscn -- --qa-d56 --save-path=/tmp/qa_d56/save.json [--stop-day=5]
## Runs at 4x (Engine.time_scale + AudioServer.playback_speed_scale) so no voice line is cut, just faster.
var log: Array = []
var objs: Array = []
var said: Array = []
var wrong_tried := {}
var choices := 0
var wrong_fb := 0
var t_start := 0
var shots := "/tmp/qa_d56/shots/"
var stop_day := 6

func ok(c: bool, t: String) -> void:
	log.append(("PASS " if c else "FAIL ") + t); print("D56QA ", log[-1])

func w(t: float) -> void: await get_tree().create_timer(t, true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args(): if a.begins_with("--stop-day="): stop_day = int(a.substr(11))
	DirAccess.make_dir_recursive_absolute(shots)
	Engine.time_scale = 4.0; AudioServer.playback_speed_scale = 4.0
	Audio.spoke.connect(func(t): said.append(t))
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := String(it.en)
			if not s in objs: objs.append(s); print("D56QA OBJ day%d %s | %s" % [App.day, s, String(it.get("tr", ""))]))
	run.call_deferred()

func snap(n: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots + n + ".png")

func cur() -> Node: return get_tree().current_scene
func kind() -> String:
	var p := String(cur().scene_file_path) if cur() else ""
	return p.get_file()

func go(path: String, from: String) -> void:
	App.came_from = from
	if path == "res://main.tscn": App.continue_requested = true
	get_tree().change_scene_to_file(path)
	await w(1.0)

func run() -> void:
	t_start = Time.get_ticks_msec()
	await w(1.0)
	ok(Day56Routine.active_day() == 5, "save prepared: day-5 stage alarm (%s)" % Day56.stage(5))
	await go("res://main.tscn", "")
	ok(await _until(func(): return get_tree().root.has_node("Day56Routine"), 20.0), "main.gd hook attached Day56Routine")
	var phase := {}
	var last_obj_act := ""
	var t := 0
	while t < 6000:
		await w(0.3); t += 1
		_press_choice()
		if t % 50 == 0: _diag(t)
		_press_test()
		var d := Day56Routine.active_day()
		if Day56.stage(stop_day) == "done" and (stop_day == 5 or WorldState.day >= 7):
			await w(8.0); break   # day 6 -> 7: let the get-up + red's handoff run
		if d == 0: continue
		var s := cur(); if s == null: continue
		var k := kind()
		var dr := get_tree().root.get_node_or_null("Day56Routine")
		if dr == null or dr._busy: continue
		var o: String = String(dr._cur.get("en", ""))
		if o == "" and Objectives.items.size() == 1: o = String(Objectives.items[0].en)
		if s.get("mode") != null and String(s.mode) != "play": continue
		if Audio.is_speaking(): continue
		var key := "%d|%s|%s|%s" % [d, Day56.stage(d), k, o]
		if key == last_obj_act: continue
		var did := true
		match [k, o]:
			["main.tscn", "Go to the bathroom."]: await go("res://bathroom.tscn", "bedroom")
			["bathroom.tscn", "Wash your face and brush your teeth."]: _verb(s, "sink", "routine")
			["bathroom.tscn", "Take a shower."]: _verb(s, "bath", "takeshower")
			["livingroom.tscn", "Go to the bathroom."]: await go("res://bathroom.tscn", "livingroom")
			["bathroom.tscn", "Go to the living room."], ["main.tscn", "Go to the living room."]: await go("res://livingroom.tscn", "bathroom" if k == "bathroom.tscn" else "bedroom")
			["livingroom.tscn", "Go outside."]: await snap("d%d_%s_living_out" % [d, Day56.stage(d)]); App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home"); await w(2.0)
			["world_exterior.tscn", "Walk to the corner shop."]: await snap("d5_world_shop_obj"); WorldState.player_pos = Vector3(-3, 0, 27.6); Game.go_to("res://scenes/places/shop.tscn", "front_door"); await w(2.0)
			["shop.tscn", "Go outside."]:
				if Day56.stage(5) == "home": s.qa_use("exit"); await w(1.0); App.came_from = "shop"; Game.go_to(Game.WORLD_SCENE, "lot:corner_shop"); await w(2.0)
				else: did = false
			["world_exterior.tscn", "Go to the bus stop."]:
				await snap("d6_world_stop_obj")
				var sp: Vector3 = Transit.stops.stop_home.pos if Transit.stops.has("stop_home") else Vector3(9.5, 0, 14.7)
				s.player.global_position = Vector3(sp.x + 1.5, 0.07, sp.z + 1.0)
			["world_exterior.tscn", "Go home."], ["world_exterior.tscn", "Go inside."]: await snap("d%d_world_home" % d); await go(Game.HOUSE_FRONT_DOOR_SCENE, "outside")
			["livingroom.tscn", "Go to bed."]: await snap("d%d_living_bed_obj" % d); await go("res://main.tscn", "livingroom")
			_: did = false
		if did: last_obj_act = key
		var ph := "%d_%s" % [d, Day56.stage(d)]
		if not phase.has(ph): phase[ph] = true; print("D56QA PHASE ", ph, " in ", k, " t=", (Time.get_ticks_msec() - t_start) / 1000); await snap("phase_" + ph)
	var sv := Day56.story()
	ok(Day56.stage(5) == "done", "day 5 finished (stage %s)" % Day56.stage(5))
	ok(bool(sv.get("d5_shop_done", false)), "day 5 dramatic event (lost child) played")
	ok(sv.has("d5_night_score"), "day 5 bedtime test finished %s" % str(sv.get("d5_night_score")))
	for p in ["d5_breakfast", "d5_shop", "d5_couch"]: ok(Life.photo(p) != null, "polaroid " + p)
	if stop_day >= 6:
		ok(Day56.stage(6) == "done", "day 6 finished (stage %s)" % Day56.stage(6))
		ok(bool(sv.get("d6_storm_done", false)), "day 6 dramatic event (storm + bus) played")
		ok(sv.has("d6_night_score"), "day 6 bedtime test finished %s" % str(sv.get("d6_night_score")))
		for p in ["d6_breakfast", "d6_storm", "d6_couch"]: ok(Life.photo(p) != null, "polaroid " + p)
		ok(WorldState.day >= 7, "day advanced to %d" % WorldState.day)
	ok(choices >= 8 and wrong_fb >= 3, "choices answered %d, wrong-answer feedback shown %d" % [choices, wrong_fb])
	var miss: Array = []
	for x in said:
		var nk := Audio.norm(String(x))
		if not Audio.index.has(nk) and not Audio.alt_index.has(nk) and not miss.has(x): miss.append(x)
	print("D56QA MISSING_VOICE ", JSON.stringify(miss))
	print("D56QA OBJECTIVES ", JSON.stringify(objs))
	print("D56QA TOTAL %d PASS %d FAIL  (%ds game-run)" % [log.filter(func(l): return l.begins_with("PASS")).size(), log.filter(func(l): return l.begins_with("FAIL")).size(), (Time.get_ticks_msec() - t_start) / 1000])
	get_tree().quit()

func _diag(t: int) -> void:
	var s := cur(); var box := get_tree().root.find_child("D56Choice", true, false)
	var shop := get_tree().root.find_child("Day5Shop", true, false)
	print("D56QA DIAG t=%d scene=%s mode=%s speaking=%s choice=%s obj=%s player=%s shop=%s" % [t, kind(), str(s.get("mode")) if s else "-", Audio.is_speaking(),
		box != null, JSON.stringify(Objectives.items.map(func(i): return i.en)), str(s.player.global_position) if s and s.get("player") else "-", str(shop.get("_dbg")) if shop else "-"])
	await snap("diag_%d" % t)

func _until(c: Callable, t: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not c.call():
		if Time.get_ticks_msec() - t0 > t * 1000.0: return false
		await w(0.2)
	return true

func _verb(s: Node, id: String, key: String) -> void:
	for v in s.verbs(id):
		if v[2] == key: s.do_verb(id, v); return

## choice panel: first a wrong option once per panel (feedback path), then the right one
func _press_choice() -> void:
	var box := get_tree().root.find_child("D56Choice", true, false)
	if box == null: return
	var btns := box.find_children("D56Opt*", "Button", true, false)
	var id := box.get_instance_id()
	btns = btns.filter(func(b): return not (b as Button).disabled and (b as Button).is_visible_in_tree())
	if btns.is_empty() or Audio.is_speaking(): return
	if not wrong_tried.has(id):
		wrong_tried[id] = true
		for b in btns:
			if not bool(b.get_meta("ok")): b.pressed.emit(); wrong_fb += 1; return
	for b in btns:
		if bool(b.get_meta("ok")): b.pressed.emit(); choices += 1; return

## bedtime test: day 5 answers every question (Opt0..2, then Continue), day 6 uses the Skip button
func _press_test() -> void:
	var r := get_tree().root
	if Day56Routine.active_day() == 6:
		var sk := r.find_child("SkipTest", true, false) as Button
		if sk and sk.is_visible_in_tree() and not sk.disabled: print("D56QA skip test (day 6)"); sk.pressed.emit(); return
	for i in 3:
		var o := r.find_child("Opt%d" % i, true, false) as Button
		if o and o.is_visible_in_tree() and not o.disabled: o.pressed.emit(); return
	var c := r.find_child("ScoreContinue", true, false) as Button
	if c and c.is_visible_in_tree(): await snap("test_score_day%d" % App.day); c.pressed.emit()
