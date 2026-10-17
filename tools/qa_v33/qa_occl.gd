extends "res://scripts/qa_flow.gd"
## v33 blue: universal wall-occlusion fade QA. One short run: bedroom (mirror wall + right wall, south proximity) ->
## living room (left wall, breakfast force_fade) -> bathroom (left wall) -> shop -> cafe -> street building -> school room.
## godot --path . res://tools/qa_v33/qa_occl.tscn -- --save-path=<created save>   Shots -> res://docs/v33_wall_occlude/
func _ready() -> void:
	if name != "QAOCCL":
		var n = (get_script() as Script).new(); n.name = "QAOCCL"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = ProjectSettings.globalize_path("res://docs/v33_wall_occlude/"); DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()

func A(g: Node) -> float: return float(g.get_meta("wf_a", 1.0)) if is_instance_valid(g) else -1.0
func trace(tag: String, g: Node, t: float) -> Array:   # alpha samples every 0.05 s
	var out := []; var n := int(t / 0.05)
	for i in n: out.append(snappedf(A(g), 0.01)); await w(0.05)
	print("QOCC TRACE %s %s" % [tag, str(out)]); return out
var focus_node: Node3D = null
## every visible, non-faded mesh whose world AABB cuts the camera -> player chest segment (player meshes excluded)
func blockers() -> Array:
	var cam3 := get_viewport().get_camera_3d(); var out := []
	if cam3 == null or focus_node == null: return out
	var cp := cam3.global_position; var pc := focus_node.global_position + Vector3(0, 1.0, 0)
	var sc := get_tree().current_scene
	for g in sc.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if focus_node.is_ancestor_of(gi) or not (gi is VisualInstance3D): continue
		var ab: AABB = gi.global_transform * gi.get_aabb()
		var p2 := pc + (cp - pc).normalized() * 0.45
		if not ab.intersects_segment(cp, p2): continue
		if gi.has_meta("wh_view_only"): continue
		if ab.size.x > 20.0 or ab.size.z > 20.0: continue   # v33 int: block-wide merged ground / tree / lamp meshes: an AABB test cannot judge them   # v33 int: whole-house black void / ground twin (view-only layer, inside-out)
		if ab.grow(0.05).has_point(cp) and ab.grow(0.05).has_point(pc): continue   # v33 int: an AABB enclosing camera AND player (block-wide merged ground / tree / lamp multimesh) is not an occluder
		var a := float(gi.get_meta("wf_a", 1.0))
		var mat = gi.material_override
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_color.a < 0.3: a = minf(a, (mat as BaseMaterial3D).albedo_color.a)
		if a > 0.3: out.append("%s a=%.2f tr=%s ab=%s" % [gi.get_path(), a, str(mat.transparency) if mat is BaseMaterial3D else "-", str(ab)])
	return out
func mono(a: Array, down: bool) -> bool:
	for i in range(1, a.size()): if (a[i] > a[i - 1] + 0.001) if down else (a[i] < a[i - 1] - 0.001): return false
	return true
## blocked -> fade -> clear: shots before / after fade / restored, alpha trace checks
func blocked(tag: String, g: Node, set_blocked: Callable, set_clear: Callable, lo := 0.25) -> void:
	set_clear.call(); await w(0.8)
	var a0 := A(g)
	set_blocked.call(); await get_tree().process_frame; await shot(tag + "_1_blocked_before_fade")
	var cdiag := get_viewport().get_camera_3d(); print("QOCC DIAG2 %s cam_now=%s cam_obj=%s current_cam=%s a=%.2f vis=%s" % [tag, cdiag.global_position, cdiag.get_path(), cdiag.current, A(g), g.is_visible_in_tree()])
	var tr := await trace(tag + "_out", g, 0.9)
	await shot(tag + "_2_blocked_faded")
	var bl := blockers(); print("QOCC BLOCKERS %s %s" % [tag, str(bl)])
	ok(bl.is_empty(), "%s: no opaque mesh between camera and player when faded (%d)" % [tag, bl.size()])
	ok(a0 > 0.99 and tr.filter(func(x): return x > lo + 0.01 and x < 0.99).size() >= 1 and A(g) <= lo and mono(tr, true), "%s: wall fades gradually when it hides the player (%.2f -> %.2f)" % [tag, a0, A(g)])
	set_clear.call()
	var tb := await trace(tag + "_back", g, 0.9)
	await shot(tag + "_3_clear_restored")
	ok(A(g) > 0.99 and tb.size() > 3 and tb[2] < 0.99 and mono(tb, false), "%s: fades back gradually when no longer blocking" % tag)

