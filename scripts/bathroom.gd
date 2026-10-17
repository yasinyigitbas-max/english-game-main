## English Home 3D: BATHROOM. Same look, camera, controls, HUD and caption system as the bedroom (english_game_3dv2/scripts/main.gd).
## Tasks: wash your face -> brush your teeth -> door unlocks -> living-room door unlocks -> `bathroom_completed` -> living room.
## Captions teach the present simple ("I am washing my face." / "Yüzümü yıkarım.").
extends Node3D
const GameMenu = preload("res://scripts/game_menu.gd")

signal action_peak(id: String)
signal action_done(id: String)
signal captioned(text: String)
signal task_completed(task: String)        # "wash_face" | "brush_teeth"
signal bathroom_completed                  # both tasks done and the player walks out through the door

## Integration: the scene the SOUTH (living-room) door leads to. If it does not exist the door shows a caption instead.
@export var next_scene := "res://livingroom.tscn"
## The west door leads back to the bedroom. Leave empty to only open/close it (the house scene handles walking through).
@export var bedroom_scene := "res://main.tscn"
## false = no sliding panel in the west opening (use when the bedroom's own door already fills that opening in the house)
@export var bedroom_door_panel := true

const PROPS := "res://props/bathroom/"
const ROOM := Rect2(-2.25, -1.75, 4.5, 3.5)   # x, z
const WALL_H := 2.6
const R := 0.22
const WALK := 1.955   # house.15 max walk speed
const WALK_CLIP := 1.7
const RUN := 3.3
var RUN_CLIP := 3.3
const RUN_ON := 99.0  # house.15: walk only
#
const RUN_OFF := 0.64
const GW := 45
const GH := 35
var running := false
var move_sp := 0.0

## English -> Turkish (actions: present continuous like the bedroom; missions: imperative; no subject pronouns)
const TR := {
	"Good morning! This is my bathroom.": "Günaydın! Burası benim banyom.",
	"I am going to the plant.": "Bitkiye gidiyorum.", "I am watering the plant.": "Bitkiyi suluyorum.", "The plant is happy now.": "Bitki artık mutlu.",   # v31-fixes
	"Wash my face and brush my teeth": "Yüzümü yıka ve dişlerimi fırçala", "Go to the mirror.": "Aynaya git.",
	"Wash your face.": "Yüzünü yıka.", "Brush your teeth.": "Dişlerini fırçala.", "Go to the living room.": "Oturma odasına git.",
	"I am turning on the tap.": "Musluğu açıyorum.", "I am turning off the tap.": "Musluğu kapatıyorum.",
	"I am washing my face.": "Yüzümü yıkıyorum.", "I am washing my hands.": "Ellerimi yıkıyorum.",
	"I am drying my face with the towel.": "Yüzümü havluyla kuruluyorum.", "I am drying my hands.": "Ellerimi kuruluyorum.",
	"I am folding the towel.": "Havluyu katlıyorum.", "My face is clean.": "Yüzüm temiz.",
	"I am taking my toothbrush.": "Diş fırçamı alıyorum.", "I am putting toothpaste on my toothbrush.": "Diş fırçama diş macunu sürüyorum.",
	"I am brushing my teeth.": "Dişlerimi fırçalıyorum.", "I am rinsing my mouth.": "Ağzımı çalkalıyorum.",
	"I am putting my toothbrush back.": "Diş fırçamı geri koyuyorum.", "My teeth are clean.": "Dişlerim temiz.",
	"I am looking in the mirror.": "Aynaya bakıyorum.", "I am smiling.": "Gülümsüyorum.",
	"I am turning on the shower.": "Duşu açıyorum.", "I am turning off the shower.": "Duşu kapatıyorum.",
	"I am opening the shower curtain.": "Duş perdesini açıyorum.", "I am closing the shower curtain.": "Duş perdesini kapatıyorum.",
	"I am flushing the toilet.": "Sifonu çekiyorum.",
	"I need to pee.": "Çişim geldi.", "I need to poop.": "Kakam geldi.", "I am peeing.": "Çiş yapıyorum.", "I am pooping.": "Kaka yapıyorum.",
	"I am sitting on the toilet.": "Klozete oturuyorum.", "I am using toilet paper.": "Tuvalet kâğıdı kullanıyorum.", "I am standing up.": "Ayağa kalkıyorum.",
	"Wash your hands.": "Ellerini yıka.", "My hands are clean.": "Ellerim temiz.",
	"I am taking a shower.": "Duş alıyorum.", "I am taking off my clothes.": "Kıyafetlerimi çıkarıyorum.", "I am getting in the bathtub.": "Küvete giriyorum.",
	"I am washing my hair.": "Saçımı yıkıyorum.", "I am washing my body.": "Vücudumu yıkıyorum.", "I am rinsing.": "Durulanıyorum.",
	"I am getting out of the bathtub.": "Küvetten çıkıyorum.", "I am drying myself with a towel.": "Havluyla kuruluyorum.",
	"I am putting on my clothes.": "Kıyafetlerimi giyiyorum.", "I am clean now.": "Artık temizim.",
	"I am opening the cabinet.": "Dolabı açıyorum.", "I am closing the cabinet.": "Dolabı kapatıyorum.",
	"I am turning on the light.": "Işığı açıyorum.", "I am turning off the light.": "Işığı kapatıyorum.",
	"I am opening the window.": "Pencereyi açıyorum.", "I am closing the window.": "Pencereyi kapatıyorum.",
	"I am opening the door.": "Kapıyı açıyorum.", "I'm in the bathroom now.": "Şimdi banyodayım.", "I am closing the door.": "Kapıyı kapatıyorum.",
	"The door is closed. Wash your face and brush your teeth first.": "Kapı kapalı. Önce yüzünü yıka ve dişlerini fırçala.",
	"I am going to the living room now.": "Şimdi oturma odasına gidiyorum.", "The living room comes later.": "Oturma odası daha sonra gelecek.",
	"This door goes to my bedroom.": "Bu kapı yatak odama açılıyor.", "I am going to the bedroom door.": "Yatak odası kapısına gidiyorum.", "I am going to the living room door.": "Oturma odası kapısına gidiyorum.",
	"I am going to the sink.": "Lavaboya gidiyorum.", "I am going to the towel.": "Havluya gidiyorum.", "I am going to the bathtub.": "Küvete gidiyorum.",
	"I am going to the toilet.": "Tuvalete gidiyorum.", "I am going to the cabinet.": "Dolaba gidiyorum.", "I am going to the light switch.": "Işık düğmesine gidiyorum.",
	"I am going to the window.": "Pencereye gidiyorum.", "I am going to the door.": "Kapıya gidiyorum.",
	"I am looking at my phone.": "Telefonuma bakıyorum.", "I am walking.": "Yürüyorum.", "I am running.": "Koşuyorum.", "My phone is in the bedroom.": "Telefonum yatak odasında.",
}
const GO := {"sink": "I am going to the sink.", "towel": "I am going to the towel.", "bath": "I am going to the bathtub.", "toilet": "I am going to the toilet.",
	"cabinet": "I am going to the cabinet.", "switch": "I am going to the light switch.", "window": "I am going to the window.", "door": "I am going to the living room door.", "door_bed": "I am going to the bedroom door.", "plant": "I am going to the plant."}

var hero: DemoCharacter
var cam: CameraRig
var sun: DirectionalLight3D
var env: Environment
## character keys use the bedroom's save.json names so the same player appears
var S := {"tap": "off", "shower": "off", "curtain": "open", "cabinet": "closed", "light": "on", "window": "closed",
	"door": "closed", "door_bed": "closed", "towel": "hanging", "brush": "cup", "plant": "dry", "face_done": false, "teeth_done": false,
	"tr": false, "voice": true, "gender": "men", "build": "average", "height": "medium", "skin": 1, "hair": 0, "top": 0, "bottoms": 0, "shoes": 0, "age": "adult"}
var OBJ := {}
var N := {}
var obstacles: Array[Rect2] = []
var astar := AStarGrid2D.new()
var mode := "play"   # play | busy
var near_id := ""
var stick := Vector2.ZERO
var cam_stick := Vector2.ZERO
var cam_focus := Vector3.ZERO
var hand3d: Sprite3D
var ui: CanvasLayer
var touch: Control
var font: FontVariation
var font_b: FontVariation
var hud: GameHUD
var step_state := {}
var mission_lbl: Label
var mission_tr: Label
var cap_panel: PanelContainer
var cap_en: Label
var cap_tr: Label
var tr_btn: Button
var chips: VBoxContainer
var menu: Control
var cap_text := ""
var mission := ""
var cam_zoom := 1.0
var cam_yaw := 0.0
var cam_pitch := 0.9025
var cam_dist := 7.6
var cam_yaw_s := 0.0
var cam_pitch_s := 0.9025
var walls_l: Array = []
var walls_r: Array = []
var walls_s: Array = []   # v32-polish: south (camera-side) wall pieces, faded by the shared helper
const WallFade := preload("res://scripts/props/wall_fade.gd")
var wall_fade: Node
func _wall_fade_setup() -> void:
	if wall_fade: return
	wall_fade = WallFade.attach(self, func(): return cam.global_position if is_instance_valid(cam) else Vector3.INF, func(): return hero.global_position if is_instance_valid(hero) else Vector3.INF)
	for w in walls_s: wall_fade.register(w)
	for w in walls_l: wall_fade.register_occluder(w, {"group": "L", "hide_containers": true, "out": func(): return cam.position.x < LX})   # v33: side walls fade only while they hide the player
	for w in walls_r: wall_fade.register_occluder(w, {"group": "R", "hide_containers": true, "out": func(): return cam.position.x > RX})
var wall_alpha := {}
var was_walking := false
var last_step_ph := 1.0
var no_steps := false   # v13: no footsteps while hopping over the tub rim
var cam_shot := {}
var shot_at := Vector3.INF
var exit_xf := Transform3D()
var exit_t := 1.0
var tap_fx: CPUParticles3D
var shower_fx: CPUParticles3D
var splash_fx: CPUParticles3D
var foam_fx: CPUParticles3D
## voice: own English clip bank (Piper ljspeech, same voice as the bedroom), see tools/build_voice_bathroom.py
var vindex := {}
var vfile: FileAccess
var vplayer: AudioStreamPlayer
var vqueue: Array = []
## ---- extension API for scripts/bk_extras.gd (see HOOKS.md)
var extras: Node
var qa_cam := {}
var extra_verbs := {}      # id -> Callable() -> Array of [chip label, caption, key]
var extra_handlers := {}   # id -> Callable(key: String, verb: Array) (may await)
var voice_banks: Array = []  # [{index: Dictionary, file: FileAccess}]
var TR_EXTRA := {}

func register_interactable(id: String, display_name: String, focus: Vector3, spot: Vector3, face: Vector3, verbs_fn: Callable, handler: Callable) -> void:
	reg(id, display_name, focus, spot, face); extra_verbs[id] = verbs_fn; extra_handlers[id] = handler

func add_translations(d: Dictionary) -> void:
	TR_EXTRA.merge(d, true)

func add_voice_bank(index_json: String, bin_path: String) -> void:
	if FileAccess.file_exists(index_json) and FileAccess.file_exists(bin_path):
		voice_banks.append({"index": JSON.parse_string(FileAccess.get_file_as_string(index_json)), "file": FileAccess.open(bin_path, FileAccess.READ)})

func add_obstacle(x0: float, z0: float, x1: float, z1: float) -> void:
	rect_block(x0, z0, x1, z1); _build_grid()

# ============================================================ setup
const House := preload("res://scripts/core/house.gd")   # v32wh: whole house
func _ready() -> void:
	if House.shell_ready(self, func(): _load_player(); _build_room()): return   # v32wh: next-door room = geometry only
	_live_ready()

func _live_ready() -> void:   # v32wh: the v32 _ready (also run when this room's shell turns live)
	DoorLabel.attach.call_deferred(self, OBJ, {"door": ["Living room", "Oturma odası"], "door_bed": ["Bedroom", "Yatak odası"]})   # v30.2
	Life.event("bathroom")   # house.29: event clock
	_load_player()
	_build_env()
	if not has_meta("wh_built"): _build_room()   # v32wh: a shell turning live already has its geometry
	_build_grid(); _build_fx()
	hero = OwLink.hero_for(self); hero.setup(S.gender); _apply_character()
	hero.position = Vector3(LX + 0.65, 0, (WD.x + WD.y) / 2); hero.rotation.y = PI / 2   # from the bedroom: inside the west door
	if App.came_from == "livingroom": hero.position = Vector3((SD.x + SD.y) / 2, 0, FZ - 0.6); hero.rotation.y = PI   # inside the south door
	App.came_from = ""
	cam = (load("res://ui/shared/camera_rig.tscn") as PackedScene).instantiate(); add_child(cam)
	cam.avoid_with_override = true   # v33: override_point is the room framing here (camera occlusion avoidance stays on)
	cam.setup(hero, 7.6, 0.9025, 4.5, 11.0)     # shared rig: wheel / right-drag / pinch / two-finger drag / ring / Q,E,+,-
	cam.override_point = Vector3(hero.position.x * 0.35, 0, -0.35 + hero.position.z * 0.3); cam.focus = cam.override_point; cam.snap()
	hand3d = Sprite3D.new(); hand3d.texture = load("res://ui/hand.png"); hand3d.pixel_size = 0.0013
	hand3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED; hand3d.no_depth_test = true; hand3d.render_priority = 10; hand3d.visible = false; add_child(hand3d)
	_load_voice(); _build_ui(); _apply_states()
	_stable_lights()   # v304: final omni settings from frame 0 (no shadow/variant switch 0.5 s in, right before the mirror pan)
	_entry_mission()
	get_tree().create_timer(0.6, false).timeout.connect(func(): caption("I'm in the bathroom now.", false))   # house.17: silent room caption
	action_done.connect(func(_i): _save_progress())
	if ResourceLoader.exists("res://scripts/bk_extras.gd"):   # black bot extras (HOOKS.md)
		var gs = load("res://scripts/bk_extras.gd")
		if gs is GDScript and gs.can_instantiate():
			extras = gs.new(); extras.name = "BkExtras"; add_child(extras)
			if extras.has_method("setup"): extras.setup(self)
		else: push_warning("bk_extras.gd failed to load; extras disabled")
	if "--qa-bath" in OS.get_cmdline_user_args():
		var q = load("res://scripts/qa_bathroom.gd").new(); add_child(q); q.run(self)
	House.live_ready(self)   # v32wh: the two other rooms as shells next door

