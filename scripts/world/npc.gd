## NPC: Quaternius casual character (same DemoCharacter as the player) with a random outfit.
## mode "walk": loops a sidewalk route (waits when the player / another NPC is in the way).
## mode "idle": plays one animation on a spot (sit_idle on a bench, idle at the bus stop, talk behind a counter...).
## Talk: "Say hello" -> player line + NPC greeting (TR via Lines). Cheap: no shadows, hidden beyond 32 m.
class_name NPC
extends Node3D

var hero: DemoCharacter
var mode := "idle"
var anim := "idle"
var route := PackedVector3Array()
var wp := 0
var speed := 1.15
var line := "Hello!"
var it: Interactable
var talking := 0.0
var wait := 0.0
var _steps := {}
var _anim_acc := 0.0
static var all: Array = []

func _enter_tree() -> void: all.append(self)
func _exit_tree() -> void: all.erase(self)

func setup(seed_: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	hero = DemoCharacter.new(); add_child(hero); speed = rng.randf_range(1.0, 1.35)
	hero.setup("men" if rng.randf() < 0.5 else "women")
	for slot in DemoCharacter.SLOTS: hero.set_outfit_part(slot, rng.randi() % 3)
	hero.set_skin(rng.randi() % 4)
	hero.set_height(["short", "medium", "tall"][rng.randi() % 3])
	_merge_parts()
	# soft blob shadow (1 cheap transparent quad)
	var blob := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.7, 0.7); q.orientation = PlaneMesh.FACE_Y; blob.mesh = q
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0, 0, 0, 0.22); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; blob.material_override = bm; blob.position.y = 0.02; blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blob.visibility_range_end = 12.0; add_child(blob)
	it = Interactable.new(); it.obj_name = "person"; it.radius = 1.7; it.walk_to = false; add_child(it)
	it.verbs = func(): return [["Say hello", _talk]]
	hero.play(anim if mode == "idle" else "walk", 0.0, speed / 1.7 if mode == "walk" else 1.0)
	hero.player.speed_scale = 1.0

## v32-npc-pose: talking keeps the NPC's pose (shared NpcTalk routine). The old code played the "talk" clip, which is a
## SEATED clip, so every standing NPC sat down for its line and stood back up. Now: turn toward the player + head nod only.
## A walker still stops on the sidewalk for the line (idle = its standing pose, no foot sliding) and walks on after.
## scripted_pose (opt-in): a clip name to play only for this NPC's line, for an explicitly scripted scene.
const NpcTalk := preload("res://scripts/core/npc_talk.gd")
var scripted_pose := ""

func _talk() -> void:
	var w := get_tree().current_scene
	await w.say_line("I am saying hello.")
	talking = 6.0
	if mode == "walk": hero.play("idle", 0.2)
	var p: Node3D = w.get("player")
	var st: Dictionary = NpcTalk.begin(hero, p.global_position if p else hero.global_position + Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y)), scripted_pose)
	await w.say_line(line)          # the nod / head turn waits for the line (never cut)
	await get_tree().create_timer(0.6).timeout
	NpcTalk.end(hero, st)
	if mode == "walk": hero.play("walk", 0.3, speed / 1.7)

