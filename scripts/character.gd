## Casual Quaternius character (man or woman) with outfit options, build and height presets,
## a shared retargeted AnimationLibrary and palm-side item gripping.
##   set_outfit_part("Body", 2)   set_build("thin"|"average"|"fat")   set_height("short"|"medium"|"tall")
##   hold_item(scene_path, item_kind, left_hand)   release_item()   play("walk")
class_name DemoCharacter
extends Node3D

const LOOPING := ["idle", "walk", "run", "crouch_idle", "crouch_walk", "sit_idle", "sprint", "talk",
	"phone_call", "typing", "dance", "sleep", "fall", "climb_ladder", "hug"]
const SLOTS := ["Head", "Body", "Legs", "Feet"]
const BUILDS := ["thin", "average", "fat"]
const HEIGHTS := {"short": 0.92, "medium": 1.0, "tall": 1.08}
const PARTS_SCENES := {"men": "res://characters/men_parts.glb", "women": "res://characters/women_parts.glb"}
const LIB_SCENES := {"men": "res://characters/men_library.glb", "women": "res://characters/women_library.glb"}
## Three modern-casual options per slot. "recolor": material-name prefix -> colour.
const OUTFITS := {
	"men": {
		"Head": [{"mesh": "Casual2_Head", "label": "Short hair", "len": 0}, {"mesh": "Casual_Head", "label": "Medium hair", "len": 1},
			{"mesh": "Casual_Head", "label": "Long hair", "len": 2}],
		"Body": [{"mesh": "Casual2_Body", "label": "Sand T-shirt"}, {"mesh": "Casual_Body", "label": "Purple hoodie"},
			{"mesh": "Casual2_Body", "label": "Navy T-shirt", "recolor": {"LightBrown": Color(0.08, 0.11, 0.24)}}],
		"Legs": [{"mesh": "Casual2_Legs", "label": "Blue jeans"}, {"mesh": "Casual_Legs", "label": "Denim shorts"},
			{"mesh": "Suit_Legs", "label": "Khaki chinos", "recolor": {"Suit": Color(0.62, 0.54, 0.38)}}],
		"Feet": [{"mesh": "Casual2_Feet", "label": "Red sneakers"},
			{"mesh": "Casual_Feet", "label": "Grey sneakers", "recolor": {"Purple": Color(0.3, 0.31, 0.34)}},
			{"mesh": "Suit_Feet", "label": "Black shoes"}],
	},
	"women": {
		"Head": [{"mesh": "Suit_Head", "label": "Short hair", "len": 0}, {"mesh": "Casual_Head", "label": "Medium hair", "len": 1},
			{"mesh": "Casual_Head", "label": "Long hair", "len": 2}],
		"Body": [{"mesh": "Casual_Body", "label": "White T-shirt"},
			{"mesh": "Casual_Body", "label": "Teal T-shirt", "recolor": {"White": Color(0.2, 0.55, 0.56)}},
			{"mesh": "Suit_Body", "label": "Black top"}],
		"Legs": [{"mesh": "Casual_Legs", "label": "Rust trousers"},
			{"mesh": "Casual_Legs", "label": "Blue jeans", "recolor": {"Orange": Color(0.22, 0.33, 0.52)}},
			{"mesh": "Suit_Legs", "label": "Black trousers"}],
		"Feet": [{"mesh": "Casual_Feet", "label": "Grey flats"}, {"mesh": "Suit_Feet", "label": "Black shoes"},
			{"mesh": "Punk_Feet", "label": "Boots"}],
	},
}
static var _libs := {}

var gender := ""
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var build := "average"
var height := "medium"
var outfit := {"Head": 0, "Body": 0, "Legs": 0, "Feet": 0}
## mannequin: faceless, neutral grey base clothes (tee, shorts, plain shoes). Not nude.
var mannequin := false
const MANNEQUIN_MESH := {"men": {"Head": "Casual2_Head", "Body": "Casual2_Body", "Legs": "Casual_Legs", "Feet": "Casual_Feet"},
	"women": {"Head": "Casual_Head", "Body": "Casual_Body", "Legs": "Casual_Legs", "Feet": "Casual_Feet"}}
