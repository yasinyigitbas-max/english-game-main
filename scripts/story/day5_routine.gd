## v33 (blue): DAYS 5 + 6 ROUTINE DIRECTOR. Lives on the tree ROOT (survives room changes), like Day3Morning.
## Each day, in order (every step: voice line + top-left Objectives + camera pan via Life.guide_to):
##   alarm (bedroom) -> bathroom -> breakfast review at the table (living room) -> the outing (day 5: corner shop + lost child,
##   day5_shop.gd; day 6: bus stop + storm + broken-down bus, day6_storm.gd) -> family couch talk -> the polaroids in bed
##   -> the bedtime 10-question test (day5_test.gd, questions via _bedtime_questions() -> red's shared no-repeat bank when present)
##   -> sleep -> next day's alarm. Day 6 ends by handing over to red's day 7 (see _to_day7()).
## Saved stage: story.d5 / story.d6 (see day5_common.gd).
## ENTRY (red, end of day-4 bedtime, after Life.advance_day() -> day 5 and the fade-in; the player may still be lying in bed):
##     load("res://scripts/story/day5_routine.gd").begin(get_tree())
## HOOK (main.gd _continue_game, one line): load("res://scripts/story/day5_routine.gd").attach(get_tree())   (resume on Continue)
class_name Day56Routine
extends "res://scripts/story/day5_common.gd"

const DAY7_SCRIPT := "res://scripts/story/day7_morning.gd"   # red's day 7 (optional; see _to_day7)

static func begin(tree: SceneTree, d := 5, lying := true) -> void:
	set_stage(d, "alarm"); flag("d56_lying", lying)
	if load("res://scripts/story/day3_morning.gd").stage() != "done": flag("d3", "done")   # no stale day-3 objectives
	var d2 = load("res://scripts/story/day2_morning.gd")
	if d2.stage() in ["", "living", "car"]: d2.set_stage("day%d" % d)   # livingroom.gd would otherwise start the day-2 breakfast
	attach(tree)

static func active_day() -> int:
	for d in [5, 6]:
		var st := stage(d)
		if st != "" and st != "done": return d
	return 0

static func attach(tree: SceneTree) -> void:
	var d := active_day()
	if d == 0 or tree.root.has_node("Day56Routine"): return
	var n = load("res://scripts/story/day5_routine.gd").new(); n.name = "Day56Routine"; n.day = d; tree.root.add_child(n)

var _sc: Node = null
var _guided := {}
var _cur := {}
var _busy := false
var _t := 0.0
var bed_lock := false
var _bed_xf: Transform3D
var m: Node   # bedroom while bedtime runs

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	D = data(day)
	ensure_voice()

func _kind(s: Node) -> String:
	if s == null: return ""
	var p := String(s.scene_file_path)
	if p.ends_with("main.tscn"): return "bedroom"
	if p.ends_with("bathroom.tscn"): return "bathroom"
	if p.ends_with("livingroom.tscn"): return "living"
	if p.ends_with("shop.tscn"): return "shop"
	if p.ends_with("menu.tscn") or p == "": return ""
	if s is UniversalScene and s.get("grid") != null: return "outside"
	return "other"

func _process(dt: float) -> void:
	if bed_lock and m and is_instance_valid(m) and is_instance_valid(m.hero):
		if not m.breathing or m.hero.transform.origin.distance_to(_bed_xf.origin) > 0.05 or not m.hero.visible:
			m.hero.transform = _bed_xf; m.hero.visible = true; m._pose_sleep()
	_t += dt
	if _t < 0.4: return
	_t = 0.0
	ensure_voice()   # the narrator setting may have reloaded the packs
	if _busy:
		# a step awaiting in a scene that got freed (player left mid-step) must not lock the director forever
		if not is_instance_valid(_sc) and get_tree().current_scene != null: _busy = false; _sc = null
		else: return
	var st := stage(day)
	if st in ["", "done"]: queue_free(); return
	var s := get_tree().current_scene
	if s != _sc:
		_sc = s; sc = s; _cur = {}
		if s and _kind(s) != "": reg_all(s, D.get("lines", {}))
		if s and s.has_signal("action_done") and _kind(s) == "bathroom": s.action_done.connect(_on_bath_action.bind(s))
		_busy = true; _enter.call_deferred(s); return
	if not _cur.is_empty() and not Objectives.has(String(_cur.id)): Objectives.set_list([_cur])
	if day == 6 and st == "out" and _kind(s) == "outside": _stop_check(s)

