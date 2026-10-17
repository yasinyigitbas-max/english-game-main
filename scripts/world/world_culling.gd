## v34 open world (blue): culling / perf for the one world scene, as one drop-in node (child of scenes/world.tscn).
##   var wc := preload("res://scripts/world/world_culling.gd").new(); world.add_child(wc)
## Applied to everything under the parent, and to whatever streams in later (node_added):
##   * visibility ranges (no fade = no transparency cost on gl_compatibility; small hysteresis margin):
##       small props (largest side < PROP_SIZE)            -> hidden beyond PROP_RANGE
##       interior contents (world places, house rooms,
##       group "interiors"; not their walls / floors)      -> hidden beyond INTERIOR_RANGE (from the camera)
##       everything else (buildings, walls, roads)          -> FAR_RANGE (0 = unlimited)
##     a node that already has a visibility_range_end, or meta "no_cull", is left alone
##   * lights: omni / spot fade out beyond LIGHT_RANGE, their shadows beyond SHADOW_RANGE; the sun's shadows end at SUN_SHADOW
##   * occluders (rendering/occlusion_culling/use_occlusion_culling must be on in project.godot, measured to work on
##     gl_compatibility: the culling is CPU side): one BoxOccluder3D per real wall (thin + tall box) and per street building
##     ("fade" group), shrunk a little. Walls and buildings FADE when they hide the player, and an occluder would then hide
##     the player, so an occluder is only active while its wall is more than OCC_ON m from the player (off below OCC_OFF):
##     toggled sporadically (2 Hz check + hysteresis), as the occlusion system wants.
extends Node

const ShoulderCam := preload("res://scripts/core/shoulder_cam.gd")
const House := preload("res://scripts/core/house.gd")
@export var prop_size := 1.2
@export var prop_range := 24.0
@export var interior_range := 38.0
@export var mid_size := 6.0        # diagonal: street furniture, cars parked, fences, small sheds
@export var mid_range := 48.0
@export var far_range := 95.0      # everything up to BIG_SIZE (building parts, road pieces); 0 = unlimited
@export var big_size := 30.0
@export var tighten := true        # also shorten World._cull_setup's 70 m / 30 m ranges (blue owns the tuning)
@export var light_range := 24.0
@export var shadow_range := 10.0
@export var sun_shadow := 32.0
@export var occluders := true
@export var enabled := true
const OCC_ON := 14.0
const OCC_OFF := 10.0
var host: Node = null
var _occ: Array = []        # [OccluderInstance3D, AABB world]
var _pending: Array = []
var _next := 0.0
var stats := {"props": 0, "interior": 0, "lights": 0, "occluders": 0}

func _ready() -> void:
	name = "WorldCulling"
	if host == null: host = get_parent()
	if not enabled: return
	if occluders: get_viewport().use_occlusion_culling = true   # runtime switch (no project.godot change needed)
	get_tree().node_added.connect(func(n: Node) -> void: if n is GeometryInstance3D or n is Light3D: _pending.append(n))
	apply.call_deferred(host)

func apply(root: Node) -> void:
	for g in root.find_children("*", "GeometryInstance3D", true, false): _geo(g)
	for l in root.find_children("*", "Light3D", true, false): _light(l)

func _interior(n: Node) -> bool:
	var p := n.get_parent()
	while p and p != host:
		if p.is_in_group("world_places") or p.is_in_group("interiors") or House.is_room(String(p.scene_file_path)): return true
		p = p.get_parent()
	return false

