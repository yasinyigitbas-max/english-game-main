## v31 CAFE interior: counter + barista, cake display, menu boards, 4 tables, customers, lounge corner, warm lights.
## Flow (each beat once): enter pan -> "Go to the counter." -> cinematic order (how much / how many) -> "Sit at a table."
## -> phone lesson + test (countable / uncountable, how much / how many, ordering) -> "Go outside." (exit hook).
extends PlaceBase

const BAR_Z := -2.55
var seat_pos := Vector3(2.2, 0, 0.75)
var seat_yaw := PI
var cup_on_counter: Node3D
var steam: CPUParticles3D

func place_en() -> String: return "Cafe"
func place_tr() -> String: return "Kafe"
func floor_colors() -> Array: return [Color(0.55, 0.38, 0.27), Color(0.96, 0.91, 0.83), Color(0.47, 0.62, 0.55)]

func build() -> void:
	place_id = "cafe"; world_lot = "cafe"; room = Vector2(10.0, 8.0)
	var hz := room.y / 2.0
	# ---- counter (customer side faces +Z)
	for i in 5: furn("kitchenBar", Vector3(-3.0 + i * 0.95, 0, BAR_Z), 180, 1.0, 0.0, true)
	furn("kitchenBarEnd", Vector3(1.75, 0, BAR_Z), 180, 1.0, 0.0, true)
	box(Vector3(5.9, 0.05, 0.7), Vector3(-0.85, 1.02, BAR_Z), Color(0.36, 0.24, 0.17), false)
	# back counter + machines + shelves
	for i in 6: furn("kitchenCabinet", Vector3(-3.3 + i * 0.95, 0, -3.62), 0, 0.92, 0.0, true)
	box(Vector3(6.0, 0.04, 0.64), Vector3(-0.95, 0.94, -3.62), Color(0.25, 0.25, 0.27), false)
	furn("kitchenCoffeeMachine", Vector3(-1.6, 0.94, -3.65), 0, 0.5, 0.0, false)
	furn("kitchenCoffeeMachine", Vector3(-0.8, 0.94, -3.65), 0, 0.5, 0.0, false)
	furn("kitchenBlender", Vector3(0.6, 0.94, -3.62), 0, 0.36, 0.0, false)
	furn("kitchenMicrowave", Vector3(1.5, 0.94, -3.65), 0, 0.32, 0.0, false)
	for y in [1.55, 1.95]:
		box(Vector3(4.6, 0.04, 0.26), Vector3(-1.0, y, -3.8), Color(0.55, 0.38, 0.25), false)
		for k in 10:
			var x := -3.1 + k * 0.45
			if (k + int(y * 10)) % 3 == 0: cyl(0.06, 0.16, Vector3(x, y + 0.1, -3.8), [Color(0.9, 0.75, 0.45), Color(0.55, 0.35, 0.2), Color(0.95, 0.95, 0.9)][k % 3], false, 0.0)
			else: food("mug", Vector3(x, y + 0.02, -3.78), 0.12, 20.0 * k)
	# menu boards (chalkboard style)
	for b in [[-2.6, "COFFEE   2.50\nTEA      2.00\nHOT CHOC 3.00"], [-0.6, "COOKIE   0.75\nMUFFIN   2.20\nCROISSANT 1.80"], [1.4, "CARROT CAKE\n3.00\n* today *"]]:
		box(Vector3(1.6, 0.85, 0.05), Vector3(b[0], 2.45, -3.9), Color(0.12, 0.14, 0.13), false)
		box(Vector3(1.7, 0.95, 0.03), Vector3(b[0], 2.45, -3.92), Color(0.55, 0.38, 0.25), false)
		label(b[1], Vector3(b[0], 2.45, -3.86), 46, Color(0.98, 0.96, 0.88))
	label("MENU", Vector3(-0.6, 2.98, -3.86), 70, Color(1.0, 0.85, 0.5))
	# cake display on the counter
	box(Vector3(1.1, 0.34, 0.5), Vector3(0.75, 1.22, BAR_Z), Color(0.8, 0.92, 1.0), false, 0.0, 0.15).material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	(get_child(get_child_count() - 1) as MeshInstance3D).material_override.albedo_color.a = 0.3
	for k in 4: food(["cupcake", "croissant", "donut-sprinkles", "muffin"][k], Vector3(0.38 + k * 0.25, 1.06, BAR_Z), 0.14, 30.0 * k)
	food("cake", Vector3(-2.7, 1.045, BAR_Z), 0.3)
	food("cookie-chocolate", Vector3(-2.2, 1.05, BAR_Z + 0.1), 0.09); food("cookie", Vector3(-2.05, 1.05, BAR_Z - 0.05), 0.09)
	cyl(0.12, 0.2, Vector3(-1.4, 1.14, BAR_Z), Color(0.75, 0.8, 0.85), false)   # tip jar
	label("TIPS", Vector3(-1.4, 1.16, BAR_Z + 0.125), 22, Color(0.2, 0.2, 0.25), 0.0, Color(1, 1, 1, 0.8))
	box(Vector3(0.36, 0.26, 0.3), Vector3(-0.4, 1.17, BAR_Z), Color(0.2, 0.2, 0.22), false)   # till
	box(Vector3(0.3, 0.16, 0.02), Vector3(-0.4, 1.38, BAR_Z + 0.08), Color(0.3, 0.7, 0.5), false, 0.0, 0.6)
	# ---- seating: round tables + chairs, a lounge corner
	for t in [[Vector3(-3.0, 0, 0.6), true], [Vector3(-0.6, 0, 1.4), true], [Vector3(2.2, 0, 0.0), false], [Vector3(3.3, 0, 2.5), true]]:
		var c: Vector3 = t[0]
		cyl(0.45, 0.04, c + Vector3(0, 0.74, 0), Color(0.62, 0.42, 0.28)); cyl(0.05, 0.72, c + Vector3(0, 0.36, 0), Color(0.18, 0.18, 0.2)); cyl(0.25, 0.03, c + Vector3(0, 0.015, 0), Color(0.18, 0.18, 0.2))
		collider(Vector3(0.9, 0.76, 0.9), c + Vector3(0, 0.38, 0))
		for a in [0.0, PI]: _chair(c + Vector3(sin(a) * 0.66, 0, cos(a) * 0.66), a + PI, [Color(0.47, 0.62, 0.55), Color(0.93, 0.6, 0.45)][int(a > 0.1)])
		furn("plantSmall" + str(1 + int(abs(c.x)) % 3), c + Vector3(0.18, 0.75, -0.12), 0, 0.2, 0.0, false)
	seat_pos = Vector3(2.2, 0, 0.62); seat_yaw = PI
	food("cup-saucer", Vector3(-3.05, 0.76, 0.42), 0.12); food("croissant", Vector3(-2.85, 0.76, 0.75), 0.12)
	food("cup-tea", Vector3(-0.6, 0.76, 1.6), 0.1); food("cupcake", Vector3(-0.45, 0.76, 1.3), 0.09)
	food("frappe", Vector3(3.3, 0.76, 2.3), 0.16); food("donut", Vector3(3.1, 0.76, 2.6), 0.1)
	furn("loungeDesignSofa", Vector3(3.8, 0, -2.0), -90, 0.8, 0.0, true); furn("sideTable", Vector3(3.9, 0, -0.95), 0, 0.5, 0.0, true)
	furn("rugRound", Vector3(3.2, 0.0, -2.0), 0, 0.0, 2.0, false)
	food("cup-tea", Vector3(3.9, 0.51, -0.95), 0.1)
	box(Vector3(0.18, 0.04, 0.26), Vector3(3.55, 0.47, -1.7), Color(0.85, 0.3, 0.3), false)   # book on the sofa
	# plants, frames, windows, lights
	for p in [Vector3(-4.5, 0, -3.5), Vector3(4.5, 0, 3.5), Vector3(-4.5, 0, 3.5), Vector3(4.5, 0, -3.5)]: furn("pottedPlant", p, 30, 1.2, 0.0, true)
	for z in [-1.6, 1.2]:
		box(Vector3(0.06, 1.4, 1.8), Vector3(4.93, 1.6, z), Color(0.55, 0.78, 0.98), false, 0.0, 0.5)   # window (sky)
		box(Vector3(0.08, 1.5, 0.06), Vector3(4.92, 1.6, z), Color(1, 1, 1), false)
		box(Vector3(0.08, 0.06, 1.9), Vector3(4.92, 1.6, z), Color(1, 1, 1), false)
		box(Vector3(0.2, 0.05, 1.95), Vector3(4.86, 0.88, z), Color(1, 1, 1), false)
		food("plantSmall1" if false else "lemon", Vector3(4.86, 0.92, z + 0.4), 0.08)
	for f in [[Vector3(-4.92, 1.8, -1.0), Color(0.93, 0.52, 0.44)], [Vector3(-4.92, 1.7, 0.4), Color(0.4, 0.56, 0.76)], [Vector3(-4.92, 1.9, 1.7), Color(0.95, 0.8, 0.4)]]:
		var p: Vector3 = f[0]; box(Vector3(0.04, 0.6, 0.5), p, Color(0.3, 0.22, 0.16), false); box(Vector3(0.045, 0.5, 0.4), p, f[1], false)
	label("Corner Cafe", Vector3(-4.88, 2.55, 0.4), 90, Color(0.98, 0.9, 0.7), PI / 2)
	box(Vector3(room.x - 0.14, 0.06, 0.06), Vector3(0, 3.03, BAR_Z), Color(0.2, 0.17, 0.14), false)   # v32 polish: wooden beam the pendants hang from
	for t in [Vector3(-1.5, 0, BAR_Z), Vector3(0.5, 0, BAR_Z)]:   # pendant lamps over the counter (emissive, high so the top camera sees past them)
		cyl(0.006, 0.4, t + Vector3(0, 2.8, 0), Color(0.15, 0.15, 0.15))
		cyl(0.06, 0.18, t + Vector3(0, 2.52, 0), Color(0.2, 0.18, 0.16), false, 0.0, 0.22)
		ball(0.06, t + Vector3(0, 2.42, 0), Color(1.0, 0.85, 0.55), 3.0)
	# string lights: garlands fixed along the top of the side walls (cable + bulbs), hidden together with their wall by the
	# cutaway, so they never float in the air in front of the top-down camera (v31 QA fix)
	_garland(Vector3(-4.9, 2.86, -3.7), Vector3(-4.9, 2.86, 3.7), Vector3(-1, 0, 0))
	_garland(Vector3(4.9, 2.86, -3.7), Vector3(4.9, 2.86, 3.7), Vector3(1, 0, 0))
	var omni := OmniLight3D.new(); omni.position = Vector3(-0.8, 2.3, -1.5); omni.omni_range = 7.0; omni.light_energy = 0.7; omni.light_color = Color(1, 0.85, 0.65); omni.light_specular = 0.0; add_child(omni)
	omni.add_to_group("ow_no_ceiling")   # Yasin 00:12: no bright centre / ceiling light in any room (World hides them every frame)
	# steam over the coffee machine (shown while it brews)
	steam = CPUParticles3D.new(); steam.amount = 24; steam.lifetime = 1.2; steam.emitting = false; steam.position = Vector3(-1.6, 1.5, -3.55)
	steam.direction = Vector3(0, 1, 0); steam.spread = 12; steam.initial_velocity_min = 0.15; steam.initial_velocity_max = 0.3; steam.gravity = Vector3(0, 0.05, 0)
	var sm := SphereMesh.new(); sm.radius = 0.025; sm.height = 0.05; steam.mesh = sm
	var stm := StandardMaterial3D.new(); stm.albedo_color = Color(1, 1, 1, 0.35); stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; steam.material_override = stm; add_child(steam)
	# ---- people (CC0-licensed Piper voices only: amy, kristin, joe, hfc_female)
	person("barista", "women", "amy", Vector3(-1.0, 0, -3.15), 0.0, "idle", Color(0.2, 0.25, 0.3))
	box(Vector3(0.36, 0.5, 0.02), Vector3(-1.0, 1.0, -2.92), Color(0.55, 0.35, 0.22), false).visible = false
	var c1 := person("c1", "women", "kristin", Vector3(-3.0, 0, 0.0), 0.0, "sit_idle", Color(0.85, 0.5, 0.35))
	var c2 := person("c2", "men", "joe", Vector3(1.9, 0, -1.55), -2.6, "idle", Color(0.35, 0.6, 0.45))
	var c3 := person("c3", "women", "hfc_female", Vector3(3.75, 0, -2.0), -PI / 2, "sit_idle", Color(0.6, 0.45, 0.75))
	chat_target("c1", c1); chat_target("c2", c2); chat_target("c3", c3)
	# ---- objective targets
	target("counter", Vector3(-1.0, 0, -1.55), Vector3(-1.0, 1.4, -3.15), "Order a drink")
	target("seat", seat_pos + Vector3(0, 0, 0.55), Vector3(2.2, 0.8, 0.0), "Sit down")
	exit_door(Vector3(0, 0, room.y / 2.0 - 0.75), Vector3(0, 1.2, room.y / 2.0))

