## CityBlock: one fixed-size square tile of the city (BLOCK x BLOCK metres, default 40).
## Draws its half of the four surrounding roads (so neighbouring tiles join seamlessly), sidewalks with curbs,
## street lamps and street trees (MultiMesh, 1 draw call each), then asks every Lot child to build itself.
## All static geometry of the block is merged into ONE mesh (MeshKit) -> ~4 draw calls per block.
class_name CityBlock
extends Node3D

const BLOCK := 40.0
const ROAD := 4.0          # half road width inside this tile (full road = 8 m between two tiles)
const WALK := 2.5          # sidewalk width
const INNER := BLOCK * 0.5 - ROAD - WALK   # 13.5: lots live in -13.5..13.5
const C_ROAD := Color(0.34, 0.34, 0.37)
const C_WALK := Color(0.85, 0.81, 0.74)
const C_CURB := Color(0.96, 0.95, 0.93)
const C_GRASS := Color(0.40, 0.57, 0.33)
const C_LINE := Color(0.96, 0.95, 0.93)

@export var block_name := ""
@export var ground_color := C_GRASS
@export var crosswalks_south: PackedFloat32Array = []   # local x of zebra crossings over the south road
@export var crosswalks_east: PackedFloat32Array = []    # local z of zebra crossings over the east road
@export var street_trees := true
@export var lamp_spacing := 13.0
@export var street_furniture := true

var grid_pos := Vector2i.ZERO
var trees: Array = []      # legacy list (Vector3) -> random tree type
var lamps: Array = []      # Transform3D (local)
var fol := {}              # foliage type -> [[Transform3D, Color], ...]
var body: StaticBody3D
var rng := RandomNumberGenerator.new()
const TREE_TYPES := ["tree_round", "tree_round", "tree_pine", "tree_birch"]
const FLOWER_COLS := [Color(0.85, 0.4, 0.35), Color(0.96, 0.95, 0.93), Color(0.95, 0.78, 0.35), Color(0.62, 0.52, 0.80), Color(0.93, 0.62, 0.70)]

func _ready() -> void:
	rng.seed = hash(grid_pos) ^ hash(scene_file_path)
	body = StaticBody3D.new(); add_child(body)
	var k := MeshKit.new()
	_ground(k)
	_street_furniture(k)
	for c in get_children():
		if c is Lot: (c as Lot).build(k, self)
	_tufts()
	k.commit(self)
	for t in trees: add(TREE_TYPES[rng.randi() % TREE_TYPES.size()], t)
	for l in lamps: add("lamp", l); add("lamp_glow", l)
	for t in fol: _multimesh(t)

## add one foliage / furniture instance (Vector3 = random yaw + scale)
func add(t: String, x, c := Color(1, 1, 1)) -> void:
	var xf: Transform3D = x if x is Transform3D else Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), x)
	if not fol.has(t): fol[t] = []
	fol[t].append([xf, c])

func flower_bed(center: Vector3, size: Vector2, k: MeshKit, yaw := 0.0) -> void:
	var b := Basis(Vector3.UP, yaw)
	k.box(Vector3(size.x + 0.12, 0.14, size.y + 0.12), center + Vector3(0, 0.07, 0), Color(0.96, 0.95, 0.93), yaw)
	k.box(Vector3(size.x, 0.15, size.y), center + Vector3(0, 0.08, 0), Color(0.45, 0.34, 0.27), yaw)
	var n := int(size.x * size.y * 7.0)
	var col: Color = FLOWER_COLS[rng.randi() % FLOWER_COLS.size()]
	for i in n:
		var p := center + b * Vector3(rng.randf_range(-0.5, 0.5) * size.x * 0.9, 0.14, rng.randf_range(-0.5, 0.5) * size.y * 0.9)
		if rng.randf() < 0.25: col = FLOWER_COLS[rng.randi() % FLOWER_COLS.size()]
		add("flower", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), p), col)

func bush(p: Vector3, s := 1.0) -> void:
	add("bush", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.85, 1.1), s)), p),
		Color(0.48, 0.64, 0.46).lerp(Color(0.60, 0.72, 0.50), rng.randf()))

