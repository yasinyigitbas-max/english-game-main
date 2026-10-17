## CarKit (v32): builds polished low-poly procedural vehicles for Vehicle (traffic car + bus) and StreetObject ("my car").
## Everything merges into ONE ArrayMesh with 4 surfaces (= 4 draw calls) + 1 blob-shadow quad:
##   0 paint  : vertex colour, metallic 0.5 / roughness 0.3 (body paint + chrome rims/trim)
##   1 trim   : vertex colour, matte (tyres, grille, bumpers, plates, door seams)
##   2 glass  : dark tinted, glossy, opaque (cheap on mobile)
##   3 lights : vertex colour, unshaded (always-bright head/tail lights)
## Materials are static and shared by every vehicle, so batching stays friendly on the mobile renderer.
##   var ck := CarKit.new(); ck.car(color, cabin_z, variant); ck.commit(parent); CarKit.add_shadow(root, size)
class_name CarKit
extends RefCounted

enum { PAINT, TRIM, GLASS, LIGHT }
var sts: Array = []
var used := [false, false, false, false]
static var _mats: Array = []
static var _shadow_mat: StandardMaterial3D

const TYRE := Color(0.06, 0.06, 0.07)
const CHROME := Color(0.82, 0.83, 0.85)
const RIM := Color(0.70, 0.72, 0.75)
const BLACK_TRIM := Color(0.10, 0.10, 0.11)
const PLATE := Color(0.94, 0.94, 0.92)
const PLATE_BLUE := Color(0.10, 0.22, 0.60)
const HEAD := Color(1.0, 0.97, 0.86)
const TAIL := Color(0.90, 0.06, 0.05)
const AMBER := Color(1.0, 0.55, 0.08)
## realistic car paints; any requested colour is snapped to the nearest one
const PAINTS := [
	Color(0.60, 0.05, 0.06),  # cherry red
	Color(0.90, 0.90, 0.88),  # pearl white
	Color(0.05, 0.05, 0.06),  # black
	Color(0.62, 0.64, 0.67),  # silver
	Color(0.30, 0.31, 0.33),  # gunmetal grey
	Color(0.07, 0.14, 0.34),  # navy
	Color(0.14, 0.36, 0.66),  # ocean blue
	Color(0.07, 0.26, 0.17),  # racing green
	Color(0.70, 0.60, 0.44),  # champagne beige
	Color(0.80, 0.32, 0.10),  # burnt orange
	Color(0.95, 0.74, 0.12),  # taxi yellow
]

func _init() -> void:
	for i in 4:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); sts.append(st)

static func paint_for(c: Color) -> Color:
	var best: Color = PAINTS[0]; var bd := INF
	for p in PAINTS:
		var pc: Color = p
		var d := Vector3(pc.r - c.r, pc.g - c.g, pc.b - c.b).length_squared()
		if d < bd: bd = d; best = pc
	return best

static func materials() -> Array:
	if _mats.is_empty():
		var paint := StandardMaterial3D.new(); paint.vertex_color_use_as_albedo = true; paint.vertex_color_is_srgb = true
		paint.metallic = 0.5; paint.roughness = 0.3; paint.metallic_specular = 0.6
		var trim := StandardMaterial3D.new(); trim.vertex_color_use_as_albedo = true; trim.vertex_color_is_srgb = true
		trim.metallic_specular = 0.2; trim.roughness = 0.75
		var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.07, 0.09, 0.12)
		glass.metallic = 0.6; glass.roughness = 0.08; glass.metallic_specular = 0.9
		var light := StandardMaterial3D.new(); light.vertex_color_use_as_albedo = true; light.vertex_color_is_srgb = true
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats = [paint, trim, glass, light]
	return _mats

# ------------------------------------------------------------------ low-level geometry
## one triangle with a flat outward normal n (Godot front faces are clockwise -> fix winding from n)
func _tri(s: int, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	var st: SurfaceTool = sts[s]; used[s] = true
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b; b = c; c = t
	st.set_color(col); st.set_normal(n)
	st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)

