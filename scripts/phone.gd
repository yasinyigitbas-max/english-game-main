extends Control
## In-game smartphone = the game's hub (v9).
## Before a job: Jobs, Grammar, Words, Me.  After: Family, Calendar, Grammar, Words, Me (the Jobs app is gone).
## Jobs: 71 jobs in 13 sectors. Family: pronoun lesson + quick check, then up to 6 members (people or pets).
## Every list is a ScrollContainer, so a thumb swipe anywhere scrolls it (TouchScroll autoload).
signal closed
signal job_chosen(id: String)
signal lesson_finished
signal family_saved
signal calendar_opened

const INK := Color(0.12, 0.15, 0.25)
const MUTED := Color(0.42, 0.47, 0.58)
const BLUE := Color(0.31, 0.42, 0.93)
const TR_C := Color(0.36, 0.45, 0.7)
const GREEN := Color(0.16, 0.55, 0.36)
const RED := Color(0.86, 0.3, 0.32)
const HAIR_COLS := [["black", Color(0.08, 0.07, 0.06)], ["brown", Color(0.35, 0.2, 0.1)], ["blonde", Color(0.9, 0.75, 0.42)],
	["red", Color(0.66, 0.25, 0.12)], ["grey", Color(0.62, 0.62, 0.64)], ["white", Color(0.93, 0.93, 0.92)]]
const CLOTH_COLS := [["red", Color(0.84, 0.26, 0.26)], ["blue", Color(0.2, 0.38, 0.8)], ["green", Color(0.2, 0.6, 0.38)],
	["yellow", Color(0.95, 0.78, 0.25)], ["purple", Color(0.52, 0.3, 0.75)], ["black", Color(0.12, 0.12, 0.14)]]
const PET_COLS := [["brown", Color(0.6, 0.4, 0.22)], ["black", Color(0.2, 0.2, 0.22)], ["white", Color(0.97, 0.97, 0.96)],
	["grey", Color(0.6, 0.62, 0.66)], ["orange", Color(0.95, 0.55, 0.2)], ["golden", Color(0.9, 0.72, 0.35)]]
const SKIN_UI := [Color(0.98, 0.84, 0.72), Color(0.87, 0.67, 0.50), Color(0.68, 0.47, 0.32), Color(0.42, 0.28, 0.19)]
const MAX_FAMILY := 6

var main
var frame: PanelContainer
var screen: Control
var body: MarginContainer
var page := ""
var history: Array = []
var sel := {}
var g_level := "A1"
var w_level := "A1"
var w_cat := "nouns"
var jobs_data := {}
var fam_data := {}
## house.17: the lesson/quiz pages can run another lesson set (breakfast: present simple) in the same format
var les := {}
var quiz_score := 0
var quiz_wrong := false
signal lesson_steps_done          # a set with "quiz_after": false finished its last lesson step
signal quiz_done(score: int, total: int)
func _les() -> Dictionary:
	return les if not les.is_empty() else fam_data
func start_set(data: Dictionary, first: String) -> void:
	_active_quiz = []; _studying = false
	les = data; lesson_i = 0; quiz_i = 0; quiz_score = 0; quiz_wrong = false; show_page(first, false)
var lesson_i := 0
var quiz_i := 0
var edit := {}          # member being edited
var edit_index := -1    # -1 = new
var edit_step := "who"
var preview_vp: SubViewport
var preview_char: DemoCharacter
var preview_sentence: Label
var job_scroll: ScrollContainer
var sector_headers := {}

static func article(w: String) -> String:
	return "an" if w.length() > 0 and w[0].to_lower() in "aeiou" else "a"

func job(id: String) -> Dictionary:
	for j in jobs_data.get("jobs", []): if j.id == id: return j
	return {}

func role(id: String) -> Dictionary:
	for r in fam_data.get("roles", []): if r.id == id: return r
	return {}

func _ready() -> void:
	jobs_data = App.load_json("res://data/jobs.json"); fam_data = App.load_json("res://data/family.json")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP; name = "Phone"; add_to_group("game_phone")   # v31.1: Objectives hides while any phone is open
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
	var clk := _l("07:05", 18, true, INK); clk.name = "StatusClock"; sbh.add_child(clk)   # house.25: shared game clock
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sbh.add_child(sp)
	var bat := _l("4G   Wi-Fi   87%", 16, true, INK); bat.name = "StatusBattery"; sbh.add_child(bat)
	body = MarginContainer.new(); body.name = "Body"; body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k in ["left", "right"]: body.add_theme_constant_override("margin_" + k, 30)
	body.add_theme_constant_override("margin_top", 4); body.add_theme_constant_override("margin_bottom", 2); col.add_child(body)
	var nav := HBoxContainer.new(); nav.alignment = BoxContainer.ALIGNMENT_CENTER; nav.add_theme_constant_override("separation", 26)
	nav.custom_minimum_size.y = 58; col.add_child(nav)
	nav.add_child(_navbtn("Back", "NavBack", back))
	nav.add_child(_navbtn("Home", "NavHome", func(): Audio.click(); show_page("home")))
	nav.add_child(_navbtn("Close", "NavClose", close))
	var capgap := Control.new(); capgap.name = "CaptionGap"; capgap.custom_minimum_size.y = 74; capgap.mouse_filter = Control.MOUSE_FILTER_IGNORE; col.add_child(capgap)   # v29.1: full-size phone; the room caption sits here
	resized.connect(_fit)

func _fit() -> void:
	var ps: Vector2 = (get_parent() as Control).size if get_parent() is Control else get_viewport_rect().size
	if size != ps: size = ps
	# v29.1: the phone fills the whole landscape view (1600x720 at the 1600x720 design size)
	var w := size.x; var h := size.y
	frame.size = Vector2(w, h); frame.position = Vector2.ZERO
	frame.pivot_offset = frame.size / 2.0

func open(from: Rect2, first := "home") -> void:
	var by_player := not visible   # story scenes make the phone visible before open(); the player's own taps don't
	_fit(); visible = true; history.clear(); page = ""
	if by_player and Life.battery <= 0.0 and not active_locked:   # v31.1: dead battery -> no apps
		_dead_screen(); return
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

## house.20: a lesson / quiz in progress locks the phone (no close, no home, no back-out) until the score page / finish
static var active_locked := false
func is_locked() -> bool:
	return visible and page in ["lesson", "quiz", "score"]   # house.27: the score page releases only via Continue
func _lock_tick() -> void:
	if visible:
		var ck = find_child("StatusClock", true, false); var bt = find_child("StatusBattery", true, false)
		if ck: ck.text = WorldState.clock_text()
		var hck = find_child("HomeClock", true, false)
		if hck: hck.text = WorldState.clock_text()
		if bt: bt.text = "%s %d   4G   %d%%" % [App.tx("Day"), WorldState.day, int(Life.battery)]
	# house.24.2: safety - a locked lesson/quiz page that failed to build (empty body) is rebuilt, then released
	if is_locked() and page in ["lesson", "quiz"] and body and find_child("LessonNext" if page == "lesson" else "Options", true, false) == null:
		_empty_t += get_process_delta_time()
		if _empty_t > 2.0:
			_empty_t = 0.0; _rebuilds += 1
			if _rebuilds > 2: page = "score"; lesson_steps_done.emit(); quiz_done.emit(quiz_score, maxi(1, _les().get("quiz", []).size()))
			elif page == "lesson": _lesson()
			else: _quiz()
	else: _empty_t = 0.0
	var lk := is_locked()
	active_locked = lk
	for n in ["NavClose", "NavHome", "NavBack"]:
		var b = find_child(n, true, false)
		if b: b.visible = not lk; b.disabled = lk
	if get_tree().quit_on_go_back == lk: get_tree().quit_on_go_back = not lk
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and not is_locked(): back()
func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not is_locked(): back()

