## Bathroom self-test: xvfb-run -a godot --path . --rendering-driver opengl3 -- --qa-bath
## Runs both tasks, writes screens/b*.png and qa_bathroom.log.
extends Node
var m
var log_lines: Array = []
var sig := {}

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://screens/%s.png" % n)

func _log(s: String) -> void:
	print("[QA] " + s); log_lines.append(s)

func _w(t: float) -> void:
	await get_tree().create_timer(t).timeout

func run(main) -> void:
	m = main
	if "--qa-pose" in OS.get_cmdline_user_args():
		await _w(1.0); m.mode = "busy"; await m.walk_to(m.OBJ.sink.spot, m.OBJ.sink.yaw); m._sink_shot(); await _w(4.0)
		m.hero.hold_item(m.PROPS + "Toothbrush.tscn", "long", 0.17, false)
		for an in ["drink", "pick_up"]:
			m.hero.player.play(an, 0.0)
			for i in 18:
				m.hero.player.seek(i * 0.6, true); m.hero.player.speed_scale = 0.0; await _w(0.15); await _shot("p_%s_%02d" % [an, i])
		get_tree().quit(); return
	if "--qa-front" in OS.get_cmdline_user_args():
		await _w(1.0); m.mode = "busy"; await m.walk_to(m.OBJ.sink.spot, m.OBJ.sink.yaw); await _w(0.5)
		cu = {"side": 2.6, "h": 1.5, "d": 1.6, "up": 0.1}; _cu_update(); await _w(0.3); await _shot("q_mirror_view")
		m.hero.position = Vector3(0, 0, 0.3); m.hero.rotation.y = 0.0
		cu = {"side": 0.0, "h": 1.55, "d": 1.3, "up": 0.0}; _cu_update(); await _w(0.3); await _shot("q_front_direct")
		get_tree().quit(); return
	if "--qa-brush" in OS.get_cmdline_user_args():
		await _w(1.0); m.mode = "busy"; await m.walk_to(m.OBJ.sink.spot, m.OBJ.sink.yaw)
		m.hero.hold_item(m.PROPS + "Toothbrush.tscn", "long", 0.19, false)
		if m.has_method("_brush_grip"): m._brush_grip(true)
		await m._hand_to_face(0.0); await _w(0.5)
		var dbg = m.box(Vector3(0.012, 0.012, 0.012), m.mouth_pos(), Color(1, 0, 0), m, 2.0)
		var v = OS.get_environment("MOUTH")
		if v != "": var a = v.split(","); m.MOUTH = Vector3(float(a[0]), float(a[1]), float(a[2]))
		await _w(0.1); dbg.global_position = m.mouth_pos()
		print("DBG hero ", m.hero.global_position, " rot ", m.hero.rotation.y, " head ", m._head_pos(), " mouth ", m.mouth_pos(), " hand ", m._hand_pos("R"), " headbasis ", (m.hero.skeleton.global_transform * m.hero.skeleton.get_bone_global_pose(m.hero.skeleton.find_bone("Head"))).basis, " cam ", m.cam.global_position)
		var i := 0
		for c in [{"side": 1.57, "h": 1.5, "d": 0.7, "up": 0.0, "mouth": 1}, {"side": -1.57, "h": 1.5, "d": 0.7, "up": 0.0, "mouth": 1}, {"side": 0.9, "h": 1.5, "d": 0.6, "up": 0.05, "mouth": 1}]:
			cu = c; _cu_update(); await _w(0.2); await _shot("q_brush_%d" % i); i += 1
		get_tree().quit(); return
	if "--qa-hands" in OS.get_cmdline_user_args():   # house.17: prop hand == moving hand (front + side close-ups)
		await _w(1.0)
		var fr := {"side": 0.35, "h": 1.4, "d": 1.1, "up": 0.05}
		var sd := {"side": 1.3, "h": 1.4, "d": 1.2, "up": 0.05}
		var cams := []; var ts := []
		for i in 26: ts.append(1.0 + i * 0.8); cams.append(fr if i % 2 == 0 else sd)
		shot_dir_hands = true
		await _act("sink", "teeth", "v17/h_teeth", ts, cams)
		var ts2 := []; var c2 := []
		for i in 30: ts2.append(4.0 + i * 0.35); c2.append(fr if i % 2 == 0 else sd)
		await _act("sink", "face", "v17/h_face", ts2, c2)
		get_tree().quit(); return
	if "--qa-doors" in OS.get_cmdline_user_args():   # house.17: hinged doors (swing) both doors open
		await _w(1.5); m.S.door = "open"; m.S.door_bed = "open"; m._apply_states(true); await _w(1.6)
		await _shot("v17/door_bath_swing_inside")
		_log("door rot %.1f door_bed rot %.1f" % [rad_to_deg(m.N.door.rotation.y), rad_to_deg(m.N.door_bed.rotation.y)])
		get_tree().quit(); return
	if "--qa-new" in OS.get_cmdline_user_args():
		await _w(1.0); await new_actions(); get_tree().quit(); return
	m.task_completed.connect(func(t): sig[t] = true)
	m.bathroom_completed.connect(func(): sig["completed"] = true)
	await _w(1.5); await _shot("b00_overview")
	m.cam.yaw = -0.6; await _w(1.2); await _shot("b01_overview_left"); m.cam.yaw = 0.6; await _w(1.2); await _shot("b02_overview_right"); m.cam.yaw = 0.0
	# door is locked before tasks
	m.do_verb("door", m.verbs("door")[0]); await _w(0.5)
	while m.mode != "play": await _w(0.2)
	_log("door locked before tasks: %s" % (m.S.door == "closed"))
	# wash face
	m.do_verb("sink", m.verbs("sink")[0])
	var t := 0.0; var shots := [3.0, 7.0, 10.5, 17.5]; var si := 0
	while m.mode != "play":
		await _w(0.1); t += 0.1
		if si < shots.size() and t >= shots[si]: await _shot("b1%d_wash_face" % si); si += 1
	_log("wash face done: %s signal: %s" % [m.S.face_done, sig.has("wash_face")])
	_log("mission now: " + m.mission)
	# brush teeth
	m.do_verb("sink", m.verbs("sink")[1])
	t = 0.0; shots = [1.6, 4.5, 10.5, 11.8, 17.0]; si = 0
	while m.mode != "play":
		await _w(0.1); t += 0.1
		if si < shots.size() and t >= shots[si]: await _shot("b2%d_brush_teeth" % si); si += 1
	_log("brush teeth done: %s signal: %s brush back in cup: %s" % [m.S.teeth_done, sig.has("brush_teeth"), m.S.brush == "cup"])
	_log("mission now: " + m.mission)
	# a few states
	m.do_verb("bath", _vk("bath", "shower")); while m.mode != "play": await _w(0.2)
	m.do_verb("bath", _vk("bath", "curtain")); while m.mode != "play": await _w(0.2)
	await _w(0.5); await _shot("b30_shower")
	var new_ok := await new_actions()
	new_ok = (await timing_pass()) and new_ok; _log("new actions: %s" % new_ok); m.cam.yaw = 0.0
	m.do_verb("cabinet", m.verbs("cabinet")[0]); while m.mode != "play": await _w(0.2)
	await _shot("b31_cabinet")
	m.phone_btn.pressed.emit()
	var tw0 := 0.0
	while not m.phone.visible and tw0 < 20.0: await _w(0.2); tw0 += 0.2   # house.17: waits for the narrator + pocket take-out
	await _w(0.8); await _shot("b70_phone")
	var ph_ok: bool = m.phone.visible
	m.phone.close(); tw0 = 0.0
	while m.mode != "play" and tw0 < 15.0: await _w(0.2); tw0 += 0.2
	ph_ok = ph_ok and m.mode == "play" and not m.phone.visible
	_log("phone opens + closes in the bathroom: %s" % ph_ok)
	m.cam.dist = 5.0; m.cam.yaw = 0.9; await _w(1.2); await _shot("b71_camera_zoom_rotate"); m.cam.dist = 7.6; m.cam.yaw = 0.0; await _w(0.8)
	var bk_ok := true
	if m.S.cabinet == "open": m.do_verb("cabinet", m.verbs("cabinet")[0]); while m.mode != "play": await _w(0.2)
	if m.extras and m.extras.has_method("qa"):
		var r = await m.extras.qa(m); bk_ok = r != false; _log("bk_extras qa: %s" % bk_ok)
	# house.17: doors are one chip that opens + changes scene (tested end-to-end in qa_flow --qa-e2e)
	_log("bedroom door chip: %s" % str(m.verbs("door_bed")))
	_log("living room door chip: %s" % str(m.verbs("door")))
	sig["completed"] = m.verbs("door").size() == 1 and m.verbs("door")[0][0] == "Go to the living room" and m.verbs("door_bed")[0][0] == "Go to the bedroom"
	_log("voice clips queued: %d, Turkish clips: %d" % [m.voice_log.size(), m.voice_log.filter(func(x): return not x.begins_with("en:")).size()])
	var missing := []
	for k in m.TR: if not m.vindex.has("en:" + k) and not k.begins_with("I'm in the"): missing.append(k)   # house.17: room captions are silent
	_log("lines without clips: %s" % str(missing))
	var ok: bool = ph_ok and new_ok and m.S.face_done and m.S.teeth_done and sig.has("completed") and missing.is_empty() and m.vindex.keys().all(func(k): return k.begins_with("en:"))
	_log("RESULT: " + ("PASS" if ok else "FAIL") + " (bathroom core: tasks, doors, new actions, phone, voice)")
	if m.extras: _log("BK_EXTRAS RESULT (black bot's scale/medicine/make-up, scripts/bk_qa.gd): " + ("PASS" if bk_ok else "FAIL"))
	var f := FileAccess.open("res://qa_bathroom.log", FileAccess.WRITE); f.store_string("\n".join(log_lines))
	get_tree().quit()

