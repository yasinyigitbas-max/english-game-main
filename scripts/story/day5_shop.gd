## v33 (blue): DAY 5 dramatic event - a lost child in the corner shop (scenes/places/shop.tscn, PlaceBase).
## Started by day5_routine.gd when the shop is entered on day 5 (stage "out"/"event"). It waits until the shop's own flow is at its
## exit objective ("Go outside.") so the shop's shopping / lesson beats are never interrupted, then: a little boy (Leo) is crying near the
## door -> talk to him -> ask the shop assistant -> describe him (appearance + clothes) -> announcement -> reassure him -> his mum comes in
## -> find out she is his mum -> reunion + polaroid (d5_shop). Steps: data/day5.json "event". Uses only PlaceBase's public helpers
## (person, npcs, its, cine, cine_end, walk_to, busy, room, player, _mark_target), so it also fits the rebuilt v32 shop.
extends "res://scripts/story/day5_common.gd"

var child: DemoCharacter
var mum: DemoCharacter
var asst: DemoCharacter
var _used := ""

func run() -> void:
	var qa := "--qa-d56" in OS.get_cmdline_user_args()
	# wait for the shop's own flow to reach its exit objective
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(sc):
		var ex = sc.its.get("exit") if sc.get("its") is Dictionary else null
		if ex and ex.enabled and String(sc.mode) == "play" and not Audio.is_speaking(): break
		if qa and Time.get_ticks_msec() - t0 > 4000: break
		await _w(0.3)
	if not is_instance_valid(sc): return
	await Audio.wait_idle(10.0)
	if sc.its.has("exit"): sc.its.exit.enabled = false
	sc._mark_target = null
	Objectives.clear()
	sc.used.connect(func(id): _used = String(id))
	sc.busy(true)
	asst = sc.npcs.get("assistant") if sc.get("npcs") is Dictionary else null
	await run_steps(D.event)
	flag("d5_shop_done", true)
	set_stage(day, "home")

## back to the shop's own exit objective (its objective() loop is still waiting for "exit")
func exit_prompt() -> void:
	if not is_instance_valid(sc) or not sc.its.has("exit"): return
	var ex: Interactable = sc.its.exit
	ex.enabled = true; sc._mark_target = ex
	await Life.guide_to(ex.focus, "Go outside.", {"id": "Go outside.", "tr": "Dışarı çık.", "list": [{"id": "Go outside.", "en": "Go outside.", "tr": "Dışarı çık."}]})
	sc.busy(false)

func spk(who: String) -> Array:
	var r := super.spk(who)
	match who:
		"child": r[3] = child
		"mum": r[3] = mum
		"assistant":
			r[3] = asst
			if asst and asst.has_meta("voice"): r[2] = String(asst.get_meta("voice"))   # the shop's own assistant voice (joe)
	return r

func _hz() -> float: return float(sc.room.y) / 2.0
func _near(n: Node3D, d := 1.3) -> Vector3:   # a spot in front of n, towards the room centre
	var to := -n.global_position; to.y = 0
	if to.length() < 0.05: to = Vector3(0, 0, -1)
	return n.global_position + to.normalized() * d

func target(tag: String):
	match tag:
		"child": return child
		"mum": return mum
		"assistant": return asst if asst else null
	return null

func play_mode(on: bool) -> void:
	sc.busy(not on)
	if on:
		var n: Node3D = target(_tag)
		if n:
			var it: Interactable = sc.its.get("d5_" + _tag)
			if it == null: it = sc.target("d5_" + _tag, Vector3.ZERO, Vector3.ZERO, "Talk")
			it.global_position = _near(n, 0.9); it.focus = n.global_position + Vector3(0, 1.1, 0); it.enabled = true
			sc._mark_target = it
	else:
		sc._mark_target = null
		for k in sc.its: if String(k).begins_with("d5_"): sc.its[k].enabled = false

var _tag := ""
func objective(tag: String, en: String, tr: String) -> void:
	_tag = tag
	await super.objective(tag, en, tr)

