## Bathroom extras (black bot): (3) bathroom scale, (4) medicine cabinet + taking medicine, (5) make-up at the mirror.
## Loaded by bathroom.gd (HOOKS.md): setup(main). Own save: user://bk_bathroom.json. Own voice bank: data/bk_voice_index.json + voice/bk_voice.bin
## (tools/bk_build_voice.py). QA: godot --path . --rendering-driver opengl3 -- --qa-bk  (screens/bk_*.png, bk_qa.log)
extends Node

const P := "res://props/bathroom/"
## English -> Turkish (actions: present continuous, no subject pronoun in the Turkish). Voice built from this table.
const LINES := {
	"I am going to the scale.": "Tartıya gidiyorum.",
	"I am weighing myself.": "Kendimi tartıyorum.",
	"I am stepping on the scale.": "Tartıya çıkıyorum.",
	"I am stepping off the scale.": "Tartıdan iniyorum.",
	"I am taking my medicine.": "İlacımı alıyorum.",
	"I am taking a pill.": "Bir hap alıyorum.",
	"I am putting the medicine back.": "İlacı geri koyuyorum.",
	"I am drinking water.": "Su içiyorum.",
	"I am going to the mirror.": "Aynaya gidiyorum.",
	"I am doing my make-up.": "Makyaj yapıyorum.",
	"I am putting on blush.": "Allık sürüyorum.",
	"I am putting on eyeshadow.": "Far sürüyorum.",
	"I am putting on lipstick.": "Ruj sürüyorum.",
	"I look nice!": "Güzel görünüyorum!",
	"I am taking off my make-up.": "Makyajımı siliyorum.",
}
const W_MIN := 18
const W_MAX := 112

var m          # bathroom main
var mk := {"blush": 0.0, "lip": 0.0, "shadow": 0.0}
var mk_mat: ShaderMaterial
var scale_lbl: Label3D
var pill_bottle: Node3D
var tray := {}
var SC := Vector3(-1.15, 0, 0.45)       # scale centre
const SCALE_TOP := 0.031

func setup(main) -> void:
	m = main
	var tr := LINES.duplicate()
	for n in range(W_MIN, W_MAX + 1): tr["I weigh %d kilos." % n] = "%d kilo geliyorum." % n
	m.add_translations(tr)
	m.add_voice_bank("res://data/bk_voice_index.json", "res://voice/bk_voice.bin")
	_load()
	_build_scale(); _build_cabinet(); _build_makeup_tray(); _setup_makeup()
	if "--qa-bk" in OS.get_cmdline_user_args():
		var q = load("res://scripts/bk_qa.gd").new(); add_child(q); q.run(m, self)

# ------------------------------------------------------------ save
func _load() -> void:
	if FileAccess.file_exists("user://bk_bathroom.json") and not "--qa-bk" in OS.get_cmdline_user_args():
		var d = JSON.parse_string(FileAccess.get_file_as_string("user://bk_bathroom.json"))
		if d is Dictionary and d.get("makeup") is Dictionary:
			for k in mk: mk[k] = float(d.makeup.get(k, 0.0))

