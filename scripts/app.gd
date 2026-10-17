extends Node
## Menu state: settings, save detection, UI strings (TR/EN), word voice clips.

## >>> INTEGRATION HOOK: the game's main scene (english_game_3dv2/main.tscn). <<<
const GAME_SCENE := "res://main.tscn"
## 3dv2 has no save system yet, so the menu uses this path. The game should write it.
var SAVE_PATH: String = SavePath.P()   # v29.1: --save-path= / GAME_SAVE_PATH override for QA
const SETTINGS_PATH := "user://menu_settings.cfg"

var settings := {"lang": "tr", "volume": 0.8, "sfx": 0.8, "narrator": "f", "narrator_manual": false}   # narrator-voices: f/m/c/g (Audio.set_narrator)
## v13: true once the phone was picked up from the bedside table; carried in every room (save.json "has_phone")
var has_phone := false
var family_breakfast := false   # house.16: family at the dining table (set at phone pickup / family creation)
var day := 1   # house.17: in-game day (save.json "day"); tidy living-room states last until it changes
var bath_done := false   # house.17: bathroom routine finished (save.json "bath_done")
var came_from := ""   # house.15: room the player came from (bedroom/bathroom)
var continue_requested := false   # the game can read App.continue_requested / App.load_save()
var _word_index: Dictionary = {}
var _word_file: FileAccess
var _voice: AudioStreamPlayer

const STR := {
	"subtitle": ["İngilizce öğren · A1–A2", "Learn English · A1–A2"],
	"new_game": ["Yeni Oyun", "New Game"],
	"continue": ["Devam Et", "Continue"],
	"grammar": ["Dilbilgisi Notları", "Grammar Notes"],
	"vocab": ["Kelimeler", "Vocabulary"],
	"settings": ["Ayarlar", "Settings"],
	"back": ["Geri", "Back"],
	"close": ["Kapat", "Close"],
	"language": ["Arayüz dili", "Menu language"],
	"volume": ["Ses düzeyi", "Volume"],
	"sfx": ["Efekt sesleri", "Sound effects"],
	"narrator": ["Anlatıcı sesi", "Narrator voice"],
	"narrator_f": ["Kadın", "Female"], "narrator_m": ["Erkek", "Male"], "narrator_c": ["Erkek çocuk", "Boy"], "narrator_g": ["Kız çocuk", "Girl"],
	"use": ["Ne zaman kullanılır?", "Meaning and use"],
	"form": ["Yapı", "Form"],
	"table": ["Tablo", "Form table"],
	"positive": ["Olumlu cümleler", "Positive"],
	"negative": ["Olumsuz cümleler", "Negative"],
	"question": ["Soru ve kısa cevap", "Questions and short answers"],
	"mistakes": ["Sık yapılan hatalar", "Common mistakes"],
	"wrong": ["Yanlış", "Wrong"],
	"right": ["Doğru", "Right"],
	"verbs": ["Fiiller", "Verbs"],
	"nouns": ["İsimler", "Nouns"],
	"adjectives": ["Sıfatlar", "Adjectives"],
	"tap_hint": ["Dinlemek için mavi düğmeye dokun.", "Tap the blue button to listen."],
	"no_game": ["Oyun sahnesi bu geliştirme sürümünde yok: ", "Game scene is not in this dev build: "],
	"words": ["kelime", "words"],
}

func t(key: String) -> String:
	var a: Array = STR.get(key, [key, key])
	return a[0] if settings.lang == "tr" else a[1]

func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cf.get_value("menu", k, settings[k])
	apply_volume()
	Audio.set_narrator(String(settings.narrator))
	var f := FileAccess.open("res://data/word_voice_index.json", FileAccess.READ)
	if f:
		_word_index = JSON.parse_string(f.get_as_text())
	_word_file = FileAccess.open("res://voice/words.bin", FileAccess.READ)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)

## narrator-voices: change + persist the narrator voice (user://menu_settings.cfg, shared by every scene)
func set_narrator(v: String, manual := true) -> void:   # menu = manual override (kept until the next character creation)
	settings.narrator = v; settings.narrator_manual = manual; save_settings(); Audio.set_narrator(v)

## v30.1: narrator follows the player's character: man -> m, woman -> f, boy -> c, girl -> g
static func narrator_for(gender: String, age: String) -> String:
	var child := age == "child"; var fem := gender == "women"
	return ("g" if fem else "c") if child else ("f" if fem else "m")
## v30.1: the ONLY narrator source (no menu setting): creator confirmed + every save load
func narrator_from_look(gender: String, age: String, creation := false) -> void:
	if not creation and bool(settings.get("narrator_manual", false)): return   # v32: a save load never overrides the chosen narrator
	var v := narrator_for(gender, age)
	if v != String(settings.narrator) or creation: set_narrator(v, false)
