## RoutineScope (red, open-world prep): the cancel token for story coroutines.
## v33: a routine is "alive" while its host scene is valid AND still current_scene (identical to the old
## `is_instance_valid(sc) and sc == get_tree().current_scene` guards). In the open world nothing is freed,
## so a routine is stopped with RoutineScope.cancel(host) (bumps the host's epoch) instead.
class_name RoutineScope
extends RefCounted

const META := "_routine_epoch"

## the node story routines run against (v33: current_scene; open world: the world / active region)
static func current(tree: SceneTree) -> Node:
	return tree.current_scene if tree else null

## start a routine on host and remember its epoch; pass the epoch to alive() to detect a later cancel
static func begin(host: Node) -> int:
	if not is_instance_valid(host): return -1
	return int(host.get_meta(META, 0))

## stop every routine started on host before now (no-op for v33 flow; nothing calls it yet)
static func cancel(host: Node) -> void:
	if is_instance_valid(host): host.set_meta(META, int(host.get_meta(META, 0)) + 1)

static func alive(host: Node, epoch := -1) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree(): return false
	if host != host.get_tree().current_scene: return false
	return epoch < 0 or int(host.get_meta(META, 0)) == epoch
