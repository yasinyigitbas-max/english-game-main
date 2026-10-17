## One-off asset render (not QA): plays the outdoor accident and copies the "accident" snapshot to ../polaroid_accident.png
extends SceneTree
var t := 0.0
func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://photos/accident.png"))
	change_scene_to_file.call_deferred("res://scenes/world_exterior.tscn")
	Engine.time_scale = 2.0
func _process(dt: float) -> bool:
	t += dt
	if FileAccess.file_exists("user://photos/accident.png"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path("user://photos/accident.png"), "/workspace/story_blue/polaroid_accident.png")
		print("SNAP_OK"); quit(); return true
	if t > 140.0: print("SNAP_TIMEOUT"); quit()
	return false
