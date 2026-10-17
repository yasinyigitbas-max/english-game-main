## Vehicle: follows a closed lane loop (built from the road grid, right-hand traffic). Kinematic, no physics.
## Brakes smoothly for: red/yellow traffic lights (stop line before the crossing), the player in its lane, the vehicle ahead.
## A bus also stops at its bus stops, opens its doors and offers "Get on the bus".
class_name Vehicle
extends Node3D

var path := PackedVector3Array()   # closed loop
var cum := PackedFloat32Array()
var length := 0.0
var s := 0.0
var speed := 0.0
var max_speed := 7.0
var accel := 3.0
var half_len := 2.1
var is_bus := false
var route_id := ""
var stops: Array = []              # [{id, s}]
var dwell := 0.0
var at_stop := ""
var last_stop := ""
var color := Color(0.85, 0.4, 0.35)
var doors: Array = []
var board: Interactable
var blocked_by := ""
# timetable (bus): arrival offsets in game minutes from the cycle start, cycle = headway; set by set_schedule()
var sched_first := 360.0
var headway := 60.0
var dwell_min := 6.0
var arr: Array = []          # arrival offset per stop (same order as stops)
var hold_stop := -1          # index of the stop we are waiting at
# body feel
var acc := 0.0               # smoothed acceleration (m/s^2) -> pitch
var body: Node3D             # visual body (sways on its suspension)
var _yaw_prev := 0.0
var _roll := 0.0
var _pitch := 0.0
static var all: Array = []

const DARK := Color(0.22, 0.23, 0.26)
const GLASS := Color(0.62, 0.74, 0.86)

func _enter_tree() -> void: all.append(self)
func _exit_tree() -> void: all.erase(self)

## lane loop from road-centre corners (clockwise / counter-clockwise order sets the direction), lane 2 m right of centre
static func lane_loop(corners: Array, offset := 2.0) -> PackedVector3Array:
	var out := PackedVector3Array(); var n := corners.size()
	for i in n:
		var p: Vector2 = corners[i]; var a: Vector2 = corners[(i - 1 + n) % n]; var b: Vector2 = corners[(i + 1) % n]
		var din := (p - a).normalized(); var dout := (b - p).normalized()
		var rin := Vector2(-din.y, din.x); var rout := Vector2(-dout.y, dout.x)
		# rounded corner: 3 points
		var c := p + (rin + rout) * offset
		out.append(Vector3(c.x - din.x * 3.0, 0.02, c.y - din.y * 3.0) if din.dot(dout) < 0.9 else Vector3(c.x, 0.02, c.y))
		if din.dot(dout) < 0.9:
			var m := c - din * 1.0 + dout * 1.0
			out.append(Vector3(m.x, 0.02, m.y)); out.append(Vector3(c.x + dout.x * 3.0, 0.02, c.y + dout.y * 3.0))
	return out

func setup(p: PackedVector3Array, start_s := 0.0) -> void:
	path = p; cum.resize(p.size() + 1); cum[0] = 0.0
	for i in p.size(): cum[i + 1] = cum[i] + p[i].distance_to(p[(i + 1) % p.size()])
	length = cum[p.size()]; s = fposmod(start_s, length)
	_build_mesh(); _place()

## build a deterministic timetable from the loop geometry: drive time is padded for one red light per leg,
## so the bus is never late; it waits at each stop until its scheduled departure (no drift).
func set_schedule(first_min: float, dw: float, ts: float) -> Dictionary:
	sched_first = first_min; dwell_min = dw; arr.clear()
	var t := 0.0
	for i in stops.size():
		arr.append(t)
		var d := fposmod(stops[(i + 1) % stops.size()].s - stops[i].s, length)
		t += dw + ceilf((d / max_speed + max_speed / accel + 14.0) * ts)
	headway = ceilf(t / 10.0) * 10.0     # even, so two buses half a cycle apart keep whole-minute times
	return {"offsets": arr.duplicate(), "headway": headway, "dwell": dw}

func phase(m: float) -> float: return fposmod(m - sched_first, headway)
func _past(ph: float, t: float) -> bool: return fposmod(ph - t, headway) < headway * 0.5