## label in a given language ("tr"/"en"), independent of the menu language
func t_lang(key: String, tr: bool) -> String:
	var a: Array = STR.get(key, [key, key])
	return a[0] if tr else a[1]

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("menu", k, settings[k])
	cf.save(SETTINGS_PATH)

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(settings.volume))))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		has_phone = bool(d.get("has_phone", d.get("state", {}).get("has_phone", false)))
		family_breakfast = bool(d.get("family_breakfast", has_phone))
		bath_done = bool(d.get("bath_done", false))
		day = int(d.get("day", 1))
		return d
	return {}

func has_word_clip(word: String) -> bool:
	return _word_file != null and _word_index.has(word.to_lower())

func say_word(word: String) -> void:
	var alt := Audio.narrator_alt(word)   # v31: selected narrator pack first
	if alt: _voice.stream = alt; _voice.play(); return
	if not has_word_clip(word):
		return
	var e: Array = _word_index[word.to_lower()]
	_word_file.seek(int(e[0]))
	_voice.stream = AudioStreamOggVorbis.load_from_buffer(_word_file.get_buffer(int(e[1])))
	_voice.play()

func load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text()) if f else null


## v29.1: ONE persisted TR flag for every scene: save.json state.tr (default OFF)
## v30.5: THE single TR flag (persisted in the save, default off). Every UI path reads tr_on().
var _trf := -1
func tr_saved() -> bool:
	if _trf < 0:
		var d = load_save()
		_trf = 1 if (d is Dictionary and d.get("state") is Dictionary and bool(d.state.get("tr", false))) else 0
	return _trf == 1
func save_tr(on: bool) -> void:
	_trf = 1 if on else 0
	var d = load_save()
	if not (d is Dictionary): return   # no save yet (new game before the first save): the scene keeps it
	var st: Dictionary = d.get("state", {}) if d.get("state") is Dictionary else {}
	st["tr"] = on; patch_save({"state": st})

## house.17: merge keys into user://save.json (rooms other than the bedroom)
func patch_save(keys: Dictionary) -> void:
	var d := {}
	if FileAccess.file_exists(SAVE_PATH):
		var x = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if x is Dictionary: d = x
	for k in keys: d[k] = keys[k]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d, "\t"))

## house.28: reopen the word bank after downloaded packs are mounted.
func reopen_banks() -> void:
	_word_file = FileAccess.open("res://voice/words.bin", FileAccess.READ)

## house.29: UI text in the menu language. English source text -> Turkish from data/extra_lines.json when lang is "tr".
var _xl := {}
func tx(en: String) -> String:
	if not tr_on(): return en   # v29.1: only while the in-game TR toggle is on (NOT the menu language)
	if _xl.is_empty():
		var d = load_json("res://data/extra_lines.json"); _xl = d if d is Dictionary else {"_": ""}
	var v := String(_xl.get(en, ""))
	return v if v != "" else en

## v29.1: the in-game TR toggle of the current scene (room S.tr, or the shared HUD's show_tr outdoors)
func tr_on() -> bool:
	return tr_saved()

## v32 (black): New Game = a full reset from zero, whatever the game was doing (paused, mid-cutscene, any day / room).
## Clears the save + side files and every autoload's in-memory state; menu.gd then loads the opening (creator) scene.
func new_game_reset() -> void:
	var tree := get_tree()
	if tree: tree.paused = false
	Audio.stop_all()
	if _voice: _voice.stop()
	for p in [SAVE_PATH, "user://bathroom.json", "user://bk_bathroom.json"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for d in [SavePath.photos(), "user://portraits"]:
		if DirAccess.dir_exists_absolute(d):
			for f in DirAccess.get_files_at(d): DirAccess.remove_absolute(d + "/" + f)
	has_phone = false; family_breakfast = false; day = 1; bath_done = false; came_from = ""; continue_requested = false; _trf = 0
	settings.narrator_manual = false; save_settings()
	WorldState.day = 1; WorldState.minutes = 7.0 * 60.0; WorldState.flags = {}; WorldState.scene = ""; WorldState.player_pos = Vector3.ZERO
	WorldState.paused = false; WorldState.creep = 0.0; WorldState.set("_loaded", false); WorldState.set("_last_hour", -1)
	Economy.wallet = Economy.START_CENTS; Economy.history = []; Economy.inventory = {}
	Transit.tickets = 0
	Game.spawn = ""; Game.busy = false
	var fd = Game.get("_fade")
	if fd is ColorRect: (fd as ColorRect).color.a = 0.0
	Life.new_game(); Life.charging = false; Life.set("_once_mem", {}); Life.set("_last_min", -1.0)
	Objectives.clear(false)
	var pm = load("res://scripts/core/portraits.gd")
	if pm: pm.mem = {}
	load("res://scripts/phone.gd").active_locked = false
	print("App: new game reset")
