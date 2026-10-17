## English Home 3D: bedroom test. Modern flat UI, touch stick + action button, stateful objects, captions + Turkish.
extends Node3D
const GameMenu = preload("res://scripts/game_menu.gd")

signal action_peak(id: String)
signal action_done(id: String)
signal captioned(text: String)

const FURN := "res://props/furniture/"
const ROOM := Rect2(-3.5, -3.0, 7.0, 6.0)   # x, z
const WALL_H := 2.6
const R := 0.22                              # player radius
const WALK := 1.955           # v11: back to 1.7 m/s; a full stick push runs
const WALK_CLIP := 1.7      # ground speed the walk clip was authored for (feet do not slide at this speed)
const RUN := 3.3            # v11: indoor run speed
var RUN_CLIP := 3.3         # ground speed of the run clip (measured by --qa-walk, see README)
const RUN_ON := 99.0  # house.15: walk only, running disabled
#        # stick length that switches walk -> run (hysteresis below)
const RUN_OFF := 0.64
var running := false
var move_sp := 0.0
# bed (along X, pillow at -X)
const B := Vector3(-1.45, 0, -2.48)
const BED_FRONT := -1.965
const M := 0.44                               # mattress surface for lying / sitting-up poses
var LIE_ROOT := Vector3(B.x + 0.03, M - 0.03, B.z - 0.12)
## v9: lying flat = standing idle pose with the whole model tipped back 90 degrees (feet = model origin)
var LIE_FLAT := Vector3(B.x + 0.88, M + 0.10, B.z - 0.10)
var SIT_ROOT := Vector3(B.x + 0.01, 0, BED_FRONT - 0.18)
var STAND_BED := Vector3(B.x + 0.01, 0, BED_FRONT + 0.23)

const TR := {
	"Get a notebook and a pencil. Let's take notes.": "Bir defter ve kalem al. Hadi not alalım.",
	"Go to the mirror.": "Aynaya git.", "I should take my phone first.": "Önce telefonumu almalıyım.", "The door is locked. Look in the mirror first.": "Kapı kilitli. Önce aynaya bak.",
	"The door is open now.": "Kapı artık açık.", "I am trying to open the door.": "Kapıyı açmaya çalışıyorum.",
	"Look in the mirror.": "Aynaya bak.",
	"What is your name? How do you spell it?": "Adın ne? Nasıl yazılır?",
	"Spell your name.": "Adını harf harf yaz.",
	"My name is": "Benim adım",
	"Now I am choosing my look.": "Şimdi görünüşümü seçiyorum.",
	"Choose how you look.": "Görünüşünü seç.",
	"This is me!": "Bu benim!",
	"I am ready.": "Hazırım.",
	"I am a man.": "Ben bir erkeğim.",
	"I am a woman.": "Ben bir kadınım.",
	"I am thin.": "Zayıfım.",
	"My build is average.": "Vücut yapım ortalama.",
	"I am fat.": "Şişmanım.",
	"I am short.": "Kısayım.",
	"I am medium height.": "Orta boyluyum.",
	"I am tall.": "Uzun boyluyum.",
	"I have short hair.": "Kısa saçlarım var.",
	"I have medium hair.": "Orta uzunlukta saçlarım var.", "I have long hair.": "Uzun saçlarım var.",
	"I have black hair.": "Siyah saçlarım var.", "I have brown hair.": "Kahverengi saçlarım var.", "I have blonde hair.": "Sarı saçlarım var.",
	"I have red hair.": "Kızıl saçlarım var.", "I have white hair.": "Beyaz saçlarım var.",
	"I have side-swept hair.": "Yana taranmış saçlarım var.",
	"I have neat hair.": "Düzgün taranmış saçlarım var.",
	"I have light brown hair.": "Açık kahverengi saçlarım var.",
	"I have dark hair.": "Koyu renk saçlarım var.",
	"I have tied-back hair.": "Arkadan toplanmış saçlarım var.",
	"My skin is light.": "Tenim açık.",
	"My skin is medium.": "Tenim buğday.",
	"My skin is tan.": "Tenim esmer.",
	"My skin is dark.": "Tenim koyu.",
	"I am wearing a sand T-shirt.": "Kum rengi bir tişört giyiyorum.",
	"I am wearing a purple hoodie.": "Mor bir kapüşonlu giyiyorum.",
	"I am wearing a navy T-shirt.": "Lacivert bir tişört giyiyorum.",
	"I am wearing blue jeans.": "Mavi kot pantolon giyiyorum.",
	"I am wearing denim shorts.": "Kot şort giyiyorum.",
	"I am wearing khaki chinos.": "Haki pantolon giyiyorum.",
	"I am wearing red sneakers.": "Kırmızı spor ayakkabı giyiyorum.",
	"I am wearing grey sneakers.": "Gri spor ayakkabı giyiyorum.",
	"I am wearing black shoes.": "Siyah ayakkabı giyiyorum.",
	"I am wearing a white T-shirt.": "Beyaz bir tişört giyiyorum.",
	"I am wearing a teal T-shirt.": "Camgöbeği bir tişört giyiyorum.",
	"I am wearing a black top.": "Siyah bir bluz giyiyorum.",
	"I am wearing rust trousers.": "Kiremit rengi pantolon giyiyorum.",
	"I am wearing black trousers.": "Siyah pantolon giyiyorum.",
	"I am wearing grey flats.": "Gri babet giyiyorum.",
	"I am wearing boots.": "Bot giyiyorum.",
	"I am waking up.": "Uyanıyorum.", "I am getting up.": "Kalkıyorum.",
	"I am making the bed.": "Yatağı topluyorum.", "I am sitting on the bed.": "Yatağın üstüne oturuyorum.",
	"I am lying on the bed.": "Yatağa uzanıyorum.",
	"I am turning off the alarm clock.": "Çalar saati kapatıyorum.", "I am setting the alarm clock.": "Çalar saati kuruyorum.",
	"I am checking the time.": "Saate bakıyorum.",
	"I am turning on the lamp.": "Lambayı açıyorum.", "I am turning off the lamp.": "Lambayı kapatıyorum.",
	"I am opening the drawer.": "Çekmeceyi açıyorum.", "I am closing the drawer.": "Çekmeceyi kapatıyorum.",
	"I am turning on the light.": "Işığı açıyorum.", "I am turning off the light.": "Işığı kapatıyorum.",
	"I am opening the curtains.": "Perdeleri açıyorum.", "I am closing the curtains.": "Perdeleri kapatıyorum.",
	"I am opening the window.": "Pencereyi açıyorum.", "I am closing the window.": "Pencereyi kapatıyorum.",
	"I am looking out of the window.": "Pencereden dışarı bakıyorum.",
	"I am opening the wardrobe.": "Gardırobu açıyorum.", "I am closing the wardrobe.": "Gardırobu kapatıyorum.",
	"I am getting dressed.": "Giyiniyorum.",
	"I am turning on the laptop.": "Dizüstü bilgisayarı açıyorum.", "I am turning off the laptop.": "Dizüstü bilgisayarı kapatıyorum.",
	"I am working on my laptop.": "Bilgisayarımda çalışıyorum.",
	"I am turning on the desk lamp.": "Masa lambasını açıyorum.", "I am turning off the desk lamp.": "Masa lambasını kapatıyorum.",
	"I am looking in the mirror.": "Aynaya bakıyorum.", "I am reading a book.": "Kitap okuyorum.",
	"I am taking a book.": "Bir kitap alıyorum.", "I am putting the book back.": "Kitabı geri koyuyorum.",
	"I am watering the plant.": "Bitkiyi suluyorum.", "The plant is happy now.": "Bitki artık mutlu.",
	"I am opening the door.": "Kapıyı açıyorum.", "The rest of the house comes later.": "Evin geri kalanı daha sonra gelecek.",
	"Turn off the alarm clock.": "Çalar saati kapat.", "Explore your bedroom.": "Yatak odanı keşfet.",
	"Good morning!": "Günaydın!", "I am walking.": "Yürüyorum.", "I am running.": "Koşuyorum.", "I am standing up.": "Ayağa kalkıyorum.",
	"I am closing the door.": "Kapıyı kapatıyorum.",
	"I am going to the bed.": "Yatağa gidiyorum.", "I am going to the alarm clock.": "Çalar saate gidiyorum.",
	"I am going to the bedside table.": "Komodine gidiyorum.", "I am going to the window.": "Pencereye gidiyorum.",
	"I am going to the wardrobe.": "Gardıroba gidiyorum.", "I am going to the desk.": "Masaya gidiyorum.",
	"I am going to the bookcase.": "Kitaplığa gidiyorum.", "I am going to the mirror.": "Aynaya gidiyorum.",
	"I am going to the plant.": "Bitkiye gidiyorum.", "I am going to the light switch.": "Işık düğmesine gidiyorum.",
	"I am going to the door.": "Kapıya gidiyorum.",
"I am brushing my hair.": "Saçımı tarıyorum.", "I am folding my clothes.": "Kıyafetlerimi katlıyorum.",
	"Charge my phone": "Telefonumu şarj et", "Charge my phone.": "Telefonumu şarj et.",
	"I am charging my phone.": "Telefonumu şarj ediyorum.", "I am unplugging my phone.": "Telefonumun fişini çekiyorum.",
	"I am opening the window for some fresh air.": "Temiz hava için pencereyi açıyorum.",
	# v8 phone + jobs
	"Pick up your phone.": "Telefonunu al.", "Choose a job on your phone.": "Telefonunda bir meslek seç.",
	"My phone is on the bedside table.": "Telefonum komodinin üstünde.", "Go to your phone.": "Telefonuna git.",
	"I am picking up my phone.": "Telefonumu alıyorum.", "I am looking at my phone.": "Telefonuma bakıyorum.",
	"I am choosing my job.": "Mesleğimi seçiyorum.", "I am putting my phone down.": "Telefonumu bırakıyorum.",
	"I am opening the Jobs app.": "Meslekler uygulamasını açıyorum.", "I am learning grammar.": "Dilbilgisi öğreniyorum.",
	"I am learning new words.": "Yeni kelimeler öğreniyorum.", "Open the door.": "Kapıyı aç.", "Go to the bathroom.": "Banyoya git.", "I'm in the bedroom now.": "Şimdi yatak odamdayım.", "Go to the living room.": "Oturma odasına git.", "The door is locked. Go to the bathroom first.": "Kapı kilitli. Önce banyoya git.", "I am going to the bathroom.": "Banyoya gidiyorum.",
	"The door is locked. Choose a job on your phone first.": "Kapı kilitli. Önce telefonunda bir meslek seç.",
	# v9 family + calendar
	"I am a child.": "Ben bir çocuğum.", "I am an adult.": "Ben bir yetişkinim.", "I am a boy.": "Ben bir erkek çocuğum.", "I am a girl.": "Ben bir kız çocuğum.",
	"Learn he, she and it.": "He, she ve it öğren.", "Add your family.": "Aileni ekle.", "Open the Calendar.": "Takvimi aç.",
	"I am learning about he, she and it.": "He, she ve it konusunu öğreniyorum.", "I am answering a question.": "Bir soruyu cevaplıyorum.",
	"That is right!": "Doğru!", "Try again.": "Tekrar dene.", "I am adding my family.": "Ailemi ekliyorum.",
	"I am adding a family member.": "Bir aile üyesi ekliyorum.", "I am looking at my calendar.": "Takvimime bakıyorum.",
	"I have a new message on my phone.": "Telefonumda yeni bir mesaj var.", "This is my family.": "Bu benim ailem.",
	"The door is locked. Add your family on your phone first.": "Kapı kilitli. Önce telefonunda aileni ekle.",
	"Choose a job.": "Bir meslek seç.", "Explore the house.": "Evi keşfet.",
	"Teacher. I am a teacher. I work at a school.": "Öğretmen. Ben öğretmenim. Okulda çalışırım.",
	"Doctor. I am a doctor. I work at a hospital.": "Doktor. Ben doktorum. Hastanede çalışırım.",
	"Nurse. I am a nurse. I help sick people.": "Hemşire. Ben hemşireyim. Hasta insanlara yardım ederim.",
	"Cook. I am a cook. I make food.": "Aşçı. Ben aşçıyım. Yemek yaparım.",
	"Police officer. I am a police officer. I help people.": "Polis memuru. Ben polis memuruyum. İnsanlara yardım ederim.",
	"Farmer. I am a farmer. I work on a farm.": "Çiftçi. Ben çiftçiyim. Çiftlikte çalışırım.",
	"Shop assistant. I am a shop assistant. I work in a shop.": "Satış görevlisi. Ben satış görevlisiyim. Bir dükkânda çalışırım.",
	"Bus driver. I am a bus driver. I drive a bus.": "Otobüs şoförü. Ben otobüs şoförüyüm. Otobüs kullanırım.",
	"I am a teacher now.": "Artık öğretmenim.", "I am a doctor now.": "Artık doktorum.", "I am a nurse now.": "Artık hemşireyim.",
	"I am a cook now.": "Artık aşçıyım.", "I am a police officer now.": "Artık polis memuruyum.", "I am a farmer now.": "Artık çiftçiyim.",
	"I am a shop assistant now.": "Artık satış görevlisiyim.", "I am a bus driver now.": "Artık otobüs şoförüyüm.",
}

var hero: DemoCharacter
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var S := {"bed": "unmade", "alarm": "off", "lamp": "off", "drawer": "closed", "ceiling": "on", "curtains": "open",
	"window": "closed", "wardrobe": "closed", "laptop": "off", "desklamp": "off", "plant": "dry", "book": "shelf",
	"door": "closed", "outfit": 0, "phone": "off", "clothes": "messy", "tr": false, "voice": true, "gender": "men", "age": "adult", "build": "average", "height": "medium",
	"name": "", "job": "", "family": [], "lesson_done": false, "calendar_seen": false, "door_opened": false, "created": false, "has_phone": false, "door_locked": true, "skin": 1, "hair": 0, "hair_col": 1, "top": 0, "bottoms": 0, "shoes": 0}
var OBJ := {}            # id -> {name, focus, spot, yaw}
var N := {}              # visual nodes
var obstacles: Array[Rect2] = []
var astar := AStarGrid2D.new()
var mode := "menu"       # menu | opening | play | busy | lying
var near_id := ""
var stick := Vector2.ZERO
var cam_focus := Vector3(0, 0, 0)
var t_ring := 0.0
var hand3d: Sprite3D
# UI
var ui: CanvasLayer
var touch: Control
var font: FontVariation
var font_b: FontVariation
var menu: Control; var menu_play: Button; var settings: Control
var hud: Control; var mission_lbl: Label; var mission_tr: Label
var cap_panel: PanelContainer; var cap_en: Label; var cap_tr: Label; var tr_btn: Button
var chips: VBoxContainer
var cap_text := ""
var started := false
var cam_zoom := 1.0
var cam_yaw := 0.0
var cam_pitch := 0.9025
var cam_dist := 9.68
var cam_stick := Vector2.ZERO
var walls_l: Array = []
var walls_r: Array = []
var was_walking := false
var cam_shot := {}
var shot_at := Vector3.INF
var exit_xf := Transform3D()
var exit_t := 1.0
var last_step_ph := 1.0
var cam_yaw_s := 0.0
var cam_pitch_s := 0.9025
var wall_alpha := {}
var cam_override := false
var cam_avoid = preload("res://scripts/props/wall_fade.gd").CamAvoid.new()   # v33 (blue): follow-camera occlusion avoidance
var mission := ""

# ============================================================ setup
const House := preload("res://scripts/core/house.gd")   # v32wh: whole house
func _ready() -> void:
	if House.shell_ready(self, func(): _build_room(); load("res://scripts/decor/decor_bedroom.gd").build(self)): return   # v32wh: next-door room = geometry only
	_live_ready()

func _live_ready() -> void:   # v32wh: the v32 _ready (also run when this room's shell turns live)
	DoorLabel.attach.call_deferred(self, OBJ, {"door": ["Bathroom", "Banyo"], "door_s": ["Living room", "Oturma odası"]})   # v30.2
	_build_env()
	if not has_meta("wh_built"):   # v32wh: a shell turning live already has its geometry
		_build_room()
		load("res://scripts/decor/decor_bedroom.gd").build(self)   # v305: static bedroom decor (no lights / obstacles)
	_build_grid()
	water_fx = CPUParticles3D.new(); water_fx.amount = 80; water_fx.lifetime = 0.55; water_fx.emitting = false; water_fx.local_coords = false
	water_fx.direction = Vector3(0, -1, 0); water_fx.spread = 8.0; water_fx.initial_velocity_min = 0.4; water_fx.initial_velocity_max = 0.7
	var dm := SphereMesh.new(); dm.radius = 0.008; dm.height = 0.016; water_fx.mesh = dm
	water_fx.material_override = _mat(Color(0.45, 0.7, 1.0), 0.3, 0.85); add_child(water_fx)
	hero = OwLink.hero_for(self); hero.setup(S.gender)
	_pose_sleep()
	cam = OwLink.cam_for(self); cam.fov = 42; cam.current = true
	cam_focus = Vector3(-0.6, 0, -1.0); _update_cam(1.0)
	hand3d = Sprite3D.new(); hand3d.texture = load("res://ui/hand.png"); hand3d.pixel_size = 0.0013
	hand3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED; hand3d.no_depth_test = true; hand3d.modulate = Color(1, 1, 1, 0.95)
	hand3d.render_priority = 10; hand3d.visible = false; add_child(hand3d)
	_build_ui()
	_apply_states()
	menu.visible = false; hud.visible = true
	var app := get_node_or_null("/root/App")
	var qa_args := OS.get_cmdline_user_args()
	if app and (app.continue_requested or app.came_from in ["bathroom", "livingroom", "hospital"]) and load_game():
		_continue_game()
		match app.came_from:   # house.16: just inside the door we came through, facing into the room
			"bathroom": hero.position = Vector3(2.85, 0, 1.2); hero.rotation.y = -PI / 2
			"livingroom": hero.position = Vector3(1.8, 0, 2.4); hero.rotation.y = PI
		cam_focus = hero.position
		app.came_from = ""
	elif not ("--qa" in qa_args or "--qa-mirror" in qa_args or "--qa-cine" in qa_args or "--qa-probe" in qa_args or "--qa-lie" in qa_args or "--qa-walk" in qa_args or "--qa-wake" in qa_args):
		hero.set_mannequin(true); _start_game.call_deferred()
	if not S.created: hero.set_mannequin(true)
	action_done.connect(func(_i): if S.created: save_game())
	if "--qa-mirror" in OS.get_cmdline_user_args():
		var qm = load("res://scripts/qa.gd").new(); add_child(qm); qm.run_mirror(self)
	elif "--qa-probe" in OS.get_cmdline_user_args():
		var qp = load("res://scripts/qa.gd").new(); add_child(qp); qp.run_probe(self)
	elif "--qa-wake" in OS.get_cmdline_user_args():
		var qk = load("res://scripts/qa.gd").new(); add_child(qk); qk.run_wake(self)
	elif "--qa-walk" in OS.get_cmdline_user_args():
		var qw = load("res://scripts/qa.gd").new(); add_child(qw); qw.run_walk(self)
	elif "--qa-lie" in OS.get_cmdline_user_args():
		var ql = load("res://scripts/qa.gd").new(); add_child(ql); ql.run_lie(self)
	elif "--qa-cine" in OS.get_cmdline_user_args():
		var qc = load("res://scripts/qa.gd").new(); add_child(qc); qc.run_cine(self)
	elif "--qa" in OS.get_cmdline_user_args():
		var qa = load("res://scripts/qa.gd").new(); add_child(qa); qa.run(self)
	House.live_ready(self)   # v32wh: the two other rooms as shells next door

