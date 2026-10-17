## v33 test-UI QA: renders every test / lesson screen type on the real phone.gd (and the word-order puzzles) and saves
## screenshots to qa/<tag>/<W>x<H>/ (tag from --tag=before|after). Run: godot --path . res://tools/qa_testui/qa_testui.tscn -- --tag=after
extends Node
var fm; var ph; var out := ""; var root: Control
var log_lines: Array = []

func w(s: float) -> void: await get_tree().create_timer(s, false).timeout
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image(); img.save_png(out + n + ".png")
	var info := "SHOT %s" % n
	var sc = ph.find_child("LessonScroll", true, false) if ph else null
	if sc: info += " scroll_max=%d" % int((sc as ScrollContainer).get_v_scroll_bar().max_value - (sc as ScrollContainer).size.y)
	for c in get_tree().get_nodes_in_group("caption_box"):
		if c is CanvasItem and (c as CanvasItem).is_visible_in_tree(): info += " CAPTION_VISIBLE"
	print(info); log_lines.append(info)

func _ready() -> void:
	var tag := "run"; var base := ProjectSettings.globalize_path("res://qa/")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="): tag = a.substr(6)
		if a.begins_with("--out="): base = a.substr(6)
	var sz := DisplayServer.window_get_size()
	out = base.path_join("%s/%dx%d/" % [tag, sz.x, sz.y]); DirAccess.make_dir_recursive_absolute(out)
	App.save_tr(true)
	var bgl := CanvasLayer.new(); bgl.layer = -1; add_child(bgl)
	var bg := ColorRect.new(); bg.color = Color(0.35, 0.42, 0.38); bg.set_anchors_preset(Control.PRESET_FULL_RECT); bgl.add_child(bg)
	var cl := CanvasLayer.new(); cl.layer = 10; add_child(cl)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; cl.add_child(root)
	fm = load("res://tools/qa_testui/fake_main.gd").new(); add_child(fm)
	fm.ui = StoryUI.new(); add_child(fm.ui)
	ph = load("res://scripts/phone.gd").new(); ph.main = fm; ph.visible = false; root.add_child(ph)
	await w(1.0)
	var D: Dictionary = App.load_json("res://data/cafe_shop.json")
	ph.visible = true; ph.open(Rect2(), "home"); await w(0.8)
	# --- lessons
	ph.start_set(D.shop, "lesson"); await w(0.5); await shot("01_shop_lesson1_with_caption")
	await w(4.0); await shot("01b_shop_lesson1")
	ph.lesson_i = 2; ph._lesson(); await w(0.6); await shot("02_shop_lesson3")
	App.save_tr(false); await w(0.3); await shot("02b_shop_lesson3_tr_off"); App.save_tr(true)
	fm.caption("Now a short lesson and test on your phone.", false); await w(0.4); await shot("02c_shop_lesson3_caption_not_on_screen")
	fm.caption("Excuse me, where's the rice?", false); await w(0.4); await shot("02d_shop_lesson3_caption_on_screen")
	await w(3.0)
	ph.start_set(D.cafe, "lesson"); ph.lesson_i = 2; ph._lesson(); await w(0.6); await shot("03_cafe_lesson3")
	var body: Dictionary = App.load_json("res://data/body_day2.json")
	ph.start_set(body, "lesson"); await w(0.6); await shot("04_body_lesson1_9rows")
	ph.les = {}; ph.lesson_i = 1; ph.page = "lesson"; ph._lesson(); await w(0.6); await shot("05_family_lesson2_glosses")
	ph.lesson_i = 2; ph._lesson(); await w(0.6); await shot("06_family_lesson3_am_is_are")
	var bk: Dictionary = App.load_json("res://data/breakfast.json")
	ph.start_set(bk, "lesson"); ph.lesson_i = 2; ph._lesson(); await w(0.6); await shot("07_breakfast_lesson3")
	# --- phone quiz + score
	ph.start_set(D.shop, "quiz"); await w(0.6); await shot("08_shop_quiz")
	ph.quiz_score = 1; ph._suggested = false; ph._score_page(); await w(0.6); await shot("09_shop_score_page")
	ph._unlocking = true; ph.page = "home"; ph.show_page("home", false); await w(0.4)
	# --- bedtime test (d2 / d3 night test share the code) + day-2 test
	for spec in [["res://scripts/story/d3_night_test.gd", "10_bedtime_d3_test"], ["res://scripts/story/day2_test.gd", "12_day2_test"]]:
		var t = load(spec[0]).new(); t.run(fm, ph); await w(0.9); await shot(spec[1] + "_q1")
		fm.caption("Choose the right words.", false); await w(0.3); await shot(spec[1] + "_q1_caption_on_screen")
		t._score_page(); await w(0.6); await shot(spec[1] + "_score")
		t.finished.emit([0, 0]); await w(0.6)
	# --- vocab test (3D prop view)
	var vt = load("res://scripts/story/vocab_test.gd").new(); vt.run(fm, ph); await w(1.5); await shot("14_vocab_test_q1")
	vt._score_page(); await w(0.6); await shot("15_vocab_test_score")
	vt.finished.emit(0, 0); await w(0.6)
	ph.visible = false; fm.ui.hide_caption()
	# --- word-order puzzles
	var d2e = load("res://scripts/story/day2_evening.gd").new(); d2e.lr = fm; add_child(d2e)
	d2e._puzzle("I had breakfast with my family.", "Ailemle kahvaltı yaptım."); await w(0.6)
	await shot("16_d2_puzzle_start"); await _tap(["I", "had", "breakfast"]); await w(0.3); await shot("16b_d2_puzzle_building")
	await _tap(["with", "my", "family"]); await w(0.2); await shot("16c_d2_puzzle_done"); await w(1.0)
	var d3e = load("res://scripts/story/day3_evening.gd").new(); d3e.lr = fm; add_child(d3e)
	d3e._puzzle("I bought six apples and a bottle of milk.", "Altı elma ve bir şişe süt aldım."); await w(0.6)
	await shot("17_d3_puzzle_start"); await _tap(["I", "bought", "six"]); await w(0.3); await shot("17b_d3_puzzle_building")
	await _tap(["apples", "and", "a", "bottle", "of", "milk"]); await w(0.2); await shot("17c_d3_puzzle_done"); await w(1.0)
	var sh = load("res://scripts/story/story_home.gd").new(); sh.ui = fm.ui; sh.cl = CanvasLayer.new(); sh.cl.layer = 30; add_child(sh); sh.add_child(sh.cl)
	sh._puzzle("I went to the hospital."); await w(0.6); await shot("18_call_puzzle_start")
	await _tap(["I", "went"]); await w(0.3); await shot("18b_call_puzzle_building")
	await _tap(["to", "the", "hospital"]); await w(0.3); await shot("18c_call_puzzle_done"); await w(2.0)
	FileAccess.open(out + "log.txt", FileAccess.WRITE).store_string("\n".join(log_lines))
	print("QA_TESTUI DONE"); get_tree().quit()

## press the puzzle's word buttons in this order (first enabled button with that text)
func _tap(words: Array) -> void:
	for wd in words:
		for b in get_tree().root.find_children("*", "Button", true, false):
			if b.is_visible_in_tree() and not b.disabled and b.text == wd and b.get_parent() is HFlowContainer:
				b.pressed.emit(); break
		await w(0.15)
