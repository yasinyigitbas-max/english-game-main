## v31c (red): DAY 3 MORNING. After the day-3 alarm (bedtime.gd) the objectives are: take a shower (bathroom) -> go to the
## living room -> go outside to roam. Every objective gets Life.guide_to (camera pan + sound + top-left objective).
## Lives on the tree ROOT (survives room changes). Saved stage: story.d3 = "shower" -> "living" -> "outside" -> "done".
## ENTRY: Day3Morning.attach(get_tree())  (static, idempotent; bedtime.gd calls it, and Bedtime.hook_bedroom on a day-3 continue)
class_name Day3Morning
extends Node

var _sc: Node = null
var _guided := {}      # stage|scene -> true (one pan per objective per room visit)
var _cur := {}         # current objective {id, en, tr}

static func stage() -> String:
	var sv = App.load_save().get("story", {})
	return String(sv.get("d3", "")) if sv is Dictionary else ""

static func set_stage(v: String) -> void:
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv["d3"] = v; App.patch_save({"story": sv})

static func attach(tree: SceneTree) -> void:
	if maxi(WorldState.day, App.day) < 3 or stage() in ["", "done"]: return
	if tree.root.has_node("Day3Morning"): return
	var n = load("res://scripts/story/day3_morning.gd").new(); n.name = "Day3Morning"; tree.root.add_child(n)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _kind(sc: Node) -> String:
	if sc == null: return ""
	var p := String(sc.scene_file_path)
	if p.ends_with("main.tscn"): return "bedroom"
	if p.ends_with("bathroom.tscn"): return "bathroom"
	if p.ends_with("livingroom.tscn"): return "living"
	if p.ends_with("menu.tscn") or p == "": return ""
	return "outside"

var _t := 0.0
var _busy := false
func _process(d: float) -> void:
	_t += d
	if _t < 0.4 or _busy: return
	_t = 0.0
	var st := stage()
	if st in ["", "done"]: queue_free(); return
	var sc := get_tree().current_scene
	if sc != _sc:
		_sc = sc; _cur = {}
		if sc and sc.has_signal("action_done") and _kind(sc) == "bathroom": sc.action_done.connect(_on_bath_action.bind(sc))
		_busy = true; _enter.call_deferred(sc); return
	# keep the objective on the list (room code may rewrite Objectives after its own actions)
	if not _cur.is_empty() and not Objectives.has(String(_cur.id)): Objectives.set_list([_cur])

func _wait_free(sc: Node) -> void:
	await get_tree().create_timer(1.6, false).timeout
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(sc) and "mode" in sc and String(sc.mode) != "play" and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await Audio.wait_idle(8.0)

func _guide(sc: Node, target, id: String, en: String, tr: String, speak := true) -> void:
	_cur = {"id": id, "en": en, "tr": tr}
	var key := id + "|" + str(sc.get_instance_id())
	if _guided.has(key): Objectives.set_list([_cur]); return
	_guided[key] = true
	if not speak and is_instance_valid(sc) and sc.has_method("caption"): sc.caption(en)   # outdoors: say it first, then the 2.6 s pan
	await Life.guide_to(target, en, {"id": id, "tr": tr, "list": [_cur], "speak": speak})

func _enter(sc: Node) -> void:
	if not is_instance_valid(sc): _busy = false; return
	var k := _kind(sc)
	await _wait_free(sc)
	if not is_instance_valid(sc) or sc != get_tree().current_scene: _busy = false; return
	var st := stage()
	match [st, k]:
		["shower", "bedroom"]:
			var f: Vector3 = sc.OBJ.door.focus
			await _guide(sc, {"pos": f + Vector3(-2.4, 1.0, 0.4), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["shower", "bathroom"]:
			var f: Vector3 = sc.OBJ.bath.focus
			await _guide(sc, {"pos": f + Vector3(-2.2, 1.3, 1.6), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["living", "bathroom"]:
			var f: Vector3 = sc.OBJ.door.focus
			await _guide(sc, {"pos": f + Vector3(0.3, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
		["living", "bedroom"]:
			var f: Vector3 = sc.OBJ.door_s.focus
			await _guide(sc, {"pos": f + Vector3(0.4, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
		["living", "living"], ["outside", "living"]:
			set_stage("outside")
			var dx: float = (sc.DOOR_FRONT.x + sc.DOOR_FRONT.y) / 2
			await _guide(sc, {"pos": Vector3(dx - 1.6, 2.0, 0.2), "at": Vector3(dx, 1.1, 3.0)}, "Go outside.", "Go outside.", "Dışarı çık.")
		["outside", "bedroom"], ["outside", "bathroom"]:
			var f: Vector3 = sc.OBJ.door_s.focus if k == "bedroom" else sc.OBJ.door.focus
			await _guide(sc, {"pos": f + Vector3(0.4, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
		["outside", "outside"], ["living", "outside"]:
			var hero = sc.get("player") if sc.get("player") is Node3D else sc.get("hero")
			var at: Vector3 = (hero as Node3D).global_position + (hero as Node3D).global_transform.basis.z * -6.0 + Vector3(0, 1.2, 0) if hero is Node3D else Vector3(0, 1.2, 6)
			await _guide(sc, at, "Explore the town.", "Explore the town.", "Kasabayı keşfet.")
			set_stage("done")
	_busy = false

func _on_bath_action(_id, sc: Node) -> void:
	if stage() != "shower" or not is_instance_valid(sc): return
	var ld = sc.get("last_dur")
	if not (ld is Dictionary and ld.has("takeshower")): return
	set_stage("living")
	_busy = true
	await Audio.wait_idle(10.0)
	if is_instance_valid(sc) and sc.has_method("caption"): sc.caption("I feel fresh and clean.")
	await Audio.wait_idle(10.0)
	await get_tree().create_timer(0.6, false).timeout
	if is_instance_valid(sc) and sc == get_tree().current_scene:
		var f: Vector3 = sc.OBJ.door.focus
		await _guide(sc, {"pos": f + Vector3(0.3, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
	_busy = false
