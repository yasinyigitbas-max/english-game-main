extends Node
func _ready() -> void:
	var d = load("res://tools/qa_voices.gd").new(); d.name = "QAVoices"
	get_tree().root.add_child.call_deferred(d)
	get_tree().change_scene_to_file.call_deferred("res://menu.tscn")
