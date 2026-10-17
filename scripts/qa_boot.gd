extends Node
func _ready() -> void:
	var d = load("res://scripts/qa_v31fix.gd" if "--qa-v31fix" in OS.get_cmdline_user_args() else ("res://scripts/qa_day2m.gd" if "--qa-day2m" in OS.get_cmdline_user_args() else "res://scripts/qa_flow.gd")).new(); d.name = "QAFlow"
	get_tree().root.add_child.call_deferred(d)
	if "--qa-hosptr" in OS.get_cmdline_user_args(): d.ready.connect(func(): await d.run_hosptr(), CONNECT_ONE_SHOT)
	elif "--qa-v304" in OS.get_cmdline_user_args(): d.ready.connect(func(): await d.run_v304(), CONNECT_ONE_SHOT)
	elif "--qa-v31fix" in OS.get_cmdline_user_args(): d.ready.connect(func(): await d.run_v31fix(), CONNECT_ONE_SHOT)
	elif "--qa-day2m" in OS.get_cmdline_user_args(): d.ready.connect(func(): await d.run_day2m(), CONNECT_ONE_SHOT)
	else: d.ready.connect(func(): d.run_v31() if "--qa-v31" in OS.get_cmdline_user_args() else (d.run_day2() if "--qa-day2" in OS.get_cmdline_user_args() else (d.run_story() if "--qa-story" in OS.get_cmdline_user_args() else (d.run_v291b() if "--qa-v291b" in OS.get_cmdline_user_args() else (d.run_v291() if "--qa-v291" in OS.get_cmdline_user_args() else (d.run_phone() if "--qa-phone" in OS.get_cmdline_user_args() else (d.run_child() if "--qa-child" in OS.get_cmdline_user_args() else (d.run_scroll() if "--scroll" in OS.get_cmdline_user_args() else d.run_flow()))))))), CONNECT_ONE_SHOT)
	get_tree().change_scene_to_file.call_deferred("res://menu.tscn")
