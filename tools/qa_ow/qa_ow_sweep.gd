## black sweep: days 6/7 autopilot + places + fix33 checks. -- --qa-ow=d6|d6b|d6c|d7|d7b|places|fix|d1 [--qa-out=/dir/]
extends Node
var ev := "d6"
var OUT := "/workspace/dl/ow_sweep/"
var objs: Array = []
var last_key := ""
var t0 := 0
var nshot := 0
func P(s) -> void: print("SWEEP ", s)
func w(t: float) -> void: await get_tree().create_timer(t, true).timeout
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa-ow="): ev = a.substr(8)
		if a.begins_with("--qa-out="): OUT = a.substr(9)
	if ev != "d6b": await _setup(true); App.continue_requested = true
	var wn = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(wn)
	await get_tree().process_frame; await get_tree().process_frame
	get_tree().current_scene = wn
	await w(6.0)
	if OwLink.inst and is_instance_valid(OwLink.inst.live): get_tree().current_scene = OwLink.inst.live
	P("LIVE " + (OwLink.inst.live_id if OwLink.inst else "-"))
	if not ev in ["places", "fix", "fixb", "trburst", "d1", "ui", "hosp", "hosp2"]: Engine.time_scale = 2.5; AudioServer.playback_speed_scale = 2.5
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := String(it.en)
			if not s in objs: objs.append(s); P("OBJ t=%d day%d %s | %s" % [_t(), App.day, s, String(it.get("tr", ""))]); _snap.call_deferred("obj_" + s.left(24)))
	Audio.spoke.connect(func(t): P("SAY t=%d %s" % [_t(), str(t).left(80)]))
	t0 = Time.get_ticks_msec()
	await _setup()
	await run()
func _t() -> int: return (Time.get_ticks_msec() - t0) / 1000
func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	nshot += 1
	var f := OUT + "%s_%02d_%s.png" % [ev, nshot, n.replace(" ", "_").replace(".", "").replace("'", "").replace("!", "").replace("?", "")]
	get_viewport().get_texture().get_image().save_png(f)
	var cs = get_tree().current_scene
	var caps := get_tree().root.find_children("*Caption*", "", true, false).filter(func(c): return c is CanvasItem and c.is_visible_in_tree())
	P("SHOT %s scene=%s objs=%s caps=%d cam=%s" % [f, cs.name if cs else "-", JSON.stringify(Objectives.items.map(func(i): return i.en)), caps.size(), get_viewport().get_camera_3d().get_path() if get_viewport().get_camera_3d() else "none"])
func _setup(pre := false) -> void:
	var day := 6 if ev in ["d6", "d6b", "d6c", "places", "fix", "fixb", "trburst", "ui", "hosp"] else 7
	if ev == "d1": day = 1
	var st: Dictionary = {}
	for k in ["d3", "d4", "d5"]: st[k] = "done"
	st.merge({"day1_done": true, "day2": "done", "day2_work_done": true, "day2_hospital_done": true, "d2_couch_done": true, "d5_shop_done": true}, true)
	if ev in ["d6", "d6b"]: st["d6"] = "start"
	if ev == "d6c": st["d6"] = "home"; st["d6_storm_done"] = true
	if ev == "d7": st["d6"] = "done"; st["d7"] = "start"
	if ev == "d7b": st["d6"] = "done"; st["d7"] = "home"; st["d7_shop"] = true
	if ev in ["places", "fix", "fixb", "trburst", "ui", "hosp"]: st["d6"] = "done"; st["d7"] = "done"
	if ev == "d1": st = {}; WorldState.flags.erase("story_accident")
	if ev == "hosp": day = 1; st.erase("day1_done"); st.erase("day2_hospital_done"); WorldState.flags.erase("story_accident")
	if ev == "hosp2": day = 2; st.erase("day2_hospital_done"); st["day2"] = "work"
	var sv: Dictionary = App.load_save(); var state: Dictionary = (sv.get("state", {}) if sv.get("state", {}) is Dictionary else {}).duplicate()
	state["family"] = [{"role": "mother", "name": "Ayse", "skin": 1, "hair": 0, "hcol": 1, "cloth": 0},
		{"role": "father", "name": "Mehmet", "skin": 2, "hair": 2, "hcol": 0, "cloth": 1},
		{"role": "sister", "name": "Elif", "skin": 1, "hair": 2, "hcol": 2, "cloth": 3, "child": true}, {"role": "dog", "name": "Karabas", "col": 0}]
	state.merge({"created": true, "job": "doctor", "lesson_done": true, "calendar_seen": true, "has_phone": true, "name": "Yasin"}, true)
	WorldState.day = day; App.day = day
	App.patch_save({"story": st, "day": day, "state": state, "family_breakfast": true, "has_phone": true})
	if pre: return
	await OwLink.enter("bedroom", "")
	await w(1.0)
	var b = get_tree().current_scene
	if b and b.get("S") is Dictionary:
		for k in state: if b.S.has(k): b.S[k] = state[k]
		b.S.created = true; b.hero.set_mannequin(false); b._apply_character()
		P("HERO real=%s gender=%s" % [str(b.S.created), str(b.S.get("gender"))])
	await w(1.0)
	if ev == "d7b": await OwLink.enter("livingroom", "bedroom"); await w(1.0); load("res://scripts/story/day4_routine.gd").start(get_tree())
	if ev == "d6c": await OwLink.enter("livingroom", "bedroom"); await w(1.0); Day56Routine.attach(get_tree())
	if ev in ["d6", "d6b"]: load("res://scripts/story/day5_routine.gd").start(get_tree())
	if ev == "d7": load("res://scripts/story/day4_routine.gd").start(get_tree())
