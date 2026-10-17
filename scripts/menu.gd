extends Control
## Main menu for English Home 3D. Builds every page in code (same approach as 3dv2's _build_ui).
## Pages: title, grammar (A1/A2 tabs -> topic pages), vocabulary (A1/A2 x verbs/nouns/adjectives), settings overlay.

var grammar: Array = []
var vocab: Dictionary = {}
var page: Control
var overlay: Control
var toast: PanelContainer
var g_level := "A1"
var g_topic := 0
var v_level := "A1"
var v_cat := "verbs"
var current := "title"

var _note_lbls := []
func _ready() -> void:
	theme = UI.theme
	grammar = App.load_json("res://data/grammar.json").topics
	vocab = App.load_json("res://data/vocabulary.json").levels
	var bg := TextureRect.new()
	bg.texture = load("res://ui/menu_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var scrim := ColorRect.new()
	scrim.color = UI.SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	show_title()

# ------------------------------------------------------------ helpers
func _clear() -> void:
	if page:
		page.queue_free()
		remove_child(page)
	if overlay:
		overlay.queue_free()
		remove_child(overlay)
		overlay = null

func _btn(text: String, h := 62, size := 26, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_size_override("font_size", size)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if primary:
		UI.primary_button(b)
	else:
		UI.soft_button(b)
	b.pressed.connect(UI.click)
	return b

func _tab(text: String, on: bool, cb: Callable, w := 0) -> Button:
	var b := _btn(text, 56, 22, on)
	if w > 0:
		b.custom_minimum_size.x = w
	b.pressed.connect(cb)
	return b

func _vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func _hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func _card(color := UI.CARD, r := 30, pad := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.sb(color, r, pad))
	return p

func _scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.scroll_deadzone = 8
	return s

## Full-screen page frame: margins + top bar (Back, title, extra controls) + body.
func _frame(title: String) -> Array:
	page = MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right"]:
		page.add_theme_constant_override("margin_" + k, 28)
	for k in ["top", "bottom"]:
		page.add_theme_constant_override("margin_" + k, 20)
	add_child(page)
	var v := _vbox(14)
	page.add_child(v)
	var bar := _hbox(12)
	v.add_child(bar)
	var back := _btn(App.t("back"), 60, 24)
	back.custom_minimum_size.x = 130
	back.name = "Back"
	back.pressed.connect(show_title)
	bar.add_child(back)
	var tp := _card(Color(1, 1, 1, 0.9), 18, 6)
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := UI.label(title, 30, true)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tp.add_child(tl)
	bar.add_child(tp)
	return [v, bar]

func _toast(msg: String) -> void:
	if toast:
		toast.queue_free()
	toast = _card(Color(0.08, 0.10, 0.16, 0.85), 22, 12)
	var l := UI.label(msg, 22, true, Color(1, 1, 1))
	l.custom_minimum_size.x = 560
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_child(l)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.position.y -= 30
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)

# ------------------------------------------------------------ title
func show_title() -> void:
	_clear()
	current = "title"
	page = CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var card := _card(Color(1, 1, 1, 0.92), 30, 30)
	card.name = "MenuCard"
	page.add_child(card)
	var v := _vbox(14)
	v.custom_minimum_size.x = 440
	card.add_child(v)
	var t := UI.label("English Home", 46, true, UI.INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	# house.24: notebook prompt (EN + TR), narrated once per launch
	var nb := UI.label("Get a notebook and a pencil. Let's take notes.", 20, true); nb.name = "NotebookTip"
	var nbt := UI.label("Bir defter ve kalem al. Hadi not alalım.", 16, false, UI.MUTED)
	nb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nbt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note_lbls = [nb, nbt]
	if not App.has_meta("note_said"): App.set_meta("note_said", true); Audio.say("Get a notebook and a pencil. Let's take notes.")
	var st := UI.label(App.t("subtitle"), 22, false, UI.MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st); v.add_child(nb); v.add_child(nbt)
	var ng := _btn(App.t("new_game"), 62, 26, true)
	ng.name = "NewGame"
	ng.pressed.connect(_new_game)
	v.add_child(ng)
	var cont := _btn(App.t("continue"))
	cont.name = "Continue"
	cont.disabled = not App.has_save()
	cont.pressed.connect(_continue)
	v.add_child(cont)
	var row := _hbox(12)
	v.add_child(row)
	for d in [["grammar", show_grammar], ["vocab", show_vocab]]:
		var b := _btn(App.t(d[0]), 62, 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.pressed.connect(d[1])
		row.add_child(b)
	var s := _btn(App.t("settings"))
	s.pressed.connect(show_settings)
	v.add_child(s)

func _go_game() -> void:
	if ResourceLoader.exists(App.GAME_SCENE):
		get_tree().change_scene_to_file(App.GAME_SCENE)
	else:
		_toast(App.t("no_game") + App.GAME_SCENE)

func _new_game() -> void:
	App.continue_requested = false
	_go_game()

func _continue() -> void:
	App.continue_requested = true
	_go_game()

# ------------------------------------------------------------ settings
func show_settings() -> void:
	if overlay:
		overlay.queue_free()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.07, 0.09, 0.14, 0.55)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	current = "settings"
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var card := _card(Color(1, 1, 1, 0.94), 30, 26)
	cc.add_child(card)
	var v := _vbox(14)
	v.custom_minimum_size.x = 520
	card.add_child(v)
	v.add_child(UI.label(App.t("settings"), 36, true, UI.INK))
	# language
	var lr := _hbox(12)
	v.add_child(lr)
	var ll := UI.label(App.t("language"), 24, false, UI.BODY)
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lr.add_child(ll)
	for code in ["tr", "en"]:
		lr.add_child(_tab(code.to_upper(), App.settings.lang == code, func():
			App.settings.lang = code; App.save_settings(); show_title(); show_settings(), 96))
	for key in ["volume", "sfx"]:
		var r := _hbox(16)
		v.add_child(r)
		var l := UI.label(App.t(key), 24, false, UI.BODY)
		l.custom_minimum_size.x = 190
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05
		sl.value = float(App.settings[key])
		sl.custom_minimum_size = Vector2(0, 56)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var track := UI.sb(UI.CHIP_ON, 8, 0); track.content_margin_top = 8; track.content_margin_bottom = 8
		var fill := UI.sb(UI.BLUE, 8, 0); fill.content_margin_top = 8; fill.content_margin_bottom = 8
		sl.add_theme_stylebox_override("slider", track)
		sl.add_theme_stylebox_override("grabber_area", fill)
		sl.add_theme_stylebox_override("grabber_area_highlight", fill)
		sl.value_changed.connect(func(x):
			App.settings[key] = x; App.apply_volume(); App.save_settings())
		sl.drag_ended.connect(func(_c): UI.click())
		r.add_child(sl)
	var close := _btn(App.t("close"), 62, 26, true)
	close.name = "Close"
	close.pressed.connect(func(): overlay.queue_free(); overlay = null; current = "title")
	v.add_child(close)

# ------------------------------------------------------------ grammar
func show_grammar() -> void:
	_clear()
	current = "grammar"
	var f := _frame(App.t("grammar"))
	var v: VBoxContainer = f[0]
	var bar: HBoxContainer = f[1]
	for lv in ["A1", "A2"]:
		bar.add_child(_tab(lv, g_level == lv, func(): g_level = lv; g_topic = 0; show_grammar(), 96))
	var body := _hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	# topic list
	var lp := _card(Color(1, 1, 1, 0.9), 26, 10)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 0.42
	body.add_child(lp)
	var ls := _scroll()
	ls.name = "TopicScroll"
	lp.add_child(ls)
	var lv := _vbox(8)
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(lv)
	var topics := level_topics(g_level)
	g_topic = clampi(g_topic, 0, topics.size() - 1)
	for i in topics.size():
		var tp: Dictionary = topics[i]
		var b := _btn(tp.title if App.settings.lang == "en" else tp.title_tr, 64, 20, i == g_topic)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): g_topic = i; show_grammar())
		lv.add_child(b)
	# topic page
	var rp := _card(UI.CARD, 26, 18)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.size_flags_stretch_ratio = 1.0
	body.add_child(rp)
	var rs := _scroll()
	rs.name = "PageScroll"
	rp.add_child(rs)
	var pv := _vbox(10)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(pv)
	_topic_page(pv, topics[g_topic])

