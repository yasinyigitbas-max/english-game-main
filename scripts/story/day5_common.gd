## v33 (blue): DAYS 5 + 6 shared base. Every day-5/6 script extends this file (day5_routine.gd, day5_shop.gd, day6_storm.gd).
##  * story stages: save.json "story".d5 / .d6  ("alarm" -> "bath" -> "breakfast" -> "out" -> "event" -> "home" -> "couch" -> "bed" -> "done")
##  * own voice bank merged at runtime (nothing shared is rewritten): data/day56_voice_index.json -> voice/voice_025.bin (chunk 25 is opened by
##    Audio.reopen_banks, which scans voice_000..031); narrator packs data/day56_voice_index_<m|c|g>.json -> voice_<n>/voice_<n>_d56.bin
##    are appended to Audio.alt_files (re-merged whenever the narrator setting reloads the packs). Built by tools/days56/build_voice_days56.py.
##  * TR is text only (TR toggle): every line's TR is registered with the current scene's own TR source (XTR / TRD / extra_tr).
##  * one bottom-centre caption (the scene's own caption box, TR inside); lines wait for each other on Audio's single queue (never cut).
##  * data-driven steps (data/day5.json, data/day6.json): {who,en,tr} lines, {obj} objectives (Life.guide_to pan + sound + Objectives),
##    {choice} choice panel with EN feedback + TR, {do} scripted actions, {review} breakfast review. See tools/days56/days56_content.py.
class_name Day56
extends Node

const VOICE_IDX := "res://data/day56_voice_index.json"
const SHE_ROLES := ["mother", "sister", "grandmother", "wife", "daughter", "aunt"]
const PET_ROLES := ["dog", "cat", "bird", "fish", "rabbit", "hamster", "turtle"]
const VOICES_F := ["amy", "kristin", "hfc_female", "lessac"]   # = livingroom.gd voice_of()
const VOICES_M := ["ryan", "joe", "hfc_male"]
## ryan / lessac / hfc_male are not used for new lines (licence): the same family member speaks days 5-6 in a CC0 / PD voice

var sc: Node            # the current scene
var D: Dictionary = {}  # data/day<N>.json
var day := 5

# ------------------------------------------------------------------ story state
static func story() -> Dictionary:
	var sv = App.load_save().get("story", {})
	return sv if sv is Dictionary else {}

static func flag(k: String, v) -> void:
	var sv := story().duplicate(); sv[k] = v; App.patch_save({"story": sv})

static func stage(d: int) -> String: return String(story().get("d%d" % d, ""))
static func set_stage(d: int, v: String) -> void: flag("d%d" % d, v); print("D56 stage d%d = %s" % [d, v])

static func data(d: int) -> Dictionary:
	var j = App.load_json("res://data/day%d.json" % d)
	return j if j is Dictionary else {}

# ------------------------------------------------------------------ voice bank (merged into Audio at runtime)
static var _vidx := {}
static func ensure_voice() -> void:
	if _vidx.is_empty():
		var j = App.load_json(VOICE_IDX)
		_vidx = j if j is Dictionary and not j.is_empty() else {"_d56_none": [25, 0, 0, ""]}
	var k0: String = String(_vidx.keys()[0])
	if not Audio.index.has(k0):
		for k in _vidx:
			if not Audio.index.has(k): Audio.index[k] = _vidx[k]
	var n: String = Audio.narrator
	if n == "f": return
	var ai = App.load_json("res://data/day56_voice_index_%s.json" % n)
	var bin := "res://voice_%s/voice_%s_d56.bin" % [n, n]
	if not (ai is Dictionary) or ai.is_empty() or not FileAccess.file_exists(bin): return
	var a0: String = String(ai.keys()[0])
	if Audio.alt_index.has(a0): return
	var f := FileAccess.open(bin, FileAccess.READ)
	if f == null: return
	Audio.alt_files.append(f); var ci: int = Audio.alt_files.size() - 1
	for k in ai:
		if Audio.alt_index.has(k): continue
		var e: Array = (ai[k] as Array).duplicate(); e[0] = ci; Audio.alt_index[k] = e

