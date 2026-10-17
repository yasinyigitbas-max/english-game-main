extends Node
var m
var log := []
var shot_dir := "res://screens/"

func ok(c: bool, t: String) -> void:
	log.append(("PASS " if c else "FAIL ") + t); print(log[-1])

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + n + ".png"))

func w(t: float) -> void:
	await get_tree().create_timer(t, true).timeout

func hips() -> Vector3:
	var sk: Skeleton3D = m.hero.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin

func head() -> Vector3:
	var sk: Skeleton3D = m.hero.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin

func feet_min_y() -> float:
	var sk: Skeleton3D = m.hero.skeleton
	var a := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L"))).origin
	var b := (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.R"))).origin
	return minf(a.y, b.y)

var caps := []
var leg_clip := 0.0
var head_dip := 0.0
var last_head := -9.0
var done_n := 0
func side_shot(n: String, from: Vector3, at: Vector3) -> void:
	m.cam_override = true; m.cam.position = from; m.cam.look_at(at, Vector3.UP)
	await shot(n); m.cam_override = false

## v12: toe/heel clearance over a stretch of frames (m above the floor; the sole sits at 0)
func foot_check(label: String, frames: int, tiptoe_check := true) -> void:
	var mint := 9.0; var minh := 9.0; var tip_run := {"L": 0.0, "R": 0.0}; var tip_max := 0.0; var t_prev := Time.get_ticks_usec()
	var trace := []
	for k in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec(); var dt := (now - t_prev) / 1e6; t_prev = now
		for sd in ["L", "R"]:
			var tip := false
			var P: Dictionary = m.hero.foot_log.get(sd, m.hero.foot_points(sd))
			mint = minf(mint, P.toe); minh = minf(minh, P.heel)
			# tiptoe: toe on the floor, heel well up, ankle low (standing on the toes rather than pushing off)
			if P.toe < 0.02 and P.heel > 0.035: tip = true
			if sd == "L" and k % 6 == 0: trace.append("%.3f/%.3f" % [P.heel, P.toe])
			tip_run[sd] = tip_run[sd] + dt if tip else 0.0
			tip_max = maxf(tip_max, tip_run[sd])
	var line := "%s: min toe %.4f m, min heel %.4f m, longest tiptoe %.2f s, L heel/toe %s" % [label, mint, minh, tip_max, str(trace.slice(0, 10))]
	print(line); log.append("INFO " + line)
	ok(mint >= -0.005, label + ": toe never below the floor (min %.4f)" % mint)
	ok(minh >= -0.012, label + ": heel not sunk in the floor (min %.4f)" % minh)
	if tiptoe_check: ok(tip_max < 0.4, label + ": no long-held tiptoe (%.2f s)" % tip_max)

func feet_shot(n: String) -> void:
	await rel_shot(n, 0.25, -0.9, 0.16, 0.05)

func rel_shot(n: String, f: float, r: float, h: float, look_h: float) -> void:
	var y: float = m.hero.rotation.y
	var fw := Vector3(sin(y), 0, cos(y)); var rt := Vector3(cos(y), 0, -sin(y))
	await side_shot(n, m.hero.position + fw * f + rt * r + Vector3(0, h, 0), m.hero.position + fw * 0.25 + Vector3(0, look_h, 0))

func run_mirror(main) -> void:
	m = main
	process_mode = Node.PROCESS_MODE_ALWAYS
	await w(0.5)
	m.started = true; m._show_menu(false); m.breathing = false; m.mode = "play"; m.S.alarm = "off"; m._apply_states()
	m.hero.bone_offsets.clear(); m.hero.player.speed_scale = 1.0; m.hero.player.play("idle", 0.0)
	m.hero.position = Vector3(-1.5, 0, 1.4)
	m.S.tr = true; m._refresh_text()
	for k in [0, 1]:
		var v: Array = m.verbs("mirror")[k]
		var d0 := done_n
		m.action_done.connect(func(_i): done_n += 1, CONNECT_ONE_SHOT)
		m.do_verb("mirror", v)
		await m.action_peak
		await w(0.8)
		var tag := "mirror_%s" % v[2]
		await shot(tag + "_game")
		var vp: SubViewport = m.N.mirror_cam.get_viewport()
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://screens/%s_reflection_raw.png" % tag))
		var sk: Skeleton3D = m.hero.skeleton
		var hd := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin + Vector3(0, 0.08, 0)
		var mc: Camera3D = m.N.mirror_cam
		var sp = mc.unproject_position(hd)
		var vis := not mc.is_position_behind(hd) and Rect2(Vector2.ZERO, Vector2(vp.size)).grow(-10).has_point(sp)
		var to_cam = (mc.global_position - hd); to_cam.y = 0
		var fw = Vector3(sin(m.hero.rotation.y), 0, cos(m.hero.rotation.y))
		ok(vis and fw.dot(to_cam.normalized()) > 0.8, "%s: face in the reflection at %s (viewport %s), facing the glass (dot %.2f)" % [tag, sp, vp.size, fw.dot(to_cam.normalized())])
		var gp = m.cam.unproject_position(hd); var mp = m.cam.unproject_position(m.MIRROR_C)
		var vr = get_viewport().get_visible_rect()
		ok(vr.has_point(gp) and vr.has_point(mp), "%s: game camera shows player and mirror" % tag)
		await side_shot(tag + "_zoom", Vector3(-2.15, 1.55, 1.25), Vector3(-3.43, 1.35, 2.05))
		while done_n == d0: await w(0.1)
		await w(0.3)
	ok(m.cam_shot.is_empty(), "camera returns after the mirror action")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_mirror.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	print("QA DONE"); get_tree().quit()

func run(main) -> void:
	m = main
	m.captioned.connect(func(t): caps.append(t))
	m.action_done.connect(func(_i): done_n += 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	await w(0.8)
	await shot("01_menu")
	ok(overflow().is_empty(), "menu: no text overflow " + str(overflow()))
	m.settings.visible = true; await w(0.2); await shot("02_settings")
	ok(overflow().is_empty(), "settings: no text overflow " + str(overflow()))
	m.settings.visible = false
	# ---- opening strip
	m._start_game()
	var frames := []
	var t0 := Time.get_ticks_msec()
	var last := hips(); var max_jump := 0.0; var min_feet := 9.0
	var i := 0
	while m.mode != "play" and Time.get_ticks_msec() - t0 < 30000:
		await RenderingServer.frame_post_draw
		var h := hips()
		if h.distance_to(last) > 0.05: log.append("  JUMP %.3f at %.2fs anim=%s pos=%s" % [h.distance_to(last), (Time.get_ticks_msec() - t0) / 1000.0, m.hero.player.current_animation, m.hero.position])
		max_jump = maxf(max_jump, h.distance_to(last)); last = h
		if i % 6 == 0:
			var img = get_viewport().get_texture().get_image()
			var sp: Vector2 = m.cam.unproject_position(h + Vector3(0, 0.1, 0))
			frames.append([img, sp, "%.1fs %s" % [(Time.get_ticks_msec() - t0) / 1000.0, m.hero.player.current_animation]])
			log.append("  strip %.2fs anim=%s root=%s hips=%s head=%s" % [(Time.get_ticks_msec() - t0) / 1000.0, m.hero.player.current_animation, m.hero.position, h, head()])
		i += 1
		if m.mode == "busy" and m.hero.player.current_animation in ["sit_idle", "sit_to_stand"]: min_feet = minf(min_feet, feet_min_y())
		for bn in ["Foot.L", "Foot.R", "LowerLeg.L", "LowerLeg.R", "Shin.L", "Shin.R"]:
			var bi: int = m.hero.skeleton.find_bone(bn)
			if bi < 0: continue
			var bp: Vector3 = m.hero.skeleton.global_transform * m.hero.skeleton.get_bone_global_pose(bi).origin
			if absf(bp.x - m.B.x) < 0.95 and absf(bp.z - m.B.z) < 0.45 and bp.y < 0.36: leg_clip = maxf(leg_clip, 0.36 - bp.y)
		if m.hero.player.current_animation == "wake_up" and m.mode == "busy":
			var hy := head().y
			if last_head > -1.0 and hy < last_head - 0.03 and h.y > 0.5: head_dip = maxf(head_dip, last_head - hy)
			last_head = hy
	ok(m.mode == "play", "opening reaches free play")
	ok(leg_clip < 0.02, "no leg/foot clipping into the mattress during the opening (worst %.3f m)" % leg_clip)
	ok(head_dip < 0.05, "sit-up is monotonic, no twisted dip (worst head drop %.3f m)" % head_dip)
	ok(not caps.has("I am stretching."), "v11: no stretching caption in the wake sequence")
	ok(max_jump < 0.12, "opening: no hips pop between frames (max %.3f m/frame)" % max_jump)
	ok(min_feet > -0.06 and min_feet < 0.2, "sitting on the bed edge: feet on the floor (min foot y %.2f)" % min_feet)
	var strip_dir := ProjectSettings.globalize_path(shot_dir + "strip/")
	DirAccess.make_dir_recursive_absolute(strip_dir)
	for k in frames.size():
		var f: Array = frames[k]
		var img: Image = f[0]
		var c: Vector2 = f[1]
		var r := Rect2i(clampi(int(c.x) - 200, 0, img.get_width() - 400), clampi(int(c.y) - 200, 0, img.get_height() - 320), 400, 320)
		img.get_region(r).save_png(strip_dir + "f%03d.png" % k)
	var fl := FileAccess.open(strip_dir + "labels.txt", FileAccess.WRITE)
	for f in frames: fl.store_line(f[2])
	fl.close()
	await shot("03_after_wakeup")
	ok(m.S.alarm == "ringing" and m.mission != "", "alarm still ringing with mission shown")
	# ---- hand only when near
	ok(m.near_id == "bed", "hand shown for bed right after getting up (near=%s)" % m.near_id)
	m.hero.position = Vector3(0.3, 0, 0.8); await w(0.3)
	ok(m.near_id == "", "no hand in the middle of the room (near=%s)" % m.near_id)
	await shot("04_free_no_hand")
	# ---- stick: drag right/down via real touch events
	var tc: Control = m.touch
	var c0: Vector2 = tc.get_global_transform_with_canvas() * tc.stick_center()
	_touch(0, c0, true); _drag(0, c0 + Vector2(80, -30))
	var p0: Vector3 = m.hero.position
	await w(0.6); await shot("05_stick_walk")
	ok(m.hero.position.distance_to(p0) > 0.4 and m.hero.player.current_animation == "walk", "stick moves the player with walk anim")
	var yaw: float = m.hero.rotation.y
	ok(absf(angle_difference(yaw, atan2(80, -30))) < 0.35, "player faces the stick direction (yaw %.2f)" % yaw)
	await w(3.0)
	ok(m.hero.position.x <= 3.5 - 0.21 and absf(m.hero.position.y) < 0.001, "wall stops the player, no hopping (x=%.2f y=%.3f)" % [m.hero.position.x, m.hero.position.y])
	_touch(0, c0, false); await w(0.3)
	ok(m.hero.player.current_animation == "idle", "idle after release")
	# both sticks at once: camera orbit (right) + camera-relative walking (left)
	m.hero.position = Vector3(0, 0, 0.5)
	var cc: Vector2 = tc.get_global_transform_with_canvas() * tc.cam_center()
	_touch(1, cc, true); _drag(1, cc + Vector2(70, -20))
	await w(0.6)
	_touch(0, c0, true); _drag(0, c0 + Vector2(0, -90))
	await w(0.5); await shot("07_both_sticks")
	_touch(1, cc, false)
	var pb: Vector3 = m.hero.position; await w(0.6)
	var mv: Vector3 = (m.hero.position - pb).normalized()
	var fwd = Vector3(-sin(m.cam_yaw), 0, -cos(m.cam_yaw))
	ok(m.cam_yaw > 0.4, "right stick orbits the camera (yaw %.2f)" % m.cam_yaw)
	ok(mv.dot(fwd) > 0.9, "stick-up walks along the camera forward (dot %.2f)" % mv.dot(fwd))
	_touch(0, c0, false); await w(0.3)
	await shot("08_orbited_view")
	await w(1.2)
	var ra: float = m.wall_alpha.get(m.walls_r[0], 1.0)
	ok(ra < 0.3, "occluding right wall fades out when orbiting (alpha %.2f)" % ra)
	var inside := 0
	for yw in [-1.3, -0.6, 0.0, 0.6, 1.3]:
		for pt in [0.6, 0.9, 1.3]:
			for ds in [6.0, 12.0]:
				m.cam_yaw = yw; m.cam_pitch = pt; m.cam_dist = ds; m.cam_yaw_s = yw; m.cam_pitch_s = pt
				m._update_cam(0.016)
				for wl in m.walls_l + m.walls_r:
					var ab: AABB = wl.get_aabb(); ab.position += wl.position
					if ab.grow(0.05).has_point(m.cam.position): inside += 1
				if m.cam.position.y < m.WALL_H and absf(m.cam.position.x) < 3.6 and absf(m.cam.position.z) < 3.1: inside += 1
	ok(inside == 0, "camera never inside a wall over 30 orbit/zoom samples (%d bad)" % inside)
	m.cam_yaw = 0.0; m.cam_pitch = 0.9025; m.cam_dist = 9.68
	# into the bed
	m.hero.position = Vector3(-1.4, 0, -0.8)
	_touch(0, c0, true); _drag(0, c0 + Vector2(0, -90)); await w(2.0); _touch(0, c0, false)
	ok(m.hero.position.z > -1.97 + 0.2, "bed is solid (z=%.2f)" % m.hero.position.z)
	# ---- chips
	m.hero.position = m.OBJ.bed.spot + Vector3(0.2, 0, 0.3); await w(0.3)
	m.on_action(); await w(0.3); await shot("06_chips_bed")
	ok(overflow().is_empty(), "chips: no overflow " + str(overflow()))
	m._hide_chips()
	# ---- every verb, zoomed
	m.S.tr = true; m._refresh_text()
	var plan := [["alarm", 0], ["bed", 0], ["night", 0], ["night", 1], ["night", 2], ["window", 0], ["window", 0], ["window", 1], ["wardrobe", 0], ["wardrobe", 0], ["wardrobe", 1],
		["desk", 0], ["desk", 1], ["desk", 2], ["books", 0], ["walk_book", 0], ["books", 0], ["books", 1], ["mirror", 0], ["mirror", 1], ["plant", 0], ["switch", 0], ["switch", 0], ["door", 0], ["bed", 0], ["bed", 1]]
	var n := 10
	for st in plan:
		var id: String = st[0]
		if id == "walk_book":
			await w(0.5)
			_touch(0, c0, true); _drag(0, c0 + Vector2(-80, 40)); await w(1.0)
			ok(m.hero.held != null and m.hero.player.current_animation == "walk", "book carried while walking")
			await side_shot("22b_book_walking", m.hero.position + Vector3(1.2, 1.5, 1.4), m.hero.position + Vector3(0, 0.9, 0))
			_touch(0, c0, false); await w(0.3)
			continue
		var vs: Array = m.verbs(id)
		var v: Array = vs[mini(st[1], vs.size() - 1)]
		m.hero.position = Vector3(0.3, 0, 0.6) if id != "plant" else Vector3(-1.5, 0, 1.8)
		if id == "books": m.hero.position = Vector3(1.6, 0, 0.2)
		m.cam_zoom = 0.55
		caps.clear()
		var d0 := done_n
		m.do_verb(id, v)
		await m.action_peak
		var tag := "%02d_%s_%s" % [n, id, String(v[2])]
		if id in ["door", "night", "window", "wardrobe"]: await shot(tag + "_mid"); await w(0.5)
		else: await w(0.15)
		await shot(tag); n += 1
		ok(caps.has(v[1]) and caps.has("I am going to the %s." % m.OBJ[id].name), "%s: captions %s" % [tag, str(caps)])
		for c in caps:
			if not m.TR.has(c) or not Audio.has_clip(c): ok(false, "caption without TR/voice: " + c)
		if id == "bed" and v[2] == "sit":
			var hp2 := hips()
			ok(hp2.y > 0.42 and hp2.y < 0.6 and hp2.z < m.BED_FRONT - 0.03 and hp2.z > m.BED_FRONT - 0.4 and feet_min_y() < 0.15,
				"sitting ON the mattress edge: hips y %.2f z %.2f (edge %.2f), feet y %.2f" % [hp2.y, hp2.z, m.BED_FRONT, feet_min_y()])
			await side_shot(tag + "_side", Vector3(0.6, 1.1, -0.2), hp2)
		if id == "desk" and v[2] == "work":
			var hp3 := hips()
			ok(hp3.y > 0.42 and hp3.y < 0.62 and absf(hp3.z - m.N.chair.position.z) < 0.2, "sitting on the desk chair: hips y %.2f z %.2f chair z %.2f" % [hp3.y, hp3.z, m.N.chair.position.z])
			await side_shot(tag + "_side", Vector3(1.0, 1.2, -1.0), hp3)
		if id == "door":
			await side_shot(tag + "_mid_clear", Vector3(1.6, 4.2, 3.6), Vector3(3.7, 0.9, 1.2))
		if id == "books" and v[2] == "read":
			var hl: Vector3 = m.hero.skeleton.global_transform * m.hero.skeleton.get_bone_global_pose(m.hero.skeleton.find_bone("Hand.L")).origin
			ok(hl.y > 1.05, "reading: book raised in front of the chest (left hand y %.2f)" % hl.y)
			await rel_shot(tag + "_pose", 0.55, 1.1, 1.5, 1.15)
		if id == "plant":
			ok(m.hero.held != null and m.water_fx.emitting, "watering can in hand and water flowing")
			await rel_shot(tag + "_can", 0.45, 1.2, 1.3, 0.7)
		if id == "mirror":
			await side_shot(tag + "_reflection", Vector3(-1.9, 1.5, 1.1), Vector3(-3.43, 1.2, 2.05))
		if id == "night" and v[2] == "phone":
			await side_shot(tag + "_cable", Vector3(-2.3, 0.95, -2.2), Vector3(-2.95, 0.45, -2.75))
		if id == "wardrobe" and v[2] == "fold":
			await w(0.6); await side_shot(tag + "_folded", Vector3(-2.2, 0.9, 0.9), Vector3(-3.15, 0.25, 0.3))
		if id == "books" and v[2] == "take":
			await w(1.5)
			ok(m.hero.held != null and m.hero.held.is_visible_in_tree(), "book is in the hand after taking")
			await side_shot(tag + "_inhand", m.hero.position + Vector3(-1.4, 1.4, 0.9), m.hero.position + Vector3(0, 1.0, 0))
		var hp: Vector3 = m.hero.position; var f: Vector3 = m.OBJ[id].focus
		var to := Vector2(f.x - hp.x, f.z - hp.z).normalized()
		var fw = Vector2(sin(m.hero.rotation.y), cos(m.hero.rotation.y))
		var front: bool = id == "bed" or to.dot(fw) > 0.8
		ok(front, "%s/%s: in front of it, facing it (dot %.2f)" % [id, v[2], to.dot(fw)])
		ok(overflow().is_empty(), "%s: caption fits %s" % [tag, str(overflow())])
		if m.mode == "lying":
			await shot(tag + "_lying")
			while done_n == d0: await w(0.1)
			var d1 = done_n; m.on_action()
			while done_n == d1: await w(0.1)
		else:
			while done_n == d0: await w(0.1)
		await w(0.2)
	m.cam_zoom = 1.0
	ok(m.hero.held == null and m.S.book == "shelf" and m.N.shelf_book.visible, "book returned to the shelf")
	var missing := []
	for sn in ["doorOpen_1", "doorClose_2", "metalClick", "cloth1", "drawer", "alarm", "bookFlip1", "water", "footstep00", "footstep01"]:
		if not sn in Audio.sfx_log and not (sn.begins_with("footstep") and Audio.sfx_log.any(func(x): return x.begins_with("footstep"))): missing.append(sn)
	ok(missing.is_empty(), "sound effects fired: missing %s" % str(missing))
	await side_shot("42_soft_bed", Vector3(-0.3, 1.6, -0.6), Vector3(-1.5, 0.45, -2.48))
	ok(m.S.bed == "made" or m.S.bed == "unmade", "bed state: " + m.S.bed)
	# ---- all captions EN+TR fit
	var bad := []
	for k in m.TR.keys():
		m.caption(k); await get_tree().process_frame; await get_tree().process_frame
		var o := overflow()
		if not o.is_empty(): bad.append(k)
	ok(bad.is_empty(), "all %d captions (EN+TR) fit on screen: %s" % [m.TR.size(), str(bad)])
	m.caption("The rest of the house comes later."); await w(0.3)
	m.hero.position = Vector3(0.3, 0, 0.4); await w(1.2)
	await shot("40_overview_tr")
	m._show_menu(true); await w(0.2); await shot("41_pause_menu")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	print("QA DONE")
	get_tree().quit()

func _touch(idx: int, p: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = idx; e.position = p; e.pressed = pressed; Input.parse_input_event(e)

func _drag(idx: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = idx; e.position = p; Input.parse_input_event(e)

## controls whose text is wider/taller than their box, or that leave the screen
func overflow() -> Array:
	var out := []
	var vr: Rect2 = get_viewport().get_visible_rect()
	for c in m.ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree(): continue
		var r := ctl.get_global_rect()
		if r.size.x > 0 and not vr.grow(1).encloses(r): out.append("%s offscreen %s" % [ctl.name, r])
		if ctl is Label:
			var l := ctl as Label
			var f := l.get_theme_font("font"); var fs := l.get_theme_font_size("font_size")
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				if f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x + 1: out.append("label '%s' too wide" % l.text)
			elif l.get_line_count() * (f.get_height(fs)) > l.size.y + 2: out.append("label '%s' too tall" % l.text)
		elif ctl is Button:
			var b := ctl as Button
			var f2 := b.get_theme_font("font"); var fs2 := b.get_theme_font_size("font_size")
			var sb := b.get_theme_stylebox("normal")
			if f2.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x + sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) > b.size.x + 1:
				out.append("button '%s' too narrow" % b.text)
	return out

func run_cine(main) -> void:
	m = main; process_mode = Node.PROCESS_MODE_ALWAYS
	await w(0.5)
	m.started = true; m.hero.set_mannequin(true); m.breathing = false; m.mode = "busy"; m.S.alarm = "off"; m._apply_states()
	m.hero.bone_offsets.clear(); m.hero.player.speed_scale = 1.0; m.hero.player.play("idle", 0.0)
	m.hero.position = m.OBJ.alarm.spot; m.hero.rotation.y = PI; m._set_mission("Look in the mirror.")
	await w(0.3)
	m._cine_mirror(); await w(2.3)
	await shot("41_cine_face_mirror")
	print("QA DONE"); get_tree().quit()

func run_probe(main) -> void:
	m = main; process_mode = Node.PROCESS_MODE_ALWAYS
	await w(0.5)
	m.started = true; m.hero.set_mannequin(false); m.mode = "busy"; m.S.alarm = "off"; m._apply_states()
	var sk: Skeleton3D = m.hero.skeleton
	var names := []
	for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
	print("BONES ", names)
	m.breathing = false; m.hero.bone_offsets.clear()
	await w(0.3)
	await side_shot("p_frame0_side", Vector3(-1.45, 0.9, -0.9), Vector3(-1.45, 0.6, -2.48))
	m._pose_sleep(); await w(0.3)
	await side_shot("p_cur_side", Vector3(-1.45, 0.9, -0.9), Vector3(-1.45, 0.6, -2.48))
	await side_shot("p_cur_top", Vector3(-1.45, 3.0, -1.2), Vector3(-1.45, 0.5, -2.48))
	await side_shot("p_cur_end", Vector3(0.6, 1.3, -2.4), Vector3(-1.45, 0.6, -2.48))
	print("QA DONE"); get_tree().quit()
func _bone(n: String) -> Vector3:
	var sk: Skeleton3D = m.hero.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin

func _lie_check(tag: String) -> void:
	var hd := _bone("Head"); var hp := _bone("Hips"); var ft := (_bone("Foot.L") + _bone("Foot.R")) / 2.0
	var bx: float = m.B.x
	ok(absf(hd.y - hp.y) < 0.14 and absf(ft.y - hp.y) < 0.16, "%s: body flat (head y %.2f, hips y %.2f, feet y %.2f)" % [tag, hd.y, hp.y, ft.y])
	ok(hp.y > m.M - 0.02 and hp.y < m.M + 0.26, "%s: on the mattress, not floating (hips %.2f, mattress %.2f)" % [tag, hp.y, m.M])
	ok(hd.x < bx - 0.55 and hd.x > bx - 0.95, "%s: head on the pillow (head x %.2f, pillow x %.2f)" % [tag, hd.x, bx - 0.72])
	await side_shot(tag + "_side", Vector3(-1.45, 0.95, -0.85), Vector3(-1.45, 0.55, -2.48))
	await side_shot(tag + "_top", Vector3(-1.45, 3.0, -1.3), Vector3(-1.45, 0.5, -2.48))
	await side_shot(tag + "_feet", Vector3(0.7, 1.35, -2.3), Vector3(-1.6, 0.55, -2.48))
	await side_shot(tag + "_head", Vector3(-2.9, 1.5, -1.3), Vector3(-1.2, 0.5, -2.48))

func run_lie(main) -> void:
	m = main; process_mode = Node.PROCESS_MODE_ALWAYS
	m.action_done.connect(func(_i): done_n += 1)
	await w(0.6)
	m.started = true; m.hero.set_mannequin(false); m.S.alarm = "off"; m._apply_states(); m.mode = "lying"
	await w(0.4)
	await _lie_check("80_lie_wakeup")
	m.get_up_sequence(true); await w(0.8)
	await side_shot("81_situp_mid", Vector3(-1.45, 0.95, -0.85), Vector3(-1.45, 0.65, -2.48))
	await w(1.0)
	await side_shot("81b_sitting_up", Vector3(-1.45, 0.95, -0.85), Vector3(-1.45, 0.65, -2.48))
	var t0 := Time.get_ticks_msec()
	while m.mode != "play" and Time.get_ticks_msec() - t0 < 30000: await w(0.1)
	ok(m.mode == "play" and absf(m.hero.model.rotation.x) < 0.01 and _bone("Head").y > 1.3, "wake-up: stands up straight afterwards (head y %.2f)" % _bone("Head").y)
	for v in m.verbs("bed"):
		if v[2] == "lie": m.do_verb("bed", v)
	t0 = Time.get_ticks_msec()
	while m.mode != "lying" and Time.get_ticks_msec() - t0 < 30000: await w(0.1)
	await w(0.6)
	ok(m.mode == "lying" and m.cap_text == "I am lying on the bed.", "'Lie down' action reaches the lying state")
	await _lie_check("82_lie_action")
	m.on_action()
	t0 = Time.get_ticks_msec()
	while m.mode != "play" and Time.get_ticks_msec() - t0 < 30000: await w(0.1)
	ok(m.mode == "play" and _bone("Head").y > 1.3, "gets up again after 'Lie down'")
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_lie.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close(); print("QA DONE"); get_tree().quit()

# ============================================================ v10: walk speed / foot slide / heel contact
func run_walk(main) -> void:
	m = main; process_mode = Node.PROCESS_MODE_ALWAYS
	await w(0.6)
	m.started = true; m.S.alarm = "off"; m._apply_states(); m.S.created = true; m.hero.set_mannequin(false)
	m.breathing = false; m.hero.bone_offsets.clear(); m.hero.player.speed_scale = 1.0; m.hero.model.rotation = Vector3.ZERO; m.hero.model.position = Vector3.ZERO
	m.hero.play("idle", 0.0)
	var logl := []
	for g in ["men", "women", "child"]:
		m.S.gender = "women" if g == "women" else "men"; m.S.age = "child" if g == "child" else "adult"; m._apply_character()
		m.hero.position = Vector3(-1.2, 0, 1.2); m.hero.rotation.y = 0.0; m.mode = "play"; m.cam_yaw = 0.0
		await w(0.5)
		m.stick = Vector2(0.5, 0)
		await w(0.6)
		var miny := 9.0; var samples := []
		for k in 50:
			await get_tree().physics_frame
			var f := _bone("Foot.L"); samples.append([f, Time.get_ticks_usec(), _bone("Foot.L_end") if m.hero.skeleton.find_bone("Foot.L_end") >= 0 else f]); miny = minf(miny, f.y)
		var slide := 0.0; var n := 0; var heel := 0.0
		for k in range(1, samples.size()):
			var f: Vector3 = samples[k][0]; var p: Vector3 = samples[k - 1][0]
			if f.y < miny + 0.01:
				var dt: float = (samples[k][1] - samples[k - 1][1]) / 1e6
				if dt > 0: slide += Vector2(f.x - p.x, f.z - p.z).length() / dt; n += 1
		slide = slide / maxf(n, 1)
		var pitch := []
		for smp in samples:
			if smp[0].y < miny + 0.01: pitch.append("%.3f/%.3f" % [smp[0].y - m.hero.global_position.y, smp[2].y - m.hero.global_position.y])
		logl.append(g + " stance ankle/toe y: " + str(pitch.slice(0, 8))); print(logl[-1])
		var flat := true
		for smp in samples:
			if smp[0].y < miny + 0.01 and absf(smp[0].y - smp[2].y) > 0.03: flat = false
		ok(flat, g + ": stance foot flat (heel and toe on the floor)")
		var sk: Skeleton3D = m.hero.skeleton
		var rest_y: float = (m.hero.model.global_transform * sk.get_bone_global_rest(sk.find_bone("Foot.L")).origin).y - m.hero.global_position.y
		var line := "%s: speed scale %.2f, stance foot min y %.3f (rest %.3f), slide %.3f m/s (walk %.2f m/s)" % [g, m.hero.player.speed_scale, miny - m.hero.global_position.y, rest_y, slide, m.WALK]
		print(line); logl.append(line)
		ok(slide < 0.35, g + " feet do not slide much: %.2f m/s" % slide)
		ok(miny - m.hero.global_position.y < rest_y + 0.03, g + " heel plants (stance foot %.3f vs rest %.3f)" % [miny - m.hero.global_position.y, rest_y])
		await foot_check(g + " walk", 120)
		for i in 3:
			await w(0.18); await rel_shot("98_walk_%s_side_%d" % [g, i], 0.3, 1.6, 0.12, 0.12)
		for i in 4:
			await w(0.11); await feet_shot("99f_walk_%s_feet_%d" % [g, i])
		m.stick = Vector2.ZERO; await w(0.4)
		m.hero.position = Vector3(-1.2, 0, 1.2); m.hero.rotation.y = 0.0; await w(0.3)
		m.stick = Vector2(1, 0); await w(0.7)
		ok(not m.running and m.hero.player.current_animation == "walk" and m.move_sp <= 1.956, g + ": full push walks, no run (house.15+) (%.2f m/s)" % m.move_sp)
		await foot_check(g + " run", 120)
		for i in 2:
			await w(0.12); await rel_shot("98r_run_%s_side_%d" % [g, i], 0.3, 1.8, 0.5, 0.45)
		for i in 4:
			await w(0.07); await feet_shot("99f_run_%s_feet_%d" % [g, i])
		m.stick = Vector2.ZERO; await w(0.8)
		await foot_check(g + " idle", 90)
		await feet_shot("99f_idle_%s_feet" % g)
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_walk.log"), FileAccess.WRITE)
	for l in log + logl: fa.store_line(l)
	fa.close(); print("QA DONE"); get_tree().quit()

# ============================================================ v11: wake-up smoothness (pops, clipping, final position)
var wk_samples := []
var wk_on := false
func _wake_sampler() -> void:
	while wk_on:
		await get_tree().process_frame
		var r := {"t": Time.get_ticks_msec(), "cap": m.cap_text}
		for b in ["Head", "Hips", "Foot.L", "Foot.R", "Hand.L", "Hand.R"]: r[b] = _bone(b)
		r["toe"] = minf(m.hero.foot_points("L").toe, m.hero.foot_points("R").toe)
		wk_samples.append(r)

func run_wake(main) -> void:
	m = main; process_mode = Node.PROCESS_MODE_ALWAYS
	m.captioned.connect(func(t): caps.append(t))
	await w(0.6)
	m.started = true; m.hero.set_mannequin(false); m.S.alarm = "off"; m._apply_states(); m.mode = "lying"
	await w(0.5)
	await side_shot("100_wake_0_lying", Vector3(-1.2, 1.1, -0.6), Vector3(-1.6, 0.55, -2.4))
	wk_on = true; _wake_sampler()
	m.get_up_sequence(true)
	var t0 := Time.get_ticks_msec(); var k := 1
	for at in [0.7, 1.4, 2.2, 3.0, 3.8, 4.6, 5.4]:
		while Time.get_ticks_msec() - t0 < at * 1000: await get_tree().process_frame
		await side_shot("100_wake_%d" % k, Vector3(-1.2, 1.1, -0.6), Vector3(-1.6, 0.55, -2.4)); k += 1
	while m.mode != "play" and Time.get_ticks_msec() - t0 < 30000: await w(0.05)
	await w(0.6); wk_on = false
	await side_shot("100_wake_9_standing", Vector3(-1.2, 1.1, -0.6), Vector3(-1.6, 0.55, -2.4))
	await shot("100_wake_9b_game_view")
	# frame-to-frame jumps (skip frames right after screenshot stalls by normalising per 1/60 s)
	var worst := 0.0; var worst_at := ""
	var floor_clip := 0.0; var bed_clip := 0.0
	for i in range(1, wk_samples.size()):
		var a: Dictionary = wk_samples[i - 1]; var b: Dictionary = wk_samples[i]
		var dt: float = maxf((b.t - a.t) / 1000.0, 1.0 / 60.0)
		for bn in ["Head", "Hips", "Foot.L", "Foot.R", "Hand.L", "Hand.R"]:
			var v: float = (b[bn] - a[bn]).length() / dt
			if v > worst: worst = v; worst_at = "%s @ %.2fs (%s)" % [bn, (b.t - wk_samples[0].t) / 1000.0, b.cap]
		floor_clip = minf(floor_clip, minf(b["Foot.L"].y, b["Foot.R"].y))
		if absf(b["Hips"].x - m.B.x) < 0.6 and b["Hips"].z < m.BED_FRONT: bed_clip = minf(bed_clip, b["Hips"].y - (m.M - 0.08))
	for smp in wk_samples:
		var tt: float = (smp.t - wk_samples[0].t) / 1000.0
	# pop = a frame whose speed is far above both neighbours (a discontinuity), not just a fast smooth move
	var pops := []
	var spd := {}
	for bn in ["Head", "Hips", "Foot.L", "Foot.R", "Hand.L", "Hand.R"]:
		var arr := []
		for i in range(1, wk_samples.size()):
			var dt2: float = maxf((wk_samples[i].t - wk_samples[i - 1].t) / 1000.0, 1.0 / 60.0)
			arr.append((wk_samples[i][bn] - wk_samples[i - 1][bn]).length() / dt2)
		for i in range(1, arr.size() - 1):
			if arr[i] > 1.2 and arr[i] > 2.5 * maxf(arr[i - 1], arr[i + 1]): pops.append("%s@%.2fs %.2f m/s" % [bn, (wk_samples[i + 1].t - wk_samples[0].t) / 1000.0, arr[i]])
	print("wake: worst bone speed %.2f m/s at %s, floor clip %.3f, bed clip %.3f, %d frames" % [worst, worst_at, floor_clip, bed_clip, wk_samples.size()])
	ok(pops.is_empty() and worst < 3.5, "wake-up has no pops %s (fastest bone %.2f m/s at %s)" % [str(pops), worst, worst_at])
	ok(floor_clip > -0.03, "feet never go through the floor (%.3f)" % floor_clip)
	ok(bed_clip > -0.03, "hips never sink into the mattress (%.3f)" % bed_clip)
	var fin: Vector3 = m.hero.position
	ok(fin.z > m.BED_FRONT + 0.05 and absf(fin.x - m.SIT_ROOT.x) < 0.25 and absf(wrapf(m.hero.rotation.y, -PI, PI)) < 0.2 and absf(m.hero.model.rotation.x) < 0.01, "ends standing in front of the bed, facing the room (%s, yaw %.2f)" % [fin, m.hero.rotation.y])
	ok(m.resolve(fin).distance_to(fin) < 0.02, "final position is free floor (not inside the bed)")
	ok(not caps.has("I am stretching.") and not m.TR.has("I am stretching.") and not Audio.has_clip("I am stretching."), "no stretching caption / voice")
	ok(caps.has("I am waking up.") and caps.has("I am standing up."), "wake captions: %s" % str(caps))
	var fa := FileAccess.open(ProjectSettings.globalize_path("res://qa_wake.log"), FileAccess.WRITE)
	for l in log: fa.store_line(l)
	fa.close(); print("QA DONE"); get_tree().quit()
