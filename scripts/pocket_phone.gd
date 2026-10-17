## v13 PocketPhone: reusable "phone lives in the pocket" component for every room.
## use(): hand to the front trouser pocket -> phone appears in the hand, raised in front of the chest ->
## camera zooms onto it -> phone UI opens (zooming out of the phone's screen) -> on close: UI closes,
## camera zooms back out, phone goes back into the pocket (disappears).
## Needs a character with bone_offsets {bone: [axis, angle]}, hold_item(path, kind, size, left), release_item(), play(anim)
## (DemoCharacter / 3dv2 hero) and a Camera3D.
## API (matches world_dev/SHARED_UI.md "Pocket phone hook"):
##   await pp.take_out(player, camera)   # pocket -> hand -> chest, camera zooms onto the phone
##   ... open the phone UI (screen_rect() = where the phone is on screen), wait until closed ...
##   await pp.put_away(player, camera)   # camera zooms back out, phone back into the pocket
##   await pp.use()                      # all of it, with open_ui: Callable(Rect2) awaited in the middle
## Camera: CameraRig take_over()/release() when present, else set_camera: Callable(shot {} | {"pos","at"}),
## else the Camera3D is tweened directly (its _process paused meanwhile).
## `player` may be the character itself or a node holding it in `character`/`hero`/`model`.
extends Node

signal stage(name: String)          # "take_out", "in_hand", "zoomed", "ui_open", "ui_closed", "put_away", "pocketed"
var character: Node3D
var camera: Camera3D
var set_camera: Callable
var open_ui: Callable
var item_scene := "res://props/phone.tscn"
var left_hand := false
var busy := false
var current := ""
var _saved_xf: Transform3D
## v14 natural one-handed hold: an arm IK pose (applied after the character's animation/bone_offsets) puts the
## phone upright in portrait at chest / lower-face height, screen facing the face, palm + fingers behind it.
var hold_w := 0.0                   # 0 = animation pose, 1 = full phone-hold pose (tweened in/out)
const HOLD_WRIST := Vector3(0.12, 0.03, 0.25)   # wrist target from the Chest bone (x = outwards), metres at arm length 0.37
const PHONE_CURL_CANCEL := 0.52     # softer than the character's generic 0.75 rad curl: fingers wrap the far edge of the phone

func _init() -> void:
	process_priority = 200          # after DemoCharacter (100) so the IK pose is applied on top

func _process(_d: float) -> void:
	if hold_w > 0.001 and is_instance_valid(character) and "skeleton" in character and character.skeleton:
		_apply_hold(character.skeleton, hold_w)

func _gq(sk: Skeleton3D, i: int) -> Quaternion:
	return sk.get_bone_global_pose(i).basis.orthonormalized().get_rotation_quaternion()

func _set_global_rot(sk: Skeleton3D, i: int, q: Quaternion, w: float) -> void:
	var par := sk.get_bone_parent(i)
	var loc := _gq(sk, par).inverse() * q
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(loc.normalized(), w))

## target hand basis in skeleton space (character faces +Z): fingers up, palm (-Z) towards the face, phone tilted back
func _hand_basis(out: float) -> Basis:
	var n := Vector3(-out * 0.15, 0.62, -1.0).normalized()         # screen normal: back + up towards the eyes, slightly inwards
	var f := Vector3(-out, -0.05, 0.0); f = (f - n * f.dot(n)).normalized()   # fingers run inwards across the back of the phone
	var z := -n
	return Basis(f.cross(z), f, z).orthonormalized()