## put the bus where the timetable says it is at game minute m
func sync(m: float) -> void:
	var ph := phase(m); var n := stops.size()
	for i in n:
		var a: float = arr[i]; var dep: float = a + dwell_min
		var next_a: float = arr[i + 1] if i + 1 < n else headway
		if ph >= a and ph < dep:
			s = stops[i].s; speed = 0.0; _place(); _arrive(stops[i].id, i); return
		if ph >= dep and ph < next_a:
			var d := fposmod(stops[(i + 1) % n].s - stops[i].s, length)
			var drive := (d / max_speed + max_speed / accel) * WorldState.time_scale
			var k := clampf((ph - dep) / maxf(drive, 0.01), 0.0, 1.0)
			if k >= 1.0: s = stops[(i + 1) % n].s; speed = 0.0; _place(); _arrive(stops[(i + 1) % n].id, (i + 1) % n); return
			s = fposmod(stops[i].s + d * k, length); speed = max_speed; _close_doors(); last_stop = stops[i].id; hold_stop = -1; _place(); return
	s = stops[0].s; _place()

func project(pt: Vector3) -> float:
	var best := 0.0; var bd := INF
	for i in path.size():
		var a := path[i]; var b := path[(i + 1) % path.size()]
		var q := Geometry3D.get_closest_point_to_segment(pt, a, b)
		var d := q.distance_squared_to(pt)
		if d < bd: bd = d; best = cum[i] + a.distance_to(q)
	return best

func pos_at(d: float) -> Vector3:
	d = fposmod(d, length)
	var i := cum.bsearch(d, true) - 1; i = clampi(i, 0, path.size() - 1)
	var a := path[i]; var b := path[(i + 1) % path.size()]
	return a.lerp(b, (d - cum[i]) / maxf(cum[i + 1] - cum[i], 0.001))

func _place() -> void:
	var p := pos_at(s); var ahead := pos_at(s + 2.5); var behind := pos_at(s - 2.5)
	position = p
	var dir := ahead - behind
	if dir.length() > 0.01: rotation.y = atan2(dir.x, dir.z)

func fwd() -> Vector3: return Vector3(sin(rotation.y), 0, cos(rotation.y))

func _physics_process(dt: float) -> void:
	if length <= 0.0: return
	var gap := 99.0; blocked_by = ""
	var f := fwd(); var r := Vector3(f.z, 0, -f.x)
	# traffic lights
	for tl in get_tree().get_nodes_in_group("traffic_lights"):
		if tl.car_state() == "green": continue
		if absf(f.dot(tl.road_dir())) < 0.7: continue
		var rel: Vector3 = tl.center() - position
		var along := rel.dot(f) - 4.8 - half_len; var lat := absf(rel.dot(r))
		if lat < 6.0 and along > -0.5 and along < 16.0 and (tl.car_state() == "red" or along > 3.0):
			if along < gap: gap = along; blocked_by = "light"
	# player in the lane ahead
	var pl = get_tree().current_scene.get("player")
	if pl:
		var rel2: Vector3 = (pl as Node3D).global_position - position
		var a2 := rel2.dot(f) - half_len - 1.2
		if absf(rel2.dot(r)) < 1.8 and a2 > -half_len - 1.0 and a2 < 12.0 and a2 < gap: gap = maxf(a2, 0.0); blocked_by = "player"
	# vehicle ahead
	for v in all:
		if v == self: continue
		var rel3: Vector3 = v.position - position
		var a3: float = rel3.dot(f) - half_len - v.half_len - 2.0
		if absf(rel3.dot(r)) < 1.5 and rel3.dot(f) > 0.0 and a3 < 14.0 and a3 < gap and f.dot(v.fwd()) > 0.3: gap = maxf(a3, 0.0); blocked_by = "car"
	# v25 crossing paths (intersections / merging lanes): sample my lane ahead; any other vehicle whose body sits on it
	# is an obstacle. Mutual conflicts: the one closer to the conflict point goes, the other yields -> never collide.
	var cg := _conflict_gap()
	if cg < gap: gap = cg; blocked_by = "cross"
	# bus stops: hold until the scheduled departure, then drive to the next stop
	if is_bus and arr.size() == stops.size():
		if hold_stop >= 0:
			gap = 0.0; blocked_by = "stop"
			if _past(phase(WorldState.minutes), float(arr[hold_stop]) + dwell_min): _close_doors(); hold_stop = -1
		else:
			for i in stops.size():
				var st: Dictionary = stops[i]
				if st.id == last_stop: continue
				var ds := fposmod(st.s - s, length)
				if ds < gap: gap = ds; blocked_by = "stop"
				if ds < 0.15 and speed < 0.3: _arrive(st.id, i)
	var target := clampf(sqrt(maxf(2.0 * accel * maxf(gap - 0.1, 0.0), 0.0)), 0.0, max_speed)
	var want := clampf((target - speed) * 1.5, -accel * 2.2, accel)
	acc = move_toward(acc, want, 6.0 * dt)                    # jerk limit -> soft starts and stops
	speed = clampf(speed + acc * dt, 0.0, max_speed)
	if gap < 0.05 or (gap < 0.6 and speed < 0.4): speed = 0.0; acc = minf(acc, 0.0) * 0.5
	s = fposmod(s + speed * dt, length)
	_place()
	_sway(dt)
	_push_player(pl)