## room-entry objective (v33town: also on re-entry of the persistent room)
func _entry_mission() -> void:
	if Objectives.d2_chat_done(): _set_mission("Go to bed.")   # Yasin 17:58
	elif (S.face_done and S.teeth_done) or WorldState.day >= 2:
		_set_mission("Go to the living room.")
	else:
		# Objectives feed only — bathroom-door / mirror pans: black bot via Life.guide_to
		var todo: Array = []
		if not S.face_done: todo.append("Wash your face.")
		if not S.teeth_done: todo.append("Brush your teeth.")
		if todo.is_empty(): todo = ["Go to the mirror."]
		Objectives.set_list(todo); _set_mission(String(todo[0]))
		if WorldState.day < 2: _mirror_prompt.call_deferred(todo)   # v30.4: pan to the mirror

## v33town (one persistent house): the bathroom was live before and slept; everything in it stays as it was. Re-entry runs
## only the room-entry steps of _live_ready (event clock, the player's look / TR from save.json, objective, caption).
func _wh_resume() -> void:
	Life.event("bathroom")
	_load_player(); _apply_character(); _apply_states()
	App.came_from = ""
	mode = "play"; _update_hand()
	_entry_mission()
	get_tree().create_timer(0.6, false).timeout.connect(func(): caption("I'm in the bathroom now.", false))

## v33town: the spot just inside the door the player comes through (same spots as in _live_ready)
func _wh_spawn(from: String) -> Array:
	if from == "livingroom": return [Vector3((SD.x + SD.y) / 2, 0, FZ - 0.6), PI]
	if from == "bedroom": return [Vector3(LX + 0.65, 0, (WD.x + WD.y) / 2), PI / 2]
	return []

## reads the bedroom's user://save.json (same keys) so the player keeps the look they created
func _load_player() -> void:
	if FileAccess.file_exists(SavePath.P()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if d is Dictionary and d.has("state"):
			for k in ["gender", "build", "height", "skin", "hair", "top", "bottoms", "shoes", "tr", "voice", "age"]:
				if d.state.has(k): S[k] = d.state[k]
	if FileAccess.file_exists("user://bathroom.json") and not "--qa-bath" in OS.get_cmdline_user_args():
		var b = JSON.parse_string(FileAccess.get_file_as_string("user://bathroom.json"))
		if b is Dictionary: S.face_done = b.get("face_done", false); S.teeth_done = b.get("teeth_done", false)
	if App.bath_done: S.face_done = true; S.teeth_done = true

## the host game can also push its state dictionary directly (call before add_child)
func set_player_state(st: Dictionary) -> void:
	for k in st: if S.has(k): S[k] = st[k]

func _save_progress() -> void:
	var f := FileAccess.open("user://bathroom.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"face_done": S.face_done, "teeth_done": S.teeth_done}))
	f = null
	if S.face_done and S.teeth_done and not App.bath_done: _mark_bath_done()

## house.17: bathroom routine finished -> persistent flag (App + save.json) unlocks the living-room doors
func _mark_bath_done() -> void:
	App.bath_done = true
	if FileAccess.file_exists(SavePath.P()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if d is Dictionary:
			d["bath_done"] = true
			var f := FileAccess.open(SavePath.P(), FileAccess.WRITE)
			if f: f.store_string(JSON.stringify(d, "\t"))

func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c, alpha); m.roughness = 0.85
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
	return m

func _chrome() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.82, 0.84, 0.87); m.metallic = 0.85; m.roughness = 0.25; return m

func box(size: Vector3, pos: Vector3, c: Color, parent: Node = self, emit := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(c, emit, alpha); mi.position = pos; parent.add_child(mi); return mi

func chrome_box(size: Vector3, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var mi := box(size, pos, Color.WHITE, parent); mi.material_override = _chrome(); return mi

func cyl(r: float, h: float, pos: Vector3, c: Color, parent: Node = self, chrome := false, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r if r2 < 0 else r2; cm.height = h
	cm.radial_segments = 20; cm.rings = 1; mi.mesh = cm
	mi.material_override = _chrome() if chrome else _mat(c); mi.position = pos; parent.add_child(mi); return mi

func prop(file: String, pos: Vector3, yaw_deg: float, height := 0.0, length := 0.0, parent: Node = self, sy := 1.0) -> Node3D:
	var pivot := Node3D.new(); parent.add_child(pivot)
	var inst: Node3D = (load(PROPS + file + ".glb") as PackedScene).instantiate(); pivot.add_child(inst)
	var ab := _aabb(inst)
	var s := 1.0
	if height > 0.0: s = height / maxf(ab.size.y, 0.001)
	elif length > 0.0: s = length / maxf(maxf(ab.size.x, ab.size.z), 0.001)
	inst.scale = Vector3(s, s * sy, s)
	inst.position = -Vector3((ab.position.x + ab.size.x * 0.5) * s, ab.position.y * s * sy, (ab.position.z + ab.size.z * 0.5) * s)
	pivot.position = pos; pivot.rotation.y = deg_to_rad(yaw_deg)
	for m in inst.find_children("*", "MeshInstance3D", true, false): (m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
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

func block(n: Node3D, grow := 0.0) -> Rect2:
	var ab := _aabb(n); var xf := n.transform
	var p0 := xf * ab.get_endpoint(0)
	var r := Rect2(Vector2(p0.x, p0.z), Vector2.ZERO)
	for i in 8:
		var p := xf * ab.get_endpoint(i); r = r.expand(Vector2(p.x, p.z))
	r = r.grow(grow); obstacles.append(r); return r

func rect_block(x0: float, z0: float, x1: float, z1: float) -> void:
	obstacles.append(Rect2(x0, z0, x1 - x0, z1 - z0))

const CENTRE := Vector3(0, 0, 0)
## v31: every small plant is waterable (same water verbs / watering can as the big plants)
var _spl_n := 0
func _spl(n: Node3D) -> Node3D:
	_spl_n += 1; var id := "splant%d" % _spl_n
	var p: Vector3 = n.global_position if n.is_inside_tree() else n.position
	var d := Vector3(CENTRE.x - p.x, 0, CENTRE.z - p.z); d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)
	reg(id, "plant", p + Vector3(0, 0.12, 0), Vector3(p.x, 0, p.z) + d * 0.75, -d)
	if not S.has(id): S[id] = "dry"
	return n

func reg(id: String, nm: String, focus: Vector3, spot: Vector3, face: Vector3) -> void:
	OBJ[id] = {"name": nm, "focus": focus, "spot": spot, "yaw": atan2(face.x, face.z)}

## soft cloth (bedroom sheet() idea), used for towels, curtain, clothes
func sheet(size: Vector2, pos: Vector3, c: Color, amp: float, seed: int, parent: Node, vertical := true) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 14; var nz := 18; var pts := []
	for iz in nz + 1:
		for ix in nx + 1:
			var x := (float(ix) / nx - 0.5) * size.x; var y := (float(iz) / nz - 0.5) * size.y
			var w := amp * (sin(x * 30.0 + seed) * 0.6 + sin(y * 9.0 + seed * 2.0) * 0.4)
			pts.append(Vector3(x, y, w) if vertical else Vector3(x, w, y))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			for k in [a, a + nx + 1, a + 1, a + 1, a + nx + 1, a + nx + 2]: st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := _mat(c); m.cull_mode = BaseMaterial3D.CULL_DISABLED; mi.material_override = m
	mi.position = pos; parent.add_child(mi); return mi

func _build_env() -> void:
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.86, 0.89, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1.0, 0.97, 0.93)
	env.ambient_light_energy = 0.6; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.95
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.95, 0.85); sun.light_specular = 0.25
	add_child(sun); sun.look_at_from_position(to_global(Vector3(1.5, 9, -9)), to_global(Vector3(0, 0, 0))); sun.light_energy = 1.3 * WorldState.daylight()
	sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_fade_start = 1.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 2.5; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2

# ============================================================ room
const BZ := -1.75            # back wall inner face
const LX := -2.25            # left wall inner face
const RX := 2.25             # right wall inner face (door)
const TILE := Color(0.90, 0.88, 0.85)
const SAGE := Color(0.62, 0.74, 0.70)
const CAB := Color(0.96, 0.95, 0.93)
const WOOD := Color(0.72, 0.56, 0.40)
const BLUE := Color(0.40, 0.56, 0.76)
const TERRA := Color(0.85, 0.4, 0.35)
const CREAM := Color(0.93, 0.86, 0.74)
const DARK := Color(0.2, 0.21, 0.24)
const SINK := Vector3(-0.35, 0, BZ)        # vanity centre on the back wall
const TOP_Y := 0.86                         # counter top height
const MZ := BZ + 0.025                      # mirror glass plane
const MC := Vector3(-0.35, 1.55, BZ + 0.025)
const MSIZE := Vector2(0.78, 0.86)

## grout lines on a wall face (pos = centre of the face; the face normal is +Z before yaw)
func _tiles_wall(w: float, h: float, pos: Vector3, yaw: float, c: Color, group: Array = [], tw := 0.3, th := 0.15) -> void:
	var n := Node3D.new(); n.position = pos; n.rotation.y = yaw; add_child(n)
	if yaw != 0.0: group.append(n)
	var g := c.darkened(0.1)
	for i in range(1, int(h / th) + 1): box(Vector3(w, 0.006, 0.004), Vector3(0, -h / 2 + i * th, 0.002), g, n)
	for row in int(h / th):
		var x := -w / 2 + ((tw * 0.5) if row % 2 == 1 else 0.0) + tw
		while x < w / 2 - 0.01:
			box(Vector3(0.006, th, 0.004), Vector3(x, -h / 2 + row * th + th / 2, 0.002), g, n); x += tw

func _build_room() -> void:
	var floor_c := Color(0.84, 0.82, 0.78)
	box(Vector3(4.5, 0.1, 3.5), Vector3(0, -0.05, 0), floor_c)
	for i in range(1, 8): box(Vector3(0.008, 0.004, 3.5), Vector3(LX + i * 0.5625, 0.002, 0), floor_c.darkened(0.14))
	for i in range(1, 7): box(Vector3(4.5, 0.004, 0.008), Vector3(0, 0.002, BZ + i * 0.5), floor_c.darkened(0.14))
	box(Vector3(30, 0.1, 30), Vector3(0, -0.16, 0), Color(0.80, 0.84, 0.88))
	# back wall with a small frosted window (x 0.95..1.75, y 1.55..2.2) above the toilet
	var bwz := BZ - 0.05
	box(Vector3(3.2, WALL_H, 0.1), Vector3(-0.65, WALL_H / 2, bwz), TILE)
	box(Vector3(0.5, WALL_H, 0.1), Vector3(2.0, WALL_H / 2, bwz), TILE)
	box(Vector3(0.8, 1.55, 0.1), Vector3(1.35, 0.775, bwz), TILE)
	box(Vector3(0.8, 0.4, 0.1), Vector3(1.35, 2.4, bwz), TILE)
	# lower 1.2 m tiled (subway pattern), upper part painted sage
	box(Vector3(3.18, 1.4, 0.01), Vector3(-0.66, 1.9, BZ + 0.006), SAGE)
	box(Vector3(0.48, 1.4, 0.01), Vector3(2.0, 1.9, BZ + 0.006), SAGE)
	box(Vector3(0.8, 0.35, 0.01), Vector3(1.35, 1.375, BZ + 0.006), SAGE)
	box(Vector3(0.8, 0.4, 0.01), Vector3(1.35, 2.4, BZ + 0.006), SAGE)
	_tiles_wall(4.5, 1.2, Vector3(0, 0.6, BZ), 0.0, TILE)
	box(Vector3(4.5, 0.03, 0.025), Vector3(0, 1.215, BZ + 0.012), Color(1, 1, 1))
	# left (west) wall with the bedroom door opening, solid right (east) wall; both fade when the camera is behind them
	var zc := (WD.x + WD.y) / 2
	walls_l.append(box(Vector3(0.1, WALL_H, WD.x - BZ), Vector3(LX - 0.05, WALL_H / 2, (BZ + WD.x) / 2), TILE))
	walls_l.append(box(Vector3(0.1, WALL_H, FZ - WD.y), Vector3(LX - 0.05, WALL_H / 2, (WD.y + FZ) / 2), TILE))
	walls_l.append(box(Vector3(0.1, WALL_H - 2.12, 0.9), Vector3(LX - 0.05, 2.12 + (WALL_H - 2.12) / 2, zc), TILE))
	walls_l.append(box(Vector3(0.01, 1.4, WD.x - BZ), Vector3(LX + 0.006, 1.9, (BZ + WD.x) / 2), SAGE))
	walls_l.append(box(Vector3(0.01, 1.4, FZ - WD.y), Vector3(LX + 0.006, 1.9, (WD.y + FZ) / 2), SAGE))
	walls_l.append(box(Vector3(0.01, WALL_H - 2.17, 0.9), Vector3(LX + 0.006, 2.17 + (WALL_H - 2.17) / 2, zc), SAGE))
	_tiles_wall(WD.x - BZ, 1.2, Vector3(LX + 0.001, 0.6, (BZ + WD.x) / 2), PI / 2, TILE, walls_l)
	_tiles_wall(FZ - WD.y, 1.2, Vector3(LX + 0.001, 0.6, (WD.y + FZ) / 2), PI / 2, TILE, walls_l)
	walls_r.append(box(Vector3(0.1, WALL_H, 3.5), Vector3(RX + 0.05, WALL_H / 2, 0), TILE))
	walls_r.append(box(Vector3(0.01, 1.4, 3.5), Vector3(RX - 0.006, 1.9, 0), SAGE))
	_tiles_wall(3.5, 1.2, Vector3(RX - 0.001, 0.6, 0), -PI / 2, TILE, walls_r)
	# south (camera-side) wall: low cut wall (0.35 m, white cap) either side of the living-room door
	for seg in [[LX - 0.1, SD.x - 0.025], [SD.y + 0.025, RX + 0.1]]:
		var w: float = seg[1] - seg[0]
		if House.SHOULDER_CAM:   # fix33: full-height south wall (the low cut wall showed the lawn / street from inside)
			walls_s.append(box(Vector3(w, WALL_H, 0.1), Vector3(seg[0] + w / 2, WALL_H / 2, FZ + 0.05), TILE))
			continue
		walls_s.append(box(Vector3(w, 0.35, 0.1), Vector3(seg[0] + w / 2, 0.175, FZ + 0.05), TILE))   # v32-polish: south walls -> WallFade
		walls_s.append(box(Vector3(w, 0.03, 0.12), Vector3(seg[0] + w / 2, 0.365, FZ + 0.05), Color(1, 1, 1)))
	if House.SHOULDER_CAM:
		walls_s.append(box(Vector3(SD.y - SD.x + 0.05, WALL_H - 2.12, 0.1), Vector3((SD.x + SD.y) / 2, (WALL_H + 2.12) / 2, FZ + 0.05), TILE))
	# invisible roof + front wall: shadows only (same as bedroom)
	for bx in [[Vector3(4.9, 0.1, 3.9), Vector3(0, WALL_H + 0.05, 0), Color(0.97, 0.97, 0.96)]]:
		box(bx[0], bx[1], bx[2]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	box(Vector3(4.5, 0.08, 0.02), Vector3(0, 0.04, BZ + 0.01), Color(1, 1, 1))
	box(Vector3(0.02, 0.08, 3.5), Vector3(LX + 0.01, 0.04, 0), Color(1, 1, 1))
	_build_window(); _build_vanity(); _build_mirror(); _build_towel(); _build_bath(); _build_toilet()
	_build_cabinet(); _build_door(); _build_lights(); _build_decor()

func _build_window() -> void:
	var sky := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.8, 0.65); sky.mesh = qm
	sky.material_override = _mat(Color(0.88, 0.94, 0.98), 0.6); sky.position = Vector3(1.35, 1.875, BZ - 0.12)
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sky)
	var fr := Color(0.98, 0.98, 0.98)
	box(Vector3(0.9, 0.05, 0.16), Vector3(1.35, 1.55, BZ + 0.02), fr)
	box(Vector3(0.86, 0.05, 0.08), Vector3(1.35, 2.2, BZ - 0.04), fr)
	box(Vector3(0.05, 0.65, 0.08), Vector3(0.95, 1.875, BZ - 0.04), fr); box(Vector3(0.05, 0.65, 0.08), Vector3(1.75, 1.875, BZ - 0.04), fr)
	N.sash = Node3D.new(); N.sash.position = Vector3(1.35, 1.575, BZ - 0.05); add_child(N.sash)      # tilt sash, hinged at the bottom
	box(Vector3(0.74, 0.6, 0.02), Vector3(0, 0.3, 0), Color(0.92, 0.95, 0.98), N.sash, 0.15, 0.6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(0.76, 0.03, 0.04), Vector3(0, 0.6, 0), fr, N.sash); box(Vector3(0.03, 0.6, 0.04), Vector3(-0.37, 0.3, 0), fr, N.sash)
	box(Vector3(0.03, 0.6, 0.04), Vector3(0.37, 0.3, 0), fr, N.sash); box(Vector3(0.08, 0.025, 0.03), Vector3(0, 0.55, 0.03), DARK, N.sash)
	_spl(prop("plantSmall2", Vector3(1.62, 1.575, BZ + 0.05), 0, 0.22))
	reg("window", "window", Vector3(1.35, 1.9, BZ), Vector3(1.15, 0, BZ + 0.45), Vector3(0.3, 0, -1))

func _build_vanity() -> void:
	var x := SINK.x; var z := BZ + 0.26
	box(Vector3(0.96, 0.46, 0.5), Vector3(x, 0.55, z), CAB)                       # floating vanity cabinet
	box(Vector3(0.98, 0.05, 0.52), Vector3(x, 0.32, z), CAB.darkened(0.04))
	N.vdoor = []
	for i in 2:
		var d := Node3D.new(); d.position = Vector3(x - 0.47 if i == 0 else x + 0.47, 0.55, z + 0.255); add_child(d)
		var sx := 0.235 if i == 0 else -0.235
		box(Vector3(0.465, 0.42, 0.02), Vector3(sx, 0, 0), CAB.lightened(0.3), d)
		box(Vector3(0.012, 0.16, 0.02), Vector3(sx * 1.85, 0, 0.018), DARK, d)
		N.vdoor.append(d)
	box(Vector3(1.0, 0.06, 0.54), Vector3(x, TOP_Y - 0.03, z), WOOD)
	rect_block(x - 0.5, BZ, x + 0.5, z + 0.29)
	box(Vector3(0.5, 0.1, 0.36), Vector3(x, TOP_Y + 0.05, z + 0.02), Color(0.98, 0.98, 0.98))     # basin
	box(Vector3(0.44, 0.012, 0.3), Vector3(x, TOP_Y + 0.095, z + 0.02), Color(0.86, 0.88, 0.9))
	cyl(0.02, 0.004, Vector3(x, TOP_Y + 0.103, z + 0.02), Color.WHITE, self, true)
	N.water_surf = box(Vector3(0.4, 0.004, 0.26), Vector3(x, TOP_Y + 0.105, z + 0.02), Color(0.55, 0.78, 1.0), self, 0.2, 0.55)
	cyl(0.018, 0.2, Vector3(x, TOP_Y + 0.2, BZ + 0.06), Color.WHITE, self, true)                 # faucet
	chrome_box(Vector3(0.03, 0.025, 0.13), Vector3(x, TOP_Y + 0.29, BZ + 0.12))
	N.lever = Node3D.new(); N.lever.position = Vector3(x, TOP_Y + 0.31, BZ + 0.06); add_child(N.lever)
	chrome_box(Vector3(0.015, 0.012, 0.09), Vector3(0, 0, -0.045), N.lever)
	N.spout = Vector3(x, TOP_Y + 0.275, BZ + 0.175)
	# cup with two toothbrushes, toothpaste, soap pump, soap bar, spare towels under the vanity
	N.cup_pos = Vector3(x + 0.36, TOP_Y, BZ + 0.12)
	N.cup = (load(PROPS + "Cup.tscn") as PackedScene).instantiate(); N.cup.position = N.cup_pos + Vector3(0, 0.05, 0); add_child(N.cup)
	N.brush = (load(PROPS + "Toothbrush.tscn") as PackedScene).instantiate(); add_child(N.brush)
	N.brush.position = N.cup_pos + Vector3(-0.01, 0.12, 0.0); N.brush.rotation = Vector3(-PI / 2 + 0.25, 0, 0.2)
	var b2: Node3D = (load(PROPS + "Toothbrush.tscn") as PackedScene).instantiate(); add_child(b2)
	b2.position = N.cup_pos + Vector3(0.012, 0.12, 0.0); b2.rotation = Vector3(-PI / 2 - 0.2, 0, -0.25)
	for m in b2.find_children("*", "MeshInstance3D", true, false): if m.name != "P2": m.material_override = _mat(TERRA)
	N.paste = (load(PROPS + "Toothpaste.tscn") as PackedScene).instantiate(); add_child(N.paste)
	N.paste.position = Vector3(x + 0.33, TOP_Y + 0.012, BZ + 0.33); N.paste.rotation.y = 0.5
	cyl(0.03, 0.13, Vector3(x - 0.38, TOP_Y + 0.065, BZ + 0.1), CREAM)
	cyl(0.008, 0.04, Vector3(x - 0.38, TOP_Y + 0.15, BZ + 0.1), Color.WHITE, self, true)
	chrome_box(Vector3(0.03, 0.01, 0.05), Vector3(x - 0.38, TOP_Y + 0.17, BZ + 0.12))
	box(Vector3(0.09, 0.025, 0.06), Vector3(x - 0.38, TOP_Y + 0.0125, BZ + 0.27), Color(0.98, 0.96, 0.8))
	box(Vector3(0.24, 0.05, 0.18), Vector3(x - 0.3, 0.19, BZ + 0.22), BLUE)
	box(Vector3(0.24, 0.05, 0.18), Vector3(x - 0.3, 0.24, BZ + 0.22), CREAM)
	box(Vector3(0.24, 0.05, 0.18), Vector3(x + 0.25, 0.19, BZ + 0.22), SAGE)
	reg("sink", "sink", Vector3(x, 1.0, BZ + 0.2), Vector3(x, 0, BZ + 0.78), Vector3(0, 0, -1))

func _build_mirror() -> void:
	# frame + light bar, and the bedroom's real planar reflection rotated onto the back wall
	box(Vector3(MSIZE.x + 0.06, MSIZE.y + 0.06, 0.03), Vector3(MC.x, MC.y, BZ + 0.004), Color(0.18, 0.18, 0.2))
	var vp := SubViewport.new(); vp.size = Vector2i(390, 430); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED; add_child(vp)
	N.mirror_cam = Camera3D.new(); N.mirror_cam.cull_mask = 1; N.mirror_cam.keep_aspect = Camera3D.KEEP_HEIGHT; vp.add_child(N.mirror_cam)
	var mq := MeshInstance3D.new(); var qmm := QuadMesh.new(); qmm.size = MSIZE; mq.mesh = qmm; mq.layers = 2
	var mm := StandardMaterial3D.new(); mm.albedo_texture = vp.get_texture(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.97, 0.99, 1.0); mm.uv1_scale = Vector3(-1, 1, 1); mm.uv1_offset = Vector3(1, 0, 0); mq.material_override = mm
	mq.position = MC; mq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mq)
	var sh := MeshInstance3D.new(); var shq := QuadMesh.new(); shq.size = Vector2(0.08, 0.6); sh.mesh = shq; sh.layers = 2
	var shm := StandardMaterial3D.new(); shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(1, 1, 1, 0.12); sh.material_override = shm; sh.position = MC + Vector3(0.2, 0.05, 0.002); sh.rotation.z = -0.5; add_child(sh)
	chrome_box(Vector3(0.6, 0.05, 0.08), Vector3(MC.x, MC.y + MSIZE.y / 2 + 0.09, BZ + 0.04))
	N.mglow = box(Vector3(0.56, 0.02, 0.06), Vector3(MC.x, MC.y + MSIZE.y / 2 + 0.06, BZ + 0.05), Color(1, 0.93, 0.8), self, 3.0)
	N.mlight = OmniLight3D.new(); N.mlight.position = Vector3(MC.x, MC.y + 0.4, BZ + 0.45); N.mlight.light_color = Color(1, 0.85, 0.6)
	N.mlight.omni_range = 2.5; N.mlight.light_energy = 0.6; add_child(N.mlight)
	N.mlight.add_to_group("ow_no_ceiling")   # Yasin 00:23: no lamps switching on while roaming the house (forced off every frame)

