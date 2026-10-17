## v33 child-drive (red): the street in front of a destination (hospital / school / work / shop) for a CHILD player's
## trips (ChildDrive.plan). "leave": the child and the parent come out of the door, walk to the car, get in, drive off;
## "arrive": the car drives in and stops, both get out and walk in side by side; "home" hands over to world_exterior
## (spawn home_car), where the parent drives into the home driveway. Only ever entered from ChildDrive (children).
extends Node3D

const DOOR := Vector3(0, 0, 8.0)
const PARK := Vector3(0, 0.07, 2.6)
const CAM_OFF := Vector3(2.5, 7.5, -8.5)

var mode := "busy"            # Life.guide_to reads it
var cam: Camera3D             # Life.guide_to pans from it
var cd: ChildDrive
var kid: DemoCharacter
var car: StreetObject
var door: Node3D
var sign_en: Label3D
var sign_tr: Label3D
var focus_on: Node3D
var _focus := Vector3.ZERO

func _ready() -> void:
	var plan: Dictionary = ChildDrive.plan.duplicate()
	if plan.is_empty(): plan = {"mode": "arrive", "from": "home", "to": "hospital"}   # QA / direct load
	_build()
	kid = DemoCharacter.new(); kid.name = "Kid"; add_child(kid)
	kid.setup(String(CharacterHook.creator().get("gender", "men"))); Game.apply_character(kid); kid.play("idle", 0.0)
	cd = load("res://scripts/story/child_drive.gd").new(); cd.name = "ChildDrive"; cd.w = self; add_child(cd)
	cd.kid = kid; cd.kid_hero = kid; cd.car = car
	cam = Camera3D.new(); cam.fov = 50.0; add_child(cam); cam.current = true
	if String(plan.mode) == "leave": _place_leave(String(plan.from))
	else: _place_arrive(String(plan.to))
	_snap_cam()
	_run.call_deferred(plan)

## Life.guide_to speaks the objective through the host: the child's own voice in the one box
func say_line(t: String) -> void: await cd.say_me(t, 0.1)

func _process(dt: float) -> void:
	if focus_on == null or cam == null: return
	_focus = _focus.lerp(focus_on.global_position, 1.0 - exp(-3.0 * dt))
	cam.global_position = _focus + CAM_OFF; cam.look_at(_focus + Vector3(0, 0.6, 0), Vector3.UP)
func _snap_cam() -> void:
	_focus = focus_on.global_position; cam.global_position = _focus + CAM_OFF; cam.look_at(_focus + Vector3(0, 0.6, 0), Vector3.UP)

func _run(plan: Dictionary) -> void:
	await get_tree().process_frame
	if String(plan.mode) == "leave":
		await _leave(String(plan.to))
		if String(plan.to) == "home":
			ChildDrive.plan = {"mode": "home"}
			App.came_from = "outside"; StoryNav.travel(get_tree(), Game.WORLD_SCENE, "home_car"); return
		await Game.fade(1.0, 0.5)
		_place_arrive(String(plan.to)); _snap_cam()
		Game.fade(0.0, 0.5)
	await _arrive(String(plan.to))

# ------------------------------------------------------------------ the street front
func _sign(key: String) -> void:
	var place := ChildDrive.place_of(key)
	var en: String = {"the hospital": "HOSPITAL", "school": "SCHOOL", "the shop": "SHOP"}.get(place, "OFFICE")
	var tr: String = {"the hospital": "HASTANE", "school": "OKUL", "the shop": "DÜKKAN"}.get(place, "OFİS")
	sign_en.text = en; sign_tr.text = tr; sign_tr.visible = App.tr_on()
	var col: Color = {"the hospital": Color(0.93, 0.93, 0.95), "school": Color(0.93, 0.80, 0.55), "the shop": Color(0.75, 0.86, 0.80)}.get(place, Color(0.70, 0.76, 0.86))
	($Building.get_surface_override_material(0) as StandardMaterial3D).albedo_color = col
	$Cross.visible = place == "the hospital"

