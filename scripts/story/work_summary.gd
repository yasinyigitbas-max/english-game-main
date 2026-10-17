

extends CanvasLayer

const PAST: = {"Answer": "answered", "Ask": "asked", "Check": "checked", "Cut": "cut", "Do": "did", "Feed": "fed", 
	"Find": "found", "Finish": "finished", "Get": "got", "Give": "gave", "Go": "went", "Have": "had", "Help": "helped", 
	"Make": "made", "Open": "opened", "Pay": "paid", "Put": "put", "Read": "read", "Say": "said", "Serve": "served", 
	"Show": "showed", "Start": "started", "Take": "took", "Train": "trained", "Turn": "turned", "Warm": "warmed", 
	"Wash": "washed", "Watch": "watched", "Water": "watered", "Work": "worked", "Write": "wrote"}

static func past_of(task: String) -> String:
	var w: = task.split(" ", false)
	if w.is_empty(): return ""
	var v: String = PAST.get(w[0], w[0].to_lower() + "ed")
	var rest: = " ".join(w.slice(1)).replace("your ", "my ")
	if w[0] == "Pay" and rest == "": rest = "for my things"
	return ("I %s %s." % [v, rest]).replace(" .", ".")

static func lines_for(job: String, child: bool) -> Array:
	var WK = load("res://scripts/story/work.gd")
	var w = App.load_json("res://data/work.json")
	var cid: String = WK.category_of(job, child)
	var c: Dictionary = w.categories[cid] if w is Dictionary else {"tasks": []}
	var out: Array = ["I went to school." if cid in ["teach", "study"] else ("I went shopping." if cid == "home" else "I went to work.")]
	for t in c.get("tasks", []): out.append(past_of(String(t[0])))
	out.append("I came home." if cid != "home" else "I drove home.")
	return out

var bg: ColorRect
var lbl: Label

static func play(tree: SceneTree) -> void :
	var s = load("res://scripts/story/work_summary.gd").new();tree.root.add_child(s);s.run()

func run() -> void :
	layer = 120;process_mode = Node.PROCESS_MODE_ALWAYS
	bg = ColorRect.new();bg.color = Color(0, 0, 0, 0);bg.set_anchors_preset(Control.PRESET_FULL_RECT);add_child(bg)
	lbl = Label.new();lbl.set_anchors_preset(Control.PRESET_FULL_RECT);lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;lbl.add_theme_font_override("font", UI.font_b);lbl.add_theme_font_size_override("font_size", 46)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1));lbl.modulate.a = 0.0;add_child(lbl)
	var tw: = create_tween();tw.tween_property(bg, "color:a", 1.0, 0.6); await tw.finished
	var st: = CharacterHook.state()
	Life.event("work")
	for t in lines_for(String(st.get("job", "")), CharacterHook.is_child(st)):
		lbl.text = t
		var a: = create_tween();a.tween_property(lbl, "modulate:a", 1.0, 0.35); await a.finished
		await get_tree().create_timer(1.9).timeout
		var b: = create_tween();b.tween_property(lbl, "modulate:a", 0.0, 0.35); await b.finished
	var sv = App.load_save().get("story", {});sv = sv.duplicate() if sv is Dictionary else {}
	sv["day2_work_done"] = true;App.patch_save({"story": sv})
	Life.event("work_end")
	# v32-polish: day 2, work first -> straight on to the hospital (no trip home); work second -> home as before
	if not bool(sv.get("day2_hospital_done", false)) and maxi(WorldState.day, App.day) == 2:
		var ui := StoryUI.new(); add_child(ui); ui.layer = 121   # the one standard caption box, above the black summary screen
		await ui.line("Now I'm going to the hospital.")
		HospitalScene.start_day2_visit(get_tree())
	else:
		App.came_from = "outside";Game.go_to(Game.HOUSE_FRONT_DOOR_SCENE, "front_door")
	await get_tree().create_timer(0.9).timeout
	var o: = create_tween();o.tween_property(bg, "color:a", 0.0, 0.6); await o.finished
	queue_free()
