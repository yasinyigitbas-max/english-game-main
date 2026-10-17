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
## v33 occlusion mode (blue, Yasin's rule: ANY wall that hides the player from the camera fades, then comes back):
##   wf.register_occluder(wall, {"group": "L", "out": Callable})  # fades to OCC_MIN_A only while it blocks the camera -> player
##       view (AABB segment test camera -> feet/chest/head, throttled ~10 Hz, entry/keep hysteresis, only walls within OCC_NEAR
##       of the player). Walls with the same "group" fade together; "out" (Callable -> bool) forces the fade (e.g. camera
##       outside the room); "hide_containers": non-mesh nodes just hide below alpha 0.6 (bathroom tile grids). force_fade()
##       does NOT touch occluders (breakfast pans stay as before).
##   Static, for callers with their own wall loops (place_base / work / world_exterior):
##   WallFade.occluded(node, cam_pos, feet, aabb := auto) -> bool   # throttled + hysteresis, state kept in node metas
##   WallFade.step_occl(g, to_alpha, dt)                            # asymmetric fade: out over ~0.3 s, back over ~0.4 s
## Materials: on the first fade a mesh gets its own copy of its material (material_override or surface 0) with alpha; at
## alpha >= 0.999 the original material comes back (opaque pipeline). Alpha-hash keeps shadows on walls (house.24.2).
extends Node

const SPEED := 3.0          # alpha per second (about 0.3 s for a full fade)
const MIN_A := 0.12
const NEAR_CAM := 1.2
const NEAR_PLAYER := 1.0
const EYE := 1.2
const OCC_MIN_A := 0.18     # v33 occlusion: lowest alpha of a wall that hides the player
const OCC_OUT := 0.3        # s for a full fade out
const OCC_IN := 0.4         # s for a full fade back
const OCC_NEAR := 4.0       # m: only walls this close to the player's chest fade
const OCC_DT := 0.1         # s between occlusion tests (~10 Hz)
const OCC_HOLD := 0.3       # s a wall must stay clear before it fades back (no edge flicker)
const OCC_GROW_IN := 0.12   # m: small sphere around the test points (entry)
const OCC_GROW_KEEP := 0.35 # m: wider keep margin once faded (hysteresis)
const OCC_PTS := [0.25, 0.9, 1.5]   # feet, chest, head above the player's feet

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

func register_occluder(wall: Node, opt := {}) -> void:
	var o: Dictionary = opt.duplicate(); o["occl"] = true; register(wall, o)
	if is_instance_valid(wall) and not bool(opt.get("no_cam", false)): wall.add_to_group(CAM_GROUP)   # v33: camera avoids it

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
	var occ := {}   # v33: group -> blocked
	for e in _walls.duplicate():
		if not is_instance_valid(e.node): _walls.erase(e); continue
		if not e.opt.get("occl", false): continue
		var key = e.opt.get("group", e.node)
		var hit: bool = bool(occ.get(key, false))
		if not hit:
			var oc = e.opt.get("out", null)
			hit = (oc is Callable and bool((oc as Callable).call())) or occluded(e.node, cp, pp, AABB(), float(e.opt.get("near", OCC_NEAR)))
		occ[key] = hit
	for e in _walls:
		var o: Dictionary = e.opt
		if o.get("occl", false):
			_occl_apply(e, bool(occ.get(o.get("group", e.node), false)), dt)
			continue
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

