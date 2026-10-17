## vocabtest: end-of-day-1 vocabulary test (runs right after the past-simple dream / flashbacks).
## 20 objects from the day (real in-game 3D props, shown live in a SubViewport) -> "What can you do with it?"
## 4 options, exactly 2 right + 2 wrong (multi-select). Follows the universal test rules of phone.gd (house.24-27):
## 3 rotating versions (save "quiz_ver"), options shuffled every time, notebook prompt once, narrator never cut,
## next question waits for the narrator, score page with optional study tip (>= half wrong) + Retake (next version) + Continue,
## phone locked (page "quiz") until Continue. Point = both right options picked and no wrong one (first try only, like phone.gd).
extends Node

const DATA := "res://data/vocab_test.json"
const KEY := "VocabTest"
const NOTE_EN := "Get a notebook and a pencil. Let's take notes."
const NOTE_TR := "Bir defter ve kalem al. Hadi not alalım."
var ph; var Q: Array = []; var qi := 0; var score := 0
var picked := {}; var _note := false; var _suggested := false
var _skipped: = false
var _trs: Array = []   # TR labels: shown only while the HUD TR button is on (main.gd S.tr / tr_btn), like the caption TR line
signal finished(score: int, total: int)

func run(host: Node, phone) -> Array:
	ph = phone; host.add_child(self)
	ph.visible = true
	if not ph.page in ["lesson", "quiz"]: ph.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	if ph.main and ph.main.get("tr_btn") and not ph.main.tr_btn.pressed.is_connected(_tr_refresh): ph.main.tr_btn.pressed.connect(_tr_refresh)
	_pick_version(); qi = 0; score = 0
	ph.page = "quiz"   # phone.gd lock: no close / home / back-out while a test runs
	_question()
	var res = await finished
	if ph.main and ph.main.get("tr_btn") and ph.main.tr_btn.pressed.is_connected(_tr_refresh): ph.main.tr_btn.pressed.disconnect(_tr_refresh)
	ph.page = "home"
	queue_free()
	return res

var version: = 0
func _pick_version(next: = false) -> void :
	var d: Dictionary = App.load_json(DATA)
	var vers: Array = []
	for k in ["quiz", "quiz_b", "quiz_c"]: if d.get(k, []) is Array and not d.get(k, []).is_empty(): vers.append(d[k])
	var qv = App.load_save().get("quiz_ver", {})
	if not qv is Dictionary: qv = {}
	var vi: int = int(qv.get(KEY, 0)) % vers.size()
	if next: vi = (version + 1) % vers.size()
	version = vi
	Q = []
	for q in vers[vi]:
		var qq: Dictionary = q.duplicate(true); var order := range(4); order.shuffle()
		var opts := []; var ok := []
		for o in order: opts.append(q.opts[o]); ok.append(q.a.any(func(x): return int(x) == int(o)))   # JSON numbers are floats: compare as int
		qq.opts = opts; qq.ok = ok; Q.append(qq)
	Q.shuffle()
	qv = qv.duplicate(); qv[KEY] = (vi + 1) % vers.size(); App.patch_save({"quiz_ver": qv})

func _tr_on() -> bool: return true   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
func _trl(l: Label) -> Label: _trs.append(l); l.visible = _tr_on() and l.text.strip_edges() != ""; return l
func _tr_refresh() -> void:
	_trs = _trs.filter(func(l): return is_instance_valid(l))
	for l in _trs: l.visible = _tr_on() and l.text.strip_edges() != ""
func _cap(t: String) -> void: if ph.main: ph.main.caption(t, false)
## caption + narrator; Audio.say queues (global voice queue never cuts the current line)
func _say(t: String) -> void: Audio.say(t); _cap(t)