func _wait_free(s: Node) -> void:
	await _w(1.6)
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(s) and "mode" in s and not String(s.mode) in ["play", "lying"] and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await Audio.wait_idle(8.0)

## one pan per objective per room visit; afterwards the objective just stays listed
func _guide(s: Node, tgt, en: String, tr: String) -> void:
	_cur = {"id": en, "en": en, "tr": tr}
	reg_tr(s, en, tr)
	var key := en + "|" + str(s.get_instance_id())
	if _guided.has(key): Objectives.set_list([_cur]); return
	_guided[key] = true
	await Life.guide_to(tgt, en, {"id": en, "tr": tr, "list": [_cur]})

func _shot(focus: Vector3, toward: Vector3, dist := 2.4, up := 1.0) -> Dictionary:
	var d := toward - focus; d.y = 0
	if d.length() < 0.05: d = Vector3(0, 0, 1)
	return {"pos": focus + d.normalized() * dist + Vector3(0, up, 0), "at": focus}

func _obj_shot(s: Node, id: String) -> Dictionary:
	var o = s.OBJ.get(id) if s.get("OBJ") is Dictionary else null
	if o == null: return {}
	return _shot(o.focus, Vector3.ZERO)

# ------------------------------------------------------------------ the room-by-room prompts
const GO_LIVING := ["Go to the living room.", "Oturma odasına git."]
const GO_BATH := ["Go to the bathroom.", "Banyoya git."]
const GO_OUT := ["Go outside.", "Dışarı çık."]
const GO_HOME := ["Go home.", "Eve git."]
const GO_BED := ["Go to bed.", "Yatmaya git."]

func _enter(s: Node) -> void:
	if not is_instance_valid(s): _busy = false; return
	var k := _kind(s)
	if k in ["", "other"]: _busy = false; return
	await _wait_free(s)
	if not is_instance_valid(s) or s != get_tree().current_scene: _busy = false; return
	var st := stage(day)
	match st:
		"alarm":
			if k == "bedroom": await _alarm(s)
			else: set_stage(day, "bath"); _sc = null   # continued elsewhere: re-enter with the next step
		"bath":
			if k == "bedroom": await _guide(s, _obj_shot(s, "door"), GO_BATH[0], GO_BATH[1])
			elif k == "bathroom":
				var b: Dictionary = D.bath
				await _guide(s, _obj_shot(s, String(b.obj)), String(b.en), String(b.tr))
			elif k == "living": await _guide(s, _living_door(s, "bath"), GO_BATH[0], GO_BATH[1])
			elif k == "outside": await _guide(s, _world_target(s, "home"), GO_HOME[0], GO_HOME[1])
		"breakfast":
			if k == "bedroom": await _guide(s, _obj_shot(s, "door_s"), GO_LIVING[0], GO_LIVING[1])
			elif k == "bathroom": await _guide(s, _obj_shot(s, "door"), GO_LIVING[0], GO_LIVING[1])
			elif k == "living": await _breakfast(s)
			elif k == "outside": await _guide(s, _world_target(s, "home"), GO_HOME[0], GO_HOME[1])
		"out", "event":
			if k == "bedroom": await _guide(s, _obj_shot(s, "door_s"), GO_LIVING[0], GO_LIVING[1])
			elif k == "bathroom": await _guide(s, _obj_shot(s, "door"), GO_LIVING[0], GO_LIVING[1])
			elif k == "living": await _guide(s, _living_door(s, "front"), GO_OUT[0], GO_OUT[1]); s.mode = "play"
			elif k == "outside":
				var o: Dictionary = D.outing
				await _guide(s, _world_target(s, String(o.obj)), String(o.en), String(o.tr))
			elif k == "shop" and day == 5:
				set_stage(day, "event")
				var ev = load("res://scripts/story/day5_shop.gd").new(); ev.name = "Day5Shop"; ev.day = day; ev.D = D; ev.sc = s; s.add_child(ev)
				await ev.run()
				if stage(day) == "home": await ev.exit_prompt()
		"home":
			if k == "outside":
				var gh: Array = ["Go inside.", "İçeri gir."] if day == 6 else GO_HOME
				await _guide(s, _world_target(s, "home"), gh[0], gh[1])
			elif k == "living": set_stage(day, "couch"); await _couch(s)
			elif k == "bedroom": await _guide(s, _obj_shot(s, "door_s"), GO_LIVING[0], GO_LIVING[1])
			elif k == "bathroom": await _guide(s, _obj_shot(s, "door"), GO_LIVING[0], GO_LIVING[1])
		"couch":
			if k == "living": await _couch(s)
			elif k == "outside": await _guide(s, _world_target(s, "home"), GO_HOME[0], GO_HOME[1])
			elif k == "bedroom": await _guide(s, _obj_shot(s, "door_s"), GO_LIVING[0], GO_LIVING[1])
			elif k == "bathroom": await _guide(s, _obj_shot(s, "door"), GO_LIVING[0], GO_LIVING[1])
		"bed":
			if k == "bedroom": await _bedtime(s)
			elif k == "living": await _guide(s, _living_door(s, "bed"), GO_BED[0], GO_BED[1]); s.mode = "play"
			elif k == "bathroom": await _guide(s, _obj_shot(s, "door_bed"), GO_BED[0], GO_BED[1])
			elif k == "outside": await _guide(s, _world_target(s, "home"), GO_HOME[0], GO_HOME[1])
	_busy = false

