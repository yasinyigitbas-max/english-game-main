extends Node
## v33town (Yasin 17:33): one continuous over-the-shoulder follow camera for the whole house (God of War style).
## Low and close, behind the hero and off one shoulder, smoothed in house space, so a door is just this camera following
## (the floating origin shift of House._swap is applied to its state: no cut). It drives whichever room camera is current
## (the room cameras are only carriers now; their own placement is overwritten every frame, process_priority 900).
## Blocked view: 1) push in closer (0.75 / 0.55 / 0.4 of the distance, min 0.9 m), 2) swap to the other shoulder,
## 3) last resort: stay and let the rooms' wall fade fade the wall. Only real walls block (thin, tall, visible boxes of
## the house rooms + group cam_occluder); never the ground, the outside box, props, trees or lamps.
## Story moments / objective pans (room cam_shot, Life.guide_to temp cameras): the same camera moves smoothly behind the
## hero and frames BOTH the hero and the shot target. Movement stays camera-relative: the rooms' stick yaw follows it.
const House := preload("res://scripts/core/house.gd")
const DIST := 2.7           # m behind the hero
const HEIGHT := 1.72        # camera height above the feet
const LOOK_H := 1.3         # look-at height
const LOOK_AHEAD := 1.1     # look a little ahead of the hero
const SHOULDER := 0.42      # m to the side
const FOV := 62.0           # wide enough on a phone to spot interactables
const MIN_D := 1.3
const PULLS := [1.0, 0.8, 0.65, 0.5]
const TAU_POS := 0.22
const TAU_LOOK := 0.14
const FOLLOW := 1.3         # rad/s auto-turn behind a walking hero
const STICK := 1.8          # rad/s camera stick / drag
var enabled := true
var yaw := 0.0
var side := 1.0             # +1 right shoulder, -1 left
var side_s := 1.0
var k := 1.0
var pos := Vector3.INF      # smoothed camera position (world)
var look := Vector3.INF     # smoothed look point (world)
var _room: Node = null
var _manual := 0.0
var _next := 0.0
var _last_hero := Vector3.INF
var _walls := {}            # room -> Array[AABB] (room-local)
var _set_yaw := INF         # yaw last written to a CameraRig (a different value = the player rotated it)
var _out_since := -1.0
var _aside := false
var _room_house := false
var _wrote_cy := INF        # cam_yaw last written into a house room
var dbg := ""               # QA: which branch ran last frame
var _guide_on := false      # an objective pan is framing hero + target right now (QA reads it)

static func ensure(tree: SceneTree) -> Node:
	var n := tree.root.get_node_or_null("ShoulderCam")
	if n == null:
		n = load("res://scripts/core/shoulder_cam.gd").new(); n.name = "ShoulderCam"; tree.root.add_child(n)
	return n

func _ready() -> void:
	process_priority = 900; process_mode = Node.PROCESS_MODE_ALWAYS

## v34 (blue): start fresh behind the hero next frame (WorldTrip arrival at a destination door: no swoop across town)
func snap() -> void:
	pos = Vector3.INF; look = Vector3.INF; _set_yaw = INF; _last_hero = Vector3.INF; _wrote_cy = INF

## House._swap: the whole house moved by d (floating origin)
func shift(d: Vector3) -> void:
	if pos != Vector3.INF: pos += d
	if look != Vector3.INF: look += d
	if _last_hero != Vector3.INF: _last_hero += d
	_apply_now.call_deferred()

## fix33: Godot 4.7 gl_compatibility keeps RENDERING a stale camera after the current camera was reparented / swapped
## (OwLink lends ONE room camera to each room; rooms and places toggle `current`): get_camera_3d() named the room camera
## while the screen showed the street CameraRig (top-down from outside: day-2 couch, bedtime polaroids, D7 wake).
## Re-attaching the current camera (clear + make current in the same frame: nothing else renders in between) whenever
## the current camera / scene changes, and every 0.5 s as a safety net, keeps the render camera = the current camera.
var _rc_cam: Camera3D = null
var _rc_scene: Node = null
var _rc_t := 0.0
var _rc_kick := 0
func _reattach(dt: float) -> void:
	var c := get_viewport().get_camera_3d()
	var sc := get_tree().current_scene
	_rc_t -= dt
	if c != _rc_cam or sc != _rc_scene: _rc_cam = c; _rc_scene = sc; _rc_kick = 3
	if c == null or (_rc_kick <= 0 and _rc_t > 0.0): return
	_rc_t = 0.5; _rc_kick -= 1
	c.clear_current(false); c.make_current()