## close-up camera: side = angle around the hero (0 = in front), h = target height, d = distance
var cu := {}
func _cu_update() -> void:
	if cu.is_empty(): m.qa_cam = {}; return
	var hp: Vector3 = m.hero.global_position
	var a: float = m.hero.rotation.y + cu.side
	var at := hp + Vector3(0, cu.h, 0)
	if cu.has("mouth"): at = m.mouth_pos(); hp = Vector3(at.x, 0, at.z)
	m.qa_cam = {"pos": at + Vector3(sin(a), 0, cos(a)) * cu.d + Vector3(0, cu.get("up", 0.15), 0), "at": at}

func _act(id: String, key: String, prefix: String, times: Array, cams: Array) -> float:
	var v: Array = []
	for x in m.verbs(id): if x[2] == key: v = x
	m.do_verb(id, v)
	var t := 0.0; var si := 0
	while m.mode != "play" or t < 0.3:
		await _w(0.1); t += 0.1
		if si < times.size() and t >= times[si] - 0.6: cu = cams[si]
		_cu_update()
		if m.censor and m.censor.visible: censor_seen = true
		if m.shower_snd and m.shower_snd.playing: loop_seen = true
		if m.S.shower == "on" and m.S.curtain == "closed" and m.hero.position.x > m.RX - 0.8: curtain_closed_in = true
		if si < times.size() and t >= times[si]: await _shot("%s_%02d" % [prefix, si]); si += 1
		if t > 120: break
	cu = {}; _cu_update()
	return t

