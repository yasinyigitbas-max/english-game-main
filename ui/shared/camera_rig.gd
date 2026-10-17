## CameraRig - shared follow camera (res://ui/shared/camera_rig.tscn): the bedroom framing (fov 42, pitch 0.9025,
## distance 9.68) plus zoom + rotate on every platform:
##   mouse wheel = zoom, right/middle drag = rotate, touch pinch = zoom, two-finger drag = rotate,
##   HUD camera ring (GameHUD) -> cam_stick, keyboard Q/E = rotate, +/- = zoom.
## Movement code turns stick input by `yaw` so "up" is always away from the camera.
class_name CameraRig
extends Camera3D

var target: Node3D
var override_point := Vector3.INF      # look here instead of the target (cut-scenes / QA)
var focus := Vector3.ZERO
var yaw := 0.0
var pitch := 0.9025
var dist := 9.68
var min_dist := 4.0
var max_dist := 22.0
var min_pitch := 0.45
var max_pitch := 1.30
var cam_stick := Vector2.ZERO
var _touches := {}
var controlled := true                  # false while another system (pocket_phone) drives the camera
var _saved: Array = []
## v33 (blue): camera occlusion avoidance (scripts/props/wall_fade.gd CamAvoid): pull in / swing around walls that hide
## the target, ease back when clear. Off while another system drives the camera (take_over), while the rig is not the
## current camera (cut-scene temp cameras) and while override_point is set (cut-scenes) unless avoid_with_override.
var avoid := true
var avoid_with_override := false        # bathroom: override_point is its normal room framing, not a cut-scene
var _avoid = preload("res://scripts/props/wall_fade.gd").CamAvoid.new()
var _dt := 1.0

## temporary take-over (e.g. ui/pocket_phone.gd zooming in on the phone): release() hands control back and
## restores the exact framing that was active before.
func take_over() -> void:
	_saved.push_back([global_transform, fov, yaw, pitch, dist, focus]); controlled = false
func release(restore := true) -> void:
	if not _saved.is_empty():
		var st: Array = _saved.pop_back()
		if restore: global_transform = st[0]; fov = st[1]; yaw = st[2]; pitch = st[3]; dist = st[4]; focus = st[5]
	controlled = _saved.is_empty()
var _pinch0 := 0.0

func _ready() -> void:
	fov = 42.0; current = true
	if target: focus = target.global_position

func setup(t: Node3D, d: float, p: float, dmin := 4.0, dmax := 22.0) -> void:
	target = t; dist = d; pitch = p; min_dist = dmin; max_dist = maxf(dmax, d); focus = t.global_position; snap()

func snap() -> void: _place(focus)

func _process(dt: float) -> void:
	if target == null or not controlled: return
	var want := override_point if override_point != Vector3.INF else target.global_position
	focus = focus.lerp(want, 1.0 - exp(-3.0 * dt))
	var k := Vector2(float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_MINUS)) - float(Input.is_physical_key_pressed(KEY_EQUAL)))
	var s := cam_stick + Vector2(k.x, 0)
	if s.length() > 0.1:
		yaw -= s.x * 1.8 * dt; pitch = clampf(pitch + s.y * 0.9 * dt, min_pitch, max_pitch)
	if k.y != 0.0: zoom(1.0 + k.y * 1.5 * dt)
	_dt = dt
	_place(focus)

func _place(f: Vector3) -> void:
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	position = f + off
	if avoid and is_inside_tree():   # v33: occlusion avoidance (eases back to the plain offset when off)
		var on: bool = controlled and current and target != null and is_instance_valid(target) and (override_point == Vector3.INF or avoid_with_override)
		var tp: Vector3 = target.global_position + Vector3(0, 1.0, 0) if target != null and is_instance_valid(target) else Vector3.INF
		var par := get_parent() as Node3D
		var gf: Vector3 = par.to_global(f) if par else f
		var gp: Vector3 = _avoid.adjust(gf, par.to_global(position) if par else position, tp, _dt, on, get_tree())
		position = par.to_local(gp) if par else gp
		_dt = 1.0
	look_at(f + Vector3(0, 0.3, 0), Vector3.UP)

func zoom(factor: float) -> void: dist = clampf(dist * factor, min_dist, max_dist)
func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx * 0.008; pitch = clampf(pitch + dy * 0.005, min_pitch, max_pitch)

func _unhandled_input(e: InputEvent) -> void:
	if not controlled: return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom(0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom(1.1)
	elif e is InputEventMouseMotion and (e.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
		rotate_by(e.relative.x, e.relative.y)
	elif e is InputEventMagnifyGesture: zoom(1.0 / e.factor)
	elif e is InputEventScreenTouch:
		if e.pressed: _touches[e.index] = e.position
		else: _touches.erase(e.index)
		if _touches.size() == 2: _pinch0 = (_touches.values()[0] as Vector2).distance_to(_touches.values()[1])
	elif e is InputEventScreenDrag and _touches.has(e.index):
		var before: Vector2 = _touches[e.index]; _touches[e.index] = e.position
		if _touches.size() == 2:
			var ps: Array = _touches.values(); var d: float = (ps[0] as Vector2).distance_to(ps[1])
			if _pinch0 > 1.0 and d > 1.0: zoom(_pinch0 / d); _pinch0 = d
			rotate_by((e.position - before).x * 0.5, (e.position - before).y * 0.5)   # two-finger drag
