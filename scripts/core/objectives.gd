## v304: shared top-left story objectives list (persistent across rooms).
## English by default; TR when the scene / GameHUD TR toggle is on (live).
## Readable on phone; sits under Life's clock strip and hides while the phone UI is open.
## API: Objectives.set_list(items), complete(id), clear(), set_tr(on)
extends CanvasLayer

signal changed

## each item: {"id": String, "en": String, "tr": String, "done": bool}
var items: Array = []
var show_tr := false
var _panel: PanelContainer
var _box: VBoxContainer
var _cue := false
var _t := 0.0

const TR_FALLBACK := {
	"Turn off the alarm clock.": "Alarmı kapat.",
	"Look in the mirror.": "Aynaya bak.",
	"Spell your name.": "Adını hecele.",
	"Choose how you look.": "Görünümünü seç.",
	"Explore your bedroom.": "Yatak odanı keşfet.",
	"Pick up your phone.": "Telefonunu al.",
	"Choose a job on your phone.": "Telefonunda bir meslek seç.",
	"Learn he, she and it.": "He, she ve it öğren.",
	"Add your family.": "Aileni ekle.",
	"Open the Calendar.": "Takvimi aç.",
	"Go to the bathroom.": "Banyoya git.",
	"Go to the mirror.": "Aynaya git.",
	"Wash your face.": "Yüzünü yıka.",
	"Brush your teeth.": "Dişlerini fırçala.",
	"Go to the living room.": "Oturma odasına git.",
	"Have breakfast with your family.": "Ailenle kahvaltı yap.",
	"Have breakfast.": "Kahvaltı yap.",
	"Go outside to the car.": "Arabaya gitmek için dışarı çık.",
	"Go to the car.": "Arabaya git.",
	"Where do you want to go?": "Nereye gitmek istiyorsun?",
	"Walk to the street.": "Sokağa yürü.",
}

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new(); _panel.name = "Objectives"
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.10, 0.16, 0.72); sb.set_corner_radius_all(16); sb.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(20, 18); _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_box = VBoxContainer.new(); _box.add_theme_constant_override("separation", 4); _panel.add_child(_box)
	_panel.visible = false

func _process(dt: float) -> void:
	_t += dt
	_trg_t -= dt
	if _trg_t <= 0.0:
		_trg_t = 0.4; tr_guard()
	_ovl_t -= dt
	if _ovl_t <= 0.0:
		_ovl_t = 0.1; resolve_overlaps()
	# hide over open phone UI; stay clear of Life clock (y≈128) and top-right phone button
	var phone_open := _phone_open()
	_panel.visible = not items.is_empty() and not phone_open
	if _cue and _panel.visible:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var sb := _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb.bg_color = Color(0.31, 0.42, 0.93, 0.75 + 0.2 * pulse)
			sb.border_color = Color(1, 1, 1, 0.5 + 0.4 * pulse); sb.set_border_width_all(3)
	# live TR from current scene / GameHUD
	var on := _tr_on()
	if on != show_tr: set_tr(on)

## v30.5 SYSTEM-WIDE no-overlap rule for on-screen text (every scene / day / lesson / test / phone / hospital / outdoor / menu).
## Shared layer: any visible Control named in OVL_NAMES, or in group "no_overlap" with meta "ovl_prio" (higher = stays put),
## is laid out so that lower-priority boxes slide vertically clear of higher ones. New UI inherits it by name or group:
##   ctrl.add_to_group("no_overlap"); ctrl.set_meta("ovl_prio", 5)
const OVL_NAMES := {"Caption": 10, "StoryCaption": 10, "Objectives": 8, "LifeClock": 6, "DayTitle": 4, "Toast": 3}
var _ovl_t := 0.0
static func ovl_register(c: Control, prio: int) -> void:
	c.add_to_group("no_overlap"); c.set_meta("ovl_prio", prio)
func _ovl_collect(nd: Node, out: Array) -> void:
	if nd is CanvasItem and not (nd as CanvasItem).visible: return
	if nd is Control:
		var pr := -1
		if nd.is_in_group("no_overlap"): pr = int(nd.get_meta("ovl_prio", 1))
		elif OVL_NAMES.has(String(nd.name)): pr = OVL_NAMES[String(nd.name)]
		if pr >= 0 and (nd as Control).size.x > 4 and not (nd.get_parent() is Container):
			out.append([pr, nd]); return   # a registered box counts as one rect (children are its content)
	for c in nd.get_children(): _ovl_collect(c, out)
