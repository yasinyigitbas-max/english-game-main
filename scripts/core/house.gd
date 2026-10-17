extends RefCounted
## v32wh: whole-house mode. The bedroom (main.tscn), bathroom and living room are all instanced at once, laid out as
## one house so their real doors line up (the door coordinates of the three rooms already agree):
##   living room at the house origin, bedroom 6 m north (its south door x 1.8 = the living room's bedroom door),
##   bathroom at (5.95, -4.75) (its south door = the living room's bathroom door, its west door = the bedroom's east door).
## The room the player is in is the "live" room: it is current_scene, sits at the world origin (all room code uses
## room-local world coordinates) and runs exactly the v32 code. The two other rooms are "shells": geometry only
## (their _build_room / decor), no environment, no hero/camera/UI/story, processing disabled, lights and
## shadow casting off, mirror viewports stopped. v33town: walking through a door no longer frees / rebuilds anything:
## the room left falls asleep with all its state (see _swap below).
const OFS := {"res://livingroom.tscn": Vector3.ZERO, "res://main.tscn": Vector3(0, 0, -6.0), "res://bathroom.tscn": Vector3(5.95, 0, -4.75)}
const ZSPAN := {"res://livingroom.tscn": Vector2(-3.0, 3.0), "res://main.tscn": Vector2(-3.0, 3.0), "res://bathroom.tscn": Vector2(-1.75, 1.75)}
const SHELL := "house_shell"
static var swapping := false

static func is_room(path: String) -> bool: return OFS.has(path)
static func is_shell(n: Node) -> bool: return n.has_meta(SHELL)

## room script, top of _ready: build the shell and stop (true) or continue with the normal live _ready (false)
static func shell_ready(room: Node, build: Callable) -> bool:
	if not is_shell(room): return false
	room.set_meta("wh_built", true); build.call(); _cheap(room, true); return true

## room script, end of the live _ready: make sure the two other rooms exist as shells around this one
static func live_ready(room: Node) -> void:
	if not is_room(room.scene_file_path): return
	room.set_meta(ONCE, true)   # v33town: from now on this instance is never rebuilt, only put to sleep / woken
	if SHOULDER_CAM: load("res://scripts/core/shoulder_cam.gd").ensure(room.get_tree())
	if OwLink.active(): return   # open world: rooms are World-built at fixed positions; no black void, no shells, no floating origin
	_dark_outside(room)
	if not room.has_meta("wh_hooked"):
		room.set_meta("wh_hooked", true); room.tree_exiting.connect(func(): _on_live_exit(room))
	(func(): _ensure(room)).call_deferred()

## v33town: ONE persistent house. Every room is instanced once and never freed or rebuilt while the player is in the house:
##   shell   = never entered yet (geometry only, as in v32wh)
##   live    = current_scene, at the world origin, runs its code
##   dormant = was live before; processing / lights / UI / camera / hero off, every node and its state kept as it was
## A door is just walking: the room left falls asleep, the house shifts so the room entered sits at the origin (floating
## origin, all room code uses room-local == world coordinates), the room entered wakes (or a shell turns live once), its
## hero takes over exactly where the other one stood and walks on through the door, and the camera blends over.
const ONCE := "wh_live_once"
const DORMANT := "wh_dormant"
const ROOM_NAME := {"res://livingroom.tscn": "livingroom", "res://main.tscn": "bedroom", "res://bathroom.tscn": "bathroom"}
const WALK_IN := 1.7   # m/s, the bedroom walk clip speed
const SHOULDER_CAM := true   # v33town (Yasin 17:33): one continuous over-the-shoulder camera (scripts/core/shoulder_cam.gd)
static func again(room: Node) -> bool: return room.has_meta(ONCE)
static func dormant(room: Node) -> bool: return is_instance_valid(room) and room.has_meta(DORMANT)

