## GameHUD - shared HUD (res://ui/shared/hud.tscn), identical to the bedroom HUD in english_game_3dv2/scripts/main.gd
## _build_ui + touch.gd: mission bar top-left, phone (68x68) + pause (64x64) top-right, analog stick bottom-left,
## round hand action button + camera ring bottom-right, dark caption pill bottom-centre with a TR toggle,
## verb chips stacked left of the action button.  Extra info (place) is a second small pill under the mission
## bar in the same style; clock and money live inside the phone (status bar, Home, Clock, Wallet apps).
## Requires the UI autoload (theme.gd: theme, font, font_b, sb(), click()).  See SHARED_UI.md.
class_name GameHUD
extends CanvasLayer

signal phone_opened
signal pause_toggled(on: bool)

var camera: Camera3D                   # the scene camera (CameraRig); handed to ui/pocket_phone.gd
const POCKET_PHONE := "res://scripts/pocket_phone.gd"   # v29 review: res://ui/pocket_phone.gd never existed (instant open)
var pocket: Object
var player: Node                       # any node with `stick: Vector2`, optional `cam_stick: Vector2`, optional perform(it, cb)
var tr_func: Callable                  # func(en: String) -> String  (Turkish line; "" = none)
var voice_func: Callable               # func(en: String) -> void    (default: /root/Voice.say when present)
var root: Control
var mission_panel: PanelContainer; var mission_lbl: Label; var mission_tr: Label
var place_panel: PanelContainer; var place_lbl: Label; var place_tr: Label
var _phone_shown := false
var _clock_off := false   # blue v29: clock strip hidden by the open phone (restored on close)
var phone_btn: Button; var phone_dot: Panel; var pause_btn: Button
var phone: GamePhone
var pause_menu: Control
var cap_panel: PanelContainer; var cap_en: Label; var cap_tr: Label; var tr_btn: Button
var chips: VBoxContainer
var stick: Control
var show_tr := false
var mission := ""; var mission_tr_text := ""
var place := ""; var place_tr_text := ""
var cap_text := ""
var cap_serial := 0
var cue_on := false                    # mission bar flashes blue (3dv2 cue highlight), e.g. hud.cue_on = true
var phone_light: Panel
var _cue_t := 0.0
var near                               # current interactable (needs obj_name + verb_list() -> [[label, Callable], ...])

