## v32c (red): day-3 polaroid fallbacks with the PLAYER'S OWN character (same pattern as d2_polaroids.gd / black's
## polaroid_renderer.gd). A real snapshot always wins: Life.snap_from("d3_couch", ...) on the couch (day3_evening.gd);
## blue can add Life.snap_from("d3_cafe" / "d3_shop", ...) in the cafe / shop and these stills are then skipped.
## Keys: d3_shower, d3_cafe, d3_shop, d3_couch.
extends "res://scripts/story/d2_polaroids.gd"

static func ensure_d3(host: Node, keys: Array) -> void:
	var todo: Array = []
	for k in keys:
		if Life.photos.has(k) or FileAccess.file_exists(SavePath.photos() + "/%s.png" % k) or k in todo: continue
		todo.append(k)
	if todo.is_empty(): return
	var r = load("res://scripts/story/d3_polaroids.gd").new(); host.add_child(r)
	await r._render(todo); r.queue_free()

func _build(key: String) -> void:
	match key:
		"d3_shower":   # bathroom tiles, fresh after the shower
			_stage(Color(0.82, 0.9, 0.95), Color(0.86, 0.93, 0.97), Color(0.7, 0.78, 0.82), Vector3(1.3, 1.5, 1.8), Vector3(0, 1.0, -0.3))
			_box(Vector3(1.0, 2.0, 0.05), Vector3(-0.9, 1.0, -0.9), Color(0.95, 0.97, 1.0)); _box(Vector3(0.9, 0.06, 0.9), Vector3(-0.9, 0.03, -0.6), Color(0.9, 0.93, 0.96))
			_box(Vector3(0.12, 0.12, 0.05), Vector3(-0.9, 1.9, -0.85), Color(0.75, 0.78, 0.8))
			_char("me", Vector3(0.1, 0, -0.3), 15.0, "idle", 0.5)
		"d3_cafe":   # cafe table: hot chocolate + two cookies
			_stage(Color(0.92, 0.86, 0.78), Color(0.84, 0.74, 0.62), Color(0.5, 0.38, 0.28), Vector3(1.5, 1.5, 1.6), Vector3(0, 0.9, -0.3))
			_box(Vector3(0.9, 0.05, 0.9), Vector3(0.0, 0.75, 0.15), Color(0.96, 0.95, 0.92)); _box(Vector3(0.08, 0.75, 0.08), Vector3(0.0, 0.37, 0.15), Color(0.22, 0.23, 0.26))
			_box(Vector3(0.1, 0.02, 0.1), Vector3(0.2, 0.785, 0.25), Color(0.72, 0.52, 0.32)); _box(Vector3(0.1, 0.02, 0.1), Vector3(0.32, 0.785, 0.15), Color(0.72, 0.52, 0.32))
			var c: DemoCharacter = _char("me", Vector3(0, 0, -0.4), 0.0, "drink", 1.2); c.hold_item("res://props/mug.tscn", "mug", 0.1, false)
		"d3_shop":   # shelves with products, the player picking something up
			_stage(Color(0.9, 0.93, 0.88), Color(0.94, 0.95, 0.9), Color(0.62, 0.64, 0.6), Vector3(1.4, 1.5, 1.8), Vector3(0, 1.0, -0.3))
			for y in [0.45, 0.95, 1.45]:
				_box(Vector3(1.8, 0.04, 0.4), Vector3(-0.2, y, -1.0), Color(0.85, 0.85, 0.88))
				for i in 6: _box(Vector3(0.16, 0.22, 0.16), Vector3(-0.95 + i * 0.3, y + 0.13, -1.0), [Color(0.85, 0.3, 0.3), Color(0.96, 0.96, 0.94), Color(0.9, 0.75, 0.4)][(i + int(y * 2)) % 3])
			_char("me", Vector3(0, 0, -0.35), 180.0, "pick_up", 1.1)
		"d3_couch":
			super._build("d2_couch")
		_: super._build(key)
