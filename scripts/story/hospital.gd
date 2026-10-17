## house.25: hospital room (primitives), first-person, blurry view that slowly clears; can/should lesson + quiz on the phone
## (sharp, on its own layer), doctor + one family member from the player's family, then home.
extends Node3D
class_name HospitalScene

## v31: public entry for the day-2 hospital visit (black: call from the car choice 'hospital' on day 2)
##   HospitalScene.start_day2_visit(get_tree())
static func start_day2_visit(tree: SceneTree) -> void:
	tree.change_scene_to_file("res://scenes/hospital_day2.tscn")

var S := {"voice": true, "tr": false, "lesson_done": true}   # v29: TR off by default; real setting read from save.json state.tr in _ready
var font: Font = UI.font
var notify_app := ""
var font_b: Font = UI.font_b
var ui: StoryUI
var cam: Camera3D
var blur: ColorRect
var phone: Control
var doctor: DemoCharacter
var fam: DemoCharacter
var fam_name := ""
var fam_voice := "amy"

func _ready() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.85, 0.9, 0.92)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.7; env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); sun.light_energy = 0.8; add_child(sun)
	var lamp := OmniLight3D.new(); lamp.position = Vector3(0, 2.6, 0); lamp.omni_range = 7.0; lamp.light_energy = 0.7; lamp.light_specular = 0.0; add_child(lamp)
	_room()
	cam = Camera3D.new(); add_child(cam); cam.fov = 65.0
	cam.position = Vector3(0, 0.95, -1.6); cam.look_at(Vector3(0, 1.3, 1.5)); cam.current = true
	doctor = DemoCharacter.new(); add_child(doctor); doctor.setup("men"); doctor.top_color = Color(0.97, 0.97, 0.97); doctor.set_height("medium"); doctor._refresh()
	doctor.position = Vector3(0.7, 0, 0.9); doctor.rotation.y = PI + 0.4; doctor.play("idle", 0.0)
	if not ResourceLoader.exists("res://scripts/story/doctor_coat.gd"): _dress_doctor()   # v29: old static coat only as fallback
	if ResourceLoader.exists("res://scripts/story/doctor_coat.gd"): load("res://scripts/story/doctor_coat.gd").dress(doctor)   # v28: black's skinned coat
	var st: Dictionary = App.load_save().get("state", {})
	S.tr = App.tr_saved()   # v29: follow the player's TR setting (no Turkish "Gün 1" when TR is off)
	for m in st.get("family", []):
		if m is Dictionary:
			var ch = CharacterHook.make_family_member(m)
			if ch: fam = ch; fam_name = String(m.get("name", "")); fam_voice = ("child_f" if ch.gender == "women" else "child_m") if m.get("child", false) else ("amy" if ch.gender == "women" else "ryan"); break
	if fam == null:
		fam = DemoCharacter.new(); fam.setup("women"); fam_name = "Mom"   # v29: generic family fallback (no family member saved)
	_player_body()   # v29 (M4): the player in the bed - hidden from the first-person camera, seen by the polaroid camera
	add_child(fam); fam.position = Vector3(-0.8, 0, 0.8); fam.rotation.y = PI - 0.5; fam.play("idle", 0.0)
	# blur (screen shader, below the UI layers) + fade from black
	var bl := CanvasLayer.new(); bl.layer = 2; add_child(bl)
	blur = ColorRect.new(); blur.set_anchors_preset(Control.PRESET_FULL_RECT); blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear;\nuniform float amount = 4.0;\nuniform float dark = 1.0;\nuniform float lid = 0.0;\nuniform float flash = 0.0;\nuniform vec2 fpos = vec2(0.5);\nvoid fragment(){ vec2 px = SCREEN_PIXEL_SIZE * amount * 3.0; vec3 c = vec3(0.0); for (int x = -2; x <= 2; x++) { for (int y = -2; y <= 2; y++) { c += texture(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * px).rgb; } } c /= 25.0; vec2 d = SCREEN_UV - 0.5; c *= 1.0 - clamp(length(d) * amount * 0.18, 0.0, 0.6); float ey = abs(SCREEN_UV.y - 0.5) * 2.0; float op = 1.1 - 1.15 * lid; c *= 1.0 - smoothstep(op - 0.12, op + 0.02, ey); vec2 fd = (SCREEN_UV - fpos) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0); c += vec3(1.0, 0.97, 0.88) * flash * (exp(-dot(fd, fd) * 60.0) + 0.25 * exp(-dot(fd, fd) * 6.0)); COLOR = vec4(mix(c, vec3(0.0), dark), 1.0); }"
	var mt := ShaderMaterial.new(); mt.shader = sh; blur.material = mt; bl.add_child(blur); mt.set_shader_parameter("amount", 4.0); mt.set_shader_parameter("dark", 1.0)
	var pl := CanvasLayer.new(); pl.layer = 20; add_child(pl)
	var holder := Control.new(); holder.set_anchors_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE; pl.add_child(holder)
	phone = load("res://scripts/phone.gd").new(); phone.main = self; phone.visible = false; holder.add_child(phone)
	ui = StoryUI.new(); add_child(ui)
	_add_tr_toggle()
	if _day2_exam_done(): _already_seen()   # v306: after the day-2 visit no exam ever plays again (every entry path lands here)
	else: _run()

