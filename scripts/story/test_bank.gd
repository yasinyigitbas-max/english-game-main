## v33 (red): SHARED NO-REPEAT BEDTIME TEST BANK (data/test_bank.json). Used by the day-4 / day-7 bedtimes (red) and the
## day-5 / day-6 bedtimes (blue). Reference it by path (the class cache may not be rebuilt on a bot box):
##   const TB := preload("res://scripts/story/test_bank.gd")
## DATA API (static, no node needed):
##   TB.draw(day:int, n:int = 10, topics:Array = [], ver:int = -1) -> Array
##       n question dicts {id, day, v, topic, q, opts (shuffled), a (index into the shuffled opts), say, tr}, in random order.
##       Never repeats a question that was already drawn (ids kept in save.json "test_bank".used) while unused ones are left.
##       Order of preference: 1) the day's current version (v = 0/1/2, rotating: each draw moves the day to the next version,
##       so a Retake gets a new set) 2) the day's other versions 3) review questions from EARLIER days with the same topics
##       4) only when the bank is exhausted: the day's least recently used questions (so a test is never empty).
##       topics = [] -> every topic of that day; unknown topics -> the whole day. ver >= 0 forces a version.
##   TB.questions(day, topics := []) -> Array      raw entries of a day (no marking)
##   TB.version(day) -> int                        version the next draw() of that day starts with (0..2)
##   TB.used_ids() -> Array / TB.is_used(id) / TB.mark_used(ids) / TB.reset(day := 0)   (0 = everything)
## RUNNER (phone test page, same rules as d2/d3_night_test.gd: notebook reminder once, narrator waits, Retake, the study
## tip when half or more are wrong, full TR, shared skip button):
##   var res: Array = await TB.run_test(host, phone, day, {"n": 10, "topics": [], "key": "TestBank_d4"})   # -> [score, total]
##   host = the room (needs caption(t, speak)); phone = main.phone / lr.room_phone.phone (already open).
extends Node

const DATA := "res://data/test_bank.json"
const SAVE_KEY := "test_bank"
const VERSIONS := 3
const NOTE_EN := "Get a notebook and a pencil. Let's take notes."
const NOTE_TR := "Bir defter ve kalem al. Hadi not alalım."
const ASK := "Choose the right words."
const ASK_TR := "Doğru kelimeleri seç."

static var _cache: Array = []

static func all() -> Array:
	if _cache.is_empty():
		var d = App.load_json(DATA)
		if d is Dictionary and d.get("questions") is Array: _cache = d.questions
	return _cache

static func _state() -> Dictionary:
	var s = App.load_save().get(SAVE_KEY, {})
	s = s.duplicate(true) if s is Dictionary else {}
	if not s.get("used") is Array: s["used"] = []
	if not s.get("ver") is Dictionary: s["ver"] = {}
	return s

static func used_ids() -> Array: return _state()["used"]
static func is_used(id: String) -> bool: return id in used_ids()

static func mark_used(ids: Array) -> void:
	var s := _state(); var u: Array = s["used"]
	for id in ids:
		var k := String(id); u.erase(k); u.append(k)   # most recently used last
	s["used"] = u; App.patch_save({SAVE_KEY: s})

static func reset(day := 0) -> void:
	var s := _state()
	if day <= 0: s = {"used": [], "ver": {}}
	else:
		var keep: Array = []
		for k in s["used"]:
			var q := _by_id(String(k))
			if q.is_empty() or int(q.get("day", 0)) != day: keep.append(k)
		s["used"] = keep; (s["ver"] as Dictionary).erase(str(day))
	App.patch_save({SAVE_KEY: s})

static func _by_id(id: String) -> Dictionary:
	for q in all():
		if String(q.get("id", "")) == id: return q
	return {}

static func version(day: int) -> int: return int(_state()["ver"].get(str(day), 0)) % VERSIONS

static func questions(day: int, topics: Array = []) -> Array:
	var out: Array = []
	for q in all():
		if int(q.get("day", 0)) == day and (topics.is_empty() or String(q.get("topic", "")) in topics): out.append(q)
	return out

