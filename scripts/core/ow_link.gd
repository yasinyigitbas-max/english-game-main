## OwLink (red, open world story port): runs the v33 room / place story code inside the ONE world (scenes/world.tscn).
## - ONE hero: the WorldPlayer's DemoCharacter. A live room borrows it (reparented, same node, never a new one) and moves it
##   in room-local coordinates exactly like v33; on the street it goes back to the WorldPlayer body.
## - ONE room camera carrier shared by every room (ShoulderCam drives it like in v33town); the street uses the CameraRig.
## - The live room / place is current_scene (as in v33 House), so the v33 room code and ShoulderCam run unchanged; on the
##   street current_scene is the World again (story_accident / day routines get the World as their scene).
## - Rooms never move, are never freed or rebuilt: sleep / wake (House._sleep/_wake) with all their state.
## - Car / bus / ambulance: travel() = fade out, place, fade in (the only gameplay fade, Yasin 18:12) + sleep.
class_name OwLink
extends Node

const House := preload("res://scripts/core/house.gd")
const ROOM_PATH := {"bedroom": "res://main.tscn", "bathroom": "res://bathroom.tscn", "livingroom": "res://livingroom.tscn"}
## story places that are not part of black's phase-1 layout yet: instanced ONCE at their reserved world slot
const EXTRA := {"hospital": "res://scenes/hospital.tscn", "hospital_day2": "res://scenes/hospital_day2.tscn", "child_drive_stop": "res://scenes/child_drive_stop.tscn"}
const EXTRA_SLOT := {"hospital": "hospital", "hospital_day2": "hospital", "child_drive_stop": "school"}
const PLACES := ["cafe", "shop"]   # World-built street places: live with the WorldPlayer (hero stays on its body)

static var inst: OwLink
var world: Node            # World
var live: Node = null      # the live room / place (current_scene) or null on the street
var live_id := ""
var room_cam: Camera3D
var extras := {}

static func active() -> bool: return is_instance_valid(inst) and is_instance_valid(inst.world)
static func the_hero() -> DemoCharacter: return inst.world.player.hero if active() else null

## World._ready end (one line in world.gd)
static func attach(w: Node) -> void:
	var n := OwLink.new(); n.name = "OwLink"; n.world = w; inst = n; w.add_child(n)
	n.process_priority = -50
	w.entered.connect(n._on_entered)
	n._start.call_deferred()

func _start() -> void:
	for id in ROOM_PATH:   # rooms become root children (needed for current_scene); same global transform: nothing moves
		var r: Node = world.places.get(id)
		if r and r.get_parent() != get_tree().root: r.reparent(get_tree().root, true)
	WorldState.ensure_loaded()
	if App.continue_requested and WorldState.place != "" and WorldState.place != "bedroom": await _resume(WorldState.place)
	else:
		await _enter("bedroom", "")
		if App.continue_requested and WorldState.place == "bedroom": _put_hero()

## Continue: the saved place goes live and the hero stands where he was saved (world coordinates)
func _resume(pl: String) -> void:
	var p := world.player as Node3D
	if ROOM_PATH.has(pl):
		await _enter(pl, ""); _put_hero()
	elif pl in PLACES:
		_put_hero(); await _enter(pl, "street")
	elif EXTRA.has(pl):
		await _enter(pl, "")
	else:   # street (any unknown place resumes on the street at the home door)
		get_tree().current_scene = world; p.process_mode = Node.PROCESS_MODE_INHERIT; world.hud.visible = true; world.cam.current = true
		if WorldState.hero_pos == null: p.place_at("front")
		_put_hero()
		_street_hooks("resume")

func _put_hero() -> void:
	var hp = WorldState.hero_pos
	if not (hp is Array and hp.size() == 3): return
	var g := Vector3(float(hp[0]), float(hp[1]), float(hp[2]))
	var h := the_hero(); var p := world.player as Node3D
	if is_instance_valid(live) and ROOM_PATH.has(live_id):
		h.global_position = Vector3(g.x, h.global_position.y, g.z); h.global_rotation.y = WorldState.hero_yaw
		if live.get("cam_focus") is Vector3: live.set("cam_focus", h.position)
	else:
		p.global_position = Vector3(g.x, p.global_position.y, g.z); h.rotation.y = WorldState.hero_yaw

