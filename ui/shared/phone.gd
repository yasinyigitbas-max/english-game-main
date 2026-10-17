## GamePhone - shared in-game smartphone (res://ui/shared/phone.tscn).
## Visual copy of english_game_3dv2/scripts/phone.gd: black rounded frame, lavender screen, status bar,
## big clock + greeting on Home, 122 px app icons with bold 22 px names, Back / Home / Close nav pills.
## Built-in apps: Clock, Wallet, Bus, Map, Me.  Scenes add their own with register_app() (see SHARED_UI.md).
## Optional autoloads used when present: UI (fonts), WorldState (time), Economy (wallet), Transit (bus times).
class_name GamePhone
extends Control

signal closed
signal page_shown(id: String)

const INK := Color(0.12, 0.15, 0.25)
const MUTED := Color(0.42, 0.47, 0.58)
const BLUE := Color(0.31, 0.42, 0.93)
const TR_C := Color(0.36, 0.45, 0.7)
const GREEN := Color(0.16, 0.55, 0.36)
const RED := Color(0.86, 0.3, 0.32)
const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

var player_name := "Yasin"
var subtitle := ""                      # under "Hi, name!" (default: wallet balance)
var map_provider: Callable              # func() -> {"cells": [[x,y,name]...], "player": Vector2 (world xz), "block": 40.0}
var frame: PanelContainer
var screen: Control
var body: MarginContainer
var status_time: Label
var page := ""
var history: Array = []
var _apps: Array = []                   # [{id, title, icon, build: Callable(VBoxContainer)}]
var _font_b: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP; name = "Phone"; visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ui := get_node_or_null("/root/UI")
	if ui and "font_b" in ui: _font_b = ui.font_b
	var dim := ColorRect.new(); dim.color = Color(0.03, 0.04, 0.07, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(dim)
	frame = PanelContainer.new(); frame.name = "PhoneFrame"
	var fsb := StyleBoxFlat.new(); fsb.bg_color = Color(0.07, 0.08, 0.1); fsb.set_corner_radius_all(46)
	fsb.border_color = Color(0.32, 0.34, 0.4); fsb.set_border_width_all(3)
	for k in ["left", "right", "top", "bottom"]: fsb.set("content_margin_" + k, 12)
	frame.add_theme_stylebox_override("panel", fsb); add_child(frame)
	screen = Control.new(); screen.name = "Screen"; screen.clip_contents = true; frame.add_child(screen)
	var wp := Panel.new(); wp.set_anchors_preset(Control.PRESET_FULL_RECT); wp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wsb := StyleBoxFlat.new(); wsb.bg_color = Color(0.91, 0.93, 1.0); wsb.set_corner_radius_all(36); wsb.anti_aliasing = true
	wp.add_theme_stylebox_override("panel", wsb); screen.add_child(wp)
	var col := VBoxContainer.new(); col.set_anchors_preset(Control.PRESET_FULL_RECT); col.add_theme_constant_override("separation", 0); screen.add_child(col)
	var sbm := MarginContainer.new(); sbm.add_theme_constant_override("margin_left", 34); sbm.add_theme_constant_override("margin_right", 34)
	sbm.add_theme_constant_override("margin_top", 6); col.add_child(sbm)
	var sbh := HBoxContainer.new(); sbm.add_child(sbh)
	status_time = l(now_text(), 18, true); sbh.add_child(status_time)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sbh.add_child(sp)
	sbh.add_child(l("4G   Wi-Fi   87%", 16, true))
	body = MarginContainer.new(); body.name = "Body"; body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["left", "right"]: body.add_theme_constant_override("margin_" + k, 30)
	body.add_theme_constant_override("margin_top", 4); body.add_theme_constant_override("margin_bottom", 2); col.add_child(body)
	var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER; nav.add_theme_constant_override("separation", 26)
	nav.custom_minimum_size.y = 58; col.add_child(nav)
	nav.add_child(_navbtn("Back", "NavBack", back))
	nav.add_child(_navbtn("Home", "NavHome", func(): _click(); show_page("home")))
	nav.add_child(_navbtn("Close", "NavClose", close))
	resized.connect(_fit)
	register_app("clock", "Clock", "res://ui/phone/app_calendar.png", _clock)
	register_app("wallet", "Wallet", "res://ui/phone/sub_money.png", _wallet)
	register_app("bus", "Bus", "res://ui/phone/j_bus_transport.png", _bus)
	register_app("map", "Map", "res://ui/phone/sub_road.png", _map)
	register_app("me", "Me", "res://ui/phone/app_me.png", _me)

## add (or replace) an app on the home screen. build(v: VBoxContainer) fills the page.
func register_app(id: String, title: String, icon: String, build: Callable, at := -1) -> void:
	for a in _apps: if a.id == id: a.title = title; a.icon = icon; a.build = build; return
	var e := {"id": id, "title": title, "icon": icon, "build": build}
	if at < 0 or at >= _apps.size(): _apps.append(e)
	else: _apps.insert(at, e)

func remove_app(id: String) -> void: _apps = _apps.filter(func(a): return a.id != id)
func app_ids() -> Array: return _apps.map(func(a): return a.id)

func _process(_dt: float) -> void:
	if visible and status_time: status_time.text = now_text()

func now_text() -> String:
	var ws := get_node_or_null("/root/WorldState")
	if ws: return ws.clock_text()
	var t := Time.get_time_dict_from_system(); return "%02d:%02d" % [t.hour, t.minute]

func date_text() -> String:
	var ws := get_node_or_null("/root/WorldState")
	var d: int = ws.day if ws else 1
	return "%s, day %d" % [DAYS[(d - 1) % 7], d]

func money_text() -> String:
	var ec := get_node_or_null("/root/Economy")
	return ec.format(ec.balance()) if ec else ""

func _fit() -> void:
	var ps: Vector2 = (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	if size != ps: size = ps
	var avail := Vector2(size.x - 40, size.y - 128)
	var w := minf(avail.x, avail.y * 2.05); var h := minf(avail.y, w / 1.6)
	frame.size = Vector2(w, h); frame.position = Vector2((size.x - w) / 2.0, 14)
	frame.pivot_offset = frame.size / 2.0

func open(from := Rect2(), first := "home") -> void:
	_fit(); visible = true; history.clear(); page = ""
	show_page(first, false)
	if from.size.x > 1.0:
		var full := Rect2(frame.position, frame.size)
		var s := clampf(from.size.x / full.size.x, 0.05, 1.0)
		frame.scale = Vector2(s, s); frame.position = from.get_center() - full.size / 2.0
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(frame, "scale", Vector2.ONE, 0.55); tw.tween_property(frame, "position", full.position, 0.55)
		tw.tween_property(self, "modulate:a", 1.0, 0.25)
		await tw.finished

func close() -> void:
	_click()
	var tw := create_tween(); tw.tween_property(self, "modulate:a", 0.0, 0.22); await tw.finished
	visible = false; modulate.a = 1.0; closed.emit()

func back() -> void:
	_click()
	if history.is_empty(): close(); return
	show_page(history.pop_back(), false)

func show_page(p: String, push := true) -> void:
	if push and page != "" and page != p: history.append(page)
	if p == "home": history.clear()
	page = p
	var v := clear()
	if p == "home": _home(v)
	else:
		for a in _apps: if a.id == p: (a.build as Callable).call(v)
	page_shown.emit(p)

# ------------------------------------------------------------ helpers (public: apps from other scenes use them)
func l(t: String, fs: int, bold := false, c := INK) -> Label:
	var lb := Label.new(); lb.text = t; lb.add_theme_font_size_override("font_size", fs); lb.add_theme_color_override("font_color", c)
	if bold and _font_b: lb.add_theme_font_override("font", _font_b)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lb

func sb(c: Color, r := 22, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad; s.content_margin_bottom = pad
	return s

func style(b: Button, c: Color, fc: Color, r := 18) -> void:
	b.add_theme_stylebox_override("normal", sb(c, r, 8)); b.add_theme_stylebox_override("hover", sb(c.lightened(0.06), r, 8))
	b.add_theme_stylebox_override("pressed", sb(c.darkened(0.12), r, 8)); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, fc)

func btn(t: String, cb: Callable, sz: Vector2, primary := false, fs := 22) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = sz; b.add_theme_font_size_override("font_size", fs)
	if _font_b: b.add_theme_font_override("font", _font_b)
	style(b, BLUE if primary else Color(1, 1, 1, 0.95), Color.WHITE if primary else INK)
	b.pressed.connect(func(): _click(); cb.call()); return b

func card() -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(Color(1, 1, 1, 0.92), 22, 16)); return p

func header(v: Control, en: String, sub := "", tr := "") -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); v.add_child(h)
	h.add_child(l(en, 32, true))
	if sub != "": var s := l(sub, 19, false, MUTED); s.size_flags_vertical = Control.SIZE_SHRINK_END; h.add_child(s)
	if tr != "": var t := l(tr, 15, false, TR_C); t.size_flags_vertical = Control.SIZE_SHRINK_END; h.add_child(t)

