extends Node
func _ready() -> void:
	var d = load("res://tools/qa_fix33/qa_jump.gd").new(); d.name = "QAJump"
	get_tree().root.add_child.call_deferred(d)