func _ready() -> void:
	layer = 10; process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new(); root.name = "UIRoot"; root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme; add_child(root)
	stick = TouchControls.new(); stick.hud = self; stick.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(stick)
	# mission bar (3dv2: dark 0.6 pill at 20,18; bold 22 white + TR 18 light blue)
	mission_panel = _dark_pill(Vector2(20, 18), 0.6)
	var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 0); mission_panel.add_child(mv)
	mission_lbl = _lbl(22, true, Color(1, 1, 1)); mv.add_child(mission_lbl)
	mission_tr = _lbl(18, false, Color(0.75, 0.88, 1.0)); mv.add_child(mission_tr)
	# place pill: same language, smaller, under the mission bar
	place_panel = _dark_pill(Vector2(20, 18), 0.45, 14, 6)
	var pv := HBoxContainer.new(); pv.add_theme_constant_override("separation", 10); place_panel.add_child(pv)
	place_lbl = _lbl(18, true, Color(1, 1, 1)); pv.add_child(place_lbl)
	place_tr = _lbl(16, false, Color(0.75, 0.88, 1.0)); pv.add_child(place_tr)
	# pause + phone (exact 3dv2 offsets)
	pause_btn = Button.new(); pause_btn.text = "II"; pause_btn.name = "Pause"; pause_btn.add_theme_font_override("font", UI.font_b)
	pause_btn.anchor_left = 1; pause_btn.anchor_right = 1; pause_btn.offset_left = -84; pause_btn.offset_right = -20; pause_btn.offset_top = 18; pause_btn.offset_bottom = 82
	pause_btn.pressed.connect(func(): UI.click(); set_paused(true)); root.add_child(pause_btn)
	phone_btn = Button.new(); phone_btn.name = "PhoneBtn"; phone_btn.tooltip_text = "Phone"
	phone_btn.anchor_left = 1; phone_btn.anchor_right = 1; phone_btn.offset_left = -168; phone_btn.offset_right = -100; phone_btn.offset_top = 16; phone_btn.offset_bottom = 84
	phone_btn.add_theme_stylebox_override("normal", UI.sb(Color(1, 1, 1, 0.94), 18, 6)); phone_btn.add_theme_stylebox_override("hover", UI.sb(Color(0.93, 0.95, 1.0), 18, 6))
	phone_btn.add_theme_stylebox_override("pressed", UI.sb(Color(0.82, 0.86, 0.98), 18, 6))
	var pic := TextureRect.new(); pic.texture = load("res://ui/phone/hud_phone.png"); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.set_anchors_preset(Control.PRESET_FULL_RECT); pic.offset_left = 12; pic.offset_right = -12
	pic.offset_top = 10; pic.offset_bottom = -10; pic.mouse_filter = Control.MOUSE_FILTER_IGNORE; phone_btn.add_child(pic)
	phone_dot = Panel.new(); phone_dot.add_theme_stylebox_override("panel", UI.sb(Color(0.93, 0.26, 0.3), 9, 0)); phone_dot.position = Vector2(50, 2)
	phone_dot.size = Vector2(18, 18); phone_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; phone_dot.visible = false; phone_btn.add_child(phone_dot)
	phone_light = Panel.new(); phone_light.name = "PhoneLight"; phone_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsb := StyleBoxFlat.new(); lsb.bg_color = Color(0.35, 0.62, 1.0, 0.35); lsb.set_corner_radius_all(26); lsb.border_color = Color(0.45, 0.75, 1.0)
	lsb.set_border_width_all(4); lsb.shadow_color = Color(0.35, 0.65, 1.0, 0.8); lsb.shadow_size = 14; phone_light.add_theme_stylebox_override("panel", lsb)
	phone_light.anchor_left = 1; phone_light.anchor_right = 1; phone_light.offset_left = -176; phone_light.offset_right = -92; phone_light.offset_top = 8; phone_light.offset_bottom = 92
	phone_light.visible = false; root.add_child(phone_light)
	phone_btn.pressed.connect(func(): UI.click(); open_phone()); root.add_child(phone_btn)
	# caption
	cap_panel = PanelContainer.new(); cap_panel.name = "Caption"; cap_panel.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.10, 0.16, 0.72), 22, 12))
	cap_panel.add_to_group("caption_box"); cap_panel.visibility_changed.connect(func(): if cap_panel.visible: StoryUI.claim(cap_panel))   # v32-polish: ONE caption box on screen (StoryUI.claim)
	root.add_child(cap_panel)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 16); cap_panel.add_child(ch)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 2); ch.add_child(cv)
	cap_en = _lbl(30, true, Color(1, 1, 1)); cap_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cv.add_child(cap_en)
	cap_tr = _lbl(22, false, Color(0.75, 0.88, 1.0)); cap_tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cv.add_child(cap_tr)
	tr_btn = Button.new(); tr_btn.text = "TR"; tr_btn.name = "Translate"; tr_btn.custom_minimum_size = Vector2(76, 56); tr_btn.add_theme_font_override("font", UI.font_b)
	tr_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tr_btn.pressed.connect(func(): UI.click(); set_tr(not show_tr)); ch.add_child(tr_btn)
	cap_panel.visible = false
	chips = VBoxContainer.new(); chips.name = "Chips"; chips.add_theme_constant_override("separation", 10); chips.alignment = BoxContainer.ALIGNMENT_END; root.add_child(chips)
	phone = (load("res://ui/shared/phone.tscn") as PackedScene).instantiate(); root.add_child(phone)
	root.move_child(phone, cap_panel.get_index())     # under the caption (3dv2 order)
	phone.closed.connect(_on_phone_closed)
	_build_pause()
	get_viewport().size_changed.connect(_layout)
	_refresh()

func _dark_pill(pos: Vector2, a: float, r := 18, pad := 10) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UI.sb(Color(0.08, 0.10, 0.16, a), r, pad)); p.position = pos
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(p); return p

func _lbl(fs: int, bold: bool, c: Color) -> Label:
	var lb := Label.new(); lb.add_theme_font_size_override("font_size", fs); lb.add_theme_color_override("font_color", c)
	if bold: lb.add_theme_font_override("font", UI.font_b)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE; return lb