## v33town (one persistent house): the bedroom was live before and slept while the player was in another room. Nothing is
## rebuilt or reloaded from defaults: every object (alarm, lamp, door, bed...) is exactly as it was left. Only what other
## rooms / the pause menu can change in save.json "state" (look, TR, voice, family, job...) is taken over, then the usual
## room-entry steps of _continue_game run (caption, story hooks, objective).
const WH_OBJ_KEYS := ["bed", "alarm", "lamp", "drawer", "ceiling", "curtains", "window", "wardrobe", "laptop", "desklamp", "plant", "book", "door", "outfit", "phone", "clothes", "door_locked"]
func _wh_resume() -> void:
	var d: Dictionary = App.load_save()
	if d.get("state") is Dictionary:
		for k in d.state:
			if not S.has(k) or k in WH_OBJ_KEYS: continue
			if k in ["created", "lesson_done", "calendar_seen", "door_opened", "has_phone"] and bool(S[k]) and not bool(d.state[k]): continue   # build 3.2: a stale room save never undoes the mirror (day-2 "Look in the mirror." again)
			S[k] = d.state[k]
	if d.has("has_phone"): S.has_phone = bool(d.has_phone)
	S.tr = App.tr_saved(); _sync_app_phone(); _refresh_text.call_deferred()
	S.door_locked = door_rule()
	_apply_character(); _apply_states()
	menu.visible = false; hud.visible = true
	mode = "play"; _update_hand(); cam_focus = hero.position
	var _ow_from := App.came_from
	App.came_from = ""
	get_tree().create_timer(0.6, false).timeout.connect(func(): caption("I'm in the bedroom now.", false))   # house.17: silent room caption
	# open world: the bedroom was already live; the hospital return (car trip) continues the story here (as _continue_game did)
	var _svh = App.load_save().get("story", {})
	if _ow_from == "hospital" and not (_svh is Dictionary and bool(_svh.get("day1_done", false))):
		hero.position = STAND_BED; hero.rotation.y = 0.0; cam_focus = hero.position
		_home_from_hospital(); _hosp_home = true
	elif _ow_from == "hospital_day2": get_tree().create_timer(1.2, false).timeout.connect(func(): Day2After.run(self, "bedroom"))
	load("res://scripts/story/bedtime.gd").hook_bedroom(self)   # idempotent (named child)
	load("res://scripts/story/day5_routine.gd").attach(get_tree())
	if not _hosp_home: _advance(false)

## v33town: the spot just inside the door the player comes through (same spots as the came_from match in _live_ready)
func _wh_spawn(from: String) -> Array:
	match from:
		"bathroom": return [Vector3(2.85, 0, 1.2), -PI / 2]
		"livingroom": return [Vector3(1.8, 0, 2.4), PI]
	return []

func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c, alpha); m.roughness = 0.85
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
	return m

func box(size: Vector3, pos: Vector3, c: Color, parent: Node = self, emit := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(c, emit, alpha); mi.position = pos; parent.add_child(mi); return mi

func prop(file: String, pos: Vector3, yaw_deg: float, height := 0.0, length := 0.0, parent: Node = self, sy := 1.0) -> Node3D:
	var pivot := Node3D.new(); parent.add_child(pivot)
	var inst: Node3D = (load(FURN + file + ".glb") as PackedScene).instantiate(); pivot.add_child(inst)
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

## world-space XZ footprint of a placed prop -> obstacle
func block(n: Node3D, grow := 0.0) -> Rect2:
	var ab := _aabb(n)
	var xf := n.transform
	var pts := []
	for i in 8: pts.append(xf * ab.get_endpoint(i))
	var r := Rect2(Vector2(pts[0].x, pts[0].z), Vector2.ZERO)
	for p in pts: r = r.expand(Vector2(p.x, p.z))
	r = r.grow(grow); obstacles.append(r); return r

const CENTRE := Vector3(0, 0, 0.5)
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

func _build_env() -> void:
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.86, 0.89, 0.93)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1.0, 0.97, 0.93)
	env.ambient_light_energy = 0.6; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.95
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.95, 0.85); sun.light_specular = 0.25; get_tree().create_timer(0.5).timeout.connect(_stable_lights)
	add_child(sun); sun.look_at_from_position(to_global(Vector3(1.5, 9, -9)), to_global(Vector3(0, 0, 0))); sun.light_energy = 1.3
	sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_fade_start = 1.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 2.5; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2

func _build_room() -> void:
	var floor_c := Color(0.80, 0.66, 0.50); var wall_c := Color(0.90, 0.88, 0.85); var accent := Color(0.62, 0.74, 0.70)
	# floor with plank lines
	box(Vector3(7.0, 0.1, 6.0), Vector3(0, -0.05, 0), floor_c)
	for i in range(1, 12): box(Vector3(7.0, 0.004, 0.012), Vector3(0, 0.002, -3.0 + i * 0.5), floor_c.darkened(0.12))
	# outer ground so the cutaway front edge does not float
	box(Vector3(30, 0.1, 30), Vector3(0, -0.16, 0), Color(0.80, 0.84, 0.88))
	# back wall (z=-3) with window opening x 0.65..1.95, y 0.9..2.2 ; accent paint behind bed
	var bw := Vector3(0, 0, -3.05)
	box(Vector3(4.15, WALL_H, 0.1), Vector3(-1.425, WALL_H / 2, bw.z), wall_c)
	box(Vector3(4.12, WALL_H - 0.02, 0.01), Vector3(-1.425, WALL_H / 2, -2.995), accent)
	box(Vector3(1.55, WALL_H, 0.1), Vector3(2.725, WALL_H / 2, bw.z), wall_c)
	box(Vector3(1.3, 0.9, 0.1), Vector3(1.3, 0.45, bw.z), wall_c)
	box(Vector3(1.3, 0.4, 0.1), Vector3(1.3, 2.4, bw.z), wall_c)
	# left (x=-3.5) and right (x=3.5) walls, low cut so the camera sees in; door opening z 0.75..1.65 on the right
	walls_l.append(box(Vector3(0.1, WALL_H, 6.0), Vector3(-3.55, WALL_H / 2, 0), wall_c))
	walls_r.append(box(Vector3(0.1, WALL_H, 3.75), Vector3(3.55, WALL_H / 2, -1.125), wall_c))
	walls_r.append(box(Vector3(0.1, WALL_H, 1.35), Vector3(3.55, WALL_H / 2, 2.325), wall_c))
	walls_r.append(box(Vector3(0.1, 0.5, 0.9), Vector3(3.55, 2.35, 1.2), wall_c))
	# invisible roof + front wall: cast shadows only, so daylight enters through the window
	N.closed = []
	for bx in [[Vector3(7.4, 0.1, 6.4), Vector3(0, WALL_H + 0.05, 0), Color(0.97, 0.97, 0.96)], [Vector3(7.4, WALL_H, 0.1), Vector3(0, WALL_H / 2, 3.1), wall_c]]:
		var sbx := box(bx[0], bx[1], bx[2]); sbx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY; N.closed.append(sbx)
	_south_wall(-3.5, 3.5, 1.35, 2.25, 2.97, wall_c)   # v30.5
	_wall_fade_setup()
	# skirting boards
	box(Vector3(7.0, 0.08, 0.02), Vector3(0, 0.04, -2.99), Color(1, 1, 1))
	box(Vector3(0.02, 0.08, 6.0), Vector3(-3.49, 0.04, 0), Color(1, 1, 1))
	# sky + window frame, sash, sill, curtains
	var sky := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(6, 4); sky.mesh = qm
	var sm := StandardMaterial3D.new(); sm.albedo_texture = load("res://ui/sky.png"); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.material_override = sm; sky.position = Vector3(1.3, 1.5, -4.2); sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sky)
	var frame_c := Color(0.98, 0.98, 0.98)
	box(Vector3(1.4, 0.06, 0.22), Vector3(1.3, 0.9, -2.93), frame_c)          # sill
	box(Vector3(1.36, 0.05, 0.08), Vector3(1.3, 2.2, -3.0), frame_c)
	box(Vector3(0.05, 1.3, 0.08), Vector3(0.65, 1.55, -3.0), frame_c)
	box(Vector3(0.05, 1.3, 0.08), Vector3(1.95, 1.55, -3.0), frame_c)
	box(Vector3(0.04, 1.3, 0.06), Vector3(1.3, 1.55, -3.02), frame_c)        # fixed mullion
	N.sash = Node3D.new(); N.sash.position = Vector3(1.3, 0.92, -3.0); add_child(N.sash)   # right casement, hinged at mullion
	box(Vector3(0.63, 1.26, 0.04), Vector3(0.325, 0.63, 0), Color(0.75, 0.88, 0.97), N.sash, 0.0, 0.35).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(0.63, 0.04, 0.05), Vector3(0.325, 1.24, 0), frame_c, N.sash); box(Vector3(0.63, 0.04, 0.05), Vector3(0.325, 0.02, 0), frame_c, N.sash)
	box(Vector3(0.04, 1.26, 0.05), Vector3(0.63, 0.63, 0), frame_c, N.sash)
	box(Vector3(0.62, 1.26, 0.02), Vector3(0.97, 1.55, -3.02), Color(0.75, 0.88, 0.97), self, 0.0, 0.35).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(2.1, 0.03, 0.03), Vector3(1.3, 2.38, -2.9), Color(0.25, 0.25, 0.28))  # rod
	N.curtL = box(Vector3(1.0, 1.75, 0.04), Vector3(0, 0, 0), Color(0.93, 0.86, 0.74))
	N.curtR = box(Vector3(1.0, 1.75, 0.04), Vector3(0, 0, 0), Color(0.93, 0.86, 0.74))
	reg("window", "window", Vector3(1.3, 1.5, -2.95), Vector3(1.3, 0, -2.25), Vector3(0, 0, -1))
	# ---------- bed
	N.bed = prop("bedSingle", B, 90, 0.0, 2.05, self, 0.9)
	block(N.bed)
	for pn in N.bed.find_children("pillow*", "MeshInstance3D", true, false): pn.visible = false
	var blue := Color(0.40, 0.56, 0.76)
	N.unmade = Node3D.new(); N.unmade.position = B; add_child(N.unmade)
	sheet(Vector2(1.15, 1.2), Vector3(0.48, 0.475, 0.04), blue, 0.05, 3, 0.2, N.unmade).rotation.y = 0.12
	sheet(Vector2(0.75, 0.55), Vector3(-0.05, 0.47, -0.12), blue.lightened(0.08), 0.04, 7, 0.0, N.unmade).rotation.y = -0.5
	N.made = Node3D.new(); N.made.position = B; add_child(N.made)
	sheet(Vector2(1.62, 1.16), Vector3(0.24, 0.44, 0), blue, 0.006, 5, 0.24, N.made)
	sheet(Vector2(0.22, 1.18), Vector3(-0.5, 0.452, 0), Color(0.96, 0.96, 0.97), 0.004, 9, 0.24, N.made)
	for pz in [0.0]:
		var pil := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; pil.mesh = sp
		pil.scale = Vector3(0.36, 0.13, 0.78); pil.position = B + Vector3(-0.72, 0.48, pz); pil.material_override = _mat(Color(0.97, 0.97, 0.98)); add_child(pil)
	var pil2 := MeshInstance3D.new(); var sp2 := SphereMesh.new(); sp2.radius = 0.5; sp2.height = 1.0; pil2.mesh = sp2
	pil2.scale = Vector3(0.12, 0.26, 0.36); pil2.position = B + Vector3(-0.9, 0.58, 0.18); pil2.rotation.z = -0.3
	pil2.material_override = _mat(Color(0.95, 0.78, 0.62)); add_child(pil2)
	reg("bed", "bed", B + Vector3(0, 0.5, 0), STAND_BED, Vector3(0, 0, -1))
	# ---------- left bedside: drawer cabinet + round lamp
	N.night = prop("cabinetBedDrawer", Vector3(-3.1, 0, -2.68), 0, 0.5)
	block(N.night)
	N.drawer = box(Vector3(0.44, 0.15, 0.04), Vector3(-3.1, 0.36, -2.43), Color(0.85, 0.72, 0.55))
	N.lamp = prop("lampRoundTable", Vector3(-3.15, 0.5, -2.75), 0, 0.5)
	N.lamp_light = OmniLight3D.new(); N.lamp_light.position = Vector3(-3.15, 0.85, -2.6); N.lamp_light.light_color = Color(1, 0.8, 0.55)
	N.lamp_light.omni_range = 2.6; N.lamp_light.light_energy = 1.6; add_child(N.lamp_light)
	N.lamp_glow = box(Vector3(0.14, 0.12, 0.14), Vector3(-3.15, 0.82, -2.75), Color(1, 0.85, 0.6), self, 3.0)
	N.phone_body = box(Vector3(0.075, 0.012, 0.15), Vector3(-2.93, 0.506, -2.6), Color(0.12, 0.12, 0.14))
	N.phone_screen = box(Vector3(0.065, 0.002, 0.135), Vector3(-2.93, 0.513, -2.6), Color(0.05, 0.05, 0.07))
	N.cable = Node3D.new(); add_child(N.cable)
	box(Vector3(0.012, 0.008, 0.33), Vector3(-2.93, 0.505, -2.84), Color(0.95, 0.95, 0.95), N.cable)
	box(Vector3(0.012, 0.5, 0.012), Vector3(-2.93, 0.25, -2.995), Color(0.95, 0.95, 0.95), N.cable)
	box(Vector3(0.08, 0.1, 0.02), Vector3(-2.93, 0.25, -2.99), Color(0.98, 0.98, 0.98))
	reg("night", "bedside table", Vector3(-3.1, 0.6, -2.65), Vector3(-3.05, 0, -1.9), Vector3(0, 0, -1))
	# ---------- right bedside: side table + alarm clock + book
	N.side = prop("cabinetBedDrawer", Vector3(0.05, 0, -2.7), 0, 0.5)
	block(N.side)
	N.alarm = Node3D.new(); N.alarm.position = Vector3(0.05, 0.5, -2.7); add_child(N.alarm)
	box(Vector3(0.2, 0.12, 0.08), Vector3(0, 0.06, 0), Color(0.2, 0.22, 0.26), N.alarm)
	N.alarm_face = box(Vector3(0.16, 0.08, 0.01), Vector3(0, 0.065, 0.041), Color(0.1, 0.1, 0.1), N.alarm)
	N.alarm_txt = Label3D.new(); N.alarm_txt.text = "7:00"; N.alarm_txt.font_size = 40; N.alarm_txt.pixel_size = 0.0018
	N.alarm_txt.position = Vector3(0, 0.065, 0.048); N.alarm_txt.font = load("res://fonts/Nunito.ttf"); N.alarm.add_child(N.alarm_txt)
	N.ring = Label3D.new(); N.ring.text = "Ring! Ring!"; N.ring.font_size = 64; N.ring.pixel_size = 0.004; N.ring.outline_size = 14
	N.ring.billboard = BaseMaterial3D.BILLBOARD_ENABLED; N.ring.no_depth_test = true; N.ring.modulate = Color(1, 0.35, 0.3)
	N.ring.outline_modulate = Color(1, 1, 1); N.ring.position = Vector3(0.05, 1.1, -2.6); N.ring.font = load("res://fonts/Nunito.ttf"); add_child(N.ring)
	prop("books", Vector3(0.12, 0.5, -2.6), 15, 0.0, 0.25)
	reg("alarm", "alarm clock", Vector3(0.05, 0.6, -2.7), Vector3(0.05, 0, -1.92), Vector3(0, 0, -1))
	# ---------- wardrobe on the left wall (doors face +X), z -0.6..0.6
	var wd := Color(0.96, 0.95, 0.93); var wood := Color(0.72, 0.56, 0.40)
	box(Vector3(0.62, 2.1, 1.24), Vector3(-3.19, 1.05, 0), wd)
	box(Vector3(0.56, 2.0, 1.16), Vector3(-3.15, 1.05, 0), Color(0.55, 0.45, 0.38))       # dark interior
	box(Vector3(0.02, 0.02, 1.1), Vector3(-3.15, 1.85, 0), Color(0.6, 0.6, 0.62))
	var cols := [Color(0.85, 0.35, 0.3), Color(0.3, 0.5, 0.75), Color(0.95, 0.85, 0.5), Color(0.35, 0.6, 0.45), Color(0.9, 0.9, 0.9)]
	for i in 5: box(Vector3(0.04, 0.8, 0.16), Vector3(-3.12, 1.42, -0.42 + i * 0.21), cols[i])
	box(Vector3(0.62, 0.08, 1.24), Vector3(-3.19, 2.14, 0), wood)
	N.clothes_messy = Node3D.new(); add_child(N.clothes_messy)
	sheet(Vector2(0.45, 0.4), Vector3(-3.15, 0.14, 0.3), Color(0.85, 0.4, 0.35), 0.04, 2, 0.0, N.clothes_messy).rotation.y = 0.4
	sheet(Vector2(0.4, 0.35), Vector3(-3.12, 0.18, 0.25), Color(0.3, 0.45, 0.7), 0.05, 4, 0.0, N.clothes_messy).rotation.y = -0.6
	N.clothes_folded = Node3D.new(); add_child(N.clothes_folded)
	var fc := [Color(0.85, 0.4, 0.35), Color(0.3, 0.45, 0.7), Color(0.9, 0.9, 0.88)]
	for i in 3: box(Vector3(0.3, 0.05, 0.3), Vector3(-3.15, 0.13 + i * 0.055, 0.3), fc[i], N.clothes_folded)
	N.wdoorL = Node3D.new(); N.wdoorL.position = Vector3(-2.87, 0.05, -0.6); add_child(N.wdoorL)
	N.wdoorR = Node3D.new(); N.wdoorR.position = Vector3(-2.84, 0.05, 0.6); add_child(N.wdoorR)
	box(Vector3(0.03, 1.98, 0.59), Vector3(0, 0.99, 0.295), wd.darkened(0.03), N.wdoorL); box(Vector3(0.03, 0.3, 0.025), Vector3(0.025, 1.0, 0.55), Color(0.3, 0.3, 0.3), N.wdoorL)
	box(Vector3(0.03, 1.98, 0.59), Vector3(0, 0.99, -0.295), wd.darkened(0.03), N.wdoorR); box(Vector3(0.03, 0.3, 0.025), Vector3(0.025, 1.0, -0.55), Color(0.3, 0.3, 0.3), N.wdoorR)
	obstacles.append(Rect2(-3.5, -0.62, 0.65, 1.24))
	reg("wardrobe", "wardrobe", Vector3(-3.0, 1.2, 0), Vector3(-2.15, 0, 0), Vector3(-1, 0, 0))
	# ---------- mirror on the left wall
	# frame: dark metal with a light inner bevel (highlight)
	box(Vector3(0.04, 1.70, 0.56), Vector3(-3.47, 1.25, 2.05), Color(0.18, 0.18, 0.2))
	for fb in [[Vector3(0.012, 0.012, 0.5), Vector3(-3.428, 2.065, 2.05)], [Vector3(0.012, 0.012, 0.5), Vector3(-3.428, 0.435, 2.05)],
			[Vector3(0.012, 1.64, 0.012), Vector3(-3.428, 1.25, 1.806)], [Vector3(0.012, 1.64, 0.012), Vector3(-3.428, 1.25, 2.294)]]:
		box(fb[0], fb[1], Color(0.92, 0.93, 0.95), self, 0.35).layers = 2
	# planar reflection: SubViewport camera mirrored behind the glass plane (x = MIRROR_X), near plane on the glass,
	# texture flipped horizontally. 240x710, works in gl_compatibility. The glass quad is on layer 2, which this camera skips.
	var vp := SubViewport.new(); vp.size = Vector2i(240, 810); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED; add_child(vp)
	N.mirror_cam = Camera3D.new(); N.mirror_cam.cull_mask = 1; N.mirror_cam.keep_aspect = Camera3D.KEEP_HEIGHT; vp.add_child(N.mirror_cam)
	var mq := MeshInstance3D.new(); var qmm := QuadMesh.new(); qmm.size = Vector2(0.48, 1.62); mq.mesh = qmm; mq.layers = 2
	var mm := StandardMaterial3D.new(); mm.albedo_texture = vp.get_texture(); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.90, 0.96, 1.0)          # slight cool glass tint
	mm.uv1_scale = Vector3(-1, 1, 1); mm.uv1_offset = Vector3(1, 0, 0); mq.material_override = mm
	mq.position = Vector3(MIRROR_X, 1.25, 2.05); mq.rotation.y = PI / 2; mq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mq)
	# soft diagonal sheen on the glass
	var sh := MeshInstance3D.new(); var shq := QuadMesh.new(); shq.size = Vector2(0.09, 1.2); sh.mesh = shq; sh.layers = 2
	sh.material_override = _mat(Color(1, 1, 1), 0.0, 0.10); (sh.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sh.position = Vector3(MIRROR_X + 0.004, 1.2, 2.12); sh.rotation = Vector3(0.0, PI / 2, 0.35); sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(sh)
	_update_mirror()
	# ---- mirror cues (until the character is created): pulsing glow frame + floating marker
	N.mirror_glow = box(Vector3(0.02, 1.80, 0.66), Vector3(-3.445, 1.25, 2.05), Color(0.45, 0.65, 1.0), self, 2.0, 0.0)
	N.mirror_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cone := CylinderMesh.new(); cone.top_radius = 0.11; cone.bottom_radius = 0.0; cone.height = 0.22; cone.radial_segments = 16
	N.mirror_marker = MeshInstance3D.new(); N.mirror_marker.mesh = cone; N.mirror_marker.position = Vector3(-3.1, 2.45, 2.05)
	var mkm := _mat(Color(0.31, 0.47, 1.0), 1.2); mkm.no_depth_test = true; mkm.render_priority = 5
	N.mirror_marker.material_override = mkm; N.mirror_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(N.mirror_marker)
	reg("mirror", "mirror", Vector3(-3.4, 1.3, 2.05), Vector3(-2.85, 0, 2.05), Vector3(-1, 0, 0))
	# v30.5: hand towel on a wall hook next to the mirror (blue's ClothTowel, gentle indoor breeze)
	box(Vector3(0.05, 0.03, 0.34), Vector3(-3.46, 1.56, 2.68), Color(0.6, 0.6, 0.62))
	var btw := ClothTowel.new(); btw.size = Vector2(0.3, 0.5); btw.colour = Color(0.93, 0.78, 0.55); btw.breeze = 0.08; add_child(btw)
	btw.attach_to(self, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-3.43, 1.55, 2.68))); btw.snap.call_deferred()   # build 3.2: room-local pin (top_level cloth; was world coords -> towel in the living room); N.bed_towel = btw
	# ---------- plant front-left corner
	N.plant = prop("pottedPlant", Vector3(-3.15, 0, 1.0), 0, 1.0)
	block(N.plant)
	reg("plant", "plant", Vector3(-3.15, 0.6, 1.0), Vector3(-2.5, 0, 1.0), Vector3(-1, 0, 0))
	# ---------- desk back-right corner + chair, lamp, laptop
	N.desk = prop("desk", Vector3(2.75, 0, -2.62), 0, 0.76)
	block(N.desk)
	N.chair = prop("chairDesk", Vector3(2.75, 0, -1.6), 180, 1.0)
	N.laptop = prop("laptop", Vector3(2.6, 0.76, -2.62), 0, 0.0, 0.36)
	N.screen = box(Vector3(0.3, 0.19, 0.005), Vector3(2.6, 0.88, -2.72), Color(0.25, 0.55, 0.95), self, 1.2)
	N.screen.rotation.x = -0.2
	N.dlamp = prop("lampSquareTable", Vector3(3.2, 0.76, -2.75), 0, 0.45)
	N.dlamp_light = OmniLight3D.new(); N.dlamp_light.position = Vector3(3.2, 1.25, -2.55); N.dlamp_light.light_color = Color(1, 0.88, 0.7)
	N.dlamp_light.omni_range = 2.2; N.dlamp_light.light_energy = 1.5; add_child(N.dlamp_light)
	N.dlamp_glow = box(Vector3(0.12, 0.1, 0.12), Vector3(3.2, 1.12, -2.75), Color(1, 0.9, 0.7), self, 3.0)
	_spl(prop("plantSmall1", Vector3(2.15, 0.76, -2.8), 0, 0.25))
	N.desk_book = prop("books", Vector3(2.95, 0.76, -2.5), -20, 0.0, 0.22)
	reg("desk", "desk", Vector3(2.75, 0.9, -2.62), Vector3(2.75, 0, -2.02), Vector3(0, 0, -1))
	# ---------- bookcase on the right wall (faces -X)
	N.shelf = prop("bookcaseOpen", Vector3(3.3, 0, -0.85), -90, 1.75)
	block(N.shelf)
	# v32-polish: books seated ON the shelf boards (bookcaseOpen.glb shelf tops y = 0.13 / 0.37 / 0.61 of 0.88, scaled 1.75/0.88);
	# they used to float 0.16 m above each board
	for i in 3: prop("books", Vector3(3.3, (0.13 + i * 0.24) * 1.75 / 0.88, -0.95 + (i % 2) * 0.15), -90, 0.0, 0.32)
	_spl(prop("plantSmall3", Vector3(3.3, 1.76, -0.85), 0, 0.3))
	N.shelf_book = box(Vector3(0.16, 0.24, 0.05), Vector3(3.3, 0.37 * 1.75 / 0.88 + 0.122, -0.62), Color(0.85, 0.3, 0.3))   # v32-polish: standing on the 2nd board
	reg("books", "bookcase", Vector3(3.3, 1.2, -0.85), Vector3(2.6, 0, -0.85), Vector3(1, 0, 0))
	# ---------- light switch + door on the right wall
	box(Vector3(0.02, 0.12, 0.08), Vector3(3.49, 1.2, 0.35), Color(1, 1, 1))
	N.switch_nub = box(Vector3(0.02, 0.04, 0.03), Vector3(3.475, 1.22, 0.35), Color(0.6, 0.62, 0.66))
	reg("switch", "light switch", Vector3(3.45, 1.2, 0.35), Vector3(2.9, 0, 0.35), Vector3(1, 0, 0))
	box(Vector3(0.12, 2.12, 0.05), Vector3(3.5, 1.06, 0.73), Color(1, 1, 1)); box(Vector3(0.12, 2.12, 0.05), Vector3(3.5, 1.06, 1.67), Color(1, 1, 1))
	box(Vector3(0.12, 0.05, 0.99), Vector3(3.5, 2.12, 1.2), Color(1, 1, 1))
	N.door = Node3D.new(); N.door.position = Vector3(3.53, 0, 0.76); add_child(N.door)
	box(Vector3(0.05, 2.08, 0.88), Vector3(0, 1.04, 0.44), Color(0.82, 0.74, 0.64), N.door)
	box(Vector3(0.1, 0.03, 0.12), Vector3(-0.04, 1.0, 0.78), Color(0.3, 0.3, 0.32), N.door)
	reg("door", "door", Vector3(3.5, 1.2, 1.2), Vector3(2.85, 0, 1.2), Vector3(1, 0, 0))
	# house.15: simple south door (x 1.35..2.25, z=3.0) -> living room door_bed
	N.door_s = Node3D.new(); N.door_s.position = Vector3(1.35, 0, 3.02); add_child(N.door_s)   # house.17: hinged at x 1.35
	box(Vector3(0.9, 2.08, 0.05), Vector3(0.45, 1.04, 0), Color(0.82, 0.74, 0.64), N.door_s)
	box(Vector3(0.12, 0.03, 0.1), Vector3(0.75, 1.0, -0.05), Color(0.3, 0.3, 0.32), N.door_s)
	reg("door_s", "living room door", Vector3(1.8, 1.2, 3.0), Vector3(1.8, 0, 2.4), Vector3(0, 0, 1))
	# ---------- ceiling pendant + decor
	N.pendant = prop("lampSquareCeiling", Vector3(0.2, 2.25, -0.3), 0, 0.35)
	N.ceil_light = OmniLight3D.new(); N.ceil_light.position = Vector3(0.2, 2.1, -0.3); N.ceil_light.omni_range = 6.0
	N.ceil_light.add_to_group("ow_no_ceiling")   # Yasin 00:12: no bright centre / ceiling light in any room (World hides them every frame)
	N.ceil_light.light_energy = 0.8; N.ceil_light.light_color = Color(1, 0.96, 0.9); add_child(N.ceil_light)
	N.ceil_glow = box(Vector3(0.16, 0.04, 0.16), Vector3(0.2, 2.26, -0.3), Color(1, 0.95, 0.85), self, 3.0)
	box(Vector3(0.01, 0.4, 0.01), Vector3(0.2, 2.45, -0.3), Color(0.2, 0.2, 0.2))
	var rug := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 1.0; cy.bottom_radius = 1.0; cy.height = 0.012; cy.radial_segments = 48
	rug.mesh = cy; rug.scale = Vector3(1.3, 1, 0.85); rug.position = Vector3(0.1, 0.008, 0.25); rug.material_override = _mat(Color(0.80, 0.84, 0.90)); add_child(rug)
	var rug2 := MeshInstance3D.new(); var cy2 := CylinderMesh.new(); cy2.top_radius = 1.0; cy2.bottom_radius = 1.0; cy2.height = 0.014; cy2.radial_segments = 48
	rug2.mesh = cy2; rug2.scale = Vector3(1.05, 1, 0.62); rug2.position = Vector3(0.1, 0.009, 0.25); rug2.material_override = _mat(Color(0.92, 0.90, 0.86)); add_child(rug2)
	_poster("res://ui/poster1.png", Vector3(-1.9, 1.55, -2.97), Vector2(0.5, 0.7), 0)
	_poster("res://ui/poster2.png", Vector3(-1.1, 1.6, -2.97), Vector2(0.55, 0.55), 0)
	_poster("res://ui/poster3.png", Vector3(2.75, 1.65, -2.97), Vector2(0.45, 0.63), 0)
	_poster("res://ui/poster2.png", Vector3(-3.47, 1.5, -1.5), Vector2(0.5, 0.5), 90)
	# floating shelf over desk with books
	box(Vector3(0.9, 0.03, 0.22), Vector3(2.75, 1.2, -2.89), Color(0.72, 0.56, 0.40))
	prop("books", Vector3(2.55, 1.215, -2.89), 0, 0.0, 0.26); _spl(prop("plantSmall2", Vector3(3.0, 1.215, -2.89), 0, 0.22))
	# small rug by the bed side
	box(Vector3(1.3, 0.012, 0.6), Vector3(-1.4, 0.006, -1.6), Color(0.95, 0.93, 0.88))

