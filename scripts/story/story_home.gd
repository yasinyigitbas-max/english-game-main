## house.25: day-1 story, part 3 (home from the hospital): review (skippable) -> 20-question test (locked) -> sleep, day advances
## -> dream: past simple with polaroids -> day 2: phone call (boss / teacher), answer by putting the words in order.
extends Node

var m: Node     # bedroom main.gd
var ui: StoryUI
var cl: CanvasLayer
const PAST := ["I had breakfast.", "I saw a cat.", "A bus hit me.", "I went to the hospital.", "I was fine in the end."]   # v29: the day's events in the past simple
const ACTIONS := ["wake", "wash_face", "brush_teeth", "breakfast"]
const PHOTO := ["breakfast", "outside", "accident", "hospital", "fine"]

func run() -> void:
	Life.event("home")   # house.29: event clock
	ui = StoryUI.new(); add_child(ui)
	cl = CanvasLayer.new(); cl.layer = 30; add_child(cl)
	m.mode = "busy"
	bed_lock = true;_bed_xf = m.hero.transform
	await get_tree().create_timer(1.0).timeout
	await ui.line("I am at home now.")
	Life.snap("home")
	# ---- review of all lessons (skippable)
	var fam: Dictionary = App.load_json("res://data/family.json"); var bk: Dictionary = App.load_json("res://data/breakfast.json"); var cs: Dictionary = App.load_json("res://data/can_should.json")
	var review := {"label": "Review", "quiz_after": false, "lesson": fam.lesson + bk.lesson + cs.lesson, "quiz": []}
	await ui.line("Let's review the lessons.")
	ui.hide_caption(); m.caption("", false)   # v32-polish: the narrator box goes right before the review screen shows
	var ph = m.phone
	ph.visible = true; ph.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	ph.start_set(review, "lesson")
	var skip := Button.new(); skip.text = "Skip the review  ·  Tekrarı atla"; skip.add_theme_font_size_override("font_size", 20)
	skip.anchor_left = 0.5; skip.anchor_right = 0.5; skip.offset_left = -160; skip.offset_right = 160; skip.offset_top = 14; skip.offset_bottom = 64; cl.add_child(skip)
	skip.pressed.connect(func(): Audio.click(); ph.lesson_steps_done.emit())
	await ph.lesson_steps_done
	skip.queue_free(); Audio.cancel_group("lesson")
	# ---- unskippable 20-question test on every topic
	var test := {"label": "Test", "quiz_after": true, "lesson": review.lesson}
	for k in ["quiz", "quiz_b", "quiz_c"]:   # house.26: three versions of the 10-question test
		var qs: Array = fam.get(k, fam.quiz) + bk.get(k, bk.quiz) + cs.get(k, cs.quiz); qs.shuffle(); test[k] = qs.slice(0, 10)
	await ui.line("Now the big test. Ten questions.")
	ui.hide_caption()   # v32-polish: one caption box; the test page shows without the stacked narrator box
	ph.start_set(test, "quiz")
	var res = await ph.quiz_done
	_story_save("test_score", [res[0], res[1]])
	await ph.close(true)
	# ---- sleep: the shared clock moves to the next day
	await ui.line("I am tired. I should rest.", "", 0.0)
	bed_lock = false; m.sleep_pose()   # v33 (red): the real sleep clip right after the line (main.gd sleep_pose)
	await get_tree().create_timer(0.7).timeout
	var black := ColorRect.new(); black.color = Color(0.05, 0.05, 0.12, 0.0); black.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(black)
	var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 1.5); await tw.finished
	Life.event("bedtime"); Life.advance_day(true)   # house.29: the day ends at exactly 00:00 with the dream
	await _night(black)
	m.end_sleep_pose(); _bed_xf = m.hero.transform; bed_lock = true   # v33 (red): under the black, the flat pose back for the get-up
	# ---- day 2
	ui.hide_caption()
	tw = create_tween(); tw.tween_property(black, "color:a", 0.0, 1.5); await tw.finished
	black.queue_free()
	Life.event("morning")
	ui.hide_caption(); await _new_day_title()   # v30.5: short upper-centre title, gone before the next caption
	bed_lock = false
	if m.breathing:   # v30.4: lay in bed since the hospital; get up now
		await m.get_up_sequence(); m.mode = "busy"
	await _call()
	await day2_start()
	queue_free()