func _build() -> void:
	var we := WorldEnvironment.new(); var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.86, 0.89, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1.0, 0.97, 0.93); env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.5
	env.adjustment_enabled = true; env.adjustment_saturation = 1.18; env.adjustment_contrast = 1.06
	we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.95, 0.85); sun.light_energy = 1.45; add_child(sun)
	sun.look_at_from_position(Vector3(7, 8, -9), Vector3.ZERO)
	var k := MeshKit.new()
	k.box(Vector3(160, 0.1, 80), Vector3(0, -0.06, 10), Color(0.62, 0.74, 0.55))      # grass
	k.box(Vector3(160, 0.04, 8), Vector3(0, 0.0, 0), Color(0.30, 0.31, 0.33))           # road
	for x in range(-78, 80, 6): k.box(Vector3(2.4, 0.045, 0.16), Vector3(x, 0.005, 0), Color(0.95, 0.95, 0.9))
	k.box(Vector3(160, 0.14, 4.0), Vector3(0, 0.05, 6.0), Color(0.80, 0.79, 0.76))      # sidewalk
	k.box(Vector3(160, 0.14, 4.0), Vector3(0, 0.05, -6.0), Color(0.80, 0.79, 0.76))
	k.box(Vector3(2.2, 0.15, 1.0), Vector3(0, 0.06, 8.4), Color(0.72, 0.71, 0.68))      # step
	for x in [-14.0, -7.0, 7.0, 14.0]:                                                  # street lamps
		k.box(Vector3(0.12, 4.2, 0.12), Vector3(x, 2.1, 4.4), Color(0.22, 0.23, 0.26)); k.box(Vector3(0.5, 0.16, 0.3), Vector3(x, 4.2, 4.2), Color(0.95, 0.9, 0.7))
	for x in [-30.0, -20.0, 22.0, 32.0]:                                                # neighbours
		k.box(Vector3(8, 5 + absf(x) * 0.05, 7), Vector3(x, 2.6, 13), Color(0.86, 0.82, 0.76).darkened(absf(x) * 0.004))
	k.commit(self)
	var b := MeshInstance3D.new(); b.name = "Building"; var bm := BoxMesh.new(); bm.size = Vector3(16, 7, 8); b.mesh = bm
	b.position = Vector3(0, 3.5, 12.0); var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.93, 0.93, 0.95); b.set_surface_override_material(0, mat); add_child(b)
	var w := MeshKit.new()
	for x in [-6.0, -3.5, 3.5, 6.0]:
		for y in [2.0, 4.8]: w.box(Vector3(1.6, 1.2, 0.08), Vector3(x, y, 7.97), Color(0.55, 0.68, 0.82))
	for x in [-1.6, 1.6]: w.box(Vector3(1.6, 1.2, 0.08), Vector3(x, 4.8, 7.97), Color(0.55, 0.68, 0.82))
	w.box(Vector3(1.8, 2.5, 0.06), Vector3(0, 1.25, 7.985), Color(0.25, 0.26, 0.3))   # door frame
	w.box(Vector3(5.0, 1.0, 0.12), Vector3(0, 3.3, 7.92), Color(0.18, 0.32, 0.62))    # sign board
	w.commit(self)
	var cr := MeshKit.new(); cr.box(Vector3(0.9, 0.28, 0.06), Vector3(0, 0, 0), Color(0.85, 0.1, 0.1)); cr.box(Vector3(0.28, 0.9, 0.06), Vector3(0, 0, 0), Color(0.85, 0.1, 0.1))
	var cn := Node3D.new(); cn.name = "Cross"; cn.position = Vector3(0, 6.1, 7.92); add_child(cn); cr.commit(cn)
	door = Node3D.new(); door.position = Vector3(-0.8, 0, 7.94); add_child(door)
	var dk := MeshKit.new(); dk.box(Vector3(1.6, 2.4, 0.06), Vector3(0.8, 1.2, 0), Color(0.62, 0.78, 0.88)); dk.commit(door)
	sign_en = Label3D.new(); sign_en.position = Vector3(0, 3.38, 7.84); sign_en.rotation.y = PI; sign_en.font_size = 120; sign_en.pixel_size = 0.005
	sign_en.modulate = Color(1, 1, 1); sign_en.outline_size = 0; add_child(sign_en)
	sign_tr = Label3D.new(); sign_tr.position = Vector3(0, 3.03, 7.84); sign_tr.rotation.y = PI; sign_tr.font_size = 60; sign_tr.pixel_size = 0.005
	sign_tr.modulate = Color(0.75, 0.88, 1.0); sign_tr.outline_size = 0; add_child(sign_tr)
	car = StreetObject.new(); car.kind = "car"; car.color = Color(0.36, 0.52, 0.76); car.name = "FamilyCar"; add_child(car)
	car.S.locked = false

func _place_leave(from: String) -> void:
	_sign(from)
	car.global_position = PARK; car.global_rotation.y = -PI * 0.5
	kid.global_position = DOOR + Vector3(-0.45, 0, 0.1); kid.rotation.y = PI
	focus_on = kid

func _place_arrive(to: String) -> void:
	_sign(to)
	cd.riding = false
	car.global_position = PARK + Vector3(38, 0, 0); car.global_rotation.y = -PI * 0.5
	if cd.par == null: cd.spawn_parent(car.global_position)
	cd.riding = true; cd._process(0.0)
	kid.play("sit_idle", 0.0); cd.par.play("sit_idle", 0.0)
	focus_on = kid

func _door(open: bool) -> void:
	Audio.sfx("doorOpen_1" if open else "doorClose_2", -8.0)
	var tw := create_tween(); tw.tween_property(door, "rotation:y", -1.4 if open else 0.0, 0.45).set_trans(Tween.TRANS_SINE); await tw.finished