func resolve_overlaps() -> int:
	var tree := get_tree()
	if tree == null: return 0
	var all: Array = []; _ovl_collect(tree.root, all)
	all.sort_custom(func(a, b): return a[0] > b[0])
	var placed: Array = []; var moved := 0
	var vh := get_viewport().get_visible_rect().size.y
	for e in all:
		var c: Control = e[1]
		if not c.has_meta("ovl_base"): c.set_meta("ovl_base", c.position.y)
		var base: float = c.get_meta("ovl_base")
		if absf(c.position.y - float(c.get_meta("ovl_last", base))) > 0.5: base = c.position.y; c.set_meta("ovl_base", base)   # the owner moved it
		var y := base
		for _i in 6:
			var r := Rect2(c.global_position.x, c.global_position.y - c.position.y + y, c.size.x, c.size.y).grow(-1)
			var hit: Rect2 = Rect2()
			for q in placed:
				if r.intersects(q): hit = q; break
			if hit.size == Vector2.ZERO: break
			var up := r.get_center().y < hit.get_center().y
			y = (y - (r.end.y - hit.position.y) - 8.0) if up else (y + (hit.end.y - r.position.y) + 8.0)
			if c.global_position.y - c.position.y + y < 0.0 or c.global_position.y - c.position.y + y + c.size.y > vh: y = (y + (hit.end.y - r.position.y) + 8.0) if up else y
		if absf(y - c.position.y) > 0.5: c.position.y = y; moved += 1
		c.set_meta("ovl_last", c.position.y)
		placed.append(Rect2(c.global_position, c.size))
	return moved

## v30.5 TR guard: with the single TR flag OFF, no Turkish may be visible in any in-game UI.
## Lines with Turkish letters (or exact Turkish values of extra_lines.json) are stripped; empty labels hide.
var _trg_t := 0.0
var _tr_vals := {}
static func has_tr(t: String) -> bool:
	for c in "çğıöşüÇĞİÖŞÜ":
		if t.contains(c): return true
	return false
func _is_tr_line(l: String) -> bool:
	var x := l.strip_edges()
	return x != "" and (has_tr(x) or _tr_vals.has(x))
func tr_guard() -> int:
	if App.tr_on(): return 0
	var sc := get_tree().current_scene
	if sc == null or String(sc.scene_file_path).contains("menu"): return 0   # menu language is separate
	if _tr_vals.is_empty():
		var d = App.load_json("res://data/extra_lines.json"); _tr_vals["_"] = 1
		if d is Dictionary:
			for k in d:
				var v := String(d[k]).strip_edges()
				if v != "" and v != String(k).strip_edges() and not v.contains(" ") and v.length() > 2: _tr_vals[v] = 1   # single-word TR values (Pil, Gün, Banyo)
	var n := [0]
	_trg_walk(get_tree().root, n)
	return n[0]
func _trg_walk(nd: Node, n: Array) -> void:
	if nd is CanvasItem and not nd.visible: return
	if nd is Label or nd is Button or nd is Label3D:
		var t: String = nd.text
		if t != "" and (has_tr(t) or _is_tr_line(t)):
			var rx := RegEx.create_from_string("\\s*\\([^)]*[çğıöşüÇĞİÖŞÜ][^)]*\\)")
			t = rx.sub(t, "", true)
			var keep := PackedStringArray()
			for l in t.split("\n"):
				var parts := PackedStringArray()
				for seg in l.split("  ·  "):
					if not _is_tr_line(seg): parts.append(seg)
				var jl := "  ·  ".join(parts)
				if not _is_tr_line(jl): keep.append(jl)
			var nt := "\n".join(keep)
			# "Gün 2" / "Şarj %90" style tokens inside one line
			for w in ["Gün", "Şarj", "Pil", "şarj oluyor"]:
				if not App.tr_on(): nt = nt.replace(w + " ", ("Day " if w == "Gün" else "Battery ") if w != "şarj oluyor" else "").replace("(" + w + ")", "")
			nt = nt.replace("Pil", "Battery") if nt.begins_with("Pil") else nt
			if nt.strip_edges() == "": nd.visible = false
			else: nd.text = nt
			n[0] += 1
	for c in nd.get_children(): _trg_walk(c, n)
	# hide over open phone UI; stay clear of Life clock (y≈128) and top-right phone button
