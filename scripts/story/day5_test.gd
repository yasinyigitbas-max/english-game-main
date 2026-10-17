## v33 (blue): days 5 + 6 bedtime test (10 questions) = red's d2_night_test.gd (universal test rules: 3 rotating versions, shuffled
## answers, Retake = next version, grammar tip at half or more wrong, no pass mark, TR feedback, narrator reads, notebook reminder once,
## phone locked (page "quiz"), StoryUI.add_skip_button). Questions come from questions_for(version) = Day56Bank (red's shared bank).
extends Node


var key := "Day5Bed"
var questions_for: Callable   # version -> Array (day5_routine.gd _bedtime_questions -> Day56Bank)
const NOTE_EN := "Get a notebook and a pencil. Let's take notes."
const NOTE_TR := "Bir defter ve kalem al. Hadi not alalım."
const ASK := "Choose the right words."
var ph; var host: Node; var Q: Array = []; var qi := 0; var score := 0
var _note := false; var _suggested := false; var _busy := false
var retakes := 0
var _skipped := false   # skip-test
var _trs: Array = []
signal finished(res: Array)

func run(h: Node, phone) -> Array:
	host = h; ph = phone; h.add_child(self)
	ph.visible = true
	if not ph.page in ["lesson", "quiz"]: ph.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	_pick_version(); qi = 0; score = 0
	ph.page = "quiz"   # phone.gd lock: no close / home / back-out while the test runs
	_question()
	var res: Array = await finished
	ph.page = "home"
	queue_free()
	return res

func _pick_version(next := false) -> void:   # v30.5: next = Retake -> always the following version
	var nv := 3
	var qv = App.load_save().get("quiz_ver", {})
	if not qv is Dictionary: qv = {}
	var vi: int = int(qv.get(key, 0)) % nv
	if next: vi = (version + 1) % nv
	var src: Array = questions_for.call(vi) if questions_for.is_valid() else []
	Q = []
	for q in src:
		var qq: Dictionary = q.duplicate(true); var order := range(q.opts.size()); order.shuffle()
		var opts := []; for o in order: opts.append(q.opts[o])
		qq.opts = opts; qq.a = order.find(int(q.a)); Q.append(qq)
	Q.shuffle()
	qv = qv.duplicate(); qv[key] = (vi + 1) % nv; App.patch_save({"quiz_ver": qv})
	version = vi; print("D56T pick next=", next, " vi=", vi, " n=", Q.size(), " src=", load("res://scripts/story/day5_bank.gd").source())

var version := 0
func _tr_on() -> bool: return App.tr_on()   # v30.5: single TR flag
func _trl(l: Label) -> Label: _trs.append(l); l.visible = _tr_on() and l.text.strip_edges() != ""; return l
var _last_tr := false
func _process(_d: float) -> void:
	if _tr_on() != _last_tr:
		_last_tr = _tr_on(); _trs = _trs.filter(func(l): return is_instance_valid(l))
		for l in _trs: l.visible = _last_tr and l.text.strip_edges() != ""
func _cap(t: String) -> void: if host and host.has_method("caption"): host.caption(t, false)
func _say(t: String) -> void: Audio.say(t); _cap(t)

func _question() -> void:
	if _skipped: return   # skip-test
	Audio.cancel_group("lesson"); _trs = []; _busy = false
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12)
	var q: Dictionary = Q[qi]
	if not _note:   # notebook-and-pencil reminder exactly once (Retake does not repeat it)
		_note = true; var n = ph._l(NOTE_EN, 16, true, ph.MUTED); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(n)
		var nt = ph._l(NOTE_TR, 14, false, ph.TR_C); nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(nt)); _say(NOTE_EN)
	var t = ph._l("Test %d / %d" % [qi + 1, Q.size()], 18, true, ph.MUTED); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var ql = ph._l(q.q, 40, true); ql.name = "Question"; ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ql)
	var il = ph._l(ASK, 17, false, ph.MUTED); il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(il)
	var it = ph._l("Doğru kelimeleri seç.  (%s)" % String(q.get("tr", "")), 16, false, ph.TR_C); it.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(it))
	var row := HBoxContainer.new(); row.name = "Options"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 20); v.add_child(row)
	var fb = ph._l(" ", 24, true, ph.GREEN); fb.name = "Feedback"; fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(fb)
	var fbt = ph._l("", 17, false, ph.TR_C); fbt.name = "FeedbackTR"; fbt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(fbt))
	for i in q.opts.size():
		var b: Button = ph._btn(q.opts[i], func(): pass, Vector2(230, 76), false, 28); b.name = "Opt%d" % i; row.add_child(b)
		var ii: int = i; b.pressed.connect(func(): _answer(ii, b, row, fb, fbt))
	_say(ASK)
	_enable_when_idle(row)
	StoryUI.add_skip_button(v, _skip_test)   # skip-test

func _enable_when_idle(row: Control) -> void:   # phone.gd house.24.1: answers wait for the narrator
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
	await Audio.wait_idle(15.0)   # never move on before the narrator has finished
	await get_tree().create_timer(0.3, false).timeout
	if qi < Q.size() - 1: qi += 1; _question()
	else: _score_page()

## skip-test: end now with full marks, same finished signal as the score page's Continue (no tip, no score page)
func _skip_test() -> void:
	if _skipped: return
	_skipped = true; StoryUI.mark_skipped(key); finished.emit([Q.size(), Q.size()])

func _score_page() -> void:
	if _skipped: return   # skip-test
	_trs = []
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14)
	var tot := Q.size()
	for row in [["Your score", 22, ph.MUTED, true], ["%d / %d" % [score, tot], 60, ph.GREEN, true, "Score"], ["Puanın: %d / %d" % [score, tot], 18, ph.TR_C, false]]:
		var l = ph._l(row[0], row[1], row[3], row[2])
		if row.size() > 4: l.name = row[4]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l if row[2] != ph.TR_C else _trl(l))
	if tot - score >= ceili(tot / 2.0):   # gentle, optional - never forced, no pass mark
		var sg = ph._l("You should study the grammar again.", 20, true, ph.INK); sg.name = "GrammarTip"; sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sg)
		var st = ph._l("Dilbilgisi konusunu tekrar çalışmalısın.", 15, false, ph.TR_C); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(st))
		if not _suggested: _suggested = true; _say("You should study the grammar again.")
	var bar := HBoxContainer.new(); bar.name = "ScoreBar"; bar.alignment = BoxContainer.ALIGNMENT_CENTER; bar.add_theme_constant_override("separation", 14); v.add_child(bar)
	var rb: Button = ph._btn("Retake the test", func(): Audio.click(); retakes += 1; _pick_version(true); qi = 0; score = 0; _suggested = false; _question(), Vector2(200, 64), false, 17); rb.name = "Retake"; bar.add_child(rb)
	var cb: Button = ph._btn("Continue", func(): Audio.click(); finished.emit([score, tot]), Vector2(180, 64), true, 17); cb.name = "ScoreContinue"; bar.add_child(cb)
	var bt = ph._l("Testi tekrarla  ·  Devam", 14, false, ph.TR_C); bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(bt))
	_last_tr = not _tr_on()