## a door between two house rooms: walk through it in the same scene instead of change_scene_to_file(path)
static func go(from: Node, path: String) -> void:
	var tree := from.get_tree()
	var target := _find(tree, path)
	if target == null or not is_room(from.scene_file_path) or tree.current_scene != from:
		tree.change_scene_to_file(path); return
	(func(): _swap(from, target)).call_deferred()

static func _swap(from: Node, target: Node) -> void:
	if not is_instance_valid(from) or not is_instance_valid(target): return
	var tree := target.get_tree()
	if tree.current_scene != from: return
	# hand-over point: where the camera and the hero of the room left are right now
	var vc := from.get_viewport().get_camera_3d()
	var cxf: Transform3D = vc.global_transform if vc else Transform3D.IDENTITY
	var cfov: float = vc.fov if vc else 42.0
	var h = from.get("hero")
	var hp := Vector3.INF; var hy := 0.0
	if h is Node3D and is_instance_valid(h): hp = (h as Node3D).global_position; hy = (h as Node3D).global_rotation.y
	_sleep(from)
	var base: Vector3 = target.position
	for s in _rooms(tree): s.position -= base   # floating origin: the room entered moves to (0,0,0), the rest with it
	var sc_cam := tree.root.get_node_or_null("ShoulderCam")
	if sc_cam: sc_cam.shift(-base)   # the shoulder camera keeps following in house space: no cut at the door
	cxf.origin -= base
	if hp != Vector3.INF: hp -= base
	target.position = Vector3.ZERO
	tree.current_scene = target
	_ensure(target)
	if again(target):
		_wake(target)
		if target.has_method("_wh_resume"): target.call("_wh_resume")
	else:
		target.remove_meta(SHELL); _cheap(target, false)
		target.call("_live_ready")
	target.set_meta(ONCE, true)
	if not (SHOULDER_CAM and sc_cam): _blend_cam(target, cxf, cfov)
	var sp: Array = target.call("_wh_spawn", String(ROOM_NAME.get(from.scene_file_path, ""))) if target.has_method("_wh_spawn") else []
	if hp != Vector3.INF and sp.size() == 2: _walk_in(target, hp, hy, sp[0], sp[1])

## the room left: everything stays exactly as it is, it only stops running and drawing its own UI / camera / lights
static func _sleep(r: Node) -> void:
	r.set_meta(DORMANT, true)
	if r.has_method("_wh_sleep"): r.call("_wh_sleep")   # black 3.2: the room puts its own fades back to solid
	var all: Array = []; _walk(r, all)
	for c in all:
		if c is CanvasLayer: c.set_meta("wh_cl", c.visible); c.visible = false
		elif c is WorldEnvironment: c.set_meta("wh_env", c.environment); c.environment = null   # one active environment
		elif c is Camera3D and c.current and not (c.get_viewport() is SubViewport): c.set_meta("wh_cur", true); c.current = false
		# nodes with their own process mode (the room UI, HUD, pause menu, phone are ALWAYS) ignore the room's DISABLED:
		# stop them too, or a sleeping room would still answer the back key / run its HUD
		if c.process_mode != Node.PROCESS_MODE_INHERIT and c.process_mode != Node.PROCESS_MODE_DISABLED:
			c.set_meta("wh_pm", c.process_mode); c.process_mode = Node.PROCESS_MODE_DISABLED
	for k in ["hero", "hand3d"]:
		var n = r.get(k)
		if n is Node3D and is_instance_valid(n): n.set_meta("wh_hv", n.visible); n.visible = false
	_cheap(r, true)

static func _wake(r: Node) -> void:
	_cheap(r, false)
	var all: Array = []; _walk(r, all)
	for c in all:
		if c.has_meta("wh_cl"): c.visible = c.get_meta("wh_cl"); c.remove_meta("wh_cl")
		if c.has_meta("wh_env"): c.environment = c.get_meta("wh_env"); c.remove_meta("wh_env")
		if c.has_meta("wh_cur"): c.current = true; c.remove_meta("wh_cur")
		if c.has_meta("wh_hv"): c.visible = c.get_meta("wh_hv"); c.remove_meta("wh_hv")
		if c.has_meta("wh_pm"): c.process_mode = c.get_meta("wh_pm"); c.remove_meta("wh_pm")
	r.remove_meta(DORMANT)

