## v31c (red): DAY 2 BEDTIME (bedroom, main.gd). Cinematic go-to-sleep with a POLAROID recap of day 2 (same card style as
## day 1's dream in story_home.gd), a past-simple test (d2_night_test.gd), the sleep cinematic, then day 3 wakes to the alarm
## and hands over to day3_morning.gd. The player is LYING on the bed (pose locked every frame, like story_home bed_lock)
## from the moment he lies down until the day-3 get-up - through the recap, the test and the sleep.
## ENTRY: Bedtime.hook_bedroom(main)  - call from main.gd _continue_game() (bedroom entered). Plays once:
##   story.d2_bed_pending (set by day2_evening.gd) -> story.d2_bedtime_done. Day 3 resumes Day3Morning when needed.
## v32c (red): also the DAY 3 night (night = 3): story.d3_bed_pending (day3_evening.gd) -> day-3 polaroids (d3_polaroids.gd) ->
##   d3_night_test.gd -> sleep -> DAY 4 (WorldState.day = 4): wake with only "I'm waking up." + "I'm getting up." (no alarm,
##   silent "Day 4" title) -> placeholder first objective "Start your day." (story.d4 = "start"). Flags d3_bedtime_done, d3_recap,
##   d3_night_score.
class_name Bedtime
extends Node

const DATA := "res://data/day2_evening.json"
var m: Node   # bedroom main.gd
var ui: StoryUI
var cl: CanvasLayer
var bed_lock := false
var _bed_xf: Transform3D
var bed_fixes := 0
var recap: Array = []   # [photo key, EN caption]
var night := 2          # v32c (red): 2 = day-2 night -> day 3, 3 = day-3 night -> day 4

static func _story() -> Dictionary:
	var sv = App.load_save().get("story", {})
	return sv if sv is Dictionary else {}

static func hook_bedroom(main: Node) -> void:
	var sv := _story()
	if maxi(WorldState.day, App.day) == 2 and bool(sv.get("d2_bed_pending", false)) and not bool(sv.get("d2_bedtime_done", false)):
		if main.has_node("Bedtime"): return
		var b = load("res://scripts/story/bedtime.gd").new(); b.name = "Bedtime"; b.m = main; main.add_child(b); b.run()
	elif maxi(WorldState.day, App.day) == 3 and bool(sv.get("d3_bed_pending", false)) and not bool(sv.get("d3_bedtime_done", false)):   # v32c (red)
		if main.has_node("Bedtime"): return
		var b3 = load("res://scripts/story/bedtime.gd").new(); b3.name = "Bedtime"; b3.night = 3; b3.m = main; main.add_child(b3); b3.run()
	elif maxi(WorldState.day, App.day) >= 3:
		load("res://scripts/story/day3_morning.gd").attach(main.get_tree())

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func _process(_d: float) -> void:
	if bed_lock and m and is_instance_valid(m.hero):
		if not m.breathing or m.hero.player.speed_scale != 0.0 or m.hero.transform.origin.distance_to(_bed_xf.origin) > 0.05 or not m.hero.visible:
			m.hero.transform = _bed_xf; m.hero.visible = true; m._pose_sleep(); bed_fixes += 1

func _cap(t: String) -> void:   # room caption + narrator, waits until spoken
	await Audio.wait_idle(12.0); m.caption(t); await _w(0.2); await Audio.wait_idle(12.0); await _w(0.5)

