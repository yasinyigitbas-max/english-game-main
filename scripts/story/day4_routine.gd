## v33 (red): DAY 4 ROUTINE driver (day7_routine.gd extends it). Lives on the tree ROOT like Day3Morning (it extends
## day3_morning.gd for its room detection, Life.guide_to wrapper and the no-clip town camera pans; its own stage logic).
## Saved stage story.d4 (story.d7): "start"/"" -> "shower" -> "breakfast" -> "outing" -> "home" -> "evening" -> "bed" -> "done"
##   shower    bedroom: pan to the bathroom door / bathroom: pan to the shower, "Take a shower." -> "I feel fresh and clean."
##   breakfast "Go to the living room." -> day4_breakfast.gd (family breakfast + review of yesterday's English)
##   outing    "Go to the shop." (front door pan; outside: the shop pan) -> day4_shop.gd in blue's shop (flag story.d4_shop)
##   home      "Go back home." (home pan) -> living room: evening (day4_evening.gd: couch talk + POWER CUT + polaroid)
##   bed       "Go to bed." -> bedroom: bedtime.gd hook -> day4_bedtime.gd (dream polaroids, TestBank test, sleep -> day 5)
## ENTRY: load("res://scripts/story/day4_routine.gd").start(get_tree())   (static, idempotent, day 4 and day 7)
extends "res://scripts/story/day3_morning.gd"

var day_n := 4
var key := "d4"
var data_path := "res://data/day4.json"
var evening_script := "res://scripts/story/day4_evening.gd"
var out_goal := ["Go to the shop.", "Dükkâna git."]

static func st_of(k: String) -> String:
	var sv = App.load_save().get("story", {})
	return String(sv.get(k, "")) if sv is Dictionary else ""

static func st_set(k: String, v: String) -> void:
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv[k] = v; App.patch_save({"story": sv})

static func start(tree: SceneTree) -> void:
	var d := maxi(WorldState.day, App.day)
	if not d in [4, 7]: return
	var k := "d%d" % d
	var st := st_of(k)
	if st == "done": return
	if st in ["", "start"]: st_set(k, "shower")   # day 4: bedtime.gd wake; day 7: whatever blue's day 6 left
	var nm := "Day%dRoutine" % d
	if tree.root.has_node(nm): return
	var n = load("res://scripts/story/day%d_routine.gd" % d).new(); n.name = nm; tree.root.add_child(n)

## bedroom objective for main.gd objective() (so the room's own _advance shows the same step)
static func main_objective() -> String:
	var d := maxi(WorldState.day, App.day)
	if d == 8: return "Start your day." if st_of("d8") == "start" else ""
	if not d in [4, 7]: return ""
	var st := st_of("d%d" % d)
	if st in ["", "start", "shower"]: return "Take a shower."
	if st == "outing": return "Go to the shop."
	if st == "bed" or (st == "evening" and _flag_on("d%d_bed_pending" % d)): return "Go to bed."
	if st in ["breakfast", "home", "evening"]: return "Go to the living room."
	return ""

static func _flag_on(k: String) -> bool:
	var sv = App.load_save().get("story", {})
	return sv is Dictionary and bool(sv.get(k, false))

func stage_now() -> String:
	var st := st_of(key)
	if st == "evening" and _flag_on(key + "_bed_pending"): st = "bed"
	return st

func _process(d: float) -> void:
	_t += d
	if _t < 0.4 or _busy: return
	_t = 0.0
	var st := stage_now()
	if st in ["", "done"] or maxi(WorldState.day, App.day) != day_n: queue_free(); return
	var sc := get_tree().current_scene
	if sc != _sc:
		_sc = sc; _cur = {}
		if sc and sc.has_signal("action_done") and _kind(sc) == "bathroom": sc.action_done.connect(_bath.bind(sc))
		_from = String(App.came_from) if String(App.came_from) in ["cafe", "shop"] else ""
		if _from == "" and String(Game.spawn) in ["lot:corner_shop", "shop_door"]: _from = "shop"
		_busy = true; _enter.call_deferred(sc); return
	if not _cur.is_empty() and not Objectives.has(String(_cur.id)): Objectives.set_list([_cur])