## v31.1: "Battery empty" screen; closes itself after a moment (hosts get the normal closed signal)
func _dead_screen() -> void:
	page = "dead"
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var a := _l("0%", 64, true, Color(0.85, 0.2, 0.2)); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(a)
	var e := _l("Battery empty. Charge your phone.", 30, true); e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; e.name = "DeadText"; v.add_child(e)
	var t := _trl(_l("Pil bitti. Telefonunu şarj et.", 18, false, TR_C)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	Audio.say("My phone is dead. I need to charge it.")
	if not Objectives.has("charge"): Objectives.add("charge", "Charge my phone.", "Telefonumu şarj et.")
	await get_tree().create_timer(3.0, false).timeout
	if visible and page == "dead": close(true)

func close(force := false) -> void:
	if is_locked() and not force: return   # house.20
	if page == "score": _score_continue(true)   # house.26: closing the score page = Continue
	Audio.click(); _lesson_serial += 1; Audio.cancel_group("lesson")   # house.19: closing the lesson stops its narration
	var tw := create_tween(); tw.tween_property(self, "modulate:a", 0.0, 0.22); await tw.finished
	visible = false; modulate.a = 1.0; _free_preview(); closed.emit()

func back() -> void:
	if is_locked() and not (page == "lesson" and lesson_i > 0): return   # house.20: only step back inside the lesson
	Audio.click()
	if page == "member": show_page("family", false); return
	if page in ["lesson", "quiz"]: _lesson_serial += 1; Audio.cancel_group("lesson")
	if page in ["lesson", "quiz"] and lesson_i > 0 and page == "lesson": lesson_i -= 1; _lesson(); return
	if history.is_empty(): close(); return
	show_page(history.pop_back(), false)

# ------------------------------------------------------------ helpers
func _l(t: String, fs: int, bold := false, c := INK) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", fs); l.add_theme_color_override("font_color", c)
	if bold and main: l.add_theme_font_override("font", main.font_b)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _wrap(t: String, fs: int, w: float, bold := false, c := INK) -> Label:
	var l := _l(t, fs, bold, c); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = w; return l

func _sb(c: Color, r := 22, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r)
	s.content_margin_left = pad; s.content_margin_right = pad; s.content_margin_top = pad; s.content_margin_bottom = pad
	return s

func _style(b: Button, c: Color, fc: Color, r := 18) -> void:
	b.add_theme_stylebox_override("normal", _sb(c, r, 8)); b.add_theme_stylebox_override("hover", _sb(c.lightened(0.06), r, 8))
	b.add_theme_stylebox_override("pressed", _sb(c.darkened(0.12), r, 8)); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _sb(Color(0.85, 0.87, 0.92), r, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.62, 0.68))

func _btn(t: String, cb: Callable, sz: Vector2, primary := false, fs := 22) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = sz; b.add_theme_font_size_override("font_size", fs)
	if main: b.add_theme_font_override("font", main.font_b)
	_style(b, BLUE if primary else Color(1, 1, 1, 0.95), Color.WHITE if primary else INK)
	b.pressed.connect(cb); return b

func _navbtn(t: String, nm: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = t; b.name = nm; b.custom_minimum_size = Vector2(150, 44); b.add_theme_font_size_override("font_size", 19)
	if main: b.add_theme_font_override("font", main.font_b)
	_style(b, Color(0.12, 0.15, 0.25, 0.08), INK, 22)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; b.pressed.connect(cb); return b

func _icon(n: String, s: float) -> TextureRect:
	var t := TextureRect.new(); t.texture = load("res://ui/phone/%s.png" % n); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; t.custom_minimum_size = Vector2(s, s); t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _scroll(horizontal := false) -> ScrollContainer:
	var s := ScrollContainer.new(); s.scroll_deadzone = 8
	if horizontal: s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	else: s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _card_btn(nm: String, h: float, on := false) -> Button:
	var b := Button.new(); b.name = nm; b.custom_minimum_size = Vector2(0, h); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nb := _sb(Color(0.86, 0.9, 1.0) if on else Color(1, 1, 1, 0.92), 22)
	if on: nb.border_color = BLUE; nb.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", nb); b.add_theme_stylebox_override("hover", _sb(Color(0.95, 0.96, 1.0), 22))
	b.add_theme_stylebox_override("pressed", _sb(Color(0.85, 0.89, 0.99), 22)); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _inner(b: Control) -> VBoxContainer:
	var bv := VBoxContainer.new(); bv.set_anchors_preset(Control.PRESET_FULL_RECT); bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 0); bv.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(bv); return bv

func _header(v: Control, en: String, sub: String, tr := "") -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); v.add_child(h)
	h.add_child(_l(en, 32, true))
	if sub != "":
		var s := _l(sub, 19, false, MUTED); s.size_flags_vertical = Control.SIZE_SHRINK_END; h.add_child(s)
	if tr != "":
		var t := _l(tr, 15, false, TR_C); t.size_flags_vertical = Control.SIZE_SHRINK_END; h.add_child(t)
	return h

func _clear() -> VBoxContainer:
	_free_preview()
	for c in body.get_children(): body.remove_child(c); c.queue_free()
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); body.add_child(v); return v

func _badge(parent: Control, pos: Vector2) -> void:
	var bd := Label.new(); bd.text = "1"; bd.name = "Badge"; bd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bd.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.26, 0.3), 17, 0)); bd.add_theme_font_size_override("font_size", 18)
	bd.add_theme_color_override("font_color", Color.WHITE); bd.position = pos; bd.size = Vector2(34, 34); parent.add_child(bd)

func show_page(p: String, push := true) -> void:
	if page == "dead" and visible: close(true); return   # v31.1 (O3): Home/Back on a dead phone just put it away
	if is_locked() and not p in ["lesson", "quiz", "score"] and not _unlocking: return   # house.20: can't leave a running lesson
	_unlocking = false
	if page in ["lesson", "quiz"] and p != page: _lesson_serial += 1; Audio.cancel_group("lesson")   # house.19
	if push and page != "" and page != p and page not in ["done", "member", "quiz"]: history.append(page)
	if p == "home": history.clear()
	page = p
	match p:
		"home": _home()
		"jobs": _jobs()
		"jobsub": _jobsub()
		"joblist": _joblist()
		"jobsearch": _job_search()
		"job": _job_detail()
		"done": _job_done()
		"grammar": _grammar()
		"words": _words()
		"me": _me()
		"family": _family_entry()
		"lesson": _lesson()
		"quiz": _quiz()
		"member": _member()
		"calendar": _calendar()
	if main and main.has_method("phone_event"): main.phone_event(p)

# ------------------------------------------------------------ home
const APP_TR := {"Jobs": "Meslekler", "Family": "Aile", "Calendar": "Takvim", "Grammar": "Dilbilgisi", "Words": "Kelimeler", "Me": "Ben"}
const WD := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
## v31.1: the date follows the shared day counter (day 1 = Monday, 7 September)
static func date_text() -> String:
	var d := maxi(1, WorldState.day)
	var dom := 7 + d - 1
	var mon := "September"
	if dom > 30: dom -= 30; mon = "October"
	return "%s, %d %s" % [WD[(d - 1) % 7], dom, mon]
func apps() -> Array:
	var S: Dictionary = main.S if main else {}
	var out := []
	if S.get("job", "") == "": out.append(["jobs", "Jobs", "app_jobs"])
	else: out.append(["family", "Family", "app_family"]); out.append(["calendar", "Calendar", "app_calendar"])
	out += [["grammar", "Grammar", "app_grammar"], ["words", "Words", "app_words"], ["me", "Me", "app_me"]]
	return out

func _home() -> void:
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := HBoxContainer.new(); v.add_child(top)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", -6); top.add_child(tv)
	var hc := _l(WorldState.clock_text(), 60, true); hc.name = "HomeClock"; tv.add_child(hc)   # v31.1: shared game clock (was "07:05")
	var hd := _l(date_text(), 20, false, MUTED); hd.name = "HomeDate"; tv.add_child(hd)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	var hi := VBoxContainer.new(); hi.alignment = BoxContainer.ALIGNMENT_CENTER; top.add_child(hi)
	var S: Dictionary = main.S if main else {}
	var nm: String = S.get("name", "")
	var g := _l("Hi, %s!" % nm if nm != "" else "Hi!", 30, true); g.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hi.add_child(g)
	var gt := _trl(_l("Merhaba, %s!" % nm if nm != "" else "Merhaba!", 17, false, TR_C)); gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hi.add_child(gt)   # v31.1: TR only with TR on
	var jb: String = S.get("job", "")
	var st := _l(i_am(job(jb)) if jb != "" else "Choose a job in the Jobs app.", 19, false, BLUE if jb == "" else MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hi.add_child(st)
	var gap := Control.new(); gap.custom_minimum_size.y = 14; v.add_child(gap)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 26); v.add_child(row)
	var pending: String = main.notify_app if main else ""
	for a in apps():
		var b := Button.new(); b.name = "App_" + a[0]; b.custom_minimum_size = Vector2(146, 180)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new()); b.add_theme_stylebox_override("hover", _sb(Color(1, 1, 1, 0.35), 26))
		b.add_theme_stylebox_override("pressed", _sb(Color(1, 1, 1, 0.55), 26)); b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var bv := _inner(b)
		var ic := _icon(a[2], 122); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; bv.add_child(ic)
		var l := _l(a[1], 22, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(l)
		var lt := _trl(_l(String(APP_TR.get(a[1], "")), 16, false, TR_C)); lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(lt)   # v31.1: TR app label (EN default)
		if a[0] == pending: _badge(b, Vector2(112, 4))
		var id: String = a[0]
		b.pressed.connect(func(): Audio.click(); show_page(id)); row.add_child(b)

# ------------------------------------------------------------ jobs: groups -> subcategories -> a few job cards
var j_group := {}
var j_sub := {}
var j_search := ""

func _crumbs(v: Control, title_tr: String) -> void:
	var top := HBoxContainer.new(); top.name = "Crumbs"; top.add_theme_constant_override("separation", 4); v.add_child(top)
	var parts := [["Jobs", "jobs"]]
	if not j_group.is_empty(): parts.append([j_group.en, "jobsub"])
	if not j_sub.is_empty(): parts.append([j_sub.en, "joblist"])
	elif j_search != "": parts.append(["Search: " + j_search, "joblist"])
	for i in parts.size():
		if i > 0:
			var sep := _l("›", 30, true, MUTED); sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(sep)
		var last: bool = i == parts.size() - 1
		var b := Button.new(); b.name = "Crumb_%d" % i; b.text = parts[i][0]; b.flat = true; b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 30 if last else 22)
		if main: b.add_theme_font_override("font", main.font_b)
		b.add_theme_color_override("font_color", INK if last else BLUE); b.add_theme_color_override("font_hover_color", BLUE)
		var target: String = parts[i][1]
		if not last: b.pressed.connect(func(): Audio.click(); _crumb_to(target))
		top.add_child(b)
	var tl := _l(title_tr, 15, false, TR_C); tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tl)
	if parts.size() == 1:
		# v12: no LineEdit (Android OS keyboard unreliable) -> a button that opens the in-game QWERTY search page
		var se := _btn("🔍  Search a job", open_job_search, Vector2(230, 44), false, 18); se.name = "JobSearch"
		se.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(se)

