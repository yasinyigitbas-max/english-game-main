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
	if p.contains("/places/cafe"): return "cafe"   # v32 (red): blue's interiors are not "outside"
	if p.contains("/places/shop"): return "shop"
	if p.ends_with("world_exterior.tscn"): return "outside"
	return "other"   # v32 (red): hospital / work / QA scenes get no day-3 town cues or pans (was "outside")

var _t := 0.0
var _busy := false
var _from := ""   # v32 (red): "cafe" / "shop" when this scene was entered from that interior
func _process(d: float) -> void:
	_t += d
	if _t < 0.4 or _busy: return
	_t = 0.0
	var st := stage()
	if st in ["", "done"]: queue_free(); return
	var sc := RoutineScope.current(get_tree())
	if sc != _sc:
		_sc = sc; _cur = {}
		# build 3.2 (black #22): a "go to X" step is done the moment we are in X (no stale "Go to the living room." in the living room)
		var reached: Array = {"living": ["Go to the living room.", "Go back home."], "bathroom": ["Go to the bathroom.", "Go back home."], "bedroom": ["Go to bed.", "Go back home."], "shop": ["Go to the shop."], "cafe": ["Go to the café.", "Go to the cafe."]}.get(_kind(sc), [])
		if not reached.is_empty(): Objectives.set_list(Objectives.items.filter(func(it): return not (it is Dictionary and String(it.get("en", "")) in reached)))
		if sc and sc.has_signal("action_done") and _kind(sc) == "bathroom": sc.action_done.connect(_on_bath_action.bind(sc))
		# v32 (red): read the exit marker now (before anything else rewrites it): back on the street from blue's cafe / shop
		_from = String(App.came_from) if String(App.came_from) in ["cafe", "shop"] else ""
		if _from == "" and String(Game.spawn) in ["lot:cafe", "cafe_door"]: _from = "cafe"
		if _from == "" and String(Game.spawn) in ["lot:corner_shop", "shop_door"]: _from = "shop"
		if _kind(sc) in ["cafe", "shop"] and st in ["town", "home"]: _mark_place(_kind(sc))   # entering counts as visited (now, not after blue's cinematics)
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
	var said := "said|" + id + "|" + str(maxi(WorldState.day, App.day))   # build 3.2 (d4/034): an objective is voiced ONCE (not again on the street)
	if _guided.has(said): await Life.guide_to(target, en, {"id": id, "tr": tr, "list": [_cur], "speak": false}); return
	_guided[said] = true
	if not speak and is_instance_valid(sc) and sc.has_method("caption"): _cap_out(sc, en)   # outdoors: say it first, then the 2.6 s pan
	await Life.guide_to(target, en, {"id": id, "tr": tr, "list": [_cur], "speak": speak})

## v33 (red QA): universal scenes (town, cafe, shop) speak through Voice.say, which is SILENT for a line without a clip;
## such a line gets the caption without voice + Audio.say (the narrator clip or the live Piper fallback)
static func _cap_out(sc: Node, line: String) -> void:
	if sc.has_method("voice_idle") and not Voice.has_clip(line) and Audio.narrator_alt(line) == null:
		sc.caption(line, false); Audio.say(line)
	else: sc.caption(line)