func _process(dt: float) -> void:
	_reattach(get_process_delta_time())
	var sc := get_tree().current_scene
	var room := sc != null and House.is_room(String(sc.scene_file_path))
	var rc = sc.get("cam") if sc else null
	# house rooms + every walkable scene on the shared CameraRig (street, café, shop, work / school); not the hospital etc.
	if not enabled or sc == null or (room and House.dormant(sc)) or not (room or rc is CameraRig):
		dbg = "off"; pos = Vector3.INF; look = Vector3.INF; _room = null; return
	var hero = sc.get("player") if sc.get("player") is Node3D else sc.get("hero")
	var face = sc.get("hero") if sc.get("hero") is Node3D else hero
	if not (hero is Node3D) or not is_instance_valid(hero) or not (rc is Camera3D) or not is_instance_valid(rc): dbg = "nohero"; return
	if String(sc.get("mode")) == "menu": dbg = "menu"; pos = Vector3.INF; return
	if get_tree().paused: dt = 0.0
	if rc.get("avoid") != null: rc.set("avoid", false)   # the rig's own CamAvoid: this camera handles walls
	var ca = sc.get("cam_avoid")
	if ca != null and ca.get("enabled") != null: ca.enabled = false   # bedroom / living CamAvoid: same
	# objective pans (Life.guide_to: temp camera marked guide_cam, or a cam_shot marked guide) frame hero + target with
	# this camera; any OTHER scripted camera (cutscenes, intro pans, cam_override, story cam_shots, phone take-over) is
	# left untouched: we only track it so the hand-back afterwards eases from where it ended (no pop)
	var tgt := Vector3.INF
	var vc := get_viewport().get_camera_3d()
	var scripted := false
	if vc and vc != rc and not (vc.get_viewport() is SubViewport):
		if vc.has_meta("guide_cam"): tgt = vc.get_meta("guide_at", _aim_point(vc)); rc.current = true
		else: scripted = true
	var shot = sc.get("cam_shot")
	if shot is Dictionary and not (shot as Dictionary).is_empty() and shot.has("at"):
		if bool(shot.get("guide", false)): tgt = (sc as Node3D).to_global(shot.at) if sc is Node3D else shot.at   # v34 (blue): cam_shot values are room-local (rooms sit off the origin in the open world)
		else: scripted = true
	if sc.get("cam_override") == true or (rc is CameraRig and not (rc as CameraRig).controlled): scripted = true
	_guide_on = tgt != Vector3.INF and not scripted
	if scripted:
		var oc: Camera3D = vc if vc else rc
		if room or _indoors(hero.global_position): _unclip_scripted(oc, sc, hero)
		if oc.has_meta("sc_fov0") and dt > 0.0: oc.fov = lerpf(oc.fov, float(oc.get_meta("sc_fov0")), 1.0 - exp(-dt / 0.3))   # story shots keep their own fov
		pos = oc.global_position; look = oc.global_position - oc.global_transform.basis.z * 3.0; _aside = true
		dbg = "scripted:%s ov=%s shot=%s" % [oc.name, str(sc.get("cam_override")), str(shot is Dictionary and not (shot as Dictionary).is_empty())]
		return
	dbg = "follow"
	if _aside:
		_aside = false
		var ry: float = (rc as Node3D).global_rotation.y
		if pos != Vector3.INF: yaw = ry   # continue from the scripted view's heading
	if rc is CameraRig and _set_yaw != INF and absf(wrapf((rc as CameraRig).yaw - _set_yaw, -PI, PI)) > 0.0005:
		yaw = (rc as CameraRig).yaw; _manual = 1.5   # the player dragged / turned the rig: follow that
	var h: Vector3 = (hero as Node3D).global_position
	var chest := h + Vector3(0, LOOK_H, 0)
	if _room != sc:
		# a house door keeps the view (House._swap shifted it); any other scene change starts fresh behind the hero
		if not (room and _room_house): pos = Vector3.INF; look = Vector3.INF; _set_yaw = INF
		_room = sc; _room_house = room; _next = 0.0
	if pos == Vector3.INF:   # fix33: a fresh start (boot / Continue / trip) never starts inside or behind a wall
		_boxes = _blockers(sc, chest); _next = 0.0
		yaw = _clear_yaw(h, chest, (face as Node3D).global_rotation.y + PI, _boxes)
	# yaw: camera stick, else ease behind a walking hero, or behind the hero looking at the story target
	var cs = sc.get("cam_stick")
	if cs is Vector2 and absf(cs.x) > 0.1: yaw -= cs.x * STICK * dt; _manual = 1.5
	elif _wrote_cy != INF and "cam_yaw" in sc and not (rc is CameraRig) and absf(wrapf(float(sc.cam_yaw) - _wrote_cy, -PI, PI)) > 0.0005:
		yaw = float(sc.cam_yaw); _manual = 1.5   # v34: the room's mouse drag turned its cam_yaw: follow it (free, no ±1.3 clamp)
	_manual = maxf(0.0, _manual - dt)
	if pos == Vector3.INF: _trail.clear(); _tp = Vector3.INF
	if _trail.is_empty() or (_trail[-1] as Vector3).distance_to(h) > 0.15:
		_trail.append(h)
		if _trail.size() > 40: _trail.pop_front()
	var moving := _last_hero != Vector3.INF and dt > 0.0 and Vector2(h.x - _last_hero.x, h.z - _last_hero.z).length() / dt > 0.25
	_last_hero = h
	if tgt != Vector3.INF and Vector2(tgt.x - h.x, tgt.z - h.z).length() > 0.4:
		var away := Vector3(h.x - tgt.x, 0, h.z - tgt.z).normalized()
		yaw = lerp_angle(yaw, atan2(away.x, away.z), 1.0 - exp(-dt * 2.5))
	elif moving and _manual <= 0.0:
		var want: float = (face as Node3D).global_rotation.y + PI
		var dy := wrapf(want - yaw, -PI, PI)
		if absf(dy) > 0.2: yaw += clampf(dy, -FOLLOW * dt, FOLLOW * dt) * clampf((absf(dy) - 0.2) / 0.5, 0.0, 1.0)
	yaw = wrapf(yaw, -PI, PI)
	# occlusion: pull in, then the other shoulder (checked 10x per second)
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next:
		_next = now + 0.1
		var boxes := _blockers(sc, chest); _boxes = boxes
		var best := [side, k]; var found := false
		for sd in [side, -side]:
			for p in PULLS:
				if DIST * p < MIN_D: continue
				if not _blocked(_spot(h, yaw, sd, p), chest, boxes): best = [sd, p]; found = true; break
			if found: break
		_tp = Vector3.INF if found or tgt != Vector3.INF else _trail_spot(h, chest, boxes)
		if found:
			# hysteresis: closing in / swapping happens at once, easing back out only after 0.35 s of clear view
			if best[0] != side or best[1] < k - 0.01: side = best[0]; k = best[1]; _out_since = -1.0
			elif best[1] > k + 0.01:
				if _out_since < 0.0: _out_since = now
				elif now - _out_since >= 0.35: k = best[1]; _out_since = -1.0
			else: _out_since = -1.0
		else:
			k = PULLS[-1]   # nothing clear: close in on the hero, the room wall fade covers the rest
			# fix33: but never INSIDE a wall (hero backed up against it = the solid grey / pale-green screen): swing to
			# the nearest clear heading instead (unless the player is steering the camera)
			if _tp == Vector3.INF and _in_wall(_spot(h, yaw, side, k), boxes) and _manual <= 0.0 and tgt == Vector3.INF: _swing = _clear_yaw(h, chest, yaw, boxes)
	if _swing != INF:
		yaw = lerp_angle(yaw, _swing, 1.0 - exp(-dt * 4.0)) if dt > 0.0 else yaw
		if absf(wrapf(_swing - yaw, -PI, PI)) < 0.05 or _manual > 0.0: _swing = INF
	side_s = lerpf(side_s, side, 1.0 - exp(-dt / 0.25))
	var want_pos := _spot(h, yaw, side_s, k)
	if tgt != Vector3.INF: want_pos = _frame_both(h, chest, tgt, yaw, side_s, cam_fov(rc))
	if _tp != Vector3.INF and tgt == Vector3.INF:   # fix33: blocked everywhere (a door just passed, a corner): follow the hero's own path
		want_pos = _tp
		var ty := atan2(_tp.x - h.x, _tp.z - h.z)
		if _manual <= 0.0 and dt > 0.0: yaw = lerp_angle(yaw, ty, 1.0 - exp(-dt * 5.0))
	want_pos = _out_of_walls(want_pos, chest, _boxes)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var want_look := chest + fwd * LOOK_AHEAD + Vector3(cos(yaw), 0, -sin(yaw)) * side_s * SHOULDER * 0.5
	if tgt != Vector3.INF: want_look = chest.lerp(tgt, 0.5)
	if pos == Vector3.INF: pos = want_pos; look = want_look
	pos = pos.lerp(want_pos, 1.0 - exp(-dt / TAU_POS)) if dt > 0.0 else pos
	if _in_wall(pos, _boxes): pos = want_pos   # the smoothing path itself must not cross through a wall slab
	look = look.lerp(want_look, 1.0 - exp(-dt / TAU_LOOK)) if dt > 0.0 else look
	# the room's movement stays relative to this camera
	if "cam_yaw" in sc and not (rc is CameraRig): sc.set("cam_yaw", yaw); _wrote_cy = yaw
	if rc is CameraRig: (rc as CameraRig).yaw = yaw; _set_yaw = yaw
	var cam := get_viewport().get_camera_3d() as Camera3D
	if cam == null or cam != rc: cam = rc
	if not cam.has_meta("sc_fov0"): cam.set_meta("sc_fov0", cam.fov)
	var want_fov := _guide_fov if tgt != Vector3.INF else FOV
	cam.fov = lerpf(cam.fov, want_fov, 1.0 - exp(-dt / 0.3)) if dt > 0.0 else cam.fov
	if pos.distance_to(look) > 0.05: cam.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)

