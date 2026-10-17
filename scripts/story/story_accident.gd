## house.25 / blue v27: day-1 story, part 1 (first time outside). Automatic cutscene as soon as the player goes outside ("Go outside" loads this scene): stretch, "Wow, such a nice day!",
## a cat is sitting on the road, "Go away, kitty!", a bus is coming, the player runs and dives over the cat, brake + horn,
## first-person bus approach, crash, fade -> hospital. No gore. Captions use the normal queue and animations wait for each line.
## Assets: props/story/animal-cat.glb (Kenney Cube Pets, CC0), props/story/Bus.obj (Quaternius Public Transport, CC0),
## sfx/bus_*.ogg + music/accident_tension.ogg (synthesised for this project, CC0).
extends Node

var w: Node          # world_exterior (UniversalScene)
const RUN_SPEED := 4.0          # m/s that matches the "run" clip stride (no foot sliding)

static func should_run() -> bool:

	return not bool(WorldState.flags.get("story_accident", false)) and maxi(WorldState.day, App.day) <= 1

func _wait(s: float) -> void: await w.get_tree().create_timer(s).timeout

func _line(t: String) -> void:   # caption + English voice, then wait until the line has finished (never cut off)
	await w.caption(t)
	if w.voice_busy(): await w.voice_idle(0.25)
	else: await _wait(clampf(Voice.clip_len(t), 1.8, 4.0))   # blue v29: no clip / clip failed to load: still give the line time

