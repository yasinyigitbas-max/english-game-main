extends Control
## Speaker/play triangle drawn in code (Nunito has no ▶ glyph).
func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.24
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, -r), c + Vector2(-r * 0.7, r), c + Vector2(r, 0)]), Color(1, 1, 1))