func run() -> void:
	await _w(1.4)   # let main.gd's "I'm in the bedroom now." pass
	await Audio.wait_idle(8.0)
	m.mode = "busy"; m._hide_chips(); m.hand3d.visible = false
	Life.event("bedtime")
	var bed: Dictionary = m.OBJ.bed
	await Life.guide_to({"pos": bed.focus + Vector3(1.6, 1.4, 1.8), "at": bed.focus}, "Go to bed.", {"tr": "Yatmaya git.", "id": "Go to bed.", "list": [{"id": "Go to bed.", "en": "Go to bed.", "tr": "Yatmaya git."}]})
	m.mode = "busy"; m._hide_chips()
	m.caption("I am going to bed.")
	await m.walk_to(bed.spot, 0.0)
	await m.sit_on_bed(); await m.edge_to_bedsit(); await m.bedsit_to_lie()
	m.S.bed = "unmade"; m._apply_states()
	_bed_xf = m.hero.transform; bed_lock = true
	Objectives.clear()
	await _cap("I am lying in bed.")
	ui = StoryUI.new(); add_child(ui)
	cl = CanvasLayer.new(); cl.layer = 30; add_child(cl)
	m.cam_shot = {"pos": bed.focus + Vector3(1.4, 1.6, 1.6), "at": bed.focus + Vector3(-0.3, -0.1, 0)}
	await _dream()
	await _test()
	await _sleep()
	queue_free()

func _flag(k: String, v) -> void:
	var sv := _story().duplicate(); sv[k] = v; App.patch_save({"story": sv})

func _tr_line(en: String) -> String: return ui.tr_of(en) if App.tr_on() else ""

## dream narration line (StoryUI caption, TR only when TR is on)
func _dline(en: String) -> void:
	await Audio.wait_idle(15.0)
	ui.en_l.text = en; ui.tr_l.text = _tr_line(en); ui.tr_l.visible = ui.tr_l.text != ""; ui.panel.visible = true
	m.cap_panel.visible = false
	Audio.say(en)
	await _w(0.2); await Audio.wait_idle(15.0); await _w(0.9)

func _recap_list() -> Array:
	var sv := _story(); var out: Array = []
	if night == 3:   # v32c (red): day 3 = shower, cafe, shop, couch (data/day3_evening.json "recap")
		var d3 = App.load_json("res://data/day3_evening.json")
		var need := {"d3_cafe": "d3_cafe", "d3_shop": "d3_shop", "d3_couch": "d3_couch_done"}
		for r in (d3.get("recap", []) if d3 is Dictionary else []):
			if need.has(r[0]) and not bool(sv.get(need[r[0]], false)): continue
			out.append([String(r[0]), String(r[1])])
		return out
	var d = App.load_json(DATA)
	if sv.has("day2_score") or bool(App.load_save().get("breakfast_done", false)): out.append(["d2_breakfast", "I had breakfast and learned have to."])
	if bool(sv.get("day2_work_done", false)):
		var st: Dictionary = App.load_save().get("state", {})
		var cid: String = load("res://scripts/story/work.gd").category_of(String(st.get("job", "")), CharacterHook.is_child(st))
		out.append(["d2_work", "I went to school." if cid in ["teach", "study"] else ("I went shopping." if cid == "home" else "I went to work.")])
	if bool(sv.get("day2_hospital_done", false)): out.append(["d2_hospital", "I went to the hospital."])
	if bool(sv.get("d2_couch_done", false)): out.append(["d2_couch", "I talked to my family."])
	return out

func _dream() -> void:
	recap = _recap_list()
	var dim := ColorRect.new(); dim.color = Color(0.25, 0.2, 0.45, 0.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(dim)
	var t := create_tween(); t.tween_property(dim, "color:a", 0.6, 1.0)
	var keys: Array = []; for r in recap: keys.append(r[0])
	if night == 3: await load("res://scripts/story/d3_polaroids.gd").ensure_d3(self, keys)   # v32c (red)
	else: await load("res://scripts/story/d2_polaroids.gd").ensure_d2(self, keys)
	if t.is_running(): await t.finished
	await _dline("I am dreaming about my day.")
	var row := HBoxContainer.new(); row.name = "D2Polaroids"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT); row.offset_top = 150; row.offset_bottom = -150; row.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(row)
	for i in recap.size():
		var card := _polaroid(String(recap[i][0]), String(recap[i][1]), i)
		card.modulate.a = 0.0; row.add_child(card)
		var ct := create_tween(); ct.tween_property(card, "modulate:a", 1.0, 0.5)
		var tl: Control = card.get_child(0)
		ct.parallel().tween_property(tl, "scale", Vector2.ONE, 0.6).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(tl, "rotation_degrees", [-4.0, 3.0, -2.0, 4.0, -3.0][i % 5], 0.6).from(0.0); await ct.finished
		await _dline(String(recap[i][1]))
	await _dline("Went, ordered, bought: this is the past simple." if night == 3 else "Went, had, talked: this is the past simple.")
	await _w(1.2)
	var ft := create_tween(); ft.tween_property(row, "modulate:a", 0.0, 1.0); ft.parallel().tween_property(dim, "color:a", 0.0, 1.0); await ft.finished
	row.queue_free(); dim.queue_free(); ui.hide_caption()
	_flag("d%d_recap" % night, keys)