## the hero of the room entered starts where the other one stood (same spot, same facing) and walks on to the room's
## usual "just inside the door" spot. Hands over at once if a story step moves the hero itself.
static func _walk_in(r: Node, hp: Vector3, hy: float, to: Vector3, yaw: float) -> void:
	var hero = r.get("hero")
	if not (hero is Node3D) or not is_instance_valid(hero): return
	var tree := r.get_tree()
	hero.position = Vector3(hp.x, 0, hp.z); hero.rotation.y = hy
	var took := false
	if String(r.get("mode")) == "play": r.set("mode", "busy"); took = true
	var d: Vector3 = to - hero.position; d.y = 0
	var last: Vector3 = hero.position
	var own := true
	if d.length() > 0.05:
		var dir_yaw := atan2(d.x, d.z)
		var sc := 1.0
		if hero.get("model") is Node3D: sc = maxf(0.3, (hero.model as Node3D).scale.y)
		if hero.has_method("play"): hero.play("walk", 0.15, clampf(WALK_IN / (1.7 * sc), 0.5, 1.8))
		while true:
			await tree.process_frame
			if not is_instance_valid(r) or not is_instance_valid(hero) or dormant(r) or tree.current_scene != r: return
			if hero.position.distance_to(last) > 0.001: own = false; break   # somebody else moved the hero
			if tree.paused: continue
			var dt := r.get_process_delta_time()
			var rem: Vector3 = to - hero.position; rem.y = 0
			hero.rotation.y = lerp_angle(hero.rotation.y, dir_yaw, 1.0 - exp(-14.0 * dt))
			if rem.length() <= WALK_IN * dt: hero.position = Vector3(to.x, 0, to.z); last = hero.position; break
			hero.position += rem.normalized() * WALK_IN * dt; last = hero.position
	if own:
		if hero.has_method("play"): hero.play("idle", 0.25)
		var t := 0.0
		while t < 0.35:
			await tree.process_frame
			if not is_instance_valid(r) or not is_instance_valid(hero) or dormant(r) or tree.current_scene != r: return
			if hero.position.distance_to(last) > 0.001: break
			var dt2 := r.get_process_delta_time(); t += dt2
			hero.rotation.y = lerp_angle(hero.rotation.y, yaw, 1.0 - exp(-12.0 * dt2))
		if is_instance_valid(hero) and hero.position.distance_to(last) <= 0.001: hero.rotation.y = yaw
	if took and is_instance_valid(r) and String(r.get("mode")) == "busy":
		r.set("mode", "play")
		if r.has_method("_update_hand"): r.call("_update_hand")

## the camera does not cut: for 0.9 s the picture blends from the old room camera to the new one (drawn on top of the
## room's own camera logic, which keeps running untouched: CamPre puts its own transform back before the rooms run)
static var _blend: Node
static func _blend_cam(r: Node, from_xf: Transform3D, from_fov: float) -> void:
	if is_instance_valid(_blend): _blend.queue_free()
	var b := CamBlend.new(); b.from_xf = from_xf; b.from_fov = from_fov; b.name = "WHCamBlend"
	var pre := CamPre.new(); pre.b = b; pre.name = "WHCamPre"
	r.get_tree().root.add_child(b); r.get_tree().root.add_child(pre)
	b.pre = pre; _blend = b
	var c := r.get_viewport().get_camera_3d()   # this very frame already shows the old view (no one-frame cut)
	if c:
		b.cam = c; b.own_xf = c.global_transform; b.own_fov = c.fov
		c.global_transform = from_xf; c.fov = from_fov