func _process(dt: float) -> void:
	var w := get_tree().current_scene
	var pl: Node3D = w.get("player")
	var far := pl != null and pl.global_position.distance_to(global_position) > 26.0
	visible = not far
	hero.player.active = not far                # skip animation work when hidden
	hero.set_process(not far)
	var mid := pl != null and pl.global_position.distance_to(global_position) > 14.0
	var ap := hero.player
	if mid and not far:
		if ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL: ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_acc += dt
		if (Engine.get_process_frames() + get_instance_id()) % 3 == 0: ap.advance(_anim_acc); _anim_acc = 0.0
	elif ap.callback_mode_process != AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE:
		ap.advance(_anim_acc); _anim_acc = 0.0; ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	it.focus = global_position + Vector3(0, 1.2, 0)
	if mode != "walk" or far or route.size() < 2: return
	if talking > 0.0: talking -= dt; return
	var target := route[wp]; var d := target - position; d.y = 0.0
	if d.length() < 0.3: wp = (wp + 1) % route.size(); return
	var f := d.normalized()
	# avoidance: wait for the player or another NPC right ahead
	var blocked := false
	if pl:
		var rp := pl.global_position - global_position
		if rp.dot(f) > 0.0 and rp.dot(f) < 1.4 and absf(rp.cross(f).y) < 0.6: blocked = true
	for n in all:
		if n == self or not n.visible: continue
		var rn: Vector3 = n.position - position
		if rn.dot(f) > 0.0 and rn.dot(f) < 1.1 and absf(rn.cross(f).y) < 0.5 and n.get_instance_id() < get_instance_id(): blocked = true
	if blocked:
		wait += dt
		if wait < 2.5:
			if hero.player.current_animation != "idle": hero.play("idle", 0.2)
			return
		position += Vector3(f.z, 0, -f.x) * 0.6 * dt      # side-step after waiting
	else: wait = 0.0
	if hero.player.current_animation != "walk": hero.play("walk", 0.2, speed / 1.7)
	position += f * speed * dt
	if pl and Footsteps.contact(hero.player, hero.anim_length("walk"), _steps): Footsteps.npc_step(self, pl.global_position)
	hero.rotation.y = lerp_angle(hero.rotation.y, atan2(f.x, f.z), 1.0 - exp(-8.0 * dt))

static var _merged_mat: StandardMaterial3D
## draw-call diet: bake every visible outfit part (several surfaces each) into ONE skinned surface with
## per-vertex colours from the part materials -> 1 draw call per NPC instead of ~10.
func _merge_parts() -> void:
	var sk := hero.skeleton
	var st_arrays := []
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray()
	var bones := PackedInt32Array(); var weights := PackedFloat32Array(); var idx := PackedInt32Array()
	var bind_pose := {}
	var parts: Array = []
	for m in sk.get_children():
		if m is MeshInstance3D and (m as MeshInstance3D).visible and (m as MeshInstance3D).mesh: parts.append(m)
	for mi: MeshInstance3D in parts:
		var sk_res := mi.skin
		var remap := PackedInt32Array()
		if sk_res:
			for b in sk_res.get_bind_count():
				var bi := sk_res.get_bind_bone(b)
				if bi < 0: bi = sk.find_bone(sk_res.get_bind_name(b))
				remap.append(bi)
				if not bind_pose.has(bi): bind_pose[bi] = sk_res.get_bind_pose(b)
		for si in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(si)
			var mat := mi.get_active_material(si) as BaseMaterial3D
			var c := mat.albedo_color if mat else Color(0.8, 0.8, 0.8)
			var base := verts.size()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; verts.append_array(v)
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]; norms.append_array(n)
			for i in v.size(): cols.append(c)
			var bb: PackedInt32Array = a[Mesh.ARRAY_BONES]; var ww: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var per: int = bb.size() / maxi(v.size(), 1)
			for i in v.size():
				for j in 4:
					var k := i * per + j
					bones.append(remap[bb[k]] if j < per and remap.size() > 0 else 0)
					weights.append(ww[k] if j < per else 0.0)
			var ii: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			for x in ii: idx.append(x + base)
		mi.visible = false
	if verts.is_empty(): return
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_BONES] = bones; arr[Mesh.ARRAY_WEIGHTS] = weights; arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if _merged_mat == null:
		_merged_mat = StandardMaterial3D.new(); _merged_mat.vertex_color_use_as_albedo = true; _merged_mat.vertex_color_is_srgb = true
		_merged_mat.roughness = 0.85
	am.surface_set_material(0, _merged_mat)
	var skin := Skin.new()
	for bi in sk.get_bone_count(): skin.add_bind(bi, bind_pose.get(bi, sk.get_bone_global_rest(bi).affine_inverse()))   # bind index == bone index
	var out := MeshInstance3D.new(); out.name = "Merged"; out.mesh = am; out.skin = skin
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sk.add_child(out); out.skeleton = NodePath("..")