func _chair(p: Vector3, yaw: float, col: Color) -> void:
	var n := Node3D.new(); n.position = p; n.rotation.y = yaw; add_child(n)
	for b in [[Vector3(0.42, 0.05, 0.42), Vector3(0, 0.45, 0)], [Vector3(0.42, 0.42, 0.04), Vector3(0, 0.7, -0.19)]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = b[0]; mi.mesh = bm; mi.material_override = mat(col); mi.position = b[1]; n.add_child(mi)
	for lx in [-0.18, 0.18]:
		for lz in [-0.17, 0.17]:
			var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.03, 0.44, 0.03); mi.mesh = bm; mi.material_override = mat(Color(0.35, 0.25, 0.18)); mi.position = Vector3(lx, 0.22, lz); n.add_child(mi)

## a wall garland from a to b (on the wall with outward normal n): 6 scallops, cable segments + emissive bulbs, registered with
## the wall cutaway (walls[]) so the whole garland hides when its wall does
func _garland(a: Vector3, b: Vector3, n: Vector3) -> void:
	var cols := [Color(1, 0.8, 0.4), Color(1, 0.55, 0.5), Color(0.6, 0.85, 1)]
	var pts: Array = []
	var N := 36
	for i in N + 1:
		var f := float(i) / N
		pts.append(a.lerp(b, f) + Vector3(0, -0.16 * sin(f * PI * 6.0) ** 2, 0) - n * 0.02)
	for i in N:
		var p0: Vector3 = pts[i]; var p1: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.008, 0.008, p0.distance_to(p1)); seg.mesh = bm
		seg.material_override = mat(Color(0.12, 0.1, 0.08)); add_child(seg)
		seg.look_at_from_position((p0 + p1) * 0.5, p1, Vector3.UP if absf((p1 - p0).normalized().y) < 0.99 else Vector3.RIGHT)
		walls.append([seg, n])
		if i % 2 == 1:
			var bl := ball(0.028, p0 + Vector3(0, -0.03, 0), cols[(i / 2) % 3], 2.5); walls.append([bl, n])

