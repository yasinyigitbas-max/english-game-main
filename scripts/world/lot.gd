## Lot: one building plot inside a CityBlock. Local frame: origin = footprint centre, the FRONT faces local +Z.
## The block calls build(); the lot adds its geometry to the block's merged mesh, its colliders, tree spots,
## and an entrance Interactable. Set `interior_scene` to make the building enterable (spawn "front_door").
class_name Lot
extends Node3D

@export var lot_id := ""
@export_enum("house", "home", "shop", "bus_stop", "park", "empty") var kind := "house"
@export var size := Vector2(8, 7)                     # building footprint (x width, z depth)
@export var body_color := Color(0.90, 0.88, 0.85)
@export var roof_color := Color(0.85, 0.4, 0.35)
@export var accent_color := Color(0.62, 0.74, 0.70)   # door / trim accent
@export var path_length := 4.0                        # front path from door to the sidewalk
@export var interior_scene := ""                      # e.g. res://scenes/house_interior.tscn
@export var display_name := ""
@export var display_name_tr := ""
@export var shop_id := ""                              # Economy shop id (kind == shop)
@export var stop_id := ""                              # Transit stop id (kind == bus_stop)
@export var tree_spots: PackedVector3Array = []       # local positions of garden trees
@export var driveway_x := 999.0                       # local x of a driveway to the street (999 = none)
@export var own_car := false                          # the car on the driveway is an interactive StreetObject instead

const WHITE := Color(0.98, 0.98, 0.98)
const GLASS := Color(0.62, 0.74, 0.86)
const DARK := Color(0.22, 0.22, 0.25)
const WOOD := Color(0.72, 0.56, 0.40)
const PAVE := Color(0.82, 0.80, 0.76)

var kit: MeshKit
var gkit: MeshKit
var blk: Node

func entrance_local() -> Vector3: return Vector3(0, 0, size.y * 0.5 + 0.9)
func entrance_global() -> Vector3: return global_transform * entrance_local()

func _g(s: Vector3, p: Vector3, c: Color) -> void: gkit.box(s, transform * p, c, rotation.y)
func _b(s: Vector3, p: Vector3, c: Color, yaw := 0.0) -> void: kit.box(s, transform * p, c, rotation.y + yaw)

func build(k: MeshKit, block: Node) -> void:
	blk = block; position.y = 0.07; add_to_group("lots")
	# the building goes into its own mesh so it can fade when it hides the player (group "fade")
	gkit = k; kit = MeshKit.new()
	match kind:
		"house": _house(false)
		"home": _house(true)
		"shop": _shop()
		"bus_stop": _bus_stop()
		"park": _park()
	if kit.count > 0:
		var mi := kit.commit(block); mi.add_to_group("fade" if kind in ["house", "home", "shop"] else "solid")
		if kind in ["house", "home", "shop"]: mi.set_meta("cut", _cutaway(block))
	if kind == "home": (func(): DoorLabel.at(self, entrance_global() + Vector3(0, 2.3, 0), "Home", "Ev")).call_deferred()   # v30.2: door sign
	kit = k
	for t in tree_spots: blk.trees.append(transform * t)
	if kind in ["house", "home"]: _garden()
	if driveway_x < 900.0:
		_b(Vector3(3.2, 0.03, path_length + size.y * 0.5), Vector3(driveway_x, 0.015, (path_length + size.y * 0.5) * 0.5), PAVE.darkened(0.04))
		if not own_car: _car(Vector3(driveway_x, 0, size.y * 0.5 - 2.0 + path_length * 0.5))
	if kind in ["house", "home", "shop"]: blk.collider(Vector3(size.x, 3, size.y), transform * Vector3(0, 1.5, 0), rotation.y)
	if kind in ["house", "home"] or (kind == "shop" and interior_scene != ""):   # v31 QA (blue): café / shop with an interior get a door too
		var it := Interactable.make(self, entrance_local(), _enter_en(), _enter_tr(), 1.6, _on_enter)
		it.obj_name = display_name.capitalize() if kind == "shop" and display_name != "" else (display_name if display_name != "" else ("house" if kind == "house" else "my house"))
		it.add_to_group("entrances")

