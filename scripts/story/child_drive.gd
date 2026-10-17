## v33 child-drive (red): a CHILD player never drives. A parent (the first mom / dad in save.json state.family) walks to
## the car with the child, gets in on the driver side (the child on the passenger side), drives with the camera
## following, and on arrival both get out and the parent walks in beside the child. Adults never reach this file:
## every hook is `if ChildDrive.<check>(): <child flow>` and the adult code path below it is byte-for-byte v32.
##
## Hooks (all tiny): street_object.gd _drive (car choice), world_exterior.gd (escort on the day-2 morning + the drive
## back into the home driveway), hospital_day2.gd / work_summary.gd (day-2 transitions), work.gd (driving line),
## phone.gd + main.gd + room_phone.gd (family screen: a child needs a mom or a dad).
## Between two places the drive plays in scenes/child_drive_stop.tscn (a street front with the destination building).
##
## Lines: the child's own narrator voice only (pack clip, else res://voice_drive/<narrator>/<md5>.ogg, else silent:
## never another voice). Parent lines: the parent's own voice (v_amy / v_ryan pack clips, else voice_drive/amy|ryan).
## Captions: the ONE standard StoryUI box (EN + TR button inside); TR from data/extra_lines.json.
class_name ChildDrive
extends Node

const STOP_SCENE := "res://scenes/child_drive_stop.tscn"
const VDIR := "res://voice_drive"
const NpcTalk := preload("res://scripts/core/npc_talk.gd")
const SEAT_D := Vector3(-0.36, 0.0, 0.05)    # car-local seat roots (sit_idle hips land on the seat)
const SEAT_P := Vector3(0.36, 0.0, 0.05)
const SPOT_D := Vector3(-1.6, 0, 0.3)        # car-local standing spots beside the doors (driver = -X, as StreetObject)
const SPOT_P := Vector3(1.6, 0, 0.3)
const HINT := "Add a mom or a dad first."

## the trip between scenes: {"mode": "arrive" | "leave" | "home", "from": key, "to": key}  (keys: home / hospital / work)
static var plan := {}
static var _hint_t := -10.0

# ------------------------------------------------------------------ who drives
static func is_child_player() -> bool: return CharacterHook.is_child(CharacterHook.state())
static func is_parent(m) -> bool: return m is Dictionary and String(m.get("role", "")) in ["mother", "father"]
static func has_parent(fam) -> bool:
	if fam is Array:
		for m in fam:
			if is_parent(m): return true
	return false
static func parent_member() -> Dictionary:
	var fam = CharacterHook.state().get("family", [])
	if fam is Array:
		for m in fam:
			if is_parent(m): return m
	return {}
## true only for a child player with a mom or a dad (adults: always false -> the v32 code runs unchanged)
static func active() -> bool: return is_child_player() and not parent_member().is_empty()
static func is_mom(m: Dictionary) -> bool: return String(m.get("role", "")) == "mother"
static func parent_voice(m: Dictionary) -> String: return "amy" if is_mom(m) else "ryan"
static func parent_label(m: Dictionary) -> String: return "Mom" if is_mom(m) else "Dad"   # the child calls them Mom / Dad

## "My mom is driving me to school." (dest: school / the hospital / work / home / the shop)
static func drive_line(dest: String, m := {}) -> String:
	if m.is_empty(): m = parent_member()
	var who := "dad" if (not m.is_empty() and not is_mom(m)) else "mom"
	return "My %s is driving me %s." % [who, "home" if dest == "home" else "to " + dest]
## any existing "I am driving <to ...>." line -> the child variant; adults (and other lines) unchanged
static func child_line(en: String) -> String:
	if not en.begins_with("I am driving ") or not en.ends_with(".") or not is_child_player(): return en
	var to := en.trim_prefix("I am driving ").trim_suffix(".")
	if to == "home": return drive_line("home")
	if to.begins_with("to "): return drive_line(to.trim_prefix("to "))
	return en
## place word for a destination key (the job label decides school / work / the shop, like the car chips)
static func place_of(key: String) -> String:
	if key == "hospital": return "the hospital"
	if key == "home": return "home"
	var lbl := String(load("res://scripts/story/work.gd").car_label(String(CharacterHook.state().get("job", "")), true))
	return "school" if lbl == "Go to school" else ("the shop" if lbl == "Go shopping" else "work")
static func go_line(place: String) -> String:
	return {"school": "Go to school.", "the hospital": "Go to the hospital.", "the shop": "Go shopping.", "home": "Go back home."}.get(place, "Go to work.")