func run() -> void:
	Audio.music("cafe_lofi")
	busy(true)
	if not done("enter"): await cine(Vector3(3.5, 2.6, 3.0), Vector3(-1.0, 1.0, -2.5), 0.01)   # v32 polish: cut to the opening shot UNDER the fade-in (was a visible snap 0.6 s after it)
	await get_tree().create_timer(0.6).timeout
	Audio.sfx("place_bell", -8.0)
	if not done("enter"):
		var pan := cine_go(Vector3(-3.5, 2.4, 2.6), Vector3(0.5, 1.0, -2.6), 5.0)
		await beat("enter")
		if pan.is_running(): await pan.finished
		await cine_end(); mark("enter")
	if not done("teach"):   # first visit: how to order food and drinks (menu card + narrator)
		await cine(Vector3(-0.6, 1.6, -1.0), Vector3(-0.6, 2.45, -3.9), 1.4)   # v32 polish: lower camera, the pendant lamps sit above the boards instead of over them
		teach_card("How to order", "Nasıl sipariş verilir", [["like", "I'd like a hot chocolate, please.", "Bir sıcak çikolata istiyorum, lütfen."], ["can", "Can I have a cookie, please?", "Bir kurabiye alabilir miyim, lütfen?"],
			["much", "How much milk? A little, please.", "Ne kadar süt? Biraz, lütfen."], ["many", "How many cookies? Two, please.", "Kaç kurabiye? İki tane, lütfen."], ["here", "For here or to go?", "Burada mı, götürmek için mi?"]])
		await beat("teach")
		await cine_end(); mark("teach")
	if not done("order"):
		await objective("counter", "Go to the counter.", {"pos": Vector3(1.2, 2.0, 0.2), "at": Vector3(-1.0, 1.3, -3.0)})
		await order(); close_card(); mark("order")
	if not done("sit"):
		await objective("seat", "Sit at a table.")
		await sit(); mark("sit")
	if not done("lesson"):
		await say_line("Now a short lesson and test on your phone.")
		var res := await phone_lesson(D.cafe)
		save_score("test_score", res); mark("lesson")
	if player.sitting: player.stand_up(); player.hero.release_item()
	if not done("done"):
		await beat("done"); mark("done")
		await say_line("Well done! You finished the cafe.")
	await objective("exit", "Go outside.")
	await leave()

