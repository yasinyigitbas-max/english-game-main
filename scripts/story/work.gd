## v31 day 2: a short work routine for the player's job (data/work.json, one routine per job category).
## Reached from the car on day 2 ("Go to work" / "Go to school" / "Go shopping"). A walkable room like the outdoor world
## (UniversalScene: shared HUD, phone, pause menu, TR toggle, queued captions). Four tasks, one at a time: the station of
## the current task lights up, the player walks there and taps the chip; the player character acts and speaks, a
## colleague / customer / pupil answers in their own voice. Then the player drives home (living room front door).
extends UniversalScene

const FURN := "res://props/furniture/"
var W: Dictionary
var cid := "home"
var C: Dictionary
var job := ""
var TRD := {}
var spots: Array = []            # [pos, focus] per setting station
var people: Array = []           # DemoCharacter per C.people
var stations: Array = []         # Interactable per task
var marker: MeshInstance3D
var step := -1
var walls: Array = []            # [MeshInstance3D, outward normal]
var room := Vector2(8.0, 7.0)
signal task_done
## v34 open world (blue): work / school as a world place (same rules as PlaceBase world mode): world_mode = true. The world's hud / player / cam are used; the room is built place-local at the node's transform with
## a real swinging door in the south wall; the routine starts when the player walks in (no scene change, no fade) and the
## drive home at the end is a WorldTrip (fade to black -> the house front door -> fade in, no card text).
signal place_entered(id: String)
signal place_exited(id: String)
@export var world_mode := false
@export var home_door := "house_front"   # WorldTrip door id for the drive home
var host: Node = null
var inside := false
var door_hinge: Node3D
var _started := false
const DOOR_GAP := 1.4
const DOOR_W := 1.0

## category for a job id (children always go to school as pupils)
static func category_of(job_id: String, child := false) -> String:
	if child: return "study"
	var w = App.load_json("res://data/work.json")
	if w is Dictionary:
		for k in w.categories:
			if job_id in w.categories[k].jobs: return k
	return "home"

static func car_label(job_id: String, child := false) -> String:
	var w = App.load_json("res://data/work.json")
	return String(w.categories[category_of(job_id, child)].label) if w is Dictionary else "Go to work"

func _ready() -> void:
	W = App.load_json("res://data/work.json")
	var st := CharacterHook.state()
	job = String(st.get("job", "")); cid = category_of(job, CharacterHook.is_child(st)); C = (W.categories[cid] as Dictionary).duplicate(true)
	for k in W.categories:
		var c: Dictionary = W.categories[k]
		TRD[c.label] = c.label_tr; TRD[c.end] = c.end_tr
		for t in c.tasks: TRD[t[0]] = t[1]; TRD[t[2]] = t[3]; if t[6] != "": TRD[t[6]] = t[7]
	for k in W.common: TRD[W.common[k][0]] = W.common[k][1]
	if world_mode: _world_init.call_deferred(); return   # v34: set world_mode before add_child (scenes/world/places/work_place.tscn does)
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	var outdoor: bool = C.setting == "garden"
	e.background_color = Color(0.62, 0.8, 0.95) if outdoor else Color(0.86, 0.89, 0.93)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1.0, 0.97, 0.93); e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 0.95; we.environment = e; add_child(we)
	# same light rig as the bedroom (main.gd _build_env), sun scaled by the shared clock
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.95, 0.85); sun.light_specular = 0.25; add_child(sun)
	sun.look_at_from_position(Vector3(1.5, 9, -9), Vector3(0, 0, 0)); sun.light_energy = 1.1 * maxf(WorldState.daylight(), 0.35)
	sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; sun.shadow_blur = 2.5; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2
	WorldState.ensure_loaded(); WorldState.scene = scene_file_path
	hud = (load("res://ui/shared/hud.tscn") as PackedScene).instantiate(); add_child(hud)
	player = WorldPlayer.new(); add_child(player); player.hud = hud; hud.player = player; player.floor_y = 0.0
	player.surface_func = func(_p: Vector3) -> String: return "grass" if outdoor else "pave"
	_room(outdoor)
	call("_set_" + String(C.setting))
	player.global_position = Vector3(0, 0, room.y / 2.0 - 0.9); player.face(PI)
	cam = (load("res://ui/shared/camera_rig.tscn") as PackedScene).instantiate(); add_child(cam)
	hud.camera = cam; player.attach_camera(cam, 9.0, 0.95); cam.max_dist = 12.0
	setup_universal(_place_en(), _place_tr())
	var base_tr: Callable = hud.tr_func
	hud.tr_func = func(en: String) -> String: return String(TRD[en]) if TRD.has(en) else String(base_tr.call(en))
	hud.set_tr(App.tr_saved())
	_people(); _stations()
	_run()

func _world_init() -> void:
	if host == null: host = get_tree().current_scene
	hud = host.get("hud"); player = host.get("player"); cam = host.get("cam"); room_phone = host.get("room_phone"); menu = host.get("menu")
	_room(C.setting == "garden")
	call("_set_" + String(C.setting))
	if hud and hud.get("tr_func") is Callable:
		var base_tr: Callable = hud.tr_func
		hud.tr_func = func(en: String) -> String: return String(TRD[en]) if TRD.has(en) else String(base_tr.call(en))
	_people(); _stations()
	add_to_group("places"); add_to_group("world_places")

