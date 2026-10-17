## v34 open world (blue): simple, cheap street fronts for the café and the shop (from outside they were plain white boxes).
##   WorldFacades.build(place_node, "cafe" | "shop", wf := null)
## On the front wall (place-local +z, the door side): coloured plaster skin, plinth, cornice, two framed windows, a door
## frame, a striped awning over the door and a sign board with the name (Label3D). Low-poly boxes with shared materials
## (one material per colour). The parts lying on the front wall fade WITH it (registered in the same wall_fade occluder
## group when `wf` is given); the awning / sign hang above head height and stay. The door leaf is never touched.
class_name WorldFacades
extends RefCounted

const STYLE := {
	"cafe": {"wall": Color(0.78, 0.55, 0.38), "trim": Color(0.96, 0.92, 0.84), "a": Color(0.72, 0.16, 0.14), "b": Color(0.97, 0.95, 0.9),
		"sign": Color(0.25, 0.16, 0.1), "text": "CAFÉ", "tc": Color(1.0, 0.9, 0.6)},
	"shop": {"wall": Color(0.55, 0.7, 0.62), "trim": Color(0.95, 0.96, 0.94), "a": Color(0.16, 0.5, 0.26), "b": Color(0.96, 0.97, 0.94),
		"sign": Color(0.12, 0.3, 0.18), "text": "SHOP", "tc": Color(1.0, 1.0, 1.0)},
}
const GLASS := Color(0.32, 0.45, 0.58)
static var _mats := {}

static func _m(c: Color) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.8; _mats[c] = m
	return _mats[c]

static func _box(parent: Node3D, s: Vector3, p: Vector3, c: Color, rot_x := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.material_override = _m(c)
	mi.position = p; mi.rotation.x = rot_x; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; parent.add_child(mi)
	return mi

static func build(n: Node3D, id: String, wf: Node = null) -> Node3D:
	if n == null or not STYLE.has(id) or n.has_node("OWFacade"): return null
	var S: Dictionary = STYLE[id]
	var rm: Vector2 = n.get("room") if n.get("room") is Vector2 else Vector2(10, 8)
	var hx := rm.x / 2.0; var hz := rm.y / 2.0
	var gap := 0.65                       # World._cut_place_door: 1.3 m opening
	var z := hz + 0.07 + 0.02             # just outside the 0.14 m front wall
	var root := Node3D.new(); root.name = "OWFacade"; n.add_child(root)
	var flat := Node3D.new(); flat.name = "OnWall"; root.add_child(flat)     # fades with the front wall
	var hang := Node3D.new(); hang.name = "Hanging"; root.add_child(hang)    # awning + sign (above head height)
	var w := hx - gap
	for sx in [-1.0, 1.0]:
		var cx: float = sx * (gap + w / 2.0)
		_box(flat, Vector3(w, 3.0, 0.03), Vector3(cx, 1.5, z), S.wall)                      # plaster skin
		_box(flat, Vector3(w, 0.4, 0.05), Vector3(cx, 0.2, z + 0.02), (S.wall as Color).darkened(0.35))   # plinth
		var ww := minf(2.2, w - 0.8)
		if ww > 0.6:
			_box(flat, Vector3(ww + 0.16, 1.46, 0.04), Vector3(cx, 1.45, z + 0.02), S.trim)   # window frame
			_box(flat, Vector3(ww, 1.3, 0.05), Vector3(cx, 1.45, z + 0.03), GLASS)            # glass
			_box(flat, Vector3(ww + 0.3, 0.08, 0.14), Vector3(cx, 0.72, z + 0.07), S.trim)    # sill
	_box(flat, Vector3(gap * 2.0, 0.8, 0.03), Vector3(0, 2.6, z), S.wall)                    # over the door
	for sx in [-1.0, 1.0]: _box(flat, Vector3(0.1, 2.25, 0.06), Vector3(sx * (gap + 0.05), 1.125, z + 0.02), S.trim)   # door frame
	_box(flat, Vector3(gap * 2.0 + 0.2, 0.1, 0.06), Vector3(0, 2.25, z + 0.02), S.trim)
	_box(flat, Vector3(rm.x + 0.1, 0.22, 0.18), Vector3(0, 3.0, z + 0.06), S.trim)          # cornice
	# awning: 7 stripes, sloping down and out over the door + windows
	var aw := minf(rm.x - 0.6, 6.0); var k := 7; var sw := aw / k
	for i in k:
		_box(hang, Vector3(sw, 0.04, 1.0), Vector3(-aw / 2.0 + sw * (i + 0.5), 2.5, z + 0.48), S.a if i % 2 == 0 else S.b, 0.35)
	_box(hang, Vector3(aw, 0.18, 0.03), Vector3(0, 2.25, z + 0.96), S.a)                     # valance
	# sign board + name
	_box(hang, Vector3(2.4, 0.42, 0.06), Vector3(0, 2.78, z + 0.05), S.sign)
	var lb := Label3D.new(); lb.text = String(S.text); lb.font_size = 96; lb.pixel_size = 0.0032; lb.modulate = S.tc
	lb.outline_size = 0; lb.position = Vector3(0, 2.78, z + 0.09); lb.visibility_range_end = 45.0; lb.shaded = false
	hang.add_child(lb)
	if wf and wf.has_method("register_occluder"):
		var key := "ow_front_" + id
		for g in n.get_children():   # the front wall pieces (thin tall boxes at local z = hz), never the door leaf
			if g is MeshInstance3D and (g as MeshInstance3D).visible and (g as MeshInstance3D).mesh is BoxMesh and absf((g as Node3D).position.z - hz) < 0.15:
				wf.register_occluder(g, {"group": key})
		wf.register_occluder(flat, {"group": key, "no_cam": true})
	return root
