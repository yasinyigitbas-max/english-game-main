extends "res://scripts/qa_flow.gd"
## v32 (black) QA through the real entry paths: menu -> New Game -> wake-up -> mirror name entry -> creation -> bedroom ->
## bathroom (mirror, chips, re-entry) -> back. Three play-throughs in one app session, each ending with
## pause -> Main menu -> New Game (2: mid-cutscene of the wake-up, 3: on a day-2 morning reached through Continue).
## godot --path . res://tools/v32/qa_v32.tscn -- --save-path=/tmp/v32qa/save.json
const OUT := "/workspace/v32_audit/"
var said32 := []

func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png"); print("V32 SHOT ", OUT + n + ".png")

func refl(sc: Node, n: String) -> float:   # saves the mirror SubViewport image, returns its mean brightness
	var vp: SubViewport = sc.N.mirror_cam.get_viewport()
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image(); img.flip_x(); img.save_png(OUT + n + ".png")
	var s := 0.0; var k := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			var c := img.get_pixel(x, y); s += (c.r + c.g + c.b) / 3.0; k += 1
	return s / maxf(1.0, k)

func cur() -> Node: return get_tree().current_scene
func scene_is(p: String, t := 30.0) -> bool:
	return await wait_until(func(): return cur() != null and cur().scene_file_path == p, t)
func count(t: String) -> int: return said32.filter(func(x): return x == t).size()

func pause_to_menu(tag: String) -> void:
	var gm: Node = null
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("show_menu") and n.has_method("to_main_menu"): gm = n; break
	ok(gm != null, tag + ": pause menu found")
	gm.show_menu(true); get_tree().paused = true; await w(0.5)
	await snap(tag + "_paused")
	var mm := btn_named(get_tree().root, "MainMenu")
	ok(mm != null and mm.is_visible_in_tree(), tag + ": Main menu button visible"); mm.pressed.emit()

func _ready() -> void:
	if name != "QAV32Root":
		var n = (get_script() as Script).new(); n.name = "QAV32Root"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT)
	Audio.spoke.connect(func(t): said32.append(t); print("V32 SAY | ", t))
	run32.call_deferred()

func new_game_from_menu(tag: String) -> void:
	await scene_is("res://menu.tscn", 20.0)
	await w(0.8)
	var b := btn_text(cur(), ["Yeni Oyun", "New Game"])
	ok(b != null, tag + ": New Game button in the menu")
	b.pressed.emit()
	ok(await scene_is("res://main.tscn", 20.0), tag + ": New Game -> bedroom opening")
	m = cur(); await w(0.3)
	var sv_exists := FileAccess.file_exists(SavePath.P())
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P())) if sv_exists else {}
	ok(not get_tree().paused, tag + ": tree unpaused")
	ok(App.day == 1 and WorldState.day == 1 and WorldState.flags.is_empty() and not App.has_phone and not App.bath_done and App.came_from == "", tag + ": App/WorldState default (day %d/%d flags %s)" % [App.day, WorldState.day, WorldState.flags])
	ok(Economy.wallet == Economy.START_CENTS and Economy.inventory.is_empty() and Life.battery == 100.0, tag + ": economy/life default (wallet %d, battery %.0f)" % [Economy.wallet, Life.battery])
	ok(m.S.name == "" and not m.S.created and m.S.family.is_empty() and m.S.job == "" and m.hero.mannequin, tag + ": character/family/job default, mannequin")
	ok(not (sv is Dictionary and (sv.has("announced") or sv.has("places") or sv.has("story"))), tag + ": no old played-once flags in the save")

func opening_to_creator(tag: String, finish := true) -> void:
	ok(await wait_until(func(): return m.mode == "play", 45.0), tag + ": wake-up reaches free play")
	for v in m.verbs("alarm"):
		if v[2] == "off": m.do_verb("alarm", v)
	await wait_until(func(): return m.mission == "Look in the mirror." and m.mode == "play", 30.0)
	await w(0.5)
	for v in m.verbs("mirror"):
		if v[2] == "look": m.do_verb("mirror", v)
	ok(await wait_until(func(): return m.side != null and m.side.find_child("Letters", true, false) != null, 30.0), tag + ": mirror name entry opens")
	await w(1.0); await snap("%s_bedroom_mirror_name_entry" % tag)
	var br := await refl(m, "%s_bedroom_mirror_reflection" % tag)
	ok(br > 0.08, tag + ": bedroom mirror not black (mean %.3f)" % br)
	if not finish: return
	for L in "ADA": btn_named(m.side, "Key_" + L).pressed.emit(); await w(0.3)
	ok(m.S.name == "Ada", tag + ": name typed")
	btn_named(m.side, "DoneName").pressed.emit()
	await wait_until(func(): return m.side != null and m.side.find_child("DoneLook", true, false) != null, 25.0)
	await w(1.5)
	btn_named(m.side, "DoneLook").pressed.emit()
	ok(await wait_until(func(): return m.mode == "play", 20.0), tag + ": creation done -> free play")
	m._on_job_chosen("teacher"); m._on_lesson_finished()
	m.S.family.append({"role": "dog", "name": "Rex", "adj": ["funny"], "col": 0}); m._on_family_saved()
	m.S.calendar_seen = true; m.S.has_phone = true; App.has_phone = true; m.save_game(); m._advance(false)
	await w(1.0)