## 3dv2 behaviour: mission / pause / phone button hide while the phone is open; notify glow pulses; cue flash
func _process(dt: float) -> void:
	_cue_t += dt
	var pv := phone.visible
	mission_panel.visible = false; place_panel.visible = false   # v30.5: one top-left window (Objectives)
	pause_btn.visible = not pv; phone_btn.visible = not pv and App.has_phone   # v29.1
	var lh = Life.get("_hud")   # blue v29: the clock strip would draw over the phone's own status bar
	if lh is CanvasLayer:
		if pv and lh.visible: lh.visible = false; _clock_off = true
		elif not pv and _clock_off: lh.visible = true; _clock_off = false
	phone_light.visible = phone_dot.visible and not pv and App.has_phone   # v29 review: no glow without the phone
	phone_light.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_cue_t * 5.0))
	var pulse := 0.5 + 0.5 * sin(_cue_t * 4.0)
	var sb := mission_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb.bg_color = Color(0.31, 0.42, 0.93, 0.75 + 0.2 * pulse) if cue_on else Color(0.08, 0.10, 0.16, 0.6)
		sb.border_color = Color(1, 1, 1, 0.5 + 0.4 * pulse); sb.set_border_width_all(3 if cue_on else 0)

# ------------------------------------------------------------ public API
func set_mission(en: String, tr_ := "") -> void:
	mission = en; mission_tr_text = tr_; _refresh()
	# v30.5: the old mission pill is gone; missions go to the one Objectives list (non-empty only, no duplicate pulse)
	if en != "" and (Objectives.items.is_empty() or String(Objectives.items[0].en) != en):
		Objectives.set_list([{"en": en, "tr": tr_}] if tr_ != "" else [en])
func set_place(en: String, tr_ := "") -> void: place = en; place_tr_text = tr_; _refresh()
func set_tr(on: bool) -> void:
	var changed := on != show_tr
	show_tr = on; App.save_tr(on); _refresh()
	if is_inside_tree():
		Lines.apply_signs(get_tree(), on)   # v28 blue: in-world signs
		if changed: _persist_tr(on)

## v29 review: the TR toggle is one setting for every scene: the scene's S.tr + save.json state.tr
func _persist_tr(on: bool) -> void:
	var sc := get_tree().current_scene
	if sc:
		var s = sc.get("S")
		if s is Dictionary: s["tr"] = on
		var rp = sc.get("room_phone")
		if rp and rp.get("S") is Dictionary: rp.S["tr"] = on
	var path: String = App.SAVE_PATH
	if not FileAccess.file_exists(path): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (d is Dictionary): return
	if not (d.get("state") is Dictionary): d["state"] = {}
	if d.state.get("tr") == on: return
	d.state["tr"] = on
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d, "\t"))
func notify_phone(on := true) -> void: phone_dot.visible = on

func open_phone(first := "home") -> void:
	phone_dot.visible = false; _hide_chips()
	if player and "frozen" in player: player.frozen = true
	if player and "stick" in player: player.stick = Vector2.ZERO
	phone_opened.emit()
	var pk := _pocket()
	if pk and pk.has_method("take_out"): await pk.take_out(player, _cam())     # character takes the phone out, camera zooms in
	var r := phone_btn.get_global_rect()
	if pk and pk.has_method("screen_rect"):          # zoom the UI out of the phone in the hand
		var pr: Rect2 = pk.screen_rect()
		if pr.size.x > 1.0: r = pr
	await phone.open(r, first)
	caption("I am looking at my phone.")

func _cam() -> Camera3D: return camera if camera else get_viewport().get_camera_3d()

## optional pocket-phone hook (black bot's ui/pocket_phone.gd). Absent -> instant open/close.
func _pocket() -> Object:
	if pocket == null and ResourceLoader.exists(POCKET_PHONE):
		var sc: Script = load(POCKET_PHONE)
		if sc and sc.can_instantiate():
			pocket = sc.new()
			if pocket is Node: add_child(pocket)
	return pocket

func _on_phone_closed() -> void:
	var pk := _pocket()
	if pk and pk.has_method("put_away"): await pk.put_away(player, _cam())
	if player and "frozen" in player: player.frozen = false

func set_paused(on: bool) -> void:
	if on and preload("res://scripts/phone.gd").active_locked: return   # house.20
	pause_menu.visible = on; get_tree().paused = on; pause_toggled.emit(on)

## called by the player when the nearest interactable changes
func set_near(i) -> void:
	near = i; stick.queue_redraw()
	if i == null: _hide_chips()
	elif chips.get_child_count() > 0: show_chips()

func on_action() -> void:
	if near == null or phone.visible: return
	UI.click()
	if chips.get_child_count() > 0: _hide_chips()
	else: show_chips()

func show_chips() -> void:
	_hide_chips()
	if near == null: return
	# v32-polish: no title panel above the buttons any more ("Take Apples" showed two boxes); the button text names the action
	var target = near
	for v in target.verb_list():
		var b := Button.new(); b.text = v[0]; b.custom_minimum_size = Vector2(230, 58); b.add_theme_font_size_override("font_size", 22)
		var cb: Callable = v[1]
		b.pressed.connect(func():
			UI.click(); _hide_chips()
			if player and player.has_method("perform"): player.perform(target, cb)
			else: cb.call())
		chips.add_child(b)
	_layout.call_deferred()