const LOOK := 16.0
## crossing / merging traffic. (1) a body already standing on my lane ahead is always an obstacle.
## (2) predicted conflict: first point where my next LOOK metres meet its next LOOK metres; the vehicle that reaches
## it later (tie: higher instance id) stops before it. Same-direction followers are handled by the follow rule.
func _conflict_gap() -> float:
	var best := 99.0
	var mine: Array = []
	var t := 0.0
	while t <= LOOK: mine.append(pos_at(s + half_len + t)); t += 1.0
	for v in all:
		if v == self: continue
		if v.position.distance_squared_to(position) > (LOOK * 2.0 + 6.0) * (LOOK * 2.0 + 6.0): continue
		var vf: Vector3 = v.fwd()
		if fwd().dot(vf) > 0.7 and absf((v.position - position).dot(Vector3(fwd().z, 0, -fwd().x))) < 2.0: continue
		var d := _first_hit(v.position, v.half_len, vf)
		if d < 98.0:
			# both bodies on each other's lane (inside a junction): lower instance id clears it first, no deadlock
			if d > 2.5 and v._first_hit(position, half_len, fwd()) < 98.0 and get_instance_id() < v.get_instance_id(): continue
			best = minf(best, maxf(d - 1.5, 0.0)); continue
		if v.length <= 0.0: continue
		var ti := -1; var tj := -1
		for a in mine.size():
			var tt := 0.0; var j2 := 0
			while tt <= LOOK:
				if (mine[a] as Vector3).distance_squared_to(v.pos_at(v.s + v.half_len + tt)) < 4.8:
					ti = a; tj = j2; break
				tt += 1.0; j2 += 1
			if ti >= 0: break
		if ti < 0: continue
		# arrival times (s) at the conflict point
		var my_t := float(ti) / maxf(speed, 1.0); var ot := float(tj) / maxf(v.speed, 1.0)
		var yield_: bool = ot < my_t - 0.2 or (absf(ot - my_t) <= 0.2 and get_instance_id() > v.get_instance_id())
		if v.blocked_by == "cross" and v.speed < 0.2 and not (ot < 0.5): yield_ = false   # it is already yielding to me
		if yield_: best = minf(best, maxf(float(ti) - 2.0, 0.0))
	return best

## distance along my lane to the first sample (every 1 m, up to LOOK) that touches a body at p (half length hl, dir f)
func _first_hit(p: Vector3, hl: float, f: Vector3) -> float:
	var r := Vector3(f.z, 0, -f.x)
	var t := 0.0
	while t <= LOOK:
		var q := pos_at(fposmod(s + half_len + t, length)) - p
		if absf(q.dot(f)) < hl + 0.6 and absf(q.dot(r)) < 1.6: return t
		t += 1.0
	return 99.0

