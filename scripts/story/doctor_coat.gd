## v29: knee-length white lab coat for the hospital doctor, attached PER BONE with BoneAttachment3D
## (hips, abdomen, torso, chest, upper/lower arms, thighs), so it follows every animation and bone offset
## (incl. the flashlight arm raise) with no floating or clipping. Sizes are in skeleton units (metres in the rig).
## Usage (one line in hospital.gd): DoctorCoat.dress(doctor)
class_name DoctorCoat

const WHITE := Color(0.97, 0.97, 0.98)
const EDGE := Color(0.84, 0.85, 0.88)
const DARK := Color(0.15, 0.2, 0.3)

static func dress(doc: Node) -> void:
	var sk: Skeleton3D = doc.skeleton
	if sk == null: return
	var old := sk.get_node_or_null("DoctorCoat")
	if old: old.free()
	var holder := Node3D.new(); holder.name = "DoctorCoat"; sk.add_child(holder)
	var mat := StandardMaterial3D.new(); mat.albedo_color = WHITE; mat.roughness = 0.85
	var edge := StandardMaterial3D.new(); edge.albedo_color = EDGE; edge.roughness = 0.9
	var dark := StandardMaterial3D.new(); dark.albedo_color = DARK
	# body: [bone, from y, to y, bottom radius, top radius, depth squash]
	# one continuous coat skirt on the hips bone: waist -> just above the knee, flared, encloses both legs
	_tube(sk, holder, "Hips", -0.33, 0.14, 0.27, 0.185, 0.8, mat)
	var hp := _att(sk, holder, "Hips")
	if hp:
		var seam := _box(hp, Vector3(0.012, 0.48, 0.01), Vector3(0, -0.095, 0.0), edge)   # open front of the coat
		var zt := 0.185 * 0.8; var zb := 0.27 * 0.8
		seam.position.z = (zt + zb) * 0.5 + 0.004; seam.rotation.x = atan2(zb - zt, 0.47)
		var hem := _tube_on(hp, -0.335, -0.32, 0.272, 0.272, 0.8, edge)   # hem line
	_tube(sk, holder, "Abdomen", -0.04, 0.17, 0.165, 0.158, 0.76, mat)
	_tube(sk, holder, "Torso", -0.01, 0.22, 0.158, 0.165, 0.74, mat)
	_tube(sk, holder, "Chest", -0.01, 0.12, 0.168, 0.11, 0.74, mat)
	# coat skirt: one flared panel per thigh, to just above the knee; the two overlap in the middle
	for s in ["L", "R"]:
		_tube(sk, holder, "UpperArm." + s, -0.02, 0.185, 0.058, 0.064, 1.0, mat)
		_tube(sk, holder, "LowerArm." + s, -0.01, 0.215, 0.05, 0.057, 1.0, mat)
		_tube(sk, holder, "LowerArm." + s, 0.2, 0.235, 0.056, 0.056, 1.0, edge)    # cuff
	# open front, lapels, buttons, pocket, stethoscope (on the chest/torso bones)
	var ch := _att(sk, holder, "Chest"); var to := _att(sk, holder, "Torso"); var ab := _att(sk, holder, "Abdomen")
	if to: _box(to, Vector3(0.014, 0.23, 0.01), Vector3(0, 0.1, 0.122), edge)
	if ab: _box(ab, Vector3(0.014, 0.18, 0.01), Vector3(0, 0.08, 0.125), edge)
	if ch:
		for x in [-1.0, 1.0]:
			var lp := _box(ch, Vector3(0.05, 0.13, 0.012), Vector3(0.045 * x, 0.05, 0.118), edge); lp.rotation_degrees.z = -18.0 * x
		var tm := TorusMesh.new(); tm.inner_radius = 0.07; tm.outer_radius = 0.083; tm.rings = 16; tm.ring_segments = 6
		var st := MeshInstance3D.new(); st.mesh = tm; st.material_override = dark; st.position = Vector3(0, 0.1, 0.03); st.rotation_degrees.x = 65; ch.add_child(st)
		_box(ch, Vector3(0.06, 0.035, 0.008), Vector3(-0.085, 0.0, 0.122), StandardMaterial3D.new()).material_override.albedo_color = Color(0.2, 0.45, 0.85)   # badge
	if to:
		for y in [0.04, 0.12, 0.2]:
			var b := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.009; cm.bottom_radius = 0.009; cm.height = 0.006
			b.mesh = cm; b.material_override = edge; b.position = Vector3(0.025, y, 0.124); b.rotation_degrees.x = 90; to.add_child(b)
		_box(to, Vector3(0.07, 0.075, 0.008), Vector3(0.085, 0.16, 0.12), edge)   # chest pocket
		for x in [-1.0, 1.0]: _tube_on(to, 0.0, 0.17, 0.006, 0.006, 1.0, dark, Vector3(0.05 * x, 0.08, 0.118))   # stethoscope tubes

static func _att(sk: Skeleton3D, holder: Node, bone: String) -> BoneAttachment3D:
	if sk.find_bone(bone) < 0: return null
	var nm := "Att_" + bone.replace(".", "_")
	var a := holder.get_node_or_null(nm) as BoneAttachment3D
	if a: return a
	a = BoneAttachment3D.new(); a.name = nm; holder.add_child(a)
	a.set_use_external_skeleton(true); a.set_external_skeleton(a.get_path_to(sk)); a.bone_name = bone
	return a

static func _tube(sk: Skeleton3D, holder: Node, bone: String, y0: float, y1: float, r_bot: float, r_top: float, squash: float, m: Material) -> void:
	var a := _att(sk, holder, bone)
	if a: _tube_on(a, y0, y1, r_bot, r_top, squash, m)

static func _tube_on(par: Node3D, y0: float, y1: float, r_bot: float, r_top: float, squash: float, m: Material, off := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.bottom_radius = r_bot; cm.top_radius = r_top; cm.height = y1 - y0; cm.radial_segments = 20; cm.rings = 2
	var mi := MeshInstance3D.new(); mi.mesh = cm; mi.material_override = m
	mi.position = off + Vector3(0, (y0 + y1) * 0.5, 0); mi.scale = Vector3(1, 1, squash); par.add_child(mi); return mi

static func _box(par: Node3D, s: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new(); bm.size = s
	var mi := MeshInstance3D.new(); mi.mesh = bm; mi.material_override = m; mi.position = p; par.add_child(mi); return mi
