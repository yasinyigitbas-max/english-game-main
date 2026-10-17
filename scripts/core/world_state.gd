## WorldState (autoload): clock / time of day, player location, save + load of every saveable singleton.
## Save: house save.json key "world":  {version, clock, scene, spawn, player_pos, economy, transit}
extends Node

signal hour_changed(hour: int)
signal time_of_day_changed(phase: String)    # "morning" | "afternoon" | "evening" | "night"

var SAVE_PATH: String = SavePath.P()   # = App.SAVE_PATH (shared with the house), key "world"
var _loaded := false
const VERSION := 1
var minutes := 7.0 * 60.0       # minutes since midnight of `day`
var day := 1
var time_scale := 0.1           # house.29: event-driven clock; between story events time only creeps (6 game min per real min)
var paused := false
var creep := 0.0                ## v29.1: no free-running time between events (time_scale still drives the traffic schedule)
var scene := ""                 # current top-level scene path
var player_pos := Vector3.ZERO  # last exterior position (world coordinates)
var flags := {}                 # free-form story flags, e.g. {"bedroom_done": true}
var _last_hour := -1

func _process(dt: float) -> void:
	if paused: return
	minutes += dt * time_scale * creep   # v29.1: creep = 0 -> the clock moves only on story events (Life.event)
	if minutes >= 1440.0: minutes -= 1440.0; day += 1
	var h := hour()
	if h != _last_hour:
		var old := phase_for(_last_hour) if _last_hour >= 0 else ""
		_last_hour = h; hour_changed.emit(h)
		if phase_for(h) != old: time_of_day_changed.emit(phase_for(h))

func hour() -> int: return int(minutes / 60.0)
func clock_text() -> String: return "%02d:%02d" % [hour(), int(minutes) % 60]
func stamp() -> String: return "D%d %s" % [day, clock_text()]
func phase() -> String: return phase_for(hour())
func phase_for(h: int) -> String:
	if h >= 6 and h < 12: return "morning"
	if h >= 12 and h < 17: return "afternoon"
	if h >= 17 and h < 21: return "evening"
	return "night"
## 0..1 daylight factor for lighting (future day/night cycle)
func daylight() -> float: return clampf(sin((minutes / 1440.0 - 0.25) * TAU) * 1.4 + 0.3, 0.0, 1.0)

func to_dict() -> Dictionary:
	return {"version": VERSION, "minutes": minutes, "day": day, "scene": scene, "flags": flags,
		"player_pos": [player_pos.x, player_pos.y, player_pos.z],
		"economy": Economy.to_dict(), "transit": Transit.to_dict()}

## shared save: the house's user://save.json (App.SAVE_PATH), key "world" (the house keeps "state", "day", ...)
func save_game() -> bool:
	App.patch_save({"world": to_dict(), "day": day}); App.day = day; return true

func has_save() -> bool: return App.has_save() and (App.load_save().get("world") is Dictionary)

func load_game() -> bool:
	if not has_save(): return false
	var d = App.load_save().get("world")
	if d is Dictionary: d = SaveMigration.migrate(d)
	if not d is Dictionary: return false
	minutes = float(d.get("minutes", minutes)); day = int(d.get("day", 1)); scene = str(d.get("scene", ""))
	flags = d.get("flags", {})
	var p: Array = d.get("player_pos", [0, 0, 0]); player_pos = Vector3(p[0], p[1], p[2])
	Economy.from_dict(d.get("economy", {})); Transit.from_dict(d.get("transit", {}))
	return true

## first outdoor/house scene after boot pulls the world part of the shared save once (Continue-compatible)
func ensure_loaded() -> void:
	if _loaded: return
	_loaded = true
	if has_save(): load_game()

## house.29: story events move the clock forward to a set time (never backwards within a day).
func set_time(h: int, m := 0) -> void:
	var t := float(h * 60 + m)
	if t > minutes: minutes = t