## hedge along the front with gaps for the path / driveway, flower beds by the door, bushes, side fences, mailbox
func _garden() -> void:
	var w := size.x; var d := size.y
	var fz := d * 0.5 + path_length - 0.45
	var x0 := -w * 0.5 - 1.6; var x1 := w * 0.5 + 1.6
	var gaps := [[-0.9, 0.9]]
	if driveway_x < 900.0: gaps.append([driveway_x - 1.8, driveway_x + 1.8]); x1 = maxf(x1, driveway_x + 2.4)
	gaps.sort_custom(func(a, b): return a[0] < b[0])
	var cur := x0
	for g in gaps:
		if g[0] - cur > 0.3: _hedge(cur, g[0], fz)
		cur = g[1]
	if x1 - cur > 0.3: _hedge(cur, x1, fz)
	# white picket side fences from the hedge to the back of the house
	for sx in [x0, x1]:
		var n := int((fz + d * 0.5) / 0.3)
		for i in n: _b(Vector3(0.07, 0.8, 0.05), Vector3(sx, 0.4, fz - 0.3 - i * 0.3), WHITE)
		for y in [0.3, 0.65]: _b(Vector3(0.04, 0.06, fz + d * 0.5), Vector3(sx, y, (fz - d * 0.5) * 0.5 - 0.15), WHITE)
		blk.collider(Vector3(0.2, 1.0, fz + d * 0.5), transform * Vector3(sx, 0.5, (fz - d * 0.5) * 0.5 - 0.15), rotation.y)   # house.24: fences block
	# v29 review: close the back corners (side fence -> back wall of the house): the garden was open from behind,
	# so the player could walk around the hedge/gate and through where a fence should be
	for seg in [[x0, -w * 0.5], [w * 0.5, x1]]:
		var a: float = seg[0]; var b: float = seg[1]
		if b - a < 0.05: continue
		for y in [0.3, 0.65]: _b(Vector3(b - a, 0.06, 0.04), Vector3((a + b) * 0.5, y, -d * 0.5 + 0.15), WHITE)
		for i in int((b - a) / 0.3): _b(Vector3(0.07, 0.8, 0.05), Vector3(a + 0.15 + i * 0.3, 0.4, -d * 0.5 + 0.15), WHITE)
		blk.collider(Vector3(b - a, 1.0, 0.2), transform * Vector3((a + b) * 0.5, 0.5, -d * 0.5 + 0.15), rotation.y)
	# flower beds either side of the door + bushes at the corners
	for sx in [-1, 1]:
		blk.flower_bed(transform * Vector3(sx * 2.4, 0, d * 0.5 + 0.55), Vector2(2.2, 0.6), kit, rotation.y)
		blk.bush(transform * Vector3(sx * (w * 0.5 - 0.3), 0, d * 0.5 + 0.6), 1.1)
		blk.bush(transform * Vector3(sx * (w * 0.5 + 0.7), 0, d * 0.5 - 1.5), 0.9)
	for i in 4: blk.bush(transform * Vector3(lerpf(x0 + 0.6, -1.6, i / 3.0), 0, fz - 0.7), 0.75)
	if kind == "house": _mailbox(Vector3(1.3, 0, fz + 0.1))

func _hedge(a: float, b: float, z: float) -> void:
	_b(Vector3(b - a, 0.75, 0.55), Vector3((a + b) * 0.5, 0.37, z), Color(0.42, 0.58, 0.42))
	_b(Vector3(b - a - 0.1, 0.12, 0.45), Vector3((a + b) * 0.5, 0.8, z), Color(0.47, 0.63, 0.46))
	blk.collider(Vector3(b - a, 1, 0.55), transform * Vector3((a + b) * 0.5, 0.5, z), rotation.y)

func _mailbox(p: Vector3) -> void:
	_b(Vector3(0.08, 1.0, 0.08), p + Vector3(0, 0.5, 0), Color(0.22, 0.22, 0.25))
	_b(Vector3(0.3, 0.3, 0.45), p + Vector3(0, 1.1, 0), accent_color.darkened(0.1))
	_b(Vector3(0.04, 0.16, 0.04), p + Vector3(0.17, 1.2, -0.1), Color(0.85, 0.4, 0.35))

