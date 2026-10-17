## v31: day-2 hospital visit (player chose 'hospital' at the car on day 2). Same room as day 1 (hospital.gd), but a clear,
## face-to-face check-up: no blur, the player sits on the bed edge facing the doctor; coat (DoctorCoat.dress), 
## third-person camera with zoomed body-part close-ups, questions on OTHER body parts, then a 3-version body + can/should test on
## the phone (phone.gd universal test rules: notebook once, retake, study tip, continue regardless).
## Entry: HospitalScene.start_day2_visit(get_tree())  (static, in hospital.gd)  -> res://scenes/hospital_day2.tscn
extends "res://scripts/story/hospital.gd"

signal visit_finished(score: int, total: int)
const DOC_POS := Vector3(0.05, 0, 0.55)      # doctor stands in front of the bed edge
const CAM_SEAT := Vector3(0.0, 1.25, -0.3)   # player's eyes, sitting up on the bed edge
const MODEL_YAW := 0.13                       # character model yaw quirk (FACE_ME calibration from day 1)
var next_scene := "res://main.tscn"
const BODY2 := [
	["How is your head?", "My head is okay.", "head"], ["How is your neck?", "My neck is all right.", "neck"],
	["How are your shoulders?", "My shoulders are strong.", "shoulders"], ["How is your back?", "My back hurts a little.", "back"],
	["How is your stomach?", "My stomach is not hurting.", "stomach"], ["Show me your hands and fingers.", "My hands and fingers are perfect.", "hands and fingers"],
	["How are your knees?", "My knees are healthy.", "knees"], ["How are your feet?", "My feet are great.", "feet"],
	["Open your mouth, please. Your teeth look good.", "I brush my teeth every day.", "mouth and teeth"], ["How is your nose?", "My nose is good.", "nose"]]

## the player sits on the bed edge (third person: visible)
func _player_body() -> void:
	super._player_body()
	body.rotation = Vector3(0, 0, 0); body.position = Vector3(0, 0.2, -0.45); body.play("sit_idle", 0.0)

func set_tr(on: bool) -> void:
	S.tr = on
	if ui: ui.tr_l.visible = on
	if _lbl_tr: _lbl_tr.visible = on

func caption(t: String, _speak := true) -> void:
	super.caption(t, _speak)
	if ui: ui.tr_l.visible = S.tr

func _face_yaw(from: Vector3) -> float: return atan2(cam.global_position.x - from.x, cam.global_position.z - from.z) + MODEL_YAW

func _say_doc(t: String, p := 0.5) -> void:
	await ui.line(t, "Doctor", p, "hfc_male")
func _say_me(t: String, p := 0.5) -> void:
	await ui.line(t, "Me", p)

func _run() -> void:
	S.tr = App.tr_saved(); set_tr(S.tr)   # English by default; Turkish line only when the player's TR setting is on
	var m: ShaderMaterial = blur.material; _ba = 0.0; m.set_shader_parameter("amount", 0.0); m.set_shader_parameter("lid", 0.0)
	# third person: the player's body is visible (day 1 hid it on layer 2)
	cam.cull_mask = 0xFFFFF; cam.fov = 50.0
	fam.visible = false   # day 2: the player came alone
	doctor.position = DOC_POS; doctor.rotation.y = _yaw_between(DOC_POS, body.global_position); doctor.play("idle", 0.0)
	_mk_label()
	await get_tree().process_frame
	_wide(0.0)
	var sk: Skeleton3D = body.skeleton
	var names := []; for i in sk.get_bone_count(): names.append(sk.get_bone_name(i))
	print("D2 bones: ", names)
	await _set_blur(0.0, 0.0, 1.0)
	Life.event("hospital")
	await _say_doc("Hello again! How are you today?")
	await _say_me("I am fine, thank you.")
	await _say_doc("Yesterday we checked your legs, arms, chest, ears and eyes.")
	for k in RECAP: await _zoom_part(k, 1.1)
	await _wide(0.8)
	await _say_doc("Today I want to check other parts of your body.")
	for q in BODY2:
		_zoom_part(q[2], -1.0)
		await _say_doc(q[0], 0.3)
		await _say_me(q[1], 0.3)
	_hide_label(); _set_iv_visible(true); await _wide(0.9)
	await _say_doc("Your back hurts a little. You should not carry heavy bags.")
	await _say_doc("You are healthy. Well done! Now a short quiz on your phone.")
	ui.hide_caption()
	# ---- body parts + can/should test (phone.gd: notebook prompt once, 3 versions, retake, study tip, continue)
	var data: Dictionary = App.load_json("res://data/body_day2.json")
	phone.visible = true; phone.open(Rect2(), "home"); await get_tree().create_timer(0.5).timeout
	phone.start_set(data, "lesson")
	var res = await phone.quiz_done
	await phone.close(true)
	await Audio.wait_idle(15.0)
	_story_save("day2_hospital_score", [res[0], res[1]])
	_story_save("day2_hospital_done", true)   # v30.5: the car never offers the hospital again
	_story_save("hospital_day2_done", true)   # v306: no exam ever again (hospital.gd _ready checks it on every entry)
	await _say_doc("Good job! Take care of your body. See you soon!", 0.8)
	await _say_me("Thank you, doctor. Goodbye!", 0.8)
	visit_finished.emit(res[0], res[1])
	await _set_blur(0.0, 1.0, 1.2)
	App.came_from = "hospital_day2"; App.continue_requested = true
	if next_scene != "": get_tree().change_scene_to_file(next_scene)

