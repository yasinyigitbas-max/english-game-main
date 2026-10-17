## v31 day 2 morning, outside part: prompt to the player's car on the home driveway (camera pan + sound + top-left mission),
## then STOP at the car and call the single hook day2_reached_car(). Runs only while save "story".day2 == "car".
## HOOK for black bot: implement the destination choice (hospital / work) in day2_reached_car() (or connect to the
## day2_car_reached signal). Nothing beyond that point is implemented here.
extends Node

signal day2_car_reached(car: Node)
var w: Node   # world_exterior.gd (UniversalScene)
var car: Node3D
var fired := false
const NEAR := 3.4   # metres from the car centre (car is 4.2 m long)

static func should_run() -> bool:
	return load("res://scripts/story/day2_morning.gd").stage() == "car"

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run() -> void:
	await get_tree().process_frame
	car = _find_car()
	w.hud.cue_on = true
	if car == null:
		push_warning("day2_car: no car on the home lot")
		await Life.guide_to(null, "Go to the car.", {"tr": "Arabaya git."})
		return
	# Life.guide_to: notify + Objectives + pan (temp Camera3D on exterior which has no cam_shot)
	var at: Vector3 = car.global_position + Vector3(0, 0.8, 0)
	var p0: Vector3 = w.player.global_position
	var away: Vector3 = at - p0; away.y = 0
	if away.length() < 0.05: away = Vector3(0, 0, 1)
	var shot: Vector3 = at + away.normalized() * 5.5 + Vector3(0, 2.4, 0)
	await Life.guide_to({"pos": shot, "at": at}, "Go to the car.", {"tr": "Arabaya git."})

func _find_car() -> Node3D:
	var lot = w.grid.find_lot("home")
	var pool: Array = (lot.find_children("*", "StreetObject", true, false) if lot else []) + w.find_children("*", "StreetObject", true, false)
	var best: Node3D = null
	for o in pool:
		if o.kind == "car" and (best == null or o.global_position.distance_to(w.player.global_position) < best.global_position.distance_to(w.player.global_position)): best = o
	return best

func _process(_d: float) -> void:
	if fired or car == null or w.mode != "play" or w.player == null: return
	var a: Vector3 = w.player.global_position; var b: Vector3 = car.global_position; a.y = 0; b.y = 0
	if a.distance_to(b) < NEAR:
		fired = true; w.hud.cue_on = false; w.hud.set_mission("", "")
		w.mode = "busy"; w.player.velocity = Vector3.ZERO
		day2_reached_car(car)

## ===== HOOK (black bot): the player has reached the car on the morning of day 2. Destination choice hospital / work goes here.
## Default body only records the stage, emits day2_car_reached and gives control back (the car's own verbs stay usable).
func day2_reached_car(c: Node) -> void:
	print("DAY2_HOOK day2_reached_car fired")
	load("res://scripts/story/day2_morning.gd").set_stage("at_car")
	day2_car_reached.emit(c)
	# v31 (black): destination choice - the job option (work.json: Go to work / Go to school / Go shopping) or the hospital
	if c.S.locked: c.S.locked = false; Audio.sfx("metalClick", -6.0)
	w.mode = "play"
	await w.player.perform(c.it, func(): pass)   # walk up to the driver's door
	if not c.S.open: c.S.open = true; c.swing(c.parts.door, "rotation:y", -1.1); Audio.sfx("doorOpen_1", -6.0)
	w.hud.cue_on = true
	await Life.guide_to(null, "Where do you want to go?", {"tr": "Nereye gitmek istiyorsun."})
	w.hud.near = c.it; w.hud.show_chips()
