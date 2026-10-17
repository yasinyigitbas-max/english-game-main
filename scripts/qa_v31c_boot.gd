extends Node
func _ready() -> void:
	var d = load("res://scripts/qa_v31c.gd").new(); d.name = "QAV31C"
	get_tree().root.add_child.call_deferred(d)