func _update_mirror() -> void:
	var v := Vector3(MC.x, 1.5, MZ + 1.3)
	if hero and Vector2(hero.position.x - MC.x, hero.position.z - MZ).length() < 2.0:
		v = Vector3(lerpf(MC.x, hero.position.x, 0.5), 1.5, hero.position.z + 0.6)
	var r := Vector3(v.x, v.y, 2.0 * MZ - v.z)
	var d := MZ - r.z
	N.mirror_cam.position = r; N.mirror_cam.rotation = Vector3(0, PI, 0)
	N.mirror_cam.transform = global_transform * N.mirror_cam.transform   # v34 (blue): SubViewport camera = world space (room not at the origin)
	N.mirror_cam.projection = Camera3D.PROJECTION_FRUSTUM
	N.mirror_cam.near = maxf(0.05, d - 0.002)
	var k: float = N.mirror_cam.near / d
	N.mirror_cam.size = MSIZE.y * k
	N.mirror_cam.frustum_offset = Vector2(-(MC.x - r.x) * k, (MC.y - r.y) * k)

## house.26: towel physics - a damped pendulum (spring) on the rail; kicked when used or brushed past, swings and settles naturally
var _tw_ang := 0.0
var _tw_vel := 0.0
func towel_kick(strength: float) -> void: _tw_vel += 2.2 * strength

func _towel_phys(_dt: float) -> void:
	return   # v30.5: the cloth towel simulates itself (ClothTowel)

func _build_towel() -> void:
	var x := 0.55
	chrome_box(Vector3(0.56, 0.02, 0.02), Vector3(x, 1.32, BZ + 0.07))
	for sx in [-0.28, 0.28]: chrome_box(Vector3(0.02, 0.02, 0.07), Vector3(x + sx, 1.32, BZ + 0.035))
	N.towel = Node3D.new(); N.towel.position = Vector3(x, 1.32, BZ + 0.07); add_child(N.towel)
	# v30.5: blue's verlet cloth towel (scripts/props/cloth_towel.gd) hanging on the rail; gentle indoor breeze
	var ct := ClothTowel.new(); ct.size = Vector2(0.46, 0.62); ct.colour = BLUE; ct.breeze = 0.08; N.towel.add_child(ct)
	ct.attach_to(self, Transform3D(Basis(), Vector3(x, 1.31, BZ + 0.07))); ct.snap.call_deferred()   # build 3.2: room-local pin; N.towel_cloth = ct
	N.towel_used = Node3D.new(); N.towel_used.position = Vector3(x, 1.32, BZ + 0.07); add_child(N.towel_used)
	sheet(Vector2(0.4, 0.5), Vector3(0.03, -0.24, 0.02), BLUE, 0.03, 9, N.towel_used).rotation.z = 0.25
	reg("towel", "towel", Vector3(x, 1.1, BZ + 0.1), Vector3(x, 0, BZ + 0.62), Vector3(0, 0, -1))