## reached: the player used the Talk chip or is standing next to the person (QA walks there)
func reach(tag: String) -> void:
	var n: Node3D = target(tag)
	if n == null: return
	_used = ""
	if "--qa-d56" in OS.get_cmdline_user_args(): await sc.walk_to(_near(n, 1.0))
	while is_instance_valid(sc) and is_instance_valid(n):
		var a: Vector3 = sc.player.global_position; var b := n.global_position; a.y = 0; b.y = 0
		if _used == "d5_" + tag or a.distance_to(b) < 1.5: break
		await _w(0.2)
	sc.busy(true)
	await sc.walk_to(_near(n, 1.0))
	_face(sc.player.hero, n.global_position); _face(n, sc.player.global_position)

func _spawn(id: String, g: String, voice: String, pos: Vector3, yaw: float, top: Color, is_child: bool) -> DemoCharacter:
	var ch: DemoCharacter = sc.person(id, g, voice, pos, yaw, "sit_idle", top, is_child)   # "sit_idle" = no static collider at the spawn spot (they move)
	ch.set_meta("pose", "idle"); ch.play("idle", 0.0)
	return ch

func _walk(ch: DemoCharacter, to: Vector3, speed := 1.4) -> void:
	var d := to - ch.global_position; d.y = 0
	if d.length() < 0.05: return
	ch.play("walk", 0.2)
	create_tween().tween_property(ch, "rotation:y", ch.rotation.y + wrapf(atan2(d.x, d.z) - ch.rotation.y, -PI, PI), 0.25)
	var tw := create_tween(); tw.tween_property(ch, "global_position", Vector3(to.x, ch.global_position.y, to.z), d.length() / speed)
	await tw.finished
	ch.play("idle", 0.25)

func act(tag: String) -> void:
	var hz := _hz()
	match tag:
		"child_appears":
			child = _spawn("d5_child", "men", "child_m", Vector3(1.5, 0, hz - 1.7), PI * 0.85, Color(0.98, 0.85, 0.2), true)
			child.hair_color = Color(0.36, 0.22, 0.12); child.outfit["Head"] = 0; child._refresh()   # short brown hair, yellow T-shirt (the description)
			child.bone_offsets["Head"] = [Vector3.RIGHT, 0.35]   # head down, sad
			await sc.cine(child.global_position + Vector3(-1.6, 1.5, -1.8), child.global_position + Vector3(0, 0.7, 0), 1.2)
			await _w(1.6)
			await sc.cine_end()
		"walk_to_assistant":
			if asst:
				var spot := _near(asst, 1.1)
				var side := (spot - asst.global_position).cross(Vector3.UP).normalized() * 0.7
				_walk(child, spot + side)
				await _w(0.6)
				_face(child, asst.global_position)
		"look_at_child":
			await sc.cine(child.global_position + Vector3(0.9, 1.2, 1.4), child.global_position + Vector3(0, 0.75, 0), 1.0)
		"announce":
			Audio.sfx("place_bell", -4.0)
			await sc.cine_end()
		"mum_enters":
			Audio.sfx("place_bell", -6.0); Audio.sfx("doorOpen_1", -4.0)
			mum = _spawn("d5_mum", "women", "amy", Vector3(0, 0, hz - 0.5), PI, Color(0.35, 0.55, 0.85), false)
			mum.hair_color = Color(0.36, 0.22, 0.12); mum._refresh()
			await _walk(mum, Vector3(-0.6, 0, hz - 1.9), 2.2)
			_face(mum, sc.player.global_position)
		"reunite":
			child.bone_offsets.erase("Head")
			await _walk(child, _near(mum, 0.55), 1.8)
			_face(child, mum.global_position); _face(mum, child.global_position)
			Audio.sfx("cloth1", -8.0)
		"photo":
			var c := (child.global_position + mum.global_position) * 0.5
			var p := sc.player.global_position
			var mid := (c + p) * 0.5
			var side := (c - p).cross(Vector3.UP).normalized()
			await snap("d5_shop", mid + side * 2.6 + Vector3(0, 1.4, 0), mid + Vector3(0, 0.8, 0), 50.0)
		"npcs_leave":
			var door := Vector3(0, 0, hz - 0.4)
			_walk(child, door + Vector3(0.3, 0, 0), 1.2)
			await _walk(mum, door, 1.2)
			Audio.sfx("place_bell", -8.0)
			await _w(0.4)
			for n in [child, mum]: if is_instance_valid(n): n.queue_free()
			sc.npcs.erase("d5_child"); sc.npcs.erase("d5_mum")