func _apply_hold(sk: Skeleton3D, w: float) -> void:
	var s := "L" if left_hand else "R"
	var ua := sk.find_bone("UpperArm." + s); var la := sk.find_bone("LowerArm." + s); var hd := sk.find_bone("Hand." + s)
	var ch := sk.find_bone("Chest")
	if ua < 0 or la < 0 or hd < 0 or ch < 0: return
	var out := 1.0 if left_hand else -1.0
	var S := sk.get_bone_global_pose(ua).origin; var E := sk.get_bone_global_pose(la).origin; var W := sk.get_bone_global_pose(hd).origin
	var a := S.distance_to(E); var b := E.distance_to(W); var L := a + b
	var k := L / 0.37
	var T := sk.get_bone_global_pose(ch).origin + Vector3(HOLD_WRIST.x * out, HOLD_WRIST.y, HOLD_WRIST.z) * k
	var d := clampf(S.distance_to(T), absf(a - b) + 0.001, L * 0.995)
	var u := (T - S).normalized()
	var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var pole := Vector3(out * 0.45, -1.0, -0.35); pole = (pole - u * pole.dot(u)).normalized()   # elbow down, out, a bit back
	var E2 := S + u * a * ca + pole * a * sqrt(1.0 - ca * ca)
	_set_global_rot(sk, ua, Quaternion((E - S).normalized(), (E2 - S).normalized()) * _gq(sk, ua), w)
	E = sk.get_bone_global_pose(la).origin; W = sk.get_bone_global_pose(hd).origin
	_set_global_rot(sk, la, Quaternion((W - E).normalized(), (S + u * d - E).normalized()) * _gq(sk, la), w)
	_set_global_rot(sk, hd, _hand_basis(out).get_rotation_quaternion(), w)
	if character.get("held") != null:
		var cc: float = PHONE_CURL_CANCEL + (0.45 if character.get("gender") == "women" else 0.0)   # women's fingers rest more curled
		for i in character._finger_bones.get(s, []):
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, cc * w))

## v14: the phone lies across the palm (long axis along the thumb line, so it stands upright in portrait when the
## fingers point inwards), back against the palm/fingers, screen facing out of the palm side (towards the face)
func _place_phone() -> void:
	var pv := phone_node()
	if pv == null or pv == _fallback or not ("skeleton" in character) or character.skeleton == null: return
	var sk: Skeleton3D = character.skeleton
	var s := "L" if left_hand else "R"
	var hd := sk.find_bone("Hand." + s); var la := sk.find_bone("LowerArm." + s)
	var k := 1.0
	if hd >= 0 and la >= 0: k = sk.get_bone_global_rest(hd).origin.distance_to(sk.get_bone_global_rest(la).origin) / 0.235
	pv.transform = Transform3D(Basis(Vector3.UP, Vector3(0, 0, -1), Vector3(-1, 0, 0)), Vector3((-0.026 if left_hand else 0.026) * k, 0.12 * k, -0.034 * k))

func _arm(pose: Dictionary, t: float) -> void:
	var s := "L" if left_hand else "R"
	var tw := create_tween().set_parallel(true)
	for b in pose:
		var bone: String = b + "." + s
		var ax: Vector3 = pose[b][0]; var ang: float = pose[b][1]
		var cur: float = character.bone_offsets[bone][1] if character.bone_offsets.has(bone) else 0.0
		tw.tween_method(func(a): character.bone_offsets[bone] = [ax, a], cur, ang, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _st(n: String) -> void:
	current = n; stage.emit(n)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

var _rig := false
var _p := Vector3.ZERO
var _fallback: Node3D

func _shot(shot: Dictionary, t: float) -> void:
	if set_camera.is_valid():
		set_camera.call(shot); await _wait(t)
		if not shot.is_empty() and camera:   # wait until a smoothed camera has arrived (max 2 s)
			var n := 0
			while camera.global_position.distance_to(shot.pos) > 0.12 and n < 40: await _wait(0.05); n += 1
		return
	if camera == null: return
	if shot.is_empty():
		var tw := create_tween(); tw.tween_property(camera, "global_transform", _saved_xf, t).set_trans(Tween.TRANS_SINE)
		await tw.finished
		if _rig: camera.release()
		else: camera.set_process(true)
		return
	_saved_xf = camera.global_transform
	_rig = camera.has_method("take_over") and camera.has_method("release")
	if _rig: camera.take_over()
	else: camera.set_process(false)
	var xf := Transform3D(Basis(), shot.pos).looking_at(shot.at, Vector3.UP)
	var tw2 := create_tween(); tw2.tween_property(camera, "global_transform", xf, t).set_trans(Tween.TRANS_SINE)
	await tw2.finished

func screen_rect() -> Rect2:
	if camera == null: return Rect2()
	var r := Rect2(camera.unproject_position(_p), Vector2.ZERO)
	for d in [Vector3(0.05, 0.08, 0), Vector3(-0.05, -0.08, 0), Vector3(0, 0.08, 0.05), Vector3(0, -0.08, -0.05)]:
		r = r.expand(camera.unproject_position(_p + d))
	return r

func _resolve(player) -> void:
	if player == null: return
	var c = player
	for k in ["character", "hero", "model"]:
		if not c.has_method("hold_item") and k in player and player.get(k) is Node3D: c = player.get(k)
	character = c

func _hold() -> void:
	if character.has_method("hold_item") and ResourceLoader.exists(item_scene): character.hold_item(item_scene, "flat", 0.15, left_hand); return
	_fallback = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.075, 0.15, 0.012); _fallback.mesh = bm
	character.add_child(_fallback); _fallback.position = Vector3(0.12 if not left_hand else -0.12, 1.15, 0.3)

