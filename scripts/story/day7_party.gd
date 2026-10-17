## v33 (red): DAY 7 SURPRISE PARTY (living room) = day4_evening.gd interpreter + the surprise.
## prepare(lr) (livingroom.gd _intro, first line): coming home on day 7 (story.d7 "home"/"evening", no d7_surprise_done)
##   the room is DARK (lights, TV off, curtains closed) and the family is hidden (behind the sofa).
## run(): data/day7.json "party" steps (once, flag story.d7_surprise_done):
##   {"do": "reveal"}      the light goes on, the family jumps up behind the sofa and waves, balloons + banner
##   {"do": "photo_wall"}  the week's polaroids (days 1-6, existing storage: Life.photo(key)); for each day a family
##                         question "What did you do on day N?" and the player's past-simple answer; then the family sits
##   {"do": "cake"}        a cake on the coffee table
## then the "evening" steps (couch talk with scrambled past-simple sentences, the d7_party polaroid) -> "Go to bed.".
## Blue's days 5 / 6: photo + caption from any data/day5*.json / day6*.json "recap" [[key, caption], ...] whose photo exists,
## else from story.d5_recap / d6_recap keys (bedtime.gd stores them), else that day's card is left out.
extends "res://scripts/story/day4_evening.gd"

const BALLOONS := [Color(0.95, 0.3, 0.35), Color(0.3, 0.6, 0.95), Color(0.98, 0.8, 0.25), Color(0.5, 0.85, 0.45), Color(0.85, 0.45, 0.9)]

func _init() -> void:
	data_path = "res://data/day7.json"; steps_key = "evening"; bed_flag = "d7_bed_pending"

static func _flag(k: String) -> bool:
	var sv = App.load_save().get("story", {})
	return sv is Dictionary and bool(sv.get(k, false))

static func _setf(k: String, v) -> void:
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv[k] = v; App.patch_save({"story": sv})

static func prepare(lr: Node) -> void:
	if maxi(WorldState.day, App.day) != 7 or _flag("d7_surprise_done"): return
	var sv = App.load_save().get("story", {})
	var st := String(sv.get("d7", "")) if sv is Dictionary else ""
	if not st in ["home", "evening"]: return
	if not lr.breakfast_members.is_empty(): lr.family_at_tv_now()
	for bm in lr.humans():
		if bm.node is Node3D: bm.node.visible = false
	lr.S.ceiling = "off"; lr.S.floorlamp = "off"; lr.S.tv = "off"; lr.S.curtains = "closed"; lr._apply_states()
	if lr.env: lr.env.ambient_light_energy = 0.05
	lr.set_meta("d7_dark", true)

func _before() -> void:
	if _flag("d7_surprise_done"):
		for bm in hs:
			if bm.node is Node3D: bm.node.visible = true
		return
	_dark = true; _restore_dark()
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	if lr.get("touch"): lr.touch.visible = false
	if lr.wall_fade: lr.wall_fade.force_fade(true)
	for e in D.get("party", []):
		if not is_instance_valid(lr): return
		await _step(e)
	_setf("d7_surprise_done", true)
	lr.set_meta("d7_dark", false)

func _do(what: String, e: Dictionary) -> void:
	match what:
		"reveal": await _reveal()
		"photo_wall": await _photo_wall()
		"cake": _cake()
		_: await super._do(what, e)

func _reveal() -> void:
	_dark = false
	lr.S.ceiling = "on"; lr.S.curtains = "open"; _light_env(); Audio.sfx("metalClick", 2.0)
	_decor()
	var spots := [Vector3(3.5, 0, -0.9), Vector3(3.5, 0, 0.0), Vector3(3.5, 0, 0.9), Vector3(3.3, 0, 1.7)]
	var ctr := Vector3.ZERO
	for i in hs.size():
		var bm: Dictionary = hs[i]
		if not bm.node is DemoCharacter: continue
		var ch: DemoCharacter = bm.node
		if bm.has("tw") and bm.tw: bm.tw.kill()
		ch.bone_offsets.clear(); ch.set_meta("seat", "")   # standing now (NpcTalk turns the body)
		ch.position = spots[i % spots.size()] + Vector3(0, 0, 0.0 if i < spots.size() else 0.5 * (i - spots.size() + 1))
		var dv: Vector3 = lr.hero.global_position - ch.global_position
		ch.rotation.y = atan2(dv.x, dv.z)
		ch.visible = true; ch.player.speed_scale = 1.0; ch.play("wave", 0.15)
		ctr += ch.position
	if not hs.is_empty(): ctr /= float(hs.size())
	else: ctr = Vector3(3.4, 0, 0.3)
	Audio.sfx("plop", -2.0); Audio.sfx("plop", 0.0, 1.3)
	# v33 QA: the old shot (1.4 m behind the player at the front door) was inside the south wall: the screen showed only wall.
	# Now: inside the room, 3 m in front of the family (TV side).
	var cp := ctr + Vector3(-3.0, 1.7, 1.0)   # from the TV side: the family jumps up behind the sofa, the player is not in front of the lens
	cp.z = clampf(cp.z, -2.4, 2.4); cp.x = clampf(cp.x, -2.8, 5.5)
	lr.cam_shot = {"pos": cp, "at": ctr + Vector3(0, 1.1, 0)}
	await _w(1.6)
	for bm in hs:
		if bm.node is DemoCharacter: bm.node.play("idle", 0.4)

