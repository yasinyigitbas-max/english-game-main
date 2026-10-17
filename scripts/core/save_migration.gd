## SaveMigration (red, open-world prep): upgrades the "world" save block.
## v1 (v33): {scene: "res://...tscn", player_pos: Vector3 (exterior only), ...}
## v2 (open world, NOT active yet): {place: "<place id>", door: "<door id>", hero_pos: [x,y,z] in world.tscn}
## Today migrate() returns v1 data untouched; set TARGET := 2 once World exists.
class_name SaveMigration
extends RefCounted

const TARGET := 2   # ON: v1 (v33 scene saves) -> v2 open world

static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2 and TARGET >= 2: d = _v1_to_v2(d)
	return d

static func _v1_to_v2(d: Dictionary) -> Dictionary:
	var o := d.duplicate(true)
	var pl := StoryNav.place_of(String(d.get("scene", "")))
	pl = {"town": "street", "world_exterior": "street", "work": "street", "child_drive_stop": "street", "hospital_day2": "hospital"}.get(pl, pl)
	if pl == "hospital": pl = "bedroom"   # a v33 hospital scene restarts its story from its own done flags; resume safely at home
	if pl == "": pl = "bedroom"
	o["place"] = pl
	o["door"] = "front" if pl == "street" else ""   # street: resume at the home front door
	o["hero_pos"] = null; o["hero_yaw"] = 0.0   # v1 player_pos was exterior-local; world.tscn decides from place/door
	o["version"] = 2
	return o