## the cinematic order: close two-shot, pans to the menu, the cake display, the coffee machine; payment; cup into the hand
func order() -> void:
	var b: DemoCharacter = npcs.barista
	await walk_to(Vector3(-1.0, 0, -1.55), PI)
	face(b, player.global_position)
	var L: Array = D.beats.cafe.order
	Economy.spend(450, "cafe: hot chocolate + 2 cookies")   # v31: "That's four pounds fifty" (no cafe items in shops.json)
	await cine(Vector3(0.4, 1.75, -0.6), Vector3(-1.2, 1.35, -2.8), 1.2)
	await speak("barista", L[0][1])
	tick_card("like")
	await cine(Vector3(-0.6, 1.6, -1.0), Vector3(-0.6, 2.45, -3.9), 1.3)   # the menu board (v32 polish: no pendant lamp in front of it)
	await speak("me", L[1][1])
	await cine(Vector3(0.3, 1.8, -0.9), Vector3(-1.0, 1.3, -3.0), 1.0)
	await speak("barista", L[2][1]); await speak("me", L[3][1]); tick_card("much")
	await cine(Vector3(0.9, 1.55, -1.5), Vector3(0.75, 1.15, BAR_Z), 1.2)   # cake display + cookies
	await speak("barista", L[4][1]); await speak("me", L[5][1]); tick_card("many"); tick_card("can")
	await speak("barista", L[6][1]); await speak("me", L[7][1]); tick_card("here")
	# brewing: barista turns to the machine, steam + hiss, camera on the machine
	b.play("typing", 0.3); create_tween().tween_property(b, "rotation:y", PI, 0.4)
	steam.emitting = true; Audio.sfx("place_steam", -5.0)
	await cine(Vector3(-1.1, 1.6, -2.4), Vector3(-1.6, 1.2, -3.6), 1.4)
	await get_tree().create_timer(1.2).timeout
	steam.emitting = false; Audio.sfx("place_clink", -5.0)
	cup_on_counter = food("cup-coffee", Vector3(-1.0, 1.045, BAR_Z + 0.15), 0.12)
	b.play("idle", 0.3); face(b, player.global_position)
	await cine(Vector3(0.2, 1.7, -0.9), Vector3(-1.0, 1.15, BAR_Z), 1.0)
	await speak("barista", L[8][1])
	player.hero.play("pick_up", 0.25); Audio.sfx("place_coins", -8.0)
	await speak("me", L[9][1])
	Audio.sfx("place_till", -4.0)
	await speak("barista", L[10][1])
	if is_instance_valid(cup_on_counter): cup_on_counter.queue_free()
	player.hero.hold_item(FOOD + "cup-coffee.glb", "cylinder", 0.1, false); Audio.sfx("place_clink", -5.0)
	player.hero.play("idle", 0.3)
	await speak("me", L[11][1])
	await cine_end()

