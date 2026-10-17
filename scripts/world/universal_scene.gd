## UniversalScene: base of every world_dev scene (outdoor world, stand-in house). Hooks the scene into the house's
## universal features exactly like english_game_3dv2/scripts/bathroom.gd does:
##   * shared GameHUD (ui/shared) + CameraRig (zoom / rotate)
##   * bedroom phone + pocket take_out/screen/put_away (scripts/room_phone.gd) on the always-visible HUD phone button
##   * shared pause / main menu (scripts/game_menu.gd: settings voice/gender/build/height, Main menu -> menu.tscn)
##   * queued captions: caption() / say_line() / voice_idle() / caption_if_free() over Audio's single voice queue.
##     A line never cuts or drops another one; un-awaited calls keep their order (ticket queue).
##   * shared state: room_phone.S == save.json "state" (look, job, family, voice, tr ...), world progress in "world".
class_name UniversalScene
extends Node3D

const GameMenu = preload("res://scripts/game_menu.gd")

var player: WorldPlayer
var hud: GameHUD
var cam: CameraRig
var room_phone: Node
var menu: Node
var phone_btn: Button
var frozen := false
var _mute_next := false
var _ticket := 0
var _serving := 0

## host interface used by room_phone.gd / game_menu.gd / pocket_phone.gd
var mode := "play":
	set(v):
		mode = v
		if player: player.frozen = v != "play"
var stick: Vector2:
	get: return player.stick if player else Vector2.ZERO
	set(v): if player: player.stick = v
var hero: DemoCharacter:
	get: return player.hero if player else null
var S: Dictionary:
	get: return room_phone.S if room_phone else {"voice": true, "tr": false}

## call after player, hud and cam exist
func setup_universal(place_en: String, place_tr: String) -> void:
	hud.player = player; hud.camera = cam
	hud.tr_func = func(en: String) -> String:
		var t := Lines.tr_of(en)
		return t if t != "" else (String(room_phone.extra_tr(en)) if room_phone and room_phone.has_method("extra_tr") else "")
	hud.voice_func = func(en: String) -> void: if S.get("voice", true) and not _mute_next and not voice_busy(): say(en)
	room_phone = load("res://scripts/room_phone.gd").new(); add_child(room_phone)
	room_phone.setup(self, hud.phone.get_parent(), hud.phone_btn)
	# v28 blue: no outdoor override any more; App.has_phone (save.json "has_phone", loaded by room_phone.setup) decides
	phone_btn = hud.phone_btn; phone_btn.visible = App.has_phone
	var gm := GameMenu.new(); gm.setup(self, place_en, func(): hud.set_paused(false))
	hud.pause_menu.get_parent().add_child(gm); hud.pause_menu.queue_free(); hud.pause_menu = gm; menu = gm
	S["tr"] = App.tr_saved(); hud.set_tr(S.tr)
	if hud.has_method("set_place"): hud.set_place(place_en, place_tr)
	Audio.voice_player.volume_db = 0.0 if S.get("voice", true) else -80.0
	Game.apply_character(player, S)

func open_phone() -> void:
	if mode == "play": room_phone.open_phone()

func _hide_chips() -> void:
	if hud: hud._hide_chips()

## game_menu.gd settings (gender/build/height) call this: persist + broadcast so every scene/actor stays in sync
func _apply_character() -> void:
	Game.refresh_character(S)

func save_game() -> void:
	if room_phone: room_phone.save()
	if player: WorldState.player_pos = player.global_position
	WorldState.save_game()

func _to_main_menu() -> void:
	save_game(); get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")

# ------------------------------------------------------------ captions + voice (bathroom.gd v13b/v13c timing)
func voice_busy() -> bool: return Audio.is_speaking()

func voice_idle(tail := 0.4) -> void:
	var t := 0.0
	var spoke := voice_busy()
	while voice_busy() and t < 8.0:
		if not is_inside_tree(): return   # v31: the scene was left mid-line
		await get_tree().process_frame; t += get_process_delta_time()
	if spoke and tail > 0.0 and is_inside_tree(): await get_tree().create_timer(tail, false).timeout

func clip_len(t: String) -> float: return Voice.clip_len(t) if Voice.has_clip(t) else 0.0

## show + speak one line. Waits for its turn (earlier lines, the clip still playing), so nothing is cut or dropped.
func caption(t: String, speak = true) -> void:
	if speak is String: speak = true          # legacy (en, tr) calls
	_ticket += 1; var my := _ticket
	while _serving != my - 1:
		if not is_inside_tree(): return
		await get_tree().process_frame
	if t != "" and speak and S.get("voice", true): await voice_idle(0.05)
	if not is_inside_tree(): return
	_mute_next = true; hud.caption(t, maxf(4.5, clip_len(t) + 1.0)); _mute_next = false
	if t != "" and speak and S.get("voice", true): say(t)
	_serving = my
	if room_phone: room_phone.S.tr = hud.show_tr

## speak a line and let it finish before the next animation step starts
func say_line(t: String) -> void:
	await caption(t)
	if S.get("voice", true) and is_inside_tree(): await voice_idle(0.15)

## ambient lines (walking ...): skipped while another line is queued or being spoken
func caption_if_free(t: String) -> void:
	if not voice_busy() and _serving == _ticket: await caption(t)

func say(t: String) -> void: Voice.say(t)
