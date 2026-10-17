## CharacterHook: the persistent-character hook. The bedroom mirror (english_game_3dv2 main.gd creator) is the ONE
## source of truth; this rebuilds any DemoCharacter from it with the house's own function (character.gd apply_creator),
## so the outdoor player is identical to the house player (child/adult proportions, height, build, skin, hair style +
## colour, clothes, gender) and gets the same derived values the house uses (walk-clip rate / step length via
## model.scale, footsteps from the animation, child hum pitch, scale weight, bathroom make-up).
## Called through the Game autoload: Game.apply_character(node), Game.creator(), Game.character_changed.
class_name CharacterHook
extends RefCounted

## every key the house's creator writes into save.json "state" (DemoCharacter.CREATOR_KEYS, house.21)
const KEYS: Array = DemoCharacter.CREATOR_KEYS   # gender age build height skin hair hair_col top bottoms shoes
## bathroom extras (bk_extras.gd): make-up overlay saved in user://bk_bathroom.json {"makeup": {blush, lip, shadow}}
const MAKEUP_FILE := "user://bk_bathroom.json"
const MAKEUP_SHADER := "res://scripts/bk_makeup.gdshader"
## livingroom.gd family palette / roles (copied, read-only reference)
const FAM_HAIR := [Color(0.08, 0.07, 0.06), Color(0.35, 0.2, 0.1), Color(0.9, 0.75, 0.42), Color(0.66, 0.25, 0.12), Color(0.62, 0.62, 0.64), Color(0.93, 0.93, 0.92)]
const FAM_CLOTH := [Color(0.84, 0.26, 0.26), Color(0.2, 0.38, 0.8), Color(0.2, 0.6, 0.38), Color(0.95, 0.78, 0.25), Color(0.52, 0.3, 0.75), Color(0.12, 0.12, 0.14)]
const SHE_ROLES := ["mother", "sister", "grandmother", "wife", "daughter", "aunt"]
const PET_ROLES := ["dog", "cat", "bird", "fish", "rabbit", "hamster", "turtle"]

## creator data: live state first (a house room's `S`, or the outdoor room_phone.S), else save.json "state"
static func creator(tree: SceneTree = null) -> Dictionary:
	var out := DemoCharacter.load_creator()
	var live := live_state(tree)
	for k in KEYS: if live.has(k): out[k] = live[k]
	return out

## the full house state dict (name, job, family, voice, tr ... + creator keys)
static func state(tree: SceneTree = null) -> Dictionary:
	var d := App.load_save()
	var out: Dictionary = (d.get("state") as Dictionary).duplicate() if d.get("state") is Dictionary else {}
	var live := live_state(tree)
	for k in live: out[k] = live[k]
	return out

static func live_state(tree: SceneTree) -> Dictionary:
	if tree == null: tree = Engine.get_main_loop() as SceneTree
	var sc := tree.current_scene if tree else null
	if sc == null: return {}
	if "room_phone" in sc and sc.room_phone and "S" in sc.room_phone: return sc.room_phone.S
	if "S" in sc and sc.S is Dictionary: return sc.S
	return {}

static func is_child(c: Dictionary) -> bool: return String(c.get("age", "adult")) == "child"

## rebuild `hero` exactly like every house room does (hero.apply_creator) + make-up
static func apply(hero: DemoCharacter, c: Dictionary) -> void:
	if hero == null: return
	var cc := {}
	for k in KEYS: if c.has(k): cc[k] = c[k]
	hero.apply_creator(cc)
	apply_makeup(hero)