const MANNEQUIN_COL := {"skin": Color(0.80, 0.78, 0.75), "Body": Color(0.58, 0.59, 0.61), "Legs": Color(0.40, 0.41, 0.44), "Feet": Color(0.30, 0.31, 0.33)}
const SKIN_TONES := [Color(0.98, 0.84, 0.72), Color(0.87, 0.67, 0.50), Color(0.68, 0.47, 0.32), Color(0.42, 0.28, 0.19)]
var skin := -1     # index into SKIN_TONES, -1 = model default
## house.21: creator hair colours (Black, Brown, Blonde, Red, White)
const HAIR_NAMES := ["Black", "Brown", "Blonde", "Red", "White"]
const HAIR_TONES := [Color(0.06, 0.05, 0.05), Color(0.33, 0.2, 0.11), Color(0.88, 0.72, 0.4), Color(0.62, 0.2, 0.08), Color(0.9, 0.9, 0.88)]
var hair_len := -1   # house.21: -1 = from the outfit option; 0 short, 1 medium, 2 long
var _hair_extra: Node3D
var hair_color := Color(0, 0, 0, 0)   # v9 family creator: alpha 0 = model default
var top_color := Color(0, 0, 0, 0)
## v10: child body = whole model scaled down + bigger head (child proportions) + bright kids' top
var child := false
const CHILD_SCALE := 0.66
const CHILD_HEAD := 1.28
const CHILD_TOP := Color(0.98, 0.55, 0.25)
var _mat_cache := {}
var _meshes := {}        # mesh_name__build -> MeshInstance3D
var _hand := {}          # "L"/"R" -> BoneAttachment3D
var held: Node3D
var _held_left := false
var _finger_bones := {"L": [], "R": []}

static func get_library(g: String) -> AnimationLibrary:
	if _libs.has(g):
		return _libs[g]
	var scene: Node = (load(LIB_SCENES[g]) as PackedScene).instantiate()
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = ap.get_animation_library("")
	for n in lib.get_animation_list():
		lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR if n in LOOPING else Animation.LOOP_NONE
	scene.free()
	_libs[g] = lib
	return lib

func _ready() -> void:
	process_priority = 100  # run after the AnimationPlayer so finger curls are applied on top

func setup(g: String) -> void:
	release_item()
	if model:
		model.free()
	gender = g
	model = (load(PARTS_SCENES[g]) as PackedScene).instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	_meshes.clear()
	for m in skeleton.get_children():
		if m is MeshInstance3D:
			_meshes[String(m.name)] = m
			m.visible = false
	player = AnimationPlayer.new()
	model.add_child(player)
	player.root_node = NodePath("..")
	player.add_animation_library("", get_library(g))
	for s in ["L", "R"]:
		var b := BoneAttachment3D.new(); b.name = "Hand_" + s
		skeleton.add_child(b); b.bone_name = "Hand." + s
		_hand[s] = b
		_finger_bones[s] = []
		for i in skeleton.get_bone_count():
			var bn := skeleton.get_bone_name(i)
			if bn.ends_with("." + s) and (bn.begins_with("Index") or bn.begins_with("Middle") or bn.begins_with("Ring") or bn.begins_with("Pinky")) and not bn.ends_with("_end." + s) and not bn.contains("_end"):
				_finger_bones[s].append(i)
	_refresh()
	set_height(height)
	play("idle", 0.0)

func option_labels(slot: String) -> PackedStringArray:
	var out := PackedStringArray()
	for o in OUTFITS[gender][slot]: out.append(o.label)
	return out

func set_outfit_part(slot: String, index: int) -> void:
	outfit[slot] = clampi(index, 0, OUTFITS[gender][slot].size() - 1)
	_refresh()

func set_build(b: String) -> void:
	if b in BUILDS:
		build = b
		_refresh()

