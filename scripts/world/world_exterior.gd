## Exterior: streamed city (WorldGrid) + player + follow camera + HUD + traffic (cars, bus) + pooled NPCs.
## Lighting follows WorldState's clock (day / evening / night with lit streetlights).
## Buildings that hide the player fade out (group "fade").
extends UniversalScene

var grid: WorldGrid
var sun: DirectionalLight3D
var env: Environment
var cur_cell := Vector2i(999, 999)
var bus: Vehicle
var buses: Array = []
var cars: Array = []
var npc_pool: Array = []
var npc_seed := 100
var lamp_lights: Array = []
var fade_mat: StandardMaterial3D
const WallFade := preload("res://scripts/places/wall_fade_adapter.gd")
var _lamp_t := 0.0
const LAMP_E := 2.4

const DAY := {"bg": Color(0.86, 0.89, 0.93), "amb": Color(1.0, 0.97, 0.93), "amb_e": 0.45, "sun": Color(1.0, 0.95, 0.85), "sun_e": 1.45}
const NIGHT := {"bg": Color(0.13, 0.16, 0.25), "amb": Color(0.50, 0.58, 0.85), "amb_e": 0.45, "sun": Color(0.6, 0.7, 1.0), "sun_e": 0.12}
const EXPOSURE := 0.5   # style guide 0.95 is for the roofed bedroom; outdoors every floor is sun-lit (see README)

const Town := preload("res://scripts/core/town.gd")   # v33 whole town
func _ready() -> void:
	if Town.shell_ready(self): return   # v33 town: street shell = its streamed blocks only (hidden while you are inside)
	_live_ready()

func _live_ready() -> void:   # v33 town: the v32 _ready (also run when the street shell turns live)
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = EXPOSURE
	env.adjustment_enabled = true; env.adjustment_saturation = 1.18; env.adjustment_contrast = 1.06
	env.fog_enabled = true; env.fog_density = 0.0018; env.fog_sky_affect = 0.0
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; add_child(sun)
	sun.look_at_from_position(Vector3(7, 8, -9), Vector3(0, 0, 0))
	sun.directional_shadow_max_distance = 30.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 2.0; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2
	fade_mat = MeshKit.material().duplicate(); fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fade_mat.albedo_color = Color(1, 1, 1, 0.5)
	for i in 6:
		var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.82, 0.55); l.omni_range = 10.0; l.light_energy = 2.4; l.light_specular = 0.0; l.distance_fade_enabled = false; l.visible = false; add_child(l); lamp_lights.append(l)
	WorldState.ensure_loaded(); WorldState.scene = scene_file_path
	if grid == null or not is_instance_valid(grid): grid = WorldGrid.new(); add_child(grid)   # v33 town: a shell turning live keeps its blocks
	hud = (load("res://ui/shared/hud.tscn") as PackedScene).instantiate(); add_child(hud)
	hud.phone.map_provider = map_info
	player = WorldPlayer.new(); add_child(player); player.hud = hud; hud.player = player; player.floor_y = 0.07
	player.surface_func = surface_at
	if not App.came_from in ["cafe", "shop"] and Game.spawn != "home_car": hud.set_mission("Walk to the street."); Objectives.set_list(["Walk to the street."] + _keep_objs())   # v31: not after a café / shop visit
	var start := Vector3(-3, 0.07, 5)
	grid.load_around_now(start)
	var _sp: String = {"cafe_door": "lot:cafe", "shop_door": "lot:corner_shop"}.get(Game.spawn, Game.spawn)   # v31: café / shop door spawns
	var lot := grid.find_lot((_sp if _sp.begins_with("lot:") else "lot:home").substr(4))
	if Game.spawn == "resume" and WorldState.player_pos != Vector3.ZERO: start = WorldState.player_pos; start.y = 0.07
	elif lot: start = lot.entrance_global() + lot.global_transform.basis.z * 0.6; start.y = 0.07
	elif WorldState.player_pos != Vector3.ZERO: start = WorldState.player_pos
	grid.load_around_now(start)
	var _home_car := Game.spawn == "home_car" and lot != null   # v32-polish: day 2, both visits done -> spawn beside the car on the home lot
	if _home_car:
		for o in lot.find_children("*", "StreetObject", true, false) + find_children("*", "StreetObject", true, false):
			if o.kind == "car": start = o.global_position + o.global_transform.basis.x * 1.7; start.y = 0.07; break
		grid.load_around_now(start)
	player.global_position = start; player.face(0.0)
	grid.target = player
	cam = (load("res://ui/shared/camera_rig.tscn") as PackedScene).instantiate(); cam.far = 220.0; add_child(cam)
	hud.camera = cam; player.attach_camera(cam, 13.5, 0.82)
	setup_universal("Outside", "Dışarıda")
	_spawn_traffic()
	_apply_light(true)
	caption("I'm outside now.", false)   # house.23: silent room caption, like the house rooms
	if load("res://scripts/story/story_accident.gd").should_run():   # house.25: day-1 story
		var st = load("res://scripts/story/story_accident.gd").new(); st.w = self; add_child(st); st.run()
	elif _home_car: _day2_go_inside.call_deferred(lot)
	elif load("res://scripts/story/day2_car.gd").should_run():   # v31: day-2 morning -> prompt to the car, hook day2_reached_car
		var d2 = load("res://scripts/story/day2_car.gd").new(); d2.name = "Day2Car"; d2.w = self; add_child(d2); d2.run()
	Town.live_ready(self)   # v33 town: the house rooms, cafe and shop as hidden shells

