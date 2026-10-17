extends SceneTree
## house.28: build voice.pck + speech.pck into /workspace/dl/packs_v28 (run: godot --headless -s tools/build_packs.gd)
const OUT_DEFAULT := "/workspace/dl/packs_v31/"
## v31.1 recovery: PACKS_OUT env var overrides the output folder (used by tools/black_ship31.sh)
var OUT: String = (OS.get_environment("PACKS_OUT").trim_suffix("/") + "/") if OS.get_environment("PACKS_OUT") != "" else OUT_DEFAULT
func _add_dir(pk: PCKPacker, dir: String, cnt: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		var p := dir + "/" + f
		if f.ends_with(".import"):
			var cf := ConfigFile.new(); cf.load(p)
			var imp := String(cf.get_value("remap", "path", ""))
			pk.add_file(p, p); pk.add_file(imp, imp); cnt[0] += 2
		elif dir.begins_with("res://voice") and f.ends_with(".ogg"):
			continue
		else:
			pk.add_file(p, p); cnt[0] += 1
	for d in DirAccess.get_directories_at(dir): _add_dir(pk, dir + "/" + d, cnt)
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for pair in [["voice.pck", ["res://voice"]], ["speech.pck", ["res://tts"]], ["narrator.pck", ["res://voice_m", "res://voice_c", "res://voice_g"]]]:
		var pk := PCKPacker.new(); pk.pck_start(OUT + pair[0])
		var cnt := [0]
		for d in pair[1]: _add_dir(pk, d, cnt)
		pk.flush()
		print(pair[0], " files=", cnt[0])
	quit()
