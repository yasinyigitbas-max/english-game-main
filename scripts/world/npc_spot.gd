## NpcSpot: placed in block scenes. When the block loads it borrows a pooled NPC from the exterior scene
## (npc_acquire) and gives it back when the block unloads. loop_inset > 0 = walk the block's sidewalk loop.
class_name NpcSpot
extends Node3D

@export_enum("idle", "walk") var mode := "idle"
@export var anim := "idle"
@export var line := "Hello!"
@export var loop_inset := 0.0
@export var look_seed := 1
@export var loop_phase := 0.0        # 0..1 start position along the loop
@export var reverse := false
var npc: NPC

## the exterior borrows an NPC for this spot only while the player is near (see world_exterior._npc_lod)
func _ready() -> void: add_to_group("npc_spots")

func _exit_tree() -> void:
	var w := get_tree().current_scene
	if npc and w and w.has_method("npc_release"): w.npc_release(self)

func route() -> PackedVector3Array:
	var r := loop_inset; var b := get_parent() as Node3D; var out := PackedVector3Array()
	for c in [Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(-r, 0, r)]: out.append(b.to_global(c) + Vector3(0, 0.06, 0))
	if reverse: out.reverse()
	return out