## v31: after the wake-up call: day-2 morning -> living room (mirror / bathroom not required any more)
func day2_start() -> void:
	_story_save("day1_done", true)
	_story_save("day2", "living")
	ui.hide_caption()
	await m.day2_living_prompt()

## v29: App.patch_save is shallow - merge into the existing "story" dict instead of replacing it
func _story_save(k: String, v) -> void:
	var st = App.load_save().get("story", {})
	st = st.duplicate() if st is Dictionary else {}
	st[k] = v; App.patch_save({"story": st})

## v29: dream (polaroids) -> past simple lesson -> past simple test (phone.gd universal test rules) -> blue vocab test
func _night(black: ColorRect) -> void:
	await _dream(black)
	black.visible = false
	var ph = m.phone
	var past: Dictionary = App.load_json("res://data/past_day1.json")
	await ui.line("Let's learn the past simple.")
	ui.hide_caption()
	ph.visible = true; ph.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	ph.start_set(past, "lesson")   # lesson (notebook prompt once) -> Check -> 3-version test -> score page (study / retake / continue)
	var pr = await ph.quiz_done
	_story_save("past_score", [pr[0], pr[1]])
	await ph.close(true)
	await Audio.wait_idle(15.0)
	await ui.line("Now the vocabulary test.")
	ui.hide_caption()
	var vt = await load("res://scripts/story/vocab_test.gd").new().run(self, ph)
	_story_save("vocab_score", vt)
	await ph.close(true)
	black.visible = true

func _dream(bg: ColorRect) -> void:
	var dim := ColorRect.new(); dim.color = Color(0.25, 0.2, 0.45, 0.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(dim)
	var t := create_tween(); t.tween_property(dim, "color:a", 0.6, 1.0)
	await load("res://scripts/story/polaroid_renderer.gd").ensure(self, ACTIONS + PHOTO)   # house.27: player-look fallbacks for any action without a snapshot
	if t.is_running(): await t.finished
	await _dline("I am dreaming about yesterday.")
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT); row.offset_top = 60; row.offset_bottom = -170; cl.add_child(row)
	# house.27: small polaroids of the morning actions the player really did (snapshot or pre-rendered still)
	var mini := HBoxContainer.new(); mini.alignment = BoxContainer.ALIGNMENT_CENTER; mini.add_theme_constant_override("separation", 22)
	mini.anchor_right = 1; mini.offset_top = 14; mini.offset_bottom = 140; cl.add_child(mini)
	for k in ACTIONS.size():
		var mc := _mini_polaroid(ACTIONS[k], [-5.0, 4.0, -3.0, 5.0][k % 4])
		if mc == null: continue
		mc.modulate.a = 0.0; mini.add_child(mc); var mt := create_tween(); mt.tween_property(mc, "modulate:a", 1.0, 0.35); await mt.finished
	await _dline("I woke up. I washed my face. I brushed my teeth.")   # v29: the morning polaroids in the past simple
	for i in PAST.size():
		var card := _polaroid(i)
		card.modulate.a = 0.0; row.add_child(card)
		var ct := create_tween(); ct.tween_property(card, "modulate:a", 1.0, 0.5)
		var tl: Control = card.get_child(0)
		ct.parallel().tween_property(tl, "scale", Vector2.ONE, 0.6).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(tl, "rotation_degrees", [-4.0, 3.0, -2.0, 4.0, -3.0][i], 0.6).from(0.0); await ct.finished
		await _dline(PAST[i])
	await _dline("This is the past simple. Have becomes had. Go becomes went. Am and is become was.")
	await get_tree().create_timer(1.5).timeout
	var ft := create_tween(); ft.tween_property(row, "modulate:a", 0.0, 1.0); ft.parallel().tween_property(mini, "modulate:a", 0.0, 1.0); ft.parallel().tween_property(dim, "color:a", 0.0, 1.0); await ft.finished
	mini.queue_free(); row.queue_free(); dim.queue_free()

