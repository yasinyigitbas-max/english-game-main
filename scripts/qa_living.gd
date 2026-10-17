## Automated QA for the living room: runs every interaction, checks states + seated poses, writes screens/*.png and qa.log.
## xvfb-run -a godot --path . --rendering-driver opengl3 -- --qa
extends Node
var m
var log := []
var fails := 0
var peaks := []

func ok(c: bool, t: String) -> void:
	log.append(("PASS " if c else "FAIL ") + t); print(log[-1])
	if not c: fails += 1

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screens/" + n + ".png"))

func w(t: float) -> void:
	await get_tree().create_timer(t, true).timeout

func bone(n: String, ch = null) -> Vector3:
	var c: DemoCharacter = ch if ch else m.hero
	var sk: Skeleton3D = c.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin

func feet_y(ch = null) -> float:
	return minf(bone("Foot.L", ch).y, bone("Foot.R", ch).y)

func side_shot(n: String, from: Vector3, at: Vector3) -> void:
	m.cam_override = true; m.cam.position = from; m.cam.look_at(at, Vector3.UP)
	await w(0.05); await shot(n); m.cam_override = false

## run one verb by key on an object, wait until it is finished; check the player stood at the object's spot at the peak
func act(id: String, key: String, peak_shot := "") -> bool:
	var vs: Array = m.verbs(id)
	var v = null
	for x in vs:
		if x[2] == key: v = x
	if v == null:
		ok(false, "%s/%s available (have %s)" % [id, key, vs.map(func(a): return a[2])]); return false
	var seated: bool = m.mode == "seated"
	m.do_verb(id, v)
	var st := {"got": false, "at": Vector3.INF}     # lambdas capture locals by value: use a dictionary
	var t0 := Time.get_ticks_msec()
	var cb := func(_i): st.got = true; st.at = m.hero.position
	m.action_peak.connect(cb)
	while m.mode == "busy" and Time.get_ticks_msec() - t0 < 200000:
		if st.got and peak_shot != "":
			await w(0.25); await shot(peak_shot); peak_shot = ""
		await w(0.05)
	m.action_peak.disconnect(cb)
	var at_peak: Vector3 = st.at
	if not seated and key != "sit" and key != "go" and m.OBJ.has(id):
		var sp: Vector3 = m.OBJ[id].spot
		if at_peak != Vector3.INF: ok(Vector2(at_peak.x - sp.x, at_peak.z - sp.z).length() < 0.12, "%s/%s: player in front of the object (%.2f m)" % [id, key, Vector2(at_peak.x - sp.x, at_peak.z - sp.z).length()])
	ok(m.mode != "busy", "%s/%s finished (mode %s)" % [id, key, m.mode])
	return true

func check_seated(tag: String, ch = null) -> void:
	var c: DemoCharacter = ch if ch else m.hero
	var seat: String = c.get_meta("seat", "")
	var s: Dictionary = m.SEATS[seat]
	var h := bone("Hips", c)
	ok(absf(h.y - (s.top + m.HIP_ABOVE_SEAT * c.model.scale.y)) < 0.04, "%s: hips on the seat (hips y %.3f, seat top %.2f)" % [tag, h.y, s.top])
	ok(Vector2(h.x - s.hips.x, h.z - s.hips.z).length() < 0.06, "%s: hips centred on the seat (%.3f m off)" % [tag, Vector2(h.x - s.hips.x, h.z - s.hips.z).length()])
	var fy := feet_y(c)
	if c.child: ok(fy > -0.02 and fy < s.top - 0.1, "%s: child's feet hang below the seat, not in the floor (min foot y %.3f)" % [tag, fy])
	else: ok(fy > -0.02 and fy < 0.16, "%s: feet on the floor (min foot bone y %.3f)" % [tag, fy])
	var knee := (bone("LowerLeg.L", c) + bone("LowerLeg.R", c)) * 0.5
	ok(knee.y > s.top - 0.02, "%s: knees above the seat front (%.2f)" % [tag, knee.y])