func _leave(to: String) -> void:
	if cd.par == null: cd.spawn_parent(DOOR + Vector3(0.45, 0, 0.1))
	cd.par.rotation.y = PI
	await _door(true)
	cd.walk(cd.par, cd.par, [DOOR + Vector3(0.45, 0, -1.4)])
	await cd.walk(kid, kid, [DOOR + Vector3(-0.45, 0, -1.4)])
	_door(false)
	var cp := car.global_position + Vector3(0, 1.0, 0)
	await Life.guide_to({"pos": cp + Vector3(3.5, 3.0, 6.0), "at": cp}, "Go to the car.", {"tr": ChildDrive.tr_of("Go to the car."), "repeat": true})
	await cd.say_parent("Get in the car, please.")
	var pd := [false]
	var pw := func():
		await cd.walk(cd.par, cd.par, [cd._g(Vector3(1.4, 0, -2.9)), cd._g(Vector3(-1.4, 0, -2.9)), cd._g(ChildDrive.SPOT_D)])
		await cd.turn(cd.par, car.global_rotation.y + PI * 0.5, 0.25); pd[0] = true
	pw.call()
	await cd.walk(kid, kid, [cd._g(ChildDrive.SPOT_P)])
	await cd.turn(kid, car.global_rotation.y - PI * 0.5, 0.25)
	while not pd[0]: await get_tree().process_frame
	kid.play("open_door", 0.2)
	await cd.say_me("I am opening the car door.", 0.1)
	await cd.doors(true)
	cd.sit(cd.par, cd.par, ChildDrive.SEAT_D)
	await cd.sit(kid, kid, ChildDrive.SEAT_P)
	cd.riding = true
	await get_tree().create_timer(0.3).timeout; await cd.doors(false)
	await cd.say_parent("Put on your seat belt." if to != "home" else "Let's go home.", 0.2)
	var line := ChildDrive.drive_line(ChildDrive.place_of(to), cd.pm)
	Objectives.set_list([{"id": "child_drive", "en": line, "tr": ChildDrive.tr_of(line)}])
	cd.drive(ChildDrive.path([car.global_position, car.global_position + Vector3(-50, 0, 0)]), 7.0, 0.0, false, 8.0)
	await get_tree().create_timer(1.2).timeout
	await cd.say_me(line, 0.0)
	while car.global_position.x > -24.0: await get_tree().process_frame
	print("CHILD_DRIVE left for ", to)

func _arrive(to: String) -> void:
	var place := ChildDrive.place_of(to)
	cd.drive(ChildDrive.path([car.global_position, PARK]), 6.5, 6.5, true)
	await get_tree().create_timer(1.4).timeout
	await cd.say_me("The car is stopping.", 0.0)
	while car.global_position.distance_to(PARK) > 0.08: await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	await cd.say_me("We are here.", 0.1)
	await cd.doors(true)
	cd.riding = false   # get_out moves both from the seats
	cd.get_out(cd.par, cd.par, ChildDrive.SPOT_D)
	await cd.get_out(kid, kid, ChildDrive.SPOT_P)
	await get_tree().create_timer(0.3).timeout
	await cd.say_me("I am closing the car door.", 0.0)
	await cd.doors(false)
	# the parent walks round the back of the car to the child; objective + pan to the building's door
	await cd.walk(cd.par, cd.par, [cd._g(Vector3(-1.4, 0, -2.9)), cd._g(Vector3(1.4, 0, -2.9)), kid.global_position + Vector3(0.9, 0, 0.3)])
	var dp := DOOR + Vector3(0, 1.4, 0)
	await Life.guide_to({"pos": dp + Vector3(2.5, 1.6, -6.0), "at": dp}, ChildDrive.go_line(place), {"tr": ChildDrive.tr_of(ChildDrive.go_line(place)), "repeat": true})
	await cd.say_parent("We are here. Let's go in.", 0.1)
	cd.walk(cd.par, cd.par, [DOOR + Vector3(0.45, 0, -1.3), DOOR + Vector3(0.45, 0, -0.2)])
	await cd.walk(kid, kid, [DOOR + Vector3(-0.45, 0, -1.3), DOOR + Vector3(-0.45, 0, -0.2)])
	await _door(true)
	cd.walk(cd.par, cd.par, [DOOR + Vector3(0.4, 0, 1.6)])
	cd.walk(kid, kid, [DOOR + Vector3(-0.4, 0, 1.6)])
	await get_tree().create_timer(0.7).timeout
	cd.ui.hide_caption()
	print("CHILD_DRIVE arrived at ", to)
	await Game.fade(1.0, 0.5)
	var tree := get_tree()
	if to == "hospital":
		HospitalScene.start_day2_visit(tree)
		tree.create_timer(0.25).timeout.connect(Game.fade.bind(0.0, 0.3))   # bound to the autoload (this scene is freed)
	else:
		load("res://scripts/story/work_summary.gd").play(tree)
		await tree.create_timer(0.75).timeout
		Game.fade(0.0, 0.05)