## house.27: polaroid card - thick white frame, wider bottom strip, soft shadow, sepia-ish photo, tape on top, handwritten-style caption
func _polaroid(i: int) -> Control:
	var wrap := Control.new(); wrap.custom_minimum_size = Vector2(212, 268); wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tilt := Control.new(); tilt.size = Vector2(212, 268); tilt.pivot_offset = Vector2(106, 134); wrap.add_child(tilt)
	var shadow := Panel.new(); var ss := StyleBoxFlat.new(); ss.bg_color = Color(0, 0, 0, 0.35); ss.set_corner_radius_all(4); ss.shadow_color = Color(0, 0, 0, 0.3); ss.shadow_size = 12
	shadow.add_theme_stylebox_override("panel", ss); shadow.position = Vector2(5, 8); shadow.size = Vector2(212, 268); tilt.add_child(shadow)
	var card := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.99, 0.98, 0.95); sb.set_corner_radius_all(3); sb.border_color = Color(0.88, 0.86, 0.8); sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb); card.size = Vector2(212, 268); tilt.add_child(card)
	var well := ColorRect.new(); well.color = Color(0.12, 0.12, 0.14); well.position = Vector2(12, 12); well.size = Vector2(188, 188); card.add_child(well)
	var tex := TextureRect.new(); tex.position = Vector2(14, 14); tex.size = Vector2(184, 184); tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture = Life.photo(PHOTO[i])
	if tex.texture == null: tex.texture = Life.photo("home")
	tex.modulate = Color(1.0, 0.96, 0.88); card.add_child(tex)
	if tex.texture == null: tex.queue_free(); var ph := ColorRect.new(); ph.color = Color(0.7, 0.75, 0.85); ph.position = Vector2(14, 14); ph.size = Vector2(184, 184); card.add_child(ph)
	var gloss := ColorRect.new(); gloss.color = Color(1, 1, 1, 0.07); gloss.position = Vector2(14, 14); gloss.size = Vector2(184, 70); gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE; card.add_child(gloss)
	var l := Label.new(); l.text = PAST[i]; l.add_theme_font_size_override("font_size", 18); l.add_theme_color_override("font_color", Color(0.12, 0.16, 0.38))
	if UI.font_b: l.add_theme_font_override("font", UI.font_b)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(8, 204); l.size = Vector2(196, 60); card.add_child(l)
	var tape := ColorRect.new(); tape.color = Color(0.98, 0.92, 0.6, 0.75); tape.size = Vector2(80, 24); tape.position = Vector2(66, -10); tape.pivot_offset = Vector2(40, 12); tape.rotation_degrees = [6.0, -5.0, 3.0, -7.0, 4.0][i]; card.add_child(tape)
	return wrap

func _mini_polaroid(key: String, rot: float) -> Control:
	var t := Life.photo(key)
	if t == null: return null
	var w := Control.new(); w.custom_minimum_size = Vector2(104, 122)
	var tl := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.99, 0.98, 0.95); sb.set_corner_radius_all(2); sb.shadow_color = Color(0, 0, 0, 0.35); sb.shadow_size = 6; sb.shadow_offset = Vector2(3, 4)
	tl.add_theme_stylebox_override("panel", sb); tl.size = Vector2(104, 122); tl.pivot_offset = Vector2(52, 61); tl.rotation_degrees = rot; w.add_child(tl)
	var tex := TextureRect.new(); tex.position = Vector2(7, 7); tex.size = Vector2(90, 90); tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; tex.texture = t; tex.modulate = Color(1.0, 0.96, 0.88); tl.add_child(tex)
	return w

