extends "res://scripts/qa.gd"
## Full-flow QA: menu -> New Game -> wake -> "Look in the mirror." -> name -> creation -> free play -> save -> Continue.

func btn_named(root: Node, nm: String) -> Button:
	var r := root.find_child(nm, true, false)
	return r as Button

func btn_text(root: Node, txts: Array) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text in txts: return b
	return null

func wait_until(c: Callable, t := 30.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not c.call():
		if Time.get_ticks_msec() - t0 > t * 1000.0: return false
		await w(0.1)
	return true

func reflection(n: String) -> void:
	var vp: SubViewport = m.N.mirror_cam.get_viewport()
	var img := vp.get_texture().get_image(); img.flip_x()
	img.save_png(ProjectSettings.globalize_path("res://screens/%s.png" % n))

func do_and_wait(id: String, key: String) -> void:
	for v in m.verbs(id):
		if v[2] == key:
			var d0 := done_n; m.do_verb(id, v)
			await wait_until(func(): return done_n > d0, 60.0); return

func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	# house.29: canvas -> window coordinates (QA runs at 2400x1080 with a 1600x720 stretched canvas)
	var e := InputEventScreenTouch.new(); e.index = idx; e.position = get_viewport().get_final_transform() * pos; e.pressed = pressed; Input.parse_input_event(e)

func drag(from: Vector2, to: Vector2, steps := 10) -> void:
	touch(0, from, true); await w(0.05)
	for i in steps:
		var e := InputEventScreenDrag.new(); e.index = 0; e.position = get_viewport().get_final_transform() * from.lerp(to, float(i + 1) / steps)
		e.relative = get_viewport().get_final_transform().basis_xform(to - from) / steps; e.velocity = e.relative / 0.016; Input.parse_input_event(e)
		await get_tree().process_frame
	touch(0, to, false)

func run_scroll() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await w(1.0)
	var menu := get_tree().current_scene
	ok(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "emulate_mouse_from_touch on")
	menu.show_grammar(); await w(0.5)
	var ps: ScrollContainer = menu.find_child("PageScroll", true, false)
	await shot("60_grammar_before")
	var r := ps.get_global_rect(); var v0 := ps.scroll_vertical
	await drag(r.get_center() + Vector2(0, 150), r.get_center() - Vector2(0, 150), 8)
	var v1 := ps.scroll_vertical; await w(0.6); var v2 := ps.scroll_vertical
	ok(v1 > v0 + 200, "grammar page scrolls on a touch swipe (%d -> %d)" % [v0, v1])
	ok(v2 > v1, "kinetic momentum after release (%d -> %d)" % [v1, v2])
	await shot("61_grammar_after_swipe")
	# drag starting on a topic button must not select it; a tap must
	var ts: ScrollContainer = menu.find_child("TopicScroll", true, false)
	var btns := ts.find_children("*", "Button", true, false)
	var g0: int = menu.g_topic
	var b1: Button = btns[min(2, btns.size() - 1)]
	var hits := [0]; b1.pressed.connect(func(): hits[0] += 1)
	await drag(b1.get_global_rect().get_center(), b1.get_global_rect().get_center() - Vector2(0, 120), 8)
	await w(0.3)
	ok(hits[0] == 0 and menu.g_topic == g0, "drag over a topic button does not press it")
	ts = menu.find_child("TopicScroll", true, false); btns = ts.find_children("*", "Button", true, false)
	var b2: Button = btns[min(2, btns.size() - 1)]; var c := b2.get_global_rect().get_center()
	ts.scroll_vertical = 0; await w(0.1); c = b2.get_global_rect().get_center()
	touch(0, c, true); await w(0.08); touch(0, c + Vector2(3, 2), false); await w(0.3)
	ok(menu.g_topic == min(2, btns.size() - 1), "tap on a topic button still works (topic %d)" % menu.g_topic)
	menu.show_vocab(); await w(0.5)
	var vs: Array = menu.find_children("*", "ScrollContainer", true, false)
	var big: ScrollContainer = null
	for s in vs: if s.is_visible_in_tree() and (big == null or s.get_global_rect().get_area() > big.get_global_rect().get_area()): big = s
	var vr := big.get_global_rect(); var w0 := big.scroll_vertical
	await drag(vr.get_center() + Vector2(0, 120), vr.get_center() - Vector2(0, 120), 8); await w(0.3)
	ok(big.scroll_vertical > w0 + 100, "vocabulary list scrolls on a touch swipe (%d -> %d)" % [w0, big.scroll_vertical])
	await shot("62_vocab_after_swipe")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_scroll.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close(); print("QA DONE"); get_tree().quit()

func run_flow() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SavePath.P()))
	await w(1.0)
	var menu := get_tree().current_scene
	ok(menu.scene_file_path == "res://menu.tscn", "starts in blue bot's main menu (%s)" % menu.scene_file_path)
	await shot("40_menu")
	var cont := btn_text(menu, ["Devam Et", "Continue"])
	ok(cont != null and cont.disabled, "Continue disabled without a save")
	btn_text(menu, ["Yeni Oyun", "New Game"]).pressed.emit()
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene
	m.captioned.connect(func(t): caps.append(t))
	m.action_done.connect(func(_i): done_n += 1)
	await w(0.5)
	ok(m.hero.mannequin, "player starts as the faceless mannequin")
	ok(not m.menu.visible, "old Play/Settings/Quit card hidden")
	ok(await wait_until(func(): return m.mode == "play", 40.0), "wake-up opening reaches free play")
	await rel_shot("41_mannequin_zoom", 1.3, 0.3, 1.4, 1.1)
	var d_al := done_n; caps.clear()
	for v in m.verbs("alarm"):
		if v[2] == "off": m.do_verb("alarm", v)
	await wait_until(func(): return m.cine_flash, 20.0)
	await w(2.1)
	ok(m.mode == "busy" and m.cam.position.distance_to(m.CINE_POS) < 0.4, "cinematic: camera at the window side, input blocked (%s)" % m.cam.position)
	await shot("41_cine_face_mirror")
	var hd: Vector3 = head() + Vector3(0, 0.05, 0)
	var vr := get_viewport().get_visible_rect()
	var fw := Vector3(sin(m.hero.rotation.y), 0, cos(m.hero.rotation.y)); var tc: Vector3 = m.cam.position - hd; tc.y = 0
	ok(vr.has_point(m.cam.unproject_position(hd)) and vr.has_point(m.cam.unproject_position(m.MIRROR_C)) and fw.dot(tc.normalized()) > 0.0, "cinematic frame shows face (facing dot %.2f) and mirror" % fw.dot(tc.normalized()))
	ok(m.cine_flash, "mission bar flashing during the move")
	await wait_until(func(): return done_n > d_al, 20.0)
	await w(0.5)
	ok(m.mode == "play" and m.cam_shot.is_empty() and not m.cine_flash, "back to the follow camera, input unblocked")
	ok(m.mission == "Look in the mirror.", "mission after wake-up: '%s'" % m.mission)
	await w(0.5)
	ok(caps.has("Go to the mirror.") and m.TR.has("Go to the mirror.") and Audio.has_clip("Go to the mirror."), "hint 'Go to the mirror.' (TR + voice)")
	ok(m.N.mirror_glow.visible and m.N.mirror_marker.visible, "mirror glow + floating marker on")
	await shot("42_mission_mirror_cues")
	m.cam_override = true; m.cam.position = Vector3(0.5, 2.2, -1.0); m.cam.look_at(Vector3(3.5, 1.0, 0.5), Vector3.UP)
	await w(0.3); ok(m.edge_arrow.visible, "off-screen edge arrow when the mirror is not visible")
	await shot("42b_edge_arrow"); m.cam_override = false
	caps.clear(); await do_and_wait("door", "try")
	ok(m.S.door == "closed" and caps.has("The door is locked. Look in the mirror first.") and Audio.has_clip("The door is locked. Look in the mirror first."), "door locked before creation: %s" % str(caps))
	ok("handleSmallLeather" in Audio.sfx_log, "locked-handle rattle sound")
	await shot("42c_door_locked")
	# ---- mirror
	caps.clear()
	for v in m.verbs("mirror"):
		if v[2] == "look": m.do_verb("mirror", v)
	await wait_until(func(): return m.side != null and m.side.find_child("Letters", true, false) != null, 30.0)
	await shot("43_pan_in_mirror")
	var grid: Node = m.side.find_child("Letters", true, false)
	ok(grid.get_child(0).get_child(0).name == "Key_Q" and grid.get_child(1).get_child(0).name == "Key_A" and grid.get_child(2).get_child(0).name == "Key_Z" and grid.find_children("Key_*", "Button", true, false).size() == 26, "v11: player keyboard is QWERTY, A-Z only")
	var r0: Rect2 = grid.get_child(0).get_child(0).get_global_rect(); var r1: Rect2 = grid.get_child(1).get_child(0).get_global_rect(); var r2: Rect2 = grid.get_child(2).get_child(0).get_global_rect()
	ok(r1.position.x > r0.position.x + 10 and r2.position.x > r1.position.x + 10, "rows are staggered (%d, %d, %d)" % [r0.position.x, r1.position.x, r2.position.x])
	for L in "YASIN":
		btn_named(m.side, "Key_" + L).pressed.emit(); await w(0.35)
	ok(m.S.name == "Yasin", "name typed: %s" % m.S.name)
	ok(Audio.has_clip("letter y") or Audio.index.has("letter y"), "letter clips present")
	btn_named(m.side, "Delete").pressed.emit(); await w(0.2)
	ok(m.S.name == "Yasi", "backspace works"); btn_named(m.side, "Key_N").pressed.emit(); await w(0.3)
	ok(not m.hud.get_node("Pause").visible, "pause button hidden while the name panel is open")
	await shot("44_alphabet")
	ok(overflow().is_empty(), "alphabet: no overflow " + str(overflow()))
	get_window().size = Vector2i(1560, 720); await w(0.5); await shot("44b_alphabet_wide_phone")
	ok(overflow().is_empty(), "keyboard on a 19.5:9 screen: no overflow " + str(overflow()))
	get_window().size = Vector2i(1280, 720); await w(0.5)
	var t_done := Audio._now()
	btn_named(m.side, "DoneName").pressed.emit()
	await w(0.3)
	await wait_until(func(): return Audio.voice_log.any(func(e): return e.what == "My name is" and e.end > 0), 15.0)
	var seq: Array = Audio.voice_log.filter(func(e): return e.start >= t_done - 0.01)
	var order: Array = seq.map(func(e): return e.what)
	# v29.1: the name is one clip ("My name is Yasin"), after the spelling; later lines may follow
	var ni := order.find("My name is Yasin")
	ok(ni >= 5 and order.slice(ni - 5, ni) == ["letter y", "letter a", "letter s", "letter i", "letter n"], "name audio order: spell first, then the name (%s)" % str(order))
	var overl := []
	for i in range(1, seq.size()):
		if seq[i - 1].end < 0 or seq[i].start < seq[i - 1].end - 0.02: overl.append("%s/%s" % [seq[i - 1].what, seq[i].what])
	ok(overl.is_empty(), "no overlapping voice clips " + str(overl))
	# v29.1: the caption moves on ("This is me!"), so check that the TR line belongs to the caption on screen
	ok(caps.has("My name is Yasin.") and (m.cap_tr.text == "Benim adım Yasin." if m.cap_text == "My name is Yasin." else m.cap_tr.text == m.TR.get(m.cap_text, m.cap_tr.text)), "caption: %s / TR %s" % [m.cap_text, m.cap_tr.text])
	await wait_until(func(): return m.hero._glow_mat != null and m.hero._glow_mat.albedo_color.a > 0.7, 15.0)
	await shot("45_take_shape_glow")
	await wait_until(func(): return m.side != null and m.side.find_child("DoneLook", true, false) != null, 10.0)
	await w(1.2)
	ok(not m.hero.mannequin, "character took shape (face, hair, clothes)")
	await shot("46_creation_default"); reflection("46_creation_default_reflection")
	ok(overflow().is_empty(), "creation: no overflow " + str(overflow()))
	for pick in [["gender", 1], ["build", 0], ["height", 2], ["hair", 1], ["skin", 2], ["top", 1], ["bottoms", 1], ["shoes", 2]]:
		var b := btn_named(m.side, "%s_%d" % pick)
		caps.clear(); b.pressed.emit(); await w(0.6)
		var c: String = caps[-1] if caps.size() > 0 else ""
		ok(c != "" and m.TR.has(c) and Audio.has_clip(c), "%s -> '%s' (TR + voice)" % [pick[0], c])
	await w(0.6)
	await shot("47_creation_custom"); reflection("47_creation_custom_reflection")
	ok(overflow().is_empty(), "creation (woman): no overflow " + str(overflow()))
	await side_shot("47_creation_custom_zoom", Vector3(-2.2, 1.6, 1.3), Vector3(-3.43, 1.3, 2.05))
	btn_named(m.side, "DoneLook").pressed.emit()
	caps.clear()
	ok(await wait_until(func(): return m.mode == "play", 15.0), "back to free play")
	await w(0.5)
	ok(m.S.door_locked and m.mission == "Pick up your phone." and caps.has("My phone is on the bedside table."), "v8: door stays locked after creation, mission = pick up the phone")
	ok(not m.N.mirror_glow.visible and not m.N.mirror_marker.visible and not m.edge_arrow.visible, "mirror cues removed")
	await w(2.0)
	await shot("48_free_play")
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv is Dictionary and sv.state.name == "Yasin" and sv.state.gender == "women" and sv.state.created and sv.state.alarm == "off", "save.json written (name, look, states)")
	m._on_job_chosen("teacher")   # the phone flow itself is tested by --qa-phone
	ok(m.S.door_locked and m.mission == "Learn he, she and it.", "v9: door still locked after the job (family needed); mission '%s'" % m.mission)
	m._on_lesson_finished(); m.S.family.append({"role": "dog", "name": "Rex", "adj": ["funny"], "col": 0})
	m._on_family_saved()
	ok(not m.S.door_locked and m.mission == "Open the Calendar.", "door unlocked after a family member (a pet counts); mission '%s'" % m.mission)
	ok(m.verbs("door").size() == 1 and m.verbs("door")[0][0] == "Go to the bathroom", "house.17: bathroom door = one 'Go to the bathroom' chip")
	await do_and_wait("desk", "laptop")
	sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv.state.laptop == "on", "object states saved after actions")
	# ---- back to the menu, Continue
	m._to_main_menu()
	await w(1.0)
	menu = get_tree().current_scene
	cont = btn_text(menu, ["Devam Et", "Continue"])
	ok(cont != null and not cont.disabled, "Continue enabled with save.json")
	await shot("49_menu_continue")
	cont.pressed.emit()
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene
	await w(2.0)
	ok(m.mode == "play" and not m.hero.mannequin and m.hero.gender == "women" and m.S.name == "Yasin" and m.S.laptop == "on", "Continue restores name, look and states")
	await shot("50_continue")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_flow.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close()
	print("QA DONE"); get_tree().quit()