static func draw(day: int, n := 10, topics: Array = [], ver := -1) -> Array:
	var s := _state()
	var used: Array = s["used"]
	var vk := str(day)
	var v: int = (int(s["ver"].get(vk, 0)) if ver < 0 else ver) % VERSIONS
	var mine := questions(day, topics)
	if mine.is_empty() and not topics.is_empty(): mine = questions(day)
	var tset: Array = topics.duplicate()
	if tset.is_empty():
		for q in mine:
			if not String(q.get("topic", "")) in tset: tset.append(String(q.get("topic", "")))
	var tiers: Array = []   # [questions, shuffle]
	for k in VERSIONS:
		var vv: int = (v + k) % VERSIONS
		tiers.append([mine.filter(func(q): return int(q.get("v", 0)) % VERSIONS == vv and not String(q.get("id", "")) in used), true])
	var rev: Array = []
	for q in all():
		if int(q.get("day", 0)) < day and String(q.get("topic", "")) in tset and not String(q.get("id", "")) in used: rev.append(q)
	tiers.append([rev, true])
	var old: Array = mine.duplicate()
	old.sort_custom(func(a, b): return used.find(String(a.get("id", ""))) < used.find(String(b.get("id", ""))))
	tiers.append([old, false])
	var picked: Array = []; var seen := {}
	for t in tiers:
		var list: Array = (t[0] as Array).duplicate()
		if t[1]: list.shuffle()
		for q in list:
			if picked.size() >= n: break
			var id := String(q.get("id", ""))
			if seen.has(id): continue
			seen[id] = true; picked.append(q)
		if picked.size() >= n: break
	# mark + rotate the version in one save write
	for q in picked:
		var id := String(q.get("id", "")); used.erase(id); used.append(id)
	s["used"] = used; s["ver"][vk] = (v + 1) % VERSIONS
	App.patch_save({SAVE_KEY: s})
	var out: Array = []
	for q in picked:
		var qq: Dictionary = (q as Dictionary).duplicate(true)
		var order: Array = range((q.opts as Array).size()); order.shuffle()
		var opts: Array = []
		for o in order: opts.append(q.opts[o])
		qq["opts"] = opts; qq["a"] = order.find(int(q.get("a", 0))); out.append(qq)
	out.shuffle()
	return out

## ------------------------------------------------------------------ runner (one phone test, Retake = a fresh draw)
static func run_test(host: Node, phone, day: int, opts := {}) -> Array:
	var t = load("res://scripts/story/test_bank.gd").new()
	return await t.run(host, phone, day, opts)

var ph; var host: Node; var Q: Array = []; var qi := 0; var score := 0
var _day := 0; var _n := 10; var _topics: Array = []; var _key := ""
var _note := false; var _suggested := false; var _busy := false; var _skipped := false
var retakes := 0
var _trs: Array = []
var _last_tr := false
signal finished(res: Array)

func run(h: Node, phone, d: int, opts := {}) -> Array:
	host = h; ph = phone; _day = d; _n = int(opts.get("n", 10)); _topics = opts.get("topics", []); _key = String(opts.get("key", "TestBank_d%d" % d))
	h.add_child(self)
	ph.visible = true
	if not ph.page in ["lesson", "quiz"]: ph.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	Q = draw(_day, _n, _topics); qi = 0; score = 0
	if Q.is_empty(): queue_free(); return [0, 0]
	ph.page = "quiz"   # phone.gd lock: no close / home / back-out while the test runs
	_question()
	var res: Array = await finished
	ph.page = "home"
	queue_free()
	return res

func _tr_on() -> bool: return App.tr_on()
func _trl(l: Label) -> Label: _trs.append(l); l.visible = _tr_on() and l.text.strip_edges() != ""; return l
func _process(_d: float) -> void:
	if _tr_on() != _last_tr:
		_last_tr = _tr_on(); _trs = _trs.filter(func(l): return is_instance_valid(l))
		for l in _trs: l.visible = _last_tr and l.text.strip_edges() != ""
func _cap(t: String) -> void: if host and host.has_method("caption"): host.caption(t, false)
func _say(t: String) -> void: Audio.say(t); _cap(t)

func _question() -> void:
	if _skipped: return
	Audio.cancel_group("lesson"); _trs = []; _busy = false
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 20)   # v33: full test page
	var q: Dictionary = Q[qi]
	if not _note:   # notebook-and-pencil reminder exactly once (Retake does not repeat it)
		_note = true; var nl = ph._l(NOTE_EN, 16, true, ph.MUTED); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(nl)
		var nt = ph._l(NOTE_TR, 14, false, ph.TR_C); nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(nt)); _say(NOTE_EN)
	var t = ph._l("Test %d / %d" % [qi + 1, Q.size()], 18, true, ph.MUTED); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var ql = ph._l(String(q.q), 48, true); ql.name = "Question"; ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ql.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(ql)
	var il = ph._l(ASK, 17, false, ph.MUTED); il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(il)
	var it = ph._l("%s  (%s)" % [ASK_TR, String(q.get("tr", ""))], 16, false, ph.TR_C); it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_trl(it))
	var row := HBoxContainer.new(); row.name = "Options"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 20); v.add_child(row)
	var fb = ph._l(" ", 24, true, ph.GREEN); fb.name = "Feedback"; fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; fb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(fb)
	var fbt = ph._l("", 17, false, ph.TR_C); fbt.name = "FeedbackTR"; fbt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(fbt))
	for i in (q.opts as Array).size():
		var b: Button = ph._btn(String(q.opts[i]), func(): pass, Vector2(260, 100), false, 34); b.name = "Opt%d" % i; row.add_child(b)
		var ii: int = i; b.pressed.connect(func(): _answer(ii, b, row, fb, fbt))
	_say(ASK)
	_enable_when_idle(row)
	StoryUI.add_skip_button(v, _skip_test)

