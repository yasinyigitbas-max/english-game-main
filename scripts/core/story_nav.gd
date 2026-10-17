## StoryNav (red, open-world prep): the ONE place story/gameplay code moves the hero between places.
## Today every call does exactly the old v33 thing. After black's skeleton lands, only this file changes:
##   goto   -> World.goto(place, door)          (walk through a real door, no fade)
##   room   -> World.door(...).walk_through()   (house room -> house room)
##   travel -> World.skip_travel(door, en, tr)  (car/bus/ambulance: never shown; fade out, place, fade in, per Yasin)
class_name StoryNav
extends RefCounted

## scene path -> open-world place id (for the switch to World.goto)
const PLACE := {
	"res://main.tscn": "bedroom", "res://livingroom.tscn": "livingroom", "res://bathroom.tscn": "bathroom",
	"res://scenes/world_exterior.tscn": "town", "res://scenes/hospital.tscn": "hospital",
	"res://scenes/hospital_day2.tscn": "hospital", "res://scenes/places/cafe.tscn": "cafe",
	"res://scenes/places/shop.tscn": "shop",
}

static func place_of(path: String) -> String: return String(PLACE.get(path, path.get_file().get_basename()))

## walk to a place / door (v33: Game.go_to = fade + change_scene + Game.spawn)
static func goto(path: String, door := "") -> void:
	Game.go_to(path, door)

## house room -> house room through the shared door (v33: House.go in-scene swap)
static func room(from: Node, path: String) -> void:
	House.go(from, path)

## off-screen trip (car / ambulance / bus); hero ends up at dest door. covered = the screen is already black.
## v33: Game.go_to (fade) or, when covered or Game.busy, a raw change_scene under the existing black.
static func travel(tree: SceneTree, path: String, door := "", covered := false) -> void:
	if covered: tree.change_scene_to_file(path); WorldState.scene = path; return
	Game.go_to(path, door)

## a story cut with no fade at all (v33: change_scene_to_file; hospital day changes, hospital -> bedroom)
static func cut(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file(path)
