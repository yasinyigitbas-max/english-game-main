extends Control
## house.17: ONE pause menu for every room (the bedroom's menu is the reference: card, Resume / Settings / Main menu,
## settings Voice / Character / Build / Height + Done). Used by main.gd, bathroom.gd and livingroom.gd.
var host: Node
var room := "Bedroom"
var on_resume: Callable
var menu: ColorRect
var settings: ColorRect
var menu_play: Button
var font_b: FontVariation

static func sb(c: Color, r := 22, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r)
	s.content_margin_left = pad + 6; s.content_margin_right = pad + 6; s.content_margin_top = pad; s.content_margin_bottom = pad
	return s

func setup(h: Node, room_name: String, resume: Callable) -> void:
	host = h; room = room_name; on_resume = resume
	name = "GameMenu"; process_mode = Node.PROCESS_MODE_ALWAYS; set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base: Font = load("res://fonts/Nunito.ttf")
	var font := FontVariation.new(); font.base_font = base; font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	font_b = FontVariation.new(); font_b.base_font = base; font_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	var th := Theme.new(); th.default_font = font; th.default_font_size = 24
	th.set_stylebox("normal", "Button", sb(Color(1, 1, 1, 0.94), 18, 10)); th.set_stylebox("hover", "Button", sb(Color(0.93, 0.95, 1.0, 0.98), 18, 10))
	th.set_stylebox("pressed", "Button", sb(Color(0.85, 0.89, 0.98), 18, 10)); th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.13, 0.16, 0.24)); th.set_color("font_hover_color", "Button", Color(0.13, 0.16, 0.24))
	th.set_color("font_pressed_color", "Button", Color(0.13, 0.16, 0.24)); th.set_color("font_focus_color", "Button", Color(0.13, 0.16, 0.24))
	theme = th
	_build_menu(); _build_settings()
	visible = false

func S() -> Dictionary:
	# rooms without some keys (living room) take them from save.json so every room shows the same values
	if not _filled:
		_filled = true
		if FileAccess.file_exists(App.SAVE_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH))
			if d is Dictionary and d.get("state") is Dictionary:
				for r in ROWS: if not host.S.has(r[1]) and d.state.has(r[1]): host.S[r[1]] = d.state[r[1]]
	return host.S
var _filled := false

func _build_menu() -> void:
	menu = ColorRect.new(); menu.name = "Menu"; menu.color = Color(0.07, 0.09, 0.14, 0.45); menu.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(menu)
	var card := PanelContainer.new(); card.name = "MenuCard"; card.add_theme_stylebox_override("panel", sb(Color(1, 1, 1, 0.9), 30, 30))
	card.set_anchors_preset(Control.PRESET_CENTER); card.grow_horizontal = Control.GROW_DIRECTION_BOTH; card.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); v.custom_minimum_size.x = 360; card.add_child(v)
	var t := Label.new(); t.text = "English Home"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var st := Label.new(); st.name = "RoomLabel"; st.text = "%s · A1–A2" % room; st.add_theme_font_size_override("font_size", 22)
	st.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55)); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var sp := Control.new(); sp.custom_minimum_size.y = 8; v.add_child(sp)
	menu_play = _btn(v, "Resume", func(): on_resume.call(), true); menu_play.name = "Resume"
	_btn(v, "Settings", func(): settings.visible = true).name = "Settings"
	_btn(v, "Main menu", func(): to_main_menu()).name = "MainMenu"

func _btn(parent: Control, txt: String, cb: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(0, 62); b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26)
	if primary:
		b.add_theme_stylebox_override("normal", sb(Color(0.31, 0.42, 0.93), 18, 10)); b.add_theme_stylebox_override("hover", sb(Color(0.36, 0.48, 0.97), 18, 10))
		b.add_theme_stylebox_override("pressed", sb(Color(0.25, 0.35, 0.8), 18, 10))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color(1, 1, 1))
	else:
		b.add_theme_stylebox_override("normal", sb(Color(0.93, 0.94, 0.97), 18, 10))
	b.pressed.connect(func(): Audio.click(); cb.call()); parent.add_child(b); return b

