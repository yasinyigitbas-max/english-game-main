## v31 places: shared base for the CAFE and SHOP interiors (scripts/places/cafe.gd, shop.gd).
## A walkable UniversalScene (shared HUD, phone, pause menu, TR toggle, queued captions, Objectives top-left) like work.gd.
## Content: data/cafe_shop.json (lessons + 3-version tests for phone.gd, scripted beats, NPC chats, TR).
## Rules: every objective goes through Life.guide_to (camera pan + notify sound + Objectives); each scripted beat plays once
## (save.json "places".<id>.<beat>); EN by default, TR text only with the TR toggle (no TR voice); captions go through the
## shared caption queue (UniversalScene.caption) and the v30.5 no-overlap layer (Objectives.resolve_overlaps).
## Entry: StoryNav.goto("res://scenes/places/cafe.tscn") / shop.tscn. Exit: the door -> StoryNav.goto(Game.WORLD_SCENE, "<id>_door").
class_name PlaceBase
extends UniversalScene

const DATA := "res://data/cafe_shop.json"
const WallFade := preload("res://scripts/places/wall_fade_adapter.gd")
const FOOD := "res://props/places/food/"
const PF := "res://props/places/furn/"
var place_id := "cafe"
var world_lot := "cafe"   # Lot.lot_id of this building in scenes/blocks/block_shops.tscn ("cafe" / "corner_shop"); exit returns to "lot:<world_lot>"
var D: Dictionary = {}
var TRD: Dictionary = {}
var room := Vector2(10.0, 8.0)
var walls: Array = []
var npcs: Dictionary = {}          # id -> DemoCharacter
var its: Dictionary = {}           # id -> Interactable
var marker: MeshInstance3D
var _mark_target: Node3D
var _cine_cam: Camera3D
var _cine_tw: Tween
var _hud_vis := {}

## hide joysticks / buttons during cinematics (captions stay), like red's story_accident
func _hud_hide(on: bool) -> void:
	if hud == null or not is_instance_valid(hud) or hud.get("root") == null: return
	if on:
		_hud_vis.clear()
		for c in hud.root.get_children():
			if c == hud.get("cap_panel"): continue
			_hud_vis[c] = c.visible; c.visible = false; c.modulate.a = 0.0
	else:
		for c in _hud_vis:
			if is_instance_valid(c): c.visible = _hud_vis[c]; c.modulate.a = 1.0
		_hud_vis.clear()
var _t := 0.0
var exit_spawn := ""
signal used(id: String)
## hooks for other code (e.g. day-3 town cues). Both carry place_id ("cafe" / "shop"). The place scene is in group "places".
## place_entered: the interior is built and the player stands at the door (end of _ready, before the scripted flow).
## place_exited: the player is leaving through the door (in leave(), right before StoryNav.goto(WORLD_SCENE, "lot:<world_lot>")).
## After the switch the world sees App.came_from == place_id and Game.spawn == "lot:<world_lot>".
signal place_entered(place_id: String)
signal place_exited(place_id: String)

