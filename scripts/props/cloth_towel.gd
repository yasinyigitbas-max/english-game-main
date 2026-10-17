## Cloth towel: self-contained verlet cloth (no SoftBody3D, no physics server), mobile-cheap.
## 8 x 12 points, structural + shear + bend constraints, gravity, damping, a light idle breeze,
## top edge pinned to an anchor (hand/bone via attach_to, rail/hook via hang_at). The mesh is an
## ArrayMesh rebuilt each frame in WORLD space (top_level) with smooth normals; double-sided material.
## Usage:
##   var t := preload("res://scripts/props/cloth_towel.gd").new(); add_child(t)
##   t.hang_at(rail.global_transform)                 # pinned on a rail / hook
##   t.attach_to(hero._hand["R"], Transform3D(...))   # follows the hand, swings with it
##   t.detach()                                       # drops pins: the towel falls (keep for a frame or free it)
class_name ClothTowel
extends Node3D

@export var size := Vector2(0.46, 0.62)      # width (along the pinned edge) x hanging length, metres
@export var cols := 8
@export var rows := 12
@export var colour := Color(0.40, 0.56, 0.76)   # bathroom BLUE (current towel colour)
@export var gravity := 9.8
@export var damping := 0.985                    # verlet velocity keep per 1/60 s step
@export var iterations := 5
@export var breeze := 0.25                      # idle breeze acceleration (m/s^2)
@export var floor_y := -INF                     # optional: keep points above this world height

const STEP := 1.0 / 60.0
var _p := PackedVector3Array()     # current positions (world)
var _o := PackedVector3Array()     # previous positions (world)
var _pinned := PackedByteArray()
var _rest := PackedFloat32Array()
var _ca := PackedInt32Array(); var _cb := PackedInt32Array()
var _acc := 0.0
var _t := 0.0
var _anchor: Node3D = null
var _offset := Transform3D.IDENTITY
var _fixed := Transform3D.IDENTITY
var _mode := 0                     # 0 = hang_at (fixed), 1 = attached, 2 = free
var _last_pin := Transform3D.IDENTITY
var _mi: MeshInstance3D
var _mesh: ArrayMesh
var _idx := PackedInt32Array(); var _uv := PackedVector2Array()
var _inited := false

func _ready() -> void:
	top_level = true; global_transform = Transform3D.IDENTITY
	_mi = MeshInstance3D.new(); _mesh = ArrayMesh.new(); _mi.mesh = _mesh
	var m := StandardMaterial3D.new(); m.albedo_color = colour; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95; m.metallic_specular = 0.15
	_mi.material_override = m; _mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.extra_cull_margin = 2.0; add_child(_mi)
	_build_topology()
	if not _inited: _reset(_fixed if _mode == 0 else _pin_xf())

## pin the top edge to a moving node (hand / bone attachment). offset is in the node's local space;
## the towel's top edge runs along offset's local X, hanging is along world -Y.
func attach_to(node: Node3D, offset := Transform3D.IDENTITY) -> void:
	_anchor = node; _offset = offset; _mode = 1
	if is_inside_tree() and not _inited: _reset(_pin_xf())

## pin the top edge to a fixed world transform (rail / hook). Edge along the transform's X axis.
func hang_at(xf: Transform3D) -> void:
	_anchor = null; _fixed = xf; _mode = 0
	if is_inside_tree() and not _inited: _reset(xf)

## release all pins; the cloth falls freely (use floor_y to stop it at the floor).
func detach() -> void:
	_anchor = null; _mode = 2

## teleport the cloth to hang straight from the current pin (e.g. after a scene jump)
func snap() -> void: _reset(_pin_xf())

func max_speed() -> float:   # m/s, for tests (jitter / explosion checks)
	var m := 0.0
	for i in _p.size(): m = maxf(m, (_p[i] - _o[i]).length() / STEP)
	return m

func points() -> PackedVector3Array: return _p

func _pin_xf() -> Transform3D:
	if _mode == 1 and is_instance_valid(_anchor): return _anchor.global_transform * _offset
	return _fixed

func _pin_point(xf: Transform3D, c: int) -> Vector3:
	var u := float(c) / float(cols - 1) - 0.5
	var ax := xf.basis.x.normalized() * size.x
	return xf.origin + ax * u