func row(v: Control, left: String, right: String, rc := INK) -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(Color(1, 1, 1, 0.92), 18, 10)); v.add_child(p)
	var h := HBoxContainer.new(); p.add_child(h)
	h.add_child(l(left, 22, true)); var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	h.add_child(l(right, 22, true, rc))

func clear() -> VBoxContainer:
	for c in body.get_children(): body.remove_child(c); c.queue_free()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); body.add_child(v); return v

func icon(path: String, s: float) -> TextureRect:
	var t := TextureRect.new(); t.texture = load(path); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; t.custom_minimum_size = Vector2(s, s); t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _navbtn(t: String, nm: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = t; b.name = nm; b.custom_minimum_size = Vector2(150, 44); b.add_theme_font_size_override("font_size", 19)
	if _font_b: b.add_theme_font_override("font", _font_b)
	style(b, Color(0.12, 0.15, 0.25, 0.08), INK, 22)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; b.pressed.connect(cb); return b

func _click() -> void:
	var ui := get_node_or_null("/root/UI")
	if ui and ui.has_method("click"): ui.click()

# ------------------------------------------------------------ home (same layout as 3dv2 _home)
func _home(v: VBoxContainer) -> void:
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new(); v.add_child(top)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", -6); top.add_child(tv)
	tv.add_child(l(now_text(), 60, true)); tv.add_child(l(date_text(), 20, false, MUTED))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	var hi := VBoxContainer.new(); hi.alignment = BoxContainer.ALIGNMENT_CENTER; top.add_child(hi)
	var g := l("Hi, %s!" % player_name if player_name != "" else "Hi!", 30, true); g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hi.add_child(g)
	var st := l(subtitle if subtitle != "" else ("My money: %s" % money_text() if money_text() != "" else ""), 19, false, MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hi.add_child(st)
	var gap := Control.new(); gap.custom_minimum_size.y = 14; v.add_child(gap)
	var r := HBoxContainer.new(); r.alignment = BoxContainer.ALIGNMENT_CENTER; r.add_theme_constant_override("separation", 26 if _apps.size() <= 5 else 8); v.add_child(r)
	var isz := 122.0 if _apps.size() <= 5 else 96.0
	for a in _apps:
		var b := Button.new(); b.name = "App_" + a.id; b.custom_minimum_size = Vector2(isz + 24, isz + 58)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); b.add_theme_stylebox_override("hover", sb(Color(1, 1, 1, 0.35), 26))
		b.add_theme_stylebox_override("pressed", sb(Color(1, 1, 1, 0.55), 26)); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var bv := VBoxContainer.new(); bv.set_anchors_preset(Control.PRESET_FULL_RECT); bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 0); bv.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(bv)
		var ic := icon(a.icon, isz); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; bv.add_child(ic)
		var lb := l(a.title, 22, true); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(lb)
		var id: String = a.id
		b.pressed.connect(func(): _click(); show_page(id)); r.add_child(b)