func _crumb_to(target: String) -> void:
	while not history.is_empty() and history[-1] != target: history.pop_back()
	if not history.is_empty(): history.pop_back()
	if target == "jobs": j_group = {}; j_sub = {}; j_search = ""
	elif target == "jobsub": j_sub = {}; j_search = ""
	show_page(target)

func search_jobs(t: String) -> void:
	t = t.strip_edges()
	if t == "": return
	Audio.click(); j_search = t; j_sub = {}; j_group = {}; show_page("joblist")

func open_job_search() -> void:
	Audio.click(); j_search = ""; j_sub = {}; j_group = {}; show_page("jobsearch")

func _job_search() -> void:
	var v := _clear(); v.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 10); v.add_child(top)
	var tt := _l("Search a job", 26, true); tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tt)
	var np := PanelContainer.new(); np.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.95), 16, 6)); np.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fh := HBoxContainer.new(); np.add_child(fh); v.add_child(np)
	var fl := _l(j_search if j_search != "" else "Type a job…", 28, true, INK if j_search != "" else MUTED); fl.name = "SearchText"
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; fh.add_child(fl)
	var cl := _btn("✕ Clear", func(): Audio.click(); j_search = ""; _job_search(), Vector2(110, 40), false, 16); cl.name = "SearchClear"; fh.add_child(cl)
	var res := HBoxContainer.new(); res.name = "SearchResults"; res.alignment = BoxContainer.ALIGNMENT_CENTER; res.add_theme_constant_override("separation", 8); res.custom_minimum_size.y = 64; v.add_child(res)
	if j_search != "":
		var list := found_jobs().slice(0, 5)
		if list.is_empty():
			var e := _l("No jobs found. Try another word.", 20, false, MUTED); e.size_flags_vertical = Control.SIZE_SHRINK_CENTER; res.add_child(e)
		for j in list:
			var jj: Dictionary = j
			var b := _card_btn("Result_" + str(j.id).replace(" ", "_"), 64); b.custom_minimum_size = Vector2(150, 64)
			var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 4); bh.alignment = BoxContainer.ALIGNMENT_CENTER; bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); b.add_child(bh)
			var ic := _icon(j.icon, 44); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; bh.add_child(ic)
			var lb := _l(j.en, 16, true); lb.mouse_filter = Control.MOUSE_FILTER_IGNORE; lb.autowrap_mode = TextServer.AUTOWRAP_WORD; lb.custom_minimum_size.x = 92; bh.add_child(lb)
			b.pressed.connect(func(): Audio.click(); sel = jj; show_page("job")); res.add_child(b)
	else:
		var hint := _l("Tap the letters. / Harflere dokun.", 18, false, MUTED); hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER; res.add_child(hint)
	var kb := VBoxContainer.new(); kb.name = "SearchKeys"; kb.add_theme_constant_override("separation", 6); v.add_child(kb)
	for ri in QWERTY.size():
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 5); kb.add_child(row)
		for ch in QWERTY[ri]:
			var b := Button.new(); b.text = ch; b.name = "Key_" + ch; b.custom_minimum_size = Vector2(50, 46)
			b.add_theme_font_size_override("font_size", 20); if main: b.add_theme_font_override("font", main.font_b)
			_style(b, Color(1, 1, 1, 0.95), INK, 12)
			var c: String = ch
			b.pressed.connect(func(): _search_type(c)); row.add_child(b)
	var orow := HBoxContainer.new(); orow.alignment = BoxContainer.ALIGNMENT_CENTER; orow.add_theme_constant_override("separation", 10); kb.add_child(orow)
	var del := _btn("Delete", func(): Audio.click(); j_search = j_search.substr(0, j_search.length() - 1); _job_search(), Vector2(130, 46), false, 16); del.name = "KeyDelete"; orow.add_child(del)
	var okb := _btn("Close", func(): back(), Vector2(200, 46), true, 18); okb.name = "KeyClose"; orow.add_child(okb)

func _search_type(c: String) -> void:
	if j_search.length() >= 16: return
	Audio.letter(c.to_lower())
	j_search = c if j_search == "" else j_search + c.to_lower()
	_job_search()

func found_jobs() -> Array:
	var out := []
	if not j_sub.is_empty():
		for id in j_sub.jobs: out.append(job(id))
	elif j_search != "":
		var q := j_search.to_lower()
		for j in jobs_data.jobs:
			if j.get("hidden", false): continue
			if String(j.en).to_lower().contains(q) or String(j.tr).to_lower().contains(q): out.append(j)
	return out.slice(0, 8)

func _tile(nm: String, icon: String, en: String, tr: String, isz: float, sz: Vector2, fs := 22) -> Button:
	var b := _card_btn(nm, sz.y); b.custom_minimum_size = sz; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bv := _inner(b); bv.alignment = BoxContainer.ALIGNMENT_CENTER; bv.add_theme_constant_override("separation", 4)
	var ic := _icon(icon, isz); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; bv.add_child(ic)
	var l := _l(en, fs, true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(l)
	var t := _l(tr, 15, false, TR_C); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(t)
	return b

func _grid_page(cols: int) -> GridContainer:
	var g := GridContainer.new(); g.name = "TileGrid"; g.columns = cols; g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 18)
	return g

func _jobs() -> void:
	j_group = {}; j_sub = {}; j_search = ""
	var v := _clear(); v.add_theme_constant_override("separation", 12)
	_crumbs(v, "Bir alan seç.")
	var sc := _scroll(); sc.name = "JobScroll"; v.add_child(sc)
	var g := _grid_page(5); sc.add_child(g)
	for gr in jobs_data.groups:
		var gg: Dictionary = gr
		var b := _tile("Group_" + gr.id, gr.icon, gr.en, gr.tr, 80, Vector2(0, 168), 19)
		b.pressed.connect(func(): Audio.click(); j_group = gg; j_sub = {}; show_page("jobsub")); g.add_child(b)

func _jobsub() -> void:
	var v := _clear(); v.add_theme_constant_override("separation", 12)
	_crumbs(v, j_group.tr)
	var c := CenterContainer.new(); c.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(c)
	var g := _grid_page(j_group.subs.size()); g.custom_minimum_size.x = 260 * j_group.subs.size(); c.add_child(g)
	for sb in j_group.subs:
		var ss: Dictionary = sb
		var b := _tile("Sub_" + sb.id, sb.icon, sb.en, sb.tr, 120, Vector2(0, 250), 24)
		var n := _l("%d job%s" % [sb.jobs.size(), "" if sb.jobs.size() == 1 else "s"], 15, false, MUTED); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.get_child(0).add_child(n)
		b.pressed.connect(func(): Audio.click(); j_sub = ss; show_page("joblist")); g.add_child(b)

func _joblist() -> void:
	var v := _clear(); v.add_theme_constant_override("separation", 12)
	var list := found_jobs()
	_crumbs(v, j_sub.get("tr", "Bir meslek seç."))
	var cur: String = main.S.get("job", "") if main else ""
	if list.is_empty():
		var e := _l("No jobs found. Try another word.", 24, false, MUTED); e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(e); return
	var few: bool = list.size() <= 4
	var holder: Control = v
	if not few:
		var sc := _scroll(); sc.name = "JobScroll"; v.add_child(sc); holder = sc
	var c := CenterContainer.new(); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; c.size_flags_vertical = Control.SIZE_EXPAND_FILL; holder.add_child(c)
	var cols: int = list.size() if few else 4
	var g := _grid_page(cols); g.custom_minimum_size.x = (260 if few else 240) * cols; c.add_child(g)
	for j in list:
		var jj: Dictionary = j
		var b := _tile("Job_" + str(j.id).replace(" ", "_"), j.icon, j.en, j.tr, 120 if few else 84, Vector2(0, 240 if few else 160), 24 if few else 21)
		if j.id == cur:
			var st := _sb(Color(0.86, 0.9, 1.0), 22); st.border_color = BLUE; st.set_border_width_all(3); b.add_theme_stylebox_override("normal", st)
		b.pressed.connect(func(): Audio.click(); sel = jj; show_page("job")); g.add_child(b)

