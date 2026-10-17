## v305: bedroom decoration (static, low poly, no lights, no collisions / no obstacles added).
## Called once from main.gd _ready(): load("res://scripts/decor/decor_bedroom.gd").build(self)
## Everything sits on the back wall, on top of furniture or flat on the floor, so walk routes, the bed, mirror,
## bedside table / phone, plant, desk, bookcase, door and window stay free. Roof / front wall are not touched.
extends RefCounted

const BZ := -2.965   # back wall face (posters sit at -2.97)

static func build(m: Node3D) -> void:
	var root := Node3D.new(); root.name = "DecorBedroom"; m.add_child(root)
	_clock(root, Vector3(-0.2, 1.95, BZ + 0.03))
	# two small framed prints above the bedside lamp (back wall, left corner)
	_frame(root, Vector3(-2.95, 1.85, BZ), Vector2(0.32, 0.42), Color(0.55, 0.72, 0.85), Color(0.95, 0.8, 0.45))
	_frame(root, Vector3(-2.5, 1.55, BZ), Vector2(0.36, 0.28), Color(0.93, 0.62, 0.55), Color(0.4, 0.6, 0.45))
	# triangle bunting along the top of the back wall over the bed
	var cols := [Color(0.95, 0.45, 0.4), Color(0.98, 0.82, 0.35), Color(0.4, 0.7, 0.9), Color(0.5, 0.78, 0.55), Color(0.85, 0.6, 0.85)]
	_box(root, Vector3(2.7, 0.006, 0.006), Vector3(-1.95, 2.33, BZ + 0.02), Color(0.3, 0.3, 0.3))
	for i in 12:
		var t := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.14, 0.17, 0.005); t.mesh = pm
		t.rotation.z = PI; t.position = Vector3(-3.2 + i * 0.23, 2.24 - absf(i - 5.5) * -0.004, BZ + 0.025)
		t.material_override = _mat(cols[i % cols.size()]); t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(t)
	# storage boxes + a stack of books on top of the wardrobe (top at y 2.18)
	_box(root, Vector3(0.4, 0.22, 0.38), Vector3(-3.2, 2.29, -0.35), Color(0.82, 0.7, 0.52))
	_box(root, Vector3(0.36, 0.18, 0.34), Vector3(-3.2, 2.27, 0.1), Color(0.55, 0.68, 0.78))
	for i in 3: _box(root, Vector3(0.24, 0.045, 0.17), Vector3(-3.2, 2.205 + i * 0.047, 0.42), [Color(0.8, 0.3, 0.3), Color(0.25, 0.45, 0.7), Color(0.95, 0.85, 0.5)][i]).rotation.y = i * 0.25
	# radio on the floating shelf over the desk (between the books and the plant)
	if ResourceLoader.exists(m.FURN + "radio.glb"): m.prop("radio", Vector3(2.79, 1.215, -2.88), 0, 0.0, 0.18, root)
	# floor lamp in the free front-right corner (no light, no obstacle)
	if ResourceLoader.exists(m.FURN + "lampRoundFloor.glb"): m.prop("lampRoundFloor", Vector3(3.2, 0, 2.75), 0, 1.45, 0.0, root)
	# flat striped rug under the desk chair (floor only, 4 mm)
	for i in 5: _box(root, Vector3(1.3, 0.004, 0.18), Vector3(2.7, 0.004, -2.0 + i * 0.18), Color(0.86, 0.78, 0.68) if i % 2 == 0 else Color(0.62, 0.72, 0.8))
	# floor cushion in the free front-left area (between mirror and room middle), thin, no obstacle
	if ResourceLoader.exists(m.FURN + "pillowBlue.glb"): m.prop("pillowBlue", Vector3(-1.9, 0.0, 2.75), 20, 0.12, 0.0, root)
	for c in root.find_children("*", "MeshInstance3D", true, false):
		if (c as MeshInstance3D).position.y < 0.01: (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _mat(c: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new(); mt.albedo_color = c; mt.roughness = 0.85; return mt

static func _box(p: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(c); mi.position = pos; p.add_child(mi); return mi

## simple framed print: dark frame, light mat, two flat colour shapes
static func _frame(p: Node3D, pos: Vector3, size: Vector2, a: Color, b: Color) -> void:
	_box(p, Vector3(size.x + 0.04, size.y + 0.04, 0.02), pos, Color(0.2, 0.17, 0.15))
	_box(p, Vector3(size.x, size.y, 0.004), pos + Vector3(0, 0, 0.012), Color(0.97, 0.96, 0.93))
	_box(p, Vector3(size.x * 0.7, size.y * 0.45, 0.003), pos + Vector3(0, -size.y * 0.12, 0.016), a)
	var s := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = size.x * 0.13; sm.height = size.x * 0.26; sm.radial_segments = 12; sm.rings = 6
	s.mesh = sm; s.scale = Vector3(1, 1, 0.05); s.position = pos + Vector3(size.x * 0.18, size.y * 0.22, 0.016); s.material_override = _mat(b); p.add_child(s)

## round wall clock with hands at 07:00
static func _clock(p: Node3D, pos: Vector3) -> void:
	var rim := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.17; cy.bottom_radius = 0.17; cy.height = 0.04; cy.radial_segments = 24
	rim.mesh = cy; rim.rotation.x = PI / 2; rim.position = pos; rim.material_override = _mat(Color(0.25, 0.3, 0.4)); p.add_child(rim)
	var face := MeshInstance3D.new(); var cf := CylinderMesh.new(); cf.top_radius = 0.15; cf.bottom_radius = 0.15; cf.height = 0.01; cf.radial_segments = 24
	face.mesh = cf; face.rotation.x = PI / 2; face.position = pos + Vector3(0, 0, 0.021); face.material_override = _mat(Color(0.98, 0.97, 0.94)); p.add_child(face)
	for i in 12:
		var a := i * TAU / 12.0
		_box(p, Vector3(0.012, 0.03 if i % 3 == 0 else 0.015, 0.004), pos + Vector3(sin(a) * 0.125, cos(a) * 0.125, 0.028), Color(0.2, 0.2, 0.22)).rotation.z = -a
	var hh := _box(p, Vector3(0.014, 0.07, 0.004), pos + Vector3(0, 0, 0.032), Color(0.15, 0.15, 0.17)); hh.rotation.z = -7 * TAU / 12.0
	hh.position += Vector3(sin(7 * TAU / 12.0) * 0.035, cos(7 * TAU / 12.0) * 0.035, 0)
	var mh := _box(p, Vector3(0.01, 0.11, 0.004), pos + Vector3(0, 0.055, 0.034), Color(0.15, 0.15, 0.17))