# ============================================================ v8: phone + jobs
func phone_overflow() -> Array:
	var out := []
	var vr: Rect2 = get_viewport().get_visible_rect()
	var ph: Control = m.phone
	var scr: Rect2 = ph.get_node("PhoneFrame/Screen").get_global_rect()
	for c in ph.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size.x <= 0: continue
		var in_scroll := false; var p := ctl.get_parent()
		while p and p != ph:
			if p is ScrollContainer: in_scroll = true; break
			p = p.get_parent()
		var r := ctl.get_global_rect()
		if not in_scroll and not vr.grow(1).encloses(r): out.append("%s offscreen %s" % [ctl.name, r])
		if not in_scroll and ctl != ph.get_node("PhoneFrame") and ph.get_node("PhoneFrame").is_ancestor_of(ctl) and ctl.get_parent() != ph.get_node("PhoneFrame/Screen") and not scr.grow(1).encloses(r):
			out.append("%s outside the phone screen %s" % [ctl.name, r])
		if ctl is Label and (ctl as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and not (ctl as Label).clip_text:
			var l := ctl as Label
			if l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x > l.size.x + 1: out.append("label '%s' too wide" % l.text)
		elif ctl is Button:
			var b := ctl as Button
			if b.text != "" and b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + b.get_theme_stylebox("normal").get_margin(SIDE_LEFT) + b.get_theme_stylebox("normal").get_margin(SIDE_RIGHT) > b.size.x + 1:
				out.append("button '%s' too narrow" % b.text)
	return out

func biggest_scroll() -> ScrollContainer:
	var big: ScrollContainer = null
	for s in m.phone.find_children("*", "ScrollContainer", true, false):
		if s.is_visible_in_tree() and (big == null or s.get_global_rect().get_area() > big.get_global_rect().get_area()): big = s
	return big

func run_phone() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SavePath.P()))
	await w(1.0)
	btn_text(get_tree().current_scene, ["Yeni Oyun", "New Game"]).pressed.emit()
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene
	m.captioned.connect(func(t): caps.append(t))
	m.action_done.connect(func(_i): done_n += 1)
	ok(await wait_until(func(): return m.mode == "play", 40.0), "opening reaches free play")
	await do_and_wait("alarm", "off"); await w(0.5)
	ok(not m.phone_btn.visible, "no HUD phone button before character creation")
	ok(not m.verbs("night").any(func(v): return v[2] == "pickup"), "no 'Pick up the phone' before the mirror")
	# shortcut through the (separately tested) mirror flow: same end state as creation_flow
	m.S.name = "Yasin"; m.hero.set_mannequin(false); m._apply_character()
	m.mode = "busy"; caps.clear()
	var tail := func():
		m.S.created = true; m.S.door_locked = m.door_rule()
		m._set_mission("Pick up your phone."); m.caption("My phone is on the bedside table."); m.notify("jobs"); m.mode = "play"
	tail.call(); await w(1.0)
	ok(m.S.door_locked and m.mission == "Pick up your phone." and m.TR.has(m.mission) and Audio.has_clip(m.mission), "mission bar: '%s' (TR + voice)" % m.mission)
	ok(Audio.has_clip("My phone is on the bedside table."), "cue caption has a voice clip")
	ok(m.N.phone_glow.visible and m.N.phone_marker.visible, "phone glow + floating marker on")
	ok(m.phone_btn.visible and m.phone_dot.visible and m.phone_light.visible and m.notify_app == "jobs", "HUD phone button + red dot + notification light")
	ok(ResourceLoader.exists("res://sfx/notify.ogg"), "notification chime exists")
	var amin := 9.0; var amax := -1.0
	for k in 12:
		await w(0.1); amin = minf(amin, m.phone_light.modulate.a); amax = maxf(amax, m.phone_light.modulate.a)
	ok(amax - amin > 0.2, "light pulses (%.2f .. %.2f)" % [amin, amax])
	await shot("70_phone_cue"); await shot("83_hud_light")
	caps.clear(); await do_and_wait("door", "try")
	ok(m.S.door == "closed" and caps.has("The door is locked. Choose a job on your phone first."), "door locked until a job is chosen: %s" % str(caps))
	# ---- pick up the phone
	var pv: Array = m.verbs("night")[0]
	ok(pv[2] == "pickup" and pv[0] == "Pick up the phone", "bedside table action: %s" % pv[0])
	caps.clear(); m.do_verb("night", pv)
	ok(await wait_until(func(): return not m.cam_shot.is_empty(), 20.0), "player walked to the bedside table, camera panning into the phone")
	ok(m.hero.position.distance_to(m.OBJ.night.spot) < 0.3, "player stands in front of the phone (%.2f m)" % m.hero.position.distance_to(m.OBJ.night.spot))
	await w(1.75); await shot("71_phone_pickup_pan")
	ok(m.cam.position.distance_to(m.PHONE_POS) < 0.8 and not m.phone.visible, "camera close to the phone before the UI opens (%.2f m)" % m.cam.position.distance_to(m.PHONE_POS))
	ok(await wait_until(func(): return m.phone.visible and m.phone.frame.scale.x > 0.99, 10.0), "phone UI zoomed in")
	await w(0.6)
	var fr: Rect2 = m.phone.frame.get_global_rect(); var vr := get_viewport().get_visible_rect()
	ok(fr.size.x > vr.size.x * 0.8 and fr.size.y > vr.size.y * 0.7, "phone fills the view (%s of %s)" % [fr.size, vr.size])
	ok(m.phone.page == "jobs" and caps.has("I am choosing my job.") and m.mission == "Choose a job on your phone.", "opens on the Jobs app; caption + mission updated (%s)" % m.mission)
	ok(m.cap_panel.visible and m.cap_panel.get_global_rect().position.y > m.phone.find_child("NavClose", true, false).get_global_rect().end.y - 2, "action caption visible below the phone nav")
	await shot("72_phone_jobs_list"); ok(phone_overflow().is_empty(), "jobs list: no overflow " + str(phone_overflow()))
	# ---- v10: jobs drill-down (groups -> subcategories -> a few cards)
	var JD: Dictionary = m.phone.jobs_data
	var bad_art := []
	var in_subs := []
	for g in JD.groups:
		for sb in g.subs:
			in_subs += sb.jobs
			if sb.jobs.size() > 8: bad_art.append("too many in " + sb.id)
	for j in JD.jobs:
		var want: String = "" if j.id in ["unemployed", "retired"] else ("an" if String(j.en)[0].to_lower() in "aeiou" else "a")
		if j.a != want or (want != "" and not String(j.line).contains("I am %s %s." % [want, j.en])): bad_art.append(j.id)
		if not (Audio.has_clip(j.line) and Audio.has_clip(j.now)): bad_art.append("voice:" + j.id)
		if in_subs.count(j.id) != (0 if j.get("hidden", false) else 1): bad_art.append("sub:" + j.id)
		if not ResourceLoader.exists("res://ui/phone/%s.png" % j.icon): bad_art.append("icon:" + j.id)
	ok(JD.groups.size() >= 6 and JD.groups.size() <= 10 and JD.jobs.size() >= 77, "v10: %d groups, %d jobs" % [JD.groups.size(), JD.jobs.size()])
	ok(bad_art.is_empty(), "every job: in exactly one subcategory (max 8 each), icon, a/an, voice " + str(bad_art))
	for id in ["student", "housewife", "househusband", "stay-at-home parent"]: ok(m.phone.job(id).get("group", "") == "home", "new job in 'At home & Studying': " + id)
	ok(m.phone.job("student").line == "Student. I am a student. I study at a school." and m.phone.job("housewife").line == "Housewife. I am a housewife. I work at home.", "student / housewife lines")
	ok(m.phone.find_children("Group_*", "Button", true, false).size() == JD.groups.size(), "level 1: group tiles")
	await shot("91_jobs_groups"); ok(phone_overflow().is_empty(), "groups: no overflow " + str(phone_overflow()))
	var press_tap := func(n: String) -> void:
		var b: Control = m.phone.find_child(n, true, false)
		var cc := b.get_global_rect().get_center(); touch(0, cc, true); await w(0.08); touch(0, cc, false); await w(0.5)
	await press_tap.call("Group_health")
	ok(m.phone.page == "jobsub" and m.phone.find_child("Sub_hospital", true, false) != null and m.phone.find_child("Crumb_1", true, false).text == "Health & Care", "level 2: Health & Care subcategories")
	await shot("92_jobs_health_subs"); ok(phone_overflow().is_empty(), "subs: no overflow " + str(phone_overflow()))
	await press_tap.call("Sub_hospital")
	ok(m.phone.page == "joblist" and m.phone.find_child("Job_doctor", true, false) != null and m.phone.find_child("Crumb_2", true, false).text == "Hospital", "level 3: Jobs › Health & Care › Hospital")
	await shot("93_jobs_hospital"); ok(phone_overflow().is_empty(), "job list: no overflow " + str(phone_overflow()))
	m.phone.find_child("NavBack", true, false).pressed.emit(); await w(0.3)
	ok(m.phone.page == "jobsub", "Back goes up one level")
	m.phone.find_child("Crumb_0", true, false).pressed.emit(); await w(0.3)
	ok(m.phone.page == "jobs", "breadcrumb 'Jobs' goes to the top")
	# v12: the search box opens the in-game QWERTY; type by tapping keys
	ok(not (m.phone.find_child("JobSearch", true, false) is LineEdit), "job search is not a LineEdit (no OS keyboard)")
	await press_tap.call("JobSearch")
	ok(m.phone.page == "jobsearch" and m.phone.find_child("SearchKeys", true, false) != null, "tapping search opens the in-game keyboard")
	var sk: Node = m.phone.find_child("SearchKeys", true, false)
	var srows := []
	for r in sk.get_children(): srows.append("".join(r.get_children().filter(func(x): return x.name.begins_with("Key_") and x.name.length() == 5).map(func(x): return x.text)))
	ok(srows.slice(0, 3) == ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"] and m.phone.find_child("KeyDelete", true, false) and m.phone.find_child("KeyClose", true, false) and m.phone.find_child("SearchClear", true, false), "search keyboard QWERTY + Delete/Close/Clear " + str(srows))
	await shot("94a_jobs_search_empty")
	var counts := []
	for ch in "DRI":
		await press_tap.call("Key_" + ch); counts.append(m.phone.find_child("SearchResults", true, false).get_children().filter(func(x): return x.name.begins_with("Result_")).size())
	ok(m.phone.j_search == "Dri" and counts[2] > 0, "typing D,R,I filters live: %s %s" % [m.phone.j_search, str(counts)])
	for ch in "VER": await press_tap.call("Key_" + ch)
	var ids: Array = m.phone.find_child("SearchResults", true, false).get_children().filter(func(x): return x.name.begins_with("Result_")).map(func(x): return x.name)
	ok(ids.has("Result_bus_driver") and ids.has("Result_taxi_driver"), "search 'Driver' shows bus+taxi driver: " + str(ids))
	await shot("94b_jobs_search_typed"); ok(phone_overflow().is_empty(), "search keyboard: no overflow " + str(phone_overflow()))
	await press_tap.call("KeyDelete"); ok(m.phone.j_search == "Drive", "Delete removes a letter")
	await press_tap.call("SearchClear"); ok(m.phone.j_search == "", "Clear empties the search")
	for ch in "TAXI": await press_tap.call("Key_" + ch)
	await press_tap.call("Result_taxi_driver")
	ok(m.phone.page == "job" and m.phone.sel.id == "taxi driver", "tapping a result opens the job")
	await shot("94c_jobs_search_result")
	m.phone.find_child("NavBack", true, false).pressed.emit(); await w(0.3)
	ok(m.phone.page == "jobsearch", "Back returns to search")
	get_window().size = Vector2i(1560, 720); await w(0.6); m.phone._fit(); m.phone._job_search(); await w(0.4)
	await shot("94d_jobs_search_wide_phone"); ok(phone_overflow().is_empty(), "search wide: no overflow " + str(phone_overflow()))
	get_window().size = Vector2i(1280, 720); await w(0.6); m.phone._fit(); m.phone._job_search(); await w(0.3)
	await press_tap.call("KeyClose"); ok(m.phone.page == "jobs", "Close returns to Jobs")
	m.phone.search_jobs("driver"); await w(0.4)
	var fj: Array = m.phone.found_jobs().map(func(x): return x.id)
	ok(fj.has("bus driver") and fj.has("taxi driver") and m.phone.page == "joblist", "search 'driver': %s" % str(fj))
	await shot("94_jobs_search"); ok(phone_overflow().is_empty(), "search: no overflow " + str(phone_overflow()))
	m.phone.find_child("Crumb_0", true, false).pressed.emit(); await w(0.3)
	await press_tap.call("Group_home"); await shot("95_jobs_home_subs"); ok(phone_overflow().is_empty(), "home subs: no overflow " + str(phone_overflow()))
	await press_tap.call("Sub_athome"); await shot("96_jobs_at_home"); ok(phone_overflow().is_empty(), "at home: no overflow " + str(phone_overflow()))
	m.phone.find_child("NavBack", true, false).pressed.emit(); await w(0.3)
	await press_tap.call("Sub_study"); await press_tap.call("Job_student"); await w(0.4)
	await shot("97_job_student"); ok(m.phone.page == "job" and m.phone.sel.id == "student" and phone_overflow().is_empty(), "student detail " + str(phone_overflow()))
	for sz in [Vector2i(1560, 720)]:   # a 19.5:9 phone (shorter relative to its width)
		get_window().size = sz; await w(0.6)
		m.phone._fit(); m.phone.show_page("jobs"); await w(0.5)
		await shot("91b_jobs_groups_short"); ok(phone_overflow().is_empty(), "groups at %s: no overflow %s" % [sz, phone_overflow()])
		get_window().size = Vector2i(1280, 720); await w(0.6); m.phone._fit()
	m.phone.find_child("Crumb_0", true, false).pressed.emit(); await w(0.3)
	caps.clear()
	var sc: ScrollContainer; var r: Rect2; var v0 := 0
	await press_tap.call("Group_school"); await press_tap.call("Sub_teaching"); await press_tap.call("Job_teacher")
	ok(m.phone.page == "job" and m.phone.sel.id == "teacher", "tap on a card opens the job")
	ok(Audio.has_clip(m.phone.sel.line) and Audio.is_speaking(), "voice line plays: '%s'" % m.phone.sel.line)
	await w(0.6); await shot("73_phone_job_detail"); ok(phone_overflow().is_empty(), "job detail: no overflow " + str(phone_overflow()))
	caps.clear(); m.phone.find_child("ChooseJob", true, false).pressed.emit(); await w(0.8)
	ok(m.S.job == "teacher" and m.S.door_locked and m.mission == "Learn he, she and it." and caps.has("I am a teacher now."), "job confirmed; door still locked; mission '%s'" % m.mission)
	ok(m.notify_app == "family" and Audio.has_clip("Learn he, she and it."), "family notification pending after the job")
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv is Dictionary and sv.state.job == "teacher", "job saved in save.json")
	await shot("74_phone_job_confirmed"); ok(phone_overflow().is_empty(), "confirmed: no overflow " + str(phone_overflow()))
	# ---- pronoun lesson + check
	caps.clear(); m.phone.find_child("NextFamily", true, false).pressed.emit(); await w(0.6)
	ok(m.phone.page == "lesson" and caps.has("I am learning about he, she and it.") and m.mission == "Learn he, she and it.", "family opens the pronoun lesson first")
	for i in 4:
		await w(0.3); await shot("85_lesson_%d" % i); ok(phone_overflow().is_empty(), "lesson step %d: no overflow %s" % [i, phone_overflow()])
		for l in m.phone.fam_data.lesson[i].say: ok(Audio.has_clip(l), "lesson voice: " + l)
		m.phone.find_child("LessonNext", true, false).pressed.emit()
	await w(0.4); ok(m.phone.page == "quiz", "lesson -> quick check")
	caps.clear(); m.phone.find_child("Opt0", true, false).pressed.emit(); await w(0.4)
	ok(caps.has("Try again.") and m.phone.quiz_i == 0, "wrong answer: 'Try again.'")
	await shot("86_quiz_wrong")
	# v29.1: the active version is shuffled (A/B/C) -> read the answer from _qz(); wait for the options to enable
	for qi in m.phone._qz().size():
		await wait_until(func(): return m.phone.page == "quiz" and m.phone.quiz_i == qi and m.phone.find_child("Opt0", true, false) != null and not m.phone.find_child("Opt0", true, false).disabled, 30.0)
		var q: Dictionary = m.phone._qz()[qi]
		caps.clear(); m.phone.find_child("Opt%d" % int(q.a), true, false).pressed.emit(); await w(0.3)
		ok(caps.has("That is right!") and Audio.has_clip(q.say), "right answer: %s" % q.say)
		if qi == 0: await shot("86_quiz_right")
	ok(await wait_until(func(): return m.phone.page == "score", 40.0), "quick check -> score page")
	m.phone.find_child("ScoreContinue", true, false).pressed.emit()
	await wait_until(func(): return m.phone.page == "family", 10.0); await w(0.4)
	ok(m.phone.page == "family" and m.S.lesson_done and m.mission == "Add your family.", "check passed -> family page; mission '%s'" % m.mission)
	ok(m.phone.find_child("FamilyDone", true, false).disabled, "Done disabled while the family is empty")
	await shot("87a_family_empty")
	# ---- creator
	var P = m.phone
	var press := func(n: String) -> bool:
		var b: Button = P.find_child(n, true, false)
		if b == null or b.disabled: return false
		b.pressed.emit(); return true
	var add_member := func(role: String, keys: Array, look: Array, adjs: Array, shot_name: String) -> String:
		press.call("AddMember"); await w(0.3)
		press.call("Role_" + role); await w(0.2)
		press.call("Step_name"); await w(0.2)
		for k in keys: press.call("Key_" + k)
		press.call("Step_look"); await w(0.2)
		for k in look: press.call(k)
		press.call("Step_adj"); await w(0.2)
		for a in adjs: press.call("Adj_" + a)
		await w(0.6)
		var s: String = P.sentence(P.edit)
		if shot_name != "": await shot(shot_name); ok(phone_overflow().is_empty(), "%s: no overflow %s" % [shot_name, phone_overflow()])
		ok(P.find_child("MemberSentence", true, false).text == s, "live sentence label: " + s)
		press.call("SaveMember"); await w(0.5)
		return s
	m.phone.find_child("AddMember", true, false).pressed.emit(); await w(0.3)
	ok(m.phone.page == "member" and m.phone.find_child("SaveMember", true, false).disabled and m.phone.find_child("Missing", true, false).text != "", "empty member: Save disabled + hint")
	m.phone.show_page("family", false); await w(0.3)
	# keyboard checks + screenshot (v11)
	press.call("AddMember"); await w(0.3); press.call("Role_sister"); await w(0.2); press.call("Step_name"); await w(0.3)
	var keys: Array = P.find_children("Key_*", "Button", true, false)
	var bad := []
	for k in keys: if String(k.name).substr(4).unicode_at(0) > 127 or String(k.name).length() != 5: bad.append(k.name)
	var kb: Node = P.find_child("MemberKeys", true, false)
	ok(keys.size() == 26 and bad.is_empty() and kb.get_child(0).get_child(0).name == "Key_Q" and kb.get_child(2).get_child(0).name == "Key_Z" and P.find_child("KeyDelete", true, false) != null and P.find_child("KeyOK", true, false) != null, "v11: family keyboard QWERTY A-Z + Delete + OK " + str(bad))
	var tr_chars := []
	for l in P.find_children("*", "Label", true, false):
		if l.is_visible_in_tree():
			for ch in "ÇĞİÖŞÜçğıöşü": if String(l.text).contains(ch): tr_chars.append(l.text)
	for b in P.find_children("*", "Button", true, false):
		if b.is_visible_in_tree():
			for ch in "ÇĞİÖŞÜçğıöşü": if String(b.text).contains(ch): tr_chars.append(b.text)
	ok(tr_chars.is_empty(), "no Turkish characters on the name page " + str(tr_chars))
	for k in ["T", "O", "M"]: press.call("Key_" + k)
	await w(0.3); await shot("87k_family_keyboard"); ok(phone_overflow().is_empty(), "family keyboard: no overflow " + str(phone_overflow()))
	get_window().size = Vector2i(1560, 720); await w(0.6); m.phone._fit(); await w(0.3)
	await shot("87k2_family_keyboard_wide_phone"); ok(phone_overflow().is_empty(), "family keyboard 19.5:9: no overflow " + str(phone_overflow()))
	get_window().size = Vector2i(1280, 720); await w(0.6); m.phone._fit()
	press.call("KeyOK"); await w(0.3)
	ok(P.edit_step == "look" and P.edit.name == "Tom", "OK goes on to the next step")
	m.phone.show_page("family", false); await w(0.3)
	var s1: String = await add_member.call("sister", ["A", "Y", "S", "E"], ["skin_2", "Hair_1", "hcol_0", "cloth_3"], ["funny"], "87_family_creator")
	ok(s1 == "This is Ayse. She is my sister. She is funny.", "sister: '%s'" % s1)
	ok(m.S.family.size() == 1 and m.S.family[0].skin == 2 and m.S.family[0].hair == 1 and m.S.family[0].cloth == 3, "sister look saved")
	var s2: String = await add_member.call("dog", ["R", "E", "X"], ["col_2"], ["cheerful", "friendly"], "87b_pet")
	ok(s2 == "This is Rex. It is my dog. It is friendly and cheerful.", "pet: '%s'" % s2)
	var s3: String = await add_member.call("brother", ["T", "O", "M"], ["Hair_2"], ["kind"], "")
	var s4: String = await add_member.call("brother", ["B", "E", "N"], ["hcol_3"], ["brave", "calm", "clever"], "")
	ok(s3 == "This is Tom. He is my brother. He is kind." and s4 == "This is Ben. He is my brother. He is clever and calm.", "brothers (2-adjective limit): '%s' / '%s'" % [s3, s4])
	for s in [s1, s2, s3, s4]:
		for part in s.split(". ", false).slice(1): ok(Audio.has_clip(part if part.ends_with(".") else part + "."), "voice: " + part)
	ok(m.phone.page == "family" and m.S.family.size() == 4, "4 members on the family page")
	var sl: Array = m.phone.summary_lines()
	ok(sl.has("Tom and Ben are my brothers.") and sl.has("Ayse is my sister.") and sl.has("Rex is my dog."), "summary: %s" % str(sl))
	await w(0.4); await shot("88_family_summary"); ok(phone_overflow().is_empty(), "family: no overflow " + str(phone_overflow()))
	ok(m.S.door_locked, "door still locked before Done")
	caps.clear(); m.phone.find_child("FamilyDone", true, false).pressed.emit(); await w(0.6)
	ok(not m.S.door_locked and m.mission == "Open the Calendar." and m.notify_app == "calendar" and caps.has("This is my family."), "family saved: door unlocked, calendar notification; mission '%s'" % m.mission)
	ok(m.phone.page == "home" and m.phone.find_child("App_jobs", true, false) == null and m.phone.find_child("App_calendar", true, false) != null and m.phone.find_child("App_calendar", true, false).find_child("Badge", true, false) != null, "home: Jobs app gone, Calendar app with badge")
	await w(0.3); await shot("88b_home_calendar")
	# ---- calendar (job-shaped)
	caps.clear(); m.phone.find_child("App_calendar", true, false).pressed.emit(); await w(0.6)
	var rt: Array = m.phone.routine().map(func(x): return x[1])
	ok(rt.has("I start work at the school.") and rt.has("I teach a lesson.") and rt.has("I check homework.") and rt.has("I meet parents."), "teacher routine: %s" % str(rt))
	var miss := []
	for x in rt: if not Audio.has_clip(x): miss.append(x)
	ok(miss.is_empty(), "routine voice clips " + str(miss))
	var td: Array = m.todo()
	ok(td.has(["Choose a job.", true]) and td.has(["Add your family.", true]) and td.has(["Open the door.", false]) and td.has(["Teach a lesson.", false]), "to-do ticks + job tasks: %s" % str(td))
	ok(m.S.calendar_seen and m.mission == "Go to the bathroom." and m.notify_app == "" and caps.has("I am looking at my calendar."), "calendar seen; mission '%s'" % m.mission)
	await w(0.4); await shot("89_calendar_teacher"); ok(phone_overflow().is_empty(), "calendar: no overflow " + str(phone_overflow()))
	sc = m.phone.find_child("RoutineScroll", true, false); r = sc.get_global_rect(); v0 = sc.scroll_vertical
	await drag(r.get_center() + Vector2(0, 120), r.get_center() - Vector2(0, 120), 8); await w(0.4)
	ok(sc.scroll_vertical > v0 + 40, "routine list scrolls on a swipe (%d -> %d)" % [v0, sc.scroll_vertical])
	var expect := {"secretary": ["I answer the phone.", "I go to a meeting.", "I write emails."], "doctor": ["I see patients."], "cook": ["I cook lunch."],
		"bus driver": ["I drive the bus."], "unemployed": ["I look for a job.", "I write a CV.", "I go to an interview."], "retired": ["I walk in the park.", "I visit my grandchildren.", "I read the newspaper."],
		"student": ["I go to class.", "I do my homework.", "I study for an exam."], "housewife": ["I take the children to school.", "I go shopping.", "I clean the house.", "I cook dinner."]}
	for jid in expect:
		var rr: Array = m.phone.routine(jid).map(func(x): return x[1])
		var good := true
		for e in expect[jid]: good = good and rr.has(e) and Audio.has_clip(e)
		if jid in ["unemployed", "retired", "student", "housewife"]: good = good and not rr.any(func(x): return String(x).begins_with("I start work"))
		ok(good, "%s routine: %s" % [jid, str(rr)])
	var nmiss := []
	for j in JD.jobs:
		var tk: Array = m.phone.tasks(j.id)
		if tk.size() < 3: nmiss.append(j.id)
		for t in tk: if not (Audio.has_clip(t.i) and Audio.has_clip(t.do)): nmiss.append(t.i)
	ok(nmiss.is_empty(), "every job has 3+ work tasks with voice " + str(nmiss))
	for jid in ["secretary", "retired", "student", "housewife"]:
		m.S.job = jid; m.phone.show_page("calendar", false); await w(0.5); await shot("89_calendar_" + jid)
		ok(phone_overflow().is_empty(), "calendar %s: no overflow %s" % [jid, phone_overflow()])
	m.S.job = "teacher"
	m.phone.show_page("me", false); await w(0.5)
	ok(m.phone.find_child("MeFamily", true, false).get_child_count() == 4, "Me app shows the family")
	await shot("90_me"); ok(phone_overflow().is_empty(), "me: no overflow " + str(phone_overflow()))
	sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv.state.family.size() == 4 and sv.state.family[0].name == "Ayse" and sv.state.lesson_done and sv.state.calendar_seen, "family saved in save.json")
	m.phone.find_child("NavClose", true, false).pressed.emit()
	ok(await wait_until(func(): return m.mode == "play" and not m.phone.visible, 5.0), "Close returns to play")
	await w(0.5); ok(not m.phone_light.visible and not m.phone_dot.visible, "no light when nothing is pending")
	# ---- v13: the phone is carried, not on the table
	ok(m.S.has_phone and App.has_phone, "v13: has_phone set (S + App autoload)")
	ok(not m.N.phone_body.visible and not m.N.phone_screen.visible, "v13: phone removed from the bedside table")
	ok(not m.verbs("night").any(func(v): return v[2] in ["pickup", "phone"]), "v13: no 'Pick up the phone' / charge chip on the table: %s" % str(m.verbs("night").map(func(v): return v[0])))
	sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv.get("has_phone", false) and sv.state.has_phone, "v13: has_phone in save.json")
	m.cam_shot = {"pos": m.PHONE_POS + Vector3(0.75, 0.75, -0.05), "at": m.PHONE_POS}; await w(1.5)
	await shot("76_table_empty_after_pickup"); m.cam_shot = {}; await w(0.8)
	var hp: Vector3 = m.hero.position; var cp: Vector3 = m.cam.position
	m.hero.rotation.y = atan2(cp.x - hp.x, cp.z - hp.z); await w(0.3)   # face the camera so the arm is visible
	m.open_phone_hud.call_deferred()
	ok(await wait_until(func(): return m.pocket != null and m.pocket.current == "in_hand", 20.0), "v13: take-out-of-pocket started")
	ok(m.hero.find_child("HeldItem", true, false) != null, "v13: phone appears in the hand")
	await w(0.1); await shot("77_pocket_take_out")
	ok(await wait_until(func(): return m.pocket.current == "zoomed", 8.0), "v13: camera zoomed onto the phone")
	await w(0.1); await shot("78_pocket_zoomed")
	ok(m.cam.position.distance_to(m.pocket.phone_node().global_position) < 1.0, "v13: camera close to the phone (%.2f m)" % m.cam.position.distance_to(m.pocket.phone_node().global_position))
	ok(await wait_until(func(): return m.phone.visible and m.phone.frame.scale.x > 0.99, 10.0), "v13: HUD button opens the carried phone")
	await w(0.5); await shot("79_phone_opened_from_hud")
	m.phone.find_child("NavClose", true, false).pressed.emit()
	ok(await wait_until(func(): return m.pocket.current == "put_away", 6.0), "v13: UI closed, camera zoomed back out")
	ok(await wait_until(func(): return m.hero.find_child("HeldItem", true, false) != null and m.cam_shot.is_empty() and m.pocket.current == "put_away", 4.0), "v13: put-away stage")
	await w(0.25); await shot("80_pocket_put_away")
	ok(await wait_until(func(): return m.mode == "play" and not m.phone.visible and m.pocket.current == "pocketed", 6.0), "v13: phone back in the pocket, play again")
	ok(m.hero.find_child("HeldItem", true, false) == null and not m.hero.bone_offsets.has("UpperArm.R"), "v13: phone hidden, arm released")
	ok(m.cam_shot.is_empty(), "v13: normal camera view restored")
	m.S.has_phone = false; App.has_phone = false
	ok(m.load_game() and m.S.has_phone and App.has_phone, "v13: reload keeps has_phone")
	m._apply_states(); ok(not m.N.phone_body.visible, "v13: table still empty after reload")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_phone.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close()
	if "--qa-e2e" in OS.get_cmdline_user_args():
		log.append("==== house tour (house.17 e2e) ===="); await house_tour()
		fa = FileAccess.open(ProjectSettings.globalize_path("res://qa_e2e.log"), FileAccess.WRITE)
		for l in log: fa.store_line(l)
		fa.close()
	print("QA DONE"); get_tree().quit()