## derived values (all from the house's own formulas)
static func body_scale(hero: DemoCharacter) -> float: return hero.model.scale.y if hero and hero.model else 1.0
## house: same max walk speed for everybody (PlayerController.WALK); the clip is sped up by 1/scale, so a child or a
## short body takes shorter, quicker steps; footsteps follow the clip's foot contacts automatically.
static func walk_speed(_c: Dictionary) -> float: return PlayerController.WALK
static func step_length(hero: DemoCharacter) -> float: return 0.85 * body_scale(hero)   # approx stride per foot contact (m)
## bathroom.gd hum: child 1.15, adult 1.0; women hum_f / men hum_m. Narration voice itself is never pitched in the house.
static func voice_pitch(c: Dictionary) -> float: return 1.15 if is_child(c) else 1.0
static func hum_sfx(c: Dictionary) -> String: return "res://sfx/hum_f.ogg" if String(c.get("gender", "men")) == "women" else "res://sfx/hum_m.ogg"
## bk_extras.gd weight_kg() (bathroom scale)
static func weight_kg(c: Dictionary) -> int:
	var men: bool = c.get("gender", "men") == "men"
	var w: float
	if is_child(c):
		w = 30.0 + {"thin": -5.0, "average": 0.0, "fat": 8.0}.get(c.get("build", "average"), 0.0) + {"short": -5.0, "medium": 0.0, "tall": 5.0}.get(c.get("height", "medium"), 0.0)
	else:
		w = (76.0 if men else 63.0) + {"thin": -11.0 if men else -9.0, "average": 0.0, "fat": 22.0 if men else 18.0}.get(c.get("build", "average"), 0.0) \
			+ {"short": -7.0 if men else -6.0, "medium": 0.0, "tall": 8.0 if men else 7.0}.get(c.get("height", "medium"), 0.0)
	return clampi(int(round(w)), 20, 140)

## bathroom make-up (bk_extras.gd _setup_makeup): bake head rest positions into CUSTOM0 + overlay shader
static func load_makeup() -> Dictionary:
	var mk := {"blush": 0.0, "lip": 0.0, "shadow": 0.0}
	if FileAccess.file_exists(MAKEUP_FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(MAKEUP_FILE))
		if d is Dictionary and d.get("makeup") is Dictionary:
			for k in mk: mk[k] = float(d.makeup.get(k, 0.0))
	return mk

static func apply_makeup(hero: DemoCharacter) -> void:
	var mk := load_makeup()
	if mk.values().max() <= 0.0 or not ResourceLoader.exists(MAKEUP_SHADER): return
	var mat := ShaderMaterial.new(); mat.shader = load(MAKEUP_SHADER)
	if hero.gender == "women": mat.set_shader_parameter("eye_y", 1.690); mat.set_shader_parameter("eye_x", 0.042)
	for k in mk: mat.set_shader_parameter(k, mk[k])
	for key in hero._meshes:
		if not String(key).contains("_Head__"): continue
		var mi: MeshInstance3D = hero._meshes[key]
		var src: ArrayMesh = mi.mesh
		if src == null: continue
		var out := ArrayMesh.new()
		for i in src.get_surface_count():
			var a := src.surface_get_arrays(i)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var smat := src.surface_get_material(i)
			var skin := 1.0 if (smat and smat.resource_name.begins_with("Skin")) else 0.0
			var cu := PackedFloat32Array(); cu.resize(v.size() * 4)
			for j in v.size():
				cu[j * 4] = v[j].x; cu[j * 4 + 1] = v[j].y; cu[j * 4 + 2] = v[j].z; cu[j * 4 + 3] = skin
			a[Mesh.ARRAY_CUSTOM0] = cu
			var fl := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (src.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			out.add_surface_from_arrays(src.surface_get_primitive_type(i), a, [], {}, fl)
			out.surface_set_material(i, smat); out.surface_set_name(i, src.surface_get_name(i))
		mi.mesh = out; mi.material_overlay = mat

## family members (phone Family app -> save.json state.family) built like livingroom.gd spawn_family_breakfast.
## Not spawned outdoors yet; call this when family appears outside. Pets return null.
static func make_family_member(m: Dictionary) -> DemoCharacter:
	var role := String(m.get("role", ""))
	if role == "" or PET_ROLES.has(role): return null
	var ch := DemoCharacter.new()
	var g := "women" if (SHE_ROLES.has(role) or (role == "cousin" and m.get("pron", "she") == "she")) else "men"
	ch.ready.connect(func():
		ch.setup(g)
		ch.skin = int(m.get("skin", 1)); ch.hair_color = FAM_HAIR[clampi(int(m.get("hcol", 1)), 0, 5)]; ch.top_color = FAM_CLOTH[clampi(int(m.get("cloth", 1)), 0, 5)]
		ch.outfit = {"Head": int(m.get("hair", 0)), "Body": 0, "Legs": 1 if g == "women" else 0, "Feet": 0}
		if m.get("child", false): ch.set_child(true)
		else: ch.set_height("medium")
		ch._refresh(), CONNECT_ONE_SHOT)
	return ch