func _job_detail() -> void:
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 40); h.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(h)
	h.add_child(_icon(sel.icon, 240))
	var r := VBoxContainer.new(); r.add_theme_constant_override("separation", 6); r.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(r)
	var where := ""
	for g in jobs_data.groups:
		for sb in g.subs:
			if sel.id in sb.jobs: where = "%s › %s" % [g.en, sb.en]
	r.add_child(_l(where, 18, true, MUTED))
	r.add_child(_l(sel.en, 54, true))
	r.add_child(_l(sel.tr, 18, false, TR_C))
	var parts: PackedStringArray = String(sel.line).split(". ", false)
	var sl := _wrap(". ".join(parts.slice(1)), 27, 520); sl.name = "Sentence"; r.add_child(sl)
	var gap := Control.new(); gap.custom_minimum_size.y = 8; r.add_child(gap)
	var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 14); r.add_child(bh)
	bh.add_child(_btn("Listen", func(): Audio.say(sel.line), Vector2(160, 62)))
	var cb := _btn("Choose this job", confirm, Vector2(260, 62), true, 23); cb.name = "ChooseJob"; bh.add_child(cb)
	Audio.say(sel.line)

func confirm() -> void:
	Audio.good()
	job_chosen.emit(sel.id)
	show_page("done", false)

func _job_done() -> void:
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 36); v.add_child(h)
	h.add_child(_icon(sel.icon, 200))
	var r := VBoxContainer.new(); r.alignment = BoxContainer.ALIGNMENT_CENTER; r.add_theme_constant_override("separation", 6); h.add_child(r)
	r.add_child(_l("Job saved!", 22, true, GREEN))
	r.add_child(_l(i_am(sel), 44, true))
	r.add_child(_l("Next: tell me about your family.", 24, false, MUTED))
	r.add_child(_l("Sırada: aileni anlat.", 16, false, TR_C))
	var gap := Control.new(); gap.custom_minimum_size.y = 8; r.add_child(gap)
	var nb := _btn("Next: my family", func(): Audio.click(); show_page("family"), Vector2(280, 62), true); nb.name = "NextFamily"; r.add_child(nb)

# ------------------------------------------------------------ family: lesson -> check -> creator
func _family_entry() -> void:
	if main and not main.S.get("lesson_done", false): lesson_i = 0; page = "lesson"; _lesson()
	else: page = "family"; _family()

const NOTE_EN := "Get a notebook and a pencil. Let's take notes."
const NOTE_TR := "Bir defter ve kalem al. Hadi not alalım."
func _lesson() -> void:
	if lesson_i == 0 and _note_for != _les():   # house.24: notebook prompt once at the start of every lesson
		_note_for = _les()
		# house.29: spoken exactly once (the caption is silent; a repeat within 8 s is dropped)
		if Time.get_ticks_msec() - _note_ms > 8000:
			_note_ms = Time.get_ticks_msec(); Audio.say(NOTE_EN)
		if main and main.has_method("caption"):
			if main.get_method_argument_count("caption") >= 2: main.caption(NOTE_EN, false)
	var v := _clear()
	var L: Array = _les().lesson
	var st: Dictionary = L[lesson_i]
	var top := HBoxContainer.new(); v.add_child(top)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 4); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tv)
	tv.add_child(_l("%s · Lesson %d / %d" % [_les().get("label", "Family"), lesson_i + 1, L.size()], 17, true, MUTED))
	tv.add_child(_l(String(st.get("title_tr", st.title)) if _tr_now() else st.title, 34, true)); tv.add_child(_trl(_l(st.tr, 16, false, TR_C)))   # v31: TR only with the TR toggle
	var dots := HBoxContainer.new(); dots.add_theme_constant_override("separation", 8); dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(dots)
	for i in L.size() + 1:
		var d := Panel.new(); d.custom_minimum_size = Vector2(14, 14)
		d.add_theme_stylebox_override("panel", _sb(BLUE if i <= lesson_i else Color(0.78, 0.8, 0.88), 7, 0)); dots.add_child(d)
	var sc := _scroll(); sc.name = "LessonScroll"; v.add_child(sc)
	var grid := GridContainer.new(); grid.name = "LessonRows"; grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 10); sc.add_child(grid)
	var fam := les.is_empty()
	var two := lesson_i == 2 and fam
	for row in st.rows:
		for k in 2:
			var txt: String = row[k]
			var b := _card_btn("Row", 54)
			if txt == "":
				var e := Control.new(); e.size_flags_horizontal = Control.SIZE_EXPAND_FILL; grid.add_child(e); continue
			var lb := _l(txt, 25 if (k == 0 or two) else 20, k == 0 or two, INK if (k == 0 or two) else (TR_C if (lesson_i in [0, 3] or not fam) else Color(0.25, 0.28, 0.36)))
			lb.set_anchors_preset(Control.PRESET_FULL_RECT); lb.offset_left = 20; lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lb.clip_text = true; lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; b.add_child(lb)
			if k == 1 and not two and (lesson_i in [0, 3] or not fam): _trl(lb)   # v31: TR column only with the TR toggle
			var say := txt if (k == 0 or two) else (txt.split(": ")[1] if txt.contains(": ") else "")
			if lesson_i == 1 and k == 0 and fam: say = ""
			if not fam: say = txt if k == 0 else ""
			if say != "": b.pressed.connect(func(): _page_say(say))
			else: b.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_child(b)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 12); bar.alignment = BoxContainer.ALIGNMENT_END; v.add_child(bar)
	bar.add_child(_btn("Listen", func(): _say_all(st.say), Vector2(150, 56)))
	var nb := _btn("Next" if lesson_i < L.size() - 1 else "Check", _lesson_next, Vector2(180, 56), true)
	nb.name = "LessonNext"; bar.add_child(nb)
	_say_all(st.say)

func _lesson_next() -> void:
	Audio.click()
	if lesson_i < _les().lesson.size() - 1:
		lesson_i += 1; _lesson()
	elif _studying:
		_studying = false; _score_page()   # house.26: back to the score page after studying
	elif not _les().get("quiz_after", true):
		lesson_steps_done.emit()
	else:
		quiz_i = 0; page = "quiz"; _quiz()
		if main: main.phone_event("quiz")

var _lesson_serial := 0
var _empty_t := 0.0
var _rebuilds := 0
var _note_for = null
var _note_ms := -100000
var _unlocking := false   # house.20: the lesson code itself leaves the lesson when finished
## house.19: lesson page narration is page-scoped: a new page cuts the old page's lines, only the latest page plays
func _say_all(lines: Array) -> void:
	_lesson_serial += 1; Audio.cancel_group("lesson")
	var g := "lesson_page_%d" % _lesson_serial
	for i in lines.size(): Audio.say_group(lines[i], g)
func _page_say(line: String) -> void:
	Audio.say_group(line, "lesson_page_%d" % _lesson_serial)

## house.26: three versions per test (quiz, quiz_b, quiz_c) rotating A->B->C->A per test (save.json "quiz_ver"),
## options shuffled every time
var _active_quiz: Array = []
var _active_for = null
func _qz() -> Array:
	if _active_for != _les() or _active_quiz.is_empty(): _pick_version()
	return _active_quiz
func _test_key() -> String: return String(_les().get("label", "family"))
func _pick_version() -> void:
	_active_for = _les()
	var vers: Array = []
	for k in ["quiz", "quiz_b", "quiz_c"]: if _les().get(k, []) is Array and not _les().get(k, []).is_empty(): vers.append(_les()[k])
	if vers.is_empty(): _active_quiz = []; return
	var qv = App.load_save().get("quiz_ver", {})
	var vi: int = int(qv.get(_test_key(), 0)) % vers.size() if qv is Dictionary else 0
	var out: Array = []
	for q in vers[vi]:
		var qq: Dictionary = q.duplicate(true); var order := range(qq.opts.size()); order.shuffle()
		var opts := []; for o in order: opts.append(q.opts[o])
		qq.opts = opts; qq.a = order.find(int(q.a)); out.append(qq)
	_active_quiz = out
	if qv is Dictionary: qv = qv.duplicate()
	else: qv = {}
	qv[_test_key()] = (vi + 1) % vers.size(); App.patch_save({"quiz_ver": qv})
func _score_continue(closing := false) -> void:
	var sc := quiz_score; var tot := _qz().size()
	page = "scored"
	if not les.is_empty(): quiz_done.emit(sc, tot); return
	page = "family"; lesson_finished.emit()
	if not closing: _family()
	if main: main.phone_event("family")

func _retake() -> void:
	Audio.click(); _answering = false; _active_quiz = []; quiz_i = 0; quiz_score = 0; quiz_wrong = false; page = "quiz"; _quiz()
func _study() -> void:
	Audio.click(); _studying = true; lesson_i = 0; page = "lesson"; _lesson()
var _studying := false
var _suggested := false

