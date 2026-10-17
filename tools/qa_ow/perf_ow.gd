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
	var sc: Node = (load("res://scenes/world_exterior.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sc); get_tree().current_scene = sc
	for i in 90: await get_tree().process_frame
	var s0: Vector3 = sc.player.global_position
	P("start %s" % s0)
	var places := WorldPlaces.add_all(sc, {"cafe": s0 + Vector3(-14, 0, -16), "shop": s0 + Vector3(0, 0, -16), "work": s0 + Vector3(14, 0, -16)})
	var wwf: Node = load("res://scripts/world/world_wall_fade.gd").new(); sc.add_child(wwf)
	for i in 30: await get_tree().process_frame
	var spots := [["street", s0, PI], ["street_turn", s0, 0.0], ["before_shop", s0 + Vector3(0, 0, -10.5), PI], ["in_shop", s0 + Vector3(0, 0, -16.5), PI], ["far", s0 + Vector3(40, 0, 30), PI]]
	for sp in spots: await _measure("off " + sp[0], sc, sp[1], sp[2])
	var wc: Node = load("res://scripts/world/world_culling.gd").new(); sc.add_child(wc)
	for i in 10: await get_tree().process_frame
	P("culling stats %s" % [wc.stats])
	for sp in spots: await _measure("on  " + sp[0], sc, sp[1], sp[2])
	wc.occluders = false; get_viewport().use_occlusion_culling = false
	for o in wc._occ: if is_instance_valid(o[0]): o[0].visible = false
	for sp in spots: await _measure("on-no-occl " + sp[0], sc, sp[1], sp[2])
	for id in places: P("place %s ok=%s walls=%d door=%s" % [id, places[id] != null, (places[id].get("walls") as Array).size(), places[id].get("door_hinge") != null])
	var f := FileAccess.open("/tmp/blue_perf.txt", FileAccess.WRITE); f.store_string("\n".join(out)); f.close()
	get_tree().quit()