## soft cloth: subdivided plane with gentle wrinkles, edges hanging down over the mattress sides
func sheet(size: Vector2, pos: Vector3, c: Color, amp: float, seed: int, drop: float, parent: Node) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 28; var nz := 20
	var pts := []
	for iz in nz + 1:
		for ix in nx + 1:
			var u := float(ix) / nx; var v := float(iz) / nz
			var x := (u - 0.5) * size.x; var z := (v - 0.5) * size.y
			var y := amp * (sin(x * 9.0 + seed) * 0.6 + sin(z * 13.0 + seed * 2.0) * 0.4 + sin((x + z) * 6.0 + seed * 0.7) * 0.5)
			var ez := clampf((absf(z) - 0.47) / maxf(size.y * 0.5 - 0.47, 0.001), 0.0, 1.0)
			var ex := clampf((x - (size.x * 0.5 - 0.06)) / 0.06, 0.0, 1.0) if size.x > 1.0 else 0.0
			y -= drop * (ez * ez * (3.0 - 2.0 * ez)) + drop * ex
			pts.append(Vector3(x, y, z))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			for k in [a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]: st.add_vertex(pts[k])
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := _mat(c); m.cull_mode = BaseMaterial3D.CULL_DISABLED; mi.material_override = m
	mi.position = pos; parent.add_child(mi); return mi

const MIRROR_X := -3.43
const MIRROR_C := Vector3(-3.43, 1.25, 2.05)
## virtual viewer: standing in front of the mirror at eye height (follows the player when close), reflected through the glass
func _update_mirror() -> void:
	var v := Vector3(-1.9, 1.5, 2.05)
	if hero and Vector2(hero.position.x - MIRROR_X, hero.position.z - MIRROR_C.z).length() < 2.2:
		v = Vector3(hero.position.x + 0.95, 1.5, lerpf(MIRROR_C.z, hero.position.z, 0.5))
	var r := Vector3(2.0 * MIRROR_X - v.x, v.y, v.z)
	var d := MIRROR_X - r.x
	N.mirror_cam.position = r
	# off-axis frustum: the camera looks straight through the glass (near plane = glass plane), so nothing
	# behind the mirror (wall, frame) leaks in, and the image matches the glass rectangle exactly.
	N.mirror_cam.rotation = Vector3(0, -PI / 2, 0)
	N.mirror_cam.transform = global_transform * N.mirror_cam.transform   # v34 (blue): a SubViewport camera is in WORLD space; the room is not at the origin in the open world
	N.mirror_cam.projection = Camera3D.PROJECTION_FRUSTUM
	N.mirror_cam.near = maxf(0.05, d - 0.002)
	var k: float = N.mirror_cam.near / d
	N.mirror_cam.size = 1.62 * k
	N.mirror_cam.frustum_offset = Vector2((MIRROR_C.z - r.z) * k, (MIRROR_C.y - r.y) * k)

func _poster(tex: String, pos: Vector3, size: Vector2, yaw: float) -> void:
	var fr := box(Vector3(size.x + 0.05, size.y + 0.05, 0.02), pos, Color(0.12, 0.12, 0.13)); fr.rotation.y = deg_to_rad(yaw)
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = size; q.mesh = qm
	var m := StandardMaterial3D.new(); m.albedo_texture = load(tex); m.roughness = 0.9; q.material_override = m
	q.rotation.y = deg_to_rad(yaw); q.position = pos + Vector3(0, 0, 0.012).rotated(Vector3.UP, deg_to_rad(yaw)); add_child(q)

