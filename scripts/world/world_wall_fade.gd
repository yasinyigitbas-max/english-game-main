## v34 open world (blue): the wall fade for the whole world, as one drop-in node in scenes/world.tscn.
##   var wwf := preload("res://scripts/world/world_wall_fade.gd").new(); world.add_child(wwf)   # or a Node in the .tscn
## Registers in ONE scripts/props/wall_fade.gd manager (occluder mode: a wall fades to ~0.18 only while it hides the player
## from the camera, gradual out ~0.3 s / back ~0.4 s, 10 Hz tests, hysteresis), keeps doing so as the world streams in:
##   * every node in group "cam_occluder" or "world_walls" (one wall / building = one group, its meshes fade together)
##   * every street building in group "fade" (one merged mesh each) unless world_exterior.gd already fades it (meta wf_ext)
##   * thin + tall box meshes under any node in group "world_wall_roots" (e.g. the skeleton's house / building roots)
## Skipped: anything another manager already owns (meta "wf_reg": the house rooms' own WallFade, which keeps the south-wall
## proximity fade and the breakfast force_fade exactly as before) and the world places (café / shop / work fade their own
## walls, scripts/places/place_base.gd + scripts/story/work.gd world mode). Ground, the outside box, props, trees and lamps
## never fade (not walls). Camera: the current viewport camera; player: host.player (or host.hero).
extends Node

const WallFade := preload("res://scripts/props/wall_fade.gd")
const ShoulderCam := preload("res://scripts/core/shoulder_cam.gd")
var host: Node = null
var wf: Node = null
var _pending: Array = []

func _ready() -> void:
	name = "WorldWallFade"
	if host == null: host = get_parent()
	wf = WallFade.attach(self, func() -> Vector3:
		var c := get_viewport().get_camera_3d()
		return c.global_position if c else Vector3.INF,
		func() -> Vector3:
		var p = host.get("player") if host and host.get("player") is Node3D else (host.get("hero") if host else null)
		return (p as Node3D).global_position if p is Node3D and is_instance_valid(p) else Vector3.INF)
	get_tree().node_added.connect(func(n: Node) -> void: if n is Node3D: _pending.append(n))
	_scan_all.call_deferred()

func _scan_all() -> void:
	for g in ["cam_occluder", "world_walls"]:
		for n in get_tree().get_nodes_in_group(g): _try(n)
	for n in get_tree().get_nodes_in_group("fade"): _try(n, true)
	for r in get_tree().get_nodes_in_group("world_wall_roots"): _scan_root(r)

func _process(_dt: float) -> void:
	if _pending.is_empty(): return
	var q := _pending; _pending = []
	for n in q:
		if not is_instance_valid(n) or not n.is_inside_tree(): continue
		if n.is_in_group("cam_occluder") or n.is_in_group("world_walls"): _try(n)
		elif n.is_in_group("fade"): _try(n, true)
		elif n.is_in_group("world_wall_roots"): _scan_root(n)

func _owned(n: Node) -> bool:
	if n.has_meta("wf_reg") or n.has_meta("wf_ext"): return true
	var p := n.get_parent()
	while p:
		if p.is_in_group("world_places") or p.has_meta("wf_reg"): return true
		if p is WallFade: return true
		p = p.get_parent()
	return false

func _try(n: Node, building := false) -> void:
	if not (n is Node3D) or wf.is_registered(n) or _owned(n): return
	if building and _ext_fades(): return
	if building and n is VisualInstance3D:
		var ab: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		if ab.size.x >= 40.0 or ab.size.z >= 40.0 or ab.size.y < 1.5: return   # ground / outside box / low props
	wf.register_occluder(n, {"no_cam": building})

## world_exterior.gd (the old street scene, if the skeleton reuses it) fades the "fade" buildings itself
func _ext_fades() -> bool:
	for n in [host, get_tree().current_scene]:
		if n and n.has_method("_fade_buildings"): return true
	return false

func _scan_root(r: Node) -> void:
	for g in r.find_children("*", "MeshInstance3D", true, false):
		var m := g as MeshInstance3D
		if m.mesh == null or not (m.mesh is BoxMesh) or _owned(m): continue
		var ab: AABB = m.global_transform * m.get_aabb()
		if ShoulderCam._is_wall(ab): _try(m)
