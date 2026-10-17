extends "res://scripts/qa_flow.gd"
## v32 integration smoke (black): day-2 night -> day-3 alarm/shower -> town pan -> cafe/shop (real lot entry/leave) -> home ->
## day-3 evening couch puzzles -> bedtime/test -> day 4 wake; street NPC talk pose, cars, phone vs caption, water levels.
## godot --path . res://tools/qa_v32int/qa_v32int.tscn -- --save-path=<day-2 night save>   Shots -> res://qa/
var qsaid := []
var obj_seen := []
var cam_max_y := -99.0
var track_cam := false
func snap(n: String) -> void: await shot("v32_" + n)
func _ready() -> void:
	if name != "QAV32INT":
		var n = (get_script() as Script).new(); n.name = "QAV32INT"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = ProjectSettings.globalize_path("res://qa/"); DirAccess.make_dir_recursive_absolute(shot_dir)
	Audio.spoke.connect(_on_spoke)
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := "%s|%s" % [it.id, it.en]
			if not s in obj_seen: obj_seen.append(s); print("QOBJ ", s))
	var mode := ""
	for a in OS.get_cmdline_user_args(): if a.begins_with("--mode="): mode = a.substr(7)
	if mode.begins_with("d2"): run_d2.call_deferred(mode)
	else: run_int.call_deferred()
func _on_spoke(t: String) -> void:
	qsaid.append(t); print("QSAY ", "OK  " if _voiced(t) else "MISS", " | ", t)
	if t == "Here is the café." or t == "Here is the shop.": _snap_later.call_deferred(t)
func _snap_box(i: int) -> void: await snap("box_dup_%d" % i)
func _snap_later(t: String) -> void:
	await w(1.2); await snap("13_pan_" + ("cafe" if t.contains("café") else "shop"))
var box_max := 0
var box_bad := []
var _box_t := 0.0
func _boxes() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("caption_box"):
		if n is Control and n.is_visible_in_tree() and n.size.y > 4: out.append(n)
	for c in get_tree().root.find_children("*", "Control", true, false):
		if String(c.name) in ["Caption", "StoryCaption"] and c.is_visible_in_tree() and c.size.y > 4 and not c in out:
			var dup := false
			for o in out: if o.is_ancestor_of(c) or c.is_ancestor_of(o): dup = true
			if not dup: out.append(c)
	return out
func _process(d: float) -> void:
	_box_t += d
	if _box_t >= 0.25:
		_box_t = 0.0
		var b := _boxes(); box_max = maxi(box_max, b.size())
		if b.size() > 1 and box_bad.size() < 6:
			var sc = get_tree().current_scene
			box_bad.append("%s:%s" % [sc.scene_file_path.get_file() if sc else "-", b.map(func(x): return String(x.get_path()).right(60))])
			print("QBOX >1 ", box_bad[-1]); _snap_box.call_deferred(box_bad.size())
	if track_cam and get_viewport().get_camera_3d(): cam_max_y = maxf(cam_max_y, get_viewport().get_camera_3d().global_position.y)
func _water_report(tag: String) -> void:
	for pl in Audio._sfx_pool:
		if pl.playing and pl.stream: print("QWATER %s %s %.1f dB" % [tag, String(pl.stream.resource_path).get_file(), pl.volume_db])
func _try_verb(sc, id: String, key: String) -> Array:
	for v in sc.verbs(id):
		if v[2] == key: sc.do_verb(id, v); return v
	return []
func _puzzles(nm: String) -> void:
	var box := get_tree().root.find_child(nm, true, false)
	if box == null: return
	for b in box.find_children("*", "Button", true, false):
		if is_instance_valid(b) and not b.disabled: b.pressed.emit()
		await w(0.03)
