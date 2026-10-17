## v34 open world (blue): draw-call cut. Static meshes are baked at install time into one mesh per chunk.
##   WorldMerge.merge_root(root, range_end := 0.0) -> stats
## Untextured opaque StandardMaterial3D surfaces (almost all of this low-poly game) go into ONE vertex-coloured surface with
## one shared material (albedo / MultiMesh instance colour baked into COLOR); every other opaque material keeps one surface
## per material, all its users merged. MultiMeshInstance3Ds (street trees, lamps) are expanded into the same chunk.
## Originals are hidden, not freed (scripts may still hold them).
## Never merged (they move, fade or are driven by scripts):
##   * nodes referenced by a script variable (directly or inside a Dictionary / Array) of any scripted node in the root,
##     with their subtrees (room N / OBJ dicts, place its / npcs, lot door_pivot, World door leaves ...)
##   * Interactables, doors (group "doors", meta no_fade, names *door* / *leaf*), characters / players / NPCs / vehicles
##     (script file names), CharacterBody3D / RigidBody3D / AnimatableBody3D, Skeleton3D / AnimationPlayer subtrees,
##     groups fade / cam_occluder / no_merge / entrances, metas no_merge / wf_reg / wf_a / ow_removed
##   * thin + tall wall boxes (they fade one by one), hidden meshes, transparent / emissive / special materials,
##     skinned or blend-shape meshes, Label3D / sprites / particles
class_name WorldMerge
extends RefCounted

const ShoulderCam := preload("res://scripts/core/shoulder_cam.gd")
const SKIP_SCRIPTS := ["vehicle", "npc", "character", "interactable", "player", "door", "car_kit"]
static var _plain_mat: StandardMaterial3D

static func plain_mat() -> StandardMaterial3D:
	if _plain_mat == null:
		_plain_mat = StandardMaterial3D.new(); _plain_mat.vertex_color_use_as_albedo = true; _plain_mat.roughness = 0.85
		_plain_mat.resource_name = "ow_merged"
	return _plain_mat

static func _protected(root: Node) -> Dictionary:
	var out := {}
	var nodes: Array = [root]; nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		if n.get_script() == null: continue
		for p in n.get_property_list():
			if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
			_collect(n.get(p.name), out, 0, n)
	return out

static func _collect(v, out: Dictionary, depth: int, owner_n: Node) -> void:
	if depth > 2: return
	if v is Object and not is_instance_valid(v): return
	if v is Node3D and v != owner_n: out[v] = true
	elif v is Dictionary: for k in v: _collect(v[k], out, depth + 1, owner_n)
	elif v is Array: for e in v: _collect(e, out, depth + 1, owner_n)

static func _skip_node(n: Node) -> bool:
	for g in ["no_merge", "doors", "fade", "cam_occluder", "entrances"]: if n.is_in_group(g): return true
	for m in ["no_merge", "no_fade", "wf_reg", "wf_a", "ow_removed"]: if n.has_meta(m): return true
	if n is CharacterBody3D or n is RigidBody3D or n is AnimatableBody3D or n is Skeleton3D or n is AnimationPlayer or n is Interactable: return true
	if n is Camera3D or n is Light3D: return false
	var nm := String(n.name).to_lower()
	if "door" in nm or "leaf" in nm: return true
	var s = n.get_script()
	if s is Script:
		var f := String((s as Script).resource_path).get_file().to_lower()
		for k in SKIP_SCRIPTS: if k in f: return true
	return false

static func _gather(n: Node, prot: Dictionary, out: Array) -> void:
	for c in n.get_children():
		if prot.has(c) or _skip_node(c): continue
		if c is Node3D and not (c as Node3D).visible: continue
		var anim := false
		for cc in c.get_children(): if cc is AnimationPlayer: anim = true
		if anim: continue
		if c is MeshInstance3D or c is MultiMeshInstance3D: out.append(c)
		_gather(c, prot, out)

static func _plain(m: Material) -> bool:
	if m == null: return true
	if not (m is StandardMaterial3D) or m.next_pass != null: return false
	var sm := m as StandardMaterial3D
	return sm.albedo_texture == null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled \
		and sm.cull_mode == BaseMaterial3D.CULL_BACK and not sm.vertex_color_use_as_albedo and sm.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL

static func _opaque_ok(m: Material) -> bool:
	if m == null or _plain(m): return true
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not b.emission_enabled and m.next_pass == null
	return false