func run(main) -> void:
	m = main
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screens"))
	m.S.tr = true
	await w(1.2)
	m.caption("Welcome to the living room!"); m._advance()
	await w(0.8)
	await shot("01_overview")
	if "--quick" in OS.get_cmdline_user_args():
		var ex := []
		m.exit_requested.connect(func(t): ex.append(t))
		await extra(ex); print("QA QUICK DONE fails=", fails); get_tree().quit(); return
	ok(m.mission == "Turn on the TV.", "first mission is 'Turn on the TV.'")
	ok(m.OBJ.size() >= 12, "%d interactive objects" % m.OBJ.size())
	ok(m.get_node("SeatMarkers").get_child_count() >= 6, "seat + door markers present")
	# ---- TV at the unit
	await act("tv", "power", "03a_tv_on_standing")
	ok(m.S.tv == "on" and m.N.tv_light.visible, "TV on (screen + glow)")
	ok(m.mission == "Sit on the sofa.", "mission advanced to 'Sit on the sofa.'")
	await act("tv", "channel"); ok(m.S.channel == 1, "channel 2")
	await act("tv", "drawer"); ok(m.S.drawer == "open", "TV drawer open")
	await shot("09_tv_drawer_open")
	await act("tv", "drawer"); ok(m.S.drawer == "closed", "TV drawer closed")
	# ---- coffee table
	await act("coffee", "remote"); ok(m.S.remote == "hand" and m.remote_in_hand != null, "remote in hand")
	await act("coffee", "channel"); ok(m.S.channel == 2, "channel 3 with the remote")
	await act("coffee", "tea", "10_drink_tea"); ok(m.N.mug.visible and m.hero.held == null, "mug back on the table")
	await act("coffee", "remote"); ok(m.S.remote == "table" and m.remote_in_hand == null, "remote back on the table")
	# ---- sofa
	await act("sofa", "cushions"); ok(m.S.cushions == "tidy", "cushions tidy")
	await act("sofa", "sit")
	ok(m.mode == "seated" and m.S.seat == "sofa_middle", "seated on the sofa")
	await w(0.6)
	check_seated("sofa")
	await shot("02_sofa_sit")
	await side_shot("02b_sofa_sit_side", Vector3(0.9, 1.25, 1.9), m.hero.position + Vector3(0, 0.6, 0))
	await side_shot("02c_sofa_sit_front", Vector3(0.5, 1.4, 0.0), m.hero.position + Vector3(0, 0.55, 0))
	await act("sofa", "tv"); ok(m.S.tv == "off", "TV off from the sofa")
	await act("sofa", "tv"); ok(m.S.tv == "on", "TV on from the sofa (remote)")
	await act("sofa", "channel"); ok(m.S.channel == 3, "channel 4 from the sofa")
	await act("sofa", "channel"); ok(m.S.channel == 0, "channel 1 from the sofa")
	await act("sofa", "watch", "03_tv_on")
	await act("sofa", "blanket"); ok(m.S.blanket == "on" and m.N.blanket_open.visible, "blanket on the legs")
	await w(0.5)
	await side_shot("11_blanket", Vector3(0.9, 1.3, 1.6), m.hero.position + Vector3(0, 0.5, 0))
	await act("sofa", "stand")
	ok(m.mode == "play" and m.S.seat == "" and m.S.blanket == "folded", "stood up, blanket folded back")
	ok(absf(m.hero.position.y) < 0.001 and feet_y() < 0.12, "standing on the floor after the sofa (feet %.3f)" % feet_y())
	ok(m.hero.position.distance_to(m.sit_spot("sofa_middle")) < 0.35, "ends in front of the sofa (%.2f m)" % m.hero.position.distance_to(m.sit_spot("sofa_middle")))
	# ---- books
	await act("books", "take"); ok(m.S.book == "hand" and m.hero.held != null, "book in the hand")
	await act("books", "read", "05a_reading_standing")
	await act("sofa", "sit")
	ok(m.hero.held != null, "book stays in the hand while sitting")
	await act("sofa", "read", "05_reading")
	ok(m.S.read and m.mission != "Read a book.", "reading done")
	await act("sofa", "stand")
	ok(m.hero.held != null, "book still in the hand after standing up")
	await act("books", "back"); ok(m.S.book == "shelf" and m.hero.held == null, "book back on the shelf")
	# ---- armchair + floor lamp from the chair
	await act("armchair", "sit")
	await w(0.5)
	check_seated("armchair")
	await act("armchair", "lamp"); ok(m.S.floorlamp == "on", "floor lamp on from the armchair")
	await shot("12_armchair")
	await side_shot("12b_armchair_close", Vector3(-0.4, 1.4, -0.6), m.hero.position + Vector3(0, 0.55, 0))
	await act("armchair", "stand"); ok(absf(m.hero.position.y) < 0.001, "stood up from the armchair")
	await act("floorlamp", "toggle"); ok(m.S.floorlamp == "off", "floor lamp off")
	await act("floorlamp", "toggle"); ok(m.S.floorlamp == "on", "floor lamp on")
	# ---- plants, photos
	await act("plant", "water", "13_water_plant"); ok(m.S.plant == "watered", "big plant watered")
	await act("plant2", "water"); ok(m.S.plant2 == "watered", "small plant watered")
	await act("plant", "look")
	await act("photos", "look", "14_photos")
	await act("photos", "straight"); ok(m.S.picture == "straight", "picture straight")
	# ---- window + curtains
	await act("window", "window"); ok(m.S.window == "open", "window open")
	await act("window", "look")
	await act("window", "window"); ok(m.S.window == "closed", "window closed")
	await act("window", "curtains"); ok(m.S.curtains == "closed" and m.sun.light_energy == 0.0, "curtains closed, evening")
	# ---- ceiling light via the switch
	await act("switch", "toggle"); ok(m.S.ceiling == "off", "ceiling light off")
	await act("sofa", "sit")
	await w(0.8)
	await shot("04_evening_lights_off")
	await act("sofa", "stand")
	await act("switch", "toggle"); ok(m.S.ceiling == "on", "ceiling light on")
	await act("window", "curtains"); ok(m.S.curtains == "open", "curtains open")
	# ---- north doors: smooth hinge + exit signals (bedroom / bathroom)
	var exits := []
	m.exit_requested.connect(func(t): exits.append(t))
	for dk in ["door_bed", "door_bath"]:   # house.17: one chip opens the door and goes through
		ok(m.verbs(dk).size() == 1 and m.verbs(dk)[0][2] == "go", "%s: one chip %s" % [dk, str(m.verbs(dk))])
		await act(dk, "go")
		ok(m.S[dk] == "open" and absf(m.N[dk].rotation.y - deg_to_rad(-82.0)) < 0.02, "%s opened by the go chip (%.1f deg)" % [dk, rad_to_deg(m.N[dk].rotation.y)])
		if dk == "door_bed": await shot("15_doors_open")
	ok(exits == ["bedroom", "bathroom"], "exit_requested emitted %s" % [exits])
	await extra(exits)
	ok(m.mission == "Explore the living room.", "all missions done (mission: %s)" % m.mission)
	# ---- family members on the named seats
	var mum := DemoCharacter.new(); m.add_child(mum); mum.setup("women"); mum.skin = 1; mum._refresh()
	m.seat_family_member(mum, "sofa_left")
	var kid := DemoCharacter.new(); m.add_child(kid); kid.child = true; kid.setup("men"); kid.set_child(true)
	m.seat_family_member(kid, "armchair")
	await w(0.3)
	check_seated("family sofa_left", mum); check_seated("family armchair (child)", kid)
	await act("sofa", "sit"); ok(m.S.seat == "sofa_right" or m.S.seat == "sofa_middle", "player takes a free seat (%s)" % m.S.seat)
	await w(0.6)
	check_seated("player next to family")
	await shot("06_family_on_seats")
	await side_shot("06b_family_close", Vector3(0.6, 1.5, 1.3), Vector3(2.6, 0.6, 0.0))
	await act("sofa", "stand")
	# ---- chips (scroll container) + missions list swipe
	m.hero.position = m.OBJ.tv.spot; m.hero.rotation.y = m.OBJ.tv.yaw; await w(0.3)
	m.on_action(); await w(0.4)
	ok(m.chips.get_child_count() == 4, "TV chips shown (%d)" % m.chips.get_child_count())
	await shot("08_chips")
	m._hide_chips()
	m.open_tasks(); await w(0.4)
	await shot("07_missions_list")
	var sc: ScrollContainer = m.tasks_panel.find_child("TaskScroll", true, false)
	var before := sc.scroll_vertical
	var c := sc.get_global_rect().get_center()
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; e.position = c; e.global_position = c; Input.parse_input_event(e)
	for i in 10:
		await get_tree().process_frame
		var mv := InputEventMouseMotion.new(); mv.button_mask = MOUSE_BUTTON_MASK_LEFT; mv.position = c - Vector2(0, 22 * (i + 1)); mv.global_position = mv.position; mv.relative = Vector2(0, -22); Input.parse_input_event(mv)
	var u := InputEventMouseButton.new(); u.button_index = MOUSE_BUTTON_LEFT; u.pressed = false; u.position = c - Vector2(0, 220); u.global_position = u.position; Input.parse_input_event(u)
	await w(0.5)
	ok(sc.scroll_vertical > before, "missions list scrolls by swipe (%d -> %d)" % [before, sc.scroll_vertical])
	await shot("07b_missions_list_swiped")
	m.tasks_panel.visible = false
	# ---- voice coverage
	var missing := []
	for k in m.TR: if not Audio.has_clip(k) and not k.begins_with("I'm in the"): missing.append(k)   # house.17: room captions are silent
	ok(missing.is_empty(), "Piper clip for every line (%d lines, missing %s)" % [m.TR.size(), missing])
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.store_line("TOTAL %d checks, %d failed" % [log.size(), fails])
	print("QA DONE fails=", fails); get_tree().quit()

