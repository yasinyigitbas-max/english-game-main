## English Home 3D: LIVING ROOM. Same style, camera, HUD, character and interaction model as the bedroom
## (english_game_3dv2/scripts/main.gd). Stateful objects, seated poses on real seat heights, captions + Turkish + Piper voice.
extends Node3D
const GameMenu = preload("res://scripts/game_menu.gd")

signal action_peak(id: String)
signal action_done(id: String)
signal captioned(text: String)
## emitted when the player walks out through the door (main game: change room here)
signal exit_requested(target: String)

const FURN := "res://props/furniture/"
## House plan (world_dev/LAYOUT_DOORS.md): living room inner floor 11.7 x 6 south of the bedroom + bathroom.
## Room-local x = house x + 2.35, z = house z - 3.2 (scene origin in the house: (-2.35, 3.2), yaw 0).
const ROOM := Rect2(-3.5, -3.0, 11.7, 6.0)   # x, z
const RCX := 2.35                            # room centre x
const EX := 8.2                              # east (outer) wall inner face
const DOOR_BED := Vector2(1.35, 2.25)        # north wall door -> bedroom (bedroom +Z door)
const DOOR_BATH := Vector2(5.5, 6.4)         # north wall door -> bathroom (bathroom +Z door)
const DOOR_FRONT := Vector2(1.85, 2.85)      # south (camera-side) wall: front door
## false = no door panels in the two north openings (use when the bedroom/bathroom scenes already have their own door there)
@export var north_door_panels := true
const WALL_H := 2.6
const R := 0.22
const WALK := 1.955   # house.15 max walk speed
const WALK_CLIP := 1.7
const RUN := 3.3
var RUN_CLIP := 3.3
const RUN_ON := 99.0  # house.15: walk only
#
const RUN_OFF := 0.64
var running := false
var move_sp := 0.0

# ---- palette (bedroom)
const C_WALL := Color(0.90, 0.88, 0.85)
const C_SAGE := Color(0.62, 0.74, 0.70)
const C_FLOOR := Color(0.80, 0.66, 0.50)
const C_WOOD := Color(0.72, 0.56, 0.40)
const C_CAB := Color(0.96, 0.95, 0.93)
const C_BLUE := Color(0.40, 0.56, 0.76)
const C_CORAL := Color(0.93, 0.52, 0.44)
const C_CREAM := Color(0.95, 0.90, 0.80)
const C_WHITE := Color(1, 1, 1)
const C_DARK := Color(0.16, 0.16, 0.18)

## seats: hips target (x,z), seat top height, facing yaw. Used by the player and by family members.
const SOFA_X := 2.62
const SEAT_TOP := 0.44
const DINE_C := Vector3(5.6, 0, 0.9)
var SEATS := {
	"sofa_left": {"hips": Vector3(SOFA_X, 0, 0.62), "top": SEAT_TOP, "yaw": -PI / 2, "obj": "sofa"},
	"sofa_middle": {"hips": Vector3(SOFA_X, 0, 0.0), "top": SEAT_TOP, "yaw": -PI / 2, "obj": "sofa"},
	"sofa_right": {"hips": Vector3(SOFA_X, 0, -0.62), "top": SEAT_TOP, "yaw": -PI / 2, "obj": "sofa"},
	"armchair": {"hips": Vector3.ZERO, "top": SEAT_TOP, "yaw": deg_to_rad(-32.0), "obj": "armchair"},
}
const ARM_C := Vector3(-1.45, 0, -2.25)

const TR := {
	"Welcome to the living room!": "Oturma odasına hoş geldin!",
	"Turn on the TV.": "Televizyonu aç.", "Sit on the sofa.": "Kanepeye otur.", "Change the channel.": "Kanalı değiştir.",
	"Read a book.": "Bir kitap oku.", "Water the plants.": "Bitkileri sula.", "Close the curtains.": "Perdeleri kapat.",
	"Turn on the floor lamp.": "Ayaklı lambayı aç.", "Explore the living room.": "Oturma odasını keşfet.", "Well done!": "Aferin!",
	"I am going to the sofa.": "Kanepeye gidiyorum.", "I am going to the armchair.": "Koltuğa gidiyorum.",
	"I am going to the TV.": "Televizyona gidiyorum.", "I am going to the coffee table.": "Sehpaya gidiyorum.",
	"I am going to the floor lamp.": "Ayaklı lambaya gidiyorum.", "I am going to the light switch.": "Işık düğmesine gidiyorum.",
	"I am going to the window.": "Pencereye gidiyorum.", "I am going to the bookcase.": "Kitaplığa gidiyorum.",
	"I am going to the plant.": "Bitkiye gidiyorum.", "I am going to the big plant.": "Büyük bitkiye gidiyorum.",
	"I am going to the family photos.": "Aile fotoğraflarına gidiyorum.",
	"I am going to the bedroom door.": "Yatak odası kapısına gidiyorum.", "I'm in the living room now.": "Şimdi oturma odasındayım.", "I am going to the bathroom door.": "Banyo kapısına gidiyorum.",
	"I am going to my bedroom.": "Yatak odama gidiyorum.", "I am going to the bathroom.": "Banyoya gidiyorum.",
	"I am sitting on the sofa.": "Kanepeye oturuyorum.", "I am sitting in the armchair.": "Koltuğa oturuyorum.",
	"I am standing up.": "Ayağa kalkıyorum.", "I am tidying the cushions.": "Yastıkları düzeltiyorum.",
	"I am folding the blanket.": "Battaniyeyi katlıyorum.", "I am putting the blanket on my legs.": "Battaniyeyi bacaklarıma örtüyorum.",
	"I am taking the blanket off.": "Battaniyeyi kaldırıyorum.",
	"I am turning on the TV.": "Televizyonu açıyorum.", "I am turning off the TV.": "Televizyonu kapatıyorum.",
	"I am changing the channel.": "Kanalı değiştiriyorum.", "I am watching TV.": "Televizyon izliyorum.",
	"I am opening the drawer.": "Çekmeceyi açıyorum.", "I am closing the drawer.": "Çekmeceyi kapatıyorum.",
	"I am taking the remote control.": "Kumandayı alıyorum.", "I am putting the remote control down.": "Kumandayı bırakıyorum.",
	"I am drinking some tea.": "Biraz çay içiyorum.",
	"I am turning on the floor lamp.": "Ayaklı lambayı açıyorum.", "I am turning off the floor lamp.": "Ayaklı lambayı kapatıyorum.",
	"I am turning on the light.": "Işığı açıyorum.", "I am turning off the light.": "Işığı kapatıyorum.",
	"I am opening the curtains.": "Perdeleri açıyorum.", "I am closing the curtains.": "Perdeleri kapatıyorum.",
	"I am opening the window.": "Pencereyi açıyorum.", "I am closing the window.": "Pencereyi kapatıyorum.",
	"I am looking out of the window.": "Pencereden dışarı bakıyorum.",
	"I am taking a book.": "Bir kitap alıyorum.", "I am reading a book.": "Kitap okuyorum.", "I am putting the book back.": "Kitabı geri koyuyorum.",
	"I am watering the plant.": "Bitkiyi suluyorum.", "The plant is happy now.": "Bitki artık mutlu.",
	"I am looking at the photos.": "Fotoğraflara bakıyorum.", "This is my family.": "Bu benim ailem.",
	"I am straightening the picture.": "Resmi düzeltiyorum.",
	"I am opening the door.": "Kapıyı açıyorum.", "I am closing the door.": "Kapıyı kapatıyorum.",
	"I am walking.": "Yürüyorum.", "I am running.": "Koşuyorum.",
	"This is the news.": "Bu haberler.", "This is a cartoon.": "Bu bir çizgi film.", "This is a nature show.": "Bu bir doğa programı.",
	"This is sport.": "Bu spor.", "My hands are full.": "Ellerim dolu.", "It is evening now.": "Artık akşam.",
	"I am looking at my missions.": "Görevlerime bakıyorum.",
	"I am going to the front door.": "Ön kapıya gidiyorum.", "I am going to the shoe rack.": "Ayakkabılığa gidiyorum.",
	"I am opening the front door.": "Ön kapıyı açıyorum.", "I am closing the front door.": "Ön kapıyı kapatıyorum.",
	"I am locking the door.": "Kapıyı kilitliyorum.", "I am unlocking the door.": "Kapının kilidini açıyorum.",
	"I am putting on my shoes.": "Ayakkabılarımı giyiyorum.", "I am taking off my shoes.": "Ayakkabılarımı çıkarıyorum.",
	"I am taking my keys.": "Anahtarlarımı alıyorum.", "I am putting my keys back.": "Anahtarlarımı geri koyuyorum.",
	"The door is locked.": "Kapı kilitli.",
}

var hero: DemoCharacter
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var S := {"tv": "off", "channel": 0, "ceiling": "on", "floorlamp": "off", "curtains": "open", "window": "closed",
	"drawer": "closed", "plant": "dry", "plant2": "dry", "plant3": "dry", "plant4": "dry", "book": "shelf", "remote": "table", "blanket": "folded",
	"cushions": "messy", "picture": "crooked", "door_bed": "closed", "door_bath": "closed", "front": "closed", "lock": "locked", "shoes": "rack", "keys": "hook", "seat": "", "tr": false, "voice": true,
	"gender": "men", "watched": false, "read": false}
var OBJ := {}
var N := {}
var obstacles: Array[Rect2] = []
var astar := AStarGrid2D.new()
var mode := "play"       # play | busy | seated
var near_id := ""
var stick := Vector2.ZERO
var cam_focus := Vector3.ZERO
var hand3d: Sprite3D
var ui: CanvasLayer
var touch: Control
var font: FontVariation
var font_b: FontVariation
var hud: Control; var mission_lbl: Label; var mission_tr: Label
var cap_panel: PanelContainer; var cap_en: Label; var cap_tr: Label; var tr_btn: Button
var chips: VBoxContainer; var chips_scroll: ScrollContainer
var menu: Control; var tasks_panel: Control; var tasks_list: VBoxContainer
var cap_text := ""
var cam_zoom := 1.0
var cam_yaw := 0.0
var cam_pitch := 0.9025
var cam_dist := 9.68
var cam_stick := Vector2.ZERO
var walls_l: Array = []
var walls_r: Array = []
var front_alpha := 1.0
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
var water_fx: CPUParticles3D
var family: Array = []          # seated family members (DemoCharacter)
var remote_in_hand: Node3D

# ============================================================ setup
const House := preload("res://scripts/core/house.gd")   # v32wh: whole house
func _ready() -> void:
	if House.shell_ready(self, func(): _build_room(); preload("res://scripts/decor/decor_living.gd").build(self)): return   # v32wh: next-door room = geometry only
	_live_ready()

func _live_ready() -> void:   # v32wh: the v32 _ready (also run when this room's shell turns live)
	DoorLabel.attach.call_deferred(self, OBJ, {"door_bed": ["Bedroom", "Yatak odası"], "door_bath": ["Bathroom", "Banyo"], "front": ["Outside", "Dışarı"]})   # v30.2
	S.tr = App.tr_saved(); call_deferred("_refresh_text")   # v29.1: shared persisted TR flag (default off)
	SEATS.armchair.hips = ARM_C + Vector3(sin(SEATS.armchair.yaw), 0, cos(SEATS.armchair.yaw)) * 0.02
	_build_env()
	if not has_meta("wh_built"):   # v32wh: a shell turning live already has its geometry
		_build_room()
		preload("res://scripts/decor/decor_living.gd").build(self)   # decor-living
	_build_grid()
	water_fx = CPUParticles3D.new(); water_fx.amount = 80; water_fx.lifetime = 0.55; water_fx.emitting = false; water_fx.local_coords = false
	water_fx.direction = Vector3(0, -1, 0); water_fx.spread = 8.0; water_fx.initial_velocity_min = 0.4; water_fx.initial_velocity_max = 0.7
	var dm := SphereMesh.new(); dm.radius = 0.008; dm.height = 0.016; water_fx.mesh = dm
	water_fx.material_override = _mat(Color(0.45, 0.7, 1.0), 0.3, 0.85); add_child(water_fx)
	hero = OwLink.hero_for(self); hero.setup(S.gender)
	_apply_character()   # house.18: the bedroom creator's player (child/adult, gender, look) from save.json
	hero.position = Vector3(RCX, 0, 2.3); hero.rotation.y = PI
	cam = OwLink.cam_for(self); cam.fov = 42; cam.current = true
	cam_focus = _cam_target(); _update_cam(1.0)
	hand3d = Sprite3D.new(); hand3d.texture = load("res://ui/hand.png"); hand3d.pixel_size = 0.0013
	hand3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED; hand3d.no_depth_test = true; hand3d.modulate = Color(1, 1, 1, 0.95)
	hand3d.render_priority = 10; hand3d.visible = false; add_child(hand3d)
	_build_ui()
	_apply_states()
	_house_enter()
	if "--qa" in OS.get_cmdline_user_args():
		var qa = load("res://scripts/qa_living.gd").new(); add_child(qa); qa.run(self)
	else:
		_intro.call_deferred()
	House.live_ready(self)   # v32wh: the two other rooms as shells next door

## v33town (one persistent house): the living room was live before and slept; the family, the table, the TV, the
## breakfast... stay exactly as they were. Re-entry runs only the room-entry steps (TR, look, _intro: caption / story).
func _wh_resume() -> void:
	S.tr = App.tr_saved(); call_deferred("_refresh_text")
	_apply_character(); _apply_states()
	mode = "play"; _update_hand()
	if "--qa" in OS.get_cmdline_user_args(): return
	_intro.call_deferred()

## v33town: the spot just inside the door the player comes through (same spots as in _house_enter)
func _wh_spawn(from: String) -> Array:
	if from in ["bedroom", "bathroom"]:
		var dv: Vector2 = DOOR_BED if from == "bedroom" else DOOR_BATH
		return [Vector3((dv.x + dv.y) / 2, 0, -2.1), 0.0]
	return []

func _intro() -> void:
	load("res://scripts/story/day7_party.gd").prepare(self)   # v33 (red): day 7 coming home: dark room, the family hides (surprise)
	load("res://scripts/story/day4_routine.gd").start(get_tree())   # v33 (red): day-4 / day-7 routine (idempotent)
	await wait(0.6)
	caption("I'm in the living room now.", false)   # house.17: silent room caption
	_advance()
	# v30.4: a game continued on day 2 before the wake-up call had saved story.day2 (long night lessons/tests) has an empty
	# stage -> it got the day-1 breakfast, which ends without the car prompt. Day 2+ with no stage = the day-2 morning.
	if maxi(WorldState.day, App.day) >= 2 and D2.stage() == "" and not breakfast_done: D2.set_stage("living")
	if Day2After.pending() != "": await wait(1.0); await Day2After.run(self, "living"); return   # v30.5: back from work / hospital
	if D2.stage() == "living" and maxi(WorldState.day, App.day) >= 2:   # v31-fixes: day 2+ only; v31: day-2 morning scripted breakfast (scripts/story/day2_morning.gd)
		await wait(1.2); var d2 = D2.new(); d2.lr = self; add_child(d2); await d2.run(); _advance(); return
	load("res://scripts/story/day3_evening.gd").start(get_tree())   # v32c (red): day-3 evening couch talk (after the cafe + the shop) / "Go to bed."
	if breakfast_pending(): await wait(2.0); breakfast_call()

# ============================================================ house.17: breakfast with the family (present simple lesson + quiz)
var XTR := {}                 # extra Turkish lines (breakfast.json)
var BK := {}
var breakfast_done := false
var join_btn: Button   # (unused since house.18: breakfast starts by itself)
signal breakfast_finished(score: int, total: int)

func _bk_load() -> void:
	BK = App.load_json("res://data/breakfast.json"); BK = BK if BK is Dictionary else {}
	for k in BK.get("lines", {}): XTR[k] = BK.lines[k]
	for w in BK.get("week", []): XTR[w[0]] = w[1]

func humans() -> Array:
	return breakfast_members.filter(func(b): return String(b.seat) != "")

const D2 := preload("res://scripts/story/day2_morning.gd")
func breakfast_pending() -> bool:
	if maxi(WorldState.day, App.day) >= 2: return false   # v30.4: never the day-1 breakfast on day 2+   # v31-fixes: only day 2+ (a stale story.day2 hid day 1); v31: on day 2 the scripted day-2 breakfast replaces the day-1 one
	return not breakfast_done and not humans().is_empty() and not BK.is_empty() and not "--qa" in OS.get_cmdline_user_args()

## house.18: a family member calls; when the call has been said the player walks to the free chair by itself
func _say_as(b: Dictionary, en: String, tr_line: String) -> void:
	var who := String(b.data.get("name", ""))
	var line := "%s: %s" % [who, en]; XTR[line] = "%s: %s" % [who, tr_line]
	await Audio.wait_idle(12.0); caption(line, false); Audio.say_as(en, voice_of(b)); action_peak.emit("talk")
	_talk_nod(b.node)
	await Audio.wait_idle(12.0); await wait(0.7)

## house.26: each family member has their own Piper voice (distinct within the family); child = pitched-up voice
const VOICES_F := ["amy", "kristin", "hfc_female", "lessac"]
const VOICES_M := ["ryan", "joe", "hfc_male"]
func voice_of(b: Dictionary) -> String:
	var hs := humans(); var nf := 0; var nm := 0; var nc := 0
	for x in hs:
		var child: bool = x.data.get("child", false)
		var fem: bool = x.node is DemoCharacter and x.node.gender == "women"
		var v := ""
		if child: v = ["child_f", "child_m"][nc % 2] if fem else ["child_m", "child_f"][nc % 2]; nc += 1
		elif fem: v = VOICES_F[nf % VOICES_F.size()]; nf += 1
		else: v = VOICES_M[nm % VOICES_M.size()]; nm += 1
		if x == b: return v
	return ""

## the player's own line in a conversation (narrator voice), "Me:" caption
## v32-polish SCRAMBLE RULE: the sentence the player is building shows in the ONE standard caption box ("Me: ..."),
## TR inside once complete; _say_me() then speaks the same line in the same box, so it shows once (no second panel)
func caption_live(line: String, tr_line := "") -> void:
	if tr_line != "": XTR[line] = tr_line
	cap_text = line; cap_serial += 1; cap_panel.visible = line != ""; _refresh_text()
	if cap_panel.visible: StoryUI.claim(cap_panel)   # v32-polish: also when the box was already up (no visibility_changed) -> any other box hides

func _say_me(en: String, tr_line: String) -> void:
	var line := "Me: " + en; XTR[line] = "Ben: " + tr_line
	await Audio.wait_idle(12.0); caption(line, false); Audio.say(en)
	await Audio.wait_idle(12.0); await wait(0.6)

func _talk_nod(ch: Node3D) -> void:
	if not ch is DemoCharacter: return
	var tw := create_tween()
	tw.tween_method(func(a): ch.bone_offsets["Head"] = [Vector3.RIGHT, a], 0.0, 0.18, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a): ch.bone_offsets["Head"] = [Vector3.RIGHT, a], 0.18, 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func breakfast_call() -> void:
	Life.event("breakfast")   # house.29: event clock
	var h: Dictionary = humans()[0]
	var nm: String = String(room_phone.S.get("name", "")) if room_phone and room_phone.S.get("name", "") != "" else "friend"
	mode = "busy"; _hide_chips(); hand3d.visible = false; stick = Vector2.ZERO
	if wall_fade: wall_fade.force_fade(true)   # v32-polish: the south wall never blocks the breakfast pan / camera
	await Life.guide_to({"pos": DINE_C + Vector3(0.2, 2.0, 2.2), "at": DINE_C + Vector3(0, 0.9, 0)}, "Have breakfast with your family.")
	await Audio.wait_idle(12.0)
	var who := "%s (my %s)" % [String(h.data.get("name", "")), String(h.data.get("role", ""))]
	var line := "%s: Good morning, %s! Come and join us at the table." % [who, nm]
	XTR[line] = "%s: Günaydın, %s! Gel, masada bize katıl." % [who, nm]
	caption(line, false); Audio.say_as("Good morning!", voice_of(h)); Audio.say_as("Come and join us at the table.", voice_of(h)); _talk_nod(h.node)
	await Audio.wait_idle(15.0); await wait(1.2)
	mode = "play"; start_breakfast()