func _decor() -> void:
	for i in 7:
		var s := SphereMesh.new(); s.radius = 0.16; s.height = 0.38
		var p := Vector3(2.2 + (i % 4) * 0.55, 2.05 + (i % 3) * 0.12, -1.6 + i * 0.5)
		_mesh(s, p, BALLOONS[i % BALLOONS.size()])
		var st := BoxMesh.new(); st.size = Vector3(0.006, 0.7, 0.006); _mesh(st, p - Vector3(0, 0.55, 0), Color(0.9, 0.9, 0.9))
	var lb := Label3D.new(); lb.text = "Congratulations!"; lb.font_size = 96; lb.pixel_size = 0.004; lb.modulate = Color(0.95, 0.35, 0.45)
	lb.outline_size = 18; lb.outline_modulate = Color(1, 1, 1); lb.position = Vector3(2.6, 2.15, -2.9); add_child(lb)

const CAKE := Vector3(-0.15, 0, -0.4)   # v33 QA: free corner of the coffee table (was inside the fruit bowl)
func _cake() -> void:
	var c1 := CylinderMesh.new(); c1.top_radius = 0.16; c1.bottom_radius = 0.16; c1.height = 0.1
	_mesh(c1, TABLE + CAKE + Vector3(0, 0.05, 0), Color(0.55, 0.36, 0.22))
	var c2 := CylinderMesh.new(); c2.top_radius = 0.165; c2.bottom_radius = 0.165; c2.height = 0.03
	_mesh(c2, TABLE + CAKE + Vector3(0, 0.115, 0), Color(0.98, 0.9, 0.95))
	var ch := SphereMesh.new(); ch.radius = 0.025; ch.height = 0.05
	for a in 5: _mesh(ch, TABLE + CAKE + Vector3(cos(a * TAU / 5) * 0.1, 0.14, sin(a * TAU / 5) * 0.1), Color(0.85, 0.1, 0.15))
	Audio.sfx("place_clink", -6.0)

# ------------------------------------------------------------------ the week's polaroids
## [{day, key, q, en, tr}] for every day that has a photo
func _week() -> Array:
	var out: Array = []
	for w in D.get("week", []):
		var d := int(w.get("day", 0))
		var key := ""; var en := String(w.get("en", "")); var tr := String(w.get("tr", ""))
		for k in w.get("keys", []):
			if Life.photo(String(k)) != null: key = String(k); break
		if key == "" and bool(w.get("blue", false)):
			var r := _blue_recap(d)
			if not r.is_empty(): key = r[0]; en = r[1]; tr = T.tr_of(en)
		if key == "": continue
		out.append({"day": d, "key": key, "q": String(w.get("q", "")), "en": en, "tr": tr})
	return out

## blue's day: [photo key, caption] from data/day<d>*.json "recap", else a saved story.d<d>_recap key with a photo
func _blue_recap(d: int) -> Array:
	var dir := DirAccess.open("res://data")
	if dir:
		for f in dir.get_files():
			var fn := String(f).trim_suffix(".remap")
			if not (fn.begins_with("day%d" % d) and fn.ends_with(".json")): continue
			var j = App.load_json("res://data/" + fn)
			if not (j is Dictionary and j.get("recap") is Array): continue
			for r in j.recap:
				if r is Array and r.size() >= 2 and Life.photo(String(r[0])) != null: return [String(r[0]), String(r[1])]
	var sv = App.load_save().get("story", {})
	var keys = sv.get("d%d_recap" % d, []) if sv is Dictionary else []
	if keys is Array:
		for k in keys:
			if Life.photo(String(k)) != null: return [String(k), "I had a good day."]
	return []

func _photo_wall() -> void:
	var wk := _week()
	if wk.is_empty(): return
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	var dim := ColorRect.new(); dim.color = Color(0.1, 0.08, 0.2, 0.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(dim)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 26); grid.add_theme_constant_override("v_separation", 14)
	grid.set_anchors_preset(Control.PRESET_CENTER_TOP); grid.offset_top = 24; grid.offset_left = -270; grid.offset_right = 270; grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(grid)
	var tw := create_tween(); tw.tween_property(dim, "color:a", 0.55, 0.6)
	var cards: Array = []
	for i in wk.size():
		var c := T.card(String(wk[i].key), "Day %d" % int(wk[i].day), i, 150.0)
		c.modulate.a = 0.0; grid.add_child(c); cards.append(c)
		var ct := create_tween(); ct.tween_property(c, "modulate:a", 1.0, 0.4); await ct.finished
	for i in wk.size():
		var tl: Control = (cards[i] as Control).get_child(0)
		var up := create_tween(); up.tween_property(tl, "scale", Vector2(1.18, 1.18), 0.3).set_trans(Tween.TRANS_BACK)
		if String(wk[i].q) != "": await T.fam(lr, _who("fam%d" % i), String(wk[i].q))
		await T.me(lr, String(wk[i].en), String(wk[i].tr))
		var dn := create_tween(); dn.tween_property(tl, "scale", Vector2.ONE, 0.3)
	await _w(0.6)
	# the family sits down while the screen is dark (no visible teleport)
	var ft := create_tween(); ft.tween_property(dim, "color", Color(0.02, 0.02, 0.05, 1.0), 0.6); ft.parallel().tween_property(grid, "modulate:a", 0.0, 0.6); await ft.finished
	if not lr.breakfast_members.is_empty(): lr.family_at_tv_now()
	lr.S.tv = "off"; lr._apply_states()
	hs = lr.humans()
	lr.cam_shot = {}
	await _w(0.3)
	var bt := create_tween(); bt.tween_property(dim, "color:a", 0.0, 0.6); await bt.finished
	cl.queue_free()