func extra(exits: Array) -> void:
	# ---- front door: lock / unlock / open / go out (coming soon) / close, shoe rack
	await act("entry", "shoes", "16_put_on_shoes"); ok(m.S.shoes == "on", "shoes on")
	await act("entry", "keys"); ok(m.S.keys == "pocket", "keys taken")
	await act("front", "lock", "17_unlock_door"); ok(m.S.lock == "unlocked", "front door unlocked")
	await act("front", "toggle"); ok(m.S.front == "open" and absf(m.N.front.rotation.y - deg_to_rad(82.0)) < 0.02, "front door open")
	await shot("18_front_door_open")
	await act("front", "go"); ok(exits.has("outside"), "exit_requested('outside') emitted")
	await act("front", "toggle"); ok(m.S.front == "closed", "front door closed")
	await act("front", "lock"); ok(m.S.lock == "locked", "front door locked")
	await act("entry", "keys"); await act("entry", "shoes"); ok(m.S.keys == "hook" and m.S.shoes == "rack", "keys + shoes back")
	ok(m.mode == "play", "no crash going outside")
	# ---- family breakfast hook (sample save.json family data)
	var fam := [{"role": "mother", "name": "Ayse", "skin": 1, "hair": 0, "hcol": 1, "cloth": 0},
		{"role": "father", "name": "Mehmet", "skin": 2, "hair": 2, "hcol": 0, "cloth": 1},
		{"role": "sister", "name": "Elif", "skin": 1, "hair": 2, "hcol": 2, "cloth": 3, "child": true},
		{"role": "grandmother", "name": "Fatma", "skin": 0, "hair": 1, "hcol": 4, "cloth": 4},
		{"role": "brother", "name": "Can", "skin": 1, "hair": 1, "hcol": 1, "cloth": 2, "child": true},
		{"role": "dog", "name": "Karabas", "col": 0}, {"role": "cat", "name": "Tekir", "col": 3}]
	var got: Array = m.spawn_family_breakfast(fam)
	ok(got.size() == 6, "breakfast spawned 6 members (max 6) -> %d" % got.size())
	await w(1.5)
	for e in got:
		if e.seat != "": check_seated("breakfast " + e.data.role, e.node)
	await shot("19_family_breakfast")
	await side_shot("19b_breakfast_close", Vector3(5.6, 1.7, 3.0), Vector3(5.6, 0.7, 0.9))
	await side_shot("19c_breakfast_side", Vector3(3.6, 1.5, 0.9), Vector3(5.8, 0.6, 0.9))
	m.spawn_family_breakfast(fam.slice(3, 7) + [{"role": "fish", "col": 4}, {"role": "bird", "col": 3}])
	await w(1.0)
	await side_shot("19d_breakfast_pets", Vector3(5.6, 3.2, 4.2), Vector3(5.6, 0.3, -0.6))
	m.clear_family_breakfast(); await w(0.3)
	ok(m.get_node_or_null("FamilyBreakfast") == null, "breakfast cleared")
