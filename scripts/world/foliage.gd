## Foliage + street-furniture meshes for MultiMesh instancing (one cached ArrayMesh each, vertex coloured,
## one shared matte material). CityBlock collects instance transforms per type -> 1 draw call per type per block.
class_name Foliage
extends RefCounted

static var _cache := {}
static var _glow_mat: StandardMaterial3D

## type -> [mesh builder, cast shadows, visibility range end (0 = always), uses instance colours]
const TYPES := {
	"tree_round": [true, 0.0, false], "tree_pine": [true, 0.0, false], "tree_birch": [true, 0.0, false],
	"bush": [true, 60.0, true], "flower": [false, 24.0, true], "tuft": [false, 20.0, false],
	"lamp": [true, 0.0, false], "lamp_glow": [false, 0.0, false],
}

static func mesh(t: String) -> ArrayMesh:
	if _cache.has(t): return _cache[t]
	var k := MeshKit.new()
	match t:
		"tree_round":
			k.cyl(0.12, 1.6, Vector3(0, 0.8, 0), Color(0.55, 0.42, 0.32), 6, 0.09)
			k.sphere(1.05, Vector3(0, 2.4, 0), Color(0.50, 0.66, 0.48), 0.9, 8, 5)
			k.sphere(0.7, Vector3(0.35, 3.05, 0.15), Color(0.56, 0.72, 0.52), 0.9, 8, 4)
		"tree_pine":
			k.cyl(0.11, 1.0, Vector3(0, 0.5, 0), Color(0.50, 0.38, 0.30), 6, 0.08)
			for i in 3: k.cyl(1.1 - i * 0.3, 1.2, Vector3(0, 1.3 + i * 0.75, 0), Color(0.36, 0.55, 0.45).lightened(i * 0.05), 8, 0.12)
		"tree_birch":
			k.cyl(0.08, 2.6, Vector3(0, 1.3, 0), Color(0.93, 0.92, 0.88), 6, 0.06)
			for i in 3: k.box(Vector3(0.17, 0.04, 0.17), Vector3(0, 0.5 + i * 0.7, 0), Color(0.25, 0.25, 0.27))
			k.sphere(0.8, Vector3(0, 3.0, 0), Color(0.66, 0.78, 0.50), 1.25, 8, 5)
		"bush":
			k.sphere(0.5, Vector3(0, 0.35, 0), Color(1, 1, 1), 0.8, 7, 4)
			k.sphere(0.36, Vector3(0.32, 0.3, 0.1), Color(0.92, 0.94, 0.92), 0.8, 7, 4)
		"flower":
			k.cyl(0.012, 0.32, Vector3(0, 0.16, 0), Color(0.45, 0.62, 0.40), 4)
			k.sphere(0.07, Vector3(0, 0.34, 0), Color(1, 1, 1), 0.6, 6, 3)
			k.box(Vector3(0.12, 0.01, 0.05), Vector3(0.0, 0.22, 0.0), Color(0.5, 0.68, 0.45), 0.6)
		"tuft":
			for i in 3: k.box(Vector3(0.025, 0.18, 0.01), Vector3(-0.04 + i * 0.04, 0.08, 0), Color(0.32, 0.50, 0.28).lightened(i * 0.05), i * 0.9)
		"lamp":
			var dk := Color(0.22, 0.23, 0.26)
			k.cyl(0.07, 4.2, Vector3(0, 2.1, 0), dk, 8, 0.05)
			k.cyl(0.13, 0.3, Vector3(0, 0.15, 0), dk, 8, 0.1)
			k.box(Vector3(0.08, 0.08, 0.9), Vector3(0, 4.15, -0.45), dk)
			k.box(Vector3(0.28, 0.1, 0.5), Vector3(0, 4.1, -0.85), dk)
		"lamp_glow":
			k.box(Vector3(0.22, 0.03, 0.42), Vector3(0, 4.04, -0.85), Color(1.0, 0.93, 0.75))
	var m := k.mesh()
	if t == "lamp_glow": m.surface_set_material(0, glow_material())
	_cache[t] = m; return m

static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new(); _glow_mat.albedo_color = Color(1.0, 0.93, 0.75)
		_glow_mat.emission_enabled = true; _glow_mat.emission = Color(1.0, 0.85, 0.55); _glow_mat.emission_energy_multiplier = 0.3
	return _glow_mat

static func set_night(on: bool) -> void: glow_material().emission_energy_multiplier = 4.0 if on else 0.3
