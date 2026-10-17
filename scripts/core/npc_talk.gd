## v32-npc-pose: the ONE shared talk routine for every NPC, family member, colleague, customer or pupil, and the player.
## Universal rule (Yasin): talking NEVER changes a character's pose or animation. Standing stays standing, sitting stays
## sitting, the idle / walk / sit clip that was playing keeps playing. On talk the character only
##   * turns toward the player: body yaw when standing, head/neck yaw only when seated (a seated body never spins off its chair)
##   * gives a subtle, repeating head nod while the line plays (bone offset on top of the current clip, no clip change).
## Why: the library clip "talk" (Mixamo "Talking", see character/animations/retarget.py) is a SEATED clip:
## Hips y about 0.54 m against about 0.87 m for idle (men_library.glb). Playing it on a standing NPC made them sit
## down for the line and stand back up when the old clip came back.
## A pose change on talk is opt-in only, for explicitly scripted scenes: pass scripted_pose to begin(), or set
## ch.set_meta("scripted_pose", "<clip>") on the character. That clip plays for the line and the previous clip
## comes back in end(). Story code that calls sit_down() / stand_up() / play() itself (breakfast, TV, hospital) is not
## affected by this file.
## Usage (preload, no class_name, so no global-class cache refresh is needed):
##   const NpcTalk := preload("res://scripts/core/npc_talk.gd")
##   var st := NpcTalk.begin(ch, player.global_position)
##   await <the line>
##   NpcTalk.end(ch, st)
extends RefCounted

## the library "talk" clip (seated). Never play it on a standing character; callers that get it from data (work.json
## tasks for the PLAYER) route it to begin()/end() instead. The player uses the same routine as the NPCs.
const TALK_CLIP := "talk"
## clips that are seated poses (the "talk" clip is seated too, see above)
const SEATED_CLIPS := ["sit_idle", "talk", "typing", "stand_to_sit"]
const HEAD_YAW_MAX := 0.7      # rad, head/neck turn limit for a seated character
const NOD := 0.12              # rad, subtle nod (livingroom _talk_nod uses 0.18 for a single nod)

static func is_seated(ch: DemoCharacter) -> bool:
	if ch == null: return false
	if String(ch.get_meta("seat", "")) != "": return true
	var a := String(ch.player.current_animation) if ch.player else ""
	return a in SEATED_CLIPS or a.begins_with("sit")

## start talking: returns a state dict for end(). Never plays a clip unless a scripted pose is asked for.
static func begin(ch: DemoCharacter, look_at: Vector3, scripted_pose := "") -> Dictionary:
	var st := {"anim": "", "speed": 1.0, "scripted": "", "nod": null, "neck": false}
	if ch == null or not is_instance_valid(ch): return st
	if ch.player: st.anim = String(ch.player.current_animation); st.speed = ch.player.speed_scale
	var sp := scripted_pose if scripted_pose != "" else String(ch.get_meta("scripted_pose", ""))
	if sp != "" and ch.player and ch.player.has_animation(sp):
		ch.play(sp, 0.25); st.scripted = sp          # explicitly scripted pose change (opt-in only)
	# face the player: body yaw when standing, head/neck yaw when seated
	var d := look_at - ch.global_position; d.y = 0.0
	if d.length() > 0.05:
		var diff := angle_difference(ch.global_rotation.y, atan2(d.x, d.z))
		if is_seated(ch) or bool(ch.get_meta("lock_yaw", false)):
			if not ch.bone_offsets.has("Neck"):   # the breakfast eating loop owns Neck while it runs
				var ang := clampf(diff, -HEAD_YAW_MAX, HEAD_YAW_MAX); st.neck = true
				ch.create_tween().tween_method(func(a: float): ch.bone_offsets["Neck"] = [Vector3.UP, a], 0.0, ang, 0.35).set_trans(Tween.TRANS_SINE)
		else:
			ch.create_tween().tween_property(ch, "rotation:y", ch.rotation.y + diff, 0.4).set_trans(Tween.TRANS_SINE)
	# subtle repeating head nod on top of whatever clip is playing (no clip change)
	if not ch.bone_offsets.has("Head"):
		var tw := ch.create_tween().set_loops()
		tw.tween_method(func(a: float): ch.bone_offsets["Head"] = [Vector3.RIGHT, a], 0.0, NOD, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(a: float): ch.bone_offsets["Head"] = [Vector3.RIGHT, a], NOD, 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(1.6)
		st.nod = tw
	return st

## stop talking: removes the nod / head turn. The animation is only touched when begin() played a scripted pose.
static func end(ch: DemoCharacter, st: Dictionary) -> void:
	if ch == null or not is_instance_valid(ch): return
	if st.get("nod") is Tween and (st.nod as Tween).is_valid(): (st.nod as Tween).kill()
	if st.get("nod") != null: ch.bone_offsets.erase("Head")
	if st.get("neck", false) and ch.bone_offsets.has("Neck"):
		var a0: float = ch.bone_offsets["Neck"][1]
		var tw := ch.create_tween(); tw.tween_method(func(a: float): ch.bone_offsets["Neck"] = [Vector3.UP, a], a0, 0.0, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): ch.bone_offsets.erase("Neck"))
	if String(st.get("scripted", "")) != "" and String(st.get("anim", "")) != "":
		ch.play(String(st.anim), 0.3, float(st.get("speed", 1.0)))
