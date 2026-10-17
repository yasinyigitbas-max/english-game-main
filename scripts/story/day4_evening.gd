## v33 (red): DAY 4 EVENING - the family couch talk and the POWER CUT (living room, livingroom.gd as `lr`).
## Data-driven: data/day4.json "evening" = a list of steps, played in order:
##   {"who": "fam0|fam1|me|nar|all", "en": "...", "tr": "..."}   a line (family = own voice + NpcTalk, me = "Me: ...")
##   {"puzzle": "The torch is next to the candles.", "tr": "..."} scrambled words (sentence in the ONE caption box)
##   {"do": "couch"}       Life.guide_to the sofa "Talk to my family." -> the player walks there -> sits; walls force-faded
##   {"do": "props"}       candles, a box of matches and the torch appear on the coffee table (the shopping)
##   {"do": "power_cut"}   every light + the TV go off, the room goes dark (kept dark every frame)
##   {"do": "guide", "en": "Find the torch.", "at": "torch"|"candles"|"sofa"}   objective + camera pan, then the couch shot again
##   {"do": "torch"} / {"do": "candles"} / {"do": "candles_out"} / {"do": "lights_on"}
##   {"do": "snap", "key": "d4_candles"}  polaroid: "Take a photo." pan + flash + Life.snap_from (the player on the sofa)
## End: stand up, "Go to bed." pan to the bedroom door (story.d4_bed_pending -> bedtime: day4_bedtime.gd).
## day7_party.gd extends this file (same interpreter, more "do" steps).
## ENTRY (Day4Routine): var e = load(this).new(); e.lr = lr; lr.add_child(e); await e.run()
extends Node

const T := preload("res://scripts/story/day4_talk.gd")
const TABLE := Vector3(0.85, 0.44, 0.0)   # livingroom.gd _build_coffee_table: centre, top height
var lr: Node
var data_path := "res://data/day4.json"
var steps_key := "evening"
var bed_flag := "d4_bed_pending"
var D := {}
var hs: Array = []
var _keep_pose := false
var _keep_obj := ""
var _dark := false
var _couch_shot := {}
var torch: MeshInstance3D   # spawned props (_props)
var spot: SpotLight3D
var candle_light: OmniLight3D
var flames: Array = []

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run() -> void:
	D = App.load_json(data_path); D = D if D is Dictionary else {}
	load("res://scripts/story/day4_breakfast.gd").load_lines(lr.XTR, data_path)
	await _w(1.0); await Audio.wait_idle(10.0)
	Life.event("home")
	hs = lr.humans()
	await _before()
	for e in D.get(steps_key, []):
		if not is_instance_valid(lr): return
		await _step(e)
	await _end()

func _before() -> void: pass   # day7_party.gd: the surprise

func _who(w: String) -> Dictionary:
	if hs.is_empty() or not w.begins_with("fam"): return {}
	return hs[int(w.trim_prefix("fam")) % hs.size()]

func _step(e: Dictionary) -> void:
	if e.has("do"): await _do(String(e.do), e); return
	if e.has("puzzle"): await T.puzzle(lr, String(e.puzzle), String(e.get("tr", ""))); return
	var en := String(e.get("en", "")); var w := String(e.get("who", "nar")); var tr := String(e.get("tr", ""))
	if en == "": return
	match w:
		"me": await T.me(lr, en, tr)
		"all": await T.all(lr, hs, en)
		"nar": await T.line(lr, en)
		_: await T.fam(lr, _who(w), en, tr)

func _do(what: String, e: Dictionary) -> void:
	match what:
		"couch": await _couch()
		"props": _props()
		"power_cut": await _power_cut()
		"guide": await _guide(String(e.get("en", "")), String(e.get("at", "sofa")))
		"torch": _torch(true)
		"candles": _candles(true)
		"candles_out": _candles(false)
		"lights_on": _lights_on()
		"snap": await _snap(String(e.get("key", "d4_candles")))

# ------------------------------------------------------------------ couch (day3_evening.gd pattern)
func _sofa_at() -> Vector3:
	if lr.get("N") is Dictionary and lr.N.has("sofa") and lr.N.sofa is Node3D: return (lr.N.sofa as Node3D).global_position + Vector3(0, 0.7, 0)
	return Vector3(lr.SOFA_X, 0.7, 0.0)

