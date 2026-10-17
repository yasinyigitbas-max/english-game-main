## v32c (red): DAY 3 EVENING - the family couch talk about day 3 (modelled on day2_evening.gd).
## Runs when the player is home after BOTH the cafe and the shop (story.d3_cafe + story.d3_shop, set by day3_morning.gd;
## story.d3 = "home" / "done").
## ENTRY:  Day3Evening.start(get_tree())   (static, idempotent; plays once, flag story.d3_couch_done)
##   hooked from livingroom.gd _intro() (one line). A continued game with story.d3_bed_pending only re-shows "Go to bed.".
## Flow: Life.guide_to pan to the sofa "Talk to my family." -> the player reaches the couch -> sits next to the family (the
## family stays seated: _process re-poses anyone who lost the sit pose) -> family questions + scrambled-word puzzles about the
## day (cafe order, how many / how much, countable / uncountable) -> family reply -> Life.guide_to the bedroom door
## "Go to bed." (story.d3_bed_pending = true; bedtime.gd runs the day-3 night in the bedroom).
## One bottom caption box: every line goes through lr.caption / lr._say_as / lr._say_me (the room's caption panel); the
## puzzle is the same centre panel as day 2 (Objectives.ovl_register).
class_name Day3Evening
extends Node

const DATA := "res://data/day3_evening.json"
var lr: Node
var D := {}
var _talking := false

static func story() -> Dictionary:
	var sv = App.load_save().get("story", {})
	return sv if sv is Dictionary else {}

static func set_flag(k: String, v) -> void:
	var sv := story().duplicate(); sv[k] = v; App.patch_save({"story": sv})

static func ready_to_run() -> bool:
	var sv := story()
	return maxi(WorldState.day, App.day) == 3 and String(sv.get("d3", "")) in ["home", "done"] and bool(sv.get("d3_cafe", false)) \
		and bool(sv.get("d3_shop", false)) and not bool(sv.get("d3_couch_done", false))

static func load_tr(into: Dictionary) -> void:
	var d = App.load_json(DATA)
	if not d is Dictionary: return
	for k in d.get("lines", {}): into[k] = d.lines[k]

static func start(tree: SceneTree) -> void:
	var sc := RoutineScope.current(tree)
	if sc == null or not String(sc.scene_file_path).ends_with("livingroom.tscn"): return
	if sc.has_node("Day3Evening"): return
	var sv := story()
	if not ready_to_run():
		if maxi(WorldState.day, App.day) == 3 and bool(sv.get("d3_couch_done", false)) and bool(sv.get("d3_bed_pending", false)) and not bool(sv.get("d3_bedtime_done", false)):
			var g = load("res://scripts/story/day3_evening.gd").new(); g.name = "Day3Evening"; g.lr = sc; sc.add_child(g); g.bed_prompt()
		return
	var e = load("res://scripts/story/day3_evening.gd").new(); e.name = "Day3Evening"; e.lr = sc; sc.add_child(e)
	e.run()

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run() -> void:
	D = App.load_json(DATA); load_tr(lr.XTR)
	await _w(1.6)   # let the room's "I'm in the living room now." + _advance() pass
	await Audio.wait_idle(10.0)
	var hs: Array = lr.humans()
	if not hs.is_empty():
		var at_tv := hs.all(func(b): return String(b.seat).begins_with("sofa") or String(b.seat) in ["armchair", "tv_stand"])
		if not at_tv: lr.family_at_tv_now()
	_keep_pose = true
	# ---- objective: Talk to my family. (pan to the couch)
	var at := Vector3(lr.SOFA_X, 0.7, 0.0)
	if lr.get("N") is Dictionary and lr.N.has("sofa") and lr.N.sofa is Node3D: at = lr.to_local((lr.N.sofa as Node3D).global_position) + Vector3(0, 0.7, 0)   # build 3.2: room-local
	lr.mode = "busy"
	await Life.guide_to({"pos": at + Vector3(-3.0, 1.4, 0.4), "at": at}, "Talk to my family.", {"tr": "Ailemle konuş.", "id": "Talk to my family."})
	lr.mode = "play"; lr._update_hand()
	_keep_obj = "Talk to my family."
	# wait for the player at the couch (or sitting on it)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(lr):
		var h: Vector3 = lr.to_local(lr.hero.global_position)   # open world: room-local like SOFA_X
		if String(lr.S.seat).begins_with("sofa") or Vector2(h.x, h.z).distance_to(Vector2(lr.SOFA_X, 0.0)) < 1.9: break
		if Time.get_ticks_msec() - t0 > 600000: break
		await _w(0.25)
	if not is_instance_valid(lr): return
	while lr.mode == "busy" and String(lr.S.seat) == "": await _w(0.2)
	_keep_obj = ""
	set_flag("d3_couch_done", true)   # plays once (even if the app is closed mid-talk)
	set_flag("d3_bed_pending", true)
	Life.event("home")
	_talking = true
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	Objectives.complete("Talk to my family.")
	await _sit()
	lr.cam_shot = {"pos": Vector3(lr.SOFA_X - 2.6, 1.55, 0.9), "at": Vector3(lr.SOFA_X, 0.85, 0.0)}
	await _w(1.0)
	_snap_couch()
	await Audio.wait_idle(12.0)
	var a: Dictionary = hs[0] if not hs.is_empty() else {}
	var b: Dictionary = hs[1 % hs.size()] if not hs.is_empty() else {}
	await _ask(a, "How was your day?")
	await lr._say_me("It was a good day.", _tr("It was a good day."))
	await _line("Put the words in the right order.")
	var told: Array = []
	var i := 0
	for t in D.get("talk", []):
		var q := String(t[0])
		if q != "": await _ask(a if i % 2 == 0 else b, q)
		await _puzzle(String(t[1]), String(t[2]))
		await lr._say_me(String(t[1]), String(t[2]))
		told.append(t[1]); i += 1
		if String(t[1]) == "I bought six apples.": await _line("Apples are countable, so we ask: How many apples?")
		if String(t[1]) == "I bought a bottle of milk.": await _line("Milk is uncountable, so we ask: How much milk?")
	set_flag("d3_couch_told", told)
	await _ask(b, "Thank you for the shopping! Well done.")
	await _ask(a, "You must be tired. Go to bed.")
	await lr._say_me("Good night!", "İyi geceler!")
	if String(lr.S.seat) != "": await lr.stand_up()
	lr.cam_shot = {}
	_talking = false
	await bed_prompt()