var _swing := INF
var _trail: Array = []      # fix33: the hero's recent path (world, newest last, 0.15 m steps)
var _tp := Vector3.INF      # fix33: camera spot on that path when every off-shoulder spot is blocked
## a camera spot on the hero's own recent path, MIN_D..DIST behind him along it, with a clear line to the chest
## (the path went through the door the hero just used, so the camera follows him through it instead of jamming on the wall)
func _trail_spot(h: Vector3, chest: Vector3, boxes: Array) -> Vector3:
	var acc := 0.0; var prev := h
	for i in range(_trail.size() - 1, -1, -1):
		var q: Vector3 = _trail[i]
		acc += Vector2(q.x - prev.x, q.z - prev.z).length(); prev = q
		if acc < MIN_D: continue
		if acc > DIST * 1.15: break
		var c := Vector3(q.x, h.y + HEIGHT, q.z)
		if not _blocked(c, chest, boxes): return c
	return Vector3.INF
## fix33: the first heading (from `y`, then alternating ±0.6 rad steps, then the opposite side) with a clear view at any pull
func _clear_yaw(h: Vector3, chest: Vector3, y: float, boxes: Array) -> float:
	for dy in [0.0, 0.6, -0.6, 1.2, -1.2, 1.8, -1.8, 2.4, -2.4, PI]:
		for sd in [side, -side]:
			for p in PULLS:
				if DIST * p < MIN_D: continue
				if not _blocked(_spot(h, y + dy, sd, p), chest, boxes):
					side = sd; side_s = sd; k = p
					return wrapf(y + dy, -PI, PI)
	return y