var eat_tw: Tween
func start_breakfast() -> void:
	if mode != "play" or breakfast_done: return
	mode = "busy"; _hide_chips(); hand3d.visible = false; stick = Vector2.ZERO
	await Audio.wait_idle(12.0)
	var n := humans().size(); var seat := ""
	if n < DINE_CHAIRS.size():
		var c: Array = DINE_CHAIRS[n]; seat = c[0]
		if n >= 4: _dining_chair(DINE_C + c[1], c[2], C_CREAM, breakfast_root)
		if n >= 4: _place_setting(n, breakfast_root)
		var f := Vector3(sin(c[2]), 0, cos(c[2]))
		SEATS[seat] = {"hips": DINE_C + c[1] - f * (0.03 + _body_back(hero)), "top": 0.475, "yaw": c[2], "obj": "dining"}
		_build_grid_obstacles_refresh()
		# camera like the bedroom mirror shot: swing round behind the player's chair, player + table in one frame
		cam_shot = _breakfast_frame(DINE_C + c[1], f)
		await wait(0.8)
		await walk_to(sit_spot(seat), SEATS[seat].yaw)
		caption("I am sitting at the table.")
		await sit_down(hero, seat, true); S.seat = seat
	action_peak.emit("breakfast")
	await Audio.wait_idle(12.0); await wait(0.8)
	caption("I am having breakfast."); eat_tw = _breakfast_loop(hero, SEATS[seat].yaw if seat != "" else 0.0, 0)
	await Audio.wait_idle(12.0); await wait(1.5)
	# a little chit-chat first (A1)
	var hs := humans(); var a0: Dictionary = hs[0]; var a1: Dictionary = hs[1 % hs.size()]; var a2: Dictionary = hs[2 % hs.size()]
	# house.26: a real conversation - nobody answers their own question; with one member the player answers
	var many := hs.size() > 1
	await _say_as(a0, "Pass the bread, please.", "Ekmeği uzatır mısın, lütfen?")
	if many: await _say_as(a1, "Here you are.", "Buyur.")
	else: await _say_me("Here you are.", "Buyur.")
	await _say_as(a2 if hs.size() > 2 else a0, "This tea is good.", "Bu çay güzel.")
	await _say_me("Yes, it is very good.", "Evet, çok güzel.")
	await _say_as(a0, "Did you sleep well?", "İyi uyudun mu?")
	await _say_me("Yes, I did. Thank you.", "Evet, uyudum. Teşekkürler.")
	await _say_as(a1 if many else a0, "The eggs are very good.", "Yumurtalar çok güzel.")
	if many: await _say_as(a0, "Thank you!", "Teşekkürler!")
	else: await _say_me("Yes, they are.", "Evet, öyleler.")
	await wait(0.8)
	# question -> present simple lesson on the phone
	await _say_as(a1 if hs.size() > 1 else a0, "How is your week looking?", "Haftan nasıl görünüyor?")
	caption("Let's learn the present simple."); await Audio.wait_idle(12.0); await wait(0.6)
	var ph = room_phone.phone
	ph.visible = true; ph.open(Rect2(), "home"); await wait(0.6)
	ph.start_set(BK, "lesson")
	await ph.lesson_steps_done
	ph.page = "between"; await ph.close(true)   # house.20: the lesson part is done (quiz follows)
	await wait(0.8)
	# family members tell the player about their week
	var wk: Array = BK.week; var wi := 0
	for bm in hs.slice(0, 3):
		for k in 2:
			var ln: Array = wk[wi % wk.size()]; wi += 1
			await _say_as(bm, ln[0], ln[1])
		await wait(0.5)
	caption("Now let's check."); await Audio.wait_idle(12.0)
	ph.visible = true; ph.open(Rect2(), "home"); await wait(0.6)
	ph.start_set(BK, "quiz")
	var res: Array = await ph.quiz_done
	await Audio.wait_idle(12.0)
	caption("Well done!"); await Audio.wait_idle(12.0)
	await ph.close(); ph.les = {}
	if eat_tw: eat_tw.kill()
	breakfast_done = true
	App.patch_save({"breakfast_done": true, "breakfast_day": App.day, "breakfast_score": [res[0], res[1]]})
	Life.satisfy(["hunger", "thirst"]); Life.snap("breakfast")   # house.25: needs + story polaroid
	caption("Breakfast is over.")
	await Audio.wait_idle(12.0)
	if S.seat != "":
		for bn in ["UpperArm.R", "LowerArm.R", "UpperArm.L", "LowerArm.L", "Neck"]: hero.bone_offsets.erase(bn)
		await stand_up()
	cam_shot = {}
	if wall_fade: wall_fade.force_fade(false)   # v32-polish
	_clear_table(true)
	mode = "play"; _advance(); _update_hand()
	await family_to_tv()
	breakfast_finished.emit(res[0], res[1])

# ------------------------------------------------------------ house.18: table cleanup + family to the TV
var table_clean := false
var _fam_at_tv_pending := false
func _clear_table(anim: bool) -> void:
	table_clean = true
	if N.has("food") and is_instance_valid(N.food):
		if anim:
			var tw := create_tween(); tw.tween_property(N.food, "scale", Vector3(1, 0.01, 1), 0.6); tw.tween_callback(func(): N.food.visible = false)
			Audio.sfx("clink", -6.0)
		else: N.food.visible = false
	if breakfast_root:
		for c in breakfast_root.get_children(): if c.has_meta("setting"): c.visible = false
	_living_save()

## one character walks along the A* path (same pathing as the player)
func walk_char(ch: DemoCharacter, target: Vector3, yaw: float) -> void:
	var a := _nearest_free(_cell(ch.position)); var b := _nearest_free(_cell(target))
	var path := astar.get_id_path(a, b)
	var pts: Array[Vector3] = []
	for i in range(1, path.size()):
		if i % 3 == 0 or i == path.size() - 1: pts.append(_cell_pos(path[i]))
	pts.append(Vector3(target.x, 0, target.z))
	ch.player.speed_scale = 1.0; ch.play("walk", 0.2, walk_rate(WALK * 0.8))
	for p in pts:
		var guard := 0.0
		while guard < 8.0:
			var d := p - ch.position; d.y = 0
			if d.length() < 0.04: break
			var dt := get_process_delta_time(); guard += dt
			ch.position += d.normalized() * minf(WALK * 0.8 * dt, d.length())
			ch.rotation.y = lerp_angle(ch.rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * dt))
			await get_tree().process_frame
	ch.play("idle", 0.25)
	var tw := create_tween(); tw.tween_property(ch, "rotation:y", ch.rotation.y + angle_difference(ch.rotation.y, yaw), 0.4); await tw.finished

const TV_SEATS := ["sofa_left", "sofa_right", "armchair", "sofa_middle"]
func _stand_npc(ch: DemoCharacter) -> void:
	var tw := create_tween(); tw.tween_property(ch, "position:y", 0.0, 0.8)
	ch.player.speed_scale = 1.0; ch.player.play("sit_to_stand", 0.2)
	await wait(maxf(0.5, ch.anim_length("sit_to_stand") - 0.05))
	ch.player.play("idle", 0.3); ch.position.y = 0.0; ch.set_meta("seat", "")
	var f := Vector3(sin(ch.rotation.y), 0, cos(ch.rotation.y)); ch.position += f * 0.35

## after breakfast: stand up, walk to the TV area (around the furniture), sit down, TV on; pets settle nearby
func family_to_tv() -> void:
	var hs := humans(); var i := 0
	for bm in hs:
		if bm.has("tw") and bm.tw: bm.tw.kill()
		for bn in ["UpperArm.R", "LowerArm.R", "UpperArm.L", "LowerArm.L", "Neck", "Head"]: bm.node.bone_offsets.erase(bn)
	for bm in hs:
		var ch: DemoCharacter = bm.node
		var seat: String = TV_SEATS[i] if i < TV_SEATS.size() else ""; i += 1
		_npc_to_tv(ch, seat, i * 1.4, bm)
	var spots := [Vector3(SOFA_X - 1.0, 0, 1.3), Vector3(SOFA_X - 1.3, 0, -1.1), Vector3(SOFA_X - 0.9, 0, 0.1)]; var k := 0
	for bm in breakfast_members:
		if String(bm.seat) != "" or bm.data.get("role", "") in ["fish", "bird"]: continue
		var tw := create_tween(); tw.tween_interval(2.5 + k); tw.tween_property(bm.node, "position", spots[k % spots.size()], 4.0).set_trans(Tween.TRANS_SINE); k += 1
	await wait(3.0 + hs.size() * 1.4 + 6.0)
	S.tv = "on"; _apply_states(true); Audio.sfx("click")
	_living_save()

func _npc_to_tv(ch: DemoCharacter, seat: String, delay: float, bm: Dictionary) -> void:
	await wait(delay)
	await _stand_npc(ch)
	if seat == "":
		await walk_char(ch, Vector3(SOFA_X - 1.2, 0, 0.6), -PI / 2); bm.seat = "tv_stand"; return
	await walk_char(ch, sit_spot(seat), SEATS[seat].yaw)
	await sit_down(ch, seat, true)
	if not family.has(ch): family.append(ch)
	bm.seat = seat; _fam_reg()

## re-entry after breakfast: the family is already at the TV (no walking needed)
func family_at_tv_now() -> void:
	var i := 0
	for bm in humans():
		if bm.has("tw") and bm.tw: bm.tw.kill()
		bm.node.bone_offsets.clear()
		var seat: String = TV_SEATS[i] if i < TV_SEATS.size() else ""; i += 1
		if seat == "": bm.node.position = Vector3(SOFA_X - 1.2, 0, 0.6); bm.node.rotation.y = -PI / 2; bm.node.play("idle", 0.0); bm.seat = "tv_stand"; continue
		sit_down(bm.node, seat, false); bm.seat = seat
		if not family.has(bm.node): family.append(bm.node)
	var spots := [Vector3(SOFA_X - 1.0, 0, 1.3), Vector3(SOFA_X - 1.3, 0, -1.1), Vector3(SOFA_X - 0.9, 0, 0.1)]; var k := 0
	for bm in breakfast_members:
		if String(bm.seat) == "" and not bm.data.get("role", "") in ["fish", "bird"]: bm.node.position = spots[k % spots.size()]; k += 1
	S.tv = "on"; _apply_states()

# ------------------------------------------------------------ house.18: family members are interactable (hug / ask / good morning)
func _fam_reg() -> void:
	for k in OBJ.keys(): if String(k).begins_with("fam_"): OBJ.erase(k)
	var i := 0
	for bm in breakfast_members:
		if String(bm.seat) == "" or not bm.node is DemoCharacter: i += 1; continue
		var ch: Node3D = bm.node; var p := to_local(ch.global_position); p.y = 0
		var f := Vector3(sin(ch.rotation.y), 0, cos(ch.rotation.y))
		var spot := p + f * 0.75
		if bm.seat.begins_with("dine"): spot = p - f * 0.0 + Vector3(f.z, 0, -f.x) * 0.7   # beside the chair
		var id := "fam_%d" % i
		OBJ[id] = {"name": String(bm.data.get("name", "")), "focus": p + Vector3(0, 1.1, 0), "spot": spot, "yaw": atan2(p.x - spot.x, p.z - spot.z), "member": i}
		i += 1

func _fam_verbs(id: String) -> Array:
	var bm: Dictionary = breakfast_members[int(OBJ[id].member)]
	var nm := String(bm.data.get("name", "")); var role := String(bm.data.get("role", ""))
	return [["Hug %s" % nm, "I am hugging my %s." % role, "hug"], ["Ask how %s is" % nm, "How are you?", "ask"], ["Say good morning", "Good morning!", "morning"]]

const FAM_REPLY := [["I am fine, thank you.", "İyiyim, teşekkür ederim."], ["I am very well, thanks.", "Çok iyiyim, teşekkürler."], ["I am good. And you?", "İyiyim. Ya sen?"]]
func _fam_verb(id: String, key: String) -> void:
	var bm: Dictionary = breakfast_members[int(OBJ[id].member)]
	var ch: DemoCharacter = bm.node
	await walk_to(OBJ[id].spot, OBJ[id].yaw)
	var role := String(bm.data.get("role", ""))
	match key:
		"hug":
			var l := "I am hugging my %s." % role; XTR[l] = "Ona sarılıyorum."
			caption(l)
			var ax := Vector3(cos(hero.rotation.y), 0, -sin(hero.rotation.y))
			var hug := func(a: float):
				for sd in ["L", "R"]:
					hero.bone_offsets["UpperArm." + sd] = [ax, -1.2 * a]; hero.bone_offsets["LowerArm." + sd] = [ax, -0.6 * a]
			var tw := create_tween(); tw.tween_method(hug, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
			_talk_nod(ch); action_peak.emit(id)
			await wait(1.6)
			tw = create_tween(); tw.tween_method(hug, 1.0, 0.0, 0.5); await tw.finished
			for sd in ["L", "R"]: hero.bone_offsets.erase("UpperArm." + sd); hero.bone_offsets.erase("LowerArm." + sd)
			await _say_as(bm, "I love you too.", "Ben de seni seviyorum.")
		"ask":
			caption("How are you?"); action_peak.emit(id); await Audio.wait_idle(12.0)
			var r: Array = FAM_REPLY[(int(OBJ[id].member) + randi() % 3) % FAM_REPLY.size()]
			await _say_as(bm, r[0], r[1])
		"morning":
			caption("Good morning!"); action_peak.emit(id); await Audio.wait_idle(12.0)
			await _say_as(bm, "Good morning to you too!", "Sana da günaydın!")

## house.17: living-room tidy states last for one in-game day (save.json "living": {cushions: day, picture: day})
func _living_load() -> void:
	if not FileAccess.file_exists(App.SAVE_PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH))
	if not d is Dictionary: return
	breakfast_done = bool(d.get("breakfast_done", false)) and App.day - int(d.get("breakfast_day", App.day)) < 1   # house.18: one breakfast per day
	var lv: Dictionary = d.get("living", {}) if d.get("living", {}) is Dictionary else {}
	if "--qa" in OS.get_cmdline_user_args(): return   # living-room QA starts from the messy room
	if lv.has("table") and App.day - int(lv.table) < 1: table_clean = true
	if lv.has("tv_family") and App.day - int(lv.tv_family) < 1: _fam_at_tv_pending = true
	if lv.has("cushions") and App.day - int(lv.cushions) < 1: S.cushions = "tidy"
	if lv.has("picture") and App.day - int(lv.picture) < 1: S.picture = "straight"

func _living_save() -> void:
	var lv := {}
	if S.cushions == "tidy": lv["cushions"] = App.day
	if S.picture == "straight": lv["picture"] = App.day
	if table_clean: lv["table"] = App.day
	if breakfast_done: lv["tv_family"] = App.day
	App.patch_save({"living": lv})