## camera avoidance: default view blocked (avoid + fades frozen) -> avoidance on -> camera moved, player clear -> back
func avoid_test(tag: String, av, set_blocked: Callable, set_clear: Callable, freeze: Callable) -> void:
	set_clear.call(); await w(1.5)
	av.enabled = false; freeze.call(true)
	set_blocked.call(); await w(1.6)
	var b0 := blockers(); await shot(tag + "_A1_default_view_blocked")
	print("QOCC AVOID %s blocked-default blockers %s" % [tag, str(b0)])
	var c0 := get_viewport().get_camera_3d().global_position
	av.enabled = true; freeze.call(false)
	var moved := []
	for i in 6: await w(0.1); moved.append(snappedf(get_viewport().get_camera_3d().global_position.distance_to(c0), 0.01))
	await w(1.0)
	var b1 := blockers(); await shot(tag + "_A2_camera_adjusted")
	print("QOCC AVOID %s yaw %.2f k %.2f active %s fallback %s moved %s blockers %s" % [tag, av.t_yaw, av.t_k, av.active, av.fallback, str(moved), str(b1)])
	ok(not b0.is_empty(), "%s: default camera view really blocked (%d)" % [tag, b0.size()])
	ok(av.active and b1.is_empty() and moved[0] < moved[-1], "%s: camera moved smoothly to a clear spot, player visible" % tag)
	set_clear.call(); await w(3.5)
	await shot(tag + "_A3_back_to_default")
	ok(not av.active and absf(av.yaw) < 0.01 and absf(av.k - 1.0) < 0.01, "%s: camera eased back to its default offset" % tag)