# ------------------------------------------------------------------ v33 occlusion (blue)
func _occl_apply(e: Dictionary, hit: bool, dt: float) -> void:
	var o: Dictionary = e.opt; var min_a: float = float(o.get("min_a", OCC_MIN_A))
	var to := min_a if hit else 1.0
	if bool(o.get("hide_containers", false)) and not (e.node is GeometryInstance3D):
		var a: float = float(e.get("a", 1.0))
		a = move_toward(a, to, dt * (1.0 - min_a) / (OCC_OUT if to < a else OCC_IN)); e["a"] = a
		(e.node as Node3D).visible = a > 0.6
		return
	if hit and not e.has("att"): e["att"] = _attached(e)   # first fade: wall decor / baseboards / frames fade with it
	for g in e.meshes: if is_instance_valid(g): step_occl(g, to, dt, bool(o.get("shadows", true)))
	for g in e.get("att", []):
		if not is_instance_valid(g): continue
		if g.has_meta("wf_vis"):   # no plain material to fade: just hide while the wall is faded
			var a: float = move_toward(float(g.get_meta("wf_va", 1.0)), to, dt * (1.0 - min_a) / (OCC_OUT if to < float(g.get_meta("wf_va", 1.0)) else OCC_IN))
			g.set_meta("wf_va", a)
			if a <= 0.6 and not g.has_meta("wf_hid"): g.set_meta("wf_hid", g.visible); g.visible = false
			elif a > 0.6 and g.has_meta("wf_hid"): g.visible = bool(g.get_meta("wf_hid")); g.remove_meta("wf_hid")
		else: step_occl(g, to, dt, bool(o.get("shadows", true)))

## meshes of the scene lying flat on / inside this wall (within 0.2 m of its box): posters, baseboards, trims, frames,
## mirror glass. Not registered walls, not the player. Multi-surface / non-standard materials only hide (no white copy).
func _attached(e: Dictionary) -> Array:
	var out := []; var host := get_parent()
	if host == null: return out
	var ab := _aabb_of(e.meshes).grow(0.2)
	if ab.size == Vector3.ZERO: return out
	var mine := {}
	for w in _walls: for g in w.meshes: mine[g] = true
	var pn: Node = null
	var pp = player
	if pp is Node: pn = pp
	for g in host.find_children("*", "GeometryInstance3D", true, false):
		if mine.has(g) or not (g is VisualInstance3D) or g.has_meta("wf_att"): continue
		if pn and (pn == g or pn.is_ancestor_of(g)): continue
		if "hero" in host and host.hero is Node and (host.hero as Node).is_ancestor_of(g): continue
		var gb: AABB = (g as VisualInstance3D).global_transform * (g as VisualInstance3D).get_aabb()
		if gb.size == Vector3.ZERO or not ab.encloses(gb) or not (g as Node3D).is_visible_in_tree(): continue
		var plain: bool = g is MeshInstance3D and (g as MeshInstance3D).mesh != null and (g as MeshInstance3D).mesh.get_surface_count() == 1
		var mat: Material = g.material_override
		if plain and mat == null: mat = (g as MeshInstance3D).get_active_material(0)
		if not plain or not (mat is StandardMaterial3D) or (mat as StandardMaterial3D).albedo_texture is ViewportTexture:
			g.set_meta("wf_vis", true)
		g.set_meta("wf_att", true); out.append(g)
	return out

## true while `ab` (a wall's world AABB) sits between the camera and the player (feet / chest / head, each a small sphere of
## radius `grow`). Walls behind the player or farther than `near` from the chest never count.
static func occludes(ab: AABB, cp: Vector3, feet: Vector3, grow := OCC_GROW_IN, near := OCC_NEAR) -> bool:
	if cp == Vector3.INF or feet == Vector3.INF or ab.size == Vector3.ZERO: return false
	if _dist(ab, feet + Vector3(0, 0.9, 0)) > near: return false
	var gb := ab.grow(grow)
	for h in OCC_PTS:
		var p: Vector3 = feet + Vector3(0, h, 0)
		var d := cp - p; var l := d.length()
		if l < 0.05: continue
		if (ab.get_center() - p).dot(d) <= 0.0: continue        # wall behind the player (seen from the camera)
		var p2 := p + d / l * minf(grow + 0.1, l)                   # start just outside the sphere (a wall the player leans on but
		if gb.intersects_segment(cp, p2): return true              # that is not between player and camera never fades)
	return false

