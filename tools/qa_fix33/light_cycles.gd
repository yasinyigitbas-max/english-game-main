## fix33 QA (headless, no visuals): 10 room / place enter-exit cycles; counts the drawn lights, WorldEnvironments and the
## active environment's ambient / exposure before and after. Stable = the same numbers every cycle.
## godot --headless --path . res://tools/qa_fix33/light_cycles.tscn
extends Node
func _t(s: float) -> void: await get_tree().create_timer(s).timeout
func _report(tag: String) -> void:
	var n := 0; var e := 0.0; var dirs := 0; var all := 0
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		all += 1
		if (l as Light3D).is_visible_in_tree() and (l as Light3D).light_energy > 0.0 and not (l.get_viewport() is SubViewport):
			n += 1; e += (l as Light3D).light_energy
			if l is DirectionalLight3D: dirs += 1
	var wes := 0
	for w in get_tree().root.find_children("*", "WorldEnvironment", true, false): if (w as WorldEnvironment).environment != null and not (w.get_viewport() is SubViewport): wes += 1
	var env: Environment = get_viewport().find_world_3d().environment
	if tag.begins_with("start") or tag.ends_with("09_living") or tag.begins_with("cycle00") or tag.begins_with("cycle05") or tag.begins_with("cycle06"):
		for l in get_tree().root.find_children("*", "Light3D", true, false):
			if not (l.get_viewport() is SubViewport): print("LIGHTQA_L %s %s vis=%s e=%.2f" % [tag, str(l.get_path()), (l as Light3D).is_visible_in_tree(), (l as Light3D).light_energy])
		for w in get_tree().root.find_children("*", "WorldEnvironment", true, false): if (w as WorldEnvironment).environment != null: print("LIGHTQA_E %s %s" % [tag, str(w.get_path())])
	print("LIGHTQA %s lights_total=%d lit=%d dir_lit=%d energy_sum=%.2f world_envs=%d amb=%.3f exp=%.3f" % [tag, all, n, dirs, e, wes, env.ambient_light_energy if env else -1.0, env.tonemap_exposure if env else -1.0])
func _ready() -> void:
	add_child(load("res://scenes/world.tscn").instantiate())
	await _t(5.0)
	WorldState.minutes = 12.0 * 60.0
	await OwLink.enter("livingroom", ""); await _t(1.0); _report("start_living")
	for i in int(OS.get_environment("CYC")) if OS.get_environment("CYC") != "" else 10:
		await OwLink.enter("bedroom", "livingroom"); await _t(0.6)
		await OwLink.enter("bathroom", "bedroom"); await _t(0.6)
		await OwLink.enter("livingroom", "bathroom"); await _t(0.6)
		OwLink.to_street("front"); await _t(0.8)
		await OwLink.travel("shop", "shop"); await _t(0.8)
		await OwLink.travel("cafe", "cafe"); await _t(0.8)
		await OwLink.travel("livingroom", ""); await _t(1.0)
		_report("cycle%02d_living" % i)
	get_tree().quit()
