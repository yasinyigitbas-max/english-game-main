## Game (autoload): scene transitions with a fade + named spawn points.
##   Game.go_to("res://scenes/world_exterior.tscn", "lot:home")   -> scene reads Game.spawn in _ready()
extends Node

## merge hook: the outdoor home door enters this scene when it exists (black bot's living room)
const HOUSE_FRONT_DOOR_SCENE := "res://livingroom.tscn"
const WORLD_SCENE := "res://scenes/world_exterior.tscn"
var spawn := ""
## ---- persistent character hook (scripts/core/character_hook.gd) ----
## emitted whenever the creator data may have changed (pause-menu settings, mirror, make-up, scene entry)
signal character_changed(creator: Dictionary)                 # e.g. "bedroom_door", "front_door", "lot:<lot_id>"
var _fade: ColorRect
var busy := false

func _ready() -> void:
	var cl := CanvasLayer.new(); cl.layer = 100; add_child(cl)
	_fade = ColorRect.new(); _fade.color = Color(0.86, 0.89, 0.93, 0.0); _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(_fade)

func go_to(path: String, spawn_id := "") -> void:
	if busy or not ResourceLoader.exists(path): return
	busy = true; spawn = spawn_id
	var tw := create_tween(); tw.tween_property(_fade, "color:a", 1.0, 0.35); await tw.finished
	# v33 whole town: a building door between the street, the house, the cafe and the shop swaps the live place in the
	# same scene (scripts/core/town.gd); anything else (hospital, work, menu ...) changes scene as before
	var cs := get_tree().current_scene
	if not (cs and load("res://scripts/core/town.gd").go(cs, path)): get_tree().change_scene_to_file(path)
	WorldState.scene = path
	await get_tree().process_frame; await get_tree().process_frame
	tw = create_tween(); tw.tween_property(_fade, "color:a", 0.0, 0.45); await tw.finished
	busy = false

func fade(to: float, t := 0.35) -> void:
	var tw := create_tween(); tw.tween_property(_fade, "color:a", to, t); await tw.finished

# ------------------------------------------------------------ persistent character hook
## the bedroom creator's data (live room state first, else save.json "state")
func creator() -> Dictionary: return CharacterHook.creator(get_tree())

## rebuild a player (WorldPlayer / any node with `hero`) or a DemoCharacter from the house creator.
## Pass `c` to use specific data (e.g. a room's live S); otherwise creator() is read.
func apply_character(target: Object, c: Dictionary = {}) -> void:
	var data := c if not c.is_empty() else creator()
	var hero: DemoCharacter = target as DemoCharacter
	if hero == null and target and "hero" in target: hero = target.hero
	CharacterHook.apply(hero, data)

## call after anything changes the look (mirror again, make-up, settings); every listening player rebuilds itself.
## Also persists live creator keys into save.json "state" so the next scene (house or world) sees them.
func refresh_character(c: Dictionary = {}) -> void:
	var data := c if not c.is_empty() else creator()
	var d := App.load_save()
	if d.get("state") is Dictionary:
		var st: Dictionary = d.state
		var dirty := false
		for k in CharacterHook.KEYS:
			if data.has(k) and st.get(k) != data[k]: st[k] = data[k]; dirty = true
		if dirty: App.patch_save({"state": st})
	character_changed.emit(data)