## throttled (~10 Hz) + hysteresis occlusion state for one node (metas wf_ot / wf_oc / wf_ol)
static func occluded(n: Node, cp: Vector3, feet: Vector3, ab := AABB(), near := OCC_NEAR) -> bool:
	if n == null or not is_instance_valid(n): return false
	if not n.is_in_group(CAM_GROUP): n.add_to_group(CAM_GROUP)   # v33: the follow camera avoids it (CamAvoid)
	var now := Time.get_ticks_msec() / 1000.0
	var on: bool = bool(n.get_meta("wf_oc", false))
	if now < float(n.get_meta("wf_ot", -1.0)): return on
	n.set_meta("wf_ot", now + OCC_DT)
	if ab.size == Vector3.ZERO:
		var ms: Array = [n] if n is VisualInstance3D else n.find_children("*", "VisualInstance3D", true, false)
		ab = _aabb_of(ms)
	var hit := occludes(ab, cp, feet, OCC_GROW_KEEP if on else OCC_GROW_IN, near + (0.5 if on else 0.0))
	if hit: n.set_meta("wf_ol", now)
	elif on and now - float(n.get_meta("wf_ol", 0.0)) < OCC_HOLD: hit = true
	n.set_meta("wf_oc", hit)
	return hit

## hysteresis only, for callers with their own hit test (world_exterior): stays true OCC_HOLD s after the last raw hit
static func hold(n: Node, hit: bool) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if hit: n.set_meta("wf_ol", now)
	elif bool(n.get_meta("wf_oc", false)) and now - float(n.get_meta("wf_ol", 0.0)) < OCC_HOLD: hit = true
	n.set_meta("wf_oc", hit)
	return hit

