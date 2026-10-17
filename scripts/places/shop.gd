## v31 SHOP interior: fruit & veg crates, 3 aisles of products (MultiMesh, one draw call per aisle side), fridges with milk,
## bakery corner, checkout with till + conveyor, shop assistant, customers (one walks the aisles with a basket).
## Flow (each beat once): enter pan -> basket -> six apples -> milk -> bread -> cinematic checkout (how much / how many)
## -> phone lesson + test (countable / uncountable, how much / how many, shopping) -> "Go outside." (exit hook).
extends PlaceBase

const CK := Vector3(3.6, 0, 2.3)     # checkout counter centre
const AISLE_Z := -1.3                # centre (z) of the three shelf units and their cross beam
const APPLE_SPOT := Vector3(-6.2, 0, 1.15)   # on the 1.4 m path between the aisle ends (z 0.2) and the crates (z 1.6)
const MILK_SPOT := Vector3(-4.8, 0, -3.6)    # on the 1.35 m path between the fridges (front ~z -4.1) and the aisle backs (z -2.8)
const BREAD_SPOT := Vector3(4.6, 0, -3.35)   # open floor in front of the bakery counter (front z -3.95)
var walker_t := 0.0
const WALKER_V := 1.1   # m/s (the walk clip matches 1.7 m/s at speed 1.0)
# blue layout (room 14 x 10): walking lanes x = -4.45 (west, milk side), -2.15, 0.15 (between aisles); paths z = 0.9 (front of aisles) / -3.45 (back)
var walker_path := [Vector3(-4.45, 0, 0.9), Vector3(-4.45, 0, -3.45), Vector3(-2.15, 0, -3.45), Vector3(-2.15, 0, 0.9), Vector3(0.15, 0, 0.9), Vector3(0.15, 0, -3.45), Vector3(-2.15, 0, -3.45), Vector3(-2.15, 0, 0.9)]
var walker_i := 0
var basket_items: Array = []

func place_en() -> String: return "Shop"
func place_tr() -> String: return "Market"
func floor_colors() -> Array: return [Color(0.68, 0.7, 0.68), Color(0.84, 0.88, 0.84), Color(0.4, 0.62, 0.46)]

