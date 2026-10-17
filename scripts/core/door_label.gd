class_name DoorLabel
extends Label3D
## v30.2 playtest: small floating sign over every door saying where it leads; fades in as the player approaches
## (no interaction). English by default, Turkish while the TR toggle is on (App.tr_on()).
var en := ""
var tr := ""
var host: Node

static func attach(scene: Node, objs: Dictionary, doors: Dictionary) -> void:
	for id in doors:
		if not objs.has(id): continue
		var l := DoorLabel.new(); l.host = scene; l.en = doors[id][0]; l.tr = doors[id][1]
		scene.add_child(l); l.global_position = Vector3(objs[id].focus.x, 2.15, objs[id].focus.z)

static func at(parent: Node, pos: Vector3, en_t: String, tr_t: String) -> DoorLabel:
	var l := DoorLabel.new(); l.host = parent.get_tree().current_scene if parent.is_inside_tree() else null; l.en = en_t; l.tr = tr_t
	parent.add_child(l); l.global_position = pos; return l

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED; no_depth_test = true; fixed_size = true; pixel_size = 0.0011
	layers = 2   # v30.5: visual layer 2 - the mirror cameras (cull_mask 1) never show the signs
	font_size = 34; outline_size = 10; modulate = Color(1, 1, 1, 0); outline_modulate = Color(0.1, 0.12, 0.2, 0)
	var ui = get_node_or_null("/root/UI")
	if ui and ui.get("font_b") is Font: font = ui.font_b
	render_priority = 10

func _process(_d: float) -> void:
	var sc = host if host and is_instance_valid(host) else get_tree().current_scene
	var who = sc.get("hero") if sc else null
	if who == null and sc: who = sc.get("player")
	text = tr if (App.tr_on() and tr != "") else en
	var a := 0.0
	if who is Node3D:
		var d := Vector2(who.global_position.x - global_position.x, who.global_position.z - global_position.z).length()
		a = clampf((4.5 - d) / 1.5, 0.0, 1.0)
	modulate.a = lerpf(modulate.a, a, 0.15); outline_modulate.a = modulate.a * 0.85
	visible = modulate.a > 0.02
