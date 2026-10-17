## QA for the bk extras (scale, medicine, make-up). Standalone:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -- --qa-bk [--bk-women] [--bk-child]
## writes screens/bk_*.png and bk_qa.log
extends Node
var m; var x; var ok := true; var lines: Array = []; var tag := ""

func _log(s: String) -> void: print("[QA] bk: " + s); lines.append(s)
func _w(t: float) -> void: await get_tree().create_timer(t).timeout
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screens/bk_%s%s.png" % [tag, n])
func _idle() -> void:
	while m.mode != "play": await _w(0.1)
## run an action; shots: {"cap:<caption>" or "peak:<id>": [delay_s, name]}, nth occurrence via "peak:id#2"
func _act(id: String, key: String, shots: Dictionary) -> void:
	var v: Array = []
	for e in m.verbs(id): if e[2] == key: v = e
	if v.is_empty(): _log("no verb %s/%s" % [id, key]); ok = false; return
	var pend: Array = []; var seen := {}
	var on_ev := func(ev: String):
		seen[ev] = seen.get(ev, 0) + 1
		for k in [ev, ev + "#%d" % seen[ev]]:
			if shots.has(k): print("[QA] bk: event %s at %d" % [k, Time.get_ticks_msec()]); pend.append([Time.get_ticks_msec() + int(shots[k][0] * 1000), shots[k][1]])
	var c1 := func(t): on_ev.call("cap:" + t)
	var c2 := func(i): on_ev.call("peak:" + i)
	m.captioned.connect(c1); m.action_peak.connect(c2)
	m.do_verb(id, v)
	while m.mode != "play" or not pend.is_empty():
		await get_tree().process_frame
		for p in pend.duplicate():
			if Time.get_ticks_msec() >= p[0]: pend.erase(p); await _shot(p[1])
	m.captioned.disconnect(c1); m.action_peak.disconnect(c2)

func run(main, ext, quit := true) -> bool:
	m = main; x = ext
	var args := OS.get_cmdline_user_args()
	if "--bk-women" in args or "--bk-child" in args:
		m.S.gender = "women" if "--bk-women" in args else m.S.gender
		if "--bk-child" in args: m.S.age = "child"; tag = "child_"
		else: tag = "women_"
		m.hero.setup(m.S.gender); m._apply_character(); x._setup_makeup()
	await _w(1.5)
	if "--bk-pose" in args: await _pose(); get_tree().quit(); return true
	if quit:
		m.cam_shot = {"pos": Vector3(0.6, 2.1, 2.2), "at": Vector3(2.05, 1.5, 0.75)}
		m.S.cabinet = "open"; m._apply_states(); await _w(2.5); await _shot("cabinet_open_full")
		m.S.cabinet = "closed"; m._apply_states(); m.cam_shot = {}
	# (3) scale
	var kg: int = x.weight_kg(); _log("weight for %s/%s/%s/%s = %d kg" % [m.S.gender, m.S.build, m.S.height, m.S.age, kg])
	await _act("scale", "weigh", {"peak:scale": [0.3, "scale_display"]})
	_log("scale caption clip: %s" % m.voice_banks.any(func(b): return b.index.has("en:I weigh %d kilos." % kg)))
	ok = ok and m.hero.position.y == 0.0
	# (4) medicine
	await _act("cabinet", "medicine", {"peak:cabinet#1": [0.1, "med_open"], "peak:cabinet#2": [0.0, "med_bottle"], "cap:I am taking a pill.#1": [1.0, "med_pill_shake"], "peak:medicine": [0.0, "med_pill_mouth"], "cap:I am drinking water.": [5.0, "med_cup"], "peak:drink": [0.6, "med_drink"]})
	_log("cabinet closed after: %s, cup back: %s, tap off: %s" % [m.S.cabinet == "closed", m.N.cup.visible, m.S.tap == "off"])
	ok = ok and m.S.cabinet == "closed" and m.N.cup.visible and m.S.tap == "off"
	# (5) make-up
	await m.walk_to(x.MIRROR_SPOT, PI); x._mk_shot(); await _w(2.5); await _shot("makeup_before")
	await _face("makeup_before_face")
	await _act("mirror", "makeup", {"peak:blush": [1.0, "makeup_blush"], "cap:I am putting on eyeshadow.": [1.2, "makeup_eyeshadow"], "cap:I am putting on lipstick.": [1.3, "makeup_lipstick"]})
	_log("make-up values: %s" % str(x.mk))
	ok = ok and x.mk.lip > 0.99 and x.mk.blush > 0.99
	x._mk_shot(); m.mode = "busy"; m.hand3d.visible = false; await _w(2.5); await _shot("makeup_after_mirror")
	await _face("makeup_after_face"); m.cam_shot = {}; m.mode = "play"
	if quit:
		await _act("mirror", "remove", {"cap:I am taking off my make-up.": [2.5, "makeup_remove"]})
		_log("make-up removed: %s" % (x.mk.lip < 0.01))
	var missing := []
	for k in x.LINES: if not m.voice_banks.any(func(b): return b.index.has("en:" + k)): missing.append(k)
	_log("lines without clips: %s" % str(missing)); ok = ok and missing.is_empty()
	_log("RESULT: " + ("PASS" if ok else "FAIL"))
	if quit:
		var f := FileAccess.open("res://bk_qa%s.log" % ("_" + tag.trim_suffix("_") if tag != "" else ""), FileAccess.WRITE); f.store_string("\n".join(lines))
		get_tree().quit()
	return ok

func _face(n: String) -> void:
	var sk: Skeleton3D = m.hero.skeleton
	var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	var f: Vector3 = Vector3(sin(m.hero.rotation.y), 0, cos(m.hero.rotation.y))
	m.cam_shot = {"pos": hp + f * 0.55 + Vector3(0.12, 0.08, 0), "at": hp + Vector3(0, 0.07, 0)}
	await _w(3.0); await _shot(n)

func _pose() -> void:
	m.mode = "busy"; await m.walk_to(x.MIRROR_SPOT, PI)
	var h = m.hero; h.player.play("idle", 0.0); h.player.seek(0.5, true); h.player.speed_scale = 0.0
	for tg in [["cheek", Vector3(-0.075, 1.58, 0.21)], ["mouth", Vector3(-0.03, 1.53, 0.24)]]:
		var tgt: Vector3 = h.model.global_transform * tg[1]
		var best := [9.0]
		for ax in [Vector3.UP, Vector3.FORWARD]:
			for c in range(-8, 9, 2):
				for a in range(-12, -1, 2):
					for b in range(-24, -11, 2):
						h.bone_offsets = {"Shoulder.R": [ax, c * 0.1], "UpperArm.R": [Vector3.RIGHT, a * 0.1], "LowerArm.R": [Vector3.RIGHT, b * 0.1]}
						await get_tree().process_frame
						var d: float = m._hand_pos("R").distance_to(tgt)
						if d < best[0]: best = [d, ax, c * 0.1, a * 0.1, b * 0.1]
		print("BEST ", tg[0], best)

