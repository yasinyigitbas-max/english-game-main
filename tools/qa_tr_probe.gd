extends Node
## v32-polish QA probe: phone lesson / family / jobs TR visibility (TR on, and TR off -> on).
func _dump(ph: Node, tag: String) -> void:
	var out := []
	var st := [ph]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Label or n is Button:
			var t: String = n.text
			if t != "": out.append("%s%s" % ["" if (n as CanvasItem).is_visible_in_tree() else "[H]", t.replace("\n", "|")])
		for c in n.get_children(): st.append(c)
	print("PROBE ", tag, " TR=", App.tr_on(), " :: ", " ; ".join(out.slice(0, 60)))
func _ready() -> void:
	for sp in ["res://scripts/main.gd", "res://scripts/livingroom.gd", "res://scripts/bathroom.gd", "res://scripts/phone.gd", "res://scripts/room_phone.gd",
			"res://scripts/core/objectives.gd", "res://scripts/props/wall_fade.gd", "res://scripts/story/story_ui.gd", "res://scripts/story/story_home.gd",
			"res://scripts/story/day2_morning.gd", "res://scripts/story/hospital.gd", "res://scripts/story/hospital_day2.gd", "res://ui/shared/hud.gd", "res://scripts/qa.gd"]:
		var g = load(sp)
		print("PROBE parse ", sp, " ok=", g is GDScript and (g as GDScript).can_instantiate())
	var cl := CanvasLayer.new(); add_child(cl)
	var ph = load("res://scripts/phone.gd").new(); ph.visible = true; ph.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(ph)
	await get_tree().process_frame
	App._trf = 0
	ph.start_set(App.load_json("res://data/can_should.json"), "lesson")
	for i in 40: await get_tree().process_frame
	_dump(ph, "lesson_off")
	App._trf = 1
	for i in 20: await get_tree().process_frame
	_dump(ph, "lesson_off_to_on")
	ph.start_set(App.load_json("res://data/can_should.json"), "lesson")
	for i in 20: await get_tree().process_frame
	_dump(ph, "lesson_on")
	ph.les = {}; ph._unlocking = true
	App._trf = 0
	for p in ["jobs", "family"]:
		ph._unlocking = true; ph.show_page(p, false)
		for i in 40: await get_tree().process_frame
		_dump(ph, p + "_off")
		App._trf = 1
		for i in 20: await get_tree().process_frame
		_dump(ph, p + "_off_to_on")
		App._trf = 0
	# tr_guard reversible: a Turkish label stripped/hidden while TR is off comes back when TR is on
	var lb := Label.new(); lb.text = "Bir defter al."; cl.add_child(lb)
	var lb2 := Label.new(); lb2.text = "Day 1  ·  Gün 1"; cl.add_child(lb2)
	App._trf = 0
	await get_tree().create_timer(1.0).timeout
	print("PROBE guard_off visible=", lb.visible, " text2=", lb2.text)
	App._trf = 1
	await get_tree().create_timer(1.0).timeout
	print("PROBE guard_on visible=", lb.visible, " text2=", lb2.text)
	# WallFade: a wall between camera and player fades gradually; force_fade
	var WF := preload("res://scripts/props/wall_fade.gd")
	var root3 := Node3D.new(); add_child(root3)
	var cam := Camera3D.new(); root3.add_child(cam); cam.position = Vector3(0, 2, 6)
	var pl := Node3D.new(); root3.add_child(pl); pl.position = Vector3(0, 0, 0)
	var wall := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(4, 2.5, 0.1); wall.mesh = bm; wall.material_override = StandardMaterial3D.new(); root3.add_child(wall); wall.position = Vector3(0, 1.25, 3)
	var far := MeshInstance3D.new(); var bm2 := BoxMesh.new(); bm2.size = Vector3(4, 2.5, 0.1); far.mesh = bm2; root3.add_child(far); far.position = Vector3(0, 1.25, -6)
	var wf = WF.attach(root3, cam, pl); wf.register(wall); wf.register(far)
	await get_tree().create_timer(0.15).timeout
	var a_mid := float(wall.get_meta("wf_a", 1.0))
	await get_tree().create_timer(0.6).timeout
	print("PROBE wallfade occluding a_mid=%.2f a_end=%.2f far=%.2f" % [a_mid, float(wall.get_meta("wf_a", 1.0)), float(far.get_meta("wf_a", 1.0))])
	pl.position = Vector3(0, 0, 5.0); cam.position = Vector3(0, 2, 7)   # walk out in front: wall behind the player
	await get_tree().create_timer(0.8).timeout
	print("PROBE wallfade clear a=%.2f" % float(wall.get_meta("wf_a", 1.0)))
	wf.force_fade(true); await get_tree().create_timer(0.8).timeout
	print("PROBE wallfade forced wall=%.2f far=%.2f" % [float(wall.get_meta("wf_a", 1.0)), float(far.get_meta("wf_a", 1.0))])
	wf.force_fade(false); await get_tree().create_timer(0.8).timeout
	print("PROBE wallfade unforced wall=%.2f far=%.2f mat_restored=%s" % [float(wall.get_meta("wf_a", 1.0)), float(far.get_meta("wf_a", 1.0)), str(far.material_override == null)])
	# StoryUI: one box, TR inside, claim hides others
	var sui := StoryUI.new(); add_child(sui)
	var other := PanelContainer.new(); other.add_to_group("caption_box"); cl.add_child(other); other.visible = true
	sui.en_l.text = "Hello."; sui.panel.visible = true
	await get_tree().process_frame
	print("PROBE storyui other_hidden=", not other.visible, " tr_btn_inside=", sui.tr_btn.get_parent().get_parent() == sui.panel)
	get_tree().quit()
