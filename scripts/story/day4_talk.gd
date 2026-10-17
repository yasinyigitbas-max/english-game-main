## v33 (red): shared living-room talk helpers for days 4 and 7 (day4_breakfast.gd, day4_evening.gd, day7_party.gd).
## Static only (preload, no class_name). Every line goes through the ROOM's one bottom caption box (lr.caption, standard
## style, TR inside from lr.XTR / data/extra_lines.json). Family lines use NpcTalk (the speaker keeps the pose: turn + nod).
##   const T := preload("res://scripts/story/day4_talk.gd")
##   await T.fam(lr, member, "Where is the torch?")   # "Name: line" in the member's own voice
##   await T.me(lr, "I bought candles.")             # "Me: line" (narrator voice)
##   await T.line(lr, "The lights went out.")        # narrator
##   await T.puzzle(lr, "The torch is next to the candles.")   # scrambled words; the built sentence shows in the caption box
##   var ok: bool = await T.choose(lr, q)            # TestBank question {q, opts, a, say, tr} as a centre panel
extends RefCounted

const NpcTalk := preload("res://scripts/core/npc_talk.gd")

static func tr_of(en: String) -> String: return StoryUI.tr_of(en)

static func wait(lr: Node, t: float) -> void: await lr.get_tree().create_timer(t, false).timeout

## narrator line in the room caption box, waits until it has been spoken
static func line(lr: Node, en: String) -> void:
	await Audio.wait_idle(12.0); lr.caption(en); await wait(lr, 0.2); await Audio.wait_idle(12.0); await wait(lr, 0.5)

static func me(lr: Node, en: String, tr := "") -> void:
	await lr._say_me(en, tr if tr != "" else tr_of(en))

## family member line (member = an entry of lr.humans()); empty member = narrator
static func fam(lr: Node, b: Dictionary, en: String, tr := "") -> void:
	if b.is_empty() or not is_instance_valid(b.get("node")): await line(lr, en); return
	var who := String(b.data.get("name", ""))
	var t := tr if tr != "" else tr_of(en)
	var cap := "%s: %s" % [who, en] if who != "" else en
	lr.XTR[cap] = ("%s: %s" % [who, t]) if who != "" else t
	await Audio.wait_idle(12.0)
	var st := {}
	if b.node is DemoCharacter and is_instance_valid(lr.hero): st = NpcTalk.begin(b.node, lr.hero.global_position)
	lr.caption(cap, false); Audio.say_as(en, lr.voice_of(b))
	await wait(lr, 0.2); await Audio.wait_idle(12.0)
	if b.node is DemoCharacter: NpcTalk.end(b.node, st)
	await wait(lr, 0.6)

## everybody at once (one caption "Everybody: ..." in the first member's voice, every member nods)
static func all(lr: Node, hs: Array, en: String) -> void:
	if hs.is_empty(): await line(lr, en); return
	var cap := "Everybody: " + en
	lr.XTR[cap] = "Herkes: " + tr_of(en)
	await Audio.wait_idle(12.0)
	var sts: Array = []
	for b in hs:
		sts.append(NpcTalk.begin(b.node, lr.hero.global_position) if b.node is DemoCharacter else {})
	lr.caption(cap, false); Audio.say_as(en, lr.voice_of(hs[0]))
	await wait(lr, 0.2); await Audio.wait_idle(12.0)
	for i in hs.size():
		if hs[i].node is DemoCharacter: NpcTalk.end(hs[i].node, sts[i])
	await wait(lr, 0.6)

static func _panel(lr: Node, nm: String, top := -190.0, bottom := 70.0) -> Array:
	var cl := CanvasLayer.new(); cl.layer = 30; lr.add_child(cl)
	var box := PanelContainer.new(); box.name = nm; var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.95); sb.set_corner_radius_all(20); sb.set_content_margin_all(18); box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5; box.anchor_right = 0.5; box.anchor_top = 0.5; box.anchor_bottom = 0.5; box.offset_left = -400; box.offset_right = 400; box.offset_top = top; box.offset_bottom = bottom; cl.add_child(box)
	Objectives.ovl_register(box, 5)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); box.add_child(v)
	return [cl, v]

static func _lbl(v: Control, t: String, fs: int, c: Color) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(l); return l

