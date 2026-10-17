extends "res://scripts/qa_flow.gd"
## v32 blue smoke (one short run): street -> shop (crates / bread / caption with TR / south-wall fade shots) -> leave ->
## cafe -> leave. Shots -> res://qa_shots/ (export-excluded tool).
func _ready() -> void:
	if name != "QA32B":
		var n = (get_script() as Script).new(); n.name = "QA32B"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	shot_dir = ProjectSettings.globalize_path("res://qa_shots/") ; DirAccess.make_dir_recursive_absolute(shot_dir)
	App.save_tr(true)
	await w(1.0); WorldState.load_game()
	for lid in ["corner_shop", "cafe"]:
		var pid := "shop" if lid == "corner_shop" else "cafe"
		App.came_from = "livingroom"
		Game.go_to(Game.WORLD_SCENE, "lot:" + lid)
		ok(await _scene_is(Game.WORLD_SCENE, 40.0), "%s: street" % pid)
		await w(3.0)
		var lot = get_tree().current_scene.grid.find_lot(lid)
		ok(lot != null and lot.interior_scene != "", "%s: lot wired (%s)" % [pid, lot.interior_scene if lot else "-"])
		if lot == null: continue
		lot._on_enter()
		ok(await _scene_is("res://scenes/places/%s.tscn" % pid, 30.0), "%s: entered" % pid)
		var sc = get_tree().current_scene
		await w(4.0)
		ok(sc.is_in_group("places"), "%s: in group places" % pid)
		if pid == "shop":
			var c := Camera3D.new(); c.fov = 55.0; sc.add_child(c)
			c.global_transform = Transform3D(Basis.looking_at(Vector3(0, -11.5, -6.5)), Vector3(0, 12.0, 6.5)); c.current = true
			await w(1.5); await shot("v32_shop_overview_crates_bread_fadedsouth")
			c.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1.0, -5.5)), Vector3(0.5, 2.6, 6.2))
			await w(1.2); await shot("v32_shop_south_wall_faded")
			var line := ""
			for k in sc.TRD: line = String(k); break
			sc.hud.set_tr(true); sc.hud.caption(line if line != "" else "Get six apples.", 6.0)
			await w(0.8); await shot("v32_caption_tr_inside")
			print("QA32B caption panels visible: ", sc.hud.root.find_children("Caption*", "PanelContainer", true, false).filter(func(p): return p.visible).size())
		sc.leave()
		ok(await _scene_is(Game.WORLD_SCENE, 30.0), "%s: left to the street" % pid)
		await w(2.0)
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("QA32B TOTAL %d PASS %d FAIL" % [pc, fc]); get_tree().quit()
