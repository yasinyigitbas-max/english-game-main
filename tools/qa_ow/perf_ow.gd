## v34 open world (blue): short perf measurement (part 4). Street scene + the 3 world places + WorldWallFade, measured at
## a few spots with WorldCulling off, then on. Prints PERF lines; writes /tmp/blue_perf.txt.
extends Node
var out := []
func P(s: String) -> void: print("PERF ", s); out.append(s)

func _ready() -> void: _run.call_deferred()

func _measure(tag: String, sc: Node, at: Vector3, yaw: float) -> void:
	sc.player.global_position = at; sc.player.face(yaw)
	var sh = get_tree().root.get_node_or_null("ShoulderCam")
	if sh: sh.snap()
	if sc.get("grid"): sc.grid.load_around_now(at)
	for i in 40: await get_tree().process_frame
	var n := 0; var fps := 0.0; var dc := 0.0; var ob := 0.0; var pr := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500:
		await get_tree().process_frame
		n += 1; dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		ob += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME); pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	fps = n / ((Time.get_ticks_msec() - t0) / 1000.0)
	P("%s fps=%.1f draw_calls=%.0f objects=%.0f primitives=%.0f" % [tag, fps, dc / n, ob / n, pr / n])

func _run() -> void:
	var sc: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sc); get_tree().current_scene = sc
	for i in 90: await get_tree().process_frame
	var s0: Vector3 = sc.player.global_position
	P("start %s" % s0)
	var places := WorldPlaces.add_all(sc)   # World has café + shop: adds work at the reserved slot
	var wwf: Node = load("res://scripts/world/world_wall_fade.gd").new(); sc.add_child(wwf)
	for i in 30: await get_tree().process_frame
	var W = load("res://scripts/core/world.gd")
	var fr: Vector3 = W.spot("front"); var cf: Vector3 = W.spot("cafe"); var sh: Vector3 = W.spot("shop")
	var shc: Vector3 = (sc.regions["shop"] as AABB).get_center() if sc.regions.has("shop") else sh
	var spots := [["bedroom", s0, PI], ["front_door_street", fr + Vector3(0, 0, 2.5), PI], ["street_turn", fr + Vector3(0, 0, 6.0), 0.0],
		["before_cafe", cf + Vector3(0, 0, -3.0), 0.0], ["in_shop", Vector3(shc.x, 0.07, shc.z), PI], ["far_street", fr + Vector3(30, 0, 18), PI]]
	for sp in spots: await _measure("off " + sp[0], sc, sp[1], sp[2])
	var wc: Node = load("res://scripts/world/world_culling.gd").new(); sc.add_child(wc)
	for i in 10: await get_tree().process_frame
	P("culling stats %s wallfade walls=%d" % [wc.stats, (wwf.wf._walls as Array).size()])
	for sp in spots: await _measure("on  " + sp[0], sc, sp[1], sp[2])
	for id in places: P("place %s ok=%s walls=%d door=%s at=%s" % [id, places[id] != null, (places[id].get("walls") as Array).size(), places[id].get("door_hinge") != null, places[id].global_position])
	var f := FileAccess.open("/tmp/blue_perf.txt", FileAccess.WRITE); f.store_string("\n".join(out)); f.close()
	get_tree().quit()