func _phone_open() -> bool:
	for ph0 in get_tree().get_nodes_in_group("game_phone"):
		if ph0 is CanvasItem and (ph0 as CanvasItem).is_visible_in_tree(): return true
	var sc := get_tree().current_scene
	if sc == null: return false
	var ph = sc.get("phone")
	if ph is CanvasItem and ph.visible: return true
	var hud = sc.get("hud")
	if hud and hud.get("phone") is CanvasItem and hud.phone.visible: return true
	return false

func _tr_on() -> bool:
	return App.tr_on()   # v30.5: single persisted TR flag
	var sc := get_tree().current_scene
	if sc and sc.get("S") is Dictionary and sc.S.has("tr"): return bool(sc.S.tr)
	var hud = sc.get("hud") if sc else null
	if hud and "show_tr" in hud: return bool(hud.show_tr)
	return show_tr

## items: Array of String (en) or Dictionary {id?, en, tr?}


func _charge_item() -> Dictionary:
	for it in items:
		if String(it.get("id", "")) == "charge": return it
	return {}
func _keep_charge() -> bool:
	return not Life.charging and Life.battery < 30.0

func set_list(list: Array, keep_charge: = true) -> void :
	var ch: = _charge_item() if keep_charge and _keep_charge() else {}
	items = []
	for it in list:
		if it is String:
			items.append({"id": it, "en": it, "tr": TR_FALLBACK.get(it, ""), "done": false})
		elif it is Dictionary:
			var en := String(it.get("en", it.get("id", "")))
			var id := String(it.get("id", en))
			items.append({"id": id, "en": en, "tr": String(it.get("tr", TR_FALLBACK.get(en, ""))), "done": bool(it.get("done", false))})
	if not ch.is_empty():
		var has_ch: = false
		for it2 in items:
			if String(it2.id) == "charge": has_ch = true
		if not has_ch: items.append(ch)
	_cue = true; _rebuild(); changed.emit()

func complete(id: String) -> void:
	var left: Array = []
	for it in items:
		if String(it.id) == id or String(it.en) == id:
			it.done = true
		else:
			left.append(it)
	# remove completed from the persistent list (tick = drop)
	items = left
	_rebuild(); changed.emit()

## v30.5: append one entry (no-op when already listed)
func add(id: String, en: String, tr := "") -> void:
	for it in items:
		if String(it.id) == id: return
	items.append({"id": id, "en": en, "tr": tr if tr != "" else String(TR_FALLBACK.get(en, "")), "done": false})
	_cue = true; _rebuild(); changed.emit()

func has(id: String) -> bool:
	for it in items:
		if String(it.id) == id: return true
	return false

func clear(keep_charge: = true) -> void :
	var ch: = _charge_item() if keep_charge and _keep_charge() else {}
	items = [] if ch.is_empty() else [ch];_cue = false;_rebuild();changed.emit()

func set_tr(on: bool) -> void:
	show_tr = on; _rebuild()

func _rebuild() -> void:
	for c in _box.get_children(): c.queue_free()
	if items.is_empty():
		_panel.visible = false; return
	for it in items:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
		var mark := Label.new(); mark.text = "✓" if it.done else "•"
		mark.add_theme_font_size_override("font_size", 20)
		mark.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55) if it.done else Color(1, 1, 1))
		row.add_child(mark)
		var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0); row.add_child(col)
		var en := Label.new(); en.text = String(it.en); en.add_theme_font_size_override("font_size", 20)
		en.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78) if it.done else Color(1, 1, 1))
		if UI: en.add_theme_font_override("font", UI.font_b)
		col.add_child(en)
		var tr := String(it.tr)
		if tr != "":
			var tl := Label.new(); tl.text = tr; tl.add_theme_font_size_override("font_size", 16)
			tl.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0)); tl.visible = show_tr; col.add_child(tl)
		_box.add_child(row)
	_panel.visible = true