func sit() -> void:
	await walk_to(seat_pos + Vector3(0, 0, 0.5), PI)
	player.sit_at(seat_pos, seat_yaw)
	await cine(Vector3(3.6, 1.7, 1.8), Vector3(2.2, 0.9, 0.2), 1.4)
	if player.hero.held: pass
	food("cup-coffee", Vector3(2.2, 0.76, 0.28), 0.1); food("cookie", Vector3(2.4, 0.76, 0.2), 0.07); food("cookie-chocolate", Vector3(2.32, 0.77, 0.34), 0.07)
	player.hero.release_item()
	await beat("sit")
	await cine_end()

## v32 polish: the cafe feels alive between the beats: seated customers glance around, the standing customer takes a
## phone call now and then, the barista works the till / chats; nothing moves while a scripted beat owns the NPCs.
var _lt := 0.0
func lively(dt: float) -> void:
	if mode != "play" or not npcs.has("c1"): return
	for id in ["c1", "c3", "c2", "barista"]: glance(id, dt, 7.0 if id != "barista" else 9.0, 0.3 if id != "barista" else 0.2)
	_lt += dt
	if _lt < 6.0: return
	_lt = randf_range(-1.5, 1.0)
	match randi() % 3:
		0: gesture(npcs.c2, "phone_call", 6.0)
		1: nod(npcs.barista, 2.5)   # v32 rule: "typing" / "talk" are seated clips -> a standing barista / customer sat down
		_: nod([npcs.c2, npcs.barista][randi() % 2], 1.8)