func _save() -> void:
	var f := FileAccess.open("user://bk_bathroom.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"makeup": mk}))
	f = null
	if has_node("/root/Game"): Game.refresh_character(m.S)   # house.29: live look refresh (blue MERGE_GUIDE §4)

# ------------------------------------------------------------ (3) scale
## plausible body weight (kg) from the character creator: sex, build, height, child/adult
func weight_kg() -> int:
	var S: Dictionary = m.S
	var men: bool = S.get("gender", "men") == "men"
	var w: float
	if S.get("age", "adult") == "child":
		w = 30.0 + {"thin": -5.0, "average": 0.0, "fat": 8.0}.get(S.get("build", "average"), 0.0) + {"short": -5.0, "medium": 0.0, "tall": 5.0}.get(S.get("height", "medium"), 0.0)
	else:
		w = (76.0 if men else 63.0) + {"thin": -11.0 if men else -9.0, "average": 0.0, "fat": 22.0 if men else 18.0}.get(S.get("build", "average"), 0.0) \
			+ {"short": -7.0 if men else -6.0, "medium": 0.0, "tall": 8.0 if men else 7.0}.get(S.get("height", "medium"), 0.0)
	return clampi(int(round(w)), W_MIN, W_MAX)

func _build_scale() -> void:
	if m.N.has("scale"): m.N.scale.visible = false
	if m.N.has("scale_display"): m.N.scale_display.visible = false
	var root := Node3D.new(); root.name = "BkScale"; root.position = SC; m.add_child(root)
	m.box(Vector3(0.36, 0.022, 0.38), Vector3(0, 0.011, 0), Color(0.93, 0.93, 0.94), root)
	m.box(Vector3(0.34, 0.008, 0.36), Vector3(0, 0.026, 0), Color(0.97, 0.98, 0.99), root)
	for sx in [-0.16, 0.16]:
		for sz in [-0.17, 0.17]: m.box(Vector3(0.02, 0.003, 0.02), Vector3(sx, 0.0015, sz), Color(0.3, 0.3, 0.32), root)
	m.box(Vector3(0.11, 0.003, 0.045), Vector3(0, SCALE_TOP, -0.15), Color(0.12, 0.13, 0.15), root)
	scale_lbl = Label3D.new(); scale_lbl.text = ""; scale_lbl.font_size = 56; scale_lbl.pixel_size = 0.0007
	scale_lbl.modulate = Color(0.55, 0.92, 1.0); scale_lbl.outline_size = 0; scale_lbl.font = m.font_b
	scale_lbl.rotation = Vector3(-PI / 2, 0, 0)   # house.18: flat, top of the digits away from the player/camera (reads upright)
	scale_lbl.position = Vector3(0, SCALE_TOP + 0.0025, -0.15); root.add_child(scale_lbl)
	m.add_obstacle(SC.x - 0.18, SC.z - 0.19, SC.x + 0.18, SC.z + 0.19)
	m.register_interactable("scale", "scale", SC + Vector3(0, 0.1, 0), Vector3(SC.x, 0, SC.z + 0.55), Vector3(0, 0, -1),
		func(): return [["Weigh myself", "I am weighing myself.", "weigh"]], _scale_action)

func _scale_action(_key: String, _v: Array) -> void:
	var h = m.hero
	m.cam_shot = {"pos": Vector3(SC.x + 0.7, 1.45, SC.z - 1.05), "at": Vector3(SC.x, 0.3, SC.z - 0.05)}
	await m.caption("I am weighing myself.")
	await m.wait(1.2)
	# step up: short walk onto the platform, lifted by the platform height
	var dest := Vector3(SC.x, SCALE_TOP, SC.z + 0.05)
	m.no_steps = true   # house.18: scripted steps play their own sounds (no stale footstep loop)
	h.player.speed_scale = 1.0; h.play("walk", 0.2, 0.8)
	var tw: Tween = m.create_tween(); tw.tween_property(h, "position", dest, 0.75).set_trans(Tween.TRANS_SINE)
	Audio.sfx("footstep01", -8.0); await m.wait(0.4); Audio.sfx("footstep02", -8.0); await m.wait(0.35)
	h.play("idle", 0.3); Audio.sfx("metalClick", -10.0, 1.6)
	m._tw_offset("Neck", Vector3.RIGHT, 0.35, 0.5)
	# display counts up and settles
	var kg := weight_kg()
	for i in 10:
		scale_lbl.text = "%d" % int(lerpf(0.0, float(kg), ease(float(i) / 9.0, 0.4)) + randi_range(-2, 2) * (1 if i < 8 else 0))
		await m.wait(0.09)
	scale_lbl.text = "%d kg" % kg; Audio.sfx("metalClick", -6.0, 2.0)
	m.action_peak.emit("scale")
	await m.wait(0.6)
	await m.caption("I weigh %d kilos." % kg)
	await m.wait(2.6)
	m._tw_offset("Neck", Vector3.RIGHT, 0.0, 0.4)
	# step off backwards
	h.play("walk", 0.2, -0.7)
	tw = m.create_tween(); tw.tween_property(h, "position", Vector3(SC.x, 0, SC.z + 0.55), 0.8).set_trans(Tween.TRANS_SINE)
	Audio.sfx("footstep00", -8.0); await m.wait(0.8); h.position.y = 0.0
	h.player.speed_scale = 1.0; h.play("idle", 0.3)
	await m.wait(0.35); m.step_state["ph"] = 1.0; m.no_steps = false
	await m.wait(1.5); scale_lbl.text = ""

# ------------------------------------------------------------ (4) medicine cabinet
func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D: return m.box(size, pos, c)

func _build_cabinet() -> void:
	var RX: float = m.RX; var cz := 0.75; var cy := 1.55
	var CAB: Color = m.CAB
	if m.N.has("cabinet"): m.N.cabinet.visible = false
	# hollow carcass instead of the solid block, so the contents show when the door is open
	_box(Vector3(0.015, 0.55, 0.5), Vector3(RX - 0.0075, cy, cz), CAB.darkened(0.04))                 # back
	_box(Vector3(0.18, 0.015, 0.5), Vector3(RX - 0.09, cy + 0.2675, cz), CAB)                         # top
	_box(Vector3(0.18, 0.045, 0.5), Vector3(RX - 0.09, cy - 0.2525, cz), CAB)                        # bottom (top face y 1.32)
	for sz in [-0.2425, 0.2425]: _box(Vector3(0.18, 0.55, 0.015), Vector3(RX - 0.09, cy, cz + sz), CAB)
	_box(Vector3(0.165, 0.012, 0.47), Vector3(RX - 0.0975, 1.706, cz), CAB.darkened(0.06))         # extra top shelf (top face 1.712)
	var W := Color(0.97, 0.97, 0.96); var BLU := Color(0.33, 0.52, 0.78); var GRN := Color(0.42, 0.66, 0.55); var RED := Color(0.85, 0.3, 0.3)
	# --- top compartment (1.712 .. 1.81): blister packs, boxes with a red cross, small tub
	for i in 3: _blister(Vector3(RX - 0.1, 1.712 + 0.004 + i * 0.008, 0.585), i)
	for i in 2:
		var z := 0.705 + i * 0.12
		_box(Vector3(0.12, 0.085, 0.1), Vector3(RX - 0.09, 1.712 + 0.0425, z), W)
		_box(Vector3(0.002, 0.018, 0.1), Vector3(RX - 0.151, 1.712 + 0.065, z), [BLU, GRN][i])
		_box(Vector3(0.002, 0.034, 0.01), Vector3(RX - 0.151, 1.712 + 0.03, z), RED); _box(Vector3(0.002, 0.01, 0.034), Vector3(RX - 0.151, 1.712 + 0.03, z), RED)
	m.cyl(0.032, 0.045, Vector3(RX - 0.09, 1.712 + 0.0225, 0.935), Color(0.95, 0.93, 0.88))
	m.cyl(0.034, 0.012, Vector3(RX - 0.09, 1.712 + 0.051, 0.935), BLU)
	# --- middle (on the 1.555 shelf): the player's pill bottle + a slim box
	pill_bottle = (load(P + "bk_pill_bottle.tscn") as PackedScene).instantiate(); m.add_child(pill_bottle)
	pill_bottle.position = Vector3(RX - 0.12, 1.556, 0.94)
	_box(Vector3(0.1, 0.11, 0.045), Vector3(RX - 0.09, 1.556 + 0.055, 0.54), W)
	_box(Vector3(0.002, 0.11, 0.045), Vector3(RX - 0.141, 1.556 + 0.055, 0.54), Color(0.95, 0.75, 0.3)).scale.y = 0.25
	# --- bottom (1.32): tall box, a stack of blister packs, a tube
	_box(Vector3(0.09, 0.15, 0.045), Vector3(RX - 0.09, 1.32 + 0.075, 0.54), Color(0.93, 0.95, 0.97))
	_box(Vector3(0.002, 0.03, 0.045), Vector3(RX - 0.136, 1.32 + 0.11, 0.54), GRN)
	for i in 4: _blister(Vector3(RX - 0.1, 1.32 + 0.004 + i * 0.008, 0.945), i + 3)
	var tube: MeshInstance3D = m.cyl(0.012, 0.11, Vector3(RX - 0.14, 1.32 + 0.012, 0.75), Color(0.95, 0.95, 0.97)); tube.rotation.x = PI / 2
	m.cyl(0.008, 0.02, Vector3(RX - 0.14, 1.32 + 0.012, 0.815), BLU).rotation.x = PI / 2
	m.register_interactable("cabinet", "cabinet", Vector3(RX - 0.1, cy, cz), Vector3(RX - 0.53, 0, cz), Vector3(1, 0, 0), _cab_verbs, _cab_action)

func _blister(pos: Vector3, seed: int) -> void:
	var n := Node3D.new(); n.position = pos; n.rotation.y = (seed % 3 - 1) * 0.08; m.add_child(n)
	m.box(Vector3(0.1, 0.002, 0.055), Vector3.ZERO, Color(0.8, 0.82, 0.86), n).material_override = m._chrome()
	m.box(Vector3(0.1, 0.0015, 0.055), Vector3(0, -0.0018, 0), [Color(0.95, 0.95, 0.97), Color(0.9, 0.93, 1.0), Color(1, 0.95, 0.9)][seed % 3], n)
	for ix in 4:
		for iz in 2:
			var b := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.007; sm.height = 0.006; sm.radial_segments = 8; sm.rings = 3
			b.mesh = sm; b.position = Vector3(-0.036 + ix * 0.024, 0.0015, -0.013 + iz * 0.026); b.material_override = m._mat(Color(0.96, 0.97, 1.0), 0.0, 0.7); n.add_child(b)

func _cab_verbs() -> Array:
	var t: Array = [["Close", "I am closing the cabinet.", "toggle"]] if m.S.cabinet == "open" else [["Open", "I am opening the cabinet.", "toggle"]]
	t.append(["Take my medicine", "I am taking my medicine.", "medicine"])
	return t

func _cab_shot() -> void:
	m.cam_shot = {"pos": Vector3(0.55, 1.95, 1.75), "at": Vector3(1.95, 1.35, 0.72)}

## arm poses on top of idle (found by a hand-position search in bk_qa --bk-pose): [UpperArm.R, LowerArm.R] about the model X axis
const ARM_HIGH := [-1.4, -0.6]     # forward + up to the wall cabinet (y ~1.55)
const ARM_LOW := [-0.7, -0.3]      # forward to the counter
const ARM_MOUTH := [-1.05, -1.8, 0.85]  # hand (cup / pill / lipstick) at the mouth
const ARM_CHEEK := [-1.2, -1.6, 0.8]   # brush at the cheeks / eyes

func _arm(p: Array, t: float) -> void:
	m._tw_offset("UpperArm.R", Vector3.RIGHT, p[0], t); m._tw_offset("LowerArm.R", Vector3.RIGHT, p[1], t)
	m._tw_offset("Shoulder.R", Vector3.UP, p[2] if p.size() > 2 else 0.0, t)

func _idle_now() -> void:
	m.hero.player.speed_scale = 1.0; m.hero.play("idle", 0.3)

## reach out with the right hand, call change at the peak, come back
func _reach(p: Array, id: String, change: Callable) -> void:
	_idle_now(); _arm(p, 0.6); await m.wait(0.65)
	change.call(); m._apply_states(true); m.action_peak.emit(id); await m.wait(0.35)
	_arm([0.0, 0.0], 0.55); await m.wait(0.6)

func _cab_toggle(open: bool) -> void:
	if (m.S.cabinet == "open") == open: return
	await m.caption("I am opening the cabinet." if open else "I am closing the cabinet.")
	await _reach(ARM_HIGH, "cabinet", func(): m.S.cabinet = "open" if open else "closed"; Audio.sfx("drawer", -3.0, 1.1))

func _cab_action(key: String, v: Array) -> void:
	_cab_shot()
	if key == "toggle":
		await _cab_toggle(m.S.cabinet != "open"); return
	var h = m.hero
	await m.caption("I am taking my medicine."); await m.wait(1.4)
	await _cab_toggle(true)
	await _reach(ARM_HIGH, "cabinet", func(): pill_bottle.visible = false; h.hold_item(P + "bk_pill_bottle.tscn", "cylinder", 0.095, false); Audio.sfx("metalClick", -8.0, 1.4))
	# shake one pill out: bottle up in front of the chest, tip it, a pill lands in the fingers
	await m.caption("I am taking a pill.")
	_arm(ARM_LOW, 0.5); await m.wait(0.55)
	m._tw_offset("Hand.R", Vector3.FORWARD, 0.6, 0.25); Audio.sfx("metalClick", -14.0, 2.4); await m.wait(0.35)
	m._tw_offset("Hand.R", Vector3.FORWARD, 0.0, 0.25); await m.wait(0.3)
	_arm([0.0, 0.0], 0.4); await m.wait(0.45)
	await m.caption("I am putting the medicine back.")
	await _reach(ARM_HIGH, "cabinet", func(): h.release_item(); pill_bottle.visible = true; _pill(); Audio.sfx("metalClick", -8.0, 1.4))
	await _cab_toggle(false)
	await m.caption("I am taking a pill.")
	m.cam_shot = {"pos": Vector3(2.2, 1.8, 1.72), "at": Vector3(1.68, 1.42, 0.66)}
	_arm(ARM_MOUTH, 0.7); await m.wait(0.9); m.action_peak.emit("medicine")
	_free_pill(); m._tw_offset("Neck", Vector3.RIGHT, -0.15, 0.25); await m.wait(0.5)
	m._tw_offset("Neck", Vector3.RIGHT, 0.0, 0.3); _arm([0.0, 0.0], 0.6); await m.wait(0.6)
	# water from the cup at the sink
	await m.caption("I am going to the sink.")
	await m.walk_to(m.OBJ.sink.spot, m.OBJ.sink.yaw); m._sink_shot()
	await m.caption("I am drinking water.")
	await m.gesture("sink", "sink", func(): m.N.cup.visible = false; h.hold_item(P + "Cup.tscn", "cylinder", 0.1, false); Audio.sfx("metalClick", -10.0))
	m.S.tap = "on"; m._apply_states(true); Audio.sfx("metalClick"); Audio.sfx("water", -6.0)
	await m._lean_basin(); await m.wait(0.9); await m._straighten(); _idle_now()
	m.S.tap = "off"; m._apply_states(true); Audio.sfx("metalClick")
	_arm(ARM_MOUTH, 0.8); await m.wait(0.7); m._tw_offset("Neck", Vector3.RIGHT, -0.25, 0.5); m.action_peak.emit("drink")
	Audio.sfx("water", -10.0, 1.6); await m.wait(1.5)
	m._tw_offset("Neck", Vector3.RIGHT, 0.0, 0.4); _arm([0.0, 0.0], 0.7); await m.wait(0.7)
	await m.gesture("sink", "sink", func(): h.release_item(); m.N.cup.visible = true; Audio.sfx("metalClick", -10.0))

var pill_node: Node3D
## a small white pill pinched at the right fingertips
func _pill() -> void:
	var mi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.006; cm.height = 0.02; cm.radial_segments = 10; cm.rings = 2
	mi.mesh = cm; mi.material_override = m._mat(Color(0.98, 0.97, 0.94))
	var hl := 0.14 if m.hero.gender == "men" else 0.11
	mi.position = Vector3(0, hl * 0.92, -0.02); mi.rotation.z = PI / 2
	m.hero._hand["R"].add_child(mi); pill_node = mi

func _free_pill() -> void:
	if pill_node: pill_node.queue_free(); pill_node = null

# ------------------------------------------------------------ (5) make-up
const MIRROR_SPOT := Vector3(-0.68, 0, -0.97)

func _build_makeup_tray() -> void:
	var y: float = m.TOP_Y; var BZ: float = m.BZ
	var c := Vector3(-0.78, y, BZ + 0.44)
	m.box(Vector3(0.12, 0.008, 0.08), c + Vector3(0, 0.004, 0), Color(0.92, 0.86, 0.8))
	tray.lipstick = (load(P + "bk_lipstick.tscn") as PackedScene).instantiate(); m.add_child(tray.lipstick)
	tray.lipstick.position = c + Vector3(-0.035, 0.008, 0.012)
	tray.brush = (load(P + "bk_blush_brush.tscn") as PackedScene).instantiate(); m.add_child(tray.brush)
	tray.brush.position = c + Vector3(0.05, 0.0125, -0.012); tray.brush.rotation = Vector3(0, -0.15, PI / 2)
	m.cyl(0.022, 0.01, c + Vector3(0.0, 0.013, 0.022), Color(0.2, 0.2, 0.22))                  # blush compact
	m.cyl(0.018, 0.002, c + Vector3(0.0, 0.0185, 0.022), Color(0.9, 0.5, 0.52))
	tray.pads = Node3D.new(); m.add_child(tray.pads)
	for i in 3: m.cyl(0.02, 0.005, c + Vector3(-0.035, 0.011 + i * 0.006, -0.022), Color(0.99, 0.99, 0.98), tray.pads)
	m.register_interactable("mirror", "mirror", Vector3(-0.68, 1.3, BZ + 0.1), MIRROR_SPOT, Vector3(0, 0, -1), _mk_verbs, _mk_action)

func _mk_verbs() -> Array:
	var t := [["Do my make-up", "I am doing my make-up.", "makeup"]]
	if mk.blush + mk.lip + mk.shadow > 0.01: t.append(["Take off my make-up", "I am taking off my make-up.", "remove"])
	t.append(["Look in the mirror", "I am looking in the mirror.", "look"])
	return t

## bake the rest-pose position of every head-mesh vertex into CUSTOM0 so the overlay shader can paint face zones per pixel
func _setup_makeup() -> void:
	mk_mat = ShaderMaterial.new(); mk_mat.shader = load("res://scripts/bk_makeup.gdshader")
	if m.hero.gender == "women": mk_mat.set_shader_parameter("eye_y", 1.690); mk_mat.set_shader_parameter("eye_x", 0.042)
	for key in m.hero._meshes:
		if not String(key).contains("_Head__"): continue
		var mi: MeshInstance3D = m.hero._meshes[key]
		var src: ArrayMesh = mi.mesh
		var out := ArrayMesh.new()
		for i in src.get_surface_count():
			var a := src.surface_get_arrays(i)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var mat := src.surface_get_material(i)
			var skin := 1.0 if (mat and mat.resource_name.begins_with("Skin")) else 0.0
			var cu := PackedFloat32Array(); cu.resize(v.size() * 4)
			for j in v.size():
				cu[j * 4] = v[j].x; cu[j * 4 + 1] = v[j].y; cu[j * 4 + 2] = v[j].z; cu[j * 4 + 3] = skin
			a[Mesh.ARRAY_CUSTOM0] = cu
			var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.add_surface_from_arrays(src.surface_get_primitive_type(i), a, [], {}, fl)
			out.surface_set_material(i, mat); out.surface_set_name(i, src.surface_get_name(i))
		mi.mesh = out
		mi.material_overlay = mk_mat
	_apply_mk()

func _apply_mk() -> void:
	for k in mk: mk_mat.set_shader_parameter(k, mk[k])

func _tw_mk(k: String, to: float, t: float) -> void:
	m.create_tween().tween_method(func(x): mk[k] = x; _apply_mk(), mk[k], to, t)

func _mk_shot() -> void:
	m.cam_shot = {"pos": Vector3(MIRROR_SPOT.x + 0.85, 1.72, MIRROR_SPOT.z + 0.75), "at": Vector3(MIRROR_SPOT.x - 0.05, 1.42, MIRROR_SPOT.z - 0.35)}

func _strokes(n: int, amp: float, k: String, to: float) -> void:
	_tw_mk(k, to, n * 0.22)
	for i in n:
		m._tw_offset("Hand.R", Vector3.UP, amp * 1.6 if i % 2 == 0 else -amp * 1.6, 0.2)
		if i % 3 == 0: Audio.sfx("cloth1", -16.0, 2.4)
		await m.wait(0.22)
	m._tw_offset("Hand.R", Vector3.UP, 0.0, 0.15)

func _mk_action(key: String, v: Array) -> void:
	var h = m.hero
	_mk_shot()
	if key == "look":
		await m.caption(v[1]); await m.wait(2.2)
		if mk.lip > 0.5: await m.caption("I look nice!"); h.player.play("wave", 0.3); await m.wait(1.3); h.play("idle", 0.3)
		await m.wait(0.6); return
	if key == "remove":
		await m.caption("I am taking off my make-up.")
		await _reach(ARM_LOW, "mirror", func(): h.hold_item(P + "bk_cotton_pad.tscn", "flat", 0.05, false); Audio.sfx("cloth1", -10.0))
		_arm(ARM_CHEEK, 0.7); await m.wait(0.75)
		_tw_mk("blush", 0.0, 2.4); _tw_mk("lip", 0.0, 2.4); _tw_mk("shadow", 0.0, 2.4)
		for i in 10:
			m._tw_offset("Hand.R", Vector3.UP, 0.35 if i % 2 == 0 else -0.35, 0.22); await m.wait(0.24)
		m._tw_offset("Hand.R", Vector3.UP, 0.0, 0.15); _arm([0.0, 0.0], 0.6); await m.wait(0.6)
		await _reach(ARM_LOW, "mirror", func(): h.release_item())
		_save(); await m.caption("My face is clean."); await m.wait(1.8); return
	await m.caption("I am doing my make-up."); await m.wait(1.6)
	# brush: blush, then eyeshadow
	await _reach(ARM_LOW, "mirror", func(): tray.brush.visible = false; h.hold_item(P + "bk_blush_brush.tscn", "long", 0.14, false); Audio.sfx("metalClick", -12.0, 1.5))
	await m.caption("I am putting on blush.")
	_arm(ARM_CHEEK, 0.7); await m.wait(0.75); m.action_peak.emit("blush")
	await _strokes(8, 0.3, "blush", 1.0)
	await m.caption("I am putting on eyeshadow.")
	_arm([ARM_CHEEK[0] - 0.12, ARM_CHEEK[1] - 0.05, ARM_CHEEK[2] - 0.15], 0.3); await m.wait(0.3)
	await _strokes(7, 0.16, "shadow", 1.0)
	_arm([0.0, 0.0], 0.6); await m.wait(0.6)
	await _reach(ARM_LOW, "mirror", _swap_to_lipstick)
	await m.caption("I am putting on lipstick.")
	_arm(ARM_MOUTH, 0.7); await m.wait(0.75)
	await _strokes(6, 0.12, "lip", 1.0)
	_arm([0.0, 0.0], 0.6); await m.wait(0.6)
	await _reach(ARM_LOW, "mirror", func(): h.release_item(); tray.lipstick.visible = true; Audio.sfx("metalClick", -12.0, 1.8))
	_save()
	await m.caption("I look nice!"); h.player.play("wave", 0.3); await m.wait(1.4); h.play("idle", 0.3); await m.wait(0.8)

func _swap_to_lipstick() -> void:
	m.hero.release_item(); tray.brush.visible = true; tray.lipstick.visible = false
	m.hero.hold_item(P + "bk_lipstick.tscn", "cylinder", 0.063, false); Audio.sfx("metalClick", -12.0, 1.8)

# ------------------------------------------------------------ QA hook for qa_bathroom.gd
func qa(main) -> bool:
	var q = load("res://scripts/bk_qa.gd").new(); add_child(q)
	return await q.run(main, self, false)