## ---- third-person camera + body-part close-ups on the PLAYER's skeleton
const RECAP := ["legs", "arms", "chest", "ears", "eyes"]
const PARTS := {   # word: [TR, bone candidates, close-up distance, side offset]
	"legs": ["bacaklar", ["UpperLeg.L", "LowerLeg.L"], 0.9], "arms": ["kollar", ["LowerArm.L", "UpperArm.L"], 0.8],
	"chest": ["göğüs", ["Chest", "Torso"], 0.75], "ears": ["kulaklar", ["Head"], 0.45], "eyes": ["gözler", ["Head"], 0.4],
	"head": ["baş", ["Head"], 0.6], "neck": ["boyun", ["Neck"], 0.5], "shoulders": ["omuzlar", ["Shoulder.L", "UpperArm.L"], 0.7],
	"back": ["sırt", ["Torso", "Chest"], 0.8], "stomach": ["karın", ["Abdomen", "Torso"], 0.7], "hands and fingers": ["eller ve parmaklar", ["Hand.L"], 0.45],
	"knees": ["dizler", ["LowerLeg.L", "Knee.L", "Shin.L"], 0.6], "feet": ["ayaklar", ["Foot.L"], 0.6], "mouth and teeth": ["ağız ve dişler", ["Head"], 0.4], "nose": ["burun", ["Head"], 0.4]}
func _yaw_between(from: Vector3, to: Vector3) -> float: return atan2(to.x - from.x, to.z - from.z) + MODEL_YAW
func _part_pos(word: String) -> Vector3:
	var sk: Skeleton3D = body.skeleton
	var p: Vector3 = body.global_position + Vector3(0, 0.8, 0)
	for bn in PARTS[word][1]:
		var i := sk.find_bone(bn)
		if i >= 0: p = sk.global_transform * sk.get_bone_global_pose(i).origin; break
	if word in ["ears", "eyes", "nose", "mouth and teeth", "head"]: p += Vector3(0, {"ears": 0.08, "eyes": 0.1, "nose": 0.075, "mouth and teeth": 0.04, "head": 0.16}[word], 0)   # v306: tuned for the close-ups
	if word == "knees":
		var i := sk.find_bone(PARTS[word][1][0]); if i >= 0: p = sk.global_transform * sk.get_bone_global_pose(i).origin
	return p