func _mat(c: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(c, alpha); m.roughness = 0.85
	if alpha < 1.0: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0: m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = emit
	return m

func box(size: Vector3, pos: Vector3, c: Color, parent: Node = self, emit := 0.0, alpha := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = _mat(c, emit, alpha); mi.position = pos; parent.add_child(mi); return mi

## soft cushion: a scaled sphere with a box core = rounded, puffy block
func cushion(size: Vector3, pos: Vector3, c: Color, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; sp.radial_segments = 20; sp.rings = 10
	mi.mesh = sp; mi.scale = size; mi.position = pos; mi.material_override = _mat(c); parent.add_child(mi)
	var core := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.86, 0.72, 0.86); core.mesh = bm
	core.material_override = mi.material_override; mi.add_child(core)
	return mi

func cyl(r: float, h: float, pos: Vector3, c: Color, parent: Node = self, emit := 0.0, seg := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = seg
	mi.mesh = cm; mi.material_override = _mat(c, emit); mi.position = pos; parent.add_child(mi); return mi

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

func block(n: Node3D, grow := 0.0) -> Rect2:
	var ab := _aabb(n)
	var xf := n.transform
	var p0 := xf * ab.position
	var r := Rect2(Vector2(p0.x, p0.z), Vector2.ZERO)
	for i in 8:
		var p := xf * ab.get_endpoint(i); r = r.expand(Vector2(p.x, p.z))
	r = r.grow(grow); obstacles.append(r); return r

const CENTRE := Vector3(1.5, 0, 0)
## v31: every small plant is waterable (same water verbs / watering can as the big plants)
var _spl_n := 0
func _spl(n: Node3D) -> Node3D:
	_spl_n += 1; var id := "splant%d" % _spl_n
	var p: Vector3 = to_local(n.global_position) if n.is_inside_tree() else n.position   # open world: room-local spot
	var d := Vector3(CENTRE.x - p.x, 0, CENTRE.z - p.z); d = d.normalized() if d.length() > 0.01 else Vector3(0, 0, 1)
	reg(id, "plant", p + Vector3(0, 0.12, 0), Vector3(p.x, 0, p.z) + d * 0.75, -d)
	if not S.has(id): S[id] = "dry"
	return n

func reg(id: String, nm: String, focus: Vector3, spot: Vector3, face: Vector3) -> void:
	OBJ[id] = {"name": nm, "focus": focus, "spot": spot, "yaw": atan2(face.x, face.z)}

func sheet(size: Vector2, pos: Vector3, c: Color, amp: float, seed: int, drop: float, parent: Node) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 24; var nz := 18
	var pts := []
	for iz in nz + 1:
		for ix in nx + 1:
			var u := float(ix) / nx; var v := float(iz) / nz
			var x := (u - 0.5) * size.x; var z := (v - 0.5) * size.y
			var y := amp * (sin(x * 9.0 + seed) * 0.6 + sin(z * 13.0 + seed * 2.0) * 0.4 + sin((x + z) * 6.0 + seed * 0.7) * 0.5)
			var ez := clampf((absf(z) - (size.y * 0.5 - 0.14)) / 0.14, 0.0, 1.0)
			var ex := clampf((x - (size.x * 0.5 - 0.16)) / 0.16, 0.0, 1.0)
			y -= drop * ez * ez + drop * 1.6 * ex * ex
			pts.append(Vector3(x, y, z))
	for iz in nz:
		for ix in nx:
			var a := iz * (nx + 1) + ix
			for k in [a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]: st.add_vertex(pts[k])
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
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_color = Color(1.0, 0.95, 0.85)
	add_child(sun); sun.look_at_from_position(to_global(Vector3(14, 9, 1.0)), to_global(Vector3(RCX, 0, 0))); sun.light_energy = 1.3
	sun.directional_shadow_max_distance = 40.0; sun.directional_shadow_fade_start = 1.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_blur = 2.5; sun.shadow_bias = 0.04; sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 40.0; sun.light_specular = 0.25   # house.24: stable lighting (no camera-dependent hot spots)
	_stable_lights.call_deferred()

# ============================================================ room
const WIN_X0 := -0.35
const WIN_X1 := 2.25
const WIN_Y0 := 0.55
const WIN_Y1 := 2.25
func _build_room() -> void:
	box(Vector3(11.7, 0.1, 6.0), Vector3(RCX, -0.05, 0), C_FLOOR)
	for i in range(1, 12): box(Vector3(11.7, 0.004, 0.012), Vector3(RCX, 0.002, -3.0 + i * 0.5), C_FLOOR.darkened(0.12))
	box(Vector3(40, 0.1, 30), Vector3(RCX, -0.16, 0), Color(0.30, 0.29, 0.28))
	# south (camera-side) wall: low cut stub so the room's front edge reads as a wall, gap for the front door
	for c in [Vector2(-3.6, DOOR_FRONT.x - 0.5), Vector2(DOOR_FRONT.y + 0.5, EX + 0.1)]:
		box(Vector3(c.y - c.x, 0.32, 0.1), Vector3((c.x + c.y) / 2, 0.16, 3.05), C_WALL)
		box(Vector3(c.y - c.x, 0.02, 0.12), Vector3((c.x + c.y) / 2, 0.33, 3.05), C_WHITE.darkened(0.08))
		box(Vector3(c.y - c.x, 0.08, 0.02), Vector3((c.x + c.y) / 2, 0.04, 2.99), C_WHITE)
	# north wall (shared with bedroom + bathroom) with the two door openings
	var bz := -3.05
	var cuts := [Vector2(-3.6, DOOR_BED.x), Vector2(DOOR_BED.y, DOOR_BATH.x), Vector2(DOOR_BATH.y, EX + 0.1)]
	for c in cuts: box(Vector3(c.y - c.x, WALL_H, 0.1), Vector3((c.x + c.y) / 2, WALL_H / 2, bz), C_WALL); box(Vector3(c.y - c.x - (0.0 if c.x < -3 else 0.0), 0.08, 0.02), Vector3((c.x + c.y) / 2, 0.04, -2.99), C_WHITE)
	for d in [DOOR_BED, DOOR_BATH]: box(Vector3(d.y - d.x, WALL_H - 2.12, 0.1), Vector3((d.x + d.y) / 2, (WALL_H + 2.12) / 2, bz), C_WALL)
	box(Vector3(2.3, WALL_H - 0.02, 0.01), Vector3(-1.5, WALL_H / 2, -2.995), C_SAGE)       # accent behind armchair + photos
	walls_l.append(box(Vector3(0.1, WALL_H, 6.0), Vector3(-3.55, WALL_H / 2, 0), C_WALL))
	box(Vector3(0.01, WALL_H - 0.02, 2.3), Vector3(-3.495, WALL_H / 2, 0.0), C_SAGE)          # accent behind the TV
	# east (outer) wall with the big window opening z -1.3..1.3
	walls_r.append(box(Vector3(0.1, WALL_H, 1.85), Vector3(EX + 0.05, WALL_H / 2, -2.225), C_WALL))
	walls_r.append(box(Vector3(0.1, WALL_H, 1.85), Vector3(EX + 0.05, WALL_H / 2, 2.225), C_WALL))
	walls_r.append(box(Vector3(0.1, WIN_Y0, 2.6), Vector3(EX + 0.05, WIN_Y0 / 2, 0), C_WALL))
	walls_r.append(box(Vector3(0.1, WALL_H - WIN_Y1, 2.6), Vector3(EX + 0.05, (WALL_H + WIN_Y1) / 2, 0), C_WALL))
	N.closed = []
	for bx in [[Vector3(12.1, 0.1, 6.4), Vector3(RCX, WALL_H + 0.05, 0), Color(0.97, 0.97, 0.96)], [Vector3(12.1, WALL_H, 0.1), Vector3(RCX, WALL_H / 2, 3.1), C_WALL]]:
		var sbx := box(bx[0], bx[1], bx[2]); sbx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY; N.closed.append(sbx)
	_south_wall(RCX - 6.0, RCX + 6.0, DOOR_FRONT.x, DOOR_FRONT.y, 2.97, C_WALL)   # v30.5
	_wall_fade_setup()
	box(Vector3(0.02, 0.08, 6.0), Vector3(-3.49, 0.04, 0), C_WHITE)
	box(Vector3(0.02, 0.08, 6.0), Vector3(EX - 0.01, 0.04, 0), C_WHITE)
	_build_window()
	_build_tv()
	_build_sofa()
	_build_armchair()
	_build_coffee_table()
	_build_shelf()
	_build_lights()
	_build_plants()
	_build_photos()
	_build_door()
	_build_dining()
	_build_front_door()
	_build_details()
	# rug: cream with a blue border, under the coffee table
	box(Vector3(2.9, 0.012, 2.3), Vector3(0.75, 0.006, 0.0), C_BLUE.lightened(0.25))
	box(Vector3(2.7, 0.014, 2.1), Vector3(0.75, 0.008, 0.0), Color(0.95, 0.93, 0.88))
	for z in [-0.85, 0.85]: box(Vector3(2.3, 0.0155, 0.03), Vector3(0.75, 0.009, z), C_BLUE.lightened(0.25))
	# rug pattern: inner border + small diamonds
	box(Vector3(2.4, 0.0152, 0.02), Vector3(0.75, 0.0095, -0.7), C_CORAL.lightened(0.3)); box(Vector3(2.4, 0.0152, 0.02), Vector3(0.75, 0.0095, 0.7), C_CORAL.lightened(0.3))
	for k in 5:
		var dm := box(Vector3(0.12, 0.0154, 0.12), Vector3(-0.25 + k * 0.5, 0.0096, 0.0 if k % 2 == 0 else 0.0), C_BLUE.lightened(0.45)); dm.rotation.y = PI / 4
	_build_markers()

## window: the parts are built in back-wall coordinates (x along the wall, -Z = outside) inside a pivot that turns
## them onto the east wall (local (0.95, y, -3.0) -> world (EX, y, 0)).
var WIN: Node3D
func _build_window() -> void:
	WIN = Node3D.new(); WIN.name = "EastWindow"; WIN.rotation.y = -PI / 2; WIN.position = Vector3(EX - 3.0, 0, -0.95); add_child(WIN)
	var sky := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(3.6, 2.1); sky.mesh = qm
	var sm := StandardMaterial3D.new(); sm.albedo_texture = load("res://ui/sky.png"); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.material_override = sm; sky.position = Vector3(0.95, 1.3, -3.3); sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; WIN.add_child(sky)
	N.sky = sm
	var fc := Color(0.98, 0.98, 0.98); var cx := (WIN_X0 + WIN_X1) / 2; var w := WIN_X1 - WIN_X0; var h := WIN_Y1 - WIN_Y0; var cy := (WIN_Y0 + WIN_Y1) / 2
	box(Vector3(w + 0.14, 0.06, 0.24), Vector3(cx, WIN_Y0, -2.93), fc, WIN)
	box(Vector3(w, 0.06, 0.09), Vector3(cx, WIN_Y1, -3.0), fc, WIN)
	box(Vector3(0.06, h, 0.09), Vector3(WIN_X0, cy, -3.0), fc, WIN); box(Vector3(0.06, h, 0.09), Vector3(WIN_X1, cy, -3.0), fc, WIN)
	box(Vector3(0.05, h, 0.07), Vector3(cx - 0.43, cy, -3.02), fc, WIN); box(Vector3(0.05, h, 0.07), Vector3(cx + 0.43, cy, -3.02), fc, WIN)
	box(Vector3(w, 0.04, 0.07), Vector3(cx, WIN_Y0 + 1.25, -3.02), fc, WIN)
	var glass := Color(0.75, 0.88, 0.97)
	for gx in [WIN_X0 + 0.43, cx]:
		box(Vector3(0.82, h - 0.04, 0.02), Vector3(gx, cy, -3.03), glass, WIN, 0.0, 0.3).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	N.sash = Node3D.new(); N.sash.position = Vector3(WIN_X1 - 0.03, WIN_Y0 + 0.03, -2.99); WIN.add_child(N.sash)
	var sw := 0.80; var sh := 1.20
	box(Vector3(sw, sh, 0.02), Vector3(-sw / 2, sh / 2, 0), glass, N.sash, 0.0, 0.3).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in [[Vector3(sw, 0.04, 0.045), Vector3(-sw / 2, 0.02, 0)], [Vector3(sw, 0.04, 0.045), Vector3(-sw / 2, sh - 0.02, 0)], [Vector3(0.04, sh, 0.045), Vector3(-sw + 0.02, sh / 2, 0)], [Vector3(0.04, sh, 0.045), Vector3(-0.02, sh / 2, 0)]]:
		box(b[0], b[1], fc, N.sash)
	box(Vector3(0.025, 0.12, 0.03), Vector3(-sw + 0.06, 0.62, 0.03), Color(0.3, 0.3, 0.32), N.sash)
	box(Vector3(w + 0.9, 0.03, 0.03), Vector3(cx, 2.42, -2.88), Color(0.25, 0.25, 0.28), WIN)
	N.curtL = _curtain(); N.curtR = _curtain()
	reg("window", "window", Vector3(EX - 0.05, 1.5, 0.0), Vector3(EX - 0.75, 0, -0.25), Vector3(1, 0, 0))

## pleated curtain: 6 slightly angled panels inside a pivot (scaled on x to open/close)
func _curtain() -> Node3D:
	var n := Node3D.new(); WIN.add_child(n)
	for i in 6:
		var p := box(Vector3(0.18, 2.3, 0.03), Vector3(-0.5 + 0.0833 + i * 0.1667, -1.15, (0.012 if i % 2 == 0 else -0.012)), C_CREAM, n)
		p.rotation.y = 0.2 if i % 2 == 0 else -0.2
	return n

func _set_curtains(open: bool, anim := false) -> void:
	var w := 0.42 if open else 1.42
	_to(N.curtL, "scale:x", w, anim, 1.2); _to(N.curtR, "scale:x", w, anim, 1.2)
	_to(N.curtL, "position", Vector3(WIN_X0 - 0.42 + w * 0.5, 2.40, -2.86), anim, 1.2)
	_to(N.curtR, "position", Vector3(WIN_X1 + 0.42 - w * 0.5, 2.40, -2.86), anim, 1.2)

# ---------- TV unit (left wall, faces +X) + TV
const TV_C := Vector3(-3.37, 1.12, 0.0)
const UX := -3.24
func _build_tv() -> void:
	box(Vector3(0.46, 0.44, 1.9), Vector3(UX, 0.28, 0), C_CAB)
	box(Vector3(0.48, 0.035, 1.94), Vector3(UX, 0.515, 0), C_WOOD)
	for z in [-0.85, 0.85]:
		for x in [UX - 0.18, UX + 0.18]: box(Vector3(0.035, 0.06, 0.035), Vector3(x, 0.03, z), C_WOOD.darkened(0.2))
	for z in [-0.635, 0.635]:
		box(Vector3(0.012, 0.40, 0.61), Vector3(UX + 0.236, 0.28, z), C_CAB.darkened(0.03))
		box(Vector3(0.015, 0.012, 0.2), Vector3(UX + 0.246, 0.44, z), Color(0.3, 0.3, 0.32))
	box(Vector3(0.40, 0.36, 0.6), Vector3(UX + 0.02, 0.28, 0), Color(0.55, 0.45, 0.38))
	N.drawer = Node3D.new(); N.drawer.position = Vector3(UX + 0.236, 0.28, 0); add_child(N.drawer)
	box(Vector3(0.012, 0.40, 0.62), Vector3(0, 0, 0), C_CAB.darkened(0.03), N.drawer)
	box(Vector3(0.015, 0.012, 0.22), Vector3(0.01, 0.16, 0), Color(0.3, 0.3, 0.32), N.drawer)
	box(Vector3(0.36, 0.02, 0.56), Vector3(-0.19, -0.16, 0), C_CAB.darkened(0.08), N.drawer)
	for i in 3: box(Vector3(0.14, 0.03, 0.12), Vector3(-0.1 - (i % 2) * 0.12, -0.13 + i * 0.02, -0.15 + i * 0.15), [C_BLUE, C_CORAL, C_CREAM][i], N.drawer)
	obstacles.append(Rect2(-3.5, -0.98, 0.52, 1.96))
	var tvp := Node3D.new(); tvp.position = TV_C; tvp.rotation.y = PI / 2; add_child(tvp); N.tv = tvp
	box(Vector3(1.36, 0.80, 0.045), Vector3.ZERO, Color(0.07, 0.07, 0.08), tvp)
	box(Vector3(0.30, 0.02, 0.18), Vector3(0, -0.585, 0.0), Color(0.15, 0.15, 0.16), tvp)
	box(Vector3(0.06, 0.18, 0.03), Vector3(0, -0.49, -0.01), Color(0.15, 0.15, 0.16), tvp)
	var scr := MeshInstance3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(1.30, 0.735); scr.mesh = sq
	scr.position = Vector3(0, 0, 0.024); tvp.add_child(scr); scr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; N.screen = scr
	N.tv_led = box(Vector3(0.012, 0.006, 0.004), Vector3(0.6, -0.395, 0.024), Color(0.9, 0.2, 0.2), tvp, 2.0)
	N.chan_lbl = Label3D.new(); N.chan_lbl.font = load("res://fonts/Nunito.ttf"); N.chan_lbl.font_size = 48; N.chan_lbl.pixel_size = 0.0025
	N.chan_lbl.position = Vector3(-0.5, 0.30, 0.03); N.chan_lbl.outline_size = 8; tvp.add_child(N.chan_lbl)
	N.tv_light = OmniLight3D.new(); N.tv_light.position = Vector3(-2.9, 1.1, 0); N.tv_light.omni_range = 3.2; N.tv_light.light_energy = 0.6
	add_child(N.tv_light)
	N.channels = [_tv_image(0), _tv_image(1), _tv_image(2), _tv_image(3)]
	prop("speakerSmall", Vector3(UX, 0.53, -0.84), 90, 0.26)
	prop("speakerSmall", Vector3(UX, 0.53, 0.84), 90, 0.26)
	_spl(prop("plantSmall2", Vector3(UX - 0.02, 0.53, 0.58), 0, 0.26))
	prop("books", Vector3(UX, 0.53, -0.58), 90, 0.0, 0.24)
	box(Vector3(0.2, 0.03, 1.1), Vector3(-3.39, 1.86, 0), C_WOOD)
	_spl(prop("plantSmall3", Vector3(-3.39, 1.875, -0.35), 0, 0.22))
	prop("books", Vector3(-3.39, 1.875, 0.3), 90, 0.0, 0.22)
	reg("tv", "TV", Vector3(-3.3, 0.9, 0), Vector3(-2.45, 0, 0.0), Vector3(-1, 0, 0))

## simple flat TV pictures (A1: news, cartoon, nature, sport)
const CH_NAMES := ["1 NEWS", "2 KIDS", "3 NATURE", "4 SPORT"]
const CH_LINES := ["This is the news.", "This is a cartoon.", "This is a nature show.", "This is sport."]
func _tv_image(i: int) -> ImageTexture:
	var W := 192; var H := 108
	var im := Image.create(W, H, false, Image.FORMAT_RGB8)
	match i:
		0:
			im.fill(Color(0.16, 0.32, 0.62))
			im.fill_rect(Rect2i(0, 0, W, 70), Color(0.22, 0.42, 0.75))
			im.fill_rect(Rect2i(42, 54, 44, 30), Color(0.15, 0.18, 0.25))
			_disc(im, Vector2(64, 36), 15, Color(0.2, 0.13, 0.08)); _disc(im, Vector2(64, 41), 13, Color(0.87, 0.67, 0.5))
			im.fill_rect(Rect2i(110, 22, 64, 40), Color(0.92, 0.95, 1.0)); im.fill_rect(Rect2i(116, 30, 30, 22), Color(0.95, 0.75, 0.3))
			im.fill_rect(Rect2i(0, 80, W, 18), Color(0.95, 0.95, 0.97)); im.fill_rect(Rect2i(0, 80, 40, 18), Color(0.85, 0.2, 0.2))
			for k in 6: im.fill_rect(Rect2i(48 + k * 22, 87, 16, 4), Color(0.4, 0.42, 0.5))
		1:
			im.fill(Color(1.0, 0.85, 0.35))
			_disc(im, Vector2(50, 54), 30, Color(0.95, 0.45, 0.4)); _disc(im, Vector2(40, 46), 6, Color(1, 1, 1)); _disc(im, Vector2(60, 46), 6, Color(1, 1, 1))
			_disc(im, Vector2(41, 47), 3, Color(0.1, 0.1, 0.1)); _disc(im, Vector2(61, 47), 3, Color(0.1, 0.1, 0.1))
			im.fill_rect(Rect2i(40, 64, 20, 4), Color(0.4, 0.1, 0.1))
			_disc(im, Vector2(140, 58), 26, Color(0.35, 0.65, 0.95)); _disc(im, Vector2(132, 52), 5, Color(1, 1, 1)); _disc(im, Vector2(148, 52), 5, Color(1, 1, 1))
			_disc(im, Vector2(132, 53), 2, Color(0.1, 0.1, 0.1)); _disc(im, Vector2(148, 53), 2, Color(0.1, 0.1, 0.1))
			im.fill_rect(Rect2i(0, 92, W, 16), Color(0.45, 0.78, 0.4))
		2:
			for y in H: im.fill_rect(Rect2i(0, y, W, 1), Color(0.55, 0.78, 0.98).lerp(Color(0.85, 0.93, 1.0), minf(1.0, float(y) / 60.0)))
			_disc(im, Vector2(150, 26), 14, Color(1.0, 0.92, 0.55))
			for x in W:
				var h1 := int(62 + 10 * sin(x * 0.05)); var h2 := int(78 + 6 * sin(x * 0.09 + 1.0))
				im.fill_rect(Rect2i(x, h1, 1, H - h1), Color(0.45, 0.70, 0.45)); im.fill_rect(Rect2i(x, h2, 1, H - h2), Color(0.30, 0.56, 0.36))
			for k in 3:
				im.fill_rect(Rect2i(29 + k * 18, 80 - k * 3, 3, 10), Color(0.45, 0.32, 0.2)); _disc(im, Vector2(30 + k * 18, 74 - k * 3), 8, Color(0.2, 0.45, 0.28))
		3:
			im.fill(Color(0.30, 0.62, 0.32))
			for k in 6: im.fill_rect(Rect2i(k * 32, 0, 16, H), Color(0.33, 0.66, 0.35))
			im.fill_rect(Rect2i(0, 10, W, 2), Color(1, 1, 1)); im.fill_rect(Rect2i(0, 96, W, 2), Color(1, 1, 1)); im.fill_rect(Rect2i(95, 10, 2, 88), Color(1, 1, 1))
			for a in 64:
				var p := Vector2(96, 54) + Vector2(cos(a * TAU / 64), sin(a * TAU / 64)) * 18
				im.fill_rect(Rect2i(int(p.x), int(p.y), 2, 2), Color(1, 1, 1))
			_disc(im, Vector2(120, 60), 6, Color(1, 1, 1)); _disc(im, Vector2(120, 60), 2, Color(0.1, 0.1, 0.1))
			_disc(im, Vector2(60, 40), 5, Color(0.87, 0.67, 0.5)); im.fill_rect(Rect2i(55, 45, 10, 14), Color(0.9, 0.25, 0.25))
			_disc(im, Vector2(140, 70), 5, Color(0.68, 0.47, 0.32)); im.fill_rect(Rect2i(135, 75, 10, 14), Color(0.2, 0.35, 0.8))
	return ImageTexture.create_from_image(im)

func _disc(im: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height() and Vector2(x, y).distance_to(c) <= r: im.set_pixel(x, y, col)

# ---------- sofa (right side, faces -X): modern 3-seater in blue fabric, wood legs
const SX := 2.9
func _build_sofa() -> void:
	var L := 2.2
	var fab := C_BLUE
	N.sofa = Node3D.new(); add_child(N.sofa)
	box(Vector3(0.9, 0.22, L), Vector3(SX, 0.2, 0), fab.darkened(0.08), N.sofa)
	for z in [-L / 2 + 0.08, L / 2 - 0.08]:
		for x in [SX - 0.38, SX + 0.38]: box(Vector3(0.04, 0.09, 0.04), Vector3(x, 0.045, z), C_WOOD.darkened(0.15), N.sofa)
	for z in [-L / 2 + 0.1, L / 2 - 0.1]:
		box(Vector3(0.9, 0.3, 0.2), Vector3(SX, 0.42, z), fab, N.sofa)
		cushion(Vector3(0.9, 0.1, 0.2), Vector3(SX, 0.58, z), fab, N.sofa)
	box(Vector3(0.2, 0.46, L - 0.4), Vector3(SX + 0.35, 0.54, 0), fab.darkened(0.04), N.sofa)
	for i in 3:
		var z := -0.6 + i * 0.6
		cushion(Vector3(0.68, 0.15, 0.6), Vector3(SX - 0.07, SEAT_TOP - 0.07, z), fab.lightened(0.04), N.sofa)
		var bc := cushion(Vector3(0.2, 0.46, 0.58), Vector3(SX + 0.22, 0.68, z), fab.lightened(0.06), N.sofa); bc.rotation.z = -0.18
	obstacles.append(Rect2(SX - 0.45, -L / 2, 1.1, L))
	N.cush = []
	for d in [C_CORAL, C_CREAM, C_CORAL.lightened(0.25)]:
		N.cush.append(cushion(Vector3(0.13, 0.34, 0.34), Vector3.ZERO, d, self))
	N.blanket_folded = Node3D.new(); add_child(N.blanket_folded)
	for i in 3: box(Vector3(0.6, 0.035, 0.17), Vector3(SX + 0.02, 0.645 + i * 0.035, 1.0), [Color(0.95, 0.88, 0.7), Color(0.92, 0.84, 0.65), Color(0.95, 0.88, 0.7)][i], N.blanket_folded)
	for i in 3: box(Vector3(0.6, 0.002, 0.012), Vector3(SX + 0.02, 0.716, 0.94 + i * 0.05), C_CORAL, N.blanket_folded)
	N.blanket_open = Node3D.new(); add_child(N.blanket_open)
	sheet(Vector2(0.56, 0.58), Vector3.ZERO, Color(0.95, 0.88, 0.7), 0.01, 4, 0.13, N.blanket_open)
	reg("sofa", "sofa", Vector3(SX, 0.6, 0), Vector3(1.95, 0, 0.0), Vector3(-1, 0, 0))

func _build_armchair() -> void:
	var a := Node3D.new(); a.position = ARM_C; a.rotation.y = SEATS.armchair.yaw; add_child(a); N.armchair = a
	var fab := C_SAGE.darkened(0.12)
	box(Vector3(0.82, 0.2, 0.78), Vector3(0, 0.2, 0), fab.darkened(0.08), a)
	for x in [-0.34, 0.34]:
		for z in [-0.3, 0.3]: box(Vector3(0.04, 0.1, 0.04), Vector3(x, 0.05, z), C_WOOD.darkened(0.15), a)
	for x in [-0.36, 0.36]:
		box(Vector3(0.12, 0.3, 0.78), Vector3(x, 0.42, 0), fab, a); cushion(Vector3(0.12, 0.08, 0.78), Vector3(x, 0.58, 0), fab, a)
	cushion(Vector3(0.6, 0.14, 0.62), Vector3(0, SEAT_TOP - 0.065, 0.06), fab.lightened(0.06), a)
	var bk := cushion(Vector3(0.62, 0.5, 0.18), Vector3(0, 0.7, -0.3), fab.lightened(0.06), a); bk.rotation.x = -0.15
	cushion(Vector3(0.3, 0.26, 0.11), Vector3(0.0, 0.66, -0.2), C_CREAM, a).rotation.x = -0.2
	obstacles.append(Rect2(ARM_C.x - 0.5, ARM_C.z - 0.48, 1.0, 0.85))
	var f := Vector3(sin(a.rotation.y), 0, cos(a.rotation.y))
	reg("armchair", "armchair", ARM_C + Vector3(0, 0.6, 0), SEATS.armchair.hips + f * 0.46, -f)

func _build_coffee_table() -> void:
	var c := Vector3(0.85, 0, 0.0)
	box(Vector3(0.7, 0.04, 1.2), c + Vector3(0, 0.42, 0), C_WOOD)
	box(Vector3(0.62, 0.02, 1.1), c + Vector3(0, 0.14, 0), C_WOOD.darkened(0.06))
	for x in [-0.3, 0.3]:
		for z in [-0.55, 0.55]: box(Vector3(0.04, 0.42, 0.04), c + Vector3(x, 0.21, z), C_WOOD.darkened(0.12))
	obstacles.append(Rect2(c.x - 0.36, c.z - 0.61, 0.72, 1.22))
	box(Vector3(0.24, 0.012, 0.32), c + Vector3(-0.1, 0.156, 0.25), Color(0.95, 0.95, 0.97)).rotation.y = 0.2
	box(Vector3(0.24, 0.012, 0.32), c + Vector3(-0.08, 0.168, 0.22), C_CORAL).rotation.y = -0.1
	box(Vector3(0.22, 0.01, 0.3), c + Vector3(0.12, 0.445, -0.32), C_BLUE.lightened(0.3)).rotation.y = 0.3
	cyl(0.05, 0.18, c + Vector3(0.05, 0.53, 0.32), C_WHITE)
	for k in 5:
		var st := cyl(0.004, 0.16, c + Vector3(0.05 + (k - 2) * 0.012, 0.66, 0.32), Color(0.35, 0.55, 0.3)); st.rotation.z = (k - 2) * 0.15
		var fl := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.025; sp.height = 0.05; fl.mesh = sp
		fl.material_override = _mat([C_CORAL, C_CREAM, Color(0.98, 0.8, 0.35)][k % 3]); fl.position = c + Vector3(0.05 + (k - 2) * 0.03, 0.74 + (k % 2) * 0.02, 0.32); add_child(fl)
	var bowl := MeshInstance3D.new(); var bs := SphereMesh.new(); bs.radius = 0.11; bs.height = 0.11; bs.is_hemisphere = true; bowl.mesh = bs
	bowl.material_override = _mat(Color(0.97, 0.97, 0.97)); bowl.rotation.x = PI; bowl.position = c + Vector3(-0.12, 0.55, -0.05); add_child(bowl)
	for k in 4: _ball(0.038, c + Vector3(-0.12 + [0.03, -0.04, 0.0, 0.05][k], 0.49 + (0.03 if k == 2 else 0.0), -0.05 + [0.03, 0.02, -0.04, -0.03][k]), [Color(0.9, 0.3, 0.25), Color(0.98, 0.65, 0.2), Color(0.95, 0.85, 0.3), Color(0.5, 0.75, 0.3)][k])
	N.mug = (load("res://props/mug.tscn") as PackedScene).instantiate(); N.mug.position = c + Vector3(-0.18, 0.49, 0.42); add_child(N.mug)
	N.remote = (load("res://props/remote.tscn") as PackedScene).instantiate(); N.remote.position = c + Vector3(0.2, 0.449, 0.05); N.remote.rotation.y = 0.3; add_child(N.remote)
	reg("coffee", "coffee table", c + Vector3(0, 0.5, 0), c + Vector3(-0.78, 0, 0.0), Vector3(1, 0, 0))

func _ball(r: float, p: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = r; sp.height = r * 2; mi.mesh = sp; mi.material_override = _mat(col); mi.position = p; add_child(mi); return mi

func _build_shelf() -> void:
	N.shelf = prop("bookcaseOpen", Vector3(-2.95, 0, -2.75), 0, 1.85)
	block(N.shelf)
	for i in 3: prop("books", Vector3(-3.05 + (i % 2) * 0.12, (0.13 + i * 0.24) * 1.85 / 0.88, -2.75), 0, 0.0, 0.34)   # v32-polish: seated on the boards (were 0.17 m above)
	_spl(prop("plantSmall1", Vector3(-2.8, 1.36, -2.75), 0, 0.22))
	_spl(prop("plantSmall3", Vector3(-2.95, 1.86, -2.75), 0, 0.28))
	N.shelf_book = box(Vector3(0.05, 0.24, 0.17), Vector3(-2.72, 0.13 * 1.85 / 0.88 + 0.122, -2.72), Color(0.85, 0.3, 0.3))   # v32-polish: on the bottom board
	box(Vector3(0.05, 0.22, 0.16), Vector3(-2.66, 0.55, -2.72), C_BLUE)
	reg("books", "bookcase", Vector3(-2.95, 1.2, -2.75), Vector3(-2.85, 0, -2.0), Vector3(0, 0, -1))

func _build_lights() -> void:
	N.pendant = prop("lampSquareCeiling", Vector3(0.85, 2.18, 0.0), 0, 0.36)
	box(Vector3(0.01, 0.4, 0.01), Vector3(0.85, 2.45, 0.0), Color(0.2, 0.2, 0.2))
	N.ceil_light = OmniLight3D.new(); N.ceil_light.position = Vector3(0.85, 2.05, 0.0); N.ceil_light.omni_range = 6.5
	N.ceil_light.light_energy = 0.8; N.ceil_light.light_color = Color(1, 0.96, 0.9); add_child(N.ceil_light)
	N.ceil_glow = box(Vector3(0.16, 0.04, 0.16), Vector3(0.85, 2.19, 0.0), Color(1, 0.95, 0.85), self, 3.0)
	var fx := Vector3(-2.3, 0, -2.6)
	cyl(0.16, 0.025, fx + Vector3(0, 0.012, 0), C_DARK)
	cyl(0.012, 1.45, fx + Vector3(0, 0.74, 0), Color(0.75, 0.62, 0.38))
	var shade := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.22; cm.height = 0.3; cm.radial_segments = 32
	shade.mesh = cm; shade.position = fx + Vector3(0, 1.55, 0); add_child(shade); N.shade = shade
	N.flamp_light = OmniLight3D.new(); N.flamp_light.position = fx + Vector3(0.25, 1.35, 0.3); N.flamp_light.light_color = Color(1, 0.8, 0.55)
	N.flamp_light.omni_range = 3.2; N.flamp_light.light_energy = 1.8; add_child(N.flamp_light)
	N.flamp_glow = cyl(0.15, 0.02, fx + Vector3(0, 1.41, 0), Color(1, 0.85, 0.6), self, 3.0)
	obstacles.append(Rect2(fx.x - 0.18, fx.z - 0.18, 0.36, 0.36))
	reg("floorlamp", "floor lamp", fx + Vector3(0, 1.3, 0), Vector3(-2.35, 0, -1.85), Vector3(0, 0, -1))
	box(Vector3(0.08, 0.12, 0.02), Vector3(1.1, 1.2, -2.99), C_WHITE)
	N.switch_nub = box(Vector3(0.03, 0.04, 0.02), Vector3(1.1, 1.22, -2.975), Color(0.6, 0.62, 0.66))
	reg("switch", "light switch", Vector3(1.1, 1.2, -2.95), Vector3(1.0, 0, -2.3), Vector3(0, 0, -1))
	var st := prop("sideTable", Vector3(3.08, 0, -1.55), -90, 0.5)
	block(st)
	_spl(prop("plantSmall1", Vector3(3.05, 0.5, -1.42), 0, 0.24))
	var fr := box(Vector3(0.14, 0.18, 0.02), Vector3(3.15, 0.59, -1.68), C_DARK); fr.rotation.y = -1.2

func _build_plants() -> void:
	N.plant = prop("pottedPlant", Vector3(3.05, 0, -2.6), 0, 1.25)
	block(N.plant)
	reg("plant", "big plant", Vector3(3.05, 0.8, -2.6), Vector3(2.55, 0, -2.05), Vector3(1, 0, -1))
	N.plant2 = prop("pottedPlant", Vector3(-3.1, 0, 2.55), 40, 0.95)
	block(N.plant2)
	reg("plant2", "plant", Vector3(-3.1, 0.6, 2.55), Vector3(-2.45, 0, 2.2), Vector3(-1, 0, 0.5))

## family photo wall above the armchair: generated portraits in thin frames
func _build_photos() -> void:
	var frames := [[Vector3(-1.95, 1.75, -2.97), Vector2(0.42, 0.52), 0], [Vector3(-1.4, 1.9, -2.97), Vector2(0.5, 0.36), 1],
		[Vector3(-1.4, 1.5, -2.97), Vector2(0.5, 0.32), 2], [Vector3(-0.92, 1.72, -2.97), Vector2(0.3, 0.38), 3], [Vector3(-1.95, 1.33, -2.97), Vector2(0.3, 0.24), 4]]
	N.photos = []
	for f in frames:
		var p := Node3D.new(); p.position = f[0]; add_child(p); N.photos.append(p)
		var sz: Vector2 = f[1]
		box(Vector3(sz.x + 0.04, sz.y + 0.04, 0.02), Vector3.ZERO, [C_DARK, C_WHITE, C_WOOD, C_DARK, C_WHITE][f[2]], p)
		box(Vector3(sz.x - 0.02, sz.y - 0.02, 0.004), Vector3(0, 0, 0.011), C_WHITE, p)
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = sz - Vector2(0.09, 0.09); q.mesh = qm
		var m := StandardMaterial3D.new(); m.albedo_texture = _portrait(f[2]); m.roughness = 0.6; q.material_override = m
		q.position = Vector3(0, 0, 0.0135); p.add_child(q)
	reg("photos", "family photos", Vector3(-1.45, 1.7, -2.95), Vector3(-0.8, 0, -1.9), Vector3(-0.45, 0, -1))

const SKINS := [Color(0.98, 0.84, 0.72), Color(0.87, 0.67, 0.50), Color(0.68, 0.47, 0.32), Color(0.42, 0.28, 0.19)]
func _portrait(i: int) -> ImageTexture:
	var W := 96; var H := 96
	var im := Image.create(W, H, false, Image.FORMAT_RGB8)
	var bgs := [Color(0.80, 0.88, 0.95), Color(0.98, 0.90, 0.75), Color(0.82, 0.92, 0.84), Color(0.95, 0.82, 0.80), Color(0.88, 0.85, 0.95)]
	im.fill(bgs[i])
	var people: Array = [[[48, 1.0, 0, C_BLUE, 0]], [[22, 1.0, 1, C_CORAL, 1], [48, 0.75, 0, C_BLUE.lightened(0.2), 2], [74, 1.0, 1, Color(0.3, 0.35, 0.45), 0]],
		[[30, 1.0, 2, Color(0.35, 0.6, 0.45), 0], [62, 1.0, 1, C_CORAL, 1]], [[48, 0.8, 0, Color(0.98, 0.55, 0.25), 1]], [[34, 1.0, 3, C_BLUE, 0], [62, 1.0, 3, C_CREAM.darkened(0.2), 1]]][i]
	if i == 2:
		im.fill_rect(Rect2i(0, 60, W, 36), Color(0.95, 0.88, 0.66)); im.fill_rect(Rect2i(0, 46, W, 14), Color(0.45, 0.7, 0.9))
	for p in people:
		var x: int = p[0]; var s: float = p[1]; var sk: Color = SKINS[p[2]]; var top: Color = p[3]
		var hy := int(H - 58 * s)
		im.fill_rect(Rect2i(int(x - 15 * s), int(hy + 14 * s), int(30 * s), H), top)
		_disc(im, Vector2(x, hy), 12 * s, sk)
		var hair: Color = [Color(0.25, 0.16, 0.1), Color(0.55, 0.38, 0.2), Color(0.1, 0.08, 0.06)][int(p[4])]
		for yy in range(int(hy - 13 * s), int(hy - 3 * s)):
			for xx in range(int(x - 13 * s), int(x + 13 * s) + 1):
				if Vector2(xx, yy).distance_to(Vector2(x, hy)) <= 12.5 * s and xx >= 0 and xx < W and yy >= 0: im.set_pixel(xx, yy, hair)
		im.set_pixel(int(x - 4 * s), hy, Color(0.1, 0.1, 0.1)); im.set_pixel(int(x + 4 * s), hy, Color(0.1, 0.1, 0.1))
	return ImageTexture.create_from_image(im)

## two hinged doors in the north wall (bedroom + bathroom); they swing smoothly into the living room
func _build_door() -> void:
	for d in [["door_bed", DOOR_BED, "bedroom door"], ["door_bath", DOOR_BATH, "bathroom door"]]:
		var sp: Vector2 = d[1]
		box(Vector3(0.05, 2.12, 0.12), Vector3(sp.x - 0.025, 1.06, -3.0), C_WHITE); box(Vector3(0.05, 2.12, 0.12), Vector3(sp.y + 0.025, 1.06, -3.0), C_WHITE)
		box(Vector3(sp.y - sp.x + 0.1, 0.05, 0.12), Vector3((sp.x + sp.y) / 2, 2.145, -3.0), C_WHITE)
		box(Vector3(sp.y - sp.x, 0.1, 0.25), Vector3((sp.x + sp.y) / 2, -0.05, -3.1), C_FLOOR.darkened(0.08))     # threshold / next room floor
		var mid := (sp.x + sp.y) / 2
		if north_door_panels:
			var dn := Node3D.new(); dn.name = d[0]; dn.position = Vector3(sp.x + 0.01, 0, -3.03); add_child(dn); N[d[0]] = dn
			var wdt := sp.y - sp.x - 0.02
			box(Vector3(wdt, 2.08, 0.045), Vector3(wdt / 2, 1.04, 0), C_WHITE.darkened(0.04), dn)
			for xx in [0.24, 0.64]:
				box(Vector3(0.3, 0.85, 0.055), Vector3(xx, 1.5, 0), C_WHITE.darkened(0.07), dn)
				box(Vector3(0.3, 0.75, 0.055), Vector3(xx, 0.52, 0), C_WHITE.darkened(0.07), dn)
			box(Vector3(0.12, 0.025, 0.12), Vector3(wdt - 0.1, 1.0, 0.0), Color(0.3, 0.3, 0.32), dn)
		reg(d[0], d[2], Vector3(mid, 1.2, -3.0), Vector3(mid + 0.2, 0, -1.95), Vector3(0, 0, -1))

## dining corner in the east half: table, four chairs, a pendant, a sideboard + plant
func _build_dining() -> void:
	var c := Vector3(5.6, 0, 0.9)
	box(Vector3(1.5, 0.04, 0.9), c + Vector3(0, 0.74, 0), C_WOOD)
	for x in [-0.66, 0.66]:
		for z in [-0.36, 0.36]: box(Vector3(0.05, 0.72, 0.05), c + Vector3(x, 0.36, z), C_WOOD.darkened(0.12))
	obstacles.append(Rect2(c.x - 0.78, c.z - 0.9, 1.56, 1.8))
	for k in 4:
		var cx: float = [-0.4, 0.4, -0.4, 0.4][k]; var sz: float = -1.0 if k < 2 else 1.0
		var ch := Node3D.new(); ch.position = c + Vector3(cx, 0, sz * 0.74); ch.rotation.y = 0.0 if sz < 0 else PI; add_child(ch)
		box(Vector3(0.42, 0.05, 0.4), Vector3(0, 0.45, 0), [C_SAGE, C_CREAM, C_CREAM, C_SAGE][k], ch)
		box(Vector3(0.42, 0.42, 0.04), Vector3(0, 0.7, -0.19), [C_SAGE, C_CREAM, C_CREAM, C_SAGE][k], ch)
		for lx in [-0.18, 0.18]:
			for lz in [-0.17, 0.17]: box(Vector3(0.03, 0.44, 0.03), Vector3(lx, 0.22, lz), C_WOOD.darkened(0.12), ch)
	_table_spread()
	N.pendant2 = prop("lampSquareCeiling", c + Vector3(0, 2.18, 0), 0, 0.36)
	box(Vector3(0.01, 0.4, 0.01), c + Vector3(0, 2.45, 0), Color(0.2, 0.2, 0.2))
	N.ceil_glow2 = box(Vector3(0.16, 0.04, 0.16), c + Vector3(0, 2.19, 0), Color(1, 0.95, 0.85), self, 3.0)
	N.ceil_light2 = OmniLight3D.new(); N.ceil_light2.position = c + Vector3(0, 2.0, 0); N.ceil_light2.omni_range = 5.0
	N.ceil_light2.light_energy = 0.6; N.ceil_light2.light_color = Color(1, 0.96, 0.9); add_child(N.ceil_light2)
	# sideboard on the north wall between the doors' + a plant in the north-east corner
	var sbx := 3.9
	box(Vector3(1.0, 0.7, 0.42), Vector3(sbx, 0.38, -2.78), C_CAB); box(Vector3(1.04, 0.03, 0.45), Vector3(sbx, 0.745, -2.78), C_WOOD)
	for k in 2: box(Vector3(0.48, 0.6, 0.012), Vector3(sbx - 0.245 + k * 0.49, 0.38, -2.565), C_CAB.darkened(0.03))
	obstacles.append(Rect2(sbx - 0.52, -3.0, 1.04, 0.45))
	prop("books", Vector3(sbx - 0.3, 0.76, -2.8), 0, 0.0, 0.24); _spl(prop("plantSmall2", Vector3(sbx + 0.3, 0.76, -2.8), 0, 0.28))
	box(Vector3(0.36, 0.48, 0.02), Vector3(sbx, 1.55, -2.98), C_DARK)
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.3, 0.42); q.mesh = qm
	var pm := StandardMaterial3D.new(); pm.albedo_texture = load("res://ui/poster1.png"); q.material_override = pm; q.position = Vector3(sbx, 1.55, -2.968); add_child(q)
	var pl := prop("pottedPlant", Vector3(7.75, 0, -2.6), 20, 1.15); block(pl)
	var pl2 := prop("pottedPlant", Vector3(7.75, 0, 2.55), -30, 0.9); block(pl2)
	N.plant3 = pl; reg("plant3", "big plant", Vector3(7.75, 0.8, -2.6), Vector3(7.2, 0, -2.05), Vector3(1, 0, -1))   # v31-fixes: dining plants waterable
	N.plant4 = pl2; reg("plant4", "plant", Vector3(7.75, 0.6, 2.55), Vector3(7.15, 0, 2.05), Vector3(1, 0, 1))

## named seat markers for family members: Marker3D at hips height on the seat, +Z = facing direction
func _build_markers() -> void:
	var g := Node3D.new(); g.name = "SeatMarkers"; add_child(g)
	for k in SEATS:
		var mk := Marker3D.new(); mk.name = "Seat_" + k; g.add_child(mk)
		mk.position = Vector3(SEATS[k].hips.x, SEATS[k].top, SEATS[k].hips.z); mk.rotation.y = SEATS[k].yaw
		mk.set_meta("seat_top", SEATS[k].top); mk.set_meta("object", SEATS[k].obj)
	# door markers (in the opening, on the floor) + spawn points just inside the room (+Z of the marker = facing into the room)
	for d in [["Door_Bedroom", DOOR_BED, -3.0, 0.0], ["Door_Bathroom", DOOR_BATH, -3.0, 0.0], ["Door_Front", DOOR_FRONT, 3.0, PI]]:
		var dv: Vector2 = d[1]; var mk := Marker3D.new(); mk.name = d[0]; mk.position = Vector3((dv.x + dv.y) / 2, 0, d[2]); mk.rotation.y = d[3]; g.add_child(mk)
		var sp := Marker3D.new(); sp.name = "Spawn_" + String(d[0]).trim_prefix("Door_"); sp.rotation.y = d[3]
		sp.position = mk.position + Vector3(0, 0, 0.9 if d[2] < 0 else -0.7); g.add_child(sp)

# ============================================================ states -> visuals
func _to(n: Object, p: String, val, anim: bool, t := 0.8) -> void:
	if anim: create_tween().tween_property(n, p, val, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else: n.set(p, val)

const CUSH_TIDY := [[Vector3(2.98, 0.62, -0.82), Vector3(0, 0, -0.22)], [Vector3(2.98, 0.62, 0.82), Vector3(0, 0, -0.22)], [Vector3(3.0, 0.62, 0.55), Vector3(0, 0.15, -0.25)]]
const CUSH_MESSY := [[Vector3(2.78, 0.52, -0.25), Vector3(1.25, 0.5, 0.2)], [Vector3(2.98, 0.62, 0.82), Vector3(0.25, 0.5, -0.25)], [Vector3(1.75, 0.08, 0.95), Vector3(1.5, 0.9, 0.0)]]
func _apply_states(anim := false) -> void:
	var tv_on: bool = S.tv == "on"
	var sm := StandardMaterial3D.new()
	if tv_on: sm.albedo_texture = N.channels[S.channel]; sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else: sm.albedo_color = Color(0.04, 0.045, 0.05); sm.roughness = 0.2; sm.metallic_specular = 0.9
	N.screen.material_override = sm
	N.tv_light.visible = tv_on; N.chan_lbl.visible = tv_on; N.chan_lbl.text = CH_NAMES[S.channel]
	N.tv_led.material_override = _mat(Color(0.3, 0.9, 0.4) if tv_on else Color(0.9, 0.2, 0.2), 2.0)
	N.tv_light.light_color = [Color(0.55, 0.7, 1.0), Color(1.0, 0.85, 0.5), Color(0.6, 0.9, 0.7), Color(0.55, 0.95, 0.55)][S.channel]
	var c_on: bool = S.ceiling == "on"
	N.ceil_light.visible = c_on; N.ceil_glow.visible = c_on; N.ceil_light2.visible = c_on; N.ceil_glow2.visible = c_on; N.switch_nub.position.y = 1.22 if c_on else 1.18
	var fl_on: bool = S.floorlamp == "on"
	N.flamp_light.visible = fl_on; N.flamp_glow.visible = fl_on
	N.shade.material_override = _mat(Color(0.98, 0.92, 0.80), 1.1 if fl_on else 0.0)
	if N.has("tlamp_shade"): N.tlamp_shade.material_override = _mat(Color(0.98, 0.9, 0.75), 0.9 if (fl_on or not c_on) else 0.0)
	_set_curtains(S.curtains == "open", anim)
	_to(N.sash, "rotation:y", deg_to_rad(-60.0) if S.window == "open" else 0.0, anim, 1.0)
	_to(N.drawer, "position:x", UX + 0.236 + (0.3 if S.drawer == "open" else 0.0), anim, 0.6)
	for pi in [[N.plant, S.plant], [N.plant2, S.plant2], [N.plant3, S.plant3], [N.plant4, S.plant4]]:
		for m in pi[0].find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = null if pi[1] == "watered" else _mat(Color(0.75, 0.6, 0.25), 0.0, 0.55)
	N.shelf_book.visible = S.book == "shelf"
	N.remote.visible = S.remote == "table"
	N.blanket_folded.visible = S.blanket == "folded"
	N.blanket_open.visible = S.blanket == "on"
	for i in 3:
		var t: Array = (CUSH_TIDY if S.cushions == "tidy" else CUSH_MESSY)[i]
		_to(N.cush[i], "position", t[0], anim, 0.7); _to(N.cush[i], "rotation", t[1], anim, 0.7)
	_to(N.photos[1], "rotation:z", 0.0 if S.picture == "straight" else 0.12, anim, 0.5)
	for dk in ["door_bed", "door_bath"]:
		if N.has(dk): _to(N[dk], "rotation:y", deg_to_rad(-82.0) if S[dk] == "open" else 0.0, anim, 1.3)
	if N.has("front"):
		_to(N.front, "rotation:y", deg_to_rad(82.0) if S.front == "open" else 0.0, anim, 1.4)
		_to(N.lock_turn, "rotation:z", 0.0 if S.lock == "locked" else PI / 2, anim, 0.3)
		N.shoes_rack.visible = S.shoes == "rack"; N.keys_hook.visible = S.keys == "hook"
	var day: bool = S.curtains == "open"
	sun.light_energy = (1.6 * WorldState.daylight()) if day else 0.0   # house.29: shared clock
	(N.sky as StandardMaterial3D).albedo_color = Color(1, 1, 1) if day else Color(0.35, 0.38, 0.6)
	env.ambient_light_energy = 0.22 + (0.16 if c_on else 0.0) + (0.14 if day else 0.0) + (0.07 if fl_on else 0.0) + (0.03 if tv_on else 0.0)

# ============================================================ verbs: [chip label, sentence, key]
func verbs(id: String) -> Array:
	if id.begins_with("fam_") and mode != "seated" and OBJ.has(id): return _fam_verbs(id)
	if mode == "seated":
		var v := [["Stand up", "I am standing up.", "stand"]]
		if S.seat.begins_with("sofa"):
			v.append(["Turn off the TV", "I am turning off the TV.", "tv"] if S.tv == "on" else ["Turn on the TV", "I am turning on the TV.", "tv"])
			if S.tv == "on": v.append(["Change the channel", "I am changing the channel.", "channel"]); v.append(["Watch TV", "I am watching TV.", "watch"])
			v.append(["Take the blanket off", "I am taking the blanket off.", "blanket"] if S.blanket == "on" else ["Use the blanket", "I am putting the blanket on my legs.", "blanket"])
		else:
			v.append(["Turn off the lamp", "I am turning off the floor lamp.", "lamp"] if S.floorlamp == "on" else ["Turn on the lamp", "I am turning on the floor lamp.", "lamp"])
		if S.book == "hand": v.append(["Read", "I am reading a book.", "read"])
		return v
	match id:
		_ when id.begins_with("splant"):   # v31: small plants waterable
			if String(S.get(id, "dry")) == "dry": return [["Water", "I am watering the plant.", "water"]]
			return [["Look", "The plant is happy now.", "look"]]
		"sofa":
			var v := [["Sit down", "I am sitting on the sofa.", "sit"]]
			if S.cushions == "messy": v.append(["Tidy the cushions", "I am tidying the cushions.", "cushions"])
			if S.blanket == "on": v.append(["Fold the blanket", "I am folding the blanket.", "fold"])
			return v
		"armchair": return [["Sit down", "I am sitting in the armchair.", "sit"]]
		"tv":
			var v := [["Turn off the TV", "I am turning off the TV.", "power"] if S.tv == "on" else ["Turn on the TV", "I am turning on the TV.", "power"]]
			if S.tv == "on": v.append(["Change the channel", "I am changing the channel.", "channel"])
			v.append(["Close the drawer", "I am closing the drawer.", "drawer"] if S.drawer == "open" else ["Open the drawer", "I am opening the drawer.", "drawer"])
			return v
		"coffee":
			var v := [["Put the remote down", "I am putting the remote control down.", "remote"] if S.remote == "hand" else ["Take the remote", "I am taking the remote control.", "remote"],
				["Drink some tea", "I am drinking some tea.", "tea"]]
			if S.remote == "hand" and S.tv == "on": v.append(["Change the channel", "I am changing the channel.", "channel"])
			return v
		"floorlamp": return [["Turn off the lamp", "I am turning off the floor lamp.", "toggle"] if S.floorlamp == "on" else ["Turn on the lamp", "I am turning on the floor lamp.", "toggle"]]
		"switch": return [["Turn off the light", "I am turning off the light.", "toggle"] if S.ceiling == "on" else ["Turn on the light", "I am turning on the light.", "toggle"]]
		"window":
			var v := [["Close the curtains", "I am closing the curtains.", "curtains"] if S.curtains == "open" else ["Open the curtains", "I am opening the curtains.", "curtains"]]
			if S.curtains == "open":
				v.append(["Close the window", "I am closing the window.", "window"] if S.window == "open" else ["Open the window", "I am opening the window.", "window"])
				v.append(["Look out", "I am looking out of the window.", "look"])
			return v
		"books":
			if S.book == "shelf": return [["Take a book", "I am taking a book.", "take"]]
			return [["Read", "I am reading a book.", "read"], ["Put it back", "I am putting the book back.", "back"]]
		"plant", "plant2", "plant3", "plant4":
			if S[id] == "dry": return [["Water", "I am watering the plant.", "water"]]
			return [["Look", "The plant is happy now.", "look"]]
		"photos":
			var v := [["Look", "I am looking at the photos.", "look"]]
			if S.picture == "crooked": v.append(["Straighten", "I am straightening the picture.", "straight"])
			return v
		"front":
			return [["Go outside", "", "go"]]   # house.23: one tap opens the door and goes out (like every room door)
		"entry":
			return [["Put on my shoes", "I am putting on my shoes.", "shoes"] if S.shoes == "rack" else ["Take off my shoes", "I am taking off my shoes.", "shoes"],
				["Take my keys", "I am taking my keys.", "keys"] if S.keys == "hook" else ["Put my keys back", "I am putting my keys back.", "keys"]]
		"door_bed", "door_bath":
			var go := ["Go to the bedroom", "I am opening the door.", "go"] if id == "door_bed" else ["Go to the bathroom", "I am opening the door.", "go"]
			return [go]   # house.17: one chip opens the door and goes through
	return []

# ============================================================ actions
func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout
	while House.dormant(self) and is_inside_tree(): await get_tree().process_frame   # v33town: a sleeping room's steps wait until the player is back

func gesture(kind: String, id: String, change: Callable) -> void:
	var g: Array = {"reach": ["pick_up", 1.35], "low": ["pick_up", 2.6], "mid": ["pick_up", 1.75], "door": ["open_door", 2.7]}[kind]
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

func do_verb(id: String, v: Array) -> void:
	if mode != "play" and mode != "seated": return
	var was_seated := mode == "seated"
	mode = "busy"; _hide_chips(); hand3d.visible = false
	await Audio.wait_idle(12.0)   # house.17: an action waits for the current announcement
	var key: String = v[2]
	if was_seated:
		caption(v[1])
		await seated_verb(key)
		_after(id); return
	if id.begins_with("fam_"):
		await _fam_verb(id, key); _after(id); return
	var spot: Vector3 = OBJ[id].spot; var yaw: float = OBJ[id].yaw
	# house.26: face the object itself (cushions, pictures, plants ...) - not the registered "front" direction
	var fc: Vector3 = OBJ[id].get("focus", spot)
	if Vector2(fc.x - spot.x, fc.z - spot.z).length() > 0.05: yaw = atan2(fc.x - spot.x, fc.z - spot.z)
	var seat := ""
	if key == "sit":
		seat = "armchair" if id == "armchair" else _free_sofa_seat()
		yaw = SEATS[seat].yaw      # turn your back to the seat
		spot = sit_spot(seat)
	if hero.position.distance_to(spot) > 0.5: caption("I am going to the %s." % OBJ[id].name)
	await walk_to(spot, yaw)
	caption(v[1])
	match id:
		_ when id.begins_with("splant"):   # v31: small plants waterable
			if key == "water": await water_plant(id)
			else: action_peak.emit(id); await wait(1.5)
		"sofa", "armchair":
			if key == "sit":
				await sit_down(hero, seat, true); S.seat = seat; action_peak.emit(id)
				_after(id); return
			elif key == "cushions": await gesture("mid", id, func(): S.cushions = "tidy"; Audio.sfx("fluff"); Audio.sfx("cloth1", -6.0)); _living_save()
			elif key == "fold": await gesture("mid", id, func(): S.blanket = "folded"; Audio.sfx("cloth3"))
		"tv":
			if key == "drawer": await gesture("low", id, func(): S.drawer = _flip("drawer"); Audio.sfx("drawer"))
			elif key == "power": await gesture("reach", id, func(): S.tv = _flip("tv"); Audio.sfx("click"); if S.tv == "on": Audio.sfx("tvhum", -6.0))
			else:
				await gesture("reach", id, func(): S.channel = (S.channel + 1) % 4; Audio.sfx("click"))
				caption(CH_LINES[S.channel]); await wait(1.2)
		"coffee":
			if key == "remote":
				await gesture("low", id, func():
					Audio.sfx("metalClick", 0.0, 1.3)
					S.remote = "table" if S.remote == "hand" else "hand"
					_hold_remote(S.remote == "hand"))
			elif key == "channel":
				await press_remote(func(): S.channel = (S.channel + 1) % 4)
				caption(CH_LINES[S.channel]); await wait(1.2)
			else: await drink_tea()
		"floorlamp": await gesture("reach", id, func(): S.floorlamp = _flip("floorlamp"); Audio.sfx("metalClick"))
		"switch": await gesture("door", id, func(): S.ceiling = _flip("ceiling"); Audio.sfx("metalClick", 2.0))
		"window":
			if key == "look": hero.play("idle", 0.3); action_peak.emit(id); await wait(2.2)
			else: await gesture("door", id, func():
				S[key] = _flip(key); Audio.sfx("swish" if key == "curtains" else "creak1", -4.0 if key == "window" else 0.0); if key == "curtains": Audio.sfx("cloth1", -8.0))
			if key == "curtains" and S.curtains == "closed": await wait(0.3); caption("It is evening now."); await wait(1.0)
		"books":
			if key == "read": await read_book()
			elif key == "take": await gesture("reach", id, func(): S.book = "hand"; Audio.sfx("bookPlace1"); hero.hold_item("res://props/book.tscn", "flat", 0.24, true))
			else: await gesture("reach", id, func(): S.book = "shelf"; Audio.sfx("bookPlace1"); hero.release_item())
		"plant", "plant2", "plant3", "plant4":
			if key == "water": await water_plant(id)
			else: action_peak.emit(id); await wait(1.5)
		"photos":
			if key == "look":
				cam_shot = {"pos": Vector3(-1.0, 1.75, -0.9), "at": Vector3(-1.45, 1.65, -2.97)}
				hero.play("idle", 0.3); action_peak.emit(id); await wait(1.6); caption("This is my family."); await wait(2.0)
			else: await gesture("reach", id, func(): S.picture = "straight"; Audio.sfx("metalClick", -2.0, 0.8)); _living_save()
		"front":
			if key == "go":
				if S.lock == "locked": S.lock = "unlocked"; Audio.sfx("keys", -4.0); Audio.sfx("metalClick", 0.0, 0.7); await wait(0.4)
				if S.front == "closed":
					S.front = "open"; _apply_states(true); Audio.sfx("doorOpen_1", 0.0, 0.85); Audio.sfx("creak1", -8.0, 0.8); await wait(0.6)
				await walk_to(Vector3((DOOR_FRONT.x + DOOR_FRONT.y) / 2 + 0.1, 0, 2.8), 0.0)
				action_peak.emit(id); exit_requested.emit("outside")
			elif key == "lock":
				await gesture("reach", id, func():
					S.lock = "unlocked" if S.lock == "locked" else "locked"
					Audio.sfx("keys", -4.0); Audio.sfx("metalClick", 0.0, 0.7))
			else:
				var opening: bool = S.front == "closed"
				await gesture("door", id, func():
					S.front = _flip("front")
					Audio.sfx("doorOpen_1" if opening else "doorClose_2", 0.0, 0.85); Audio.sfx("creak1", -8.0, 0.8))
		"entry":
			if key == "shoes":
				await gesture("low", id, func(): S.shoes = "on" if S.shoes == "rack" else "rack"; Audio.sfx("handleSmallLeather"); Audio.sfx("cloth3", -6.0))
			else:
				await gesture("reach", id, func(): S.keys = "pocket" if S.keys == "hook" else "hook"; Audio.sfx("keys"))
		"door_bed", "door_bath":
			if key == "go":
				if north_door_panels and S[id] == "closed":
					await gesture("door", id, func(): S[id] = "open"; Audio.sfx("doorOpen_1"))
				var dv: Vector2 = DOOR_BED if id == "door_bed" else DOOR_BATH
				await walk_to(Vector3((dv.x + dv.y) / 2, 0, -2.75), PI)
				exit_requested.emit("bedroom" if id == "door_bed" else "bathroom"); action_peak.emit(id)
				await wait(1.4); await walk_to(OBJ[id].spot, PI)
			else:
				var opening: bool = S[id] == "closed"
				await gesture("door", id, func():
					S[id] = _flip(id)
					Audio.sfx("doorOpen_1" if opening else "doorClose_2"); Audio.sfx("creak1", -6.0))
	_after(id)

func _after(id: String) -> void:
	cam_shot = {}
	mode = "seated" if S.seat != "" else "play"
	_update_hand(); action_done.emit(id); _advance()

func _free_sofa_seat() -> String:
	var taken := []
	for f in family: taken.append(f.get_meta("seat", ""))
	for k in ["sofa_middle", "sofa_left", "sofa_right"]:
		if not k in taken: return k
	return "sofa_middle"

## standing spot in front of a seat (the player stands there with the back to the seat)
func sit_spot(seat: String) -> Vector3:
	var f := Vector3(sin(SEATS[seat].yaw), 0, cos(SEATS[seat].yaw))
	return SEATS[seat].hips + f * 0.46

# ---------- sitting: the stand_to_sit clip runs while the root slides so the hips land exactly on the cushion.
## Measured from the clips per character (child / short / tall bodies all fit): hips HIP_ABOVE_SEAT over the seat top.
const HIP_ABOVE_SEAT := 0.10
func _hips(ch: DemoCharacter) -> Vector3:
	var sk := ch.skeleton
	return to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips")).origin)   # open world: room-local (SEATS / ch.position)

## root position that puts the hips of `anim` at time t onto the seat
func _pose_fix(ch: DemoCharacter, anim: String, t: float, seat: String) -> Vector3:
	var h := _anim_hips(ch, anim, t)
	var tgt: Vector3 = SEATS[seat].hips
	return ch.position + Vector3(tgt.x - h.x, SEATS[seat].top + HIP_ABOVE_SEAT * ch.model.scale.y - h.y, tgt.z - h.z)

## world position of the Hips bone for clip `anim` at time t, read from the animation track (no pose evaluation needed:
## with a renderer the skeleton pose is only refreshed later in the frame, so sampling the pose would be stale)
func _anim_hips(ch: DemoCharacter, anim: String, t: float) -> Vector3:
	var sk := ch.skeleton
	var hi := sk.find_bone("Hips")
	var a: Animation = ch.player.get_animation(anim)
	var local: Vector3 = sk.get_bone_rest(hi).origin
	for ti in a.get_track_count():
		if a.track_get_type(ti) == Animation.TYPE_POSITION_3D and String(a.track_get_path(ti)).ends_with(":Hips"):
			local = a.position_track_interpolate(ti, t)
	var par := sk.get_bone_parent(hi)
	var pxf := sk.get_bone_global_rest(par) if par >= 0 else Transform3D.IDENTITY
	return to_local(sk.global_transform * (pxf * local))   # open world: room-local, like SEATS and ch.position

func sit_down(ch: DemoCharacter, seat: String, animate: bool) -> void:
	ch.rotation.y = SEATS[seat].yaw
	ch.set_meta("seat", seat)
	var fix_idle := _pose_fix(ch, "sit_idle", 0.0, seat)
	if not animate:
		ch.player.play("sit_idle", 0.0); ch.player.advance(0.0); ch.position = fix_idle; return
	var L := ch.anim_length("stand_to_sit")
	var fix_end := _pose_fix(ch, "stand_to_sit", L - 0.04, seat)
	ch.player.play("idle", 0.0); ch.player.advance(0.0)
	ch.player.speed_scale = 1.0
	ch.player.play("stand_to_sit", 0.25)
	if ch == hero: get_tree().create_timer(L * 0.6).timeout.connect(func(): Audio.sfx("fluff", -8.0))
	var tw := create_tween(); tw.tween_property(ch, "position", fix_end, L - 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await wait(L - 0.06)
	tw.kill()     # slow frames: the timer can fire before the tween's last step, which would then overwrite the position
	ch.player.play("sit_idle", 0.0); ch.player.advance(0.0); ch.position = fix_idle

func stand_up() -> void:
	_blanket(false)
	var seat: String = S.seat
	S.seat = ""
	hero.bone_offsets.clear()
	var fix0 := _pose_fix(hero, "sit_to_stand", 0.0, seat)
	hero.player.play("sit_to_stand", 0.0); hero.player.advance(0.0); hero.position = fix0
	var L := hero.anim_length("sit_to_stand")
	var tw := create_tween(); tw.tween_property(hero, "position:y", 0.0, L * 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _sit_to_stand(true)
	tw.kill(); hero.position.y = 0.0
	hero.set_meta("seat", "")
	if S.remote == "hand" and true: pass

func _sit_to_stand(started := false) -> void:
	hero.player.speed_scale = 1.0
	if not started: hero.player.play("sit_to_stand", 0.35)
	await wait(hero.anim_length("sit_to_stand") - 0.04)
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

func seated_verb(key: String) -> void:
	match key:
		"stand": await stand_up()
		"tv": await press_remote(func(): S.tv = _flip("tv"); if S.tv == "on": Audio.sfx("tvhum", -6.0))
		"channel":
			await press_remote(func(): S.channel = (S.channel + 1) % 4)
			caption(CH_LINES[S.channel]); await wait(1.2)
		"watch":
			S.watched = true; action_peak.emit("tv"); await wait(2.6)
		"blanket":
			Audio.sfx("cloth1"); _blanket(S.blanket != "on"); await wait(0.5); action_peak.emit("sofa"); await wait(0.8)
		"lamp": await seated_reach(func(): S.floorlamp = _flip("floorlamp"); Audio.sfx("metalClick"))
		"read": await read_seated()

func _side_axis() -> Vector3:
	var f := _fwd(); return Vector3(f.z, 0, -f.x)      # model-space axis for a forward arm raise (pitch about the body's left-right axis)

## remote control from the sofa: picks it up from the table if needed, raises the arm toward the TV, clicks
func press_remote(change: Callable) -> void:
	if S.remote != "hand": _hold_remote(true); S.remote = "hand"; _apply_states()
	var ax := _side_axis()
	_tw_offset("UpperArm.R", ax, -0.75, 0.5)
	await wait(0.6); Audio.sfx("click"); change.call(); _apply_states(true); action_peak.emit("tv")
	await wait(0.9)
	_tw_offset("UpperArm.R", ax, 0.0, 0.5); await wait(0.55)
	hero.bone_offsets.erase("UpperArm.R")

func seated_reach(change: Callable) -> void:
	var ax := _side_axis()
	_tw_offset("UpperArm.L", ax, -0.8, 0.5); await wait(0.6)
	change.call(); _apply_states(true); action_peak.emit("floorlamp"); await wait(0.6)
	_tw_offset("UpperArm.L", ax, 0.0, 0.5); await wait(0.55); hero.bone_offsets.erase("UpperArm.L")

func _hold_remote(on: bool) -> void:
	if remote_in_hand: remote_in_hand.queue_free(); remote_in_hand = null
	if not on: return
	var r: Node3D = (load("res://props/remote.tscn") as PackedScene).instantiate()
	var piv := Node3D.new(); piv.add_child(r); r.rotation.x = PI / 2
	piv.position = Vector3(0, 0.085 if hero.gender == "men" else 0.07, -0.03)
	hero._hand["R"].add_child(piv); remote_in_hand = piv

func _blanket(on: bool) -> void:
	if on:
		S.blanket = "on"
		var f := _fwd(); var h := _hips(hero)
		N.blanket_open.position = Vector3(h.x, SEAT_TOP + 0.19, h.z) + f * 0.2
		N.blanket_open.rotation = Vector3(0, hero.rotation.y - PI / 2, 0)
	elif S.blanket == "on": S.blanket = "folded"
	_apply_states(true)

func _fwd() -> Vector3:
	return Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y))

func read_book() -> void:
	hero.player.play("drink", 0.4); hero.player.seek(1.6, true)
	await wait(0.9)
	hero.player.speed_scale = 0.0
	_tw_offset("Neck", Vector3.RIGHT, 0.35, 0.5)
	Audio.sfx("bookOpen"); S.read = true; action_peak.emit("books")
	await wait(1.2); Audio.sfx("bookFlip1"); await wait(1.0)
	_tw_offset("Neck", Vector3.RIGHT, 0.0, 0.4)
	hero.player.speed_scale = 1.0; hero.player.play("idle", 0.5); await wait(0.5)
	hero.bone_offsets.erase("Neck")

## seated reading: sitting pose, left forearm raised with the book in front of the chest, head tilted down
var READ_UP := -0.55
var READ_LOW := -1.1
var READ_NECK := 0.35
func read_seated() -> void:
	var ax := _side_axis()
	_tw_offset("UpperArm.L", ax, READ_UP, 0.6); _tw_offset("LowerArm.L", ax, READ_LOW, 0.6)
	await wait(0.4); _tw_offset("Neck", ax, READ_NECK, 0.5)
	await wait(0.3); Audio.sfx("bookOpen"); S.read = true; action_peak.emit("books")
	await wait(1.4); Audio.sfx("bookFlip1"); await wait(1.2)
	_tw_offset("Neck", ax, 0.0, 0.4); _tw_offset("UpperArm.L", ax, 0.0, 0.5); _tw_offset("LowerArm.L", ax, 0.0, 0.5)
	await wait(0.55)
	for b in ["UpperArm.L", "LowerArm.L", "Neck"]: hero.bone_offsets.erase(b)

func _tw_offset(bone: String, axis: Vector3, ang: float, t: float) -> void:
	var cur: float = hero.bone_offsets[bone][1] if hero.bone_offsets.has(bone) else 0.0
	var tw := create_tween()
	tw.tween_method(func(a): hero.bone_offsets[bone] = [axis, a], cur, ang, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func drink_tea() -> void:
	if S.book == "hand": caption("My hands are full."); await wait(1.5); return
	var had_remote: bool = S.remote == "hand"
	_hold_remote(false)
	N.mug.visible = false
	hero.hold_item("res://props/mug.tscn", "cylinder", 0.1, false)
	Audio.sfx("clink", -4.0); _tea_arm([-1.05, -1.8, 0.85], 0.6); await wait(0.8); action_peak.emit("coffee"); await wait(1.4)
	_tea_arm([0.0, 0.0, 0.0], 0.5); await wait(0.55)
	for b in ["UpperArm.R", "LowerArm.R", "Shoulder.R"]: hero.bone_offsets.erase(b)
	hero.release_item(); N.mug.visible = true; Audio.sfx("clink", -8.0, 0.9)
	if had_remote: _hold_remote(true)

func water_plant(id: String) -> void:
	var book: bool = S.book == "hand"
	hero.hold_item("res://props/watering_can.tscn", "cylinder", 0.26, false)
	hero.player.play("pick_up", 0.3); await wait(1.55)
	hero.player.speed_scale = 0.0
	var hb: Node3D = hero._hand["R"]
	water_fx.global_position = hb.global_position + _fwd() * 0.18 + Vector3(0, -0.02, 0)
	water_fx.emitting = true; Audio.sfx("water_drops", -6.0)   # house.24: soft trickle, not the tap
	await wait(0.5); S[id] = "watered"; _apply_states(true); action_peak.emit(id)
	await wait(1.2); water_fx.emitting = false
	hero.player.speed_scale = -1.2; await wait(1.2)
	hero.player.speed_scale = 1.0; hero.player.play("idle", 0.3); hero.release_item()
	if book: hero.hold_item("res://props/book.tscn", "flat", 0.24, true)
	caption("The plant is happy now.")

## family members (main game): seat a DemoCharacter on a named seat (see SeatMarkers / INTEGRATION.md)
func seat_family_member(ch: DemoCharacter, seat: String) -> void:
	if ch.get_parent() == null: add_child(ch)
	family.append(ch); sit_down(ch, seat, false)

# ============================================================ movement / path (bedroom code)
const GW := 117
const GH := 60
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
	if cam_stick.length() > 0.1:
		var dy := cam_stick.x * 1.8 * dt
		if signf(dy) == signf(cam_yaw): dy *= clampf(1.0 - pow(absf(cam_yaw) / 1.3, 3.0), 0.0, 1.0)
		cam_yaw = clampf(cam_yaw + dy, -1.3, 1.3)
		var dp := cam_stick.y * 1.0 * dt
		if signf(dp) == signf(cam_pitch - 0.95): dp *= clampf(1.0 - pow(absf(cam_pitch - 0.95) / 0.35, 3.0), 0.0, 1.0)
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
	if mode == "play" or mode == "seated": _update_hand()
	if hero.player.current_animation in ["walk", "run"]:
		var ph: float = fmod(hero.player.current_animation_position / hero.anim_length(hero.player.current_animation) * 2.0, 1.0)
		if ph < last_step_ph: Audio.sfx("footstep0%d" % randi_range(0, 3), -10.0, randf_range(0.9, 1.1))
		last_step_ph = ph
	var tt := Time.get_ticks_msec() * 0.001
	if S.window == "open":
		N.curtL.rotation.x = sin(tt * 1.7) * 0.04; N.curtR.rotation.x = sin(tt * 1.3 + 1.0) * 0.05
	else:
		N.curtL.rotation.x = lerpf(N.curtL.rotation.x, 0.0, 0.1); N.curtR.rotation.x = lerpf(N.curtR.rotation.x, 0.0, 0.1)
	if S.tv == "on": N.tv_light.light_energy = 0.55 + 0.12 * sin(tt * 7.0) * sin(tt * 2.3)
	if hand3d.visible and near_id != "": hand3d.position.y = OBJ[near_id].focus.y + 0.55 + sin(Time.get_ticks_msec() * 0.005) * 0.05
	_update_cam(dt)
	_layout()

## same follow camera as the bedroom; the room is wider, so the focus follows x more (keeps the player on screen)
func _cam_target() -> Vector3:
	return Vector3(RCX + (hero.position.x - RCX) * 0.72, 0, -0.35 + hero.position.z * 0.3)

func _update_cam(dt: float) -> void:
	var target := _cam_target()
	if cam_zoom < 1.0: target = Vector3(hero.position.x, 0.4, hero.position.z - 0.3)
	cam_focus = cam_focus.lerp(target, 1.0 - exp(-2.5 * dt))
	if cam_override: return
	if not cam_shot.is_empty():
		var k := 1.0 - exp(-2.2 * dt)
		if shot_at == Vector3.INF: shot_at = cam.position - cam.transform.basis.z * 6.0
		cam.position = cam.position.lerp(cam_shot.pos, k); shot_at = shot_at.lerp(cam_shot.at, k)
		cam.look_at(to_global(shot_at), Vector3.UP); _fade_walls(dt); exit_xf = cam.transform; exit_t = 0.0; return
	shot_at = Vector3.INF
	cam_yaw_s = lerp_angle(cam_yaw_s, cam_yaw, 1.0 - exp(-8.0 * dt)); cam_pitch_s = lerpf(cam_pitch_s, cam_pitch, 1.0 - exp(-8.0 * dt))
	var off := Vector3(sin(cam_yaw_s) * cos(cam_pitch_s), sin(cam_pitch_s), cos(cam_yaw_s) * cos(cam_pitch_s)) * cam_dist * cam_zoom
	var cp := cam_focus + off
	if cp.y < WALL_H + 0.4 and absf(cp.x - RCX) < 6.1 and cp.z > -3.2 and cp.z < 3.2: cp.y = WALL_H + 0.4
	cp = cam_avoid.adjust(cam_focus, cp, hero.position + Vector3(0, 1.0, 0), dt, mode == "play", get_tree())   # v33: camera occlusion avoidance
	if cp.y < WALL_H + 0.4 and absf(cp.x - RCX) < 6.1 and cp.z > -3.2 and cp.z < 3.2: cp.y = WALL_H + 0.4
	cam.position = cp
	_fade_walls(dt)
	cam.look_at(to_global(cam_focus + Vector3(0, 0.3, 0)), Vector3.UP)
	if exit_t < 1.0:
		exit_t = minf(1.0, exit_t + dt / 0.9)
		cam.transform = exit_xf.interpolate_with(cam.transform, ease(exit_t, -2.0))

func _fade_walls(dt: float) -> void:
	var eye := hero.position + Vector3(0, 1.2, 0)
	if N.has("front_meshes"):
		var fab := AABB(Vector3(DOOR_FRONT.x - 1.0, 0, 2.0), Vector3(DOOR_FRONT.y - DOOR_FRONT.x + 2.4, WALL_H, 1.15))
		var hide_fd: bool = fab.intersects_segment(cam.position, eye) or fab.intersects_segment(cam.position, hero.position + Vector3(0, 0.3, 0))
		front_alpha = move_toward(front_alpha, 0.15 if hide_fd else 1.0, dt * 3.0)
		for w in N.front_meshes:
			var fm: StandardMaterial3D = w.material_override
			fm.albedo_color.a = front_alpha * (0.4 if w.has_meta("glass") else 1.0)
			fm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if front_alpha > 0.99 and not w.has_meta("glass") else (BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if w.has_meta("glass") else BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)
	for group in ([] if wall_fade else [[walls_l, cam.position.x < -3.5], [walls_r, cam.position.x > EX]]):   # v33: side walls -> WallFade occluders   # v32-polish: south walls -> WallFade
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
	elif mode == "seated" and S.seat != "": best = SEATS[S.seat].obj
	near_id = best
	hand3d.visible = best != "" and mode == "play"
	if best != "": hand3d.position = Vector3(OBJ[best].focus.x, OBJ[best].focus.y + 0.55, OBJ[best].focus.z)
	if touch: touch.queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		cam_yaw = clampf(cam_yaw - e.relative.x * 0.006, -1.3, 1.3); cam_pitch = clampf(cam_pitch + e.relative.y * 0.004, 0.6, 1.3)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		cam_dist = clampf(cam_dist * (0.92 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 6.0, 12.0)
	elif e is InputEventMagnifyGesture:
		cam_dist = clampf(cam_dist / e.factor, 6.0, 12.0)

func on_action() -> void:
	if (mode != "play" and mode != "seated") or near_id == "": return
	Audio.click()
	var v := verbs(near_id)
	if v.size() == 1: do_verb(near_id, v[0])
	else: _show_chips(near_id)

# ============================================================ missions
const MISSIONS := ["Turn on the TV.", "Sit on the sofa.", "Change the channel.", "Read a book.", "Water the plants.", "Close the curtains.", "Turn on the floor lamp."]
var done_missions := {}
func _mission_done(m: String) -> bool:
	match m:
		"Turn on the TV.": return S.tv == "on"
		"Sit on the sofa.": return S.seat.begins_with("sofa")
		"Change the channel.": return S.channel != 0
		"Read a book.": return S.read
		"Water the plants.": return S.plant == "watered" and S.plant2 == "watered"
		"Close the curtains.": return S.curtains == "closed"
		"Turn on the floor lamp.": return S.floorlamp == "on"
	return false

var _out_guided := false
## ===== HOOK (red, v31): day 2, work AND hospital done -> "Talk to your family." (couch). Default: nothing.
signal day2_family_ready
func day2_family_talk() -> void:
	day2_family_ready.emit()
	load("res://scripts/story/day2_evening.gd").start(get_tree())   # v31c (red): Day2Evening couch talk -> bedtime

func _go_outside_guide() -> void:
	var dx := (DOOR_FRONT.x + DOOR_FRONT.y) / 2
	await Life.guide_to({"pos": Vector3(dx - 1.6, 2.0, 0.2), "at": Vector3(dx, 1.1, 3.0)}, "Go outside.", {"tr": "Dışarı çık."})
	_set_mission("Go outside.")

func _advance() -> void:
	var newly := false
	for m in MISSIONS:
		if not done_missions.has(m) and _mission_done(m): done_missions[m] = true; newly = true
	var nxt := "Explore the living room."
	for m in MISSIONS:
		if not done_missions.has(m): nxt = m; break
	if newly: Audio.sfx("notify", -6.0)
	if breakfast_pending(): nxt = "Have breakfast with your family."
	if D2.stage() == "car": nxt = "Go outside to the car."   # v31
	# v30.5: day 1 after breakfast the story goes outside (no stale "Turn on the TV." etc.): pan to the front door once
	if maxi(WorldState.day, App.day) < 2 and breakfast_done:
		nxt = "Go outside."
		if not _out_guided and mission != nxt:
			_out_guided = true; _set_mission(nxt)
			_go_outside_guide.call_deferred(); return
	if get_tree().root.has_node("Day4Routine") or get_tree().root.has_node("Day7Routine"): return   # v33 (red QA): the day-4 / day-7 routine owns the objective (no "Turn on the TV." flash)
	_set_mission(nxt)
	if tasks_panel and tasks_panel.visible: _fill_tasks()

# ============================================================ UI (bedroom style)
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
	hud = Control.new(); hud.name = "HUD"; hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; rootc.add_child(hud)
	touch = load("res://scripts/touch.gd").new(); touch.main = self; touch.set_anchors_preset(Control.PRESET_FULL_RECT); hud.add_child(touch)
	var mp := PanelContainer.new(); mp.name = "Mission"; mp.add_theme_stylebox_override("panel", _sb(Color(0.31, 0.42, 0.93, 0.85), 18, 10))
	mp.position = Vector2(20, 18); hud.add_child(mp)
	var mv := VBoxContainer.new(); mv.add_theme_constant_override("separation", 0); mp.add_child(mv)
	mission_lbl = Label.new(); mission_lbl.add_theme_font_override("font", font_b); mission_lbl.add_theme_font_size_override("font_size", 22); mv.add_child(mission_lbl)
	mission_tr = Label.new(); mission_tr.add_theme_font_size_override("font_size", 18); mission_tr.modulate = Color(0.85, 0.92, 1.0); mv.add_child(mission_tr)
	var pause := Button.new(); pause.text = "II"; pause.name = "Pause"; pause.add_theme_font_override("font", font_b)
	pause.anchor_left = 1; pause.anchor_right = 1; pause.offset_left = -84; pause.offset_right = -20; pause.offset_top = 18; pause.offset_bottom = 82
	pause.pressed.connect(func(): Audio.click(); _show_menu(true)); hud.add_child(pause)
	var phone_btn := Button.new(); phone_btn.name = "PhoneBtn"; phone_btn.tooltip_text = "Missions"
	phone_btn.anchor_left = 1; phone_btn.anchor_right = 1; phone_btn.offset_left = -168; phone_btn.offset_right = -100; phone_btn.offset_top = 16; phone_btn.offset_bottom = 84
	phone_btn.add_theme_stylebox_override("normal", _sb(Color(1, 1, 1, 0.94), 18, 6)); phone_btn.add_theme_stylebox_override("hover", _sb(Color(0.93, 0.95, 1.0), 18, 6))
	phone_btn.add_theme_stylebox_override("pressed", _sb(Color(0.82, 0.86, 0.98), 18, 6))
	var pic := TextureRect.new(); pic.texture = load("res://ui/phone/hud_phone.png"); pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.set_anchors_preset(Control.PRESET_FULL_RECT); pic.offset_left = 12; pic.offset_right = -12
	pic.offset_top = 10; pic.offset_bottom = -10; pic.mouse_filter = Control.MOUSE_FILTER_IGNORE; phone_btn.add_child(pic)
	hud.add_child(phone_btn)
	# house.16: the bedroom's phone + pocket sequence (missions live in the phone's to-do list)
	room_phone = load("res://scripts/room_phone.gd").new(); add_child(room_phone)
	room_phone.setup(self, hud, phone_btn, func(shot: Dictionary): cam_shot = shot)
	phone_btn.visible = App.has_phone   # v29.1: only after the bedroom pickup
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
	# verb chips above the action button in a swipe-scrollable container (TouchScroll autoload)
	chips_scroll = ScrollContainer.new(); chips_scroll.name = "ChipsScroll"; chips_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; hud.add_child(chips_scroll)
	chips = VBoxContainer.new(); chips.name = "Chips"; chips.add_theme_constant_override("separation", 10); chips.alignment = BoxContainer.ALIGNMENT_END
	chips_scroll.add_child(chips)
	var gm := GameMenu.new(); gm.setup(self, "Living room", func(): _show_menu(false)); rootc.add_child(gm); menu = gm   # house.17: shared menu
	_build_tasks(rootc)

func _build_menu(rootc: Control) -> void:
	menu = ColorRect.new(); (menu as ColorRect).color = Color(0.07, 0.09, 0.14, 0.45); menu.name = "Menu"; menu.set_anchors_preset(Control.PRESET_FULL_RECT); menu.visible = false; rootc.add_child(menu)
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.9), 30, 30))
	card.set_anchors_preset(Control.PRESET_CENTER); card.grow_horizontal = Control.GROW_DIRECTION_BOTH; card.grow_vertical = Control.GROW_DIRECTION_BOTH; menu.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); v.custom_minimum_size.x = 360; card.add_child(v)
	var t := Label.new(); t.text = "English Home"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 46)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var st := Label.new(); st.text = "Living room test · A1–A2"; st.add_theme_font_size_override("font_size", 22)
	st.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55)); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	_menu_btn(v, "Resume", func(): _show_menu(false), true)
	var vb := _menu_btn(v, "Voice: On", func(): pass)
	vb.pressed.connect(func(): S.voice = not S.voice; vb.text = "Voice: " + ("On" if S.voice else "Off"); Audio.voice_player.volume_db = 0.0 if S.voice else -80.0)
	var gb := _menu_btn(v, "Character: Man", func(): pass)
	gb.pressed.connect(func(): set_gender("women" if S.gender == "men" else "men"); gb.text = "Character: " + ("Man" if S.gender == "men" else "Woman"))
	_menu_btn(v, "Restart", func(): get_tree().paused = false; (get_tree().change_scene_to_file(App.GAME_SCENE) if OwLink.active() else get_tree().reload_current_scene()))