## house.27: full-screen incoming-call screen (caller photo, name, answer / decline) shown before the word-order puzzle
func _call_screen(who: String) -> void:
	var scr := Control.new(); scr.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(scr)
	var bg := ColorRect.new(); bg.set_anchors_preset(Control.PRESET_FULL_RECT); scr.add_child(bg)
	var gs := Shader.new(); gs.code = "shader_type canvas_item;\nvoid fragment(){ COLOR = vec4(mix(vec3(0.10,0.16,0.32), vec3(0.04,0.05,0.10), UV.y), 1.0); }"
	var gm := ShaderMaterial.new(); gm.shader = gs; bg.material = gm
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER_TOP); v.anchor_left = 0.5; v.anchor_right = 0.5; v.offset_left = -220; v.offset_right = 220; v.offset_top = 40
	v.alignment = BoxContainer.ALIGNMENT_BEGIN; v.add_theme_constant_override("separation", 10); scr.add_child(v)
	var top := Label.new(); top.text = "Incoming call  ·  Gelen arama"; top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; top.add_theme_font_size_override("font_size", 22); top.add_theme_color_override("font_color", Color(0.7, 0.8, 1)); v.add_child(top)
	# caller photo: round avatar (bust drawn from shapes) with pulsing ring
	var ph := Control.new(); ph.custom_minimum_size = Vector2(160, 160); ph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(ph)
	var ring := Panel.new(); var rs := StyleBoxFlat.new(); rs.bg_color = Color(0, 0, 0, 0); rs.border_color = Color(0.4, 0.9, 0.55, 0.8); rs.set_border_width_all(4); rs.set_corner_radius_all(90)
	ring.add_theme_stylebox_override("panel", rs); ring.size = Vector2(160, 160); ring.pivot_offset = Vector2(80, 80); ph.add_child(ring)
	var av := Panel.new(); var as_ := StyleBoxFlat.new(); as_.bg_color = Color(0.55, 0.68, 0.85) if who == "My teacher" else Color(0.85, 0.66, 0.45); as_.set_corner_radius_all(70)
	av.add_theme_stylebox_override("panel", as_); av.position = Vector2(12, 12); av.size = Vector2(136, 136); av.clip_children = CanvasItem.CLIP_CHILDREN_ONLY; ph.add_child(av)
	var head := Panel.new(); var hs := StyleBoxFlat.new(); hs.bg_color = Color(0.96, 0.82, 0.68); hs.set_corner_radius_all(26); head.add_theme_stylebox_override("panel", hs); head.position = Vector2(42, 24); head.size = Vector2(52, 56); av.add_child(head)
	var hair := Panel.new(); var hr := StyleBoxFlat.new(); hr.bg_color = Color(0.25, 0.17, 0.1); hr.corner_radius_top_left = 26; hr.corner_radius_top_right = 26; hair.add_theme_stylebox_override("panel", hr); hair.position = Vector2(40, 18); hair.size = Vector2(56, 22); av.add_child(hair)
	var bust := Panel.new(); var bs := StyleBoxFlat.new(); bs.bg_color = Color(0.2, 0.3, 0.5) if who == "My teacher" else Color(0.18, 0.2, 0.24); bs.corner_radius_top_left = 40; bs.corner_radius_top_right = 40
	bust.add_theme_stylebox_override("panel", bs); bust.position = Vector2(22, 86); bust.size = Vector2(92, 60); av.add_child(bust)
	var nm := Label.new(); nm.text = who.trim_prefix("My ").capitalize(); nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nm.add_theme_font_size_override("font_size", 40); nm.add_theme_color_override("font_color", Color.WHITE)
	if UI.font_b: nm.add_theme_font_override("font", UI.font_b)
	v.add_child(nm)
	var sub := Label.new(); sub.text = "mobile  ·  cep"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.add_theme_font_size_override("font_size", 18); sub.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75)); v.add_child(sub)
	var pulse := create_tween().set_loops(); pulse.tween_property(ring, "scale", Vector2(1.12, 1.12), 0.6); pulse.parallel().tween_property(ring, "modulate:a", 0.3, 0.6); pulse.tween_property(ring, "scale", Vector2.ONE, 0.01); pulse.parallel().tween_property(ring, "modulate:a", 1.0, 0.01)
	# answer / decline buttons
	var bar := HBoxContainer.new(); bar.anchor_left = 0.5; bar.anchor_right = 0.5; bar.anchor_top = 1; bar.anchor_bottom = 1; bar.offset_left = -200; bar.offset_right = 200; bar.offset_top = -360; bar.offset_bottom = -220   # v32-polish: kept clear of the standard caption box (StoryUI, bottom-centre, up to ~170 px tall)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER; bar.add_theme_constant_override("separation", 140); scr.add_child(bar)
	var mk := func(col: Color, sym: String, cap: String) -> Button:
		var c := VBoxContainer.new(); c.add_theme_constant_override("separation", 6); bar.add_child(c)
		var b := Button.new(); b.custom_minimum_size = Vector2(92, 92); b.text = sym; b.add_theme_font_size_override("font_size", 36)
		for st in ["normal", "hover", "pressed", "focus"]:
			var x := StyleBoxFlat.new(); x.bg_color = col.lightened(0.15) if st == "hover" else col; x.set_corner_radius_all(46); b.add_theme_stylebox_override(st, x)
		c.add_child(b)
		var t := Label.new(); t.text = cap; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_font_size_override("font_size", 18); t.add_theme_color_override("font_color", Color(0.85, 0.9, 1)); c.add_child(t)
		return b
	var dec: Button = mk.call(Color(0.9, 0.25, 0.25), "", "Decline")
	var ans: Button = mk.call(Color(0.2, 0.75, 0.35), "", "Answer")
	var wig := create_tween().set_loops(); wig.tween_property(ans, "rotation_degrees", 12.0, 0.08); wig.tween_property(ans, "rotation_degrees", -12.0, 0.16); wig.tween_property(ans, "rotation_degrees", 0.0, 0.08); wig.tween_interval(0.6)
	ans.pivot_offset = Vector2(46, 46)
	var done := [false]
	ans.pressed.connect(func(): Audio.click(); done[0] = true)
	dec.pressed.connect(func(): Audio.bad())     # the call matters: you cannot decline it
	var rt := 0.0
	while not done[0]:
		await get_tree().process_frame; rt += get_process_delta_time()
		if rt > 2.2: rt = 0.0; Audio.sfx("ring", -2.0)
	pulse.kill(); wig.kill(); ans.rotation_degrees = 0
	# connected: show a small call bar with a timer for the rest of the call
	var ft := create_tween(); ft.tween_property(scr, "modulate:a", 0.0, 0.4); await ft.finished; scr.queue_free()
	_callbar = PanelContainer.new(); var cb := StyleBoxFlat.new(); cb.bg_color = Color(0.13, 0.55, 0.3, 0.95); cb.set_corner_radius_all(22); cb.set_content_margin_all(10); cb.content_margin_left = 22; cb.content_margin_right = 22
	_callbar.add_theme_stylebox_override("panel", cb); _callbar.anchor_left = 0.5; _callbar.anchor_right = 0.5; _callbar.offset_left = -170; _callbar.offset_right = 170; _callbar.offset_top = 12; cl.add_child(_callbar)
	_calllbl = Label.new(); _calllbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _calllbl.add_theme_font_size_override("font_size", 20); _calllbl.add_theme_color_override("font_color", Color.WHITE); _callbar.add_child(_calllbl)
	_callname = nm.text; _callt = 0.0