func _kind() -> String:
	var cs = get_tree().current_scene
	if cs == null: return ""
	var p := String(cs.scene_file_path)
	if p.ends_with("main.tscn"): return "bedroom"
	if p.ends_with("bathroom.tscn"): return "bathroom"
	if p.ends_with("livingroom.tscn"): return "living"
	if OwLink.inst and OwLink.inst.live_id != "": return OwLink.inst.live_id
	return "street"
func _verb(s: Node, id: String, key: String) -> bool:
	if not s.has_method("verbs"): return false
	for v in s.verbs(id):
		if v[2] == key: s.do_verb(id, v); return true
	return false
func _press() -> void:
	var r := get_tree().root
	var box := r.find_child("D56Choice", true, false)
	if box:
		for b in box.find_children("D56Opt*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and not b.disabled and bool(b.get_meta("ok", false)): await _snap("choice"); b.pressed.emit(); return
	for pn in r.find_children("D4*", "", true, false):
		if pn is Control and (pn as Control).is_visible_in_tree():
			for b in pn.find_children("*", "Button", true, false):
				if b.is_visible_in_tree() and not b.disabled:
					if randi() % 4 == 0: await _snap("d4panel")
					b.pressed.emit(); return
	for i in 3:
		var o := r.find_child("Opt%d" % i, true, false) as Button
		if o and o.is_visible_in_tree() and not o.disabled:
			if randi() % 6 == 0: await _snap("test_q")
			o.pressed.emit(); return
	for nm in ["ScoreContinue", "Continue", "ContinueBtn", "Next"]:
		var c := r.find_child(nm, true, false) as Button
		if c and c.is_visible_in_tree() and not c.disabled: await _snap("btn_" + nm); c.pressed.emit(); return
func run() -> void:
	if ev == "places": await places(); get_tree().quit(); return
	if ev == "fix": await fix(); get_tree().quit(); return
	if ev == "fixb": await fixb(); get_tree().quit(); return
	if ev == "trburst": await trburst(); get_tree().quit(); return
	if ev == "d1": await d1(); get_tree().quit(); return
	if ev == "ui": await ui33(); get_tree().quit(); return
	if ev == "hosp": await hosp33(); get_tree().quit(); return
	if ev == "hosp2": await hosp33(true); get_tree().quit(); return
	var stuck := 0
	var limit := 3000
	while _t() < limit:
		await w(0.5)
		await _press()
		var s = get_tree().current_scene
		if s == null: continue
		var k := _kind()
		var o: String = String(Objectives.items[0].en) if Objectives.items.size() >= 1 else ""
		if _t() % 30 == 0: P("DIAG t=%d k=%s mode=%s obj=%s d6=%s d7=%s day=%d speaking=%s" % [_t(), k, str(s.get("mode")), o, Day56.stage(6), str(App.load_save().get("story", {}).get("d7", "")), App.day, Audio.is_speaking()]); await _snap("diag_" + k)
		if ev in ["d6", "d6b", "d6c"] and Day56.stage(6) == "done" and App.day >= 7: await w(10.0); await _snap("end"); break
		if ev in ["d7", "d7b"] and str(App.load_save().get("story", {}).get("d7", "")) == "done": await w(10.0); await _snap("end"); break
		if s.get("mode") != null and not String(s.mode) in ["play"]: continue
		if Audio.is_speaking(): continue
		var key := "%s|%s" % [k, o]
		if key == last_key: stuck += 1
		else: stuck = 0
		if key == last_key and stuck < 40: continue
		stuck = 0
		last_key = key
		match [k, o]:
			["bedroom", "Go to the bathroom."], ["livingroom", "Go to the bathroom."], ["living", "Go to the bathroom."]: await w(3.0); await _snap("pre_bath"); await OwLink.enter("bathroom", "bedroom" if k == "bedroom" else "livingroom")
			["bedroom", "Turn off the alarm."], ["bedroom", "Turn off the alarm clock."]: _verb(s, "alarm", "off")
			["bedroom", "Take a shower."], ["living", "Take a shower."]: await w(3.0); await _snap("pre_bath"); await OwLink.enter("bathroom", "bedroom" if k == "bedroom" else "livingroom")
			["bathroom", "Take a shower."]: _verb(s, "bath", "takeshower")
			["bathroom", "Wash your face and brush your teeth."]: _verb(s, "sink", "routine")
			["bathroom", "Go to the living room."], ["bedroom", "Go to the living room."]: await w(3.0); await _snap("pre_living"); await OwLink.enter("livingroom", "bathroom" if k == "bathroom" else "bedroom")
			["living", "Go outside."]: await w(3.0); await _snap("pre_out"); await OwLink.to_street("front"); await w(4.0); await _snap("street_arrive")
			["street", "Go to the bus stop."]:
				await w(3.0); await _snap("stop_obj")
				var sp: Vector3 = Transit.stops.stop_home.pos if Transit.stops.has("stop_home") else Vector3(9.5, 0, 14.7)
				var wp = OwLink.inst.world.player; wp.global_position = Vector3(sp.x + 1.5, wp.global_position.y, sp.z + 1.0)
				await w(2.0); await _snap("at_stop")
			["street", "Go inside."], ["street", "Go home."], ["street", "Go home and talk to my family."], ["street", "Go back home."]:
				await w(3.0); await _snap("home_obj"); App.came_from = "outside"; await OwLink.enter("livingroom", "street")
			["living", "Go to the shop."]: await w(3.0); await _snap("pre_out_shop"); await OwLink.to_street("front"); await w(5.0); await _snap("street_arrive_d7")
			["street", "Go to the shop."]:
				await w(3.0); await _snap("shop_obj"); await OwLink.enter("shop", "street"); await w(5.0); await _snap("shop_in")
			["shop", "Go outside."], ["shop", "Go home."]: await w(2.0); await OwLink.to_street("shop"); await w(3.0); await _snap("shop_out")
			["living", "Talk to your family."]:
				P("hero global=%s local=%s SOFA_X=%s" % [str(s.hero.global_position), str(s.to_local(s.hero.global_position)), str(s.SOFA_X)])
				var seat: String = s._free_sofa_seat(); s.mode = "busy"; await s.walk_to(s.sit_spot(seat), s.SEATS[seat].yaw); await s.sit_down(s.hero, seat, true); s.S.seat = seat
			["living", "Go to bed."], ["bathroom", "Go to bed."]: await w(3.0); await _snap("pre_bed"); await OwLink.enter("bedroom", "livingroom" if k == "living" else "bathroom")
			_:
				P("UNHANDLED t=%d k=%s o=%s" % [_t(), k, o]); await _snap("unhandled_" + k)
				if s.has_method("qa_use"):
					for id in ["counter", "pay", "talk", "woman", "bed"]: s.qa_use(id)
	P("END t=%d d6=%s d7=%s day=%d" % [_t(), Day56.stage(6), str(App.load_save().get("story", {}).get("d7", "")), App.day])
	P("OBJECTIVES " + JSON.stringify(objs))
	get_tree().quit()
func places() -> void:
	await OwLink.enter("livingroom", "bedroom"); await w(5.0); await _snap("living")
	P("to_street"); OwLink.to_street("front"); await w(12.0); P("on street"); await w(5.0); await _snap("street_front")
	var wp = OwLink.inst.world.player
	for d in ["cafe", "shop"]:
		P("place_at " + d); wp.place_at(d); await w(4.0); await _snap("street_at_" + d)
		OwLink.enter(d, "street"); await w(8.0); await _snap(d + "_in")
		var c = get_tree().current_scene
		if c and c.has_method("qa_use"): c.qa_use("counter"); await w(10.0); await _snap(d + "_counter")
		OwLink.to_street(d); await w(8.0); await _snap(d + "_out")
	for id in ["hospital", "hospital_day2", "child_drive_stop"]:
		OwLink.enter(id, ""); await w(12.0); await _snap(id + "_a"); await w(15.0); await _snap(id + "_b")
	# travel cards
	OwLink.travel("street", "front"); await w(0.5); await _snap("travel_mid"); await w(3.0); await _snap("travel_front")
	var W = OwLink.inst.world
	P("WORLD doors=%s reserved=%s" % [str(W.doors.keys()) if W.get("doors") else "-", str(W.RESERVED) if W.get("RESERVED") else "-"])
	for k in ["work", "school", "office"]:
		if W.get("doors") and W.doors.has(k): wp.place_at(k); await w(4.0); await _snap("door_" + k)

## ---------------------------------------------------------------- fix33 (black) verification (world.tscn, real OwLink)
func _where(tag: String) -> void:
	var W = OwLink.inst.world; var wp = W.player
	var c3 := get_viewport().get_camera_3d()
	P("WHERE %s pos=%s yaw=%.2f region=%s live=%s cur=%s cam=%s" % [tag, str(wp.global_position), wp.hero.global_rotation.y, W.region_at(wp.global_position), OwLink.inst.live_id,
		get_tree().current_scene.name if get_tree().current_scene else "-", c3.get_path() if c3 else "none"])
func _fade_a() -> float: return (Game._fade as ColorRect).color.a
func _shc() -> void:
	var sc = get_tree().root.get_node_or_null("ShoulderCam")
	if sc and sc.has_method("snap"): sc.snap()
func _hintdbg(tag: String) -> void:
	var W = OwLink.inst.world; var live = OwLink.inst.live
	var h3 = live.get("hand3d") if live else null
	var c3 := get_viewport().get_camera_3d()
	if h3: P("HINT %s h3vis=%s layers=%d behind=%s sp=%s 2d=%s" % [tag, str(h3.is_visible_in_tree()), h3.layers, str(c3.is_position_behind(h3.global_position)), str(c3.unproject_position(h3.global_position)), str(W._hint.visible) if W.get("_hint") else "none"])
func fix() -> void:
	var W = OwLink.inst.world; var wp = W.player
	# H: ceilings + tap hint (bedroom / living room)
	var b = get_tree().current_scene
	if b.has_method("walk_to"): b.mode = "busy"; await b.walk_to(Vector3(0.5, 0, 0.8), PI); b.mode = "play"
	_shc(); await w(2.5); await _snap("H_bedroom"); _where("bedroom"); _hintdbg("bedroom")
	for id in ["alarm", "wardrobe", "desk", "bed", "window"]:
		if b.get("OBJ") is Dictionary and b.OBJ.has(id):
			b.mode = "busy"; await b.walk_to(b.OBJ[id].spot, b.OBJ[id].yaw); b.mode = "play"; await w(2.0); _hintdbg(id); await _snap("H_bed_hint_" + id)
	await OwLink.enter("livingroom", "bedroom"); await w(5.0)
	var lv = get_tree().current_scene
	for id in ["tv", "sofa", "table", "coat", "door"]:
		if lv.get("OBJ") is Dictionary and lv.OBJ.has(id):
			lv.mode = "busy"; await lv.walk_to(lv.OBJ[id].spot, lv.OBJ[id].yaw); lv.mode = "play"; await w(2.0); _hintdbg(id); await _snap("H_living_hint_" + id)
	# C + B: trip home (mid-trip colour, arrival)
	OwLink.travel("street", "front")
	await w(0.5); P("FADE mid a=%.2f col=%s" % [_fade_a(), str((Game._fade as ColorRect).color)]); await _snap("C_travel_mid")
	await w(3.0); await _snap("B_travel_front"); _where("after_travel_front")
	P("OBJS " + JSON.stringify(Objectives.items.map(func(i): return i.en)))
	await w(4.0); _where("after_travel_front_4s"); await _snap("B_travel_front_4s")
	# F: café door + spot
	wp.place_at("cafe"); await w(3.0); _where("place_at_cafe"); await _snap("F_cafe_door")
	W.doors["cafe"].open(); await w(1.5); await _snap("F_cafe_door_open"); W.doors["cafe"].close(); await w(1.0)
	# C: car trip to the café door from elsewhere (StoryNav-style travel)
	wp.place_at("front"); await w(1.0)
	OwLink.travel("street", "cafe"); await w(0.3); await _snap("C_travel_cafe_mid"); await w(3.0); await _snap("C_travel_cafe_after"); _where("travel_cafe")
	# E: shop teach card hidden after leaving
	wp.place_at("shop"); await w(1.0)
	await OwLink.enter("shop", "street"); await w(8.0)
	var c = OwLink.inst.live
	if c and c.has_method("qa_use"): c.qa_use("counter"); await w(10.0)
	var cards = c.find_children("*", "CanvasLayer", true, false).filter(func(l): return l.visible)
	P("SHOP visible layers=%s" % str(cards.map(func(l): return l.name))); await _snap("E_shop_card")
	await OwLink.to_street("shop"); await w(3.0)
	cards = c.find_children("*", "CanvasLayer", true, false).filter(func(l): return l.visible)
	P("SHOP after leave visible layers=%s" % str(cards.map(func(l): return l.name))); await _snap("E_after_shop"); _where("after_shop")
	await OwLink.enter("shop", "street"); await w(4.0)
	cards = c.find_children("*", "CanvasLayer", true, false).filter(func(l): return l.visible)
	P("SHOP re-enter visible layers=%s" % str(cards.map(func(l): return l.name))); await _snap("E_shop_again")
	await OwLink.to_street("shop"); await w(3.0)
	# G: hospital entry (day 6: 'already seen' -> trip home) then camera in the bedroom
	OwLink.enter("hospital", ""); await w(6.0); await _snap("G_hospital_a"); await w(12.0); _where("after_hospital"); _hintdbg("after_hospital"); await _snap("G_after_hospital")
	await OwLink.travel("street", "front"); await w(2.0)
	# I: fences
	var fz = W.fences
	P("FENCE day=%d visible=%s" % [WorldState.day, str(fz.visible)])
	var lo: Vector3 = W.grid.cell_center(W.grid.bounds_min) - Vector3.ONE * W.grid.block_size * 0.5
	var hi: Vector3 = W.grid.cell_center(W.grid.bounds_max) + Vector3.ONE * W.grid.block_size * 0.5
	P("FENCE bounds lo=%s hi=%s" % [str(lo), str(hi)])
	# walk east along the home street toward the edge
	var hp: Vector3 = wp.global_position
	wp.global_position = Vector3(hi.x - 8.0, wp.global_position.y, hp.z)
	await w(1.0)
	var t := 0.0
	while t < 6.0:
		if wp.has_method("set_stick"): wp.set_stick(Vector2(1, 0))
		wp.velocity = Vector3(4, 0, 0) if "velocity" in wp else Vector3.ZERO
		if wp is CharacterBody3D: wp.move_and_slide()
		await get_tree().physics_frame; t += get_physics_process_delta_time()
	P("FENCE pushed east: x=%.2f (fence at %.2f)" % [wp.global_position.x, hi.x - 1.5]); await _snap("I_fence_day6")
	WorldState.day = 8; App.day = 8; await w(1.0)
	P("FENCE day=8 visible=%s colliders_disabled=%s" % [str(fz.visible), str(fz.find_children("*", "CollisionShape3D", true, false).all(func(x): return x.disabled))]); await _snap("I_fence_day8")
	WorldState.day = 6; App.day = 6; await w(1.0); P("FENCE back day6 visible=%s" % str(fz.visible))
	# H: street props / NPCs upright
	var bad := 0; var n := 0
	for g in W.find_children("*", "Node3D", true, false):
		var nm := String(g.name).to_lower()
		if not (g is DemoCharacter or "lamp" in nm or "traffic" in nm or "post" in nm or "pole" in nm): continue
		if g.get_parent() is DemoCharacter: continue
		n += 1
		var up: Vector3 = (g as Node3D).global_transform.basis.y.normalized()
		var tilt := rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1, 1)))
		if tilt > 10.0 and (g as Node3D).is_visible_in_tree(): bad += 1; P("TILT %s %.1f deg pos=%s" % [str(g.get_path()), tilt, str((g as Node3D).global_position)])
	P("TILT checked=%d bad=%d" % [n, bad])
	# D: a freed occluder in world_culling._occ (as when the bus is freed) is dropped silently
	for wc in W.get_children():
		if "_occ" in wc and wc.get("_occ") is Array:
			var oi := OccluderInstance3D.new(); W.add_child(oi); wc._occ.append([oi, AABB(Vector3.ZERO, Vector3.ONE)]); var n0: int = wc._occ.size()
			oi.free(); await w(1.5)
			P("CULL freed occluder: before=%d after=%d (dropped=%s)" % [n0, wc._occ.size(), str(wc._occ.size() < n0)])