## quad a-b-c-d (in order around its edge); normal points away from 'inside'
func _quad(s: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10: n = (c - a).cross(d - a)
	if n.length_squared() < 1e-10: return
	n = n.normalized()
	if n.dot((a + b + c + d) * 0.25 - inside) < 0.0: n = -n
	_tri(s, a, b, c, n, col); _tri(s, a, c, d, n, col)

## append a PrimitiveMesh with transform (same as MeshKit.add) into surface s
func prim(s: int, pm: PrimitiveMesh, xf: Transform3D, col: Color) -> void:
	var st: SurfaceTool = sts[s]; used[s] = true
	var a := pm.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]; var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	st.set_color(col)
	if idx.is_empty():
		for i in v.size(): st.set_normal((nb * n[i]).normalized()); st.add_vertex(xf * v[i])
	else:
		for i in idx: st.set_normal((nb * n[i]).normalized()); st.add_vertex(xf * v[i])

func box(s: int, size: Vector3, pos: Vector3, col: Color) -> void:
	var bm := BoxMesh.new(); bm.size = size
	prim(s, bm, Transform3D(Basis(), pos), col)

## cylinder whose axis is local X (wheels, hubcaps, arches)
func cyl_x(s: int, r: float, w: float, pos: Vector3, col: Color, seg := 12) -> void:
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = w; cm.radial_segments = seg; cm.rings = 1
	prim(s, cm, Transform3D(Basis(Vector3(0, 0, 1), PI / 2), pos), col)