# ------------------------------------------------------------------ setup
func _ready() -> void:
	D = App.load_json(DATA)
	TRD = D.get("tr", {})
	WorldState.ensure_loaded(); WorldState.scene = scene_file_path
	_env()
	hud = (load("res://ui/shared/hud.tscn") as PackedScene).instantiate(); add_child(hud)
	player = WorldPlayer.new(); add_child(player); player.hud = hud; hud.player = player; player.floor_y = 0.0
	player.surface_func = func(_p: Vector3) -> String: return "pave"
	build()   # sets room (shop: 14 x 10) before the shell is built
	_room()   # blue fix: _room() ran BEFORE build(), so the walls / floor always used the default 10 x 8 room and the shop's crates / bakery poked through the walls
	player.global_position = Vector3(0, 0, room.y / 2.0 - 0.9); player.face(PI)
	cam = (load("res://ui/shared/camera_rig.tscn") as PackedScene).instantiate(); add_child(cam)
	hud.camera = cam; player.attach_camera(cam, 8.0, 0.9); cam.max_dist = 11.0
	Objectives.set_list(Objectives.items.filter(func(it): return it is Dictionary and String(it.get("id", "")) == "charge"))   # v31: no stale outdoor objective inside (v31 QA: keep Life's "Charge my phone.")
	setup_universal(place_en(), place_tr())
	var base_tr: Callable = hud.tr_func
	hud.tr_func = func(en: String) -> String: return String(TRD[en]) if TRD.has(en) else String(base_tr.call(en))
	hud.set_tr(App.tr_saved())
	_marker()
	add_to_group("places")
	place_entered.emit.call_deferred(place_id)   # deferred: listeners connected from node_added / the group still get it
	if not "--qa-place" in OS.get_cmdline_user_args(): _start.call_deferred()

func _start() -> void: await run()

func place_en() -> String: return "Cafe"
func place_tr() -> String: return "Kafe"
func build() -> void: pass          # override: furniture, props, NPCs, interactables
func run() -> void: pass            # override: the scripted flow

func tr_line(en: String) -> String: return String(TRD.get(en, ""))
func extra_tr(en: String) -> String: return String(TRD.get(en, ""))

func _env() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.89, 0.93)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1.0, 0.95, 0.88); e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_exposure = 0.88; we.environment = e; add_child(we)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.94, 0.84); sun.light_specular = 0.2; add_child(sun)
	sun.look_at_from_position(Vector3(3, 9, 6), Vector3.ZERO); sun.light_energy = 0.75
	sun.directional_shadow_max_distance = 30.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; sun.shadow_blur = 2.0; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2

# ------------------------------------------------------------------ state (each beat once)
func done(beat: String) -> bool:
	var p = App.load_save().get("places", {})
	return p is Dictionary and p.get(place_id, {}) is Dictionary and bool(p.get(place_id, {}).get(beat, false))

func mark(beat: String) -> void:
	var p = App.load_save().get("places", {}); p = p.duplicate(true) if p is Dictionary else {}
	var q = p.get(place_id, {}); q = q if q is Dictionary else {}
	q[beat] = true; p[place_id] = q; App.patch_save({"places": p})

func save_score(key: String, v) -> void:
	var p = App.load_save().get("places", {}); p = p.duplicate(true) if p is Dictionary else {}
	var q = p.get(place_id, {}); q = q if q is Dictionary else {}
	q[key] = v; p[place_id] = q; App.patch_save({"places": p})

# ------------------------------------------------------------------ guide / objectives / lines
func guide(target, en: String) -> void:
	await Life.guide_to(target, en, {"tr": tr_line(en)})

func beat(name: String) -> void:   # plays data beats[place][name]: [speaker, line, tr]
	for b in D.beats[place_id].get(name, []): await speak(String(b[0]), String(b[1]))

func speak(who: String, en: String) -> void:
	if who == "me" or not npcs.has(who): await say_line(en); return
	await npc_line(npcs[who], en)

## NPC line in the NPC's own Piper voice, on the same queue as the narrator (nothing is cut); caption with TR toggle
func npc_line(npc: DemoCharacter, en: String) -> void:
	# v32 rule: ONE bottom-centre caption box (the shared HUD caption, TR button inside). Wait for queued narrator lines so
	# an NPC line never replaces one that is still pending
	while _serving != _ticket and is_inside_tree(): await get_tree().process_frame
	await voice_idle(0.1)
	# v32 universal rule (Yasin): talking never changes the pose. The library "talk" clip is SEATED (standing NPCs sat down
	# for the line and stood up again). Red's shared routine scripts/core/npc_talk.gd (turn + head nod, no clip change) is
	# used when it is in the project; otherwise the NPC only turns to the player and nods.
	var nt = _npc_talk()
	var talk_st = nt.begin(npc, player.global_position) if nt != null else null
	if nt == null:
		if not String(npc.get_meta("pose", "idle")).begins_with("sit"): face(npc, player.global_position)   # a seated body never spins off its chair
		nod(npc, 2.0)
	_mute_next = true; hud.caption(en, read_secs(en, Voice.clip_len("v_%s %s" % [npc.get_meta("voice"), Audio.norm(en)])))   # v32 polish: reading time; _mute_next = false
	if S.get("voice", true):
		Audio.say_as(en, String(npc.get_meta("voice")))
		await get_tree().create_timer(0.2).timeout
		await voice_idle(0.25)
	else: await get_tree().create_timer(2.2).timeout
	if nt != null: nt.end(npc, talk_st)

