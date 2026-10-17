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

static func install(world: Node, opts := {}) -> Dictionary:
	var out := {}
	var doors = world.get("doors")
	if doors is Dictionary:
		for id in doors:
			var lf = doors[id].get("leaf")
			if lf is Node: (lf as Node).set_meta("no_fade", true); (lf as Node).add_to_group("doors")
	var wwf: Node = load("res://scripts/world/world_wall_fade.gd").new(); wwf.set("host", world); world.add_child(wwf); out.wall_fade = wwf
	var places = world.get("places")
	if places is Dictionary:
		for id in ["cafe", "shop"]:
			if places.has(id): out["front_" + id] = Facades.build(places[id], id, wwf.wf)
	_clear_lots(world)
	if bool(opts.get("work", true)): out.places = Places.add_all(world)
	if bool(opts.get("merge", true)): out.merge = merge_all(world)
	if bool(opts.get("culling", true)):
		var wc: Node = load("res://scripts/world/world_culling.gd").new(); wc.set("host", world); world.add_child(wc); out.culling = wc
	return out

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
## direct children (fences, ...). Rooms / places keep a 40 m range, street blocks 120 m.
static func merge_all(world: Node) -> Dictionary:
	var tot := {"roots": 0, "meshes": 0, "surfaces_in": 0, "surfaces_out": 0}
	var roots: Array = []
	var grid = world.get("grid")
	if grid and grid.get("loaded") is Dictionary:
		for c in grid.loaded: roots.append([grid.loaded[c], 120.0])
		if grid.has_signal("block_loaded"):
			grid.block_loaded.connect(func(_c, b): (func(): Merge.merge_root(b, 120.0)).call_deferred())
	var places = world.get("places")
	if places is Dictionary:
		for id in places: roots.append([places[id], 40.0])
	for c in world.get_children():
		if c is Node3D and c != grid and not (places is Dictionary and c in (places as Dictionary).values()) and not (c is CharacterBody3D) and c.get_script() == null:
			roots.append([c, 0.0])
	for r in roots:
		var s: Dictionary = Merge.merge_root(r[0], r[1])
		if int(s.get("meshes", 0)) > 0: tot.roots += 1
		for k in ["meshes", "surfaces_in", "surfaces_out"]: tot[k] += int(s.get(k, 0))
	return tot
