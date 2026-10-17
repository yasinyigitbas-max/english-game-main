## Virtual analog stick (bottom-left, multitouch) + round action button (bottom-right). Mouse works via touch emulation.
extends Control
var main
var stick_idx := -1
var cam_idx := -1
var cknob := Vector2.ZERO
var act_idx := -1
var knob := Vector2.ZERO
const BASE_R := 92.0
const KNOB_R := 42.0
const ACT_R := 64.0
const CAM_R := 80.0
var hand: Texture2D = preload("res://ui/hand.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func stick_center() -> Vector2: return Vector2(170, size.y - 160)
func act_center() -> Vector2: return Vector2(size.x - 170, size.y - 360)
func cam_center() -> Vector2: return Vector2(size.x - 170, size.y - 150)

func _input(e: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if e is InputEventScreenTouch:
		var p: Vector2 = make_input_local(e).position
		if e.pressed:
			if stick_idx == -1 and p.x < size.x * 0.4 and p.y > size.y * 0.45:
				stick_idx = e.index; _move(p); get_viewport().set_input_as_handled()
			elif act_idx == -1 and p.distance_to(act_center()) < ACT_R + 16:
				act_idx = e.index; queue_redraw(); get_viewport().set_input_as_handled()
			elif cam_idx == -1 and p.x > size.x * 0.65 and p.y > size.y * 0.6:
				cam_idx = e.index; _cmove(p); get_viewport().set_input_as_handled()
		else:
			if e.index == stick_idx: stick_idx = -1; knob = Vector2.ZERO; main.stick = Vector2.ZERO; queue_redraw()
			if e.index == cam_idx: cam_idx = -1; cknob = Vector2.ZERO; main.cam_stick = Vector2.ZERO; queue_redraw()
			if e.index == act_idx: act_idx = -1; queue_redraw(); main.on_action()
	elif e is InputEventScreenDrag and e.index == stick_idx:
		_move(make_input_local(e).position); get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and e.index == cam_idx:
		_cmove(make_input_local(e).position); get_viewport().set_input_as_handled()

func _cmove(p: Vector2) -> void:
	var d := p - cam_center()
	if d.length() > CAM_R: d = d.normalized() * CAM_R
	cknob = d; main.cam_stick = d / CAM_R; queue_redraw()

func _move(p: Vector2) -> void:
	var d := p - stick_center()
	if d.length() > BASE_R: d = d.normalized() * BASE_R
	knob = d; main.stick = d / BASE_R; queue_redraw()

func _draw() -> void:
	var c := stick_center()
	draw_circle(c, BASE_R, Color(1, 1, 1, 0.16))
	draw_arc(c, BASE_R, 0, TAU, 64, Color(1, 1, 1, 0.55), 3.0, true)
	draw_circle(c + knob, KNOB_R, Color(1, 1, 1, 0.85))
	draw_circle(c + knob, KNOB_R - 14, Color(0.31, 0.42, 0.93, 0.35))
	var cc := cam_center()
	draw_circle(cc, CAM_R, Color(1, 1, 1, 0.12))
	draw_arc(cc, CAM_R, 0, TAU, 64, Color(1, 1, 1, 0.5), 3.0, true)
	for i in 4:
		var ang := i * PI / 2
		var tip := cc + Vector2(cos(ang), sin(ang)) * (CAM_R - 12)
		draw_colored_polygon(PackedVector2Array([tip, tip - Vector2(cos(ang), sin(ang)).rotated(0.5) * 14, tip - Vector2(cos(ang), sin(ang)).rotated(-0.5) * 14]), Color(1, 1, 1, 0.6))
	draw_circle(cc + cknob, 34, Color(1, 1, 1, 0.8))
	draw_arc(cc + cknob, 16, 0.4, TAU - 0.4, 24, Color(0.31, 0.42, 0.93, 0.7), 4.0, true)
	var a := act_center()
	var near: bool = main.near_id != ""
	draw_circle(a, ACT_R, Color(0.31, 0.42, 0.93, 0.92 if act_idx != -1 else 0.82) if near else Color(1, 1, 1, 0.14))
	draw_arc(a, ACT_R, 0, TAU, 64, Color(1, 1, 1, 0.7 if near else 0.35), 3.0, true)
	if near:
		var s := 78.0
		draw_texture_rect(hand, Rect2(a - Vector2(s, s) / 2, Vector2(s, s)), false, Color(1, 1, 1))
