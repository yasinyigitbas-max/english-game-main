## v33 (red): DAY 4 BEDTIME (bedroom, main.gd as `m`), extends bedtime.gd (same go-to-bed cinematic, lying lock, StoryUI
## dream captions). Dream polaroids of the day (data "recap" in data/day4.json, real snapshots or day4_polaroids.gd stills)
## -> 10-question TestBank test (TB.run_test: no repeats, Retake = new set, study tip, full TR, notebook reminder once)
## -> sleep -> DAY 5: silent "Day 5" title, wake with only "I'm waking up." + "I'm getting up." -> story.d5 = "start";
## blue's day-5 code takes over (_handoff tries blue's day-5 entry points defensively).
## day7_bedtime.gd extends this (day 7 -> day 8).
## ENTRY: bedtime.gd hook_bedroom (story.d4_bed_pending and not d4_bedtime_done).
extends "res://scripts/story/bedtime.gd"

const TB := preload("res://scripts/story/test_bank.gd")
var day_n := 4
var data_path := "res://data/day4.json"
var D4 := {}

func _data() -> Dictionary:
	if D4.is_empty():
		var d = App.load_json(data_path); D4 = d if d is Dictionary else {}
	return D4

func _recap_list() -> Array:
	var sv := _story(); var out: Array = []
	for r in _data().get("recap", []):
		if r.size() > 2 and String(r[2]) != "" and not bool(sv.get(String(r[2]), false)): continue   # [key, caption, needed story flag]
		out.append([String(r[0]), String(r[1])])
	return out

func _dream() -> void:
	night = day_n
	recap = _recap_list()
	var dim := ColorRect.new(); dim.color = Color(0.25, 0.2, 0.45, 0.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(dim)
	var t := create_tween(); t.tween_property(dim, "color:a", 0.6, 1.0)
	var keys: Array = []; for r in recap: keys.append(r[0])
	await load("res://scripts/story/day4_polaroids.gd").ensure_d47(self, keys)
	if t.is_running(): await t.finished
	await _dline("I am dreaming about my day.")
	var row := HBoxContainer.new(); row.name = "D2Polaroids"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT); row.offset_top = 150; row.offset_bottom = -150; row.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(row)
	for i in recap.size():
		var card := _polaroid(String(recap[i][0]), String(recap[i][1]), i)
		card.modulate.a = 0.0; row.add_child(card)
		var ct := create_tween(); ct.tween_property(card, "modulate:a", 1.0, 0.5)
		var tl: Control = card.get_child(0)
		ct.parallel().tween_property(tl, "scale", Vector2.ONE, 0.6).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(tl, "rotation_degrees", [-4.0, 3.0, -2.0, 4.0, -3.0][i % 5], 0.6).from(0.0); await ct.finished
		await _dline(String(recap[i][1]))
	var dl := String(_data().get("dream_line", ""))
	if dl != "": await _dline(dl)
	await _w(1.2)
	var ft := create_tween(); ft.tween_property(row, "modulate:a", 0.0, 1.0); ft.parallel().tween_property(dim, "color:a", 0.0, 1.0); await ft.finished
	row.queue_free(); dim.queue_free(); ui.hide_caption()
	_flag("d%d_recap" % day_n, keys)

func _test() -> void:
	await _dline("Now a test about my day. Ten questions.")
	ui.hide_caption()
	var ph = m.phone
	ph.visible = true; ph.open(Rect2(), "home"); await _w(0.5)
	var res: Array = await TB.run_test(m, ph, day_n, {"n": 10, "key": "TestBank_d%d" % day_n})
	_flag("d%d_night_score" % day_n, res)
	await Audio.wait_idle(15.0)
	await ph.close(true)

func _sleep() -> void:
	m.cam_shot = {"pos": m.OBJ.bed.focus + Vector3(0.9, 1.3, 0.9), "at": m.OBJ.bed.focus + Vector3(-0.4, -0.15, 0)}
	await _dline("Good night!")
	m.S.lamp = "off"; m.S.ceiling = "off"; m.S.desklamp = "off"; m._apply_states(); Audio.sfx("metalClick", -6.0)
	bed_lock = false; m.sleep_pose()   # build 3.2 (v33.1): the real sleep clip at every bedtime (days 4 + 7), as on day 2
	await _dline("I am sleeping.")
	await _w(2.5)
	ui.hide_caption()
	var black := ColorRect.new(); black.color = Color(0.05, 0.05, 0.12, 0.0); black.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(black)
	var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 2.0); await tw.finished
	m.end_sleep_pose(); _bed_xf = m.hero.transform; bed_lock = true   # under the black: the flat pose back for the get-up
	var nd := day_n + 1
	_flag("d%d_bedtime_done" % day_n, true); _flag("d%d_bed_pending" % day_n, false); _flag("d%d" % day_n, "done"); _flag("d%d" % nd, "start")
	Life.advance_day(true)   # next day, 00:00
	if WorldState.day != nd:
		WorldState.day = nd; App.day = nd; App.patch_save({"day": nd})
	await _w(1.2)
	Life.event("morning")
	m.S.ceiling = "on"; m._apply_states()
	tw = create_tween(); tw.tween_property(black, "color:a", 0.0, 1.5); await tw.finished
	black.queue_free()
	await _day_title(false)   # silent "Day N" title
	m.cam_shot = {}
	bed_lock = false
	await _wake_simple()      # only "I'm waking up." then "I'm getting up."
	m.mode = "play"; m._update_hand()
	await _handoff()

## DAY 5 is blue's. story.d5 = "start" is set; if blue's day-5 script is in the build, start it (any of these entry points).
func _handoff() -> void:
	for p in ["res://scripts/story/day5_routine.gd", "res://scripts/story/day5_morning.gd", "res://scripts/story/day5.gd"]:
		if not ResourceLoader.exists(p): continue
		var s: Script = load(p)
		if s == null: continue
		for fn in ["start", "attach"]:
			if _has_static(s, fn): s.call(fn, get_tree()); return
	# no blue code in this build: the next step with the standard pan + voice (v33 QA: _advance gave it without a pan)
	await Audio.wait_idle(8.0)
	var f: Vector3 = m.OBJ.door_s.focus
	await Life.guide_to({"pos": f + Vector3(0.4, 1.0, -2.4), "at": f}, "Go to the living room.", {"tr": "Oturma odasına git.", "id": "Go to the living room.",
		"list": [{"id": "Go to the living room.", "en": "Go to the living room.", "tr": "Oturma odasına git."}]})
	if m.has_method("_advance"): m._advance(false)

static func _has_static(s: Script, fn: String) -> bool:
	for md in s.get_script_method_list():
		if String(md.get("name", "")) == fn: return true
	return false