func build() -> void:
	place_id = "shop"; world_lot = "corner_shop"; room = Vector2(14.0, 10.0)   # blue: was 12 x 9 in code but built at 10 x 8 (see place_base._ready)
	for n in get_children(): if n is DirectionalLight3D: (n as DirectionalLight3D).light_energy = 0.45   # bright shop: tame the sun so shelf tops don't blow out
	var hx := room.x / 2.0; var hz := room.y / 2.0
	# floor tiles checker (cheap)
	for i in range(-7, 7):
		for j in range(-5, 5):
			if (i + j) % 2 == 0: box(Vector3(1.0, 0.004, 1.0), Vector3(i * 1.0 + 0.5, 0.003, j * 1.0 + 0.5), Color(0.55, 0.58, 0.56), false)
	# ---- aisles: double-sided shelving units along Z (blue layout: x -3.3 / -1.0 / 1.3, z -2.8..0.2; lanes between them 1.4 m,
	# 1.35 m behind them to the fridges, 1.4 m in front of them to the fruit crates, open floor east of them to the bakery / checkout)
	for a in 3:
		var x := -3.3 + a * 2.3
		_shelf_unit(Vector3(x, 0, AISLE_Z), 3.0, a)
		box(Vector3(0.05, 0.4, 1.2), Vector3(x, 2.55, AISLE_Z), Color(0.2, 0.45, 0.35), false)
		var sg: String = ["2  Rice & Pasta", "3  Drinks & Snacks", "5  Tins & Jars"][a]
		label(sg, Vector3(x + 0.03, 2.55, AISLE_Z), 40, Color.WHITE, PI / 2); label(sg, Vector3(x - 0.03, 2.55, AISLE_Z), 40, Color.WHITE, -PI / 2)
		cyl(0.008, 0.36, Vector3(x, 2.88, AISLE_Z), Color(0.3, 0.3, 0.3))   # v32 polish: cord ends on the ceiling beam (was 0.6 m into the open sky)
	# ---- fruit & veg crates near the door (left)
	var crates := [["apple", Color(0.85, 0.2, 0.2)], ["banana", Color(0.95, 0.85, 0.3)], ["orange", Color(1.0, 0.6, 0.15)], ["tomato", Color(0.9, 0.25, 0.2)], ["carrot", Color(1.0, 0.55, 0.2)], ["broccoli", Color(0.3, 0.6, 0.3)]]
	for k in crates.size():
		var c := Vector3(-6.2 + (k % 3) * 0.95, 0, 2.0 + int(k / 3) * 1.05)   # blue: x -6.625..-3.875 (west wall inner face -6.93), z 1.6..3.45
		box(Vector3(0.85, 0.6, 0.8), c + Vector3(0, 0.3, 0), Color(0.62, 0.45, 0.3), true, 0.0)
		box(Vector3(0.8, 0.02, 0.75), c + Vector3(0, 0.61, 0), Color(0.42, 0.31, 0.2), false)
		if crates[k][0] in ["apple", "tomato"]: _fruit_heap(c + Vector3(0, 0.62, 0), crates[k][1])   # procedural heap (one draw call)
		else:
			for n in 7: food(String(crates[k][0]), c + Vector3(-0.25 + (n % 4) * 0.17, 0.62 + int(n / 4) * 0.06, -0.15 + int(n / 4) * 0.25 + (n % 2) * 0.06), 0.16 if crates[k][0] != "banana" else 0.18, n * 47.0)
		label(["Apples 0.40", "Bananas 0.25", "Oranges 0.40", "Tomatoes 0.20", "Carrots 0.15", "Broccoli 0.90"][k], c + Vector3(0, 0.75, -0.41 if k < 3 else 0.41), 26, Color(0.1, 0.1, 0.1), PI if k < 3 else 0.0, Color(1, 1, 1, 0.9))
	label("1  Fruit & Veg", Vector3(-5.25, 2.55, 2.5), 44, Color.WHITE)
	for x in [-5.85, -4.65]: cyl(0.008, 0.36, Vector3(x, 2.88, 2.47), Color(0.3, 0.3, 0.3))   # v32 polish: the sign hung from nothing
	box(Vector3(1.6, 0.4, 0.05), Vector3(-5.25, 2.55, 2.47), Color(0.2, 0.45, 0.35), false)
	# ---- fridges with milk along the back wall
	for i in 4:
		var f := Vector3(-5.9 + i * 1.05, 0, -4.55)
		furn("kitchenFridgeLarge", f, 0, 2.0, 0.0, true)
	box(Vector3(4.3, 1.5, 0.02), Vector3(-4.3, 1.15, -4.12), Color(0.75, 0.9, 1.0), false, 0.0, 0.35)   # cool glow
	for i in 16: food(["carton", "carton-small", "cheese", "carton"][i % 4], Vector3(-6.1 + i * 0.26, 0.95 + (i % 2) * 0.5, -4.16), 0.16 if i % 4 != 2 else 0.14)
	label("4  Milk & Cheese", Vector3(-4.3, 2.35, -4.1), 44, Color.WHITE)
	label("Milk 1.50", Vector3(-4.8, 1.75, -4.05), 28, Color(0.1, 0.1, 0.1), 0.0, Color(1, 1, 1, 0.9))
	# ---- bakery (back wall, east half; blue: open floor in front of it, 3+ m to the aisles, was squeezed into the corner)
	box(Vector3(2.2, 0.9, 0.7), Vector3(4.6, 0.45, -4.3), Color(0.75, 0.55, 0.35), true)
	box(Vector3(2.2, 0.04, 0.72), Vector3(4.6, 0.92, -4.3), Color(0.45, 0.3, 0.2), false)
	for k in 9: food(["loaf", "loaf-baguette", "loaf-round", "croissant", "bread", "loaf", "donut", "loaf-round", "muffin"][k], Vector3(3.7 + k * 0.22, 0.94, -4.3 + (k % 2) * 0.15), 0.2 if k < 3 else 0.14, 20.0 * k)
	for y in [1.5, 1.9]:
		box(Vector3(2.2, 0.04, 0.3), Vector3(4.6, y, -4.8), Color(0.55, 0.38, 0.25), false)
		for k in 6: food(["loaf", "bread", "loaf-round"][k % 3], Vector3(3.75 + k * 0.33, y + 0.02, -4.78), 0.2, 15.0 * k)
	label("Bakery", Vector3(4.6, 2.45, -4.85), 70, Color(1.0, 0.85, 0.5))
	label("Bread 2.50", Vector3(4.6, 0.7, -3.93), 28, Color(0.1, 0.1, 0.1), 0.0, Color(1, 1, 1, 0.9))
	# ---- checkout
	box(Vector3(0.8, 0.95, 2.0), CK + Vector3(0, 0.475, 0), Color(0.3, 0.35, 0.45), true)
	box(Vector3(0.6, 0.02, 1.6), CK + Vector3(0, 0.96, 0.15), Color(0.12, 0.12, 0.12), false)   # conveyor belt
	box(Vector3(0.36, 0.28, 0.3), CK + Vector3(0.1, 1.1, -0.75), Color(0.2, 0.2, 0.22), false)   # till
	box(Vector3(0.3, 0.18, 0.02), CK + Vector3(-0.05, 1.32, -0.7), Color(0.3, 0.7, 0.5), false, -PI / 2, 0.7)
	box(Vector3(0.2, 0.02, 0.2), CK + Vector3(-0.15, 0.97, -0.35), Color(0.3, 0.3, 0.32), false)   # scanner
	box(Vector3(0.12, 0.012, 0.12), CK + Vector3(-0.15, 0.982, -0.35), Color(1.0, 0.2, 0.2), false, 0.0, 1.5)
	cyl(0.02, 1.3, CK + Vector3(0.35, 1.6, 0.9), Color(0.5, 0.5, 0.5)); box(Vector3(0.05, 0.3, 0.45), CK + Vector3(0.35, 2.3, 0.9), Color(0.95, 0.75, 0.2), false, 0.0, 0.6)
	label("1", CK + Vector3(0.32, 2.3, 0.9), 70, Color(0.15, 0.15, 0.15), -PI / 2, Color(1, 1, 1, 0))
	label("1", CK + Vector3(0.38, 2.3, 0.9), 70, Color(0.15, 0.15, 0.15), PI / 2, Color(1, 1, 1, 0))
	for k in 5: food(["candy-bar", "chocolate", "soda-can", "candy-bar", "chocolate"][k], CK + Vector3(-0.42, 0.5 + (k % 2) * 0.25, -0.6 + k * 0.25), 0.12)
	# ---- sweets rack on the east wall (blue v32): x 6.35..6.85, z -0.7..1.5, faces west into the 2.3 m open lane between the
	# checkout (x <= 4.0) and the wall; clear of the bakery customer (5.3, -1.0) and the bread spot
	var SW := Vector3(6.6, 0, 0.4)
	box(Vector3(0.5, 1.7, 2.2), SW + Vector3(0.05, 0.85, 0), Color(0.85, 0.45, 0.6), true)
	for y in [0.35, 0.75, 1.15, 1.55]:
		box(Vector3(0.62, 0.04, 2.2), SW + Vector3(-0.06, y, 0), Color(0.95, 0.9, 0.92), false)
		for k in 7: food(["candy-bar", "chocolate", "cookie", "donut-sprinkles", "chocolate", "candy-bar", "cookie-chocolate"][(k + int(y * 10)) % 7], SW + Vector3(-0.15, y + 0.02, -0.9 + k * 0.3), 0.13, 90.0 + k * 15.0)
	label("6  Sweets", SW + Vector3(-0.32, 1.95, 0), 44, Color.WHITE, -PI / 2, Color(0.55, 0.15, 0.35, 0.9))
	label("Chocolate 1.00", SW + Vector3(-0.38, 0.6, -0.5), 24, Color(0.1, 0.1, 0.1), -PI / 2, Color(1, 1, 1, 0.9))
	# basket stack by the door
	for k in 4: model("res://props/places/basket.tscn", Vector3(-1.6, k * 0.12, 4.2), 0, 0.0, 0.42, k == 0)
	label("Baskets", Vector3(-1.6, 1.0, 4.45), 36, Color(0.15, 0.15, 0.15), PI, Color(1, 1, 1, 0.9))
	# lights: long emissive ceiling panels + one omni (no shadows)
	# v32 polish: the light panels floated in the air (no ceiling, 6.5 m in a 9 m room). Now they hang under steel rails that
	# run wall to wall, and two cross beams carry the hanging aisle signs, so nothing floats in the top-down view.
	for x in [-5.2, -2.15, 0.15, 2.6, 5.2]:   # blue: over the lanes / open floor of the 14 m room
		box(Vector3(0.08, 0.08, room.y - 0.14), Vector3(x, 2.96, 0), Color(0.32, 0.33, 0.35), false)
		box(Vector3(0.26, 0.03, room.y - 0.6), Vector3(x, 2.905, 0), Color(1.0, 0.98, 0.92), false, 0.0, 0.8)
	for z in [AISLE_Z, 2.47]: box(Vector3(room.x - 0.14, 0.06, 0.06), Vector3(0, 3.03, z), Color(0.32, 0.33, 0.35), false)
	var omni := OmniLight3D.new(); omni.position = Vector3(0, 2.9, 0); omni.omni_range = 10.0; omni.light_energy = 0.35; omni.light_specular = 0.0; add_child(omni)
	label("FRESH MARKET", Vector3(0, 2.6, hz - 0.1), 90, Color(0.3, 0.6, 0.35), PI)
	for p in [Vector3(-hx + 0.4, 0, hz - 0.4), Vector3(hx - 0.4, 0, hz - 0.4)]: furn("pottedPlant", p, 0, 1.1, 0.0, true)
	box(Vector3(2.4, 0.9, 0.04), Vector3(-hx + 0.08, 1.7, -1.0), Color(1.0, 0.85, 0.3), false, PI / 2)
	label("SALE!\nRice 2 for 3.00", Vector3(-hx + 0.11, 1.7, -1.0), 60, Color(0.8, 0.15, 0.15), PI / 2, Color(1, 1, 1, 0))
	# ---- people
	person("assistant", "men", "joe", CK + Vector3(0.75, 0, -0.35), -PI / 2, "idle", Color(0.25, 0.55, 0.4))
	# c1 walks: person() leaves a static collider at the spawn point, so spawn her inside aisle 1's shelf body (collider hidden
	# there, never blocks a lane) and put her on her path right away
	var c1 := person("c1", "women", "kristin", Vector3(-3.3, 0, AISLE_Z), PI / 2, "idle", Color(0.85, 0.45, 0.6))
	c1.position = walker_path[0]
	var c2 := person("c2", "women", "hfc_female", Vector3(5.3, 0, -1.0), PI, "idle", Color(0.35, 0.5, 0.8))   # blue: browses toward the bakery, out of the lanes; her talk spot (5.3, -1.9) is 1.6 m from the bread spot
	c1.hold_item("res://props/places/basket.tscn", "long", 0.4, true); _basket_upright(c1)
	chat_target("c2", c2); chat_target("assistant", npcs.assistant)
	# ---- objective targets
	target("basket", Vector3(-1.6, 0, 3.5), Vector3(-1.6, 0.5, 4.2), "Take a basket")
	target("apples", APPLE_SPOT, Vector3(-6.2, 0.7, 2.0), "Take apples")
	target("milk", MILK_SPOT, Vector3(-4.8, 1.2, -4.4), "Take milk")
	target("bread", BREAD_SPOT, Vector3(4.6, 1.0, -4.3), "Take bread")
	target("pay", CK + Vector3(-0.85, 0, -0.2), CK + Vector3(0.75, 1.4, -0.35), "Pay")
	exit_door(Vector3(0, 0, hz - 0.75), Vector3(0, 1.2, hz))