func _bath(_id, sc: Node) -> void:
	if st_of(key) != "shower" or not is_instance_valid(sc): return
	var ld = sc.get("last_dur")
	if not (ld is Dictionary and ld.has("takeshower")): return
	st_set(key, "breakfast")
	_busy = true
	await Audio.wait_idle(10.0)
	if is_instance_valid(sc) and sc.has_method("caption"): sc.caption("I feel fresh and clean.")
	await Audio.wait_idle(10.0)
	await get_tree().create_timer(0.6, false).timeout
	if is_instance_valid(sc) and sc == get_tree().current_scene:
		var f: Vector3 = sc.OBJ.door.focus
		await _guide(sc, {"pos": f + Vector3(0.3, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
	_busy = false

func _door_shot(sc: Node, k: String) -> Dictionary:
	var f: Vector3 = sc.OBJ.door_s.focus if k == "bedroom" else sc.OBJ.door.focus
	return {"pos": f + Vector3(0.4, 1.0, -2.4), "at": f} if k == "bedroom" else {"pos": f + Vector3(0.3, 1.0, -2.4), "at": f}

func _front_shot(sc: Node) -> Dictionary:
	var dx: float = (sc.DOOR_FRONT.x + sc.DOOR_FRONT.y) / 2
	return {"pos": Vector3(dx - 1.6, 2.0, 0.2), "at": Vector3(dx, 1.1, 3.0)}

func _enter(sc: Node) -> void:
	if not is_instance_valid(sc): _busy = false; return
	var k := _kind(sc)
	if k == "shop": await _shop(sc); _busy = false; return
	if k in ["cafe", "other", ""]: _busy = false; return
	await _wait_free(sc)
	if not is_instance_valid(sc) or sc != get_tree().current_scene: _busy = false; return
	var st := stage_now()
	match [st, k]:
		["shower", "bedroom"]:
			var f: Vector3 = sc.OBJ.door.focus
			await _guide(sc, {"pos": f + Vector3(-2.4, 1.0, 0.4), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["shower", "bathroom"]:
			var f: Vector3 = sc.OBJ.bath.focus
			await _guide(sc, {"pos": f + Vector3(-2.2, 1.3, 1.6), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["shower", "living"], ["shower", "outside"]:
			await _guide(sc, null, "Take a shower.", "Take a shower.", "Duş al.")
		["breakfast", "bedroom"], ["breakfast", "bathroom"], ["home", "bedroom"], ["home", "bathroom"], ["evening", "bedroom"], ["evening", "bathroom"]:
			await _guide(sc, _door_shot(sc, k), "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
		["breakfast", "outside"], ["home", "outside"], ["evening", "outside"], ["bed", "outside"]:
			await _home_cue(sc)
		["breakfast", "living"]:
			await _breakfast(sc)
			if is_instance_valid(sc) and sc == get_tree().current_scene:
				st_set(key, "outing")
				await _guide(sc, _front_shot(sc), out_goal[0], out_goal[0], out_goal[1])
		["outing", "bedroom"], ["outing", "bathroom"]:
			await _guide(sc, _door_shot(sc, k), out_goal[0], out_goal[0], out_goal[1])
		["outing", "living"]:
			await _guide(sc, _front_shot(sc), out_goal[0], out_goal[0], out_goal[1])
		["outing", "outside"]:
			if _flag_on(key + "_shop"): await _home_cue(sc)
			else:
				var first := not _guided.has(out_goal[0] + "|" + str(sc.get_instance_id()))
				await _guide(sc, null, out_goal[0], out_goal[0], out_goal[1], false)
				if first and is_instance_valid(sc) and sc == get_tree().current_scene: await _pan(sc, [_lot_view(sc, "corner_shop", "Here is the shop.")])
		["home", "living"], ["evening", "living"]:
			st_set(key, "evening")
			await _evening(sc)
		["bed", "living"]:
			var e = load(evening_script).new(); e.lr = sc; e.data_path = data_path; sc.add_child(e)
			await e.bed_prompt()
			_cur = {"id": "Go to bed.", "en": "Go to bed.", "tr": "Yatmaya git."}
		["bed", "bathroom"]:
			await _guide(sc, _door_shot(sc, k), "Go to bed.", "Go to bed.", "Yatmaya git.")
	_busy = false

## outside after the shop (or any time the next step is at home): "Go back home." + one pan to our house
func _home_cue(sc: Node) -> void:
	if st_of(key) == "outing": st_set(key, "home")
	var first := not _guided.has("Go back home.|" + str(sc.get_instance_id()))
	await _guide(sc, null, "Go back home.", "Go back home.", "Eve dön.", false)
	if first and is_instance_valid(sc) and sc == get_tree().current_scene: await _pan(sc, [_lot_view(sc, "home", "Here is my home.")])

func _breakfast(sc: Node) -> void:
	var b = load("res://scripts/story/day4_breakfast.gd").new(); b.lr = sc; b.data_path = data_path; sc.add_child(b)
	await b.run()

func _shop(sc: Node) -> void:
	if st_of(key) != "outing" or _flag_on(key + "_shop"): return
	var s = load("res://scripts/story/day4_shop.gd").new(); s.sc = sc; s.data_path = data_path; sc.add_child(s)
	await s.run()

func _evening(sc: Node) -> void:
	var e = load(evening_script).new(); e.lr = sc; e.data_path = data_path; sc.add_child(e)
	await e.run()
	_cur = {"id": "Go to bed.", "en": "Go to bed.", "tr": "Yatmaya git."}
