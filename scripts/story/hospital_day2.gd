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
	_fit_to_bed("Hips")   # v33 (red): a child sits on the bed, not in it

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
	StoryUI.hide_all(get_tree())   # v33 (red): the work summary's "Now I'm going to the hospital." box lives on the root; never a 2nd box here
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
	# v32-polish: day 2, hospital first -> straight on to work (the same work flow the car starts); hospital second -> home as before
	var sv = App.load_save().get("story", {})
	if not (sv is Dictionary and bool(sv.get("day2_work_done", false))) and maxi(WorldState.day, App.day) == 2:
		await ui.line(_go_line())   # v33 (red): "Now I'm going to school." for pupils / teachers (the work summary then says "I went to school.")
		load("res://scripts/story/work_summary.gd").play(get_tree())
		return
	if maxi(WorldState.day, App.day) == 2:   # v32-polish: both visits done -> outside beside the car on the home lot (not inside the house)
		App.came_from = "outside"; Game.go_to(Game.WORLD_SCENE, "home_car"); return
	if next_scene != "": get_tree().change_scene_to_file(next_scene)

## v33 (red): the day-2 destination after the hospital in the job's own words (work.json label: Go to work / school / shopping)
func _go_line() -> String:
	var st := CharacterHook.state()
	var lbl: String = load("res://scripts/story/work.gd").car_label(String(st.get("job", "")), CharacterHook.is_child(st))
	if ChildDrive.active(): return ChildDrive.drive_line(ChildDrive.place_of("work"))   # v33: child "My mom is driving me to school."
	return {"Go to school": "Now I'm going to school.", "Go shopping": "Now I'm going shopping."}.get(lbl, "Now I'm going to work.")

## ---- third-person camera + body-part close-ups on the PLAYER's skeleton
const RECAP := ["legs", "arms", "chest", "ears", "eyes"]
const PARTS := {   # word: [TR, bone candidates, close-up distance, side offset]
	"legs": ["bacaklar", ["UpperLeg.L", "LowerLeg.L"], 0.9], "arms": ["kollar", ["LowerArm.L", "UpperArm.L"], 0.8],
	"chest": ["göğüs", ["Chest", "Torso"], 0.75], "ears": ["kulaklar", ["Head"], 0.45], "eyes": ["gözler", ["Head"], 0.4],
	"head": ["baş", ["Head"], 0.6], "neck": ["boyun", ["Neck"], 0.5], "shoulders": ["omuzlar", ["Shoulder.L", "UpperArm.L"], 0.7],
	"back": ["sırt", ["Torso", "Chest"], 0.8], "stomach": ["karın", ["Abdomen", "Torso"], 0.7], "hands and fingers": ["eller ve parmaklar", ["Hand.L"], 0.45],
	"knees": ["dizler", ["LowerLeg.L", "Knee.L", "Shin.L"], 0.6], "feet": ["ayaklar", ["Foot.L"], 0.6], "mouth and teeth": ["ağız ve dişler", ["Head"], 0.4], "nose": ["burun", ["Head"], 0.4]}
## v33 (red): close-up framing per part: [distance m, elevation, side (toward the player's left = the camera side)]
const FRAME := {
	"legs": [1.0, 0.8, 0.45], "arms": [0.8, 0.3, 0.9], "chest": [0.75, 0.2, 0.3], "ears": [0.5, 0.08, 1.0], "eyes": [0.45, 0.08, 0.25],
	"head": [0.6, 0.35, 0.3], "neck": [0.55, 0.08, 0.35], "shoulders": [0.8, 0.5, 0.35], "back": [0.85, 0.4, 0.35],
	"stomach": [0.75, 0.75, 0.3], "hands and fingers": [0.6, 0.7, 0.4], "knees": [0.75, 0.3, 0.0], "feet": [0.85, 0.12, 0.0],   # v33: straight in front, low - the bed rail / mattress edge hid them from above (child legs hang higher)
	
	"mouth and teeth": [0.45, 0.0, 0.2], "nose": [0.45, 0.06, 0.3]}
## v33 (red): pixel-safe close-ups - the arrow tip sits on the part at the frame centre, and the camera distance is the
## smallest that keeps every point of the part's FIT set inside the safe area (below the part label, above the caption box)
const FIT := {   # word: [[bone, up offset in m at scale 1], ...]
	"head": [["Head", -0.02], ["Head", 0.42]], "neck": [["Neck", -0.06], ["Head", 0.42]], "ears": [["Head", 0.0], ["Head", 0.34]],
	"eyes": [["Head", 0.02], ["Head", 0.34]], "nose": [["Head", 0.0], ["Head", 0.3]], "mouth and teeth": [["Head", -0.03], ["Head", 0.26]],
	"shoulders": [["UpperArm.L", 0.05], ["UpperArm.R", 0.05], ["Neck", 0.0]], "chest": [["Chest", 0.0], ["UpperArm.L", 0.0], ["UpperArm.R", 0.0]],
	"back": [["Chest", 0.1], ["Hips", 0.0]], "stomach": [["Abdomen", 0.0], ["Hips", 0.0], ["Torso", 0.0]],
	"hands and fingers": [["Hand.L", -0.08], ["Hand.L", 0.08], ["LowerArm.L", 0.0]], "arms": [["UpperArm.L", 0.0], ["Hand.L", 0.0]],
	"legs": [["UpperLeg.L", 0.0], ["Foot.L", 0.0], ["UpperLeg.R", 0.0]], "knees": [["LowerLeg.L", 0.08], ["LowerLeg.R", 0.08]],
	"feet": [["Foot.L", -0.05], ["Foot.R", -0.05], ["Foot.L", 0.1]]}