func _quiz() -> void:
	_lesson_serial += 1; Audio.cancel_group("lesson")   # house.19: leaving a page stops its narration
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 18)
	var Q: Array = _qz()
	var q: Dictionary = Q[quiz_i]
	var t := _l("Quick check %d / %d" % [quiz_i + 1, Q.size()], 18, true, MUTED); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var ql := _l(q.q, 40, true); ql.name = "Question"; ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ql)
	var tr := _l("Doğru kelimeye dokun.", 16, false, TR_C); tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tr)
	var row := HBoxContainer.new(); row.name = "Options"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 20); v.add_child(row)
	var fb := _l(" ", 24, true, GREEN); fb.name = "Feedback"; fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(fb)
	for i in q.opts.size():
		var b := _btn(q.opts[i], func(): pass, Vector2(170, 76), false, 30); b.name = "Opt%d" % i; row.add_child(b)
		var ii: int = i; var bb := b
		b.pressed.connect(func(): _answer(ii, bb, fb))
	_enable_when_idle(row)
	StoryUI.add_skip_button(v, _skip_test)   # skip-test

## skip-test: end the test now with full marks and continue exactly like the score page's Continue (no tip, no score page)
func _skip_test() -> void:
	if page != "quiz": return
	_answering = false; quiz_wrong = false; quiz_score = _qz().size(); StoryUI.mark_skipped(_test_key()); _score_continue()

## house.24.1: answer buttons stay disabled while the narrator is still speaking
func _enable_when_idle(row: Control) -> void:
	for c in row.get_children(): (c as Button).disabled = true
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(row) and Audio.is_speaking() and Time.get_ticks_msec() - t0 < 15000: await get_tree().process_frame
	if is_instance_valid(row):
		for c in row.get_children(): (c as Button).disabled = false

var _answering := false
func _answer(i: int, b: Button, fb: Label) -> void:
	if _answering or b.disabled or page != "quiz": return   # v29.1: one answer at a time (a double tap used to skip/stall a question)
	var q: Dictionary = _qz()[quiz_i]
	if i != int(q.a):
		quiz_wrong = true
		Audio.bad(); _style(b, Color(1.0, 0.86, 0.86), RED); fb.text = "Try again.  ·  Tekrar dene."; fb.add_theme_color_override("font_color", RED)
		if main: main.caption("Try again.")
		return
	if not quiz_wrong: quiz_score += 1
	quiz_wrong = false; _answering = true
	Audio.good(); _style(b, GREEN, Color.WHITE); fb.text = "That is right! (Doğru!)  " + q.say; fb.add_theme_color_override("font_color", GREEN)
	for c in b.get_parent().get_children(): (c as Button).disabled = c != b
	if main: main.caption("That is right!")
	_page_say(q.say)
	# house.24.1: never move on before the narrator has finished the sentence
	await get_tree().create_timer(1.0, false).timeout
	var t0 := Time.get_ticks_msec()
	while Audio.is_speaking() and Time.get_ticks_msec() - t0 < 15000: await get_tree().process_frame
	await get_tree().create_timer(0.3, false).timeout
	_answering = false
	if page != "quiz": return
	if quiz_i < _qz().size() - 1: quiz_i += 1; _quiz()
	elif not les.is_empty():
		_suggested = false; _score_page()   # house.26: quiz_done is emitted by the Continue button
	else:
		_suggested = false; _score_page()   # house.27: the family to-be quiz gets the same score page (Continue -> family page)

func _score_page() -> void:
	_lesson_serial += 1; Audio.cancel_group("lesson"); page = "score"   # house.20: finished -> phone closable again
	var v := _clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 18)
	var t := _l("Your score", 22, true, MUTED); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var sl := _l("%d / %d" % [quiz_score, _qz().size()], 64, true, GREEN); sl.name = "Score"; sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sl)
	var tr := _l("Puanın: %d / %d" % [quiz_score, _qz().size()], 18, false, TR_C); tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tr)
	# house.26: optional study suggestion when half or more were wrong; retake (next version) and continue
	var total := _qz().size()
	if total > 0 and total - quiz_score >= ceili(total / 2.0):
		var sg := _l("You should study the grammar again.", 20, true, INK); sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sg)
		var sgt := _l("Dilbilgisi konusunu tekrar çalışmalısın.", 15, false, TR_C); sgt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sgt)
		if not _suggested: _suggested = true; Audio.say("You should study the grammar again.")
	var bar := HBoxContainer.new(); bar.alignment = BoxContainer.ALIGNMENT_CENTER; bar.add_theme_constant_override("separation", 14); v.add_child(bar)
	if not _les().get("lesson", []).is_empty(): bar.add_child(_btn("Study grammar\nDilbilgisi çalış", _study, Vector2(200, 64), false, 17))
	bar.add_child(_btn("Retake the test\nTesti tekrarla", _retake, Vector2(200, 64), false, 17))
	var cb := _btn("Continue\nDevam", func(): Audio.click(); _score_continue(), Vector2(180, 64), true, 17); cb.name = "ScoreContinue"; bar.add_child(cb)

## sentence for a member: "This is Ayşe. She is my sister. She is funny and kind."
func pron(m: Dictionary) -> String:
	var r := role(m.get("role", ""))
	if r.is_empty(): return "he"
	return r.pron if r.pron != "" else m.get("pron", "she")

func adj_sentence(m: Dictionary) -> String:
	var a: Array = m.get("adj", [])
	if a.is_empty(): return ""
	var order := []
	for x in fam_data.adjectives: if x.en in a: order.append(x.en)
	return "%s is %s." % [pron(m).capitalize(), " and ".join(order)]

func role_sentence(m: Dictionary) -> String:
	if m.get("role", "") == "": return ""
	return "%s is my %s." % [pron(m).capitalize(), m.role]

func sentence(m: Dictionary) -> String:
	var out := []
	if m.get("name", "") != "": out.append("This is %s." % m.name)
	if m.get("role", "") != "": out.append(role_sentence(m))
	var a := adj_sentence(m)
	if a != "": out.append(a)
	return " ".join(out)

func speak_member(m: Dictionary) -> void:
	var first := true
	if m.get("name", "") != "":
		Audio.say("This is", true); first = false
		Audio.say_tts(m.name)
	if m.get("role", "") != "": Audio.say(role_sentence(m), first); first = false
	var a := adj_sentence(m)
	if a != "": Audio.say(a, first)

func summary_lines() -> Array:
	var fam: Array = main.S.get("family", []) if main else []
	var groups := {}; var order := []
	for m in fam:
		if not groups.has(m.role): groups[m.role] = []; order.append(m.role)
		groups[m.role].append(m.name)
	var out := []
	for r in order:
		var names: Array = groups[r]
		if names.size() == 1: out.append("%s is my %s." % [names[0], r])
		else:
			var nm: String = ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
			out.append("%s are my %s." % [nm, role(r).get("plural", r + "s")])
	return out

const Portraits = preload("res://scripts/core/portraits.gd")
var _pr: Node
func _portraits() -> Node:
	if not is_instance_valid(_pr): _pr = Portraits.new(); add_child(_pr)
	return _pr

func _avatar(m: Dictionary, s: float) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(s, s); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgp := Panel.new(); bgp.set_anchors_preset(Control.PRESET_FULL_RECT); bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bgp.add_theme_stylebox_override("panel", _sb(Color(0.86, 0.9, 1.0), int(s / 2), 0)); c.add_child(bgp)
	var layers := []
	if role(m.get("role", "")).get("pet", false):
		layers = [["pet_" + m.role, PET_COLS[int(m.get("col", 0))][1]], ["pet_" + m.role + "_d", Color.WHITE]]
	elif m.get("role", "") != "":
		layers = [["av_body", CLOTH_COLS[int(m.get("cloth", 1))][1]], ["av_head", SKIN_UI[int(m.get("skin", 1))]], ["av_face", Color.WHITE],
			["av_hair%d" % int(m.get("hair", 0)), HAIR_COLS[int(m.get("hcol", 1))][1]]]
	var kid: bool = m.get("child", false) and not role(m.get("role", "")).get("pet", false)
	# house.29: humans show a portrait rendered from their real 3D look (cached; re-rendered only when the look changes)
	if not layers.is_empty() and not role(m.get("role", "")).get("pet", false):
		var tex := Portraits.cached(m)
		var ptex := TextureRect.new(); ptex.set_anchors_preset(Control.PRESET_FULL_RECT); ptex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ptex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ptex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if tex:
			ptex.texture = tex; c.add_child(ptex); return c
		c.add_child(ptex)
		_portraits().request(m, func(t: Texture2D):
			if is_instance_valid(ptex):
				ptex.texture = t
				for ch in ptex.get_parent().get_children(): if ch is TextureRect and ch != ptex: ch.queue_free())
	for L in layers:
		var t := _icon(L[0], s); t.set_anchors_preset(Control.PRESET_FULL_RECT); t.modulate = L[1]; c.add_child(t)
		if kid: t.set_anchors_preset(Control.PRESET_TOP_LEFT); t.size = Vector2(s, s) * 0.8; t.position = Vector2(s * 0.1, s * 0.2)
	return c

