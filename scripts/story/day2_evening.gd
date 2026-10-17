## v31c (red): DAY 2 EVENING - the couch talk. Runs only when BOTH day-2 work and the hospital check-up are done
## (story.day2_work_done + story.day2_hospital_done, set by black's work_summary.gd / hospital_day2.gd).
## ENTRY:  Day2Evening.start(get_tree())   (static; safe to call more than once - plays once, flag story.d2_couch_done)
##   hooked from livingroom.gd day2_family_talk() (black's v30.5 hook, after Day2After's "Talk to your family." pan).
## Flow: wait until the player reaches the couch (or sits on it) -> auto-sit next to the family -> "How was your day?"
## -> word-order puzzles in the past simple built from what really happened (breakfast, the job's routine, hospital)
## -> family reply -> Life.guide_to the bedroom door "Go to bed." (story.d2_bed_pending = true; bedtime.gd runs in the bedroom).
class_name Day2Evening
extends Node

const DATA := "res://data/day2_evening.json"
const D2 := preload("res://scripts/story/day2_morning.gd")
var lr: Node
var D := {}

static func story() -> Dictionary:
	var sv = App.load_save().get("story", {})
	return sv if sv is Dictionary else {}

static func set_flag(k: String, v) -> void:
	var sv := story().duplicate(); sv[k] = v; App.patch_save({"story": sv})

static func ready_to_run() -> bool:
	var sv := story()
	return maxi(WorldState.day, App.day) == 2 and bool(sv.get("day2_work_done", false)) and bool(sv.get("day2_hospital_done", false)) and not bool(sv.get("d2_couch_done", false))

static func load_tr(into: Dictionary) -> void:
	var d = App.load_json(DATA)
	if not d is Dictionary: return
	for k in d.get("lines", {}): into[k] = d.lines[k]
	for c in d.get("work", {}).values(): for p in c: into[p[0]] = p[1]

## the entry point (static): attaches itself to the current living-room scene
static func start(tree: SceneTree) -> void:
	var sc := RoutineScope.current(tree)
	if sc == null or not String(sc.scene_file_path).ends_with("livingroom.tscn"): return
	if sc.has_node("Day2Evening"): return
	if not ready_to_run():
		if bool(story().get("d2_couch_done", false)) and bool(story().get("d2_bed_pending", false)):
			var g = load("res://scripts/story/day2_evening.gd").new(); g.name = "Day2Evening"; g.lr = sc; sc.add_child(g); g.bed_prompt()
		return
	var e = load("res://scripts/story/day2_evening.gd").new(); e.name = "Day2Evening"; e.lr = sc; sc.add_child(e)
	e.run()

## the past-simple sentences of the real day (EN, TR)
static func day_sentences() -> Array:
	var d = App.load_json(DATA); var sv := story()
	var st: Dictionary = App.load_save().get("state", {})
	var child := CharacterHook.is_child(st)
	var cid: String = load("res://scripts/story/work.gd").category_of(String(st.get("job", "")), child)
	var out: Array = []
	if sv.has("day2_score") or bool(App.load_save().get("breakfast_done", false)): out.append(["I had breakfast with my family.", "Ailemle kahvaltı yaptım."])
	var go := "I went to school." if cid in ["teach", "study"] else ("I went shopping." if cid == "home" else "I went to work.")
	out.append([go, String(d.lines.get(go, ""))])
	var wl: Array = d.get("work", {}).get(cid, [])
	if not wl.is_empty(): out.append(wl[0])
	out.append(["I went to the hospital.", "Hastaneye gittim."])
	out.append(["The doctor said I was fine.", "Doktor iyi olduğumu söyledi."])
	return out

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run() -> void:
	D = App.load_json(DATA); load_tr(lr.XTR)
	var hs: Array = lr.humans()
	if not hs.is_empty():
		var at_tv := hs.any(func(b): return String(b.seat).begins_with("sofa") or String(b.seat) == "armchair")
		if not at_tv: lr.family_at_tv_now()
	# wait for the player to come to the couch (Day2After already panned + set "Talk to your family.")
	var sofa: Vector3 = lr.N.sofa.global_position if lr.N.has("sofa") else Vector3(lr.SOFA_X, 0, 0)
	sofa = Vector3(lr.SOFA_X, 0, 0)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(lr):
		var h: Vector3 = lr.to_local(lr.hero.global_position)   # open world: room-local like SOFA_X
		if String(lr.S.seat).begins_with("sofa") or Vector2(h.x, h.z).distance_to(Vector2(sofa.x, sofa.z)) < 1.9: break
		if Time.get_ticks_msec() - t0 > 600000: break
		await _w(0.25)
	while lr.mode == "busy" and String(lr.S.seat) == "": await _w(0.2)   # let a running action finish
	set_flag("d2_couch_done", true)   # plays once (even if the app is closed mid-talk)
	set_flag("d2_bed_pending", true)
	Life.event("home")
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	Objectives.complete("Talk to your family.")
	if not String(lr.S.seat).begins_with("sofa"):
		var seat: String = lr._free_sofa_seat()
		await lr.walk_to(lr.sit_spot(seat), lr.SEATS[seat].yaw)
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
		lr.caption("I am sitting on the sofa.")   # build 3.2: said once the hero really sits
	lr.cam_shot = {"pos": Vector3(lr.SOFA_X - 2.6, 1.55, 0.9), "at": Vector3(lr.SOFA_X, 0.85, 0.0)}
	await _w(1.0)
	_snap_couch()
	await Audio.wait_idle(12.0)
	if not hs.is_empty(): await lr._say_as(hs[0], "How was your day?", "Günün nasıldı?")
	else: await _line("How was your day?")
	await lr._say_me("My day was busy.", "Günüm yoğundu.")
	await _line("Put the words in the right order.")
	var told: Array = []
	for s in day_sentences():
		await _puzzle(String(s[0]), String(s[1]))
		await lr._say_me(String(s[0]), String(s[1]))
		told.append(s[0])
	set_flag("d2_couch_told", told)
	var sp: Dictionary = hs[1 % hs.size()] if not hs.is_empty() else {}
	if not sp.is_empty():
		await lr._say_as(sp, "What a busy day! Well done.", "Ne yoğun bir gün! Aferin.")
		await lr._say_as(hs[0], "You must be tired. Go to bed.", "Yorgun olmalısın. Yatmaya git.")
	await lr._say_me("Good night!", "İyi geceler!")
	await lr.stand_up()
	lr.cam_shot = {}
	await bed_prompt()