const NPC_TALK := "res://scripts/core/npc_talk.gd"   # red (v32-npc-pose); preload-free so the places run without it
func _npc_talk():
	return load(NPC_TALK) if ResourceLoader.exists(NPC_TALK) else null

## subtle head nod on top of the current clip (bone offset, no clip change): "talking" / "busy" without a pose change
func nod(n: DemoCharacter, secs := 1.8) -> void:
	if n == null or not is_instance_valid(n) or n.bone_offsets.has("Head"): return
	var tw := n.create_tween()
	for i in maxi(1, int(secs / 0.9)):
		tw.tween_method(func(a: float): n.bone_offsets["Head"] = [Vector3.RIGHT, a], 0.0, 0.12, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(a: float): n.bone_offsets["Head"] = [Vector3.RIGHT, a], 0.12, 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(0.2)
	tw.tween_callback(func(): if is_instance_valid(n): n.bone_offsets.erase("Head"))

func face(who: Node3D, at: Vector3) -> void:
	var y := atan2(at.x - who.global_position.x, at.z - who.global_position.z)
	create_tween().tween_property(who, "rotation:y", who.rotation.y + wrapf(y - who.rotation.y, -PI, PI), 0.4)

# ------------------------------------------------------------------ cinematic camera (temporary Camera3D, like Life.guide_to)
func cine(pos: Vector3, at: Vector3, t := 1.4) -> void:
	pos = _safe_pos(pos, at)
	var rig := get_viewport().get_camera_3d()
	if _cine_cam == null:
		_cine_cam = Camera3D.new(); _cine_cam.fov = 50.0; add_child(_cine_cam)
		_cine_cam.global_transform = rig.global_transform if rig else Transform3D.IDENTITY; _cine_cam.current = true; _hud_hide(true)
		if hud and hud.get("touch"): pass
	var from := _cine_cam.global_transform
	var to := Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)
	var cc := _cine_cam
	var tw := cc.create_tween(); tw.tween_property(cc, "global_transform", to, t).from(from).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cine_tw = tw
	await tw.finished

## non-blocking camera move (returns the tween; await tw.finished when needed)
func cine_go(pos: Vector3, at: Vector3, t := 1.4) -> Tween:
	pos = _safe_pos(pos, at)
	if _cine_cam == null:
		var rig := get_viewport().get_camera_3d()
		_cine_cam = Camera3D.new(); _cine_cam.fov = 50.0; add_child(_cine_cam)
		_cine_cam.global_transform = rig.global_transform if rig else Transform3D.IDENTITY; _cine_cam.current = true; _hud_hide(true)
	var from := _cine_cam.global_transform
	var to := Transform3D(Basis.looking_at(at - pos, Vector3.UP), pos)
	var cc := _cine_cam
	var tw := cc.create_tween(); tw.tween_property(cc, "global_transform", to, t).from(from).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cine_tw = tw
	return tw