func _family() -> void:
	var v := _clear()
	var fam: Array = main.S.get("family", []) if main else []
	var h := _header(v, "My family", "%d / %d" % [fam.size(), MAX_FAMILY], "Ailen: en fazla 6 kişi veya hayvan")
	var sc := _scroll(); sc.name = "FamilyScroll"; v.add_child(sc)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); sc.add_child(list)
	if fam.is_empty():
		var e := _wrap("Who is in your family? Add a person or a pet. A pet is family too!", 24, 700, false, MUTED); list.add_child(e)
		list.add_child(_l("Ailende kim var? Bir kişi ya da evcil hayvan ekle.", 16, false, TR_C))
	else:
		var sm := PanelContainer.new(); sm.name = "Summary"; sm.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.7), 20, 12)); list.add_child(sm)
		var sv := VBoxContainer.new(); sm.add_child(sv)
		for line in summary_lines() + ["They are my family." if fam.size() > 1 else ""]:
			if line != "": sv.add_child(_wrap(line, 22, 900, true))
	var grid := GridContainer.new(); grid.columns = 2; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); list.add_child(grid)
	for i in fam.size():
		var m: Dictionary = fam[i]
		var b := _card_btn("Member%d" % i, 112)
		var hb := HBoxContainer.new(); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.offset_left = 14; hb.offset_right = -10
		hb.add_theme_constant_override("separation", 14); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(hb)
		var av := _avatar(m, 88); av.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(av)
		var tl := _wrap(sentence(m), 19, 0, false, INK); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.size_flags_vertical = Control.SIZE_FILL; hb.add_child(tl)
		var ii: int = i
		b.pressed.connect(func(): _edit_member(ii))
		grid.add_child(b)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 12); bar.alignment = BoxContainer.ALIGNMENT_END; v.add_child(bar)
	var add := _btn("+  Add a family member", new_member, Vector2(300, 56), fam.is_empty())
	add.name = "AddMember"; add.disabled = fam.size() >= MAX_FAMILY; bar.add_child(add)
	var done := _btn("Done", family_done, Vector2(150, 56), not fam.is_empty())
	done.name = "FamilyDone"; done.disabled = fam.is_empty(); bar.add_child(done)

func _edit_member(ii: int) -> void:
	var fam: Array = main.S.family
	Audio.click(); speak_member(fam[ii]); edit = fam[ii].duplicate(true); edit_index = ii; edit_step = "who"; page = "member"; _member()

func new_member() -> void:
	Audio.click(); edit = {"role": "", "name": "", "skin": 1, "hair": 0, "hcol": 1, "cloth": 1, "col": 0, "adj": [], "pron": "she", "child": false}
	edit_index = -1; edit_step = "who"; page = "member"; _member()
	if main: main.phone_event("member")

func family_done() -> void:
	Audio.good(); speak_family(); family_saved.emit(); show_page("home")

func speak_family() -> void:
	var fam: Array = main.S.get("family", [])
	if fam.size() > 1: Audio.say("They are my family.")

# ---- member editor (phone-sized version of the mirror creator)
func _member() -> void:
	var v := _clear(); v.add_theme_constant_override("separation", 8)
	var h := HBoxContainer.new(); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_theme_constant_override("separation", 18); v.add_child(h)
	# left: live preview + sentence
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 290; left.add_theme_constant_override("separation", 6); h.add_child(left)
	var pp := PanelContainer.new(); pp.name = "Preview"; pp.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.8), 24, 6)); pp.custom_minimum_size = Vector2(290, 300); left.add_child(pp)
	_build_preview(pp)
	preview_sentence = _wrap("", 19, 290, true); preview_sentence.name = "MemberSentence"; left.add_child(preview_sentence)
	# right: steps
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation", 8); h.add_child(right)
	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); right.add_child(tabs)
	var steps := [["who", "Who?"], ["name", "Name"], ["look", "Look"], ["adj", "Personality"]]
	for s in steps:
		var sid: String = s[0]
		var tb := _btn(s[1], func(): Audio.click(); edit_step = sid; _member(), Vector2(0, 46), edit_step == sid, 18); tb.name = "Step_" + sid
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(tb)
	var sc := _scroll(); sc.name = "MemberScroll"; right.add_child(sc)
	var content := VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 8); sc.add_child(content)
	match edit_step:
		"who": _step_who(content)
		"name": _step_name(content)
		"look": _step_look(content)
		"adj": _step_adj(content)
	var bar := HBoxContainer.new(); bar.add_theme_constant_override("separation", 10); bar.alignment = BoxContainer.ALIGNMENT_END; right.add_child(bar)
	if edit_index >= 0:
		var rm := _btn("Remove", _remove_member, Vector2(130, 52), false, 18)
		rm.name = "RemoveMember"; bar.add_child(rm)
	var hint := _l(_missing(), 16, false, RED); hint.name = "Missing"; hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER; bar.add_child(hint)
	var idx := ["who", "name", "look", "adj"].find(edit_step)
	if idx < 3:
		var nb := _btn("Next", func(): Audio.click(); edit_step = ["who", "name", "look", "adj"][idx + 1]; _member(), Vector2(130, 52), false, 20); nb.name = "MemberNext"; bar.add_child(nb)
	var sv := _btn("Save", _save_member, Vector2(130, 52), true, 20); sv.name = "SaveMember"; sv.disabled = _missing() != ""; bar.add_child(sv)
	_update_preview()

func _remove_member() -> void:
	Audio.click(); main.S.family.remove_at(edit_index); edit_index = -1; page = "family"; _family()

func _missing() -> String:
	if edit.get("role", "") == "": return "Choose who it is."
	if edit.get("name", "") == "": return "Write a name."
	if edit.get("adj", []).is_empty(): return "Choose a word for the personality."
	return ""

func _save_member() -> void:
	if _missing() != "": return
	Audio.good()
	var fam: Array = main.S.family
	if edit_index >= 0: fam[edit_index] = edit.duplicate(true)
	else: fam.append(edit.duplicate(true))
	speak_member(edit)
	if main: main.member_saved()
	page = "family"; _family()
	if main: main.phone_event("family")

func _section(v: Control, en: String, tr: String) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_l(en, 20, true)); var t := _l(tr, 14, false, TR_C); t.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(t)

func _chip_grid(v: Control, cols: int) -> GridContainer:
	var g := GridContainer.new(); g.columns = cols; g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8); v.add_child(g); return g

func _chip(g: Control, nm: String, en: String, tr: String, on: bool, cb: Callable) -> Button:
	var b := _card_btn(nm, 56 if tr != "" else 48, on)
	var bv := _inner(b)
	var l := _l(en, 19, true, BLUE if on else INK); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(l)
	if tr != "":
		var t := _l(tr, 13, false, TR_C); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.clip_text = true; t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; bv.add_child(t)
	b.pressed.connect(cb); g.add_child(b); return b