func _geo(g: GeometryInstance3D) -> void:
	if not is_instance_valid(g) or g.has_meta("no_cull") or g.has_meta("wc_done"): return
	if g.visibility_range_end > 0.0 and not tighten: return
	if g is MeshInstance3D and (g as MeshInstance3D).mesh == null: return
	g.set_meta("wc_done", true)
	var ab: AABB = g.global_transform * g.get_aabb()
	var big := maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
	var wall := ShoulderCam._is_wall(ab)
	var r0 := g.visibility_range_end
	var r := 0.0; var mg := 2.0
	if big < prop_size:
		r = prop_range; stats.props += 1; g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # props: no shadow pass
	elif not wall and ab.size.y < 2.6 and ab.size.x < 12.0 and ab.size.z < 12.0 and _interior(g):   # furniture, decor (not walls / floors)
		r = interior_range; mg = 3.0; stats.interior += 1
	elif ab.size.length() < mid_size: r = mid_range; mg = 4.0; stats.mid = int(stats.get("mid", 0)) + 1
	elif far_range > 0.0 and big < big_size: r = far_range; mg = 6.0; stats.far = int(stats.get("far", 0)) + 1
	if r > 0.0 and (r0 <= 0.0 or r < r0): g.visibility_range_end = r; g.visibility_range_end_margin = mg
	if occluders and g is MeshInstance3D and (wall or (g.is_in_group("fade") and ab.size.y >= 2.0 and ab.size.x < 40.0 and ab.size.z < 40.0)):
		_add_occluder(g as MeshInstance3D, ab, wall)

func _add_occluder(m: MeshInstance3D, ab_world: AABB, wall: bool) -> void:
	var la := m.get_aabb()
	var oi := OccluderInstance3D.new(); oi.name = "WCOccluder"
	var bo := BoxOccluder3D.new()
	var s := la.size * (Vector3(1.0, 0.95, 1.0) if wall else Vector3(0.9, 0.95, 0.9))
	if wall:   # keep a wall occluder thin, inside the wall
		if s.x < s.z: s.x = minf(s.x, 0.05)
		else: s.z = minf(s.z, 0.05)
	bo.size = s; oi.occluder = bo; oi.position = la.get_center(); oi.visible = false
	m.add_child(oi); _occ.append([oi, ab_world]); stats.occluders += 1

func _light(l: Light3D) -> void:
	if not is_instance_valid(l) or l.has_meta("no_cull") or l.has_meta("wc_done"): return
	l.set_meta("wc_done", true)
	if l is DirectionalLight3D:
		var d := l as DirectionalLight3D
		if d.shadow_enabled:
			d.directional_shadow_max_distance = minf(d.directional_shadow_max_distance, sun_shadow)
			d.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL   # one shadow pass instead of 2 splits
		return
	if not l.distance_fade_enabled:
		l.distance_fade_enabled = true; l.distance_fade_begin = light_range; l.distance_fade_length = 6.0
		l.distance_fade_shadow = shadow_range; stats.lights += 1

func _process(_dt: float) -> void:
	if not enabled: return
	if not _pending.is_empty():
		var q := _pending; _pending = []
		for n in q:
			if not is_instance_valid(n) or not n.is_inside_tree(): continue
			if n is GeometryInstance3D: _geo.call_deferred(n)   # deferred: its parents / groups are set up by then
			elif n is Light3D: _light(n)
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next or _occ.is_empty(): return
	_next = now + 0.5
	var c := get_viewport().get_camera_3d()
	var pl = host.get("player") if host else null
	var p: Vector3 = (pl as Node3D).global_position if pl is Node3D and is_instance_valid(pl) else (c.global_position if c else Vector3.INF)
	if p == Vector3.INF: return
	for e in _occ.duplicate():
		var oi: OccluderInstance3D = e[0]
		if not is_instance_valid(oi): _occ.erase(e); continue
		var ab: AABB = e[1]
		var d := (ab.get_center() - p).length() - ab.size.length() * 0.5
		var f: Node = oi.get_parent()
		var faded: bool = f != null and f.has_meta("wf_a") and float(f.get_meta("wf_a", 1.0)) < 0.99
		if oi.visible and (d < OCC_OFF or faded): oi.visible = false
		elif not oi.visible and d > OCC_ON and not faded: oi.visible = true