static func _in_wall(p: Vector3, boxes: Array) -> bool:
	for abv in boxes: if (abv as AABB).grow(0.06).has_point(p): return true
	return false

## fix33: a camera point inside a wall slab is moved out of it, away from the hero (the wall between then fades)
func _out_of_walls(p: Vector3, chest: Vector3, boxes: Array) -> Vector3:
	if not _in_wall(p, boxes): return p
	var d := Vector3(p.x - chest.x, 0, p.z - chest.z)
	d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)
	for i in 30:
		var q := p + d * (0.04 * (i + 1))
		if not _in_wall(q, boxes): return q
	return p

## fix33: a scripted (story) camera is never left inside a wall or above the ceiling: pushed along its view into the room
func _unclip_scripted(oc: Camera3D, sc: Node, hero) -> void:
	if not (hero is Node3D) or oc.get_viewport() is SubViewport: return
	var h: Vector3 = (hero as Node3D).global_position
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _next: _next = now + 0.1; _boxes = _blockers(sc, h + Vector3(0, LOOK_H, 0))
	var boxes := _boxes
	var p := oc.global_position
	var f := -oc.global_transform.basis.z
	if House.is_room(String(sc.scene_file_path)) and p.y > h.y + 2.45: p.y = h.y + 2.45
	if _in_wall(p, boxes):
		for i in 40:
			var q := p + f * (0.05 * (i + 1))
			if not _in_wall(q, boxes): p = q; break
	if not p.is_equal_approx(oc.global_position): oc.global_position = p

