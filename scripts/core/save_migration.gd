## SaveMigration (red, open-world prep): upgrades the "world" save block.
## v1 (v33): {scene: "res://...tscn", player_pos: Vector3 (exterior only), ...}
## v2 (open world, NOT active yet): {place: "<place id>", door: "<door id>", hero_pos: [x,y,z] in world.tscn}
## Today migrate() returns v1 data untouched; set TARGET := 2 once World exists.
class_name SaveMigration
extends RefCounted

const TARGET := 1

static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2 and TARGET >= 2: d = _v1_to_v2(d)
	return d

static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var o := d.duplicate(true)
	o["place"] = StoryNav.place_of(String(d.get("scene", "")))
	o["door"] = "front_door" if o.place in ["bedroom", "livingroom", "bathroom"] else ""   # resume at a known door
	o["hero_pos"] = null   # v1 player_pos was exterior-local; world.tscn decides from place/door
	o["version"] = 2
	return o