## the save always knows the live place + the hero position (rooms / places save their own story state as in v33)
var _save_t := 0.0
func _remember(save_now := false) -> void:
	var h := the_hero()
	if not is_instance_valid(h): return
	WorldState.place = live_id if live_id != "" else "street"
	var g := h.global_position
	WorldState.hero_pos = [snappedf(g.x, 0.01), snappedf(g.y, 0.01), snappedf(g.z, 0.01)]; WorldState.hero_yaw = snappedf(h.global_rotation.y, 0.01)
	if save_now and App.has_save(): WorldState.save_game()

# ------------------------------------------------------------ room code helpers (v33 code calls these)
## room _live_ready: `hero = OwLink.hero_for(self)` instead of DemoCharacter.new() + add_child
static func hero_for(room: Node) -> DemoCharacter:
	if not active():
		var h := DemoCharacter.new(); room.add_child(h); return h
	var hh := the_hero(); _adopt(hh, room); return hh

## room _live_ready: `cam = OwLink.cam_for(self)` instead of Camera3D.new() + add_child
static func cam_for(room: Node) -> Camera3D:
	if not active():
		var c := Camera3D.new(); room.add_child(c); return c
	if not is_instance_valid(inst.room_cam): inst.room_cam = Camera3D.new(); inst.room_cam.name = "OwRoomCam"; room.add_child(inst.room_cam)
	else: inst.room_cam.reparent(room, true)
	return inst.room_cam

static func _adopt(n: Node3D, parent: Node) -> void:
	if n.get_parent() == parent: return
	var g := n.global_transform
	if n.get_parent(): n.reparent(parent, false)
	else: parent.add_child(n)
	n.global_transform = g
	if n.has_meta("wh_hv"): n.remove_meta("wh_hv")
	n.visible = true
	_reset_hero(n)

## undo a story place's pose / layer tweaks on the one hero (hospital bed lie / sit, first-person hide layer)
static func _reset_hero(n: Node3D) -> void:
	for v in n.find_children("*", "VisualInstance3D", true, false): if (v as VisualInstance3D).layers == 2: (v as VisualInstance3D).layers = 1
	n.rotation = Vector3(0, n.rotation.y, 0)
	if n is DemoCharacter: (n as DemoCharacter).play("idle", 0.2)

# ------------------------------------------------------------ going live
## make place `id` live (house room or story place). from = room/place id the hero comes from ("" / "street")
static func enter(id: String, from: String) -> void:
	if active(): await inst._enter(id, from)

func _enter(id: String, from: String) -> void:
	if id == live_id and is_instance_valid(live): return
	if id in PLACES:
		_sleep_live()
		var pl: Node = world.places.get(id)
		if pl == null: return
		live = pl; live_id = id
		# fix33 (black) K: a café / shop is a child of World (built in place, never a root child), so it can never be
		# current_scene (the engine refused it with an error on every entry and kept World). World stays current_scene.
		if get_tree().current_scene != world: get_tree().current_scene = world
		pl.process_mode = Node.PROCESS_MODE_INHERIT
		for c in pl.find_children("*", "CanvasLayer", true, false):
			if c.has_meta("ow_hidden"): c.remove_meta("ow_hidden"); (c as CanvasLayer).visible = true
		if pl.has_meta("ow_shell"): pl.remove_meta("ow_shell"); pl.call("_ow_live", world)
		else: pl.call_deferred("_start")
		return
	if not ROOM_PATH.has(id) and not EXTRA.has(id): push_warning("OwLink: no place " + id); return
	var h := the_hero()
	var hp := h.global_position; var hy := h.global_rotation.y
	_sleep_live()
	var r: Node = world.places.get(id) if ROOM_PATH.has(id) else _extra(id)   # an extra's _ready borrows the hero (after the sleep)
	if r == null: push_warning("OwLink: no place " + id); return
	if not ROOM_PATH.has(id):
		if h.has_meta("wh_hv"): h.remove_meta("wh_hv")
		h.visible = true
	var p := world.player as Node3D
	p.process_mode = Node.PROCESS_MODE_DISABLED
	world.hud.visible = false
	live = r; live_id = id
	get_tree().current_scene = r
	if ROOM_PATH.has(id):
		_adopt(h, r)
		var first := not House.again(r)
		if first:
			r.remove_meta(House.SHELL); House._cheap(r, false); r.process_mode = Node.PROCESS_MODE_INHERIT
			r.call("_live_ready")
		else:
			House._wake(r); r.process_mode = Node.PROCESS_MODE_INHERIT
			if r.has_method("_wh_resume"): r.call("_wh_resume")
		r.set_meta(House.ONCE, true)
		h.visible = true
		# fix33 (black): the ONE room camera may still hang under another (slept) room, or the extra (hospital) just turned
		# every camera off -> the street CameraRig stayed current inside the bedroom. The entered room owns it, current.
		if is_instance_valid(room_cam):
			if room_cam.get_parent() != r: room_cam.reparent(r, true)
			if room_cam.has_meta("wh_cur"): room_cam.remove_meta("wh_cur")
			room_cam.current = true
		if from != "":
			var sp: Array = r.call("_wh_spawn", from) if r.has_method("_wh_spawn") else []
			if sp.size() == 2: House._walk_in(r, r.to_local(hp), hy, sp[0], sp[1])

