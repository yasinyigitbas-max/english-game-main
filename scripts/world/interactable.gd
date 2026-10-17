## Interactable: something the player can use. Same flow as the bedroom: when the player is within `radius`
## the round hand button lights up; pressing it shows verb chips (object name on top); choosing a verb makes the
## player walk to the spot (this node's position), face `focus`, and run the verb.
##   verbs: Callable returning [[label_en, Callable], ...]   (or a single prompt_en + action)
class_name Interactable
extends Node3D

@export var obj_name := ""
@export var prompt_en := "Open"
@export var prompt_tr := "Aç"
@export var radius := 1.4
var action: Callable
var verbs: Callable
var focus := Vector3.INF          # world point to face; INF = straight ahead along -local Z
var walk_to := true
var enabled := true

func _enter_tree() -> void: add_to_group("interact")

func verb_list() -> Array:
	if verbs.is_valid(): return verbs.call()
	return [[prompt_en, action]]

func focus_point() -> Vector3:
	return focus if focus != Vector3.INF else global_position - global_transform.basis.z

static func make(parent: Node, pos: Vector3, en: String, tr: String, r: float, cb: Callable) -> Interactable:
	var it := Interactable.new(); it.prompt_en = en; it.prompt_tr = tr; it.radius = r; it.action = cb
	it.position = pos; parent.add_child(it); return it