func _hide_chips() -> void:
	for c in chips.get_children(): chips.remove_child(c); c.queue_free()

func caption(en: String, secs := 4.5) -> void:
	cap_text = en; cap_panel.visible = en != ""
	if cap_panel.visible: StoryUI.claim(cap_panel)   # v32-polish: also when the box was already up (no visibility_changed) -> any other box hides
	cap_serial += 1; var my := cap_serial
	if is_inside_tree(): get_tree().create_timer(secs, false).timeout.connect( func(): if my == cap_serial: cap_panel.visible = false)
	_refresh()
	if en == "": return
	if voice_func.is_valid(): voice_func.call(en)
	elif get_node_or_null("/root/Voice"): get_node("/root/Voice").say(en)

func tr_of(en: String) -> String: return String(tr_func.call(en)) if tr_func.is_valid() else ""

func _refresh() -> void:
	if cap_en == null: return
	cap_en.text = cap_text; cap_tr.text = tr_of(cap_text); cap_tr.visible = show_tr and cap_tr.text != ""
	tr_btn.add_theme_stylebox_override("normal", UI.sb(Color(0.31, 0.42, 0.93) if show_tr else Color(1, 1, 1, 0.94), 18, 10))
	tr_btn.add_theme_color_override("font_color", Color(1, 1, 1) if show_tr else Color(0.13, 0.16, 0.24))
	cap_en.custom_minimum_size.x = clampf(UI.font_b.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 4, 200, 560)
	cap_tr.custom_minimum_size.x = cap_en.custom_minimum_size.x
	mission_lbl.text = mission; mission_tr.text = mission_tr_text if mission_tr_text != "" else tr_of(mission)
	mission_tr.visible = show_tr and mission_tr.text != ""; mission_panel.visible = false   # v30.5: Objectives only
	place_lbl.text = place; place_tr.text = place_tr_text; place_tr.visible = show_tr and place_tr_text != ""; place_panel.visible = false   # v30.5: Objectives only
	_layout.call_deferred()

## manual placement (3dv2 _layout): caption bottom-centre, chips above the action button, place pill under the mission bar
func _layout() -> void:
	var vs := root.size
	cap_panel.size = cap_panel.get_combined_minimum_size()
	cap_panel.position = Vector2(roundf(maxf(12.0, (vs.x - cap_panel.size.x) / 2)), vs.y - 22 - cap_panel.size.y)
	mission_panel.size = mission_panel.get_combined_minimum_size(); place_panel.size = place_panel.get_combined_minimum_size()
	place_panel.position = Vector2(20, 18 + (mission_panel.size.y + 8 if mission_panel.visible else 0.0))
	chips.size = chips.get_combined_minimum_size()
	var ac: Vector2 = stick.act_center()
	chips.position = Vector2(ac.x - stick.ACT_R - 24 - chips.size.x, clampf(ac.y + stick.ACT_R - chips.size.y, 96, vs.y - chips.size.y - 8))