## v32-polish: after BOTH day-2 visits the player stands beside the car; objective + pan to the home's main door, in the
## one caption box (Life.guide_to -> HUD caption). Entering the door leads to the living room, where Day2After.run()
## starts the existing "Talk to your family." / day-2 family evening flow.
func _day2_go_inside(lot) -> void:
	await get_tree().process_frame
	var door: Vector3 = lot.entrance_global() + Vector3(0, 1.1, 0)
	var away: Vector3 = player.global_position - door; away.y = 0
	if away.length() < 0.05: away = Vector3(0, 0, 1)
	Objectives.set_list(_keep_objs())   # v32 int: drop the stale morning steps ("Walk to the street." / "Go to the car.") before the new objective
	await Life.guide_to({"pos": door + away.normalized() * 5.5 + Vector3(0, 2.6, 0), "at": door}, "Go inside and talk to my family.", {"tr": "İçeri gir ve ailemle konuş."})

# ------------------------------------------------------------------ traffic
func _spawn_traffic() -> void:
	var a := Vehicle.lane_loop([Vector2(-20, -20), Vector2(20, -20), Vector2(20, 20), Vector2(-20, 20)])
	var b := Vehicle.lane_loop([Vector2(-20, 20), Vector2(20, 20), Vector2(20, 60), Vector2(-20, 60)])
	for d in [[a, 10.0, Color(0.85, 0.4, 0.35)], [a, 90.0, Color(0.93, 0.86, 0.74)], [b, 30.0, Color(0.62, 0.74, 0.70)]]:
		var v := Vehicle.new(); v.color = d[2]; add_child(v); v.setup(d[0], d[1]); cars.append(v)
	# two buses on one deterministic timetable, half a cycle apart
	var loop := Vehicle.lane_loop([Vector2(60, 20), Vector2(-20, 20), Vector2(-20, 60), Vector2(60, 60)])
	var r: Dictionary = Transit.routes.bus_1
	var first := float(Transit._hm(r.get("first", "06:00")))
	for k in 2:
		var vb := Vehicle.new(); vb.is_bus = true; vb.max_speed = 8.0; vb.accel = 2.2; vb.route_id = "bus_1"; add_child(vb)
		vb.setup(loop, 0.0)
		for id in r.stops: vb.stops.append({"id": id, "s": fposmod(vb.project(Transit.stops[id].pos) - 0.5, vb.length)})
		var sch := vb.set_schedule(first, 6.0, WorldState.time_scale)
		if k == 1: vb.sched_first = first + vb.headway * 0.5
		else: r["offsets"] = sch.offsets; r["headway"] = int(sch.headway / 2.0); r["dwell"] = int(sch.dwell); r["cycle"] = int(sch.headway)
		vb.board = Interactable.new(); vb.board.obj_name = "bus"; vb.board.radius = 2.2; vb.board.position = Vector3(-2.1, 0, 3.6)
		vb.board.enabled = false; vb.board.walk_to = true; vb.add_child(vb.board)
		vb.board.verbs = func(): return [["Get on the bus (%s)" % Economy.format(int(Transit.routes.bus_1.fare)), _ride.bind(vb)]]
		vb.sync(WorldState.minutes); buses.append(vb)
	bus = buses[0]
	Transit.stop_registered.connect(func(id):
		for vb in buses:
			for st in vb.stops: if st.id == id: st.s = fposmod(vb.project(Transit.stops[id].pos) - 0.5, vb.length))

