## Decor pass for the living room / dining / kitchen corner (decor-living branch).
## Purely visual: MeshInstance3D only, no collision bodies, no obstacles, no lights (emissive shades only).
## Wall props are mounted ONLY on the north wall (z = -3.0), which is never faded by the side-wall cutaway.
## All meshes are procedural (Godot primitive meshes) - no external assets.
extends RefCounted

const WALL_Z := -2.95

static func build(room: Node3D) -> void:
	var root := Node3D.new(); root.name = "DecorLiving"; room.add_child(root)
	var wood := Color(0.72, 0.56, 0.40); var cream := Color(0.95, 0.90, 0.80); var coral := Color(0.93, 0.52, 0.44)
	var blue := Color(0.40, 0.56, 0.76); var sage := Color(0.62, 0.74, 0.70); var white := Color(1, 1, 1); var dark := Color(0.16, 0.16, 0.18)
	# --- rug under the dining table (flat, below the table's walk obstacle) + door mat
	_box(root, Vector3(2.3, 0.01, 1.9), Vector3(5.6, 0.005, 0.9), sage.darkened(0.1))
	_box(root, Vector3(2.1, 0.012, 1.7), Vector3(5.6, 0.007, 0.9), cream)
	for z in [0.25, 1.55]: _box(root, Vector3(1.9, 0.013, 0.03), Vector3(5.6, 0.008, z), coral.lightened(0.2))
	_box(root, Vector3(0.9, 0.012, 0.45), Vector3(2.35, 0.006, 2.7), Color(0.55, 0.42, 0.3))
	# --- floating book shelf under the clock (north wall, west of the light switch)
	var s := Vector3(0.45, 1.42, WALL_Z + 0.08)
	_box(root, Vector3(0.62, 0.025, 0.16), s, wood)
	var bx := s.x - 0.26
	for i in 7:
		var h: float = [0.2, 0.17, 0.22, 0.18, 0.2, 0.16, 0.19][i]
		_box(root, Vector3(0.035, h, 0.12), Vector3(bx, s.y + 0.0125 + h / 2, s.z), [coral, blue, cream, sage, dark, coral.darkened(0.2), blue.lightened(0.3)][i])
		bx += 0.04
	var lean := _box(root, Vector3(0.035, 0.18, 0.12), Vector3(bx + 0.04, s.y + 0.1, s.z), cream.darkened(0.15)); lean.rotation.z = -0.35
	_cyl(root, 0.035, 0.14, Vector3(s.x + 0.2, s.y + 0.08, s.z), blue.lightened(0.2))
	# --- picture frames between the bedroom door and the big plant
	_frame(root, Vector3(2.62, 1.7, WALL_Z), Vector2(0.32, 0.42), wood, sage.lightened(0.15), coral)
	_frame(root, Vector3(2.98, 1.85, WALL_Z), Vector2(0.24, 0.24), white, blue.lightened(0.2), cream)
	# --- emissive wall sconces flanking the dining area (no light nodes)
	for x in [4.75, 7.0]:
		_box(root, Vector3(0.06, 0.12, 0.04), Vector3(x, 1.78, WALL_Z + 0.02), dark)
		var sh := _cone(root, 0.05, 0.08, 0.13, Vector3(x, 1.86, WALL_Z + 0.09), Color(1.0, 0.88, 0.65)); _emit(sh, Color(1.0, 0.85, 0.6), 1.6)
	# --- kitchen wall shelves (east of the bathroom door): jars, plates, kettle, fruit bowl
	var kx := 6.98
	for y in [1.25, 1.62]: _box(root, Vector3(0.78, 0.025, 0.2), Vector3(kx, y, WALL_Z + 0.1), wood)
	for k in 3:   # jars with lids (bottom shelf)
		var jp := Vector3(kx - 0.28 + k * 0.13, 1.2625, WALL_Z + 0.1)
		var jh: float = [0.16, 0.12, 0.14][k]
		_cyl(root, 0.045, jh, jp + Vector3(0, jh / 2, 0), [Color(0.95, 0.85, 0.55), Color(0.7, 0.45, 0.3), Color(0.9, 0.9, 0.85)][k], 0.75)
		_cyl(root, 0.048, 0.02, jp + Vector3(0, jh + 0.01, 0), wood.darkened(0.2))
	# kettle (bottom shelf, right)
	var kt := Vector3(kx + 0.2, 1.2625, WALL_Z + 0.1)
	_cone(root, 0.055, 0.075, 0.14, kt + Vector3(0, 0.07, 0), coral)
	_cyl(root, 0.03, 0.02, kt + Vector3(0, 0.15, 0), dark)
	var sp := _cyl(root, 0.012, 0.09, kt + Vector3(-0.08, 0.08, 0), coral); sp.rotation.z = 0.9
	var hd := _box(root, Vector3(0.1, 0.02, 0.02), kt + Vector3(0, 0.17, 0), dark)
	# plates standing on the top shelf + a fruit bowl
	for k in 3:
		var pl := _cyl(root, 0.09, 0.012, Vector3(kx - 0.28 + k * 0.03, 1.725, WALL_Z + 0.06), [white, blue.lightened(0.35), white][k]); pl.rotation.x = PI / 2 - 0.12
	var bowl := _cyl(root, 0.11, 0.06, Vector3(kx + 0.15, 1.663, WALL_Z + 0.1), cream); (bowl.mesh as CylinderMesh).bottom_radius = 0.06
	for k in 4:
		_ball(root, 0.035, Vector3(kx + 0.15 + [0.04, -0.04, 0.0, 0.03][k], 1.71 + (0.03 if k == 2 else 0.0), WALL_Z + 0.1 + [0.03, 0.01, -0.02, -0.04][k]), [Color(0.9, 0.3, 0.25), Color(0.98, 0.65, 0.2), Color(0.95, 0.85, 0.3), Color(0.5, 0.75, 0.3)][k])
	# small pot plant (trailing leaves) at the shelf end
	_cyl(root, 0.04, 0.07, Vector3(kx - 0.05, 1.6675, WALL_Z + 0.1), white)
	for k in 5: _ball(root, 0.03, Vector3(kx - 0.05 + (k - 2) * 0.02, 1.72 - abs(k - 2) * 0.03, WALL_Z + 0.12), Color(0.35, 0.6, 0.32))
	# --- sideboard tray with teapot + cups (top at y 0.76, kept away from the fish-bowl spot x 4.2)
	_box(root, Vector3(0.28, 0.012, 0.18), Vector3(3.62, 0.766, -2.72), wood.darkened(0.15))
	_ball(root, 0.05, Vector3(3.58, 0.815, -2.72), white)
	for k in 2: _cyl(root, 0.022, 0.04, Vector3(3.68, 0.792, -2.77 + k * 0.08), [coral, blue][k])