func d1() -> void:
	await OwLink.enter("livingroom", "bedroom"); await w(3.0)
	P("D1 should_run=%s" % str(load("res://scripts/story/story_accident.gd").should_run()))
	await OwLink.to_street("front"); await w(1.0); await _snap("A_d1_street"); _where("d1_street")
	for i in 12:
		await w(5.0); P("D1 t=%d objs=%s" % [i * 5, JSON.stringify(Objectives.items.map(func(it): return it.en))])
		if i % 3 == 1: await _snap("A_d1_%02d" % i)

func fixb() -> void:
	var W = OwLink.inst.world; var wp = W.player
	# H: tap hint badge in bedroom + bathroom
	var b = get_tree().current_scene
	for id in ["alarm", "desk", "window"]:
		if b.get("OBJ") is Dictionary and b.OBJ.has(id):
			b.mode = "busy"; await b.walk_to(b.OBJ[id].spot, b.OBJ[id].yaw); b.mode = "play"; await w(2.0); _hintdbg(id); await _snap("H2_bed_hint_" + id)
	await OwLink.enter("bathroom", "bedroom"); await w(6.0)
	var bt = get_tree().current_scene; _where("bathroom")
	for id in ["sink", "bath", "towel", "toilet", "mirror"]:
		if bt.get("OBJ") is Dictionary and bt.OBJ.has(id):
			bt.mode = "busy"; await bt.walk_to(bt.OBJ[id].spot, bt.OBJ[id].yaw); bt.mode = "play"; await w(2.0); _hintdbg(id); await _snap("H2_bath_hint_" + id)
	# E: the shop teach card, hero really inside
	await OwLink.travel("street", "shop"); await w(1.0)
	var ab: AABB = W.regions["shop"]
	wp.global_position = Vector3(ab.get_center().x, wp.global_position.y, ab.get_center().z); await w(1.5)
	if OwLink.inst.live_id != "shop": await OwLink.enter("shop", "street")
	await w(8.0); _where("in_shop")
	var c = OwLink.inst.live
	if c and c.has_method("qa_use"): c.qa_use("counter")
	await w(14.0)
	var vis = func(): return c.find_children("*", "CanvasLayer", true, false).filter(func(l): return l.visible).map(func(l): return l.name)
	P("SHOP in visible layers=%s" % str(vis.call())); await _snap("E2_shop_card")
	await OwLink.to_street("shop"); await w(3.0); _where("after_shop")
	P("SHOP after leave visible layers=%s" % str(vis.call())); await _snap("E2_after_shop")
	await OwLink.travel("street", "front"); await w(3.0); await _snap("E2_home_front_no_card")
	wp.global_position = Vector3(ab.get_center().x, wp.global_position.y, ab.get_center().z); await w(2.0)
	if OwLink.inst.live_id != "shop": await OwLink.enter("shop", "street")
	await w(2.0); P("SHOP re-enter visible layers=%s" % str(vis.call())); await _snap("E2_shop_again")
	await OwLink.to_street("shop"); await w(2.0)
	# I: fence colliders: rays across each edge at several points (day 6 blocked, day 8 open)
	var lo: Vector3 = W.grid.cell_center(W.grid.bounds_min) - Vector3.ONE * W.grid.block_size * 0.5
	var hi: Vector3 = W.grid.cell_center(W.grid.bounds_max) + Vector3.ONE * W.grid.block_size * 0.5
	for day in [6, 8]:
		WorldState.day = day; App.day = day; await w(1.0); await get_tree().physics_frame
		var ss: PhysicsDirectSpaceState3D = W.get_world_3d().direct_space_state
		var hits := 0; var tot := 0; var gaps := []
		for f in [0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9]:
			var x := lerpf(lo.x, hi.x, f); var z := lerpf(lo.z, hi.z, f)
			for seg in [[Vector3(x, 0.8, lo.z + 5), Vector3(x, 0.8, lo.z - 2)], [Vector3(x, 0.8, hi.z - 5), Vector3(x, 0.8, hi.z + 2)], [Vector3(lo.x + 5, 0.8, z), Vector3(lo.x - 2, 0.8, z)], [Vector3(hi.x - 5, 0.8, z), Vector3(hi.x + 2, 0.8, z)]]:
				var q := PhysicsRayQueryParameters3D.create(seg[0], seg[1]); q.collision_mask = wp.collision_mask
				var r := ss.intersect_ray(q); tot += 1
				var fence_hit: bool = not r.is_empty() and W.fences.is_ancestor_of(r.collider)
				if fence_hit: hits += 1
				else: gaps.append(str(seg[1]))
		P("FENCE day=%d visible=%s rays=%d fence_hits=%d gaps=%s" % [day, str(W.fences.visible), tot, hits, str(gaps)])