## doors (house plan /workspace/world_dev/LAYOUT_DOORS.md): west wall z -0.50..0.40 -> bedroom (= bedroom 3dv2 +X door z 0.75..1.65),
## south (camera-side) wall x -0.45..0.45 -> living room
var TUB_FLOOR := 0.1
const WD := Vector2(-0.5, 0.4)     # west door span (z)
const SD := Vector2(-0.45, 0.45)   # south door span (x)
const FZ := 1.75                   # south wall inner face

func _build_bath() -> void:
	# bathtub along the RIGHT (east) wall, shower set on that wall, bottle shelf, curtain on a rail
	var bt := prop("bathtub", Vector3(RX - 0.42, 0, BZ + 0.9), 90, 0.0, 1.75)
	block(bt)
	var top_y: float = _aabb(bt.get_child(0)).size.y * bt.get_child(0).scale.y
	TUB_FLOOR = top_y * 0.18
	N.tub_water = box(Vector3(0.62, 0.004, 1.5), Vector3(RX - 0.42, top_y * 0.6, BZ + 0.9), Color(0.55, 0.78, 1.0), self, 0.2, 0.01)
	var px := RX - 0.03
	cyl(0.012, 1.0, Vector3(px - 0.02, 1.45, BZ + 0.45), Color.WHITE, self, true)
	cyl(0.07, 0.025, Vector3(px - 0.17, 1.95, BZ + 0.45), Color.WHITE, self, true)
	chrome_box(Vector3(0.16, 0.02, 0.02), Vector3(px - 0.09, 1.96, BZ + 0.45))
	chrome_box(Vector3(0.04, 0.1, 0.16), Vector3(px - 0.02, 0.85, BZ + 0.45))
	N.shower_head = Vector3(px - 0.17, 1.93, BZ + 0.45)
	box(Vector3(0.12, 0.02, 0.4), Vector3(RX - 0.06, 1.15, BZ + 1.3), Color(1, 1, 1))
	for i in 3: cyl(0.025, 0.14 + i * 0.03, Vector3(RX - 0.06, 1.16 + (0.14 + i * 0.03) / 2, BZ + 1.18 + i * 0.12), [TERRA, SAGE.darkened(0.2), CREAM][i])
	chrome_box(Vector3(0.025, 0.025, 1.8), Vector3(RX - 0.8, 2.2, BZ + 0.9))
	N.curtain = Node3D.new(); N.curtain.position = Vector3(RX - 0.8, 2.19, BZ + 0.02); add_child(N.curtain)
	var cs := sheet(Vector2(1.7, 1.6), Vector3(0, -0.8, 0.85), CREAM.lightened(0.3), 0.025, 2, N.curtain); cs.rotation.y = PI / 2
	N.curtain_mat = cs.material_override
	for i in 9: cyl(0.012, 0.004, Vector3(0, 0, 0.05 + i * 0.2), Color.WHITE, N.curtain, true).rotation.x = PI / 2
	reg("bath", "bathtub", Vector3(RX - 0.4, 0.9, BZ + 0.9), Vector3(RX - 1.25, 0, BZ + 1.15), Vector3(1, 0, 0))

func _build_toilet() -> void:
	# toilet in the back-left corner (between the vanity and the bedroom door)
	var tz := BZ + 0.3; var tx := LX + 0.42
	N.toilet = prop("toiletSquare", Vector3(tx, 0, tz), 0, 0.8)
	block(N.toilet)
	box(Vector3(0.16, 0.1, 0.015), Vector3(tx, 1.05, BZ + 0.008), Color(0.98, 0.98, 0.98))
	N.flush = chrome_box(Vector3(0.06, 0.06, 0.01), Vector3(tx, 1.05, BZ + 0.018))
	chrome_box(Vector3(0.02, 0.02, 0.1), Vector3(tx + 0.4, 0.72, BZ + 0.05))
	cyl(0.055, 0.1, Vector3(tx + 0.4, 0.68, BZ + 0.08), Color(0.99, 0.99, 0.99)).rotation.z = PI / 2
	cyl(0.05, 0.3, Vector3(tx + 0.42, 0.15, BZ + 0.12), Color(0.95, 0.95, 0.95), self, false, 0.045)
	rect_block(tx + 0.35, BZ, tx + 0.5, BZ + 0.2)
	reg("toilet", "toilet", Vector3(tx, 0.6, tz), Vector3(tx + 0.02, 0, tz + 0.8), Vector3(0, 0, -1))

func _build_cabinet() -> void:
	# wall cabinet with a hinged door on the right wall (faces -X), above a heated towel rail; south of the bathtub
	var cz := 0.75; var cy := 1.55
	N.cabinet = box(Vector3(0.18, 0.55, 0.5), Vector3(RX - 0.09, cy, cz), CAB)
	box(Vector3(0.14, 0.015, 0.46), Vector3(RX - 0.09, cy, cz), CAB.darkened(0.06))
	for i in 3:
		cyl(0.022, 0.12, Vector3(RX - 0.09, cy + 0.07, cz - 0.15 + i * 0.13), [BLUE, Color(0.98, 0.98, 0.98), TERRA][i])
		box(Vector3(0.06, 0.08, 0.08), Vector3(RX - 0.09, cy - 0.19, cz - 0.12 + i * 0.12), [CREAM, SAGE, Color(0.98, 0.98, 0.98)][i])
	N.cdoor = Node3D.new(); N.cdoor.position = Vector3(RX - 0.19, cy, cz - 0.25); add_child(N.cdoor)
	box(Vector3(0.02, 0.55, 0.5), Vector3(0, 0, 0.25), CAB.lightened(0.3), N.cdoor)
	box(Vector3(0.02, 0.12, 0.012), Vector3(-0.018, 0, 0.45), DARK, N.cdoor)
	for i in 6: chrome_box(Vector3(0.02, 0.02, 0.5), Vector3(RX - 0.08, 0.35 + i * 0.12, cz))
	for sz in [-0.25, 0.25]: chrome_box(Vector3(0.03, 0.72, 0.03), Vector3(RX - 0.08, 0.7, cz + sz))
	sheet(Vector2(0.4, 0.4), Vector3(RX - 0.1, 0.8, cz), SAGE, 0.004, 7, self).rotation.y = PI / 2
	rect_block(RX - 0.2, cz - 0.3, RX, cz + 0.3)
	reg("cabinet", "cabinet", Vector3(RX - 0.1, cy, cz), Vector3(RX - 0.7, 0, cz), Vector3(1, 0, 0))

## frame + sliding panel (slides along the wall into a pocket, like the bedroom door glides)
func _door_frame(parent: Node3D, frosted: bool, inset: float, hinge := -1.0) -> Node3D:
	# house.17: hinged swinging panel (was sliding), same as the bedroom / living-room doors on the other side
	box(Vector3(0.05, 2.17, 0.14), Vector3(-0.475, 1.085, 0), Color(1, 1, 1), parent)
	box(Vector3(0.05, 2.17, 0.14), Vector3(0.475, 1.085, 0), Color(1, 1, 1), parent)
	box(Vector3(1.0, 0.05, 0.14), Vector3(0, 2.145, 0), Color(1, 1, 1), parent)
	var pan := Node3D.new(); pan.position = Vector3(0.45 * hinge, 0, inset); parent.add_child(pan)
	var o := -0.45 * hinge   # panel centre from the hinge
	box(Vector3(0.9, 2.08, 0.04), Vector3(o, 1.04, 0.0), Color(0.82, 0.74, 0.64), pan)
	if frosted:
		box(Vector3(0.62, 1.5, 0.045), Vector3(o, 1.15, 0), Color(0.92, 0.95, 0.98), pan, 0.1, 0.55).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chrome_box(Vector3(0.03, 0.22, 0.06), Vector3(o - 0.36 * hinge, 1.0, 0), pan)
	return pan

func _build_door() -> void:
	# (1) west wall -> bedroom
	var wf := Node3D.new(); wf.position = Vector3(LX - 0.03, 0, (WD.x + WD.y) / 2); wf.rotation.y = PI / 2; add_child(wf)
	N.door_bed = _door_frame(wf, false, 0.08, 1.0); N.door_bed.visible = bedroom_door_panel
	walls_l.append(wf)
	box(Vector3(0.5, 0.012, 0.8), Vector3(LX + 0.3, 0.006, (WD.x + WD.y) / 2), CREAM)
	# (2) south (camera-side) wall -> living room: low cut wall + full frame + frosted sliding door
	var sf := Node3D.new(); sf.position = Vector3((SD.x + SD.y) / 2, 0, FZ + 0.05); add_child(sf)
	N.door = _door_frame(sf, true, -0.08)
	walls_s.append(sf)   # v32-polish: the south door frame + frosted door fade with the south wall (WallFade)
	_wall_fade_setup.call_deferred()
	box(Vector3(0.9, 0.012, 0.5), Vector3((SD.x + SD.y) / 2, 0.006, FZ - 0.3), SAGE.lightened(0.15))
	# light switch next to the living-room door (south wall, inner face)
	box(Vector3(0.08, 0.12, 0.02), Vector3(SD.y + 0.2, 1.2, FZ - 0.0), Color(1, 1, 1))
	N.switch_nub = box(Vector3(0.03, 0.04, 0.02), Vector3(SD.y + 0.2, 1.22, FZ - 0.015), Color(0.6, 0.62, 0.66))
	reg("switch", "light switch", Vector3(SD.y + 0.2, 1.2, FZ), Vector3(SD.y + 0.35, 0, FZ - 0.55), Vector3(-0.3, 0, 1))
	reg("door", "living room door", Vector3((SD.x + SD.y) / 2, 1.2, FZ), Vector3((SD.x + SD.y) / 2, 0, FZ - 0.6), Vector3(0, 0, 1))
	reg("door_bed", "bedroom door", Vector3(LX, 1.2, (WD.x + WD.y) / 2), Vector3(LX + 0.6, 0, (WD.x + WD.y) / 2), Vector3(-1, 0, 0))

func _build_lights() -> void:
	prop("lampSquareCeiling", Vector3(0.0, WALL_H - 0.25, -0.2), 0, 0.25)
	box(Vector3(0.01, 0.1, 0.01), Vector3(0.0, WALL_H - 0.03, -0.2), DARK)
	N.ceil_glow = box(Vector3(0.12, 0.03, 0.12), Vector3(0.0, WALL_H - 0.25, -0.2), Color(1, 0.95, 0.85), self, 3.0)
	N.ceil_light = OmniLight3D.new(); N.ceil_light.position = Vector3(0.0, WALL_H - 0.4, -0.2); N.ceil_light.omni_range = 5.0
	N.ceil_light.add_to_group("ow_no_ceiling")   # Yasin 00:12: no bright centre / ceiling light in any room (World hides them every frame)
	N.ceil_light.light_energy = 0.8; N.ceil_light.light_color = Color(1, 0.96, 0.9); add_child(N.ceil_light)

func _build_decor() -> void:
	prop("rugRectangle", Vector3(RX - 1.12, 0.002, BZ + 0.95), 90, 0.0, 0.85)
	var rug := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 1.0; cy.bottom_radius = 1.0; cy.height = 0.012; cy.radial_segments = 40
	rug.mesh = cy; rug.scale = Vector3(0.42, 1, 0.3); rug.position = Vector3(SINK.x, 0.008, BZ + 0.85); rug.material_override = _mat(SAGE.lightened(0.2)); add_child(rug)
	var pp := prop("pottedPlant", Vector3(LX + 0.25, 0, 1.45), 0, 0.8); block(pp)
	N.plant = pp; reg("plant", "plant", Vector3(LX + 0.25, 0.5, 1.45), Vector3(LX + 0.85, 0, 1.2), Vector3(-1, 0, 0.4))   # v31-fixes: waterable
	var bk := Node3D.new(); bk.position = Vector3(-1.0, 0, 1.45); add_child(bk)               # laundry basket with clothes
	cyl(0.2, 0.5, Vector3(0, 0.25, 0), WOOD.lightened(0.15), bk, false, 0.17)
	for i in 5: cyl(0.205, 0.012, Vector3(0, 0.08 + i * 0.09, 0), WOOD.darkened(0.1), bk, false, 0.19)
	sheet(Vector2(0.3, 0.2), Vector3(0.02, 0.5, 0.02), BLUE, 0.03, 4, bk, false).rotation.z = 0.3
	sheet(Vector2(0.25, 0.2), Vector3(-0.05, 0.51, -0.03), TERRA, 0.03, 8, bk, false).rotation.x = -0.3
	rect_block(-1.22, 1.23, -0.78, 1.67)
	var tc := prop("trashcan", Vector3(0.36, 0, BZ + 0.2), 0, 0.3); block(tc)
	N.scale = box(Vector3(0.3, 0.03, 0.3), Vector3(-1.15, 0.015, 0.45), Color(0.95, 0.95, 0.96))           # bathroom scale
	N.scale_display = box(Vector3(0.12, 0.004, 0.06), Vector3(-1.15, 0.032, 0.37), DARK)
	# framed picture on the left wall above the tiles + small shelf with candles by the mirror
	walls_l.append(box(Vector3(0.02, 0.45, 0.35), Vector3(LX + 0.012, 1.85, 1.15), Color(0.12, 0.12, 0.13)))
	walls_l.append(box(Vector3(0.01, 0.39, 0.29), Vector3(LX + 0.025, 1.85, 1.15), SAGE.lightened(0.15)))
	walls_l.append(box(Vector3(0.012, 0.16, 0.16), Vector3(LX + 0.03, 1.82, 1.15), TERRA))
	box(Vector3(0.36, 0.025, 0.14), Vector3(LX + 0.42, 1.45, BZ + 0.07), WOOD)
	cyl(0.03, 0.07, Vector3(LX + 0.32, 1.497, BZ + 0.07), CREAM); cyl(0.03, 0.05, Vector3(LX + 0.4, 1.487, BZ + 0.07), CREAM)
	_spl(prop("plantSmall1", Vector3(LX + 0.52, 1.4625, BZ + 0.07), 0, 0.18))