var _callbar: PanelContainer
var _calllbl: Label
var _callname := ""
var _callt := 0.0
var bed_lock: = false
var _bed_xf: Transform3D
var bed_fixes: = 0
func _process(d: float) -> void:
	if bed_lock and m and is_instance_valid(m.hero) and not m.get("sleep_clip"):   # v33 (red): not while the sleep clip plays (it moves the body on purpose)
		if not m.breathing or m.hero.player.speed_scale != 0.0 or m.hero.transform.origin.distance_to(_bed_xf.origin) > 0.05 or not m.hero.visible:
			m.hero.transform = _bed_xf;m.hero.visible = true;m._pose_sleep();bed_fixes += 1
	if _calllbl and is_instance_valid(_calllbl):
		_callt += d; _calllbl.text = "%s  ·  %02d:%02d" % [_callname, int(_callt) / 60, int(_callt) % 60]

func _call() -> void:
	var st: Dictionary = App.load_save().get("state", {})
	var teacher := String(st.get("age", "adult")) == "child" or String(st.get("job", "")) in ["student", ""]
	var who := "My teacher" if teacher else "My boss"
	Audio.sfx("ring", -2.0)
	_call_screen_task(who)
	await ui.line("My phone is ringing.")
	while not _answered: await get_tree().process_frame
	await ui.line("Hello! What happened yesterday?", who)
	await ui.line("Put the words in the right order.")
	for s in PAST: await _puzzle(s)
	await ui.line("Oh no! I am happy you are fine. See you soon.", who)
	if _callbar: _callbar.queue_free(); _callbar = null; _calllbl = null

