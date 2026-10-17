## v33 (red): day-4 / day-7 polaroid fallbacks with the PLAYER'S OWN character (d3_polaroids.gd pattern). A real
## snapshot always wins (Life.snap_from): d4_breakfast / d7_breakfast (day4_breakfast.gd), d4_shop / d7_shop
## (day4_shop.gd), d4_candles (day4_evening.gd), d7_party (day7_party.gd). Stills here are only used when a snapshot is missing.
## Keys: d4_shower, d4_breakfast, d4_shop, d4_candles, d7_shower, d7_breakfast, d7_shop, d7_party.
extends "res://scripts/story/d3_polaroids.gd"

static func ensure_d47(host: Node, keys: Array) -> void:
	var todo: Array = []
	for k in keys:
		if Life.photos.has(k) or FileAccess.file_exists(SavePath.photos() + "/%s.png" % k) or k in todo: continue
		todo.append(k)
	if todo.is_empty(): return
	var r = load("res://scripts/story/day4_polaroids.gd").new(); host.add_child(r)
	await r._render(todo); r.queue_free()

func _build(key: String) -> void:
	match key:
		"d4_shower", "d7_shower": super._build("d3_shower")
		"d4_breakfast", "d7_breakfast": super._build("d2_breakfast")
		"d4_shop", "d7_shop": super._build("d3_shop")
		"d4_candles":   # dark living room, the player on the sofa, three candles on the coffee table
			_stage(Color(0.08, 0.07, 0.1), Color(0.22, 0.18, 0.16), Color(0.2, 0.15, 0.1), Vector3(0, 1.4, 2.3), Vector3(0, 0.8, -0.6))
			_glb(F + "loungeDesignSofa.glb", Vector3(-0.8, 0, -1.0), 0.0, 1.3)
			_char("me", Vector3(0, 0.05, -0.75), 180.0, "sit_idle", 0.5)
			_box(Vector3(1.0, 0.05, 0.6), Vector3(0, 0.42, 0.3), Color(0.35, 0.24, 0.14))
			for x in [-0.2, 0.0, 0.2]:
				_box(Vector3(0.05, 0.14, 0.05), Vector3(x, 0.52, 0.3), Color(0.97, 0.95, 0.88))
				var f := _box(Vector3(0.025, 0.04, 0.025), Vector3(x, 0.61, 0.3), Color(1.0, 0.7, 0.25))
				var m := f.material_override as StandardMaterial3D; m.emission_enabled = true; m.emission = Color(1.0, 0.7, 0.25); m.emission_energy_multiplier = 4.0
			var l := OmniLight3D.new(); l.light_color = Color(1.0, 0.72, 0.42); l.omni_range = 3.0; l.light_energy = 2.0; l.position = Vector3(0, 0.8, 0.3); root.add_child(l)
		"d7_party":   # the sofa with balloons and a cake
			super._build("d2_couch")
			var cols := [Color(0.95, 0.3, 0.35), Color(0.3, 0.6, 0.95), Color(0.98, 0.8, 0.25), Color(0.5, 0.85, 0.45)]
			for i in 4:
				var b := _box(Vector3(0.28, 0.34, 0.28), Vector3(-1.2 + i * 0.8, 1.9 + (i % 2) * 0.15, -1.0), cols[i])
				b.rotation_degrees.y = 45.0
			_box(Vector3(0.36, 0.18, 0.36), Vector3(0.6, 0.5, 0.2), Color(0.98, 0.9, 0.95)); _box(Vector3(0.4, 0.4, 0.4), Vector3(0.6, 0.2, 0.2), Color(0.55, 0.38, 0.25))
		_: super._build(key)