func to_bathroom(tag: String) -> void:
	await wait_until(func(): return m.mode == "play", 20.0)
	for v in m.verbs("door"): m.do_verb("door", v)
	ok(await scene_is("res://bathroom.tscn", 40.0), tag + ": bedroom door -> bathroom (real verb)")
	var b := cur(); await w(4.5)
	await wait_until(func(): return b.mode == "play", 20.0)
	await snap("%s_bathroom_after_entry" % tag)
	var br := await refl(b, "%s_bathroom_mirror_reflection" % tag)
	ok(br > 0.08, tag + ": bathroom mirror not black (mean %.3f)" % br)

func run32() -> void:
	await w(1.0)
	get_tree().change_scene_to_file("res://menu.tscn")
	# ---------- play-through 1: fresh -> creator -> bathroom (+ re-entry) -> pause -> Main menu -> New Game
	await new_game_from_menu("pt1")
	await opening_to_creator("pt1")
	var c0 := count("Go to the mirror.")
	await to_bathroom("pt1")
	var c1 := count("Go to the mirror.")
	ok(c1 - c0 <= 1, "pt1: bathroom 'Go to the mirror.' spoken once on entry (%d)" % (c1 - c0))
	var b := cur()
	for v in b.verbs("door_bed"): b.do_verb("door_bed", v)
	await w(3.0)
	ok(cur().scene_file_path == "res://bathroom.tscn", "pt1: bathroom door to the bedroom stays closed until face + teeth (game rule) -> no mirror re-entry possible on day 1")
	await pause_to_menu("pt1")
	# ---------- play-through 2: New Game, pause mid wake-up cutscene -> Main menu -> New Game
	await new_game_from_menu("pt2")
	await w(2.5)
	ok(m.mode != "play", "pt2: still inside the wake-up cutscene (mode %s)" % m.mode)
	await pause_to_menu("pt2_midcutscene")
	await new_game_from_menu("pt2b")
	await opening_to_creator("pt2b")
	await to_bathroom("pt2b")
	# ---------- play-through 3: make it day 2, Continue (real path), pause in the day-2 morning -> New Game
	await pause_to_menu("pt2b")
	await scene_is("res://menu.tscn", 20.0); await w(0.5)
	WorldState.day = 2; App.day = 2; App.patch_save({"day": 2, "bath_done": true}); var sv = App.load_save()
	var wd: Dictionary = sv.get("world", WorldState.to_dict()); wd["day"] = 2; wd["minutes"] = 420.0; App.patch_save({"world": wd})
	btn_text(cur(), ["Devam Et", "Continue"]).pressed.emit()
	ok(await scene_is("res://main.tscn", 20.0), "pt3: Continue -> bedroom on day 2")
	m = cur(); await w(3.0)
	ok(WorldState.day == 2 or App.day == 2, "pt3: day 2 loaded (App %d, World %d)" % [App.day, WorldState.day])
	await snap("pt3_day2_before_newgame")
	await pause_to_menu("pt3_day2")
	await new_game_from_menu("pt3")
	await opening_to_creator("pt3", true)
	await to_bathroom("pt3")
	# re-entry: finish the bathroom, bedroom gets "Go to the living room." (pan + voice) once; bathroom -> bedroom again = silent
	var bt := cur(); bt.S.face_done = true; bt.S.teeth_done = true; bt._save_progress(); await w(0.5)
	var lr0 := count("Go to the living room.")
	for v in bt.verbs("door_bed"): bt.do_verb("door_bed", v)
	ok(await scene_is("res://main.tscn", 40.0), "pt3: bathroom -> bedroom (door_bed verb)")
	m = cur(); await w(9.0)
	var lr1 := count("Go to the living room.")
	ok(lr1 - lr0 == 1, "pt3: first bedroom return announces 'Go to the living room.' once (%d)" % (lr1 - lr0))
	await snap("pt3_bedroom_living_prompt")
	await wait_until(func(): return m.mode == "play", 20.0)
	for v in m.verbs("door"): m.do_verb("door", v)
	ok(await scene_is("res://bathroom.tscn", 40.0), "pt3: bedroom -> bathroom (2nd entry)")
	bt = cur(); await w(4.0); await wait_until(func(): return bt.mode == "play", 20.0)
	for v in bt.verbs("door_bed"): bt.do_verb("door_bed", v)
	ok(await scene_is("res://main.tscn", 40.0), "pt3: bathroom -> bedroom (2nd return)")
	m = cur(); await w(9.0)
	ok(count("Go to the living room.") == lr1, "pt3: bedroom re-entry does NOT re-announce 'Go to the living room.' (%d -> %d)" % [lr1, count("Go to the living room.")])
	await snap("pt3_bedroom_reentry_no_reannounce")
	# ---------- play-through 4: into the living room (real door), pause there -> Main menu -> New Game
	await wait_until(func(): return m.mode == "play", 20.0)
	for v in m.verbs("door_s"): m.do_verb("door_s", v)
	ok(await scene_is("res://livingroom.tscn", 40.0), "pt4: bedroom -> living room (door_s verb)")
	await w(4.0); await snap("pt4_livingroom")
	await pause_to_menu("pt4_livingroom")
	await new_game_from_menu("pt4")
	ok(await wait_until(func(): return m.mode == "play", 45.0) and m.hero.mannequin and m.S.name == "", "pt4: New Game from the living room -> opening with the mannequin (no old save loaded)")
	await snap("pt4_after_newgame")
	var fails := log.filter(func(l): return l.begins_with("FAIL")).size()
	var fa := FileAccess.open(OUT + "qa_v32.log", FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.store_line("SAID: " + str(said32)); fa.close()
	print("V32 QA DONE fails=%d" % fails); get_tree().quit()
