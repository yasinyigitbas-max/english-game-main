## v32-polish (red): THE shared wall-fade helper (house rooms + blue's café / shop / outdoor buildings).
## A wall (or any Node3D whose meshes block the view) fades GRADUALLY to transparent when it sits between the camera and
## the player, or when the camera / player come close to it, and fades back when they move away. Scripted scenes can
## force every registered wall transparent (force_fade) so a camera pan is never blocked (both breakfasts).
##
## Usage (preload, no class_name, so it works from any script without the class cache):
##   const WallFade := preload("res://scripts/props/wall_fade.gd")
##   var wf = WallFade.attach(self, cam, hero)      # one manager node per scene; cam: Camera3D, hero: Node3D (or Callables -> Vector3)
##   wf.register(wall_node)                         # MeshInstance3D / GeometryInstance3D, or a Node3D (all its meshes fade as one)
##   wf.register(wall_node, {"min_a": 0.12})        # options: min_a (lowest alpha, default 0.12), near_cam (1.2 m), near_player (1.0 m),
##                                                  #          eye (1.2 m above the player's feet), shadows (keep receiving/casting, default true)
##   wf.force_fade(true) / wf.force_fade(false)      # scripted scenes: everything registered fades out / back (still gradual)
##   wf.unregister(wall_node); wf.enabled = false    # stop managing one wall / pause the manager
## Static per-frame API (what blue's scripts/places/wall_fade_adapter.gd step() forwards to; same signature):
##   WallFade.step(g, hidden, dt, speed := 3.0)      # one GeometryInstance3D: hidden fades to 0 (invisible), false back to opaque
##   WallFade.step_to(g, alpha, dt, speed := 3.0)    # same, towards any target alpha 0..1
## Materials: on the first fade a mesh gets its own copy of its material (material_override or surface 0) with alpha; at
## alpha >= 0.999 the original material comes back (opaque pipeline). Alpha-hash keeps shadows on walls (house.24.2).
extends Node

const SPEED := 3.0          # alpha per second (about 0.3 s for a full fade)
const MIN_A := 0.12
const NEAR_CAM := 1.2
const NEAR_PLAYER := 1.0
const EYE := 1.2

var cam = null              # Camera3D or Callable -> Vector3
var player = null           # Node3D or Callable -> Vector3 (feet)
var enabled := true
var forced := false
var _walls: Array = []      # [{"node": Node3D, "meshes": [GeometryInstance3D], "opt": {}}]

static func attach(host: Node, camera = null, target = null) -> Node:
	var wf: Node = (load("res://scripts/props/wall_fade.gd") as GDScript).new()
	wf.name = "WallFade"; wf.cam = camera; wf.player = target; host.add_child(wf); return wf

func register(wall: Node, opt := {}) -> void:
	if wall == null or not is_instance_valid(wall): return
	for e in _walls: if e.node == wall: return
	var ms: Array = []
	if wall is GeometryInstance3D: ms.append(wall)
	for m in wall.find_children("*", "GeometryInstance3D", true, false): ms.append(m)
	_walls.append({"node": wall, "meshes": ms, "opt": opt})

func unregister(wall: Node) -> void:
	for e in _walls.duplicate():
		if e.node == wall:
			for g in e.meshes: if is_instance_valid(g): step_to(g, 1.0, 1000.0)
			_walls.erase(e)

func force_fade(on: bool) -> void:
	forced = on

func is_registered(wall: Node) -> bool:
	for e in _walls: if e.node == wall: return true
	return false

func _pos(src) -> Vector3:
	if src is Callable: return (src as Callable).call()
	if src is Node3D and is_instance_valid(src): return (src as Node3D).global_position
	return Vector3.INF

static func _aabb_of(meshes: Array) -> AABB:
	var out := AABB(); var first := true
	for g in meshes:
		if not is_instance_valid(g) or not (g is VisualInstance3D): continue
		var ab: AABB = (g as VisualInstance3D).global_transform * (g as VisualInstance3D).get_aabb()
		if first: out = ab; first = false
		else: out = out.merge(ab)
	return out

static func _dist(ab: AABB, p: Vector3) -> float:
	var q := p.clamp(ab.position, ab.end); return q.distance_to(p)

func _process(dt: float) -> void:
	if not enabled or _walls.is_empty(): return
	var cp := _pos(cam); var pp := _pos(player)
	for e in _walls.duplicate():
		if not is_instance_valid(e.node): _walls.erase(e); continue
		var o: Dictionary = e.opt
		var min_a: float = float(o.get("min_a", MIN_A))
		var target := 1.0
		if forced: target = min_a
		elif cp != Vector3.INF:
			var ab := _aabb_of(e.meshes)
			var k := 0.0
			var eye := pp + Vector3(0, float(o.get("eye", EYE)), 0) if pp != Vector3.INF else Vector3.INF
			if eye != Vector3.INF and (ab.intersects_segment(cp, eye) or ab.intersects_segment(cp, pp + Vector3(0, 0.3, 0))): k = 1.0
			# gradual: the closer the camera (or the player, from the camera side) is to the wall, the more it fades
			k = maxf(k, 1.0 - clampf(_dist(ab, cp) / float(o.get("near_cam", NEAR_CAM)), 0.0, 1.0))
			if eye != Vector3.INF and _dist(ab, cp) < _dist(ab, eye) + 2.5:
				k = maxf(k, 0.6 * (1.0 - clampf(_dist(ab, eye) / float(o.get("near_player", NEAR_PLAYER)), 0.0, 1.0)))
			target = lerpf(1.0, min_a, k)
		for g in e.meshes: if is_instance_valid(g): step_to(g, target, dt, SPEED, bool(o.get("shadows", true)))

## blue-compatible single-mesh step (scripts/places/wall_fade_adapter.gd): hidden -> fully transparent (invisible)
static func step(g: GeometryInstance3D, hidden: bool, dt: float, speed := SPEED) -> void:
	step_to(g, 0.0 if hidden else 1.0, dt, speed, false)

static func step_to(g: GeometryInstance3D, to: float, dt: float, speed := SPEED, shadows := true) -> void:
	if g == null or not is_instance_valid(g): return
	var a: float = float(g.get_meta("wf_a", 1.0))
	if is_equal_approx(a, to) and g.has_meta("wf_a"): return
	a = move_toward(a, to, dt * speed); g.set_meta("wf_a", a)
	if not g.has_meta("wf_cast"): g.set_meta("wf_cast", g.cast_shadow)
	if a >= 0.999:   # fully back: original material, opaque pipeline, shadows
		if g.has_meta("wf_mat"): g.material_override = g.get_meta("wf_orig")
		g.visible = true; g.cast_shadow = g.get_meta("wf_cast")
		return
	var fm: StandardMaterial3D = g.get_meta("wf_mat") if g.has_meta("wf_mat") else null
	if fm == null:
		var base: Material = g.material_override
		if base == null and g is MeshInstance3D and (g as MeshInstance3D).mesh and (g as MeshInstance3D).mesh.get_surface_count() > 0:
			base = (g as MeshInstance3D).get_active_material(0)
		g.set_meta("wf_orig", g.material_override)
		fm = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		g.set_meta("wf_mat", fm)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH if shadows else BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color.a = a
	g.material_override = fm
	g.visible = a > 0.001
	if not shadows: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