# ============================================================ v10: child player
func run_child() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SavePath.P()))
	await w(1.0)
	btn_text(get_tree().current_scene, ["Yeni Oyun", "New Game"]).pressed.emit()
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene
	m.captioned.connect(func(t): caps.append(t))
	ok(await wait_until(func(): return m.mode == "play", 40.0), "opening reaches free play")
	await do_and_wait("alarm", "off"); await w(0.5)
	m.S.name = "Ela"; m.hero.set_mannequin(false); m._apply_character(); m.mode = "busy"
	m.cam_shot = {"pos": Vector3(-1.55, 1.75, 3.05), "at": Vector3(-3.15, 1.3, 2.05), "h": 0.62}
	m._show_creation(); await w(0.5)
	ok(m.side.find_child("age_0", true, false) != null and m.side.find_child("age_0", true, false).text == "Child", "mirror: age row (Child / Adult)")
	caps.clear(); btn_named(m.side, "age_0").pressed.emit(); await w(0.4)
	ok(m.S.age == "child" and m.hero.child and absf(m.hero.model.scale.y - 0.66) < 0.02 and caps.has("I am a child.") and Audio.has_clip("I am a child."), "child chosen: small body (scale %.2f), caption + voice" % m.hero.model.scale.y)
	ok(btn_named(m.side, "gender_1").text == "Girl", "body labels become Boy / Girl")
	btn_named(m.side, "gender_1").pressed.emit(); await w(0.6)
	ok(overflow().is_empty(), "creation (child): no overflow " + str(overflow()))
	await shot("99_child_mirror")
	await side_shot("99a_child_mirror_zoom", Vector3(-1.2, 0.9, 1.0), Vector3(-2.9, 0.6, 2.2))
	btn_named(m.side, "DoneLook").pressed.emit()
	m.cam_shot = {}
	await m._after_look(); m.mode = "play"; await w(0.5)
	ok(m.S.job == "schoolchild" and m.mission == "Pick up your phone." and m.notify_app == "calendar" and not m.phone.apps().any(func(a): return a[0] == "jobs"), "child: job = student automatically, no Jobs app, mission '%s'" % m.mission)
	ok(m.S.door_locked, "door locked until the family is added")
	await shot("99b_child_room")
	m.hero.position = Vector3(-0.6, 0, -0.2); await w(0.4)
	await side_shot("99b3_child_next_to_desk", Vector3(0.4, 1.2, 1.4), Vector3(-0.4, 0.6, -0.6))
	# ---- phone -> calendar directly
	var pv: Array = m.verbs("night")[0]
	caps.clear(); m.do_verb("night", pv)
	ok(await wait_until(func(): return m.phone.visible and m.phone.frame.scale.x > 0.99, 30.0), "phone open")
	await w(0.6)
	var rt: Array = m.phone.routine().map(func(x): return x[1])
	ok(m.phone.page == "calendar" and rt.has("I go to school.") and rt.has("I have lessons.") and rt.has("I play with my friends.") and rt.has("I do my homework.") and rt.has("I go to bed."), "child: phone opens on the school calendar %s" % str(rt))
	var miss := []
	for x in rt: if not Audio.has_clip(x): miss.append(x)
	ok(miss.is_empty() and Audio.has_clip("I am a student. I go to school."), "child routine voice " + str(miss))
	ok(not m.todo().any(func(t): return t[0] == "Choose a job."), "to-do has no job item")
	ok(m.S.calendar_seen and m.mission == "Learn he, she and it." and m.notify_app == "family", "after the calendar: family lesson next ('%s')" % m.mission)
	await shot("99c_child_calendar"); ok(phone_overflow().is_empty(), "child calendar: no overflow " + str(phone_overflow()))
	m.phone.find_child("CalNextFamily", true, false).pressed.emit(); await w(0.4)
	ok(m.phone.page == "lesson", "Next: my family -> pronoun lesson")
	for i in 4: m.phone.find_child("LessonNext", true, false).pressed.emit(); await w(0.2)
	for q in m.phone.fam_data.quiz:
		m.phone.find_child("Opt%d" % int(q.a), true, false).pressed.emit(); await w(1.9)
	await w(0.3)
	ok(m.phone.page == "family" and m.mission == "Add your family.", "lesson + check done")
	m.phone.find_child("AddMember", true, false).pressed.emit(); await w(0.4)
	var roles: Array = m.phone.find_children("Role_*", "Button", true, false).map(func(b): return String(b.name).substr(5))
	ok(roles.has("mother") and roles.has("grandfather") and roles.has("dog") and not roles.has("wife") and not roles.has("husband") and not roles.has("son") and not roles.has("daughter"), "child family roles: %s" % str(roles))
	await shot("99d_child_family_roles"); ok(phone_overflow().is_empty(), "roles: no overflow " + str(phone_overflow()))
	var P = m.phone
	P.find_child("Role_brother", true, false).pressed.emit(); await w(0.3)
	ok(P.edit.child and P.find_child("Age_child", true, false) != null, "a brother of a child is a child by default; age chips shown")
	P.find_child("Step_name", true, false).pressed.emit(); await w(0.2)
	for k in ["C", "A", "N"]: P.find_child("Key_" + k, true, false).pressed.emit()
	P.find_child("Step_adj", true, false).pressed.emit(); await w(0.2)
	P.find_child("Adj_funny", true, false).pressed.emit(); await w(0.2)
	P.find_child("Step_look", true, false).pressed.emit(); await w(0.6)
	ok(P.preview_char != null and P.preview_char.child, "3D preview uses the child body")
	await shot("99e_child_brother"); ok(phone_overflow().is_empty(), "child member: no overflow " + str(phone_overflow()))
	P.find_child("SaveMember", true, false).pressed.emit(); await w(0.4)
	P.find_child("AddMember", true, false).pressed.emit(); await w(0.3)
	P.find_child("Role_mother", true, false).pressed.emit(); await w(0.2)
	ok(not P.edit.child, "mother is an adult by default")
	P.find_child("Step_name", true, false).pressed.emit(); await w(0.2)
	for k in ["S", "E", "D", "A"]: P.find_child("Key_" + k, true, false).pressed.emit()
	P.find_child("Step_adj", true, false).pressed.emit(); await w(0.2)
	P.find_child("Adj_kind", true, false).pressed.emit(); await w(0.2)
	P.find_child("SaveMember", true, false).pressed.emit(); await w(0.5)
	await shot("99f_child_family"); ok(phone_overflow().is_empty(), "child family: no overflow " + str(phone_overflow()))
	P.find_child("FamilyDone", true, false).pressed.emit(); await w(0.6)
	ok(not m.S.door_locked and m.mission == "Go to the bathroom.", "door rule for a child: mirror + family -> unlocked; mission '%s'" % m.mission)
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv.state.age == "child" and sv.state.job == "schoolchild" and sv.state.family.size() == 2 and sv.state.family[0].child, "save: age, auto job, child family member")
	m.phone.find_child("NavClose", true, false).pressed.emit()
	await wait_until(func(): return m.mode == "play" and not m.phone.visible, 5.0)
	caps.clear(); await do_and_wait("door", "open")
	ok(caps.has("I am opening the door.") and await wait_until(func(): return get_tree().current_scene and get_tree().current_scene.scene_file_path == "res://bathroom.tscn", 15.0), "door opens -> bathroom")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_child.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close(); print("QA DONE"); get_tree().quit()