func _extra(id: String) -> Node:
	if extras.has(id) and is_instance_valid(extras[id]): return extras[id]
	var ps := load(EXTRA[id]) as PackedScene
	var n: Node3D = ps.instantiate()
	n.position = world.RESERVED.get(EXTRA_SLOT[id], Vector3(0, 0, -120))
	n.add_to_group("interiors")   # build 3.2: an indoor story set (WorldCulling: interior ranges, keeps its lamps on its props)
	get_tree().root.add_child(n)   # its _ready starts its story (as when v33 loaded the scene)
	extras[id] = n
	return n

func _sleep_live() -> void:
	if not is_instance_valid(live): return
	if ROOM_PATH.has(live_id):
		House._sleep(live)
	elif live_id in PLACES:
		live.process_mode = Node.PROCESS_MODE_DISABLED
		# fix33 (black): a slept café / shop hides its 2D overlays (teach card, lists); they come back when it is live again
		for c in live.find_children("*", "CanvasLayer", true, false):
			if (c as CanvasLayer).visible: (c as CanvasLayer).visible = false; c.set_meta("ow_hidden", true)
	else:
		live.process_mode = Node.PROCESS_MODE_DISABLED
		for c in live.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
		for c in live.find_children("*", "Camera3D", true, false): if not (c.get_viewport() is SubViewport): (c as Camera3D).current = false
		var we := live.find_children("*", "WorldEnvironment", true, false)
		for c in we: (c as WorldEnvironment).environment = null
	live = null; live_id = ""

## back on the street at the hero's current spot (or at door id `door`)
static func to_street(door := "") -> void:
	if active(): await inst._to_street(door)

func _to_street(door: String) -> void:
	if live_id in PLACES: Objectives.clear()   # build 3.2 (v33.1): the shop / cafe list ("Take a basket." ...) never follows the hero onto the street
	if world.has_method("street_objective"): world.street_objective(door)   # black 3.1: the street objective from the first step out
	var h := the_hero()
	var p := world.player as Node3D
	var g := h.global_transform
	var was_room := ROOM_PATH.has(live_id) or live_id in PLACES
	_sleep_live()
	get_tree().current_scene = world
	if h.get_parent() != p: h.reparent(p, false)
	_reset_hero(h)
	h.transform = Transform3D(Basis(Vector3.UP, g.basis.get_euler().y), Vector3.ZERO); h.visible = true
	p.global_position = Vector3(g.origin.x, p.floor_y, g.origin.z)
	p.process_mode = Node.PROCESS_MODE_INHERIT
	world.hud.visible = true; world.cam.current = true
	if door != "":
		if was_room and world.doors.has(door): await (world.doors[door]).walk_through(p)
		elif door != "": p.place_at(door)
	_street_hooks(door)

## world_exterior._ready story hooks, run on every arrival on the street (World is current_scene)
func _street_hooks(door: String) -> void:
	world.hud.visible = true
	if world.has_method("street_objective"): world.street_objective(door)   # black 3.1: no stale room mission on the street
	var lot = world.grid.find_lot("home")
	if load("res://scripts/story/story_accident.gd").should_run():   # house.25: day-1 story starts the moment the hero is outside
		var st = load("res://scripts/story/story_accident.gd").new(); st.w = world; world.add_child(st); st.run()
	elif door == "home_car" and lot and ChildDrive.arriving_home(): ChildDrive.arrive_home(world, lot)
	elif door == "home_car" and lot: _day2_go_inside.call_deferred(lot)
	elif load("res://scripts/story/day2_car.gd").should_run() and not world.has_node("Day2Car"):
		var d2 = load("res://scripts/story/day2_car.gd").new(); d2.name = "Day2Car"; d2.w = world; world.add_child(d2); d2.run()
		ChildDrive.escort(world)