## v30.5: the standard TR toggle (top right) on the shared persisted flag; lesson pages update live
var tr_btn: Button
func _add_tr_toggle() -> void:
	# v32-polish: the TR button lives INSIDE the one standard caption box (StoryUI), not bottom-left on its own layer
	tr_btn = ui.tr_btn; _style_tr()
func _style_tr() -> void:
	var on := App.tr_on()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.31, 0.42, 0.93) if on else Color(1, 1, 1, 0.94); sb.set_corner_radius_all(18)
	for k in ["normal", "hover", "pressed"]: tr_btn.add_theme_stylebox_override(k, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]: tr_btn.add_theme_color_override(k, Color(1, 1, 1) if on else Color(0.13, 0.16, 0.24))
func toggle_tr(on: bool) -> void:
	App.save_tr(on); S.tr = on
	if has_method("set_tr"): call("set_tr", on)
	elif ui: ui.tr_l.visible = on and ui.tr_l.text != ""
	_style_tr()
	if phone and phone.visible and String(phone.page) == "lesson": phone._lesson()   # re-render title / TR rows

# ---- host API used by phone.gd
func caption(t: String, _speak := true) -> void:
	if ui:
		ui.en_l.text = t; ui.tr_l.text = StoryUI.tr_of(t); ui._sync_tr(); ui.panel.visible = t != ""   # v32-polish: same box
		if t != "": StoryUI.claim(ui.panel)   # v32-polish: hide any other bottom box even if this one was already up
func phone_event(_a: String) -> void: pass
func extra_tr(_t: String) -> String: return ""
func is_child() -> bool: return String(App.load_save().get("state", {}).get("age", "adult")) == "child"
func save() -> void: pass

func _set_blur(a: float, d: float, t: float) -> void:
	var m: ShaderMaterial = blur.material
	var a0: float = _ba; var d0: float = _bd
	var tw := create_tween()
	tw.tween_method(func(k: float):
		_ba = lerpf(a0, a, k); _bd = lerpf(d0, d, k)
		m.set_shader_parameter("amount", _ba); m.set_shader_parameter("dark", _bd), 0.0, 1.0, t)
	await tw.finished