func _living_door(lr: Node, which: String) -> Dictionary:
	match which:
		"front":
			var dx: float = (lr.DOOR_FRONT.x + lr.DOOR_FRONT.y) / 2
			return {"pos": Vector3(dx - 1.6, 2.0, 0.2), "at": Vector3(dx, 1.1, 3.0)}
		"bed":
			var door := Vector3((lr.DOOR_BED.x + lr.DOOR_BED.y) / 2, 1.1, -3.0)
			return {"pos": door + Vector3(0.4, 1.0, 2.6), "at": door}
		_:
			var dv: Vector2 = lr.get("DOOR_BATH") if lr.get("DOOR_BATH") is Vector2 else Vector2(5.5, 6.4)
			var door2 := Vector3((dv.x + dv.y) / 2, 1.1, -3.0)
			return {"pos": door2 + Vector3(-0.4, 1.0, 2.6), "at": door2}

## outdoor targets: home lot / corner shop / the home bus stop (pan from the player's side, day2_car.gd framing)
func _world_pos(w: Node, what: String) -> Vector3:
	match what:
		"home", "shop":
			var lot = w.grid.find_lot("home" if what == "home" else "corner_shop")
			if lot: return lot.entrance_global()
			return Vector3(0, 0, 5) if what == "home" else Vector3(-3, 0, 27.6)
		"stop":
			if Transit.stops.has("stop_home"): return Transit.stops.stop_home.pos
			return Vector3(9.5, 0, 14.7)
	return w.player.global_position

func _world_target(w: Node, what: String) -> Dictionary:
	var at: Vector3 = _world_pos(w, what) + Vector3(0, 1.0, 0)
	var away: Vector3 = at - w.player.global_position; away.y = 0
	if away.length() < 0.05: away = Vector3(0, 0, 1)
	return {"pos": at + away.normalized() * 6.0 + Vector3(0, 3.0, 0), "at": at}

var _storm_on := false
func _stop_check(w: Node) -> void:
	if _storm_on or w.mode != "play": return
	var a: Vector3 = w.player.global_position; var b := _world_pos(w, "stop"); a.y = 0; b.y = 0
	if a.distance_to(b) > 4.5: return
	_storm_on = true; _busy = true
	set_stage(day, "event")
	Objectives.complete(String(D.outing.en))
	var ev = load("res://scripts/story/day6_storm.gd").new(); ev.name = "Day6Storm"; ev.day = day; ev.D = D; ev.sc = w; w.add_child(ev)
	await ev.run()
	_storm_on = false
	_sc = null; _busy = false   # re-enter: "home" -> "Go inside." / living room couch talk