func _build_fx() -> void:
	tap_fx = _drops(60, 0.35, 0.006, Vector3(0, -1, 0), 4.0, 0.3, 0.5)
	shower_fx = _drops(220, 0.7, 0.007, Vector3(-0.45, -1, 0), 14.0, 1.4, 2.0)
	splash_fx = _drops(40, 0.4, 0.007, Vector3(0, 1, 0), 60.0, 0.3, 0.6); splash_fx.gravity = Vector3(0, -6, 0); splash_fx.one_shot = true
	foam_fx = _drops(20, 0.5, 0.008, Vector3(0, 1, 0), 80.0, 0.05, 0.15); foam_fx.material_override = _mat(Color(1, 1, 1), 0.2, 0.9); foam_fx.gravity = Vector3(0, -1, 0)

var shower_snd: AudioStreamPlayer
func _shower_sound(on: bool) -> void:
	if shower_snd == null:
		shower_snd = AudioStreamPlayer.new(); shower_snd.name = "ShowerLoop"; add_child(shower_snd)
		var st: AudioStreamOggVorbis = load("res://sfx/shower_loop.ogg"); st = st.duplicate(); st.loop = true
		shower_snd.stream = st; shower_snd.volume_db = Audio.WATER_LEVEL["shower_loop"]   # v32: same loudness as every water sound
		shower_snd.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	if on and not shower_snd.playing: shower_snd.play()
	elif not on and shower_snd.playing:
		var tw := create_tween(); tw.tween_property(shower_snd, "volume_db", -60.0, 0.4)
		tw.tween_callback(func(): shower_snd.stop(); shower_snd.volume_db = Audio.WATER_LEVEL["shower_loop"])

func _drops(n: int, life: float, r: float, dir: Vector3, spread: float, v0: float, v1: float) -> CPUParticles3D:
	var p := CPUParticles3D.new(); p.amount = n; p.lifetime = life; p.emitting = false; p.local_coords = false
	p.direction = dir; p.spread = spread; p.initial_velocity_min = v0; p.initial_velocity_max = v1
	var dm := SphereMesh.new(); dm.radius = r; dm.height = r * 2; dm.radial_segments = 6; dm.rings = 3; p.mesh = dm
	p.material_override = _mat(Color(0.45, 0.7, 1.0), 0.3, 0.85); add_child(p); return p