func _phone_play() -> void:
	var r := get_tree().root
	var sk := r.find_child("SkipTest", true, false) as Button
	if sk and sk.is_visible_in_tree() and not sk.disabled: sk.pressed.emit(); return
	var c := r.find_child("ScoreContinue", true, false) as Button
	if c and c.is_visible_in_tree(): c.pressed.emit()
func _bedtime(m, tag: String, until: Callable, limit := 1500) -> void:
	var t := 0; var shots := 0
	while not until.call() and t < limit:
		await w(0.3); t += 1; _phone_play()
		if t % 25 == 0 and shots < 8: shots += 1; await snap("%s_%02d" % [tag, shots])
	print("QBED %s %ds" % [tag, int(t * 0.3)])
func _phone_check(tag: String, ph: Control) -> void:
	var cap_top := 99999.0
	for c in get_tree().root.find_children("*", "Control", true, false):
		if String(c.name) in ["Caption", "StoryCaption"] and c.is_visible_in_tree() and c.size.y > 4: cap_top = minf(cap_top, c.get_global_rect().position.y)
	var nav_bot := -1.0
	for nm in ["NavBack", "NavHome", "NavClose"]:
		var b = ph.find_child(nm, true, false)
		if b and b.is_visible_in_tree(): nav_bot = maxf(nav_bot, b.get_global_rect().end.y)
	print("QPHONE %s caption_top=%.0f nav_bottom=%.0f phone_visible=%s" % [tag, cap_top, nav_bot, ph.visible])
	ok(ph.visible and nav_bot > 0 and cap_top < 90000.0 and nav_bot < cap_top, "%s: phone nav row above the caption (nav bottom %.0f < caption top %.0f)" % [tag, nav_bot, cap_top])
	await snap(tag)
func _hosp_step(h) -> void:
	var ph = h.get("phone")
	if ph == null or not ph.visible: return
	if ph.page == "lesson":
		var nb = ph.find_child("LessonNext", true, false)
		if nb and not Audio.is_speaking(): nb.pressed.emit()
	elif ph.page == "quiz":
		var row = ph.find_child("Options", true, false)
		if row and row.get_child_count() > 0 and not row.get_child(0).disabled: row.get_child(int(ph._qz()[ph.quiz_i].a)).pressed.emit()
	elif ph.page == "score":
		var c = ph.find_child("ScoreContinue", true, false)
		if c: await w(1.0); c.pressed.emit()
