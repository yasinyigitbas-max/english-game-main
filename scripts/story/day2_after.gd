## v30.5 (black): day 2 after work / the hospital check-up. On spawning home, guide the player (Life.guide_to: pan, sound,
## top-left objective) back to the car for whichever of the two is NOT done yet. When BOTH are done the objective is
## "Talk to your family." with a pan to the couch.
## ===== HOOK (red, v31): the family talk on the couch. Connect to Day2After.family_ready (static signal holder below) or
## override livingroom.gd day2_family_talk(); story stage is "family" (day2_morning.gd stage) from then on.
class_name Day2After
extends RefCounted

const D2 := preload("res://scripts/story/day2_morning.gd")

static func _story() -> Dictionary:
	var sv = App.load_save().get("story", {})
	return sv if sv is Dictionary else {}

static func pending() -> String:   # "" (not applicable) | "work" | "hospital" | "both" (= family next)
	if maxi(WorldState.day, App.day) != 2: return ""   # v31c (red): day 2 only (day 3 must not repeat "Talk to your family.")
	var sv := _story()
	var w := bool(sv.get("day2_work_done", false)); var h := bool(sv.get("day2_hospital_done", false))
	if not (w or h): return ""
	if w and h: return "both"
	return "hospital" if w else "work"

static func _once(key: String) -> bool:
	var sv := _story().duplicate()
	if bool(sv.get(key, false)): return false
	sv[key] = true; App.patch_save({"story": sv}); return true

## where: "living" (livingroom.gd) or "bedroom" (main.gd)
static func run(sc: Node, where: String) -> void:
	var p := pending()
	if p == "": return
	if p == "both":
		if bool(_story().get("d2_couch_done", false)):   # v31c (red): couch talk done -> Day2Evening shows "Go to bed." instead
			if where == "living" and sc.has_method("day2_family_talk"): sc.day2_family_talk()
			return
		D2.set_stage("family")
		if where == "living":
			var at: Vector3 = sc.to_local(sc.N.sofa.global_position) + Vector3(0, 0.7, 0) if sc.get("N") and sc.N.has("sofa") else Vector3(1.95, 0.7, 0)
			var opts := {"tr": "Ailenle konuş."}
			if not _once("guide_family_living"): opts["sound"] = false
			await Life.guide_to({"pos": at + Vector3(-3.0, 1.4, 0.4), "at": at}, "Talk to your family.", opts)
			if sc.has_method("day2_family_talk"): sc.day2_family_talk()   # red's v31 hook
		else:
			await Life.guide_to({"pos": Vector3(0.6, 1.9, 0.6), "at": Vector3(1.8, 1.1, 3.0)}, "Talk to your family.", {"tr": "Ailenle konuş.", "no_flash": true})
		return
	D2.set_stage("car")   # day2_car.gd: the car prompt runs again with the remaining destination
	var txt := "Go to the car."
	var tr := "Arabaya git."
	if where == "living":
		var DF: Vector2 = sc.DOOR_FRONT
		var dx := (DF.x + DF.y) / 2
		await Life.guide_to({"pos": Vector3(dx - 1.6, 2.0, 0.2), "at": Vector3(dx, 1.1, 3.0)}, txt, {"tr": tr})
	else:
		await Life.guide_to({"pos": Vector3(0.6, 1.9, 0.6), "at": Vector3(1.8, 1.1, 3.0)}, txt, {"tr": tr, "no_flash": true})
