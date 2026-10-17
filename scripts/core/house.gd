extends RefCounted
## v32wh: whole-house mode. The bedroom (main.tscn), bathroom and living room are all instanced at once, laid out as
## one house so their real doors line up (the door coordinates of the three rooms already agree):
##   living room at the house origin, bedroom 6 m north (its south door x 1.8 = the living room's bedroom door),
##   bathroom at (5.95, -4.75) (its south door = the living room's bathroom door, its west door = the bedroom's east door).
## The room the player is in is the "live" room: it is current_scene, sits at the world origin (all room code uses
## room-local world coordinates) and runs exactly the v32 code. The two other rooms are "shells": geometry only
## (their _build_room / decor), no environment, no hero/camera/UI/story, processing disabled, lights and
## shadow casting off, mirror viewports stopped. Walking through a door frees the room left (as change_scene did),
## shifts the house so the room entered sits at the origin, turns its shell live in place (it keeps the geometry it
## already built and runs the rest of its v32 _ready) and rebuilds the room left as a shell.
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
	if not room.has_meta("wh_hooked"):
		room.set_meta("wh_hooked", true); room.tree_exiting.connect(func(): _on_live_exit(room))
	(func(): _ensure(room)).call_deferred()

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
	var base: Vector3 = target.position
	swapping = true
	from.get_parent().remove_child(from); from.queue_free()   # like change_scene: the room left (and its awaits) goes away
	swapping = false
	for s in _shells(tree): s.position -= base
	target.position = Vector3.ZERO
	_ensure(target, [target])                  # rebuild the room left as a shell (same frame, no gap at the door)
	target.remove_meta(SHELL); _cheap(target, false)
	tree.current_scene = target
	target.call("_live_ready")

static func _on_live_exit(room: Node) -> void:
	if swapping: return
	# leaving the house (world, hospital, menu...) or a plain scene change: the shells go with the live room
	for s in _shells(room.get_tree()):
		s.set_meta("house_dead", true); s.queue_free()

static func _shells(tree: SceneTree) -> Array:
	return tree.root.get_children().filter(func(c): return is_shell(c) and not c.has_meta("house_dead"))

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
		_hide_tall(s, z0 >= OFS[lp].z + ZSPAN[lp].y - 0.05)

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
		if not (c is GeometryInstance3D) or c.has_meta("wh_ground"): continue
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