var door_pivot: Node3D
func _enter_en() -> String: return "Go inside" if kind == "home" or interior_scene != "" else "Knock on the door"   # v31: cafe / shop interiors
func _enter_tr() -> String: return ""

func _on_enter() -> void:
	var w := get_tree().current_scene
	# merged game: the home's front door leads into black bot's living room (App.came_from = "outside")
	if kind == "home" and ResourceLoader.exists(Game.HOUSE_FRONT_DOOR_SCENE):
		App.came_from = "outside"; interior_scene = Game.HOUSE_FRONT_DOOR_SCENE
	if interior_scene != "" and ResourceLoader.exists(interior_scene):
		await Audio.wait_idle(12.0)   # house.24: silent transition; one tap: the door swings open, then the living room
		if door_pivot:
			Audio.sfx("doorOpen_1", 0.0, 0.85); var tw := create_tween(); tw.tween_property(door_pivot, "rotation:y", -1.45, 0.6).set_trans(Tween.TRANS_SINE); await tw.finished
		w.save_game(); WorldState.player_pos = entrance_global(); StoryNav.goto(interior_scene, "front_door")
	elif w.has_method("caption"):
		await w.say_line("I am knocking on the door."); await get_tree().create_timer(1.2).timeout; await w.say_line("Nobody is at home.")

func _windows(w: float, d: float, h: float, door_gap: float) -> void:
	# front windows either side of the door, side windows
	for sx in [-1, 1]:
		var x: float = sx * (door_gap + (w * 0.5 - door_gap) * 0.5)
		var ww: float = minf(2.2, (w * 0.5 - door_gap) * 0.7)
		_b(Vector3(ww + 0.16, 1.36, 0.06), Vector3(x, 1.55, d * 0.5 + 0.02), WHITE)
		_b(Vector3(ww, 1.2, 0.08), Vector3(x, 1.55, d * 0.5 + 0.03), GLASS)
		_b(Vector3(ww + 0.3, 0.06, 0.18), Vector3(x, 0.9, d * 0.5 + 0.08), WHITE)
		_b(Vector3(0.08, 1.2, 1.6), Vector3(sx * (w * 0.5 + 0.03), 1.55, 0), GLASS)
		_b(Vector3(0.06, 1.36, 1.76), Vector3(sx * (w * 0.5 + 0.02), 1.55, 0), WHITE)