func level_topics(lv: String) -> Array:
	return grammar.filter(func(x): return x.level == lv)

func _section(parent: Control, title: String) -> void:
	var l := UI.label(title, 24, true, UI.BLUE)
	l.custom_minimum_size.y = 40
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	parent.add_child(l)

func _topic_page(pv: VBoxContainer, tp: Dictionary) -> void:
	pv.add_child(UI.label(tp.title, 32, true, UI.INK))
	pv.add_child(UI.label(tp.title_tr, 22, false, UI.MUTED))
	_section(pv, App.t("use"))
	pv.add_child(UI.label(tp.use_tr, 22, false, UI.BODY))
	_section(pv, App.t("form"))
	pv.add_child(UI.label(tp.form_tr, 22, false, UI.BODY))
	_section(pv, App.t("table"))
	var rows: Array = tp.table
	var grid := GridContainer.new()
	grid.columns = rows[0].size()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	pv.add_child(grid)
	for ri in rows.size():
		for cell in rows[ri]:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UI.sb(UI.BLUE if ri == 0 else UI.ROW, 12, 8))
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var l := UI.label(str(cell), 20, ri == 0, Color(1, 1, 1) if ri == 0 else UI.INK)
			l.custom_minimum_size.x = 60
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.add_child(l)
			grid.add_child(p)
	for kind in ["positive", "negative", "question"]:
		_section(pv, App.t(kind))
		for e in tp[kind]:
			var p := _card(UI.ROW, 16, 8)
			var ev := _vbox(2)
			p.add_child(ev)
			ev.add_child(UI.label(e.en, 23, true, UI.INK))
			ev.add_child(UI.label(e.tr, 20, false, UI.MUTED))
			if e.has("short"):
				var sh := UI.label("— " + e.short + "  (" + e.short_tr + ")", 20, true, UI.GREEN)
				ev.add_child(sh)
			pv.add_child(p)
	_section(pv, App.t("mistakes"))
	for m in tp.mistakes:
		var p := _card(UI.ROW, 16, 8)
		var mv := _vbox(4)
		p.add_child(mv)
		mv.add_child(_tagged(App.t("wrong"), m.wrong, UI.RED))
		mv.add_child(_tagged(App.t("right"), m.right, UI.GREEN))
		mv.add_child(UI.label(m.tr, 20, false, UI.BODY))
		pv.add_child(p)