## family line (or the narrator when there is no family)
func _ask(who: Dictionary, en: String) -> void:
	if who.is_empty(): await _line(en)
	else: await lr._say_as(who, en, _tr(en))

func _tr(en: String) -> String: return String(D.get("lines", {}).get(en, ""))

## sit on a free sofa seat; if the family fills the sofa, stand next to it (never on top of a family member)
func _sit() -> void:
	if String(lr.S.seat).begins_with("sofa"): return
	var taken: Array = []
	for f in lr.family: taken.append(String(f.get_meta("seat", "")))
	var seat := ""
	for k in ["sofa_middle", "sofa_left", "sofa_right"]:
		if not k in taken: seat = k; break
	if seat != "":
		await lr.walk_to(lr.sit_spot(seat), lr.SEATS[seat].yaw)
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
		lr.caption("I am sitting on the sofa.")   # build 3.2: said once the hero really sits
	else:
		await lr.walk_to(Vector3(lr.SOFA_X - 1.3, 0, 0.0), PI / 2)
		lr.caption("I am standing next to the sofa.")

## pan to the bedroom door + sound + top-left objective, control back to the player
func bed_prompt() -> void:
	if lr.get("XTR") is Dictionary: load_tr(lr.XTR)
	var dv: Vector2 = lr.DOOR_BED
	var door := Vector3((dv.x + dv.y) / 2, 1.1, -3.0)
	lr.mode = "busy"
	await Life.guide_to({"pos": door + Vector3(0.4, 1.0, 2.6), "at": door}, "Go to bed.", {"tr": "Yatmaya git.", "id": "Go to bed."})
	lr.mode = "play"; lr._update_hand()
	_keep_obj = "Go to bed."

## the room's own _advance() rewrites the objective after any action: keep ours on the list; keep the family seated
var _keep_obj := ""
var _keep_pose := false
var _kt := 0.0
func _process(d: float) -> void:
	_kt += d
	if _kt < 0.4 or not is_instance_valid(lr): return
	_kt = 0.0
	if _keep_obj != "" and not Objectives.has(_keep_obj) and lr.mode != "busy": lr._set_mission(_keep_obj)
	if _keep_pose:
		for bm in lr.humans():
			var seat := String(bm.seat)
			if not (seat.begins_with("sofa") or seat == "armchair") or not bm.node is DemoCharacter: continue
			var ch: DemoCharacter = bm.node
			if String(ch.player.current_animation) != "sit_idle":
				if bm.has("tw") and bm.tw: bm.tw.kill()
				lr.sit_down(ch, seat, false)

func _line(t: String) -> void:
	await Audio.wait_idle(12.0); lr.caption(t); await _w(0.2); await Audio.wait_idle(12.0); await _w(0.5)

## the couch polaroid: offscreen camera framing the player (and the family) on the sofa
func _snap_couch() -> void:
	var h: Vector3 = lr.hero.global_position
	var at := h + Vector3(0, 0.75, 0)
	var eye := at + Vector3(-2.2, 0.55, 0.35)
	Life.snap_from("d3_couch", Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), 45.0)

## word-order puzzle (day2_evening.gd style): tap the shuffled words in the right order. The end mark (. ? !) is kept,
## commas stay on their word ("chocolate,"). TR line of the target sentence under the answer when TR is on.
func _puzzle(sentence: String, tr_line := "") -> void:
	var end := sentence.right(1) if sentence.right(1) in [".", "?", "!"] else ""
	var words := sentence.left(sentence.length() - end.length()).split(" "); var target := Array(words)
	var pool := target.duplicate(); while pool == target and pool.size() > 1: pool.shuffle()
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	var P := StoryUI.scramble_panel(cl, "D3Puzzle", pool)   # v33: standard compact scramble panel (low, above the caption box)
	var box: PanelContainer = P.box; var askt: Label = P.askt
	Objectives.ovl_register(box, 5)
	var ans := Label.new(); ans.text = "..."; ans.visible = false   # v32-polish: built sentence -> standard caption box (lr.caption_live)
	var got: Array = []
	var done := [false]
	for bt in P.buttons:
		var wd: String = bt.text
		bt.pressed.connect(func():
			if bt.disabled or done[0]: return
			if wd == target[got.size()]:
				Audio.click(); got.append(wd); bt.disabled = true; ans.text = " ".join(got)
				if got.size() == target.size(): ans.text += end; done[0] = true
				lr.caption_live("Me: " + ans.text, ("Ben: " + tr_line) if done[0] and tr_line != "" else "")
			else: Audio.bad())
	while not done[0]:
		askt.visible = true   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
		await get_tree().process_frame
	Audio.good()
	await _w(0.5)
	ans.free()
	cl.queue_free()