## pan to the bedroom door + sound + top-left objective, control back to the player
func bed_prompt() -> void:
	if lr.get("XTR") is Dictionary: load_tr(lr.XTR)
	var dv: Vector2 = lr.DOOR_BED
	var door := Vector3((dv.x + dv.y) / 2, 1.1, -3.0)
	lr.mode = "busy"
	await Life.guide_to({"pos": door + Vector3(0.4, 1.0, 2.6), "at": door}, "Go to bed.", {"tr": "Yatmaya git.", "id": "Go to bed."})
	lr.mode = "play"; lr._update_hand()
	_keep_bed = true

## the room's own _advance() rewrites the objective after any action: keep "Go to bed." on the list until the bedroom
var _keep_bed := false
var _kt := 0.0
func _process(d: float) -> void:
	_kt += d
	if not _keep_bed or _kt < 0.5: return
	_kt = 0.0
	if not Objectives.has("Go to bed.") and is_instance_valid(lr) and lr.mode != "busy": lr._set_mission("Go to bed.")

func _line(t: String) -> void:
	await Audio.wait_idle(12.0); lr.caption(t); await _w(0.2); await Audio.wait_idle(12.0); await _w(0.5)

## the couch polaroid: offscreen camera framing the player (and the family) on the sofa
func _snap_couch() -> void:
	var h: Vector3 = lr.hero.global_position
	var at := h + Vector3(0, 0.75, 0)
	var eye := at + Vector3(-2.2, 0.55, 0.35)
	Life.snap_from("d2_couch", Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), 45.0)

## word-order puzzle (story_home.gd _puzzle style): tap the shuffled words in the right order
func _puzzle(sentence: String, tr_line := "") -> void:
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	var words := sentence.trim_suffix(".").split(" "); var target := Array(words)
	var pool := target.duplicate(); while pool == target and pool.size() > 1: pool.shuffle()
	var P := StoryUI.scramble_panel(cl, "D2Puzzle", pool)   # v33: standard compact scramble panel (low, above the caption box)
	var box: PanelContainer = P.box; var askt: Label = P.askt
	Objectives.ovl_register(box, 5)
	var ans := Label.new(); ans.text = "..."; ans.visible = false   # v32-polish: the built sentence shows in the standard caption box (lr.caption_live), not here
	var got: Array = []
	var done := [false]
	for b in P.buttons:
		var wd: String = b.text
		b.pressed.connect(func():
			if b.disabled: return
			if wd == target[got.size()]:
				Audio.click(); got.append(wd); b.disabled = true; ans.text = " ".join(got)
				if got.size() == target.size(): ans.text += "."; done[0] = true
				lr.caption_live("Me: " + ans.text, ("Ben: " + tr_line) if done[0] and tr_line != "" else "")
			else: Audio.bad())
	while not done[0]:
		askt.visible = true   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box
		await get_tree().process_frame
	Audio.good()
	await _w(0.5)
	ans.free()
	cl.queue_free()
