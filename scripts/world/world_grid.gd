## WorldGrid: streams CityBlock scenes around a target (the player).
## The city is a grid of BLOCK-metre tiles; data/world/city.json maps grid cells to block scenes
## (cells inside the bounds without an entry use `default_block`). Blocks within `load_radius` tiles
## of the player are loaded (threaded), blocks beyond `unload_radius` are freed -> constant cost on Android.
class_name WorldGrid
extends Node3D

signal block_loaded(cell: Vector2i, block: Node3D)
signal block_unloaded(cell: Vector2i)

@export var city_path := "res://data/world/city.json"
@export var load_radius := 1          # 1 -> 3x3 tiles around the player
@export var unload_radius := 2
@export var target: Node3D

var block_size := 40.0
var bounds_min := Vector2i(-2, -1)
var bounds_max := Vector2i(2, 1)
var default_block := "res://scenes/blocks/block_residential.tscn"
var cells := {}        # Vector2i -> scene path
var loaded := {}       # Vector2i -> Node3D
var pending := {}      # Vector2i -> scene path (threaded request in flight)
var _t := 0.0

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(city_path))
	if d is Dictionary:
		block_size = float(d.get("block_size", 40)); default_block = d.get("default_block", default_block)
		bounds_min = Vector2i(d.bounds.min[0], d.bounds.min[1]); bounds_max = Vector2i(d.bounds.max[0], d.bounds.max[1])
		for b in d.get("blocks", []): cells[Vector2i(b.cell[0], b.cell[1])] = b.scene
	_build_outskirts()

func cell_of(p: Vector3) -> Vector2i: return Vector2i(roundi(p.x / block_size), roundi(p.z / block_size))
func cell_center(c: Vector2i) -> Vector3: return Vector3(c.x * block_size, 0, c.y * block_size)
func in_bounds(c: Vector2i) -> bool: return c.x >= bounds_min.x and c.y >= bounds_min.y and c.x <= bounds_max.x and c.y <= bounds_max.y
func scene_for(c: Vector2i) -> String: return cells.get(c, default_block)

## load everything around `p` synchronously (first frame / after a teleport)
func load_around_now(p: Vector3) -> void:
	var c0 := cell_of(p)
	for c in _wanted(c0):
		if not loaded.has(c): _spawn(c, load(scene_for(c)))

func _wanted(c0: Vector2i) -> Array:
	var out := []
	for dz in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var c := c0 + Vector2i(dx, dz)
			if in_bounds(c): out.append(c)
	return out

func _process(dt: float) -> void:
	for c in pending.keys():                       # finish threaded loads
		var st := ResourceLoader.load_threaded_get_status(pending[c])
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			var ps: PackedScene = ResourceLoader.load_threaded_get(pending[c]); pending.erase(c)
			if not loaded.has(c): _spawn(c, ps)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("WorldGrid: failed to load " + pending[c]); pending.erase(c)
	_t -= dt
	if _t > 0.0 or target == null: return
	_t = 0.25
	var c0 := cell_of(target.global_position)
	for c in _wanted(c0):
		if not loaded.has(c) and not pending.has(c):
			var path := scene_for(c)
			if ResourceLoader.has_cached(path): _spawn(c, load(path))
			else: ResourceLoader.load_threaded_request(path); pending[c] = path
	for c in loaded.keys():
		if maxi(absi(c.x - c0.x), absi(c.y - c0.y)) > unload_radius:
			loaded[c].queue_free(); loaded.erase(c); block_unloaded.emit(c)

func _spawn(c: Vector2i, ps: PackedScene) -> void:
	if ps == null: return
	var b: Node3D = ps.instantiate()
	if b is CityBlock: (b as CityBlock).grid_pos = c
	b.position = cell_center(c); b.name = "Block_%d_%d" % [c.x, c.y]; add_child(b)
	loaded[c] = b; block_loaded.emit(c, b)

## flat countryside outside the city bounds + invisible walls so the player stays on the map
func _build_outskirts() -> void:
	var k := MeshKit.new()
	var lo := cell_center(bounds_min) - Vector3.ONE * block_size * 0.5
	var hi := cell_center(bounds_max) + Vector3.ONE * block_size * 0.5
	var mid := (lo + hi) * 0.5; var sz := hi - lo
	k.box(Vector3(sz.x + 400, 0.1, sz.z + 400), Vector3(mid.x, -0.12, mid.z), Color(0.70, 0.78, 0.64))
	k.commit(self, false)
	var body := StaticBody3D.new(); add_child(body)
	for w in [[Vector3(sz.x, 4, 1), Vector3(mid.x, 2, lo.z - 0.5)], [Vector3(sz.x, 4, 1), Vector3(mid.x, 2, hi.z + 0.5)],
			[Vector3(1, 4, sz.z), Vector3(lo.x - 0.5, 2, mid.z)], [Vector3(1, 4, sz.z), Vector3(hi.x + 0.5, 2, mid.z)]]:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = w[0]; cs.shape = bs; cs.position = w[1]; body.add_child(cs)

## find a lot by id among loaded blocks
func find_lot(id: String) -> Lot:
	for b in loaded.values():
		for c in b.get_children():
			if c is Lot and (c as Lot).lot_id == id: return c
	return null