## blue fix: hold_item("long") points the basket's +Y along the fingers, so with the arm hanging it was upside down.
## Re-orient the held pivot (hand-bone frame: +Y = fingers): basket up = -fingers (opening up), long side across the palm,
## and hang it below the hand so the handle (its top) sits in the grip. Only touches this shop's basket, not character.gd.
func _basket_upright(ch: DemoCharacter) -> void:
	var pv: Node3D = ch.held
	if pv == null or pv.get_child_count() == 0: return
	var inst := pv.get_child(0) as Node3D
	var b := pv.transform.basis
	var down := Vector3(0, -1, 0)   # opposite the fingers = up when the arm hangs
	var nb: Basis
	if absf(b.y.dot(Vector3.UP)) > 0.9:   # branch with the basket's X across the thumb: flip 180 deg about X
		nb = Basis(b.x, down, b.x.cross(down))
	else:                                 # branch with the basket's Z across the thumb
		nb = Basis(down.cross(b.z), down, b.z)
	var h: float = ch._aabb(inst).size.y * inst.scale.y
	pv.transform = Transform3D(nb.orthonormalized(), pv.position + Vector3(0, h * 0.45, 0))

## a heap of round fruit in a crate: one MultiMesh of spheres with slight colour variation
func _fruit_heap(top: Vector3, col: Color) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	var sm := SphereMesh.new(); sm.radius = 0.055; sm.height = 0.1; sm.radial_segments = 10; sm.rings = 6; mm.mesh = sm
	var pts: Array = []
	for ix in 6:
		for iz in 5: pts.append(Vector3(-0.3 + ix * 0.12, 0.05, -0.28 + iz * 0.14))
	for ix in 5:
		for iz in 4: pts.append(Vector3(-0.24 + ix * 0.12, 0.13, -0.21 + iz * 0.14))
	mm.instance_count = pts.size()
	var rng := RandomNumberGenerator.new(); rng.seed = int(top.x * 100.0)
	for n in pts.size():
		mm.set_instance_transform(n, Transform3D(Basis(), top + pts[n] + Vector3(rng.randf_range(-0.015, 0.015), 0, rng.randf_range(-0.015, 0.015))))
		mm.set_instance_color(n, col.lerp(Color(0.55, 0.08, 0.08), rng.randf_range(0.0, 0.35)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.45; mi.material_override = m; add_child(mi)

## a double-sided shelf unit (length along Z) filled with products: one MultiMesh per side, plus a few real models at the front
func _shelf_unit(c: Vector3, length: float, seed_i: int) -> void:
	box(Vector3(0.7, 1.9, length), c + Vector3(0, 0.95, 0), Color(0.36, 0.55, 0.52), true)
	for y in [0.12, 0.6, 1.08, 1.56]:
		box(Vector3(0.9, 0.04, length), c + Vector3(0, y, 0), Color(0.62, 0.64, 0.62), false)
		for s in [-1, 1]: box(Vector3(0.02, 0.06, length), c + Vector3(s * 0.45, y + 0.02, 0), Color(0.95, 0.6, 0.2), false)
	var rng := RandomNumberGenerator.new(); rng.seed = 11 + seed_i
	for s in [-1, 1]:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
		var bm := BoxMesh.new(); bm.size = Vector3(1, 1, 1); mm.mesh = bm
		var items: Array = []
		for y in [0.14, 0.62, 1.1, 1.58]:
			var z := -length / 2 + 0.12
			while z < length / 2 - 0.12:
				var w := rng.randf_range(0.1, 0.18); var h := rng.randf_range(0.16, 0.32); var d := rng.randf_range(0.12, 0.2)
				var col := Color.from_hsv(rng.randf(), rng.randf_range(0.45, 0.8), rng.randf_range(0.6, 0.95))
				var n := rng.randi_range(2, 3)
				for k in n: items.append([Transform3D(Basis().scaled(Vector3(d, h, w)), c + Vector3(s * (0.36 - k * 0.11), y + h / 2, z)), col])
				z += w + 0.03
		mm.instance_count = items.size()
		for i in items.size(): mm.set_instance_transform(i, items[i][0]); mm.set_instance_color(i, items[i][1])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm
		var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.roughness = 0.7; mi.material_override = m; add_child(mi)
	for k in 4: food(["can", "soda-bottle", "bottle-oil", "peanut-butter", "honey", "can-small"][(k + seed_i) % 6], c + Vector3(0.42, 1.1, -1.4 + k * 0.9), 0.16)

func run() -> void:
	Audio.music("shop_pop")
	busy(true)
	if not done("enter"): await cine(Vector3(5.0, 2.8, 4.0), Vector3(-1.0, 1.0, -2.0), 0.01)   # v32 polish: cut to the opening shot UNDER the fade-in (was a visible snap 0.6 s after it)
	await get_tree().create_timer(0.6).timeout
	Audio.sfx("place_bell", -8.0)
	if not done("enter"):
		var pan := cine_go(Vector3(-4.5, 2.6, 3.6), Vector3(1.5, 1.0, -2.5), 5.0)
		await beat("enter")
		if pan.is_running(): await pan.finished
		await cine_end(); mark("enter")
	if has_meta("story_hold"):   # build 3.2 (black #21): a day-4 / day-7 errand owns the visit (its own list: candles, a bottle of milk...)
		set_meta("ow_exit_ready", true)
		while has_meta("story_hold") and is_inside_tree(): await get_tree().process_frame
		await objective("exit", "Go outside.")
		await leave(); return
	if not done("teach"):   # first visit: the shopping list teaches countable / uncountable + how many / how much
		show_list()
		await beat("list"); await beat("teach")
		mark("teach")
	if not done("shopping"):
		if card_layer == null: show_list()
		await objective("basket", "Take a basket.")
		await walk_to(Vector3(-1.6, 0, 3.5), 0.0); player.hero.play("pick_up", 0.25); Audio.sfx("place_bag", -3.0)
		await say_line("I'm taking a basket.")
		player.hero.hold_item("res://props/places/basket.tscn", "long", 0.4, true); _basket_upright(player.hero); player.hero.play("idle", 0.3)
		await objective("apples", "Get six apples.", {"pos": Vector3(-5.2, 1.7, 0.6), "at": Vector3(-6.2, 0.7, 2.0)})
		await _pick(APPLE_SPOT, 0.0, {"pos": Vector3(-4.95, 1.55, 1.35), "at": Vector3(-6.2, 0.62, 2.1)}, "fruit", "apple")
		await objective("milk", "Get a bottle of milk.", {"pos": Vector3(-3.9, 1.7, -2.3), "at": Vector3(-4.8, 1.2, -4.4)})
		await _pick(MILK_SPOT, PI, {"pos": Vector3(-3.2, 1.7, -3.75), "at": Vector3(-4.7, 1.15, -4.25)}, "milk", "carton")   # v32 polish: side shot (the old one sat 0.8 m behind the head: the camera clipped into the player)
		await objective("bread", "Get a loaf of bread.", {"pos": Vector3(3.4, 1.8, -2.3), "at": Vector3(4.6, 1.0, -4.3)})
		await _pick(BREAD_SPOT, PI, {"pos": Vector3(4.0, 1.5, -2.9), "at": Vector3(4.6, 1.0, -4.3)}, "bread", "loaf")
		await objective("pay", "Pay at the checkout.", {"pos": Vector3(1.5, 2.0, 3.6), "at": CK + Vector3(0, 1.1, 0)})
		await checkout(); close_card(); mark("shopping")
	if not done("lesson"):
		await say_line("Now a short lesson and test on your phone.")
		var res := await phone_lesson(D.shop)
		save_score("test_score", res); mark("lesson")
	if not done("done"):
		await beat("done"); mark("done")
		await say_line("Well done! You finished the shop.")
	set_meta("ow_exit_ready", true)
	await get_tree().create_timer(1.5).timeout   # build 3.2 (v33.1): grace for a day errand (day 4 / 5 / 7) that starts on the entry hook to claim the visit
	while has_meta("story_hold") and is_inside_tree(): await get_tree().process_frame   # build 3.2: a day-4/7 checkout story first, "Go outside." only after buying
	await objective("exit", "Go outside.")
	await leave()

func show_list() -> void:
	teach_card("My shopping list", "Alışveriş listem", [["apple", "6 apples  (countable: How many?)", "6 elma (sayılabilir: How many?)"],
		["carton", "milk  (uncountable: How much?)", "süt (sayılamaz: How much?)"], ["loaf", "a loaf of bread  (uncountable)", "bir somun ekmek (sayılamaz)"]])

func _pick(spot: Vector3, yaw: float, shot: Dictionary, beat_name: String, item: String) -> void:
	await walk_to(spot, yaw)
	await cine(shot.pos, shot.at, 1.2)
	player.hero.play("pick_up", 0.25); Audio.sfx("cloth1", -10.0)
	await get_tree().create_timer(0.6).timeout
	basket_items.append(item); tick_card(item)
	await beat(beat_name)
	player.hero.play("idle", 0.3)
	await cine_end()

## cinematic checkout: items beep along the conveyor, close-ups on the till, payment, the bag
func checkout() -> void:
	var a: DemoCharacter = npcs.assistant
	await walk_to(CK + Vector3(-0.85, 0, -0.2), PI / 2)
	face(a, player.global_position)
	var L: Array = D.beats.shop.pay
	# v31 QA (blue): charge exactly what the assistant says ("six pounds forty"), shelf labels match (6 x 0.40 + 1.50 + 2.50);
	# Economy.buy() used the catalogue prices (7.50), so the voiced total and the wallet disagreed
	if Economy.spend(640, "shop: 6 apples, milk, bread"):
		for k in [["apple", 6], ["milk", 1], ["bread", 1]]: Economy.inventory[k[0]] = int(Economy.inventory.get(k[0], 0)) + int(k[1])
	await cine(CK + Vector3(-1.6, 1.8, 1.4), CK + Vector3(0.3, 1.2, -0.3), 1.2)
	await speak("assistant", L[0][1]); await speak("me", L[1][1])
	player.hero.release_item()
	var placed: Array = []
	for k in basket_items.size():   # each item onto the belt, slides to the scanner, beep
		var it: Node3D = ball(0.06, CK + Vector3(-0.1, 1.03, 0.75), Color(0.85, 0.15, 0.12)) if basket_items[k] == "apple" else food(String(basket_items[k]), CK + Vector3(-0.1, 0.97, 0.75), 0.16)
		placed.append(it)
		var tw := create_tween(); tw.tween_property(it, "position", CK + Vector3(-0.1, it.position.y, -0.3), 0.8)
		if k == 0: await cine(CK + Vector3(-0.9, 1.5, 0.6), CK + Vector3(-0.1, 0.98, -0.3), 0.8)
		if tw.is_valid() and tw.is_running(): await tw.finished
		Audio.sfx("place_beep", -13.0)
		var tw2 := create_tween(); tw2.tween_property(it, "position", CK + Vector3(-0.1, it.position.y, -0.75 + k * 0.12), 0.3)
	await cine(CK + Vector3(-1.2, 1.7, -0.9), CK + Vector3(0.1, 1.2, -0.75), 1.0)
	await speak("assistant", L[2][1])
	player.hero.play("pick_up", 0.25); Audio.sfx("place_coins", -8.0)
	await speak("me", L[3][1]); Audio.sfx("place_till", -4.0)
	await speak("assistant", L[4][1]); await speak("me", L[5][1])
	Audio.sfx("place_bag", -3.0)
	for p in placed: p.queue_free()
	player.hero.hold_item(FOOD + "bag.glb", "long", 0.42, true)
	await cine(CK + Vector3(-1.8, 1.6, 0.2), CK + Vector3(0.6, 1.3, -0.35), 1.0)
	await speak("assistant", L[6][1]); await speak("me", L[7][1])
	player.hero.play("idle", 0.3)
	await cine_end()

## v32 polish: one customer walks the aisles with a basket (walk clip speed matched to 1.1 m/s: no sliding feet; idle pose
## when she stops), the bakery customer browses (pick-up clip, never frozen on its last frame), the assistant glances / types.
var _amb_t := 4.0
var _wsteps := {}
func lively(dt: float) -> void:
	if not npcs.has("c1"): return
	if mode == "play":
		glance("assistant", dt, 8.0, 0.25); glance("c2", dt, 6.0, 0.35)
		_amb_t -= dt
		if _amb_t <= 0.0:
			_amb_t = randf_range(5.0, 8.0)
			if randi() % 2 == 0: gesture(npcs.c2, "pick_up", maxf(0.6, npcs.c2.anim_length("pick_up") - 0.1))
			elif CK.distance_to(lp(player)) > 2.5: nod(npcs.assistant, 2.5)   # v32 rule: "typing" is a seated clip (the standing assistant sat down)
	var w: DemoCharacter = npcs.c1
	var tgt: Vector3 = walker_path[walker_i]
	var d := tgt - w.position; d.y = 0
	if walker_t > 0.0:
		walker_t -= dt
		if walker_t <= 0.0: w.set_meta("pose", "walk"); w.play("walk", 0.3, WALKER_V / 1.7)
		return
	if d.length() < 0.08:
		walker_i = (walker_i + 1) % walker_path.size()
		if walker_i % 2 == 0: walker_t = 2.5; w.set_meta("pose", "idle"); w.play("idle", 0.3)
		return
	if w.get_meta("pose") != "walk" or w.player.current_animation != "walk": w.set_meta("pose", "walk"); w.play("walk", 0.3, WALKER_V / 1.7)
	w.position += d.normalized() * minf(dt * WALKER_V, d.length())
	if Footsteps.contact(w.player, w.anim_length("walk"), _wsteps): Footsteps.npc_step(w, player.global_position)   # v32 polish: her steps are heard like the street NPCs'
	w.rotation.y = lerp_angle(w.rotation.y, atan2(d.x, d.z), 1.0 - exp(-8.0 * dt))
