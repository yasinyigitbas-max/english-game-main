## v34 open world (blue): drop the café, shop and work / school interiors into the one world scene.
##   WorldPlaces.add_all(world)                      # under world/Places at the default spots below
##   WorldPlaces.add(world, "shop", Transform3D(..)) # one place at a given transform (OPENWORLD_PLAN.md positions win)
## Each place is its normal script in world mode (scripts/places/place_base.gd, scripts/story/work.gd): built place-local,
## uses the world's hud / player / cam / caption queue, a real swinging door (node "FrontDoor", group "doors") in its
## south wall (local +z), no scene loads, no fades. Their APIs stay: sc.its / sc.npcs / exit_prompt / target / guide /
## cine / walk_to (place-local points) for the day-4 / day-5 story scripts (find a place: WorldPlaces.get_place("shop")).
## Each place also registers a WorldTrip door "<id>_door" (the street side of its door) for car / bus / ambulance trips.
class_name WorldPlaces
extends RefCounted

const SCENES := {
	"cafe": "res://scenes/world/places/cafe_place.tscn",
	"shop": "res://scenes/world/places/shop_place.tscn",
	"work": "res://scenes/world/places/work_place.tscn",
}
## OPENWORLD_PLAN.md positions (World.PLACES: cafe / shop yaw PI; work = World.RESERVED.work). World already builds the
## café and shop (phase-1 ow_shell); add_all() therefore adds only what World does not have yet (see add_all).
const DEFAULT_AT := {
	"cafe": [Vector3(8.5, 0.07, 32.5), PI],
	"shop": [Vector3(-3.0, 0.07, 33.5), PI],
	"work": [Vector3(-120, 0.07, -120), 0.0],
}

static func add(world: Node, id: String, xf: Transform3D, parent: Node = null) -> Node3D:
	if not SCENES.has(id): return null
	if parent == null:
		parent = world.get_node_or_null("Places")
		if parent == null: parent = Node3D.new(); parent.name = "Places"; world.add_child(parent)
	var pl: Node3D = (load(SCENES[id]) as PackedScene).instantiate()
	pl.name = id.capitalize() + "Place"; pl.set("world_mode", true); pl.set("host", world)
	pl.transform = xf; pl.set_meta("place_id", id)
	parent.add_child(pl)
	# street-side arrival point for vehicle trips (WorldTrip.go("<id>_door")): 1.2 m outside the door, facing the street
	var room: Vector2 = pl.get("room") if pl.get("room") is Vector2 else Vector2(8, 7)
	var d := Node3D.new(); d.name = id + "_door"; d.set_meta("door_id", id + "_door"); d.position = Vector3(0, 0, room.y / 2.0 + 0.3)
	pl.add_child(d); d.add_to_group("world_doors")
	return pl

static func add_all(world: Node, at: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in SCENES:
		if not at.has(id) and world.get("places") is Dictionary and (world.places as Dictionary).has(id): continue   # World has it
		var v = at.get(id, DEFAULT_AT[id])
		var xf: Transform3D
		if v is Transform3D: xf = v
		elif v is Array: xf = Transform3D(Basis(Vector3.UP, float(v[1])), v[0])
		else: xf = Transform3D(Basis.IDENTITY, v)
		out[id] = add(world, id, xf)
	return out

static func get_place(id: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	for p in tree.get_nodes_in_group("world_places"):
		if String(p.get_meta("place_id", "")) == id or String(p.get("place_id")) == id: return p
	return null

## the place the player is standing in (or null on the street)
static func current() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	for p in tree.get_nodes_in_group("world_places"):
		if bool(p.get("inside")): return p
	return null