func _tagged(tag: String, text: String, c: Color) -> HBoxContainer:
	var h := _hbox(10)
	var tagp := PanelContainer.new()
	tagp.add_theme_stylebox_override("panel", UI.sb(c, 10, 3))
	tagp.custom_minimum_size.x = 104
	var tl := UI.label(tag, 18, true, Color(1, 1, 1))
	tl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagp.add_child(tl)
	tagp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(tagp)
	var l := UI.label(text, 22, true, c)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

# ------------------------------------------------------------ vocabulary
func show_vocab() -> void:
	_clear()
	current = "vocab"
	var f := _frame(App.t("vocab"))
	var v: VBoxContainer = f[0]
	var bar: HBoxContainer = f[1]
	for lv in ["A1", "A2"]:
		bar.add_child(_tab(lv, v_level == lv, func(): v_level = lv; show_vocab(), 96))
	var tabs := _hbox(10)
	v.add_child(tabs)
	var words: Array = vocab[v_level][v_cat]
	for c in ["verbs", "nouns", "adjectives"]:
		var b := _tab(App.t(c) + " (" + str(vocab[v_level][c].size()) + ")", v_cat == c, func(): v_cat = c; show_vocab())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	var card := _card(UI.CARD, 26, 14)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card)
	var cv := _vbox(8)
	card.add_child(cv)
	cv.add_child(UI.label(App.t("tap_hint"), 18, false, UI.MUTED))
	var s := _scroll()
	s.name = "WordScroll"
	cv.add_child(s)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(grid)
	for w in words:
		grid.add_child(_word_row(w))

func _word_row(w: Dictionary) -> PanelContainer:
	var p := _card(UI.ROW, 16, 6)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _hbox(12)
	p.add_child(h)
	if App.has_word_clip(w.en):
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		UI.primary_button(b)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ic := Control.new()
		ic.set_script(load("res://scripts/play_icon.gd"))
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		b.pressed.connect(func(): App.say_word(w.en))
		h.add_child(b)
	var en := UI.label(w.en, 23, true, UI.INK)
	en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	en.size_flags_stretch_ratio = 0.9
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	en.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(en)
	var dash := UI.label("—", 23, false, UI.MUTED)
	dash.autowrap_mode = TextServer.AUTOWRAP_OFF
	dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dash.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(dash)
	# Turkish: primary meaning at normal size, other common meanings below in a smaller muted font.
	var tv := _vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_stretch_ratio = 1.1
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(tv)
	var tr := UI.label(w.tr, 21, false, UI.BODY)
	tr.name = "TrMain"
	tv.add_child(tr)
	var more: Array = w.get("tr_more", [])
	if more.size() > 0:
		var tm := UI.label(", ".join(PackedStringArray(more)), 17, false, UI.MUTED)
		tm.name = "TrMore"
		tv.add_child(tm)
	return p
