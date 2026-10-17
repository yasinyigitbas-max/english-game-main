extends Node3D
## v29 dev-only: screenshots of the doctor coat (idle + flashlight arm raise). Not exported (tools/*).
func _ready() -> void:
	var e := WorldEnvironment.new(); var en := Environment.new(); en.background_mode = Environment.BG_COLOR; en.background_color = Color(0.6, 0.65, 0.7)
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; en.ambient_light_color = Color.WHITE; en.ambient_light_energy = 0.6; e.environment = en; add_child(e)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); add_child(sun)
	var d := DemoCharacter.new(); add_child(d); d.setup("men"); d.top_color = Color(0.97, 0.97, 0.97); d.set_height("medium"); d._refresh()
	d.play("idle", 0.0); DoctorCoat.dress(d)
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40
	for v in [["front", Vector3(0.4, 1.1, 2.6)], ["side", Vector3(2.6, 1.1, 0.3)]]:
		cam.look_at_from_position(v[1], Vector3(0, 0.95, 0)); await _shot("idle_" + v[0])
	d.bone_offsets["UpperArm.R"] = [Vector3.RIGHT, -1.4]; d.bone_offsets["LowerArm.R"] = [Vector3.RIGHT, -0.1]
	await get_tree().create_timer(0.4).timeout
	for v in [["front", Vector3(0.4, 1.1, 2.6)], ["side", Vector3(-2.6, 1.2, 0.6)]]:
		cam.look_at_from_position(v[1], Vector3(0, 1.0, 0)); await _shot("arm_" + v[0])
	get_tree().quit()
func _shot(n: String) -> void:
	for i in 6: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/coat/%s.png" % n)