func run() -> void:
	Life.event("accident")   # house.29: event clock
	var p: WorldPlayer = w.player
	var lot = w.grid.find_lot("home")
	var fwd: Vector3 = lot.global_transform.basis.z if lot else Vector3(0, 0, 1)
	fwd.y = 0; fwd = fwd.normalized()
	var side := Vector3(fwd.z, 0, -fwd.x)
	var road: Vector3 = (lot.entrance_global() if lot else p.global_position) + fwd * (lot.path_length + 3.2 if lot else 6.0)
	road.y = 0.07
	# the cat is sitting on the road from the start, so it is visible
	var cat := _make_cat(); w.add_child(cat); cat.global_position = road
	cat.rotation.y = atan2(-fwd.x, -fwd.z); _cat_anim(cat, "idle")
	# ---- automatic: starts the moment the player has chosen "Go outside" (this scene's _ready)
	w.mode = "busy"; p.frozen = true; p.velocity = Vector3.ZERO
	_traffic_off()   # blue v29: no traffic driving through the cutscene cameras
	_open_gate()     # blue v29: the front gate opens explicitly (the proximity trigger depends on the start position)
	_hud_hide(true)   # red v28: no joysticks / buttons / mission during the whole cutscene (captions stay)
	WorldState.flags["story_accident"] = true
	await w.get_tree().process_frame
	p.hero.play("idle", 0.0)
	p.hero.rotation.y = _yaw(fwd)
	var cam := Camera3D.new(); w.add_child(cam); cam.fov = 50.0
	var head := p.global_position + Vector3(0, 1.7, 0)
	# shot 0: establishing shot, the character is stepping out and stretching
	var e0 := _safe(p.global_position + fwd * 5.5 + side * 3.5 + Vector3(0, 2.6, 0), head - Vector3(0, 0.4, 0))
	cam.global_position = e0; cam.look_at(head - Vector3(0, 0.4, 0)); cam.current = true
	var est := w.create_tween(); est.tween_property(cam, "global_position", _safe(e0 - side * 1.2 - fwd * 0.8, head - Vector3(0, 0.4, 0)), 6.0).set_trans(Tween.TRANS_SINE)
	await Audio.wait_idle(6.0)
	await _stretch(p.hero, true)
	await _line("Wow, such a nice day!")
	await _stretch(p.hero, false)
	# tension music starts when the cat is noticed
	var music := AudioStreamPlayer.new(); music.stream = load("res://music/accident_tension.ogg"); music.volume_db = -14.0
	w.add_child(music); music.play()
	w.create_tween().tween_property(music, "volume_db", -6.0, 10.0)
	# notices the cat: turns towards the road, cut to the over-the-shoulder shot
	var turn := w.create_tween(); turn.tween_property(p.hero, "rotation:y", _yaw(road - p.global_position), 0.35).set_trans(Tween.TRANS_SINE)
	await turn.finished
	est.kill()
	# over the shoulder from the road side (v28 fix: the old +side offset sat inside the house wall), clamped against walls
	# blue v29: higher and further back over the shoulder, tight lens on the cat; the head sits at the frame edge, not over a quarter of it
	var os_look := road + Vector3(0, 0.2, 0)
	var os0 := _safe(head + Vector3(0, 0.9, 0) - fwd * 2.2 - side * 1.5, head)   # v29: head at the left edge, clear line to the cat
	cam.global_position = os0; cam.look_at(os_look + side * 0.6); cam.fov = 30.0
	var dolly := w.create_tween(); dolly.tween_property(cam, "fov", 24.0, 4.0).set_trans(Tween.TRANS_SINE)
	Audio.sfx("plop", -8.0, 1.6)
	await _line("Look! A cat is sitting on the road.")
	# shot 2: front of the player, he waves the cat away
	# blue v29: medium shot from the front-left inside the yard (the v28 merge had commented out its look_at)
	dolly.kill()
	cam.global_position = _safe(p.global_position + fwd * 2.2 - side * 1.2 + Vector3(0, 1.5, 0), head - Vector3(0, 0.3, 0)); cam.look_at(head - Vector3(0, 0.35, 0)); cam.fov = 42.0
	p.hero.play("wave", 0.25)
	await _line("Go away, kitty! Move!")
	p.hero.play("idle", 0.3)
	# shot 3: low on the road, the bus is coming at the cat
	var bus := _make_bus(); w.add_child(bus); bus.global_position = road - side * 42.0; bus.look_at(road, Vector3.UP)
	# blue v29: low behind the cat, looking down the road at the bus: cat in the foreground, bus coming behind it
	cam.global_position = _safe(road + side * 3.2 + fwd * 0.5 + Vector3(0, 0.45, 0), road + Vector3(0, 0.3, 0)); cam.look_at(road - side * 12.0 + fwd * 0.3 + Vector3(0, 0.9, 0)); cam.fov = 42.0
	_snap_player("outside", p.global_position.lerp(road, 0.4) + side * 2.6 + Vector3(0, 1.5, 0), p.global_position.lerp(road, 0.2) + Vector3(0, 0.9, 0))   # red v28: polaroid frames the player + cat
	var b1 := w.create_tween(); b1.tween_property(bus, "global_position", road - side * 24.0, 4.0)
	_cat_freeze(cat, bus.global_position)        # the cat freezes and looks up at the bus
	await _line("Oh no! A bus is coming!")
	await _line("I am running to the cat!")
	# shot 4: side tracking shot of the run, the bus keeps coming
	var start := p.global_position; var stop := road - fwd * 1.1; stop.y = start.y
	var run_t := maxf(0.6, start.distance_to(stop) / RUN_SPEED)
	p.hero.rotation.y = _yaw(stop - start)
	p.hero.player.speed_scale = 1.0; p.hero.play("run", 0.2)
	b1.kill(); var b2 := w.create_tween(); b2.tween_property(bus, "global_position", road - side * 11.0, run_t + 0.55)
	cam.fov = 55.0
	var mid := (start + stop) * 0.5
	# v28: chase camera behind and above the runner, along the path he came (clear line), looking ahead at the cat/bus
	var rdir := (stop - start).normalized(); var rside := Vector3(rdir.z, 0, -rdir.x)
	cam.global_position = _safe(start - rdir * 3.2 + rside * 0.6 + Vector3(0, 2.0, 0), start + Vector3(0, 1.0, 0)); cam.look_at(start + Vector3(0, 1.0, 0))
	var rt := w.create_tween().set_parallel()
	rt.tween_property(p, "global_position", stop, run_t)
	rt.tween_method(_track.bind(cam, rside, rdir), start, stop, run_t)
	await rt.finished
	# the dive (v28): procedural keyframed bone animation, blended in from the run:
	# push-off crouch, arms forward, body horizontal in flight, land prone over the cat with the arms around it, then breathing
	var land := cat.global_position - fwd * 0.3; land.y = start.y   # v28: the arc ends on the cat (hips just short of it, chest over it)
	var anims := _build_dive(p.hero)
	cam.global_position = _safe(road + side * 2.6 - fwd * 1.8 + Vector3(0, 0.6, 0), road + Vector3(0, 0.6, 0)); cam.look_at(road + Vector3(0, 0.5, 0)); cam.fov = 48.0
	Engine.time_scale = 0.6   # short slow-motion for the dive
	p.hero.player.play("blue/dive", 0.12)
	var y0: float = p.hero.position.y
	var push := stop + fwd * 0.18
	var dt := w.create_tween()
	# 0-0.14 s: last step into the crouch (the root keeps the run's speed so the planted foot does not slide much)
	dt.tween_property(p, "global_position", push, 0.14)
	dt.parallel().tween_property(p.hero, "position:y", y0 - 0.12, 0.14).set_ease(Tween.EASE_OUT)
	# 0.14-0.62 s: flight, a ballistic arc down to the prone landing height
	dt.tween_method(_fly.bind(p, push, land, y0 - 0.12, y0 + anims.prone_off), 0.0, 1.0, 0.48)
	dt.parallel().tween_property(cat, "scale", cat.scale * Vector3(1.1, 0.6, 1.1), 0.4)   # the cat crouches under him
	await w.get_tree().create_timer(0.3).timeout
	Audio.sfx("bus_brake", 0.0); Audio.sfx("bus_horn", -1.0)    # brake + horn together
	await dt.finished
	Engine.time_scale = 1.0
	p.hero.player.play("blue/shield", 0.15)   # holds the shield pose, breathing, until the cut
	# shot 5: first person from the road, the bus is approaching
	b2.kill()
	_snap_player("accident", land + fwd * 3.0 + side * 2.0 + Vector3(0, 1.5, 0), land - side * 1.5 + Vector3(0, 0.3, 0))   # red v28: moved up from the impact (the bus covers him there): player over the cat, bus coming
	var eye := land + Vector3(0, 0.45, 0) - fwd * 0.2
	cam.global_position = eye; cam.look_at(bus.global_position + Vector3(0, 1.4, 0)); cam.fov = 70.0
	var bt := w.create_tween(); bt.tween_property(bus, "global_position", road - side * 6.3, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)   # the bus origin is its centre: the front stops just short of the camera
	var zt := w.create_tween(); zt.tween_property(cam, "fov", 38.0, 1.2)
	var shake := w.create_tween().set_loops(12)
	shake.tween_callback(func(): cam.global_position = eye + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0)); shake.tween_interval(0.1)
	await bt.finished
	shake.kill()
	# impact: music cut, crash, instant black
	music.stop()
	Audio.sfx("bus_crash", 0.0)
	var cl := CanvasLayer.new(); cl.layer = 50; w.add_child(cl)
	var black := ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(black)
	var ft := w.create_tween(); ft.tween_property(black, "color:a", 1.0, 0.12); await ft.finished
	await _wait(2.2)
	_hud_hide(false)   # red v28: restore the HUD (screen is black, the scene changes next)
	w.save_game(); App.came_from = "accident"
	Life.event("hospital")   # v29: event clock
	# blue v29: stay black through the scene change (no grey frame): the persistent Game fade layer covers the load,
	# then fades out once the hospital has drawn; its usual tint is restored afterwards
	var gf: ColorRect = Game._fade
	gf.color = Color(0, 0, 0, 1)
	w.get_tree().create_timer(1.6).timeout.connect(gf.set.bind("color", Color(0, 0, 0, 0.0)))   # fix33 (black): the trip tint stays black
	# open world (black, build 3): the World is never freed, so this black layer (and the cutscene camera) used to stay on
	# top forever after the crash = Yasin's black screen. The Game fade (black, set above) now covers the trip instead.
	w.get_tree().create_timer(0.3).timeout.connect(cl.queue_free)
	if is_instance_valid(cam) and cam.get_parent() == w and not cam.has_meta("keep"): w.get_tree().create_timer(0.3).timeout.connect(func(): if is_instance_valid(cam): cam.current = false)
	if Game.busy: StoryNav.travel(w.get_tree(), "res://scenes/hospital.tscn", "", true)
	else: StoryNav.travel(w.get_tree(), "res://scenes/hospital.tscn")