## grass tufts scattered on the lawn, kept off building footprints
func _tufts() -> void:
	var rects: Array = []
	for c in get_children():
		if c is Lot and c.kind != "park": rects.append(Rect2(c.position.x - c.size.x * 0.6, c.position.z - c.size.y * 0.6, c.size.x * 1.2, c.size.y * 1.2))
	for i in 140:
		var p := Vector3(rng.randf_range(-INNER + 0.3, INNER - 0.3), 0.075, rng.randf_range(-INNER + 0.3, INNER - 0.3))
		var ok := true
		for r in rects: if r.has_point(Vector2(p.x, p.z)): ok = false; break
		if ok: add("tuft", p)

func _multimesh(t: String) -> void:
	var list: Array = fol[t]
	var cfg: Array = Foliage.TYPES.get(t, [true, 0.0, false])
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = cfg[2]
	mm.mesh = Foliage.mesh(t); mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		if cfg[2]: mm.set_instance_color(i, list[i][1])
	var mi := MultiMeshInstance3D.new(); mi.name = t; mi.multimesh = mm; add_child(mi)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cfg[0] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if cfg[1] > 0.0: mi.visibility_range_end = cfg[1]; mi.visibility_range_end_margin = 4.0

## benches, bins, bike racks with bikes, street-name sign: static decor merged into the block mesh
func _street_furniture(k: MeshKit) -> void:
	if not street_furniture: return
	var e := INNER + 0.6
	var wood := Color(0.72, 0.56, 0.40); var dk := Color(0.22, 0.23, 0.26)
	# north + west sidewalks: bench + bin, east: bike rack with bikes
	for d in [[Vector3(-6.5, 0.06, -e), 0.0], [Vector3(-e, 0.06, 6.5), PI / 2]]:
		var b := Basis(Vector3.UP, d[1]); var p: Vector3 = d[0]
		if _near_cross(p): continue
		k.box(Vector3(1.6, 0.06, 0.42), p + b * Vector3(0, 0.45, 0), wood, d[1]); k.box(Vector3(1.6, 0.36, 0.05), p + b * Vector3(0, 0.68, -0.2), wood, d[1])
		for sx in [-0.7, 0.7]: k.box(Vector3(0.06, 0.45, 0.4), p + b * Vector3(sx, 0.22, 0), dk, d[1])
		k.cyl(0.24, 0.85, p + b * Vector3(1.4, 0.42, 0), Color(0.40, 0.56, 0.76), 10)
		k.cyl(0.26, 0.06, p + b * Vector3(1.4, 0.87, 0), dk, 10)
		collider(Vector3(1.7, 1, 0.5), p + b * Vector3(0.2, 0.5, 0), d[1])
	var rp := Vector3(e, 0.06, -6.0)
	for i in 3:
		var q := rp + Vector3(0, 0, i * 0.8)
		k.box(Vector3(0.05, 0.6, 0.05), q + Vector3(-0.25, 0.3, 0), dk); k.box(Vector3(0.05, 0.6, 0.05), q + Vector3(0.25, 0.3, 0), dk)
		k.box(Vector3(0.55, 0.05, 0.05), q + Vector3(0, 0.6, 0), dk)
		if i != 1: _bike(k, q + Vector3(0, 0, 0.12), [Color(0.85, 0.4, 0.35), Color(0.40, 0.56, 0.76), Color(0.62, 0.74, 0.70)][i])
	collider(Vector3(1.8, 1, 2.2), rp + Vector3(0, 0.5, 0.8))
	# street name sign on the south-east corner
	var sp := Vector3(INNER + 1.9, 0.06, INNER + 1.9)
	k.cyl(0.04, 2.6, sp + Vector3(0, 1.3, 0), dk, 6)
	k.box(Vector3(1.3, 0.28, 0.03), sp + Vector3(-0.6, 2.45, 0), Color(0.31, 0.42, 0.93))
	if block_name != "":
		var l := Label3D.new(); l.text = block_name; l.font = load("res://fonts/Nunito.ttf"); l.font_size = 40; l.pixel_size = 0.0045
		l.position = sp + Vector3(-0.6, 2.45, 0.02); l.outline_size = 0; add_child(l)

func _bike(k: MeshKit, p: Vector3, c: Color) -> void:
	var dk := Color(0.18, 0.18, 0.2)
	for dx in [-0.5, 0.5]: k.add(_rot_cyl(0.33, 0.04), Transform3D(Basis(Vector3.RIGHT, PI / 2), p + Vector3(dx, 0.33, 0)), dk)
	k.box(Vector3(0.95, 0.04, 0.04), p + Vector3(0, 0.55, 0), c); k.box(Vector3(0.04, 0.4, 0.04), p + Vector3(-0.1, 0.42, 0), c)
	k.box(Vector3(0.22, 0.04, 0.08), p + Vector3(-0.15, 0.68, 0), dk); k.box(Vector3(0.04, 0.04, 0.45), p + Vector3(0.42, 0.78, 0), dk)