## thin bar from a to b (pillars, mirror arms)
func strip(s: int, a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var d := b - a; var l := d.length()
	if l < 0.001: return
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	var bm := BoxMesh.new(); bm.size = Vector3(thick, thick, l)
	prim(s, bm, Transform3D(Basis.looking_at(d, up), (a + b) * 0.5), col)

## eight-corner solid: bottom b[0..3], top t[0..3] in the same order around (tapered cabins, roofs)
func hexa(s: int, b: Array, t: Array, col: Color) -> void:
	var c := Vector3.ZERO
	for p in b + t: c += p
	c /= 8.0
	_quad(s, b[0], b[1], b[2], b[3], c, col)
	_quad(s, t[0], t[1], t[2], t[3], c, col)
	for i in 4:
		var j := (i + 1) % 4
		_quad(s, b[i], b[j], t[j], t[i], c, col)

## rounded body: convex side profile (Vector2(z, y) list) extruded along X over width w, with bevelled
## edges (the outer rings are the profile shrunk by 'bev') so every silhouette edge looks rounded.
func body_loft(s: int, prof: Array, w: float, bev: float, col: Color) -> void:
	var c2 := Vector2.ZERO
	for p in prof: c2 += p
	c2 /= float(prof.size())
	var zmin := INF; var zmax := -INF; var ymin := INF; var ymax := -INF
	for p in prof: zmin = minf(zmin, p.x); zmax = maxf(zmax, p.x); ymin = minf(ymin, p.y); ymax = maxf(ymax, p.y)
	var kz := 1.0 - 2.0 * bev / maxf(zmax - zmin, 0.01); var ky := 1.0 - 2.0 * bev / maxf(ymax - ymin, 0.01)
	var inner: Array = []
	for p in prof: inner.append(Vector2(c2.x + (p.x - c2.x) * kz, c2.y + (p.y - c2.y) * ky))
	var hw := w * 0.5
	var rings := [[inner, -hw], [prof, -hw + bev], [prof, hw - bev], [inner, hw]]
	var centre := Vector3(0, c2.y, c2.x)
	var n := prof.size()
	for r in 3:
		var pa: Array = rings[r][0]; var xa: float = rings[r][1]
		var pb: Array = rings[r + 1][0]; var xb: float = rings[r + 1][1]
		for i in n:
			var j := (i + 1) % n
			var a0 := Vector3(xa, pa[i].y, pa[i].x); var a1 := Vector3(xa, pa[j].y, pa[j].x)
			var b0 := Vector3(xb, pb[i].y, pb[i].x); var b1 := Vector3(xb, pb[j].y, pb[j].x)
			_quad(s, a0, a1, b1, b0, centre, col)
	for side in [-1.0, 1.0]:
		var x: float = side * hw; var nn := Vector3(side, 0, 0)
		var cc := Vector3(x, c2.y, c2.x)
		for i in n:
			var j := (i + 1) % n
			_tri(s, cc, Vector3(x, inner[i].y, inner[i].x), Vector3(x, inner[j].y, inner[j].x), nn, col)

## wheel: tyre, silver rim, hubcap, and a dark wheel-arch disc set into the body side
func wheel(x: float, y: float, z: float, r: float, w: float, arch_x: float) -> void:
	var sd := signf(x)
	cyl_x(TRIM, r * 1.22, 0.02, Vector3(arch_x * sd, y + r * 0.08, z), BLACK_TRIM, 14)       # arch shadow
	cyl_x(TRIM, r, w, Vector3(x, y, z), TYRE, 14)                                                  # tyre
	cyl_x(PAINT, r * 0.64, 0.02, Vector3(x + sd * (w * 0.5 + 0.005), y, z), RIM, 12)               # rim
	cyl_x(TRIM, r * 0.50, 0.012, Vector3(x + sd * (w * 0.5 + 0.014), y, z), Color(0.32, 0.33, 0.35), 10)  # rim well
	for k in 5:                                                                                     # spokes
		var ang := TAU * float(k) / 5.0
		var o := Vector3(x + sd * (w * 0.5 + 0.018), y, z)
		strip(PAINT, o, o + Vector3(0, sin(ang), cos(ang)) * r * 0.5, 0.045, RIM)
	cyl_x(PAINT, r * 0.20, 0.03, Vector3(x + sd * (w * 0.5 + 0.024), y, z), CHROME, 10)             # hubcap

func plate(z: float, y: float, face: float) -> void:
	box(TRIM, Vector3(0.48, 0.12, 0.02), Vector3(0, y, z), PLATE)
	box(TRIM, Vector3(0.06, 0.11, 0.024), Vector3(-0.2, y, z), PLATE_BLUE)
	for i in 4: box(TRIM, Vector3(0.05, 0.06, 0.024), Vector3(-0.1 + 0.08 * i, y, z + face * 0.002), BLACK_TRIM)

# ------------------------------------------------------------------ vehicles
## passenger car, footprint 1.8 x 4.2 m, roof ~1.46 m, front = +Z. cz = cabin centre offset along Z.
## variant 0 = sedan, 1 = hatchback (same footprint).
func car(color: Color, cz := 0.0, variant := 0) -> void:
	var paint := paint_for(color)
	var prof := [Vector2(-2.06, 0.30), Vector2(2.06, 0.30), Vector2(2.12, 0.42), Vector2(2.10, 0.68), Vector2(1.95, 0.82),
		Vector2(1.20, 0.90), Vector2(-1.40, 0.92), Vector2(-2.02, 0.88), Vector2(-2.12, 0.70), Vector2(-2.12, 0.42)]
	body_loft(PAINT, prof, 1.80, 0.07, paint)
	# tapered cabin: dark glass greenhouse + painted roof + pillars
	var fb := cz + 1.05; var rb := cz - (1.35 if variant == 1 else 1.15)
	var ft := cz + 0.35; var rt := cz - (1.15 if variant == 1 else 0.80)
	var yb := 0.90; var yt := 1.40; var xb := 0.80; var xt := 0.66
	var B := [Vector3(-xb, yb, rb), Vector3(xb, yb, rb), Vector3(xb, yb, fb), Vector3(-xb, yb, fb)]
	var T := [Vector3(-xt, yt, rt), Vector3(xt, yt, rt), Vector3(xt, yt, ft), Vector3(-xt, yt, ft)]
	hexa(GLASS, B, T, Color.WHITE)
	var R0 := [Vector3(-xt - 0.02, yt - 0.03, rt - 0.03), Vector3(xt + 0.02, yt - 0.03, rt - 0.03), Vector3(xt + 0.02, yt - 0.03, ft + 0.03), Vector3(-xt - 0.02, yt - 0.03, ft + 0.03)]
	var R1 := [Vector3(-xt + 0.04, yt + 0.06, rt + 0.05), Vector3(xt - 0.04, yt + 0.06, rt + 0.05), Vector3(xt - 0.04, yt + 0.06, ft - 0.05), Vector3(-xt + 0.04, yt + 0.06, ft - 0.05)]
	hexa(PAINT, R0, R1, paint)
	for i in 4: strip(PAINT, B[i], T[i], 0.075, paint)                    # A and C pillars
	for sx in [-1.0, 1.0]:                                                # B pillar (black) + belt chrome
		strip(TRIM, Vector3(sx * (xb + 0.004), yb, (fb + rb) * 0.5), Vector3(sx * (xt + 0.004), yt, (ft + rt) * 0.5), 0.06, BLACK_TRIM)
		strip(PAINT, Vector3(sx * (xb + 0.006), yb + 0.01, rb), Vector3(sx * (xb + 0.006), yb + 0.01, fb), 0.02, CHROME)
	box(TRIM, Vector3(1.50, 0.02, 0.05), Vector3(0, yb + 0.005, fb + 0.01), BLACK_TRIM)   # wiper cowl
	# wheels + arches
	for wz in [-1.3, 1.3]:
		for wx in [-0.80, 0.80]: wheel(wx, 0.32, wz, 0.32, 0.22, 0.905)
	# side skirts, door seams, handles, mirrors
	for sx in [-1.0, 1.0]:
		box(TRIM, Vector3(0.03, 0.08, 1.9), Vector3(sx * 0.895, 0.36, 0.0), BLACK_TRIM)
		for dz in [cz + 0.95, cz - 0.05, cz - 1.05]:
			box(TRIM, Vector3(0.014, 0.46, 0.012), Vector3(sx * 0.903, 0.64, dz), Color(0.0, 0.0, 0.0, 1.0).lerp(paint, 0.25))
		for hz in [cz + 0.15, cz - 0.85]: box(PAINT, Vector3(0.025, 0.035, 0.13), Vector3(sx * 0.912, 0.80, hz), CHROME)
		strip(PAINT, Vector3(sx * 0.80, 0.94, cz + 0.92), Vector3(sx * 0.93, 0.98, cz + 0.90), 0.04, paint)
		box(PAINT, Vector3(0.10, 0.09, 0.07), Vector3(sx * 0.96, 0.99, cz + 0.90), paint)
		box(TRIM, Vector3(0.08, 0.07, 0.01), Vector3(sx * 0.96, 0.99, cz + 0.862), Color(0.25, 0.28, 0.32))
	# front: bumper, grille with chrome bar, headlights, indicators, plate
	box(TRIM, Vector3(1.84, 0.15, 0.14), Vector3(0, 0.38, 2.09), BLACK_TRIM)
	box(TRIM, Vector3(0.80, 0.15, 0.05), Vector3(0, 0.57, 2.115), Color(0.04, 0.04, 0.05))
	box(PAINT, Vector3(0.82, 0.025, 0.06), Vector3(0, 0.655, 2.11), CHROME)
	for gx in [-0.24, 0.0, 0.24]: box(PAINT, Vector3(0.02, 0.13, 0.055), Vector3(gx, 0.57, 2.118), Color(0.4, 0.41, 0.43))
	for sx in [-1.0, 1.0]:
		box(LIGHT, Vector3(0.34, 0.11, 0.06), Vector3(sx * 0.62, 0.62, 2.10), HEAD)
		box(PAINT, Vector3(0.38, 0.14, 0.05), Vector3(sx * 0.62, 0.62, 2.095), CHROME)
		box(LIGHT, Vector3(0.10, 0.05, 0.05), Vector3(sx * 0.80, 0.50, 2.10), AMBER)
	plate(2.17, 0.40, 1.0)
	# rear: bumper, taillights, reverse lights, plate
	box(TRIM, Vector3(1.84, 0.15, 0.14), Vector3(0, 0.38, -2.09), BLACK_TRIM)
	for sx in [-1.0, 1.0]:
		box(LIGHT, Vector3(0.36, 0.12, 0.06), Vector3(sx * 0.62, 0.70, -2.10), TAIL)
		box(LIGHT, Vector3(0.10, 0.12, 0.062), Vector3(sx * 0.40, 0.70, -2.10), Color(0.95, 0.95, 0.95))
	box(PAINT, Vector3(0.6, 0.03, 0.05), Vector3(0, 0.80, -2.09), CHROME)
	plate(-2.17, 0.42, -1.0)

## city bus, footprint 2.5 x 11 m, roof 3.0 m, front = +Z (doors and the route label are added by Vehicle)
func bus(color := Color(0.14, 0.36, 0.66)) -> void:
	var white := Color(0.94, 0.94, 0.92)
	var prof := [Vector2(-5.45, 0.35), Vector2(5.45, 0.35), Vector2(5.52, 0.50), Vector2(5.52, 2.60), Vector2(5.40, 2.95),
		Vector2(-5.40, 2.95), Vector2(-5.52, 2.60), Vector2(-5.52, 0.50)]
	body_loft(PAINT, prof, 2.50, 0.10, color)
	box(PAINT, Vector3(2.52, 0.34, 10.9), Vector3(0, 0.56, 0), white)                   # skirt band
	box(PAINT, Vector3(2.52, 0.08, 10.9), Vector3(0, 1.58, 0), white)                   # waist stripe
	box(GLASS, Vector3(2.53, 0.95, 9.6), Vector3(0, 2.15, -0.4), Color.WHITE)           # side windows
	var pz := -5.0
	while pz <= 4.3:
		box(PAINT, Vector3(2.545, 0.95, 0.09), Vector3(0, 2.15, pz), color); pz += 1.4
	box(GLASS, Vector3(2.30, 1.30, 0.05), Vector3(0, 1.95, 5.52), Color.WHITE)          # windshield
	box(PAINT, Vector3(2.34, 0.05, 0.06), Vector3(0, 1.30, 5.52), CHROME)
	box(TRIM, Vector3(1.60, 0.35, 0.06), Vector3(0, 2.75, 5.53), Color(0.03, 0.03, 0.04))  # destination display
	box(GLASS, Vector3(2.00, 0.80, 0.05), Vector3(0, 2.20, -5.52), Color.WHITE)         # rear window
	box(PAINT, Vector3(2.30, 0.12, 10.6), Vector3(0, 3.00, 0), white)                   # roof
	box(PAINT, Vector3(1.40, 0.25, 2.2), Vector3(0, 3.18, -1.0), Color(0.80, 0.81, 0.82))   # AC unit
	box(TRIM, Vector3(1.20, 0.02, 1.9), Vector3(0, 3.31, -1.0), Color(0.35, 0.36, 0.38))
	for wz in [-3.6, 3.4]:
		for wx in [-1.08, 1.08]: wheel(wx, 0.48, wz, 0.48, 0.30, 1.255)
	# bumpers, lights, grille, plates
	box(TRIM, Vector3(2.56, 0.30, 0.18), Vector3(0, 0.50, 5.50), BLACK_TRIM)
	box(TRIM, Vector3(2.56, 0.30, 0.18), Vector3(0, 0.50, -5.50), BLACK_TRIM)
	box(TRIM, Vector3(1.20, 0.22, 0.04), Vector3(0, 0.92, 5.53), Color(0.04, 0.04, 0.05))
	for sx in [-1.0, 1.0]:
		box(LIGHT, Vector3(0.40, 0.16, 0.06), Vector3(sx * 0.92, 0.88, 5.52), HEAD)
		box(PAINT, Vector3(0.44, 0.20, 0.05), Vector3(sx * 0.92, 0.88, 5.515), CHROME)
		box(LIGHT, Vector3(0.12, 0.08, 0.06), Vector3(sx * 1.12, 0.66, 5.52), AMBER)
		box(LIGHT, Vector3(0.22, 0.50, 0.06), Vector3(sx * 1.05, 1.00, -5.52), TAIL)
		box(LIGHT, Vector3(0.12, 0.12, 0.06), Vector3(sx * 1.05, 1.36, -5.52), AMBER)
		# mirrors on arms
		strip(TRIM, Vector3(sx * 1.25, 2.55, 5.30), Vector3(sx * 1.45, 2.45, 5.55), 0.04, BLACK_TRIM)
		box(TRIM, Vector3(0.10, 0.36, 0.10), Vector3(sx * 1.47, 2.25, 5.58), BLACK_TRIM)
		box(TRIM, Vector3(0.012, 0.30, 0.07), Vector3(sx * 1.47 - sx * 0.05, 2.25, 5.58), Color(0.25, 0.28, 0.32))
	plate(5.60, 0.50, 1.0)
	plate(-5.60, 0.50, -1.0)

# ------------------------------------------------------------------ output
func mesh() -> ArrayMesh:
	var m := ArrayMesh.new(); var mats := materials()
	for i in 4:
		if not used[i]: continue
		var st: SurfaceTool = sts[i]
		st.commit(m)
		m.surface_set_material(m.get_surface_count() - 1, mats[i])
	return m

func commit(parent: Node, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.name = "CarMesh"; mi.mesh = mesh(); parent.add_child(mi)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## soft blob shadow on the ground (unshaded, alpha radial gradient, no shadow casting); size = (width, length)
static func add_shadow(parent: Node, size: Vector2) -> MeshInstance3D:
	if _shadow_mat == null:
		var g := Gradient.new(); g.set_color(0, Color(0, 0, 0, 0.55)); g.set_color(1, Color(0, 0, 0, 0.0))
		var tex := GradientTexture2D.new(); tex.gradient = g; tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(0.5, 0.0); tex.width = 64; tex.height = 64
		_shadow_mat = StandardMaterial3D.new(); _shadow_mat.albedo_texture = tex
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var pm := PlaneMesh.new(); pm.size = size
	var mi := MeshInstance3D.new(); mi.name = "Shadow"; mi.mesh = pm; mi.material_override = _shadow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.position = Vector3(0, 0.025, 0)
	parent.add_child(mi)
	return mi