func _question() -> void:
	if _skipped: return
	Audio.cancel_group("lesson"); _trs = []
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 8)
	var q: Dictionary = Q[qi]; picked = {}
	if not _note:   # rule: notebook-and-pencil reminder exactly once, at the start of the test
		_note = true; var n = ph._l(NOTE_EN, 15, true, ph.MUTED); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(n)
		_trl(StoryUI.tr_row(v, n, NOTE_TR, 15)); _say(NOTE_EN)   # ui33: right-column TR
	var t = ph._l("Vocabulary test %d / %d" % [qi + 1, Q.size()], 16, true, ph.MUTED); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var mid := HBoxContainer.new(); mid.alignment = BoxContainer.ALIGNMENT_CENTER; mid.add_theme_constant_override("separation", 20); v.add_child(mid)
	mid.add_child(_prop_view(String(q.scene)))
	var right := VBoxContainer.new(); right.add_theme_constant_override("separation", 8); right.custom_minimum_size.x = 480; mid.add_child(right)
	var en := "What can you do with %s?" % q.obj
	var ql = ph._wrap(en, 32, 480, true); ql.name = "Question"; right.add_child(ql)
	right.add_child(ph._wrap("Choose two answers.", 15, 480, false, ph.MUTED))
	right.add_child(_trl(ph._wrap("%s ile ne yapabilirsin? İki doğru cevabı seç." % String(q.tr).capitalize(), 15, 480, false, ph.TR_C)))
	var grid := GridContainer.new(); grid.name = "Options"; grid.columns = 2; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); right.add_child(grid)
	var fb = ph._wrap(" ", 20, 480, true, ph.GREEN); fb.name = "Feedback"; right.add_child(fb)
	var fbt = _trl(ph._wrap("", 15, 480, false, ph.TR_C)); fbt.name = "FeedbackTR"; right.add_child(fbt)
	for i in 4:
		var b: Button = ph._btn(q.opts[i], func(): pass, Vector2(230, 76), false, 20); b.name = "Opt%d" % i
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.toggle_mode = true; grid.add_child(b)
		var ii := i; b.toggled.connect(func(on): _toggle(ii, on, b, grid, fb, fbt))
	_say(en)
	_enable_when_idle(grid)
	StoryUI.add_skip_button(v, _skip_test)

func _enable_when_idle(row: Control) -> void:   # phone.gd house.24.1: buttons wait for the narrator
	for c in row.get_children(): (c as Button).disabled = true
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(row) and Audio.is_speaking() and Time.get_ticks_msec() - t0 < 15000: await get_tree().process_frame
	if is_instance_valid(row):
		for c in row.get_children(): (c as Button).disabled = false

## phone.gd _style() greys a disabled button: keep the green / red result colours on the locked buttons
func _mark(b: Button, c: Color, fc: Color) -> void:
	ph._style(b, c, fc); b.add_theme_stylebox_override("disabled", ph._sb(c, 18, 8)); b.add_theme_color_override("font_disabled_color", fc)

## resolves as soon as TWO options are picked (any order, right or wrong); point only if both picks are right
static func judge(ok: Array, picks: Array) -> bool:
	return picks.size() == 2 and ok[picks[0]] and ok[picks[1]]

func _toggle(i: int, on: bool, b: Button, grid: Control, fb: Label, fbt: Label) -> void:
	Audio.click()
	var q: Dictionary = Q[qi]
	if on: picked[i] = true
	else: picked.erase(i)
	ph._style(b, Color(0.85, 0.9, 1.0) if on else Color.WHITE, ph.INK)
	if picked.size() < 2: return
	var right := judge(q.ok, picked.keys())
	if right: score += 1
	var both: Array = []; var both_tr: Array = []
	for k in 4:
		var cb: Button = grid.get_child(k); cb.disabled = true
		if q.ok[k]: _mark(cb, ph.GREEN, Color.WHITE); both.append(q.opts[k]); both_tr.append(q.tr_opts[k])
		elif picked.has(k): _mark(cb, Color(1.0, 0.86, 0.86), ph.RED)
		else: _mark(cb, Color(0.85, 0.87, 0.92), Color(0.6, 0.62, 0.68))
	var line := "You can %s and %s." % [both[0], both[1]]
	var tr_line := "Şunları yapabilirsin: %s ve %s." % [both_tr[0], both_tr[1]]
	if right:
		Audio.good(); fb.add_theme_color_override("font_color", ph.GREEN)
		fb.text = "That is right!  " + line; fbt.text = "Doğru!  " + tr_line
		_say("That is right!")
	else:
		# wrong reply reveals the two right answers (green); "Not quite." is shown, the spoken part is the Piper clip "You can A and B."
		Audio.bad(); fb.add_theme_color_override("font_color", ph.RED)
		fb.text = "Not quite.  " + line; fbt.text = "Tam değil.  " + tr_line
		_say("Not quite.")   # v29.1: ljspeech clip (voice_006)
	_tr_refresh(); _say(line)
	await get_tree().create_timer(1.0, false).timeout
	await Audio.wait_idle(15.0)   # never move on before the narrator has finished
	await get_tree().create_timer(0.3, false).timeout
	if qi < Q.size() - 1: qi += 1; _question()
	else: _score_page()


func _skip_test() -> void :
	if _skipped: return
	_skipped = true;StoryUI.mark_skipped(KEY);finished.emit([Q.size(), Q.size()])