func _spot(h: Vector3, y: float, sd: float, p: float) -> Vector3:
	var back := Vector3(sin(y), 0, cos(y)); var right := Vector3(cos(y), 0, -sin(y))
	return h + Vector3(0, HEIGHT, 0) + back * DIST * p + right * sd * SHOULDER * clampf(p + 0.2, 0.5, 1.0)

func _aim_point(c: Camera3D) -> Vector3:
	var o := c.global_position; var f := -c.global_transform.basis.z
	if f.y < -0.05:
		var t := (o.y - 0.9) / -f.y
		if t > 0.0 and t < 12.0: return o + f * t
	return o + f * 3.0

## real walls only: thin and tall visible boxes of the house rooms (room-local cache) + group cam_occluder
func _blockers(sc: Node, chest: Vector3) -> Array:
	var out := []
	var rooms: Array = get_tree().root.get_children()
	if World.inst and is_instance_valid(World.inst) and World.inst.get("places") is Dictionary:   # black 3.2: open world: the house rooms live under World (not root children), so their walls never blocked the street camera (front-door exit: camera inside the hall wall)
		for r2 in (World.inst.places as Dictionary).values(): if is_instance_valid(r2) and not rooms.has(r2): rooms.append(r2)
	for r in rooms:
		if not House.is_room(String(r.scene_file_path)) or r.has_meta("house_dead"): continue
		if not _walls.has(r.get_instance_id()): _walls[r.get_instance_id()] = _scan(r)
		for e in _walls[r.get_instance_id()]:
			var g: GeometryInstance3D = e[0]
			if not is_instance_valid(g) or not (g.is_visible_in_tree() or g.has_meta("wf_a")): continue   # a faded wall still blocks (no fade <-> move loop)
			var ab: AABB = g.global_transform * g.get_aabb()
			if ab.get_center().distance_to(chest) < 8.0: out.append(ab)
	for n in get_tree().get_nodes_in_group("cam_occluder"):
		if n is VisualInstance3D and ((n as VisualInstance3D).is_visible_in_tree() or n.has_meta("wf_a")):
			var ab2: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
			if _is_wall(ab2) and ab2.get_center().distance_to(chest) < 8.0: out.append(ab2)
	for n in get_tree().get_nodes_in_group("fade"):   # street buildings (one merged mesh each): their outer walls block
		if n is VisualInstance3D and (n as Node3D).is_inside_tree():
			var ab3: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
			if ab3.size.x < 40.0 and ab3.size.z < 40.0 and ab3.size.y >= 1.5 and ab3.get_center().distance_to(chest) < 25.0: out.append(ab3)
	return out

func _scan(r: Node) -> Array:
	var o := []
	for g in r.find_children("*", "MeshInstance3D", true, false):
		if g.name == "WHVoid" or g.has_meta("wh_twin") or (g as MeshInstance3D).mesh == null: continue
		if not ((g as MeshInstance3D).mesh is BoxMesh): continue
		var ab: AABB = (g as MeshInstance3D).global_transform * (g as MeshInstance3D).get_aabb()
		if _is_wall(ab): o.append([g])
	return o