func run_d2(mode: String) -> void:
	var hosp_first := mode == "d2h"
	await w(1.0)
	App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home")
	ok(await _scene_is(Game.WORLD_SCENE, 40.0), "d2: street from the front door")
	await w(4.0)
	var wsc = get_tree().current_scene
	var car = null
	for o in wsc.find_children("*", "StreetObject", true, false): if o.kind == "car": car = o; break
	ok(car != null, "d2: my car on the home lot")
	if car == null: return _end()
	await wait_until(func(): return wsc.player != null and not wsc.player.busy, 30.0)
	for i in 3:   # unlock -> open -> choose the destination (the car's real verbs)
		var vs: Array = car._v_car()
		print("QCAR verbs ", vs.map(func(v): return v[0]))
		var pick = vs[0]
		for v in vs:
			if (hosp_first and v[0] == "Go to the hospital") or (not hosp_first and v[0] != "Go to the hospital" and not String(v[0]).contains("door") and not String(v[0]).contains("Lock")): pick = v
		pick[1].call(); await w(2.5)
		if i == 2: break
	var t := 0.0; var seen := {}; var last := ""
	while t < 600.0:
		await w(0.25); t += 0.25
		var sc = get_tree().current_scene
		if sc == null: continue
		var p := String(sc.scene_file_path)
		if not seen.has(p): seen[p] = t; print("QD2 scene ", p, " at ", t); await w(1.0); await snap("d2%s_scene_%d" % ["h" if hosp_first else "w", seen.size()])
		if p.ends_with("hospital_day2.tscn") and sc.get("ui") != null:
			var cap: String = sc.ui.en_l.text if sc.ui.panel.visible else ""
			if cap != last: last = cap; print("QCAP ", cap)
			if cap.begins_with("Now I'm going") and not seen.has("now"): seen["now"] = 1; await snap("d2%s_now_going" % ("h" if hosp_first else "w"))
			await _hosp_step(sc)
		if p == Game.WORLD_SCENE and seen.size() > 1 and Game.spawn == "home_car": break
	var sv: Dictionary = App.load_save().get("story", {})
	ok(bool(sv.get("day2_work_done", false)) and bool(sv.get("day2_hospital_done", false)), "d2 (%s first): both visits done" % ("hospital" if hosp_first else "work"))
	ok(qsaid.has("Now I'm going to work." if hosp_first else "Now I'm going to the hospital."), "d2: 'Now I'm going to ...' line between the visits")
	ok(Game.spawn == "home_car" and get_tree().current_scene.scene_file_path == Game.WORLD_SCENE, "d2: second visit -> street spawn home_car")
	wsc = get_tree().current_scene
	await w(1.5)
	var pp: Vector3 = wsc.player.global_position
	var surf = wsc.surface_at(pp) if wsc.has_method("surface_at") else "?"
	var space: PhysicsDirectSpaceState3D = wsc.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new(); var sh := CapsuleShape3D.new(); sh.radius = 0.3; sh.height = 1.6; q.shape = sh
	q.transform = Transform3D(Basis(), pp + Vector3(0, 0.9, 0)); q.exclude = [wsc.player.get_rid()] if wsc.player is CollisionObject3D else []
	var hits := space.intersect_shape(q, 8).map(func(h): return String(h.collider.name) + "/" + String(h.collider.get_parent().name) if h.collider else "?")
	print("QSPAWN pos=%s surface=%s overlaps=%s" % [pp, surf, hits])
	ok(not String(surf).to_lower().contains("road") and hits.is_empty(), "d2: home_car spawn not on the road (%s) and not inside a collider %s" % [surf, hits])
	await snap("d2%s_home_car_spawn" % ("h" if hosp_first else "w"))
	var cam := Camera3D.new(); wsc.add_child(cam); cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -9, -0.01)), pp + Vector3(0, 9, 0)); cam.current = true
	await w(0.4); await snap("d2%s_home_car_top" % ("h" if hosp_first else "w")); cam.queue_free()
	ok(await wait_until(func(): return Objectives.has("Go inside and talk to my family."), 30.0), "d2: 'Go inside and talk to my family.' objective")
	await w(2.0); await snap("d2%s_go_inside" % ("h" if hosp_first else "w"))
	ok(not Objectives.has("Go to the car.") and not Objectives.has("Walk to the street."), "d2: no stale morning objectives after both visits %s" % str(Objectives.items.map(func(it): return it.get("en", "") if it is Dictionary else str(it))))
	if not hosp_first:
		await wait_until(func(): return wsc.player != null and not wsc.player.busy, 30.0)
		wsc.hud.open_phone(); await wait_until(func(): return wsc.hud.phone.visible, 15.0); await w(1.5); wsc.caption("Go inside and talk to my family.", false); await w(0.6)
		await _phone_check("d2w_phone_caption_street", wsc.hud.phone)
		wsc.hud.phone.close(); await w(1.0)
	var home = wsc.grid.find_lot("home")
	home._on_enter()
	ok(await _scene_is("res://livingroom.tscn", 40.0), "d2: front door -> living room")
	ok(await wait_until(func(): return Objectives.has("Talk to your family."), 40.0), "d2: 'Talk to your family.' (Day2After)")
	await w(2.0); await snap("d2%s_talk_family" % ("h" if hosp_first else "w"))
	_end()