class CamBlend extends Node:
	var from_xf := Transform3D.IDENTITY
	var from_fov := 42.0
	var dur := 0.9
	var t := 0.0
	var cam: Camera3D
	var own_xf := Transform3D.IDENTITY
	var own_fov := 42.0
	var pre: Node
	func _ready() -> void:
		process_priority = 1000; process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(dt: float) -> void:
		if not get_tree().paused: t += dt
		var c := get_viewport().get_camera_3d()
		if c == null or t >= dur:
			restore(); queue_free(); return
		var k := ease(clampf(t / dur, 0.0, 1.0), -2.0)
		cam = c; own_xf = c.global_transform; own_fov = c.fov
		c.global_transform = from_xf.interpolate_with(own_xf, k); c.fov = lerpf(from_fov, own_fov, k)
	func restore() -> void:
		if is_instance_valid(cam): cam.global_transform = own_xf; cam.fov = own_fov
		cam = null
	func _exit_tree() -> void:
		restore()
		if is_instance_valid(pre): pre.queue_free()

class CamPre extends Node:
	var b: Node
	func _ready() -> void:
		process_priority = -1000; process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_dt: float) -> void:
		if is_instance_valid(b): b.restore()
		else: queue_free()

static func _on_live_exit(room: Node) -> void:
	if swapping or room.has_meta("house_dead"): return
	# leaving the house (world, hospital, menu...) or a plain scene change: every other room (shell or dormant) goes too
	for s in _rooms(room.get_tree()):
		if s == room: continue
		s.set_meta("house_dead", true); s.queue_free()

## every house room in the tree (shells, dormant rooms and the live one)
static func _rooms(tree: SceneTree) -> Array:
	return tree.root.get_children().filter(func(c): return is_room(String(c.scene_file_path)) and not c.has_meta("house_dead"))

static func _shells(tree: SceneTree) -> Array:
	return _rooms(tree).filter(func(c): return c != tree.current_scene)

static func _find(tree: SceneTree, path: String) -> Node:
	for s in _shells(tree): if s.scene_file_path == path: return s
	return null

static func _ensure(live: Node, skip: Array = []) -> void:
	if not is_instance_valid(live) or not live.is_inside_tree() or live.get_tree().current_scene != live: return
	var tree := live.get_tree()
	var lp: String = live.scene_file_path
	for p in OFS:
		if p == lp: continue
		var s := _find(tree, p)
		if s == null:
			s = (load(p) as PackedScene).instantiate(); s.set_meta(SHELL, true)
			tree.root.add_child(s)                 # builds its geometry at the origin (same coordinates as when live)
		s.position = OFS[p] - OFS[lp]
		# a room on the camera side (south) of the live room would hide it: keep only its floor-level parts visible there
		var z0: float = OFS[p].z + ZSPAN[p].x
		_hide_tall(s, not SHOULDER_CAM and z0 >= OFS[lp].z + ZSPAN[lp].y - 0.05)   # the low shoulder camera needs no cut-away

static func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		out.append(c); _walk(c, out)

## shell <-> live: lights, shadow casting, processing, mirror viewports, particles, the 30x30 outdoor ground box
static func _cheap(room: Node, on: bool) -> void:
	room.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT
	var all: Array = []; _walk(room, all)
	for c in all:
		if c is Light3D:
			if on: c.set_meta("wh_vis", c.visible); c.visible = false
			elif c.has_meta("wh_vis"): c.visible = c.get_meta("wh_vis"); c.remove_meta("wh_vis")
		elif c is SubViewport:
			if on: c.set_meta("wh_upd", c.render_target_update_mode); c.render_target_update_mode = SubViewport.UPDATE_DISABLED
			elif c.has_meta("wh_upd"): c.render_target_update_mode = c.get_meta("wh_upd"); c.remove_meta("wh_upd")
		elif c is Label3D:   # state text (alarm "Ring! Ring!", TV channel): drawn through walls, the live room sets it -> hidden in a shell
			if on: c.set_meta("wh_vis", c.visible); c.visible = false
			elif c.has_meta("wh_vis"): c.visible = c.get_meta("wh_vis"); c.remove_meta("wh_vis")
		elif c is GeometryInstance3D:
			var g := c as GeometryInstance3D
			if on:
				if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
					g.set_meta("wh_cs", g.cast_shadow); g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				if g is MeshInstance3D and (g as MeshInstance3D).mesh and (g as MeshInstance3D).get_aabb().size.x >= 20.0 and g.visible:
					g.set_meta("wh_ground", true); g.visible = false   # each room's own 30x30 outdoor ground: the live room's is enough
			else:
				if g.has_meta("wh_cs"): g.cast_shadow = g.get_meta("wh_cs"); g.remove_meta("wh_cs")
				if g.has_meta("wh_ground"): g.visible = true; g.remove_meta("wh_ground")
				if g.has_meta("wh_tall"): g.visible = true; g.remove_meta("wh_tall")
			if g is MeshInstance3D:   # a mirror's live reflection is stopped in a shell: plain glass instead of a black plate
				var mi := g as MeshInstance3D
				if on and mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).albedo_texture is ViewportTexture:
					mi.set_meta("wh_mat", mi.material_override); mi.material_override = _glass()
				elif not on and mi.has_meta("wh_mat"): mi.material_override = mi.get_meta("wh_mat"); mi.remove_meta("wh_mat")
			if g is CPUParticles3D and on: (g as CPUParticles3D).emitting = false
			if g is GPUParticles3D and on: (g as GPUParticles3D).emitting = false