## red v28: HUD on/off for the cutscene. GameHUD._process re-shows its panels every frame, so it is paused while hidden.
var _hud_vis := {}
func _hud_hide(on: bool) -> void:
	var hud = w.get("hud")
	if hud == null or not is_instance_valid(hud) or hud.root == null: return
	if on:
		_hud_vis.clear()
		for c in hud.root.get_children():
			if c == hud.cap_panel: continue
			_hud_vis[c] = c.visible; c.visible = false; c.modulate.a = 0.0   # modulate too: hud._refresh() (on every caption) re-shows mission/place
		hud.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		for c in _hud_vis:
			if is_instance_valid(c): c.visible = _hud_vis[c]; c.modulate.a = 1.0
		_hud_vis.clear()
		hud.process_mode = Node.PROCESS_MODE_INHERIT
	var life_hud = Life.get("_hud")   # clock / day / battery strip
	if life_hud is CanvasLayer: life_hud.visible = not on

## red v28: polaroid snapshot from an offscreen camera aimed at the player (the on-screen shot may not show him)
func _snap_player(key: String, from: Vector3, at: Vector3) -> void:
	var xf := Transform3D(Basis(), from).looking_at(at, Vector3.UP)
	Life.snap_from(key, xf, 50.0)

func _yaw(d: Vector3) -> float: return atan2(d.x, d.z)

