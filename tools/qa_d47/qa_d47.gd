extends Node
## v33 (red) QA: plays red's day 4 (-> day 5) or day 7 (-> day 8) start to end, playing the player's part, and checks
## Yasin's standard at every story step: top-left objective, camera pan, spoken line (clip / Piper), ONE bottom caption
## box with TR inside (+ TR text, TR is on). Also: NPC pose while talking, test bank 10 unique, dark-room brightness.
## godot --path . res://tools/qa_d47/qa_d47.tscn -- --save-path=/tmp/qa_d47/save_d4.json --day=4   (tools/qa_d47/run.sh)
var day := 4
var log: Array = []
var shots := "/tmp/qa_d47/shots/"
var gt := 0.0
var steps: Array = []        # {t, obj, scene, pan, said, said_t, cap_ok, cap_info, obj_ok}
var speech: Array = []       # [t, text, voiced]
var pans: Array = []         # t
var cap_bad: Array = []
var pose_bad: Array = []
var test_qs: Array = []
var tests: Array = []
var dark_lum: Array = []     # [tag, lum]
var _last_shot := -9.0
var _last_obj := ""
var _shot_n := 0
var _last_cs = null
var _last_cam: Camera3D = null
var acted := {}
var world := true            # v34 (blue fix33): run through scenes/world.tscn (--rooms = the old change_scene harness)
var _burst_until := -1.0
var _pan_n := 0

func ok(c: bool, t: String) -> void:
	log.append(("PASS " if c else "FAIL ") + t); print("D47QA ", log[-1])

func w(t: float) -> void: await get_tree().create_timer(t, true).timeout

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--day="): day = int(a.substr(6))
		if a == "--rooms": world = false
		if a.begins_with("--shots="): shots = a.substr(8)
	if shots == "/tmp/qa_d47/shots/": shots = "/tmp/qa_d47/shots_d%d/" % day
	DirAccess.make_dir_recursive_absolute(shots)
	App.save_tr(true)
	Engine.time_scale = 3.0; AudioServer.playback_speed_scale = 3.0
	Audio.spoke.connect(_on_spoke)
	run.call_deferred()

func cur() -> Node: return get_tree().current_scene
func kind() -> String:
	var f := String(cur().scene_file_path).get_file() if cur() else ""
	return "world_exterior.tscn" if f == "world.tscn" else f

func snap(n: String) -> Image:
	if DisplayServer.get_name() == "headless": return null
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)   # the viewport alpha made unshaded / alpha-hash areas look white in PNG viewers
	_shot_n += 1
	img.save_png(shots + "%03d_%s.png" % [_shot_n, n.validate_filename().replace(" ", "_").left(48)])
	return img

func lum(img: Image) -> float:
	if img == null: return -1.0
	var s := img.duplicate() as Image; s.resize(80, 36)
	var t := 0.0
	for y in 36:
		for x in 80: t += s.get_pixel(x, y).get_luminance()
	return t / (80.0 * 36.0)

func _voiced(t: String) -> bool:
	if Audio._clip(Audio.norm(t)) != null or Voice.has_clip(t): return true
	var k := " " + Audio.norm(t)
	for key in Audio.index: if String(key).begins_with("v_") and String(key).ends_with(k): return Audio._clip(key) != null
	return false

# ------------------------------------------------------------------ monitors
func _process(d: float) -> void:
	gt += d
	var sc := cur()
	if sc == null: return
	var cs = sc.get("cam_shot")
	if cs is Dictionary and not cs.is_empty() and cs != _last_cs: pans.append(gt); _burst("shot")
	_last_cs = cs
	var cam := get_viewport().get_camera_3d()
	if cam != _last_cam and cam != null and _last_cam != null and cam != sc.get("cam"): pans.append(gt); _burst("cam")
	var sh = get_tree().root.get_node_or_null("ShoulderCam")
	if sh and sh.get("_guide_on") == true and not _was_guide: pans.append(gt); _burst("guide")
	_was_guide = sh != null and sh.get("_guide_on") == true
	_last_cam = cam
	var o := String(Objectives.items[0].en) if not Objectives.items.is_empty() else ""
	if o != "" and o != _last_obj:
		_last_obj = o
		steps.append({"t": gt, "obj": o, "scene": kind(), "day": WorldState.day})
		print("D47QA OBJ t=%.1f day%d %s | %s" % [gt, WorldState.day, o, kind()])
		_obj_shot.call_deferred(o)

