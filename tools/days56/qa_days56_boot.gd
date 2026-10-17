extends Node
func _ready() -> void:
	var d = load("res://tools/days56/qa_days56.gd").new(); d.name = "QAD56"
	get_tree().root.add_child.call_deferred(d)