func _run() -> void:
	if "--full" in OS.get_cmdline_user_args():
		pass
	# ---------------- living room
	await w(1.0); WorldState.load_game()
	App.continue_requested = true; App.came_from = "bedroom"
	Game.go_to("res://livingroom.tscn")
	ok(await _scene_is("res://livingroom.tscn", 40.0), "living room loaded")
	m = get_tree().current_scene; await w(3.0); m.mode = "play"
	var h: Node3D = m.hero; focus_node = h
	await avoid_test("living_avoid", m.cam_avoid, func(): h.position = Vector3(-3.0, 0, -0.5); m.cam_yaw = -1.3; m.cam_pitch = 0.6,
		func(): h.position = Vector3(0, 0, -0.5); m.cam_yaw = 0.0; m.cam_pitch = 0.9, func(v): m.wall_fade.enabled = not v)
	m.cam_override = true
	h.position = Vector3(-2.9, 0, -0.5)
	await blocked("living_leftwall", m.walls_l[0], func(): m.cam.position = Vector3(-7.6, 5.6, 0.0); m.cam.look_at(h.position + Vector3(0, 1.0, 0)),
		func(): m.cam.position = Vector3(0.0, 4.8, 6.5); m.cam.look_at(h.position + Vector3(0, 1.0, 0)))
	# breakfast force_fade (unchanged path)
	h.position = Vector3(0, 0, -1.5); m.cam.position = Vector3(0.0, 6.0, 1.5); m.cam.look_at(h.position)   # v33 int: camera INSIDE the room (north of the south wall), so the wall starts opaque (from the old spot south of it, it is faded in normal play -> 0.12)
	await w(3.0); var s0: float = A(m.walls_s[0])   # v33 int: let the south wall settle after the previous test
	m.wall_fade.force_fade(true); await w(0.15); var s1: float = A(m.walls_s[0]); await w(0.6); var s2: float = A(m.walls_s[0])
	await shot("living_breakfast_forcefade_on")
	m.wall_fade.force_fade(false); await w(0.15); var s3: float = A(m.walls_s[0]); await w(0.8); var s4: float = A(m.walls_s[0])
	print("QOCC living force_fade south alpha %.2f -> %.2f -> %.2f | back %.2f -> %.2f ; side wall %.2f" % [s0, s1, s2, s3, s4, A(m.walls_l[0])])
	ok(s1 < s0 and s1 > s2 and s2 <= 0.13 and s3 > s2 and s3 < s4, "living: breakfast force_fade still gradual out/back (south)")
	ok(A(m.walls_l[0]) > 0.99, "living: force_fade does not touch the side walls (as before)")
	m.cam_override = false
	# ---------------- shop + cafe (real lot entry), then a street building
	for lid in ["corner_shop"]:
		var pid := "shop" if lid == "corner_shop" else "cafe"
		App.came_from = "livingroom"
		Game.go_to(Game.WORLD_SCENE, "lot:" + lid)
		ok(await _scene_is(Game.WORLD_SCENE, 40.0), "%s: street" % pid)
		await w(3.0)
		var lot = get_tree().current_scene.grid.find_lot(lid)
		if lot == null: ok(false, "%s lot" % pid); continue
		lot._on_enter()
		ok(await _scene_is("res://scenes/places/%s.tscn" % pid, 30.0), "%s: entered" % pid)
		var sc = get_tree().current_scene; await w(3.0)
		await _place_test(pid, sc)
		sc.leave()
		ok(await _scene_is(Game.WORLD_SCENE, 30.0), "%s: left to the street" % pid)
		await w(2.5)
	await _street_test(get_tree().current_scene)
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("QOCC TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()

func _place_test(pid: String, sc) -> void:
	await wait_until(func(): return sc.get("_cine_cam") == null, 25.0)
	await w(0.5)
	var c: Camera3D = get_viewport().get_camera_3d()
	if c is CameraRig: (c as CameraRig).controlled = false
	var hx: float = sc.room.x / 2.0
	var wm: MeshInstance3D = null
	for wd in sc.walls: if (wd[1] as Vector3).x < -0.5: wm = wd[0]; break
	var p: Node3D = sc.player; focus_node = p
	if c is CameraRig:
		var rg := c as CameraRig; rg.controlled = true; var y0 := rg.yaw; var p0 := rg.pitch
		await avoid_test(pid + "_avoid", rg._avoid, func(): p.global_position = Vector3(-hx + 0.8, p.global_position.y, 0.0); rg.yaw = -PI / 2; rg.pitch = 0.6,
			func(): p.global_position = Vector3(0.0, p.global_position.y, 0.0); rg.yaw = y0; rg.pitch = p0, func(v): sc.set_process(not v))
		rg.controlled = false
	p.global_position = Vector3(-hx + 0.9, p.global_position.y, 0.0)
	print("QOCC DIAG %s walls=%s wm=%s cam=%s proc=%s" % [pid, str(sc.walls.map(func(wd): return [String(wd[0].name), wd[0].global_position, wd[1]])), str(wm.global_position) if wm else "null", c.global_position, sc.is_processing()])
	# v33 int: the place camera follows the player (player.attach_camera), so a hand-placed camera is overwritten every
	# frame; drive the real rig instead (yaw to the west side, low pitch) with avoidance off, so the wall must fade
	var rg2 = sc.cam as CameraRig
	if rg2: rg2.current = true
	if rg2:
		rg2.controlled = true; rg2.avoid = false; var yy: float = rg2.yaw; var pp: float = rg2.pitch; var dd: float = rg2.dist
		await blocked(pid + "_westwall", wm, func(): rg2.yaw = -PI / 2; rg2.pitch = 0.3; rg2.dist = 8.0,
			func(): rg2.yaw = yy; rg2.pitch = pp; rg2.dist = dd, 0.25)
		rg2.avoid = true
	else:
		ok(false, "%s_westwall: no CameraRig (%s)" % [pid, c])
	if is_instance_valid(c) and c is CameraRig: (c as CameraRig).controlled = true

func _street_test(ws) -> void:
	var p: Node3D = ws.player; focus_node = p; var best: MeshInstance3D = null; var bd := 1e9
	for n in get_tree().get_nodes_in_group("fade"):
		var d: float = (n as MeshInstance3D).global_transform.origin.distance_to(p.global_position)
		var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
		if ab.size.x > 3.0 and d < bd: bd = d; best = n
	if best == null: ok(false, "street: a fade building near the player"); return
	var ab: AABB = best.global_transform * best.get_aabb(); var cx := ab.get_center().x
	var cam: CameraRig = ws.cam
	var y0 := cam.yaw; var p0 := cam.pitch; var home := p.global_position
	await avoid_test("street_avoid", cam._avoid, func(): p.global_position = Vector3(cx, p.global_position.y, ab.position.z - 1.0); cam.yaw = 0.0; cam.pitch = 0.6,
		func(): p.global_position = Vector3(cx, p.global_position.y, ab.position.z - 7.0); cam.yaw = y0; cam.pitch = p0, func(v): ws.set_process(not v))
	cam.controlled = false
	p.global_position = Vector3(cx, p.global_position.y, ab.position.z - 1.3)
	print("QOCC street building aabb ", ab)
	await blocked("street_building", best, func(): cam.global_position = Vector3(cx + 1.5, 7.5, ab.end.z + 5.0); cam.look_at(p.global_position + Vector3(0, 1.0, 0)),
		func(): cam.global_position = Vector3(cx + 1.5, 5.0, ab.position.z - 9.0); cam.look_at(p.global_position + Vector3(0, 1.0, 0)), 0.02)
	print("QOCC street player at ", p.global_position)
	cam.controlled = true