var _answered := false
func _call_screen_task(who: String) -> void:
	await _call_screen(who); _answered = true

## word-order puzzle: tap the shuffled words in the right order
func _puzzle(sentence: String) -> void:
	var words := sentence.trim_suffix(".").split(" "); var target := Array(words)
	var pool := target.duplicate(); while pool == target and pool.size() > 1: pool.shuffle()
	var box := PanelContainer.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.95); sb.set_corner_radius_all(20); sb.set_content_margin_all(18); box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5; box.anchor_right = 0.5; box.anchor_top = 0.5; box.anchor_bottom = 0.5; box.offset_left = -380; box.offset_right = 380; box.offset_top = -150; box.offset_bottom = 90; cl.add_child(box)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); box.add_child(v)
	var ans := Label.new(); ans.text = "..."; ans.add_theme_font_size_override("font_size", 30); ans.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); ans.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ans.visible = false; v.add_child(ans)   # v32-polish: built sentence -> the standard caption box (ui.live)
	var row := HFlowContainer.new(); row.alignment = FlowContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("h_separation", 10); v.add_child(row)
	var got: Array = []
	var done := [false]
	for wd in pool:
		var b := Button.new(); b.text = wd; b.custom_minimum_size = Vector2(110, 56); b.add_theme_font_size_override("font_size", 24); row.add_child(b)
		b.pressed.connect(func():
			if b.disabled: return
			if wd == target[got.size()]:
				Audio.click(); got.append(wd); b.disabled = true; ans.text = " ".join(got)
				if got.size() == target.size(): ans.text += "."; done[0] = true
				ui.live("Me: " + ans.text, StoryUI.tr_of(sentence) if done[0] else "")
			else: Audio.bad())
	while not done[0]: await get_tree().process_frame
	Audio.good()
	await ui.line(sentence, "Me")
	box.queue_free()


## v30.5: "It is a new day." as a short upper-centre title (fade in 0.4 s, hold 2 s, fade out 0.5 s) - never under the
## bottom captions or the top-left objectives; fully gone before the next caption
func _new_day_title() -> void:
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER_TOP); v.offset_top = 150; v.offset_left = -400; v.offset_right = 400
	v.alignment = BoxContainer.ALIGNMENT_CENTER; v.modulate.a = 0.0; cl.add_child(v)
	var l: = Label.new();v.name = "DayTitle";l.text = "It is a new day.";l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 44); l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 10); l.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25))
	if UI.font_b: l.add_theme_font_override("font", UI.font_b)
	v.add_child(l)
	var trt: String = ui.tr_of("It is a new day.")
	if trt != "" and App.tr_on():
		var lt := Label.new(); lt.text = trt; lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lt.add_theme_font_size_override("font_size", 26); lt.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
		lt.add_theme_constant_override("outline_size", 8); lt.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25)); v.add_child(lt)
	Audio.say("It is a new day.")
	var tw := create_tween(); tw.tween_property(v, "modulate:a", 1.0, 0.4); tw.tween_interval(2.0); tw.tween_property(v, "modulate:a", 0.0, 0.5)
	await tw.finished; v.queue_free()
	await Audio.wait_idle(5.0)


## v30.5: dream narration - each sentence its own slower clip ("dream ..." keys, tools/build_voice_dream.py) with a 1.0 s
## pause after every sentence; the caption shows the whole line
func _dline(en: String) -> void:
	await Audio.wait_idle(15.0)
	ui.en_l.text = en; ui.tr_l.text = ui.tr_of(en); ui.panel.visible = true
	for snt in RegEx.create_from_string("[^.!?]+[.!?]").search_all(en):
		var t := snt.get_string().strip_edges()
		var dk := "Dream " + t
		Audio.say(dk if Audio._clip(Audio.norm(dk)) != null else t)
		await get_tree().create_timer(0.2).timeout
		await Audio.wait_idle(15.0)
		await get_tree().create_timer(1.0).timeout