func _enable_when_idle(row: Control) -> void:   # answers wait for the narrator
	for c in row.get_children(): (c as Button).disabled = true
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(row) and Audio.is_speaking() and Time.get_ticks_msec() - t0 < 15000: await get_tree().process_frame
	if is_instance_valid(row) and not _busy:
		for c in row.get_children(): (c as Button).disabled = false

func _mark(b: Button, c: Color, fc: Color) -> void:
	ph._style(b, c, fc); b.add_theme_stylebox_override("disabled", ph._sb(c, 18, 8)); b.add_theme_color_override("font_disabled_color", fc)

func _answer(i: int, b: Button, row: Control, fb: Label, fbt: Label) -> void:
	if _busy or b.disabled or ph.page != "quiz": return
	_busy = true
	var q: Dictionary = Q[qi]
	var right := i == int(q.a)
	if right: score += 1
	for k in row.get_child_count():
		var cb: Button = row.get_child(k); cb.disabled = true
		if k == int(q.a): _mark(cb, ph.GREEN, Color.WHITE)
		elif k == i: _mark(cb, Color(1.0, 0.86, 0.86), ph.RED)
		else: _mark(cb, Color(0.85, 0.87, 0.92), Color(0.6, 0.62, 0.68))
	if right: Audio.good(); fb.add_theme_color_override("font_color", ph.GREEN); fb.text = "That is right!  " + String(q.say); fbt.text = "Doğru!  " + String(q.get("tr", ""))
	else: Audio.bad(); fb.add_theme_color_override("font_color", ph.RED); fb.text = "Not quite.  " + String(q.say); fbt.text = "Tam değil.  " + String(q.get("tr", ""))
	_last_tr = not _tr_on()   # refresh TR visibility for the new feedback text
	_say("That is right!" if right else "Not quite."); Audio.say(String(q.say))
	await get_tree().create_timer(1.0, false).timeout
	await Audio.wait_idle(15.0)
	await get_tree().create_timer(0.3, false).timeout
	if qi < Q.size() - 1: qi += 1; _question()
	else: _score_page()

func _skip_test() -> void:
	if _skipped: return
	_skipped = true; StoryUI.mark_skipped(_key); finished.emit([Q.size(), Q.size()])

func _retake() -> void:
	Audio.click(); retakes += 1
	var nq := draw(_day, _n, _topics)   # a fresh set: next version, never the questions already used
	if not nq.is_empty(): Q = nq
	qi = 0; score = 0; _suggested = false; _question()

func _score_page() -> void:
	if _skipped: return
	_trs = []
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14)
	var tot := Q.size()
	for row in [["Your score", 22, ph.MUTED, true], ["%d / %d" % [score, tot], 96, ph.GREEN, true, "Score"], ["Puanın: %d / %d" % [score, tot], 18, ph.TR_C, false]]:
		var l = ph._l(row[0], row[1], row[3], row[2])
		if row.size() > 4: l.name = row[4]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l if row[2] != ph.TR_C else _trl(l))
	if tot - score >= ceili(tot / 2.0):   # half or more wrong: gentle study tip (never forced, no pass mark)
		var sg = ph._l("You should study the grammar again.", 20, true, ph.INK); sg.name = "GrammarTip"; sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sg)
		var st = ph._l("Dilbilgisi konusunu tekrar çalışmalısın.", 15, false, ph.TR_C); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(st))
		if not _suggested: _suggested = true; _say("You should study the grammar again.")
	var bar := HBoxContainer.new(); bar.name = "ScoreBar"; bar.alignment = BoxContainer.ALIGNMENT_CENTER; bar.add_theme_constant_override("separation", 14); v.add_child(bar)
	var rb: Button = ph._btn("Retake the test", _retake, Vector2(200, 64), false, 17); rb.name = "Retake"; bar.add_child(rb)
	var cb: Button = ph._btn("Continue", func(): Audio.click(); finished.emit([score, tot]), Vector2(180, 64), true, 17); cb.name = "ScoreContinue"; bar.add_child(cb)
	ph.dock_bar(bar)   # v33: Retake bottom-left, Continue bottom-right (phone.gd test page dock)
	var bt = ph._l("Testi tekrarla  ·  Devam", 14, false, ph.TR_C); bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(bt))
	_last_tr = not _tr_on()
