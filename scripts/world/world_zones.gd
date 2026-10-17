## v34 open world (blue): coarse whole-area culling (everything is loaded at once).
## Every 0.25 s, by camera distance to each area's bounds (hysteresis 4 m):
##   * interiors (World.places rooms / places, incl. the north strip): beyond INTERIOR_OFF the contents go (every direct
##     child except the walls, doors and the street front); the shell keeps the building on the skyline
##   * north strip (places / nodes with z < NORTH_Z: hospital, school, work, their ground): beyond NORTH_OFF the whole
##     area is hidden (the construction fence hides it from the town anyway)
##   * the place the hero stands in, and anything within INTERIOR_OFF, is always fully shown
## Only visibility changes (never process / physics), so story scripts keep running.
extends Node

const ShoulderCam := preload("res://scripts/core/shoulder_cam.gd")
@export var interior_off := 26.0
@export var north_off := 70.0
@export var north_z := -85.0
var host: Node = null
var _areas: Array = []    # {"root", "ab", "north", "parts": [Node3D], "on": bool}
var _next := 0.0

func _ready() -> void:
	name = "WorldZones"
	if host == null: host = get_parent()
	_setup.call_deferred()

func _setup() -> void:
	var places = host.get("places")
	if places is Dictionary:
		for id in places: _add(places[id])
	for c in host.get_children():   # loose north-strip nodes (NorthStrip ground ...)
		if c is Node3D and not (places is Dictionary and c in (places as Dictionary).values()) and (c as Node3D).global_position.z < north_z and not (c is CharacterBody3D):
			_areas.append({"root": c, "ab": _bounds(c), "north": true, "parts": [c], "on": true})

func _add(r: Node3D) -> void:
	var ab := _bounds(r)
	var north := ab.get_center().z < north_z
	var parts: Array = []
	for c in r.get_children():
		if not (c is Node3D) or c is CharacterBody3D: continue
		var nm := String(c.name).to_lower()
		if "door" in nm or "facade" in nm or c.is_in_group("doors") or c.has_meta("no_fade"): continue
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var b: AABB = (c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()
			if ShoulderCam._is_wall(b) or b.size.y >= 2.6: continue   # walls / shell stay
		parts.append(c)
	_areas.append({"root": r, "ab": ab, "north": north, "parts": [r] if north else parts, "on": true})

func _bounds(n: Node3D) -> AABB:
	var ab := AABB(); var first := true
	for g in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = (g as VisualInstance3D).global_transform * (g as VisualInstance3D).get_aabb()
		if b.size.x > 60.0 or b.size.z > 60.0: continue
		if first: ab = b; first = false
		else: ab = ab.merge(b)
	return ab if not first else AABB(n.global_position, Vector3.ONE)

static func _dist(ab: AABB, p: Vector3) -> float:
	var q := Vector3(clampf(p.x, ab.position.x, ab.end.x), clampf(p.y, ab.position.y, ab.end.y), clampf(p.z, ab.position.z, ab.end.z))
	return q.distance_to(p)

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next: return
	_next = now + 0.25
	var c := get_viewport().get_camera_3d()
	if c == null: return
	var cp := c.global_position
	var hp = host.get("player"); var h: Vector3 = (hp as Node3D).global_position if hp is Node3D else cp
	for a in _areas:
		if not is_instance_valid(a.root): continue
		var lim: float = north_off if a.north else interior_off
		var d := minf(_dist(a.ab, cp), _dist(a.ab, h))
		var want: bool = d < (lim + 4.0 if a.on else lim)
		if want == a.on: continue
		a.on = want
		for p in a.parts:
			if not is_instance_valid(p): continue
			if want:
				if p.has_meta("zone_vis"): (p as Node3D).visible = bool(p.get_meta("zone_vis")); p.remove_meta("zone_vis")
			elif not p.has_meta("zone_vis"):
				p.set_meta("zone_vis", (p as Node3D).visible); (p as Node3D).visible = false
