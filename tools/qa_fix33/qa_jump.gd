## blue fix33 QA: start the real game scene (scenes/world.tscn as current_scene, like App.GAME_SCENE) and jump to one beat.
## godot ... res://tools/qa_fix33/qa_jump.tscn -- --ev=couch2 --shots=/dir/   (frames every 0.5 s + camera diagnostics)
extends Node
var ev := "couch2"
var shots := "/tmp/fix33/jump/"
var n := 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ev="): ev = a.substr(5)
		if a.begins_with("--shots="): shots = a.substr(8)
	DirAccess.make_dir_recursive_absolute(shots)
	run.call_deferred()
func _t(s: float) -> void: await get_tree().create_timer(s).timeout
func run() -> void:
	var st: Dictionary = {"day1_done": true, "day2": "done", "day2_work_done": true, "day2_hospital_done": true, "d2_couch_done": false}
	var state := {"family": [{"role": "mother", "name": "Ayse", "skin": 1, "hair": 0, "hcol": 1, "cloth": 0},
		{"role": "father", "name": "Mehmet", "skin": 2, "hair": 2, "hcol": 0, "cloth": 1}],
		"created": true, "job": "doctor", "lesson_done": true, "calendar_seen": true, "has_phone": true, "name": "Yasin", "tr": true, "voice": true, "age": "adult", "door_opened": true}
	App.patch_save({"story": st, "day": 2, "state": state, "family_breakfast": true, "has_phone": true})
	WorldState.day = 2; App.day = 2
	App.continue_requested = true
	get_tree().change_scene_to_file("res://scenes/world.tscn")
	if ev == "start" or ev.begins_with("cont"):
		for i in 24: await _t(0.4); _diag("boot%d" % i); _shot("boot%02d" % i)
		if ev == "start": get_tree().quit(); return
	else: await _t(7.0)
	_diag("start"); _shot("start")
	await OwLink.enter("livingroom", "bedroom")
	await _t(2.0)
	load("res://scripts/story/day2_evening.gd").start(get_tree())
	for i in 16: await _t(0.5); _diag("wait%d" % i); _shot("wait%02d" % i)
	var lr = get_tree().current_scene
	if lr and lr.get("hero"): lr.hero.position = Vector3(lr.SOFA_X - 1.2, 0, 0.3)   # the player walks to the couch
	for i in 50: await _t(0.5); _diag("beat%d" % i); _shot("beat%02d" % i)
	get_tree().quit()
func _diag(tag: String) -> void:
	var c := get_viewport().get_camera_3d(); var cs := get_tree().current_scene
	var vis := 0; var tot := 0; var hid: Array = []
	if cs is Node3D:
		for m in cs.find_children("*", "MeshInstance3D", true, false):
			tot += 1
			if (m as MeshInstance3D).is_visible_in_tree(): vis += 1
			elif hid.size() < 6: hid.append(str(cs.get_path_to(m)))
	var h = cs.get("hero") if cs else null
	print("FIX33 %s vis=%d/%d hero=%s fwd=%s cs_vis=%s hidden=%s" % [tag, vis, tot, str((h as Node3D).global_position.snapped(Vector3.ONE * 0.01)) if h is Node3D else "-", str((-c.global_transform.basis.z).snapped(Vector3.ONE * 0.01)) if c else "-", str(cs.visible) if cs is Node3D else "-", str(hid)])
	if World.inst: print("FIX33 %s world region=%s hp=%s active=%s indoor=%s regions=%s" % [tag, World.inst.region, str(World.inst.hero_pos()), str(World.inst.active), str(World.inst.indoor_vis), str(World.inst.regions) if tag == "start" else ""])
	if World.inst: print("FIX33 %s rig=%s cur=%s" % [tag, str(World.inst.cam.global_position.snapped(Vector3.ONE * 0.01)), World.inst.cam.current])
	var shc = get_tree().root.get_node_or_null("ShoulderCam")
	print("FIX33 %s shoulder=%s mode=%s" % [tag, str(shc.get("dbg")) if shc else "none", str(cs.get("mode")) if cs else "-"])
	print("FIX33 %s scene=%s cam=%s pos=%s obj=%s" % [tag, cs.name if cs else "-", str(c.get_path()) if c else "-", str(c.global_position.snapped(Vector3.ONE * 0.01)) if c else "-", str(Objectives.items.map(func(x): return x.en))])
func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	n += 1
	var img := get_viewport().get_texture().get_image(); img.convert(Image.FORMAT_RGB8)
	img.save_png(shots + "%03d_%s_%s.png" % [n, ev, nm])