# ------------------------------------------------------------------ voice + TR
static func _own_clip(en: String, v: String) -> AudioStream:
	var p := "%s/%s/%s.ogg" % [VDIR, v, en.md5_text().substr(0, 12)]
	return load(p) as AudioStream if ResourceLoader.exists(p) else null
static func voice_on() -> bool: return bool(CharacterHook.state().get("voice", true))
## the player's line, in the player's OWN narrator voice (never another voice)
static func speak_child(en: String) -> void:
	if not voice_on(): return
	var alt := Audio.narrator_alt(en)
	if alt: Audio.say_stream(alt, en); return
	var own := _own_clip(en, Audio.narrator)
	if own: Audio.say_stream(own, en); return
	if Audio.narrator == "f": Voice.say(en)
## a parent line in the parent's own voice
static func speak_parent(en: String, v: String) -> void:
	if not voice_on(): return
	if Audio.index.has("v_%s %s" % [v, Audio.norm(en)]): Audio.say_as(en, v); return
	var own := _own_clip(en, v)
	if own: Audio.say_stream(own, en)
static func tr_of(en: String) -> String:
	var t := StoryUI.tr_of(en)
	if t == "": t = Lines.tr_of(en)
	if t == "": t = String(Objectives.TR_FALLBACK.get(en, ""))
	return t

## family screen hint: the host's ONE caption box (main.gd / outdoor scene caption), spoken in the child's voice
static func hint_parent(tree: SceneTree) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _hint_t < 2.5: return
	_hint_t = now
	var sc := RoutineScope.current(tree)
	if sc and sc.has_method("caption"):
		if sc.get_method_argument_count("caption") >= 2: sc.caption(HINT, false)
		else: sc.caption(HINT)
	speak_child(HINT)
	print("CHILD_DRIVE hint: ", HINT)

# ------------------------------------------------------------------ entry points (static, called by the hooks)
## world_exterior day-2 morning: the parent comes out with the child and walks beside them to the car
static func escort(w: Node) -> void:
	if not active() or w.get_node_or_null("ChildDrive"): return
	var cd := _make(w)
	cd.spawn_parent(w.player.global_position + w.player.hero.global_basis.x * -1.0 + Vector3(0, 0, -0.4))
	cd.following = true

## street_object.gd _drive: true when the child flow took over (the adult code below the hook is skipped)
static func wants_drive(d: Dictionary) -> bool: return String(d.get("day2", "")) != "" and active()
static func depart(car: Node3D, d: Dictionary) -> void:
	var w := RoutineScope.current(car.get_tree())
	var cd: ChildDrive = w.get_node_or_null("ChildDrive")
	if cd == null:
		cd = _make(w); cd.spawn_parent(w.player.global_position + Vector3(-1.0, 0, -0.6))
	cd.run_depart(car, d)

## hospital_day2.gd / work_summary.gd: leave `from`, drive to `to` (hospital / work / home). covered = a black overlay
## already hides the screen (work_summary), so the scene can switch without another fade.
static func trip(tree: SceneTree, from: String, to: String, covered := false) -> void:
	plan = {"mode": "leave", "from": from, "to": to}
	print("CHILD_DRIVE trip ", from, " -> ", to)
	if covered: StoryNav.travel(tree, STOP_SCENE, "", true)
	else: StoryNav.travel(tree, STOP_SCENE)

## world_exterior with spawn home_car: the parent drives into the home driveway
static func arriving_home() -> bool: return String(plan.get("mode", "")) == "home" and active()
static func arrive_home(w: Node, lot: Node) -> void:
	plan = {}
	var cd := _make(w)
	cd.run_arrive_home.call_deferred(lot)

static func _make(host: Node) -> ChildDrive:
	var cd: ChildDrive = load("res://scripts/story/child_drive.gd").new(); cd.name = "ChildDrive"; cd.w = host; host.add_child(cd)
	return cd

# ------------------------------------------------------------------ instance: one trip on the host scene
var w: Node                  # host scene (world_exterior or child_drive_stop)
var kid: Node3D              # the player node (WorldPlayer outdoors, a DemoCharacter in the stop scene)
var kid_hero: DemoCharacter
var par: DemoCharacter
var pm := {}
var pv := "ryan"
var ui: StoryUI
var car: Node3D
var riding := false
var following := false

func _ready() -> void:
	pm = parent_member(); pv = parent_voice(pm)
	ui = StoryUI.new(); add_child(ui)
	if w and w.get("player"): kid = w.player; kid_hero = w.player.hero

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

## StoryUI's TR button: the one persisted flag, the outdoor HUD follows live
func toggle_tr(on: bool) -> void:
	App.save_tr(on)
	if w and w.get("S") is Dictionary: w.S["tr"] = on
	if w and w.get("hud") and w.hud.has_method("set_tr"): w.hud.set_tr(on)