# ============================================================ states -> visuals
var _tw_by := {}
func _to(n: Object, prop: String, val, anim: bool, t := 0.8) -> void:
	# house.17: only animate what actually changes (no stray window / curtain tweens from other objects)
	var cur = n.get_indexed(NodePath(prop))
	if typeof(cur) == typeof(val) and (cur == val or (cur is float and is_equal_approx(cur, val)) or (cur is Vector3 and cur.is_equal_approx(val))): return
	if _tw_by.has([n, prop]) and is_instance_valid(_tw_by[[n, prop]]): _tw_by[[n, prop]].kill()
	if anim:
		_tw_by[[n, prop]] = create_tween()
		_tw_by[[n, prop]].tween_property(n, prop, val, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT); return
	if anim: create_tween().tween_property(n, prop, val, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else: n.set_indexed(NodePath(prop), val)

func _apply_states(anim := false) -> void:
	N.unmade.visible = S.bed == "unmade" and not (blanket != null and is_instance_valid(blanket)); N.made.visible = S.bed == "made"   # Yasin 23:58: no rumpled mound under the sleep blanket
	var lamp_on: bool = S.lamp == "on"
	N.lamp_light.visible = lamp_on; N.lamp_glow.visible = lamp_on
	_to(N.drawer, "position:z", -2.43 + (0.25 if S.drawer == "open" else 0.0), anim)
	var c_on: bool = S.ceiling == "on"
	N.ceil_light.visible = c_on; N.ceil_glow.visible = c_on; N.switch_nub.position.y = 1.22 if c_on else 1.18
	_set_curtains(S.curtains == "open", anim)
	_to(N.sash, "rotation:y", deg_to_rad(-65.0) if S.window == "open" else 0.0, anim, 1.0)
	_to(N.wdoorR, "position:z", 0.0 if S.wardrobe == "open" else 0.6, anim, 0.9)
	var lt_on: bool = S.laptop == "on"
	N.screen.material_override = _mat(Color(0.3, 0.6, 0.98) if lt_on else Color(0.06, 0.06, 0.08), 1.4 if lt_on else 0.0)
	N.dlamp_light.visible = S.desklamp == "on"; N.dlamp_glow.visible = S.desklamp == "on"
	for m in N.plant.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = null if S.plant == "watered" else _mat(Color(0.75, 0.6, 0.25), 0.0, 0.55)
	N.shelf_book.visible = S.book == "shelf"
	N.desk_book.visible = true
	N.cable.visible = S.phone == "charging" and not S.has_phone
	N.phone_body.visible = not S.has_phone; N.phone_screen.visible = not S.has_phone   # v13: carried phone is not on the table
	N.phone_screen.material_override = _mat(Color(0.3, 0.9, 0.45) if S.phone == "charging" else Color(0.05, 0.05, 0.07), 1.5 if S.phone == "charging" else 0.0)
	N.clothes_messy.visible = S.clothes == "messy"; N.clothes_folded.visible = S.clothes == "folded"
	_to(N.door, "rotation:y", deg_to_rad(80.0) if S.door == "open" else 0.0, anim, 1.1)
	_set_alarm_visual()
	# light balance
	var day: bool = S.curtains == "open"
	sun.light_energy = (1.6 * WorldState.daylight()) if day else 0.0   # house.29: shared clock
	env.ambient_light_energy = 0.22 + (0.16 if c_on else 0.0) + (0.14 if day else 0.0) + (0.05 if lamp_on else 0.0) + (0.04 if S.desklamp == "on" else 0.0)

func _set_curtains(open: bool, anim := false) -> void:
	var w := 0.32 if open else 0.7
	_to(N.curtL, "scale:x", w, anim, 1.0); _to(N.curtR, "scale:x", w, anim, 1.0)
	_to(N.curtL, "position", Vector3(0.25 + w * 0.5, 1.5, -2.88), anim, 1.0); _to(N.curtR, "position", Vector3(2.35 - w * 0.5, 1.5, -2.88), anim, 1.0)

var _alarm_was := ""
func _set_alarm_visual() -> void:
	var st: String = S.alarm
	if st == "off" and _alarm_was == "ringing": App.patch_save({"alarm_off_day": maxi(WorldState.day, App.day)})   # build 3.2: this morning's alarm is done (Continue re-arms it otherwise)
	_alarm_was = st
	N.ring.visible = st == "ringing"
	N.alarm_txt.modulate = {"ringing": Color(1, 0.3, 0.3), "set": Color(0.4, 1, 0.6), "off": Color(0.7, 0.7, 0.7)}[st]
	N.alarm_txt.text = "7:00" if st != "set" else "7:00 •"
	if st != "ringing": N.alarm.rotation = Vector3.ZERO

# ============================================================ verbs
## [chip label, sentence, key]
func verbs(id: String) -> Array:
	match id:
		_ when id.begins_with("splant"):   # v31: small plants waterable
			if String(S.get(id, "dry")) == "dry": return [["Water", "I am watering the plant.", "water"]]
			return [["Look", "The plant is happy now.", "look"]]
		"bed":
			var v := []
			if S.bed == "unmade": v.append(["Make the bed", "I am making the bed.", "make"])
			v.append(["Sit", "I am sitting on the bed.", "sit"]); v.append(["Lie down", "I am lying on the bed.", "lie"])
			return v
		"alarm":
			if S.alarm == "ringing": return [["Turn off", "I am turning off the alarm clock.", "off"]]
			if S.alarm == "set": return [["Turn off", "I am turning off the alarm clock.", "off"], ["Check the time", "I am checking the time.", "check"]]
			return [["Set the alarm", "I am setting the alarm clock.", "set"], ["Check the time", "I am checking the time.", "check"]]
		"night":
			var pv := [["Pick up the phone", "I am picking up my phone.", "pickup"]] if S.created and not S.has_phone else []
			if S.has_phone and S.created and Life.NEEDS_ENABLED: pv = [["Charge my phone", "I am charging my phone.", "charge"]]   # v30.5: place + plug in; v32-polish: hidden while Life.NEEDS_ENABLED is false
			return pv + [["Turn off the lamp", "I am turning off the lamp.", "lamp"] if S.lamp == "on" else ["Turn on the lamp", "I am turning on the lamp.", "lamp"],
				["Close the drawer", "I am closing the drawer.", "drawer"] if S.drawer == "open" else ["Open the drawer", "I am opening the drawer.", "drawer"],
				] + ([] if (S.has_phone or not Life.NEEDS_ENABLED) else [["Unplug the phone", "I am unplugging my phone.", "phone"] if S.phone == "charging" else ["Charge the phone", "I am charging my phone.", "phone"]])   # v32-polish: no charge / unplug verbs while needs+battery are off
		"window":
			var v := [["Close the curtains", "I am closing the curtains.", "curtains"] if S.curtains == "open" else ["Open the curtains", "I am opening the curtains.", "curtains"]]
			if S.curtains == "open":
				v.append(["Close the window", "I am closing the window.", "window"] if S.window == "open" else ["Open the window", "I am opening the window for some fresh air.", "window"])
				v.append(["Look out", "I am looking out of the window.", "look"])
			return v
		"wardrobe":
			if S.wardrobe == "open":
				var v := [["Get dressed", "I am getting dressed.", "dress"]]
				if S.clothes == "messy": v.append(["Fold clothes", "I am folding my clothes.", "fold"])
				v.append(["Close", "I am closing the wardrobe.", "toggle"])
				return v
			return [["Open", "I am opening the wardrobe.", "toggle"]]
		"desk":
			var v := [["Turn off the laptop", "I am turning off the laptop.", "laptop"] if S.laptop == "on" else ["Turn on the laptop", "I am turning on the laptop.", "laptop"],
				["Turn off the lamp", "I am turning off the desk lamp.", "dlamp"] if S.desklamp == "on" else ["Turn on the lamp", "I am turning on the desk lamp.", "dlamp"]]
			if S.laptop == "on": v.append(["Work", "I am working on my laptop.", "work"])
			return v
		"mirror": return [["Look", "I am looking in the mirror.", "look"], ["Brush my hair", "I am brushing my hair.", "brush"]]
		"books":
			if S.book == "shelf": return [["Take a book", "I am taking a book.", "take"]]
			return [["Read", "I am reading a book.", "read"], ["Put it back", "I am putting the book back.", "back"]]
		"plant":
			if S.plant == "dry": return [["Water", "I am watering the plant.", "water"]]
			return [["Look", "The plant is happy now.", "look"]]
		"switch":
			return [["Turn off the light", "I am turning off the light.", "toggle"] if S.ceiling == "on" else ["Turn on the light", "I am turning on the light.", "toggle"]]
		"door": return [["Go to the bathroom", "I am trying to open the door.", "try"]] if (S.door_locked or (not S.has_phone and WorldState.day < 2)) else [["Go to the bathroom", "I am opening the door.", "open"]]   # v32 (red): "take your phone first" is a day-1 rule (day 3: the phone is still charging from bedtime)
		"door_s": return [["Go to the living room", "I am trying to open the door.", "try"]] if s_locked() else [["Go to the living room", "I am opening the door.", "go"]]
	return []

# ============================================================ actions
func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout
	while House.dormant(self) and is_inside_tree(): await get_tree().process_frame   # v33town: a sleeping room's steps wait until the player is back

## reach gesture: play the start of a clip up to the peak, apply the change, then play it back to the start.
func gesture(kind: String, id: String, change: Callable) -> void:
	var g: Array = {"reach": ["pick_up", 1.35], "low": ["pick_up", 2.6], "mid": ["pick_up", 1.75], "door": ["open_door", 2.7]}[kind]
	hero.player.speed_scale = 1.0
	hero.player.play(g[0], 0.25)
	await wait(g[1] * 0.8)
	change.call(); _apply_states(true)          # objects start moving as the hand arrives
	await wait(g[1] * 0.2)
	action_peak.emit(id)
	await wait(0.45)
	hero.player.speed_scale = -1.2
	await wait(g[1] / 1.2 - 0.1)
	hero.player.speed_scale = 1.0
	hero.player.play("idle", 0.3)

func do_verb(id: String, v: Array) -> void:
	if mode != "play": return
	mode = "busy"; _hide_chips(); hand3d.visible = false
	await Audio.wait_idle(12.0)   # house.17: an action waits for the current announcement
	var key: String = v[2]
	var yaw: float = OBJ[id].yaw
	if id == "bed" and key != "make": yaw = 0.0          # turn your back to the bed before sitting down
	if hero.position.distance_to(OBJ[id].spot) > 0.5: caption("I am going to the %s." % OBJ[id].name)
	await walk_to(OBJ[id].spot, yaw)
	caption(v[1])
	match id:
		_ when id.begins_with("splant"):   # v31: small plants waterable
			if key == "water": await water_plant(id)
			else: action_peak.emit(id); await wait(1.5)
		"bed":
			if key == "make": await gesture("mid", id, func(): S.bed = "made"; Audio.sfx("cloth1"))
			elif key == "sit":
				await sit_on_bed(); action_peak.emit(id); await wait(2.0)
				caption("I am standing up."); await stand_from_bed()
			elif key == "lie":
				await lie_down(); S.bed = "unmade"; _apply_states()
				action_peak.emit(id); mode = "lying"; _update_hand(); action_done.emit(id); return
		"alarm":
			await gesture("mid", id, func(): Audio.sfx("metalClick"); S.alarm = {"off": "off", "set": "set", "check": S.alarm}.get(key, "off") if key != "set" else "set")
			if key == "off":
				if S.created and maxi(WorldState.day, App.day) <= 1 and not get_tree().root.has_node("Day56Routine"): _set_mission("Explore your bedroom.")   # int: day-1 mission only (ui33: never flashes after the day-5/6 alarm)
				elif S.created: _advance(false)   # build 3.2 (black #19): day 2+ continues the story, never the day-1 "Explore your bedroom."
				else:
					Objectives.set_list(["Look in the mirror."]); _set_mission("Look in the mirror.")
					await _cine_mirror(); hint_t = 0.0; get_tree().create_timer(0.2, false).timeout.connect(_mirror_hint)
					Audio.sfx("notify", -4.0)
		"night":
			if key == "pickup": await phone_pickup()
			elif key == "charge": await gesture("reach", id, func(): charge_phone())
			elif key == "phone": await gesture("reach", id, func(): S.phone = "off" if S.phone == "charging" else "charging"; Audio.sfx("metalClick"))
			else: await gesture("reach", id, func(): S[key] = _flip(key); Audio.sfx("drawer" if key == "drawer" else "metalClick"))
		"window":
			if key == "look": hero.play("idle", 0.3); action_peak.emit(id); await wait(2.2)
			else: await gesture("door", id, func():
				S[key] = _flip(key); Audio.sfx("cloth1" if key == "curtains" else "creak1", -4.0 if key == "window" else 0.0))
		"wardrobe":
			if key == "dress":
				await gesture("reach", id, func():
					Audio.sfx("cloth3"); S.top = (S.top + 1) % 3; S.bottoms = (S.bottoms + 1) % 3; _apply_character())
			elif key == "fold": await gesture("mid", id, func(): S.clothes = "folded"; Audio.sfx("cloth3"))
			else: await gesture("door", id, func(): S.wardrobe = _flip("wardrobe"); Audio.sfx("drawer", -3.0, 0.8))
		"desk":
			if key == "work": await sit_at_desk()
			elif key == "laptop": await gesture("reach", id, func(): S.laptop = _flip("laptop"); Audio.sfx("click"))
			else: await gesture("reach", id, func(): S.desklamp = _flip("desklamp"); Audio.sfx("metalClick"))
		"mirror":
			cam_shot = {"pos": Vector3(-1.05, 2.3, 3.5), "at": Vector3(-3.0, 1.25, 1.95)}
			if key == "brush":
				hero.hold_item("res://props/brush.tscn", "long", 0.22, false)
				hero.player.play("phone_call", 0.35); await wait(1.6); action_peak.emit(id); await wait(1.6)
				hero.player.play("idle", 0.4); await wait(0.4); hero.release_item()
			elif not S.created: hero.play("idle", 0.3); action_peak.emit(id); await creation_flow()
			else: hero.play("idle", 0.3); action_peak.emit(id); await wait(2.2)
		"books":
			if key == "read": await read_book()
			elif key == "take": await gesture("reach", id, func(): S.book = "hand"; Audio.sfx("bookPlace1"); hero.hold_item("res://props/book.tscn", "flat", 0.24, true))
			else: await gesture("reach", id, func(): S.book = "shelf"; Audio.sfx("bookPlace1"); hero.release_item())
		"plant": 
			if key == "water": await water_plant()
			else: action_peak.emit(id); await wait(1.5)
		"switch": await gesture("door", id, func(): S.ceiling = _flip("ceiling"); Audio.sfx("metalClick", 2.0))
		"door_s" when s_locked():
			await gesture("door", id, func(): Audio.sfx("metalClick"))
			var why := "The door is locked. Go to the bathroom first."
			if S.door_locked:
				if not _job_chosen(): why = "The door is locked. Choose a job on your phone first."
				elif not _family_ok(): why = "The door is locked. Add your family on your phone first."
				else: why = "The door is locked."
			caption(why); await wait(2.6)
		"door_s":
			await gesture("door", id, func(): Audio.sfx("doorOpen_1"); create_tween().tween_property(N.door_s, "rotation:y", deg_to_rad(-82.0), 1.0))
			S.door_opened = true; App.came_from = "bedroom"; save_game(); await wait(0.3)
			await Audio.wait_idle(12.0); StoryNav.room(self, "res://livingroom.tscn"); return   # v32wh: walk through the door (same scene)
		"door" when S.door_locked:
			await gesture("door", id, func(): _rattle_door())
			await wait(0.3)
			var why := "The door is locked."
			if S.created and not S.has_phone: why = "I should take my phone first."
			elif not S.created: why = "The door is locked. Look in the mirror first."
			elif not _job_chosen(): why = "The door is locked. Choose a job on your phone first."
			elif not _family_ok(): why = "The door is locked. Add your family on your phone first."
			caption(why); await wait(2.6)
		"door":
			await gesture("door", id, func(): S.door = "open"; Audio.sfx("doorOpen_1"); Audio.sfx("creak1", -3.0))
			S.door_opened = true; _advance(false)
			App.came_from = "bedroom"; save_game(); await wait(0.5)
			await Audio.wait_idle(12.0); StoryNav.room(self, "res://bathroom.tscn"); return   # v32wh: walk through the door (same scene)
			await wait(2.2); caption("I am closing the door."); S.door = "closed"; _apply_states(true); await wait(0.9); Audio.sfx("doorClose_2")
	cam_shot = {}
	mode = "play"; _update_hand(); action_done.emit(id)

func _flip(k: String) -> String:
	var a := {"on": "off", "off": "on", "open": "closed", "closed": "open"}
	return a[S[k]]

## reading pose: the book is in the left hand; the "drink" clip frozen where the hand is raised in front of the chest,
## plus a small neck tilt to look at the page.
func read_book() -> void:
	hero.player.play("drink", 0.4); hero.player.seek(1.6, true)
	await wait(0.9)
	hero.player.speed_scale = 0.0
	_tw_offset("Neck", Vector3.RIGHT, 0.35, 0.5)
	Audio.sfx("bookOpen"); action_peak.emit("books")
	await wait(1.2); Audio.sfx("bookFlip1"); await wait(1.0)
	_tw_offset("Neck", Vector3.RIGHT, 0.0, 0.4)
	hero.player.speed_scale = 1.0; hero.player.play("idle", 0.5); await wait(0.5)

func _tw_offset(bone: String, axis: Vector3, ang: float, t: float) -> void:
	var cur: float = hero.bone_offsets[bone][1] if hero.bone_offsets.has(bone) else 0.0
	var tw := create_tween()
	tw.tween_method(func(a): hero.bone_offsets[bone] = [axis, a], cur, ang, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

var water_fx: CPUParticles3D
## v30.5: put the carried phone on the end table and plug it in (refills over time, ~50 s to 100%)
func charge_phone() -> void:
	S.has_phone = false; S.phone = "charging"
	N.phone_body.visible = true; N.phone_screen.visible = true
	Audio.sfx("metalClick"); Audio.sfx("notify", -6.0)
	_apply_states()
	save_game()

func water_plant(id := "plant") -> void:
	hero.hold_item("res://props/watering_can.tscn", "cylinder", 0.26, false)
	hero.player.play("pick_up", 0.3); await wait(1.55)
	hero.player.speed_scale = 0.0
	var hb: Node3D = hero._hand["R"]
	water_fx.global_position = hb.global_position + _fwd() * 0.18 + Vector3(0, -0.02, 0)
	water_fx.emitting = true; Audio.sfx("water")
	await wait(0.5); S[id] = "watered"; _apply_states(true); action_peak.emit(id)
	await wait(1.2); water_fx.emitting = false
	hero.player.speed_scale = -1.2; await wait(1.2)
	hero.player.speed_scale = 1.0; hero.player.play("idle", 0.3); hero.release_item()

func sit_at_desk() -> void:
	# chair is behind the spot: stand_to_sit moves the hips 0.42 back, then typing
	hero.player.play("stand_to_sit", 0.3); await wait(hero.anim_length("stand_to_sit") - 0.05)
	hero.position += _fwd() * -0.42; hero.player.play("typing", 0.0); hero.player.advance(0.0); action_peak.emit("desk")
	await wait(3.0)
	caption("I am standing up."); await _sit_to_stand()

func _fwd() -> Vector3:
	return Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y))

func _sit_to_stand() -> void:
	hero.player.play("sit_to_stand", 0.35); await wait(hero.anim_length("sit_to_stand") - 0.04)
	# v11: hand over to idle without a jump: keep the feet where they are
	var sk := hero.skeleton
	var f0: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L")).origin + sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.R")).origin) * 0.5
	hero.player.play("idle", 0.0); hero.player.advance(0.0)
	var f1: Vector3 = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.L")).origin + sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot.R")).origin) * 0.5
	var d := f0 - f1; d.y = 0.0
	if d.length() > 0.8: d = _fwd() * 0.41
	# back to the last sit_to_stand frame, then crossfade into idle while sliding the root by d at the same linear rate
	hero.player.play("sit_to_stand", 0.0); hero.player.seek(hero.anim_length("sit_to_stand") - 0.04, true)
	hero.player.play("idle", 0.4)
	var tw := create_tween(); tw.tween_property(hero, "position", hero.position + d, 0.4)
	await tw.finished

# ---------- bed sequence (all positions measured from the clips: hips offsets sleep/wake_up ~0.12, sit 0.49)
## Lying = the first frame of wake_up (sitting up in bed, legs along the bed) with the torso tipped back
## onto the pillow by a bone offset on Abdomen + Chest. Sitting up tweens that offset to 0: no clip crossfade, no twist.
const LIE_ANG := -0.62
const LEG_FIX := 0.3   # v9: lowers the legs of the wake_up sitting pose onto the mattress
var breathing := false
## t = 1: lying flat (feet at LIE_FLAT), t = 0: sitting up in bed at LIE_ROOT. The model turns about the hips.
func _lie_blend(t: float) -> void:
	var sk := hero.skeleton
	var h: float = (hero.model.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_rest(sk.find_bone("Hips")).origin)).y
	h *= hero.model.scale.y   # child / short / tall bodies
	var ang := -PI / 2 * t
	hero.model.rotation = Vector3(ang, hero.model.rotation.y, 0)
	var pivot := Vector3(0, h, 0)
	hero.model.position = pivot - Basis(Vector3.RIGHT, ang) * pivot
	hero.position = LIE_ROOT.lerp(LIE_FLAT - Vector3(h, h, 0), t)
	# the pose crossfade (standing idle <-> sitting) moves the hips inside the model: keep them on the mattress mid-way
	var hy: float = to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin).y   # open world: room-local like M
	hero.position.y += (lerpf(M + 0.1 * hero.model.scale.y, M + 0.12 * hero.model.scale.y, t) - hy) * (1.0 if t < 0.999 else sin(t * PI))   # build 3.2: pinned through the whole lean (was mid-way only -> float)

func _pose_sleep() -> void:
	sleep_clip = false
	_blanket(true, 0.01)   # build 3.2: lying in bed = under the blanket (morning lying pose, hospital return, opening)
	hero.rotation.y = PI / 2; _lie_blend(1.0)
	hero.bone_offsets.clear(); hero.player.speed_scale = 1.0
	hero.player.play("idle", 0.0); hero.player.seek(0.0, true); hero.player.speed_scale = 0.0
	breathing = true

## v33 (red): REAL sleep after "I am sleeping." (bedtime.gd) / "I am tired. I should rest." (story_home.gd day 1): the library
## "sleep" clip (side-lying, knees bent, its own breathing) instead of the rigid idle frame tipped flat. The clip lies on the
## floor along its own axis, so it is fitted onto the flat pose it replaces: same head->feet direction, same head/feet
## midpoint on the mattress, same hips height (works for every body: man, woman, boy, girl - child scale included).
## The clip's calm part (SLEEP_A..SLEEP_B, no tossing that would roll off the bed) ping-pongs slowly; Chest breathing on top.
## end_sleep_pose() puts the flat lying pose back (under the black fade) so the morning get-up flow is unchanged.
const SLEEP_A := 1.9
const SLEEP_B := 5.4
const SLEEP_SPEED := 0.55
var sleep_clip := false
func _bone_w(bn: String) -> Vector3:
	var sk := hero.skeleton; var i := sk.find_bone(bn)
	return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else hero.global_position
func _feet_w() -> Vector3: return (_bone_w("Foot.L") + _bone_w("Foot.R")) * 0.5
## build 3.2 (Yasin 22:00): the sleeper is UNDER the blanket - a soft quilt over the body from the chest to the foot end
## (full bed width, deep enough that the legs never poke through); fades in over the lie-down, gone when getting up
var blanket: MeshInstance3D
func _blanket(on: bool, t := 0.8) -> void:
	if on and blanket == null:
		blanket = MeshInstance3D.new(); blanket.name = "SleepBlanket"
		blanket.mesh = _drape_mesh()
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.36, 0.62, 0.95); mat.roughness = 0.95
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; blanket.material_override = mat
		blanket.position = Vector3(B.x + 0.47, M, B.z)   # head at -x (pillow), feet toward +x (LIE_FLAT)
		add_child(blanket)
	elif on: return   # already covered (bed locks re-pose every frame: no re-fade)
	if blanket == null: return
	var mt := blanket.material_override as StandardMaterial3D
	if N.has("unmade") and is_instance_valid(N.unmade): N.unmade.visible = (S.bed == "unmade") and not on   # no rumpled-sheet mound under / before the blanket
	if on:
		blanket.visible = true; mt.albedo_color.a = 0.0
		create_tween().tween_property(mt, "albedo_color:a", 1.0, t)
	else:
		var b := blanket; blanket = null
		var tw := create_tween(); tw.tween_property(mt, "albedo_color:a", 0.0, t); tw.tween_callback(b.queue_free)

## a quilt draped over the sleeper: a soft mound along the body (high enough for the bent knee of the sleep clip), flat
## on the mattress at the sides, hanging down over both bed edges; folded-back white hem at the chest
func _drape_mesh() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const NX := 28; const NZ := 22; const L := 1.42; const HW := 0.52; const DROP := 0.26
	var pts: Array = []
	for i in NX + 1:
		var row: Array = []
		var x := -L / 2.0 + L * float(i) / NX
		var u := float(i) / NX
		var mound := 0.34 * (0.6 + 0.4 * sin(clampf(u * 1.25, 0.0, 1.0) * PI))   # high to the foot end (the sleep clip lifts a knee / foot)
		for j in NZ + 1:
			var v := -1.0 + 2.0 * float(j) / NZ          # -1..1 across, the outer parts hang over the edges
			var z := v * (HW + DROP * 0.6)
			var y: float
			if absf(z) <= HW:
				var g := exp(-pow(absf(z + 0.04) / 0.40, 4.0))   # a broad raised plateau over the whole body (knees / feet of the sleep clip stay under)
				y = 0.035 + mound * g + 0.03 * (1.0 - g)
			else:
				var k := (absf(z) - HW) / (DROP * 0.6)
				y = 0.05 - DROP * smoothstep(0.0, 1.0, k); z = signf(z) * (HW + 0.03 + 0.02 * k)
			row.append(Vector3(x, y, z))
		pts.append(row)
	for i in NX:
		for j in NZ:
			var a: Vector3 = pts[i][j]; var b: Vector3 = pts[i + 1][j]; var c: Vector3 = pts[i + 1][j + 1]; var d: Vector3 = pts[i][j + 1]
			for q in [a, b, c, a, c, d]:
				st.set_color(Color(0.97, 0.97, 0.95) if (q as Vector3).x < -L / 2.0 + 0.14 else Color(1, 1, 1))
				st.add_vertex(q)
	st.generate_normals()
	return st.commit()

