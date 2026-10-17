extends Node
## Touch/drag scrolling with kinetic momentum for every ScrollContainer (menu and game UI).
## Works with emulate_mouse_from_touch: a press inside a ScrollContainer that moves past THRESHOLD px becomes a drag;
## the pressed button gets a synthetic release outside itself, so it does not fire. Short taps pass through untouched.
const THRESHOLD := 14.0
const FRICTION := 4.5
var sc: ScrollContainer
var press_pos := Vector2.ZERO
var start_v := 0.0
var start_h := 0.0
var dragging := false
var vel := Vector2.ZERO
var last_t := 0
var kin: ScrollContainer
var _synthetic := false
var drag_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _find(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	for n in get_tree().root.find_children("*", "ScrollContainer", true, false):
		var s := n as ScrollContainer
		if s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
			if best == null or best.is_ancestor_of(s): best = s
	return best

func _input(e: InputEvent) -> void:
	if _synthetic: return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			sc = _find(e.position); dragging = false; kin = null; vel = Vector2.ZERO
			if sc: press_pos = e.position; start_v = sc.scroll_vertical; start_h = sc.scroll_horizontal; last_t = Time.get_ticks_usec()
		else:
			if sc and dragging:
				get_viewport().set_input_as_handled()
				kin = sc
			sc = null; dragging = false
	elif e is InputEventMouseMotion and sc and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var d: Vector2 = e.position - press_pos
		if not dragging and d.length() > THRESHOLD:
			dragging = true; drag_count += 1
			_cancel_press()
		if dragging:
			var now := Time.get_ticks_usec(); var dt := maxf((now - last_t) / 1e6, 0.001); last_t = now
			var v_before := Vector2(sc.scroll_horizontal, sc.scroll_vertical)
			if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: sc.scroll_vertical = int(start_v - d.y)
			if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: sc.scroll_horizontal = int(start_h - d.x)
			vel = vel.lerp(-(e.relative as Vector2) / dt, 0.4).limit_length(3500.0)
			get_viewport().set_input_as_handled()

func _cancel_press() -> void:
	# release the button that got the press, far outside it, so it does not trigger
	_synthetic = true
	var mv := InputEventMouseMotion.new(); mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	mv.position = Vector2(-10000, -10000); mv.global_position = mv.position
	get_viewport().push_input(mv)
	var r := InputEventMouseButton.new(); r.button_index = MOUSE_BUTTON_LEFT; r.pressed = false
	r.position = Vector2(-10000, -10000); r.global_position = r.position
	get_viewport().push_input(r)
	_synthetic = false

func _process(dt: float) -> void:
	if kin == null or not is_instance_valid(kin): kin = null; return
	vel *= exp(-FRICTION * dt)
	if vel.length() < 20.0: kin = null; return
	if kin.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: kin.scroll_vertical += int(vel.y * dt)
	if kin.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED: kin.scroll_horizontal += int(vel.x * dt)