func _ride(b: Vehicle = null) -> void:
	if b == null: b = bus
	var stops: Array = Transit.routes.bus_1.stops
	var from := b.at_stop
	if from == "": return
	var to: String = stops[(stops.find(from) + 1) % stops.size()]
	await say_line("I am getting on the bus.")
	await get_tree().create_timer(1.6).timeout
	var fare := int(Transit.routes.bus_1.fare)
	if not Economy.spend(fare, "bus fare"): say_line("I do not have enough money."); return
	await say_line("I am paying the fare.")
	player.busy = true
	await Game.fade(1.0, 0.5)
	# jump the clock to the scheduled arrival at the next stop; the bus is placed by its timetable (no drift)
	var ti: int = stops.find(to); var ph := b.phase(WorldState.minutes)
	WorldState.minutes += fposmod(float(b.arr[ti]) - ph, b.headway) + 0.05
	for bb in buses: bb.sync(WorldState.minutes)
	Transit.ride_started.emit("bus_1", from, to)
	var dest: Vector3 = Transit.stops[to].pos
	var out := b.global_transform * Vector3(-2.3, 0, 2.0); out.y = 0.07
	grid.load_around_now(out); player.global_position = out; cam.focus = out
	await get_tree().create_timer(0.6).timeout
	player.busy = false
	await Game.fade(0.0, 0.5)
	caption("I am getting off the bus.")

# ------------------------------------------------------------------ NPC pool
const NPC_ON := 34.0
const NPC_OFF := 44.0
var _npc_t := 0.0
## acquire pooled NPCs only for spots near the player; return them when far (keeps ~20-25 characters alive)
func _npc_lod(dt: float) -> void:
	_npc_t -= dt
	if _npc_t > 0.0: return
	_npc_t = 0.4
	var pp := player.global_position
	for sp in get_tree().get_nodes_in_group("npc_spots"):
		var spot := sp as NpcSpot
		var d := spot.global_position.distance_to(pp) - (spot.loop_inset if spot.mode == "walk" else 0.0) * 0.5
		if spot.npc == null and d < NPC_ON: npc_acquire(spot)
		elif spot.npc != null and d > NPC_OFF: npc_release(spot)