func sleep_pose(fade := 0.0) -> void:
	if sleep_clip or not hero.player.has_animation("sleep"): return
	_blanket(true, maxf(fade, 0.6))
	var h0 := _bone_w("Head"); var f0 := _feet_w(); var p0 := _bone_w("Hips")
	var g0: Transform3D = hero.model.global_transform
	var prev := String(hero.player.current_animation); var prev_t := hero.player.current_animation_position if prev != "" else 0.0
	var prev_sp := hero.player.speed_scale
	var offs: Dictionary = hero.bone_offsets.duplicate(true)
	hero.bone_offsets.clear()
	hero.model.rotation = Vector3(0, hero.model.rotation.y, 0); hero.model.position = Vector3.ZERO
	hero.player.speed_scale = SLEEP_SPEED; hero.player.play("sleep", 0.0); hero.player.seek(SLEEP_A, true)
	hero.player.advance(0.0)
	if hero.skeleton.has_method("force_update_all_bone_transforms"): hero.skeleton.force_update_all_bone_transforms()   # build 3.2: no frame with the new root and the old (standing) pose
	var d0 := h0 - f0; d0.y = 0.0
	var d1 := _bone_w("Head") - _feet_w(); d1.y = 0.0
	if d0.length() > 0.1 and d1.length() > 0.1: hero.rotation.y += d1.signed_angle_to(d0, Vector3.UP)
	var m0 := (h0 + f0) * 0.5; var m1 := (_bone_w("Head") + _feet_w()) * 0.5
	hero.global_position += Vector3(m0.x - m1.x, p0.y - _bone_w("Hips").y, m0.z - m1.z)
	sleep_clip = true; breathing = true
	if fade > 0.0 and prev != "" and prev != "sleep":
		# build 3.2 (Yasin 21:33): seamless crossfade into the sleep clip - the bones blend from the lie-down pose (AnimationPlayer
		# blend) while the body root glides from where it lay to the aligned sleep transform (no pop)
		hero.player.play(prev, 0.0); hero.player.seek(prev_t, true)
		hero.player.speed_scale = SLEEP_SPEED; hero.player.play("sleep", fade); hero.player.seek(SLEEP_A, false)
		var m_to: Transform3D = hero.model.transform
		hero.model.global_transform = g0
		var m_from: Transform3D = hero.model.transform
		for k in offs: hero.bone_offsets[k] = offs[k]
		var tw := create_tween()
		tw.tween_method(func(t: float):
			if not is_instance_valid(hero): return
			hero.model.transform = m_from.interpolate_with(m_to, t)
			for k in offs:
				var v: Array = offs[k]; hero.bone_offsets[k] = [v[0], float(v[1]) * (1.0 - t)], 0.0, 1.0, fade).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			for k in offs: hero.bone_offsets.erase(k))
## Yasin 17:58 SLEEP STANDARD: the ONE lie-down on a bed (player verb, day-1..7 bedtimes): sit, lie, and straight into
## the real sleep pose the moment the body is down (no flat idle frame in between).
func lie_down() -> void:
	# Yasin 23:58: the bed is flat / made while getting in; the bulged sleep blanket only appears at the switch to the sleep pose
	if S.bed == "unmade": S.bed = "made"; _apply_states()
	await sit_on_bed(); await edge_to_bedsit(); await bedsit_to_lie()
	sleep_pose()   # straight into the sleeping / breathing clip (aligned head/feet/hips: no pop; the blanket fades over it)

func end_sleep_pose() -> void:
	if sleep_clip: _pose_sleep()
func _sleep_pingpong() -> void:
	if not sleep_clip or hero.player.current_animation != "sleep": return
	var p := hero.player.current_animation_position
	if p >= SLEEP_B and hero.player.speed_scale > 0.0: hero.player.speed_scale = -SLEEP_SPEED
	elif p <= SLEEP_A and hero.player.speed_scale < 0.0: hero.player.speed_scale = SLEEP_SPEED

func bedsit_up() -> void:     # lying -> sitting up in bed (legs stay where they are)
	end_sleep_pose()
	_blanket(false, 0.6)   # Yasin 23:58: AFTER end_sleep_pose (its _pose_sleep re-created the blanket: the bulge stayed on waking)
	breathing = false; hero.bone_offsets.clear()
	_tw_offset("UpperLeg.L", Vector3.RIGHT, LEG_FIX, 2.0); _tw_offset("UpperLeg.R", Vector3.RIGHT, LEG_FIX, 2.0)
	hero.player.speed_scale = 1.0; hero.player.play("wake_up", 2.0, 0.0)   # v11: slower, softer sit-up
	create_tween().tween_method(_lie_blend, 1.0, 0.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wait(2.05)
	await wait(0.35)   # v11: no stretch, just a short pause sitting up

func bedsit_to_edge() -> void: # turn on the bed with the legs above the mattress, scoot to the edge, drop the feet
	_tw_offset("UpperLeg.L", Vector3.RIGHT, 0.0, 0.8); _tw_offset("UpperLeg.R", Vector3.RIGHT, 0.0, 0.8)
	var tw := create_tween()
	tw.tween_property(hero, "rotation:y", 0.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(hero, "position", Vector3(SIT_ROOT.x, M, SIT_ROOT.z - 0.12), 0.6).set_trans(Tween.TRANS_SINE)
	await wait(2.0)
	hero.player.play("sit_idle", 0.9)
	var tw2 := create_tween()
	tw2.tween_property(hero, "position", SIT_ROOT, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wait(1.1)

func stand_from_bed() -> void:
	await _sit_to_stand()

func sit_on_bed() -> void:
	hero.player.play("stand_to_sit", 0.3)
	# build 3.2 (Yasin 22:00): the pelvis lands ON the mattress (not the clip's chair height): the root follows the hips down
	# in the second half of the sit so the thighs end exactly on the mattress top
	var dur := hero.anim_length("stand_to_sit") - 0.04; var t := 0.0
	while t < dur:
		await get_tree().process_frame; t += get_process_delta_time()
		var k := clampf((t / dur - 0.5) * 2.0, 0.0, 1.0)
		if k > 0.0: _pin_hips(_seat_hips_y(), k * 0.5)
	hero.position = SIT_ROOT; hero.player.play("sit_idle", 0.0); hero.player.advance(0.0)
	_pin_hips(_seat_hips_y(), 1.0)

## hips bone height (room-local) of a body sitting on the mattress edge: mattress top + the thigh thickness of this body
func _seat_hips_y() -> float: return M + 0.09 * hero.model.scale.y

## move the root so the hips bone sits at height y (room-local; w = how much of the gap to close this call)
func _pin_hips(y: float, w := 1.0) -> void:
	var sk := hero.skeleton
	var hy: float = to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin).y
	hero.position.y += (y - hy) * w

const LIE_DROP := 0.15
func edge_to_bedsit() -> void:  # exact reverse of bedsit_to_edge
	# build 3.2 (Yasin 21:33): one continuous, eased move - the body scoots back onto the mattress WHILE it turns and the legs
	# swing up (pose crossfade 1.3 s), instead of three separate rigid steps
	hero.player.play("wake_up", 1.3); hero.player.seek(0.0, true); hero.player.speed_scale = 0.0
	var p0: Vector3 = hero.position; var y0: float = hero.rotation.y
	var mid := Vector3(SIT_ROOT.x, 0, SIT_ROOT.z - 0.12)
	var t := 0.0; const DUR := 1.6
	while t < DUR:
		await get_tree().process_frame; t += get_process_delta_time()
		var k := clampf(t / DUR, 0.0, 1.0); var e := 0.5 - 0.5 * cos(k * PI)
		var a: Vector3 = p0.lerp(mid, clampf(e * 1.8, 0.0, 1.0)); var b: Vector3 = mid.lerp(LIE_ROOT, clampf((e - 0.45) / 0.55, 0.0, 1.0))
		var xz: Vector3 = a if e < 0.45 else b
		hero.position = Vector3(xz.x, hero.position.y, xz.z)
		hero.rotation.y = lerp_angle(y0, PI / 2, clampf((e - 0.1) / 0.9, 0.0, 1.0))
		# the pelvis stays ON the mattress the whole time (the root follows the pose crossfade, no float)
		_pin_hips(lerpf(_seat_hips_y(), M + 0.1 * hero.model.scale.y, e) - LIE_DROP * e - LIE_DROP * smoothstep(0.45, 1.0, k), 1.0)   # Yasin 22:58: body 15 cm lower from the bed-sit on (eased in, kept through lying + sleep)
	await wait(0.05)

func bedsit_to_lie() -> void:
	# build 3.2 (Yasin 21:33): the torso leans back slowly (eased 1.8 s) while the long-sit pose relaxes into the lying pose
	hero.player.speed_scale = 1.0; hero.player.play("idle", 1.8, 0.0); hero.player.seek(0.0, true)
	create_tween().tween_method(_lie_blend, 0.0, 1.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wait(1.85); hero.player.speed_scale = 0.0; breathing = true

## build 3.2 (Yasin 21:23): the alarm rings EVERY morning (days 1-7). True while today's alarm has not been turned off yet
## (mornings only: before 12:00 on the shared clock).
func alarm_due() -> bool:
	var d := maxi(WorldState.day, App.day)
	if int(App.load_save().get("alarm_off_day", 0)) >= d: return false
	return WorldState.hour() < 12

## the day is still at its wake-up step (nothing of the day's routine done yet): story.d<day> "" / "start" / "alarm"
func at_wake_step() -> bool:
	var d := maxi(WorldState.day, App.day)
	var st = App.load_save().get("story", {})
	var v := String(st.get("d%d" % d, "")) if st is Dictionary else ""
	if d == 2 and st is Dictionary and String(st.get("day2", "")) not in ["", "bedroom"]: return false
	return v in ["", "start", "alarm"]

## scripted morning alarm while lying in bed (wake-ups that are not the player's own): rings, then turned off from the bed
func morning_alarm() -> void:
	if not alarm_due(): return
	S.alarm = "ringing"; _apply_states(); Audio.sfx("alarm", -4.0)
	_set_mission("Turn off the alarm clock.")
	var t0 := Time.get_ticks_msec(); caption("My alarm is ringing."); await _readable(t0)
	S.alarm = "off"; _apply_states(); Audio.sfx("metalClick")
	Objectives.complete("Turn off the alarm clock.")
	t0 = Time.get_ticks_msec(); caption("I am turning off the alarm clock."); await _readable(t0)

func get_up_sequence(opening := false) -> void:
	if not opening and S.alarm != "ringing": await morning_alarm()
	Life.event("wake")   # house.29: event clock
	mode = "busy"; _hide_chips(); _update_hand()
	# v32-polish: every wake-up shows exactly "I'm waking up." then "I'm getting up.", each readable (>= 2 s and until the
	# voice has finished); the old "I am standing up." line and its voice call are gone
	var t0 := Time.get_ticks_msec()
	caption("I'm waking up.")
	hero.player.speed_scale = 0.0
	await bedsit_up()
	if opening: Life.snap("wake")   # house.27: day-1 polaroid
	await _readable(t0)
	await bedsit_to_edge()
	t0 = Time.get_ticks_msec()
	caption("I'm getting up.")
	await _readable(t0)
	await stand_from_bed()
	mode = "play"; _update_hand(); action_done.emit("getup")

## v32-polish: keep the current caption on screen at least 2 s and until the narrator has finished it
func _readable(t0: int, min_ms := 2000) -> void:
	while Time.get_ticks_msec() - t0 < min_ms or (Audio.is_speaking() and Time.get_ticks_msec() - t0 < 8000): await get_tree().process_frame

## v30.1: back from the hospital the player wakes up lying on the bed (morning lying pose + get-up flow), then the home story runs
func _home_from_hospital() -> void:
	mode = "busy"; _hide_chips(); S.bed = "unmade"; _apply_states(); _pose_sleep()
	Objectives.clear()   # v30.4: no stale room mission during the review / tests in bed
	cam_focus = Vector3(-0.8, 0, -1.4)
	await wait(1.5)
	# v30.4: the player stays LYING on the bed for the whole review / tests / night; gets up on the day-2 morning (story_home)
	var sh = load("res://scripts/story/story_home.gd").new(); sh.m = self; add_child(sh); sh.run()

func start_opening() -> void:
	App.bath_done = false; App.family_breakfast = false   # house.17: a new game starts the morning routine again
	if FileAccess.file_exists("user://bathroom.json"): DirAccess.remove_absolute("user://bathroom.json")
	if FileAccess.file_exists(SavePath.P()): DirAccess.remove_absolute(ProjectSettings.globalize_path(SavePath.P()))
	App._trf = 0   # v30.5: new game -> TR off
	App.day = 1; Life.new_game()   # house.25: shared clock / needs / battery reset
	mode = "opening"; S.alarm = "off"; _apply_states(); _pose_sleep()
	cam_focus = Vector3(-0.8, 0, -1.4)
	_set_mission("")
	await wait(1.8)
	S.alarm = "ringing"; _apply_states()
	await wait(2.2)
	await get_up_sequence(true)
	_set_mission("Turn off the alarm clock.")

# ============================================================ movement / path
func _build_grid() -> void:
	astar.region = Rect2i(0, 0, 70, 60); astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES; astar.update()
	for x in 70:
		for y in 60:
			var p := _cell_pos(Vector2i(x, y))
			astar.set_point_solid(Vector2i(x, y), not _free(p, R + 0.03))

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x - ROOM.position.x) / 0.1), 0, 69), clampi(int((p.z - ROOM.position.y) / 0.1), 0, 59))

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

## animation speed that matches the ground speed (scaled bodies take shorter steps)
func walk_rate(sp: float) -> float:
	return clampf(sp / (WALK_CLIP * hero.model.scale.y), 0.5, 1.8)

func run_rate(sp: float) -> float:
	return clampf(sp / (RUN_CLIP * hero.model.scale.y), 0.6, 2.0)

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
			while true:
				var d := p - hero.position; d.y = 0
				if d.length() < 0.04: break
				var dt := get_process_delta_time()
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

func _process(dt: float) -> void:
	_mirror_cues(dt)
	if cam_stick.length() > 0.1 and mode != "opening":
		var dy := cam_stick.x * 1.8 * dt
		var _free: bool = (load("res://scripts/core/shoulder_cam.gd") as GDScript).free_yaw(get_tree())   # v34: one free-yaw camera
		if signf(dy) == signf(cam_yaw) and not _free: dy *= clampf(1.0 - pow(absf(cam_yaw) / 1.3, 3.0), 0.0, 1.0)
		cam_yaw = wrapf(cam_yaw + dy, -PI, PI) if _free else clampf(cam_yaw + dy, -1.3, 1.3)
		var dp := cam_stick.y * 1.0 * dt
		var mid := 0.95
		if signf(dp) == signf(cam_pitch - mid): dp *= clampf(1.0 - pow(absf(cam_pitch - mid) / 0.35, 3.0), 0.0, 1.0)
		cam_pitch = clampf(cam_pitch + dp, 0.6, 1.3)
	if mode == "play" and stick.length() > 0.12:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw)); var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var d := right * stick.x + fwd * -stick.y
		if not was_walking and not cap_panel.visible: caption("I am walking.")
		was_walking = true
		PlayerController.step(self, d, stick.length(), dt)
		_hide_chips()
	else:
		was_walking = false; running = false; move_sp = 0.0
	if mode == "play" and stick.length() <= 0.12 and hero.player.current_animation in ["walk", "run"]:
		hero.player.speed_scale = 1.0; hero.play("idle", 0.25)
	if mode == "play" or mode == "lying": _update_hand()
	if hero.player.current_animation in ["walk", "run"]:
		var ph: float = fmod(hero.player.current_animation_position / hero.anim_length(hero.player.current_animation) * 2.0, 1.0)
		if ph < last_step_ph: Audio.sfx("footstep0%d" % randi_range(0, 3), -10.0, randf_range(0.9, 1.1))
		last_step_ph = ph
	_sleep_pingpong()   # v33 (red)
	if breathing:
		var b := sin(Time.get_ticks_msec() * 0.0025) * 0.025
		hero.bone_offsets["Chest"] = [Vector3.RIGHT, b * 0.6]
	if S.window == "open":
		var tt := Time.get_ticks_msec() * 0.001
		N.curtL.rotation.x = sin(tt * 1.7) * 0.07; N.curtR.rotation.x = sin(tt * 1.3 + 1.0) * 0.08
	else:
		N.curtL.rotation.x = lerpf(N.curtL.rotation.x, 0.0, 0.1); N.curtR.rotation.x = lerpf(N.curtR.rotation.x, 0.0, 0.1)
	# alarm ringing
	if S.alarm == "ringing":
		t_ring += dt
		N.alarm.rotation.z = sin(t_ring * 40.0) * 0.12
		N.ring.modulate.a = 0.55 + 0.45 * sin(t_ring * 8.0)
		if fmod(t_ring, 1.2) < dt: Audio.sfx("alarm", -8.0)
	if hand3d.visible: hand3d.position.y = OBJ[near_id].focus.y + 0.55 + sin(Time.get_ticks_msec() * 0.005) * 0.05 if near_id != "" else 0.0
	_update_cam(dt)
	_update_mirror()
	_layout()

func _update_cam(dt: float) -> void:
	var target := Vector3(hero.position.x * 0.35, 0, -0.35 + hero.position.z * 0.3) if mode != "menu" else Vector3(0, 0, -0.3)
	if cam_zoom < 1.0: target = Vector3(hero.position.x, 0.4, hero.position.z - 0.3)
	if mode == "opening": target = Vector3(-0.8, 0, -1.4)
	cam_focus = cam_focus.lerp(target, 1.0 - exp(-2.5 * dt))
	if cam_override: return
	if not cam_shot.is_empty():
		var k := 1.0 - exp(-2.2 * dt)
		if shot_at == Vector3.INF: shot_at = cam.position - cam.transform.basis.z * 6.0
		cam.position = cam.position.lerp(_shot_l("pos"), k); shot_at = shot_at.lerp(_shot_l("at"), k)
		cam.h_offset = lerpf(cam.h_offset, cam_shot.get("h", 0.0), k)
		cam.look_at(to_global(shot_at), Vector3.UP); _fade_walls(dt); exit_xf = cam.transform; exit_t = 0.0; return
	shot_at = Vector3.INF; cam.h_offset = lerpf(cam.h_offset, 0.0, 1.0 - exp(-3.0 * dt))
	cam_yaw_s = lerp_angle(cam_yaw_s, cam_yaw, 1.0 - exp(-8.0 * dt)); cam_pitch_s = lerpf(cam_pitch_s, cam_pitch, 1.0 - exp(-8.0 * dt))
	var off := Vector3(sin(cam_yaw_s) * cos(cam_pitch_s), sin(cam_pitch_s), cos(cam_yaw_s) * cos(cam_pitch_s)) * cam_dist * cam_zoom
	var cp := cam_focus + off
	if cp.y < WALL_H + 0.4 and absf(cp.x) < 3.7 and cp.z > -3.2 and cp.z < 3.2: cp.y = WALL_H + 0.4
	cp = cam_avoid.adjust(cam_focus, cp, hero.position + Vector3(0, 1.0, 0), dt, mode == "play", get_tree())   # v33: camera occlusion avoidance
	if cp.y < WALL_H + 0.4 and absf(cp.x) < 3.7 and cp.z > -3.2 and cp.z < 3.2: cp.y = WALL_H + 0.4
	cam.position = cp
	_fade_walls(dt)
	cam.look_at(to_global(cam_focus + Vector3(0, 0.3, 0)), Vector3.UP)
	if exit_t < 1.0:   # ease back from a camera shot to the follow camera
		exit_t = minf(1.0, exit_t + dt / 0.9)
		cam.transform = exit_xf.interpolate_with(cam.transform, ease(exit_t, -2.0))