func is_inside_place(world_pos: Vector3, margin := 0.0) -> bool:
	var l := to_local(world_pos)
	return absf(l.x) < room.x / 2.0 - margin and absf(l.z) < room.y / 2.0 - margin and l.y > -0.5 and l.y < 3.5

func _world_tick(dt: float) -> void:
	if player == null or not is_instance_valid(player): return
	var now_in := is_inside_place(player.global_position, 0.1)
	if now_in != inside:
		inside = now_in
		if inside:
			if hud and hud.has_method("set_place"): hud.set_place(_place_en(), _place_tr())
			place_entered.emit("work")
			if not _started and not bool((App.load_save().get("story", {}) as Dictionary).get("day2_work_done", false)):
				_started = true; _run()
		else: place_exited.emit("work")
	if door_hinge:
		var dl := to_local(player.global_position) - Vector3(0, 0, room.y / 2.0)
		var want := -1.75 if Vector2(dl.x, dl.z).length() < 2.2 else 0.0
		door_hinge.rotation.y = lerpf(door_hinge.rotation.y, want, 1.0 - exp(-dt * 5.0))

## world mode: one caption queue (the world's)
func caption(t: String, speak = true) -> void:
	if world_mode and host and host.has_method("caption"): await host.caption(t, speak); return
	await super.caption(t, speak)
func say_line(t: String) -> void:
	if world_mode and host and host.has_method("say_line"): await host.say_line(t); return
	await super.say_line(t)

func _place_en() -> String: return "School" if C.setting.begins_with("classroom") else ("Shop" if cid == "home" else "Work")
func _place_tr() -> String: return "Okul" if C.setting.begins_with("classroom") else ("Dükkan" if cid == "home" else "İş")

func tr_line(en: String) -> String: return String(hud.tr_of(en)) if hud else ""
func extra_tr(en: String) -> String: return String(TRD.get(en, ""))

# ------------------------------------------------------------------ flow
func _run() -> void:
	mode = "busy"
	Life.event("work")
	await get_tree().create_timer(0.8).timeout
	var intro: Array = W.common["intro_school"] if C.setting.begins_with("classroom") else (W.common["intro_shop"] if cid == "home" else W.common["intro_work"])
	await say_line(intro[0])
	var jd := _job_data()
	if cid not in ["home", "study"] and String(jd.get("start", "")) != "": await say_line(String(jd.start))
	mode = "play"
	for i in C.tasks.size():
		_activate(i)
		await task_done
	_activate(-1)
	mode = "busy"
	await say_line(C.end)
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv["day2_work_done"] = true; App.patch_save({"story": sv})
	Life.event("work_end")
	await say_line(ChildDrive.child_line(W.common["home"][0]))   # v33: a child says 'My mom is driving me home.'
	App.came_from = "outside"; StoryNav.travel(get_tree(), Game.HOUSE_FRONT_DOOR_SCENE, "front_door")

func _job_data() -> Dictionary:
	var d = App.load_json("res://data/jobs.json")
	if d is Dictionary:
		for j in d.get("jobs", []): if String(j.get("id", "")) == job: return j
	return {}

func _activate(i: int) -> void:
	step = i
	for k in stations.size(): (stations[k] as Interactable).enabled = k == i
	if i < 0:
		marker.visible = false; hud.set_mission("", ""); return
	var t: Array = C.tasks[i]
	hud.set_mission(t[0], t[1])
	marker.visible = true; marker.global_position = (stations[i] as Interactable).focus + Vector3(0, 1.0, 0)
	player.near = null

func _do_task(i: int) -> void:
	if i != step: return
	var t: Array = C.tasks[i]
	marker.visible = false; mode = "busy"; player.busy = true
	var npc: DemoCharacter = people[int(t[5])] if int(t[5]) >= 0 and int(t[5]) < people.size() else null
	if npc and not NpcTalk.is_seated(npc): _face(npc, player.global_position)   # v32-npc-pose: a seated person is not spun on the chair (NpcTalk turns the head)
	var anim := String(t[4])
	var pst := {}   # v32-npc-pose: player talk state (NpcTalk)
	if anim == "run": await _lap()
	elif anim == NpcTalk.TALK_CLIP:   # v32-npc-pose: the "talk" clip is SEATED; the player keeps the current clip, turns + nods only
		pst = NpcTalk.begin(player.hero, npc.global_position if npc else (stations[i] as Interactable).focus)
	else:
		player.hero.play(anim, 0.25)
		if anim in ["pick_up", "open_door"]: _sfx_for(anim)
	if cid == "nature" and t[0] == "Water the plants": Audio.sfx("water", -4.0)
	await say_line(t[2])
	if not pst.is_empty(): NpcTalk.end(player.hero, pst)   # v32-npc-pose: pose untouched
	elif anim not in ["typing", "crouch_idle", "sit_idle", "phone_call"]: player.hero.play("idle", 0.3)
	if npc and t[6] != "":
		await _npc_line(npc, t[6])
	player.hero.play("idle", 0.3)
	UI.click()
	player.busy = false; mode = "play"
	task_done.emit()