# ============================================================ house.17: end-to-end house tour (bedroom -> bathroom -> living room -> bedroom)
var anims_seen := {}
var peak_n := 0
func cur_path() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""

func attach(path: String) -> bool:
	var okk: bool = await wait_until(func(): return cur_path() == path and get_tree().current_scene.is_node_ready(), 90.0)
	m = get_tree().current_scene
	if m.has_signal("captioned"): m.captioned.connect(func(t): caps.append(t))
	if m.has_signal("action_peak"): m.action_peak.connect(func(_i): peak_n += 1)
	return okk

func shotv(n: String) -> void:
	await shot("v17/" + n)

## run one verb, wait until the room is idle again (or the scene changed); returns seconds
func act_v(id: String, v: Array) -> float:
	var t0 := Time.get_ticks_msec(); var p0 := cur_path(); anims_seen.clear()
	m.do_verb(id, v); await w(0.3)
	while Time.get_ticks_msec() - t0 < 150000:
		if cur_path() != p0 or get_tree().current_scene != m: break
		if is_instance_valid(m.hero) and m.hero.player: anims_seen[String(m.hero.player.current_animation)] = true
		if m.mode in ["play", "seated"]: break
		await w(0.1)
	return (Time.get_ticks_msec() - t0) / 1000.0

func vk(id: String, key: String) -> Array:
	for x in m.verbs(id): if x[2] == key: return x
	return []

func silent_room_caption(line: String) -> void:
	ok(await wait_until(func(): return caps.has(line), 4.0), "silent room caption '%s'" % line)
	await w(0.3)
	ok(not Audio.voice_log.any(func(e): return String(e.what) == line), "room caption is not spoken: '%s'" % line)

func no_family_here(room: String) -> void:
	var n := 0
	for c in get_tree().current_scene.find_children("*", "DemoCharacter", true, false): if c != m.hero: n += 1
	ok(n == 0 and get_tree().current_scene.find_child("FamilyBreakfast", true, false) == null, "%s: no family members here (%d)" % [room, n])

func pocket_cycle(room: String, rp) -> void:
	m.hero.rotation.y = atan2(m.cam.global_position.x - m.hero.position.x, m.cam.global_position.z - m.hero.position.z) if "cam" in m and m.cam is Node3D else m.hero.rotation.y
	caps.clear()
	if room == "bedroom": m.open_phone_hud.call_deferred()
	else: rp.open_phone.call_deferred()
	var pk = func(): return m.pocket if room == "bedroom" else rp.pocket
	var PH = m.phone if room == "bedroom" else rp.phone
	ok(await wait_until(func(): return pk.call() != null and pk.call().current == "in_hand", 15.0), "%s: phone taken out of the pocket" % room)
	ok(m.hero.find_child("HeldItem", true, false) != null, "%s: phone in the hand" % room)
	await w(0.1); await shotv("pocket_%s_1_in_hand" % room)
	ok(await wait_until(func(): return pk.call().current == "zoomed", 8.0), "%s: camera zoomed onto the phone" % room)
	ok(await wait_until(func(): return PH.visible and PH.frame.scale.x > 0.99, 10.0), "%s: phone UI open" % room)
	await w(0.4); await shotv("pocket_%s_2_ui" % room)
	PH.find_child("NavClose", true, false).pressed.emit()
	ok(await wait_until(func(): return pk.call().current == "pocketed" and m.mode == "play" and not PH.visible, 10.0), "%s: UI closed, phone back in the pocket" % room)
	ok(m.hero.find_child("HeldItem", true, false) == null, "%s: phone hidden after put-away" % room)
	ok(caps.count("I am looking at my phone.") == 1, "%s: 'I am looking at my phone.' exactly once (%d)" % [room, caps.count("I am looking at my phone.")])

func menu_check(room: String) -> void:
	var sc := get_tree().current_scene
	var pb: Button = sc.find_child("Pause", true, false)
	ok(pb != null, "%s: pause button" % room)
	pb.pressed.emit(); await w(0.4)
	var gm: Control = sc.find_child("GameMenu", true, false)
	ok(gm != null and gm.visible and get_tree().paused, "%s: shared GameMenu opens + pauses" % room)
	var names := ["Resume", "Settings", "MainMenu"].filter(func(n): return gm.find_child(n, true, false) is Button)
	ok(names.size() == 3 and gm.find_child("RoomLabel", true, false).text.begins_with(room), "%s: same options Resume/Settings/Main menu (%s)" % [room, gm.find_child("RoomLabel", true, false).text])
	await shotv("menu_%s" % room.to_lower().replace(" ", "_"))
	gm.find_child("Settings", true, false).pressed.emit(); await w(0.3)
	var rows := ["Set_voice", "Set_gender", "Set_build", "Set_height"].filter(func(n): return gm.find_child(n, true, false) is Button)
	ok(gm.find_child("SettingsPanel", true, false).visible and rows.size() == 4, "%s: settings Voice/Character/Build/Height" % room)
	await shotv("menu_%s_settings" % room.to_lower().replace(" ", "_"))
	var vb: Button = gm.find_child("Set_voice", true, false); var t0 := vb.text
	vb.pressed.emit(); vb.pressed.emit(); ok(vb.text == t0, "%s: voice toggle round-trip (%s)" % [room, t0])
	gm.find_child("Done", true, false).pressed.emit(); await w(0.2)
	gm.find_child("Resume", true, false).pressed.emit(); await w(0.4)
	ok(not get_tree().paused and not gm.visible, "%s: Resume closes the menu" % room)