func npc_acquire(spot: NpcSpot) -> void:
	if not is_instance_valid(spot) or not spot.is_inside_tree(): return
	var n: NPC = npc_pool.pop_back() if npc_pool.size() > 0 else null
	if n == null:
		n = NPC.new(); n.mode = spot.mode; n.anim = spot.anim; add_child(n); npc_seed += 1; n.setup(spot.look_seed * 31 + npc_seed)
	n.mode = spot.mode; n.anim = spot.anim; n.line = spot.line; n.visible = true; n.set_process(true); n.it.enabled = true
	n.global_position = spot.global_position; n.hero.rotation.y = spot.global_rotation.y
	if spot.mode == "walk":
		n.route = spot.route(); var f := fposmod(spot.loop_phase, 1.0) * n.route.size(); var i0 := int(f) % n.route.size()
		n.global_position = n.route[i0].lerp(n.route[(i0 + 1) % n.route.size()], f - floorf(f)); n.wp = (i0 + 1) % n.route.size()
		n.hero.play("walk", 0.0, n.speed / 1.7)
	else: n.hero.play(spot.anim, 0.0)
	spot.npc = n

func npc_release(spot: NpcSpot) -> void:
	var n := spot.npc; spot.npc = null
	if n == null or not is_instance_valid(n) or not is_inside_tree(): return
	n.visible = false; n.set_process(false); n.it.enabled = false; n.position = Vector3(0, -50, 0); npc_pool.append(n)

# ------------------------------------------------------------------ frame
func _process(dt: float) -> void:
	var c := grid.cell_of(player.global_position)
	if c != cur_cell:
		cur_cell = c
		var b: Node = grid.loaded.get(c)
		var nm: String = b.block_name if b is CityBlock and b.block_name != "" else "Maple Street"
		hud.set_place(nm, Lines.tr_of(nm))
	_fade_buildings()
	_npc_lod(dt)
	_street_check(dt)
	_apply_light(false)
	for v in cars + buses: v.visible = v.global_position.distance_to(player.global_position) < 75.0

func _fade_buildings() -> void:
	var eye := player.global_position + Vector3(0, 1.0, 0); var cp := cam.global_position
	for n in get_tree().get_nodes_in_group("fade"):
		var mi := n as MeshInstance3D
		var ab: AABB = mi.global_transform * mi.get_aabb()
		# only buildings between the camera and the player (not the one the player stands in front of)
		var to_cam := (cp - eye).normalized()
		var near_end := eye + to_cam * 1.2
		var hit: bool = (ab.get_center() - eye).dot(to_cam) > 0.0 and ab.grow(0.1).intersects_segment(cp, near_end)
		# cutaway: swap the building for its open-top 1 m wall stub (no translucent haze)
		var cut: MeshInstance3D = mi.get_meta("cut") if mi.has_meta("cut") else null
		# v32 rule (blue): the building fades out / back gradually (was an instant swap); its open-top stub shows underneath
		if cut and is_instance_valid(cut): cut.visible = hit
		WallFade.step(mi, hit, get_process_delta_time())

## v31 QA (blue): "Walk to the street." was set on every visit but never completed (it stayed on the list all day).
## Done as soon as the player stands on the sidewalk / road ring of a block (outside the lots' inner square).
var _street_t := 0.0
func _street_check(dt: float) -> void:
	_street_t -= dt
	if _street_t > 0.0: return
	_street_t = 0.3
	if not Objectives.has("Walk to the street.") or player == null: return
	var lp := player.global_position - grid.cell_center(grid.cell_of(player.global_position))
	if absf(lp.x) > CityBlock.INNER or absf(lp.z) > CityBlock.INNER:
		Objectives.complete("Walk to the street.")
		if hud and hud.has_method("set_mission") and Objectives.items.is_empty(): hud.set_mission("")

## daylight 0..1 from the clock: 1 = day, 0 = night (ramps 6-7 h and 19-20.5 h)
func day_k() -> float:
	var h := WorldState.minutes / 60.0
	if h < 6.0 or h > 20.5: return 0.0
	if h < 7.0: return smoothstep(0.0, 1.0, h - 6.0)            # v32 polish: eased dawn / dusk (was linear with kinks)
	if h > 19.0: return smoothstep(0.0, 1.0, (20.5 - h) / 1.5)
	return 1.0