# ---- cat: Kenney Cube Pets cat (CC0) with its own idle/walk animations
func _make_cat() -> Node3D:
	var n: Node3D = (load("res://props/story/animal-cat.glb") as PackedScene).instantiate()
	n.scale = Vector3.ONE * 0.32
	return n

func _cat_anim(cat: Node3D, a: String) -> void:
	var ap := cat.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(a):
		ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		ap.play(a, 0.2)

func _cat_freeze(cat: Node3D, look: Vector3) -> void:
	var ap := cat.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var to := look - cat.global_position
	var t := w.create_tween(); t.tween_property(cat, "rotation:y", _yaw(to), 0.25)
	if ap: t.tween_callback(ap.pause)
	var head := cat.find_child("Group", true, false) as Node3D   # head group: look up a little
	if head: t.tween_property(head, "rotation:x", deg_to_rad(-18.0), 0.2)

# ---- bus: Quaternius Public Transport "Bus" (CC0), recoloured per surface
func _make_bus() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new(); var mesh: Mesh = load("res://props/story/Bus.obj"); mi.mesh = mesh
	var cols := {"Top": Color(0.93, 0.33, 0.18), "Windows": Color(0.16, 0.22, 0.3), "Bottom": Color(0.35, 0.35, 0.37),
		"Bumper": Color(0.2, 0.2, 0.22), "Lights": Color(1.0, 0.95, 0.75), "Material": Color(0.07, 0.07, 0.07), "Details": Color(0.6, 0.6, 0.6)}
	for i in mesh.get_surface_count():
		var m := StandardMaterial3D.new(); var nm := String(mesh.surface_get_name(i))
		m.albedo_color = cols.get(nm, Color(0.9, 0.9, 0.9))
		if nm == "Lights": m.emission_enabled = true; m.emission = Color(1, 0.95, 0.7); m.emission_energy_multiplier = 1.5
		if nm == "Windows": m.roughness = 0.15; m.metallic = 0.3
		mi.set_surface_override_material(i, m)
	# model: length on X (-0.28..3.81), up Y (-1.12..0.55), width Z; front (grille details) at -X -> face -Z for look_at
	mi.rotation.y = -PI / 2
	mi.scale = Vector3(2.4, 1.9, 1.5)
	mi.position = Vector3(0, 1.12 * 1.9, -1.77 * 2.4)
	n.add_child(mi)
	return n