static func clip_secs(key: String) -> float:
	var e = Audio.index.get(key, Audio.alt_index.get(key, []))
	return float(e[4]) if e is Array and e.size() > 4 else 3.0

# ------------------------------------------------------------------ TR (text only) + the one caption box
static func reg_tr(s: Node, en: String, tr: String) -> void:
	if s == null or not is_instance_valid(s) or tr == "": return
	var x = s.get("XTR")
	if x is Dictionary: x[en] = tr
	var t = s.get("TRD")
	if t is Dictionary: t[en] = tr
	if s.has_method("extra_tr") and s.get("extra") is Dictionary: s.extra_tr(""); s.extra[en] = tr
	var rp = s.get("room_phone")
	if rp is Object and is_instance_valid(rp) and rp.has_method("extra_tr") and rp.get("extra") is Dictionary: rp.extra_tr(""); rp.extra[en] = tr

static func reg_all(s: Node, lines: Dictionary) -> void:
	for k in lines: reg_tr(s, String(k), String(lines[k]))

static func show_cap(s: Node, cap: String, secs: float) -> void:
	if s == null or not is_instance_valid(s): return
	if "_mute_next" in s and s.get("hud") is Object and s.hud.has_method("caption"):   # UniversalScene (outside, shop) + bathroom: GameHUD caption
		s._mute_next = true; s.hud.caption(cap, maxf(4.5, secs + 1.2)); s._mute_next = false
	elif s.has_method("caption"): s.caption(cap, false)   # bedroom / living room caption box (kept while mode == "busy")

## show + speak one line, wait until it has been fully spoken (label = speaker prefix; voice "" = narrator / me)
static func speak(s: Node, label: String, label_tr: String, en: String, tr: String, voice := "") -> void:
	var tree := Engine.get_main_loop() as SceneTree
	ensure_voice()
	await Audio.wait_idle(15.0)
	var cap := en if label == "" else "%s: %s" % [label, en]
	reg_tr(s, cap, tr if label == "" else ("%s: %s" % [label_tr, tr] if tr != "" else ""))
	var key := Audio.norm(en) if voice == "" else "v_%s %s" % [voice, Audio.norm(en)]
	show_cap(s, cap, clip_secs(key))
	if voice != "": Audio.say_as(en, voice)
	else: Audio.say(en)
	await tree.create_timer(0.2, false).timeout
	await Audio.wait_idle(15.0)
	await tree.create_timer(0.45, false).timeout

# ------------------------------------------------------------------ family voices
## the family from save.json state.family, in livingroom.gd voice_of() order: [{name, voice, child}]
static func family_people() -> Array:
	var st = App.load_save().get("state", {})
	var fam = st.get("family", []) if st is Dictionary else []
	var out: Array = []; var nf := 0; var nm := 0; var nc := 0
	if not fam is Array: return out
	for m in fam.slice(0, 6):
		if not m is Dictionary: continue
		var role := String(m.get("role", ""))
		if role == "" or role in PET_ROLES: continue
		var fem: bool = role in SHE_ROLES or (role == "cousin" and String(m.get("pron", "she")) == "she")
		var v := ""
		if bool(m.get("child", false)):
			v = (["child_f", "child_m"][nc % 2] if fem else ["child_m", "child_f"][nc % 2]); nc += 1
		elif fem: v = VOICES_F[nf % VOICES_F.size()]; nf += 1
		else: v = VOICES_M[nm % VOICES_M.size()]; nm += 1
		out.append({"name": String(m.get("name", "")), "voice": v, "child": bool(m.get("child", false))})
	return out

# ------------------------------------------------------------------ step runner (override target / reach / act / spk in the day scripts)
func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run_steps(steps: Array) -> void:
	for s in steps:
		if not s is Dictionary: continue
		if s.has("review"): await review()
		elif s.has("do"): await act(String(s["do"]))
		elif s.has("obj"): await objective(String(s.obj), String(s.en), String(s.tr))
		elif s.has("choice"): await choose(s.choice)
		elif s.has("who"): await say(String(s.who), String(s.en), String(s.tr))