# ------------------------------------------------------------------ 1. alarm
func _alarm(b: Node) -> void:
	m = b
	var lying := bool(story().get("d56_lying", false)) or String(b.mode) == "lying"
	b.mode = "busy"; b._hide_chips()
	if b.get("hand3d"): b.hand3d.visible = false
	Life.event("wake")
	b.S.alarm = "ringing"; b._apply_states(); Audio.sfx("alarm", -4.0)
	await speak(b, "", "", "My alarm is ringing.", "Alarmım çalıyor.")
	await _guide(b, _obj_shot(b, "alarm"), "Turn off the alarm.", "Alarmı kapat.")
	if lying or "--qa-d56" in OS.get_cmdline_user_args():
		b.S.alarm = "off"; b._apply_states(); Audio.sfx("metalClick")
		await speak(b, "", "", "I am turning off the alarm.", "Alarmı kapatıyorum.")
		if lying: await b.get_up_sequence()
	else:
		b.mode = "play"; b._update_hand()
		while is_instance_valid(b) and String(b.S.alarm) == "ringing": await _w(0.3)
		await Audio.wait_idle(8.0)
	if not is_instance_valid(b): return
	flag("d56_lying", false)
	Objectives.complete("Turn off the alarm.")
	b.mode = "busy"
	var a: Dictionary = D.alarm_after
	await say("me", String(a.en), String(a.tr))
	set_stage(day, "bath")
	b.mode = "play"; b._update_hand()
	await _guide(b, _obj_shot(b, "door"), GO_BATH[0], GO_BATH[1])

# ------------------------------------------------------------------ 2. bathroom
func _on_bath_action(_id, bt: Node) -> void:
	if stage(day) != "bath" or not is_instance_valid(bt): return
	var ld = bt.get("last_dur")
	if not (ld is Dictionary and ld.has(String(D.bath.key))): return
	set_stage(day, "breakfast")
	_busy = true
	Objectives.complete(String(D.bath.en))
	await Audio.wait_idle(10.0)
	sc = bt
	await say("me", String(D.bath.done.en), String(D.bath.done.tr))
	await _w(0.4)
	if is_instance_valid(bt) and bt == get_tree().current_scene:
		await _guide(bt, _obj_shot(bt, "door"), GO_LIVING[0], GO_LIVING[1])
	_busy = false

# ------------------------------------------------------------------ 3. breakfast review (day2_morning.gd seating + table framing)
func _breakfast(lr: Node) -> void:
	sc = lr
	Life.event("breakfast")
	var hs: Array = lr.humans()
	var bk := ["Have breakfast with your family.", "Ailenle kahvaltı yap."] if not hs.is_empty() else ["Have breakfast.", "Kahvaltı yap."]
	await _guide(lr, {"pos": lr.DINE_C + Vector3(-2.4, 1.7, 1.9), "at": lr.DINE_C + Vector3(0, 0.8, 0)}, bk[0], bk[1])
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
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
		await speak(lr, "", "", "I am sitting at the table.", "Masada oturuyorum.")
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
	Objectives.complete(bk[0])
	await speak(lr, "", "", "I am having breakfast.", "Kahvaltı yapıyorum.")
	if lr.eat_tw: lr.eat_tw.kill()
	lr.eat_tw = lr._breakfast_loop(lr.hero, lr.SEATS[seat].yaw if seat != "" else 0.0, 0)
	await snap("d%d_breakfast" % day, lr.DINE_C + Vector3(-2.2, 1.6, 1.6), lr.DINE_C + Vector3(0, 0.7, 0), 50.0)
	await run_steps(D.breakfast)
	flag("d%d_breakfast_done" % day, true)
	Life.satisfy(["hunger", "thirst"])
	if lr.eat_tw: lr.eat_tw.kill()
	await speak(lr, "", "", "Breakfast is over.", "Kahvaltı bitti.")
	if String(lr.S.seat) != "":
		for bn in ["UpperArm.R", "LowerArm.R", "UpperArm.L", "LowerArm.L", "Neck"]: lr.hero.bone_offsets.erase(bn)
		await lr.stand_up()
	await speak(lr, "", "", "The table is clearing itself.", "Masa kendi kendine toplanıyor.")
	lr._clear_table(true)
	lr.cam_shot = {}
	if not hs.is_empty(): await lr.family_to_tv()
	set_stage(day, "out")
	await _guide(lr, _living_door(lr, "front"), GO_OUT[0], GO_OUT[1])
	lr.mode = "play"; lr._update_hand()

## family speakers in the living room: their seat nodes (nod + talk) and CC0 / PD voices
func spk(who: String) -> Array:
	if sc and is_instance_valid(sc) and sc.has_method("humans") and who.begins_with("fam") and who != "famcall":
		var hs: Array = sc.humans()
		if not hs.is_empty():
			var b: Dictionary = hs[int(who.trim_prefix("fam")) % hs.size()]
			var nm := String(b.data.get("name", ""))
			return [nm, nm, safe_voice(sc.voice_of(b)), null]
	return super.spk(who)