var _was_guide := false
## several frames per pan (frame-by-frame check): 9 frames, 0.35 s game time apart
func _burst(why: String) -> void:
	if gt < _burst_until: return
	_burst_until = gt + 3.2
	_pan_n += 1
	var tag := "pan%02d_%s_%s" % [_pan_n, why, _last_obj.left(24)]
	for i in 9:
		await snap("%s_f%d" % [tag, i])
		await w(0.35)

func _obj_shot(o: String) -> void:
	await w(1.4)
	var vis := false
	for ov in get_tree().root.find_children("Objectives", "PanelContainer", true, false):
		if ov.is_visible_in_tree() and ov.global_position.x < 400 and ov.global_position.y < 250: vis = true
	for s in steps: if s.obj == o and not s.has("obj_ok"): s["obj_ok"] = vis
	await snap("obj_" + o)

func _on_spoke(t: String) -> void:
	var v := _voiced(t)
	speech.append([gt, t, v])
	print("D47QA SAY t=%.1f %s | %s" % [gt, "CLIP " if v else "PIPER", t])
	_cap_check.call_deferred(t)

func _boxes() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("caption_box"):
		if n is Control and n.is_visible_in_tree(): out.append(n)
	for nm in ["StoryCaption", "Caption"]:
		for n in get_tree().root.find_children(nm, "Control", true, false):
			if n.is_visible_in_tree() and not n in out and n.size.x > 4: out.append(n)
	return out

func _cap_check(t: String) -> void:
	await w(0.35)
	var sc := cur()
	var bx := _boxes()
	var vp := get_viewport().get_visible_rect().size
	var info := "n=%d" % bx.size()
	var good := bx.size() == 1
	if bx.size() >= 1:
		var b: Control = bx[0]
		var r := Rect2(b.global_position, b.size)
		var trb := false
		for c in b.find_children("*", "Button", true, false): if (c as Button).text == "TR" and c.is_visible_in_tree(): trb = true
		var labs: Array = b.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and String(l.text).strip_edges() != "")
		var bottom := r.get_center().y > vp.y * 0.55 and absf(r.get_center().x - vp.x / 2) < vp.x * 0.2
		info += " trbtn=%s labels=%d bottomcenter=%s rect=%s" % [trb, labs.size(), bottom, str(r)]
		good = good and trb and labs.size() >= 2 and bottom
	var cov: Array = []
	for n in get_tree().root.find_children("*", "Control", true, false):
		if n.is_visible_in_tree() and n.get_global_rect().has_point(Vector2(vp.x / 2, vp.y - 60)) and not b_has(bx, n):
			var cl = n.get_canvas_layer_node()
			cov.append("%s<%s>L%s" % [n.name, n.get_class(), str(cl.layer) if cl else "0"])
	var cam := get_viewport().get_camera_3d()
	print("D47QA CAPINFO %s | %s | under=%s cam=%s" % [t, info, str(cov.slice(0, 8)), str(cam.global_position.snapped(Vector3.ONE * 0.1)) if cam else "-"])
	if _in_test(): good = bx.size() == 0; info = "TEST n=%d (must be 0)" % bx.size()
	if not good: cap_bad.append("%s @%s [%s]" % [t, kind(), info]); print("D47QA CAPBAD ", cap_bad[-1])
	# NPC pose: seated family members keep a sitting animation while a line plays
	if sc and sc.has_method("humans"):
		for bm in sc.humans():
			var seat := String(bm.get("seat", ""))
			if seat == "" or not (bm.node is DemoCharacter) or not bm.node.visible: continue
			if String(bm.node.get_meta("seat", seat)) == "": continue   # standing on purpose (party reveal)
			var an := String(bm.node.player.current_animation)
			if not (an.contains("sit") or an.contains("eat")): pose_bad.append("%s seat=%s anim=%s during '%s'" % [bm.data.get("name", "?"), seat, an, t])
	if gt - _last_shot > 1.2:
		_last_shot = gt
		var img := await snap("say_" + t)
		var ev = _evening()
		if ev and (bool(ev.get("_dark")) or (ev.get("candle_light") and ev.candle_light.light_energy > 0.0)):
			var L := lum(img); dark_lum.append([t, L]); print("D47QA DARKLUM %.3f | %s" % [L, t])