func _swatches(v: Control, key: String, cols: Array, labels := true) -> void:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); v.add_child(row)
	for i in cols.size():
		var c: Color = cols[i][1] if cols[i] is Array else cols[i]
		var b := Button.new(); b.name = "%s_%d" % [key, i]; b.custom_minimum_size = Vector2(52, 52)
		var on: bool = int(edit.get(key, 0)) == i
		var st := _sb(c, 26, 0); st.border_color = BLUE if on else Color(1, 1, 1, 0.9); st.set_border_width_all(5 if on else 2)
		for k in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(k, st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		if cols[i] is Array: b.tooltip_text = cols[i][0]
		var ii: int = i
		b.pressed.connect(func(): Audio.click(); edit[key] = ii; _member())
		row.add_child(b)

func _step_who(v: Control) -> void:
	_section(v, "People", "İnsanlar")
	var g := _chip_grid(v, 5)
	var kid: bool = main != null and main.is_child()
	for r in fam_data.roles:
		if r.pet: continue
		if kid and r.id in CHILD_HIDE: continue
		var rid: String = r.id
		_chip(g, "Role_" + rid, rid, r.tr, edit.role == rid, func(): _set_role(rid))
	if edit.role == "cousin":
		_section(v, "He or she?", "Erkek mi, kız mı?")
		var pg := _chip_grid(v, 4)
		for p in ["he", "she"]:
			var pp: String = p
			_chip(pg, "Pron_" + p, p, "", edit.get("pron", "she") == p, func(): Audio.click(); edit.pron = pp; _member(); Audio.say(role_sentence(edit)))
	if edit.role != "" and not role(edit.role).get("pet", false):
		_section(v, "Child or adult?", "Çocuk mu, yetişkin mi?")
		var ag := _chip_grid(v, 4)
		for a in [["child", "Çocuk"], ["adult", "Yetişkin"]]:
			var aa: String = a[0]
			_chip(ag, "Age_" + aa, aa, a[1], ("child" if edit.get("child", false) else "adult") == aa, func(): _set_age(aa))
	_section(v, "Pets", "Evcil hayvanlar")
	var g2 := _chip_grid(v, 5)
	for r in fam_data.roles:
		if not r.pet: continue
		var rid: String = r.id
		_chip(g2, "Role_" + rid, rid, r.tr, edit.role == rid, func(): _set_role(rid))

const CHILD_HIDE := ["wife", "husband", "son", "daughter"]
func _set_age(a: String) -> void:
	Audio.click(); edit.child = a == "child"; edit.child_set = true; _member()

func _set_role(rid: String) -> void:
	Audio.click(); edit.role = rid
	if not edit.has("child_set"):
		var kid: bool = main != null and main.is_child()
		edit.child = rid in ["son", "daughter"] or (kid and rid in ["brother", "sister", "cousin"])
	if rid in ["grandmother", "grandfather"]: edit.hcol = 4
	# house.22: varied hair defaults per role (length 0 short / 1 medium / 2 long, colour index of HAIR_COLS)
	var HD := {"father": [0, 0], "mother": [2, 1], "sister": [2, 2], "brother": [0, 1], "grandmother": [1, 5], "grandfather": [0, 4],
		"son": [0, 2], "daughter": [2, 3], "uncle": [0, 0], "aunt": [1, 3], "cousin": [1, 2], "wife": [2, 0], "husband": [0, 1]}
	if HD.has(rid) and not edit.has("hair_set"): edit.hair = HD[rid][0]; edit.hcol = HD[rid][1]
	_member(); Audio.say(role_sentence(edit))   # house.24.1: only the new choice

const QWERTY := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
func _step_name(v: Control) -> void:
	_section(v, "What is the name?", "")
	var np := PanelContainer.new(); np.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.95), 16, 6)); v.add_child(np)
	var nl := _l(edit.name if edit.name != "" else " ", 32, true); nl.name = "MemberName"; nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; np.add_child(nl)
	# v11: QWERTY like a phone keyboard, A-Z only, staggered rows, Delete + OK
	var kb := VBoxContainer.new(); kb.name = "MemberKeys"; kb.add_theme_constant_override("separation", 6); v.add_child(kb)
	for ri in QWERTY.size():
		var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 5); kb.add_child(row)
		for ch in QWERTY[ri]:
			var b := Button.new(); b.text = ch; b.name = "Key_" + ch; b.custom_minimum_size = Vector2(50, 46)
			b.add_theme_font_size_override("font_size", 20); if main: b.add_theme_font_override("font", main.font_b)
			_style(b, Color(1, 1, 1, 0.95), INK, 12)
			var c: String = ch
			b.pressed.connect(func(): _type(c)); row.add_child(b)
	var orow := HBoxContainer.new(); orow.alignment = BoxContainer.ALIGNMENT_CENTER; orow.add_theme_constant_override("separation", 10); kb.add_child(orow)
	var del := _btn("Delete", _backspace, Vector2(130, 46), false, 16); del.name = "KeyDelete"; orow.add_child(del)
	var okb := _btn("OK", _name_ok, Vector2(200, 46), true, 18); okb.name = "KeyOK"; orow.add_child(okb)

func _name_ok() -> void:
	Audio.click()
	if edit.name == "": return
	edit_step = "look"; _member(); Audio.say("This is"); Audio.say_tts(edit.name)

func _backspace() -> void:
	Audio.click(); edit.name = edit.name.substr(0, edit.name.length() - 1); _member()

func _type(c: String) -> void:
	if edit.name.length() >= 12: return
	Audio.letter(c.to_lower())
	var n: String = edit.name
	edit.name = c if n == "" else n + c.to_lower()
	_member()

func _step_look(v: Control) -> void:
	if role(edit.role).get("pet", false):
		_section(v, "Colour", "Renk")
		_swatches(v, "col", PET_COLS)
		return
	if edit.role == "":
		v.add_child(_l("Choose who it is first.", 20, false, MUTED)); return
	_section(v, "Skin", "Ten rengi"); _swatches(v, "skin", SKIN_UI)
	_section(v, "Hair", "Saç modeli")
	var g := _chip_grid(v, 3)
	for i in 3:
		var ii: int = i
		_chip(g, "Hair_%d" % i, ["short hair", "medium hair", "long hair"][i], ["kısa", "orta", "uzun"][i], int(edit.hair) == i,
			func(): Audio.click(); edit.hair = ii; edit.hair_set = true; _member())
	_section(v, "Hair colour", "Saç rengi"); _swatches(v, "hcol", HAIR_COLS)
	_section(v, "Clothes colour", "Kıyafet rengi"); _swatches(v, "cloth", CLOTH_COLS)

func _step_adj(v: Control) -> void:
	_section(v, "What is %s like? Choose 1 or 2 words." % (edit.name if edit.name != "" else "he or she"), "Nasıl biri? 1-2 kelime seç.")
	var g := _chip_grid(v, 4)
	for a in fam_data.adjectives:
		var ae: String = a.en
		_chip(g, "Adj_" + ae, ae, a.tr, ae in edit.adj, func(): _toggle_adj(ae))

func _toggle_adj(ae: String) -> void:
	Audio.click()
	var arr: Array = edit.adj
	if ae in arr: arr.erase(ae)
	elif arr.size() < 2: arr.append(ae)
	else:
		arr.pop_front(); arr.append(ae)
	_member()
	if ae in arr: Audio.say("%s is %s." % [pron(edit).capitalize(), ae])   # house.24.1: only the newly chosen quality

func _gender() -> String:
	var p := pron(edit)
	return "women" if p == "she" else "men"

func _build_preview(pp: PanelContainer) -> void:
	if role(edit.get("role", "")).get("pet", false) or edit.get("role", "") == "":
		var c := CenterContainer.new(); pp.add_child(c)
		if edit.get("role", "") == "": c.add_child(_icon("app_family", 150))
		else: c.add_child(_avatar(edit, 230))
		return
	var svc := SubViewportContainer.new(); svc.stretch = true; svc.name = "Preview3D"; svc.mouse_filter = Control.MOUSE_FILTER_IGNORE; pp.add_child(svc)
	preview_vp = SubViewport.new(); preview_vp.own_world_3d = true; preview_vp.transparent_bg = true; preview_vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(preview_vp)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95); e.ambient_light_energy = 0.7; e.background_mode = Environment.BG_CLEAR_COLOR; env.environment = e; preview_vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 30, 0); sun.light_energy = 1.1; preview_vp.add_child(sun)
	var cam := Camera3D.new(); cam.fov = 30; cam.position = Vector3(0, 1.0, 4.2); preview_vp.add_child(cam); cam.look_at(Vector3(0, 0.85, 0)); cam.current = true
	preview_char = DemoCharacter.new(); preview_vp.add_child(preview_char); preview_char.setup(_gender()); preview_char.rotation.y = 0.35

func _free_preview() -> void:
	if preview_vp: preview_vp.queue_free()
	preview_vp = null; preview_char = null

func _update_preview() -> void:
	if preview_sentence: preview_sentence.text = sentence(edit) if sentence(edit) != "" else "Who is it? Choose below."
	if preview_char == null: return
	var g := _gender()
	if preview_char.gender != g: preview_char.setup(g)
	preview_char.skin = int(edit.skin); preview_char.hair_color = HAIR_COLS[int(edit.hcol)][1]; preview_char.top_color = CLOTH_COLS[int(edit.cloth)][1]
	preview_char.outfit = {"Head": int(edit.hair), "Body": 0, "Legs": 1 if g == "women" else 0, "Feet": 0}
	preview_char.child = edit.get("child", false)
	preview_char.set_height("medium")
	preview_char.scale = Vector3.ONE * (1.3 if preview_char.child else 1.0)   # a child stays smaller than an adult but fills the preview
	preview_char._refresh()

## v31: lesson TR labels follow the host scene's TR toggle (S.tr), English only by default
var _tr_lbls: Array = []
var _tr_last := false
func _tr_now() -> bool:
	return App.tr_on()   # v30.5: single persisted TR flag
func _trl(l: Label) -> Label:
	_tr_lbls = _tr_lbls.filter(func(x): return is_instance_valid(x)); _tr_lbls.append(l); l.visible = _tr_now(); _tr_last = _tr_now(); return l
func _process(dt: float) -> void:
	_lock_tick()
	if visible and not _tr_lbls.is_empty() and _tr_now() != _tr_last:
		_tr_last = _tr_now(); _tr_lbls = _tr_lbls.filter(func(x): return is_instance_valid(x))
		for l in _tr_lbls: l.visible = _tr_last
	if preview_char and is_visible_in_tree(): preview_char.rotation.y = 0.35 + sin(Time.get_ticks_msec() * 0.0008) * 0.5

# ------------------------------------------------------------ calendar
var rout_data := {}
## the job's own work tasks (job-specific, else the sector's): [{i, do, i_tr, do_tr}]
func tasks(id: String) -> Array:
	if rout_data.is_empty(): rout_data = App.load_json("res://data/routines.json")
	var j := job(id)
	if rout_data.jobs.has(id): return rout_data.jobs[id]
	return rout_data.sectors.get(j.get("sector", ""), [])

