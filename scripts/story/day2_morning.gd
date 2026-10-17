## v31 day 2 morning (living room part). Automatic scripted sequence in the style of the day-1 breakfast (livingroom.gd
## breakfast_call / start_breakfast): auto-walk to the free chair, breakfast camera, queued lines (never cut), then
## lesson (will / going to / have to + short forms, phone.gd lesson pages) -> table dialogue (data/day2_morning.json "dialogue",
## job-based "have_to" line) -> 10-question test (day2_test.gd) -> stand up, the table clears itself -> car prompt
## (camera pan to the front door + sound + top-left mission). The car itself is handled outside (day2_car.gd).
## Save: "story".day2 = "living" (set in the bedroom) -> "car" (after breakfast) -> "at_car" (hook fired).
extends Node

const DATA := "res://data/day2_morning.json"
var lr: Node   # livingroom.gd
var D := {}
signal done

static func stage() -> String:
	var st = App.load_save().get("story", {})
	return String(st.get("day2", "")) if st is Dictionary else ""

static func set_stage(v: String) -> void:
	var st = App.load_save().get("story", {})
	st = st.duplicate() if st is Dictionary else {}
	st["day2"] = v; App.patch_save({"story": st})

static func load_lines(xtr: Dictionary) -> void:
	var d = App.load_json(DATA)
	if d is Dictionary: for k in d.get("lines", {}): xtr[k] = d.lines[k]

## job-based "I have to ..." line (state.job / age from save.json)
static func have_to_line(d: Dictionary, st: Dictionary) -> Dictionary:
	var job := String(st.get("job", ""))
	var g := "school" if String(st.get("age", "adult")) == "child" else String(d.get("job_group", {}).get(job, "work"))
	return d.get("have_to", {}).get(g, d.get("have_to", {}).get("work", {"en": "I have to go to work today.", "tr": "Bugün işe gitmem gerekiyor."}))

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout
func _line(t: String) -> void:   # caption + narrator, wait until fully spoken
	await Audio.wait_idle(12.0); lr.caption(t); await _w(0.2); await Audio.wait_idle(12.0); await _w(0.5)

func run() -> void:
	D = App.load_json(DATA); load_lines(lr.XTR)
	Life.event("breakfast")
	var hs: Array = lr.humans()
	var bk := "Have breakfast with your family." if not hs.is_empty() else "Have breakfast."
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	if lr.wall_fade: lr.wall_fade.force_fade(true)   # v32-polish: the south wall never blocks the day-2 breakfast pan / camera
	# v32-polish: the objective gets the same Life.guide_to camera pan to the table as the day-1 breakfast
	await Life.guide_to({"pos": lr.DINE_C + Vector3(0.2, 2.0, 2.2), "at": lr.DINE_C + Vector3(0, 0.9, 0)}, bk)
	await Audio.wait_idle(12.0)
	# ---- walk to the free chair by itself, breakfast camera (day-1 framing)
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
	# ---- lesson (phone lesson pages: notebook reminder once, Listen / Next, narrator per page)
	await _line("Let's learn will, going to and have to.")
	var ph = lr.room_phone.phone
	ph.visible = true; ph.open(Rect2(), "home"); await _w(0.6)
	ph.start_set(D, "lesson")
	_hide_note_caption()
	await ph.lesson_steps_done
	Audio.cancel_group("lesson")
	ph.page = "between"; await ph.close(true)
	await _w(0.6)
	# ---- table dialogue (data-driven)
	await dialogue(hs)
	# ---- 10-question test
	await _line("Now the test. Ten questions.")
	var res: Array = await load("res://scripts/story/day2_test.gd").new().run(lr, ph)
	await Audio.wait_idle(15.0)
	await ph.close(true); ph.les = {}
	var st = App.load_save().get("story", {}); st = st.duplicate() if st is Dictionary else {}
	st["day2_score"] = res; st["day2"] = "car"; App.patch_save({"story": st, "breakfast_done": true, "breakfast_day": App.day})
	lr.breakfast_done = true
	Life.satisfy(["hunger", "thirst"])
	# ---- breakfast over: stand up, the table clears itself
	if lr.eat_tw: lr.eat_tw.kill()
	await _line("Breakfast is over.")
	if lr.S.seat != "":
		for bn in ["UpperArm.R", "LowerArm.R", "UpperArm.L", "LowerArm.L", "Neck"]: lr.hero.bone_offsets.erase(bn)
		await lr.stand_up()
	lr.caption("The table is clearing itself.")
	lr._clear_table(true)
	await _w(0.8); await Audio.wait_idle(12.0)
	lr.cam_shot = {}
	if lr.wall_fade: lr.wall_fade.force_fade(false)   # v32-polish
	if not hs.is_empty(): await lr.family_to_tv()   # the family sits down at the TV before control comes back
	await car_prompt()
	lr.mode = "play"; lr._update_hand()
	done.emit()

## v31: the notebook caption goes away as soon as the reminder has been spoken (mode is busy, so the room timer keeps it)
func _hide_note_caption() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
		var cur: String = String(Audio.voice_log[-1].what) if not Audio.voice_log.is_empty() else ""
		if not lr.cap_text.begins_with("Get a notebook"): return
		if cur != "" and not cur.begins_with("Get a notebook"): lr.cap_panel.visible = false; lr.cap_text = ""; return

func dialogue(hs: Array) -> void:
	var st: Dictionary = lr.room_phone.S if lr.room_phone else {}
	var ht := have_to_line(D, st)
	lr.XTR[String(ht.en)] = String(ht.tr)
	for e in D.get("dialogue", []):
		var en := String(e.en); var tr_ := String(e.get("tr", ""))
		if en == "{have_to}": en = String(ht.en); tr_ = String(ht.tr)
		en = en.replace("{name}", String(st.get("name", ""))); 
		var who := String(e.get("who", "me"))
		if who == "me": await lr._say_me(en, tr_)
		elif not hs.is_empty():
			var i := int(who.trim_prefix("fam")) % hs.size()
			await lr._say_as(hs[i], en, tr_)
	await _w(0.6)

## camera pan to the front door + sound + top-left mission via Life.guide_to (mirror-prompt pattern)
func car_prompt() -> void:
	var door := Vector3((lr.DOOR_FRONT.x + lr.DOOR_FRONT.y) / 2, 1.2, 3.0)
	await Life.guide_to({"pos": Vector3(door.x + 1.6, 2.1, -0.4), "at": door}, "Go outside to the car.")