## who -> [label, label_tr, voice, node or null]
func spk(who: String) -> Array:
	var sp: Dictionary = D.get("speakers", {})
	if sp.has(who): return [String(sp[who][0]), String(sp[who][1]), String(sp[who][2]), null]
	if who == "famcall" or who.begins_with("fam"):
		var fp := family_people()
		if fp.is_empty(): return ["", "", "", null]
		var i := 0 if who == "famcall" else int(who.trim_prefix("fam")) % fp.size()
		return [String(fp[i].name), String(fp[i].name), String(fp[i].voice), null]
	return ["", "", "", null]

func say(who: String, en: String, tr: String) -> void:
	if who == "me": await speak(sc, "Me", "Ben", en, tr); return
	if who == "narr": await speak(sc, "", "", en, tr); return
	var s := spk(who)
	var n = s[3]
	if n is DemoCharacter and is_instance_valid(n):
		n.play("talk", 0.25)
		var h = sc.get("hero") if sc else null
		if h is Node3D: _face(n, (h as Node3D).global_position)
	await speak(sc, String(s[0]), String(s[1]), en, tr, String(s[2]))
	if n is DemoCharacter and is_instance_valid(n): n.play(String(n.get_meta("pose", "idle")), 0.3)

func _face(who: Node3D, at: Vector3) -> void:
	var y := atan2(at.x - who.global_position.x, at.z - who.global_position.z)
	create_tween().tween_property(who, "rotation:y", who.rotation.y + wrapf(y - who.rotation.y, -PI, PI), 0.4)

func target(_tag: String): return null
func reach(_tag: String) -> void: pass
func act(_tag: String) -> void: pass
func play_mode(_on: bool) -> void: pass   # give control to the player while an objective waits for reach()

## objective: camera pan + notify sound + top-left Objectives + spoken (Life.guide_to), then wait until it is reached
var _dbg := ""   # QA diagnostics: the step in progress
func objective(tag: String, en: String, tr: String) -> void:
	_dbg = "guide " + tag
	reg_tr(sc, en, tr)
	var cur := {"id": en, "en": en, "tr": tr}
	await Life.guide_to(target(tag), en, {"id": en, "tr": tr, "list": [cur]})
	_dbg = "play " + tag
	play_mode(true)
	await reach(tag)
	_dbg = "reached " + tag
	play_mode(false)
	Objectives.complete(en)

func choose(c: Dictionary) -> Dictionary:
	var o: Dictionary = await choice(c)
	if bool(o.get("ok", false)) and not bool(c.get("silent", false)): await say("me", String(o.en), String(o.tr))
	return o

## breakfast review: the data's 3 questions in the choice panel (narrator reads, shuffled answers, EN + TR feedback)
func review() -> void:
	await say("narr", "Let's do a quick review at the table.", "Masada kısa bir tekrar yapalım.")
	var n_ok := 0
	for q in D.get("review", []):
		var opts: Array = []
		for i in q.opts.size():
			opts.append({"en": String(q.opts[i]), "tr": "", "ok": i == int(q.a), "fb": String(q.say), "fb_tr": String(q.tr)})
		var o: Dictionary = await choice({"prompt": String(q.q), "prompt_tr": "Doğru kelimeleri seç.  (%s)" % String(q.tr), "opts": opts, "speak": "Choose the right words.", "first_try": true})
		if bool(o.get("first_ok", false)): n_ok += 1
		await speak(sc, "", "", String(q.say), String(q.tr))
	flag("d%d_review" % day, n_ok)

