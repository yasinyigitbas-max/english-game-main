## v33 (red): DAY 4 / DAY 7 BREAKFAST with the family (living room), modelled on day2_morning.gd (no phone lesson):
## Life.guide_to pan to the table -> the player walks to the free chair by himself -> sits, eats -> the family reviews the
## PREVIOUS day's English (3 TestBank questions of that day, centre panel, the answer spoken as "Me: ...") -> the day's
## data dialogue (data/day4.json / day7.json "breakfast": the reason for the outing) -> stand up, the table clears,
## the family goes to the TV. The south wall is force-faded for the whole scene.
## ENTRY (Day4Routine / Day7Routine): var b = load(this).new(); b.lr = lr; b.data_path = ...; lr.add_child(b); await b.run()
extends Node

const T := preload("res://scripts/story/day4_talk.gd")
const TB := preload("res://scripts/story/test_bank.gd")
var lr: Node
var data_path := "res://data/day4.json"
var D := {}

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

static func load_lines(xtr: Dictionary, path: String) -> void:
	var d = App.load_json(path)
	if d is Dictionary: for k in d.get("lines", {}): xtr[k] = d.lines[k]

## previous-day review questions: the day before (blue's day 6 for day 7), else the latest earlier day with bank entries
func _review_qs(day: int, n: int) -> Array:
	for d in range(int(D.get("review_day", day - 1)), 1, -1):
		var qs: Array = TB.questions(d)
		if qs.is_empty(): continue
		qs = qs.duplicate(); qs.shuffle()
		return qs.slice(0, n)
	return []

func run() -> void:
	D = App.load_json(data_path); D = D if D is Dictionary else {}
	load_lines(lr.XTR, data_path)
	Life.event("breakfast")
	var hs: Array = lr.humans()
	var bk := "Have breakfast with your family." if not hs.is_empty() else "Have breakfast."
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	if lr.wall_fade: lr.wall_fade.force_fade(true)
	await Life.guide_to({"pos": lr.DINE_C + Vector3(0.2, 2.0, 2.2), "at": lr.DINE_C + Vector3(0, 0.9, 0)}, bk, {"tr": T.tr_of(bk)})
	lr.mode = "busy"
	await Audio.wait_idle(12.0)
	var n: int = hs.size(); var seat := ""
	if n < lr.DINE_CHAIRS.size():
		var c: Array = lr.DINE_CHAIRS[n]; seat = c[0]
		if n >= 4: lr._dining_chair(lr.DINE_C + c[1], c[2], lr.C_CREAM, lr.breakfast_root); lr._place_setting(n, lr.breakfast_root)
		var f := Vector3(sin(c[2]), 0, cos(c[2]))
		lr.SEATS[seat] = {"hips": lr.DINE_C + c[1] - f * (0.03 + lr._body_back(lr.hero)), "top": 0.475, "yaw": c[2], "obj": "dining"}
		lr._build_grid_obstacles_refresh()
		lr.cam_shot = lr._breakfast_frame(lr.DINE_C + c[1], f)
		await _w(0.8)
		await lr.walk_to(lr.sit_spot(seat), lr.SEATS[seat].yaw)
		lr.caption("I am sitting at the table.")
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
	await Audio.wait_idle(12.0); await _w(0.6)
	lr.caption("I am having breakfast."); lr.eat_tw = lr._breakfast_loop(lr.hero, lr.SEATS[seat].yaw if seat != "" else 0.0, 0)
	await Audio.wait_idle(12.0); await _w(1.0)
	_snap(seat)
	var a: Dictionary = hs[0] if not hs.is_empty() else {}
	var b: Dictionary = hs[1 % hs.size()] if not hs.is_empty() else {}
	# ---- review of the previous day's English
	var qs := _review_qs(int(D.get("day", 4)), 3)
	if not qs.is_empty():
		await T.fam(lr, a, "Good morning! Let's review yesterday's English.")
		var good := 0
		for q in qs:
			var ok: bool = await T.choose(lr, q)
			if ok: good += 1
		await T.fam(lr, b, "Well done!" if good >= 2 else "Good try! Let's practise more tonight.")
	# ---- the day's dialogue (leads into the outing)
	for e in D.get("breakfast", []):
		var en := String(e.get("en", "")); var who := String(e.get("who", "nar"))
		if who == "me": await T.me(lr, en, String(e.get("tr", "")))
		elif who.begins_with("fam") and not hs.is_empty(): await T.fam(lr, hs[int(who.trim_prefix("fam")) % hs.size()], en, String(e.get("tr", "")))
		else: await T.line(lr, en)
	App.patch_save({"breakfast_done": true, "breakfast_day": App.day})
	lr.breakfast_done = true
	if lr.eat_tw: lr.eat_tw.kill()
	await T.line(lr, "Breakfast is over.")
	if String(lr.S.seat) != "":
		for bn in ["UpperArm.R", "LowerArm.R", "UpperArm.L", "LowerArm.L", "Neck"]: lr.hero.bone_offsets.erase(bn)
		await lr.stand_up()
	lr._clear_table(true)
	await _w(0.8); await Audio.wait_idle(12.0)
	lr.cam_shot = {}
	if lr.wall_fade: lr.wall_fade.force_fade(false)
	if not hs.is_empty(): await lr.family_to_tv()
	lr.mode = "play"; lr._update_hand()

## breakfast polaroid (d4_breakfast / d7_breakfast): offscreen camera on the player at the table
func _snap(seat: String) -> void:
	var key := String(D.get("breakfast_photo", ""))
	if key == "" or seat == "": return
	var h: Vector3 = lr.hero.global_position
	var at := h + Vector3(0, 0.8, 0)
	var y: float = float(lr.SEATS[seat].yaw)
	var eye := at + Vector3(sin(y), 0, cos(y)) * 2.0 + Vector3(0.5, 0.5, 0)
	Life.snap_from(key, Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), 45.0)