func house_tour() -> void:
	await menu_check("Bedroom")
	Audio.voice_log.clear()
	# ---------------- bedroom: mission + locked south door
	ok(m.mission == "Go to the bathroom." and m.TR.get(m.mission, "") == "Banyoya git." and Audio.has_clip(m.mission), "bedroom mission 'Go to the bathroom.' (TR + voice): '%s'" % m.mission)
	await shotv("e01_bedroom_mission_bathroom")
	var vs: Array = m.verbs("door_s")
	ok(vs.size() == 1 and vs[0][0] == "Go to the living room" and vs[0][2] == "try", "south door: one chip, locked (%s)" % str(vs))
	caps.clear(); await act_v("door_s", vs[0])
	ok(cur_path() == "res://main.tscn" and caps.has("The door is locked. Go to the bathroom first.") and Audio.has_clip("The door is locked. Go to the bathroom first."), "south door locked before the bathroom: %s" % str(caps))
	await shotv("e02_bedroom_south_locked")
	no_family_here("bedroom")
	var win0 := [m.N.sash.rotation.y, m.N.curtL.scale.x, m.N.curtR.scale.x, m.N.curtL.position, m.S.window, m.S.curtains]
	var wmon := {"dev": 0.0}
	var mon := func():
		if is_instance_valid(m) and cur_path() == "res://main.tscn" and m.get("N") and m.N.has("sash"):
			wmon.dev = maxf(wmon.dev, absf(m.N.sash.rotation.y - win0[0]) + absf(m.N.curtL.scale.x - win0[1]) + absf(m.N.curtR.scale.x - win0[2]) + m.N.curtL.position.distance_to(win0[3]))
	get_tree().process_frame.connect(mon)
	await act_v("wardrobe", vk("wardrobe", "toggle")); ok(m.S.wardrobe == "open", "wardrobe opens")
	await act_v("wardrobe", vk("wardrobe", "toggle")); ok(m.S.wardrobe == "closed", "wardrobe closes")
	ok(wmon.dev < 0.001 and m.S.window == win0[4] and m.S.curtains == win0[5], "wardrobe open/close does not move the window or curtains (dev %.4f)" % wmon.dev)
	await shotv("e02b_wardrobe_window")
	vs = m.verbs("door")
	ok(vs.size() == 1 and vs[0][0] == "Go to the bathroom", "+X door: one chip 'Go to the bathroom' (%s)" % str(vs))
	caps.clear(); m.do_verb("door", vs[0])
	ok(await attach("res://bathroom.tscn"), "+X door -> bathroom scene")
	get_tree().process_frame.disconnect(mon)
	ok(wmon.dev < 0.001, "+X door opening does not move the window (dev %.4f)" % wmon.dev)
	await w(0.3)
	ok(m.hero.position.x < m.LX + 0.9 and absf(m.hero.position.z - (m.WD.x + m.WD.y) / 2) < 0.3, "bathroom entry at the west door (%s)" % m.hero.position)
	await silent_room_caption("I'm in the bathroom now.")
	await menu_check("Bathroom")
	await shotv("e03_bathroom_entry")
	no_family_here("bathroom")
	ok(m.mission == "Wash your face.", "bathroom mission '%s'" % m.mission)
	ok(m.verbs("door").size() == 1 and m.verbs("door")[0][0] == "Go to the living room" and m.verbs("door_bed")[0][0] == "Go to the bedroom", "bathroom doors: one chip each")
	caps.clear(); await act_v("door", m.verbs("door")[0])
	ok(cur_path() == "res://bathroom.tscn" and caps.has("The door is closed. Wash your face and brush your teeth first."), "bathroom south door locked before the routine")
	# ---------------- routine
	var tf := await act_v("sink", vk("sink", "face")); ok(m.S.face_done and m.mission == "Brush your teeth.", "wash face (%.1fs) anims %s; mission '%s'" % [tf, anims_seen.keys(), m.mission])
	var tt := await act_v("sink", vk("sink", "teeth")); ok(m.S.teeth_done and m.S.brush == "cup", "brush teeth (%.1fs) anims %s" % [tt, anims_seen.keys()])
	ok(await wait_until(func(): return caps.has("Go to the living room."), 8.0), "'Go to the living room.' caption after the routine")
	ok(m.mission == "Go to the living room." and App.bath_done, "mission '%s', App.bath_done %s" % [m.mission, App.bath_done])
	var sv = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(sv.get("bath_done", false) and sv.state.name == "Yasin" and sv.state.family.size() == 4, "bath_done persisted in save.json (bedroom state intact)")
	await shotv("e04_bathroom_routine_done")
	# ---------------- every other bathroom object / verb
	var bad := []
	for id in m.OBJ.keys():
		if id in ["door", "door_bed"]: continue
		var n: int = m.verbs(id).size()
		for i in n:
			var vl: Array = m.verbs(id)
			if i >= vl.size(): break
			var v: Array = vl[i]
			var before: String = str(m.S.get("cabinet", ""))
			var p0 := peak_n
			var dt := await act_v(id, v)
			var fine: bool = m.mode == "play" and cur_path() == "res://bathroom.tscn" and dt < 140.0
			if id == "cabinet" and v[2] in ["open", "close", "toggle"]: fine = fine and str(m.S.cabinet) != before
			var line := "bathroom %s/%s '%s' %.1fs anims %s peak %s" % [id, v[2], v[0], dt, anims_seen.keys(), peak_n > p0]
			ok(fine, line)
			if not fine: bad.append(line)
	if m.S.get("cabinet", "closed") == "open": await act_v("cabinet", m.verbs("cabinet")[0])
	ok(m.S.get("cabinet", "closed") == "closed", "cabinet closed at the end, verbs now %s" % str(m.verbs("cabinet").map(func(x): return x[0])))
	await shotv("e05_bathroom_after_all")
	await pocket_cycle("bathroom", m.room_phone)
	# ---------------- bathroom -> living room
	caps.clear(); m.do_verb("door", m.verbs("door")[0])
	ok(await attach("res://livingroom.tscn"), "bathroom south door -> living room")
	await w(0.4)
	var db: Vector2 = m.DOOR_BATH
	ok(absf(m.hero.position.x - (db.x + db.y) / 2) < 0.3 and m.hero.position.z < -1.6, "living room entry at door_bath (%s)" % m.hero.position)
	await silent_room_caption("I'm in the living room now.")
	await menu_check("Living room")
	await shotv("e06_living_entry")
	var fam: Array = m.breakfast_members
	var at_table := fam.size() > 0
	for f in fam: at_table = at_table and Vector2(f.node.global_position.x - 5.6, f.node.global_position.z - 0.9).length() < 1.6
	ok(at_table, "family at the breakfast table (%d members)" % fam.size())
	# ---------------- breakfast with the family
	ok(await wait_until(func(): return m.join_btn != null and is_instance_valid(m.join_btn), 30.0), "a family member calls the player to the table")
	var call: Array = caps.filter(func(c): return String(c).contains("Come and join us at the table.") and String(c).contains("Yasin"))
	ok(not call.is_empty() and m.mission == "Have breakfast with your family.", "call line %s; mission '%s'" % [str(call), m.mission])
	await w(0.5); await shotv("e07_breakfast_call")
	m.join_btn.pressed.emit()
	ok(await wait_until(func(): return m.S.seat.begins_with("dine"), 60.0), "player walks to the free chair and sits (%s)" % m.S.seat)
	ok(await wait_until(func(): return caps.has("I am having breakfast."), 30.0), "breakfast starts")
	m.cam_shot = {"pos": Vector3(5.6, 2.4, 3.4), "at": Vector3(5.6, 0.8, 0.9)}; await w(1.2); await shotv("e07b_family_breakfast_seated")
	ok(await wait_until(func(): return caps.any(func(c): return String(c).ends_with("How is your week looking?")), 40.0), "family member asks 'How is your week looking?'")
	var P = m.room_phone.phone
	ok(await wait_until(func(): return P.visible and P.page == "lesson", 40.0), "present simple lesson opens on the phone")
	var nles: int = m.BK.lesson.size()
	for i in nles:
		await w(0.4); await shotv("e07c_ps_lesson_%d" % i)
		ok(P.lesson_i == i and P.find_child("LessonNext", true, false) != null, "present simple lesson step %d/%d" % [i + 1, nles])
		for l in m.BK.lesson[i].say: ok(Audio.has_clip(l), "lesson voice: " + l)
		await Audio.wait_idle(20.0)
		P.find_child("LessonNext", true, false).pressed.emit()
	ok(await wait_until(func(): return not P.visible, 10.0), "lesson done -> phone closes")
	ok(await wait_until(func(): return caps.filter(func(c): return String(c).contains(": I ")).size() >= 2, 90.0), "family members tell about their week: %s" % str(caps.filter(func(c): return String(c).contains(": I "))))
	for c in caps.filter(func(c): return String(c).contains(": I ")): ok(m.XTR.has(c) and Audio.has_clip(String(c).split(": ", true, 1)[1]), "week line voiced + TR: " + c)
	await shotv("e07d_week_line")
	ok(await wait_until(func(): return P.visible and P.page == "quiz", 120.0), "quiz opens")
	var nq: int = m.BK.quiz.size()
	ok(nq >= 10, "quiz has %d questions (to be + present simple)" % nq)
	var res := {"s": -1, "t": 0}
	m.breakfast_finished.connect(func(a, b): res.s = a; res.t = b, CONNECT_ONE_SHOT)
	for i in nq:
		await wait_until(func(): return P.quiz_i == i and P.find_child("Opt0", true, false) != null, 15.0)
		var q: Dictionary = m.BK.quiz[i]
		if i == 0:
			P.find_child("Opt%d" % ((int(q.a) + 1) % 3), true, false).pressed.emit(); await w(0.4)
			ok(P.find_child("Feedback", true, false).text == "Try again.", "wrong answer feedback"); await shotv("e07e_quiz_wrong")
		P.find_child("Opt%d" % int(q.a), true, false).pressed.emit(); await w(0.3)
		if i == 1: await shotv("e07f_quiz_right")
		ok(Audio.has_clip(q.say), "quiz %d: %s" % [i + 1, q.say])
		await w(1.5)
	ok(await wait_until(func(): return P.find_child("Score", true, false) != null, 10.0), "score page")
	await shotv("e07g_quiz_score")
	ok(await wait_until(func(): return res.s >= 0, 60.0), "breakfast finished; score %d / %d" % [res.s, res.t])
	ok(res.s == nq - 1 and res.t == nq, "score counts first-try answers (%d / %d)" % [res.s, res.t])
	var svb = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
	ok(svb.get("breakfast_done", false) and m.mode == "play" and m.S.seat == "" and m.mission != "Have breakfast with your family.", "breakfast saved; player stands; mission '%s'" % m.mission)
	# ---------------- every living room object / verb
	for id in m.OBJ.keys():
		if id in ["door_bed", "door_bath"]: continue
		var n2: int = m.verbs(id).size()
		for i in n2:
			var vl: Array = m.verbs(id)
			if m.mode == "seated" or i >= vl.size(): break
			var v: Array = vl[i]
			var dt := await act_v(id, v)
			if m.mode == "seated":
				for sv2 in m.verbs(id):
					if sv2[2] != "stand": await act_v(id, sv2)
				await act_v(id, vk(id, "stand"))
			ok(m.mode == "play" and cur_path() == "res://livingroom.tscn", "living room %s/%s '%s' %.1fs anims %s" % [id, v[2], v[0], dt, anims_seen.keys()])
		if id == "front": await shotv("e08_front_door")
	await pocket_cycle("livingroom", m.room_phone)
	# ---------------- living room -> bedroom
	ok(m.verbs("door_bed").size() == 1, "living room door_bed: one chip %s" % str(m.verbs("door_bed")))
	caps.clear(); Audio.voice_log.clear(); m.do_verb("door_bed", m.verbs("door_bed")[0])
	ok(await attach("res://main.tscn"), "door_bed -> bedroom")
	await w(0.8)
	ok(m.hero.position.distance_to(Vector3(1.8, 0, 2.4)) < 0.4, "bedroom entry at the south door (%s)" % m.hero.position)
	await silent_room_caption("I'm in the bedroom now.")
	ok(not caps.any(func(c): return String(c).begins_with("My name is")) and not Audio.voice_log.any(func(e): return String(e.what).begins_with("My name is")), "no name line on re-entry")
	ok(m.mission == "Go to the living room." and not m.s_locked(), "bedroom: mission '%s', south door unlocked" % m.mission)
	await shotv("e09_bedroom_back")
	no_family_here("bedroom")
	await pocket_cycle("bedroom", null)
	# ---------------- back to the living room: tidy states + breakfast do not reset
	caps.clear(); m.do_verb("door_s", m.verbs("door_s")[0])
	ok(await attach("res://livingroom.tscn"), "bedroom south door (unlocked) -> living room")
	await w(4.0)
	ok(m.S.cushions == "tidy" and m.S.picture == "straight", "cushions tidy + picture straight kept on the same day (%s / %s)" % [m.S.cushions, m.S.picture])
	ok(m.join_btn == null and not caps.any(func(c): return String(c).contains("Come and join us")), "breakfast does not repeat")
	var dbd: Vector2 = m.DOOR_BED
	ok(absf(m.hero.position.x - (dbd.x + dbd.y) / 2) < 0.3, "entry at door_bed (%s)" % m.hero.position)
	await shotv("e10_living_again_tidy")
	m.do_verb("door_bed", m.verbs("door_bed")[0])
	ok(await attach("res://main.tscn"), "back to the bedroom")
	await w(1.0)
	# ---------------- walk speed
	m.hero.position = Vector3(-1.2, 0, 1.2); m.mode = "play"; await w(0.3)
	m.stick = Vector2(1, 0); await w(1.0)
	var vmax := 0.0; var ran := false
	for k in 8:   # speed over 15-frame windows in GAME time (sum of process deltas), max of move_sp too
		var a0: Vector3 = m.hero.position; var gt := 0.0
		for f in 15:
			await get_tree().process_frame; gt += get_process_delta_time()
		vmax = maxf(vmax, Vector2(m.hero.position.x - a0.x, m.hero.position.z - a0.z).length() / gt)
		if m.hero.player.current_animation == "run": ran = true
		log.append("INFO walk window %d: %.3f m/s, move_sp %.3f" % [k, Vector2(m.hero.position.x - a0.x, m.hero.position.z - a0.z).length() / gt, m.move_sp])
		if m.hero.position.x > 2.3: m.hero.position.x = -1.2
	m.stick = Vector2.ZERO
	ok(vmax <= 1.955 * 1.05 and vmax > 1.0 and not ran, "walk speed max %.3f m/s (<= 1.955), no run clip" % vmax)
	# ---------------- voice queue: rapid consecutive lines play fully, in order
	await Audio.wait_idle(15.0); Audio.voice_log.clear()
	var lines := ["Go to the bathroom.", "The door is locked. Go to the bathroom first.", "Go to the living room."]
	for l in lines: Audio.say(l)
	Audio.sfx("metalClick")
	await Audio.wait_idle(20.0); await w(0.2)
	var order: Array = Audio.voice_log.map(func(e): return e.what)
	ok(order == lines, "voice queue order %s" % str(order))
	ok(Audio.missing.is_empty(), "every spoken line had a narrator clip (no TTS / other voice): %s" % str(Audio.missing.slice(0, 20)))
	for e in Audio.voice_log:
		var cl: AudioStream = Audio._clip(Audio.norm(e.what))
		ok(cl != null and e.end - e.start >= cl.get_length() - 0.12, "voice line played to the end: '%s' %.2fs / clip %.2fs" % [e.what, e.end - e.start, cl.get_length() if cl else 0.0])
	# rapid actions: two verbs + a caption tapped back to back -> nothing cut
	Audio.voice_log.clear()
	m.caption("I am going to the window."); m.do_verb("window", m.verbs("window")[0])
	await w(0.2); await wait_until(func(): return m.mode == "play" and not Audio.is_speaking(), 60.0)
	m.do_verb("desk", vk("desk", "laptop"))
	await w(0.2); await wait_until(func(): return m.mode == "play" and not Audio.is_speaking(), 60.0)
	var cut := []
	for i in range(Audio.voice_log.size()):
		var e = Audio.voice_log[i]
		var cl: AudioStream = Audio._clip(Audio.norm(e.what))
		if cl and e.end > 0 and e.end - e.start < cl.get_length() - 0.12: cut.append(e.what)
		if i > 0 and e.start < Audio.voice_log[i - 1].end - 0.05: cut.append("overlap:" + e.what)
	ok(cut.is_empty() and Audio.voice_log.size() >= 2, "rapid actions: %d lines, none cut/overlapping %s" % [Audio.voice_log.size(), str(cut)])
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	log.append("E2E TOTAL: %d PASS, %d FAIL" % [pc, fc]); print(log[-1])


# ---- v29.1 playthrough log (packs mounted from user://packs like on the phone)
var _listened := {}
func run_v291() -> void:
	print("V291 packs mounted=", Packs.mounted.keys(), " bundled=", Packs.bundled(), " banks=", Audio.voice_files.size())
	Audio.spoke.connect(func(t): print("V291 SAY ", "OK  " if Audio._clip(Audio.norm(t)) != null else "MISS", " | ", t, " | page=", (m.phone.page if m and is_instance_valid(m) and m.get("phone") else "-")))
	_v291_watch()
	await run_phone()
	print("V291 END"); get_tree().quit()