static func _is_wall(ab: AABB) -> bool:
	var s := ab.size
	if s.x >= 20.0 or s.z >= 20.0 or s.y >= 6.0: return false     # ground, the outside box
	if s.y < 1.0 or ab.end.y < 1.6: return false                  # low parts, furniture
	return minf(s.x, s.z) <= 0.35 and maxf(s.x, s.z) >= 0.5        # thin + long = a wall

static func _blocked(cp: Vector3, target: Vector3, boxes: Array) -> bool:
	for abv in boxes:
		var ab: AABB = abv
		var gb: AABB = ab.grow(0.12)
		if gb.has_point(cp): return true
		var d := cp - target; var l := d.length()
		if l < 0.1: continue
		if gb.intersects_segment(cp, target + d / l * minf(0.25, l)) != null: return true
	return false

func cam_fov(c: Camera3D) -> float: return FOV if c == null else maxf(c.fov, 40.0)

## objective pan: the hero's chest AND the target both sit inside the view (80 % of the half vertical fov).
## v34 (blue): the pull-back never leaves the room: each candidate (behind, then 35° / 70° to either side, which needs less
## distance) steps back + up only while the line to the hero stays clear of real walls and under the ceiling; the first
## candidate that frames both wins. If none does, the best one (most of the frame) is used and the fov opens up just enough
## (max 84°) instead of backing through a wall. _guide_fov carries that fov to the camera.
var _guide_fov := FOV
var _boxes: Array = []
func _frame_both(h: Vector3, chest: Vector3, tgt: Vector3, y: float, sd: float, fov: float) -> Vector3:
	var half := deg_to_rad(maxf(fov, FOV)) * 0.5 * 0.8
	var mid := chest.lerp(tgt, 0.5)
	var top := h.y + (2.45 if _indoors(h) else 6.0)
	var best := Vector3.INF; var best_need := INF
	for dy in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var yy: float = y + dy
		var p := _spot(h, yy, sd, 1.0)
		if _blocked(p, chest, _boxes): p = _spot(h, yy, sd, 0.55)
		for i in 13:
			var need := _need_half(p, mid, chest, tgt)
			if need <= half: _guide_fov = maxf(fov, FOV); return p
			if need < best_need: best_need = need; best = p
			var q := p + Vector3(sin(yy), 0, cos(yy)) * 0.5 + Vector3(0, 0.25, 0)
			q.y = minf(q.y, top)
			if _blocked(q, chest, _boxes) or _blocked(q, tgt, _boxes): break   # next step would be behind a wall
			p = q
	_guide_fov = clampf(rad_to_deg(best_need / 0.8) * 2.0 + 2.0, FOV, 84.0)
	return best if best != Vector3.INF else _spot(h, y, sd, 1.0)

func _need_half(p: Vector3, mid: Vector3, a: Vector3, b: Vector3) -> float:
	var f := (mid - p).normalized()
	return maxf(f.angle_to((a - p).normalized()), f.angle_to((b - p).normalized()))

## inside a house room or a world place (low ceiling)
func _indoors(h: Vector3) -> bool:
	if _room_house: return true
	for pl in get_tree().get_nodes_in_group("world_places"):
		if pl.has_method("is_inside_place") and pl.is_inside_place(h): return true
	return false

## v34 (blue): the rooms' own drag / stick code clamps their cam_yaw to ±1.3 rad (the old fixed room camera); with this
## one camera the yaw is free (main.gd / livingroom.gd ask this before clamping)
static func free_yaw(tree: SceneTree) -> bool:
	var n := tree.root.get_node_or_null("ShoulderCam")
	return n != null and bool(n.get("enabled"))

## House._swap shifted the house: put the new current room camera on our view in the same deferred flush (no pop frame)
func _apply_now() -> void:
	var c := get_viewport().get_camera_3d()
	if c and pos != Vector3.INF and look != Vector3.INF and pos.distance_to(look) > 0.05:
		c.global_transform = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos); c.fov = lerpf(c.fov, FOV, 1.0)