const ROWS := [["Voice", "voice", [true, false], ["On", "Off"]], ["Character", "gender", ["men", "women"], ["Man", "Woman"]],
	["Build", "build", ["thin", "average", "fat"], ["Thin", "Average", "Fat"]], ["Height", "height", ["short", "medium", "tall"], ["Short", "Medium", "Tall"]]]
var row_btns := {}
var narr_label: Label
var narr_btn: Button
func _tr_on() -> bool:
	var s = host.get("S") if host else null   # rooms keep the live TR flag in S.tr; else the saved one
	if s is Dictionary and s.has("tr"): return bool(s.tr)
	return bool(App.call("tr_saved")) if App.has_method("tr_saved") else false
func _build_settings() -> void:
	settings = ColorRect.new(); settings.name = "SettingsPanel"; settings.color = Color(0.07, 0.09, 0.14, 0.55); settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.visible = false; add_child(settings)
	var card := PanelContainer.new(); card.name = "SettingsCard"; card.add_theme_stylebox_override("panel", sb(Color(1, 1, 1, 0.94), 30, 26))
	card.set_anchors_preset(Control.PRESET_CENTER); card.grow_horizontal = Control.GROW_DIRECTION_BOTH; card.grow_vertical = Control.GROW_DIRECTION_BOTH; settings.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); v.custom_minimum_size.x = 420; card.add_child(v)
	var t := Label.new(); t.text = "Settings"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); v.add_child(t)
	for r in ROWS:
		var h := HBoxContainer.new(); v.add_child(h)
		var l := Label.new(); l.text = r[0]; l.add_theme_font_size_override("font_size", 24); l.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var b := Button.new(); b.name = "Set_" + String(r[1]); b.custom_minimum_size = Vector2(170, 54); b.add_theme_stylebox_override("normal", sb(Color(0.91, 0.93, 0.98), 16, 8)); h.add_child(b)
		var key: String = r[1]; var vals: Array = r[2]; var labs: Array = r[3]
		row_btns[key] = b
		b.pressed.connect(func():
			Audio.click()
			var i := (maxi(0, vals.find(S().get(key, vals[0]))) + 1) % vals.size(); S()[key] = vals[i]; b.text = labs[i]
			_apply(key))
	var close := _btn(v, "Done", func(): settings.visible = false; _persist(), true); close.name = "Done"
	_sync()

func _sync() -> void:
	for r in ROWS:
		var vals: Array = r[2]; var labs: Array = r[3]
		row_btns[r[1]].text = labs[maxi(0, vals.find(S().get(r[1], vals[0])))]
	if narr_btn:
		var trn := _tr_on()
		narr_label.text = App.t_lang("narrator", trn)
		narr_btn.text = App.t_lang("narrator_" + String(App.settings.narrator), trn)

func _apply(key: String) -> void:
	if key == "voice":
		Audio.voice_player.volume_db = 0.0 if S().voice else -80.0
	if key == "gender" and not host.get_script().resource_path.ends_with("main.gd") and host.hero.gender != S().gender:
		host.hero.setup(S().gender); host.hero.play("idle", 0.0)
	if host.has_method("_apply_character"): host._apply_character()

## settings live in save.json "state" so every room shows the same values
func _persist() -> void:
	if host.has_method("save_game"): host.save_game(); return
	if not FileAccess.file_exists(App.SAVE_PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH))
	if d is Dictionary and d.get("state") is Dictionary:
		for r in ROWS: if S().has(r[1]): d.state[r[1]] = S()[r[1]]
		App.patch_save({"state": d.state})

func show_menu(on: bool) -> void:
	if on and preload("res://scripts/phone.gd").active_locked: return   # house.20: lesson/quiz running on the phone
	visible = on; menu.visible = on; if not on: settings.visible = false
	_sync()

func to_main_menu() -> void:
	_persist()
	get_tree().paused = false
	if host.has_method("_to_main_menu"): host._to_main_menu(); return
	get_tree().change_scene_to_file("res://menu.tscn")