var _ba := 4.0
var _bd := 1.0

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	await _set_blur(4.0, 0.25, 3.0)
	await _blink(2)
	await _look_around()
	await ui.line("Where am I?")
	# can / should lesson + quiz (phone UI stays sharp; phone locked until done)
	var data: Dictionary = App.load_json("res://data/can_should.json")
	phone.visible = true; phone.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	phone.start_set(data, "lesson"); await phone.lesson_steps_done
	phone.start_set(data, "quiz"); await phone.quiz_done
	await phone.close(true)
	ui.hide_caption()
	_set_blur(0.8, 0.05, 4.0)
	await ui.line("Can you hear me?", "Doctor", 0.7, "hfc_male")
	await ui.line("Yes, I can.", "Me")
	# flashlight flash
	# flashlight eye check: penlight in the doctor's hand + glare sweeping across each eye
	# v28: penlight sits in the doctor's right hand; he raises the arm to the player's eyes
	var piv := Node3D.new(); add_child(piv); _pen_piv = piv; _pen_follow(true)   # v29 (M5): penlight HELD in Hand.R (BoneAttachment3D doctor._hand.R): grip point in the bone frame, world-space metres, tip looks at the camera every frame
	var pen := _mesh(CylinderMesh.new(), Vector3.ZERO, Color(0.15, 0.3, 0.75), piv, 0.4); (pen.mesh as CylinderMesh).top_radius = 0.011; (pen.mesh as CylinderMesh).bottom_radius = 0.011; (pen.mesh as CylinderMesh).height = 0.3   # v29 (M5): bigger, bright white emissive body
	(pen.mesh as CylinderMesh).height = 0.15; pen.position = Vector3(0, 0, -0.06); pen.rotation_degrees = Vector3(-90, 0, 0)   # cylinder +Y -> pivot -Z (towards the camera); 5 cm behind the grip, 10 cm out in front
	var tip := _mesh(SphereMesh.new(), Vector3(0, 0.075, 0), Color(1, 0.95, 0.7), pen, 10.0); (tip.mesh as SphereMesh).radius = 0.018; (tip.mesh as SphereMesh).height = 0.036
	var fl := SpotLight3D.new(); fl.light_energy = 0.0; fl.spot_range = 3.0; fl.spot_angle = 25.0; piv.add_child(fl); fl.position = Vector3(0, 0, -0.13)   # light cone along pivot -Z = at the camera
	var glow := OmniLight3D.new(); glow.light_energy = 2.0; glow.omni_range = 0.9; glow.light_color = Color(1, 0.96, 0.85); tip.add_child(glow)
	_set_blur(0.0, 0.0, 0.6)   # v29 (M5): sharp view for the eye check
	# v29 (M5): the doctor steps to the bedside so the hand really reaches the player's eyes (not chest height from 2.5 m away)
	var home_pos := doctor.position; var off0: float = FACE_ME - atan2(cam.position.x - home_pos.x, cam.position.z - home_pos.z)
	var near := Vector3(0.6, 0, -0.65)
	var wt := create_tween(); wt.tween_property(doctor, "position", near, 1.0).set_trans(Tween.TRANS_SINE); doctor.play("walk", 0.2); await wt.finished; doctor.play("idle", 0.2)
	await _doc_face(atan2(cam.position.x - near.x, cam.position.z - near.z) + off0, 0.4)
	var eye := cam.global_position + cam.global_transform.basis.z * -0.25   # 25 cm in front of the player's eyes
	await _doc_arm(_aim_arm(eye), 0.9)
	var m: ShaderMaterial = blur.material
	await ui.line("Can you see the flashlight?", "Doctor", 0.1, "hfc_male")
	for k in 2:
		var x0 := 0.32 if k == 0 else 0.68
		var ft := create_tween(); ft.tween_method(func(f: float): m.set_shader_parameter("flash", f); fl.light_energy = f * 5.0, 0.0, 1.0, 0.25)
		ft.tween_method(func(f: float): m.set_shader_parameter("fpos", Vector2(lerpf(x0 - 0.12, x0 + 0.12, f), 0.47)), 0.0, 1.0, 0.9)
		ft.tween_method(func(f: float): m.set_shader_parameter("flash", f); fl.light_energy = f * 5.0, 1.0, 0.0, 0.3)
		ft.tween_method(func(f: float): m.set_shader_parameter("lid", f), 0.0, 1.0, 0.12); ft.tween_method(func(f: float): m.set_shader_parameter("lid", f), 1.0, 0.0, 0.2)
		await ft.finished
	_doc_arm([0.0, 0.0, 0.0], 0.6); await get_tree().create_timer(0.3).timeout
	piv.queue_free()
	var bt := create_tween(); bt.tween_property(doctor, "position", home_pos, 1.0).set_trans(Tween.TRANS_SINE); doctor.play("walk", 0.2); await bt.finished; doctor.play("idle", 0.2)
	doctor.rotation.y = FACE_ME
	await _set_blur(0.0, 0.0, 2.5)
	await ui.line("Yes, I can see it.", "Me")
	_doc_face(_yaw_to(fam.position))   # v28: doctor turns smoothly to the family member
	var she := String(App.load_save().get("state", {}).get("gender", "men")) == "women"
	await ui.line("Don't worry. She is completely fine." if she else "Don't worry. He is completely fine.", "Doctor", 0.7, "hfc_male")
	await ui.line("The bus driver braked on time.", "Doctor", 0.7, "hfc_male")
	await ui.line("The cat is fine, too.", "Doctor", 0.7, "hfc_male")
	_frame(fam)
	await ui.line("Thank you, doctor!", fam_name, 0.7, fam_voice)
	_frame(doctor); await _doc_face(FACE_ME)   # v28: ...and back to the player
	await ui.line("Can you get up?", "Doctor", 0.7, "hfc_male")
	await ui.line("Yes, I can.", "Me")
	var ct := create_tween(); ct.tween_property(cam, "position", Vector3(0, 1.55, -0.6), 1.6).set_trans(Tween.TRANS_SINE); await ct.finished
	await _snap_bed("hospital")
	# v28: body check (body parts) - the doctor glances at each part, the player answers
	for q in BODY:
		_doc_look(q[2], 0.45)
		await ui.line(q[0], "Doctor", 0.4, "hfc_male")
		await ui.line(q[1], "Me", 0.5)
	_doc_look(0.0, 0.4)
	await ui.line("Good. You are fine. You can go home.", "Doctor", 0.6, "hfc_male")
	await ui.line("You should rest for one full day.", "Doctor", 0.7, "hfc_male")
	_frame(fam)
	await ui.line("Let's go home.", fam_name, 0.7, fam_voice)
	await _snap_bed("fine")
	await _set_blur(0.0, 1.0, 1.2)
	App.came_from = "hospital"
	get_tree().change_scene_to_file("res://main.tscn")