func _score_page() -> void:
	if _skipped: return
	_trs = []
	var v: VBoxContainer = ph._clear(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14)
	var tot := Q.size()
	for row in [["Your score", 22, ph.MUTED, true], ["%d / %d" % [score, tot], 96, ph.GREEN, true, "Score"], ["Puanın: %d / %d" % [score, tot], 18, ph.TR_C, false]]:
		var l = ph._l(row[0], row[1], row[3], row[2])
		if row.size() > 4: l.name = row[4]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l if row[2] != ph.TR_C else _trl(l))
	if tot - score >= ceili(tot / 2.0):   # optional, never forced
		var sg = ph._l("You should study the words again.", 20, true, ph.INK); sg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sg)
		var st = ph._l("Kelimeleri tekrar çalışmalısın.", 15, false, ph.TR_C); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_trl(st))
		if not _suggested: _suggested = true; _say("You should study the words again.")
	var bar := HBoxContainer.new(); bar.name = "Options"; bar.alignment = BoxContainer.ALIGNMENT_CENTER; bar.add_theme_constant_override("separation", 14); v.add_child(bar)
	bar.add_child(ph._btn("Retake the test", func(): Audio.click();_pick_version(true);qi = 0;score = 0;_suggested = false;_question(), Vector2(200, 64), false, 17))
	var cb: Button = ph._btn("Continue", func(): Audio.click(); finished.emit([score, tot]), Vector2(180, 64), true, 17); cb.name = "ScoreContinue"; bar.add_child(cb)
	ph.dock_bar(bar)   # v33: Retake bottom-left, Continue bottom-right (phone.gd test page dock)
	var bt = ph._l("Retake the test  ·  Continue", 15, false, ph.MUTED); v.add_child(bt); _trl(StoryUI.tr_row(v, bt, "Testi tekrarla  ·  Devam", 15))

## the real in-game prop, camera fitted to its AABB (centred, ~12% padding), 3-point light, plain contrasting backdrop
const VIEW := 400   # v33: bigger on the full-height test page (was 340)
static func prop_aabb(n: Node, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB(); var has := false
	var t: Transform3D = xf * (n as Node3D).transform if n is Node3D else xf
	if n is VisualInstance3D and not (n is Light3D) and not (n is Camera3D):
		var a: AABB = t * (n as VisualInstance3D).get_aabb()
		if a.size.length() > 0.0: out = a; has = true
	for c in n.get_children():
		var ca := prop_aabb(c, t)
		if ca.size.length() > 0.0: out = ca if not has else out.merge(ca); has = true
	return out

static func build_stage(path: String, px: int) -> SubViewport:
	var vp := SubViewport.new(); vp.own_world_3d = true; vp.size = Vector2i(px, px); vp.msaa_3d = Viewport.MSAA_4X
	var res = load(path)
	var holder := Node3D.new(); holder.name = "Spin"; vp.add_child(holder)
	var obj := Node3D.new(); holder.add_child(obj)
	if res is PackedScene: obj.add_child(res.instantiate())
	elif res is Mesh: var mi := MeshInstance3D.new(); mi.mesh = res; obj.add_child(mi)
	var ab := prop_aabb(obj)
	if ab.size.z > ab.size.x * 1.2:   # long side towards the camera (toothbrush, remote) -> turn it sideways so it reads at first sight
		holder.remove_child(obj); var turn := Node3D.new(); turn.rotation.y = PI / 2; holder.add_child(turn); turn.add_child(obj)
		ab = Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO) * ab
	obj.position = -ab.get_center() if obj.get_parent() == holder else Basis(Vector3.UP, -PI / 2) * -ab.get_center()
	# radius of the bounding sphere -> distance so it stays inside the frame while turning; 12% padding
	var r: float = maxf(ab.size.length() * 0.5, 0.01)
	var cam := Camera3D.new(); cam.fov = 30.0; cam.near = r * 0.05; cam.far = r * 40.0
	var dist: float = r / sin(deg_to_rad(cam.fov * 0.5)) / 0.88
	var dir := Vector3(0, 0.38, 1).normalized()
	cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * dist); vp.add_child(cam)
	for L in [[Vector3(-35, -40, 0), 0.85, true], [Vector3(-15, 50, 0), 0.35, false], [Vector3(-30, 170, 0), 0.7, false]]:   # key / fill / rim
		var d := DirectionalLight3D.new(); d.rotation_degrees = L[0]; d.light_energy = L[1]; d.shadow_enabled = L[2]; vp.add_child(d)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2, 0.27, 0.4)   # plain dark slate backdrop: white / pastel props stand out
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.62, 0.68); e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; vp.add_child(env)
	return vp

func _prop_view(path: String) -> Control:
	var frame := PanelContainer.new(); frame.add_theme_stylebox_override("panel", ph._sb(Color(0.31, 0.42, 0.93), 18, 4))
	var box := SubViewportContainer.new(); box.custom_minimum_size = Vector2(VIEW, VIEW); box.stretch = true; frame.add_child(box)
	var vp := build_stage(path, VIEW); box.add_child(vp)
	var spin: Node3D = vp.get_node("Spin")
	var tw := spin.create_tween().set_loops(); tw.tween_property(spin, "rotation:y", TAU, 10.0).from(0.0)
	return frame