func say(who: String, en: String, tr: String) -> void:
	if sc and is_instance_valid(sc) and sc.has_method("humans") and who.begins_with("fam") and who != "famcall":
		var hs: Array = sc.humans()
		if not hs.is_empty():
			var b: Dictionary = hs[int(who.trim_prefix("fam")) % hs.size()]
			if sc.has_method("_talk_nod"): sc._talk_nod(b.node)
	await super.say(who, en, tr)

func act(tag: String) -> void:
	if tag == "photo" and sc and sc.has_method("humans"):   # the couch photo
		var h: Vector3 = sc.hero.global_position
		await snap("d%d_couch" % day, h + Vector3(-2.2, 1.3, 0.35), h + Vector3(0, 0.75, 0), 45.0)

# ------------------------------------------------------------------ 5. family couch talk (day2_evening.gd pattern)
func _couch(lr: Node) -> void:
	sc = lr
	Life.event("home")
	var hs: Array = lr.humans()
	if not hs.is_empty():
		var at_tv := hs.any(func(b): return String(b.seat).begins_with("sofa") or String(b.seat) == "armchair")
		if not at_tv: lr.family_at_tv_now()
	var at := Vector3(lr.SOFA_X, 0.7, 0)
	await _guide(lr, {"pos": at + Vector3(-3.0, 1.4, 0.4), "at": at}, "Talk to your family.", "Ailenle konuş.")
	lr.mode = "play"; lr._update_hand()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(lr):
		var h: Vector3 = lr.hero.global_position
		if String(lr.S.seat).begins_with("sofa") or Vector2(h.x, h.z).distance_to(Vector2(lr.SOFA_X, 0)) < 1.9: break
		if "--qa-d56" in OS.get_cmdline_user_args() and Time.get_ticks_msec() - t0 > 3000: break
		await _w(0.25)
	if not is_instance_valid(lr): return
	while lr.mode == "busy" and String(lr.S.seat) == "": await _w(0.2)
	lr.mode = "busy"; lr._hide_chips(); lr.hand3d.visible = false; lr.stick = Vector2.ZERO
	Objectives.complete("Talk to your family.")
	if not String(lr.S.seat).begins_with("sofa"):
		var seat: String = lr._free_sofa_seat()
		await lr.walk_to(lr.sit_spot(seat), lr.SEATS[seat].yaw)
		await speak(lr, "", "", "I am sitting on the sofa.", "Kanepede oturuyorum.")
		await lr.sit_down(lr.hero, seat, true); lr.S.seat = seat
	lr.cam_shot = {"pos": Vector3(lr.SOFA_X - 2.6, 1.55, 0.9), "at": Vector3(lr.SOFA_X, 0.85, 0.0)}
	await _w(1.0)
	await run_steps(D.couch)
	flag("d%d_couch_done" % day, true)
	await lr.stand_up()
	lr.cam_shot = {}
	set_stage(day, "bed")
	await _guide(lr, _living_door(lr, "bed"), GO_BED[0], GO_BED[1])
	lr.mode = "play"; lr._update_hand()