## story_home.gd house.27 polaroid card (same look), any photo key + caption
func _polaroid(key: String, cap: String, i: int) -> Control:
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
	var gloss := ColorRect.new(); gloss.color = Color(1, 1, 1, 0.07); gloss.position = Vector2(14, 14); gloss.size = Vector2(184, 70); gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(gloss)
	var l := Label.new(); l.text = cap; l.add_theme_font_size_override("font_size", 17); l.add_theme_color_override("font_color", Color(0.12, 0.16, 0.38))
	if UI.font_b: l.add_theme_font_override("font", UI.font_b)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(8, 204); l.size = Vector2(196, 60); card.add_child(l)
	var tape := ColorRect.new(); tape.color = Color(0.98, 0.92, 0.6, 0.75); tape.size = Vector2(80, 24); tape.position = Vector2(66, -10); tape.pivot_offset = Vector2(40, 12); tape.rotation_degrees = [6.0, -5.0, 3.0, -7.0, 4.0][i % 5]; card.add_child(tape)
	return wrap

func _test() -> void:
	await _dline("Now a short test about my day.")
	ui.hide_caption()
	var ph = m.phone
	ph.visible = true; ph.open(Rect2(), "home"); await _w(0.5)
	var res: Array = await load("res://scripts/story/d%d_night_test.gd" % night).new().run(m, ph)   # v32c (red): d3 = cafe / shop test
	_flag("d%d_night_score" % night, res)
	await Audio.wait_idle(15.0)
	await ph.close(true)

func _sleep() -> void:
	m.cam_shot = {"pos": m.OBJ.bed.focus + Vector3(0.9, 1.3, 0.9), "at": m.OBJ.bed.focus + Vector3(-0.4, -0.15, 0)}
	await _dline("Good night!")
	m.S.lamp = "off"; m.S.ceiling = "off"; m.S.desklamp = "off"; m._apply_states(); Audio.sfx("metalClick", -6.0)
	await _dline("I am sleeping.")
	ui.hide_caption()
	var black := ColorRect.new(); black.color = Color(0.05, 0.05, 0.12, 0.0); black.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(black)
	var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 2.0); await tw.finished
	if night == 3: await _sleep_to_day4(black); return   # v32c (red)
	_flag("d2_bedtime_done", true); _flag("d2_bed_pending", false); _flag("d3", "shower")
	load("res://scripts/story/day2_morning.gd").set_stage("day3")
	Life.advance_day(true)   # day 3, 00:00
	await _w(1.2)
	Life.event("morning")
	m.S.ceiling = "on"; m._apply_states()
	tw = create_tween(); tw.tween_property(black, "color:a", 0.0, 1.5); await tw.finished
	black.queue_free()
	await _day_title()
	# ---- day 3: wake to the alarm (still lying until the get-up)
	m.S.alarm = "ringing"; m._apply_states(); Audio.sfx("alarm", -4.0)
	await _cap("My alarm is ringing.")
	m.S.alarm = "off"; m._apply_states(); Audio.sfx("metalClick")
	await _cap("I am turning off the alarm.")
	m.cam_shot = {}
	bed_lock = false
	await m.get_up_sequence()
	m.mode = "play"; m._update_hand()
	load("res://scripts/story/day3_morning.gd").attach(get_tree())