var _creator_extra := {}
func _apply_character() -> void:
	if not _creator_loaded:   # first call: the saved creator data; later (pause menu): S
		_creator_loaded = true
		var c := DemoCharacter.load_creator()
		for k in c:   # v29.1: creator 'shoes' (style index) must not overwrite the room's 'shoes' state ("rack"/...)
			if S.has(k) and typeof(S[k]) == TYPE_STRING and typeof(c[k]) != TYPE_STRING: _creator_extra[k] = c[k]; continue
			S[k] = c[k]
	var cc := {}
	for k in DemoCharacter.CREATOR_KEYS: if S.has(k): cc[k] = S[k]
	cc.merge(_creator_extra, true)
	hero.apply_creator(cc)
var _creator_loaded := false

func set_gender(g: String) -> void:
	S.gender = g
	var p := hero.position; var r := hero.rotation; hero.setup(g); hero.position = p; hero.rotation = r
	if S.book == "hand": hero.hold_item("res://props/book.tscn", "flat", 0.24, true)
	if S.remote == "hand": _hold_remote(true)
	if S.seat != "": sit_down(hero, S.seat, false)

func _menu_btn(parent: Control, txt: String, cb: Callable, primary := false) -> Button:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(0, 62); b.add_theme_font_override("font", font_b)
	b.add_theme_font_size_override("font_size", 26)
	if primary:
		b.add_theme_stylebox_override("normal", _sb(Color(0.31, 0.42, 0.93), 18, 10)); b.add_theme_stylebox_override("hover", _sb(Color(0.36, 0.48, 0.97), 18, 10))
		b.add_theme_stylebox_override("pressed", _sb(Color(0.25, 0.35, 0.8), 18, 10))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color(1, 1, 1))
	else: b.add_theme_stylebox_override("normal", _sb(Color(0.93, 0.94, 0.97), 18, 10))
	b.pressed.connect(func(): Audio.click(); cb.call()); parent.add_child(b); return b

