## v33 (blue): DAY 6 dramatic event - a storm and a broken-down bus at the home bus stop (outside, world_exterior.gd).
## Started by day5_routine.gd when the player reaches stop_home on day 6 (stage "out"). Steps: data/day6.json "event":
## the sky darkens + rain + thunder -> talk about the weather with a woman at the stop -> the bus arrives and breaks down -> ask the
## driver -> wait under the shelter -> choose: walk / taxi (busy) / call family -> phone call -> polaroid (d6_storm) -> ride home.
## Gentle for kids: no crash, nobody hurt; only a strange noise, a little smoke and hazard lights.
## Storm look without touching world_exterior.gd: env adjustment brightness / saturation + fog density (its clock only sets colours),
## CPUParticles3D rain around the player, own rain loop + thunder (sfx/day6_rain.ogg, sfx/day6_thunder.ogg: generated noise, CC0).
## The two timetable buses are parked out of sight during the event and re-synced to the timetable afterwards.
extends "res://scripts/story/day5_common.gd"

var woman: DemoCharacter
var driver: DemoCharacter
var bus: Vehicle
var rain: CPUParticles3D
var rain_snd: AudioStreamPlayer
var _hazard: Array = []
var _parked: Array = []

func _stop() -> Vector3:
	var p: Vector3 = Transit.stops.stop_home.pos if Transit.stops.has("stop_home") else Vector3(9.5, 0, 14.7)
	return Vector3(p.x, 0.07, p.z)

func run() -> void:
	sc.mode = "busy"; sc._hide_chips()
	await Audio.wait_idle(10.0)
	await run_steps(D.event)
	flag("d6_storm_done", true)
	set_stage(day, "home")
	sc.mode = "play"

func _process(_dt: float) -> void:
	if rain and is_instance_valid(sc) and sc.player: rain.global_position = sc.player.global_position + Vector3(0, 11, 0)

func spk(who: String) -> Array:
	var r := super.spk(who)
	if who == "woman": r[3] = woman
	elif who == "driver": r[3] = driver
	return r

func target(tag: String):
	var p: Node3D = sc.player
	match tag:
		"woman", "driver":
			var n: Node3D = woman if tag == "woman" else driver
			if n == null: return null
			var at := n.global_position + Vector3(0, 1.2, 0)
			var away := at - p.global_position; away.y = 0
			if away.length() < 0.05: away = Vector3(0, 0, 1)
			var side := away.normalized().cross(Vector3.UP)
			return {"pos": at - away.normalized() * 2.2 + side * 2.0 + Vector3(0, 1.2, 0), "at": at}
		"shelter":
			var s := _stop() + Vector3(0, 1.4, 0)
			return {"pos": s + Vector3(4.5, 2.6, 4.5), "at": s}
		"me":
			var h := p.global_position + Vector3(0, 1.2, 0)
			return {"pos": h + Vector3(2.4, 1.2, 2.4), "at": h}
	return null

func play_mode(on: bool) -> void:
	sc.mode = "play" if on else "busy"
	if not on: sc._hide_chips()

func reach(tag: String) -> void:
	var goal: Vector3
	match tag:
		"woman": goal = woman.global_position
		"driver": goal = driver.global_position
		"shelter": goal = _stop()
		_: return
	var qa := "--qa-d56" in OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(sc):
		var a: Vector3 = sc.player.global_position; a.y = 0; var b := goal; b.y = 0
		if a.distance_to(b) < (1.2 if tag == "shelter" else 1.8): break
		if qa or Time.get_ticks_msec() - t0 > 90000: break   # never stuck: after 90 s the player is walked there
		await _w(0.2)
	sc.mode = "busy"
	await _walk_player(goal, 0.9 if tag != "shelter" else 0.0)
	if tag != "shelter":
		var n: Node3D = woman if tag == "woman" else driver
		_face(sc.player.hero, n.global_position); _face(n, sc.player.global_position)

func _walk_player(goal: Vector3, keep: float) -> void:
	var p: Node3D = sc.player
	var d := goal - p.global_position; d.y = 0
	if d.length() <= keep + 0.1: return
	var to := p.global_position + d.normalized() * (d.length() - keep)
	sc.player.hero.play("walk", 0.2)
	create_tween().tween_property(sc.player.hero, "rotation:y", sc.player.hero.rotation.y + wrapf(atan2(d.x, d.z) - sc.player.hero.rotation.y, -PI, PI), 0.25)
	var tw := create_tween(); tw.tween_property(p, "global_position", Vector3(to.x, p.global_position.y, to.z), (d.length() - keep) / 1.6)
	await tw.finished
	sc.player.hero.play("idle", 0.25)