## v32c (red): day-3 night -> DAY 4. Waking says only "I'm waking up." then "I'm getting up." (no alarm, silent title).
func _sleep_to_day4(black: ColorRect) -> void:
	_flag("d3_bedtime_done", true); _flag("d3_bed_pending", false); _flag("d4", "start")
	Life.advance_day(true)   # day 4, 00:00
	if WorldState.day != 4:
		WorldState.day = 4; App.day = 4; App.patch_save({"day": 4})
	await _w(1.2)
	Life.event("morning")
	m.S.ceiling = "on"; m._apply_states()
	var tw := create_tween(); tw.tween_property(black, "color:a", 0.0, 1.5); await tw.finished
	black.queue_free()
	await _day_title(false)
	m.cam_shot = {}
	bed_lock = false
	await _wake_simple()
	m.mode = "play"; m._update_hand()
	await _day4_prompt()

## main.gd get_up_sequence() without its extra lines: "I'm waking up." -> sit up -> edge -> "I'm getting up." -> stand
func _wake_simple() -> void:
	Life.event("wake")
	m.mode = "busy"; m._hide_chips(); m._update_hand()
	await Audio.wait_idle(8.0)
	m.caption("I'm waking up.")
	m.hero.player.speed_scale = 0.0
	await m.bedsit_up()
	await m.bedsit_to_edge()
	await Audio.wait_idle(8.0)
	m.caption("I'm getting up.")
	await m.stand_from_bed()
	m.mode = "play"; m._update_hand(); m.action_done.emit("getup")

## placeholder day-4 first objective (Life.guide_to pan onto the living-room door; main.gd objective() keeps it while d4 == "start")
func _day4_prompt() -> void:
	await Audio.wait_idle(8.0)
	var f: Vector3 = m.OBJ.door_s.focus
	await Life.guide_to({"pos": f + Vector3(0.4, 1.0, -2.4), "at": f}, "Start your day.", {"tr": "Gününe başla.", "id": "Start your day.",
		"list": [{"id": "Start your day.", "en": "Start your day.", "tr": "Gününe başla."}]})

func _day_title(speak := true) -> void:
	var v := VBoxContainer.new(); v.name = "DayTitle"; v.set_anchors_preset(Control.PRESET_CENTER_TOP); v.offset_top = 150; v.offset_left = -400; v.offset_right = 400
	v.alignment = BoxContainer.ALIGNMENT_CENTER; v.modulate.a = 0.0; cl.add_child(v)
	var rows: Array = [["It is a new day.", 44, Color.WHITE], ["Day 3", 30, Color(1, 0.92, 0.7)]] if speak else [["Day %d" % maxi(WorldState.day, App.day), 44, Color(1, 0.92, 0.7)]]   # v32c (red): day 4 = silent title
	for e in rows:
		var l := Label.new(); l.text = e[0]; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size", e[1]); l.add_theme_color_override("font_color", e[2])
		l.add_theme_constant_override("outline_size", 10); l.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25))
		if UI.font_b: l.add_theme_font_override("font", UI.font_b)
		v.add_child(l)
		if App.tr_on():
			var lt := Label.new(); lt.text = ui.tr_of(e[0]); lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lt.add_theme_font_size_override("font_size", 22); lt.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
			lt.add_theme_constant_override("outline_size", 8); lt.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25)); v.add_child(lt)
	if speak: Audio.say("It is a new day.")
	var tw := create_tween(); tw.tween_property(v, "modulate:a", 1.0, 0.4); tw.tween_interval(2.2); tw.tween_property(v, "modulate:a", 0.0, 0.5)
	await tw.finished; v.queue_free()
	await Audio.wait_idle(5.0)