## J: TR-off flashing check: per-frame monitor (TR label visibility + panel rect) and a burst of 8 shots 0.1 s apart
func _monitor(root: Control, secs: float) -> Dictionary:
	var last := ""; var changes := 0; var frames := 0; var t0m := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0m < int(secs * 1000) and is_instance_valid(root):
		await RenderingServer.frame_post_draw
		var sig := str(root.get_global_rect())
		for l in root.find_children("*", "Label", true, false):
			if Objectives.has_tr((l as Label).text) or l.has_meta("trg_orig"): sig += "|%s:%s" % [l.name, str(l.is_visible_in_tree())]
		for b in root.find_children("Opt*", "Button", true, false) + root.find_children("D56Opt*", "Button", true, false): sig += "|" + str((b as Control).get_global_rect())
		if last != "" and sig != last: changes += 1
		last = sig; frames += 1
	var trv := 0; var trn := 0
	if is_instance_valid(root):
		for l in root.find_children("*", "Label", true, false):
			if Objectives.has_tr(String(l.get_meta("trg_orig", (l as Label).text))): trn += 1; trv += int(l.is_visible_in_tree())
	return {"frames": frames, "changes": changes, "tr_labels": trn, "tr_visible": trv}
func _burst(tag: String) -> void:
	for i in 8:
		await _snap("%s_burst%d" % [tag, i]); await w(0.1)