## v32 polish: a cinematic camera never sits inside / right behind the player's head: pull it back along the shot
func _safe_pos(pos: Vector3, at: Vector3) -> Vector3:
	if player == null or not is_instance_valid(player): return pos
	var p := pos; var back := (pos - at).normalized()
	for i in 10:
		var c: Vector3 = player.global_position
		if Vector2(p.x - c.x, p.z - c.z).length() > 0.6 or p.y > 2.3: break
		p += back * 0.2
	return p

func cine_end() -> void:
	if _cine_cam == null: return
	var c := _cine_cam; _cine_cam = null
	if _cine_tw and _cine_tw.is_valid(): _cine_tw.kill()
	var tw := c.create_tween(); tw.tween_property(c, "global_transform", _rig_xf(), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # v32 polish: eased in AND out (was ease-in only: a hard stop on the rig)
	await tw.finished
	cam.current = true
	c.queue_free(); _hud_hide(false)

func _rig_xf() -> Transform3D: return cam.global_transform

# ------------------------------------------------------------------ player helpers
func walk_to(p: Vector3, yaw := INF) -> void:
	var t := 0.0; player.busy = true
	if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > 0.15:
		player.hero.play("walk", 0.2)
		while t < 6.0:
			var d := Vector3(p.x - player.global_position.x, 0, p.z - player.global_position.z)
			if d.length() < 0.1: break
			player.velocity = d.normalized() * minf(1.6, d.length() * 4.0 + 0.3)
			player.hero.rotation.y = lerp_angle(player.hero.rotation.y, atan2(d.x, d.z), 0.25)
			player.move_and_slide(); player.global_position.y = 0.0
			await get_tree().physics_frame; t += 1.0 / 60.0
		player.velocity = Vector3.ZERO; player.hero.play("idle", 0.25)
	if yaw != INF:
		var tw := create_tween(); tw.tween_property(player.hero, "rotation:y", player.hero.rotation.y + wrapf(yaw - player.hero.rotation.y, -PI, PI), 0.3); await tw.finished
	player.busy = false

func busy(on: bool) -> void:
	mode = "busy" if on else "play"; player.busy = on
	if on: _hide_chips()

## HUD header = object name (noun), chip = verb, like every other interactable (was the verb twice: "Take Apples" + "Take apples")
const TARGET_NAMES := {"basket": "basket", "apples": "apples", "milk": "milk", "bread": "bread", "pay": "checkout", "exit": "door", "counter": "counter", "seat": "seat"}
## an objective target: Interactable that emits used(id) once enabled
func target(id: String, pos: Vector3, focus: Vector3, verb_en: String, r := 1.5) -> Interactable:
	var it := Interactable.new(); it.obj_name = String(TARGET_NAMES.get(id, id)); it.radius = r; it.position = pos; it.focus = focus; add_child(it)
	it.verbs = func() -> Array: return [[verb_en, func(): used.emit(id)]] if it.enabled else []
	its[id] = it; return it

## enable one objective target, guide the player there, wait until it is used
func objective(id: String, en: String, cam_shot = null) -> void:
	for k in its: if not String(k).begins_with("npc_"): its[k].enabled = k == id
	_mark_target = its[id]
	await guide(cam_shot if cam_shot != null else its[id].focus, en)
	busy(false)
	while true:
		var got: String = await used
		if got == id: break
	its[id].enabled = false; _mark_target = null
	Objectives.complete(en)
	busy(true)

## QA / automation: use an objective target as if the player pressed it (walks there first)
func qa_use(id: String) -> void:
	if not its.has(id): return
	var it: Interactable = its[id]
	await walk_to(Vector3(it.global_position.x, 0, it.global_position.z))
	used.emit(id)

## optional chat with an NPC: first time = data npc[place][id] dialogue, later = one short line
func chat_target(id: String, npc: DemoCharacter, r := 1.6) -> void:
	var to := (player.global_position if player else Vector3(0, 0, room.y / 2)) - npc.global_position; to.y = 0
	var it := Interactable.new(); it.obj_name = String({"assistant": "shop assistant", "barista": "barista"}.get(id, "person")); it.radius = r; add_child(it)
	it.position = npc.global_position + Vector3(0, 0, 0.9).rotated(Vector3.UP, npc.rotation.y); it.focus = npc.global_position + Vector3(0, 1.2, 0)
	its["npc_" + id] = it
	it.verbs = func() -> Array:
		if mode != "play": return []
		return [["Talk", func():
			busy(true)
			if not done("chat_" + id):
				mark("chat_" + id)
				for b in D.npc[place_id].get(id, []): await speak(String(b[0]), String(b[1]))
			else: await npc_line(npc, "Nice to see you again!")
			busy(false)]]

# ------------------------------------------------------------------ NPCs
func person(id: String, g: String, voice: String, pos: Vector3, yaw: float, pose := "idle", top := Color(0.3, 0.5, 0.8), child := false, skin := -1) -> DemoCharacter:
	var ch := DemoCharacter.new(); add_child(ch); ch.setup(g)
	if child: ch.set_child(true)
	else: ch.set_height("medium")
	ch.skin = skin if skin >= 0 else randi() % 4; ch.top_color = top; ch._refresh()
	ch.position = pos; ch.rotation.y = yaw
	ch.set_meta("voice", voice); ch.set_meta("pose", pose); ch.play(pose, 0.0)
	npcs[id] = ch
	if pose != "sit_idle":
		var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.28; sh.height = 1.6
		cs.shape = sh; cs.position = Vector3(pos.x, 0.8, pos.z); col.add_child(cs); add_child(col)
	return ch

# ------------------------------------------------------------------ phone lesson + test (phone.gd universal test rules + Skip test)
func phone_lesson(data: Dictionary) -> Array:
	busy(true)
	var phone = room_phone.phone
	await voice_idle(0.2)
	phone.visible = true; phone.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	phone.start_set(data, "lesson")
	var res = await phone.quiz_done
	await phone.close(true)
	await Audio.wait_idle(15.0)
	return [res[0], res[1]]

# ------------------------------------------------------------------ first-visit teaching card (right side, no-overlap layer)
var card_layer: CanvasLayer
var card_rows: Array = []   # [en Label, tr Label, key]
func teach_card(title: String, title_tr: String, rows: Array) -> void:   # rows: [[key, en, tr], ...]
	close_card()
	card_layer = CanvasLayer.new(); card_layer.layer = 14; add_child(card_layer)
	var pc := PanelContainer.new(); pc.name = "TeachCard"
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(1.0, 0.98, 0.92, 0.95); sb.set_corner_radius_all(18); sb.set_content_margin_all(14)
	sb.border_color = Color(0.93, 0.52, 0.44); sb.set_border_width_all(3); pc.add_theme_stylebox_override("panel", sb)
	pc.anchor_left = 1.0; pc.anchor_right = 1.0; pc.anchor_top = 0.0; pc.anchor_bottom = 0.0   # top-right, under the phone button, above the right stick
	pc.offset_left = -580; pc.offset_right = -120; pc.offset_top = 96; pc.offset_bottom = 120; pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.add_child(pc)
	Objectives.ovl_register(pc, 5)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); pc.add_child(v)
	var tr_on := App.tr_on()
	var tl := Label.new(); tl.text = title; tl.add_theme_font_size_override("font_size", 26); tl.add_theme_color_override("font_color", Color(0.75, 0.32, 0.25)); v.add_child(tl)
	if tr_on and title_tr != "": var tt := Label.new(); tt.text = title_tr; tt.add_theme_font_size_override("font_size", 15); tt.add_theme_color_override("font_color", Color(0.3, 0.45, 0.75)); v.add_child(tt)
	card_rows = []
	for r in rows:
		var el := Label.new(); el.text = "•  " + String(r[1]); el.add_theme_font_size_override("font_size", 19); el.add_theme_color_override("font_color", Color(0.12, 0.12, 0.16))
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; el.custom_minimum_size.x = 420; v.add_child(el)
		var tl2: Label = null
		if tr_on and String(r[2]) != "":
			tl2 = Label.new(); tl2.text = "    " + String(r[2]); tl2.add_theme_font_size_override("font_size", 14); tl2.add_theme_color_override("font_color", Color(0.3, 0.45, 0.75)); v.add_child(tl2)
		card_rows.append([el, tl2, String(r[0])])
	pc.modulate.a = 0.0; create_tween().tween_property(pc, "modulate:a", 1.0, 0.4)
	Audio.sfx("cloth1", -10.0)