func _end() -> void:
	ok(box_max <= 1, "never more than one bottom caption box (max %d) %s" % [box_max, str(box_bad)])
	var miss := []
	for s in qsaid: if not _voiced(s) and not s in miss: miss.append(s)
	print("QMISSING_VOICE ", JSON.stringify(miss))
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("QV32INT TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()
func _scripted(path_end: String) -> Array:
	return get_tree().current_scene.find_children("*", "", true, false).filter(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with(path_end))

func run_int() -> void:
	await w(1.0)
	# ---------------- day-2 night -> day-3 alarm
	App.came_from = "livingroom"; get_tree().change_scene_to_file("res://main.tscn")
	await _scene_is("res://main.tscn")
	m = get_tree().current_scene
	ok(await wait_until(func(): return m.has_node("Bedtime"), 25.0), "day-2 bedroom: Bedtime started (night 2)")
	await _bedtime(m, "02_d2night", func(): return not m.has_node("Bedtime"))
	ok(WorldState.day == 3, "day advanced to 3")
	ok("alarm" in Audio.sfx_log, "day-3 alarm sfx played")
	ok(await wait_until(func(): return Objectives.has("Take a shower."), 30.0), "day 3: 'Take a shower.' objective")
	await w(2.0); await snap("03_d3_shower_obj")
	var nv: Array = m.verbs("night")
	print("QNIGHT verbs (has_phone=%s) %s" % [m.S.has_phone, nv.map(func(v): return v[0])])
	ok(not nv.any(func(v): return String(v[2]) in ["charge", "phone"]), "bedside: no charge / unplug button while needs are off")
	await wait_until(func(): return m.mode == "play", 30.0)
	# bathroom door through the real verb (no 'trying' block on day 3)
	var dv: Array = m.verbs("door")
	ok(not dv.is_empty() and dv[0][2] == "open" and dv[0][1] == "I am opening the door.", "day-3 bathroom door chip: %s" % str(dv))
	var n0 := qsaid.size()
	if not dv.is_empty(): m.do_verb("door", dv[0])
	await w(4.0)
	ok(not qsaid.slice(n0).any(func(s): return String(s).contains("trying")), "no door-block line on day 3")
	ok(Objectives.has("Take a shower.") and not Objectives.has("Go to the living room."), "after bathroom door: still 'Take a shower.'")
	if not await _scene_is("res://bathroom.tscn", 12.0):
		print("QNOTE door verb did not change scene by itself; entering bathroom via change_scene (came_from bedroom)")
		App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn"); await _scene_is("res://bathroom.tscn")
	var bt = get_tree().current_scene
	await w(4.0); await snap("04_bath_entered")
	ok(Objectives.has("Take a shower.") and not Objectives.has("Go to the living room."), "in bathroom before shower: 'Take a shower.' held")
	await wait_until(func(): return bt.mode == "play", 30.0)
	# tap (sink) volume
	for id in ["sink", "tap", "basin"]:
		for v in bt.verbs(id):
			if String(v[2]) in ["wash", "hands", "washhands", "tap", "face", "washface"]: bt.do_verb(id, v); await w(1.0); _water_report("tap_" + String(v[2])); await wait_until(func(): return bt.mode == "play", 30.0); break
	for v in bt.verbs("bath"):
		if v[2] == "takeshower": bt.do_verb("bath", v); break
	await w(2.5); _water_report("shower"); await snap("05_shower")
	ok(await wait_until(func(): return Objectives.has("Go to the living room."), 120.0), "after the shower: 'Go to the living room.'")
	await w(2.0); await snap("06_after_shower")
	await wait_until(func(): return bt.mode == "play", 30.0)
	for v in bt.verbs("toilet"):
		if String(v[2]) == "flush": bt.do_verb("toilet", v); await w(1.0); _water_report("flush"); await wait_until(func(): return bt.mode == "play", 30.0); break
	print("QWATER levels ", Audio.WATER_LEVEL)
	_try_verb(bt, "door", "open")
	if not await _scene_is("res://livingroom.tscn", 15.0):
		print("QNOTE bathroom door verb did not change scene; change_scene fallback")
		App.came_from = "bathroom"; get_tree().change_scene_to_file("res://livingroom.tscn"); await _scene_is("res://livingroom.tscn")
	var lr = get_tree().current_scene
	ok(await wait_until(func(): return Objectives.has("Go outside."), 40.0), "living room day 3: 'Go outside.'")
	await wait_until(func(): return lr.mode == "play", 30.0)
	await w(1.0)
	_try_verb(lr, "front", "go")
	if not await _scene_is(Game.WORLD_SCENE, 30.0):
		print("QNOTE front door verb did not change scene; Game.go_to fallback")
		App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home"); await _scene_is(Game.WORLD_SCENE, 40.0)
	# ---------------- Explore the town pan
	track_cam = true; cam_max_y = -99.0
	ok(await wait_until(func(): return Objectives.has("Explore the town."), 60.0), "outside: 'Explore the town.'")
	await w(1.0); await snap("12_explore")
	ok(await wait_until(func(): return Day3Morning.stage() == "town", 60.0), "pan done: d3 stage town")
	track_cam = false
	ok(qsaid.has("Here is the café.") and qsaid.has("Here is the shop.") and qsaid.find("Here is the café.") < qsaid.find("Here is the shop."), "pan order: café then shop")
	ok(cam_max_y >= 12.0, "pan camera went over the roofs (max y %.1f m)" % cam_max_y)
	var wsc = get_tree().current_scene
	await w(2.0); await snap("14_back_to_player")
	# ---------------- street NPC + cars
	var npcs := _scripted("world/npc.gd")
	var cars := _scripted("world/vehicle.gd")
	print("QWORLD npcs=%d cars=%d" % [npcs.size(), cars.size()])
	if not cars.is_empty():
		var p0: Array = cars.map(func(c): return (c as Node3D).global_position)
		await w(3.0)
		var moved := 0
		for i in cars.size(): if is_instance_valid(cars[i]) and (cars[i] as Node3D).global_position.distance_to(p0[i]) > 0.5: moved += 1
		ok(moved > 0, "cars run (%d/%d moved in 3 s), CarMesh on %d" % [moved, cars.size(), cars.filter(func(c): return c.find_child("CarMesh", true, false) != null).size()])
		var cam := Camera3D.new(); wsc.add_child(cam); var c0: Node3D = cars[0]
		cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -2.5, -7)), c0.global_position + Vector3(0, 3.5, 7)); cam.current = true
		await w(0.3); await snap("15_car"); cam.queue_free()
	else: ok(false, "cars: no Vehicle in the street scene")
	if not npcs.is_empty():
		var np = npcs[0]
		for x in npcs: if String(x.get("anim")) == "idle" or String(x.get("mode")) == "walk": np = x; break
		var bad := []
		np._talk()
		var tt := 0.0
		while tt < 6.0:
			await w(0.2); tt += 0.2
			var ca := String(np.hero.player.current_animation) if np.get("hero") and np.hero.get("player") else "?"
			if ca == "talk" or ca.begins_with("sit") and String(np.get("anim")) != "sit_idle": bad.append(ca)
			if absf(tt - 2.0) < 0.1:
				var cam2 := Camera3D.new(); wsc.add_child(cam2); var hp: Vector3 = (np as Node3D).global_position; print("QNPC at ", hp)
				cam2.global_transform = Transform3D(Basis.looking_at(Vector3(0, -0.6, -3.5)), hp + Vector3(0, 1.9, 3.5)); cam2.current = true
				await w(0.2); await snap("16_npc_talk"); cam2.queue_free()
		ok(bad.is_empty(), "street NPC (anim=%s mode=%s) keeps its pose while talking (bad clips %s)" % [np.get("anim"), np.get("mode"), str(bad)])
	else: print("QNOTE no street NPC streamed in")
	await w(2.0)
	# ---------------- cafe / shop through the real lot entrance + PlaceBase.leave()
	for lid in ["cafe", "corner_shop"]:
		var pid := "shop" if lid == "corner_shop" else "cafe"
		wsc = get_tree().current_scene
		var lot = wsc.grid.find_lot(lid) if wsc.get("grid") else null
		ok(lot != null and String(lot.interior_scene) != "", "%s lot wired to %s" % [pid, lot.interior_scene if lot else "-"])
		if lot == null: continue
		await wait_until(func(): return String(wsc.get("mode")) in ["play", ""] , 30.0)
		lot._on_enter()
		ok(await _scene_is("res://scenes/places/%s.tscn" % pid, 40.0), "%s entered from the street" % pid)
		await w(5.0); await snap("17_in_" + pid)
		get_tree().current_scene.leave()
		ok(await _scene_is(Game.WORLD_SCENE, 40.0), "%s left to the street" % pid)
		var want := "Go to the shop." if pid == "cafe" else "Go back home."
		ok(await wait_until(func(): return Objectives.has(want), 40.0), "after %s: '%s'" % [pid, want])
		await w(12.0); await snap("18_after_" + pid)
	ok(Day3Morning.flag("d3_cafe") and Day3Morning.flag("d3_shop") and Day3Morning.stage() == "home", "d3_cafe + d3_shop, stage home")
	# ---------------- home -> day-3 evening
	wsc = get_tree().current_scene
	var home = wsc.grid.find_lot("home") if wsc.get("grid") else null
	if home: home._on_enter()
	ok(await _scene_is("res://livingroom.tscn", 40.0), "home lot -> living room")
	lr = get_tree().current_scene
	ok(await wait_until(func(): return Day3Morning.stage() == "done", 40.0), "home again: d3 done")
	ok(await wait_until(func(): return Objectives.has("Talk to my family."), 40.0), "'Talk to my family.'")
	await w(3.0); await snap("20_talk_obj")
	await wait_until(func(): return lr.mode == "play", 30.0)
	lr.hero.global_position = Vector3(lr.SOFA_X - 1.3, 0, 0.9)   # QA shortcut for walking to the couch
	var t := 0; var sh := 0
	while not Objectives.has("Go to bed.") and t < 1200:
		await w(0.3); t += 1; await _puzzles("D3Puzzle")
		if t % 15 == 0 and sh < 8: sh += 1; await snap("21_couch_%02d" % sh)
	ok(Objectives.has("Go to bed."), "couch talk done -> 'Go to bed.' (%ds)" % int(t * 0.3))
	for q in ["Where did you go?", "How many apples did you buy?", "How much milk did you buy?"]: ok(qsaid.has(q), "family asked: " + q)
	App.came_from = "livingroom"; get_tree().change_scene_to_file("res://main.tscn")
	await _scene_is("res://main.tscn"); m = get_tree().current_scene
	ok(await wait_until(func(): return m.has_node("Bedtime"), 25.0), "day-3 bedroom: Bedtime (night 3)")
	await _bedtime(m, "22_d3night", func(): return WorldState.day == 4 and Objectives.has("Start your day."))
	ok(WorldState.day == 4, "day 4 (WorldState.day=%d)" % WorldState.day)
	ok(qsaid.has("I'm waking up.") and qsaid.has("I'm getting up."), "day-4 wake lines")
	ok(Objectives.has("Start your day."), "'Start your day.' objective")
	await w(3.0); await snap("23_day4")
	# ---------------- phone vs caption (bedroom HUD phone button handler)
	await wait_until(func(): return m.mode == "play", 30.0)
	m.S.has_phone = true
	m.open_phone_hud(); await w(0.2); m.caption("Start your day.")
	await wait_until(func(): return m.phone.visible, 15.0); await w(1.5)
	await _phone_check("24_phone_caption_bedroom", m.phone)
	_end()