func _sfx_for(anim: String) -> void:
	if anim == "open_door": Audio.sfx("doorOpen_1", -4.0)
	else: Audio.sfx("metalClick", -6.0)

## a colleague / customer / pupil answers in their own Piper voice (same queue as the narrator: nothing is cut)
const WallFade := preload("res://scripts/props/wall_fade.gd")   # v33: universal wall-occlusion fade
const NpcTalk := preload("res://scripts/core/npc_talk.gd")   # v32-npc-pose: shared talk routine (keeps the pose)
func _npc_line(npc: DemoCharacter, en: String) -> void:
	await voice_idle(0.1)
	var st: Dictionary = NpcTalk.begin(npc, player.global_position)   # v32-npc-pose: was npc.play("talk") = a SEATED clip; now turn + nod only (meta "scripted_pose" opts in)
	_mute_next = true; hud.caption(en, maxf(4.5, Voice.clip_len("v_%s %s" % [npc.get_meta("voice"), Audio.norm(en)]) + 1.0)); _mute_next = false
	if S.get("voice", true):
		Audio.say_as(en, String(npc.get_meta("voice")))
		await get_tree().create_timer(0.2).timeout
		await voice_idle(0.2)
	else: await get_tree().create_timer(2.0).timeout
	NpcTalk.end(npc, st)   # v32-npc-pose: pose untouched (only a scripted_pose is undone)
	if room_phone: room_phone.S.tr = hud.show_tr

func _face(who: Node3D, at: Vector3) -> void:
	var y := atan2(at.x - who.global_position.x, at.z - who.global_position.z)
	create_tween().tween_property(who, "rotation:y", who.rotation.y + wrapf(y - who.rotation.y, -PI, PI), 0.4)

## sports: one easy lap of the room (run animation along a rectangle)
func _lap() -> void:
	player.hero.play("run", 0.2)
	var pts := [Vector3(-2.6, 0, 1.6), Vector3(-2.6, 0, -1.6), Vector3(2.6, 0, -1.6), Vector3(2.6, 0, 1.6), Vector3(2.0, 0, 1.0)]
	for lpt in pts:
		var p: Vector3 = to_global(lpt)   # v34: place-local lap
		var d: Vector3 = p - player.global_position
		player.hero.rotation.y = atan2(d.x, d.z)
		var tw := create_tween(); tw.tween_property(player, "global_position", p, d.length() / 3.6); await tw.finished
	player.hero.play("idle", 0.3)

# ------------------------------------------------------------------ people + stations
func _people() -> void:
	for p in C.people:
		var ch := DemoCharacter.new(); add_child(ch); ch.setup(String(p[0]))
		if p[1]: ch.set_child(true)
		else: ch.set_height("medium")
		ch.skin = randi() % 4; ch.top_color = [Color(0.3, 0.5, 0.8), Color(0.8, 0.45, 0.35), Color(0.4, 0.65, 0.45), Color(0.9, 0.8, 0.4)][randi() % 4]
		if cid == "health" and people.is_empty(): pass
		ch._refresh()
		ch.position = Vector3(p[3], 0.0, p[4]); ch.set_meta("voice", p[2]); ch.set_meta("pose", p[5])
		ch.rotation.y = atan2(-p[3], -p[4] + 0.001) if p[5] != "sit_idle" else (PI if p[4] > -0.5 else 0.0)
		if p[5] == "sit_idle" and C.setting == "clinic": ch.rotation.y = -PI / 2   # patient on the bed edge, facing the doctor
		if String(p[5]) == "sit_idle": ch.position.y = 0.0
		ch.play(String(p[5]), 0.0); people.append(ch)
		var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.3; sh.height = 1.6
		cs.shape = sh; cs.position = Vector3(p[3], 0.8, p[4]); col.add_child(cs); add_child(col)
	if cid == "health" and job in ["doctor", "nurse", "dentist", "vet", "paramedic", "pharmacist"] and ResourceLoader.exists("res://scripts/story/doctor_coat.gd"):
		load("res://scripts/story/doctor_coat.gd").dress(player.hero)

func _stations() -> void:
	for i in C.tasks.size():
		var t: Array = C.tasks[i]
		var pos: Vector3; var focus: Vector3
		var ni := int(t[5])
		if ni >= 0 and ni < people.size() and int(t[8]) == 0:
			var np: Vector3 = people[ni].position
			var to := (Vector3(0, 0, room.y / 2.0) - np); to.y = 0; to = to.normalized()
			pos = np + to * 1.0; focus = np + Vector3(0, 1.1, 0)
		else:
			var sp: Array = spots[clampi(int(t[8]), 0, spots.size() - 1)]
			pos = sp[0]; focus = sp[1]
		var it := Interactable.new(); it.obj_name = String(t[0]); it.radius = 1.6; it.position = pos; add_child(it)
		it.focus = to_global(focus) if world_mode else focus; it.enabled = false   # focus = world point
		var idx: int = i
		it.verbs = func() -> Array: return [[String(C.tasks[idx][0]), func(): await _do_task(idx)]]
		stations.append(it)
	marker = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.14; cm.height = 0.28
	marker.mesh = cm; marker.rotation_degrees.x = 180
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(1.0, 0.8, 0.2); mm.emission_enabled = true; mm.emission = Color(1.0, 0.75, 0.1); mm.emission_energy_multiplier = 0.8
	mm.no_depth_test = true; mm.render_priority = 5; marker.material_override = mm; marker.visible = false; add_child(marker)