func _couch() -> void:
	if not hs.is_empty():
		var at_tv := hs.all(func(b): return String(b.seat).begins_with("sofa") or String(b.seat) in ["armchair", "tv_stand"])
		if not at_tv: lr.family_at_tv_now(); _restore_dark()
	_keep_pose = true
	var at := _sofa_at()
	lr.mode = "busy"
	await Life.guide_to({"pos": at + Vector3(-3.0, 1.4, 0.4), "at": at}, "Talk to my family.", {"tr": "Ailemle konuş.", "id": "Talk to my family."})
	lr.mode = "play"; lr._update_hand()
	if lr.get("touch"): lr.touch.visible = true   # the player walks to the sofa
	_keep_obj = "Talk to my family."
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(lr):
		var h: Vector3 = lr.hero.global_position
		if String(lr.S.seat).begins_with("sofa") or Vector2(h.x, h.z).distance_to(Vector2(lr.SOFA_X, 0.0)) < 1.9: break
		if Time.get_ticks_msec() - t0 > 600000: break
		await _w(0.25)
	if not is_instance_valid(lr): return
	while lr.mode == "busy" and String(lr.S.seat) == "": await _w(0.2)
	_keep_obj = ""
	_couch_flags()
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	Objectives.complete("Talk to my family.")
	if lr.wall_fade: lr.wall_fade.force_fade(true)
	await _sit()
	if lr.get("touch"): lr.touch.visible = false   # v33 QA: no joystick / hand button over the couch cinematic
	_couch_shot = {"pos": Vector3(lr.SOFA_X - 2.6, 1.55, 0.9), "at": Vector3(lr.SOFA_X, 0.85, 0.0)}
	lr.cam_shot = _couch_shot
	await _w(1.0); await Audio.wait_idle(12.0)

## plays once even if the app is closed mid-talk: a continued game only gets "Go to bed."
func _couch_flags() -> void:
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv[bed_flag] = true; sv[bed_flag.replace("_bed_pending", "_couch_done")] = true; App.patch_save({"story": sv})

func _sit() -> void:
	if String(lr.S.seat).begins_with("sofa"): return
	var taken: Array = []
	for f in lr.family: taken.append(String(f.get_meta("seat", "")))
	var seat := ""
	for k in ["sofa_middle", "sofa_left", "sofa_right"]:
		if not k in taken: seat = k; break
	if seat != "":
		await lr.walk_to(lr.sit_spot(seat), lr.SEATS[seat].yaw)
		lr.caption("I am sitting on the sofa.")
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
	else:
		await lr.walk_to(Vector3(lr.SOFA_X - 1.3, 0, 0.0), PI / 2)
		lr.caption("I am standing next to the sofa.")

## objective + Life.guide_to pan onto a prop, then back to the couch shot
func _guide(en: String, at_id: String) -> void:
	var at := _sofa_at()
	if at_id == "torch" and torch: at = torch.global_position
	elif at_id in ["candles", "table", "cake"]: at = TABLE + Vector3(0, 0.1, 0)
	var pos := at + Vector3(-1.6, 1.2, 0.9) if at_id != "sofa" else at + Vector3(-3.0, 1.4, 0.4)
	await Life.guide_to({"pos": pos, "at": at}, en, {"tr": T.tr_of(en), "id": en})
	if not _couch_shot.is_empty(): lr.cam_shot = _couch_shot
	Objectives.complete(en)

# ------------------------------------------------------------------ props + lights
func _mesh(m: Mesh, p: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = m
	var mat := StandardMaterial3D.new(); mat.albedo_color = c
	if emit > 0.0: mat.emission_enabled = true; mat.emission = c; mat.emission_energy_multiplier = emit; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat; mi.position = p; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if emit > 0.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi); return mi

func _props() -> void:
	if torch: return
	var cyl := CylinderMesh.new(); cyl.top_radius = 0.022; cyl.bottom_radius = 0.022; cyl.height = 0.12
	flames = []
	for p in [Vector3(-0.12, 0, -0.38), Vector3(0.08, 0, -0.28), Vector3(-0.05, 0, -0.16)]:
		_mesh(cyl, TABLE + p + Vector3(0, 0.06, 0), Color(0.97, 0.95, 0.88))
		var fl := SphereMesh.new(); fl.radius = 0.012; fl.height = 0.035
		var f := _mesh(fl, TABLE + p + Vector3(0, 0.135, 0), Color(1.0, 0.7, 0.25), 4.0); f.visible = false; flames.append(f)
	var bx := BoxMesh.new(); bx.size = Vector3(0.06, 0.016, 0.04)
	_mesh(bx, TABLE + Vector3(0.12, 0.008, 0.12), Color(0.8, 0.18, 0.15))
	var tm := CylinderMesh.new(); tm.top_radius = 0.02; tm.bottom_radius = 0.026; tm.height = 0.2
	torch = _mesh(tm, TABLE + Vector3(-0.05, 0.026, 0.32), Color(0.12, 0.13, 0.16)); torch.rotation.z = PI / 2
	var cl := OmniLight3D.new(); cl.light_color = Color(1.0, 0.72, 0.42); cl.omni_range = 4.5; cl.light_energy = 0.0; cl.shadow_enabled = true
	cl.position = TABLE + Vector3(0, 0.35, -0.25); add_child(cl); candle_light = cl
	var sp := SpotLight3D.new(); sp.light_color = Color(1.0, 0.97, 0.88); sp.spot_range = 7.0; sp.spot_angle = 28.0; sp.light_energy = 0.0
	add_child(sp); sp.position = TABLE + Vector3(-0.15, 0.1, 0.32); sp.look_at(Vector3(-3.0, 0.9, 0.6), Vector3.UP); spot = sp

func _power_cut() -> void:
	Audio.sfx("metalClick", 2.0)
	_dark = true; _restore_dark()
	await _w(0.8)

