## house.27: runtime polaroid fallbacks that show the PLAYER'S OWN character (creator look + clothes).
## Poses the player in a small offscreen SubViewport stage per action and caches it to user://photos/<key>.png.
## Never overwrites a file that already exists (a real Life.snap() snapshot always wins).

extends Node

const PATH := "user://photos/%s.png"
const F := "res://props/furniture/"
var vp: SubViewport
var root: Node3D
var look: Dictionary
var out_dir := SavePath.photos()
var look_override := {}   # QA only

## render every missing key, then frees itself
static func ensure(host: Node, keys: Array) -> void:
	var todo: Array = []
	for k in keys:
		if Life.photos.has(k) or FileAccess.file_exists(SavePath.photos() + "/%s.png" % k) or k in todo: continue
		todo.append(k)
	if todo.is_empty(): return
	var r = load("res://scripts/story/polaroid_renderer.gd").new(); host.add_child(r)
	await r._render(todo); r.queue_free()

func _render(keys: Array) -> void:
	look = look_override if not look_override.is_empty() else CharacterHook.creator(get_tree())
	vp = SubViewport.new(); vp.size = Vector2i(480, 480); vp.own_world_3d = true; vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(vp)
	var seen := {}
	for k in keys:
		if seen.has(k): continue
		seen[k] = true; _build(k)
		if root: await _shot(k)
	vp.queue_free()

func _box(s: Vector3, p: Vector3, c: Color, par: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = s; mi.mesh = b; mi.position = p
	var m := StandardMaterial3D.new(); m.albedo_color = c; mi.material_override = m; (par if par else root).add_child(mi); return mi
func _glb(path: String, p: Vector3, ry := 0.0, sc := 1.0) -> Node3D:
	var n: Node3D = (load(path) as PackedScene).instantiate(); n.position = p; n.rotation_degrees.y = ry; n.scale = Vector3.ONE * sc; root.add_child(n); return n
func _char(g: String, p: Vector3, ry: float, anim: String, t: float, top := Color(0, 0, 0, 0)) -> DemoCharacter:
	var c := DemoCharacter.new(); root.add_child(c)
	if g == "me": c.setup(String(look.get("gender", "men"))); CharacterHook.apply(c, look)   # the player's own look + clothes
	else: c.setup(g)
	if top.a > 0: c.top_color = top; c._refresh()
	c.position = p; c.rotation_degrees.y = ry; c.play(anim, 0.0)
	if c.player: c.player.seek(minf(t, c.anim_length(anim) - 0.01) if c.anim_length(anim) > 0 else 0.0, true); c.player.speed_scale = 0.0
	return c
func _stage(bg: Color, wall: Color, floor_c: Color, cam_p: Vector3, at: Vector3, fov := 50.0) -> void:
	root = Node3D.new(); vp.add_child(root)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 0.97, 0.92); e.ambient_light_energy = 0.75; we.environment = e; root.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, 35, 0); sun.light_energy = 0.9; root.add_child(sun)
	_box(Vector3(8, 0.1, 8), Vector3(0, -0.05, 0), floor_c)
	if wall.a > 0: _box(Vector3(8, 3, 0.1), Vector3(0, 1.5, -1.2), wall); _box(Vector3(0.1, 3, 8), Vector3(-2.0, 1.5, 0), wall.darkened(0.06))
	var cam := Camera3D.new(); cam.fov = fov; root.add_child(cam); cam.position = cam_p; cam.look_at(at); cam.current = true
func _shot(key: String) -> void:
	for k in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img: DirAccess.make_dir_recursive_absolute(out_dir); img.save_png(out_dir + "/%s.png" % key); print("POLAROID ", key)
	root.queue_free(); root = null; await get_tree().process_frame
const ARM_MOUTH := [-1.05, -1.8, 0.85]    # same right-arm-to-mouth pose as bathroom.gd
const ARM_FACE := [-1.0, -1.9, 0.7]
## raise the arms with bone offsets on top of the (frozen) animation; r / l = [upper arm, lower arm, shoulder]
func _arms(c: DemoCharacter, r: Array, l: Array) -> void:
	if r.size() == 3: c.bone_offsets["UpperArm.R"] = [Vector3.RIGHT, r[0]]; c.bone_offsets["LowerArm.R"] = [Vector3.RIGHT, r[1]]; c.bone_offsets["Shoulder.R"] = [Vector3.UP, r[2]]
	if l.size() == 3: c.bone_offsets["UpperArm.L"] = [Vector3.RIGHT, l[0]]; c.bone_offsets["LowerArm.L"] = [Vector3.RIGHT, l[1]]; c.bone_offsets["Shoulder.L"] = [Vector3.UP, -l[2]]

