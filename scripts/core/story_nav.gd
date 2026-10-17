## StoryNav (red, open-world prep): the ONE place story/gameplay code moves the hero between places.
## Today every call does exactly the old v33 thing. After black's skeleton lands, only this file changes:
##   goto   -> World.goto(place, door)          (walk through a real door, no fade)
##   room   -> World.door(...).walk_through()   (house room -> house room)
##   travel -> World.skip_travel(door, en, tr)  (car/bus/ambulance: never shown; fade out, place, fade in, per Yasin)
class_name StoryNav
extends RefCounted

const House := preload("res://scripts/core/house.gd")

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
	if OwLink.active():
		var pl := place_of(path)
		if pl == "town": OwLink.to_street(_world_door(door)); return
		if OwLink.ROOM_PATH.has(pl): OwLink.enter(pl, "street"); return
		if pl in OwLink.PLACES: World.goto(pl, pl); return   # cafe / shop: walk through their world door
		OwLink.travel(pl, door); return   # cafe / shop: walk through their world door
	Game.go_to(path, door)

## v33 spawn ids -> world door / spot ids
static func _world_door(door: String) -> String:
	return {"lot:home": "front", "front_door": "front", "home_car": "front", "lot:cafe": "cafe", "cafe_door": "cafe", "lot:corner_shop": "shop", "shop_door": "shop"}.get(door, door)

## house room -> house room through the shared door (v33: House.go in-scene swap)
static func room(from: Node, path: String) -> void:
	if OwLink.active(): OwLink.enter(place_of(path), place_of(from.scene_file_path)); return
	House.go(from, path)

## off-screen trip (car / ambulance / bus); hero ends up at dest door. covered = the screen is already black.
## v33: Game.go_to (fade) or, when covered or Game.busy, a raw change_scene under the existing black.
static func travel(tree: SceneTree, path: String, door := "", covered := false) -> void:
	if OwLink.active():
		var pl := place_of(path)
		if pl == "town": pl = "street"
		if path.ends_with("hospital_day2.tscn"): pl = "hospital_day2"
		OwLink.travel(pl, door, covered); return
	if covered: tree.change_scene_to_file(path); WorldState.scene = path; return
	Game.go_to(path, door)

## a story cut with no fade at all (v33: change_scene_to_file; hospital day changes, hospital -> bedroom)
static func cut(tree: SceneTree, path: String) -> void:
	if OwLink.active(): travel(tree, path); return   # hospital -> home / day-2 visit: a car trip (fade), never a scene load
	tree.change_scene_to_file(path)