func spawn_parent(at: Vector3) -> void:
	par = CharacterHook.make_family_member(pm)
	if par == null: par = DemoCharacter.new(); par.ready.connect(func(): par.setup("women" if is_mom(pm) else "men"), CONNECT_ONE_SHOT)
	par.name = "Parent"; w.add_child(par)
	at.y = kid.global_position.y if kid else 0.07
	par.global_position = at
	if kid_hero: par.rotation.y = kid_hero.global_rotation.y
	par.play("idle", 0.0)

# ---- lines (the one StoryUI box)
func _hold(en: String, t0: int) -> void:
	await _w(0.25); await Audio.wait_idle(12.0)
	var left := (0.9 + en.length() * 0.045) - (Time.get_ticks_msec() - t0) / 1000.0
	if left > 0.0: await _w(left)
func say_me(en: String, pause := 0.35) -> void:
	await Audio.wait_idle(12.0)
	var t0 := Time.get_ticks_msec()
	ui.live(en, tr_of(en)); speak_child(en)
	await _hold(en, t0); await _w(pause)
func say_parent(en: String, pause := 0.35) -> void:
	await Audio.wait_idle(12.0)
	var t0 := Time.get_ticks_msec()
	var st := NpcTalk.begin(par, kid.global_position if kid else par.global_position)   # pose kept (npc_talk rule)
	ui.live(parent_label(pm) + ": " + en, tr_of(en)); speak_parent(en, pv)
	await _hold(en, t0); NpcTalk.end(par, st); await _w(pause)

