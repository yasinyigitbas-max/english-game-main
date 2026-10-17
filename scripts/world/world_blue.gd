## v34 open world (blue): ONE call wires blue's parts into black's World (scripts/core/world.gd), end of World._ready:
##   preload("res://scripts/world/world_blue.gd").install(self)
## - doors: every World.doors leaf gets meta no_fade + group "doors" (stays solid when its wall fades)
## - WorldWallFade (occluder fade for every room / place / building wall), café + shop fronts (WorldFacades)
## - the street lots under the café / shop lose their old sign (Label3D) and any building box left over the interior
## - static mesh merging (WorldMerge): one mesh per street block / room / place / fence set, before culling
## - WorldCulling (visibility ranges for props / interiors, distance-faded lights, near-only shadows, sun shadow cap)
## - work / school interior at World.RESERVED.work (WorldPlaces.add_all adds what World does not have)
## The shoulder camera (scripts/core/shoulder_cam.gd) already drives World's CameraRig; vehicle trips: WorldTrip.go(id).
extends RefCounted
const Facades := preload("res://scripts/world/world_facades.gd")
const Places := preload("res://scripts/world/world_places.gd")
const Merge := preload("res://scripts/world/world_merge.gd")
const LOTS := {"cafe": "cafe", "corner_shop": "shop"}
const CHUNK_RANGE := 30.0   # merged small-thing chunks (World build 3: far 35 m + fog, ~28 m ranges)

static var disabled := false   # tools/qa_ow/perf_ow.gd: measure the bare World first, then install(world, {"force": true})
static var last := {}

## sync part: the wall-fade manager (World / red's OwLink may use it at once); everything that needs the built places runs
## a few frames later (the world-mode café / shop build in their deferred _world_init, World._late_places after that)
static func install(world: Node, opts := {}) -> Dictionary:
	if disabled and not bool(opts.get("force", false)): return {}
	var out := {}
	var wwf: Node = load("res://scripts/world/world_wall_fade.gd").new(); wwf.set("host", world); world.add_child(wwf); out.wall_fade = wwf
	last = out
	_late(world, opts, out)
	return out

static func _late(world: Node, opts: Dictionary, out: Dictionary) -> void:
	for i in 3: await world.get_tree().process_frame
	if not is_instance_valid(world): return
	var doors = world.get("doors")
	if doors is Dictionary:
		for id in doors:
			var lf = doors[id].get("leaf")
			if lf is Node: (lf as Node).set_meta("no_fade", true); (lf as Node).add_to_group("doors")
	var places = world.get("places")
	if places is Dictionary:
		for id in ["cafe", "shop"]:
			if places.has(id): out["front_" + id] = Facades.build(places[id], id, out.wall_fade.wf)
	_clear_lots(world)
	if bool(opts.get("work", true)): out.places = Places.add_all(world)   # the ONE work / school place (World.RESERVED.work)
	if bool(opts.get("merge", true)): out.merge = merge_all(world)
	if bool(opts.get("culling", true)):
		var wc: Node = load("res://scripts/world/world_culling.gd").new(); wc.set("host", world); world.add_child(wc); out.culling = wc
	if bool(opts.get("zones", false)):   # off: World (build 3) shows only the current room + rooms seen through open doors
		var z: Node = load("res://scripts/world/world_zones.gd").new(); z.set("host", world); world.add_child(z); out.zones = z
	if bool(opts.get("indoor_light", true)):
		var il: Node = load("res://scripts/world/world_indoor_light.gd").new(); il.set("host", world); world.add_child(il); out.indoor_light = il
	out.ready = true

## the old street lot fronts under the new interiors: their Label3D sign and the building box (World._open_lot only hides
## a box narrower than 20 m: the corner shop's is wider, so its pale front showed instead of the green one)
static func _clear_lots(world: Node) -> void:
	var grid = world.get("grid")
	if grid == null or not grid.has_method("find_lot"): return
	for lot_id in LOTS:
		var lot: Node3D = grid.find_lot(lot_id)
		if lot == null: continue
		for l in lot.find_children("*", "Label3D", true, false): (l as Label3D).visible = false
		var lc := lot.global_transform * Vector3(0, 1.5, 0)
		for m in world.get_tree().get_nodes_in_group("fade") + world.get_tree().get_nodes_in_group("solid"):
			if not (m is MeshInstance3D) or m.has_meta("ow_removed"): continue
			var ab: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if ab.size.y >= 2.0 and ab.size.x < 40.0 and ab.size.z < 40.0 and ab.grow(0.2).has_point(Vector3(lc.x, 1.0, lc.z)):
				(m as MeshInstance3D).visible = false; m.remove_from_group("fade"); m.set_meta("ow_removed", true)

## one merged mesh per street block (WorldGrid.loaded; later-streamed blocks too), per room / place, and for other
## direct children (fences, ...). Small things: CHUNK_RANGE (30 m) in 14 m cells; big things none (the 35 m far plane cuts them).
static func merge_all(world: Node) -> Dictionary:
	var tot := {"roots": 0, "meshes": 0, "surfaces_in": 0, "surfaces_out": 0}
	var roots: Array = []
	var grid = world.get("grid")
	if grid and grid.get("loaded") is Dictionary:
		for c in grid.loaded: roots.append([grid.loaded[c], CHUNK_RANGE])
		if grid.has_signal("block_loaded"):
			grid.block_loaded.connect(func(_c, b): (func(): Merge.merge_tree(b, CHUNK_RANGE)).call_deferred())
	var places = world.get("places")
	if places is Dictionary:
		for id in places: roots.append([places[id], CHUNK_RANGE])
	for c in world.get_children():
		if c is Node3D and c != grid and not (places is Dictionary and c in (places as Dictionary).values()) and not (c is CharacterBody3D) and c.get_script() == null:
			roots.append([c, 0.0])
	for r in roots:
		var s: Dictionary = Merge.merge_tree(r[0], r[1])
		if int(s.get("meshes", 0)) > 0: tot.roots += 1
		for k in ["meshes", "surfaces_in", "surfaces_out"]: tot[k] += int(s.get(k, 0))
	return tot