func _in_test() -> bool:
	for nm in ["Question", "ScoreBar"]:
		var n := get_tree().root.find_child(nm, true, false)
		if n and n is CanvasItem and n.is_visible_in_tree(): return true
	return false

var test_layout: Array = []
func _test_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var row := get_tree().root.find_child("Options", true, false) as Control
	if row == null: return
	var p: Node = row; var scroll := false
	while p:
		if p is ScrollContainer: scroll = true
		p = p.get_parent()
	var r := row.get_global_rect()
	test_layout = [r.end.y, vp.y, scroll]
	print("D47QA TESTLAYOUT options_bottom=%.0f viewport=%.0f scroll=%s" % [r.end.y, vp.y, scroll])

func b_has(bx: Array, n: Node) -> bool:
	for b in bx: if b == n or b.is_ancestor_of(n): return true
	return false

func _evening() -> Node:
	var sc := cur()
	if sc == null: return null
	for c in sc.get_children():
		if c.get_script() and String(c.get_script().resource_path).get_file() in ["day4_evening.gd", "day7_party.gd"]: return c
	return null

# ------------------------------------------------------------------ driver
func go(path: String, from: String) -> void:
	if world: await wgo(path, from); return
	App.came_from = from
	if path == "res://main.tscn": App.continue_requested = true
	get_tree().change_scene_to_file(path)
	await w(1.0)

## open world: the same moves the player makes (house doors, front door, street walk, shop door)
func wgo(path: String, from: String) -> void:
	App.came_from = from
	var s := cur(); var k := kind()
	print("D47QA WGO %s -> %s" % [k, path])
	if House.is_room(path) and House.is_room(String(s.scene_file_path)): StoryNav.room(s, path)
	elif House.is_room(path):   # street -> house: to the front door, walk in (World.entered -> OwLink)
		await WorldTrip.go("front_door"); await w(0.6); await World.goto("livingroom", "front")
	elif path == Game.WORLD_SCENE: StoryNav.goto(Game.WORLD_SCENE, "lot:home")
	elif path.ends_with("shop.tscn"): await WorldTrip.go("shop_door"); await w(0.6); await World.goto("shop", "shop")
	await w(1.5)

const House := preload("res://scripts/core/house.gd")

func stage() -> String:
	var sv = App.load_save().get("story", {})
	return String(sv.get("d%d" % day, "")) if sv is Dictionary else ""

