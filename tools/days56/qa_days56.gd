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
var world := true          # fix33: run through the open world (scenes/world.tscn); --rooms = the old scene-per-room run
var gt := 0.0              # game seconds since start
var _last_top := ""
var _was_guide := false
var _last_cam: Camera3D = null
var _burst_until := -1.0
var _pan_n := 0
const House := preload("res://scripts/core/house.gd")

func ok(c: bool, t: String) -> void:
	log.append(("PASS " if c else "FAIL ") + t); print("D56QA ", log[-1])

func w(t: float) -> void: await get_tree().create_timer(t, true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stop-day="): stop_day = int(a.substr(11))
		if a == "--rooms": world = false
		if a.begins_with("--shots="): shots = a.substr(8)
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
	return "world_exterior.tscn" if p.get_file() == "world.tscn" else p.get_file()

## fix33: objective timeline (top entry, game seconds) + pan bursts (several frames per pan, with camera facts)
func _process(dt: float) -> void:
	gt += dt
	var top := String(Objectives.items[0].en) if not Objectives.items.is_empty() else ""
	if top != _last_top:
		print("D56QA TOP t=%.1f day%d %s | %s | list=%s" % [gt, WorldState.day, top, kind(), JSON.stringify(Objectives.items.map(func(i): return i.en))])
		_last_top = top
		if top != "": _snap_async("top_%s" % top.left(28))
	var sh = get_tree().root.get_node_or_null("ShoulderCam")
	var g: bool = sh != null and sh.get("_guide_on") == true
	var c := get_viewport().get_camera_3d()
	if g and not _was_guide: _burst("guide")
	elif c != _last_cam and c != null and _last_cam != null: _burst("cam")
	_was_guide = g; _last_cam = c

var _sn := 0
func _snap_async(n: String) -> void:
	_sn += 1; await snap("%03d_%s" % [_sn, n.replace(" ", "_").replace("/", "_").replace("?", "").replace("'", "")])

func _burst(why: String) -> void:
	if gt < _burst_until: return
	_burst_until = gt + 3.0
	_pan_n += 1
	var tag := "pan%02d_%s_%s" % [_pan_n, why, _last_top.left(22)]
	for i in 8:
		_cam_diag("%s_f%d" % [tag, i]); await _snap_async("%s_f%d" % [tag, i]); await get_tree().create_timer(0.4, true).timeout

func _cam_diag(tag: String) -> void:
	var c := get_viewport().get_camera_3d(); var sc := cur()
	var hero = sc.get("hero") if sc and sc.get("hero") is Node3D else (sc.get("player") if sc else null)
	var sh = get_tree().root.get_node_or_null("ShoulderCam")
	print("D56QA CAM %s t=%.1f scene=%s cam=%s pos=%s hero=%s sh=%s" % [tag, gt, kind(), str(c.get_path()) if c else "-",
		str(c.global_position.snapped(Vector3.ONE * 0.01)) if c else "-", str((hero as Node3D).global_position.snapped(Vector3.ONE * 0.01)) if hero is Node3D else "-", str(sh.get("dbg")) if sh else "-"])

func go(path: String, from: String) -> void:
	App.came_from = from
	if world and cur() != null:
		var s := cur()
		print("D56QA WGO t=%.1f %s -> %s" % [gt, kind(), path])
		if House.is_room(path) and House.is_room(String(s.scene_file_path)): StoryNav.room(s, path)
		elif House.is_room(path): await WorldTrip.go("front_door"); await w(0.6); await World.goto("livingroom", "front")
		elif path == Game.WORLD_SCENE:   # fix33: out through the real front door (the old shim left the hero standing in the hall)
			if House.is_room(String(s.scene_file_path)): await OwLink.to_street("front")
			else: StoryNav.goto(Game.WORLD_SCENE, "lot:home")
		elif path.ends_with("shop.tscn"): await WorldTrip.go("shop_door"); await w(0.6); await World.goto("shop", "shop")
		await w(1.5)
		return
	if path == "res://main.tscn": App.continue_requested = true
	get_tree().change_scene_to_file(path)
	await w(1.0)

var _work_t := -100
func run() -> void:
	t_start = Time.get_ticks_msec()
	await w(1.0)
	ok(Day56Routine.active_day() == 5, "save prepared: day-5 stage alarm (%s)" % Day56.stage(5))
	if world:
		App.continue_requested = true
		get_tree().change_scene_to_file("res://scenes/world.tscn"); await w(3.0)
	else: await go("res://main.tscn", "")
	ok(await _until(func(): return get_tree().root.has_node("Day56Routine"), 20.0), "main.gd hook attached Day56Routine")
	if not get_tree().root.has_node("Day56Routine"): Day56Routine.attach(get_tree())
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
		# fix33: red's DayWork trip runs INSIDE the routine (busy): walk the hero to the car once the objective is up
		if k == "world_exterior.tscn" and Objectives.items.size() >= 1 and String(Objectives.items[0].en) in ["Go to work.", "Go to school."] and not Audio.is_speaking() and t - _work_t > 30:
			_work_t = t
			var pl = s.get("player"); var car: Node3D = null
			for so in s.find_children("*", "StreetObject", true, false):
				if String(so.get("kind")) == "car" and pl and (car == null or so.global_position.distance_to(pl.global_position) < car.global_position.distance_to(pl.global_position)): car = so
			print("D56QA WORK walk car=%s" % str(car.global_position if car else "-"))
			if car and pl: await pl.move_to(car.global_position + (pl.global_position - car.global_position).normalized() * 2.4)
			continue
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
			["livingroom.tscn", "Go outside."]:
				await snap("d%d_%s_living_out" % [d, Day56.stage(d)]); App.came_from = "livingroom"
				if world: await go(Game.WORLD_SCENE, "livingroom")
				else: Game.go_to(Game.WORLD_SCENE, "lot:home"); await w(2.0)
			["world_exterior.tscn", "Walk to the corner shop."]:
				await snap("d5_world_shop_obj")
				if world: await go("res://scenes/places/shop.tscn", "street")
				else: WorldState.player_pos = Vector3(-3, 0, 27.6); Game.go_to("res://scenes/places/shop.tscn", "front_door"); await w(2.0)
			["shop.tscn", "Go outside."]:
				if Day56.stage(5) == "home":
					s.qa_use("exit"); await w(1.0); App.came_from = "shop"
					if world: await w(4.0)
					else: Game.go_to(Game.WORLD_SCENE, "lot:corner_shop"); await w(2.0)
				else: did = false
			["world_exterior.tscn", "Go to work."], ["world_exterior.tscn", "Go to school."]:   # fix33: red's DayWork trip (days 3-7)
				var pl = s.get("player"); var car: Node3D = null
				for so in s.find_children("*", "StreetObject", true, false):
					if String(so.get("kind")) == "car" and pl and (car == null or so.global_position.distance_to(pl.global_position) < car.global_position.distance_to(pl.global_position)): car = so
				if car and pl: await pl.move_to(car.global_position + (pl.global_position - car.global_position).normalized() * 2.4)
				else: did = false
			["livingroom.tscn", ""]:   # fix33: back from red's work trip (front door) the day-6 routine waits on the street with no objective
				if Day56.stage(d) == "out" and t - _work_t > 60:
					print("D56QA WORK back home with no objective: going out"); App.came_from = "livingroom"; await go(Game.WORLD_SCENE, "livingroom")
				else: did = false
			["livingroom.tscn", "Go to work."], ["livingroom.tscn", "Go to school."]:
				App.came_from = "livingroom"
				if world: await go(Game.WORLD_SCENE, "livingroom")
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