var _mt := 0.0
func _process(dt: float) -> void:
	_mt += dt
	if world_mode:
		if marker == null: return
		_world_tick(dt)
		if not inside:   # from the street: a wall fades only while it hides the player
			var vc := get_viewport().get_camera_3d()
			for w in walls: WallFade.step_occl(w[0], WallFade.OCC_MIN_A if vc and WallFade.occluded(w[0], vc.global_position, player.global_position) else 1.0, dt)
			return
	if marker and marker.visible and step >= 0: marker.global_position.y = (stations[step] as Interactable).focus.y + 0.95 + sin(_mt * 3.0) * 0.08
	# cut-away walls: hide a wall while the camera is on its outer side
	# v33 rule: walls fade gradually (out when the camera is outside them, to ~0.2 while they hide the player), never pop
	var c := get_viewport().get_camera_3d()
	if cam and c:
		var occ := {}
		if player != null:
			for w in walls: if (w[1] as Vector3).z <= 0.5 and not occ.get(w[1], false): occ[w[1]] = WallFade.occluded(w[0], c.global_position, player.global_position)
		for w in walls:
			var m: MeshInstance3D = w[0]; var n: Vector3 = w[1]
			var out: bool = (cam.global_position - m.global_position).dot(global_basis * n) >= 0.3
			WallFade.step_occl(m, 0.0 if out else (WallFade.OCC_MIN_A if occ.get(n, false) else 1.0), dt)

# ------------------------------------------------------------------ building helpers
func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.85; return m