func _show_menu(on: bool) -> void:
	(menu as GameMenu).show_menu(on); hud.visible = not on
	get_tree().paused = on

## mission list on the HUD phone button: a swipe-scrollable card
func _build_tasks(rootc: Control) -> void:
	tasks_panel = ColorRect.new(); (tasks_panel as ColorRect).color = Color(0.07, 0.09, 0.14, 0.45); tasks_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tasks_panel.visible = false; tasks_panel.name = "Tasks"; rootc.add_child(tasks_panel)
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.95), 30, 22))
	card.anchor_left = 0.5; card.anchor_right = 0.5; card.anchor_top = 0.5; card.anchor_bottom = 0.5
	card.offset_left = -260; card.offset_right = 260; card.offset_top = -310; card.offset_bottom = 310; tasks_panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	var t := Label.new(); t.text = "My missions"; t.add_theme_font_override("font", font_b); t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); v.add_child(t)
	var sc := ScrollContainer.new(); sc.name = "TaskScroll"; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	tasks_list = VBoxContainer.new(); tasks_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tasks_list.add_theme_constant_override("separation", 8); sc.add_child(tasks_list)
	_menu_btn(v, "Close", func(): tasks_panel.visible = false; hud.visible = true, true).name = "CloseTasks"

var room_phone: Node
func open_tasks() -> void:
	if mode == "busy": return
	caption("I am looking at my missions."); _fill_tasks(); tasks_panel.visible = true