# ------------------------------------------------------------ built-in apps
func _clock(v: VBoxContainer) -> void:
	header(v, "Clock", "What time is it?", "Saat kaç?")
	var c := card(); v.add_child(c); var cv := VBoxContainer.new(); c.add_child(cv)
	var t := l(now_text(), 72, true); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(t)
	var ws := get_node_or_null("/root/WorldState")
	var ph: String = ws.phase() if ws else ""
	var s := l("It is %s. It is the %s." % [now_text(), ph] if ph != "night" else "It is %s. It is night." % now_text(), 24, false, MUTED)
	if ph == "": s.text = "It is %s." % now_text()
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(s)
	var d := l(date_text(), 20, false, MUTED); d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; cv.add_child(d)

func _wallet(v: VBoxContainer) -> void:
	header(v, "Wallet", "My money", "Param")
	var c := card(); v.add_child(c); var cv := VBoxContainer.new(); c.add_child(cv)
	cv.add_child(l("I have", 20, false, MUTED)); cv.add_child(l(money_text(), 56, true, GREEN))
	var ec := get_node_or_null("/root/Economy")
	if ec == null: return
	var hist: Array = ec.history.slice(-4); hist.reverse()
	for e in hist:
		var amt: int = int(e.get("amount", 0))
		row(v, String(e.get("reason", "")).capitalize(), ("+" if amt > 0 else "-") + ec.format(absi(amt)), GREEN if amt > 0 else RED)
	if not ec.inventory.is_empty():
		var parts := []
		for k in ec.inventory: parts.append("%d %s" % [ec.inventory[k], k])
		row(v, "In my bag", ", ".join(parts))