func _build_topology() -> void:
	_ca.clear(); _cb.clear(); _rest.clear(); _idx.clear(); _uv.clear()
	var dx := size.x / (cols - 1); var dy := size.y / (rows - 1)
	for r in rows:
		for c in cols:
			var i := r * cols + c
			_uv.append(Vector2(float(c) / (cols - 1), float(r) / (rows - 1)))
			if c + 1 < cols: _add_c(i, i + 1, dx)
			if r + 1 < rows: _add_c(i, i + cols, dy)
			if c + 1 < cols and r + 1 < rows:
				_add_c(i, i + cols + 1, sqrt(dx * dx + dy * dy)); _add_c(i + 1, i + cols, sqrt(dx * dx + dy * dy))
			if c + 2 < cols: _add_c(i, i + 2, dx * 2.0)
			if r + 2 < rows: _add_c(i, i + 2 * cols, dy * 2.0)
			if c + 1 < cols and r + 1 < rows:
				_idx.append_array([i, i + 1, i + cols, i + 1, i + cols + 1, i + cols])

func _add_c(a: int, b: int, l: float) -> void: _ca.append(a); _cb.append(b); _rest.append(l)

func _reset(xf: Transform3D) -> void:
	_p.resize(rows * cols); _o.resize(rows * cols); _pinned.resize(rows * cols)
	var dy := size.y / (rows - 1)
	for r in rows:
		for c in cols:
			var i := r * cols + c
			_p[i] = _pin_point(xf, c) + Vector3.DOWN * dy * r + xf.basis.z.normalized() * 0.002 * sin(c * 1.7 + r)
			_o[i] = _p[i]; _pinned[i] = 1 if r == 0 else 0
	_last_pin = xf; _inited = true; _rebuild_mesh()

func _physics_process(delta: float) -> void:
	if not _inited: return
	_acc = minf(_acc + delta, STEP * 4.0)
	var xf := _pin_xf()
	if xf.origin.distance_to(_last_pin.origin) > 1.0: _reset(xf)   # teleport guard (scene jumps)
	var steps := int(_acc / STEP)
	_acc -= steps * STEP
	for s in steps: _step(_last_pin.interpolate_with(xf, float(s + 1) / steps))
	if steps > 0: _last_pin = xf; _rebuild_mesh()

func _step(xf: Transform3D) -> void:
	_t += STEP
	var wind := Vector3(sin(_t * 0.7) + 0.4 * sin(_t * 2.3), 0.0, cos(_t * 0.5) * 0.8 + 0.3 * sin(_t * 1.9)) * breeze
	var g := Vector3(0, -gravity, 0); var dt2 := STEP * STEP
	var n := _p.size()
	for i in n:
		if _pinned[i] == 1 and _mode != 2:
			_o[i] = _p[i]; _p[i] = _pin_point(xf, i % cols); continue
		var r := i / cols
		var w := wind * (float(r) / rows) * (1.0 + 0.3 * sin(_t * 3.1 + i))
		var v := (_p[i] - _o[i]) * damping
		_o[i] = _p[i]; _p[i] += v + (g + w) * dt2
	for it in iterations:
		for k in _ca.size():
			var a := _ca[k]; var b := _cb[k]
			var d := _p[b] - _p[a]; var l := d.length()
			if l < 1e-6: continue
			var diff := (l - _rest[k]) / l
			var pa := _pinned[a] == 1 and _mode != 2; var pb := _pinned[b] == 1 and _mode != 2
			if pa and pb: continue
			if pa: _p[b] -= d * diff
			elif pb: _p[a] += d * diff
			else: _p[a] += d * diff * 0.5; _p[b] -= d * diff * 0.5
	if floor_y > -INF:
		for i in n: if _p[i].y < floor_y: _p[i].y = floor_y; _o[i].y = floor_y

func _rebuild_mesh() -> void:
	var nrm := PackedVector3Array(); nrm.resize(_p.size())
	for r in rows:
		for c in cols:
			var i := r * cols + c
			var tx := _p[r * cols + mini(c + 1, cols - 1)] - _p[r * cols + maxi(c - 1, 0)]
			var ty := _p[mini(r + 1, rows - 1) * cols + c] - _p[maxi(r - 1, 0) * cols + c]
			var nn := ty.cross(tx); nrm[i] = nn.normalized() if nn.length() > 1e-8 else Vector3.BACK
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _p; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_TEX_UV] = _uv; arr[Mesh.ARRAY_INDEX] = _idx
	_mesh.clear_surfaces(); _mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