func _fill_tasks() -> void:
	for c in tasks_list.get_children(): tasks_list.remove_child(c); c.queue_free()
	for m in MISSIONS + ["Explore the living room."]:
		var row := PanelContainer.new(); var done: bool = done_missions.has(m)
		row.add_theme_stylebox_override("panel", _sb(Color(0.86, 0.95, 0.89) if done else Color(0.95, 0.96, 0.99), 16, 10)); tasks_list.add_child(row)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); row.add_child(h)
		var ic := Label.new(); ic.text = "✓" if done else "•"; ic.add_theme_font_override("font", font_b); ic.add_theme_font_size_override("font_size", 28)
		ic.add_theme_color_override("font_color", Color(0.16, 0.55, 0.36) if done else Color(0.31, 0.42, 0.93)); h.add_child(ic)
		var vv := VBoxContainer.new(); vv.add_theme_constant_override("separation", -2); h.add_child(vv)
		var l := Label.new(); l.text = m; l.add_theme_font_override("font", font_b); l.add_theme_font_size_override("font_size", 23); l.add_theme_color_override("font_color", Color(0.12, 0.15, 0.25)); vv.add_child(l)
		var lt := Label.new(); lt.text = TR.get(m, ""); lt.add_theme_font_size_override("font_size", 17); lt.add_theme_color_override("font_color", Color(0.36, 0.45, 0.7)); vv.add_child(lt)