## walls between the camera and the player (or with the camera behind them) fade out smoothly; they keep casting shadows
func _fade_walls(dt: float) -> void:
	var eye := hero.position + Vector3(0, 1.2, 0)
	for group in ([] if wall_fade else [[walls_l, cam.position.x < -3.5], [walls_r, cam.position.x > 3.5]]):   # v33: side walls -> WallFade occluders   # v32-polish: south walls -> WallFade
		var occl: bool = group[1]
		for w in group[0]:
			var ab: AABB = (w as MeshInstance3D).get_aabb(); ab.position += w.position
			if ab.intersects_segment(cam.position, eye): occl = true
		for w in group[0]:
			var a: float = wall_alpha.get(w, 1.0)
			a = move_toward(a, 0.12 if occl else 1.0, dt * 3.0)
			wall_alpha[w] = a
			var m: StandardMaterial3D = w.material_override
			m.albedo_color.a = a
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if a > 0.99 else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH   # house.24.2: fading walls keep receiving shadows (alpha-blend lost them -> bright patches)

func _update_hand() -> void:
	var best := ""; var bd := 1.05
	if mode == "play":
		for id in OBJ:
			var s: Vector3 = OBJ[id].spot
			var d := Vector2(hero.position.x - s.x, hero.position.z - s.z).length()
			if d < bd: bd = d; best = id
	elif mode == "lying": best = "bed"
	near_id = best
	hand3d.visible = best != ""
	if best != "": hand3d.position = Vector3(OBJ[best].focus.x, OBJ[best].focus.y + 0.55, OBJ[best].focus.z)
	if touch: touch.queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		cam_yaw = wrapf(cam_yaw - e.relative.x * 0.006, -PI, PI) if (load("res://scripts/core/shoulder_cam.gd") as GDScript).free_yaw(get_tree()) else clampf(cam_yaw - e.relative.x * 0.006, -1.3, 1.3); cam_pitch = clampf(cam_pitch + e.relative.y * 0.004, 0.6, 1.3)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam_dist = clampf(cam_dist * (0.92 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 6.0, 12.0)
	elif e is InputEventMagnifyGesture:
		cam_dist = clampf(cam_dist / e.factor, 6.0, 12.0)

func on_action() -> void:
	if mode == "lying":
		Audio.click(); get_up_sequence(); return
	if mode != "play" or near_id == "": return
	Audio.click()
	var v := verbs(near_id)
	if v.size() == 1: do_verb(near_id, v[0])
	else: _show_chips(near_id)

# ============================================================ UI
func _sb(c: Color, r := 22, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = c; s.set_corner_radius_all(r)
	s.content_margin_left = pad + 6; s.content_margin_right = pad + 6; s.content_margin_top = pad; s.content_margin_bottom = pad
	return s

func _build_ui() -> void:
	var base: Font = load("res://fonts/Nunito.ttf")
	font = FontVariation.new(); font.base_font = base; font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	font_b = FontVariation.new(); font_b.base_font = base; font_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	var th := Theme.new(); th.default_font = font; th.default_font_size = 24
	th.set_stylebox("normal", "Button", _sb(Color(1, 1, 1, 0.94), 18, 10))
	th.set_stylebox("hover", "Button", _sb(Color(0.93, 0.95, 1.0, 0.98), 18, 10))
	th.set_stylebox("pressed", "Button", _sb(Color(0.82, 0.86, 0.98, 1), 18, 10))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: th.set_color(k, "Button", Color(0.13, 0.16, 0.24))
	th.set_color("font_color", "Label", Color(1, 1, 1))
	ui = CanvasLayer.new(); ui.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(ui)
	var rootc := Control.new(); rootc.set_anchors_preset(Control.PRESET_FULL_RECT); rootc.theme = th
	rootc.mouse_filter = Control.MOUSE_FILTER_IGNORE; rootc.name = "UIRoot"; ui.add_child(rootc)
	# HUD
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; rootc.add_child(hud)
	touch = load("res://scripts/touch.gd").new(); touch.main = self; touch.set_anchors_preset(Control.PRESET_FULL_RECT); hud.add_child(touch)
	var mp := PanelContainer.new(); mp.name = "Mission"; mp.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.10, 0.16, 0.6), 18, 10))
	mp.position = Vector2(20, 18); hud.add_child(mp)
	var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 0); mp.add_child(mv)
	mission_lbl = Label.new(); mission_lbl.add_theme_font_override("font", font_b); mission_lbl.add_theme_font_size_override("font_size", 22); mv.add_child(mission_lbl)
	mission_tr = Label.new(); mission_tr.add_theme_font_size_override("font_size", 18); mission_tr.modulate = Color(0.75, 0.88, 1.0); mv.add_child(mission_tr)
	var pause := Button.new(); pause.text = "II"; pause.name = "Pause"; pause.custom_minimum_size = Vector2(64, 64)
	pause.add_theme_font_override("font", font_b); pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-84, 18); pause.size = Vector2(64, 64); pause.pressed.connect(func(): Audio.click(); _show_menu(true)); hud.add_child(pause)
	pause.anchor_left = 1; pause.anchor_right = 1; pause.offset_left = -84; pause.offset_right = -20; pause.offset_top = 18; pause.offset_bottom = 82
	phone_btn = Button.new(); phone_btn.name = "PhoneBtn"; phone_btn.tooltip_text = "Phone"
	phone_btn.anchor_left = 1; phone_btn.anchor_right = 1; phone_btn.offset_left = -168; phone_btn.offset_right = -100; phone_btn.offset_top = 16; phone_btn.offset_bottom = 84
	phone_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0.94), 18, 6)); phone_btn.add_theme_stylebox_override("hover", _sb(Color(0.93, 0.95, 1.0), 18, 6))
	phone_btn.add_theme_stylebox_override("pressed", _sb(Color(0.82, 0.86, 0.98), 18, 6))
	var pic := TextureRect.new(); pic.texture = load("res://ui/phone/hud_phone.png"); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.set_anchors_preset(Control.PRESET_FULL_RECT); pic.offset_left = 12; pic.offset_right = -12
	pic.offset_top = 10; pic.offset_bottom = -10; pic.mouse_filter = Control.MOUSE_FILTER_IGNORE; phone_btn.add_child(pic)
	phone_dot = Panel.new(); phone_dot.add_theme_stylebox_override("panel", _sb(Color(0.93, 0.26, 0.3), 9, 0)); phone_dot.position = Vector2(50, 2)
	phone_dot.size = Vector2(18, 18); phone_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE; phone_btn.add_child(phone_dot)
	phone_btn.pressed.connect(func(): if mode == "play": Audio.click(); open_phone_hud())
	phone_light = Panel.new(); phone_light.name = "PhoneLight"; phone_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsb := StyleBoxFlat.new(); lsb.bg_color = Color(0.35, 0.62, 1.0, 0.35); lsb.set_corner_radius_all(26); lsb.border_color = Color(0.45, 0.75, 1.0)
	lsb.set_border_width_all(4); lsb.shadow_color = Color(0.35, 0.65, 1.0, 0.8); lsb.shadow_size = 14; phone_light.add_theme_stylebox_override("panel", lsb)
	phone_light.anchor_left = 1; phone_light.anchor_right = 1; phone_light.offset_left = -176; phone_light.offset_right = -92; phone_light.offset_top = 8; phone_light.offset_bottom = 92
	phone_light.visible = false; hud.add_child(phone_light)
	phone_btn.visible = false; hud.add_child(phone_btn)
	# caption
	cap_panel = PanelContainer.new(); cap_panel.name = "Caption"; cap_panel.add_theme_stylebox_override("panel", _sb(Color(0.08, 0.10, 0.16, 0.72), 22, 12))
	cap_panel.add_to_group("caption_box"); cap_panel.visibility_changed.connect(func(): if cap_panel.visible: StoryUI.claim(cap_panel))   # v32-polish: ONE caption box on screen (StoryUI.claim)
	hud.add_child(cap_panel)
	var ch := HBoxContainer.new(); ch.add_theme_constant_override("separation", 16); cap_panel.add_child(ch)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 2); ch.add_child(cv)
	cap_en = Label.new(); cap_en.add_theme_font_override("font", font_b); cap_en.add_theme_font_size_override("font_size", 30)
	cap_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cap_en.custom_minimum_size.x = 420; cv.add_child(cap_en)
	cap_tr = Label.new(); cap_tr.add_theme_font_size_override("font_size", 22); cap_tr.modulate = Color(0.75, 0.88, 1.0)
	cap_tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; cap_tr.custom_minimum_size.x = 420; cv.add_child(cap_tr)
	tr_btn = Button.new(); tr_btn.text = "TR"; tr_btn.name = "Translate"; tr_btn.custom_minimum_size = Vector2(76, 56); tr_btn.add_theme_font_override("font", font_b)
	tr_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tr_btn.pressed.connect(func(): Audio.click(); S.tr = not S.tr; App.save_tr(S.tr); _refresh_text()); ch.add_child(tr_btn)
	cap_panel.visible = false
	# verb chips (above the action button)
	chips = VBoxContainer.new(); chips.name = "Chips"; chips.add_theme_constant_override("separation", 10)
	chips.alignment = BoxContainer.ALIGNMENT_END; hud.add_child(chips)
	phone = load("res://scripts/phone.gd").new(); phone.main = self; phone.visible = false
	hud.add_child(phone); hud.move_child(phone, cap_panel.get_index())   # under the caption: the action text stays readable
	phone.job_chosen.connect(_on_job_chosen)
	phone.lesson_finished.connect(_on_lesson_finished)
	phone.family_saved.connect(_on_family_saved)
	phone.calendar_opened.connect(_on_calendar_opened)
	# house.17: shared pause menu (scripts/game_menu.gd), identical in every room
	var gm := GameMenu.new(); gm.setup(self, "Bedroom", func(): _start_game()); rootc.add_child(gm)
	menu = gm; settings = gm.settings; menu_play = gm.menu_play

func _build_menu(rootc: Control) -> void:
	menu = ColorRect.new(); (menu as ColorRect).color = Color(0.07, 0.09, 0.14, 0.45); menu.set_anchors_preset(Control.PRESET_FULL_RECT); rootc.add_child(menu)
	var card := PanelContainer.new(); card.name = "MenuCard"; card.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.9), 30, 30))
	card.set_anchors_preset(Control.PRESET_CENTER); card.grow_horizontal = Control.GROW_DIRECTION_BOTH; card.grow_vertical = Control.GROW_DIRECTION_BOTH
	menu.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); v.custom_minimum_size.x = 360; card.add_child(v)
	var t := Label.new(); t.text = "English Home"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var st := Label.new(); st.text = "Bedroom test · A1–A2"; st.add_theme_font_size_override("font_size", 22)
	st.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55)); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var sp := Control.new(); sp.custom_minimum_size.y = 8; v.add_child(sp)
	menu_play = _menu_btn(v, "Resume", func(): _start_game(), true)
	_menu_btn(v, "Settings", func(): settings.visible = true)
	_menu_btn(v, "Main menu", func(): _to_main_menu())

func _menu_btn(parent: Control, txt: String, cb: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(0, 62); b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(Color(0.31, 0.42, 0.93), 18, 10)); b.add_theme_stylebox_override("hover", _sb(Color(0.36, 0.48, 0.97), 18, 10))
		b.add_theme_stylebox_override("pressed", _sb(Color(0.25, 0.35, 0.8), 18, 10))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color(1, 1, 1))
	else:
		b.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.94, 0.97), 18, 10))
	b.pressed.connect(func(): Audio.click(); cb.call()); parent.add_child(b); return b

func _build_settings(rootc: Control) -> void:
	settings = ColorRect.new(); (settings as ColorRect).color = Color(0.07, 0.09, 0.14, 0.55); settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.visible = false; rootc.add_child(settings)
	var card := PanelContainer.new(); card.name = "SettingsCard"; card.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.94), 30, 26))
	card.set_anchors_preset(Control.PRESET_CENTER); card.grow_horizontal = Control.GROW_DIRECTION_BOTH; card.grow_vertical = Control.GROW_DIRECTION_BOTH; settings.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); v.custom_minimum_size.x = 420; card.add_child(v)
	var t := Label.new(); t.text = "Settings"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); v.add_child(t)
	var rows := [["Voice", "voice", [true, false], ["On", "Off"]], ["Character", "gender", ["men", "women"], ["Man", "Woman"]],
		["Build", "build", ["thin", "average", "fat"], ["Thin", "Average", "Fat"]], ["Height", "height", ["short", "medium", "tall"], ["Short", "Medium", "Tall"]]]
	for r in rows:
		var h := HBoxContainer.new(); v.add_child(h)
		var l := Label.new(); l.text = r[0]; l.add_theme_font_size_override("font_size", 24); l.add_theme_color_override("font_color", Color(0.25, 0.28, 0.36))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var b := Button.new(); b.custom_minimum_size = Vector2(170, 54); b.add_theme_stylebox_override("normal", _sb(Color(0.91, 0.93, 0.98), 16, 8)); h.add_child(b)
		var key: String = r[1]; var vals: Array = r[2]; var labs: Array = r[3]
		b.text = labs[vals.find(S[key])]
		b.pressed.connect(func():
			Audio.click()
			var i := (vals.find(S[key]) + 1) % vals.size(); S[key] = vals[i]; b.text = labs[i]
			_apply_character())
	var close := _menu_btn(v, "Done", func(): settings.visible = false, true); close.name = "Done"

func _apply_character() -> void:
	if hero.gender != S.gender:
		var p := hero.position; var r := hero.rotation; var mr := hero.model.rotation.y; var an := hero.player.current_animation
		hero.setup(S.gender); hero.position = p; hero.rotation = r; hero.model.rotation.y = mr
		if breathing and not sleep_clip: _lie_blend(1.0)
		if an != "": hero.player.play(an, 0.0)
	hero.apply_creator(S)   # house.18: shared creator -> player function (character.gd), same in every room
	Audio.voice_player.volume_db = 0.0 if S.voice else -80.0

func _show_menu(on: bool) -> void:
	(menu as GameMenu).show_menu(on); hud.visible = not on
	if on and mode != "menu": menu_play.text = "Resume"
	get_tree().paused = on and started

func _start_game() -> void:
	_show_menu(false)
	if not started:
		started = true; start_opening()

var cap_serial := 0
func caption(t: String, speak := true) -> void:
	if House.dormant(self): return   # v33town: a sleeping room shows no caption (one caption box: the live room's)
	cap_text = t; cap_panel.visible = t != ""
	if cap_panel.visible: StoryUI.claim(cap_panel)   # v32-polish: also when the box was already up (no visibility_changed) -> any other box hides
	if t != "": captioned.emit(t)
	cap_serial += 1
	var my := cap_serial
	get_tree().create_timer(4.5, false).timeout.connect(func(): if my == cap_serial and mode != "busy": cap_panel.visible = false)
	_refresh_text()
	if t != "" and S.voice and speak: Audio.say(t)

func _set_mission(t: String) -> void:
	if Objectives.stale(t): return   # Yasin 17:58
	mission = t; _refresh_text()
	if t == "": Objectives.clear()
	else:
		var trs: String = String(TR.get(t, extra_tr(t)))
		Objectives.set_list([t] if trs == "" else [{"en": t, "tr": trs}])   # v30.5: TR kept
	var mp = hud.get_node_or_null("Mission") if hud else null
	if mp: mp.visible = false   # Objectives owns the top-left list

func _refresh_text() -> void:
	cap_en.text = cap_text; cap_tr.text = TR.get(cap_text, extra_tr(cap_text) if extra_tr(cap_text) != "" else ("Benim adım %s." % S.name if cap_text.begins_with("My name is ") else "")); cap_tr.visible = S.tr and cap_tr.text != ""
	tr_btn.modulate = Color(1, 1, 1) if not S.tr else Color(0.7, 0.85, 1.0)
	tr_btn.add_theme_stylebox_override("normal", _sb(Color(0.31, 0.42, 0.93) if S.tr else Color(1, 1, 1, 0.94), 18, 10))
	tr_btn.add_theme_color_override("font_color", Color(1, 1, 1) if S.tr else Color(0.13, 0.16, 0.24))
	mission_lbl.text = mission; mission_tr.text = TR.get(mission, ""); mission_tr.visible = S.tr and mission != ""
	mission_lbl.get_parent().get_parent().visible = false   # v30.5: Objectives is the only top-left mission window
	cap_en.custom_minimum_size.x = clampf(font_b.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 4, 200, 560)
	cap_tr.custom_minimum_size.x = cap_en.custom_minimum_size.x
	_layout.call_deferred()

func _show_chips(id: String) -> void:
	_hide_chips()
	var head := Label.new(); head.text = String(OBJ[id].name).capitalize(); head.add_theme_font_override("font", font_b)
	head.add_theme_font_size_override("font_size", 20); head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0)); head.modulate = Color(0.12, 0.15, 0.25)
	var hp := PanelContainer.new(); hp.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.75), 14, 4)); hp.add_child(head)
	hp.size_flags_horizontal = Control.SIZE_SHRINK_END; chips.add_child(hp)
	for v in verbs(id):
		var b := Button.new(); b.text = v[0]; b.custom_minimum_size = Vector2(230, 58); b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): Audio.click(); do_verb(id, v)); chips.add_child(b)
	_layout.call_deferred()

## manual placement: caption bottom-centre, chips above the action button (always inside the screen)
func _layout() -> void:
	var vs := hud.size
	cap_panel.size = cap_panel.get_combined_minimum_size()
	var cw := vs.x - (side_w + 20.0 if side and side.visible else 0.0)
	cap_panel.position = Vector2(roundf(maxf(12.0, (cw - cap_panel.size.x) / 2)), vs.y - 22 - cap_panel.size.y)
	chips.size = chips.get_combined_minimum_size()
	var ac: Vector2 = touch.act_center()
	chips.position = Vector2(ac.x - touch.ACT_R - 24 - chips.size.x, clampf(ac.y + touch.ACT_R - chips.size.y, 96, vs.y - chips.size.y - 8))

func _hide_chips() -> void:
	for c in chips.get_children(): c.queue_free()

# ============================================================ save / continue / main menu
func save_game() -> void:
	var keep := {}
	if FileAccess.file_exists(SavePath.P()):
		var old = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if old is Dictionary: for k in ["living", "breakfast_done", "breakfast_score", "breakfast_day", "world", "life", "story", "places", "tests_skipped", "announced", "quiz_ver", "living_front"]: if old.has(k) and S.created: keep[k] = old[k]
	var f := FileAccess.open(SavePath.P(), FileAccess.WRITE)
	if f == null: return
	_sync_app_phone()
	var out := {"version": 1, "has_phone": S.has_phone, "family_breakfast": App.family_breakfast, "bath_done": App.bath_done, "day": App.day, "state": S, "pos": [hero.position.x, hero.position.z], "yaw": hero.rotation.y}
	out.merge(keep)
	f.store_string(JSON.stringify(out, "\t"))

func load_game() -> bool:
	var app := get_node_or_null("/root/App")
	var d: Dictionary = app.load_save() if app else {}
	if not d.has("state"): return false
	for k in d.state: if S.has(k): S[k] = d.state[k]
	if d.has("has_phone"): S.has_phone = bool(d.has_phone)
	App.narrator_from_look(String(S.get("gender", "men")), String(S.get("age", "adult")))   # v30.1 (a menu override wins)
	S.tr = App.tr_saved()   # v29.1: the one persisted TR flag (other scenes write state.tr too)
	_sync_app_phone()
	S.door_locked = door_rule()   # v9: the door needs the mirror, a job and at least one family member
	S.door = "closed"   # v32-polish: the bedroom -> bathroom door was saved "open" on day 1 and so started open on day 2; it always starts closed
	if d.has("pos"): saved_pos = Vector3(d.pos[0], 0, d.pos[1])
	return S.created