func _k() -> float: return float(body.model.scale.y) if body and body.model else 1.0
func _bone_pos(bn: String):
	var sk: Skeleton3D = body.skeleton
	var i := sk.find_bone(bn)
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else null
func _fit_dist(word: String, p: Vector3, dir: Vector3, d: float) -> float:
	var vs := get_viewport().get_visible_rect().size
	var tv := tan(deg_to_rad(cam.fov) * 0.5); var th := tv * vs.x / maxf(1.0, vs.y)
	var z := dir; var x := Vector3.UP.cross(z).normalized(); var y := z.cross(x)
	var need := d
	for e in FIT.get(word, []):
		var q = _bone_pos(String(e[0]))
		if q == null: continue
		var o: Vector3 = (q as Vector3) + Vector3(0, float(e[1]) * _k(), 0) - p
		# safe area: 50 % of the half height (part label on top, caption box at the bottom), 75 % of the half width
		need = maxf(need, o.dot(z) + absf(o.dot(y)) / (tv * 0.5) + 0.02)
		need = maxf(need, o.dot(z) + absf(o.dot(x)) / (th * 0.75) + 0.02)
	return minf(need, d * 2.5)
func _yaw_between(from: Vector3, to: Vector3) -> float: return atan2(to.x - from.x, to.z - from.z) + MODEL_YAW
func _part_pos(word: String) -> Vector3:
	var sk: Skeleton3D = body.skeleton
	var p: Vector3 = body.global_position + Vector3(0, 0.8, 0)
	for bn in PARTS[word][1]:
		var i := sk.find_bone(bn)
		if i >= 0: p = sk.global_transform * sk.get_bone_global_pose(i).origin; break
	if word in ["ears", "eyes", "nose", "mouth and teeth", "head"]: p += Vector3(0, {"ears": 0.08, "eyes": 0.1, "nose": 0.075, "mouth and teeth": 0.04, "head": 0.16}[word] * _k(), 0)   # v306: tuned for the close-ups (v33: x body scale)
	if word == "knees":
		var i := sk.find_bone(PARTS[word][1][0]); if i >= 0: p = sk.global_transform * sk.get_bone_global_pose(i).origin
	return p
func _cam_to(pos: Vector3, look: Vector3, t: float) -> void:
	var x1 := Transform3D.IDENTITY.translated(pos).looking_at(look, Vector3.UP)
	if t <= 0.0: cam.global_transform = x1; return
	var x0 := cam.global_transform
	# v33 (red): never fly THROUGH the player (front -> back close-up, nose -> wide): detour round the camera side
	var wp = _detour(x0.origin, pos)
	if wp is Vector3:
		var xm := Transform3D.IDENTITY.translated(wp).looking_at(look, Vector3.UP)
		var t1 := create_tween(); t1.tween_method(func(k: float): cam.global_transform = x0.interpolate_with(xm, k), 0.0, 1.0, t * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t1.finished
		x0 = xm
		var t2 := create_tween(); t2.tween_method(func(k: float): cam.global_transform = x0.interpolate_with(x1, k), 0.0, 1.0, t * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await t2.finished
		return
	var tw := create_tween(); tw.tween_method(func(k: float): cam.global_transform = x0.interpolate_with(x1, k), 0.0, 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
## v33 (red): a waypoint beside the player when the straight camera move passes within 0.3 m of the body axis (hips -> head)
func _detour(a: Vector3, b: Vector3):
	var sk: Skeleton3D = body.skeleton
	var hi := sk.find_bone("Hips"); var he := sk.find_bone("Head")
	if hi < 0 or he < 0: return null
	var h0: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
	var h1: Vector3 = sk.global_transform * sk.get_bone_global_pose(he).origin + Vector3(0, 0.1, 0)
	var near := 9.0
	for i in range(1, 12):
		var q := a.lerp(b, i / 12.0)
		near = minf(near, q.distance_to(Geometry3D.get_closest_point_to_segment(q, h0, h1)))
	if near > 0.3: return null
	var fwd := (doctor.global_position - body.global_position); fwd.y = 0; fwd = fwd.normalized()
	var cam_side := -fwd.cross(Vector3.UP)   # the player's left (+X): the close-up camera side, away from the bedside cabinet
	return (h0 + h1) * 0.5 + cam_side * 1.1 + Vector3(0, 0.25, 0)
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
	var fr: Array = FRAME[word]
	var d: float = float(fr[0]) * _k()   # v33 (red): child / short / tall bodies: framing scales with the body
	if word == "back": fwd = -fwd   # the doctor looks at the back from behind
	if word == "ears": p += -side * 0.075 * _k()   # v306: the ear on the camera side
	_show_label(word)
	_set_iv_visible(word != "back")   # v31.1: the IV stand sits between the camera and the player's back
	doctor.visible = false   # v306: the close camera sits where the doctor stands; never film his side
	# v33 (red): the v306 framing (0.6 x distance, almost level) put the camera INSIDE the thigh / knee / forearm and so
	# close to the head that the sit_idle sway turned "mouth and teeth" / "ears" into shots of the hair. Per-part distance,
	# elevation (look down past the thighs at the stomach, hands, knees, feet; past the bed rail at the feet) and side.
	var dir: Vector3 = (fwd - side * float(fr[2]) + Vector3(0, float(fr[1]), 0)).normalized()
	d = _fit_dist(word, p, dir, d)   # v33 (red): back off until the whole part (+ context, e.g. the head for "neck") is in frame
	var cp: Vector3 = p + dir * d
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