var cap_serial := 0
func caption(t: String, speak := true) -> void:
	if House.dormant(self): return   # v33town: a sleeping room shows no caption
	cap_text = t; cap_panel.visible = t != ""
	if cap_panel.visible: StoryUI.claim(cap_panel)   # v32-polish: also when the box was already up (no visibility_changed) -> any other box hides
	if t != "": captioned.emit(t)
	cap_serial += 1
	var my := cap_serial
	get_tree().create_timer(4.5, false).timeout.connect(func(): if my == cap_serial and mode != "busy": cap_panel.visible = false)
	_refresh_text()
	if t != "" and S.voice and speak: Audio.say(t)

func _set_mission(t: String) -> void:
	mission = t; _refresh_text()
	if t == "": Objectives.clear()
	else:
		var trs: String = String(TR.get(t, XTR.get(t, "Dışarı çık." if t == "Go outside." else "")))
		Objectives.set_list([t] if trs == "" else [{"en": t, "tr": trs}])   # v30.5: TR kept
	var mp = hud.get_node_or_null("Mission") if hud else null
	if mp: mp.visible = false

func _refresh_text() -> void:
	cap_en.text = cap_text; cap_tr.text = TR.get(cap_text, XTR.get(cap_text, room_phone.extra_tr(cap_text) if room_phone else "")); cap_tr.visible = S.tr and cap_tr.text != ""
	tr_btn.add_theme_stylebox_override("normal", _sb(Color(0.31, 0.42, 0.93) if S.tr else Color(1, 1, 1, 0.94), 18, 10))
	tr_btn.add_theme_color_override("font_color", Color(1, 1, 1) if S.tr else Color(0.13, 0.16, 0.24))
	mission_lbl.text = mission; mission_tr.text = TR.get(mission, XTR.get(mission, "")); mission_tr.visible = S.tr and mission != ""
	hud.get_node("Mission").visible = false   # v30.5: Objectives only
	cap_en.custom_minimum_size.x = clampf(font_b.get_string_size(cap_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 4, 200, 560)
	cap_tr.custom_minimum_size.x = cap_en.custom_minimum_size.x
	_layout.call_deferred()

func _show_chips(id: String) -> void:
	_hide_chips()
	var head := Label.new(); head.text = "TV" if id == "tv" else String(OBJ[id].name).capitalize(); head.add_theme_font_override("font", font_b)
	head.add_theme_font_size_override("font_size", 20); head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; head.modulate = Color(0.12, 0.15, 0.25)
	var hp := PanelContainer.new(); hp.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.75), 14, 4)); hp.add_child(head)
	hp.size_flags_horizontal = Control.SIZE_SHRINK_END; chips.add_child(hp)
	for v in verbs(id):
		var b := Button.new(); b.text = v[0]; b.custom_minimum_size = Vector2(250, 58); b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func(): Audio.click(); do_verb(id, v)); chips.add_child(b)
	_layout.call_deferred()
	chips_scroll.set_deferred("scroll_vertical", 100000)   # newest layout: start at the bottom (next to the hand button)

func _layout() -> void:
	var vs := hud.size
	cap_panel.size = cap_panel.get_combined_minimum_size()
	cap_panel.position = Vector2(roundf(maxf(12.0, (vs.x - cap_panel.size.x) / 2)), vs.y - 22 - cap_panel.size.y)
	var cs := chips.get_combined_minimum_size()
	var ac: Vector2 = touch.act_center()
	var bottom: float = ac.y + touch.ACT_R
	var h := minf(cs.y, bottom - 100.0)
	chips_scroll.size = Vector2(cs.x, h)
	chips_scroll.position = Vector2(ac.x - touch.ACT_R - 24 - cs.x, bottom - h)
	chips_scroll.visible = chips.get_child_count() > 0

func _hide_chips() -> void:
	for c in chips.get_children(): chips.remove_child(c); c.queue_free()

## front (entrance) door on the south wall: dark wood with a small window, lever handle, thumb-turn lock;
## a coat stand on the left and a shoe bench (shoes + key bowl) on the right. Everything here fades when it hides the player.
func _build_front_door() -> void:
	var fg := Node3D.new(); fg.name = "FrontDoorArea"; add_child(fg)
	var a := DOOR_FRONT.x; var b := DOOR_FRONT.y; var mid := (a + b) / 2
	var wood := Color(0.36, 0.24, 0.16)
	box(Vector3(0.45, WALL_H, 0.1), Vector3(a - 0.275, WALL_H / 2, 3.05), C_WALL, fg)
	box(Vector3(0.45, WALL_H, 0.1), Vector3(b + 0.275, WALL_H / 2, 3.05), C_WALL, fg)
	box(Vector3(b - a + 0.1, WALL_H - 2.17, 0.1), Vector3(mid, (WALL_H + 2.17) / 2, 3.05), C_WALL, fg)
	box(Vector3(0.06, 2.17, 0.14), Vector3(a - 0.03, 1.085, 3.02), C_WHITE, fg); box(Vector3(0.06, 2.17, 0.14), Vector3(b + 0.03, 1.085, 3.02), C_WHITE, fg)
	box(Vector3(b - a + 0.12, 0.06, 0.14), Vector3(mid, 2.17, 3.02), C_WHITE, fg)
	box(Vector3(b - a, 0.1, 0.25), Vector3(mid, -0.045, 3.1), Color(0.5, 0.5, 0.52), fg)      # stone threshold
	var dn := Node3D.new(); dn.name = "front_door"; dn.position = Vector3(a + 0.01, 0, 3.0); fg.add_child(dn); N.front = dn
	var w := b - a - 0.02
	box(Vector3(w, 2.1, 0.06), Vector3(w / 2, 1.05, 0), wood, dn)
	for yy in [0.35, 0.75]: box(Vector3(w - 0.2, 0.025, 0.065), Vector3(w / 2, yy, 0), wood.darkened(0.2), dn)
	box(Vector3(0.3, 0.62, 0.068), Vector3(w / 2, 1.55, 0), Color(0.95, 0.95, 0.93), dn)                 # window frame
	var gl := box(Vector3(0.24, 0.56, 0.07), Vector3(w / 2, 1.55, 0), Color(0.72, 0.85, 0.95), dn, 0.4, 0.4); gl.set_meta("glass", true)
	box(Vector3(0.24, 0.02, 0.072), Vector3(w / 2, 1.55, 0), Color(0.95, 0.95, 0.93), dn)
	var brass := Color(0.85, 0.68, 0.32)
	box(Vector3(0.05, 0.16, 0.012), Vector3(w - 0.11, 1.05, -0.036), brass, dn)                          # handle plate
	box(Vector3(0.14, 0.025, 0.03), Vector3(w - 0.15, 1.08, -0.055), brass, dn)                          # lever
	box(Vector3(0.05, 0.05, 0.012), Vector3(w - 0.11, 1.25, -0.036), brass, dn)                          # lock rose
	N.lock_turn = box(Vector3(0.012, 0.045, 0.02), Vector3(w - 0.11, 1.25, -0.048), brass.darkened(0.3), dn)
	box(Vector3(0.05, 0.16, 0.012), Vector3(w - 0.11, 1.05, 0.036), brass, dn); box(Vector3(0.14, 0.025, 0.03), Vector3(w - 0.15, 1.08, 0.055), brass, dn)
	# doormat inside
	box(Vector3(0.95, 0.014, 0.55), Vector3(mid, 0.007, 2.55), Color(0.42, 0.36, 0.30))
	for k in 5: box(Vector3(0.8, 0.0155, 0.025), Vector3(mid, 0.008, 2.37 + k * 0.09), Color(0.52, 0.45, 0.37))
	# coat stand (left)
	var cs := Vector3(a - 0.62, 0, 2.7)
	cyl(0.18, 0.03, cs + Vector3(0, 0.015, 0), wood.darkened(0.2), fg); cyl(0.022, 1.8, cs + Vector3(0, 0.9, 0), wood, fg)
	_ball(0.04, cs + Vector3(0, 1.82, 0), wood).reparent(fg)
	for k in 4:
		var ang := k * PI / 2 + 0.4; var hp := cs + Vector3(cos(ang) * 0.12, 1.68, sin(ang) * 0.12)
		var hk := box(Vector3(0.14, 0.02, 0.02), cs + Vector3(cos(ang) * 0.06, 1.7, sin(ang) * 0.06), wood.darkened(0.2), fg); hk.rotation.y = -ang
		if k < 2:
			var coat := cushion(Vector3(0.36, 0.85, 0.16), hp + Vector3(0, -0.42, 0), [Color(0.30, 0.38, 0.52), Color(0.72, 0.42, 0.30)][k], fg)
			coat.rotation.y = -ang + PI / 2
	cyl(0.13, 0.08, cs + Vector3(0.05, 1.86, 0.02), Color(0.25, 0.25, 0.28), fg)                        # hat
	obstacles.append(Rect2(cs.x - 0.25, cs.z - 0.25, 0.5, 0.5))
	# shoe bench (right): two shelves, family shoes, my shoes, a key bowl with my keys
	var sb := Vector3(b + 0.95, 0, 2.8)
	box(Vector3(0.85, 0.04, 0.32), sb + Vector3(0, 0.45, 0), C_WOOD, fg); box(Vector3(0.85, 0.025, 0.3), sb + Vector3(0, 0.2, 0), C_WOOD, fg)
	for x in [-0.41, 0.41]: box(Vector3(0.03, 0.45, 0.32), sb + Vector3(x, 0.225, 0), C_WOOD.darkened(0.1), fg)
	for k in 2:
		for s in [-0.05, 0.05]: box(Vector3(0.09, 0.07, 0.24), sb + Vector3(-0.25 + k * 0.18 + s, 0.25, 0), [Color(0.2, 0.2, 0.22), Color(0.9, 0.9, 0.88)][k], fg)
	N.shoes_rack = Node3D.new(); fg.add_child(N.shoes_rack)
	for s in [-0.05, 0.05]:
		box(Vector3(0.09, 0.07, 0.24), sb + Vector3(0.22 + s, 0.25, 0), Color(0.75, 0.15, 0.18), N.shoes_rack)
		box(Vector3(0.09, 0.012, 0.22), sb + Vector3(0.22 + s, 0.214, 0), C_WHITE, N.shoes_rack)
	cyl(0.1, 0.05, sb + Vector3(0.22, 0.495, 0.0), C_SAGE, fg)
	N.keys_hook = Node3D.new(); fg.add_child(N.keys_hook)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.018; tm.outer_radius = 0.026; ring.mesh = tm
	ring.material_override = _mat(Color(0.8, 0.8, 0.82)); ring.position = sb + Vector3(0.22, 0.53, 0); N.keys_hook.add_child(ring)
	for k in 2:
		var ky := box(Vector3(0.012, 0.006, 0.06), sb + Vector3(0.2 + k * 0.04, 0.528, 0.03), [Color(0.85, 0.7, 0.35), Color(0.75, 0.75, 0.78)][k], N.keys_hook); ky.rotation.y = 0.4 - k * 0.8
	_spl(prop("plantSmall3", sb + Vector3(-0.25, 0.47, 0), 0, 0.22, 0.0, fg))
	obstacles.append(Rect2(sb.x - 0.45, sb.z - 0.2, 0.9, 0.42))
	N.front_meshes = fg.find_children("*", "MeshInstance3D", true, false).filter(func(m): return (m as MeshInstance3D).material_override is StandardMaterial3D)
	reg("front", "front door", Vector3(mid, 1.2, 3.0), Vector3(b - 0.2, 0, 2.15), Vector3(0, 0, 1))
	reg("entry", "shoe rack", sb + Vector3(0, 0.5, 0), Vector3(sb.x, 0, 2.15), Vector3(0, 0, 1))

## small details: wall clock, table lamp on the side table, sideboard decor
func _build_details() -> void:
	var ck := Vector3(0.15, 1.95, -2.97)
	var face := cyl(0.17, 0.03, ck, C_WHITE); face.rotation.x = PI / 2
	var rim := cyl(0.185, 0.025, ck + Vector3(0, 0, -0.005), C_DARK); rim.rotation.x = PI / 2
	for k in 12:
		var t := box(Vector3(0.012, 0.03, 0.005), ck + Vector3(sin(k * PI / 6) * 0.14, cos(k * PI / 6) * 0.14, 0.018), C_DARK); t.rotation.z = -k * PI / 6
	var hh := box(Vector3(0.016, 0.09, 0.006), ck + Vector3(0.03, 0.03, 0.022), C_DARK); hh.rotation.z = -PI / 4 * 1.0
	var mh := box(Vector3(0.01, 0.13, 0.006), ck + Vector3(0, 0.06, 0.026), C_DARK)
	_ball(0.012, ck + Vector3(0, 0, 0.03), C_CORAL)
	# table lamp on the side table by the sofa
	var tl := Vector3(2.98, 0.5, -1.58)
	cyl(0.05, 0.02, tl + Vector3(0, 0.01, 0), C_DARK); cyl(0.01, 0.2, tl + Vector3(0, 0.11, 0), Color(0.75, 0.62, 0.38))
	var sh := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.085; cm.height = 0.12; sh.mesh = cm
	sh.position = tl + Vector3(0, 0.25, 0); add_child(sh); N.tlamp_shade = sh
	# sideboard: a small vase and a candle
	cyl(0.04, 0.16, Vector3(3.95, 0.84, -2.7), C_CORAL.lightened(0.2)); cyl(0.025, 0.08, Vector3(3.8, 0.8, -2.66), C_CREAM)

# ============================================================ family breakfast hook
## Call from the bedroom's phone pickup: spawns the player's family (save.json "family": up to 6 members incl. pets,
## same keys as the phone's family creator: role, name, skin, hair, hcol, cloth, child, pron, col) at the dining table
## having breakfast. Humans sit on the dining chairs (2 extra end chairs appear for 5-6 people), pets stay near the table.
## Safe to call again: the previous breakfast is removed first.
const FAM_HAIR := [Color(0.08, 0.07, 0.06), Color(0.35, 0.2, 0.1), Color(0.9, 0.75, 0.42), Color(0.66, 0.25, 0.12), Color(0.62, 0.62, 0.64), Color(0.93, 0.93, 0.92)]
const FAM_CLOTH := [Color(0.84, 0.26, 0.26), Color(0.2, 0.38, 0.8), Color(0.2, 0.6, 0.38), Color(0.95, 0.78, 0.25), Color(0.52, 0.3, 0.75), Color(0.12, 0.12, 0.14)]
const FAM_PET := [Color(0.6, 0.4, 0.22), Color(0.2, 0.2, 0.22), Color(0.97, 0.97, 0.96), Color(0.6, 0.62, 0.66), Color(0.95, 0.55, 0.2), Color(0.9, 0.72, 0.35)]
const SHE_ROLES := ["mother", "sister", "grandmother", "wife", "daughter", "aunt"]
const PET_ROLES := ["dog", "cat", "bird", "fish", "rabbit", "hamster", "turtle"]
var breakfast_root: Node3D
var breakfast_members: Array = []     # [{"data": Dictionary, "node": Node3D, "seat": String}]

## house.15 merge: spawn at the door we came through, family breakfast from save.json, north doors change scene
## house.24: omni lights with no specular / no distance fade, so floor/walls don't flare as the camera moves
func _stable_lights() -> void:
	for l in find_children("*", "OmniLight3D", true, false):
		l.light_specular = 0.0; l.distance_fade_enabled = false; l.shadow_enabled = false; l.omni_attenuation = 1.0

func _house_enter() -> void:
	_bk_load(); _living_load(); _apply_states()
	D2.load_lines(XTR)   # v31: TR for the day-2 captions / missions
	var from: String = App.came_from
	if from in ["bedroom", "bathroom"]:
		var dv: Vector2 = DOOR_BED if from == "bedroom" else DOOR_BATH
		hero.position = Vector3((dv.x + dv.y) / 2, 0, -2.1); hero.rotation.y = 0.0
	elif from == "outside":   # house.23: back from the street, just inside the front door, facing into the room
		hero.position = Vector3((DOOR_FRONT.x + DOOR_FRONT.y) / 2, 0, 2.2); hero.rotation.y = PI
	if FileAccess.file_exists(SavePath.P()):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SavePath.P()))
		if d is Dictionary and (d.get("family_breakfast", false) or d.get("has_phone", false)) and d.get("state", {}) is Dictionary:
			var fam = d.state.get("family", [])
			if fam is Array and not fam.is_empty(): spawn_family_breakfast(fam)
	if table_clean: _clear_table(false)
	if _fam_at_tv_pending and not breakfast_members.is_empty(): family_at_tv_now()
	_fam_reg()
	exit_requested.connect(func(t: String):
		if "--qa" in OS.get_cmdline_user_args(): return
		App.came_from = "livingroom"
		await Audio.wait_idle(12.0)
		if t == "outside":   # house.23: blue's outdoor world (front door of the home lot)
			S.front = "closed"; S.lock = "unlocked"
			if room_phone: room_phone.save()
			App.patch_save({"living_front": "closed"})
			Life.event("going_out"); StoryNav.goto(Game.WORLD_SCENE, "lot:home"); return
		StoryNav.room(self, "res://main.tscn" if t == "bedroom" else "res://bathroom.tscn"))   # v32wh: walk through the door (same scene; House.go defers like call_deferred did)

