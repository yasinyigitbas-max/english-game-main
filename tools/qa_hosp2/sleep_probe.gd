extends Node3D
## v33 (red): what does the library "sleep" clip look like on every body (man, woman, boy, girl)? Side shots + hips/head/feet heights.
func _ready() -> void:
	var out := "/workspace/red_hosp2_qa/sleep_probe/"; DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.7, 0.75, 0.8); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color.WHITE; env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(3, 1.2, 5); cam.look_at(Vector3(3, 0.4, 0)); cam.current = true
	var chs := []
	var i := 0
	for g in [["men", false], ["women", false], ["men", true], ["women", true]]:
		var c := DemoCharacter.new(); add_child(c); c.setup(g[0]); if g[1]: c.set_child(true)
		c.position = Vector3(i * 2.0, 0, 0); c.play("sleep", 0.0); chs.append(c); i += 1
	var L: float = chs[0].anim_length("sleep")
	print("SLEEP length=", L, " loop=", chs[0].player.get_animation("sleep").loop_mode, " wake_up len=", chs[0].anim_length("wake_up"))
	for k in 6:
		var t := L * k / 5.0
		for c in chs:
			c.player.seek(t, true)
		await get_tree().process_frame; await get_tree().process_frame
		for c in chs:
			var sk: Skeleton3D = c.skeleton
			var s := "t=%.2f %s child=%s" % [t, c.gender, c.child]
			for bn in ["Hips", "Head", "Foot.L", "Hand.L", "Chest"]:
				var bi := sk.find_bone(bn)
				if bi >= 0: var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(bi).origin; s += " %s=(%.2f,%.2f,%.2f)" % [bn, p.x - c.position.x, p.y, p.z]
			print("PROBE ", s)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "sleep_%d.png" % k)
	# top view of frame 0
	for c in chs: c.player.seek(0.0, true)
	cam.position = Vector3(3, 6, 0.01); cam.look_at(Vector3(3, 0, 0))
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "sleep_top.png")
	get_tree().quit()