# ------------------------------------------------------------------ 6 + 7. the polaroids in bed + the bedtime test (bedtime.gd pattern)
func _bedtime(b: Node) -> void:
	m = b; sc = b
	b.mode = "busy"; b._hide_chips(); b.hand3d.visible = false
	Life.event("bedtime")
	var bed: Dictionary = b.OBJ.bed
	await _guide(b, {"pos": bed.focus + Vector3(1.6, 1.4, 1.8), "at": bed.focus}, GO_BED[0], GO_BED[1])
	b.mode = "busy"; b._hide_chips()
	await speak(b, "", "", "I am going to bed.", "Yatmaya gidiyorum.")
	await b.walk_to(bed.spot, 0.0)
	await b.sit_on_bed(); await b.edge_to_bedsit(); await b.bedsit_to_lie()
	b.S.bed = "unmade"; b._apply_states()
	_bed_xf = b.hero.transform; bed_lock = true
	Objectives.complete(GO_BED[0])
	await speak(b, "", "", "I am lying in bed.", "Yatakta yatıyorum.")
	var cl := CanvasLayer.new(); cl.layer = 30; add_child(cl)
	b.cam_shot = {"pos": bed.focus + Vector3(1.4, 1.6, 1.6), "at": bed.focus + Vector3(-0.3, -0.1, 0)}
	# 6. the polaroids
	await Life.guide_to({"pos": bed.focus + Vector3(0.9, 1.9, 1.2), "at": bed.focus}, "Look at the photos of your day.", {"id": "Look at the photos of your day.", "tr": "Gününün fotoğraflarına bak.", "list": [{"id": "Look at the photos of your day.", "en": "Look at the photos of your day.", "tr": "Gününün fotoğraflarına bak."}]})
	b.cam_shot = {"pos": bed.focus + Vector3(1.4, 1.6, 1.6), "at": bed.focus + Vector3(-0.3, -0.1, 0)}
	await _dream(cl)
	Objectives.complete("Look at the photos of your day.")
	# 7. the bedtime test
	var night: Dictionary = b.OBJ.get("night", bed)
	await Life.guide_to({"pos": night.focus + Vector3(1.2, 1.0, 1.4), "at": night.focus}, "Take the bedtime test.", {"id": "Take the bedtime test.", "tr": "Yatmadan önce testi çöz.", "list": [{"id": "Take the bedtime test.", "en": "Take the bedtime test.", "tr": "Yatmadan önce testi çöz."}]})
	b.cam_shot = {"pos": bed.focus + Vector3(1.4, 1.6, 1.6), "at": bed.focus + Vector3(-0.3, -0.1, 0)}
	await speak(b, "", "", "Now the bedtime test. Ten questions.", "Şimdi yatmadan önceki test. On soru.")
	b.cap_panel.visible = false
	var ph = b.phone
	ph.visible = true; ph.open(Rect2(), "home"); await _w(0.5)
	var t = load("res://scripts/story/day5_test.gd").new()
	t.key = String(D.test_key); t.questions_for = _bedtime_questions
	var res: Array = await t.run(b, ph)
	flag("d%d_night_score" % day, res)
	await Audio.wait_idle(15.0)
	await ph.close(true)
	Objectives.complete("Take the bedtime test.")
	await _sleep(b, cl)

## ===== the ONE bank call (red's shared no-repeat question bank). version = 0..2 (rotation / Retake).
## TODO(red bank, ~15:45): red's shared bank was not in english-game-red / english-game-main on 2026-10-17 13:50; Day56Bank.draw() calls it
## when present (see day5_bank.gd for the guessed API) and otherwise falls back to this day's 3 local versions (data quiz / quiz_b / quiz_c).
func _bedtime_questions(version: int) -> Array:
	var local: Array = []
	for k in ["quiz", "quiz_b", "quiz_c"]: if D.get(k, []) is Array and not D.get(k, []).is_empty(): local.append(D[k])
	return load("res://scripts/story/day5_bank.gd").draw(String(D.test_key), day, D.get("bank_topics", []), 10, version, local)

func _dream(cl: CanvasLayer) -> void:
	var ui := StoryUI.new(); add_child(ui)
	var dim := ColorRect.new(); dim.color = Color(0.25, 0.2, 0.45, 0.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(dim)
	var t := create_tween(); t.tween_property(dim, "color:a", 0.6, 1.0); await t.finished
	m.cap_panel.visible = false
	await _dline(ui, "I am dreaming about my day.", "Günümü rüyamda görüyorum.")
	var row := HBoxContainer.new(); row.name = "D56Polaroids"; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT); row.offset_top = 150; row.offset_bottom = -150; row.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(row)
	var rec: Array = D.get("recap", [])
	for i in rec.size():
		var card := polaroid(String(rec[i][0]), String(rec[i][1]), i)
		card.modulate.a = 0.0; row.add_child(card)
		var ct := create_tween(); ct.tween_property(card, "modulate:a", 1.0, 0.5)
		var tl: Control = card.get_child(0)
		ct.parallel().tween_property(tl, "scale", Vector2.ONE, 0.6).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ct.parallel().tween_property(tl, "rotation_degrees", [-4.0, 3.0, -2.0, 4.0][i % 4], 0.6).from(0.0); await ct.finished
		await _dline(ui, String(rec[i][1]), String(D.lines.get(String(rec[i][1]), "")))
	await _dline(ui, String(D.recap_end.en), String(D.recap_end.tr))
	await _w(1.0)
	var ft := create_tween(); ft.tween_property(row, "modulate:a", 0.0, 1.0); ft.parallel().tween_property(dim, "color:a", 0.0, 1.0); await ft.finished
	row.queue_free(); dim.queue_free(); ui.queue_free()