func tick_card(key: String) -> void:
	for r in card_rows:
		if r[2] == key and is_instance_valid(r[0]):
			(r[0] as Label).text = "✓" + (r[0] as Label).text.substr(1); (r[0] as Label).add_theme_color_override("font_color", Color(0.2, 0.6, 0.35))

func close_card() -> void:
	if card_layer and is_instance_valid(card_layer): card_layer.queue_free()
	card_layer = null; card_rows = []

# ------------------------------------------------------------------ exit
func exit_door(pos: Vector3, focus: Vector3) -> void:
	target("exit", pos, focus, "Go outside")

func leave() -> void:
	Audio.sfx("place_bell", -8.0); Audio.sfx("doorOpen_1", -4.0)
	save_game(); App.came_from = place_id
	await get_tree().create_timer(0.6).timeout
	Audio.music("")
	place_exited.emit(place_id)
	if "--qa-place" in OS.get_cmdline_user_args(): return
	# back to the street in front of this building: world_exterior.gd puts the player at Lot.entrance_global() of "lot:<id>"
	# (falls back to WorldState.player_pos, which Lot._on_enter stored on the way in)
	StoryNav.goto(Game.WORLD_SCENE, "lot:" + world_lot)

# ------------------------------------------------------------------ building helpers
var _mats := {}
func mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var k := "%s_%s" % [c.to_html(), emit]
	if _mats.has(k): return _mats[k]
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.8
	if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
	_mats[k] = m; return m

