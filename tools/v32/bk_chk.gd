extends Node
## v32 (black): compile check with autoloads present. godot --headless --path . res://tools/v32/bk_chk.tscn
func _ready() -> void:
	var bad := 0; var n := 0
	for f in FileAccess.get_file_as_string("res://tools/v32/chk_list.txt").split("\n"):
		f = f.strip_edges()
		if f == "": continue
		n += 1
		var s = load("res://" + f)
		if s == null or not (s is GDScript) or not (s as GDScript).can_instantiate(): bad += 1; print("CHK FAIL ", f)
	print("CHK DONE files=%d bad=%d" % [n, bad])
	get_tree().quit()