func _day2_go_inside(lot) -> void:
	await get_tree().process_frame
	var door: Vector3 = lot.entrance_global() + Vector3(0, 1.1, 0)
	var away: Vector3 = world.player.global_position - door; away.y = 0
	if away.length() < 0.05: away = Vector3(0, 0, 1)
	await Life.guide_to({"pos": door + away.normalized() * 5.5 + Vector3(0, 2.6, 0), "at": door}, "Go inside and talk to my family.", {"tr": "İçeri gir ve ailemle konuş."})

## car / bus / ambulance: fade out, hero at dest (place id or door id), fade in. covered = screen already black.
static func travel(dest: String, door := "", covered := false) -> void:
	if not active(): return
	if not covered: await Game.fade(1.0, 0.45)
	Game.busy = true
	if dest == "street" or dest == "town" or dest in PLACES:   # build 3.2 (red): a street place (cafe/shop) - the hero leaves the room first (he stayed in the bedroom under the cafe)
		inst._sleep_live(); inst.get_tree().current_scene = inst.world
		var h := the_hero(); var p := inst.world.player as Node3D
		if h.get_parent() != p: h.reparent(p, false)
		_reset_hero(h); h.transform = Transform3D.IDENTITY; h.visible = true
		p.process_mode = Node.PROCESS_MODE_INHERIT; inst.world.cam.current = true
		p.place_at(_door_id(door if door != "" else dest))   # fix33 (black): street side of the door, facing the street (World._street_side)
		var cam = inst.world.cam
		if cam and "focus" in cam: cam.focus = p.global_position
		var shc = inst.get_tree().root.get_node_or_null("ShoulderCam")
		if shc and shc.has_method("snap"): shc.snap()
		if dest in PLACES: await inst._enter(dest, "")   # build 3.2 (red): cafe/shop go live after the hero is at their door
		else: inst._street_hooks.call_deferred(door)
	else:
		if ROOM_PATH.has(dest):
			var r: Node = inst.world.places[dest]
			var sp: Array = r.call("_wh_spawn", "livingroom" if dest == "bedroom" else "bedroom") if r.has_method("_wh_spawn") else []
			var h := the_hero()
			if sp.size() == 2: h.global_position = r.to_global(sp[0]); h.rotation.y = sp[1]
		await inst._enter(dest, "")
	await inst.get_tree().create_timer(0.3).timeout
	Game.busy = false
	await Game.fade(0.0, 0.45)

static func _door_id(d: String) -> String:
	return {"lot:home": "front", "front_door": "front", "home_car": "front", "lot:cafe": "cafe", "cafe_door": "cafe", "lot:corner_shop": "shop", "shop_door": "shop", "": "front"}.get(d, d)

## World.entered: the hero walked into a region on his own (street -> house through the front door)
func _on_entered(region: String, from: String) -> void:
	if not is_instance_valid(live) and ROOM_PATH.has(region) and from == "street":
		App.came_from = "outside"
		_enter(region, "street")
	elif not is_instance_valid(live) and region in PLACES and from == "street":
		_enter(region, "street")
	elif live_id in PLACES and region == "street":
		_sleep_live(); get_tree().current_scene = world; App.came_from = from

func _process(_dt: float) -> void:
	_save_t -= _dt
	if _save_t <= 0.0:
		_save_t = 10.0
		var busy_story := Game.busy or (is_instance_valid(live) and str(live.get("mode")) == "busy")   # black 3.2: str() (hospital etc. have no mode: String(null) errored)
		if not busy_story: _remember(true)
	# the WorldPlayer body follows the hero while a room drives him (World region / door / culling use its position)
	if is_instance_valid(live) and ROOM_PATH.has(live_id):
		var h := the_hero(); var p := world.player as Node3D
		if is_instance_valid(h): p.global_position = Vector3(h.global_position.x, p.global_position.y, h.global_position.z)