# ------------------------------------------------------------------ choice panel (centre, above the caption box)
signal _picked(i: int)
## shows the options (shuffled), waits for the right one; a wrong pick shows EN feedback (+ TR with the toggle) and is greyed out.
## option {"do": tag} runs act(tag) first (day 6 taxi). Returns the right option (+ "first_ok").
func choice(c: Dictionary) -> Dictionary:
	await Audio.wait_idle(15.0)
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	var box := PanelContainer.new(); box.name = "D56Choice"
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.96); sb.set_corner_radius_all(20); sb.set_content_margin_all(18)
	sb.border_color = Color(0.93, 0.52, 0.44); sb.set_border_width_all(3); box.add_theme_stylebox_override("panel", sb)
	# lower half, above the caption box: the faces of the people talking stay visible
	box.anchor_left = 0.5; box.anchor_right = 0.5; box.anchor_top = 1.0; box.anchor_bottom = 1.0; box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -400; box.offset_right = 400; box.offset_top = -420; box.offset_bottom = -96; cl.add_child(box)
	Objectives.ovl_register(box, 5)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); box.add_child(v)
	var trs: Array = []
	var pl := Label.new(); pl.text = String(c.prompt); pl.add_theme_font_size_override("font_size", 28); pl.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(pl)
	var pt := Label.new(); pt.text = String(c.get("prompt_tr", "")); pt.add_theme_font_size_override("font_size", 17); pt.add_theme_color_override("font_color", Color(0.35, 0.5, 0.8))
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(pt); trs.append(pt)
	var opts: Array = (c.opts as Array).duplicate(); opts.shuffle()
	var btns: Array = []
	for i in opts.size():
		var b := Button.new(); b.name = "D56Opt%d" % i; b.text = String(opts[i].en); b.custom_minimum_size = Vector2(620, 58); b.add_theme_font_size_override("font_size", 22)
		b.focus_mode = Control.FOCUS_NONE; b.disabled = true; b.set_meta("ok", bool(opts[i].get("ok", false))); b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_style(b, Color(0.33, 0.47, 0.78))   # answers in blue; a wrong pick turns red and stays greyed, the right one green
		var ii := i; b.pressed.connect(func(): _picked.emit(ii)); v.add_child(b); btns.append(b)
		if String(opts[i].get("tr", "")) != "":
			var bt := Label.new(); bt.text = String(opts[i].tr); bt.add_theme_font_size_override("font_size", 15); bt.add_theme_color_override("font_color", Color(0.35, 0.5, 0.8))
			bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(bt); trs.append(bt)
	var fb := Label.new(); fb.name = "D56Feedback"; fb.text = " "; fb.add_theme_font_size_override("font_size", 21); fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(fb)
	var fbt := Label.new(); fbt.text = ""; fbt.add_theme_font_size_override("font_size", 16); fbt.add_theme_color_override("font_color", Color(0.35, 0.5, 0.8))
	fbt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; fbt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(fbt); trs.append(fbt)
	var tr_vis := func(): for l in trs: if is_instance_valid(l): (l as Label).visible = (l as Label).text.strip_edges() != ""   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
	tr_vis.call()
	box.modulate.a = 0.0; create_tween().tween_property(box, "modulate:a", 1.0, 0.3)
	Audio.say(String(c.get("speak", c.prompt)))
	await _w(0.2); await Audio.wait_idle(15.0)
	var first := true; var first_ok := false
	var right: Dictionary = {}
	while right.is_empty():
		for b in btns: if is_instance_valid(b) and not b.has_meta("wrong"): (b as Button).disabled = false
		tr_vis.call()
		var picked := [-1]
		var cb := func(i): picked[0] = i
		_picked.connect(cb)
		while picked[0] < 0:
			tr_vis.call()
			await get_tree().process_frame
		_picked.disconnect(cb)
		for b in btns: (b as Button).disabled = true
		var o: Dictionary = opts[picked[0]]
		var bt: Button = btns[picked[0]]
		if String(o.get("do", "")) != "":
			cl.visible = false; await act(String(o["do"])); cl.visible = true
		if bool(o.get("ok", false)):
			if first: first_ok = true
			Audio.good(); _style(bt, Color(0.3, 0.72, 0.45))
			fb.add_theme_color_override("font_color", Color(0.2, 0.6, 0.35)); fb.text = "That is right!"; fbt.text = "Doğru!"; tr_vis.call()
			Audio.say("That is right!")
			right = o.duplicate(); right["first_ok"] = first_ok
		else:
			Audio.bad(); _style(bt, Color(0.95, 0.55, 0.5)); bt.set_meta("wrong", true); bt.modulate = Color(1, 1, 1, 0.6)
			if bool(c.get("remove_wrong", false)): bt.visible = false
			fb.add_theme_color_override("font_color", Color(0.8, 0.3, 0.25))
			fb.text = "Not quite.  " + String(o.get("fb", "")); fbt.text = "Tam değil.  " + String(o.get("fb_tr", "")); tr_vis.call()
			Audio.say("Not quite.")
			if String(o.get("fb", "")) != "": Audio.say(String(o.fb))
			if bool(c.get("first_try", false)):   # review: one try, the right answer is shown and read
				for k in btns.size(): if bool(btns[k].get_meta("ok")): _style(btns[k], Color(0.3, 0.72, 0.45))
				for oo in opts: if bool(oo.get("ok", false)): right = oo.duplicate()
				right["first_ok"] = false
		first = false
		await _w(0.3); await Audio.wait_idle(15.0); await _w(0.5)
	var t := create_tween(); t.tween_property(box, "modulate:a", 0.0, 0.25); await t.finished
	cl.queue_free()
	return right