## word-order puzzle (day3_evening.gd rule): tap the shuffled words in order; the end mark (. ? !) is kept. The built
## sentence goes into the ONE caption box ("Me: ...", TR inside once complete); then it is spoken as the player's line.
static func puzzle(lr: Node, sentence: String, tr := "", speak := true) -> void:
	var t := tr if tr != "" else tr_of(sentence)
	var end := sentence.right(1) if sentence.right(1) in [".", "?", "!"] else ""
	var target := Array(sentence.left(sentence.length() - end.length()).split(" "))
	var pool := target.duplicate()
	var guard := 0
	while pool == target and pool.size() > 1 and guard < 20: pool.shuffle(); guard += 1
	var cl := CanvasLayer.new(); cl.layer = 30; lr.add_child(cl)
	var P := StoryUI.scramble_panel(cl, "D4Puzzle", pool)   # v33: standard compact scramble panel (low, above the caption box)
	Objectives.ovl_register(P.box, 5)
	var askt: Label = P.askt
	var got: Array = []
	var done := [false]
	for bt in P.buttons:
		var wd: String = bt.text
		bt.pressed.connect(func():
			if bt.disabled or done[0]: return
			if wd == target[got.size()]:
				Audio.click(); got.append(wd); bt.disabled = true
				var built := " ".join(got)
				if got.size() == target.size(): built += end; done[0] = true
				lr.caption_live("Me: " + built, ("Ben: " + t) if done[0] and t != "" else "")
			else: Audio.bad())
	while not done[0] and is_instance_valid(cl):
		askt.visible = true   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
		await lr.get_tree().process_frame
	Audio.good()
	await wait(lr, 0.5)
	if is_instance_valid(cl): cl.queue_free()
	if speak: await me(lr, sentence, t)

## multiple-choice review (TestBank entry): the question in a centre panel, wrong taps are marked and can be retried;
## the right answer is then spoken as the player's line. Returns true when the first tap was right.
static func choose(lr: Node, q: Dictionary) -> bool:
	var pv := _panel(lr, "D4Choose", -200, 60); var cl: CanvasLayer = pv[0]; var v: VBoxContainer = pv[1]
	_lbl(v, "Choose the right words.", 18, Color(0.4, 0.45, 0.6))
	var askt := _lbl(v, "Doğru kelimeleri seç.  (%s)" % String(q.get("tr", "")), 15, Color(0.35, 0.5, 0.8))
	_lbl(v, String(q.get("q", "")), 32, Color(0.12, 0.15, 0.25))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 16); v.add_child(row)
	var st := [false, true]   # done, first try
	var src: Array = q.get("opts", [])
	var order: Array = range(src.size()); order.shuffle()   # raw bank entries have the answer first
	var opts: Array = []
	for o in order: opts.append(src[o])
	var right: int = order.find(int(q.get("a", 0)))
	for i in opts.size():
		var bt := Button.new(); bt.text = String(opts[i]); bt.custom_minimum_size = Vector2(180, 60); bt.add_theme_font_size_override("font_size", 24); row.add_child(bt)
		var ii: int = i
		bt.pressed.connect(func():
			if st[0] or bt.disabled: return
			if ii == right: Audio.good(); st[0] = true
			else: Audio.bad(); bt.disabled = true; st[1] = false)
	while not st[0] and is_instance_valid(cl):
		askt.visible = true   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
		await lr.get_tree().process_frame
	await wait(lr, 0.4)
	if is_instance_valid(cl): cl.queue_free()
	await me(lr, String(q.get("say", "")), String(q.get("tr", "")))
	return st[1]

## polaroid card (bedtime.gd _polaroid look), any size
static func card(key: String, cap: String, i: int, w := 212.0) -> Control:
	var k := w / 212.0; var h := 268.0 * k
	var wrap := Control.new(); wrap.custom_minimum_size = Vector2(w, h); wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tilt := Control.new(); tilt.size = Vector2(w, h); tilt.pivot_offset = Vector2(w / 2, h / 2); tilt.rotation_degrees = [-4.0, 3.0, -2.0, 4.0, -3.0, 2.0][i % 6]; wrap.add_child(tilt)
	var sh := Panel.new(); var ss := StyleBoxFlat.new(); ss.bg_color = Color(0, 0, 0, 0.35); ss.set_corner_radius_all(4); sh.add_theme_stylebox_override("panel", ss); sh.position = Vector2(5, 8); sh.size = Vector2(w, h); tilt.add_child(sh)
	var c := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.99, 0.98, 0.95); sb.set_corner_radius_all(3); sb.border_color = Color(0.88, 0.86, 0.8); sb.set_border_width_all(1)
	c.add_theme_stylebox_override("panel", sb); c.size = Vector2(w, h); tilt.add_child(c)
	var well := ColorRect.new(); well.color = Color(0.12, 0.12, 0.14); well.position = Vector2(12, 12) * k; well.size = Vector2(188, 188) * k; c.add_child(well)
	var tex := TextureRect.new(); tex.position = Vector2(14, 14) * k; tex.size = Vector2(184, 184) * k; tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.texture = Life.photo(key)
	if tex.texture == null: tex.texture = Life.photo("home")
	tex.modulate = Color(1.0, 0.96, 0.88); c.add_child(tex)
	var l := Label.new(); l.text = cap; l.add_theme_font_size_override("font_size", int(17 * k)); l.add_theme_color_override("font_color", Color(0.12, 0.16, 0.38))
	if UI.font_b: l.add_theme_font_override("font", UI.font_b)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(8, 204) * k; l.size = Vector2(196, 60) * k; c.add_child(l)
	var tape := ColorRect.new(); tape.color = Color(0.98, 0.92, 0.6, 0.75); tape.size = Vector2(80, 24) * k; tape.position = Vector2(66, -10) * k; c.add_child(tape)
	return wrap
