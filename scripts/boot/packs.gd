extends Node
## house.28: downloadable asset packs (voice.pck, speech.pck) from GitHub Releases.
## Autoload listed FIRST so packs already on disk are mounted before Audio/App open their banks.
const BASE_URL: = "https://github.com/yasinyigitbas-max/english-game-packs/releases/download/packs-v36/"
const MANIFEST_URL := BASE_URL + "manifest.json"
const DIR := "user://packs"
var mounted := {}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_cleanup()
	mount_local()

## v29.1: every pack version gets its OWN file name (name-<sha12>.pck). A mounted pack file is never overwritten:
## Godot keeps the mounted file table (offsets), so overwriting voice.pck in place made every clip read the
## wrong bytes until a restart ("random wrong sounds" after the v28 -> v29 update).
static func local_name(p: Dictionary) -> String:
	return "%s-%s.pck" % [String(p.file).get_basename(), String(p.sha256).substr(0, 12)]

## delete pack files the saved manifest does not use (old versions, partial downloads); runs before anything is mounted
func _cleanup() -> void:
	var keep := {"manifest.json": true}
	for p in local_manifest().get("packs", []): keep[local_name(p)] = true
	for f in DirAccess.get_files_at(DIR):
		if not keep.has(f): DirAccess.remove_absolute(DIR + "/" + f)

## True when the game files are already in res:// (editor / desktop runs): no packs needed.
func bundled() -> bool:
	return FileAccess.file_exists("res://voice/voice_000.bin") and not mounted.size()

func local_manifest() -> Dictionary:
	var f := FileAccess.open(DIR + "/manifest.json", FileAccess.READ)
	if not f: return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## Mount every pack of the saved manifest whose file is present with the right size.
func mount_local() -> bool:
	var m := local_manifest()
	var packs: Array = m.get("packs", [])
	if packs.is_empty(): return false
	var ok := true
	for p in packs:
		var path := DIR + "/" + local_name(p)
		if mounted.has(local_name(p)): continue
		var f := FileAccess.open(path, FileAccess.READ)
		if not f or f.get_length() != int(p.size):
			ok = false; continue
		f = null
		if ProjectSettings.load_resource_pack(path, true): mounted[local_name(p)] = true
		else: ok = false
	return ok

func all_ready() -> bool:
	var packs: Array = local_manifest().get("packs", [])
	if packs.is_empty(): return false
	for p in packs:
		if not mounted.has(local_name(p)): return false
	return true

## Re-open the voice banks after a fresh mount (Audio/App opened them at boot).
func refresh_autoloads() -> void:
	var a := get_node_or_null("/root/Audio")
	if a and a.has_method("reopen_banks"): a.reopen_banks()
	var app := get_node_or_null("/root/App")
	if app and app.has_method("reopen_banks"): app.reopen_banks()

## Android: true when the active network is metered (mobile data). Uses the SherpaTts plugin helper.
func is_metered() -> bool:
	if Engine.has_singleton("SherpaTts"):
		var s = Engine.get_singleton("SherpaTts")
		if s.has_method("isMetered"): return bool(s.isMetered())
	return false
