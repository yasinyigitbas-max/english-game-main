## v34 open world (blue): one smoke + perf run: World without blue's parts, then WorldBlue.install(world); draw calls / fps
## at a few spots; a screenshot of the café front. Writes /tmp/blue_perf.txt and /workspace/blue_ow_shots/.
extends Node
var out := []
func P(s: String) -> void: print("PERF ", s); out.append(s)
func _ready() -> void: _run.call_deferred()

func _measure(tag: String, sc: Node, at: Vector3, yaw: float) -> void:
	sc.player.global_position = at; sc.player.face(yaw)
	var sh = get_tree().root.get_node_or_null("ShoulderCam")
	if sh: sh.snap()
	for i in 30: await get_tree().process_frame
	var n := 0; var dc := 0.0; var pr := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1500:
		await get_tree().process_frame
		n += 1; dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME); pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	P("%s fps=%.1f draw_calls=%.0f primitives=%.0f" % [tag, n / ((Time.get_ticks_msec() - t0) / 1000.0), dc / n, pr / n])

func _run() -> void:
	var WB = load("res://scripts/world/world_blue.gd"); WB.disabled = true
	var sc: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(sc); get_tree().current_scene = sc
	for i in 60: await get_tree().process_frame
	var W = load("res://scripts/core/world.gd")
	var s0: Vector3 = sc.player.global_position
	var fr: Vector3 = W.spot("front"); var cf: Vector3 = W.spot("cafe")
	var shc: Vector3 = (sc.regions["shop"] as AABB).get_center()
	var spots := [["bedroom", s0, PI], ["street", fr + Vector3(0, 0, 4.0), PI], ["cafe_front", cf + Vector3(0, 0, -4.5), PI], ["in_shop", Vector3(shc.x, 0.07, shc.z), PI]]
	for sp in spots: await _measure("before " + sp[0], sc, sp[1], sp[2])
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = WB.install(sc, {"force": true})
	while not r.get("ready", false): await get_tree().process_frame
	P("install took %d ms" % (Time.get_ticks_msec() - t0))
	for i in 20: await get_tree().process_frame
	P("merge %s" % [r.get("merge")])
	P("installed culling=%s fronts=%s/%s walls=%d" % [r.culling.stats, r.get("front_cafe") != null, r.get("front_shop") != null, (r.wall_fade.wf._walls as Array).size()])
	for sp in spots: await _measure("after  " + sp[0], sc, sp[1], sp[2])
	DirAccess.make_dir_recursive_absolute("/workspace/blue_ow_shots")
	for k in [["cafe", cf], ["shop", W.spot("shop")]]:
		sc.player.global_position = k[1] + Vector3(0, 0, -5.0); sc.player.face(0.0)
		var sh = get_tree().root.get_node_or_null("ShoulderCam")
		if sh: sh.snap()
		for i in 40: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/workspace/blue_ow_shots/front_%s.png" % k[0])
	var f := FileAccess.open("/tmp/blue_perf.txt", FileAccess.WRITE); f.store_string("\n".join(out)); f.close()
	get_tree().quit()