var saved_pos := Vector3.INF
var _hosp_home := false   # v33: day-1 hospital return -> story_home runs the review / tests / night; no room objective meanwhile
func _continue_game() -> void:
	started = true; menu.visible = false; hud.visible = true
	sleep_clip = false; breathing = false; hero.bone_offsets.clear(); hero.player.speed_scale = 1.0; hero.model.rotation.x = 0.0; hero.model.position = Vector3.ZERO
	hero.set_mannequin(false); _apply_character()
	hero.position = saved_pos if saved_pos != Vector3.INF and _free(saved_pos, R) else STAND_BED
	hero.rotation.y = 0.0; hero.model.rotation.y = 0.0; hero.play("idle", 0.0)
	var app_c = get_node_or_null("/root/App")
	var wake_continue: bool = app_c != null and bool(app_c.continue_requested) and String(app_c.came_from) == "" and at_wake_step()
	S.alarm = "ringing" if wake_continue and alarm_due() else ("off" if S.alarm == "ringing" else S.alarm)   # build 3.2 (Yasin 21:23/21:40): only a Continue AT the wake step re-arms it (never a trip home / room entry)
	if S.book == "hand": S.book = "shelf"
	_apply_states(); mode = "play"; _update_hand()
	if S.alarm == "ringing": Audio.sfx("alarm", -4.0); _set_mission("Turn off the alarm clock.")
	cam_focus = hero.position
	if App.came_from == "": caption("My name is %s." % S.name, false); Audio.say_name(S.name)   # house.17: no name line on room re-entry
	else: get_tree().create_timer(0.6, false).timeout.connect(func(): caption("I'm in the bedroom now.", false))   # house.17: silent room caption
	var _svh = App.load_save().get("story", {})
	if App.came_from == "hospital" and not (_svh is Dictionary and bool(_svh.get("day1_done", false))):   # v30.5: once; house.25: day-1 story continues at home (v31: "hospital_day2" = day-2 check-up, no home story)
		_home_from_hospital(); _hosp_home = true   # v33: no room objective after this (it fell back to "Go to the living room." during the review / night)
	elif App.came_from == "hospital_day2": get_tree().create_timer(1.2, false).timeout.connect(func(): Day2After.run(self, "bedroom"))   # v30.5
	load("res://scripts/story/bedtime.gd").hook_bedroom(self)   # v31c (red): day-2 bedtime / day-3 morning
	load("res://scripts/story/day5_routine.gd").attach(get_tree())   # v33 (blue): days 5-6 routine (resume on Continue)
	if not _hosp_home: _advance(false)

func _to_main_menu() -> void:
	if S.created: save_game()
	get_tree().paused = false
	if ResourceLoader.exists("res://menu.tscn"): get_tree().change_scene_to_file("res://menu.tscn")
	else: get_tree().quit()

# ============================================================ new opening: mirror -> name -> look
signal name_done
signal look_done
var side: PanelContainer
var side_w := 0.0
var name_lbl: Label
var opt_btns := {}

func _side_panel(w: float) -> VBoxContainer:
	if side: side.queue_free()
	side = PanelContainer.new(); side.name = "SidePanel"; side.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.93), 28, 18))
	side_w = w
	side.anchor_left = 1; side.anchor_right = 1; side.anchor_top = 0; side.anchor_bottom = 1
	side.offset_left = -w - 18; side.offset_right = -18; side.offset_top = 16; side.offset_bottom = -16
	hud.add_child(side)
	hud.get_node("Pause").visible = false; phone_btn.visible = false
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); side.add_child(v)
	side.modulate.a = 0.0; create_tween().tween_property(side, "modulate:a", 1.0, 0.35)
	return v

func _close_side() -> void:
	if not side: return
	var s := side; side = null; side_w = 0.0
	hud.get_node("Pause").visible = true; phone_btn.visible = S.has_phone   # v29.1: only after the bedroom pickup
	var tw := create_tween(); tw.tween_property(s, "modulate:a", 0.0, 0.3); tw.tween_callback(s.queue_free)
	_layout.call_deferred()

func _title(v: Control, en: String, tr: String) -> void:
	var l := Label.new(); l.text = en; l.add_theme_font_override("font", font_b); l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); v.add_child(l)
	var lt := Label.new(); lt.text = tr; lt.add_theme_font_size_override("font_size", 19); lt.add_theme_color_override("font_color", Color(0.36, 0.45, 0.7)); v.add_child(lt)

func _pill(txt: String, cb: Callable, sz: Vector2, fs := 22, primary := false) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = sz; b.add_theme_font_override("font", font_b); b.add_theme_font_size_override("font_size", fs)
	b.clip_text = true; b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_pill(b, primary)
	b.pressed.connect(func(): cb.call())
	return b

func _style_pill(b: Button, sel: bool) -> void:
	var c := Color(0.31, 0.42, 0.93) if sel else Color(0.92, 0.94, 0.98)
	b.add_theme_stylebox_override("normal", _sb(c, 16, 6)); b.add_theme_stylebox_override("hover", _sb(c.lightened(0.06), 16, 6))
	b.add_theme_stylebox_override("pressed", _sb(c.darkened(0.1), 16, 6))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(1, 1, 1) if sel else Color(0.13, 0.16, 0.24))

func creation_flow() -> void:
	touch.visible = false; _set_mission("")
	cam_shot = {"pos": Vector3(-1.55, 1.75, 3.05), "at": Vector3(-3.15, 1.3, 2.05), "h": 0.62}
	await wait(1.6)
	# ---- name
	caption("What is your name? How do you spell it?"); _set_mission("Spell your name.")
	_show_alphabet()
	await name_done
	_close_side()
	# v11: spell first, wait for the spelling to finish (v33: "My name is ..." comes after the look, in the chosen narrator's voice)
	Audio.spell(S.name)
	await Audio.wait_idle()
	await wait(0.4)
	# ---- look
	caption("Now I am choosing my look."); _set_mission("Choose how you look.")
	await take_shape()
	caption("This is me!")
	_show_creation()
	await look_done
	App.narrator_from_look(String(S.gender), String(S.age), true)   # v30.1: narrator voice follows the new character
	_close_side()
	caption("My name is %s." % S.name, false)   # v33: after the look -> the chosen narrator's own name clip / model
	Audio.say_name(S.name)   # house.26: one narrator clip for common names
	await Audio.wait_idle()
	await wait(0.4)
	await _after_look()

func _after_look() -> void:
	_close_side()
	S.created = true
	if is_child(): S.job = "schoolchild"   # v10: children do not choose a job
	S.door_locked = door_rule(); save_game()
	Audio.sfx("metalClick", 2.0, 0.8)
	caption("I am ready."); _set_mission("Explore your bedroom.")
	await wait(2.2)
	if not _job_chosen():
		hint_t = 0.0; notify("jobs")
		await Life.guide_to({"pos": PHONE_POS + Vector3(0.9, 1.4, 1.1), "at": PHONE_POS + Vector3(0, 0.2, 0)}, "Pick up your phone.")
	elif is_child():
		hint_t = 0.0; notify("calendar")
		await Life.guide_to({"pos": PHONE_POS + Vector3(0.9, 1.4, 1.1), "at": PHONE_POS + Vector3(0, 0.2, 0)}, "Pick up your phone.")
	else:
		caption("The door is open now."); Audio.sfx("metalClick", 3.0, 1.15)
	await wait(1.6)
	touch.visible = true

## v32-polish: the spelled name plus a visible blinking caret (a thin bar; the space keeps the width steady)
var _caret_on := true
func _name_show() -> void:
	if is_instance_valid(name_lbl): name_lbl.text = S.name + ("|" if _caret_on else " ")

func _show_alphabet() -> void:
	var v := _side_panel(560)
	_title(v, "What is your name?", "Adın ne? Harflere dokun.")
	# v32-polish: field about 56 px tall (no extra panel padding), font 34, vertically centred, blinking caret
	var nsb := _sb(Color(0.93, 0.95, 1.0), 16, 8); nsb.content_margin_top = 0; nsb.content_margin_bottom = 0
	var np := PanelContainer.new(); np.name = "NameBox"; np.add_theme_stylebox_override("panel", nsb); np.custom_minimum_size.y = 56; v.add_child(np)
	name_lbl = Label.new(); name_lbl.name = "NameField"; name_lbl.add_theme_font_override("font", font_b); name_lbl.add_theme_font_size_override("font_size", 34)
	name_lbl.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; name_lbl.clip_text = true; name_lbl.custom_minimum_size.y = 56; np.add_child(name_lbl)
	var ct := Timer.new(); ct.wait_time = 0.5; ct.autostart = true; np.add_child(ct)
	ct.timeout.connect(func(): _caret_on = not _caret_on; _name_show())
	S.name = ""; _name_show()
	# v11: QWERTY like a phone keyboard (A-Z only), staggered rows, Delete + OK
	var kb := VBoxContainer.new(); kb.name = "Letters"; kb.add_theme_constant_override("separation", 8); v.add_child(kb)
	for ri in QWERTY.size():
		var row := HBoxContainer.new(); row.name = "Row%d" % ri; row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 5); kb.add_child(row)
		for L in QWERTY[ri]:
			var kl: String = L
			var b := _pill(kl, func(): type_letter(kl), Vector2(46, 60), 24); b.name = "Key_" + kl; b.clip_text = false; row.add_child(b)
			for st in ["normal", "hover", "pressed", "focus"]:
				var sb = b.get_theme_stylebox(st)
				if sb is StyleBoxFlat:
					var c2: StyleBoxFlat = sb.duplicate(); c2.content_margin_left = 2; c2.content_margin_right = 2; b.add_theme_stylebox_override(st, c2)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 10); kb.add_child(h)
	var del := _pill("Delete", func(): type_back(), Vector2(150, 60), 20); del.name = "Delete"; h.add_child(del)
	var ok := _pill("OK", func(): type_done(), Vector2(200, 60), 24, true); ok.name = "DoneName"; h.add_child(ok)
	_layout.call_deferred()

const QWERTY := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
func type_letter(L: String) -> void:
	if S.name.length() >= 12: return
	S.name += L if S.name == "" else L.to_lower()
	_name_show(); Audio.letter(L)

func type_back() -> void:
	Audio.click(); S.name = S.name.left(-1); _name_show()

func type_done() -> void:
	if S.name == "": caption("What is your name? How do you spell it?"); return
	Audio.click(); name_done.emit()

## mannequin -> real character: a soft glow builds up over the body, the face, hair and clothes swap in at the peak, glow fades
func take_shape() -> void:
	Audio.sfx("cloth3", 0.0, 1.2)
	var tw := create_tween(); tw.tween_method(hero.set_glow, 0.0, 0.85, 0.7).set_trans(Tween.TRANS_SINE)
	await tw.finished
	hero.set_mannequin(false); _apply_character()
	var tw2 := create_tween(); tw2.tween_method(hero.set_glow, 0.85, 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	await tw2.finished

func _flash() -> void:
	var tw := create_tween(); tw.tween_method(hero.set_glow, 0.45, 0.0, 0.5)

const SKIN_NAMES := ["light", "medium", "tan", "dark"]
var _creation_ms := 0
func _show_creation() -> void:
	_creation_ms = Time.get_ticks_msec()   # v29.1: ignore the tap that opened the creator
	var v := _side_panel(690)
	v.add_theme_constant_override("separation", 4)   # house.22: compact, fits one 720p-high screen
	var tl := Label.new(); tl.text = "Choose your look  ·  Görünüşünü seç"; tl.add_theme_font_override("font", font_b); tl.add_theme_font_size_override("font_size", 22); tl.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); v.add_child(tl)
	opt_btns.clear()
	var rows := [["age", "Age", "Yaş"], ["gender", "Body", "Vücut"], ["build", "Build", "Yapı"], ["height", "Height", "Boy"], ["hair", "Hair", "Saç"], ["hair_col", "Colour", "Saç rengi"],
		["skin", "Skin", "Ten"], ["top", "Top", "Üst"], ["bottoms", "Bottoms", "Alt"], ["shoes", "Shoes", "Ayakkabı"]]
	for r in rows:
		var h := HBoxContainer.new(); h.name = "Row_" + r[0]; h.add_theme_constant_override("separation", 6); v.add_child(h)
		var lv := VBoxContainer.new(); lv.custom_minimum_size.x = 92; lv.add_theme_constant_override("separation", -6); lv.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(lv)
		var l := Label.new(); l.text = r[1]; l.add_theme_font_override("font", font_b); l.add_theme_font_size_override("font_size", 17); l.add_theme_color_override("font_color", Color(0.2, 0.23, 0.32)); lv.add_child(l)
		var lt := Label.new(); lt.text = r[2]; lt.add_theme_font_size_override("font_size", 13); lt.add_theme_color_override("font_color", Color(0.4, 0.48, 0.7)); lv.add_child(lt)
		var opts := _opts(r[0]); opt_btns[r[0]] = []
		for i in opts.size():
			var b: Button
			if r[0] == "skin":
				b = _pill("", func(): _choose("skin", i), Vector2(84, 44))
				var c: Color = DemoCharacter.SKIN_TONES[i]
				for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, _sb(c, 24, 6))
			else:
				b = _pill(opts[i], func(): _choose(r[0], i), Vector2(104 if r[0] == "hair_col" else 176, 44), 17)
			b.name = "%s_%d" % [r[0], i]; h.add_child(b); opt_btns[r[0]].append(b)
	var done := _pill("Done", func(): Audio.click(); look_done.emit(), Vector2(0, 48), 22, true); done.name = "DoneLook"; v.add_child(done)
	_mark_sel()
	_layout.call_deferred()

func _opts(key: String) -> Array:
	match key:
		"age": return ["Child", "Adult"]
		"gender": return ["Boy", "Girl"] if is_child() else ["Man", "Woman"]
		"build": return ["Thin", "Average", "Fat"]
		"height": return ["Short", "Medium", "Tall"]
		"skin": return SKIN_NAMES
		"hair": return ["Short", "Medium", "Long"]
		"hair_col": return DemoCharacter.HAIR_NAMES
		"top": return Array(hero.option_labels("Body"))
		"bottoms": return Array(hero.option_labels("Legs"))
		"shoes": return Array(hero.option_labels("Feet"))
	return []

func _cur(key: String) -> int:
	match key:
		"age": return 0 if is_child() else 1
		"gender": return 0 if S.gender == "men" else 1
		"build": return ["thin", "average", "fat"].find(S.build)
		"height": return ["short", "medium", "tall"].find(S.height)
	return int(S.get(key, 1 if key == "hair_col" else 0))

func _mark_sel() -> void:
	for k in opt_btns:
		for i in opt_btns[k].size():
			var b: Button = opt_btns[k][i]
			if k == "skin":
				var c: Color = DemoCharacter.SKIN_TONES[i]
				var sb := _sb(c, 24, 6)
				if i == _cur(k): sb.border_color = Color(0.31, 0.42, 0.93); sb.set_border_width_all(4)
				for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, sb)
			else: _style_pill(b, i == _cur(k))

static func _wear(label: String) -> String:
	var l := label[0].to_lower() + label.substr(1)
	return "I am wearing %s." % l if label.ends_with("s") else "I am wearing a %s." % l

func _choose(key: String, i: int) -> void:
	if Time.get_ticks_msec() - _creation_ms < 400: return   # v29.1: no narration from the opening tap
	Audio.click()
	call_deferred("_refresh_look")   # house.29: live look refresh (blue MERGE_GUIDE §4)
	var line := ""
	match key:
		"age":
			S.age = ["child", "adult"][i]; line = ["I am a child.", "I am an adult."][i]
		"gender":
			S.gender = ["men", "women"][i]; line = (["I am a boy.", "I am a girl."] if is_child() else ["I am a man.", "I am a woman."])[i]
		"build":
			S.build = ["thin", "average", "fat"][i]; line = ["I am thin.", "My build is average.", "I am fat."][i]
		"height":
			S.height = ["short", "medium", "tall"][i]; line = ["I am short.", "I am medium height.", "I am tall."][i]
		"skin":
			S.skin = i; line = "My skin is %s." % SKIN_NAMES[i]
		"hair":
			S.hair = i; line = ["I have short hair.", "I have medium hair.", "I have long hair."][i]
		"hair_col":
			S.hair_col = i; line = "I have %s hair." % DemoCharacter.HAIR_NAMES[i].to_lower()
		"top": S.top = i; line = _wear(hero.option_labels("Body")[i])
		"bottoms": S.bottoms = i; line = _wear(hero.option_labels("Legs")[i])
		"shoes": S.shoes = i; line = _wear(hero.option_labels("Feet")[i])
	_apply_character(); _flash()
	if key in ["gender", "age"]:   # option labels differ per model / age: rebuild the panel
		_show_creation()
	else: _mark_sel()
	caption(line)

# ============================================================ mirror cues (until creation is done)
var cue_t := 0.0
var hint_t := 0.0
var edge_arrow: Polygon2D
func cues_on() -> bool:
	return not S.created and started and mode in ["play", "busy"] and side == null and not cam_shot.size() > 0 and S.alarm != "ringing" and mode != "opening"

func _mirror_hint() -> void:
	if not S.created and mode == "play": caption("Go to the mirror.")

func _mirror_cues(dt: float) -> void:
	if not N.has("mirror_glow"): return
	var on := cues_on() and mission == "Look in the mirror."
	var pon: bool = S.created and started and mode in ["play", "busy"] and side == null and cam_shot.is_empty() and mission == "Pick up your phone." and not S.has_phone and not phone.visible
	_phone_cues(pon)
	if phone_btn: phone_btn.visible = S.has_phone and side == null and not phone.visible and mode != "opening"
	if phone_dot: phone_dot.visible = notify_app != ""
	if phone_light:
		phone_light.visible = notify_app != "" and phone_btn.visible
		phone_light.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(cue_t * 5.0))
	hud.get_node("Mission").visible = false   # v30.5: Objectives only
	if side == null: hud.get_node("Pause").visible = not phone.visible
	var flash_on := on or cine_flash or pon
	cue_t += dt
	var pulse := 0.5 + 0.5 * sin(cue_t * 4.0)
	(N.mirror_glow.material_override as StandardMaterial3D).albedo_color.a = (0.25 + 0.5 * pulse) if on else 0.0
	N.mirror_glow.visible = on
	N.mirror_marker.visible = on
	N.mirror_marker.position.y = 2.45 + 0.08 * sin(cue_t * 3.0); N.mirror_marker.rotation.y += dt * 1.5
	# mission label highlight
	var mp: PanelContainer = hud.get_node("Mission")
	if cine_flash: pulse = 0.5 + 0.5 * sin(cue_t * 9.0)
	var mc := Color(0.31, 0.42, 0.93, 0.75 + 0.2 * pulse) if flash_on else Color(0.08, 0.10, 0.16, 0.6)
	var sb := mp.get_theme_stylebox("panel") as StyleBoxFlat
	if sb: sb.bg_color = mc; sb.border_color = Color(1, 1, 1, 0.5 + 0.4 * pulse); sb.set_border_width_all(3 if flash_on else 0)
	# repeat the spoken hint every 25 s while the player is not at the mirror
	if (on or pon) and mode == "play":
		hint_t += dt
		if hint_t > 25.0: hint_t = 0.0; _mirror_hint() if not pon else caption("Go to your phone.")
	# off-screen edge arrow
	if edge_arrow == null:
		edge_arrow = Polygon2D.new(); edge_arrow.name = "EdgeArrow"
		edge_arrow.polygon = PackedVector2Array([Vector2(26, 0), Vector2(-14, -20), Vector2(-6, 0), Vector2(-14, 20)])
		edge_arrow.color = Color(0.31, 0.47, 1.0); hud.add_child(edge_arrow)
	var tgt := PHONE_POS + Vector3(0, 0.2, 0) if pon else Vector3(-3.3, 1.3, 2.05)
	var vs := hud.size
	var sp := cam.unproject_position(tgt)
	var behind := cam.is_position_behind(tgt)
	var inside := not behind and Rect2(Vector2.ZERO, vs).grow(-30).has_point(sp)
	edge_arrow.visible = (on or pon) and not inside
	if edge_arrow.visible:
		var c := vs / 2.0
		var d := (sp - c) * (-1.0 if behind else 1.0)
		if d.length() < 1.0: d = Vector2.LEFT
		var m := 50.0
		var s := minf((c.x - m) / maxf(absf(d.x), 0.001), (c.y - m) / maxf(absf(d.y), 0.001))
		edge_arrow.position = c + d * s; edge_arrow.rotation = d.angle()
		edge_arrow.scale = Vector2.ONE * (1.0 + 0.15 * pulse)

func _rattle_door() -> void:
	Audio.sfx("handleSmallLeather", 2.0, 1.3); Audio.sfx("metalClick", 0.0, 0.7)
	get_tree().create_timer(0.25, false).timeout.connect(func(): Audio.sfx("metalClick", 0.0, 0.8))
	if N.has("door"):
		var d: Node3D = N.door; var r := d.rotation.y
		var tw := create_tween()
		for i in 4: tw.tween_property(d, "rotation:y", r + (0.03 if i % 2 == 0 else -0.03), 0.06)
		tw.tween_property(d, "rotation:y", r, 0.06)