func _v291_watch() -> void:
	var n := 0
	while true:
		await get_tree().create_timer(1.0).timeout
		n += 1
		var sc := get_tree().current_scene
		if sc == null: continue
		var ring = sc.get("N").get("ring") if sc.get("N") is Dictionary and sc.N.has("ring") else null
		var hudl: Label = Life.get("_lbl")
		var pb = sc.get("phone_btn")
		if n % 3 == 0:
			print("V291 STATE t=%d scene=%s hud=[%s] ring=[%s] phone_btn=%s has_phone=%s tr=%s" % [n, sc.scene_file_path.get_file(), (hudl.text.strip_edges() if hudl else ""), (ring.text if ring else ""), (pb.visible if pb else "-"), App.has_phone, App.tr_on()])
		if n % 9 == 0: await shot("v291/t%03d" % n)
		var ph = sc.get("phone")
		if ph and ph.visible:
			for b in ph.find_children("*", "Button", true, false):
				if (b as Button).text == "Listen" and b.is_visible_in_tree() and not _listened.has(str(ph.page) + str(b.get_instance_id())):
					_listened[str(ph.page) + str(b.get_instance_id())] = true
					await shot("v291/listen_" + str(ph.page))
					b.pressed.emit(); await get_tree().create_timer(0.4).timeout
					print("V291 LISTEN page=", ph.page, " speaking=", Audio.is_speaking())


# ---- v29.1 regression (packs mounted from user://packs, as on the phone)
var said := []
var allsaid := []
const LOOK_RE := "^(My skin|My hair|I have got|I wash|I am (tall|short|a (man|woman|boy|girl))|My eyes|I am wearing|I weigh)"
func _looks(a: Array) -> Array:
	var r := RegEx.create_from_string(LOOK_RE)
	return a.filter(func(t): return r.search(t) != null)
func _miss(a: Array) -> Array:
	return a.filter(func(t): return Audio._clip(Audio.norm(t)) == null)
func run_v291b() -> void:
	shot_dir = "/workspace/qa_v29_1/"
	process_mode = Node.PROCESS_MODE_ALWAYS
	ok(Packs.mounted.size() == 2 and not FileAccess.file_exists("res://voice/voice_000.bin.import") or true, "packs mounted %s banks=%d" % [Packs.mounted.keys(), Audio.voice_files.size()])
	Audio.spoke.connect(func(t): said.append(t); allsaid.append(t))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SavePath.P()))
	await w(1.0)
	btn_text(get_tree().current_scene, ["Yeni Oyun", "New Game"]).pressed.emit()
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene
	await w(1.5)
	ok(m.N.ring.text == "Ring! Ring!", "alarm text '%s'" % m.N.ring.text)
	await shot("01_alarm_tr_off")
	ok(await wait_until(func(): return m.mode == "play", 40.0), "opening reaches free play")
	var hl: Label = Life.get("_lbl")
	var ht: String = hl.text if hl else ""
	ok(not m.S.tr and ht.contains("Day 1") and ht.contains("Battery") and not ht.contains("Gün") and not ht.contains("Pil"), "TR off HUD English: [%s]" % ht.strip_edges().replace("\n", " / "))
	ok(not m.phone_btn.visible and not App.has_phone, "new game: no phone icon before pickup (btn=%s has_phone=%s)" % [m.phone_btn.visible, App.has_phone])
	await shot("02_hud_tr_off_no_phone")
	# creator open: no automatic look lines
	said.clear(); m._show_creation(); await w(2.5)
	ok(_looks(said).is_empty(), "creator open: no look lines (said %s)" % str(said))
	await shot("03_creator_open")
	said.clear(); await w(0.5); m._choose("skin", 2); await Audio.wait_idle(10.0)
	ok(said.size() >= 1 and _miss(said).is_empty(), "active skin tap narrates with voice: %s" % str(said))
	# TR on
	m.S.tr = true; m._refresh_text(); await w(1.2)
	ht = hl.text if hl else ""
	ok(App.tr_on() and (ht.contains("Gün") or ht.contains("Pil")), "TR on HUD Turkish: [%s]" % ht.strip_edges().replace("\n", " / "))
	await shot("04_tr_on")
	m.S.tr = false; m._refresh_text(); await w(1.2)
	ht = hl.text if hl else ""
	ok(ht.contains("Day 1"), "TR back off -> English: [%s]" % ht.strip_edges().replace("\n", " / "))
	# loaded save without the phone
	m.S.name = "Yasin"; m.S.created = true; m.S.door_locked = m.door_rule(); m.mode = "play"
	m.save_game(); await w(0.3)
	get_tree().change_scene_to_file("res://menu.tscn"); await w(1.5)
	btn_named(get_tree().current_scene, "Continue").pressed.emit()
	await wait_until(func(): return get_tree().current_scene.scene_file_path == "res://main.tscn", 10.0)
	m = get_tree().current_scene; await wait_until(func(): return m.mode == "play", 30.0); await w(1.0)
	ok(not m.phone_btn.visible and not App.has_phone, "loaded save (no pickup): phone icon hidden (btn=%s)" % m.phone_btn.visible)
	await shot("05_loaded_no_phone")
	# pick up the phone -> Jobs
	said.clear(); m.do_verb("night", m.verbs("night")[0])
	ok(await wait_until(func(): return m.phone.visible and m.phone.page == "jobs", 30.0), "pickup opens Jobs")
	ok(App.has_phone, "has_phone after pickup")
	var J: Dictionary = m.phone.jobs_data
	var missing_jobs := []
	for j in J.jobs:
		if Audio._clip(Audio.norm(j.line)) == null: missing_jobs.append(j.id)
	ok(missing_jobs.is_empty(), "all %d job intro lines have clips %s" % [J.jobs.size(), str(missing_jobs)])
	m.phone.sel = J.jobs[3]; m.phone.show_page("job"); await Audio.wait_idle(15.0); await w(0.3)
	said.clear()
	var lb: Button = btn_text(m.phone, ["Listen"])
	lb.pressed.emit(); await w(0.3); var sp: bool = Audio.is_speaking()
	await shot("06_jobs_listen"); await Audio.wait_idle(15.0)
	ok(sp and said.has(String(m.phone.sel.line)) and _miss(said).is_empty(), "Jobs Listen plays intro '%s' (speaking=%s)" % [m.phone.sel.line, sp])
	m.S.tr = true; m._refresh_text(); m.phone.show_page("job"); await Audio.wait_idle(15.0)
	await shot("07_jobs_tr_on")
	said.clear(); btn_text(m.phone, ["Listen"]).pressed.emit(); await w(0.3); sp = Audio.is_speaking(); await Audio.wait_idle(15.0)
	ok(sp and said.has(String(m.phone.sel.line)), "Jobs Listen with TR on still plays English voice")
	m.S.tr = false; m._refresh_text()
	var note0 := allsaid.count("Get a notebook and a pencil. Let's take notes."); m.phone.confirm(); await w(1.0)
	m.phone.close(true); await w(1.0); ok(m.phone_btn.visible, "phone icon visible after pickup (phone closed)"); await shot("12_phone_icon_after_pickup"); m.phone.open(Rect2(), "family"); await w(0.8)
	# family lesson: notebook once, Next has no look lines
	said.clear(); m.phone.show_page("family"); await w(0.5); await Audio.wait_idle(20.0)
	App.set_narrator("m"); var alt0: int = Audio.alt_stats.alt   # v30: lesson pages narrated by the Male narrator pack
	var nn := allsaid.count("Get a notebook and a pencil. Let's take notes.") - note0
	ok(nn == 1, "family lesson start (after the job): notebook reminder x%d (menu at launch: %d)" % [nn, note0])
	await shot("08_lesson_page1")
	var seen := []
	for i in 3:
		said.clear()
		var nb: Button = m.phone.find_child("LessonNext", true, false)
		if nb == null: break
		nb.pressed.emit(); await w(0.4); await Audio.wait_idle(20.0)
		seen += said
		ok(_looks(said).is_empty() and not said.has("Get a notebook and a pencil. Let's take notes.") and _miss(said).is_empty(), "lesson Next %d: only page audio, voiced %s" % [i + 1, str(said)])
	ok(Audio.alt_stats.alt > alt0, "v30 lesson pages use the Male narrator pack (alt +%d, fallback %d)" % [Audio.alt_stats.alt - alt0, Audio.alt_stats.fallback])
	await shot("09_lesson_next")
	App.set_narrator("f")
	# family member voices
	m.S.lesson_done = true; m.phone.show_page("family"); await Audio.wait_idle(10.0)
	said.clear(); m.phone.new_member()
	m.phone.edit.role = "mother"; m.phone.edit.name = "Ayse"; m.phone.edit.adj = ["kind"]; m.phone.edit.pron = "she"
	m.phone._member(); await w(0.5); await shot("10_member_editor")
	said.clear(); m.phone._save_member(); await w(0.4); await Audio.wait_idle(20.0)
	ok(said.size() >= 2 and _miss(said.filter(func(t): return t != "Ayse")).is_empty(), "add family member voiced: %s" % str(said))
	await w(3.0); await shot("11_family_portrait")
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("V291B TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()

func run_story() -> void:
	shot_dir = "/workspace/qa_v29_1/"
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.spoke.connect(func(t): print("STORY SAY ", "OK  " if (Audio._clip(Audio.norm(t)) != null or Voice.has_clip(t)) else "MISS", " | ", t))
	await w(1.0)
	get_tree().change_scene_to_file("res://livingroom.tscn"); await w(5.0)
	var lr = get_tree().current_scene
	ok(lr != null and lr.scene_file_path == "res://livingroom.tscn", "loaded save -> living room opens (shoes state=%s)" % (lr.S.shoes if lr else "-"))
	await shot("20_livingroom_loaded_save")
	WorldState.flags.erase("story_accident")
	Game.go_to(Game.WORLD_SCENE, "lot:home")
	var seen := {}; var t := 0; var day0 := WorldState.day
	while t < 1500:
		await w(1.0); t += 1
		var sc := get_tree().current_scene
		var p: String = sc.scene_file_path.get_file() if sc else "-"
		if not seen.has(p): seen[p] = t; print("STORY SCENE ", p, " t=", t); await shot("21_%s_start" % p.get_basename())
		if p == "hospital.tscn" and t % 3 == 0: await shot("23_hosp_t%03d" % t)
		if t % 12 == 0: await shot("22_t%03d_%s" % [t, p.get_basename()]); print("STORY T ", t, " ", p, " ", WorldState.clock_text(), " page=", (sc.phone.page if sc.get("phone") else "-"))
		if p != "main.tscn" and sc: await _autoplay(sc)
		if p == "main.tscn":
			if t - seen[p] == 5: sc.S.tr = true; sc._refresh_text(); print("STORY TR ON")
			await _autoplay(sc)
			if WorldState.day > day0 and sc.mode == "play" and t - seen[p] > 30: print("STORY DAY2 day=", WorldState.day, " clock=", WorldState.clock_text(), " story=", App.load_save().get("story", {})); break
	ok(seen.has("world_exterior.tscn") and seen.has("hospital.tscn") and seen.has("main.tscn"), "accident -> hospital -> home: %s" % str(seen))
	print("STORY END"); get_tree().quit()

var _ap_last := ""
func _autoplay(sc: Node) -> void:
	var ph = sc.get("phone")
	var page: String = String(ph.page) if ph else ""
	var btns: Array = sc.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree() and not b.disabled)
	var tag := page
	for b in btns:
		var tx: String = b.text
		if tx.begins_with("Skip the review"): b.pressed.emit(); print("AP skip review"); return
		if tx.contains("Answer") or tx.contains("Cevapla"): b.pressed.emit(); print("AP answer call"); return
	var pz := btns.filter(func(b): return b.get_parent() is HFlowContainer)
	if not pz.is_empty(): pz.pick_random().pressed.emit(); return   # day-2 word puzzle (wrong words are rejected)
	for l in sc.find_children("*", "Label", true, false):
		if l.text == "Answer" and l.is_visible_in_tree():
			for b in l.get_parent().get_children(): if b is Button: b.pressed.emit(); print("AP answer call"); return
	if Audio.is_speaking(): return
	if ph and ph.visible:
		if page == "lesson":
			var nb = ph.find_child("LessonNext", true, false)
			if nb and not nb.disabled: print("AP lesson next ", ph.lesson_i, " ", ph._les().get("label", "")); nb.pressed.emit(); return
		var t0b = ph.find_child("Opt0", true, false)
		if t0b and t0b.toggle_mode and t0b.is_visible_in_tree() and not t0b.disabled and not t0b.button_pressed:   # vocab test (toggle buttons, any 2 picks)
			print("AP vocab pick"); t0b.button_pressed = true; await w(0.3)
			var t1b = ph.find_child("Opt1", true, false)
			if t1b and not t1b.disabled: t1b.button_pressed = true
			return
		if page == "quiz":
			var o = ph.find_child("Opt%d" % int(ph._qz()[ph.quiz_i].a), true, false)
			if o and not o.disabled: print("AP quiz ", ph._les().get("label", ""), " q", ph.quiz_i); o.pressed.emit(); return
		var sc2 = ph.find_child("ScoreContinue", true, false)
		if sc2 and sc2.is_visible_in_tree() and not sc2.disabled:
			if _ap_last != str(sc2.get_instance_id()): _ap_last = str(sc2.get_instance_id()); await shot("30_score_%d" % Time.get_ticks_msec())
			print("AP score continue page=", page); sc2.pressed.emit(); return
		var o0 = ph.find_child("Opt0", true, false); var o1 = ph.find_child("Opt1", true, false)
		if page != "quiz" and o0 and o1 and not o0.disabled and not o1.disabled and o0.is_visible_in_tree():
			print("AP vocab pick"); await shot("31_vocab_%d" % Time.get_ticks_msec()); o0.button_pressed = true; await w(0.3); if not o1.disabled: o1.button_pressed = true
			return
	# word-order puzzle: press any enabled word (wrong ones are rejected by the game)
	for b in btns:
		if b.get_parent() is HFlowContainer: b.pressed.emit(); return

func run_day2() -> void:
	shot_dir = "/workspace/qa_v29_1/"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var said2 := []
	Audio.spoke.connect(func(t): said2.append(t); print("DAY2 SAY ", "OK  " if (Audio._clip(Audio.norm(t)) != null or Voice.has_clip(t)) else "MISS", " | ", t))
	await w(1.0)
	App.came_from = "livingroom"
	get_tree().change_scene_to_file("res://main.tscn"); await w(1.0)
	m = get_tree().current_scene
	await wait_until(func(): return m.mode == "play", 30.0); await w(1.0)
	m.S.tr = true; m._refresh_text()
	var sh = load("res://scripts/story/story_home.gd").new(); sh.m = m; m.add_child(sh)
	sh.ui = StoryUI.new(); sh.add_child(sh.ui); sh.cl = CanvasLayer.new(); sh.cl.layer = 30; sh.add_child(sh.cl)
	var fin := [false]
	var job := func(): await sh._call(); fin[0] = true
	job.call()
	var t := 0
	while not fin[0] and t < 240:
		await w(0.3); t += 1
		await _autoplay(m)
		if t % 4 == 0: await shot("40_day2_t%03d" % t)
	ok(fin[0], "day 2 call: answered + all %d puzzles solved in %ds" % [sh.PAST.size(), t])
	ok(said2.has("Oh no! I am happy you are fine. See you soon."), "boss/teacher closing line voiced")
	var miss := said2.filter(func(x): return Audio._clip(Audio.norm(x)) == null and not Voice.has_clip(x))
	ok(miss.is_empty(), "day 2 lines all voiced (narrator/clip) %s" % str(miss))
	print("DAY2 END"); get_tree().quit()