static func _mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c.r, c.g, c.b, alpha); m.roughness = 0.85
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _mi(root: Node3D, mesh: Mesh, pos: Vector3, c: Color, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = _mat(c, alpha); mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(mi); return mi

static func _box(root: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := BoxMesh.new(); m.size = size; return _mi(root, m, pos, c)

static func _cyl(root: Node3D, r: float, h: float, pos: Vector3, c: Color, alpha := 1.0) -> MeshInstance3D:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = h; m.radial_segments = 12; m.rings = 1
	return _mi(root, m, pos, c, alpha)

static func _cone(root: Node3D, rt: float, rb: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h; m.radial_segments = 12; m.rings = 1
	return _mi(root, m, pos, c)

static func _ball(root: Node3D, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2; m.radial_segments = 10; m.rings = 6
	return _mi(root, m, pos, c)

static func _emit(mi: MeshInstance3D, c: Color, e: float) -> void:
	var m: StandardMaterial3D = mi.material_override; m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = e

static func _frame(root: Node3D, pos: Vector3, sz: Vector2, fc: Color, bg: Color, accent: Color) -> void:
	_box(root, Vector3(sz.x + 0.04, sz.y + 0.04, 0.02), pos, fc)
	_box(root, Vector3(sz.x - 0.02, sz.y - 0.02, 0.004), pos + Vector3(0, 0, 0.011), bg)
	_ball(root, minf(sz.x, sz.y) * 0.18, pos + Vector3(-sz.x * 0.12, sz.y * 0.12, 0.012), accent).scale = Vector3(1, 1, 0.05)
	_box(root, Vector3(sz.x - 0.06, sz.y * 0.25, 0.004), pos + Vector3(0, -sz.y * 0.3, 0.014), bg.darkened(0.25))