## short cinematic after the alarm: swing to the window side, show the player's face and the mirror together
var cine_flash := false
const CINE_POS := Vector3(2.2, 1.65, -2.6)
const CINE_AT := Vector3(-1.5, 1.05, 0.5)
func _cine_mirror() -> void:
	cine_flash = true; touch.visible = false
	# turn three-quarters toward the camera, so the face shows with the mirror behind
	var d := (CINE_POS - hero.position).rotated(Vector3.UP, 0.45)
	var tw := create_tween(); tw.tween_property(hero, "rotation:y", atan2(d.x, d.z), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_shot = {"pos": CINE_POS, "at": CINE_AT}; shot_at = hero.position + Vector3(0, 1.0, 0)   # v304b: the swing starts aimed at the player (keeps them in frame)
	_cine_close_room()   # v304b: close the cut-away room only once the camera is inside it (see below)
	await wait(2.6)
	cam_shot = {}
	await wait(0.3)
	for b in N.closed: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await wait(0.3)
	cine_flash = false; touch.visible = true

## v304b (red): the roof/front wall become visible (SHADOWS_ONLY -> ON) for the cine shot. Turning them on while the swinging
## camera was still above the roof (y > WALL_H) filled the whole screen with the white roof for ~0.8 s. Wait until the
## camera is below the roof and inside the front wall, then close the room.
func _cine_close_room() -> void:
	while cine_flash and not cam_shot.is_empty() and (cam.position.y > WALL_H - 0.15 or cam.position.z > 3.0):
		await get_tree().process_frame
	if cine_flash and not cam_shot.is_empty():
		for b in N.closed: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

# ============================================================ v8: phone (hub) + job selection
const PHONE_POS := Vector3(-2.93, 0.513, -2.6)
var phone: Control
var phone_btn: Button
var phone_dot: Panel
var phone_lit := false
signal phone_done

func _phone_cues(on: bool) -> void:
	if not N.has("phone_glow"):
		N.phone_glow = box(Vector3(0.16, 0.004, 0.24), PHONE_POS + Vector3(0, 0.002, 0), Color(0.45, 0.65, 1.0), self, 2.5, 0.0)
		N.phone_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cone := CylinderMesh.new(); cone.top_radius = 0.14; cone.bottom_radius = 0.0; cone.height = 0.3; cone.radial_segments = 16
		N.phone_marker = MeshInstance3D.new(); N.phone_marker.mesh = cone
		var mkm := _mat(Color(0.31, 0.47, 1.0), 1.2); mkm.no_depth_test = true; mkm.render_priority = 5
		N.phone_marker.material_override = mkm; N.phone_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(N.phone_marker)
	var pulse := 0.5 + 0.5 * sin(cue_t * 4.0)
	N.phone_glow.visible = on; N.phone_marker.visible = on
	(N.phone_glow.material_override as StandardMaterial3D).albedo_color.a = 0.3 + 0.55 * pulse
	N.phone_marker.position = PHONE_POS + Vector3(0, 0.95 + 0.08 * sin(cue_t * 3.0), 0); N.phone_marker.rotation.y += 0.02
	if on: N.phone_screen.material_override = _mat(Color(0.35, 0.55, 1.0), 0.6 + 1.2 * pulse)
	elif not phone.visible and not phone_lit: N.phone_screen.material_override = _mat(Color(0.3, 0.9, 0.45) if S.phone == "charging" else Color(0.05, 0.05, 0.07), 1.5 if S.phone == "charging" else 0.0)

func _phone_rect() -> Rect2:
	var r := Rect2(cam.unproject_position(PHONE_POS), Vector2.ZERO)
	for dx in [-0.035, 0.035]:
		for dz in [-0.07, 0.07]: r = r.expand(cam.unproject_position(PHONE_POS + Vector3(dx, 0, dz)))
	return r

## walk to the bedside table (done by do_verb), reach, camera pans into the phone screen, phone UI zooms out of it
func phone_pickup() -> void:
	touch.visible = false
	await gesture("reach", "night", func(): Audio.sfx("metalClick", 0.0, 1.4))
	S.phone = "off"; N.cable.visible = false
	phone_lit = true; N.phone_screen.material_override = _mat(Color(0.8, 0.86, 1.0), 2.0)
	cam_shot = {"pos": PHONE_POS + Vector3(0, 0.24, 0.08), "at": PHONE_POS}
	await wait(2.0)
	caption("I am looking at my phone.")
	phone_closed_wait()
	var orect := _phone_rect()
	# v13: the phone leaves the table for good; the player carries it from now on
	S.has_phone = true; App.family_breakfast = true; N.phone_body.visible = false; N.phone_screen.visible = false; save_game()
	await phone.open(orect, "jobs" if not _job_chosen() else ("calendar" if is_child() and not S.calendar_seen else ("family" if not _family_ok() else "home")))
	await phone_done
	_advance(false)
	cam_shot = {}; phone_lit = false; await wait(0.8)
	touch.visible = true

## v13: App.has_phone is the shared flag every room (bedroom, bathroom, living room) reads
func _sync_app_phone() -> void:
	var app := get_node_or_null("/root/App")
	if app: app.has_phone = S.has_phone

func phone_closed_wait() -> void:
	await phone.closed
	phone_done.emit()

func open_phone_hud() -> void:
	if mode != "play" or phone.visible: return
	mode = "busy"; _hide_chips(); hand3d.visible = false; touch.visible = false; stick = Vector2.ZERO
	await Audio.wait_idle(12.0)   # house.17
	caption("I am looking at my phone.")
	var first: String = "jobs" if not _job_chosen() else ("calendar" if is_child() and not S.calendar_seen else ("family" if not _family_ok() else ("calendar" if notify_app == "calendar" else "home")))
	if S.has_phone:   # v13: the phone lives in the pocket: take out -> zoom -> UI -> zoom out -> pocket
		if pocket == null:
			pocket = load("res://scripts/pocket_phone.gd").new(); add_child(pocket); pocket.character = hero; pocket.camera = cam
			pocket.set_camera = func(shot: Dictionary): cam_shot = shot
		pocket.open_ui = func(r: Rect2):
			phone_lit = true
			phone_closed_wait()
			await phone.open(r, first)
			await phone_done
			phone_lit = false
		await pocket.use()
	else:
		phone_closed_wait()
		await phone.open(phone_btn.get_global_rect(), first)
		await phone_done
	_advance(false)
	touch.visible = true; mode = "play"; _update_hand()

var pocket: Node

func phone_event(p: String) -> void:
	if p == "family" and phone.page == "lesson": p = "lesson"
	match p:
		"jobs": caption("I am choosing my job." if not _job_chosen() else "I am opening the Jobs app."); _set_mission("Choose a job on your phone." if not _job_chosen() else mission)
		"grammar": caption("I am learning grammar.")
		"words": caption("I am learning new words.")
		"me": pass   # house.17: "I am looking at my phone." only once per open (said on open)
		"lesson":   # v32-polish: only the family he/she/it lesson (the dream review / scripted lessons used to stack this line)
			if phone.les.is_empty(): caption("I am learning about he, she and it."); _set_mission("Learn he, she and it.")
		"quiz":   # v32-polish: scripted tests (review / big test / day-2 test) have their own narrator line; no second box
			if phone.les.is_empty(): caption("I am answering a question.")
		"family":
			if _family_ok(): caption("I am looking at my family.")
			else:
				caption("I am adding my family.")
				if S.lesson_done: _set_mission("Add your family.")
		"member": caption("I am adding a family member.")
		"calendar": caption("I am looking at my calendar.")

func _on_job_chosen(id: String) -> void:
	S.job = id; S.door_locked = door_rule()
	caption(phone.job(id).get("now", "I am a %s now." % id))
	_advance(true)
	save_game()

# ---- v9: objectives, notifications, to-do list
var notify_app := ""
var phone_light: Panel
var extra := {}
func extra_tr(t: String) -> String:
	if extra.is_empty():
		var d = App.load_json("res://data/extra_lines.json"); extra = d if d is Dictionary else {"_": ""}
	var r: String = extra.get(t, "")
	if r == "" and t.begins_with("I weigh ") and t.ends_with(" kilos."): r = "%s kiloyum." % t.trim_prefix("I weigh ").trim_suffix(" kilos.")   # v29.1
	if r == "" and t.begins_with("My name is ") and t.ends_with("."): r = "Benim adım %s." % t.trim_prefix("My name is ").trim_suffix(".")
	return r

func is_child() -> bool:
	return S.get("age", "adult") == "child"

## house.17: the south (living-room) door also needs the bathroom routine
func s_locked() -> bool:
	return S.door_locked or (not App.bath_done and WorldState.day < 2)   # v31: day 2+ needs neither the mirror nor the bathroom

func _day2_stage() -> String:
	return load("res://scripts/story/day2_morning.gd").stage()

## v32c (red): one string from save.json "story"
func _story_str(k: String) -> String:
	var sv = App.load_save().get("story", {})
	return String(sv.get(k, "")) if sv is Dictionary else ""

## v33 (red): day-2 / day-3 evening: the couch talk is done and bedtime.gd has not run yet (story.d2_bed_pending / d3_bed_pending)
func _bed_pending() -> bool:
	var sv = App.load_save().get("story", {})
	if not sv is Dictionary: return false
	var d := maxi(WorldState.day, App.day)
	return (d == 2 and bool(sv.get("d2_bed_pending", false)) and not bool(sv.get("d2_bedtime_done", false))) \
		or (d == 3 and bool(sv.get("d3_bed_pending", false)) and not bool(sv.get("d3_bedtime_done", false)))

## v32 (red): story.d3 ("shower" -> "living" -> "outside" -> "done"), only on day 3+
func _day3_stage() -> String:
	if maxi(WorldState.day, App.day) < 3: return ""
	return load("res://scripts/story/day3_morning.gd").stage()

## v31: after the day-2 wake-up call: camera pan to the living-room door (same shot pattern as _cine_mirror), sound,
## top-left mission "Go to the living room." (spoken once), then free play
func day2_living_prompt() -> void:
	mode = "busy"; _hide_chips()
	_reveal_room_deferred()   # v304b: same deferred roof/wall reveal as _cine_close_room (no white roof while the camera is above it)
	await Life.guide_to({"pos": D2_DOOR_CAM, "at": Vector3(1.8, 1.1, 3.0)}, "Go to the living room.")
	for b in N.closed: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	mode = "play"; _update_hand(); _advance(false)
const D2_DOOR_CAM := Vector3(-1.2, 1.9, -1.6)
func _reveal_room_deferred() -> void:
	var t := 0
	while cam_shot.is_empty() and t < 60: await get_tree().process_frame; t += 1
	while not cam_shot.is_empty() and (cam.position.y > WALL_H - 0.15 or cam.position.z > 3.0): await get_tree().process_frame
	if not cam_shot.is_empty():
		for b in N.closed: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func door_rule() -> bool:
	return not (S.created and S.job != "" and _family_ok())

## v33 child-drive: a family exists (adults, as before) and, for a child, it has a mom or a dad
func _family_ok() -> bool:
	var fam: Array = S.family if S.get("family", []) is Array else []
	if fam.is_empty():
		var st = App.load_save().get("state", {})
		if st is Dictionary and st.get("family") is Array and not st.family.is_empty():
			S.family = st.family; fam = S.family
	return not fam.is_empty() and (not is_child() or ChildDrive.has_parent(fam))

## saved chosen-job flag: live S.job or save.json state.job (never re-prompt once chosen)
func _job_chosen() -> bool:
	if String(S.get("job", "")) != "": return true
	var st = App.load_save().get("state", {})
	return st is Dictionary and String(st.get("job", "")) != ""

## [mission, phone app to badge] for the current state
func objective() -> Array:
	if not S.created: return [mission, ""]
	if String(S.get("job", "")) == "" or (S.get("family", []) is Array and S.family.is_empty()):
		var _st = App.load_save().get("state", {})
		if _st is Dictionary:
			if String(S.get("job", "")) == "" and String(_st.get("job", "")) != "": S.job = String(_st.job)
			if (S.get("family", []) is Array and S.family.is_empty()) and _st.get("family") is Array and not _st.family.is_empty(): S.family = _st.family
	if WorldState.day > 1 and not S.calendar_seen: S.calendar_seen = true
	if not _job_chosen(): return ["Choose a job on your phone." if S.has_phone else "Pick up your phone.", "jobs"]
	if is_child() and not S.calendar_seen: return ["Open the Calendar." if S.has_phone else "Pick up your phone.", "calendar"]
	if not S.lesson_done: return ["Learn he, she and it.", "family"]
	if not _family_ok(): return ["Add your family.", "family"]
	if not S.calendar_seen: return ["Open the Calendar.", "calendar"]
	if WorldState.day >= 2 and S.alarm == "ringing": return ["Turn off the alarm clock.", ""]   # build 3.2 (black #26): never "Take a shower." under a ringing alarm
	var d2 := _day2_stage()
	if _bed_pending(): return ["Go to bed.", ""]   # v33 (red): evening after the couch talk -> bedtime.gd; never the stale "Go to the living room."
	if Objectives.d2_chat_done(): return ["Go to bed.", ""]   # Yasin 17:58: never "Go to the living room." after the day-2 family chat
	if d2 == "living": return ["Go to the living room.", ""]   # v31: day-2 morning
	if d2 == "car": return ["Go outside to the car.", ""]
	if _day3_stage() == "shower": return ["Take a shower.", ""]   # v32 (red): day-3 morning: the shower first, the living room only after it (Day3Morning)
	var d47: String = load("res://scripts/story/day4_routine.gd").main_objective()   # v33 (red): day 4 / day 7 routine step (+ day-8 placeholder)
	if d47 != "": return [d47, ""]
	if not App.bath_done and WorldState.day < 2: return ["Go to the bathroom.", ""]   # v31: not on day 2+; house.17: bathroom first, then the living room
	return ["Go to the living room.", ""]

func _advance(sound: bool) -> void:
	if _hosp_home:   # v33: day-1 night after the hospital (review / tests in bed): no room objective until the day-2 morning
		var _st = App.load_save().get("story", {})
		if not (_st is Dictionary and bool(_st.get("day1_done", false))): return
	load("res://scripts/story/day4_routine.gd").start(get_tree())   # v33 (red): day-4 / day-7 routine (idempotent; day 7 starts from blue's day 6)
	var o := objective()
	var prev := mission
	# Bathroom-door / mirror pans: black bot (Life.guide_to). We only feed Objectives + speak.
	if o[0] != prev and o[0] == "Go to the bathroom.":   # v30.4: pan to the bathroom door once the phone is put away
		_set_mission(o[0])
		_bath_guide()
	elif o[0] != prev and o[0] == "Go to the living room." and App.bath_done and WorldState.day < 2:
		await Life.guide_to({"pos": Vector3(0.2, 1.9, 0.6), "at": Vector3(1.8, 1.1, 3.0)}, o[0])
	else:
		if o[0] != prev and o[0] in ["Go to the living room."] and S.voice and Life.once("say|main|" + o[0]): Audio.say(o[0], false)   # v32: not again on room re-entry
		_set_mission(o[0])
	if o[1] != notify_app:
		if o[1] != "" and sound: notify(o[1])
		else: notify_app = o[1]

## soft phone notification: chime, pulsing light on the HUD phone icon, badge on the app
func notify(app: String) -> void:
	notify_app = app
	Audio.sfx("notify", -4.0)
	if not phone.visible and app != "jobs": caption("I have a new message on my phone.")
	if phone.visible and phone.page == "home": phone.show_page("home", false)

func todo() -> Array:
	return [["Turn off the alarm clock.", S.alarm != "ringing" and started], ["Look in the mirror.", S.created], ] + ([] if is_child() else [["Choose a job.", _job_chosen()]]) + [
		["Learn he, she and it.", S.lesson_done], ["Add your family.", _family_ok()], ["Open the Calendar.", S.calendar_seen],
		["Open the door.", S.door_opened], ["Explore the house.", false]] + \
		(phone.tasks(S.job).map(func(t): return [t.do, false]) if S.job != "" else [])

func _on_lesson_finished() -> void:
	S.lesson_done = true; _advance(false); save_game()

func member_saved() -> void:
	save_game()

func _on_family_saved() -> void:
	App.family_breakfast = true
	S.door_locked = door_rule(); save_game()
	caption("This is my family.")
	Audio.sfx("metalClick", 3.0, 1.15)
	_advance(true)

func _on_calendar_opened() -> void:
	if not S.calendar_seen and (not S.family.is_empty() or is_child()):
		S.calendar_seen = true; save_game(); _advance(false)

## house.24.1: same stable lighting as the living room: no lamp specular / distance fade / omni shadows (no camera-dependent hot spots)
func _stable_lights() -> void:
	for l in find_children("*", "OmniLight3D", true, false):
		l.light_specular = 0.0; l.distance_fade_enabled = false; l.shadow_enabled = false; l.omni_attenuation = 1.0

func _refresh_look() -> void:
	if has_node("/root/Game"): Game.refresh_character(S)


## v30.4: day 1 after the calendar: Life.guide_to pan onto the bathroom door (after the phone is closed and play resumes)
func _bath_guide() -> void:
	if phone and phone.visible: await phone.closed
	var t0 := Time.get_ticks_msec()
	while mode != "play" and Time.get_ticks_msec() - t0 < 30000: await get_tree().process_frame
	if mode != "play" or App.bath_done or mission != "Go to the bathroom." or S.get("bath_guided", false): return
	S.bath_guided = true; save_game()
	await wait(0.3)
	await Life.guide_to({"pos": Vector3(-1.0, 1.9, -1.9), "at": Vector3(3.5, 1.1, 1.2)}, "Go to the bathroom.", {"tr": "Banyoya git.", "no_flash": true})

## v30.5: visible south (camera-side) wall: a solid low part (0..LOW) with the door gap, the upper part + lintel fade like
## the side walls when they hide the player (walls_s). The shadow-only N.closed box stays as before (daylight / cine shots).
var walls_s: Array = []
const WallFade := preload("res://scripts/props/wall_fade.gd")   # v32-polish: shared wall-fade helper
var wall_fade: Node
## v32-polish: the south (camera-side) wall segments fade through the shared helper (gradual, distance based)
func _wall_fade_setup() -> void:
	wall_fade = WallFade.attach(self, func(): return cam.global_position if is_instance_valid(cam) else Vector3.INF, func(): return hero.global_position if is_instance_valid(hero) else Vector3.INF)
	for w in walls_s: wall_fade.register(w)
	for w in walls_l: wall_fade.register_occluder(w, {"group": "L", "out": func(): return cam.position.x < -3.5})   # v33: side walls fade only while they hide the player
	for w in walls_r: wall_fade.register_occluder(w, {"group": "R", "out": func(): return cam.position.x > 3.5})
const SOUTH_LOW := 0.9
func _south_wall(x0: float, x1: float, g0: float, g1: float, z: float, c: Color) -> void:
	for seg in [[x0, g0], [g1, x1]]:
		var w: float = seg[1] - seg[0]
		if w <= 0.01: continue
		var cx: float = (seg[0] + seg[1]) / 2
		var lo := box(Vector3(w, SOUTH_LOW, 0.1), Vector3(cx, SOUTH_LOW / 2, z), c.darkened(0.06)); (lo.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		walls_s.append(box(Vector3(w, WALL_H - SOUTH_LOW, 0.1), Vector3(cx, (WALL_H + SOUTH_LOW) / 2, z), c.darkened(0.06)))
	for w2 in walls_s: (w2.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	walls_s.append(box(Vector3(g1 - g0, WALL_H - 2.12, 0.1), Vector3((g0 + g1) / 2, (WALL_H + 2.12) / 2, z), c.darkened(0.06)))
	(walls_s[-1].material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

## build 3.2: Life.guide_to objective shots (cam_shot.guide) are WORLD space (ShoulderCam frames hero + target with them);
## story cam_shots stay room-local
func _shot_l(k: String) -> Vector3:
	var v: Vector3 = cam_shot[k]
	return to_local(v) if bool(cam_shot.get("guide", false)) else v