func _person(g: String, voice: String, pos: Vector3, top: Color) -> DemoCharacter:
	var ch := DemoCharacter.new(); sc.add_child(ch); ch.setup(g); ch.set_height("medium")
	ch.skin = randi() % 4; ch.top_color = top; ch._refresh()
	ch.global_position = pos; ch.set_meta("voice", voice); ch.set_meta("pose", "idle"); ch.play("idle", 0.0)
	return ch

func act(tag: String) -> void:
	var env: Environment = sc.get("env")
	match tag:
		"storm_start":
			WorldState.set_time(15, 0)
			_storm_look(true, env)   # build 3.2 (black #11): open-world env has adjustments / fog off: grey sky, weak sun, dim ambient
			if env:
				var t := create_tween().set_parallel(true)
				t.tween_property(env, "adjustment_brightness", 0.62, 4.0); t.tween_property(env, "adjustment_saturation", 0.7, 4.0)
				t.tween_property(env, "fog_density", 0.022, 4.0)
			_rain_on()
			await _w(1.5)
		"thunder":
			Audio.sfx("day6_thunder", -3.0)
			if env:
				var b0 := env.adjustment_brightness
				var t2 := create_tween(); t2.tween_property(env, "adjustment_brightness", 1.3, 0.08); t2.tween_property(env, "adjustment_brightness", b0, 0.5)
			await _w(0.8)
		"woman_appears":
			woman = _person("women", "kristin", _stop() + Vector3(1.6, 0, 0.4), Color(0.7, 0.35, 0.45))
			_face(woman, sc.player.global_position)
		"bus_arrives":
			_park_buses(true)
			bus = Vehicle.new(); bus.is_bus = true; sc.add_child(bus)
			bus.setup(Vehicle.lane_loop([Vector2(60, 20), Vector2(-20, 20), Vector2(-20, 60), Vector2(60, 60)]), 0.0)
			bus.set_physics_process(false)
			var s_stop := bus.project(_stop()) - 0.5
			bus.s = s_stop - 45.0; bus._place()
			Audio.sfx("bus_horn", -8.0)
			var tw := create_tween()
			tw.tween_method(func(x: float): bus.s = x; bus._place(), s_stop - 45.0, s_stop, 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await _w(4.2); Audio.sfx("bus_brake", -4.0)
			await tw.finished
		"bus_breaks":
			Audio.sfx("metalClick", -2.0, 0.6); await _w(0.35); Audio.sfx("metalClick", -2.0, 0.5)
			if bus.body:
				var sh := create_tween()
				for i in 6: sh.tween_property(bus.body, "position:y", 0.05 if i % 2 == 0 else 0.0, 0.08)
			_smoke(); _hazards()
			await _w(1.0)
			driver = _person("men", "joe_deep", bus.global_transform * Vector3(-2.2, 0, 4.2), Color(0.2, 0.3, 0.5))
			driver.global_position.y = 0.07
			_face(driver, sc.player.global_position)
		"wait":
			_face(sc.player.hero, bus.global_position if bus else sc.player.global_position + Vector3(0, 0, 1))
			if woman: await _w(0.1)
		"time_skip":
			await Game.fade(1.0, 0.6)
			WorldState.minutes += 10.0
			await _w(0.6)
			await Game.fade(0.0, 0.6)
		"taxi":
			Audio.sfx("ring", -6.0)
			await run_steps(D.get("taxi", []))
		"phone_out":
			Audio.sfx("ring", -6.0)
			sc.player.hero.play("idle", 0.2)
		"phone_away":
			Audio.sfx("metalClick", -8.0)
		"photo":
			var p: Vector3 = sc.player.global_position
			var bp: Vector3 = bus.global_position if bus else p + Vector3(0, 0, 5)
			var mid := (p + bp) * 0.5
			var side := (bp - p).cross(Vector3.UP).normalized()
			await snap("d6_storm", mid + side * 9.0 + Vector3(0, 3.0, 0), mid + Vector3(0, 1.2, 0), 55.0)
		"ride_home":
			await Game.fade(1.0, 0.8)
			for n in [bus, driver, woman]: if is_instance_valid(n): n.queue_free()
			for h in _hazard: if is_instance_valid(h): h.queue_free()
			_park_buses(false)
			Audio.sfx("doorClose_2", -6.0)
			WorldState.minutes += 20.0
			var lot = sc.grid.find_lot("home")
			var pos: Vector3 = (lot.entrance_global() + lot.global_transform.basis.z * 0.6) if lot else Vector3(-3, 0.07, 5)
			pos.y = 0.07
			sc.grid.load_around_now(pos); sc.player.global_position = pos; sc.cam.focus = pos
			sc.player.face(PI)
			await _w(0.6)
			await Game.fade(0.0, 0.8)

func _rain_on() -> void:
	rain = CPUParticles3D.new(); rain.amount = 900; rain.lifetime = 0.9; rain.local_coords = false
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(14, 0.5, 14)
	rain.direction = Vector3(0.12, -1, 0); rain.spread = 3.0; rain.initial_velocity_min = 13.0; rain.initial_velocity_max = 16.0; rain.gravity = Vector3(0, -12, 0)
	var bm := BoxMesh.new(); bm.size = Vector3(0.015, 0.45, 0.015); rain.mesh = bm
	var mm := StandardMaterial3D.new(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mm.albedo_color = Color(0.78, 0.84, 0.95, 0.45)
	bm.material = mm
	sc.add_child(rain); rain.global_position = sc.player.global_position + Vector3(0, 11, 0); rain.emitting = true
	var st = load("res://sfx/day6_rain.ogg") if ResourceLoader.exists("res://sfx/day6_rain.ogg") else null
	if st is AudioStream:
		if "loop" in st: st.loop = true
		rain_snd = AudioStreamPlayer.new(); rain_snd.stream = st; rain_snd.volume_db = -30.0; add_child(rain_snd); rain_snd.play()
		create_tween().tween_property(rain_snd, "volume_db", -11.0, 3.0)

func _smoke() -> void:
	if bus == null: return
	var rear: Vector3 = bus.global_transform * Vector3(0, 1.2, -5.2)
	var m := StandardMaterial3D.new(); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(0.75, 0.75, 0.78, 0.55); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 7:
		var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.35; sm.height = 0.7; sm.material = m; b.mesh = sm
		sc.add_child(b); b.global_position = rear + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.3, 0.3))
		var t := b.create_tween().set_parallel(true)
		t.tween_property(b, "global_position", b.global_position + Vector3(randf_range(-0.6, 0.6), 2.5 + i * 0.3, 0), 3.0 + i * 0.3).set_delay(i * 0.35)
		t.tween_property(b, "scale", Vector3.ONE * 2.2, 3.0 + i * 0.3).set_delay(i * 0.35)
		t.chain().tween_callback(b.queue_free)