# ============================================================ states -> visuals
func _to(n: Object, prop_name: String, val, anim: bool, t := 0.8) -> void:
	if anim: create_tween().tween_property(n, prop_name, val, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else: n.set_indexed(prop_name, val)

func _apply_states(anim := false) -> void:
	tap_fx.position = N.spout; tap_fx.emitting = S.tap == "on"
	_to(N.lever, "rotation:y", 0.6 if S.tap == "on" else 0.0, anim, 0.3)
	_to(N.water_surf.material_override, "albedo_color:a", 0.55 if S.tap == "on" else 0.0, anim, 0.6)
	shower_fx.position = N.shower_head; shower_fx.emitting = S.shower == "on"
	_shower_sound(S.shower == "on")
	_to(N.tub_water.material_override, "albedo_color:a", 0.5 if S.shower == "on" else 0.01, anim, 2.0)
	_to(N.curtain, "scale:z", 1.0 if S.curtain == "closed" else 0.16, anim, 0.5)
	_to(N.cdoor, "rotation:y", -1.6 if S.cabinet == "open" else 0.0, anim, 0.7)
	_to(N.door, "rotation:y", deg_to_rad(-82.0) if S.door == "open" else 0.0, anim, 1.1)      # swings into the living room
	_to(N.door_bed, "rotation:y", deg_to_rad(80.0) if S.door_bed == "open" else 0.0, anim, 1.1)  # same hinge/swing as the bedroom door
	_to(N.sash, "rotation:x", 0.35 if S.window == "open" else 0.0, anim, 0.6)
	var on: bool = S.light == "on"
	N.ceil_light.visible = on; N.mlight.visible = on
	(N.ceil_glow.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0
	(N.mglow.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0
	N.switch_nub.position.y = 1.22 if on else 1.18
	env.ambient_light_energy = 0.6 if on else 0.42
	N.towel.visible = S.towel == "hanging"; N.towel_used.visible = S.towel == "used"
	N.brush.visible = S.brush == "cup"

func verbs(id: String) -> Array:
	if extra_verbs.has(id): return extra_verbs[id].call()
	match id:
		_ when id.begins_with("splant"):   # v31: small plants waterable
			if String(S.get(id, "dry")) == "dry": return [["Water", "I am watering the plant.", "water"]]
			return [["Look", "The plant is happy now.", "look"]]
		"sink":
			var v := [["Wash my face and brush my teeth", "I am washing my face.", "routine"]]   # v30.4: one mirror action
			v.append(["Turn off the tap", "I am turning off the tap.", "tap"] if S.tap == "on" else ["Turn on the tap", "I am turning on the tap.", "tap"])
			v.append(["Wash my hands", "I am washing my hands.", "hands"]); v.append(["Look in the mirror", "I am looking in the mirror.", "look"])
			return v
		"towel":
			return [["Dry my hands", "I am drying my hands.", "dry"]]
		"bath":
			return [["Take a shower", "I am taking a shower.", "takeshower"], ["Turn off the shower", "I am turning off the shower.", "shower"] if S.shower == "on" else ["Turn on the shower", "I am turning on the shower.", "shower"],
				["Open the curtain", "I am opening the shower curtain.", "curtain"] if S.curtain == "closed" else ["Close the curtain", "I am closing the shower curtain.", "curtain"]]
		"toilet": return [["Pee", "I am peeing.", "pee"], ["Poop", "I am pooping.", "poop"], ["Flush", "I am flushing the toilet.", "flush"]]
		"cabinet": return [["Close", "I am closing the cabinet.", "toggle"]] if S.cabinet == "open" else [["Open", "I am opening the cabinet.", "toggle"]]
		"switch": return [["Turn off the light", "I am turning off the light.", "toggle"] if S.light == "on" else ["Turn on the light", "I am turning on the light.", "toggle"]]
		"window": return [["Close the window", "I am closing the window.", "toggle"] if S.window == "open" else ["Open the window", "I am opening the window.", "toggle"]]
		"door": return [["Go to the living room", "I am opening the door.", "open"]]   # house.17: one chip opens + goes
		"door_bed": return [["Go to the bedroom", "I am opening the door.", "open"]]
		"plant": return [["Water", "I am watering the plant.", "water"]] if S.plant == "dry" else [["Look", "The plant is happy now.", "look"]]   # v31-fixes
	return []

# ============================================================ actions
func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout
	while House.dormant(self) and is_inside_tree(): await get_tree().process_frame   # v33town: a sleeping room's steps wait until the player is back

## reach gesture (bedroom): play a clip up to the peak, apply the change, play it back
func gesture(kind: String, id: String, change: Callable) -> void:
	var g: Array = {"reach": ["pick_up", 1.35], "sink": ["pick_up", 0.95], "low": ["pick_up", 2.6], "mid": ["pick_up", 1.75], "door": ["open_door", 2.7]}[kind]
	hero.player.speed_scale = 1.0
	hero.player.play(g[0], 0.25)
	await wait(g[1] * 0.8)
	change.call(); _apply_states(true)
	await wait(g[1] * 0.2)
	action_peak.emit(id)
	await wait(0.45)
	hero.player.speed_scale = -1.2
	await wait(g[1] / 1.2 - 0.1)
	hero.player.speed_scale = 1.0
	hero.player.play("idle", 0.3)

func _flip(k: String) -> String:
	return {"on": "off", "off": "on", "open": "closed", "closed": "open"}[S[k]]

func _sink_shot() -> void:
	cam_shot = {"pos": Vector3(SINK.x + 1.65, 1.8, BZ + 1.05), "at": Vector3(SINK.x - 0.05, 1.25, BZ + 0.6)}

func do_verb(id: String, v: Array) -> void:
	if mode != "play": return
	mode = "busy"; _hide_chips(); hand3d.visible = false
	await voice_idle(0.0)   # house.17: an action waits for the current announcement
	var key: String = v[2]
	if hero.position.distance_to(OBJ[id].spot) > 0.5: await caption(GO.get(id, ""))
	await walk_to(OBJ[id].spot, OBJ[id].yaw)
	var t_act := game_t
	if extra_handlers.has(id):
		await extra_handlers[id].call(key, v)
	# v13 fix: an id overridden by bk_extras (e.g. "cabinet") must NOT also run the built-in branch below
	# (it re-toggled the cabinet after the medicine action -> bk QA "cabinet closed after: false")
	match ("" if extra_handlers.has(id) else id):
		_ when id.begins_with("splant"):   # v31: small plants waterable (same action as the bathroom plant)
			await caption(v[1])
			if key == "water":
				hero.hold_item("res://props/watering_can.tscn", "cylinder", 0.26, false)
				await gesture("mid", id, func(): S[id] = "watered"; Audio.sfx("water_drops", -6.0))
				hero.release_item(); await caption("The plant is happy now.")
			else: action_peak.emit(id); await wait(1.5)
		"sink":
			_sink_shot()
			match key:
				"routine":   # v30.4: one mirror action = wash face + brush teeth (both objectives complete)
					Objectives.complete("Go to the mirror.")
					if not S.face_done or S.teeth_done: await wash_face()
					if not S.teeth_done or S.face_done:
						await walk_to(OBJ.sink.spot, OBJ.sink.yaw); _sink_shot(); await brush_teeth()
				"face": await wash_face()
				"teeth": await brush_teeth()
				"hands": await wash_hands()
				"tap":
					await caption(v[1]); await gesture("sink", id, func(): S.tap = _flip("tap"); Audio.sfx("metalClick"); _water_sfx())
				"look":
					await caption(v[1]); hero.play("idle", 0.3); action_peak.emit(id); await wait(1.8)
					await caption("I am smiling."); hero.player.play("wave", 0.3); await wait(1.3); hero.play("idle", 0.3); await wait(0.6)
		"plant":   # v31-fixes: same watering-can action as the bedroom / living-room water_plant()
			await caption(v[1])
			if key == "water":
				hero.hold_item("res://props/watering_can.tscn", "cylinder", 0.26, false)
				await gesture("mid", id, func(): S.plant = "watered"; Audio.sfx("water_drops", -6.0))
				hero.release_item(); await caption("The plant is happy now.")
			else: action_peak.emit(id); await wait(1.5)
		"towel":
			await caption(v[1])
			if key == "fold": await gesture("mid", id, func(): S.towel = "hanging"; Audio.sfx("cloth1"))
			else: await dry_with_towel(false)
		"bath":
			await caption(v[1])
			if key == "takeshower": await take_shower()
			elif key == "shower": await gesture("reach", id, func(): S.shower = _flip("shower"); Audio.sfx("metalClick"); if S.shower == "on": Audio.sfx("water", -3.0, 0.8))
			else: await gesture("door", id, func(): S.curtain = _flip("curtain"); Audio.sfx("cloth3"))
		"toilet":
			if key == "flush": await caption(v[1]); await _flush()
			else: await say_line("I need to pee." if key == "pee" else "I need to poop."); await use_toilet(key)
		"cabinet":
			await caption(v[1]); await gesture("door", id, func(): S.cabinet = _flip("cabinet"); Audio.sfx("drawer", -3.0, 1.1))
		"switch":
			await caption(v[1]); await gesture("door", id, func(): S.light = _flip("light"); Audio.sfx("metalClick", 2.0))
		"window":
			await caption(v[1]); await gesture("door", id, func(): S.window = _flip("window"); Audio.sfx("creak1", -4.0))
		"door_bed":
			if not (S.face_done and S.teeth_done) and WorldState.day < 2:   # v31: day 2+ has no bathroom requirement
				await gesture("door", id, func(): Audio.sfx("handleSmallLeather"))
				await caption("The door is closed. Wash your face and brush your teeth first."); await wait(2.6)
			else:
				await gesture("door", id, func(): S.door_bed = "open"; Audio.sfx("doorOpen_1"))
				if bedroom_scene != "" and ResourceLoader.exists(bedroom_scene):
					App.came_from = "bathroom"; await wait(0.6); await voice_idle(0.0); StoryNav.room(self, bedroom_scene); return   # v32wh: walk through the door (same scene)
		"door":
			if not (S.face_done and S.teeth_done) and WorldState.day < 2:   # v31: day 2+ has no bathroom requirement
				await gesture("door", id, func(): Audio.sfx("handleSmallLeather"))
				await caption("The door is closed. Wash your face and brush your teeth first."); await wait(2.6)
			else:
				await gesture("door", id, func(): S.door = "open"; Audio.sfx("doorOpen_1"))
				await walk_to(Vector3((SD.x + SD.y) / 2, 0, FZ + 0.35), 0.0)
				bathroom_completed.emit()
				if next_scene != "" and ResourceLoader.exists(next_scene):
					App.came_from = "bathroom"; await wait(0.3); await voice_idle(0.0); StoryNav.room(self, next_scene); return   # v32wh: walk through the door (same scene)
				await caption("The living room comes later."); await wait(2.2)
				await walk_to(OBJ.door.spot, PI)
	await voice_idle(0.4)
	last_dur[key] = game_t - t_act
	cam_shot = {}
	mode = "play"; _update_hand(); action_done.emit(id)

func _water_sfx() -> void:
	if S.tap == "on": Audio.tap_sfx(-6.0)

func _hand_pos(sd: String) -> Vector3:
	return hero._hand[sd].global_position

## a second item in the other hand (hold_item() keeps one item): toothpaste, towel
func _attach(scene: String, left: bool, size: float, rot := Vector3.ZERO) -> Node3D:
	var inst: Node3D = (load(scene) as PackedScene).instantiate()
	var piv := Node3D.new(); piv.add_child(inst)
	var ab := _aabb(inst); var s := size / maxf(maxf(ab.size.x, ab.size.y), ab.size.z)
	inst.scale = Vector3.ONE * s; inst.position = -(ab.position + ab.size * 0.5) * s
	piv.position = Vector3(0, 0.1, -0.03); piv.rotation = rot
	hero._hand["L" if left else "R"].add_child(piv); return piv

## v28 blue: the real hand towel (props/bathroom/TowelHand.tscn), real size, draped over the right hand at the palm grip
func _attach_towel() -> Node3D:
	var t := ClothTowel.new(); t.size = Vector2(0.25, 0.8); t.colour = BLUE; t.breeze = 0.05; add_child(t)   # v30.5: cloth in the hand
	t.attach_to(hero._hand["R"], Transform3D(Basis(), Vector3(0, 0.07, -0.03)))
	return t

## hand to the face: the "drink" clip frozen at the hand-at-mouth frame (bedroom read_book() technique)
var FACE_T := 3.5
func _hand_to_face(blend := 0.4, t := 0.6) -> void:
	# house.17: the RIGHT arm (the hand that holds the brush / cup / towel) comes up to the mouth.
	# The "drink" clip raised the LEFT hand, so we use idle + right-arm bone offsets (bk_extras ARM_MOUTH pose).
	hero.player.speed_scale = 1.0; hero.play("idle", blend)
	_arm_r(ARM_MOUTH, t); await wait(t + 0.05)

func _arm_r(p: Array, t: float) -> void:
	_tw_offset("UpperArm.R", Vector3.RIGHT, p[0], t); _tw_offset("LowerArm.R", Vector3.RIGHT, p[1], t)
	_tw_offset("Shoulder.R", Vector3.UP, p[2] if p.size() > 2 else 0.0, t)

const ARM_MOUTH := [-1.05, -1.8, 0.85]

func _hand_down() -> void:
	hero.player.speed_scale = 1.0; hero.play("idle", 0.4)
	_arm_r([0.0, 0.0, 0.0], 0.45); _tw_offset("Hand.R", Vector3.UP, 0.0, 0.2); await wait(0.5)
	for b in ["UpperArm.R", "LowerArm.R", "Shoulder.R", "Hand.R"]: hero.bone_offsets.erase(b)

## bend over the basin: start of "pick_up" up to the reach, then hold
var LEAN_T := 1.15
func _lean_basin() -> void:
	hero.player.speed_scale = 1.0; hero.player.play("pick_up", 0.3); await wait(LEAN_T); hero.player.speed_scale = 0.0

func _straighten() -> void:
	hero.player.speed_scale = -1.4; await wait(0.8); hero.player.speed_scale = 1.0

func _tap(on: bool) -> void:
	if (S.tap == "on") == on: return
	await caption("I am turning on the tap." if on else "I am turning off the tap.")
	await gesture("sink", "sink", func(): S.tap = "on" if on else "off"; Audio.sfx("metalClick"); _water_sfx())

func wash_face() -> void:
	await _tap(true)
	await caption("I am washing my face.")
	# v13: one scoop of water (about half the old length)
	await _lean_basin(); Audio.tap_sfx(-4.0, 1.1); await wait(0.25); await _straighten()
	await _hand_to_face(0.25)
	_tw_offset("Neck", Vector3.RIGHT, 0.25, 0.25)
	splash_fx.global_position = _hand_pos("R") + Vector3(0, 0.08, 0)
	splash_fx.restart(); Audio.tap_sfx(-2.0, 1.3); action_peak.emit("sink")
	get_tree().create_timer(0.15).timeout.connect(func(): Life.snap("wash_face"))   # house.27: day-1 polaroid
	await wait(0.5); _tw_offset("Neck", Vector3.RIGHT, 0.0, 0.25); await _hand_down()
	await _tap(false)
	await walk_to(OBJ.towel.spot, OBJ.towel.yaw)
	cam_shot = {"pos": Vector3(OBJ.towel.spot.x + 1.5, 1.8, BZ + 1.0), "at": Vector3(OBJ.towel.spot.x - 0.05, 1.3, BZ + 0.55)}
	await caption("I am drying my face with the towel.")
	await dry_with_towel(true)
	if not S.face_done:
		S.face_done = true; await caption("My face is clean."); Audio.good(); task_completed.emit("wash_face")
		Objectives.complete("Wash your face.")
		if S.teeth_done: Objectives.set_list(["Go to the living room."]); _set_mission("Go to the living room.")
		else: Objectives.set_list(["Brush your teeth."]); _set_mission("Brush your teeth.")
		_routine_check(); await wait(1.8)

func dry_with_towel(face: bool) -> void:
	await gesture("reach", "towel", func(): S.towel = "hand"; Audio.sfx("cloth1"))
	var tw := _attach_towel()
	if face:
		await _hand_to_face(0.3); _tw_offset("Neck", Vector3.RIGHT, 0.3, 0.3)
		for i in 2:
			_tw_offset("Hand.R", Vector3.UP, 0.35 if i % 2 == 0 else -0.35, 0.22); await wait(0.25)
		_tw_offset("Hand.R", Vector3.UP, 0.0, 0.2); _tw_offset("Neck", Vector3.RIGHT, 0.0, 0.3); await _hand_down()
	else:
		hero.player.play("pick_up", 0.3); await wait(1.0); hero.player.speed_scale = 0.0; Audio.sfx("cloth3"); await wait(1.0); await _straighten(); hero.play("idle", 0.3)
	await gesture("reach", "towel", func(): tw.queue_free(); S.towel = "hanging"; towel_kick(1.0); Audio.sfx("cloth1"))   # house.26: no folding step, the towel swings back

func wash_hands() -> void:
	await _tap(true)
	await caption("I am washing my hands.")
	await _lean_basin()
	for i in 4:
		_tw_offset("Hand.R", Vector3.UP, 0.35 if i % 2 == 0 else -0.35, 0.25); _tw_offset("Hand.L", Vector3.UP, -0.35 if i % 2 == 0 else 0.35, 0.25); await wait(0.28)
	_tw_offset("Hand.R", Vector3.UP, 0.0, 0.2); _tw_offset("Hand.L", Vector3.UP, 0.0, 0.2)
	Audio.tap_sfx(-4.0); action_peak.emit("sink"); await wait(0.3); await _straighten(); hero.play("idle", 0.3)
	await _tap(false)

func brush_teeth() -> void:
	# 1. toothbrush from the cup into the right palm (character.gd hold_item -> BoneAttachment3D Hand.R)
	await caption("I am taking my toothbrush.")
	await gesture("sink", "sink", func(): S.brush = "hand"; hero.hold_item(PROPS + "Toothbrush.tscn", "long", 0.19, false); Audio.sfx("metalClick", -6.0))
	# 2. toothpaste in the left hand, squeeze over the brush
	await caption("I am putting toothpaste on my toothbrush.")
	N.paste.visible = false
	var paste := _attach(PROPS + "Toothpaste.tscn", true, 0.13, Vector3(PI / 2, 0, 0))
	hero.player.speed_scale = 1.0; hero.player.play("pick_up", 0.3); await wait(0.75); hero.player.speed_scale = 0.0
	foam_fx.global_position = _hand_pos("R") + Vector3(0, 0.05, 0); foam_fx.emitting = true
	await wait(1.3); foam_fx.emitting = false
	hero.player.speed_scale = -1.4; await wait(0.5); hero.player.speed_scale = 1.0
	paste.queue_free(); N.paste.visible = true; hero.play("idle", 0.3); await wait(0.3)
	# 3. brush: hand at the mouth, quick side-to-side forearm strokes + foam
	await caption("I am brushing my teeth.")
	_brush_grip(true)
	await _hand_to_face(0.4)
	get_tree().create_timer(0.3).timeout.connect(func(): Life.snap("brush_teeth"))   # house.27: day-1 polaroid
	action_peak.emit("sink")
	foam_fx.emitting = true
	for i in 14:
		foam_fx.global_position = mouth_pos()
		MOUTH.x = 0.025 if i % 2 == 0 else -0.025
		_tw_offset("Hand.R", Vector3.UP, 0.25 if i % 2 == 0 else -0.25, 0.14)
		if i % 4 == 0: Audio.sfx("cloth1", -14.0, 2.2)
		await wait(0.16)
	MOUTH.x = 0.0
	foam_fx.emitting = false; _tw_offset("Hand.R", Vector3.UP, 0.0, 0.15)
	_brush_grip(false); hero.held.transform = brush_rest
	await _hand_down()
	# 4. rinse: tap on, brush back into the cup, cup to the mouth, spit into the basin
	await _tap(true)
	await caption("I am putting my toothbrush back.")
	await gesture("sink", "sink", func(): hero.release_item(); S.brush = "cup"; Audio.sfx("metalClick", -6.0))
	await caption("I am rinsing my mouth.")
	await gesture("sink", "sink", func(): N.cup.visible = false; hero.hold_item(PROPS + "Cup.tscn", "cylinder", 0.1, false))
	await _hand_to_face(0.3); Audio.tap_sfx(-6.0, 1.4); await wait(1.0); await _hand_down()
	await _lean_basin(); splash_fx.global_position = to_global(Vector3(SINK.x, TOP_Y + 0.15, BZ + 0.3)); splash_fx.restart()
	Audio.tap_sfx(-4.0, 0.9); await wait(0.6); await _straighten(); hero.play("idle", 0.3)
	await gesture("sink", "sink", func(): hero.release_item(); N.cup.visible = true)
	await _tap(false)
	if not S.teeth_done:
		S.teeth_done = true; await caption("My teeth are clean."); Audio.good(); task_completed.emit("brush_teeth")
		Objectives.complete("Brush your teeth.")
		if S.face_done: Objectives.set_list(["Go to the living room."]); _set_mission("Go to the living room.")
		else: Objectives.set_list(["Wash your face."]); _set_mission("Wash your face.")
		_routine_check(); await wait(1.8)

# ============================================================ mosaic censor (toilet + shower)
## Pixelates whatever is behind a small camera-facing quad on the hips (hint_screen_texture works in the
## Compatibility renderer: the opaque pass is copied before transparent objects are drawn).
const CENSOR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform float cell_px = 12.0;
uniform float scl = 1.0;
uniform float toward = 0.28;
void vertex() {
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	c += normalize(cam - c) * toward;
	vec3 w = c + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * scl;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	vec2 cell = vec2(cell_px) / VIEWPORT_SIZE;
	vec2 uv = (floor(SCREEN_UV / cell) + 0.5) * cell;
	vec3 col = textureLod(scr, uv, 0.0).rgb;
	vec2 e = abs(UV - 0.5) * 2.0;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.9, 1.0, max(e.x, e.y));
}
"""
## undressed look for the shower / toilet: every clothing surface of Body, Legs, Feet becomes the skin tone
## (smooth neutral body, no anatomy) and the mosaic covers the midsection. Clothes come back with hero._refresh().
func set_undressed(on: bool) -> void:
	undressed = on
	if not on: hero._refresh(); return
	var skin_c := Color(0.87, 0.67, 0.50)
	if int(hero.skin) >= 0: skin_c = hero.SKIN_TONES[int(hero.skin)]
	else:
		for mi in hero._meshes.values():
			if not mi.visible: continue
			for i in mi.mesh.get_surface_count():
				var bm: Material = mi.mesh.surface_get_material(i)
				if bm is StandardMaterial3D and bm.resource_name.begins_with("Skin") and not bm.resource_name.begins_with("Skin_Darker"): skin_c = bm.albedo_color
	var sm := StandardMaterial3D.new(); sm.albedo_color = skin_c; sm.roughness = 0.75
	for mname in hero._meshes:
		var mi: MeshInstance3D = hero._meshes[mname]
		if not mi.visible or mname.contains("_Head"): continue
		for i in mi.mesh.get_surface_count(): mi.set_surface_override_material(i, sm)
var undressed := false

var censor: MeshInstance3D
func set_censor(on: bool) -> void:
	if censor == null:
		var ba := BoneAttachment3D.new(); ba.bone_name = "Hips"; hero.skeleton.add_child(ba)
		censor = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.36, 0.34); censor.mesh = q
		var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = CENSOR_SHADER; sm.shader = sh
		sm.render_priority = 5; censor.material_override = sm
		censor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; censor.extra_cull_margin = 2.0
		censor.position = Vector3(0, -0.04, 0); ba.add_child(censor)
	(censor.material_override as ShaderMaterial).set_shader_parameter("scl", hero.model.scale.y)
	censor.visible = on

# ============================================================ toilet
const SIT_SPEED := 1.5
const SEAT_BACK := 0.42   # stand_to_sit moves the hips this far back (bedroom measurement)
func use_toilet(kind: String) -> void:
	# v13: kept shorter than the face wash (~11-12 s): faster sit/stand clips, hand-wash is a prompt (sink -> "Wash my hands")
	var t0: Vector3 = N.toilet.position
	var stand := Vector3(t0.x, 0, t0.z + 0.12 + SEAT_BACK)   # back to the bowl; stand_to_sit puts the hips on the seat centre
	hero.play("walk", 0.2, 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(hero, "position", stand, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hero, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished; hero.play("idle", 0.15)
	cam_shot = {"pos": Vector3(t0.x + 1.7, 1.55, t0.z + 1.9), "at": Vector3(t0.x, 0.7, t0.z + 0.3)}
	set_censor(true)   # v13b: stays clothed on the toilet; mosaic only
	await say_line("I am sitting on the toilet.")   # v29 review: every toilet step waits for its line
	hero.player.play("stand_to_sit", 0.25); hero.player.speed_scale = SIT_SPEED
	await wait((hero.anim_length("stand_to_sit") - 0.05) / SIT_SPEED)
	hero.player.speed_scale = 1.0
	hero.position += _fwd() * -SEAT_BACK; hero.player.play("sit_idle", 0.0); hero.player.advance(0.0)
	action_peak.emit("toilet")
	await say_line("I am peeing." if kind == "pee" else "I am pooping.")
	if kind == "pee": await wait(0.3); Audio.sfx("trickle", -9.0); await wait(1.9)
	else:
		await wait(1.0); Audio.sfx("plop", -5.0); await wait(0.6)
		await say_line("I am using toilet paper.")
		_tw_offset("UpperArm.L", Vector3.FORWARD, -0.5, 0.35); await wait(0.4); Audio.sfx("cloth3", -4.0, 1.3)
		_tw_offset("UpperArm.L", Vector3.FORWARD, 0.0, 0.35); await wait(0.4)
	await say_line("I am standing up."); await _sit_to_stand(SIT_SPEED)
	set_censor(false)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(hero, "rotation:y", PI, 0.45).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(hero, "position", OBJ.toilet.spot + Vector3(0, 0, -0.25), 0.45)
	await tw2.finished
	await say_line("I am flushing the toilet."); await _flush()
	await say_line("Wash your hands.")

func _flush() -> void:
	await gesture("reach", "toilet", func(): Audio.sfx("metalClick"); Audio.sfx("water", 0.0, 0.7); N.flush.position.z = BZ + 0.012)
	N.flush.position.z = BZ + 0.018

func _sit_to_stand(sp := 1.0) -> void:
	hero.player.play("sit_to_stand", 0.3); hero.player.speed_scale = sp; await wait((hero.anim_length("sit_to_stand") - 0.04) / sp)
	hero.player.speed_scale = 1.0
	var sk := hero.skeleton
	var f0: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L")).origin + sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.R")).origin) * 0.5
	hero.player.play("idle", 0.0); hero.player.advance(0.0)
	var f1: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L")).origin + sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.R")).origin) * 0.5
	var d := f0 - f1; d.y = 0.0
	if d.length() > 0.8: d = _fwd() * 0.41
	hero.player.play("sit_to_stand", 0.0); hero.player.seek(hero.anim_length("sit_to_stand") - 0.04, true)
	hero.player.play("idle", 0.4)
	var tw := create_tween(); tw.tween_property(hero, "position", hero.position + d, 0.4)
	await tw.finished

# ============================================================ shower
func _hop(to: Vector3, t := 0.8) -> void:
	var from := hero.position
	no_steps = true; hero.play("walk", 0.15, 0.8)
	var tw := create_tween()
	tw.tween_method(func(k): hero.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.22, 0), 0.0, 1.0, t).set_trans(Tween.TRANS_SINE)
	await tw.finished; hero.play("idle", 0.2); no_steps = false; Audio.sfx("footstep0%d" % randi_range(0, 3), -10.0, 1.0)

## v13: the whole shower takes at most 15 s (Yasin): step in, curtain, wash, rinse, step out, dry, dress.
## v13b: only 7 spoken lines so every line is said in full inside the cap (each segment = max(animation, clip)).
# v13c: shower 15 s cap removed (Yasin)
var last_dur := {}
var hum_snd: AudioStreamPlayer
func _hum(on: bool) -> void:
	if hum_snd == null:
		hum_snd = AudioStreamPlayer.new(); hum_snd.name = "Hum"; add_child(hum_snd)
		var st: AudioStreamOggVorbis = (load("res://sfx/hum_f.ogg" if S.gender == "women" else "res://sfx/hum_m.ogg") as AudioStreamOggVorbis).duplicate()
		st.loop = true; hum_snd.stream = st; hum_snd.volume_db = -11.0
	if on: hum_snd.pitch_scale = 1.15 if S.age == "child" else 1.0; hum_snd.play()
	else: hum_snd.stop()

## quick hand-to-face (drink clip at 2x up to the hand-at-mouth frame)
func _hand_up_fast() -> void:
	await _hand_to_face(0.2, 0.3)

func _turn(yaw: float, t := 0.35) -> void:
	var tw := create_tween(); tw.tween_property(hero, "rotation:y", yaw, t).set_trans(Tween.TRANS_SINE); await tw.finished

## v13c: speak a line and let it finish before the next animation step starts (nothing is dropped)
func say_line(t: String) -> void:
	await caption(t)
	if S.voice: await voice_idle(0.15)

func take_shower() -> void:
	var tub := Vector3(RX - 0.45, TUB_FLOOR, BZ + 0.75)
	var edge := Vector3(RX - 0.95, 0, BZ + 0.75)
	cam_shot = {"pos": Vector3(RX - 2.3, 2.9, BZ + 2.5), "at": Vector3(RX - 0.5, 0.9, BZ + 0.8)}
	if S.curtain == "closed": await _curtain(false)
	await say_line("I am taking off my clothes.")
	set_censor(true); Audio.sfx("cloth1"); await wait(0.4); set_undressed(true); Audio.sfx("cloth3"); await wait(0.4)
	await say_line("I am getting in the bathtub.")
	var tw := create_tween(); tw.tween_property(hero, "position", edge, 0.3); tw.parallel().tween_property(hero, "rotation:y", PI / 2, 0.3); await tw.finished
	await _hop(tub, 0.6)
	await _turn(-PI / 2, 0.4)
	await say_line("I am closing the shower curtain.")
	await _curtain(true)
	await say_line("I am washing my hair.")
	S.shower = "on"; Audio.sfx("metalClick"); _apply_states(true); Audio.sfx("water", -3.0, 0.8)
	shower_fx.emitting = true; shower_fx.position = Vector3(tub.x + 0.25, 2.0, tub.z)
	_hum(true); action_peak.emit("bath")
	await _hand_up_fast()
	_tw_offset("UpperArm.R", Vector3.RIGHT, -1.45, 0.25)
	foam_fx.emitting = true
	for i in 4:
		foam_fx.global_position = _head_pos() + Vector3(0, 0.1, 0)
		_tw_offset("Hand.R", Vector3.UP, 0.4 if i % 2 == 0 else -0.4, 0.18); await wait(0.2)
	foam_fx.emitting = false; await _hand_down()
	await say_line("I am washing my body.")
	foam_fx.emitting = true
	for i in 3:
		foam_fx.global_position = _head_pos() + Vector3(0, -0.45, 0)
		_tw_offset("UpperArm.R", Vector3.UP, 0.5 if i % 2 == 0 else 0.1, 0.25); _tw_offset("UpperArm.L", Vector3.UP, -0.5 if i % 2 == 0 else -0.1, 0.25)
		await wait(0.28)
	foam_fx.emitting = false; _tw_offset("UpperArm.R", Vector3.UP, 0.0, 0.2); _tw_offset("UpperArm.L", Vector3.UP, 0.0, 0.2)
	await say_line("I am rinsing."); await wait(0.7)
	await say_line("I am turning off the shower.")
	await _turn(PI / 2, 0.35)
	_tw_offset("UpperArm.R", Vector3.FORWARD, 0.9, 0.3); await wait(0.35)
	S.shower = "off"; Audio.sfx("metalClick"); _hum(false); _apply_states(true); shower_fx.position = N.shower_head
	_tw_offset("UpperArm.R", Vector3.FORWARD, 0.0, 0.3); await wait(0.3)
	await _turn(-PI / 2, 0.35)
	await say_line("I am opening the shower curtain.")
	await _curtain(false)
	await say_line("I am getting out of the bathtub.")
	await _hop(edge, 0.6)
	await say_line("I am drying myself with a towel.")
	var towel := _attach_towel()
	Audio.sfx("cloth1")
	await _hand_up_fast()
	for i in 2:
		_tw_offset("Hand.R", Vector3.UP, 0.35 if i % 2 == 0 else -0.35, 0.2); await wait(0.22)
	await _hand_down()
	for i in 2:
		_tw_offset("UpperArm.R", Vector3.UP, 0.5 if i % 2 == 0 else 0.1, 0.25); await wait(0.25)
	_tw_offset("UpperArm.R", Vector3.UP, 0.0, 0.2); await wait(0.2)
	towel.queue_free()
	await say_line("I am putting on my clothes.")
	Audio.sfx("cloth3"); await wait(0.4); set_undressed(false); await wait(0.4); set_censor(false)
	await say_line("I am clean now.")
	var tw5 := create_tween(); tw5.tween_property(hero, "position", OBJ.bath.spot, 0.4); tw5.parallel().tween_property(hero, "rotation:y", OBJ.bath.yaw, 0.4); await tw5.finished
	await wait(0.4)

## v13 toothbrush: while brushing, the brush head is kept exactly at the mouth and the handle points to the palm
## (runs after the character's bone offsets: RenderingServer.frame_pre_draw)
var brushing := false
var brush_rest := Transform3D()
var MOUTH := Vector3(0.0, 0.03, 0.17)   # from the Head bone: (side, up, forward) in the bone frame
func _brush_grip(on: bool) -> void:
	brushing = on
	if on and hero.held: brush_rest = hero.held.transform
	if on and not RenderingServer.frame_pre_draw.is_connected(_aim_brush): RenderingServer.frame_pre_draw.connect(_aim_brush)

func mouth_pos() -> Vector3:
	var sk := hero.skeleton
	var hb := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))
	return hb.origin + hb.basis.x * MOUTH.x + hb.basis.y * MOUTH.y + hb.basis.z * MOUTH.z

func _aim_brush() -> void:
	if not brushing or hero.held == null: return
	var sk := hero.skeleton
	var hb := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand.R"))
	var grip := hb.origin + hb.basis.y.normalized() * 0.07 * hero.model.scale.y
	var m := mouth_pos()
	var dir := (m - grip).normalized()
	var up := (Vector3.UP - dir * dir.dot(Vector3.UP)).normalized()
	var b := Basis(up.cross(dir), up, dir)
	var inst: Node3D = hero.held.get_child(0)
	var head_off := 0.072 * inst.scale.z   # bristles at +Z 0.065 in Toothbrush.tscn
	hero.held.global_transform = Transform3D(b, m - dir * head_off - b * inst.position)

## v13: curtain closed while showering; it turns semi-translucent (frosted) so the cutaway still shows the body shape
func _curtain(close: bool) -> void:
	hero.player.speed_scale = 1.0; hero.player.play("open_door", 0.2); await wait(0.45)
	S.curtain = "closed" if close else "open"; Audio.sfx("cloth3"); _apply_states(true)
	var m: StandardMaterial3D = N.curtain_mat
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	create_tween().tween_property(m, "albedo_color:a", 0.55 if close else 1.0, 0.5)
	await wait(0.3); hero.play("idle", 0.25); await wait(0.15)
	if not close: m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

func _head_pos() -> Vector3:
	var sk := hero.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin

func _tw_offset(bone: String, axis: Vector3, ang: float, t: float) -> void:
	var cur: float = hero.bone_offsets[bone][1] if hero.bone_offsets.has(bone) else 0.0
	var tw := create_tween()
	tw.tween_method(func(a): hero.bone_offsets[bone] = [axis, a], cur, ang, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fwd() -> Vector3:
	return Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y))

# ============================================================ movement + camera (bedroom code)
func _build_grid() -> void:
	astar.region = Rect2i(0, 0, GW, GH); astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; astar.update()
	for x in GW:
		for y in GH:
			astar.set_point_solid(Vector2i(x, y), not _free(_cell_pos(Vector2i(x, y)), R + 0.03))

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x - ROOM.position.x) / 0.1), 0, GW - 1), clampi(int((p.z - ROOM.position.y) / 0.1), 0, GH - 1))

func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(ROOM.position.x + c.x * 0.1 + 0.05, 0, ROOM.position.y + c.y * 0.1 + 0.05)

func _free(p: Vector3, r: float) -> bool:
	if p.x < ROOM.position.x + r or p.x > ROOM.end.x - r or p.z < ROOM.position.y + r or p.z > ROOM.end.y - r: return false
	for o in obstacles:
		if o.grow(r).has_point(Vector2(p.x, p.z)): return false
	return true

func resolve(p: Vector3) -> Vector3:
	p.x = clampf(p.x, ROOM.position.x + R, ROOM.end.x - R); p.z = clampf(p.z, ROOM.position.y + R, ROOM.end.y - R)
	for o in obstacles:
		var g := o.grow(R)
		if g.has_point(Vector2(p.x, p.z)):
			var dl := p.x - g.position.x; var dr := g.end.x - p.x; var du := p.z - g.position.y; var dd := g.end.y - p.z
			var m := minf(minf(dl, dr), minf(du, dd))
			if m == dl: p.x = g.position.x
			elif m == dr: p.x = g.end.x
			elif m == du: p.z = g.position.y
			else: p.z = g.end.y
	p.y = 0.0
	return p

func walk_rate(sp: float) -> float: return clampf(sp / (WALK_CLIP * hero.model.scale.y), 0.5, 1.8)
func run_rate(sp: float) -> float: return clampf(sp / (RUN_CLIP * hero.model.scale.y), 0.6, 2.0)

func walk_to(target: Vector3, yaw: float) -> void:
	var a := _nearest_free(_cell(hero.position)); var b := _nearest_free(_cell(target))
	var path := astar.get_id_path(a, b)
	var pts: Array[Vector3] = []
	for i in range(1, path.size()):
		if i % 3 == 0 or i == path.size() - 1: pts.append(_cell_pos(path[i]))
	pts.append(Vector3(target.x, 0, target.z))
	if hero.position.distance_to(pts[-1]) > 0.06:
		hero.player.speed_scale = 1.0; hero.play("walk", 0.2, walk_rate(WALK))
		for p in pts:
			var guard := 0.0
			while guard < 6.0:
				var d := p - hero.position; d.y = 0
				if d.length() < 0.04: break
				var dt := get_process_delta_time(); guard += dt
				hero.position += d.normalized() * minf(WALK * dt, d.length())
				_face(d, dt)
				await get_tree().process_frame
		hero.position = Vector3(target.x, 0, target.z)
	hero.play("idle", 0.25)
	var t := 0.0
	while absf(angle_difference(hero.rotation.y, yaw)) > 0.03 and t < 1.0:
		var dt := get_process_delta_time(); t += dt
		hero.rotation.y = lerp_angle(hero.rotation.y, yaw, 1.0 - exp(-10.0 * dt))
		await get_tree().process_frame
	hero.rotation.y = yaw

func _nearest_free(c: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c): return c
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(q) and not astar.is_point_solid(q): return q
	return c

func _face(d: Vector3, dt: float) -> void:
	hero.rotation.y = lerp_angle(hero.rotation.y, atan2(d.x, d.z), 1.0 - exp(-12.0 * dt))

var game_t := 0.0   # game-time clock (durations; deterministic with --fixed-fps)
func _gt() -> float: return game_t
func _process(dt: float) -> void:
	game_t += dt
	cam.cam_stick = cam_stick
	if mode == "play" and not frozen and stick.length() > 0.12:
		var cy: float = cam.yaw
		var fwd := Vector3(-sin(cy), 0, -cos(cy)); var right := Vector3(cos(cy), 0, -sin(cy))
		var d := right * stick.x + fwd * -stick.y
		if not was_walking and not hud.cap_panel.visible: caption_if_free("I am walking.")
		was_walking = true
		PlayerController.step(self, d, stick.length(), dt)
		_hide_chips()
	else:
		was_walking = false; running = false; move_sp = 0.0
	if mode == "play" and (stick.length() <= 0.12 or frozen) and hero.player.current_animation in ["walk", "run"]:
		hero.player.speed_scale = 1.0; hero.play("idle", 0.25)
	if mode == "play": _update_hand()
	# shared footsteps (world_dev scripts/core/footsteps.gd): bedroom level, one per foot contact
	if Footsteps.contact(hero.player, hero.anim_length(hero.player.current_animation), step_state) and not no_steps:
		Footsteps.player_step(self, "pave")
	if hand3d.visible and near_id != "": hand3d.position.y = OBJ[near_id].focus.y + 0.55 + sin(Time.get_ticks_msec() * 0.005) * 0.05
	if hum_snd and hum_snd.playing:   # v29 review: humming ducks under the spoken line (no masked words)
		hum_snd.volume_db = move_toward(hum_snd.volume_db, -26.0 if voice_busy() else -11.0, dt * 40.0)
	_update_cam(dt)
	_update_mirror()

## shared CameraRig (world_dev ui/shared/camera_rig.gd) follows a room-framed focus point; scripted shots / QA close-ups
## take the camera over and blend back into the rig framing.
func _rig_xf() -> Transform3D:
	var off := Vector3(sin(cam.yaw) * cos(cam.pitch), sin(cam.pitch), cos(cam.yaw) * cos(cam.pitch)) * cam.dist
	return Transform3D(Basis.IDENTITY, cam.focus + off).looking_at(cam.focus + Vector3(0, 0.3, 0), Vector3.UP)

func _update_cam(dt: float) -> void:
	cam.override_point = Vector3(hero.position.x * 0.35, 0, -0.35 + hero.position.z * 0.3)
	var scripted := not qa_cam.is_empty() or not cam_shot.is_empty() or exit_t < 1.0
	if scripted and cam.controlled: cam.take_over()
	if not qa_cam.is_empty():   # QA close-ups only
		cam.position = qa_cam.pos; cam.look_at(to_global(qa_cam.at), Vector3.UP); _fade_walls(dt); exit_xf = cam.transform; exit_t = 0.0; return
	if not cam_shot.is_empty():
		var k := 1.0 - exp(-2.2 * dt)
		if shot_at == Vector3.INF: shot_at = cam.position - cam.transform.basis.z * 6.0
		cam.position = _over_walls(cam.position.lerp(_shot_l("pos"), k)); shot_at = shot_at.lerp(_shot_l("at"), k)
		cam.look_at(to_global(shot_at), Vector3.UP); _fade_walls(dt); exit_xf = cam.transform; exit_t = 0.0; return
	shot_at = Vector3.INF
	if exit_t < 1.0:
		cam.focus = cam.focus.lerp(cam.override_point, 1.0 - exp(-3.0 * dt))
		exit_t = minf(1.0, exit_t + dt / 0.9)
		cam.transform = exit_xf.interpolate_with(_rig_xf(), ease(exit_t, -2.0)); cam.position = _over_walls(cam.position)
		if exit_t >= 1.0: cam.release(false)
	_fade_walls(dt)

## house.27: a camera move never passes THROUGH a wall (the near plane inside a white tile wall = full-screen white flash):
## while the camera is outside the room it stays above the wall tops
func _over_walls(p: Vector3) -> Vector3:
	var inner := ROOM.grow(-0.08)
	var near_wall := ROOM.grow(0.35).has_point(Vector2(p.x, p.z)) and not inner.has_point(Vector2(p.x, p.z))
	if near_wall and p.y < WALL_H + 0.25: p.y = WALL_H + 0.25
	return p

## walls between the camera and the player fade out (grout/tile containers just hide)
func _fade_walls(dt: float) -> void:
	var eye := hero.position + Vector3(0, 1.2, 0)
	for group in ([] if wall_fade else [[walls_l, cam.position.x < LX], [walls_r, cam.position.x > RX]]):   # v33: side walls -> WallFade occluders
		var occl: bool = group[1]
		for w in group[0]:
			if w is MeshInstance3D:
				var ab: AABB = (w as MeshInstance3D).get_aabb(); ab.position += w.position
				if ab.intersects_segment(cam.position, eye): occl = true
		for w in group[0]:
			var a: float = wall_alpha.get(w, 1.0)
			a = move_toward(a, 0.12 if occl else 1.0, dt * 3.0)
			wall_alpha[w] = a
			if w is MeshInstance3D:
				var m: StandardMaterial3D = w.material_override
				m.albedo_color.a = a
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if a > 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH   # house.24.2: fading walls keep receiving shadows (alpha-blend lost them -> bright patches)
			else:
				w.visible = a > 0.6

func _update_hand() -> void:
	var best := ""; var bd := 0.9
	if mode == "play" and not frozen:
		for id in OBJ:
			var s: Vector3 = OBJ[id].spot
			var d := Vector2(hero.position.x - s.x, hero.position.z - s.z).length()
			if d < bd: bd = d; best = id
	if best != near_id:
		near_id = best
		hud.set_near(NearObj.new(self, best) if best != "" else null)
	hand3d.visible = best != ""
	if best != "": hand3d.position = Vector3(OBJ[best].focus.x, OBJ[best].focus.y + 0.55, OBJ[best].focus.z)

## adapter for GameHUD.set_near(): obj_name + verb_list() -> [[label, Callable]]
class NearObj extends RefCounted:
	var main; var id: String; var obj_name: String
	func _init(m, i: String) -> void: main = m; id = i; obj_name = String(m.OBJ[i].name)
	func verb_list() -> Array:
		var out := []
		for v in main.verbs(id): out.append([v[0], func(): main.do_verb(id, v)])
		return out

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_ENTER]:
		on_action()

## shared HUD phone; main.phone kept for HOOKS.md
var phone: Control
var phone_btn: Button
var frozen := false     # set by GameHUD while the phone is open
var room_phone: Node
func open_phone() -> void:
	if mode == "play": room_phone.open_phone()

func on_action() -> void:
	if mode != "play" or near_id == "": return
	hud.on_action()

func _apply_character() -> void:
	# house.24: the bedroom creator (save.json) is the source of truth; live S only overrides keys it really has
	var cc := DemoCharacter.load_creator()
	if _look_set: for kk in DemoCharacter.CREATOR_KEYS: if S.has(kk): cc[kk] = S[kk]
	else: for k in cc: S[k] = cc[k]
	_look_set = true
	hero.apply_creator(cc)
var _look_set := false

# ============================================================ UI: shared GameHUD (world_dev ui/shared/hud.gd, identical in every scene)
func _sb(c: Color, r := 22, pad := 14) -> StyleBoxFlat: return UI.sb(c, r, pad)

func _build_ui() -> void:
	font = UI.font; font_b = UI.font_b
	hud = (load("res://ui/shared/hud.tscn") as PackedScene).instantiate(); add_child(hud)
	hud.player = self; hud.camera = cam
	hud.tr_func = func(en: String) -> String: return TR.get(en, TR_EXTRA.get(en, room_phone.extra_tr(en) if room_phone else ""))
	hud.voice_func = func(en: String) -> void: if S.voice and not _mute_next and not voice_busy(): say(en)
	S.tr = App.tr_saved(); hud.set_tr(S.tr); hud.set_place("Bathroom", "Banyo")
	S.door_bed = "closed"; S.door = "closed"; _apply_states.call_deferred()   # v32-polish: both doors start closed on every day (day 2 started with the bedroom door open)
	# house.16: the bedroom's phone (scripts/phone.gd) + pocket sequence on the HUD phone button; hud's own phone unused
	room_phone = load("res://scripts/room_phone.gd").new(); add_child(room_phone)
	room_phone.setup(self, hud.phone.get_parent(), hud.phone_btn)
	phone = room_phone.phone; phone_btn = hud.phone_btn
	# house.17: shared pause menu (scripts/game_menu.gd) replaces the HUD's own pause card
	var gm := GameMenu.new(); gm.setup(self, "Bathroom", func(): hud.set_paused(false))
	hud.pause_menu.get_parent().add_child(gm); hud.pause_menu.queue_free(); hud.pause_menu = gm; menu = gm
	cap_panel = hud.cap_panel

var _mute_next := false
## v13b voice timing: a caption never interrupts the line that is still being spoken. caption() first waits
## (max 8 s) for the current clip to finish, then shows the text and plays its clip. Actions `await caption(...)`,
## so the animation that follows runs while the line is spoken and the next line waits for it.
## do_verb() also waits for the last clip (+0.4 s) before the action counts as finished.
func voice_busy() -> bool:
	return Audio.is_speaking()

func voice_idle(tail := 0.4) -> void:
	var t := 0.0
	var spoke := voice_busy()
	while voice_busy() and t < 8.0:
		if not is_inside_tree(): return   # v30.5: scene closed mid-line
		await get_tree().process_frame; t += get_process_delta_time()
	if spoke and tail > 0.0 and is_inside_tree(): await wait(tail)

func clip_len(t: String) -> float:
	var c := _vclip("en:" + t)
	return c.get_length() if c else 0.0

func caption(t: String, speak := true) -> void:
	if House.dormant(self): return   # v33town: a sleeping room shows no caption
	if t != "" and speak and S.voice: await voice_idle(0.05)
	cap_text = t
	if t != "": captioned.emit(t)
	_mute_next = true; hud.caption(t, maxf(4.5, clip_len(t) + 1.0)); _mute_next = false
	if t != "" and speak and S.voice: say(t)
	S.tr = hud.show_tr

## ambient lines (walking / running): skipped while another line is being spoken
func caption_if_free(t: String) -> void:
	if not voice_busy(): await caption(t)

func _set_mission(t: String) -> void:
	if Objectives.stale(t): return   # Yasin 17:58
	mission = t
	# Objectives owns the top-left list; keep GameHUD mission clear to avoid double text
	if hud: hud.set_mission("")
	if t != "" and Objectives.items.is_empty(): Objectives.set_list([t])

func _hide_chips() -> void:
	if hud: hud._hide_chips()

# ============================================================ voice: English Piper clips (TR button = Turkish text only, like the bedroom)
func _load_voice() -> void:
	vplayer = AudioStreamPlayer.new(); add_child(vplayer); vplayer.finished.connect(_vnext)
	if FileAccess.file_exists("res://data/bathroom_voice_index.json"):
		vindex = JSON.parse_string(FileAccess.get_file_as_string("res://data/bathroom_voice_index.json"))
		vfile = FileAccess.open("res://voice/bathroom_voice.bin", FileAccess.READ)

func _vclip(key: String) -> AudioStream:
	for b in voice_banks:
		if b.index.has(key):
			var be: Array = b.index[key]; b.file.seek(int(be[0])); return AudioStreamOggVorbis.load_from_buffer(b.file.get_buffer(int(be[1])))
	if vfile == null or not vindex.has(key): return null
	var e: Array = vindex[key]; vfile.seek(int(e[0]))
	return AudioStreamOggVorbis.load_from_buffer(vfile.get_buffer(int(e[1])))

var voice_log: Array = []   # QA: which clips were queued
func say(t: String) -> void:
	var en := _vclip("en:" + t)
	if en or Audio.narrator_alt(t): Audio.say_player(t, en); voice_log.append("en:" + t)   # universal narrator (one shared function)
	else: Voice.say(t)
	_vnext()

func _vnext() -> void:
	if vqueue.is_empty() or vplayer.playing: return
	vplayer.stream = vqueue.pop_front(); vplayer.play()


func _routine_check() -> void:
	if S.face_done and S.teeth_done:
		_save_progress()
		await wait(1.2); await caption("Go to the living room.")

## house.24.1: same stable lighting as the living room: no lamp specular / distance fade / omni shadows (no camera-dependent hot spots)
func _stable_lights() -> void:
	for l in find_children("*", "OmniLight3D", true, false):
		l.light_specular = 0.0; l.distance_fade_enabled = false; l.shadow_enabled = false; l.omni_attenuation = 1.0


## v30.4: day 1, entering the bathroom: camera pan to the mirror (same 2.6 s shot pattern as the bedroom mirror / door prompts),
## a sound and the top-left mission "Go to the mirror."
## v304: mirror pan owned by black bot (Life.guide_to). Kept as no-op so old call sites stay safe.
func _mirror_prompt(todo: Array) -> void:
	await get_tree().create_timer(0.8, false).timeout
	if mode != "play": return
	var sx: float = OBJ.sink.focus.x
	# v304 (red): frame the player AND the mirror (the old fixed close-up left the player out of frame / behind the camera)
	var at := Vector3(sx, 1.35, BZ + 0.05).lerp(hero.position + Vector3(0, 0.9, 0), 0.6)
	var pos := Vector3(clampf(at.x + 1.3, LX + 0.5, RX - 0.5), 2.45, clampf(maxf(hero.position.z, at.z) + 1.5, BZ + 1.2, FZ - 0.25))
	await Life.guide_to({"pos": pos, "at": at}, "Go to the mirror.",
		{"tr": "Aynaya git.", "list": [{"id": "Go to the mirror.", "en": "Go to the mirror.", "tr": "Aynaya git."}] + todo})
	_set_mission("Go to the mirror.")

## build 3.2: Life.guide_to objective shots (cam_shot.guide) are WORLD space (ShoulderCam frames hero + target with them);
## story cam_shots stay room-local
func _shot_l(k: String) -> Vector3:
	var v: Vector3 = cam_shot[k]
	return to_local(v) if bool(cam_shot.get("guide", false)) else v
