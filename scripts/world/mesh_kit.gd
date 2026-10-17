## MeshKit: merges many coloured boxes / primitives into ONE ArrayMesh (vertex colours, one matte material).
## A whole city block becomes 1-3 draw calls instead of hundreds. Same look as 3dv2's box() + _mat() (roughness 0.85).
##   var k := MeshKit.new(); k.box(size, pos, color); k.prism(...); var mi := k.commit(parent)
class_name MeshKit
extends RefCounted

var st := SurfaceTool.new()
var count := 0
static var _mat_cache: StandardMaterial3D

func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

static func material() -> StandardMaterial3D:
	if _mat_cache == null:
		_mat_cache = StandardMaterial3D.new(); _mat_cache.vertex_color_use_as_albedo = true; _mat_cache.vertex_color_is_srgb = true; _mat_cache.metallic_specular = 0.12; _mat_cache.roughness = 0.85
	return _mat_cache

## append any PrimitiveMesh (BoxMesh, CylinderMesh, SphereMesh, PrismMesh...) with a transform and a colour
func add(pm: PrimitiveMesh, xf: Transform3D, c: Color) -> void:
	var a := pm.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	st.set_color(c)
	if idx.is_empty():
		for i in v.size(): st.set_normal((nb * n[i]).normalized()); st.add_vertex(xf * v[i])
	else:
		for i in idx: st.set_normal((nb * n[i]).normalized()); st.add_vertex(xf * v[i])
	count += 1

func box(size: Vector3, pos: Vector3, c: Color, yaw := 0.0) -> void:
	var bm := BoxMesh.new(); bm.size = size
	add(bm, Transform3D(Basis(Vector3.UP, yaw), pos), c)

## gable roof: ridge along local X. size = (length, height, depth)
func prism(size: Vector3, pos: Vector3, c: Color, yaw := 0.0) -> void:
	var pm := PrismMesh.new(); pm.size = Vector3(size.z, size.y, size.x)
	add(pm, Transform3D(Basis(Vector3.UP, yaw + PI / 2), pos), c)

func cyl(r: float, h: float, pos: Vector3, c: Color, seg := 8, r_top := -1.0) -> void:
	var cm := CylinderMesh.new(); cm.bottom_radius = r; cm.top_radius = r if r_top < 0 else r_top; cm.height = h
	cm.radial_segments = seg; cm.rings = 1
	add(cm, Transform3D(Basis(), pos), c)

func sphere(r: float, pos: Vector3, c: Color, sy := 1.0, seg := 8, rings := 5) -> void:
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = seg; sm.rings = rings
	add(sm, Transform3D(Basis().scaled(Vector3(1, sy, 1)), pos), c)

func mesh() -> ArrayMesh:
	var m := st.commit(); if m.get_surface_count() > 0: m.surface_set_material(0, material())
	return m

func commit(parent: Node, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh(); parent.add_child(mi)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