func _house(home: bool) -> void:
	var w := size.x; var d := size.y; var h := 2.9 if home else 2.8
	_b(Vector3(w + 0.1, 0.2, d + 0.1), Vector3(0, 0.1, 0), DARK.lightened(0.25))           # plinth
	_b(Vector3(w, h, d), Vector3(0, h * 0.5 + 0.1, 0), body_color)
	if home:
		# modern flat roof with overhang + wood fascia, wood cladding panel around the entrance
		_b(Vector3(w + 0.8, 0.22, d + 0.8), Vector3(0, h + 0.21, 0), DARK)
		_b(Vector3(w + 0.82, 0.08, d + 0.82), Vector3(0, h + 0.08, 0), WOOD)
		_b(Vector3(3.2, h, 0.08), Vector3(0, h * 0.5 + 0.1, d * 0.5 + 0.04), WOOD)
		_g(Vector3(3.6, 0.12, 2.2), Vector3(0, 0.06, d * 0.5 + 1.1), PAVE.lightened(0.05))   # porch
		_b(Vector3(3.4, 0.1, 1.4), Vector3(0, h - 0.1, d * 0.5 + 0.7), DARK)                 # canopy
		# wide living-room glazing on the right, bedroom / spare windows on the left
		for x in [-3.6, 3.4]:
			_b(Vector3(3.4, 1.6, 0.06), Vector3(x, 1.45, d * 0.5 + 0.02), WHITE)
			_b(Vector3(3.2, 1.45, 0.08), Vector3(x, 1.45, d * 0.5 + 0.03), GLASS)
			_b(Vector3(0.05, 1.45, 0.1), Vector3(x, 1.45, d * 0.5 + 0.05), WHITE)
		for z in [-3.5, 2.5]:
			for sx in [-1, 1]:
				_b(Vector3(0.08, 1.2, 2.0), Vector3(sx * (w * 0.5 + 0.03), 1.55, z), GLASS)
		for x in [-3.6, 3.4]: _b(Vector3(3.5, 0.08, 0.25), Vector3(x, 0.66, d * 0.5 + 0.1), WHITE)
		_b(Vector3(0.18, 0.18, 0.12), Vector3(-0.9, 2.3, d * 0.5 + 0.12), Color(1.0, 0.93, 0.75))
		var lbl := Label3D.new(); lbl.text = "12"; lbl.font = load("res://fonts/Nunito.ttf"); lbl.font_size = 72; lbl.pixel_size = 0.004
		lbl.modulate = DARK; lbl.outline_size = 0; lbl.position = Vector3(1.0, 2.1, d * 0.5 + 0.1); add_child(lbl)
	else:
		_b(Vector3(w + 0.6, 0.12, d + 0.6), Vector3(0, h + 0.12, 0), WHITE)
		kit.prism(Vector3(w + 0.6, 1.8, d + 0.6), transform * Vector3(0, h + 1.08, 0), roof_color, rotation.y)
		_windows(w, d, h, 0.8)
		for sx in [-1, 1]:
			var x: float = sx * (0.8 + (w * 0.5 - 0.8) * 0.5); var ww: float = minf(2.2, (w * 0.5 - 0.8) * 0.7)
			for e in [-1, 1]: _b(Vector3(0.4, 1.3, 0.05), Vector3(x + e * (ww * 0.5 + 0.28), 1.55, d * 0.5 + 0.04), accent_color)
		_b(Vector3(0.6, 1.4, 0.6), Vector3(w * 0.3, h + 1.5, -d * 0.15), Color(0.85, 0.4, 0.35).darkened(0.2))
		_b(Vector3(w + 0.7, 0.1, 0.12), Vector3(0, h + 0.2, d * 0.5 + 0.34), WHITE)
		_b(Vector3(0.08, h, 0.08), Vector3(w * 0.5 + 0.25, h * 0.5 + 0.1, d * 0.5 + 0.3), WHITE)
	# door
	_b(Vector3(1.1, 2.2, 0.06), Vector3(0, 1.2, d * 0.5 + 0.03), WHITE)
	# house.24: real hinged door leaf (swings open when the player goes inside)
	door_pivot = Node3D.new(); door_pivot.position = Vector3(-0.475, 0.1, d * 0.5 + 0.05); add_child(door_pivot)
	for pc in [[Vector3(0.95, 2.1, 0.08), Vector3(0.475, 1.05, 0), accent_color], [Vector3(0.05, 0.3, 0.05), Vector3(0.815, 1.05, 0.06), DARK]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = pc[0]; mi.mesh = bm; mi.position = pc[1]
		var mt := StandardMaterial3D.new(); mt.albedo_color = pc[2]; mi.material_override = mt; door_pivot.add_child(mi)
	# front path
	_g(Vector3(1.4, 0.04, path_length), Vector3(0, 0.02, d * 0.5 + path_length * 0.5), PAVE)
	_g(Vector3(1.0, 0.18, 0.4), Vector3(0, 0.09, d * 0.5 + 0.25), PAVE.lightened(0.05))

func _car(p: Vector3) -> void:
	var c := Color(0.40, 0.56, 0.76)
	_b(Vector3(1.8, 0.7, 4.2), p + Vector3(0, 0.55, 0), c)
	_b(Vector3(1.6, 0.6, 2.2), p + Vector3(0, 1.15, -0.2), c.lightened(0.1))
	_b(Vector3(1.62, 0.45, 2.0), p + Vector3(0, 1.17, -0.2), GLASS)
	for wx in [-0.85, 0.85]:
		for wz in [-1.3, 1.3]: _b(Vector3(0.3, 0.6, 0.6), p + Vector3(wx, 0.3, wz), DARK)
	blk.collider(Vector3(1.9, 1.5, 4.3), transform * (p + Vector3(0, 0.75, 0)), rotation.y)

func _shop() -> void:
	var w := size.x; var d := size.y; var h := 3.4
	_b(Vector3(w, h, d), Vector3(0, h * 0.5, 0), body_color)
	_b(Vector3(w + 0.3, 0.3, d + 0.3), Vector3(0, h + 0.15, 0), WHITE)
	_b(Vector3(w - 1.0, 2.2, 0.08), Vector3(0, 1.3, d * 0.5 + 0.03), GLASS)                     # shop window
	for x in [-w * 0.25, w * 0.25]: _b(Vector3(0.1, 2.3, 0.12), Vector3(x, 1.3, d * 0.5 + 0.05), WHITE)
	_b(Vector3(1.2, 2.2, 0.1), Vector3(0, 1.1, d * 0.5 + 0.06), accent_color)                     # door
	for i in 8:                                                                                    # striped awning
		_b(Vector3(w / 8.0, 0.08, 1.4), Vector3(-w * 0.5 + w / 16.0 + i * w / 8.0, 2.7, d * 0.5 + 0.7), roof_color if i % 2 == 0 else WHITE, 0)
	_b(Vector3(w * 0.6, 0.6, 0.1), Vector3(0, 3.05, d * 0.5 + 0.06), DARK)
	var lbl := Label3D.new(); lbl.text = display_name if display_name != "" else "SHOP"; lbl.font = load("res://fonts/Nunito.ttf")
	lbl.font_size = 96; lbl.pixel_size = 0.005; lbl.modulate = Color(0.96, 0.95, 0.93); lbl.outline_size = 0
	lbl.position = Vector3(0, 3.05, d * 0.5 + 0.13); lbl.double_sided = false; add_child(lbl)   # v31 QA: no mirrored sign through the cutaway
	_g(Vector3(2.2, 0.04, path_length), Vector3(0, 0.02, d * 0.5 + path_length * 0.5), PAVE)
	for x in [-w * 0.35, w * 0.35]:                                                                # fruit crates
		_g(Vector3(0.9, 0.5, 0.6), Vector3(x, 0.25, d * 0.5 + 0.5), WOOD)
		_g(Vector3(0.8, 0.12, 0.5), Vector3(x, 0.55, d * 0.5 + 0.5), Color(0.85, 0.4, 0.35) if x < 0 else Color(0.95, 0.75, 0.3))

func _bus_stop() -> void:
	var blue := Color(0.40, 0.56, 0.76)
	_b(Vector3(3.2, 0.08, 1.4), Vector3(0, 2.4, 0), WHITE)                                        # roof
	for x in [-1.5, 1.5]: _b(Vector3(0.08, 2.4, 0.08), Vector3(x, 1.2, -0.6), DARK)
	_b(Vector3(3.0, 1.8, 0.04), Vector3(0, 1.3, -0.62), GLASS)                                    # back glass
	_b(Vector3(2.2, 0.08, 0.45), Vector3(0, 0.48, -0.35), WOOD)                                   # bench
	_b(Vector3(0.06, 0.44, 0.3), Vector3(-1.0, 0.24, -0.35), DARK); _b(Vector3(0.06, 0.44, 0.3), Vector3(1.0, 0.24, -0.35), DARK)
	_b(Vector3(0.08, 2.8, 0.08), Vector3(2.1, 1.4, 0.3), DARK)                                    # sign pole
	_b(Vector3(0.6, 0.6, 0.06), Vector3(2.1, 2.7, 0.3), blue)
	var lbl := Label3D.new(); Lines.set_sign(lbl, "BUS", "OTOBÜS"); lbl.font = load("res://fonts/Nunito.ttf"); lbl.font_size = 64; lbl.pixel_size = 0.004
	lbl.modulate = Color(1, 1, 1); lbl.outline_size = 0; lbl.position = Vector3(2.1, 2.7, 0.34); lbl.double_sided = false; add_child(lbl)
	blk.collider(Vector3(3.2, 2.4, 0.2), transform * Vector3(0, 1.2, -0.6), rotation.y)
	var it := Interactable.make(self, Vector3(0, 0, 0.6), "Read the timetable", "", 1.8, _on_stop)
	it.obj_name = "bus stop"; it.focus = to_global(Vector3(-0.9, 1.5, -0.6))
	var tt := MeshKit.new(); tt.box(Vector3(0.6, 0.8, 0.03), Vector3(-0.9, 1.5, -0.58), WHITE); tt.box(Vector3(0.5, 0.06, 0.035), Vector3(-0.9, 1.8, -0.58), Color(0.40, 0.56, 0.76))
	for i in 5: tt.box(Vector3(0.4, 0.025, 0.035), Vector3(-0.9, 1.65 - i * 0.09, -0.58), Color(0.6, 0.62, 0.66))
	tt.commit(self)
	if stop_id != "": Transit.register_stop(stop_id, global_transform.origin, display_name)

func _on_stop() -> void:
	var w := get_tree().current_scene
	if not w.has_method("caption"): return
	await w.say_line("I am reading the timetable.")
	await get_tree().create_timer(2.6).timeout
	var deps: Array = Transit.next_departures(stop_id, 1)
	w.say_line("The next bus is at %s." % (deps[0].text if deps.size() > 0 else "seven o'clock"))

func _park() -> void:
	var w := size.x; var d := size.y
	_b(Vector3(w, 0.03, 1.6), Vector3(0, 0.015, 0), PAVE)
	_b(Vector3(1.6, 0.03, d), Vector3(0, 0.015, 0), PAVE)
	for p in [Vector3(-3, 0, 1.4), Vector3(3, 0, -1.4)]:
		_b(Vector3(1.8, 0.08, 0.45), p + Vector3(0, 0.45, 0), WOOD); _b(Vector3(1.8, 0.4, 0.06), p + Vector3(0, 0.7, -0.22), WOOD)
	_b(Vector3(3.0, 0.4, 3.0), Vector3(0, 0.2, 0), WHITE.darkened(0.08))                          # fountain
	_b(Vector3(2.6, 0.06, 2.6), Vector3(0, 0.38, 0), Color(0.55, 0.72, 0.85))

## footstep surface: true when local point p (lot space) is on the building, porch or front path
func on_hard(p: Vector3) -> bool:
	var hw := size.x * 0.5 + 0.3; var hd := size.y * 0.5
	if kind in ["park", "empty"]: return false
	if absf(p.x) < hw and absf(p.z) < hd + 0.3: return true
	if absf(p.x) < (1.8 if kind == "home" else 1.2) and p.z > 0.0 and p.z < hd + path_length + 2.3: return true
	if driveway_x != 999.0 and absf(p.x - driveway_x) < 1.6 and p.z > -hd: return true
	return false

## cutaway shown instead of the building while it hides the player: walls cut at 1 m, no roof (like the bedroom's
## open-top room), floor visible, so nothing pale covers the screen
func _cutaway(block: Node) -> MeshInstance3D:
	var c := MeshKit.new(); var w := size.x; var d := size.y; var t := 0.18; var h := 1.0
	var top := body_color.darkened(0.25)
	c.box(Vector3(w, 0.12, d), transform * Vector3(0, 0.16, 0), Color(0.86, 0.76, 0.60), rotation.y)        # floor (bedroom wood tone)
	for z in [-d * 0.5 + t * 0.5, d * 0.5 - t * 0.5]:
		c.box(Vector3(w, h, t), transform * Vector3(0, h * 0.5 + 0.1, z), body_color, rotation.y)
		c.box(Vector3(w, 0.04, t + 0.02), transform * Vector3(0, h + 0.12, z), top, rotation.y)
	for x in [-w * 0.5 + t * 0.5, w * 0.5 - t * 0.5]:
		c.box(Vector3(t, h, d), transform * Vector3(x, h * 0.5 + 0.1, 0), body_color, rotation.y)
		c.box(Vector3(t + 0.02, 0.04, d), transform * Vector3(x, h + 0.12, 0), top, rotation.y)
	var mi := c.commit(block); mi.visible = false; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