func set_height(h: String) -> void:
	if HEIGHTS.has(h):
		height = h
		if model: model.scale = Vector3.ONE * HEIGHTS[h] * (CHILD_SCALE if child else 1.0)

func set_child(on: bool) -> void:
	child = on; set_height(height); _refresh()

func _solid(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mat_cache.has(k):
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.75; _mat_cache[k] = m
	return _mat_cache[k]

func _refresh() -> void:
	if not model: return
	for m in _meshes.values(): m.visible = false
	for slot in SLOTS:
		var opt: Dictionary = OUTFITS[gender][slot][outfit[slot]]
		var mesh_name: String = MANNEQUIN_MESH[gender][slot] if mannequin else opt.mesh
		var mi: MeshInstance3D = _meshes.get(mesh_name + "__" + build)
		if mi == null: continue
		mi.visible = true
		var rc: Dictionary = {} if mannequin else opt.get("recolor", {})
		var first_cloth := true
		for i in mi.mesh.get_surface_count():
			var base: Material = mi.mesh.surface_get_material(i)
			var over: Material = null
			var mn: String = base.resource_name if base else ""
			if mannequin:
				# head: every surface (eyes, brows, hair) becomes plain skin -> faceless mannequin head
				over = _solid(MANNEQUIN_COL.skin if (slot == "Head" or mn.begins_with("Skin")) else MANNEQUIN_COL[slot])
			elif slot == "Head" and mn.begins_with("Hair") and hair_color.a > 0.0:
				over = _solid(hair_color)
			elif slot == "Body" and not mn.begins_with("Skin") and first_cloth and (top_color.a > 0.0 or child):
				over = _solid(top_color if top_color.a > 0.0 else CHILD_TOP); first_cloth = false
			elif mn.begins_with("Skin") and skin >= 0:
				var c: Color = SKIN_TONES[skin]
				over = _solid(c.darkened(0.12) if mn.begins_with("Skin_Darker") else c)
			elif base:
				for prefix in rc:
					if mn.begins_with(prefix):
						var dup := base.duplicate() as StandardMaterial3D
						if dup: dup.albedo_color = rc[prefix]; over = dup
			mi.set_surface_override_material(i, over)
	_update_hair_extra()

## house.21: medium / long hair = an extra hair piece on the Head bone (back of the head, down to the neck / shoulders)
func _update_hair_extra() -> void:
	if _hair_extra and is_instance_valid(_hair_extra): _hair_extra.queue_free(); _hair_extra = null
	if mannequin or skeleton == null: return
	var opt: Dictionary = OUTFITS[gender]["Head"][outfit["Head"]]
	var ln: int = hair_len if hair_len >= 0 else int(opt.get("len", 0))
	if ln <= 0: return
	var hb := skeleton.find_bone("Head")
	if hb < 0: return
	var ba := BoneAttachment3D.new(); ba.bone_name = "Head"; skeleton.add_child(ba); _hair_extra = ba
	var g := skeleton.get_bone_global_rest(hb)
	var u := g.origin.y / 1.55   # model units per metre (head bone ~1.55 m up on an adult)
	var col: Color = hair_color if hair_color.a > 0.0 else Color(0.33, 0.2, 0.11)
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mat.roughness = 0.85
	var inv := g.basis.inverse()
	# house.22: smooth hair = rounded shells (scaled spheres / capsules) hugging the back of the head, MODEL space (faces +Z)
	# [radius, height(0 = sphere), centre offset from head bone, scale]
	var pcs := []
	if ln == 1:
		pcs = [[0.105, 0.0, Vector3(0, 0.085, -0.03), Vector3(1.0, 0.95, 1.0)],     # cap over the crown/back
			[0.09, 0.0, Vector3(0, 0.02, -0.055), Vector3(1.05, 1.0, 0.75)]]       # nape, ends just above the neck
	else:
		pcs = [[0.105, 0.0, Vector3(0, 0.085, -0.03), Vector3(1.0, 0.95, 1.0)],
			[0.075, 0.30, Vector3(0, -0.03, -0.065), Vector3(1.2, 1.0, 0.55)],     # long fall down the back, tapered capsule
			[0.03, 0.2, Vector3(0.075, 0.0, -0.02), Vector3(1.0, 1.0, 1.2)], [0.03, 0.2, Vector3(-0.075, 0.0, -0.02), Vector3(1.0, 1.0, 1.2)]]   # side strands, close to the face
	for p in pcs:
		var mi := MeshInstance3D.new()
		if p[1] > 0.0:
			var cm := CapsuleMesh.new(); cm.radius = p[0] * u; cm.height = p[1] * u; cm.radial_segments = 24; cm.rings = 8; mi.mesh = cm
		else:
			var sm := SphereMesh.new(); sm.radius = p[0] * u; sm.height = p[0] * 2.0 * u; sm.radial_segments = 24; sm.rings = 12; mi.mesh = sm
		mi.material_override = mat
		var bas := Basis.from_scale(p[3])
		mi.transform = Transform3D(inv * bas, inv * (p[2] * u)); ba.add_child(mi)
func set_skin(i: int) -> void:
	skin = i; _refresh()

func set_mannequin(on: bool) -> void:
	mannequin = on; _refresh()

## glow overlay on the visible body meshes (0..1), used for the "takes shape" transition
var _glow_mat: StandardMaterial3D
func set_glow(a: float) -> void:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new(); _glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; _glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_color = Color(0.75, 0.88, 1.0, a)
	for m in _meshes.values(): m.material_overlay = _glow_mat if a > 0.001 else null

# ------------------------------------------------------------ items in hand
## kind: "cylinder" (mug, bottle, glass), "flat" (burger, sandwich), "round" (apple), "long" (banana)
func hold_item(scene_path: String, kind: String, size: float, left: bool) -> void:
	release_item()
	var s := "L" if left else "R"
	var pivot := Node3D.new(); pivot.name = "HeldItem"
	var inst: Node3D = (load(scene_path) as PackedScene).instantiate()
	pivot.add_child(inst)
	var ab := _aabb(inst)
	var longest: float = max(ab.size.x, max(ab.size.y, ab.size.z))
	var sc: float = size / maxf(longest, 0.001)
	inst.scale = Vector3.ONE * sc
	inst.position = -(ab.position + ab.size * 0.5) * sc          # centre the item on the pivot
	var thick: float = (min(ab.size.x, ab.size.z) if kind == "cylinder" else (ab.size.y if kind == "flat" else min(ab.size.x, min(ab.size.y, ab.size.z)))) * sc
	# hand-bone local frame: +Y towards the fingers, -Z = palm side, thumb = +X (left) / -X (right)
	var thumb := Vector3(1, 0, 0) if left else Vector3(-1, 0, 0)
	var palm := Vector3(0, 0, -1)
	var along := Vector3(0, 1, 0)
	var hand_len := 0.14 if gender == "men" else 0.11
	var basis := Basis.IDENTITY
	match kind:
		"cylinder":   # item up axis points out of the thumb side, like holding a can
			basis = Basis(thumb.cross(along), thumb, along).orthonormalized()
		"flat":       # flat face against the palm, top facing out of the palm
			basis = Basis(thumb, palm, thumb.cross(palm)).orthonormalized()
		"long":       # longest axis across the palm (thumb direction)
			var lx := ab.size.x >= ab.size.z
			basis = Basis(thumb, along, thumb.cross(along)).orthonormalized() if lx else Basis(along, thumb.cross(along), thumb).orthonormalized()
		_:
			basis = Basis.IDENTITY
	var grip_y := hand_len * 0.78
	var grip_z := -(thick * 0.5 + (0.012 if gender == "men" else 0.010))
	pivot.transform = Transform3D(basis, Vector3(0, grip_y, grip_z))
	_hand[s].add_child(pivot)
	held = pivot; _held_left = left

func release_item() -> void:
	if held:
		held.queue_free()
		held = null

## extra bone rotations applied on top of the animation: bone -> [axis in model space, angle rad]
var bone_offsets := {}

func _process(_delta: float) -> void:
	if skeleton:
		var hb := skeleton.find_bone("Head")
		if hb >= 0: skeleton.set_bone_pose_scale(hb, Vector3.ONE * (CHILD_HEAD if child else 1.0))
		for bn in bone_offsets:
			var i := skeleton.find_bone(bn)
			if i < 0: continue
			var ax: Vector3 = bone_offsets[bn][0]; var ang: float = bone_offsets[bn][1]
			if absf(ang) < 0.0001: continue
			var par := skeleton.get_bone_parent(i)
			var pq := skeleton.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
			var q := pq.inverse() * Quaternion(ax.normalized(), ang) * pq
			skeleton.set_bone_pose_rotation(i, q * skeleton.get_bone_pose_rotation(i))
	if skeleton and player: _fix_feet()
	# curl the fingers of the holding hand around the item (applied on top of the animation)
	if held and skeleton:
		var s := "L" if _held_left else "R"
		for i in _finger_bones[s]:
			var r := skeleton.get_bone_pose_rotation(i)
			skeleton.set_bone_pose_rotation(i, r * Quaternion(Vector3.RIGHT, -0.75))

## v12 foot roll: heel strike is left as animated (toe up), the stance foot is levelled (no tiptoe),
## push-off is allowed once the ankle rises, and the toe tip / heel are never pushed below the floor.
const TOE_REST := Vector3(0, 0.001, 0.177)    # toe tip from the Foot bone origin, skeleton rest space (men + women)
const HEEL_REST := Vector3(0, -0.002, -0.075)  # heel point
const SOLE := 0.023                            # bone origin height above the sole at rest
var _foot_prev := {}
var foot_log := {}                             # side -> {toe, heel, ankle} clearance above floor (m), for QA

func foot_points(sd: String) -> Dictionary:
	var fi := skeleton.find_bone("Foot." + sd)
	var rb := skeleton.get_bone_global_rest(fi).basis
	var fp := skeleton.get_bone_global_pose(fi)
	var W := skeleton.global_transform; var sc := W.basis.get_scale().y
	var fl := global_position.y
	var t := W * (fp * (rb.inverse() * TOE_REST)); var h := W * (fp * (rb.inverse() * HEEL_REST)); var o := W * fp.origin
	return {"toe": t.y - fl - SOLE * sc, "heel": h.y - fl - SOLE * sc, "ankle": o.y - fl - SOLE * sc, "toe_p": t, "heel_p": h, "o": o, "sc": sc}

func _rot_foot(fi: int, axis: Vector3, ang: float) -> void:
	var par := skeleton.get_bone_parent(fi)
	var pq := skeleton.get_bone_global_pose(par).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(fi, (pq.inverse() * Quaternion(axis, ang) * pq) * skeleton.get_bone_pose_rotation(fi))

func _fix_feet() -> void:
	if skeleton.find_bone("Foot.L") < 0: return
	if player.current_animation not in ["walk", "run", "idle"]: return   # v12: only walk/run/idle (wake-up untouched)
	var moving: bool = player.current_animation in ["walk", "run"]
	for sd in ["L", "R"]:
		var fi := skeleton.find_bone("Foot." + sd)
		var P := foot_points(sd)
		var dirw: Vector3 = P.toe_p - P.heel_p
		var hl := Vector2(dirw.x, dirw.z).length()
		if hl < 0.001: continue
		# rotation axis in skeleton space: horizontal, perpendicular to the foot (positive angle lifts the toe)
		var axis := Vector3(-1, 0, 0)   # skeleton faces +Z: rotate about the side axis (stable even when the foot points straight down)
		var pitch := atan2(dirw.y, hl)   # >0 toe up
		var sc: float = P.sc
		if moving and pitch < 0.0:
			# stance (ankle near the floor): level the foot; as the ankle lifts (push-off / swing) let the clip's toe-down through
			var w := clampf(1.0 - P.ankle / (0.05 * sc), 0.0, 1.0)
			# swing (foot travelling forward fast): keep the toes up off the floor instead of pointing down
			var now := Time.get_ticks_usec(); var lp: Array = _foot_prev.get(sd, [P.o, now])
			var dtf: float = maxf((now - int(lp[1])) / 1e6, 0.001)
			var hv: float = Vector2(P.o.x - lp[0].x, P.o.z - lp[0].z).length() / dtf
			_foot_prev[sd] = [P.o, now]
			w = maxf(w, smoothstep(0.25, 0.9, hv))
			if w > 0.0: _rot_foot(fi, axis, -pitch * w); P = foot_points(sd)
		# hard floor clamp for the toe tip (any animation): lift the toe about the ankle
		# heel below the floor (strong heel strike): tip the toe down a bit, but never so the toe goes under
		if P.heel < 0.0 and P.toe > 0.0:
			var arm2: float = maxf((P.heel_p - P.o).length(), 0.03)
			var ang := -minf(asin(clampf(-P.heel / arm2, 0.0, 0.9)), asin(clampf(P.toe / maxf((P.toe_p - P.o).length(), 0.05), 0.0, 0.9)))
			_rot_foot(fi, axis, ang); P = foot_points(sd)
		for it in 24:
			if P.toe >= 0.0: break
			var arm: float = maxf((P.toe_p - P.o).length(), 0.05)
			_rot_foot(fi, axis, maxf(asin(clampf(-P.toe / arm, 0.0, 0.9)) * 1.1, 0.08)); P = foot_points(sd)
		foot_log[sd] = {"toe": P.toe, "heel": P.heel, "ankle": P.ankle}

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

# ------------------------------------------------------------ animation
func play(anim: String, blend: float = 0.2, speed: float = 1.0) -> void:
	if player and player.has_animation(anim):
		if player.current_animation == anim and player.is_playing():
			return
		player.play(anim, blend, speed)

func restart(anim: String) -> void:
	if player and player.has_animation(anim):
		player.stop()
		player.play(anim, 0.0)

func anim_length(anim: String) -> float:
	return player.get_animation(anim).length if player and player.has_animation(anim) else 0.0

func animation_names() -> PackedStringArray:
	var l := player.get_animation_list() if player else PackedStringArray()
	l.sort()
	return l

# ------------------------------------------------------------ house.18: ONE creator -> player function for every room
const CREATOR_KEYS := ["gender", "age", "build", "height", "skin", "hair", "hair_col", "top", "bottoms", "shoes"]
## the bedroom creator's choices from user://save.json ("state")
static func load_creator() -> Dictionary:
	var out := {}
	if FileAccess.file_exists(SavePath.P()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if d is Dictionary and d.get("state") is Dictionary:
			for k in CREATOR_KEYS: if d.state.has(k): out[k] = d.state[k]
	return out

## build this character exactly from creator data (gender, child/adult, build, height, skin, hair, clothes)
func apply_creator(c: Dictionary) -> void:
	var g: String = String(c.get("gender", gender if gender != "" else "men"))
	if g != gender or model == null:
		var p := position; var r := rotation
		setup(g); position = p; rotation = r
	child = String(c.get("age", "adult")) == "child"
	build = String(c.get("build", build)) if String(c.get("build", build)) in BUILDS else build
	height = String(c.get("height", height)) if HEIGHTS.has(String(c.get("height", height))) else height
	if model: model.scale = Vector3.ONE * HEIGHTS[height] * (CHILD_SCALE if child else 1.0)
	skin = int(c.get("skin", skin))
	outfit = {"Head": int(c.get("hair", 0)), "Body": int(c.get("top", 0)), "Legs": int(c.get("bottoms", 0)), "Feet": int(c.get("shoes", 0))}
	for s in SLOTS: outfit[s] = clampi(outfit[s], 0, OUTFITS[gender][s].size() - 1)
	hair_color = HAIR_TONES[clampi(int(c.get("hair_col", 1)), 0, HAIR_TONES.size() - 1)]   # house.21
	_refresh()