## everything off + dark ambient (re-applied every frame while _dark: the room's own _apply_states() may run)
func _restore_dark() -> void:
	if not _dark: return
	lr.S.ceiling = "off"; lr.S.floorlamp = "off"; lr.S.tv = "off"; lr._apply_states()
	_lamp_off = false; _dark_env()

func _dark_env() -> void:
	if is_instance_valid(lr.sun): lr.sun.light_energy = 0.0
	if lr.env: lr.env.ambient_light_energy = 0.035; lr.env.ambient_light_color = Color(0.55, 0.62, 0.9)   # moonlit blue, not pitch black
	# v33 QA: the window showed a bright daytime sky and the table lamp glowed during the power cut
	if lr.get("N") is Dictionary:
		if lr.N.get("sky") is StandardMaterial3D: (lr.N.sky as StandardMaterial3D).albedo_color = Color(0.1, 0.11, 0.2)
		if lr.N.get("tlamp_shade") is MeshInstance3D and not _lamp_off: _lamp_off = true; lr.N.tlamp_shade.material_override = lr._mat(Color(0.98, 0.9, 0.75), 0.0)
var _lamp_off := false

func _light_env() -> void:   # undo _dark_env (the room's _apply_states() sets sky, sun and ambient energy again)
	_lamp_off = false
	if lr.env: lr.env.ambient_light_color = Color(1.0, 0.97, 0.93)
	lr._apply_states()

func _torch(on: bool) -> void:
	if spot == null: _props()
	Audio.sfx("click"); spot.light_energy = 3.0 if on else 0.0

func _candles(on: bool) -> void:
	if candle_light == null: _props()
	if on: Audio.sfx("swish", -6.0)
	for f in flames: (f as Node3D).visible = on
	candle_light.light_energy = 1.6 if on else 0.0

func _lights_on() -> void:
	_dark = false
	lr.S.ceiling = "on"; _light_env(); Audio.sfx("metalClick", 2.0)
	if spot: spot.light_energy = 0.0

var _ft := 0.0
func _process(d: float) -> void:
	_ft += d
	if _dark and is_instance_valid(lr): _dark_env()
	if candle_light and candle_light.light_energy > 0.0:   # candle flicker
		candle_light.light_energy = 1.5 + sin(_ft * 13.0) * 0.08 + sin(_ft * 5.3) * 0.1
	_kt += d
	if _kt < 0.4 or not is_instance_valid(lr): return
	_kt = 0.0
	if _keep_obj != "" and not Objectives.has(_keep_obj) and lr.mode != "busy": lr._set_mission(_keep_obj)
	if not _couch_shot.is_empty() and lr.mode == "busy" and lr.get("touch") and lr.touch.visible: lr.touch.visible = false   # Life.guide_to shows it again after each pan
	if _keep_pose:   # the family stays seated (day3_evening.gd rule)
		for bm in lr.humans():
			var seat := String(bm.seat)
			if not (seat.begins_with("sofa") or seat == "armchair") or not bm.node is DemoCharacter: continue
			var ch: DemoCharacter = bm.node
			if not ch.visible: continue
			if String(ch.player.current_animation) != "sit_idle":
				if bm.has("tw") and bm.tw: bm.tw.kill()
				lr.sit_down(ch, seat, false)
var _kt := 0.0

# ------------------------------------------------------------------ polaroid
func _snap(key: String) -> void:
	await _guide("Take a photo.", "sofa")
	var h: Vector3 = lr.hero.global_position
	var at := h + Vector3(0, 0.75, 0)
	var eye := at + Vector3(-2.2, 0.55, 0.35)
	Audio.sfx("click", 2.0)
	var cl := CanvasLayer.new(); cl.layer = 40; add_child(cl)
	var fl := ColorRect.new(); fl.color = Color(1, 1, 1, 0.85); fl.set_anchors_preset(Control.PRESET_FULL_RECT); fl.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(fl)
	await Life.snap_from(key, Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), 45.0)
	var tw := create_tween(); tw.tween_property(fl, "color:a", 0.0, 0.5); await tw.finished; cl.queue_free()
	await T.line(lr, "Click! A photo for my album.")

# ------------------------------------------------------------------ end
func _end() -> void:
	_keep_pose = false
	if is_instance_valid(lr) and String(lr.S.seat) != "": await lr.stand_up()
	if not is_instance_valid(lr): return
	lr.cam_shot = {}
	if lr.wall_fade: lr.wall_fade.force_fade(false)
	_couch_shot = {}
	if lr.get("touch"): lr.touch.visible = true
	await bed_prompt()

## pan to the bedroom door + sound + top-left objective, control back to the player (also used on a continued game)
func bed_prompt() -> void:
	load("res://scripts/story/day4_breakfast.gd").load_lines(lr.XTR, data_path)
	var dv: Vector2 = lr.DOOR_BED
	var door := Vector3((dv.x + dv.y) / 2, 1.1, -3.0)
	lr.mode = "busy"
	await Life.guide_to({"pos": door + Vector3(0.4, 1.0, 2.6), "at": door}, "Go to bed.", {"tr": "Yatmaya git.", "id": "Go to bed."})
	lr.mode = "play"; lr._update_hand()
	_keep_obj = "Go to bed."