func trburst() -> void:
	var tr_on := false
	for a in OS.get_cmdline_user_args(): if a == "--qa-tr=1": tr_on = true
	App._trf = 1 if tr_on else 0
	P("TR on=%s App.tr_on=%s" % [str(tr_on), str(App.tr_on())])
	var tag := "tr1" if tr_on else "tr0"
	await OwLink.enter("livingroom", "bedroom"); await w(4.0)
	var lr = get_tree().current_scene
	lr.mode = "busy"
	# 1) dialogue choice panel (Day56.choice)
	var d = load("res://scripts/story/day5_common.gd").new(); d.name = "QAChoice"; lr.add_child(d)
	d.choice({"prompt": "What do you say to the driver?", "prompt_tr": "Şoföre ne dersin?", "speak": "What do you say to the driver?",
		"opts": [{"en": "Can you help me, please?", "tr": "Bana yardım eder misiniz, lütfen?", "ok": true, "fb": "Good!", "fb_tr": "Güzel!"},
			{"en": "I am a bus.", "tr": "Ben bir otobüsüm.", "ok": false, "fb": "Not quite.", "fb_tr": "Tam değil."},
			{"en": "Goodbye, kitchen.", "tr": "Hoşça kal, mutfak.", "ok": false, "fb": "Not quite.", "fb_tr": "Tam değil."}]})
	await w(1.0)
	var box: Control = get_tree().root.find_child("D56Choice", true, false)
	var t1 := Time.get_ticks_msec()
	while box and Time.get_ticks_msec() - t1 < 16000 and (box.find_child("D56Opt0", true, false) as Button).disabled: await w(0.2)
	await w(0.6)
	if box:
		var m: Dictionary = await _monitor(box, 3.0); P("CHOICE %s monitor=%s" % [tag, str(m)])
		await _burst(tag + "_choice")
		for b in box.find_children("D56Opt*", "Button", true, false): if bool(b.get_meta("ok", false)): b.pressed.emit()
	await w(4.0)
	# 2) quiz screen (phone TestBank)
	await OwLink.enter("bedroom", "livingroom"); await w(3.0)
	var bd = get_tree().current_scene; bd.mode = "busy"
	var ph = bd.get("phone")
	load("res://scripts/story/test_bank.gd").run_test(bd, ph, 6, {"n": 3, "key": "QA_trburst"})
	await w(1.5)
	var t2 := Time.get_ticks_msec()
	var o0: Button = null
	while Time.get_ticks_msec() - t2 < 20000:
		o0 = ph.find_child("Opt0", true, false) as Button
		if o0 and not o0.disabled: break
		await w(0.2)
	await w(0.6)
	var m2: Dictionary = await _monitor(ph, 3.0); P("QUIZ %s monitor=%s" % [tag, str(m2)])
	await _burst(tag + "_quiz")