## body on springs: pitch from acceleration, roll from turning, a small bob at speed
func _sway(dt: float) -> void:
	if body == null: return
	var yr := wrapf(rotation.y - _yaw_prev, -PI, PI) / maxf(dt, 0.001); _yaw_prev = rotation.y
	var k := 0.6 if is_bus else 1.0
	_pitch = lerpf(_pitch, clampf(-acc * 0.012 * k, -0.06, 0.06), 1.0 - exp(-6.0 * dt))
	_roll = lerpf(_roll, clampf(yr * speed * 0.012 * k, -0.07, 0.07), 1.0 - exp(-5.0 * dt))
	body.rotation = Vector3(_pitch, 0, _roll)
	body.position.y = sin(Time.get_ticks_msec() * 0.011 + get_instance_id()) * 0.008 * minf(speed, 3.0)

## solid body: the player cannot walk through a vehicle; a moving one shoves them aside
func _push_player(pl) -> void:
	if pl == null: return
	var p: Vector3 = (pl as Node3D).global_position
	var lp := global_transform.affine_inverse() * p
	var hw := (1.3 if is_bus else 0.95) + 0.25; var hl := half_len + 0.25
	if absf(lp.x) < hw and absf(lp.z) < hl:
		var px := hw - absf(lp.x); var pz := hl - absf(lp.z)
		if px < pz: lp.x = signf(lp.x if lp.x != 0.0 else 1.0) * hw
		else: lp.z = signf(lp.z) * hl
		var out := global_transform * lp; out.y = p.y
		(pl as Node3D).global_position = out
		if speed > 0.5 and pl.has_method("bumped"): pl.bumped(fwd() * speed)

func _arrive(id: String, idx := -1) -> void:
	at_stop = id; last_stop = id; dwell = 9.0; speed = 0.0; acc = 0.0
	if idx < 0:
		for i in stops.size(): if stops[i].id == id: idx = i
	hold_stop = idx
	for d in doors: create_tween().tween_property(d, "position:z", d.get_meta("z0") + 0.75, 0.6)
	if board: board.enabled = true

func _close_doors() -> void:
	if at_stop == "": return
	at_stop = ""
	for d in doors: create_tween().tween_property(d, "position:z", d.get_meta("z0"), 0.6)
	if board: board.enabled = false

## v32: polished procedural models via CarKit (one merged mesh, 4 materials) + blob shadow. Same node names
## ("Body", door nodes, route Label3D), same footprint (car 1.8 x 4.2, bus 2.5 x 11), same half_len.
func _build_mesh() -> void:
	var k := CarKit.new()
	body = Node3D.new(); body.name = "Body"; add_child(body)
	if is_bus:
		half_len = 5.5
		k.bus()
		CarKit.add_shadow(self, Vector2(3.0, 11.8))
		var lbl := Label3D.new(); Lines.set_sign(lbl, "1  Maple St - Market - Park", "1  Akçaağaç Sk. - Çarşı - Park"); lbl.font = load("res://fonts/Nunito.ttf"); lbl.font_size = 40
		lbl.pixel_size = 0.005; lbl.modulate = Color(1.0, 0.85, 0.4); lbl.outline_size = 0; lbl.position = Vector3(0, 2.75, 5.57); body.add_child(lbl)
		# doors on the right (curb) side, local -X; they slide along Z when the bus stops
		for dz in [3.6, -1.0]:
			var dk := MeshKit.new()
			dk.box(Vector3(0.06, 2.2, 1.1), Vector3(0, 1.35, 0), Color(0.10, 0.12, 0.15))
			dk.box(Vector3(0.07, 0.08, 1.12), Vector3(0, 2.45, 0), DARK); dk.box(Vector3(0.07, 0.08, 1.12), Vector3(0, 0.27, 0), DARK)
			dk.box(Vector3(0.07, 2.2, 0.05), Vector3(0, 1.35, 0), DARK)
			dk.box(Vector3(0.08, 0.04, 0.5), Vector3(-0.01, 1.3, 0.25), Color(0.8, 0.81, 0.83))
			var dn := Node3D.new(); dn.position = Vector3(-1.27, 0, dz); dn.set_meta("z0", dz); body.add_child(dn); dk.commit(dn); doors.append(dn)
	else:
		k.car(color, -0.2, int(absf(color.r * 7.0 + color.g * 13.0 + color.b * 3.0)) % 2)
		CarKit.add_shadow(self, Vector2(2.3, 4.9))
	k.commit(body)