func _bus(v: VBoxContainer) -> void:
	header(v, "Bus", "Timetable", "Otobüs saatleri")
	var tr_ := get_node_or_null("/root/Transit")
	if tr_ == null: v.add_child(l("No bus information.", 22, false, MUTED)); return
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(sc)
	var lv := VBoxContainer.new(); lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lv.add_theme_constant_override("separation", 8); sc.add_child(lv)
	for sid in tr_.stops:
		var times: Array = tr_.next_departures(sid, 3).map(func(d): return d.text)
		row(lv, String(tr_.stops[sid].get("name", sid)), "   ".join(times) if not times.is_empty() else "no bus", BLUE)
	var fare := 0
	for rid in tr_.routes: fare = int(tr_.routes[rid].get("fare", 0))
	if fare > 0 and get_node_or_null("/root/Economy"): lv.add_child(l("A ticket costs %s." % get_node("/root/Economy").format(fare), 20, false, MUTED))

func _map(v: VBoxContainer) -> void:
	header(v, "Map", "Where am I?", "Neredeyim?")
	var info: Dictionary = map_provider.call() if map_provider.is_valid() else {}
	var m := MapView.new(); m.info = info; m.phone = self; m.size_flags_vertical = Control.SIZE_EXPAND_FILL; m.custom_minimum_size.y = 200; v.add_child(m)

func _me(v: VBoxContainer) -> void:
	header(v, "Me", "About me", "Ben")
	var c := card(); v.add_child(c); var cv := VBoxContainer.new(); c.add_child(cv)
	cv.add_child(l("My name is %s." % player_name, 30, true))
	if money_text() != "": cv.add_child(l("I have %s." % money_text(), 22, false, MUTED))
	cv.add_child(l("It is %s." % now_text(), 22, false, MUTED))

## mini map: city cells as rounded tiles, roads between them, blue dot = player, bus stops as small squares
class MapView extends Control:
	var info := {}
	var phone: GamePhone
	func _draw() -> void:
		var cells: Array = info.get("cells", [])
		if cells.is_empty(): return
		var mn := Vector2(1e9, 1e9); var mx := Vector2(-1e9, -1e9)
		for c in cells: mn = mn.min(Vector2(c[0], c[1])); mx = mx.max(Vector2(c[0], c[1]))
		var n := mx - mn + Vector2.ONE
		var cs := minf(size.x / n.x, size.y / n.y); var off := (size - n * cs) / 2.0
		draw_rect(Rect2(off, n * cs), Color(0.62, 0.64, 0.70), true)
		for c in cells:
			var r := Rect2(off + (Vector2(c[0], c[1]) - mn) * cs + Vector2(cs, cs) * 0.08, Vector2(cs, cs) * 0.84)
			draw_style_box(phone.sb(Color(0.72, 0.84, 0.66) if String(c[2]).contains("park") else Color(0.97, 0.96, 0.93), 10), r)
		var bs: float = info.get("block", 40.0)
		var to_px := func(w: Vector2) -> Vector2: return off + (w / bs + Vector2(0.5, 0.5) - mn) * cs
		for s in info.get("stops", []): draw_rect(Rect2(to_px.call(s) - Vector2(6, 6), Vector2(12, 12)), Color(0.31, 0.42, 0.93))
		if info.has("player"):
			var p: Vector2 = to_px.call(info.player)
			draw_circle(p, 13, Color(1, 1, 1)); draw_circle(p, 9, Color(0.93, 0.26, 0.3))