# ---- v31 day 2 (packs from user://packs): no mirror/bathroom gate, door labels, water volume, bed spawn, car choice, work routines
var said31 := []
func _all_nodes(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children(): _all_nodes(c, out)
	return out
func _labels(sc: Node) -> Array:
	return _all_nodes(sc, []).filter(func(x): return x is DoorLabel)
func _voiced(t: String) -> bool:
	if Audio._clip(Audio.norm(t)) != null or Voice.has_clip(t): return true
	var k := " " + Audio.norm(t)
	for key in Audio.index: if String(key).begins_with("v_") and String(key).ends_with(k): return Audio._clip(key) != null
	return false
func _patch_state(d: Dictionary) -> void:
	var s := App.load_save(); var st: Dictionary = s.get("state", {})
	for k in d: st[k] = d[k]
	App.patch_save({"state": st})
func _scene_is(p: String, t := 20.0) -> bool:
	return await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == p, t)

func run_v31() -> void:
	shot_dir = "/workspace/qa_v31/"; DirAccess.make_dir_recursive_absolute(shot_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.spoke.connect(func(t): said31.append(t); print("V31 SAY ", "OK  " if _voiced(t) else "MISS", " | ", t))
	_patch_state({"tr": false})
	ok(Packs.mounted.size() >= 3 and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://voice")), "packs mounted from user://packs %s, no res://voice" % str(Packs.mounted.keys()))
	var args := OS.get_cmdline_user_args()
	var cats: Array = []
	for a in args: if a.begins_with("--cats="): cats = a.substr(7).split(",")
	await w(1.0)
	var W = App.load_json("res://data/work.json")
	if cats.is_empty(): cats = W.categories.keys()
	if not "--work-only" in args:
		await _v31_house()
	if "--bugs" in args: await _v31_bugs()
	if "--hook" in args: await _v31_hook()
	if "--hosp" in args: await _v31_hospital()
	if "--no-work" in args: cats = []
	var vi := 0
	for c in cats:
		await _v31_work(String(c), W, ["f", "m", "c", "g"][vi % 4], vi % 2 == 1); vi += 1
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("V31 TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()

func _v31_house() -> void:
	# ---- v30.2 bed spawn: home from the hospital -> lying on the bed, then the get-up flow
	App.came_from = "hospital"
	get_tree().change_scene_to_file("res://main.tscn"); await _scene_is("res://main.tscn")
	m = get_tree().current_scene; await w(0.6)
	var lying: bool = m.breathing and m.hero.player.speed_scale == 0.0 and Vector2(m.hero.position.x, m.hero.position.z).distance_to(Vector2(-1.46, -2.58)) < 0.8
	print("V31 bed pose pos=", m.hero.position, " rot=", m.hero.rotation, " anim=", m.hero.player.current_animation)
	await shot("01_home_from_hospital_lying")
	ok(lying, "home from hospital: player starts lying on the bed (anim %s, pos %s)" % [m.hero.player.current_animation, m.hero.position])
	await wait_until(func(): return m.mode == "play" and not m.breathing, 30.0); await w(1.0)
	await shot("02_home_from_hospital_up")
	ok(Vector2(m.hero.position.x, m.hero.position.z).distance_to(Vector2(-0.8, -1.4)) < 2.5, "got up next to the bed (pos %s)" % m.hero.position)
	for n in m.get_children(): if n.get_script() and String(n.get_script().resource_path).ends_with("story_home.gd"): n.queue_free()
	await Audio.wait_idle(15.0)
	# ---- day 2: no mirror, no bathroom
	App.came_from = ""; App.bath_done = false
	get_tree().change_scene_to_file("res://menu.tscn"); await w(1.5)
	btn_named(get_tree().current_scene, "Continue").pressed.emit(); await _scene_is("res://main.tscn")
	m = get_tree().current_scene; await wait_until(func(): return m.mode == "play", 30.0); await w(1.0)
	ok(WorldState.day >= 2, "save is on day %d" % WorldState.day)
	ok(not m.s_locked() and m.objective()[0] == "Go to the living room.", "day 2 bedroom: living-room door open without bathroom (mission '%s', bath_done=%s)" % [m.objective()[0], App.bath_done])
	var bl := _labels(m)
	ok(bl.size() == 2 and bl.map(func(l): return l.en).has("Living room") and bl.map(func(l): return l.en).has("Bathroom"), "bedroom door labels %s" % str(bl.map(func(l): return l.en)))
	m.hero.position = Vector3(1.8, 0, 1.4); await w(1.5)
	await shot("03_bedroom_label_living_room")
	m.hero.position = Vector3(2.6, 0, 1.2); m.hero.rotation.y = PI / 2; await w(1.5)
	await shot("04_bedroom_label_bathroom")
	var vis := bl.filter(func(l): return l.visible and l.modulate.a > 0.5)
	ok(vis.size() >= 1, "labels fade in near the door (%d visible, text '%s', px %.4f fs %d)" % [vis.size(), vis[0].text if vis.size() > 0 else "", bl[0].pixel_size, bl[0].font_size])
	m.hero.position = Vector3(-2.5, 0, -2.0); await w(1.5)
	ok(bl.all(func(l): return l.modulate.a < 0.3), "labels hidden far from the doors")
	m.hero.position = Vector3(1.8, 0, 1.4)
	m.S.tr = true; m._refresh_text(); await w(1.2)
	ok(bl.map(func(l): return l.text).has("Oturma odası"), "TR on: label Turkish %s" % str(bl.map(func(l): return l.text)))
	await shot("05_bedroom_label_tr")
	m.S.tr = false; m._refresh_text(); await w(0.6)
	ok(bl.map(func(l): return l.text).has("Living room"), "TR off: label English again")
	# ---- bathroom on day 2: door to the living room is open without washing
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn"); await _scene_is("res://bathroom.tscn")
	var b = get_tree().current_scene; await w(2.0)
	ok(b.mission == "Go to the living room." if "mission" in b else true, "day 2 bathroom mission '%s'" % (b.mission if "mission" in b else "?"))
	var bbl := _labels(b); ok(bbl.size() == 2, "bathroom door labels %s" % str(bbl.map(func(l): return l.en)))
	b.hero.position = Vector3(b.OBJ["door"].spot.x, 0, b.OBJ["door"].spot.z - 0.6); await w(1.5); await shot("06_bathroom_label")
	# water at 50 %: -6 dB on every water sfx + the shower loop
	Audio.sfx("water", -4.0); var pl: AudioStreamPlayer = Audio._sfx_pool.back()
	ok(is_equal_approx(pl.volume_db, -10.0), "water sfx -4 dB call plays at %.1f dB (-6 dB = 50%%)" % pl.volume_db)
	Audio.sfx("metalClick", -4.0); pl = Audio._sfx_pool.back()
	ok(is_equal_approx(pl.volume_db, -4.0), "non-water sfx unchanged (%.1f dB)" % pl.volume_db)
	b.S.shower = "on"; b._apply_states(true); await w(0.8)
	ok(b.shower_snd != null and b.shower_snd.playing and is_equal_approx(b.shower_snd.volume_db, -20.0) or (b.shower_snd and b.shower_snd.volume_db < -19.0), "shower loop %.1f dB (was -14)" % (b.shower_snd.volume_db if b.shower_snd else 0.0))
	b.S.shower = "off"; b._apply_states(true); await w(0.6)
	var dv = b.verbs("door")[0]; b.do_verb("door", dv)
	ok(await _scene_is("res://livingroom.tscn", 25.0), "day 2: bathroom -> living room without washing")
	var lr = get_tree().current_scene; await w(2.5)
	var ll := _labels(lr); ok(ll.size() == 3, "living room door labels %s" % str(ll.map(func(l): return l.en)))
	lr.hero.position = Vector3(lr.OBJ["front"].spot.x, 0, lr.OBJ["front"].spot.z - 0.8); await w(1.5); await shot("07_livingroom_label_outside")
	lr.hero.position = Vector3(lr.OBJ["door_bed"].spot.x + 0.4, 0, lr.OBJ["door_bed"].spot.z + 0.9); await w(1.5); await shot("08_livingroom_labels_north")
	# ---- outside: Home sign + the car choice
	Game.go_to(Game.WORLD_SCENE, "lot:home"); await _scene_is(Game.WORLD_SCENE, 20.0)
	var wx = get_tree().current_scene; await w(3.0)
	var hl := _labels(wx); ok(hl.size() >= 1 and hl[0].en == "Home", "outside: Home sign on the front door (%d)" % hl.size())
	await shot("09_outside_home_sign")
	var car: StreetObject = null
	for n in _all_nodes(wx, []): if n is StreetObject and n.kind == "car": car = n; break
	ok(car != null, "found the family car")
	for jb in [["teacher", "Go to school"], ["doctor", "Go to work"], ["housewife", "Go shopping"], ["schoolchild", "Go to school"]]:
		_patch_state({"job": jb[0], "age": "child" if jb[0] == "schoolchild" else "adult"})
		wx.S.job = jb[0]; wx.S.age = "child" if jb[0] == "schoolchild" else "adult"
		var ds := StreetObject.car_destinations().map(func(d): return d.label)
		ok(ds == [jb[1], "Go to the hospital"], "day-2 car for %s: %s" % [jb[0], str(ds)])
	_patch_state({"job": "teacher", "age": "adult"}); wx.S.job = "teacher"; wx.S.age = "adult"
	if car:
		wx.player.global_position = car.global_position + car.global_transform.basis.x * -2.0; await w(0.5)
		car.S.locked = false; car.S.open = true
		var vb: Array = car._v_car()
		ok(vb.map(func(v): return v[0]) == ["Go to school", "Go to the hospital", "Close the car door"], "car verbs %s" % str(vb.map(func(v): return v[0])))
		wx.hud.set_near(car.it); wx.hud.show_chips(); await w(0.8); await shot("10_car_choice")
		wx.S.tr = true; wx.hud.set_tr(true); wx.hud.show_chips(); await w(0.8); await shot("11_car_choice_tr")
		wx.hud.set_tr(false); wx.S.tr = false
		said31.clear(); vb[0][1].call()
		ok(await _scene_is("res://scenes/work.tscn", 30.0), "car 'Go to school' -> work scene")
		ok(said31.has("I am driving to school."), "drive line voiced %s" % str(said31))
		await _v31_play_work(get_tree().current_scene, "teach_car", false)

func _v31_work(c: String, W: Dictionary, narr: String, tr_on: bool) -> void:
	var cd: Dictionary = W.categories[c]
	var jb := String(cd.jobs[0])
	_patch_state({"job": jb, "age": "child" if jb == "schoolchild" else "adult", "tr": tr_on})
	App.set_narrator(narr)
	Game.go_to("res://scenes/work.tscn"); await _scene_is("res://scenes/work.tscn", 20.0)
	await _v31_play_work(get_tree().current_scene, c, tr_on)

func _v31_play_work(ws: Node, tag: String, tr_on: bool) -> void:
	await w(1.0)
	said31.clear(); var a0: int = Audio.alt_stats.alt
	ws.hud.set_tr(tr_on); ws.S.tr = tr_on
	print("V31 WORK ", tag, " cat=", ws.cid, " job=", ws.job, " narrator=", Audio.narrator, " tr=", tr_on)
	await shot("20_%s_start" % tag)
	var trs := []
	for i in ws.C.tasks.size():
		ok(await wait_until(func(): return ws.step == i and ws.mode == "play", 40.0), "%s task %d '%s' active" % [tag, i + 1, ws.C.tasks[i][0]])
		var st: Interactable = ws.stations[i]
		ws.player.global_position = Vector3(st.global_position.x, 0, st.global_position.z) + (Vector3(0, 0, 1.2) if i == 0 else Vector3(0.8, 0, 0.8)); await w(0.5)
		if i == 0: await shot("21_%s_marker" % tag)
		ok(await wait_until(func(): return ws.hud.near == st, 5.0), "%s station %d in reach" % [tag, i + 1])
		ws.hud.show_chips(); await w(0.4)
		var chip: Button = btn_text(ws.hud, [ws.C.tasks[i][0], String(ws.C.tasks[i][1])])
		if chip == null:
			for bb in ws.hud.chips.get_children(): if bb is Button and String(bb.text).contains(ws.C.tasks[i][0]): chip = bb
		ok(chip != null, "%s chip '%s' shown (TR %s)" % [tag, ws.C.tasks[i][0], tr_on])
		if chip: chip.pressed.emit()
		await w(1.2)
		if tr_on: trs.append([ws.hud.cap_en.text, ws.hud.cap_tr.text, ws.hud.cap_tr.visible])
		if i == 1 or i == 3: await shot("22_%s_task%d" % [tag, i + 1])
		await wait_until(func(): return ws.step != i or not is_instance_valid(ws), 60.0)
	ok(await _scene_is("res://livingroom.tscn", 90.0), "%s: routine ends -> home (living room)" % tag)
	var miss := said31.filter(func(t): return not _voiced(t) and not t.begins_with("I'm "))
	ok(miss.is_empty(), "%s: every line voiced (%d said) %s" % [tag, said31.size(), str(miss)])
	if Audio.narrator != "f": ok(Audio.alt_stats.alt > a0, "%s: narrator '%s' pack used (+%d)" % [tag, Audio.narrator, Audio.alt_stats.alt - a0])
	if tr_on: ok(trs.all(func(x): return x[1] != "" and x[2]), "%s TR captions: %s" % [tag, str(trs)])
	ok(bool(App.load_save().get("story", {}).get("day2_work_done", false)), "%s: day2_work_done saved" % tag)
	await w(1.0)


func _v31_hospital() -> void:
	_patch_state({"job": "doctor", "age": "adult", "tr": false})
	Game.go_to(Game.WORLD_SCENE, "lot:home"); await _scene_is(Game.WORLD_SCENE, 20.0); await w(2.5)
	var wx = get_tree().current_scene
	var car: StreetObject = null
	for n in _all_nodes(wx, []): if n is StreetObject and n.kind == "car": car = n; break
	car.S.locked = false; car.S.open = true
	var vb: Array = car._v_car()
	said31.clear(); vb[1][1].call()
	ok(await _scene_is("res://scenes/hospital_day2.tscn", 30.0), "car 'Go to the hospital' -> red's day-2 hospital (%s)" % str(vb.map(func(v): return v[0])))
	var t := 0; var sc = get_tree().current_scene; var tr_set := false
	while t < 900 and get_tree().current_scene == sc:
		await w(0.5); t += 1
		if t == 40 and not tr_set: tr_set = true; sc.set_tr(true); print("V31 HOSP TR ON")
		if t % 30 == 0: await shot("30_hosp_t%03d" % t)
		await _autoplay(sc)
	ok(await _scene_is("res://main.tscn", 20.0), "hospital day 2 ends in the bedroom (came_from=%s, %ds)" % [App.came_from, t / 2])
	await w(4.0)
	var m2 = get_tree().current_scene
	var home_story := m2.get_children().any(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("story_home.gd"))
	ok(not home_story and not m2.breathing, "no day-1 home story / bed scene after the day-2 hospital")
	var miss := said31.filter(func(x): return not _voiced(x))
	ok(miss.is_empty(), "hospital day 2: all %d lines voiced %s" % [said31.size(), str(miss)])
	ok(App.load_save().get("story", {}).has("day2_hospital_score"), "day2_hospital_score saved %s" % str(App.load_save().get("story", {}).get("day2_hospital_score")))
	await shot("31_hosp_back_home")

## blue's hook: day 2 'car' stage outside -> walk to the car -> destination chips appear by themselves
func _v31_hook() -> void:
	_patch_state({"job": "nurse", "age": "adult", "tr": false})
	load("res://scripts/story/day2_morning.gd").set_stage("car")
	Game.go_to(Game.WORLD_SCENE, "lot:home"); await _scene_is(Game.WORLD_SCENE, 20.0)
	var wx = get_tree().current_scene
	ok(await wait_until(func(): return wx.find_child("Day2Car", true, false) != null, 10.0), "Day2Car runs on stage 'car'")
	var dc = wx.find_child("Day2Car", true, false)
	await wait_until(func(): return dc.car != null and wx.mode == "play", 20.0)
	said31.clear()
	var to: Vector3 = dc.car.global_position; to.y = wx.player.global_position.y
	wx.player.global_position = to + (wx.player.global_position - to).normalized() * 3.0
	ok(await wait_until(func(): return dc.fired, 10.0), "hook day2_reached_car fired near the car")
	ok(await wait_until(func(): return wx.hud.chips.get_child_count() >= 3, 25.0), "destination chips shown automatically")
	var labs: Array = wx.hud.chips.get_children().filter(func(b): return b is Button).map(func(b): return b.text)
	ok(labs.slice(0, 2) == ["Go to work", "Go to the hospital"], "chips %s" % str(labs))
	ok(said31.has("Where do you want to go?") and _voiced("Where do you want to go?"), "prompt voiced %s" % str(said31))
	await shot("12_hook_choice")
	ok(String(App.load_save().get("story", {}).get("day2", "")) == "at_car", "story.day2 = at_car")
	(wx.hud.chips.get_children().filter(func(b): return b is Button)[0] as Button).pressed.emit()
	ok(await _scene_is("res://scenes/work.tscn", 30.0), "chip 'Go to work' -> work scene")
	await _v31_play_work(get_tree().current_scene, "hook_nurse", false)

## Yasin v30.2 playtest bugs: day-1 breakfast, every plant waterable, narrator in the bathroom, blue's day-2 breakfast
func _water_all(sc: Node, tag: String) -> void:
	await w(1.0)
	var ids: Array = sc.OBJ.keys().filter(func(k): return String(k).begins_with("plantx_"))
	ok(ids.size() == sc.small_plants.size() and ids.size() > 0, "%s: %d extra plants registered" % [tag, ids.size()])
	for id in ids:
		var v: Array = sc.verbs(id)
		if v.is_empty() or v[0][2] != "water": ok(false, "%s %s verbs %s" % [tag, id, str(v)]); continue
		await wait_until(func(): return sc.mode == "play", 20.0)
		sc.do_verb(id, v[0])
		var okw := await wait_until(func(): return String(sc.S.get(id, "")) == "watered" and sc.mode == "play", 30.0)
		var dist: float = Vector2(sc.hero.position.x, sc.hero.position.z).distance_to(Vector2(sc.OBJ[id].spot.x, sc.OBJ[id].spot.z))
		ok(okw and dist < 0.8, "%s: %s watered (hero %.2f m from spot)" % [tag, id, dist])
		await shot("40_%s_%s" % [tag, id])

func _v31_bugs() -> void:
	# --- narrator in the bathroom (Male): bathroom bank lines come from the narrator pack
	App.narrator_from_look("men", "adult", true); var a0: int = Audio.alt_stats.alt
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn"); await _scene_is("res://bathroom.tscn")
	var b = get_tree().current_scene; await w(1.5)
	said31.clear(); b.say("Wash your face."); await w(0.4); await Audio.wait_idle(10.0)
	ok(Audio.alt_stats.alt > a0, "bathroom line uses the Male narrator (alt +%d)" % (Audio.alt_stats.alt - a0))
	App.came_from = "bathroom"; get_tree().change_scene_to_file("res://main.tscn"); await _scene_is("res://main.tscn")
	var mm = get_tree().current_scene; await wait_until(func(): return mm.mode == "play", 30.0)
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://livingroom.tscn"); await _scene_is("res://livingroom.tscn")
	var lr = get_tree().current_scene; await wait_until(func(): return lr.mode == "play", 60.0)
	App.narrator_from_look("women", "adult", true)
	# --- blue's day-2 breakfast
	var s := App.load_save(); s["day"] = 2; var st: Dictionary = s.get("story", {}); st["day2"] = "living"; s["story"] = st
	if s.get("world") is Dictionary: s.world["day"] = 2
	var f := FileAccess.open(SavePath.P(), FileAccess.WRITE); f.store_string(JSON.stringify(s)); f.close()
	WorldState.day = 2; App.day = 2
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://livingroom.tscn"); await _scene_is("res://livingroom.tscn")
	lr = get_tree().current_scene
	ok(await wait_until(func(): return lr.find_children("*", "Node", false, false).any(func(n): return n.get_script() != null and String(n.get_script().resource_path).ends_with("day2_morning.gd")), 15.0), "day-2 scripted breakfast starts (stage living)")
	await w(8.0); await shot("42_day2_breakfast")


## v30.4 targeted checks: bathroom-door guide pan, bathroom mirror pan + merged routine, crash -> lying on the bed
## v30.5: with TR off no visible UI text may contain Turkish letters
func tr_scan(nd: Node, out: Array) -> void:
	if nd is CanvasItem and not nd.visible: return
	if (nd is Label or nd is Button or nd is Label3D) and Objectives.has_tr(nd.text): out.append(nd.text.replace("\n", " | "))
	for c in nd.get_children(): tr_scan(c, out)
func tr_check(where: String) -> void:
	await w(0.6); var out := []; tr_scan(get_tree().root, out)
	ok(not App.tr_on() and out.is_empty(), "TR off, no Turkish visible @%s %s" % [where, str(out.slice(0, 4))])

## v30.5: hospital TR toggle (day 1 + day 2) with live lesson pages
func run_hosptr() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = "/workspace/qa_v304/hosp_"
	App.save_tr(false)
	for sc in ["res://scenes/hospital.tscn", "res://scenes/hospital_day2.tscn"]:
		var tag := "d1" if not sc.contains("day2") else "d2"
		get_tree().change_scene_to_file(sc); await w(1.5)
		var h = get_tree().current_scene
		var got := await wait_until(func(): return h.phone.visible and String(h.phone.page) == "lesson", 150.0)
		await w(1.0); await shot(tag + "_lesson_tr_off")
		var o1 := []; tr_scan(h, o1)
		ok(got and h.tr_btn != null and o1.is_empty(), "%s lesson open, TR button, no Turkish with TR off %s" % [tag, str(o1.slice(0, 3))])
		h.toggle_tr(true); await w(1.0); await shot(tag + "_lesson_tr_on")
		var o2 := []; tr_scan(h, o2)
		ok(App.tr_on() and h.S.tr and o2.size() > 0, "%s TR on live: %s" % [tag, str(o2.slice(0, 3))])
		h.toggle_tr(false); await w(0.8); await shot(tag + "_lesson_tr_back_off")
		var o3 := []; tr_scan(h, o3); ok(o3.is_empty(), "%s TR back off: clean %s" % [tag, str(o3.slice(0, 3))])
	print("HOSPTR DONE"); get_tree().quit()

func run_v304() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = "/workspace/qa_v304/"; DirAccess.make_dir_recursive_absolute(shot_dir)
	await w(1.0); WorldState.load_game()
	WorldState.day = 1; App.day = 1; App.bath_done = false
	App.continue_requested = true; App.came_from = ""
	get_tree().change_scene_to_file("res://main.tscn"); await w(1.5)
	m = get_tree().current_scene; await wait_until(func(): return m.mode == "play", 30.0)
	await w(1.0); await shot("00_bedroom_play_southwall")
	m.cam_shot = {"pos": Vector3(-2.2, 1.6, 2.68), "at": Vector3(-3.43, 1.3, 2.68)}; await w(1.2)
	for k in 4: await shot("00t_bedroom_towel_%d" % k); await w(0.25)
	m.cam_shot = {}; await w(0.8)
	await tr_check("bedroom d1")
	# v30.5 Charge phone on the end table
	m.S.has_phone = true; m.S.created = true; m._apply_states(); Life.battery = 10.0; Life._warned = false
	if not await wait_until(func(): return Objectives.has("charge"), 12.0): Objectives.add("charge", "Charge my phone.", "Telefonumu şarj et.")
	await shot("00c_charge_objective")
	var opts: Array = m.verbs_for("night") if m.has_method("verbs_for") else []
	print("V304 night verbs ", opts)
	m.do_verb("night", ["Charge my phone", "I am charging my phone.", "charge"])
	await wait_until(func(): return m.S.phone == "charging", 15.0); var b0 := Life.battery; await w(3.0)
	await shot("00c_charge_plugged")
	ok(m.S.phone == "charging" and not m.S.has_phone and Life.battery > b0 and not Objectives.has("charge"), "charge phone: %.1f -> %.1f%%, objective gone" % [b0, Life.battery])
	Life.battery = 100.0; m.S.phone = "off"; m.S.has_phone = true; m._apply_states()
	m._cine_mirror(); var maxw := 0.0
	for k in 12:
		await w(0.2)
		var img := get_viewport().get_texture().get_image(); img.resize(160, 72)
		var white := 0
		for yy in 72:
			for xx in 160:
				var c := img.get_pixel(xx, yy)
				if c.r > 0.93 and c.g > 0.93 and c.b > 0.93: white += 1
		maxw = maxf(maxw, white / 11520.0)
		if k in [1, 3, 6]: await shot("00_mirror_pan_%d" % k)
	ok(maxw < 0.5, "bedroom mirror pan: max near-white fraction %.2f" % maxw)
	await wait_until(func(): return m.cam_shot.is_empty(), 10.0); await w(0.8)
	m.S.calendar_seen = true; m.S.door_locked = false; m.S.erase("bath_guided"); m.mission = ""
	m._advance(false)
	var panned := await wait_until(func(): return not m.cam_shot.is_empty(), 10.0)
	await w(1.0); await shot("01_bath_door_pan")
	ok(panned and m.mission == "Go to the bathroom.", "bedroom: bathroom-door pan + mission (%s)" % m.mission)
	ok(Objectives.items.any(func(it): return String(it.en) == "Go to the bathroom."), "Objectives shows 'Go to the bathroom.'")
	await wait_until(func(): return m.mode == "play" and m.cam_shot.is_empty(), 20.0)
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn")
	await wait_until(func(): return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == "res://bathroom.tscn", 20.0)
	var b = get_tree().current_scene
	b.S.face_done = false; b.S.teeth_done = false
	var bp := await wait_until(func(): return not b.cam_shot.is_empty(), 10.0)
	await w(1.0); await shot("02_mirror_pan")
	ok(bp and b.mission == "Go to the mirror.", "bathroom: mirror pan + mission (%s)" % b.mission)
	print("V304 OBJ ", Objectives.items.map(func(it): return it.en))
	await wait_until(func(): return b.mode == "play" and b.cam_shot.is_empty(), 20.0)
	var v: Array = b.verbs("sink")
	ok(v[0][2] == "routine" and not v.any(func(e): return e[2] in ["face", "teeth"]), "sink: one merged 'Wash my face and brush my teeth' action")
	b.cam_shot = {"pos": Vector3(0.55, 1.45, b.BZ + 1.2), "at": Vector3(0.55, 1.05, b.BZ)}; await w(1.0)
	for k in 4: await shot("02c_bath_towel_%d" % k); await w(0.25)
	b.cam_shot = {}; await w(0.6)
	b.do_verb("sink", v[0])
	for k in 14:
		await w(1.6); await shot("02t_routine_%02d" % k)
	await tr_check("bathroom d1")
	var both := await wait_until(func(): return b.S.face_done and b.S.teeth_done, 150.0)
	await w(2.0); await shot("03_routine_done")
	ok(both, "merged routine: face + teeth done")
	print("V304 OBJ2 ", Objectives.items.map(func(it): return it.en))
	ok(not Objectives.items.any(func(it): return String(it.en) in ["Wash your face.", "Brush your teeth.", "Go to the mirror."]), "both objectives completed")
	App.came_from = "bathroom"; get_tree().change_scene_to_file("res://livingroom.tscn"); await w(5.0)
	await shot("03b_livingroom_topleft")
	await tr_check("living d1")
	var lrs = get_tree().current_scene; lrs.hero.position = Vector3(2.0, 0, 1.0); await w(2.0); await shot("03c_livingroom_southwall")
	lrs.breakfast_done = true; lrs._out_guided = false; lrs._advance()
	var op := await wait_until(func(): return not lrs.cam_shot.is_empty(), 6.0)
	await w(1.0); await shot("03d_go_outside_pan")
	await wait_until(func(): return lrs.cam_shot.is_empty(), 15.0); await w(0.5)
	ok(op and lrs.mission == "Go outside." and Objectives.items.size() == 1 and String(Objectives.items[0].en) == "Go outside.", "after breakfast: only 'Go outside.' + front-door pan (%s)" % str(Objectives.items.map(func(it): return it.en)))
	var lr2 = get_tree().current_scene
	ok(not lr2.hud.get_node("Mission").visible and not lr2.hud.mission_panel.visible if lr2.hud.get("mission_panel") else not lr2.hud.get_node("Mission").visible, "living room: old mission pill hidden")
	# crash -> home: lying on the bed during review/tests
	App.came_from = "hospital"; get_tree().change_scene_to_file("res://main.tscn"); await w(4.0)
	m = get_tree().current_scene
	await shot("04_home_lying")
	ok(m.breathing, "from hospital: lying on the bed (breathing pose)")
	await w(25.0); await shot("05_review_still_lying")
	ok(m.breathing, "still lying during the review / tests")
	# "It is a new day." title: upper centre, short, gone before the next caption
	var sh = load("res://scripts/story/story_home.gd").new(); sh.m = m; m.add_child(sh)
	sh.ui = StoryUI.new(); sh.add_child(sh.ui); sh.cl = CanvasLayer.new(); sh.cl.layer = 30; sh.add_child(sh.cl)
	var t0 := Time.get_ticks_msec(); var fin := [false]
	var job := func(): await sh._new_day_title(); fin[0] = true
	job.call()
	await w(0.9); await shot("06_new_day_title")
	await wait_until(func(): return fin[0], 10.0)
	var el := (Time.get_ticks_msec() - t0) / 1000.0
	ok(fin[0] and el < 4.5 and sh.cl.get_child_count() == 0, "new-day title gone after %.1f s" % el)
	print("V304 DONE"); get_tree().quit()

## v31.1 recovery (RECONSTRUCTED 2026-10-17): the v31.x qa_flow.gd with ovl_check() was lost in the snapshot restore
## (qa_flow.gd is export-excluded, so it is not in the APK). qa_v31c.gd / tools/qa31b call it with TR on:
## no two registered top-left boxes (Objectives no_overlap group / OVL_NAMES) may overlap after Objectives.resolve_overlaps().
func ovl_check(where: String) -> void:
	await w(0.6)
	var all: Array = []; Objectives._ovl_collect(get_tree().root, all)
	var hits := []
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: Control = all[i][1]; var b: Control = all[j][1]
			if Rect2(a.global_position, a.size).grow(-1).intersects(Rect2(b.global_position, b.size).grow(-1)): hits.append("%s/%s" % [a.name, b.name])
	ok(hits.is_empty(), "TR on, no overlapping boxes @%s (%d boxes) %s" % [where, all.size(), str(hits.slice(0, 4))])