func _cam_to(pos: Vector3, look: Vector3, t: float) -> void:
	var x1 := Transform3D.IDENTITY.translated(pos).looking_at(look, Vector3.UP)
	if t <= 0.0: cam.global_transform = x1; return
	var x0 := cam.global_transform
	var tw := create_tween(); tw.tween_method(func(k: float): cam.global_transform = x0.interpolate_with(x1, k), 0.0, 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
## wide shot: three-quarter view from the room corner, player on the bed edge (left) and doctor facing them (right)
func _wide(t: float) -> void:
	_arrow_show(false); if doctor: doctor.visible = true   # v306
	var mid := (body.global_position + doctor.global_position) * 0.5
	await _cam_to(mid + Vector3(1.9, 1.5, 0.3), mid + Vector3(0, 0.85, 0), t)
## close-up of a part: camera eases in from the doctor's side (in front of the player), label shown; hold<0 = stay until the next call
## v306: MUCH closer (the part fills most of the frame), front three-quarter (never a side view), red bobbing arrow on the part
func _zoom_part(word: String, hold: float) -> void:
	_arrow_show(false)
	var p := _part_pos(word)
	var fwd := (doctor.global_position - body.global_position); fwd.y = 0; fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	var d: float = PARTS[word][2] * 0.6
	if word == "back": fwd = -fwd   # the doctor looks at the back from behind
	if word == "ears": p += -side * 0.075   # v306: the ear on the camera side
	_show_label(word)
	_set_iv_visible(word != "back")   # v31.1: the IV stand sits between the camera and the player's back
	doctor.visible = false   # v306: the close camera sits where the doctor stands; never film his side
	var cp := p + fwd * d * 0.92 - side * d * 0.3 + Vector3(0, d * 0.12, 0)
	await _cam_to(cp, p, 0.7)
	_arrow_at(p, cp, d)
	if hold > 0.0: await get_tree().create_timer(hold).timeout; _hide_label()

## v306: red 3D arrow (no depth test, unshaded, two primitives) pointing at the named part, bobbing; hidden between parts
var _arrow: Node3D
var _arrow_tip := Vector3.ZERO
var _arrow_dir := Vector3.DOWN
var _arrow_len := 0.1
func _arrow_at(part: Vector3, cam_pos: Vector3, d: float) -> void:
	if _arrow == null:
		_arrow = Node3D.new(); _arrow.name = "PartArrow"; add_child(_arrow)
		var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.1, 0.1); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true; m.render_priority = 10
		var sh := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.09; cy.bottom_radius = 0.09; cy.height = 0.6; cy.radial_segments = 10
		sh.mesh = cy; sh.position = Vector3(0, 0.7, 0); sh.material_override = m; _arrow.add_child(sh)
		var hd := MeshInstance3D.new(); var cn := CylinderMesh.new(); cn.top_radius = 0.22; cn.bottom_radius = 0.0; cn.height = 0.4; cn.radial_segments = 12
		hd.mesh = cn; hd.position = Vector3(0, 0.2, 0); hd.material_override = m; _arrow.add_child(hd)
		for c in _arrow.get_children(): (c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var to_cam := (cam_pos - part).normalized()
	var right := to_cam.cross(Vector3.UP).normalized()
	_arrow_dir = (Vector3.UP * 0.8 + right * 0.6).normalized()   # arrow comes from the upper side of the frame
	_arrow_len = d * 0.32
	_arrow_tip = part + to_cam * d * 0.15
	_arrow_show(true)
func _arrow_show(on: bool) -> void:
	if _arrow: _arrow.visible = on
func _process(dt: float) -> void:
	super._process(dt)
	if _arrow and _arrow.visible:   # v306: tip on the part, shaft along _arrow_dir, slight bob
		var bob := (0.06 + 0.06 * sin(Time.get_ticks_msec() * 0.008)) * _arrow_len
		var y := _arrow_dir; var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.99 else Vector3.RIGHT).normalized(); var z := x.cross(y)
		_arrow.global_transform = Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3.ONE * _arrow_len), _arrow_tip + _arrow_dir * bob)

var _lbl: PanelContainer; var _lbl_en: Label; var _lbl_tr: Label
func _set_iv_visible(on: bool) -> void:
	for c in get_children():
		if c is Node3D and not (c is MeshInstance3D) and (c as Node3D).position.is_equal_approx(Vector3(0.95, 0, -0.9)): (c as Node3D).visible = on
## v31.1: clear the notebook prompt caption once the quiz starts
func phone_event(a: String) -> void:
	if a == "quiz": caption("")
func _mk_label() -> void:
	var cl := CanvasLayer.new(); cl.layer = 35; add_child(cl)
	_lbl = PanelContainer.new(); var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.92); sb.set_corner_radius_all(16); sb.set_content_margin_all(12); sb.content_margin_left = 28; sb.content_margin_right = 28
	_lbl.add_theme_stylebox_override("panel", sb); _lbl.anchor_left = 0.5; _lbl.anchor_right = 0.5; _lbl.offset_left = -200; _lbl.offset_right = 200; _lbl.offset_top = 40; cl.add_child(_lbl)
	var v := VBoxContainer.new(); _lbl.add_child(v)
	_lbl_en = Label.new(); _lbl_en.name = "PartWord"; _lbl_en.add_theme_font_size_override("font_size", 44); _lbl_en.add_theme_color_override("font_color", Color(0.12, 0.2, 0.5)); _lbl_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_lbl_en)
	if UI.font_b: _lbl_en.add_theme_font_override("font", UI.font_b)
	_lbl_tr = Label.new(); _lbl_tr.add_theme_font_size_override("font_size", 22); _lbl_tr.add_theme_color_override("font_color", Color(0.35, 0.45, 0.7)); _lbl_tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(_lbl_tr)
	_lbl.visible = false; _lbl.name = "PartLabel"; Objectives.ovl_register(_lbl, 9)   # v306: shared no-overlap UI queue (caption 10 stays put)
func _show_label(word: String) -> void:
	_lbl_en.text = word; _lbl_tr.text = PARTS[word][0]; _lbl_tr.visible = S.tr; _lbl.visible = true
func _hide_label() -> void:
	_arrow_show(false)   # v306
	if _lbl: _lbl.visible = false

func _story_save(k: String, v) -> void:
	var st = App.load_save().get("story", {})
	st = st.duplicate() if st is Dictionary else {}
	st[k] = v; App.patch_save({"story": st})

