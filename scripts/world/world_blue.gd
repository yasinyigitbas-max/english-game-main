## v34 open world (blue): ONE call wires blue's parts into black's World (scripts/core/world.gd), end of World._ready:
##   preload("res://scripts/world/world_blue.gd").install(self)
## - doors: every World.doors leaf gets meta no_fade + group "doors" (stays solid when its wall fades)
## - WorldWallFade (occluder fade for every room / place / building wall), café + shop fronts (WorldFacades)
## - WorldCulling (visibility ranges for props / interiors, distance-faded lights, near-only shadows, sun shadow cap)
## - work / school interior at World.RESERVED.work (WorldPlaces.add_all adds what World does not have)
## The shoulder camera (scripts/core/shoulder_cam.gd) already drives World's CameraRig; vehicle trips: WorldTrip.go(id).
extends RefCounted
const Facades := preload("res://scripts/world/world_facades.gd")
const Places := preload("res://scripts/world/world_places.gd")

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
	if bool(opts.get("work", true)): out.places = Places.add_all(world)
	if bool(opts.get("culling", true)):
		var wc: Node = load("res://scripts/world/world_culling.gd").new(); wc.set("host", world); world.add_child(wc); out.culling = wc
	return out
