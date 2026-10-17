class_name SavePath
## v29.1 QA save override, so parallel bots don't share user://save.json:
##   godot ... -- --save-path=/tmp/red_save.json      (command-line user arg, after "--")
##   GAME_SAVE_PATH=/tmp/red_save.json godot ...       (environment variable)
## Default (phone / normal play): user://save.json
static var _p := ""
static func P() -> String:
	if _p != "": return _p
	_p = "user://save.json"
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--save-path="): _p = a.substr(12); break
	if _p == "user://save.json" and OS.get_environment("GAME_SAVE_PATH") != "": _p = OS.get_environment("GAME_SAVE_PATH")
	if _p != "user://save.json": DirAccess.make_dir_recursive_absolute(_p.get_base_dir()); print("SavePath: ", _p)
	return _p

## v31: photos live next to the save, so a QA run with its own save (and its New Game wipe) never touches
## the shared user://photos of normal play / other bots. Default play: user://photos
static func photos() -> String:
	var p := P()
	return "user://photos" if p == "user://save.json" else p.get_base_dir() + "/photos_" + p.get_file().get_basename()
