## house.25: Life - one shared game clock bridge (WorldState is the clock), day counter, phone battery, body needs, HUD.
## Needs (0 = fine, 1 = urgent) grow so each comes about once per in-game day; actions (scene action_peak ids) satisfy them.
extends Node

signal day_changed(day: int)
const NEED_RATE := {"hunger": 1.0 / 600.0, "thirst": 1.0 / 480.0, "pee": 1.0 / 540.0, "poop": 1.0 / 900.0}   # per game minute
const NEED_ICON := {"hunger": "Food", "thirst": "Drink", "pee": "Pee", "poop": "Toilet"}
const SATISFY := {"breakfast": ["hunger", "thirst"], "tea": ["thirst"], "drink": ["thirst"], "glass": ["thirst"], "cup": ["thirst"],
	"water": ["thirst"], "fridge": ["hunger"], "kitchen": ["hunger"], "snack": ["hunger"], "eat": ["hunger"], "toilet": ["pee", "poop"]}
## v32-polish GLOBAL TOGGLE (Yasin): phone battery / charging and ALL body needs are switched OFF until further notice.
## false -> needs and battery never decay (battery stays 100), no needs/battery objectives, prompts, warnings or voice lines,
## the top-left strip shows only the clock + day, the phone never goes dead. Set true to bring everything back (code kept).
const NEEDS_ENABLED := false
var needs := {"hunger": 0.1, "thirst": 0.1, "pee": 0.1, "poop": 0.0}
var battery := 100.0          # %
var charging := false
var photos := {}              # story polaroids: key -> ImageTexture
var _last_min := -1.0
var _warned := false
var _hud: CanvasLayer
var _lbl: Label
var _scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	WorldState.ensure_loaded(); _load()
	_hud = CanvasLayer.new(); _hud.layer = 5; add_child(_hud)
	_lbl = Label.new(); _lbl.name = "LifeClock"; _lbl.position = Vector2(18, 128); _lbl.add_theme_font_size_override("font_size", 15)
	_lbl.add_theme_color_override("font_color", Color(0.15, 0.18, 0.28)); _lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_lbl.add_theme_constant_override("outline_size", 5); _lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; _hud.add_child(_lbl)

## new game: clock back to day 1, 07:00, needs + battery reset
func new_game() -> void:
	App.has_phone = false   # v29.1: a new game starts without the phone
	WorldState.day = 1; WorldState.minutes = 7.0 * 60.0; WorldState.flags = {}
	needs = {"hunger": 0.1, "thirst": 0.1, "pee": 0.1, "poop": 0.0}; battery = 100.0; _warned = false; photos = {}
	for f in DirAccess.get_files_at(SavePath.photos()): DirAccess.remove_absolute(SavePath.photos() + "/" + f)
	App.day = 1

func advance_day(midnight := false) -> void:
	WorldState.day += 1; WorldState.minutes = 0.0 if midnight else 7.0 * 60.0   # house.29: the dream starts at exactly 00:00
	_on_new_day()

func _on_new_day() -> void:
	App.day = WorldState.day
	App.patch_save({"day": App.day})
	day_changed.emit(App.day)