func _apply_light(force: bool) -> void:
	var k := day_k()
	env.background_color = NIGHT.bg.lerp(DAY.bg, k); env.fog_light_color = env.background_color
	env.ambient_light_color = NIGHT.amb.lerp(DAY.amb, k); env.ambient_light_energy = lerpf(NIGHT.amb_e, DAY.amb_e, k)
	sun.light_color = NIGHT.sun.lerp(DAY.sun, k); sun.light_energy = lerpf(NIGHT.sun_e, DAY.sun_e, k)
	var night := k < 0.5
	Foliage.set_night(night)
	# v32 polish: street lamps fade in over dusk (0 at k 0.55 -> full at k 0.4) instead of all popping on at k 0.5, and the
	# 6 real lights keep their lamp post while it stays among the 6 nearest; a light that moves to a new post fades in
	# there (it used to jump between posts every 0.5 s while walking: visible light pops on the road)
	var nf := clampf((0.55 - k) / 0.15, 0.0, 1.0)
	var dt := get_process_delta_time()
	_lamp_t -= dt
	if _lamp_t <= 0.0 or force:
		_lamp_t = 0.5
		var pts: Array = []
		if nf > 0.0:
			for b in grid.loaded.values():
				if b is CityBlock and b.fol.has("lamp"):
					for e in b.fol.lamp: pts.append(b.global_transform * (e[0] as Transform3D) * Vector3(0, 3.9, -0.85))
			var pp := player.global_position
			pts.sort_custom(func(a, b2): return a.distance_squared_to(pp) < b2.distance_squared_to(pp))
			pts = pts.slice(0, lamp_lights.size())
		var idle_l: Array = []
		for l in lamp_lights:
			var keep := -1
			if l.has_meta("post"):
				for i in pts.size():
					if (pts[i] as Vector3).distance_to(l.global_position) < 0.05:
						keep = i
						break
			if keep >= 0:
				pts.remove_at(keep)
			else:
				l.remove_meta("post")
				idle_l.append(l)
		for l in idle_l:
			if pts.is_empty(): break
			l.global_position = pts.pop_front(); l.set_meta("post", true); l.light_energy = 0.0
	for l in lamp_lights:
		var tgt: float = LAMP_E * nf if l.has_meta("post") else 0.0
		l.light_energy = tgt if force else move_toward(l.light_energy, tgt, LAMP_E * dt * 1.8)
		l.visible = l.light_energy > 0.01


## "grass" or "pave" under a world position (footstep sounds)
func _exit_tree() -> void:
	if not has_meta("house_shell"): Footsteps.clear()   # v33 town: a street shell going away leaves the live place's steps alone

func surface_at(p: Vector3) -> String:
	var c := grid.cell_of(p); var lp := p - grid.cell_center(c)
	var inner := CityBlock.INNER
	var road := CityBlock.BLOCK * 0.5 - CityBlock.ROAD   # house.24: street tarmac vs sidewalk
	if absf(lp.x) > road or absf(lp.z) > road: return "tarmac"
	if absf(lp.x) > inner or absf(lp.z) > inner: return "pave"
	for l in get_tree().get_nodes_in_group("lots"):
		var lo := l as Lot
		if lo.on_hard(lo.global_transform.affine_inverse() * p): return "pave"
	return "grass"

## phone Map app data
func map_info() -> Dictionary:
	var cells := []
	for c in grid.cells: cells.append([c.x, c.y, String(grid.cells[c]).get_file()])
	var stops := []
	for sid in Transit.stops: var sp: Vector3 = Transit.stops[sid].pos; stops.append(Vector2(sp.x, sp.z))
	return {"cells": cells, "player": Vector2(player.global_position.x, player.global_position.z), "block": grid.block_size, "stops": stops}

## v31 QA (blue): the street list used to wipe Life's "Charge my phone." (id "charge") on every world load.
func _keep_objs() -> Array:
	var keep: Array = []
	for it in Objectives.items:
		if it is Dictionary and String(it.get("id", "")) == "charge": keep.append(it)
	return keep