func _hazards() -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(1.0, 0.6, 0.1); m.emission_enabled = true; m.emission = Color(1.0, 0.55, 0.1); m.emission_energy_multiplier = 2.5
	for c in [Vector3(-1.1, 0.8, 5.52), Vector3(1.1, 0.8, 5.52), Vector3(-1.1, 0.8, -5.52), Vector3(1.1, 0.8, -5.52)]:
		var b := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(0.3, 0.15, 0.05); bx.material = m; b.mesh = bx
		bus.add_child(b); b.position = c; _hazard.append(b)
		var t := b.create_tween().set_loops(); t.tween_property(b, "visible", false, 0.45); t.tween_property(b, "visible", true, 0.45)

func _park_buses(on: bool) -> void:
	var bs = sc.get("buses")
	if not bs is Array: return
	for vb in bs:
		if not is_instance_valid(vb): continue
		vb.set_physics_process(not on)
		if on: vb.position.y = -60.0
		else: vb.position.y = 0.0; vb.sync(WorldState.minutes)

var _sl := {}
func _storm_look(on: bool, env: Environment) -> void:
	if env == null: return
	var suns: Array = sc.find_children("*", "DirectionalLight3D", true, false) if is_instance_valid(sc) else []
	if on and _sl.is_empty():
		_sl = {"adj": env.adjustment_enabled, "bg": env.background_color, "amb": env.ambient_light_energy, "suns": suns.map(func(l): return [l, l.light_energy])}
		env.adjustment_enabled = true
		var t := create_tween().set_parallel(true)
		t.tween_property(env, "background_color", Color(0.42, 0.45, 0.5), 4.0); t.tween_property(env, "ambient_light_energy", env.ambient_light_energy * 0.55, 4.0)
		for l in suns: t.tween_property(l, "light_energy", (l as Light3D).light_energy * 0.25, 4.0)
	elif not on and not _sl.is_empty():
		env.adjustment_enabled = _sl.adj; env.background_color = _sl.bg; env.ambient_light_energy = _sl.amb
		for p in _sl.suns: if is_instance_valid(p[0]): (p[0] as Light3D).light_energy = p[1]
		_sl = {}

func _exit_tree() -> void:
	var env: Environment = sc.get("env") if is_instance_valid(sc) else null
	_storm_look(false, env)
	if env: env.adjustment_brightness = 1.0; env.adjustment_saturation = 1.18; env.fog_density = 0.0018