func _process(dt: float) -> void:
	if App.day != WorldState.day: _on_new_day()
	var sc := RoutineScope.current(get_tree())
	if sc != _scene: _scene = sc; _hook(sc)
	var m := WorldState.minutes + WorldState.day * 1440.0
	if _last_min < 0.0: _last_min = m
	var dm := clampf(m - _last_min, 0.0, 120.0); _last_min = m
	var in_game: bool = sc != null and sc.has_method("caption") and not String(sc.scene_file_path).ends_with("menu.tscn")
	charging = in_game and sc.get("S") is Dictionary and String(sc.S.get("phone", "")) == "charging"
	if not NEEDS_ENABLED:   # v32-polish: no decay, no warnings / objectives; strip = clock + day only
		battery = 100.0; _warned = false
		for k in needs: needs[k] = 0.0
		if Objectives.has("charge"): Objectives.set_list(Objectives.items.filter(func(it): return not (it is Dictionary and String(it.get("id", "")) == "charge")), false)
		var ph0 = sc.get("phone") if sc else null
		if not (ph0 is CanvasItem) and sc and sc.get("room_phone") != null: ph0 = sc.room_phone.phone
		_lbl.visible = in_game and not (ph0 is CanvasItem and ph0.visible)
		if in_game: _lbl.text = "%s   %s %d\n" % [WorldState.clock_text(), App.tx("Day"), WorldState.day]
		return
	if charging: battery = minf(battery + dt * 2.0, 100.0)   # house.29: charging in real time (~50 s full)
	if charging and Objectives.has("charge"): Objectives.complete("charge")   # v30.5
	if in_game and dm > 0.0:
		for k in needs: needs[k] = clampf(needs[k] + NEED_RATE[k] * dm, 0.0, 1.0)
		charging = sc.get("S") is Dictionary and String(sc.S.get("phone", "")) == "charging"
		if not charging: battery = clampf(battery - dm * 100.0 / 1020.0, 0.0, 100.0)   # house.29: one charge lasts the day (07:00-24:00)
		if battery < 15.0 and not _warned and not charging:
			_warned = true; _say(sc, "My phone battery is low. I should charge it.")
			Objectives.add("charge", "Charge my phone.", "Telefonumu şarj et.")   # v30.5
		if battery > 30.0: _warned = false
	var ph = sc.get("phone") if sc else null
	if not (ph is CanvasItem) and sc and sc.get("room_phone") != null: ph = sc.room_phone.phone   # v31: living room / outside phone too
	_lbl.visible = in_game and not (ph is CanvasItem and ph.visible)   # v29.1: not drawn over the open phone (it has its own status bar)
	if in_game:
		# v32 blue: status line stays English (TR text only inside the shared caption box; it mixed "Gün 3 Pil" with "Food!")
		var t := "%s   Day %d   Battery %d%%%s\n" % [WorldState.clock_text(), WorldState.day, int(battery), " (charging)" if charging else ""]
		for k in needs: if needs[k] > 0.6: t += "%s!  " % NEED_ICON[k]
		_lbl.text = t

func _hook(sc: Node) -> void:
	if sc and String(sc.scene_file_path).ends_with("hospital.tscn"): _dim_sun.call_deferred(sc)   # v29: hospital sun follows the shared clock
	if sc and sc.has_signal("action_peak") and not sc.action_peak.is_connected(_on_peak): sc.action_peak.connect(_on_peak)

func _on_peak(id) -> void:
	var s := String(id)
	for k in SATISFY:
		if s.contains(k): for n in SATISFY[k]: needs[n] = 0.0
	save()

func satisfy(list: Array) -> void:
	for n in list: needs[n] = 0.0
	save()

func _say(sc: Node, en: String) -> void:
	await Audio.wait_idle(12.0); sc.caption(en)

func snap(key: String) -> void:
	# red v28: hide every visible HUD CanvasLayer for the frame that is captured, then restore it
	var hidden := _hide_layers()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_restore_layers(hidden)
	if img: _store_photo(key, img)

## red v28: snapshot from an offscreen camera (same 3D world, own SubViewport) so the polaroid can frame the player
## while the on-screen shot shows something else. No HUD is drawn in a SubViewport, and the screen does not change.
func snap_from(key: String, xf: Transform3D, fov := 50.0) -> void:
	var main_vp := get_viewport()
	var vs: Vector2 = main_vp.get_visible_rect().size
	var vp := SubViewport.new(); vp.world_3d = main_vp.world_3d
	vp.size = Vector2i(960, int(960.0 * vs.y / maxf(1.0, vs.x))); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var c := Camera3D.new(); c.fov = fov; vp.add_child(c); add_child(vp); c.global_transform = xf; c.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img: _store_photo(key, img)