## ---------------------------------------------------------------- ui33: learning-screen right column + caption checks
func _caps_vis() -> Array:
	return get_tree().get_nodes_in_group("caption_box").filter(func(c): return c is CanvasItem and (c as CanvasItem).is_visible_in_tree()).map(func(c): return str(c.name))
func _trcol() -> String:
	var l := get_tree().get_nodes_in_group("tr_column").filter(func(c): return c is Label and (c as Label).is_visible_in_tree())
	return "%d %s" % [l.size(), str(l.map(func(c): return (c as Label).text.left(24)).slice(0, 6))]
func ui33() -> void:
	await OwLink.enter("livingroom", "bedroom"); await w(4.0)
	var lr = OwLink.inst.live; var ph = lr.room_phone.phone
	lr.mode = "busy"
	# 1/3: TestBank phone test (D6 + D4 share it)
	var TB = load("res://scripts/story/test_bank.gd")
	var t = TB.new(); var tdone := [false]
	(func(): await t.run(lr, ph, 6, {"n": 3, "key": "QA_ui33"}); tdone[0] = true).call()
	await w(1.5); await _snap("T1_test_note"); P("TEST caps=%s tr=%s" % [_caps_vis(), _trcol()])
	await w(9.0); await _snap("T2_test_q"); P("TEST caps=%s tr=%s" % [_caps_vis(), _trcol()])
	for k in 3:
		var row = ph.find_child("Options", true, false)
		if row: (row.get_child(1 if k == 0 else 0) as Button).disabled = false; (row.get_child(1 if k == 0 else 0) as Button).pressed.emit()
		await w(0.8); if k == 0: await _snap("T3_test_feedback")
		await w(8.0)
	await w(1.0); await _snap("T4_score"); P("SCORE caps=%s tr=%s" % [_caps_vis(), _trcol()])
	await w(1.5); await _snap("T5_score_tip"); P("SCORE2 caps=%s" % [_caps_vis()])
	var sc = ph.find_child("ScoreContinue", true, false)
	if sc: sc.pressed.emit()
	await w(2.0); ph.close(true); await w(1.5)
	# 2: Day56 choice panel (breakfast review shape: opts without TR)
	var dc = load("res://scripts/story/day5_common.gd").new(); get_tree().root.add_child(dc)
	var q: Dictionary = TB.questions(6)[0]
	var opts: Array = []
	for i in q.opts.size(): opts.append({"en": String(q.opts[i]), "tr": "", "ok": i == int(q.a), "fb": String(q.say), "fb_tr": String(q.tr)})
	(func(): await dc.choice({"prompt": String(q.q), "prompt_tr": "Doğru kelimeleri seç.  (%s)" % String(q.tr), "opts": opts, "speak": "Choose the right words.", "first_try": true})).call()
	await w(5.0); await _snap("C1_d56choice"); P("D56 tr=%s" % _trcol())
	for b in get_tree().root.find_children("D56Opt*", "Button", true, false):
		if bool(b.get_meta("ok")): b.disabled = false; b.pressed.emit()
	await w(6.0)
	# D4Choose + scramble
	var D4 = load("res://scripts/story/day4_talk.gd")
	(func(): await D4.choose(lr, TB.questions(4)[0])).call()
	await w(2.5); await _snap("C2_d4choose"); P("D4C tr=%s" % _trcol())
	for n in get_tree().root.find_children("D4Choose", "", true, false): n.get_parent().queue_free()
	await w(1.0)
	(func(): await D4.puzzle(lr, "I am very happy today.", "", false)).call()
	await w(2.5); await _snap("C3_scramble"); P("SCR tr=%s caps=%s" % [_trcol(), _caps_vis()])
	for n in get_tree().root.find_children("D4Puzzle", "", true, false): n.get_parent().queue_free()
	await w(1.0)
	# 7: glass probe around the home lot / front yard
	var W = OwLink.inst.world
	var all: Array = []; _walk_all(W, all)
	for c in all:
		if not (c is GeometryInstance3D) or not (c as Node3D).is_visible_in_tree(): continue
		var m = c.material_override
		if m == null and c is MeshInstance3D and c.mesh and c.mesh.get_surface_count() > 0: m = c.get_active_material(0)
		if m is StandardMaterial3D and (m as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			var ab: AABB = (c as VisualInstance3D).get_aabb(); var gp: Vector3 = (c as Node3D).global_position
			if gp.distance_to(Vector3(0, 0, 5)) < 25.0: P("GLASS %s pos=%s size=%s col=%s" % [str(c.get_path()).right(110), str(gp), str(ab.size), str(m.albedo_color)])
	# 8: cafe NPC poses
	await OwLink.to_street("front"); await w(4.0)
	var wp = W.player; wp.place_at("cafe"); await w(4.0); await _snap("N1_cafe_street")
	var cafe = W.places.get("cafe") if W.get("places") is Dictionary else null
	if cafe and cafe.get("npcs") is Dictionary:
		for k in cafe.npcs: var ch = cafe.npcs[k]; P("CAFE NPC %s anim=%s playing=%s pos=%.2f" % [k, ch.player.current_animation, str(ch.player.is_playing()), ch.player.current_animation_position])
	OwLink.enter("cafe", "street"); await w(8.0); await _snap("N2_cafe_in")
	cafe = OwLink.inst.live
	if cafe and cafe.get("npcs") is Dictionary:
		for k in cafe.npcs: var ch = cafe.npcs[k]; P("CAFE2 NPC %s anim=%s playing=%s" % [k, ch.player.current_animation, str(ch.player.is_playing())])
func _walk_all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _walk_all(c, out)
func hosp33(only2 := false) -> void:
	if not only2: await _hosp1()
	OwLink.enter("hospital_day2", ""); await w(6.0)
	for i in 12:
		await w(3.0); P("HOSP2 t=%d caps=%s tr=%s" % [i * 3, _caps_vis(), _trcol()])
		if i in [4, 7, 10]: await _snap("H2_hosp2_%02d" % i)
func _hosp1() -> void:
	OwLink.enter("hospital", ""); await w(6.0)
	for i in 14:
		await w(3.0); P("HOSP t=%d caps=%s tr=%s" % [i * 3, _caps_vis(), _trcol()])
		if i in [3, 5, 7, 10]: await _snap("H1_hosp_%02d" % i)
