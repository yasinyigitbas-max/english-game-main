## build 3.2 (red, Yasin 21:26): DAYS 3-7 - right after breakfast the player ALWAYS goes to work (a child: to school, a
## parent drives), the same trip as day 2: top-left objective + pan framing the hero and the car + spoken line -> at the car
## "I am getting in my car." / the child line -> black routine summary (work_summary.gd) -> home at the front door.
## ONLY AFTER that the day's own scripted events start (the day directors call DayWork.gate() first on the street).
## Save: "work_due_day" (set when the day's breakfast ends) / "work_done_day".
extends RefCounted

const NEAR := 3.4

static func _day() -> int: return maxi(WorldState.day, App.day)

## the day's breakfast is over: the work trip is now owed (days 3-7)
static func due() -> void:
	var d := _day()
	if d >= 3 and d <= 7 and int(App.load_save().get("work_done_day", 0)) != d: App.patch_save({"work_due_day": d})

## the hero is out on the street (open world: no live room / place; current_scene can lag behind there)
static func _on_street(w: Node) -> bool:
	if OwLink.active(): return OwLink.inst.live == null or not is_instance_valid(OwLink.inst.live)
	return w.get_tree().current_scene == w

static func pending() -> bool:
	var sv := App.load_save(); var d := _day()
	# QA jump harnesses (blue / black) that start past breakfast: the work step never blocks them
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--qa") and String(a) != "--qa-ow=work4": return false
	return d >= 3 and d <= 7 and int(sv.get("work_due_day", 0)) == d and int(sv.get("work_done_day", 0)) != d

static func goal() -> Array:
	var st := CharacterHook.state()
	var job := String(st.get("job", ""))
	if job == "":
		var raw = App.load_save().get("state", {})
		if raw is Dictionary: job = String(raw.get("job", ""))
	var school: bool = CharacterHook.is_child(st) or load("res://scripts/story/work.gd").category_of(job, false) in ["study"]
	return ["Go to school.", "Okula git."] if school else ["Go to work.", "İşe git."]

## living room / bedroom: point at the front door with the work objective
static func house_cue(shot) -> void:
	var g := goal()
	await Life.guide_to(shot, g[0], {"tr": g[1]})

## on the street (World / world_exterior as `w`): the whole trip. Returns true when it ran (the caller then re-enters).
static func gate(w: Node) -> bool:
	if not pending() or w == null or w.get("player") == null: return false
	var tree := w.get_tree()
	var car: Node3D = null
	var lot = w.grid.find_lot("home") if w.get("grid") else null
	var pool: Array = (lot.find_children("*", "StreetObject", true, false) if lot else []) + w.find_children("*", "StreetObject", true, false)
	for o in pool:
		if String(o.get("kind")) == "car" and (car == null or o.global_position.distance_to(w.player.global_position) < car.global_position.distance_to(w.player.global_position)): car = o
	var g := goal()
	if car:
		# pan framing BOTH the hero and the car
		var hp: Vector3 = w.player.global_position; var cp: Vector3 = car.global_position
		var mid := (hp + cp) * 0.5 + Vector3(0, 0.9, 0)
		var span := maxf(hp.distance_to(cp), 3.0)
		var side := (cp - hp).cross(Vector3.UP); side.y = 0
		if side.length() < 0.05: side = Vector3(1, 0, 0)
		await Life.guide_to({"pos": mid + side.normalized() * span * 1.15 + Vector3(0, span * 0.55 + 1.2, 0), "at": mid}, g[0], {"tr": g[1]})
		while is_instance_valid(w) and is_instance_valid(car) and _on_street(w):
			var a: Vector3 = w.player.global_position; var b: Vector3 = car.global_position; a.y = 0; b.y = 0
			if a.distance_to(b) < NEAR: break
			await tree.process_frame
		if not is_instance_valid(w) or not _on_street(w): return false
	else:
		await Life.guide_to(null, g[0], {"tr": g[1]})
	if "mode" in w: w.mode = "busy"
	if w.player: w.player.velocity = Vector3.ZERO
	Objectives.clear()
	var school: bool = g[0] == "Go to school."
	if w.has_method("say_line"):
		if CharacterHook.is_child(CharacterHook.state()): await w.say_line(ChildDrive.child_line("I am driving to school."))
		else:
			await w.say_line("I am getting in my car.")
			await w.say_line("I am driving to school." if school else "I am driving to work.")
	App.patch_save({"work_done_day": _day()})
	if w.has_method("save_game"): w.save_game()
	var s = load("res://scripts/story/work_summary.gd").new(); tree.root.add_child(s); s.run()
	await s.tree_exited
	var g0: String = goal()[0]
	if Objectives.has(g0): Objectives.complete(g0)
	Objectives.clear()   # home again: the day's own events set the next objective (no stale "Go to work.")   # black summary -> StoryNav home to the front door
	if "mode" in w and is_instance_valid(w): w.mode = "play"
	return true
