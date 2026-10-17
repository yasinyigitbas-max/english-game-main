## v34 open world (blue): vehicle trips (car, bus, ambulance). Yasin's rule: a trip is never shown driving.
## The screen fades to BLACK, the player is placed at the destination door (facing away from it), and it fades back in.
## No card text. Doors and walking never use this (they are real, continuous).
##   await WorldTrip.go("house_front")            # any node in group "world_doors" whose name or meta "door_id" matches
##   await WorldTrip.go(Vector3(..), yaw)         # or a world point + facing
## Outside the open world (no door found) it falls back to the old scene change: WorldTrip.go(id, 0, fallback_scene, spawn).
class_name WorldTrip
extends RefCounted

const OUT_T := 0.45
const HOLD_T := 0.35
const IN_T := 0.55
static var _layer: CanvasLayer
static var _rect: ColorRect
static var busy := false

## the door node for an id (group "world_doors": name == id or meta door_id == id); null if the world has none
static func door(id: String) -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	for d in tree.get_nodes_in_group("world_doors"):
		if d is Node3D and (String(d.name) == id or String(d.get_meta("door_id", "")) == id): return d
	return null

static func _black() -> ColorRect:
	if _rect and is_instance_valid(_rect): return _rect
	var tree := Engine.get_main_loop() as SceneTree
	_layer = CanvasLayer.new(); _layer.layer = 110; _layer.name = "WorldTripFade"; tree.root.add_child(_layer)
	_rect = ColorRect.new(); _rect.color = Color(0, 0, 0, 0); _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT); _layer.add_child(_rect)
	return _rect

static func _tween(a: float, t: float) -> void:
	var r := _black(); var tw := r.create_tween(); tw.tween_property(r, "color:a", a, t); await tw.finished

## dest: door id (String) or world point (Vector3). The player stands 1.2 m in front of the door (its +z), facing out.
static func go(dest, yaw := INF, fallback_scene := "", fallback_spawn := "") -> void:
	if busy: return
	var tree := Engine.get_main_loop() as SceneTree
	var pos := Vector3.INF
	if dest is Vector3: pos = dest
	elif dest is String:
		var d := door(dest)
		if d:
			pos = d.global_transform * Vector3(0, 0, 1.2); pos.y = d.global_position.y
			if yaw == INF: yaw = d.global_rotation.y
	if pos == Vector3.INF:   # not in the open world: the old scene change
		if fallback_scene != "": Game.go_to(fallback_scene, fallback_spawn)
		return
	busy = true
	var sc := tree.current_scene
	var pl: Node3D = sc.get("player") if sc else null
	if pl and "busy" in pl: pl.busy = true
	await _tween(1.0, OUT_T)
	if pl:
		if pl is CharacterBody3D: (pl as CharacterBody3D).velocity = Vector3.ZERO
		pl.global_position = pos
		if yaw != INF:
			if pl.has_method("face"): pl.face(yaw)
			else: pl.global_rotation.y = yaw
	var sh = Engine.get_main_loop().root.get_node_or_null("ShoulderCam")
	if sh and sh.has_method("snap"): sh.snap()                      # the camera starts behind the player (no swoop across town)
	elif sc and sc.get("cam") and sc.cam.has_method("snap"): sc.cam.snap()
	await tree.create_timer(HOLD_T).timeout
	await _tween(0.0, IN_T)
	if pl and "busy" in pl: pl.busy = false
	busy = false