func box(s: Vector3, p: Vector3, c: Color, solid := true, yaw := 0.0, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.material_override = mat(c, emit)
	mi.position = p; mi.rotation.y = yaw; add_child(mi)
	if solid: collider(s, p, yaw)
	return mi

func cyl(r: float, h: float, p: Vector3, c: Color, solid := false, emit := 0.0, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r if r2 < 0 else r2; cm.height = h; cm.radial_segments = 14; cm.rings = 1; mi.mesh = cm
	mi.material_override = mat(c, emit); mi.position = p; add_child(mi)
	if solid: collider(Vector3(r * 2, h, r * 2), p)
	return mi

func ball(r: float, p: Vector3, c: Color, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; sm.radial_segments = 10; sm.rings = 6; mi.mesh = sm
	mi.material_override = mat(c, emit); mi.position = p; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi); return mi

func collider(s: Vector3, p: Vector3, yaw := 0.0) -> void:
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = s; cs.shape = sh
	sb.position = p; sb.rotation.y = yaw; sb.add_child(cs); add_child(sb)

func label(text: String, p: Vector3, size := 64, col := Color.WHITE, yaw := 0.0, outline := Color(0, 0, 0, 0.6)) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.0025; l.modulate = col; l.outline_modulate = outline; l.outline_size = 6
	l.position = p; l.rotation.y = yaw; l.shaded = false; l.double_sided = false
	var f = load("res://fonts/Nunito.ttf") if ResourceLoader.exists("res://fonts/Nunito.ttf") else null
	if f: l.font = f
	add_child(l); return l

## CC0 Kenney model, scaled to height (or longest side), feet on pos.y; solid adds a box collider when on the floor
func model(path: String, pos: Vector3, yaw_deg := 0.0, height := 0.0, length := 0.0, solid := false) -> Node3D:
	var pivot := Node3D.new(); add_child(pivot)
	var inst: Node3D = (load(path) as PackedScene).instantiate(); pivot.add_child(inst)
	var ab := _aabb(inst); var s := 1.0
	if height > 0.0: s = height / maxf(ab.size.y, 0.001)
	elif length > 0.0: s = length / maxf(maxf(ab.size.x, ab.size.z), 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = -Vector3((ab.position.x + ab.size.x * 0.5) * s, ab.position.y * s, (ab.position.z + ab.size.z * 0.5) * s)
	pivot.position = pos; pivot.rotation.y = deg_to_rad(yaw_deg)
	for m in inst.find_children("*", "MeshInstance3D", true, false): (m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (ab.size * s).length() < 0.6 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if solid and pos.y < 0.3:
		var sz := ab.size * s; if absf(fmod(yaw_deg, 180.0)) > 45.0: sz = Vector3(sz.z, sz.y, sz.x)
		collider(Vector3(sz.x, maxf(sz.y, 0.6), sz.z), pos + Vector3(0, sz.y / 2.0, 0))
	return pivot

func food(name: String, pos: Vector3, size := 0.12, yaw_deg := 0.0) -> Node3D: return model(FOOD + name + ".glb", pos, yaw_deg, 0.0, size)
func furn(name: String, pos: Vector3, yaw_deg := 0.0, height := 0.0, length := 0.0, solid := true) -> Node3D: return model(PF + name + ".glb", pos, yaw_deg, height, length, solid)

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

func floor_colors() -> Array: return [Color(0.62, 0.45, 0.32), Color(0.95, 0.9, 0.82), Color(0.80, 0.55, 0.42)]   # floor, wall, accent

func _room() -> void:
	var hx := room.x / 2.0; var hz := room.y / 2.0
	var fc: Array = floor_colors(); var floor_c: Color = fc[0]; var wc: Color = fc[1]; var ac: Color = fc[2]
	box(Vector3(room.x, 0.1, room.y), Vector3(0, -0.05, 0), floor_c, true)
	for i in range(1, int(room.x / 0.5)): box(Vector3(0.012, 0.004, room.y), Vector3(-hx + i * 0.5, 0.002, 0), floor_c.darkened(0.14), false)
	box(Vector3(60, 0.1, 60), Vector3(0, -0.16, 0), Color(0.55, 0.58, 0.6), false)
	var h := 3.0
	for d in [[Vector3(room.x, h, 0.14), Vector3(0, h / 2, -hz), Vector3(0, 0, -1)], [Vector3(room.x, h, 0.14), Vector3(0, h / 2, hz), Vector3(0, 0, 1)],
			[Vector3(0.14, h, room.y), Vector3(-hx, h / 2, 0), Vector3(-1, 0, 0)], [Vector3(0.14, h, room.y), Vector3(hx, h / 2, 0), Vector3(1, 0, 0)]]:
		var m := box(d[0], d[1], wc); walls.append([m, d[2]])
		var n: Vector3 = d[2]; var sz: Vector3 = d[0]
		var a := box(Vector3(0.01, h * 0.38, sz.z - 0.04) if n.x != 0 else Vector3(sz.x - 0.04, h * 0.38, 0.01), Vector3(d[1].x, h * 0.19, d[1].z) - n * 0.075, ac, false); walls.append([a, n])
		var trim := box(Vector3(0.02, 0.05, sz.z - 0.04) if n.x != 0 else Vector3(sz.x - 0.04, 0.05, 0.02), Vector3(d[1].x, h * 0.38, d[1].z) - n * 0.08, Color(1, 1, 1), false); walls.append([trim, n])
	# front door (glass, the player came in here) + door mat
	var dm := box(Vector3(1.2, 2.2, 0.06), Vector3(0, 1.1, hz - 0.09), Color(0.35, 0.25, 0.18), false); walls.append([dm, Vector3(0, 0, 1)])
	var gl := box(Vector3(0.9, 1.5, 0.02), Vector3(0, 1.3, hz - 0.125), Color(0.7, 0.85, 0.95), false, 0.0, 0.25); walls.append([gl, Vector3(0, 0, 1)])
	furn("rugDoormat", Vector3(0, 0.0, hz - 0.6), 0, 0.0, 1.2, false)

func _marker() -> void:
	marker = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.14; cm.height = 0.28
	marker.mesh = cm; marker.rotation_degrees.x = 180
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(1.0, 0.8, 0.2); mm.emission_enabled = true; mm.emission = Color(1.0, 0.75, 0.1); mm.emission_energy_multiplier = 0.8
	mm.no_depth_test = true; mm.render_priority = 5; marker.material_override = mm; marker.visible = false; add_child(marker)

func _process(dt: float) -> void:
	_t += dt
	marker.visible = _mark_target != null and is_instance_valid(_mark_target) and mode == "play"
	if marker.visible: marker.global_position = _mark_target.focus + Vector3(0, 0.55 + sin(_t * 3.0) * 0.07, 0)
	var c := get_viewport().get_camera_3d()
	if c:
		var hz := room.y / 2.0
		var near_s: bool = player != null and player.global_position.z > hz - 1.8   # player close to the south wall
		var occ := {}   # v33 rule: a side / back wall that hides the player fades (its trim + accent with it), then fades back
		if player != null:
			for w in walls: if (w[1] as Vector3).z <= 0.5 and not occ.get(w[1], false): occ[w[1]] = WallFade.occluded(w[0], c.global_position, player.global_position)
		for w in walls:
			var m: MeshInstance3D = w[0]; var n: Vector3 = w[1]
			var d: float = (c.global_position - m.global_position).dot(n)
			if n.z > 0.5:   # v32 rule: south wall (+ door, trim, accent) fades gradually when the camera or the player is near
				WallFade.step(m, d > -0.8 or near_s, dt)
			else: WallFade.step_occl(m, 0.0 if d >= 0.3 else (WallFade.OCC_MIN_A if occ.get(n, false) else 1.0), dt)   # v33: was an instant hide
	lively(dt)

func lively(_dt: float) -> void: pass   # override: ambient NPC motion

## v32 polish: ambient life helpers for NPCs outside the scripted beats (call from lively() only while mode == "play").
## glance(): every few seconds the NPC eases its body toward a nearby direction and back (never a snap).
var _glance_t := {}
func glance(id: String, dt: float, every := 6.0, amp := 0.35) -> void:
	if not npcs.has(id): return
	var n: DemoCharacter = npcs[id]
	if not n.has_meta("home_yaw"): n.set_meta("home_yaw", n.rotation.y)
	if bool(n.get_meta("gesturing", false)): return
	var t: float = float(_glance_t.get(id, randf_range(1.5, every))) - dt
	if t <= 0.0:
		t = randf_range(every * 0.7, every * 1.3)
		var to: float = float(n.get_meta("home_yaw")) + (randf_range(-amp, amp) if randf() < 0.7 else 0.0)
		n.create_tween().tween_property(n, "rotation:y", n.rotation.y + wrapf(to - n.rotation.y, -PI, PI), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glance_t[id] = t

## gesture(): play anim for `hold` s (one-shot clips: pass their length so the last frame never freezes), then blend back
func gesture(n: DemoCharacter, anim: String, hold: float) -> void:
	if n == null or bool(n.get_meta("gesturing", false)) or not n.player.has_animation(anim): return
	var pose: String = n.get_meta("pose", "idle")
	n.set_meta("gesturing", true); n.play(anim, 0.35)
	await get_tree().create_timer(hold).timeout
	if not is_instance_valid(n): return
	if n.player.current_animation == anim: n.play(pose, 0.4)
	n.set_meta("gesturing", false)