func _store_photo(key: String, img: Image) -> void:
	photos[key] = ImageTexture.create_from_image(img)
	# house.27: keep a small copy on disk so the dream polaroids survive a save / reload
	var sm := img.duplicate() as Image; sm.resize(480, int(480.0 * img.get_height() / max(1, img.get_width())), Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(SavePath.photos()); sm.save_png(SavePath.photos() + "/%s.png" % key)

func _hide_layers() -> Array:
	var out: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := n as CanvasLayer
		if cl.visible and cl.get_viewport() == get_viewport(): cl.visible = false; out.append(cl)
	return out

func _restore_layers(list: Array) -> void:
	for cl in list:
		if is_instance_valid(cl): cl.visible = true

## house.27: polaroid picture for a story key: this run's snapshot -> saved snapshot -> pre-rendered still (never null if a still exists)
func photo(key: String) -> Texture2D:
	if photos.has(key): return photos[key]
	var f := SavePath.photos() + "/%s.png" % key
	if FileAccess.file_exists(f):
		var img := Image.load_from_file(f)
		if img: photos[key] = ImageTexture.create_from_image(img); return photos[key]
	var r := "res://ui/polaroid/%s.png" % key
	return load(r) if ResourceLoader.exists(r) else null

func save() -> void:
	App.patch_save({"life": {"needs": needs, "battery": battery}, "world": WorldState.to_dict()})
func _load() -> void:
	var d = App.load_save().get("life")
	if d is Dictionary:
		if d.get("needs") is Dictionary: for k in d.needs: needs[k] = float(d.needs[k])
		battery = float(d.get("battery", 100.0))
	App.day = WorldState.day if WorldState.day > 0 else App.day

## house.29: event-driven clock. Each story event jumps the shared WorldState clock forward to its time.
const EVENT_TIME := {"wake": [7, 0], "bathroom": [7, 15], "breakfast": [8, 0], "going_out": [9, 0], "accident": [9, 20],
	"hospital": [11, 0], "home": [18, 0], "bedtime": [23, 30], "morning": [7, 0],
	"work": [9, 30], "work_end": [16, 30]}   # v31 day 2
func event(id: String) -> void:
	if not EVENT_TIME.has(id): return
	WorldState.set_time(EVENT_TIME[id][0], EVENT_TIME[id][1])

## v29: scale every sun of a scene by the shared clock's daylight (kept out of hospital.gd)
func _dim_sun(sc: Node) -> void:
	if not is_instance_valid(sc): return
	for l in sc.find_children("*", "DirectionalLight3D", true, false):
		if not l.has_meta("base_energy"): l.set_meta("base_energy", l.light_energy)
		l.light_energy = float(l.get_meta("base_energy")) * WorldState.daylight()

## v304: shared next-step guide (mirror-prompt pattern: notify + top-left objective + 2.6 s cam pan).
## target: Node3D | Vector3 | Dictionary {pos, at[, h]} | null (objective+sound only).
## text: EN objective. opts: id, tr, list (Array replaces Objectives), speak, sound.
func guide_to(target, text: String, opts := {}) -> void:
	if Objectives.stale(text): return   # Yasin 17:58: no "Go to the living room." after the day-2 family chat
	var sc := RoutineScope.current(get_tree())
	var id := String(opts.get("id", text))
	var tr := String(opts.get("tr", ""))
	if opts.has("list") and opts.list is Array:
		Objectives.set_list(opts.list)
	else:
		var cur: Array = []
		for it in Objectives.items:
			if String(it.id) != id and String(it.en) != text: cur.append(it)
		var entry := {"id": id, "en": text}
		if tr != "": entry["tr"] = tr
		cur.push_front(entry); Objectives.set_list(cur)
	if sc:
		if sc.has_method("_set_mission"): sc._set_mission(text)
		elif sc.get("hud") and sc.hud.has_method("set_mission"): sc.hud.set_mission(text, tr)
	# v32 (black): an objective is announced (sound + pan + spoken line) ONCE per day and scene. Re-entering a room only
	# restores the top-left entry above; opts.repeat = true forces a deliberate re-announcement.
	var scn: String = sc.scene_file_path if sc else ""
	if not bool(opts.get("repeat", false)) and not once("guide|%s|%s" % [scn.get_file(), id]): return
	if bool(opts.get("sound", true)): Audio.sfx("notify", -4.0)
	var shot := _guide_shot(sc, target)
	var speak := bool(opts.get("speak", true))
	if shot.is_empty():
		if speak: await _guide_say(sc, text)
		return
	var restore_play := false
	if sc and "mode" in sc and String(sc.mode) == "play":
		sc.mode = "busy"; restore_play = true
	if sc and sc.get("touch"): sc.touch.visible = false
	if sc and "cine_flash" in sc and not bool(opts.get("no_flash", false)): sc.cine_flash = true   # v30.4: no mirror-glow pulse on other pans
	var used_temp := false
	var pan_tw: Tween = null
	var tmp: Camera3D = null
	var rig: Camera3D = null
	shot["guide"] = true   # v33 (blue): the shoulder camera frames hero + target for objective pans (scripts/core/shoulder_cam.gd)
	if sc and "cam_shot" in sc:
		sc.cam_shot = shot
	else:
		# exterior / scenes without cam_shot follow: temporary Camera3D (same 2.6 s feel)
		rig = sc.get("cam") as Camera3D if sc else null
		if rig == null: rig = get_viewport().get_camera_3d()
		if rig:
			used_temp = true; tmp = Camera3D.new(); tmp.fov = rig.fov; sc.add_child(tmp)
			tmp.set_meta("guide_cam", true); tmp.set_meta("guide_at", shot.at)   # v33 (blue): shoulder camera frames hero + target
			tmp.global_transform = rig.global_transform; tmp.current = true
			pan_tw = sc.create_tween() if sc else create_tween()
			var from_pos := rig.global_position
			# v32 polish (blue): the rotation is slerped with the position (look_at() on frame 1 snapped the view to the
			# target before the camera moved), eased in and out
			var from_q := rig.global_transform.basis.get_rotation_quaternion()
			var dv: Vector3 = shot.at - shot.pos
			var to_q := (Basis.looking_at(dv, Vector3.UP) if absf(dv.normalized().y) < 0.99 else rig.global_transform.basis).get_rotation_quaternion()
			pan_tw.tween_method(func(k):
				if is_instance_valid(tmp): tmp.global_transform = Transform3D(Basis(from_q.slerp(to_q, k)), from_pos.lerp(shot.pos, k)), 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var t0 := Time.get_ticks_msec()
	if speak: await _guide_say(sc, text)
	# v31: the pan waits for its OWN tween (+ the 2.6 s hold), never just the spoken line (short lines freed tmp mid-pan)
	if pan_tw and pan_tw.is_valid() and pan_tw.is_running(): await pan_tw.finished
	var left := 2.6 - (Time.get_ticks_msec() - t0) / 1000.0
	if left > 0.0: await get_tree().create_timer(left, false).timeout
	if used_temp and is_instance_valid(tmp) and is_instance_valid(rig):
		var back := sc.create_tween() if sc else create_tween()
		back.tween_property(tmp, "global_transform", rig.global_transform, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)   # v32 polish (blue): eased out too
		await back.finished
		if is_instance_valid(rig): rig.current = true
		if is_instance_valid(tmp): tmp.queue_free()
	elif sc and "cam_shot" in sc:
		sc.cam_shot = {}
		await get_tree().create_timer(0.3, false).timeout
	if sc and "cine_flash" in sc: sc.cine_flash = false
	if sc and sc.get("touch"): sc.touch.visible = true
	if restore_play and sc:
		sc.mode = "play"
		if sc.has_method("_update_hand"): sc._update_hand()

## v32 (black): played-once registry for announcements, kept in save.json "announced" (day-scoped keys).
## Returns true the first time `key` is seen on the current day, false afterwards. New Game deletes the save -> reset.
func once(key: String) -> bool:
	var k := "%d|%s" % [maxi(WorldState.day, App.day), key]
	var d := {}
	if FileAccess.file_exists(SavePath.P()):
		var x = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if x is Dictionary and x.get("announced") is Dictionary: d = x.announced
	if d.has(k) or _once_mem.has(k): return false
	_once_mem[k] = true; d[k] = true; App.patch_save({"announced": d}); return true
var _once_mem := {}

func _guide_say(sc: Node, text: String) -> void:
	if sc and sc.has_method("say_line"):
		await sc.say_line(text); return
	if sc and sc.has_method("caption"):
		await sc.caption(text)
		await Audio.wait_idle(12.0)
		return
	Audio.say(text)
	await get_tree().create_timer(2.6, false).timeout
	await Audio.wait_idle(12.0)

func _guide_shot(sc: Node, target) -> Dictionary:
	if target == null: return {}
	# build 3.2 (open world): rooms (main / living room / bathroom: they have cam_shot) give room-local shots and points
	# (OBJ focus, DOOR_*, SOFA_X, DINE_C ...); the guide shot is world space (ShoulderCam + rooms' _shot_l convert back)
	var room_l: bool = sc is Node3D and "cam_shot" in sc
	if target is Dictionary and target.has("pos") and target.has("at"):
		if room_l: return {"pos": (sc as Node3D).to_global(target.pos), "at": (sc as Node3D).to_global(target.at), "h": float(target.get("h", 0.0))}
		return {"pos": target.pos, "at": target.at, "h": float(target.get("h", 0.0))}
	var at: Vector3
	if target is Vector3: at = (sc as Node3D).to_global(target) if room_l else target
	elif target is Node3D: at = (target as Node3D).global_position + Vector3(0, 1.15, 0)
	else: return {}
	var eye := Vector3.ZERO
	var hero = sc.get("hero") if sc else null
	if hero == null and sc: hero = sc.get("player")
	if hero is Node3D: eye = (hero as Node3D).global_position
	elif sc and sc.get("cam") is Camera3D: eye = (sc.cam as Camera3D).global_position
	var away: Vector3 = at - eye; away.y = 0.0
	if away.length() < 0.05: away = Vector3(0, 0, 1)
	away = away.normalized()
	var pos: Vector3 = at - away * 2.4 + Vector3(0, 0.7, 0)
	return {"pos": pos, "at": at}