func box(s: Vector3, p: Vector3, c: Color, solid := true, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.material_override = _mat(c)
	mi.position = p; mi.rotation.y = yaw; add_child(mi)
	if solid: _collider(s, p, yaw)
	return mi

func cyl(r: float, h: float, p: Vector3, c: Color, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; mi.mesh = cm
	mi.material_override = _mat(c); mi.position = p; add_child(mi)
	if solid: _collider(Vector3(r * 2, h, r * 2), p)
	return mi

func _collider(s: Vector3, p: Vector3, yaw := 0.0) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = s; cs.shape = sh
	sb.position = p; sb.rotation.y = yaw; sb.add_child(cs); add_child(sb)

## v31: office / school plants are waterable too (same watering can + lines as the house plants)
func _wplant(n: Node3D) -> Node3D:
	var it := Interactable.new(); it.obj_name = "plant"; it.radius = 1.4; add_child(it)
	var p := n.position; var d := Vector3(-p.x, 0, -p.z).normalized()
	it.position = Vector3(p.x, 0, p.z) + d * 0.7; it.focus = p + Vector3(0, 0.6, 0)
	var st := {"dry": true}
	it.verbs = func() -> Array:
		if not st.dry or mode != "play": return []
		return [["Water the plant", func():
			mode = "busy"; player.busy = true; st.dry = false
			player.hero.hold_item("res://props/watering_can.tscn", "cylinder", 0.26, false)
			player.hero.play("pick_up", 0.3); Audio.sfx("water_drops", -6.0)
			await say_line("I am watering the plant.")
			player.hero.play("idle", 0.3); player.hero.release_item()
			await say_line("The plant is happy now.")
			player.busy = false; mode = "play"]]
	return n

func prop(file: String, pos: Vector3, yaw_deg: float, height := 0.0, length := 0.0, solid := true) -> Node3D:
	var pivot := Node3D.new(); add_child(pivot)
	var inst: Node3D = (load(FURN + file + ".glb") as PackedScene).instantiate(); pivot.add_child(inst)
	var ab := _aabb(inst); var s := 1.0
	if height > 0.0: s = height / maxf(ab.size.y, 0.001)
	elif length > 0.0: s = length / maxf(maxf(ab.size.x, ab.size.z), 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3((ab.position.x + ab.size.x * 0.5) * s, ab.position.y * s, (ab.position.z + ab.size.z * 0.5) * s)
	pivot.position = pos; pivot.rotation.y = deg_to_rad(yaw_deg)
	if solid:
		var sz := ab.size * s; if absf(fmod(yaw_deg, 180.0)) > 45.0: sz = Vector3(sz.z, sz.y, sz.x)
		if pos.y < 0.3: _collider(Vector3(sz.x, maxf(sz.y, 0.5), sz.z), pos + Vector3(0, sz.y / 2.0, 0))
	return pivot

func _aabb(n: Node3D) -> AABB:
	var out := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY; var c: Node = m
		while c and c != n:
			if c is Node3D: t = (c as Node3D).transform * t
			c = c.get_parent()
		var b: AABB = t * (m as MeshInstance3D).get_aabb()
		if first: out = b; first = false
		else: out = out.merge(b)
	return out

func _room(outdoor: bool) -> void:
	var hx := room.x / 2.0; var hz := room.y / 2.0
	var FL := {"classroom": Color(0.74, 0.58, 0.42), "classroom_student": Color(0.74, 0.58, 0.42), "clinic": Color(0.72, 0.80, 0.84), "kitchen": Color(0.62, 0.62, 0.66),
		"shop": Color(0.80, 0.72, 0.58), "office": Color(0.55, 0.60, 0.68), "workshop": Color(0.56, 0.54, 0.50), "station": Color(0.50, 0.52, 0.55),
		"stage": Color(0.42, 0.30, 0.24), "gym": Color(0.80, 0.55, 0.35), "salon": Color(0.85, 0.80, 0.78)}
	var AC := {"classroom": Color(0.95, 0.85, 0.55), "classroom_student": Color(0.95, 0.85, 0.55), "clinic": Color(0.62, 0.78, 0.80), "kitchen": Color(0.95, 0.75, 0.55),
		"shop": Color(0.70, 0.82, 0.62), "office": Color(0.62, 0.70, 0.85), "workshop": Color(0.80, 0.70, 0.55), "station": Color(0.75, 0.75, 0.70),
		"stage": Color(0.25, 0.22, 0.30), "gym": Color(0.60, 0.80, 0.90), "salon": Color(0.92, 0.70, 0.75)}
	var floor_c: Color = Color(0.45, 0.66, 0.38) if outdoor else (FL.get(C.setting, Color(0.8, 0.66, 0.5)) as Color).darkened(0.15)
	box(Vector3(room.x, 0.1, room.y), Vector3(0, -0.05, 0), floor_c, false)
	for i in range(1, int(room.y / 0.5)): box(Vector3(room.x, 0.004, 0.012), Vector3(0, 0.002, -hz + i * 0.5), floor_c.darkened(0.12), false)
	if not world_mode: box(Vector3(40, 0.1, 40), Vector3(0, -0.16, 0), Color(0.42, 0.62, 0.36) if outdoor else Color(0.80, 0.84, 0.88), false)
	_collider(Vector3(room.x, 0.1, room.y), Vector3(0, -0.05, 0))
	var wc := Color(0.93, 0.91, 0.86)
	var h := 0.9 if outdoor else 2.8
	if outdoor: wc = Color(0.62, 0.45, 0.3)   # low wooden fence
	var sides := [[Vector3(room.x, h, 0.12), Vector3(0, h / 2, -hz), Vector3(0, 0, -1)], [Vector3(room.x, h, 0.12), Vector3(0, h / 2, hz), Vector3(0, 0, 1)],
			[Vector3(0.12, h, room.y), Vector3(-hx, h / 2, 0), Vector3(-1, 0, 0)], [Vector3(0.12, h, room.y), Vector3(hx, h / 2, 0), Vector3(1, 0, 0)]]
	if world_mode:   # v34: the south wall gets a real opening (two parts + lintel) and a hinged door
		sides.remove_at(1)
		var sw := (room.x - DOOR_GAP) / 2.0
		for sx in [-1.0, 1.0]: walls.append([box(Vector3(sw, h, 0.12), Vector3(sx * (DOOR_GAP / 2.0 + sw / 2.0), h / 2, hz), wc), Vector3(0, 0, 1)])
		if not outdoor:
			walls.append([box(Vector3(DOOR_GAP, h - 2.2, 0.12), Vector3(0, 2.2 + (h - 2.2) / 2.0, hz), wc, false), Vector3(0, 0, 1)])
			door_hinge = Node3D.new(); door_hinge.name = "FrontDoor"; door_hinge.position = Vector3(-DOOR_W / 2.0, 0, hz + 0.02); add_child(door_hinge)
			door_hinge.add_to_group("doors")
			var dmi := MeshInstance3D.new(); var dbm := BoxMesh.new(); dbm.size = Vector3(DOOR_W, 2.1, 0.06); dmi.mesh = dbm
			dmi.material_override = _mat(Color(0.55, 0.38, 0.25)); dmi.position = Vector3(DOOR_W / 2.0, 1.05, 0); door_hinge.add_child(dmi)
	for d in sides:
		var m := box(d[0], d[1], wc); walls.append([m, d[2]])
		if not outdoor:   # accent paint on the inner side
			var n: Vector3 = d[2]; var sz: Vector3 = d[0]
			var a := box(Vector3(maxf(sz.x - 0.02, 0.01) if n.z != 0 else 0.01, h - 0.02, maxf(sz.z - 0.02, 0.01) if n.x != 0 else 0.01), d[1] - n * 0.065, AC.get(C.setting, wc), false)
			a.mesh.size = Vector3(0.01, h * 0.45, sz.z - 0.02) if n.x != 0 else Vector3(sz.x - 0.02, h * 0.45, 0.01); a.position.y = h * 0.225
			walls.append([a, n])
	# entrance door on the front wall (decor; the player came in here)
	if not outdoor and not world_mode:
		var dm := box(Vector3(1.0, 2.1, 0.06), Vector3(0, 1.05, hz - 0.08), Color(0.55, 0.38, 0.25), false); walls.append([dm, Vector3(0, 0, 1)])

# ------------------------------------------------------------------ settings (spots: [stand position, focus point])
func _set_classroom() -> void:
	box(Vector3(3.2, 1.2, 0.05), Vector3(0, 1.55, -3.42), Color(0.16, 0.3, 0.22), false)
	box(Vector3(3.4, 0.08, 0.12), Vector3(0, 0.92, -3.38), Color(0.6, 0.5, 0.4), false)
	prop("desk", Vector3(-1.9, 0, -2.4), 0, 0.76)
	for x in [-1.0, 0.0, 1.0]:
		box(Vector3(0.8, 0.06, 0.5), Vector3(x, 0.62, 0.05), Color(0.72, 0.56, 0.38), false); box(Vector3(0.7, 0.6, 0.06), Vector3(x, 0.3, -0.18), Color(0.55, 0.42, 0.3))
		box(Vector3(0.42, 0.04, 0.42), Vector3(x, 0.42, 0.62), Color(0.3, 0.45, 0.7), false)
	prop("bookcaseOpen", Vector3(3.3, 0, -1.5), -90, 1.8)
	spots = [[Vector3(0, 0, -1.5), Vector3(0, 1.0, 0.6)], [Vector3(-0.6, 0, -2.75), Vector3(-0.6, 1.5, -3.5)], [Vector3(1.0, 0, -0.75), Vector3(1.0, 0.7, 0.05)]]

func _set_classroom_student() -> void:
	_set_classroom()
	box(Vector3(0.42, 0.04, 0.42), Vector3(1.0, 0.42, 0.62), Color(0.85, 0.5, 0.3), false)
	spots = [[Vector3(1.0, 0, 1.3), Vector3(1.0, 0.7, 0.05)]]

func _set_clinic() -> void:
	prop("bedSingle", Vector3(1.6, 0, 0.2), -90, 0.0, 2.0)
	prop("desk", Vector3(-1.8, 0, -2.75), 0, 0.76); prop("laptop", Vector3(-1.8, 0.76, -2.75), 0, 0.0, 0.36, false); prop("chairDesk", Vector3(-1.8, 0, -2.1), 180, 1.0)
	box(Vector3(1.2, 0.9, 0.5), Vector3(3.6, 0.45, -2.6), Color(0.95, 0.95, 0.97))
	box(Vector3(0.5, 0.5, 0.04), Vector3(-1.0, 1.7, -3.43), Color(0.85, 0.2, 0.2), false); box(Vector3(0.16, 0.36, 0.05), Vector3(-1.0, 1.7, -3.41), Color.WHITE, false); box(Vector3(0.36, 0.16, 0.05), Vector3(-1.0, 1.7, -3.41), Color.WHITE, false)
	_wplant(prop("pottedPlant", Vector3(-3.4, 0, 2.6), 0, 1.0))
	spots = [[Vector3(0.1, 0, 0.2), Vector3(0.9, 1.0, 0.2)], [Vector3(-1.8, 0, -1.55), Vector3(-1.8, 0.85, -2.75)]]
	# patient sits on the bed edge, facing the room
	C.people[0][3] = 0.95; C.people[0][4] = 0.2

func _set_kitchen() -> void:
	box(Vector3(5.6, 0.92, 0.65), Vector3(-0.6, 0.46, -3.05), Color(0.82, 0.82, 0.84))
	box(Vector3(0.7, 0.04, 0.5), Vector3(-1.6, 0.94, -3.05), Color(0.15, 0.15, 0.15), false)
	box(Vector3(0.4, 0.45, 0.4), Vector3(1.0, 1.15, -3.1), Color(0.25, 0.25, 0.28), false)   # coffee machine
	box(Vector3(2.8, 1.0, 0.6), Vector3(1.4, 0.5, 0.25), Color(0.6, 0.42, 0.3))              # serving counter
	cyl(0.07, 0.12, Vector3(1.0, 1.06, 0.25), Color(1, 1, 1), false)
	for x in [-2.6, -1.2]: box(Vector3(0.7, 0.04, 0.7), Vector3(x, 0.74, 1.6), Color(0.7, 0.55, 0.4), false); _collider(Vector3(0.7, 0.75, 0.7), Vector3(x, 0.37, 1.6))
	spots = [[Vector3(1.4, 0, -0.4), Vector3(1.4, 1.2, 1.0)], [Vector3(-1.6, 0, -2.4), Vector3(-1.6, 0.95, -3.05)], [Vector3(1.0, 0, -2.4), Vector3(1.0, 1.1, -3.1)]]
	C.people[0][3] = 1.4; C.people[0][4] = 1.0

func _set_shop() -> void:
	for x in [-2.6, -0.9, 0.8]: prop("bookcaseOpen", Vector3(x, 0, -3.15), 0, 1.8)
	for x in [-2.6, -0.9, 0.8]:
		for y in [0.45, 0.95, 1.4]:
			for j in 4: box(Vector3(0.14, 0.2, 0.14), Vector3(x - 0.45 + j * 0.3, y + 0.1, -3.1), Color.from_hsv(fmod(x * 0.13 + y * 0.31 + j * 0.17 + 5.0, 1.0), 0.6, 0.85), false)
	box(Vector3(1.6, 1.0, 0.6), Vector3(1.8, 0.5, 0.0), Color(0.5, 0.35, 0.25)); box(Vector3(0.35, 0.25, 0.3), Vector3(1.5, 1.12, 0.0), Color(0.2, 0.2, 0.22), false)
	box(Vector3(0.06, 2.1, 1.0), Vector3(-3.92, 1.05, 1.5), Color(0.55, 0.38, 0.25), false)
	spots = [[Vector3(1.8, 0, -0.65), Vector3(1.8, 1.2, 0.9)], [Vector3(-0.9, 0, -2.45), Vector3(-0.9, 1.1, -3.15)], [Vector3(-3.25, 0, 1.5), Vector3(-3.9, 1.0, 1.5)]]
	C.people[0][3] = 1.8; C.people[0][4] = 0.9

func _set_office() -> void:
	for x in [-1.2, 1.4]:
		prop("desk", Vector3(x, 0, -2.75), 0, 0.76); prop("laptop", Vector3(x, 0.76, -2.75), 0, 0.0, 0.36, false); prop("chairDesk", Vector3(x, 0, -2.1), 180, 1.0, 0.0, false)
	box(Vector3(2.0, 0.05, 1.0), Vector3(0.6, 0.74, 1.2), Color(0.85, 0.85, 0.82), false); _collider(Vector3(2.0, 0.75, 1.0), Vector3(0.6, 0.37, 1.2))
	prop("bookcaseClosedWide", Vector3(-3.3, 0, -0.5), 90, 1.9); _wplant(prop("pottedPlant", Vector3(3.4, 0, -3.0), 0, 1.1))
	spots = [[Vector3(-1.2, 0, -1.55), Vector3(-1.2, 0.85, -2.75)], [Vector3(-1.2, 0, -1.55), Vector3(-1.2, 0.85, -2.75)]]
	C.people[0][3] = 1.3; C.people[0][4] = 0.45

func _set_workshop() -> void:
	box(Vector3(2.6, 0.9, 0.8), Vector3(-1.8, 0.45, -2.9), Color(0.55, 0.4, 0.28))
	for i in 5: box(Vector3(0.06, 0.4, 0.06), Vector3(-2.8 + i * 0.45, 1.6, -3.4), Color(0.3, 0.3, 0.32), false)
	box(Vector3(2.6, 0.05, 0.3), Vector3(-1.8, 1.35, -3.3), Color(0.5, 0.35, 0.25), false)
	box(Vector3(1.0, 2.1, 0.08), Vector3(2.0, 1.05, -2.2), Color(0.62, 0.45, 0.3), true, 0.3)       # the broken door (on a stand)
	box(Vector3(0.6, 0.6, 0.6), Vector3(3.2, 0.3, 1.8), Color(0.75, 0.55, 0.3)); box(Vector3(0.5, 0.5, 0.5), Vector3(3.1, 0.85, 1.8), Color(0.7, 0.5, 0.28))
	spots = [[Vector3(0, 0, 0), Vector3(1.3, 1, 0.6)], [Vector3(-1.8, 0, -2.1), Vector3(-1.8, 1.0, -2.9)], [Vector3(1.75, 0, -1.4), Vector3(2.0, 0.5, -2.2)]]

func _set_station() -> void:
	box(Vector3(1.9, 1.7, 3.6), Vector3(-1.9, 0.95, -1.1), Color(0.9, 0.75, 0.2) if cid == "transport" else Color(0.2, 0.3, 0.6))
	for z in [-2.4, 0.2]: cyl(0.32, 0.25, Vector3(-0.92, 0.32, z), Color(0.12, 0.12, 0.12), false)
	box(Vector3(0.05, 0.6, 1.6), Vector3(-0.93, 1.35, -1.6), Color(0.6, 0.8, 0.95), false)
	box(Vector3(1.2, 0.05, 0.4), Vector3(2.4, 0.45, -3.0), Color(0.5, 0.35, 0.25), false); _collider(Vector3(1.2, 0.45, 0.4), Vector3(2.4, 0.22, -3.0))
	box(Vector3(0.9, 1.2, 0.4), Vector3(3.3, 0.6, 0.5), Color(0.6, 0.6, 0.65))
	spots = [[Vector3(0, 0, 0), Vector3(1.2, 1, 0.8)], [Vector3(-0.4, 0, 1.2), Vector3(-1.9, 0.7, 0.7)], [Vector3(-0.35, 0, -1.6), Vector3(-1.5, 1.3, -1.6)]]

func _set_stage() -> void:
	box(Vector3(5.0, 0.4, 2.4), Vector3(0, 0.2, -2.2), Color(0.35, 0.2, 0.15), false); _collider(Vector3(5.0, 0.4, 2.4), Vector3(0, 0.2, -2.2))
	box(Vector3(5.0, 2.4, 0.05), Vector3(0, 1.6, -3.4), Color(0.6, 0.1, 0.12), false)
	for x in [-1.5, 1.5]:
		var l := SpotLight3D.new(); l.position = Vector3(x, 3.0, 0.5); l.look_at_from_position(l.position, Vector3(0, 0.4, -2.0)); l.light_energy = 3.0; l.spot_angle = 30.0; add_child(l)
		l.add_to_group("ow_no_ceiling")   # Yasin 00:12: no bright centre / ceiling light in any room (World hides them every frame)
	for x in [-2.0, -1.0, 1.0, 2.0]: prop("loungeChair", Vector3(x, 0, 2.6), 180, 0.8)
	spots = [[Vector3(0, 0, 0.6), Vector3(0, 1, 1.6)], [Vector3(-2.8, 0, -0.4), Vector3(-3.5, 1.0, -0.4)], [Vector3(0, 0, -2.2), Vector3(0, 1.2, 1.5)]]

func _set_gym() -> void:
	for i in 3: box(Vector3(1.0, 0.04, 2.0), Vector3(-2.4 + i * 1.3, 0.02, -2.2), Color(0.25, 0.45, 0.75), false)
	box(Vector3(7.0, 0.01, 0.06), Vector3(0, 0.01, 2.1), Color(1, 1, 1), false); box(Vector3(7.0, 0.01, 0.06), Vector3(0, 0.01, -1.0), Color(1, 1, 1), false)
	box(Vector3(0.6, 1.0, 0.4), Vector3(3.4, 0.5, -2.8), Color(0.4, 0.4, 0.45)); cyl(0.12, 0.3, Vector3(3.4, 1.15, -2.8), Color(0.3, 0.6, 0.95), false)
	spots = [[Vector3(0, 0, 0), Vector3(1.3, 1, 0.6)], [Vector3(-1.1, 0, -2.2), Vector3(-1.1, 1.0, 0.0)], [Vector3(2.0, 0, 1.0), Vector3(2.0, 1.0, 0.0)]]

func _set_garden() -> void:
	for i in 6: _wplant(prop("pottedPlant", Vector3(-3.0 + i * 0.55, 0, -2.6), i * 30.0, 0.9))
	for i in 4: box(Vector3(1.6, 0.25, 0.7), Vector3(-2.2 + i * 0.0, 0.12, -1.4), Color(0.4, 0.28, 0.18), false)
	box(Vector3(1.6, 0.25, 0.7), Vector3(-2.2, 0.12, -1.4), Color(0.4, 0.28, 0.18))
	if ResourceLoader.exists("res://props/story/animal-cat.glb"):
		for p in [Vector3(2.4, 0, -2.2), Vector3(3.0, 0, -1.6)]:
			var a: Node3D = (load("res://props/story/animal-cat.glb") as PackedScene).instantiate(); add_child(a); a.position = p; a.scale = Vector3.ONE * 0.6; a.rotation.y = randf() * TAU
	box(Vector3(0.5, 0.25, 0.4), Vector3(2.0, 0.12, -1.0), Color(0.6, 0.6, 0.62))
	spots = [[Vector3(0, 0, 0), Vector3(1.3, 1, 0.8)], [Vector3(-2.2, 0, -0.7), Vector3(-2.2, 0.4, -1.6)], [Vector3(2.0, 0, -0.4), Vector3(2.5, 0.3, -1.8)]]

func _set_salon() -> void:
	box(Vector3(1.2, 1.0, 0.04), Vector3(0, 1.45, -3.42), Color(0.75, 0.85, 0.92), false); box(Vector3(1.3, 1.1, 0.03), Vector3(0, 1.45, -3.44), Color(0.3, 0.3, 0.32), false)
	box(Vector3(2.0, 0.85, 0.5), Vector3(0, 0.42, -3.1), Color(0.9, 0.9, 0.92))
	box(Vector3(0.55, 0.45, 0.55), Vector3(0, 0.22, -0.4), Color(0.2, 0.2, 0.22)); box(Vector3(0.55, 0.6, 0.1), Vector3(0, 0.75, -0.65), Color(0.2, 0.2, 0.22), false)
	box(Vector3(0.9, 0.85, 0.5), Vector3(-2.6, 0.42, -3.1), Color(0.95, 0.95, 0.97)); cyl(0.2, 0.08, Vector3(-2.6, 0.88, -3.1), Color(0.8, 0.85, 0.9), false)
	_wplant(prop("pottedPlant", Vector3(3.3, 0, -3.0), 0, 1.1))
	spots = [[Vector3(0, 0, 0.6), Vector3(0, 1.1, -0.4)], [Vector3(-0.55, 0, -0.1), Vector3(0, 1.15, -0.4)]]
	C.people[0][3] = 0.0; C.people[0][4] = -0.4
