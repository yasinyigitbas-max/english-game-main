extends Node
## Shared visual theme, copied from english_game_3dv2/scripts/main.gd (_sb and _build_ui):
## Nunito variable font (wght 600 / 800), StyleBoxFlat corner radii 18-30, same colour palette.

var font: FontVariation
var font_b: FontVariation
var theme: Theme

const INK := Color(0.12, 0.15, 0.25)
const MUTED := Color(0.40, 0.45, 0.55)
const BODY := Color(0.25, 0.28, 0.36)
const BLUE := Color(0.31, 0.42, 0.93)
const BLUE_HOVER := Color(0.36, 0.48, 0.97)
const BLUE_PRESS := Color(0.25, 0.35, 0.80)
const BLUE_SOFT := Color(0.75, 0.88, 1.0)
const CHIP := Color(0.93, 0.94, 0.97)
const CHIP_ON := Color(0.91, 0.93, 0.98)
const CARD := Color(1, 1, 1, 0.96)
const SCRIM := Color(0.07, 0.09, 0.14, 0.45)
const ROW := Color(0.96, 0.97, 0.99)
const RED := Color(0.78, 0.28, 0.28)
const GREEN := Color(0.16, 0.55, 0.36)

func _ready() -> void:
	var base: Font = load("res://fonts/Nunito.ttf")
	var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	font = FontVariation.new(); font.base_font = base; font.variation_opentype = {tag: 600}
	font_b = FontVariation.new(); font_b.base_font = base; font_b.variation_opentype = {tag: 800}
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	theme.set_stylebox("normal", "Button", sb(Color(1, 1, 1, 0.94), 18, 10))
	theme.set_stylebox("hover", "Button", sb(BLUE_HOVER.lightened(0.55), 18, 10))
	theme.set_stylebox("pressed", "Button", sb(Color(0.82, 0.86, 0.98), 18, 10))
	theme.set_stylebox("disabled", "Button", sb(Color(0.90, 0.91, 0.94), 18, 10))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(k, "Button", Color(0.13, 0.16, 0.24))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.64))
	theme.set_color("font_color", "Label", INK)

## Same helper as 3dv2's _sb(): flat fill, all corners equal, content margins pad / pad+6.
func sb(c: Color, r := 22, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

func primary_button(b: Button) -> void:
	b.add_theme_font_override("font", font_b)
	b.add_theme_stylebox_override("normal", sb(BLUE, 18, 10))
	b.add_theme_stylebox_override("hover", sb(BLUE_HOVER, 18, 10))
	b.add_theme_stylebox_override("pressed", sb(BLUE_PRESS, 18, 10))
	b.add_theme_stylebox_override("disabled", sb(Color(0.78, 0.80, 0.86), 18, 10))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(1, 1, 1))

func soft_button(b: Button) -> void:
	b.add_theme_font_override("font", font_b)
	b.add_theme_stylebox_override("normal", sb(CHIP, 18, 10))
	b.add_theme_stylebox_override("hover", sb(Color(0.88, 0.90, 0.96), 18, 10))
	b.add_theme_stylebox_override("pressed", sb(Color(0.82, 0.86, 0.98), 18, 10))

func click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://sfx/click.ogg")
	p.volume_db = 0.0
	get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func label(text: String, size := 24, bold := false, color := Color(-1, -1, -1)) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_font_override("font", font_b)
	if color.r >= 0:
		l.add_theme_color_override("font_color", color)
	return l