## fade one mesh toward `to` (out over OCC_OUT s, back over OCC_IN s); own duplicated material per mesh (step_to)
static func step_occl(g: GeometryInstance3D, to: float, dt: float, shadows := true) -> void:
	if g == null or not is_instance_valid(g): return
	if not g.has_meta("wf_a"): step_to(g, to, dt, 1000.0, shadows)   # first frame of a scene: start in place (no fade-in pop)
	else:
		var a: float = float(g.get_meta("wf_a", 1.0))
		step_to(g, to, dt, (1.0 - OCC_MIN_A) / (OCC_OUT if to < a else OCC_IN), shadows)
	# true see-through (alpha blend, depth draw opaque-only so it never hides what is behind it in gl_compatibility)
	var fm = g.get_meta("wf_mat") if g.has_meta("wf_mat") else null
	if fm is StandardMaterial3D and g.material_override == fm:
		(fm as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(fm as StandardMaterial3D).depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

# ------------------------------------------------------------------ v33 camera occlusion avoidance (blue)
## Generic follow-camera helper (no per-room code): when the camera -> player line is blocked by a wall, move the camera to
## a clear spot (pull in along the boom first, then swing yaw left / right up to 90 deg), ease back to the default offset
## once the default is clear again. Blockers = walls in group "cam_occluder" (every WallFade occluder joins it) + street
## buildings (group "fade"); south walls / props / floors are never blockers. When no clear spot exists the camera stays on
## its default offset and the wall fade above covers it (fallback).
##   var av = WallFade.CamAvoid.new()
##   cam_pos = av.adjust(pivot, desired_cam_pos, player_chest, dt, enabled, get_tree())   # every frame
const CAM_GROUP := "cam_occluder"
class CamAvoid extends RefCounted:
	const GROUP := "cam_occluder"
	const PULLS := [0.8, 0.65, 0.5]
	const YAWS := [0.4, 0.8, 1.2, 1.57]       # rad, tried on the preferred side first, then the other
	const TAU := 0.09                          # s smoothing (~0.27 s to 95 %)
	const BACK_HOLD := 0.4                     # s the default must stay clear before easing back
	var min_dist := 3.0
	var enabled := true                        # master switch (QA / settings)
	var yaw := 0.0; var k := 1.0               # applied (smoothed)
	var t_yaw := 0.0; var t_k := 1.0           # chosen target
	var active := false                        # an adjusted spot is in use
	var fallback := false                      # blocked and no clear spot (wall fade handles it)
	var _next := 0.0; var _clear_since := -1.0
	static func spot(pivot: Vector3, desired: Vector3, y: float, kk: float) -> Vector3:
		return pivot + (desired - pivot).rotated(Vector3.UP, y) * kk
	func adjust(pivot: Vector3, desired: Vector3, target: Vector3, dt: float, on: bool, tree: SceneTree) -> Vector3:
		var now := Time.get_ticks_msec() / 1000.0
		if not on or not enabled or tree == null or target == Vector3.INF:
			t_yaw = 0.0; t_k = 1.0; active = false; fallback = false; _clear_since = -1.0
		elif now >= _next:
			_next = now + 0.1
			var boxes := blockers(tree, target, desired.distance_to(target) + 2.0)
			if not blocked(desired, target, boxes):
				fallback = false
				if active:
					if _clear_since < 0.0: _clear_since = now
					if now - _clear_since >= BACK_HOLD: active = false; t_yaw = 0.0; t_k = 1.0
				else: t_yaw = 0.0; t_k = 1.0
			else:
				_clear_since = -1.0
				if not (active and not blocked(spot(pivot, desired, t_yaw, t_k), target, boxes)):
					_search(pivot, desired, target, boxes)
		var s := 1.0 - exp(-dt / TAU)
		yaw = lerpf(yaw, t_yaw, s); k = lerpf(k, t_k, s)
		if absf(yaw - t_yaw) < 0.002: yaw = t_yaw
		if absf(k - t_k) < 0.002: k = t_k
		return spot(pivot, desired, yaw, k)
	func _search(pivot: Vector3, desired: Vector3, target: Vector3, boxes: Array) -> void:
		var L := (desired - pivot).length()
		var cands := []
		for p in PULLS: if L * p >= min_dist: cands.append([0.0, p])
		var side := -1.0 if t_yaw < 0.0 else 1.0
		for y in YAWS:
			cands.append([y * side, 1.0]); cands.append([-y * side, 1.0])
		for y in YAWS:
			if L * 0.7 >= min_dist: cands.append([y * side, 0.7]); cands.append([-y * side, 0.7])
		for c in cands:
			if not blocked(spot(pivot, desired, c[0], c[1]), target, boxes):
				t_yaw = c[0]; t_k = c[1]; active = true; fallback = false; return
		t_yaw = 0.0; t_k = 1.0; active = false; fallback = true
	## world AABBs of every blocker within r of the target
	static func blockers(tree: SceneTree, target: Vector3, r: float) -> Array:
		var out := []
		for gname in [GROUP, "fade"]:
			for n in tree.get_nodes_in_group(gname):
				if not (n is Node3D) or not (n as Node3D).is_inside_tree() or n.has_meta("wh_view_only"): continue   # v33: whole-house black void / ground twin
				var ms: Array = [n] if n is VisualInstance3D else n.find_children("*", "VisualInstance3D", true, false)
				var ab := AABB(); var first := true
				for g in ms:
					if not is_instance_valid(g): continue
					var gb: AABB = (g as VisualInstance3D).global_transform * (g as VisualInstance3D).get_aabb()
					if first: ab = gb; first = false
					else: ab = ab.merge(gb)
				if not first and target.clamp(ab.position, ab.end).distance_to(target) < r: out.append(ab)
		return out
	## camera -> player chest / head line cut by a blocker (walls behind the player or touching it don't count)
	static func blocked(cp: Vector3, target: Vector3, boxes: Array) -> bool:
		for abv in boxes:
			var ab: AABB = abv
			var gb: AABB = ab.grow(0.15)
			if gb.has_point(cp): return true
			for h in [0.0, 0.5]:
				var p: Vector3 = target + Vector3(0, h, 0); var d := cp - p; var l := d.length()
				if l < 0.1: continue
				if (ab.get_center() - p).dot(d) <= 0.0: continue
				if gb.intersects_segment(cp, p + d / l * minf(0.4, l)): return true
		return false
