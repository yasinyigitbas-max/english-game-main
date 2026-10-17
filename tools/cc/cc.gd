extends Node
func _ready() -> void:
	var bad := 0
	for d in ["res://scripts", "res://scripts/core", "res://scripts/story", "res://scripts/world", "res://scripts/boot", "res://ui/shared"]:
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd"): continue
			var s = ResourceLoader.load(d + "/" + f, "", ResourceLoader.CACHE_MODE_IGNORE)
			if s == null or not (s as GDScript).can_instantiate(): bad += 1; print("CC BAD ", d, "/", f)
	print("CC DONE bad=", bad); get_tree().quit()