## dream line in StoryUI's caption box (the room caption is hidden meanwhile: one caption box)
func _dline(ui: StoryUI, en: String, tr: String) -> void:
	await Audio.wait_idle(15.0)
	ui.en_l.text = en; ui.tr_l.text = tr if App.tr_on() else ""; ui.tr_l.visible = ui.tr_l.text != ""; ui.panel.visible = true
	m.cap_panel.visible = false
	Audio.say(en)
	await _w(0.2); await Audio.wait_idle(15.0); await _w(0.8)
	ui.panel.visible = false

func _sleep(b: Node, cl: CanvasLayer) -> void:
	b.cam_shot = {"pos": b.OBJ.bed.focus + Vector3(0.9, 1.3, 0.9), "at": b.OBJ.bed.focus + Vector3(-0.4, -0.15, 0)}
	await speak(b, "", "", "Good night!", "İyi geceler!")
	b.S.lamp = "off"; b.S.ceiling = "off"; b.S.desklamp = "off"; b._apply_states(); Audio.sfx("metalClick", -6.0)
	await speak(b, "", "", "I am sleeping.", "Uyuyorum.")
	b.cap_panel.visible = false
	var black := ColorRect.new(); black.color = Color(0.05, 0.05, 0.12, 0.0); black.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(black)
	var tw := create_tween(); tw.tween_property(black, "color:a", 1.0, 2.0); await tw.finished
	set_stage(day, "done")
	var nxt := day + 1
	Life.advance_day(true)
	await _w(1.2)
	Life.event("morning")
	b.S.ceiling = "on"; b._apply_states()
	tw = create_tween(); tw.tween_property(black, "color:a", 0.0, 1.5); await tw.finished
	black.queue_free()
	await _day_title(cl, nxt)
	if nxt == 6:
		day = 6; D = data(6); _guided = {}; _cur = {}
		reg_all(b, D.get("lines", {}))
		set_stage(6, "alarm"); flag("d56_lying", true)
		bed_lock = false
		await _alarm(b)
	else:
		bed_lock = false
		await _to_day7(b)
	cl.queue_free()

## ===== HOOK (red, day 7): day 6 ends lying in bed on day 7, 00:00 -> morning. If red's day-7 script exists, it takes over here:
## it must offer  static func begin(tree: SceneTree)  (same contract as Day56Routine.begin). Otherwise: alarm-free get-up, free play.
func _to_day7(b: Node) -> void:
	flag("d7", "start")
	if ResourceLoader.exists(DAY7_SCRIPT):
		var s = load(DAY7_SCRIPT)
		if s and s.has_method("begin"): s.begin(get_tree()); return
	b.cam_shot = {}
	await b.get_up_sequence()
	b.mode = "play"; b._update_hand()

func _day_title(cl: CanvasLayer, n: int) -> void:
	var v := VBoxContainer.new(); v.name = "DayTitle"; v.set_anchors_preset(Control.PRESET_CENTER_TOP); v.offset_top = 150; v.offset_left = -400; v.offset_right = 400
	v.alignment = BoxContainer.ALIGNMENT_CENTER; v.modulate.a = 0.0; cl.add_child(v)
	for e in [["It is a new day.", 44, Color.WHITE, "Yeni bir gün."], ["Day %d" % n, 30, Color(1, 0.92, 0.7), "%d. Gün" % n]]:
		var l := Label.new(); l.text = e[0]; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.add_theme_font_size_override("font_size", e[1]); l.add_theme_color_override("font_color", e[2])
		l.add_theme_constant_override("outline_size", 10); l.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25))
		if UI.font_b: l.add_theme_font_override("font", UI.font_b)
		v.add_child(l)
		if App.tr_on():
			var lt := Label.new(); lt.text = e[3]; lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lt.add_theme_font_size_override("font_size", 22); lt.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
			lt.add_theme_constant_override("outline_size", 8); lt.add_theme_color_override("font_outline_color", Color(0.1, 0.12, 0.25)); v.add_child(lt)
	Audio.say("It is a new day.")
	var tw := create_tween(); tw.tween_property(v, "modulate:a", 1.0, 0.4); tw.tween_interval(2.2); tw.tween_property(v, "modulate:a", 0.0, 0.5)
	await tw.finished; v.queue_free()
	await Audio.wait_idle(5.0)