## daily routine for the chosen job: shift frame + the workplace start line + 3 work tasks
func routine(id := "") -> Array:
	if id == "": id = main.S.get("job", "") if main else ""
	if rout_data.is_empty(): rout_data = App.load_json("res://data/routines.json")
	var j := job(id)
	var rows: Array = rout_data.frames.get(j.get("shift", "day"), rout_data.frames.day)
	var tk := tasks(id)
	var out := []
	for r in rows:
		if r[1] == "START": out.append([r[0], j.get("start", "I start work."), main.extra_tr(j.get("start", "I start work.")) if main else ""])
		elif String(r[1]).begins_with("TASK"):
			var k := int(String(r[1]).substr(4))
			if k < tk.size(): out.append([r[0], tk[k].i, tk[k].i_tr])
		else: out.append(r)
	return out

## "I am a teacher." / "I am retired."
static func i_am(j: Dictionary) -> String:
	return ("I am %s %s." % [j.a, j.en]) if j.get("a", "") != "" else "I am %s." % j.en

func _calendar() -> void:
	calendar_opened.emit()   # first, so the to-do list already ticks "Open the Calendar."
	var v := _clear()
	_header(v, "Calendar", "Monday · " + (i_am(job(main.S.job)) if main and main.S.job != "" else "My day"), "Pazartesi · Günüm")
	var h := HBoxContainer.new(); h.size_flags_vertical = Control.SIZE_EXPAND_FILL; h.add_theme_constant_override("separation", 16); v.add_child(h)
	var lp := PanelContainer.new(); lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lp.size_flags_stretch_ratio = 1.5
	lp.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.75), 22, 10)); h.add_child(lp)
	var sc := _scroll(); sc.name = "RoutineScroll"; lp.add_child(sc)
	var list := VBoxContainer.new(); list.name = "Routine"; list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 6); sc.add_child(list)
	for r in routine():
		var b := _card_btn("Routine", 54)
		var hb := HBoxContainer.new(); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.offset_left = 10; hb.offset_right = -10
		hb.add_theme_constant_override("separation", 12); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(hb)
		var tp := PanelContainer.new(); tp.add_theme_stylebox_override("panel", _sb(BLUE, 14, 6)); tp.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tp.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(tp)
		var tl := _l(r[0], 18, true, Color.WHITE); tl.custom_minimum_size.x = 56; tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tp.add_child(tl)
		var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", -2); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.alignment = BoxContainer.ALIGNMENT_CENTER; tv.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(tv)
		var el := _l(r[1], 20, true); el.clip_text = true; el.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; tv.add_child(el)
		if r[2] != "":
			var trl := _l(r[2], 13, false, TR_C); trl.clip_text = true; tv.add_child(trl)
		var line: String = r[1]
		b.pressed.connect(func(): Audio.say(line)); list.add_child(b)
	var rp := PanelContainer.new(); rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.75), 22, 12)); h.add_child(rp)
	var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 4); rp.add_child(rv)
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation", 8); rv.add_child(th)
	th.add_child(_l("To do", 22, true)); var tt := _l("Yapılacaklar", 14, false, TR_C); tt.size_flags_vertical = Control.SIZE_SHRINK_CENTER; th.add_child(tt)
	var sc2 := _scroll(); sc2.name = "TodoScroll"; rv.add_child(sc2)
	var tl2 := VBoxContainer.new(); tl2.name = "Todo"; tl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl2.add_theme_constant_override("separation", 4); sc2.add_child(tl2)
	if main and main.is_child() and main.S.family.is_empty():
		var nb := _btn("Next: my family", func(): Audio.click(); show_page("family"), Vector2(0, 50), true, 19); nb.name = "CalNextFamily"; rv.add_child(nb)
	for t in (main.todo() if main else []):
		var b := _card_btn("Todo", 44)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var hb := HBoxContainer.new(); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.offset_left = 4; hb.add_theme_constant_override("separation", 10); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(hb)
		var ck := PanelContainer.new(); ck.custom_minimum_size = Vector2(28, 28); ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER; ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cst := _sb(GREEN if t[1] else Color(1, 1, 1), 14, 0); cst.border_color = GREEN if t[1] else Color(0.7, 0.72, 0.8); cst.set_border_width_all(2); ck.add_theme_stylebox_override("panel", cst); hb.add_child(ck)
		var lb := _l(t[0], 18, not t[1], MUTED if t[1] else INK); lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; lb.clip_text = true
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; hb.add_child(lb)
		var line: String = t[0]
		b.pressed.connect(func(): Audio.say(line)); tl2.add_child(b)

# ------------------------------------------------------------ me, grammar, words
func _me() -> void:
	var v := _clear()
	var S: Dictionary = main.S if main else {}
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 22); v.add_child(h)
	h.add_child(_icon("app_me", 110))
	var r := VBoxContainer.new(); r.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(r)
	r.add_child(_l("My name is %s." % S.get("name", ""), 34, true))
	var j: String = S.get("job", "")
	r.add_child(_l(i_am(job(j)) if j != "" else "I have no job yet.", 26, false, INK))
	var sc := _scroll(); sc.name = "MeScroll"; v.add_child(sc)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 8); sc.add_child(list)
	var fam: Array = S.get("family", [])
	list.add_child(_l("My family" if not fam.is_empty() else "My family: nobody yet.", 22, true))
	var grid := GridContainer.new(); grid.name = "MeFamily"; grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); list.add_child(grid)
	for m in fam:
		var b := _card_btn("MeMember", 84)
		var hb := HBoxContainer.new(); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.offset_left = 10; hb.add_theme_constant_override("separation", 10); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(hb)
		var av := _avatar(m, 64); av.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(av)
		var tv := VBoxContainer.new(); tv.alignment = BoxContainer.ALIGNMENT_CENTER; tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(tv)
		tv.add_child(_l(m.name, 21, true)); var rl := _l("my " + m.role, 16, false, MUTED); tv.add_child(rl)
		var mm: Dictionary = m
		b.pressed.connect(func(): speak_member(mm)); grid.add_child(b)

func _grammar() -> void:
	var v := _clear()
	var data = App.load_json("res://data/grammar.json")
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); v.add_child(h)
	h.add_child(_l("Grammar", 32, true))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	for lv in ["A1", "A2"]:
		var lvv: String = lv
		h.add_child(_btn(lv, func(): Audio.click(); g_level = lvv; _grammar(), Vector2(80, 46), g_level == lv, 19))
	var sc := _scroll(); sc.name = "GrammarScroll"; v.add_child(sc)
	var list := VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 10); sc.add_child(list)
	for tp in (data.topics if data else []):
		if tp.level != g_level: continue
		var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.92), 20, 14)); list.add_child(card)
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 2); card.add_child(cv)
		var t := _l(tp.title, 23, true); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cv.add_child(t)
		cv.add_child(_l(tp.title_tr, 15, false, TR_C))
		for e in (tp.get("positive", []) as Array).slice(0, 2): cv.add_child(_l("•  " + e.en, 19, false, Color(0.25, 0.28, 0.36)))

func _words() -> void:
	var v := _clear()
	var data = App.load_json("res://data/vocabulary.json")
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); v.add_child(h)
	h.add_child(_l("Words", 32, true))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	for c in [["nouns", "Nouns"], ["verbs", "Verbs"], ["adjectives", "Adjectives"]]:
		var cc: String = c[0]
		h.add_child(_btn(c[1], func(): Audio.click(); w_cat = cc; _words(), Vector2(120, 46), w_cat == cc, 18))
	var gap := Control.new(); gap.custom_minimum_size.x = 10; h.add_child(gap)
	for lv in ["A1", "A2"]:
		var lvv: String = lv
		h.add_child(_btn(lv, func(): Audio.click(); w_level = lvv; _words(), Vector2(70, 46), w_level == lv, 18))
	var sc := _scroll(); sc.name = "WordScroll"; v.add_child(sc)
	var grid := GridContainer.new(); grid.columns = 3; grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); sc.add_child(grid)
	var words: Array = data.levels[w_level][w_cat] if data else []
	for w in words:
		var row := _card_btn("Word", 62)
		var rh := HBoxContainer.new(); rh.set_anchors_preset(Control.PRESET_FULL_RECT); rh.offset_left = 16; rh.offset_right = -12
		rh.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(rh)
		var we := _l(w.en, 22, true); we.size_flags_horizontal = Control.SIZE_EXPAND_FILL; we.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		we.size_flags_vertical = Control.SIZE_FILL; we.clip_text = true; we.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; rh.add_child(we)
		var wt := _trl(_l(w.tr, 15, false, TR_C)); wt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; wt.size_flags_vertical = Control.SIZE_FILL
		wt.clip_text = false; wt.size_flags_horizontal = Control.SIZE_SHRINK_END; wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT   # v32 polish (blue): full width for the meaning (words with ı/ç came out blank in the 50/50 split); the English word trims instead
		wt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; rh.add_child(wt)   # v32 polish (blue): meaning follows the TR toggle (Turkish showed with TR off)
		var word: String = w.en
		row.pressed.connect(func(): App.say_word(word)); grid.add_child(row)