static func _hide_tall(room: Node, hide: bool) -> void:
	var all: Array = []; _walk(room, all)
	for c in all:
		if not (c is GeometryInstance3D) or c is Label3D or c.has_meta("wh_ground"): continue
		var g := c as GeometryInstance3D
		if hide:
			if g.visible and not g.has_meta("wh_tall") and g is VisualInstance3D:
				var top: float = (g.global_transform * g.get_aabb()).end.y
				if top > 0.35: g.set_meta("wh_tall", true); g.visible = false
		elif g.has_meta("wh_tall"): g.visible = true; g.remove_meta("wh_tall")

static var _glass_m: StandardMaterial3D
static func _glass() -> StandardMaterial3D:
	if _glass_m == null:
		_glass_m = StandardMaterial3D.new(); _glass_m.albedo_color = Color(0.74, 0.8, 0.86); _glass_m.metallic = 0.6; _glass_m.roughness = 0.15
	return _glass_m

## the whole house: everything outside the walls is dark for the room camera. The live room's 30x30 outdoor ground box gets a
## black twin and a black unshaded inside-out box closes the view around the house, both on render layer 11, which the
## mirror cameras (cull mask 1) do not see; the original ground moves to layer 12, seen only by the mirror cameras. So the
## rooms, their lighting and the mirror reflections stay exactly as in v32.
const L_VIEW := 1 << 10
const L_MIRROR := 1 << 11
static var _black_m: StandardMaterial3D
static func _dark_outside(room: Node) -> void:
	if room.has_node("WHVoid"): return
	if _black_m == null:
		_black_m = StandardMaterial3D.new(); _black_m.albedo_color = Color.BLACK
		_black_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _black_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var all: Array = []; _walk(room, all)
	for c in all:
		if c is Camera3D:
			if c.get_viewport() is SubViewport: c.cull_mask |= L_MIRROR
			else: c.cull_mask &= ~L_MIRROR
		elif c is MeshInstance3D and (c as MeshInstance3D).mesh and (c as MeshInstance3D).get_aabb().size.x >= 20.0 and not c.has_meta("wh_twin"):
			var g := c as MeshInstance3D
			var tw := MeshInstance3D.new(); tw.mesh = g.mesh; tw.material_override = _black_m; tw.layers = L_VIEW; tw.set_meta("wh_twin", true); tw.set_meta("wh_view_only", true)
			tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(tw); g.layers = L_MIRROR
	var v := MeshInstance3D.new(); v.name = "WHVoid"; v.set_meta("wh_view_only", true)   # never a camera / fade blocker
	var bm := BoxMesh.new(); bm.size = Vector3(60, 40, 60); v.mesh = bm; v.layers = L_VIEW
	v.material_override = _black_m; v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	room.add_child(v)