func _enter(sc: Node) -> void:
	if not is_instance_valid(sc): _busy = false; return
	var k := _kind(sc)
	if k in ["cafe", "shop", "other"]: _busy = false; return   # v32 (red): blue's interiors / other scenes: nothing to cue (no 30 s wait)
	await _wait_free(sc)
	if not RoutineScope.alive(sc): _busy = false; return
	var st := stage()
	match [st, k]:
		["shower", "bedroom"]:
			var f: Vector3 = sc.OBJ.door.focus
			await _guide(sc, {"pos": f + Vector3(-2.4, 1.0, 0.4), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["shower", "bathroom"]:
			var f: Vector3 = sc.OBJ.bath.focus
			await _guide(sc, {"pos": f + Vector3(-2.2, 1.3, 1.6), "at": f}, "Take a shower.", "Take a shower.", "Duş al.")
		["shower", "living"], ["shower", "outside"]:
			# v32 (red): walked past the bathroom without showering: the objective stays "Take a shower." (no living-room step yet)
			await _guide(sc, null, "Take a shower.", "Take a shower.", "Duş al.")
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
			# v32 (red): objective + sound via Life.guide_to (no target = no Life pan), then our own two-stop pan:
			# the cafe, then the shop, then back to the player. The old single pan aimed 6 m "ahead" of the player, which at the
			# home spawn is our own house, and Life's straight lerp went through its walls.
			var first := not _guided.has("Explore the town.|" + str(sc.get_instance_id()))
			await _guide(sc, null, "Explore the town.", "Explore the town.", "Kasabayı keşfet.", false)
			if first and RoutineScope.alive(sc):
				await _pan(sc, [_lot_view(sc, "cafe", "Here is the café."), _lot_view(sc, "corner_shop", "Here is the shop.")])
			set_stage("town")   # v32 (red): was "done"; the town cues below run until the player is back home
		# ---- v32 (red): town cues
		["town", "outside"], ["home", "outside"]:
			if _from != "": _mark_place(_from)
			await _town_cue(sc, _from)
		["town", "bedroom"], ["town", "bathroom"], ["town", "living"]:
			var nx := _town_next()   # back in the house before both places: show the next step, no pan
			if nx[2] == "home": set_stage("done"); Objectives.complete("Go back home.")
			else: await _guide(sc, null, nx[0], nx[0], nx[1])
		["home", "bedroom"], ["home", "bathroom"], ["home", "living"]:
			set_stage("done"); Objectives.complete("Go back home.")   # home again: day-3 morning is over
	_busy = false

# ------------------------------------------------------------------ v32 (red): day-3 town camera pans (no wall clipping)
## Path rule: every move is either VERTICAL (rise / drop at one x,z), a CRUISE above every roof (houses <= ~4.9 m incl.
## roof, shops 3.4 m, street trees ~4 m, lamps lower than CRUISE_Y), or ALONG THE ROAD in front of the lots (the stop sits
## over the 8 m road between the two sidewalks). Never a straight line from the player's camera to a lot.
## Used by "Explore the town." (cafe -> shop) and the v32 town cues ("Go to the shop." / "Go to the café." / "Go back home.").
const CRUISE_Y := 14.0
const VIEW_Y := 6.5
const BLOCK_HALF := 20.0   # 40 m city blocks (data/world/city.json); the road centre line is the block edge
## fallback entrances (Lot.entrance_global()) + facing when the block is not streamed in: block_home cell (0,0), block_shops (0,1)
const LOT_FB := {"home": [Vector3(-3.0, 0.07, 3.5), Vector3(0, 0, 1)], "cafe": [Vector3(8.5, 0.07, 27.6), Vector3(0, 0, -1)],
	"corner_shop": [Vector3(-3.0, 0.07, 27.6), Vector3(0, 0, -1)]}
var _look := Vector3.ZERO

## lot stop: camera over the road in front of the lot (1 m on the lot's side of the road centre), looking at its front door
func _lot_view(sc: Node, id: String, line := "") -> Dictionary:
	var fb: Array = LOT_FB.get(id, [Vector3.ZERO, Vector3(0, 0, 1)])
	var e: Vector3 = fb[0]
	var fw: Vector3 = fb[1]
	var g = sc.get("grid")
	if g and g.has_method("find_lot"):
		var lot = g.find_lot(id)
		if lot is Node3D:
			e = lot.entrance_global() if lot.has_method("entrance_global") else (lot as Node3D).global_position
			fw = (lot as Node3D).global_transform.basis.z; fw.y = 0.0
			fw = fw.normalized() if fw.length() > 0.01 else fb[1]
	var cc := Vector3(roundf(e.x / (BLOCK_HALF * 2.0)) * BLOCK_HALF * 2.0, 0, roundf(e.z / (BLOCK_HALF * 2.0)) * BLOCK_HALF * 2.0)
	if g and g.has_method("cell_center") and g.has_method("cell_of"): cc = g.cell_center(g.cell_of(e))
	var out := clampf(BLOCK_HALF - (e - cc).dot(fw) - 1.0, 4.0, 18.0)   # entrance -> road (cafe 6.6 m, home 15.5 m)
	var p := e + fw * out
	return {"pos": Vector3(p.x, VIEW_Y + maxf(0.0, out - 6.5) * 0.3, p.z), "at": e - fw * 1.5 + Vector3(0, 1.6, 0), "fw": fw, "line": line}

func _aim(cam: Camera3D) -> void:
	var d := _look - cam.global_position
	if d.length() < 0.01: return
	cam.look_at(_look, Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.98 else Vector3.FORWARD)

## per-frame move (no Tween: a scene change mid-pan must not leave this coroutine waiting forever with _busy set)
func _fly(sc: Node, cam: Camera3D, to_pos: Vector3, to_at: Vector3, t: float) -> bool:
	var p0 := cam.global_position; var a0 := _look; var el := 0.0
	while el < t:
		await get_tree().process_frame
		if not is_instance_valid(cam) or not RoutineScope.alive(sc): return false
		el += get_process_delta_time()
		var k := smoothstep(0.0, 1.0, minf(el / t, 1.0))
		cam.global_position = p0.lerp(to_pos, k); _look = a0.lerp(to_at, k); _aim(cam)
	return true

## hold at a stop; line != "" goes through the scene's one caption queue (the single bottom caption box)
func _hold(sc: Node, line: String) -> bool:
	if line != "" and is_instance_valid(sc) and sc.has_method("caption"): _cap_out(sc, line)
	await get_tree().create_timer(2.4, false).timeout
	await Audio.wait_idle(6.0)
	return RoutineScope.alive(sc)

## stops: Array of _lot_view() dictionaries, visited in order, then back to the player's follow camera
func _pan(sc: Node, stops: Array) -> void:
	if stops.is_empty(): return
	var rig = sc.get("cam")
	if not (rig is Camera3D): rig = get_viewport().get_camera_3d()
	if not (rig is Camera3D): return
	var restore := "mode" in sc and String(sc.mode) == "play"
	if restore: sc.mode = "busy"   # universal_scene: freezes the player while the camera is away
	var tmp := Camera3D.new(); tmp.fov = (rig as Camera3D).fov; tmp.far = maxf((rig as Camera3D).far, 120.0); sc.add_child(tmp)
	tmp.global_transform = (rig as Camera3D).global_transform; tmp.current = true
	_look = tmp.global_position - tmp.global_transform.basis.z * 10.0
	var ok := true
	var p0 := tmp.global_position
	var first: Dictionary = stops[0]
	# 1) straight up (the follow camera sits ~10 m above the player, above every roof) -> 2) cruise -> 3) drop onto the road
	if ok: ok = await _fly(sc, tmp, Vector3(p0.x, maxf(p0.y, CRUISE_Y), p0.z), first.at, 1.0)
	if ok: ok = await _fly(sc, tmp, Vector3(first.pos.x, CRUISE_Y, first.pos.z), first.at, 1.4)
	if ok: ok = await _fly(sc, tmp, first.pos, first.at, 0.8)
	if ok: ok = await _hold(sc, String(first.get("line", "")))
	var last: Dictionary = first
	for i in range(1, stops.size()):
		if not ok: break
		var s: Dictionary = stops[i]
		# along the same road when both stops face it, else up / cruise / down
		var same_road: bool = (last.fw as Vector3).dot(s.fw) > 0.95 and absf((s.pos - last.pos).dot(last.fw)) < 1.0
		if same_road: ok = await _fly(sc, tmp, s.pos, s.at, 1.6)
		else:
			if ok: ok = await _fly(sc, tmp, Vector3(last.pos.x, CRUISE_Y, last.pos.z), s.at, 0.8)
			if ok: ok = await _fly(sc, tmp, Vector3(s.pos.x, CRUISE_Y, s.pos.z), s.at, 1.2)
			if ok: ok = await _fly(sc, tmp, s.pos, s.at, 0.8)
		if ok: ok = await _hold(sc, String(s.get("line", "")))
		last = s
	# back: up, cruise to above the follow camera, then blend down onto the live follow-camera transform
	if ok and is_instance_valid(rig):
		var hero = sc.get("player")
		var hp: Vector3 = (hero as Node3D).global_position + Vector3(0, 1.0, 0) if hero is Node3D else (rig as Camera3D).global_position
		ok = await _fly(sc, tmp, Vector3(last.pos.x, CRUISE_Y, last.pos.z), hp, 0.8)
		var rp: Vector3 = (rig as Camera3D).global_position
		if ok: ok = await _fly(sc, tmp, Vector3(rp.x, maxf(rp.y, CRUISE_Y), rp.z), hp, 1.4)
		if ok:
			var x0 := tmp.global_transform; var el := 0.0
			while el < 0.9 and is_instance_valid(tmp) and is_instance_valid(rig):
				await get_tree().process_frame
				el += get_process_delta_time()
				tmp.global_transform = x0.interpolate_with((rig as Camera3D).global_transform, smoothstep(0.0, 1.0, minf(el / 0.9, 1.0)))
	if is_instance_valid(rig): (rig as Camera3D).current = true
	if is_instance_valid(tmp): tmp.queue_free()
	if restore and is_instance_valid(sc):
		sc.mode = "play"
		if sc.has_method("_update_hand"): sc._update_hand()

# ------------------------------------------------------------------ v32 (red): day-3 town cues (cafe / shop / home)
## Flags (save.json "story"): d3_cafe, d3_shop (bool, visited). story.d3: "town" (after "Explore the town.") -> "home"
## (both visited) -> "done" (back inside the house). Visited = entered blue's interior (scenes/places/cafe|shop.tscn) or came
## out of it (blue's PlaceBase.leave(): App.came_from = "cafe" / "shop", spawn "lot:cafe" / "lot:corner_shop").
static func flag(k: String) -> bool:
	var sv = App.load_save().get("story", {})
	return sv is Dictionary and bool(sv.get(k, false))

static func set_flag(k: String, v) -> void:
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv[k] = v; App.patch_save({"story": sv})

func _mark_place(id: String) -> void:
	if id == "cafe" and not flag("d3_cafe"): set_flag("d3_cafe", true)
	elif id == "shop" and not flag("d3_shop"): set_flag("d3_shop", true)

## [objective EN, TR, lot id] of the next town step
func _town_next() -> Array:
	var c := flag("d3_cafe"); var s := flag("d3_shop")
	if c and s: return ["Go back home.", "Eve dön.", "home"]
	if c: return ["Go to the shop.", "Dükkâna git.", "corner_shop"]
	if s: return ["Go to the café.", "Kafeye git.", "cafe"]
	return ["Explore the town.", "Kasabayı keşfet.", ""]

## outdoors in stage "town" / "home": cue the next place with the over-the-roofs pan (only right after leaving a place)
func _town_cue(sc: Node, from_place: String) -> void:
	var nx := _town_next()
	if nx[2] == "home" and stage() == "town": set_stage("home")
	var pan: bool = from_place != "" and nx[2] != "" and not _guided.has(String(nx[0]) + "|" + str(sc.get_instance_id()))
	await _guide(sc, null, nx[0], nx[0], nx[1], false)   # objective + sound + caption (one caption box); no Life pan
	if pan and RoutineScope.alive(sc): await _pan(sc, [_lot_view(sc, nx[2])])

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
	if RoutineScope.alive(sc):
		var f: Vector3 = sc.OBJ.door.focus
		await _guide(sc, {"pos": f + Vector3(0.3, 1.0, -2.4), "at": f}, "Go to the living room.", "Go to the living room.", "Oturma odasına git.")
	_busy = false