func _build_pause() -> void:
	pause_menu = Control.new(); pause_menu.name = "PauseMenu"; pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.visible = false
	root.add_child(pause_menu)
	var dim := ColorRect.new(); dim.color = Color(0.07, 0.09, 0.14, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.add_child(dim)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); pause_menu.add_child(cc)
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.96), 30, 26)); cc.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); card.add_child(v)
	var t := UI.label("Paused", 34, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var resume := Button.new(); resume.text = "Continue"; resume.custom_minimum_size = Vector2(300, 64); UI.primary_button(resume)
	resume.pressed.connect(func(): UI.click(); set_paused(false)); v.add_child(resume)
	var trb := Button.new(); trb.custom_minimum_size = Vector2(300, 58); UI.soft_button(trb); v.add_child(trb)
	var upd := func(): trb.text = "Turkish help: %s" % ("on" if show_tr else "off")
	upd.call(); trb.pressed.connect(func(): UI.click(); set_tr(not show_tr); upd.call())
	var vb := Button.new(); vb.custom_minimum_size = Vector2(300, 58); UI.soft_button(vb); v.add_child(vb)
	var vo := get_node_or_null("/root/Voice")
	var upd2 := func(): vb.text = "Voice: %s" % ("on" if vo == null or vo.enabled else "off")
	upd2.call(); vb.pressed.connect(func(): UI.click(); if vo: vo.enabled = not vo.enabled; upd2.call())

## stick (bottom-left), hand action button + camera ring (bottom-right): 3dv2 touch.gd geometry and colours
class TouchControls extends Control:
	var hud
	var stick_idx := -1; var cam_idx := -1; var act_idx := -1
	var knob := Vector2.ZERO; var cknob := Vector2.ZERO
	const BASE_R := 92.0
	const KNOB_R := 42.0
	const ACT_R := 64.0
	const CAM_R := 80.0
	var hand: Texture2D = load("res://ui/hand.png")
	func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func stick_center() -> Vector2: return Vector2(170, size.y - 160)
	func act_center() -> Vector2: return Vector2(size.x - 170, size.y - 360)
	func cam_center() -> Vector2: return Vector2(size.x - 170, size.y - 150)
	func _input(e: InputEvent) -> void:
		if not is_visible_in_tree() or hud.phone.visible or get_tree().paused: return
		if e is InputEventScreenTouch:
			var p: Vector2 = make_input_local(e).position
			if e.pressed:
				if stick_idx == -1 and p.x < size.x * 0.4 and p.y > size.y * 0.45:
					stick_idx = e.index; _move(p); get_viewport().set_input_as_handled()
				elif act_idx == -1 and p.distance_to(act_center()) < ACT_R + 16:
					act_idx = e.index; queue_redraw(); get_viewport().set_input_as_handled()
				elif cam_idx == -1 and p.x > size.x * 0.65 and p.y > size.y * 0.6:
					cam_idx = e.index; _cmove(p); get_viewport().set_input_as_handled()
			else:
				if e.index == stick_idx: stick_idx = -1; knob = Vector2.ZERO; _send(); queue_redraw()
				if e.index == cam_idx: cam_idx = -1; cknob = Vector2.ZERO; _send(); queue_redraw()
				if e.index == act_idx: act_idx = -1; queue_redraw(); hud.on_action()
		elif e is InputEventScreenDrag and e.index == stick_idx:
			_move(make_input_local(e).position); get_viewport().set_input_as_handled()
		elif e is InputEventScreenDrag and e.index == cam_idx:
			_cmove(make_input_local(e).position); get_viewport().set_input_as_handled()
	func _move(p: Vector2) -> void: knob = (p - stick_center()).limit_length(BASE_R); _send(); queue_redraw()
	func _cmove(p: Vector2) -> void: cknob = (p - cam_center()).limit_length(CAM_R); _send(); queue_redraw()
	func _send() -> void:
		var pl = hud.player
		if pl == null: return
		if "stick" in pl: pl.stick = knob / BASE_R
		if "cam_stick" in pl: pl.cam_stick = cknob / CAM_R
	func _draw() -> void:
		var c := stick_center()
		draw_circle(c, BASE_R, Color(1, 1, 1, 0.16))
		draw_arc(c, BASE_R, 0, TAU, 64, Color(1, 1, 1, 0.55), 3.0, true)
		draw_circle(c + knob, KNOB_R, Color(1, 1, 1, 0.85))
		draw_circle(c + knob, KNOB_R - 14, Color(0.31, 0.42, 0.93, 0.35))
		var cc := cam_center()
		draw_circle(cc, CAM_R, Color(1, 1, 1, 0.12))
		draw_arc(cc, CAM_R, 0, TAU, 64, Color(1, 1, 1, 0.5), 3.0, true)
		for i in 4:
			var ang := i * PI / 2; var dv := Vector2(cos(ang), sin(ang))
			var tip := cc + dv * (CAM_R - 12)
			draw_colored_polygon(PackedVector2Array([tip, tip - dv.rotated(0.5) * 14, tip - dv.rotated(-0.5) * 14]), Color(1, 1, 1, 0.6))
		draw_circle(cc + cknob, 34, Color(1, 1, 1, 0.8))
		draw_arc(cc + cknob, 16, 0.4, TAU - 0.4, 24, Color(0.31, 0.42, 0.93, 0.7), 4.0, true)
		var a := act_center(); var near: bool = hud != null and hud.near != null
		draw_circle(a, ACT_R, Color(0.31, 0.42, 0.93, 0.92 if act_idx != -1 else 0.82) if near else Color(1, 1, 1, 0.14))
		draw_arc(a, ACT_R, 0, TAU, 64, Color(1, 1, 1, 0.7 if near else 0.35), 3.0, true)
		if near: draw_texture_rect(hand, Rect2(a - Vector2(39, 39), Vector2(78, 78)), false, Color(1, 1, 1))