func _style(b: Button, c: Color) -> void:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(14); s.set_content_margin_all(8)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]: b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_disabled_color", Color.WHITE); b.add_theme_color_override("font_color", Color.WHITE)

# ------------------------------------------------------------------ polaroid card (story_home.gd / bedtime.gd look)
static func polaroid(key: String, cap: String, i: int) -> Control:
	var wrap := Control.new(); wrap.custom_minimum_size = Vector2(212, 268); wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tilt := Control.new(); tilt.size = Vector2(212, 268); tilt.pivot_offset = Vector2(106, 134); wrap.add_child(tilt)
	var shadow := Panel.new(); var ss := StyleBoxFlat.new(); ss.bg_color = Color(0, 0, 0, 0.35); ss.set_corner_radius_all(4); ss.shadow_color = Color(0, 0, 0, 0.3); ss.shadow_size = 12
	shadow.add_theme_stylebox_override("panel", ss); shadow.position = Vector2(5, 8); shadow.size = Vector2(212, 268); tilt.add_child(shadow)
	var card := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.99, 0.98, 0.95); sb.set_corner_radius_all(3); sb.border_color = Color(0.88, 0.86, 0.8); sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb); card.size = Vector2(212, 268); tilt.add_child(card)
	var well := ColorRect.new(); well.color = Color(0.12, 0.12, 0.14); well.position = Vector2(12, 12); well.size = Vector2(188, 188); card.add_child(well)
	var tex := TextureRect.new(); tex.position = Vector2(14, 14); tex.size = Vector2(184, 184); tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture = Life.photo(key)
	if tex.texture == null: tex.texture = Life.photo("home")
	tex.modulate = Color(1.0, 0.96, 0.88); card.add_child(tex)
	var l := Label.new(); l.text = cap; l.add_theme_font_size_override("font_size", 17); l.add_theme_color_override("font_color", Color(0.12, 0.16, 0.38))
	if UI.font_b: l.add_theme_font_override("font", UI.font_b)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(8, 204); l.size = Vector2(196, 60); card.add_child(l)
	var tape := ColorRect.new(); tape.color = Color(0.98, 0.92, 0.6, 0.75); tape.size = Vector2(80, 24); tape.position = Vector2(66, -10); tape.pivot_offset = Vector2(40, 12); tape.rotation_degrees = [6.0, -5.0, 3.0, -7.0, 4.0][i % 5]; card.add_child(tape)
	return wrap

## offscreen polaroid (Life.snap_from) looking at `at` from `eye`
static func snap(key: String, eye: Vector3, at: Vector3, fov := 50.0) -> void:
	await Life.snap_from(key, Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), fov)