var shot_dir_hands := false
var censor_seen := false
var loop_seen := false
var curtain_closed_in := false
func new_actions() -> bool:
	var ok := true
	var front := {"side": 1.25, "h": 1.45, "d": 1.3}
	var mouth := {"side": 1.0, "h": 1.5, "d": 0.65, "up": 0.04, "mouth": 1}
	var hips := {"side": 0.8, "h": 0.8, "d": 1.7, "up": 0.5}
	var cs_ok := func(): return m.censor != null and m.censor.visible
	# brush teeth close-ups (toothbrush in the palm, head at the mouth)
	var tb := await _act("sink", "teeth", "b40_brush_closeup", [5.6, 6.6, 7.6], [mouth, mouth, mouth])
	_log("brush teeth again (%.1fs) brush back in cup: %s" % [tb, m.S.brush == "cup"]); ok = ok and m.S.brush == "cup"
	var tf := await _act("sink", "face", "b41_face_closeup", [2.2, 3.4], [front, front])
	_log("wash face (%.1fs, v12 was ~20s; washing part 9.7s -> 4.3s)" % tf); ok = ok and tf < 20.0
	for kind in ["pee", "poop"]:
		censor_seen = false
		var tp := await _act("toilet", kind, "b5%d_toilet_%s" % [0 if kind == "pee" else 1, kind], [3.6, 4.6, 7.5] if kind == "pee" else [3.6, 5.6, 6.6], [hips, hips, hips])
		var snd: bool = ("trickle" if kind == "pee" else "plop") in Audio.sfx_log
		var fine: bool = snd and censor_seen and not cs_ok.call() and absf(m.hero.position.y) < 0.01 and m.hero.player.current_animation == "idle"
		var td: float = m.last_dur.get(kind, 99.0); var fdd: float = m.last_dur.get("face", 0.0)
		pass
		_log("toilet %s action %.1fs <= wash face %.1fs: %s" % [kind, td, fdd, td <= fdd])
		_log("toilet %s (%.1fs): censor shown while seated %s, off after %s, sound %s, all ok %s" % [kind, tp, censor_seen, not cs_ok.call(), snd, fine]); ok = ok and fine
	censor_seen = false
	var ts := await _act("bath", "takeshower", "b60_shower", [2.0, 4.0, 5.5, 7.0, 9.5, 11.5, 13.5], [hips, hips, front, hips, hips, hips, hips])
	await _w(0.7)
	var sd: float = m.last_dur.get("takeshower", 99.0)
	_log("shower action %.2fs (no cap, with screenshots)" % sd)
	_log("hum played: %s (%s)" % ["hum_m" if m.S.gender != "women" else "hum_f", m.hum_snd != null and not m.hum_snd.playing])
	var loop_ok: bool = loop_seen and not m.shower_snd.playing
	var cur_ok: bool = curtain_closed_in and m.S.curtain == "open"
	_log("shower curtain closed while showering (player in tub): %s, open again after: %s" % [curtain_closed_in, m.S.curtain == "open"])
	var sfine: bool = cur_ok and loop_ok and censor_seen and not cs_ok.call() and absf(m.hero.position.y) < 0.01 and m.S.shower == "off"
	_log("shower (%.1fs): censor shown %s, off after %s, shower loop sound on->off %s, all ok %s" % [ts, censor_seen, not cs_ok.call(), loop_ok, sfine]); ok = ok and sfine
	return ok

func _vk(id: String, key: String) -> Array:
	for x in m.verbs(id): if x[2] == key: return x
	return []

## durations without screenshots (PNG saving stalls frames and inflates wall-clock timings)
func _run(id: String, key: String) -> float:
	m.do_verb(id, _vk(id, key)); await _w(0.2)
	while m.mode != "play": await _w(0.1)
	return float(m.last_dur.get(key, 0.0))

func timing_pass() -> bool:
	var face := await _run("sink", "face")
	var pee := await _run("toilet", "pee")
	var poop := await _run("toilet", "poop")
	var shower := await _run("bath", "takeshower")
	var ok: bool = pee <= face and poop <= face
	_log("timing (game time, no screenshots): wash face %.2fs, pee %.2fs <= face, poop %.2fs <= face, shower %.2fs (no cap) -> %s" % [face, pee, poop, shower, ok])
	return ok