func _release() -> void:
	if is_instance_valid(_fallback): _fallback.queue_free(); _fallback = null
	elif character.has_method("release_item"): character.release_item()

func phone_node() -> Node3D:
	if is_instance_valid(_fallback): return _fallback
	return character.find_child("HeldItem", true, false) as Node3D

func _arm_ok() -> bool: return "bone_offsets" in character

func take_out(player = null, cam: Camera3D = null) -> void:
	if player: _resolve(player)
	if cam: camera = cam
	if busy or character == null: return
	busy = true
	if character.has_method("play"): character.play("idle", 0.25)
	_st("take_out")   # 1) hand to the front trouser pocket
	if _arm_ok(): await _arm({"UpperArm": [Vector3.RIGHT, 0.25], "LowerArm": [Vector3.RIGHT, -0.35]}, 0.45)
	_hold(); _place_phone(); _st("in_hand")
	# 2) raise it in front of the chest: blend into the phone-hold IK pose while the pocket reach fades out
	if _arm_ok():
		var tw := create_tween(); tw.tween_property(self, "hold_w", 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _arm({"UpperArm": [Vector3.RIGHT, 0.0], "LowerArm": [Vector3.RIGHT, 0.0]}, 0.75)
	await _wait(0.12)
	# 3) camera zooms onto the phone: from the outer side, a bit above, so the screen, the hand and the face are in view
	var pn := phone_node()
	_p = pn.global_position if pn else character.global_position + Vector3(0, 1.2, 0)
	if camera:
		await _shot(zoom_shot(), 0.9)
	_st("zoomed")
	await _wait(0.4)   # beat on the phone in the hand before the UI fades in

## camera shot framing the held phone: outer side of the holding hand, looking at the screen at ~40 deg
func zoom_shot() -> Dictionary:
	var pn := phone_node()
	var P: Vector3 = pn.global_position if pn else _p
	var bz := character.global_transform.basis
	var fwd := bz.z; fwd.y = 0; fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.BACK
	var side := bz.x.normalized() * (1.0 if left_hand else -1.0)
	var nrm := (pn.global_transform.basis * Vector3.UP).normalized() if pn and pn != _fallback else -fwd
	var dir := (nrm * 0.65 + side * 0.85 + Vector3.UP * 0.3).normalized()
	return {"pos": P + dir * 0.42, "at": P + Vector3(0, 0.01, 0)}

func put_away(player = null, cam: Camera3D = null) -> void:
	if character == null: busy = false; return
	_st("ui_closed")
	await _shot({}, 0.8)   # zoom back out
	_st("put_away")
	if _arm_ok():
		var tw := create_tween(); tw.tween_property(self, "hold_w", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _arm({"UpperArm": [Vector3.RIGHT, 0.25], "LowerArm": [Vector3.RIGHT, -0.35]}, 0.6)
	hold_w = 0.0
	_release()
	if _arm_ok():
		await _arm({"UpperArm": [Vector3.RIGHT, 0.0], "LowerArm": [Vector3.RIGHT, 0.0]}, 0.4)
		for s in ["UpperArm", "LowerArm"]: character.bone_offsets.erase(s + "." + ("L" if left_hand else "R"))
	_st("pocketed")
	busy = false

func use() -> void:
	if busy: return
	await take_out()
	_st("ui_open")
	if open_ui.is_valid(): await open_ui.call(screen_rect())
	await put_away()
