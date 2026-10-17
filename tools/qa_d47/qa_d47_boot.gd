extends Node
func _ready() -> void:
	var d = load("res://tools/qa_d47/qa_d47.gd").new(); d.name = "QAD47"
	get_tree().root.add_child.call_deferred(d)