func run() -> void:
	await w(1.0)
	for f in ["day3_morning", "day4_routine", "day7_routine", "day4_breakfast", "day4_shop", "day4_evening", "day7_party", "day4_talk", "day4_bedtime", "day7_bedtime", "day4_polaroids", "test_bank", "bedtime"]:
		var scr = load("res://scripts/story/%s.gd" % f)
		ok(scr != null and scr.can_instantiate(), "script compiles: %s.gd" % f)
	ok(WorldState.day == day, "save at day %d (story.d%d=%s)" % [day, day, stage()])
	if world:
		App.continue_requested = true
		get_tree().change_scene_to_file("res://scenes/world.tscn"); await w(3.0)
	else: await go("res://main.tscn", "")
	var t := 0
	var end_t := -1.0
	while t < 12000:
		await w(0.25); t += 1
		await _panels()
		if gt > 150.0 and steps.is_empty(): print("D47QA ABORT no objective after 150 s"); break
		if t % 120 == 0: _diag(t)
		if WorldState.day > day:
			if end_t < 0: end_t = gt
			var nd := steps.filter(func(x): return int(x.day) > day)
			if (not nd.is_empty() and gt - float(nd[-1].t) > 6.0) or gt - end_t > 45.0: break
			continue
		var s := cur(); if s == null: continue
		if s.get("mode") != null and String(s.mode) != "play": continue
		if Audio.is_speaking(): continue
		var o := _last_obj
		var k := kind()
		var key := "%s|%s|%s|%s" % [stage(), k, o, s.get_instance_id()]
		if acted.has(key) and gt - float(acted[key]) < 40.0: continue
		var st_obj = steps.filter(func(x): return x.obj == o)
		if not st_obj.is_empty() and gt - float(st_obj[-1].t) < 2.5: continue
		var did := true
		match [k, o]:
			["main.tscn", "Take a shower."]: await go("res://bathroom.tscn", "bedroom")
			["bathroom.tscn", "Take a shower."]: _verb(s, "bath", "takeshower")
			["main.tscn", "Go to the living room."], ["main.tscn", "Go to the shop."]: await go("res://livingroom.tscn", "bedroom")
			["bathroom.tscn", "Go to the living room."]: await go("res://livingroom.tscn", "bathroom")
			["livingroom.tscn", "Go to the shop."]:
				if world: await wgo(Game.WORLD_SCENE, "livingroom")
				else: App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home"); await w(2.0)
			["world_exterior.tscn", "Go to the shop."]:
				if world: await wgo("res://scenes/places/shop.tscn", "street")
				else: WorldState.player_pos = Vector3(-3, 0, 27.6); Game.go_to("res://scenes/places/shop.tscn", "front_door"); await w(2.0)
			["shop.tscn", "Go outside."]:
				var sv = App.load_save().get("story", {})
				if bool(sv.get("d%d_shop" % day, false)): await snap("shop_exit"); s.qa_use("exit"); await w(3.0)
				else: did = false
			["world_exterior.tscn", "Go back home."]: await go(Game.HOUSE_FRONT_DOOR_SCENE, "outside")
			["livingroom.tscn", "Talk to my family."]: s.hero.position = Vector3(s.SOFA_X - 1.2, 0, 0.3)   # room-local (the room is off the origin in the world)
			["livingroom.tscn", "Go to bed."]: await go("res://main.tscn", "livingroom")
			_: did = false
		if did: acted[key] = gt; print("D47QA ACT t=%.1f %s" % [gt, key])
	await _report()

func _verb(s: Node, id: String, k: String) -> void:
	for v in s.verbs(id):
		if v[2] == k: s.do_verb(id, v); return

var _pz_i := 0
func _panels() -> void:
	var r := get_tree().root
	var pz := r.find_child("D4Puzzle", true, false)
	if pz and not Audio.is_speaking():
		var bs: Array = pz.find_children("*", "Button", true, false).filter(func(b): return not b.disabled)
		if not bs.is_empty():
			if _pz_i == 0: await snap("puzzle")
			_pz_i += 1
			for b in bs:
				b.pressed.emit()
				if b.disabled: break
		return
	_pz_i = 0
	var ch := r.find_child("D4Choose", true, false)
	if ch and not Audio.is_speaking():
		var bs: Array = ch.find_children("*", "Button", true, false).filter(func(b): return not b.disabled)
		if not bs.is_empty(): await w(0.4); if is_instance_valid(bs[0]): bs[0].pressed.emit()
		return
	var ql := r.find_child("Question", true, false) as Label
	if ql and ql.is_visible_in_tree():
		var q := String(ql.text)
		if test_qs.is_empty() or test_qs[-1] != q: test_qs.append(q); if test_qs.size() == 1: await w(1.0); _test_layout(); await snap("test_q1")
	for i in 3:
		var o := r.find_child("Opt%d" % i, true, false) as Button
		if o and o.is_visible_in_tree() and not o.disabled: o.pressed.emit(); return
	var c := r.find_child("ScoreContinue", true, false) as Button
	if c and c.is_visible_in_tree() and not c.disabled and not test_qs.is_empty():
		await snap("test_score")
		tests.append(test_qs.duplicate()); test_qs.clear()
		c.pressed.emit()