func _rot_cyl(r: float, h: float) -> CylinderMesh:
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 12; cm.rings = 1; return cm

func collider(size: Vector3, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs
	cs.transform = Transform3D(Basis(Vector3.UP, yaw), pos); body.add_child(cs)

func _ground(k: MeshKit) -> void:
	var h := BLOCK * 0.5
	k.box(Vector3(BLOCK, 0.1, BLOCK), Vector3(0, -0.06, 0), C_ROAD)                         # asphalt base
	var side := (INNER + WALK) * 2.0
	k.box(Vector3(side, 0.12, side), Vector3(0, 0.0, 0), C_WALK)                            # sidewalk slab (top y 0.06)
	k.box(Vector3(INNER * 2.0, 0.02, INNER * 2.0), Vector3(0, 0.065, 0), ground_color)       # lawn
	for s in [-1, 1]:                                                                        # curbs
		k.box(Vector3(side + 0.24, 0.14, 0.12), Vector3(0, 0.01, s * (side * 0.5 + 0.06)), C_CURB)
		k.box(Vector3(0.12, 0.14, side + 0.24), Vector3(s * (side * 0.5 + 0.06), 0.01, 0), C_CURB)
	# dashed centre lines on the tile edges (drawn by the tile on the -X / -Z side only, i.e. on our +X / +Z edge)
	for i in range(int(BLOCK / 4.0)):
		var t := -h + 1.0 + i * 4.0
		k.box(Vector3(2.0, 0.012, 0.14), Vector3(t, 0.0, h - 0.07), C_LINE)
		k.box(Vector3(0.14, 0.012, 2.0), Vector3(h - 0.07, 0.0, t), C_LINE)
	for x in crosswalks_south:
		for i in 7: k.box(Vector3(0.5, 0.012, 7.0), Vector3(x - 2.1 + i * 0.7, 0.0, h), C_LINE)
	for z in crosswalks_east:
		for i in 7: k.box(Vector3(7.0, 0.012, 0.5), Vector3(h, 0.0, z - 2.1 + i * 0.7), C_LINE)
	# street lamps on the outer sidewalk edge, street trees in between (skip spots close to crossings / driveways)
	var edge := INNER + WALK - 0.45
	var n := int(floor(INNER * 2.0 / lamp_spacing))
	for i in n + 1:
		var t := -INNER + i * (INNER * 2.0 / n)
		for d in [[Vector3(t, 0.06, edge), PI], [Vector3(t, 0.06, -edge), 0.0], [Vector3(edge, 0.06, t), -PI / 2], [Vector3(-edge, 0.06, t), PI / 2]]:
			if _near_cross(d[0]): continue
			lamps.append(Transform3D(Basis(Vector3.UP, d[1]), d[0]))
			collider(Vector3(0.25, 3, 0.25), d[0] + Vector3(0, 1.5, 0))
		if street_trees and i < n:
			var tm := t + INNER / n
			for p in [Vector3(tm, 0.06, edge - 0.5), Vector3(tm, 0.06, -edge + 0.5), Vector3(edge - 0.5, 0.06, tm), Vector3(-edge + 0.5, 0.06, tm)]:
				if _near_cross(p) or _blocked(p): continue
				trees.append(p); collider(Vector3(0.35, 2, 0.35), p + Vector3(0, 1, 0))

func _near_cross(p: Vector3) -> bool:
	for x in crosswalks_south: if p.z > 10 and absf(p.x - x) < 3.0: return true
	for z in crosswalks_east: if p.x > 10 and absf(p.z - z) < 3.0: return true
	return false

## keep street trees off front paths and driveways
func _blocked(p: Vector3) -> bool:
	for c in get_children():
		if c is Lot:
			var l := c as Lot
			for lx in [0.0, l.driveway_x]:
				if lx > 900.0: continue
				var q := l.transform * Vector3(lx, 0, l.size.y * 0.5 + l.path_length)
				if Vector2(q.x, q.z).distance_to(Vector2(p.x, p.z)) < 2.6: return true
	return false

