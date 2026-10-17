## v32 int: day-1 hospital (res://scenes/hospital.tscn, the scene story_accident.gd opens) -> log captions, shot on the body answers
extends SceneTree
const OUT := "/workspace/v32_int/qa/hosp1_"
func _initialize() -> void: _go.call_deferred()
func shot(n: String) -> void:
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + n); print("SHOT ", n)
func _go() -> void:
	Engine.time_scale = 3.0
	await process_frame
	change_scene_to_file("res://scenes/hospital.tscn")
	var t := 0.0; var last := ""; var n := 0
	while t < 240.0:
		await create_timer(0.25).timeout; t += 0.25
		var h = current_scene
		if h == null or not String(h.scene_file_path).ends_with("hospital.tscn"):
			if t > 20: print("QA left scene: ", h.scene_file_path if h else "-"); break
			continue
		if h.get("ui") == null: continue
		var cap: String = h.ui.en_l.text if h.ui.panel.visible else ""
		if not h.has_meta("trchk") and h.ui.panel.visible:
			h.set_meta("trchk", true)
			var trb = null
			for b in h.find_children("*", "Button", true, false): if String(b.text).strip_edges() == "TR" and b.is_visible_in_tree(): trb = b
			print("QA TR button inside the caption box: ", trb != null and h.ui.panel.is_ancestor_of(trb), " (", trb.get_path() if trb else "none", ")")
		var nbox := 0
		for bx in root.get_nodes_in_group("caption_box"): if bx is Control and bx.is_visible_in_tree(): nbox += 1
		if nbox > 1: print("QA BOXES >1: ", nbox, " cap=", h.ui.en_l.text)
		if cap != last:
			last = cap; print("CAP ", cap, " | TR ", h.ui.tr_l.text)
			if cap.begins_with("My ") and n < 5: n += 1; await shot("answer_%d.png" % n)
		if cap.contains("You are fine"): await shot("doctor_fine.png"); break
		var ph = h.get("phone")
		if ph and ph.visible:
			for b in ph.find_children("*", "Button", true, false):
				if b.is_visible_in_tree() and not b.disabled and (b.name in ["LessonNext", "SkipTest", "ScoreContinue"]): b.pressed.emit(); break
	Engine.time_scale = 1.0; quit()
