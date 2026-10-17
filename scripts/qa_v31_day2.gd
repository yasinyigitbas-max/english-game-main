## v31 QA (throwaway): HospitalScene.start_day2_visit -> clear visit -> questions -> quiz (wrong round -> study tip -> Retake v2 -> pass) -> continue
extends SceneTree
const OUT := "/workspace/story_red_v31/shots/"
func _initialize() -> void: _go.call_deferred()
func shot(n: String) -> void:
	await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT + n); print("SHOT ", n)
func _go() -> void:
	Engine.time_scale = 3.0
	await process_frame
	var ws = root.get_node_or_null("WorldState")
	if ws: ws.day = 2   # simulate arriving from the day-2 car (in-memory world state)
	root.get_node("App").day = 2
	load("res://scripts/story/hospital.gd").start_day2_visit(self)
	var t := 0.0; var seen := {}; var wrong := true; var last := ""; var h = null; var v1 := ""
	while true:
		await create_timer(0.25).timeout; t += 0.25
		if t > 500: print("QA FAIL timeout ", seen); quit(1); return
		var sc = current_scene
		if sc == null: continue
		if not String(sc.scene_file_path).ends_with("hospital_day2.tscn"):
			if seen.has("continue_btn"): seen["left_scene"] = sc.scene_file_path; break
			continue
		h = sc
		if h.ui == null: continue
		if not seen.has("entry"): seen["entry"] = true; print("QA tr_setting=", h.S.tr, " blur amount=", h._ba)
		var cap: String = h.ui.en_l.text if h.ui.panel.visible else ""
		if cap != last: last = cap; print("CAP ", cap, " | TR(vis=", h.ui.tr_l.visible, ") ", h.ui.tr_l.text)
		if not seen.has("hello") and cap.contains("Hello again"): seen["hello"] = true; await create_timer(0.6).timeout; await shot("v31_d2_wide.png")
		var lw = h.find_child("PartWord", true, false)
		if lw and lw.is_visible_in_tree() and lw.text == "shoulders": Engine.time_scale = 1.0   # real speed around the back close-up
		if lw and lw.is_visible_in_tree() and lw.text == "back" and not seen.has("back_iv"):
			seen["back_iv"] = true; await create_timer(0.8).timeout; await shot("v31_d2_zoom_back_noiv.png"); Engine.time_scale = 3.0
		if lw and lw.is_visible_in_tree() and not seen.has("zoom_" + lw.text):
			seen["zoom_" + lw.text] = true; await create_timer(0.45).timeout; await shot("v31_d2_zoom_%s.png" % lw.text.replace(" ", "_"))
			if lw.text == "stomach": h.set_tr(true); await create_timer(0.3).timeout; await shot("v31_d2_zoom_stomach_tr_on.png"); h.set_tr(false); seen["tr_on"] = true
		if not seen.has("backans") and cap.contains("My back hurts"):
			seen["backans"] = true; h.set_tr(true); await shot("v31_d2_answer_back_tr_on.png"); h.set_tr(false)
		var ph = h.phone
		if not ph.visible: continue
		if ph.page == "lesson":
			var nb = ph.find_child("LessonNext", true, false)
			if nb and not root.get_node("Audio").is_speaking():
				if not seen.has("lesson%d" % ph.lesson_i): seen["lesson%d" % ph.lesson_i] = true; await shot("v31_d2_lesson_%d%s.png" % [ph.lesson_i, "_study" if seen.has("score_suggest") else ""])
				nb.pressed.emit()
		elif ph.page == "quiz":
			var row = ph.find_child("Options", true, false)
			if row and not row.get_child(0).disabled:
				var q: Dictionary = ph._qz()[ph.quiz_i]
				if ph.quiz_i == 0:
					if wrong: v1 = q.q
					elif not seen.has("v2"): seen["v2"] = true; print("QA retake q1 v1='", v1, "' v2='", q.q, "' different=", v1 != q.q); await shot("v31_d2_quiz_retake_q1.png")
				if wrong and ph.quiz_i < 2 and not seen.has("q%d" % ph.quiz_i): seen["q%d" % ph.quiz_i] = true; await shot("v31_d2_quiz_q%d.png" % (ph.quiz_i + 1))
				var a: int = int(q.a)
				var qi: int = ph.quiz_i
				if wrong: row.get_child((a + 1) % row.get_child_count()).pressed.emit(); await create_timer(0.3).timeout
				row = ph.find_child("Options", true, false)   # the page may have been rebuilt meanwhile
				if row and is_instance_valid(row) and ph.page == "quiz" and ph.quiz_i == qi: row.get_child(a).pressed.emit()
		elif ph.page == "score" and ph.find_child("ScoreContinue", true, false):
			await create_timer(1.0).timeout
			if wrong:
				seen["score_suggest"] = ph.find_children("*", "Label", true, false).any(func(l): return l.text.begins_with("You should study"))
				await shot("v31_d2_score_study_tip.png"); wrong = false
				if not seen.has("study_used"):
					seen["study_used"] = true
					for b in ph.find_children("*", "Button", true, false): if b.text.begins_with("Study"): b.pressed.emit(); break
					continue
			if seen.has("study_used") and not seen.has("retake"):
				seen["retake"] = true
				for b in ph.find_children("*", "Button", true, false): if b.text.begins_with("Retake"): b.pressed.emit(); break
				continue
			await shot("v31_d2_score_pass.png"); seen["continue_btn"] = true; ph.find_child("ScoreContinue", true, false).pressed.emit()
		if seen.has("continue_btn") and not seen.has("bye") and cap.contains("Goodbye"): seen["bye"] = true; await shot("v31_d2_goodbye.png")
	print("QA notebook spoken count check: see log 'notebook'")
	var app = root.get_node("App")
	print("QA seen=", seen, " story=", app.load_save().get("story", {}))
	var ok: bool = seen.has("hello") and seen.has("zoom_legs") and seen.has("zoom_head") and seen.get("score_suggest", false) and seen.has("tr_on") and seen.has("v2") and seen.has("left_scene")
	print("QA ", "PASS" if ok else "FAIL"); Engine.time_scale = 1.0; quit(0 if ok else 1)