static func _append(buckets: Dictionary, mesh: Mesh, mats: Array, xf: Transform3D, tint: Color, st: Dictionary) -> void:
	for s in mesh.get_surface_count():
		var mt: Material = mats[s]
		var plain := _plain(mt)
		var key := "plain" if plain else str(mt.get_instance_id())
		if not buckets.has(key): buckets[key] = {"mat": plain_mat() if plain else mt, "plain": plain, "v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
		var b: Dictionary = buckets[key]
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if verts.is_empty(): continue
		var base: int = (b.v as PackedVector3Array).size()
		b.v.append_array(xf * verts)
		var nr = arr[Mesh.ARRAY_NORMAL]
		if nr is PackedVector3Array and (nr as PackedVector3Array).size() == verts.size():
			b.n.append_array(Transform3D(xf.basis.inverse().transposed(), Vector3.ZERO) * (nr as PackedVector3Array))
		else:
			var z := PackedVector3Array(); z.resize(verts.size()); z.fill(Vector3.UP); b.n.append_array(z)
		var base_c: Color = ((mt as StandardMaterial3D).albedo_color if plain and mt != null else Color.WHITE) * tint
		var vc = arr[Mesh.ARRAY_COLOR]
		var col := PackedColorArray(); col.resize(verts.size())
		if plain and vc is PackedColorArray and (vc as PackedColorArray).size() == verts.size() and mt != null and (mt as StandardMaterial3D).vertex_color_use_as_albedo:
			for k in verts.size(): col[k] = (vc as PackedColorArray)[k] * base_c
		else: col.fill(base_c)
		b.c.append_array(col)
		var uv = arr[Mesh.ARRAY_TEX_UV]
		if uv is PackedVector2Array and (uv as PackedVector2Array).size() == verts.size(): b.uv.append_array(uv)
		else:
			var zu := PackedVector2Array(); zu.resize(verts.size()); b.uv.append_array(zu)
		var idx = arr[Mesh.ARRAY_INDEX]
		var ii := PackedInt32Array()
		if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty(): ii = (idx as PackedInt32Array).duplicate()
		else:
			ii.resize(verts.size()); for k in verts.size(): ii[k] = k
		if xf.basis.determinant() < 0.0:
			for k in range(0, ii.size() - 2, 3):
				var t := ii[k + 1]; ii[k + 1] = ii[k + 2]; ii[k + 2] = t
		for k in ii.size(): ii[k] += base
		b.i.append_array(ii)
		st.surfaces_in += 1

static func merge_root(root: Node3D, range_end := 0.0, range_margin := 4.0) -> Dictionary:
	var st := {"meshes": 0, "surfaces_in": 0, "surfaces_out": 0}
	if root == null or not is_instance_valid(root) or root.has_meta("ow_merged"): return st
	root.set_meta("ow_merged", true)
	var prot := _protected(root)
	var cand: Array = []; _gather(root, prot, cand)
	var inv := root.global_transform.affine_inverse()
	var buckets := {}
	var used: Array = []
	for g in cand:
		var gi: GeometryInstance3D = g
		if gi.visibility_range_begin > 0.0 or gi.material_overlay != null or gi.transparency > 0.0: continue
		var mesh: Mesh = null; var mm: MultiMesh = null
		if gi is MeshInstance3D:
			var m := gi as MeshInstance3D
			mesh = m.mesh
			if mesh == null or m.skin != null or (mesh is ArrayMesh and (mesh as ArrayMesh).get_blend_shape_count() > 0): continue
			if mesh is BoxMesh and ShoulderCam._is_wall(m.global_transform * m.get_aabb()): continue   # walls fade one by one
		else:
			mm = (gi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D: continue
			mesh = mm.mesh
		var mats := []; var ok := true
		for s in mesh.get_surface_count():
			var mt: Material = gi.material_override
			if mt == null and gi is MeshInstance3D: mt = (gi as MeshInstance3D).get_surface_override_material(s)
			if mt == null: mt = mesh.surface_get_material(s)
			if mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES or not _opaque_ok(mt): ok = false
			mats.append(mt)
		if not ok: continue
		var xf := inv * gi.global_transform
		if mm:
			var n := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
			for k in n: _append(buckets, mesh, mats, xf * mm.get_instance_transform(k), mm.get_instance_color(k) if mm.use_colors else Color.WHITE, st)
		else: _append(buckets, mesh, mats, xf, Color.WHITE, st)
		used.append(gi)
	if used.size() < 2:
		root.remove_meta("ow_merged"); return st
	var am := ArrayMesh.new()
	for key in buckets:
		var b: Dictionary = buckets[key]
		if (b.i as PackedInt32Array).is_empty(): continue
		var a := []; a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = b.v; a[Mesh.ARRAY_NORMAL] = b.n; a[Mesh.ARRAY_COLOR] = b.c; a[Mesh.ARRAY_INDEX] = b.i
		if not b.plain: a[Mesh.ARRAY_TEX_UV] = b.uv
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, b.mat)
		st.surfaces_out += 1
	if am.get_surface_count() == 0: return st
	var out := MeshInstance3D.new(); out.name = "OWMerged"; out.mesh = am; out.set_meta("no_merge", true); out.set_meta("ow_merged_mesh", true)
	if range_end > 0.0: out.visibility_range_end = range_end; out.visibility_range_end_margin = range_margin
	root.add_child(out)
	for g in used: (g as GeometryInstance3D).visible = false; g.set_meta("ow_merged_src", true)
	st.meshes = used.size()
	return st
