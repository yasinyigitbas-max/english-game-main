## v31c (red): day-2 polaroid fallbacks that show the PLAYER'S OWN character (extends house.27 polaroid_renderer.gd).
## A real snapshot always wins: Life.snap_from("d2_couch", ...) on the couch (day2_evening.gd); black / the hospital
## owner can add Life.snap_from("d2_breakfast" / "d2_hospital", ...) at their events and these stills are then skipped.
## Keys: d2_breakfast, d2_work, d2_hospital, d2_couch.
extends "res://scripts/story/polaroid_renderer.gd"

static func ensure_d2(host: Node, keys: Array) -> void:
	var todo: Array = []
	for k in keys:
		if Life.photos.has(k) or FileAccess.file_exists(SavePath.photos() + "/%s.png" % k) or k in todo: continue
		todo.append(k)
	if todo.is_empty(): return
	var r = load("res://scripts/story/d2_polaroids.gd").new(); host.add_child(r)
	await r._render(todo); r.queue_free()

func _build(key: String) -> void:
	var c: DemoCharacter
	match key:
		"d2_breakfast":   # at the table with a mug, phone (the lesson) on the table
			_stage(Color(0.95, 0.9, 0.8), Color(0.98, 0.92, 0.82), Color(0.62, 0.48, 0.34), Vector3(1.5, 1.5, 1.6), Vector3(0, 0.9, -0.3))
			_box(Vector3(1.2, 0.05, 0.8), Vector3(0.0, 0.75, 0.15), Color(0.7, 0.5, 0.3)); _box(Vector3(0.08, 0.75, 0.08), Vector3(0.5, 0.37, 0.45), Color(0.6, 0.42, 0.25))
			_box(Vector3(0.22, 0.02, 0.22), Vector3(-0.25, 0.8, 0.2), Color(0.98, 0.98, 0.96)); _box(Vector3(0.12, 0.01, 0.22), Vector3(0.25, 0.785, 0.2), Color(0.1, 0.1, 0.14))
			_box(Vector3(0.1, 0.005, 0.18), Vector3(0.25, 0.792, 0.2), Color(0.45, 0.65, 1.0))
			c = _char("me", Vector3(0, 0, -0.4), 0.0, "drink", 1.2); c.hold_item("res://props/mug.tscn", "mug", 0.1, false)
		"d2_work":   # at work: desk + screen
			_stage(Color(0.85, 0.9, 0.95), Color(0.86, 0.9, 0.96), Color(0.55, 0.57, 0.62), Vector3(1.4, 1.5, 1.7), Vector3(0, 1.0, -0.3))
			_box(Vector3(1.4, 0.05, 0.7), Vector3(0, 0.74, -0.75), Color(0.85, 0.85, 0.88)); _box(Vector3(0.6, 0.38, 0.04), Vector3(0, 1.0, -0.95), Color(0.15, 0.15, 0.18))
			_box(Vector3(0.55, 0.32, 0.01), Vector3(0, 1.0, -0.925), Color(0.4, 0.7, 0.95)); _box(Vector3(0.5, 0.05, 0.4), Vector3(0, 0.85, 0.9), Color(0.3, 0.3, 0.35))
			c = _char("me", Vector3(0, 0, -0.1), 20.0, "wave", 0.6)
		"d2_hospital":   # check-up: the player sits on the bed edge, the doctor in front
			_stage(Color(0.85, 0.9, 0.92), Color(0.86, 0.92, 0.91), Color(0.78, 0.82, 0.8), Vector3(1.9, 1.5, 1.4), Vector3(0, 0.9, -0.4))
			_box(Vector3(2.0, 0.55, 1.0), Vector3(-0.3, 0.275, -0.8), Color(0.95, 0.96, 0.98)); _box(Vector3(2.0, 0.04, 1.0), Vector3(-0.3, 0.57, -0.8), Color(0.62, 0.8, 0.86))
			c = _char("me", Vector3(0, 0.1, -0.55), 180.0, "sit_idle", 0.5)
			_char("men", Vector3(-1.0, 0, 0.1), 120.0, "idle", 0.5, Color(0.98, 0.98, 0.98))
		"d2_couch":
			_stage(Color(0.9, 0.85, 0.75), Color(0.95, 0.88, 0.78), Color(0.55, 0.42, 0.3), Vector3(0, 1.4, 2.3), Vector3(0, 0.8, -0.6))
			_glb(F + "loungeDesignSofa.glb", Vector3(-0.8, 0, -1.0), 0.0, 1.3)
			_char("me", Vector3(0, 0.05, -0.75), 180.0, "sit_idle", 0.5)
		_: super._build(key)