## house.27: first-person look-around after waking: right (monitor) -> left (IV stand, window) -> centre, eased, short holds
func _look_around() -> void:
	_set_blur(1.0, 0.08, 1.2)
	var centre := Vector3(0, 1.3, 1.5)
	for st in [[Vector3(-0.95, 1.4, -1.5), 1.1, 0.6], [Vector3(0.95, 1.35, -0.9), 1.6, 0.6], [Vector3(1.2, 1.6, 2.5), 0.8, 0.5], [centre, 1.0, 0.3]]:
		await _turn_to(st[0], st[1]); await get_tree().create_timer(st[2]).timeout

func _turn_to(target: Vector3, t: float) -> void:
	var q0 := cam.quaternion
	var q1 := Transform3D.IDENTITY.translated(cam.position).looking_at(target, Vector3.UP).basis.get_rotation_quaternion()
	var tw := create_tween(); tw.tween_method(func(k: float): cam.quaternion = q0.slerp(q1, k), 0.0, 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _blink(n: int) -> void:
	var m: ShaderMaterial = blur.material
	for k in n:
		var t := create_tween(); t.tween_method(func(f: float): m.set_shader_parameter("lid", f), 0.0, 1.0, 0.18); t.tween_method(func(f: float): m.set_shader_parameter("lid", f), 1.0, 0.0, 0.35); t.tween_interval(0.4); await t.finished

func _mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.8
	if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
	if c.a < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _mesh(mesh: Mesh, p: Vector3, c: Color, parent: Node = null, emit := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.position = p; mi.material_override = _mat(c, emit); (parent if parent else self).add_child(mi); return mi

func _box(s: Vector3, p: Vector3, c: Color, parent: Node = null, emit := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new(); bm.size = s; return _mesh(bm, p, c, parent, emit)

func _cyl(r: float, h: float, p: Vector3, c: Color, parent: Node = null) -> MeshInstance3D:
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 12; cm.rings = 1; return _mesh(cm, p, c, parent)

## house.27: hospital room built from simple meshes (CC0, made for this project)
func _room() -> void:
	var wall := Color(0.86, 0.92, 0.91); var metal := Color(0.72, 0.74, 0.77)
	_box(Vector3(6, 0.1, 6), Vector3(0, -0.05, 0), Color(0.78, 0.82, 0.8))                 # vinyl floor
	for i in 6: _box(Vector3(6, 0.004, 0.02), Vector3(0, 0.002, -2.5 + i), Color(0.7, 0.74, 0.72))
	_box(Vector3(6, 3, 0.1), Vector3(0, 1.5, 2.6), wall); _box(Vector3(0.1, 3, 6), Vector3(-2.6, 1.5, 0), wall); _box(Vector3(0.1, 3, 6), Vector3(2.6, 1.5, 0), wall)
	_box(Vector3(6, 3, 0.1), Vector3(0, 1.5, -2.6), wall); _box(Vector3(6, 0.1, 6), Vector3(0, 3.0, 0), Color(0.95, 0.96, 0.96))
	_box(Vector3(6, 0.12, 0.02), Vector3(0, 0.06, 2.54), Color(0.4, 0.6, 0.6)); _box(Vector3(6, 0.03, 0.03), Vector3(0, 0.95, 2.54), Color(0.55, 0.75, 0.75))   # skirting + bumper rail
	_box(Vector3(1.2, 0.04, 0.6), Vector3(0, 2.97, 0.3), Color(1, 1, 0.97), null, 1.5)       # ceiling light panel
	# window: sky, frame, mullion, sill, blind
	_box(Vector3(1.6, 1.1, 0.02), Vector3(1.2, 1.65, 2.545), Color(0.55, 0.78, 0.98), null, 0.6)
	for x in [0.38, 1.2, 2.02]: _box(Vector3(0.06, 1.2, 0.06), Vector3(x, 1.65, 2.52), Color(0.95, 0.95, 0.95))
	for y in [1.08, 2.22]: _box(Vector3(1.7, 0.06, 0.06), Vector3(1.2, y, 2.52), Color(0.95, 0.95, 0.95))
	_box(Vector3(1.8, 0.04, 0.16), Vector3(1.2, 1.05, 2.48), Color(0.92, 0.92, 0.9))
	for k in 6: _box(Vector3(1.6, 0.012, 0.04), Vector3(1.2, 2.18 - k * 0.035, 2.49), Color(0.96, 0.96, 0.94))
	_box(Vector3(0.6, 0.5, 0.02), Vector3(1.0, 1.4, 2.56), Color(0.4, 0.6, 0.35), null, 0.3)   # tree outside
	# bed: frame, wheels, mattress, sheets, pillow, rails, head/foot boards
	var bed := Node3D.new(); bed.position = Vector3(0, 0, -1.1); add_child(bed)
	_box(Vector3(1.0, 0.08, 2.1), Vector3(0, 0.4, 0), metal, bed)
	for p in [Vector3(-0.42, 0.2, -0.95), Vector3(0.42, 0.2, -0.95), Vector3(-0.42, 0.2, 0.95), Vector3(0.42, 0.2, 0.95)]:
		_cyl(0.025, 0.36, p, metal, bed); _box(Vector3(0.05, 0.08, 0.08), Vector3(p.x, 0.04, p.z), Color(0.2, 0.2, 0.22), bed)
	_box(Vector3(0.95, 0.16, 2.0), Vector3(0, 0.52, 0), Color(0.96, 0.97, 0.98), bed)
	_box(Vector3(0.98, 0.1, 1.3), Vector3(0, 0.63, 0.32), Color(0.62, 0.8, 0.86), bed)        # blanket
	_box(Vector3(0.99, 0.02, 0.2), Vector3(0, 0.69, -0.3), Color(0.98, 0.98, 1), bed)         # folded sheet
	var pil := _box(Vector3(0.65, 0.12, 0.35), Vector3(0, 0.66, -0.78), Color(1, 1, 1), bed); pil.rotation_degrees.x = -12
	_box(Vector3(1.0, 0.65, 0.05), Vector3(0, 0.75, -1.05), Color(0.9, 0.92, 0.95), bed); _box(Vector3(1.0, 0.4, 0.05), Vector3(0, 0.6, 1.05), Color(0.9, 0.92, 0.95), bed)
	for x in [-0.52, 0.52]:
		for y in [0.68, 0.82]: _box(Vector3(0.025, 0.025, 0.9), Vector3(x, y, -0.35), metal, bed)
		for z in [-0.75, 0.05]: _box(Vector3(0.025, 0.2, 0.025), Vector3(x, 0.72, z), metal, bed)
	# patient monitor on a stand, with heart trace
	var mon := Node3D.new(); mon.position = Vector3(-0.95, 0, -1.7); mon.rotation_degrees.y = 25; add_child(mon)
	_cyl(0.025, 1.3, Vector3(0, 0.65, 0), metal, mon); _box(Vector3(0.45, 0.04, 0.45), Vector3(0, 0.02, 0), Color(0.3, 0.3, 0.32), mon)
	_box(Vector3(0.5, 0.36, 0.1), Vector3(0, 1.45, 0), Color(0.88, 0.88, 0.9), mon)
	_box(Vector3(0.42, 0.27, 0.01), Vector3(0, 1.46, 0.051), Color(0.02, 0.05, 0.06), mon)
	var ys := [0, 0, 0.02, -0.01, 0.07, -0.05, 0, 0, 0.01, 0, 0]
	for k in ys.size(): _box(Vector3(0.036, 0.008, 0.004), Vector3(-0.18 + k * 0.036, 1.5 + ys[k], 0.058), Color(0.2, 1, 0.4), mon, 3.0)
	_box(Vector3(0.12, 0.05, 0.004), Vector3(0.12, 1.39, 0.058), Color(0.3, 0.8, 1), mon, 2.5); _box(Vector3(0.08, 0.04, 0.004), Vector3(-0.13, 1.39, 0.058), Color(1, 0.85, 0.2), mon, 2.5)
	_beep = _box(Vector3(0.025, 0.025, 0.004), Vector3(0.19, 1.57, 0.058), Color(1, 0.2, 0.2), mon, 4.0)
	# IV stand: wheeled base, pole, hooks, bag, tube
	var iv := Node3D.new(); iv.position = Vector3(0.95, 0, -0.9); add_child(iv)
	for a in 5: var leg := _box(Vector3(0.3, 0.03, 0.03), Vector3(cos(a * TAU / 5) * 0.15, 0.06, sin(a * TAU / 5) * 0.15), metal, iv); leg.rotation.y = -a * TAU / 5
	_cyl(0.012, 1.9, Vector3(0, 1.0, 0), metal, iv); _box(Vector3(0.3, 0.012, 0.012), Vector3(0, 1.93, 0), metal, iv)
	var bag := _box(Vector3(0.14, 0.22, 0.04), Vector3(0.1, 1.78, 0), Color(0.85, 0.95, 1.0, 0.7), iv); bag.rotation_degrees.z = 3
	_cyl(0.004, 0.75, Vector3(0.1, 1.3, 0), Color(0.9, 0.95, 1, 0.8), iv)
	# privacy curtain on a ceiling track (pleated panels)
	_box(Vector3(0.04, 0.03, 2.6), Vector3(-1.75, 2.85, 0.2), metal)
	for k in 14:
		var pn := _box(Vector3(0.03, 2.1, 0.2), Vector3(-1.75 + (0.05 if k % 2 == 0 else -0.05), 1.75, -0.9 + k * 0.17), Color(0.55, 0.78, 0.82) if k % 4 < 2 else Color(0.5, 0.72, 0.78))
		pn.rotation_degrees.y = 25 if k % 2 == 0 else -25
	# bedside cabinet with water + chart; door; wall sign; hand sanitiser; oxygen outlet
	_box(Vector3(0.45, 0.7, 0.45), Vector3(-0.85, 0.35, -0.6), Color(0.95, 0.95, 0.93)); _box(Vector3(0.38, 0.02, 0.01), Vector3(-0.85, 0.55, -0.37), metal)
	_cyl(0.035, 0.12, Vector3(-0.8, 0.76, -0.6), Color(0.8, 0.9, 1.0, 0.6))
	_box(Vector3(0.9, 2.1, 0.05), Vector3(-1.4, 1.05, 2.54), Color(0.62, 0.48, 0.36)); _box(Vector3(0.3, 0.4, 0.02), Vector3(-1.4, 1.5, 2.51), Color(0.8, 0.92, 1.0, 0.8))
	_box(Vector3(0.05, 0.04, 0.15), Vector3(-1.1, 1.0, 2.49), metal)
	_box(Vector3(0.4, 0.4, 0.02), Vector3(-0.3, 2.2, 2.54), Color(0.95, 0.95, 0.95)); _box(Vector3(0.24, 0.07, 0.01), Vector3(-0.3, 2.2, 2.53), Color(0.85, 0.2, 0.2)); _box(Vector3(0.07, 0.24, 0.01), Vector3(-0.3, 2.2, 2.525), Color(0.85, 0.2, 0.2))
	_box(Vector3(0.1, 0.2, 0.08), Vector3(-0.85, 1.3, 2.5), Color(0.9, 0.9, 0.95))
	_box(Vector3(1.6, 0.18, 0.08), Vector3(0, 1.55, -2.52), Color(0.85, 0.88, 0.9)); for x in [-0.5, 0.0, 0.5]: _box(Vector3(0.06, 0.06, 0.03), Vector3(x, 1.55, -2.47), Color(0.3, 0.6, 0.3) if x != 0.0 else Color(0.3, 0.4, 0.9))
var _beep: MeshInstance3D
var _bt := 0.0
func _process(d: float) -> void:
	_pen_follow()
	_bt += d
	if _beep: _beep.visible = fmod(_bt, 0.9) < 0.15

## doctor look: long white coat (skirt + lapels over the white top), stethoscope round the neck, name badge
func _dress_doctor() -> void:
	var h := 1.0
	var aabb := AABB()
	for mi in doctor.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb(); a = doctor.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform * a
		aabb = a if aabb.size == Vector3.ZERO else aabb.merge(a)
	if aabb.size.y > 0.5: h = aabb.size.y / 1.75
	h *= 0.9
	doctor.child = false
	var root := Node3D.new(); root.scale = Vector3.ONE * h; doctor.add_child(root)
	var white := Color(0.98, 0.98, 0.98)
	var sk := CylinderMesh.new(); sk.top_radius = 0.19; sk.bottom_radius = 0.25; sk.height = 0.55; sk.radial_segments = 16
	var skirt := _mesh(sk, Vector3(0, 0.78, 0.0), white, root); skirt.scale = Vector3(1.0, 1.0, 0.72)
	var tor := CylinderMesh.new(); tor.top_radius = 0.17; tor.bottom_radius = 0.2; tor.height = 0.36; tor.radial_segments = 16
	var body := _mesh(tor, Vector3(0, 1.16, 0.0), white, root); body.scale = Vector3(1.05, 1.0, 0.7)
	for x in [-0.05, 0.05]: var lp := _box(Vector3(0.05, 0.22, 0.01), Vector3(x, 1.26, 0.142), Color(0.9, 0.9, 0.92), root); lp.rotation_degrees.z = 20 if x < 0 else -20
	_box(Vector3(0.012, 0.5, 0.01), Vector3(0, 0.98, 0.16), Color(0.85, 0.85, 0.88), root)    # coat opening
	var tm := TorusMesh.new(); tm.inner_radius = 0.075; tm.outer_radius = 0.09; tm.rings = 16; tm.ring_segments = 6
	var st := _mesh(tm, Vector3(0, 1.31, 0.06), Color(0.15, 0.2, 0.3), root); st.rotation_degrees.x = 70
	for x in [-0.06, 0.06]: _cyl(0.007, 0.22, Vector3(x, 1.19, 0.15), Color(0.15, 0.2, 0.3), root)
	var chest := _cyl(0.025, 0.012, Vector3(0.06, 1.08, 0.155), Color(0.8, 0.8, 0.85), root); chest.rotation_degrees.x = 90
	_box(Vector3(0.07, 0.04, 0.01), Vector3(-0.1, 1.22, 0.15), Color(0.2, 0.45, 0.85), root)
	_box(Vector3(0.07, 0.08, 0.01), Vector3(0.1, 1.06, 0.15), Color(0.9, 0.9, 0.92), root)     # pocket with pen
	_cyl(0.005, 0.07, Vector3(0.09, 1.1, 0.152), Color(0.2, 0.3, 0.8), root)

## v28: smooth doctor yaw (hand-tuned angles: player / family member)
const FACE_ME := PI + 0.4
## yaw toward a point, calibrated so the camera direction = FACE_ME (hand-tuned)
func _yaw_to(p: Vector3) -> float:
	var d := doctor.position; var off := FACE_ME - atan2(cam.position.x - d.x, cam.position.z - d.z)
	return wrapf(atan2(p.x - d.x, p.z - d.z) + off, FACE_ME - PI, FACE_ME + PI)
func _doc_face(yaw: float, t := 0.7) -> void:
	var tw := create_tween(); tw.tween_property(doctor, "rotation:y", yaw, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

## v28: right-arm pose for the penlight + head glance for the body check (bone offsets, as in bathroom.gd)
const ARM_LIGHT := [-1.4, -0.1, 0.0]
const BODY := [["How are your legs?", "My legs are strong.", 0.55], ["How are your arms?", "My arm hurts a little.", 0.35],
	["How is your chest?", "My chest is okay.", 0.3], ["How are your ears?", "My ears are good.", 0.0], ["How are your eyes?", "My eyes are perfect.", -0.05]]
## v28: two-bone aim - upper arm and forearm both point at the target (player's eyes), offsets in skeleton space
func _aim_arm(target: Vector3) -> Array:
	var sk: Skeleton3D = doctor.skeleton
	var tl: Vector3 = sk.global_transform.affine_inverse() * target
	var u := sk.get_bone_global_pose(sk.find_bone("UpperArm.R")).origin
	var l := sk.get_bone_global_pose(sk.find_bone("LowerArm.R")).origin
	var h := sk.get_bone_global_pose(sk.find_bone("Hand.R")).origin
	var q1 := Quaternion((l - u).normalized(), (tl - u).normalized())
	var l2 := u + q1 * (l - u); var h2 := u + q1 * (h - u)
	var q2 := Quaternion((h2 - l2).normalized(), (tl - l2).normalized())
	return [[q1.get_axis(), q1.get_angle()], [q2.get_axis() if q2.get_angle() > 0.001 else Vector3.RIGHT, q2.get_angle()]]
func _doc_off(bone: String, ax: Vector3, ang: float, t: float) -> void:
	var a0: float = doctor.bone_offsets.get(bone, [ax, 0.0])[1]
	create_tween().tween_method(func(a: float): doctor.bone_offsets[bone] = [ax, a], a0, ang, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
func _doc_arm(p: Array, t: float) -> void:
	if p.size() == 2:   # [[axis, ang] upper, [axis, ang] lower] from _aim_arm
		_doc_off("UpperArm.R", p[0][0], p[0][1], t); _doc_off("LowerArm.R", p[1][0], p[1][1], t)
	else:
		for b in ["UpperArm.R", "LowerArm.R"]:
			var ax: Vector3 = doctor.bone_offsets.get(b, [Vector3.RIGHT, 0.0])[0]; _doc_off(b, ax, 0.0, t)
	await get_tree().create_timer(t + 0.05).timeout
func _doc_look(down: float, t: float) -> void: _doc_off("Head", Vector3.RIGHT, down, t)

## v28: first-person framing - the player's eyes ease toward whoever is speaking (head height)
func _frame(who: Node3D, t := 0.7) -> void:
	if who: _turn_to(who.global_position + Vector3(0, 1.45, 0), t)

## v29 (M4): player body lying in the bed; render layer 2 is hidden from the first-person camera (cull_mask)
var body: DemoCharacter
func _player_body() -> void:
	body = DemoCharacter.new(); add_child(body); body.setup(String(App.load_save().get("state", {}).get("gender", "men")))
	CharacterHook.apply(body, CharacterHook.creator(get_tree()))
	body.play("idle", 0.0); body.position = Vector3(0, 0.62, -0.15); body.rotation = Vector3(-PI / 2, 0, 0)
	for n in body.find_children("*", "VisualInstance3D", true, false): (n as VisualInstance3D).layers = 2
	cam.cull_mask = 1

## v29 (M4): polaroid from an offscreen camera at the bedside so the player (in the bed) is in the photo
func _snap_bed(key: String) -> void:
	var xf := Transform3D.IDENTITY.translated(Vector3(1.5, 1.85, 0.2)).looking_at(Vector3(-0.1, 0.65, -1.2), Vector3.UP)
	await Life.snap_from(key, xf, 55.0)

## v29 (M5): penlight pivot at the Hand.R grip (between thumb and fingers), unit scale, -Z looking at the camera (player's eyes)
const PEN_GRIP := Vector3(0.0, 0.075, -0.035)   # bone-frame offset in metres (bathroom.gd uses the same frame for held props)
var _pen_piv: Node3D
func _pen_follow(dbg := false) -> void:
	if not is_instance_valid(_pen_piv): return
	var h: Node3D = doctor._hand["R"]
	var hb: Basis = h.global_transform.basis
	var p: Vector3 = h.global_position + hb.orthonormalized() * PEN_GRIP
	p += (cam.global_position - p).normalized() * 0.11   # 11 cm out of the hand toward the camera (was 4 cm) so the glowing tip clears the back of the hand in first person
	if dbg: print("PEN hand global_scale=", hb.get_scale(), " hand_pos=", h.global_position, " grip=", p, " cam=", cam.global_position)
	var to := cam.global_position - p
	if to.length() > 0.05: _pen_piv.global_transform = Transform3D(Basis.looking_at(to, Vector3.UP), p)
	else: _pen_piv.global_position = p

## v306: story.hospital_day2_done (or the v30.5 key day2_hospital_done) -> just the clear room + one line, then home
func _day2_exam_done() -> bool:
	var st = App.load_save().get("story", {})
	return st is Dictionary and (bool(st.get("hospital_day2_done", false)) or bool(st.get("day2_hospital_done", false)))
func _already_seen() -> void:
	S.tr = App.tr_saved(); ui.tr_l.visible = S.tr
	var m: ShaderMaterial = blur.material; m.set_shader_parameter("amount", 0.0); m.set_shader_parameter("dark", 0.0); m.set_shader_parameter("lid", 0.0)
	cam.cull_mask = 0xFFFFF; cam.fov = 55.0
	if fam: fam.visible = false
	cam.global_transform = Transform3D.IDENTITY.translated(Vector3(1.6, 1.6, 1.8)).looking_at(Vector3(0, 0.8, -0.3), Vector3.UP)
	await get_tree().create_timer(0.6).timeout
	await ui.line("You already saw the doctor.")
	await get_tree().create_timer(1.0).timeout
	App.came_from = ""; App.continue_requested = true
	get_tree().change_scene_to_file("res://main.tscn")