func spawn_family_breakfast(family_data: Array) -> Array:
	clear_family_breakfast()
	breakfast_root = Node3D.new(); breakfast_root.name = "FamilyBreakfast"; add_child(breakfast_root)
	var humans := []; var pets := []
	for m in family_data.slice(0, 6):
		if typeof(m) != TYPE_DICTIONARY: continue
		if PET_ROLES.has(String(m.get("role", ""))): pets.append(m)
		elif String(m.get("role", "")) != "": humans.append(m)
	# chairs: 4 around the table (yaw 0 = faces +Z), 2 end chairs only when needed
	var chairs := DINE_CHAIRS
	if humans.size() > 4:
		for k in [4, 5]:
			if k - 4 < humans.size() - 4: _dining_chair(DINE_C + chairs[k][1], chairs[k][2], [C_CREAM, C_SAGE][k - 4], breakfast_root)
	for k in range(4, humans.size()): _place_setting(k, breakfast_root)
	for i in humans.size():
		var m: Dictionary = humans[i]; var c: Array = chairs[i]
		var yaw: float = c[2]; var f := Vector3(sin(yaw), 0, cos(yaw))
		SEATS[c[0]] = {"hips": DINE_C + c[1] - f * 0.03, "top": 0.475, "yaw": yaw, "obj": "dining"}
		var _sk: String = c[0]
		var ch := DemoCharacter.new(); ch.name = "Family_%d" % i; breakfast_root.add_child(ch)
		var g := "women" if (SHE_ROLES.has(m.get("role", "")) or (m.get("role", "") == "cousin" and m.get("pron", "she") == "she")) else "men"
		ch.setup(g)
		ch.skin = int(m.get("skin", 1)); ch.hair_color = FAM_HAIR[clampi(int(m.get("hcol", 1)), 0, 5)]; ch.top_color = FAM_CLOTH[clampi(int(m.get("cloth", 1)), 0, 5)]
		ch.outfit = {"Head": int(m.get("hair", 0)), "Body": 0, "Legs": 1 if g == "women" else 0, "Feet": 0}
		if m.get("child", false): ch.set_child(true)
		else: ch.set_height("medium")
		ch._refresh()
		SEATS[_sk].hips = DINE_C + c[1] - f * (0.03 + _body_back(ch))   # house.26: per-body seat depth
		sit_down(ch, c[0], false)
		breakfast_members.append({"data": m, "node": ch, "seat": c[0]})
		breakfast_members[-1]["tw"] = _breakfast_loop(ch, yaw, i)
	var pet_spots := [[Vector3(4.55, 0, 1.75), 0.9], [Vector3(6.75, 0, 1.85), -0.6], [Vector3(6.85, 0, -0.1), -2.2], [Vector3(4.5, 0, -0.05), 2.3]]
	var pi := 0
	for m in pets:
		var col: Color = FAM_PET[clampi(int(m.get("col", 0)), 0, 5)]
		var r: String = m.role; var pn: Node3D
		if r == "fish": pn = _pet_fishbowl(col, Vector3(4.2, 0.76, -2.75))
		elif r == "bird": pn = _pet_bird(col, Vector3(7.0, 0, -2.45))
		else:
			var ps: Array = pet_spots[pi % pet_spots.size()]; pi += 1
			pn = _pet_body(r, col, ps[0], ps[1])
		pn.name = "Pet_" + r
		breakfast_members.append({"data": m, "node": pn, "seat": ""})
	_build_grid_obstacles_refresh()
	return breakfast_members

func clear_family_breakfast() -> void:
	if breakfast_root: breakfast_root.queue_free()
	breakfast_root = null; breakfast_members.clear()
	for k in SEATS.keys(): if String(k).begins_with("dine_"): SEATS.erase(k)

func _build_grid_obstacles_refresh() -> void:
	pass   # chairs/pets stay inside the dining area that is already blocked for walking

func _dining_chair(p: Vector3, yaw: float, col: Color, parent: Node) -> void:
	var ch := Node3D.new(); ch.position = p; ch.rotation.y = yaw; parent.add_child(ch)
	box(Vector3(0.42, 0.05, 0.4), Vector3(0, 0.45, 0), col, ch); box(Vector3(0.42, 0.42, 0.04), Vector3(0, 0.7, -0.19), col, ch)
	for lx in [-0.18, 0.18]:
		for lz in [-0.17, 0.17]: box(Vector3(0.03, 0.44, 0.03), Vector3(lx, 0.22, lz), C_WOOD.darkened(0.12), ch)

# house.24.2: chairs pulled back from the table (edges at z +-0.51 / x +-0.81) so knees, legs and arms stay clear
## house.26: breakfast camera framed from the occupied seats: across the table from the player (face visible), raised,
## pulled back until every seated person fits in the view
func _breakfast_frame(me: Vector3, f: Vector3) -> Dictionary:
	var pts: Array = [me]
	for bm in humans(): pts.append(to_local(bm.node.global_position))
	var ctr := Vector3.ZERO
	for p in pts: ctr += p
	ctr /= float(pts.size()); ctr.y = 0.9
	var r := 0.6
	for p in pts: r = maxf(r, Vector2(p.x - ctr.x, p.z - ctr.z).length() + 0.45)
	var fov: float = cam.fov if cam else 60.0
	var dist := r / tan(deg_to_rad(fov * 0.5)) * 1.1
	var dir := (f * 0.8 + Vector3(f.z, 0, -f.x) * 0.35).normalized()   # from the far side of the table, slightly to the side
	return {"pos": ctr + dir * dist * 0.8 + Vector3(0, dist * 0.6, 0), "at": ctr}

## house.26: taller / bigger bodies sit a little further back from the table edge (child sits closer)
func _body_back(ch: DemoCharacter) -> float:
	var sc: float = ch.model.scale.x if ch and ch.model else 1.0
	var b := {"thin": -0.01, "average": 0.0, "fat": 0.05}.get(ch.build if ch else "average", 0.0) as float
	return clampf((sc - 1.0) * 0.35 + b, -0.06, 0.1)

const DINE_CHAIRS := [["dine_n1", Vector3(-0.4, 0, -0.74), 0.0], ["dine_s1", Vector3(0.4, 0, 0.74), PI], ["dine_n2", Vector3(0.4, 0, -0.74), 0.0],
	["dine_s2", Vector3(-0.4, 0, 0.74), PI], ["dine_w", Vector3(-1.12, 0, 0), PI / 2], ["dine_e", Vector3(1.12, 0, 0), -PI / 2]]
## Turkish breakfast spread on the dining table (always there): tablecloth, 4 place settings, centre dishes
func _table_spread() -> void:
	var top := 0.76; var c := DINE_C
	box(Vector3(1.62, 0.006, 1.02), c + Vector3(0, top + 0.003, 0), Color(0.97, 0.95, 0.9))                       # tablecloth
	for x in [-0.81, 0.81]: box(Vector3(0.006, 0.16, 1.02), c + Vector3(x, top - 0.075, 0), Color(0.97, 0.95, 0.9))
	for z in [-0.51, 0.51]: box(Vector3(1.62, 0.16, 0.006), c + Vector3(0, top - 0.075, z), Color(0.97, 0.95, 0.9))
	for k in 6: box(Vector3(1.62, 0.0065, 0.02), c + Vector3(0, top + 0.0035, -0.4 + k * 0.16), C_CORAL.lightened(0.35))     # stripes
	var n0 := get_child_count()   # house.18: everything below is food / dishes (N.food, cleared after breakfast)
	for i in 4: _place_setting(i, self)
	var t := c + Vector3(0, top + 0.006, 0)
	# teapot (double Turkish çaydanlık)
	cyl(0.07, 0.11, t + Vector3(-0.2, 0.055, 0), Color(0.82, 0.83, 0.86)); cyl(0.05, 0.08, t + Vector3(-0.2, 0.15, 0), Color(0.82, 0.83, 0.86))
	_ball(0.015, t + Vector3(-0.2, 0.2, 0), C_DARK); var sp := cyl(0.01, 0.07, t + Vector3(-0.27, 0.08, 0), Color(0.82, 0.83, 0.86)); sp.rotation.z = 0.8
	# bread basket
	box(Vector3(0.26, 0.06, 0.16), t + Vector3(0.2, 0.03, -0.05), Color(0.7, 0.5, 0.3))
	for k in 3: var br := box(Vector3(0.07, 0.04, 0.12), t + Vector3(0.12 + k * 0.08, 0.07, -0.05), Color(0.88, 0.66, 0.36)); br.rotation.x = 0.2 * (k - 1)
	# plates: cheese, olives, tomatoes + cucumbers, eggs, jam + honey
	cyl(0.07, 0.01, t + Vector3(0.45, 0.005, -0.15), C_WHITE); box(Vector3(0.08, 0.03, 0.06), t + Vector3(0.45, 0.025, -0.15), Color(0.98, 0.96, 0.86))
	cyl(0.06, 0.012, t + Vector3(0.0, 0.006, 0.18), C_SAGE.lightened(0.3))
	for k in 6: _ball(0.012, t + Vector3(-0.025 + (k % 3) * 0.025, 0.02, 0.165 + (k / 3) * 0.025), Color(0.12, 0.14, 0.1))
	cyl(0.08, 0.01, t + Vector3(0.0, 0.005, -0.2), C_WHITE)
	for k in 3: _ball(0.022, t + Vector3(-0.04 + k * 0.04, 0.025, -0.22), Color(0.88, 0.2, 0.15))
	for k in 3: var cu := cyl(0.018, 0.006, t + Vector3(-0.03 + k * 0.03, 0.015, -0.16), Color(0.45, 0.7, 0.3), self, 0.0, 10); cu.rotation.x = 0.15
	for k in 2: _ball(0.024, t + Vector3(0.33 + k * 0.06, 0.03, 0.15), Color(0.98, 0.97, 0.94)); cyl(0.02, 0.025, t + Vector3(0.33 + k * 0.06, 0.012, 0.15), Color(0.95, 0.85, 0.5))
	cyl(0.03, 0.06, t + Vector3(-0.45, 0.03, 0.12), Color(0.75, 0.12, 0.18)); cyl(0.032, 0.012, t + Vector3(-0.45, 0.066, 0.12), Color(0.9, 0.9, 0.9))   # jam
	cyl(0.03, 0.06, t + Vector3(-0.45, 0.03, -0.12), Color(0.95, 0.68, 0.15)); cyl(0.032, 0.012, t + Vector3(-0.45, 0.066, -0.12), Color(0.9, 0.9, 0.9))  # honey
	var food := Node3D.new(); food.name = "TableFood"; food.position = Vector3(0, top, 0)
	var kids := get_children().slice(n0)
	add_child(food); N.food = food
	for ch in kids: ch.reparent(food)

func _place_setting(i: int, parent0: Node) -> void:
	var parent := Node3D.new(); parent.set_meta("setting", true); parent0.add_child(parent)
	var ch: Array = DINE_CHAIRS[i]; var yaw: float = ch[2]; var f := Vector3(sin(yaw), 0, cos(yaw))
	var pp: Vector3 = DINE_C + ch[1] + f * (0.5 if i < 4 else 0.44); pp.y = 0.766
	var side := Vector3(f.z, 0, -f.x)
	cyl(0.1, 0.012, pp, C_WHITE, parent)
	var eg := _ball(0.025, pp + Vector3(0.02, 0.02, 0), Color(1, 0.97, 0.9)); eg.reparent(parent); eg.scale = Vector3(1, 0.4, 1)
	var yk := _ball(0.012, pp + Vector3(0.02, 0.027, 0), Color(1, 0.72, 0.1)); yk.reparent(parent)
	box(Vector3(0.05, 0.004, 0.05), pp + side * 0.16 + Vector3(0, 0.002, 0), Color(0.9, 0.95, 1.0), parent)              # saucer
	cyl(0.022, 0.07, pp + side * 0.16 + Vector3(0, 0.04, 0), Color(0.78, 0.3, 0.12), parent, 0.0, 12)                   # tea glass
	var nap := box(Vector3(0.1, 0.006, 0.12), pp - side * 0.16 + Vector3(0, 0.0, 0), C_SAGE.lightened(0.2), parent); nap.rotation.y = yaw
	var fk := box(Vector3(0.012, 0.005, 0.14), pp - side * 0.16 + Vector3(0, 0.005, 0), Color(0.8, 0.8, 0.82), parent); fk.rotation.y = yaw

func _ball2(r: float, pos: Vector3, col: Color, parent: Node) -> MeshInstance3D:
	var mi := _ball(r, pos, col); mi.reparent(parent); return mi

## idle eating/drinking: every few seconds one arm lifts to the mouth and back (bone offsets on the sitting pose)
func _breakfast_loop(ch: DemoCharacter, yaw: float, i: int) -> Tween:
	var f := Vector3(sin(yaw), 0, cos(yaw)); var ax := Vector3(f.z, 0, -f.x)
	var arm := "R" if i % 2 == 0 else "L"
	var tw := ch.create_tween().set_loops()
	tw.tween_interval(0.8 + i * 0.7)
	for step in [[-0.55, -1.2, 0.18, 0.7], [-0.55, -1.2, 0.18, 0.9], [0.0, 0.0, 0.0, 0.6]]:
		tw.tween_method(func(a): ch.bone_offsets["UpperArm." + arm] = [ax, a * step[0]]; ch.bone_offsets["LowerArm." + arm] = [ax, a * step[1]]; ch.bone_offsets["Neck"] = [ax, a * step[2]],
			0.0 if step[0] != 0.0 else 1.0, 1.0 if step[0] != 0.0 else 0.0, step[3]).set_trans(Tween.TRANS_SINE)
		if step[0] != 0.0: break
	tw.tween_interval(0.9)
	tw.tween_method(func(a): ch.bone_offsets["UpperArm." + arm] = [ax, -0.55 * a]; ch.bone_offsets["LowerArm." + arm] = [ax, -1.2 * a]; ch.bone_offsets["Neck"] = [ax, 0.18 * a], 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(2.0 + (i % 3) * 0.8)
	return tw

func _pet_body(kind: String, col: Color, p: Vector3, yaw: float) -> Node3D:
	var n := Node3D.new(); n.position = p; n.rotation.y = yaw; breakfast_root.add_child(n)
	var dims := {"dog": [0.5, 0.26, 0.24, 0.13], "cat": [0.36, 0.18, 0.16, 0.1], "rabbit": [0.26, 0.18, 0.18, 0.08], "hamster": [0.13, 0.08, 0.1, 0.05], "turtle": [0.24, 0.09, 0.2, 0.05]}
	var d: Array = dims.get(kind, dims.cat)
	var L: float = d[0]; var H: float = d[1]; var W: float = d[2]; var hr: float = d[3]
	var legs := 0.0 if kind in ["hamster", "turtle", "rabbit"] else H * 0.6
	var body := cushion(Vector3(W, H, L), Vector3(0, legs + H * 0.5, 0), col.darkened(0.25) if kind == "turtle" else col, n)
	if legs > 0:
		for lx in [-W * 0.3, W * 0.3]:
			for lz in [-L * 0.3, L * 0.3]: cyl(0.025 if kind == "dog" else 0.018, legs + 0.02, Vector3(lx, (legs + 0.02) / 2, lz), col.darkened(0.1), n, 0.0, 8)
	var head := Node3D.new(); head.position = Vector3(0, legs + H * (0.95 if kind != "turtle" else 0.4), L * 0.5); n.add_child(head)
	var hm := _ball(hr, Vector3.ZERO, col if kind != "turtle" else Color(0.55, 0.65, 0.35)); hm.reparent(head, false)
	for ex in [-hr * 0.45, hr * 0.45]:
		var e := _ball(hr * 0.16, Vector3(ex, hr * 0.25, hr * 0.85), C_DARK); e.reparent(head, false)
	var nose := _ball(hr * 0.18, Vector3(0, -hr * 0.05, hr * 1.0), Color(0.15, 0.1, 0.1)); nose.reparent(head, false)
	match kind:
		"dog":
			for ex in [-1, 1]:
				var ear := box(Vector3(0.035, hr * 0.9, hr * 0.5), Vector3(ex * hr * 0.85, hr * 0.1, 0), col.darkened(0.3), head); ear.rotation.z = ex * 0.25
		"cat":
			for ex in [-1, 1]:
				var ear := box(Vector3(hr * 0.5, hr * 0.6, 0.02), Vector3(ex * hr * 0.55, hr * 0.9, 0), col, head); ear.rotation.z = ex * -0.5
		"rabbit":
			for ex in [-1, 1]:
				var ear := cushion(Vector3(0.035, hr * 2.4, 0.02), Vector3(ex * hr * 0.4, hr * 1.7, -0.01), col, head); ear.rotation.z = ex * -0.15
		"turtle":
			hm.material_override = _mat(Color(0.55, 0.65, 0.35))
	if kind in ["dog", "cat"]:
		var tail := Node3D.new(); tail.position = Vector3(0, legs + H * 0.75, -L * 0.48); n.add_child(tail)
		var tm := cyl(0.018, L * 0.5, Vector3(0, L * 0.22, -0.02), col.darkened(0.1), tail, 0.0, 8); tm.rotation.x = -0.6
		var ttw := tail.create_tween().set_loops()
		ttw.tween_property(tail, "rotation:z", 0.5, 0.35 if kind == "dog" else 1.2).set_trans(Tween.TRANS_SINE)
		ttw.tween_property(tail, "rotation:z", -0.5, 0.35 if kind == "dog" else 1.2).set_trans(Tween.TRANS_SINE)
	# breathing + looking around
	var btw := n.create_tween().set_loops()
	btw.tween_property(body, "scale:y", H * 1.04, 0.9).set_trans(Tween.TRANS_SINE); btw.tween_property(body, "scale:y", H, 0.9).set_trans(Tween.TRANS_SINE)
	var htw := head.create_tween().set_loops()
	htw.tween_interval(1.5); htw.tween_property(head, "rotation:y", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	htw.tween_interval(1.2); htw.tween_property(head, "rotation:y", -0.3, 0.8).set_trans(Tween.TRANS_SINE)
	if kind in ["dog", "cat"]:      # a food bowl in front
		cyl(0.08, 0.04, Vector3(0, 0.02, L * 0.5 + 0.2), C_CORAL, n)
	return n

func _pet_fishbowl(col: Color, p: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = p; breakfast_root.add_child(n)
	var g := _ball(0.12, Vector3(0, 0.12, 0), Color(0.7, 0.88, 1.0)); g.reparent(n, false); g.material_override = _mat(Color(0.7, 0.88, 1.0), 0.0, 0.35)
	var fish := Node3D.new(); fish.position = Vector3(0, 0.12, 0); n.add_child(fish)
	var fb := cushion(Vector3(0.025, 0.04, 0.07), Vector3(0.05, 0, 0), col, fish)
	var tw := fish.create_tween().set_loops(); tw.tween_property(fish, "rotation:y", TAU, 6.0).from(0.0)
	return n

func _pet_bird(col: Color, p: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = p; breakfast_root.add_child(n)
	cyl(0.16, 0.02, Vector3(0, 0.01, 0), C_DARK, n); cyl(0.012, 1.3, Vector3(0, 0.65, 0), C_WOOD, n)
	var pr := box(Vector3(0.3, 0.02, 0.02), Vector3(0, 1.3, 0), C_WOOD, n)
	var bd := Node3D.new(); bd.position = Vector3(0, 1.31, 0); n.add_child(bd)
	cushion(Vector3(0.06, 0.08, 0.1), Vector3(0, 0.04, 0), col, bd)
	var hd := _ball(0.03, Vector3(0, 0.1, 0.03), col); hd.reparent(bd, false)
	var bk := box(Vector3(0.012, 0.012, 0.025), Vector3(0, 0.1, 0.065), Color(0.95, 0.65, 0.2), bd)
	var tw := bd.create_tween().set_loops(); tw.tween_interval(1.0); tw.tween_property(bd, "rotation:y", 0.8, 0.2); tw.tween_interval(0.8); tw.tween_property(bd, "rotation:y", -0.4, 0.2)
	return n


## house.17: right arm (the mug hand) to the mouth; the "drink" clip raised the left hand
func _tea_arm(p: Array, t: float) -> void:
	for e in [["UpperArm.R", Vector3.RIGHT, p[0]], ["LowerArm.R", Vector3.RIGHT, p[1]], ["Shoulder.R", Vector3.UP, p[2]]]:
		var bone: String = e[0]; var ax: Vector3 = e[1]
		var cur: float = hero.bone_offsets[bone][1] if hero.bone_offsets.has(bone) else 0.0
		create_tween().tween_method(func(a): hero.bone_offsets[bone] = [ax, a], cur, float(e[2]), t)

## v30.5: visible south (camera-side) wall: a solid low part (0..LOW) with the door gap, the upper part + lintel fade like
## the side walls when they hide the player (walls_s). The shadow-only N.closed box stays as before (daylight / cine shots).
var walls_s: Array = []
const WallFade := preload("res://scripts/props/wall_fade.gd")   # v32-polish: shared wall-fade helper
var wall_fade: Node
## v32-polish: south walls fade through the shared helper; force_fade(true) during both breakfasts (day 1 here, day 2 in day2_morning.gd)
func _wall_fade_setup() -> void:
	wall_fade = WallFade.attach(self, func(): return cam.global_position if is_instance_valid(cam) else Vector3.INF, func(): return hero.global_position if is_instance_valid(hero) else Vector3.INF)
	for w in walls_s: wall_fade.register(w)
	for w in walls_l: wall_fade.register_occluder(w, {"group": "L", "out": func(): return cam.position.x < -3.5})   # v33: side walls fade only while they hide the player
	for w in walls_r: wall_fade.register_occluder(w, {"group": "R", "out": func(): return cam.position.x > EX})
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