func _build(key: String) -> void:
	var c: DemoCharacter
	match key:
		"wake":
			_stage(Color(0.75, 0.85, 0.95), Color(0.93, 0.88, 0.8), Color(0.6, 0.45, 0.32), Vector3(1.6, 1.5, 1.8), Vector3(0, 0.7, -0.2))
			_box(Vector3(1.1, 0.4, 2.1), Vector3(0.05, 0.2, -0.2), Color(0.95, 0.95, 0.97)); _box(Vector3(1.12, 0.08, 1.2), Vector3(0.05, 0.44, 0.25), Color(0.45, 0.6, 0.85)); _box(Vector3(0.6, 0.12, 0.35), Vector3(0.05, 0.46, -1.05), Color(1, 1, 1)); _box(Vector3(0.9, 0.7, 0.02), Vector3(0.9, 1.7, -1.14), Color(0.7, 0.88, 1.0))
			_char("me", Vector3(0.05, 0.42, -0.4), 0.0, "wake_up", 2.5)
		"wash_face":
			_stage(Color(0.8, 0.9, 0.95), Color(0.62, 0.78, 0.82), Color(0.7, 0.72, 0.75), Vector3(1.25, 1.6, -0.3), Vector3(0, 1.3, -0.55))
			_box(Vector3(0.7, 0.85, 0.45), Vector3(0, 0.42, -0.95), Color(0.97, 0.97, 0.98)); _box(Vector3(0.5, 0.05, 0.3), Vector3(0, 0.86, -0.92), Color(0.75, 0.88, 0.98))
			_box(Vector3(0.6, 0.8, 0.02), Vector3(0, 1.65, -1.14), Color(0.8, 0.9, 0.95))
			c = _char("me", Vector3(0, 0, -0.4), 120.0, "idle", 0.5); _arms(c, ARM_FACE, ARM_FACE)   # both hands at the face
			var sp := SphereMesh.new(); sp.radius = 0.02; sp.height = 0.04
			for k in 6: var d := MeshInstance3D.new(); d.mesh = sp; var dm := StandardMaterial3D.new(); dm.albedo_color = Color(0.6, 0.85, 1.0, 0.8); dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; d.material_override = dm; d.position = Vector3(0.12 + k * 0.03, 1.45 - k * 0.07, -0.3 + (k % 2) * 0.05); root.add_child(d)
		"brush_teeth":
			_stage(Color(0.8, 0.9, 0.95), Color(0.8, 0.66, 0.7), Color(0.7, 0.72, 0.75), Vector3(-1.2, 1.6, -0.2), Vector3(0, 1.4, -0.5))
			_box(Vector3(0.7, 0.85, 0.45), Vector3(0, 0.42, -0.95), Color(0.97, 0.97, 0.98)); _box(Vector3(0.6, 0.8, 0.02), Vector3(0, 1.65, -1.14), Color(0.8, 0.9, 0.95))
			c = _char("me", Vector3(0, 0, -0.4), 240.0, "idle", 0.5); _arms(c, [-0.85, -1.85, 0.85], []); c.hold_item("res://props/brush.tscn", "brush", 0.2, false)
		"breakfast":
			_stage(Color(0.95, 0.9, 0.8), Color(0.98, 0.92, 0.82), Color(0.62, 0.48, 0.34), Vector3(1.5, 1.5, 1.6), Vector3(0, 0.9, -0.3))
			_box(Vector3(1.2, 0.05, 0.8), Vector3(0.0, 0.75, 0.15), Color(0.7, 0.5, 0.3)); _box(Vector3(0.08, 0.75, 0.08), Vector3(0.5, 0.37, 0.45), Color(0.6, 0.42, 0.25))
			for p in [Vector3(-0.2, 0.8, 0.2), Vector3(0.25, 0.8, 0.1)]: _box(Vector3(0.22, 0.02, 0.22), p, Color(0.98, 0.98, 0.96))
			_box(Vector3(0.12, 0.04, 0.12), Vector3(-0.2, 0.83, 0.2), Color(0.95, 0.75, 0.3))
			c = _char("me", Vector3(0, 0, -0.4), 0.0, "drink", 1.2); c.hold_item("res://props/mug.tscn", "mug", 0.1, false)
		"outside":
			_stage(Color(0.55, 0.78, 0.98), Color(0, 0, 0, 0), Color(0.45, 0.6, 0.35), Vector3(2.0, 1.4, 2.4), Vector3(0, 1.0, 0))
			_box(Vector3(8, 0.04, 1.5), Vector3(0, 0.02, 0), Color(0.7, 0.7, 0.7)); _box(Vector3(8, 0.03, 2.5), Vector3(0, 0.015, -2.0), Color(0.3, 0.3, 0.32))
			_box(Vector3(2.5, 2.5, 2), Vector3(-2.5, 1.25, 2.2), Color(0.9, 0.75, 0.6)); _box(Vector3(0.3, 2.5, 0.3), Vector3(1.6, 1.25, 0.6), Color(0.45, 0.3, 0.2)); _box(Vector3(1.2, 1.2, 1.2), Vector3(1.6, 2.8, 0.6), Color(0.3, 0.6, 0.3))
			_char("me", Vector3(0, 0.04, 0), 90.0, "walk", 0.3)
		"accident":
			_stage(Color(0.55, 0.78, 0.98), Color(0, 0, 0, 0), Color(0.45, 0.6, 0.35), Vector3(2.6, 1.6, 3.0), Vector3(-0.5, 0.8, -0.5))
			_box(Vector3(10, 0.03, 3), Vector3(0, 0.015, -0.5), Color(0.3, 0.3, 0.32)); for x in 5: _box(Vector3(0.6, 0.01, 0.12), Vector3(-4 + x * 2, 0.035, -0.5), Color(1, 1, 1))
			_box(Vector3(4.5, 2.2, 1.6), Vector3(-3.4, 1.3, -0.9), Color(0.95, 0.75, 0.15)); _box(Vector3(0.05, 0.9, 1.4), Vector3(-1.14, 1.6, -0.9), Color(0.5, 0.75, 0.9))
			# cat on the road (Kenney Cube Pets) — the dive is over it
			if ResourceLoader.exists("res://props/story/animal-cat.glb"):
				_glb("res://props/story/animal-cat.glb", Vector3(0.45, 0.0, -0.15), -40.0, 0.85)
			else:
				_box(Vector3(0.3, 0.2, 0.15), Vector3(0.4, 0.1, -0.2), Color(0.95, 0.6, 0.25)); _box(Vector3(0.12, 0.12, 0.12), Vector3(0.58, 0.22, -0.2), Color(0.95, 0.6, 0.25))
			# mid-dive over the cat: body almost horizontal, arms forward, bus braking behind (no injury shown)
			var pv := Node3D.new(); pv.position = Vector3(0.0, 0.55, -0.2); pv.rotation_degrees = Vector3(0, 0, -72); root.add_child(pv)
			c = _char("me", Vector3.ZERO, 90.0, "walk", 0.3); c.reparent(pv, false); c.position = Vector3(0, -0.9, 0)
			_arms(c, [-2.6, -0.2, 0.0], [-2.6, -0.2, 0.0])
			for k in 4: _box(Vector3(0.25, 0.015, 0.015), Vector3(-1.0 - k * 0.12, 0.9 - k * 0.1, -0.2 + k * 0.05), Color(1, 1, 1, 0.8))   # motion streaks
		"hospital":
			_stage(Color(0.85, 0.9, 0.92), Color(0.86, 0.92, 0.91), Color(0.78, 0.82, 0.8), Vector3(0.9, 1.5, 0.9), Vector3(-0.6, 0.8, -0.6))
			_box(Vector3(1.0, 0.55, 2.0), Vector3(-0.6, 0.275, -0.3), Color(0.95, 0.96, 0.98)); _box(Vector3(1.0, 0.04, 1.2), Vector3(-0.6, 0.57, 0.0), Color(0.95, 0.96, 0.98))
			_box(Vector3(0.03, 1.8, 0.03), Vector3(0.1, 0.9, -1.0), Color(0.72, 0.74, 0.77)); _box(Vector3(0.14, 0.22, 0.04), Vector3(0.1, 1.7, -1.0), Color(0.85, 0.95, 1.0))
			_box(Vector3(0.5, 0.36, 0.1), Vector3(-1.4, 1.4, -1.1), Color(0.88, 0.88, 0.9)); _box(Vector3(0.42, 0.27, 0.01), Vector3(-1.4, 1.41, -1.04), Color(0.05, 0.25, 0.1))
			_char("men", Vector3(-0.6, 0, -1.75), 0.0, "idle", 0.5, Color(0.98, 0.98, 0.98))
			# the patient (the player) lies in the bed, head on the pillow, face up, blanket over the legs
			_box(Vector3(0.6, 0.12, 0.35), Vector3(-0.6, 0.6, -1.1), Color(1, 1, 1))
			var lp := Node3D.new(); lp.position = Vector3(-0.6, 0.62, 0.55); lp.rotation_degrees = Vector3(-90, 0, 0); root.add_child(lp)
			c = _char("me", Vector3.ZERO, 180.0, "idle", 0.5); c.reparent(lp, false); c.position = Vector3.ZERO; c.rotation_degrees = Vector3.ZERO
			_box(Vector3(1.02, 0.18, 1.1), Vector3(-0.6, 0.72, 0.15), Color(0.62, 0.8, 0.86))
		"fine":
			_stage(Color(0.95, 0.9, 0.8), Color(0.98, 0.92, 0.82), Color(0.62, 0.48, 0.34), Vector3(0, 1.5, 2.2), Vector3(0, 1.1, 0))
			_glb(F + "loungeDesignSofa.glb", Vector3(-0.8, 0, -1.0), 0.0, 1.3)
			_char("me", Vector3(0, 0, 0), 0.0, "wave", 0.8)
		"home":
			_stage(Color(0.95, 0.9, 0.8), Color(0.98, 0.92, 0.82), Color(0.62, 0.48, 0.34), Vector3(1.2, 1.5, 2.2), Vector3(0, 1.0, 0))
			_glb(F + "loungeDesignSofa.glb", Vector3(-0.8, 0, -1.0), 0.0, 1.3); _char("me", Vector3(0.2, 0, 0), 20.0, "idle", 0.5)
		_: return