# ---- stretch: the library has no stretch clip, so the arms are raised by blending bone poses over the paused idle pose
var _arm_base := {}
func _stretch(hero: Node3D, up: bool) -> void:
	var sk: Skeleton3D = hero.skeleton
	var ap: AnimationPlayer = hero.player
	if sk == null: return
	if up:
		if ap: ap.pause()
		_arm_base.clear()
		for n in ["UpperArm.L", "UpperArm.R", "LowerArm.L", "LowerArm.R"]:
			var i := sk.find_bone(n)
			if i >= 0: _arm_base[n] = sk.get_bone_pose_rotation(i)
	var t := w.create_tween()
	t.tween_method(func(k: float): _arm_pose(sk, k), 0.0 if up else 1.0, 1.0 if up else 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if not up and ap: ap.play("idle", 0.3)

func _arm_pose(sk: Skeleton3D, k: float) -> void:
	for s in ["L", "R"]:
		var ui := sk.find_bone("UpperArm." + s); var li := sk.find_bone("LowerArm." + s)
		if ui < 0 or li < 0 or not _arm_base.has("UpperArm." + s): continue
		sk.set_bone_pose_rotation(ui, _arm_base["UpperArm." + s]); sk.set_bone_pose_rotation(li, _arm_base["LowerArm." + s])
		var g := sk.get_bone_global_pose(ui); var c := sk.get_bone_global_pose(li).origin
		var dir := (c - g.origin).normalized()
		var out := 1.0 if g.origin.x > 0.0 else -1.0
		var target := (Vector3.UP * 0.92 + Vector3(out * 0.38, 0, 0)).normalized()
		if dir.dot(target) < -0.99: continue
		var q := Quaternion.IDENTITY.slerp(Quaternion(dir, target), k)
		var ng := Basis(q) * g.basis
		var pg := sk.get_bone_global_pose(sk.get_bone_parent(ui)).basis
		sk.set_bone_pose_rotation(ui, (pg.inverse() * ng).get_rotation_quaternion())
		var lb: Quaternion = _arm_base["LowerArm." + s]
		sk.set_bone_pose_rotation(li, lb.slerp(Quaternion.IDENTITY, 0.6 * k))   # elbows straighten

# ---- v28 camera clamp: pull a cutscene camera in front of any wall between it and what it looks at
func _safe(pos: Vector3, look: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = w.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(look, pos)
	if w.player is CollisionObject3D: q.exclude = [w.player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty(): return pos
	return hit.position + (look - pos).normalized() * 0.35

# ---- v28 dive: keyframed bone animations generated from aim poses on the character's own skeleton
# Directions are in the character's space (+Z forward, +Y up, sx = +1/-1 for the bone's side).
const DIVE_POSES := {
	"crouch": {"Hips": [0, 0.85, 0.55], "Abdomen": [0, 0.8, 0.6], "Torso": [0, 0.75, 0.66], "Chest": [0, 0.7, 0.7], "Neck": [0, 0.75, 0.66], "Head": [0, 0.9, 0.45],
		"UpperArm": [0.25, -0.55, -0.8], "LowerArm": [0.15, -0.7, -0.7], "UpperLeg": [0, -0.6, 0.8], "LowerLeg": [0, -0.95, -0.3]},
	"flight": {"Hips": [0, 0.1, 1], "Abdomen": [0, 0.08, 1], "Torso": [0, 0.06, 1], "Chest": [0, 0.05, 1], "Neck": [0, 0.15, 1], "Head": [0, 0.35, 1],
		"UpperArm": [0.22, 0.1, 1], "LowerArm": [0.12, 0.12, 1], "UpperLeg": [0.08, -0.05, -1], "LowerLeg": [0, 0.12, -1]},
	"prone": {"Hips": [0, -0.02, 1], "Abdomen": [0, -0.04, 1], "Torso": [0, -0.06, 1], "Chest": [0, -0.08, 1], "Neck": [0, -0.2, 1], "Head": [0, -0.45, 1],
		"UpperArm": [0.7, -0.45, 0.55], "LowerArm": [-0.75, -0.35, 0.55], "UpperLeg": [0.14, -0.06, -1], "LowerLeg": [0.04, 0.05, -1]},
	"breath": {"Hips": [0, -0.02, 1], "Abdomen": [0, 0.0, 1], "Torso": [0, 0.0, 1], "Chest": [0, -0.02, 1], "Neck": [0, -0.16, 1], "Head": [0, -0.42, 1],
		"UpperArm": [0.72, -0.42, 0.55], "LowerArm": [-0.75, -0.33, 0.56], "UpperLeg": [0.14, -0.06, -1], "LowerLeg": [0.04, 0.05, -1]},
}
const CHAIN := [["Hips", "Abdomen"], ["Abdomen", "Torso"], ["Torso", "Chest"], ["Chest", "Neck"], ["Neck", "Head"], ["Head", "Head_end"],
	["UpperArm.L", "LowerArm.L"], ["LowerArm.L", "Hand.L"], ["UpperArm.R", "LowerArm.R"], ["LowerArm.R", "Hand.R"],
	["UpperLeg.L", "LowerLeg.L"], ["LowerLeg.L", "Foot.L"], ["UpperLeg.R", "LowerLeg.R"], ["LowerLeg.R", "Foot.R"]]

func _pose(sk: Skeleton3D, base: Array, to_skel: Basis, pose: Dictionary) -> Array:
	for i in sk.get_bone_count(): sk.set_bone_pose_rotation(i, base[i])
	for pair in CHAIN:   # parents first, so each aim sees its final parent
		var bi := sk.find_bone(pair[0]); var ci := sk.find_bone(pair[1])
		if bi < 0 or ci < 0: continue
		var key: String = String(pair[0]).split(".")[0]
		if not pose.has(key): continue
		var g := sk.get_bone_global_pose(bi)
		var sx := 1.0 if g.origin.x > 0.0 else -1.0
		var d: Array = pose[key]
		var target := (to_skel * Vector3(d[0] * sx, d[1], d[2])).normalized()
		var cur := (sk.get_bone_global_pose(ci).origin - g.origin).normalized()
		if cur.length() < 0.5 or cur.dot(target) < -0.999: continue
		var ng := Basis(Quaternion(cur, target)) * g.basis
		var par := sk.get_bone_parent(bi)
		var pg := sk.get_bone_global_pose(par).basis if par >= 0 else Basis()
		sk.set_bone_pose_rotation(bi, (pg.inverse() * ng).get_rotation_quaternion())
	var out := []
	for i in sk.get_bone_count(): out.append(sk.get_bone_pose_rotation(i))
	return out

func _build_dive(hero: Node3D) -> Dictionary:
	var sk: Skeleton3D = hero.skeleton; var ap: AnimationPlayer = hero.player
	var base := []
	for i in sk.get_bone_count(): base.append(sk.get_bone_pose_rotation(i))   # the current run frame
	var to_skel: Basis = (sk.global_transform.basis.orthonormalized().inverse() * hero.global_transform.basis.orthonormalized())
	var poses := {}
	for k in DIVE_POSES: poses[k] = _pose(sk, base, to_skel, DIVE_POSES[k])
	# prone landing height: lift the hero so the lowest posed bone rests ~0.12 m above the road
	# prone landing height: the hips end ~0.2 m above the road (measured on the run frame)
	var hips := sk.find_bone("Hips")
	for i in sk.get_bone_count(): sk.set_bone_pose_rotation(i, base[i])
	var hy := (sk.global_transform * sk.get_bone_global_pose(hips)).origin.y if hips >= 0 else hero.global_position.y + 1.0
	var prone_off := (hero.global_position.y + 0.2) - hy
	for i in sk.get_bone_count(): sk.set_bone_pose_rotation(i, base[i])
	var root := ap.get_node(ap.root_node)
	var sp := String(root.get_path_to(sk))
	var dive := Animation.new(); dive.length = 0.62
	var shield := Animation.new(); shield.length = 2.4; shield.loop_mode = Animation.LOOP_PINGPONG
	for i in sk.get_bone_count():
		var t := dive.add_track(Animation.TYPE_ROTATION_3D); dive.track_set_path(t, "%s:%s" % [sp, sk.get_bone_name(i)])
		dive.rotation_track_insert_key(t, 0.0, base[i]); dive.rotation_track_insert_key(t, 0.14, poses.crouch[i])
		dive.rotation_track_insert_key(t, 0.34, poses.flight[i]); dive.rotation_track_insert_key(t, 0.62, poses.prone[i])
		var s := shield.add_track(Animation.TYPE_ROTATION_3D); shield.track_set_path(s, "%s:%s" % [sp, sk.get_bone_name(i)])
		shield.rotation_track_insert_key(s, 0.0, poses.prone[i]); shield.rotation_track_insert_key(s, 1.2, poses.breath[i])
	var lib := AnimationLibrary.new(); lib.add_animation("dive", dive); lib.add_animation("shield", shield)
	if ap.has_animation_library("blue"): ap.remove_animation_library("blue")
	ap.add_animation_library("blue", lib)
	return {"prone_off": prone_off}

func _fly(k: float, p: Node3D, a: Vector3, b: Vector3, ya: float, yb: float) -> void:
	p.global_position = a.lerp(b, k)
	p.hero.position.y = lerpf(ya, yb, k) + sin(k * PI) * 0.2

func _track(v: Vector3, cam: Camera3D, rside: Vector3, rdir: Vector3) -> void:   # v28 run tracking shot
	cam.global_position = _safe(v - rdir * 3.2 + rside * 0.6 + Vector3(0, 2.0, 0), v + Vector3(0, 1.0, 0))
	cam.look_at(v + Vector3(0, 1.0, 0) + rdir * 1.5)

func _traffic_off() -> void:   # blue v29
	var vs: Array = []
	for c in w.get_children(): if c is Vehicle: vs.append(c)
	for k in ["cars", "buses"]:
		var arr = w.get(k)
		if arr is Array: for c in arr: if is_instance_valid(c) and not vs.has(c): vs.append(c)
	for c in vs:
		c.process_mode = Node.PROCESS_MODE_DISABLED; c.visible = false
		c.global_position += Vector3(0, -200, 0)   # parked far below the street for the cutscene (the scene is left afterwards)
	print("blue v29 traffic off: ", vs.size())

func _open_gate() -> void:   # blue v29
	for n in w.find_children("*", "Node3D", true, false):
		if n is StreetObject and n.kind == "gate" and not n.S.get("open", false):
			var near := Vector2(n.global_position.x - w.player.global_position.x, n.global_position.z - w.player.global_position.z).length() < 25.0
			if not near: continue
			n.S.open = true; n.S.col.disabled = true
			var away := -1.0 if n.to_local(w.player.global_position).z < 0.0 else 1.0
			n.swing(n.parts.leaf, "rotation:y", 1.7 * away, 0.6)