func _diag(t: int) -> void:
	var s := cur()
	print("D47QA DIAG t=%d gt=%.0f day=%d st=%s scene=%s mode=%s speaking=%s obj=%s" % [t, gt, WorldState.day, stage(), kind(), str(s.get("mode")) if s else "-", Audio.is_speaking(), _last_obj])

# ------------------------------------------------------------------ report
func _report() -> void:
	var sv = App.load_save().get("story", {})
	var bad_steps: Array = []
	for s in steps:
		var t0: float = s.t - 1.5; var t1: float = s.t + 9.0
		var pan := pans.any(func(p): return p >= t0 and p <= t1)
		var said := speech.any(func(x): return x[0] >= t0 and x[0] <= t1 and (String(x[1]) == s.obj or true))
		var said_obj := speech.any(func(x): return x[0] >= t0 and x[0] <= t1 and String(x[1]) == s.obj)
		var line := "STEP day%d %-28s %-22s obj=%s pan=%s spoken=%s(objline %s)" % [s.day, s.obj, s.scene, s.get("obj_ok", "?"), pan, said, said_obj]
		print("D47QA ", line)
		if not (pan and said and bool(s.get("obj_ok", false))): bad_steps.append(line)
	ok(bad_steps.is_empty(), "every objective step has objective + pan + spoken line (%d steps, %d bad)" % [steps.size(), bad_steps.size()])
	for b in bad_steps: print("D47QA BADSTEP ", b)
	ok(cap_bad.is_empty(), "exactly one bottom-centre caption box with TR button + TR text at every spoken line (%d lines, %d bad)" % [speech.size(), cap_bad.size()])
	ok(pose_bad.is_empty(), "seated NPCs keep their sitting pose while lines play (%d bad) %s" % [pose_bad.size(), str(pose_bad.slice(0, 6))])
	ok(String(sv.get("d%d" % day, "")) == "done", "day %d stage done (%s)" % [day, sv.get("d%d" % day)])
	ok(WorldState.day == day + 1, "day advanced to %d" % WorldState.day)
	ok(bool(sv.get("d%d_shop" % day, false)), "shop checkout played (flag d%d_shop)" % day)
	ok(sv.has("d%d_night_score" % day), "bedtime test finished %s" % str(sv.get("d%d_night_score" % day)))
	for q in tests:
		var u := {}
		for x in q: u[x] = true
		ok(q.size() == 10 and u.size() == 10, "test bank: %d questions, %d unique" % [q.size(), u.size()])
	if tests.is_empty(): ok(false, "test bank: no finished test seen")
	ok(test_layout.size() == 3 and not test_layout[2] and float(test_layout[0]) > float(test_layout[1]) * 0.7, "test screen: no scroll, answer buttons low (bottom %s of %s)" % [str(test_layout.slice(0, 1)), str(test_layout.slice(1, 2))])
	if day == 4:
		ok(dark_lum.size() > 0 and dark_lum.all(func(x): return x[1] > 0.03), "power cut visible but not pitch black: lum %s" % str(dark_lum.map(func(x): return snappedf(x[1], 0.001))))
	else:
		ok(bool(sv.get("d7_surprise_done", false)), "surprise party played")
		ok(steps.any(func(s): return s.obj == "Start your day." and s.day == 8), "day 8 'Start your day.' objective")
	for p in (["d4_breakfast", "d4_shop", "d4_candles"] if day == 4 else ["d7_breakfast", "d7_shop", "d7_party"]):
		ok(Life.photo(p) != null, "polaroid " + p)
	var miss: Array = []
	for x in speech: if not x[2] and not miss.has(x[1]): miss.append(x[1])
	print("D47QA PIPER_FALLBACK %d lines: %s" % [miss.size(), JSON.stringify(miss)])
	print("D47QA CAPBAD_LIST ", JSON.stringify(cap_bad.slice(0, 30)))
	print("D47QA TOTAL %d PASS %d FAIL" % [log.filter(func(l): return l.begins_with("PASS")).size(), log.filter(func(l): return l.begins_with("FAIL")).size()])
	get_tree().quit()