# ---- motion
func walk(n: Node3D, hero: DemoCharacter, pts: Array, sp := 1.35) -> void:
	hero.play("walk", 0.2); hero.player.speed_scale = PlayerController.walk_rate(hero, sp)
	for p in pts:
		var to: Vector3 = p
		var t := 0.0
		while t < 12.0:
			if not is_inside_tree(): return
			var d := to - n.global_position; d.y = 0.0
			if d.length() < 0.05: break
			var dt := get_process_delta_time()
			n.global_position += d.normalized() * minf(d.length(), sp * dt)
			hero.global_rotation.y = lerp_angle(hero.global_rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
			await get_tree().process_frame; t += dt
	hero.play("idle", 0.25); hero.player.speed_scale = 1.0

func turn(hero: DemoCharacter, yaw: float, t := 0.3) -> void:
	var tw := create_tween(); tw.tween_method(func(k: float): hero.global_rotation.y = lerp_angle(hero.global_rotation.y, yaw, k), 0.0, 1.0, t)
	await tw.finished

func _g(local: Vector3) -> Vector3:
	var p := car.to_global(local); p.y = car.global_position.y; return p

## the passenger door (StreetObject only has the driver's door): a mirrored panel, built once per car
func pass_door() -> Node3D:
	if car.has_meta("pass_door"): return car.get_meta("pass_door")
	var paint := CarKit.paint_for(car.get("color") if car.get("color") is Color else Color(0.36, 0.52, 0.76))
	var d := CarKit.new()
	d.box(CarKit.PAINT, Vector3(0.05, 0.56, 1.1), Vector3(0.005, 0.02, 0.55), paint)
	d.box(CarKit.GLASS, Vector3(0.04, 0.4, 0.98), Vector3(0, 0.52, 0.55), Color.WHITE)
	d.box(CarKit.PAINT, Vector3(0.05, 0.035, 1.0), Vector3(0.005, 0.315, 0.55), Color(0.82, 0.83, 0.85))
	d.box(CarKit.PAINT, Vector3(0.03, 0.035, 0.14), Vector3(0.04, 0.2, 0.9), Color(0.82, 0.83, 0.85))
	var dn := Node3D.new(); dn.name = "PassDoor"; dn.position = Vector3(0.93, 0.6, -0.3); car.add_child(dn); d.commit(dn)
	car.set_meta("pass_door", dn); return dn
func drv_door() -> Node3D: return car.parts.door if car.get("parts") is Dictionary and car.parts.has("door") else null
func doors(open: bool) -> void:
	var tw := create_tween().set_parallel(true)
	if drv_door(): tw.tween_property(drv_door(), "rotation:y", -1.1 if open else 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pass_door(), "rotation:y", 1.1 if open else 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	if car.get("S") is Dictionary: car.S.open = open; car.S.locked = false
	Audio.sfx("doorOpen_1" if open else "doorClose_2", -6.0)
	await tw.finished

## step from the door spot into the seat and sit (stand_to_sit -> sit_idle); the seat then rides with the car
func sit(n: Node3D, hero: DemoCharacter, seat: Vector3) -> void:
	if n == kid and kid.get("sitting") != null: kid.sitting = true
	var to := car.to_global(seat)
	await turn(hero, atan2(to.x - n.global_position.x, to.z - n.global_position.z), 0.2)
	hero.play("walk", 0.15)
	var tw := create_tween(); tw.tween_property(n, "global_position", to, 0.55).set_trans(Tween.TRANS_SINE); await tw.finished
	hero.global_rotation.y = car.global_rotation.y
	hero.play("stand_to_sit", 0.2); await _w(0.5); hero.play("sit_idle", 0.3)

func get_out(n: Node3D, hero: DemoCharacter, spot: Vector3) -> void:
	hero.play("sit_to_stand", 0.2); await _w(0.45)
	var to := _g(spot)
	hero.global_rotation.y = atan2(to.x - n.global_position.x, to.z - n.global_position.z)
	hero.play("walk", 0.15)
	var tw := create_tween(); tw.tween_property(n, "global_position", to, 0.55).set_trans(Tween.TRANS_SINE); await tw.finished
	hero.play("idle", 0.25)
	if n == kid and kid.get("sitting") != null: kid.sitting = false

func _process(dt: float) -> void:
	if riding and car:
		if kid: kid.global_position = car.to_global(SEAT_P); kid_hero.global_rotation.y = car.global_rotation.y
		if par: par.global_position = car.to_global(SEAT_D); par.global_rotation.y = car.global_rotation.y
	elif following and par and kid:
		var want: Vector3 = kid.global_position + kid_hero.global_basis.x * -0.95 - kid_hero.global_basis.z * 0.35
		var d := want - par.global_position; d.y = 0.0
		var anim := String(par.player.current_animation)
		if d.length() > 0.45:
			var sp := minf(PlayerController.WALK, d.length() * 2.2)
			par.global_position += d.normalized() * minf(d.length(), sp * dt)
			par.global_rotation.y = lerp_angle(par.global_rotation.y, atan2(d.x, d.z), 1.0 - exp(-8.0 * dt))
			if anim != "walk": par.play("walk", 0.25)
			par.player.speed_scale = PlayerController.walk_rate(par, sp)
		elif d.length() < 0.2 and anim == "walk":
			par.play("idle", 0.3); par.player.speed_scale = 1.0
		elif anim != "walk":
			par.global_rotation.y = lerp_angle(par.global_rotation.y, kid_hero.global_rotation.y, 1.0 - exp(-4.0 * dt))

## a smooth path through `pts` (rounded corners, r metres)
static func path(pts: Array, r := 4.0) -> Curve3D:
	var c := Curve3D.new(); c.bake_interval = 0.25
	for i in pts.size():
		var p: Vector3 = pts[i]
		var din: Vector3 = (p - pts[i - 1]).normalized() if i > 0 else Vector3.ZERO
		var dout: Vector3 = (pts[i + 1] - p).normalized() if i < pts.size() - 1 else Vector3.ZERO
		if i == 0: c.add_point(p, Vector3.ZERO, dout * r * 0.7)
		elif i == pts.size() - 1: c.add_point(p, -din * r * 0.7, Vector3.ZERO)
		else:
			c.add_point(p - din * r, Vector3.ZERO, din * r * 0.55)
			c.add_point(p + dout * r, -dout * r * 0.55, Vector3.ZERO)
	return c

## move the car along the curve (accelerate to vmax; stop = brake to rest at the end). Camera follows the seated kid.
func drive(curve: Curve3D, vmax := 7.0, v0 := 0.0, stop := false, max_t := 60.0) -> void:
	var L := curve.get_baked_length(); var s := 0.0; var v := v0; var t := 0.0; var y := car.global_position.y
	while s < L - 0.02 and t < max_t:
		if not is_inside_tree(): return
		var dt := get_process_delta_time()
		v = minf(v + 3.0 * dt, vmax)
		if stop: v = minf(v, sqrt(2.0 * 2.6 * maxf(L - s, 0.0)) + 0.25)
		s = minf(s + v * dt, L)
		var p := curve.sample_baked(s, true); p.y = y
		var q := curve.sample_baked(minf(s + 0.8, L), true); q.y = y
		car.global_position = p
		if (q - p).length() > 0.05: car.global_rotation.y = atan2(q.x - p.x, q.z - p.z)
		await get_tree().process_frame; t += dt

# ------------------------------------------------------------------ world: departure from home (car choice)
func run_depart(c: Node3D, d: Dictionary) -> void:
	car = c; following = false
	var place := String(d.get("place", "work"))
	if w.has_method("save_game"): w.save_game()
	w.mode = "busy"
	if w.has_method("_hide_chips"): w._hide_chips()
	if w.get("hud"): w.hud.cue_on = false
	kid.busy = true
	await say_parent("Get in the car, please.")
	# the child walks round the front of the car to the passenger door, the parent to the driver's door
	var par_done := [false]
	var pw := func():
		await _w(0.7)
		await walk(par, par, [_g(Vector3(-2.3, 0, -0.6)), _g(SPOT_D)])
		await turn(par, car.global_rotation.y + PI * 0.5, 0.25); par_done[0] = true
	pw.call()
	await walk(kid, kid_hero, [_g(Vector3(-1.5, 0, 2.9)), _g(Vector3(1.5, 0, 2.9)), _g(SPOT_P)])
	await turn(kid_hero, car.global_rotation.y - PI * 0.5, 0.25)
	while not par_done[0]: await get_tree().process_frame
	kid_hero.play("open_door", 0.2)
	await say_me("I am opening the car door.", 0.1)
	await doors(true)
	sit(par, par, SEAT_D)
	await sit(kid, kid_hero, SEAT_P)
	riding = true
	await _w(0.4); await doors(false)
	await say_parent("Put on your seat belt.", 0.2)
	await say_parent("Let's go!", 0.1)
	# a short drive: down the driveway, a left turn onto the street, camera following
	var p0 := car.global_position; var f := car.global_basis.z; f.y = 0.0; f = f.normalized()
	var lane := (floorf(p0.z / 40.0 + 0.5) + 0.5) * 40.0 - 2.0
	var a := Vector3(p0.x, p0.y, lane) if absf(f.z) > 0.7 else p0 + f * 10.0
	var crv := path([p0, a, a + Vector3(45, 0, 0)], 4.0)
	var line := drive_line(place, pm)
	Objectives.set_list([{"id": "child_drive", "en": line, "tr": tr_of(line)}])
	drive(crv, 7.0, 0.0, false, 9.0)
	await _w(1.6)
	await say_me(line, 0.0)
	while is_inside_tree() and car.global_position.distance_to(crv.get_point_position(crv.point_count - 1)) > 2.0 and riding:
		await get_tree().process_frame
		if car.global_position.distance_to(p0) > 34.0: break
	plan = {"mode": "arrive", "from": "home", "to": String(d.get("day2", "work"))}
	print("CHILD_DRIVE depart home -> ", plan.to)
	StoryNav.travel(car.get_tree(), STOP_SCENE)

# ------------------------------------------------------------------ world: the drive back into the home driveway
func run_arrive_home(lot: Node) -> void:
	for o in lot.find_children("*", "StreetObject", true, false) + w.find_children("*", "StreetObject", true, false):
		if o.kind == "car": car = o; break
	if car == null:
		push_warning("child_drive: no home car"); w._day2_go_inside(lot); return
	w.mode = "busy"; kid.busy = true
	if kid.get("sitting") != null: kid.sitting = true
	var p0 := car.global_position
	var lane := (floorf(p0.z / 40.0 + 0.5) + 0.5) * 40.0 - 2.0
	var a := Vector3(p0.x, p0.y, lane)
	var crv := path([a - Vector3(34, 0, 0), a, p0], 4.0)
	car.global_position = crv.sample_baked(0.0); car.global_rotation.y = PI * 0.5
	spawn_parent(car.global_position)
	riding = true; _process(0.0)
	kid_hero.play("sit_idle", 0.0); par.play("sit_idle", 0.0)
	if w.get("grid"): w.grid.load_around_now(car.global_position)
	if w.get("cam"): w.cam.focus = kid.global_position; w.cam.snap()
	drive(crv, 6.5, 6.5, true)
	await _w(0.9)
	var line := drive_line("home", pm)
	Objectives.set_list([{"id": "child_drive", "en": line, "tr": tr_of(line)}])
	await say_me(line, 0.0)
	while car.global_position.distance_to(p0) > 0.08: await get_tree().process_frame
	await _w(0.2)
	await say_parent("We are home.", 0.1)
	await doors(true)
	riding = false   # get_out moves both from the seats
	get_out(par, par, SPOT_D)
	await get_out(kid, kid_hero, SPOT_P)
	await _w(0.2); await doors(false)
	kid.busy = false; following = true; ui.hide_caption()
	w.mode = "play"
	print("CHILD_DRIVE arrived home")
	await w._day2_go_inside(lot)   # the v32 objective + pan to the front door; the parent walks beside the child
