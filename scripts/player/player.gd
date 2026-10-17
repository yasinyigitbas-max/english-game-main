## WorldPlayer: the house's player character (scripts/character.gd DemoCharacter, look from the shared save) on a
## CharacterBody3D (capsule, so streets/buildings collide), driven with the house's universal controller feel
## (scripts/player_controller.gd: walk only, max 1.955 m/s, speed eased 6 m/s^2, stick 0.64 = full speed, walk clip
## rate-matched with PlayerController.walk_rate, blend 0.3, idle blend 0.25). Camera = shared CameraRig.
class_name WorldPlayer
extends CharacterBody3D

const WALK := PlayerController.WALK      # 1.955 m/s, walk only (house.15)
const WALK_CLIP := PlayerController.WALK_CLIP
const R := 0.22

var hero: DemoCharacter
var cam: CameraRig
var hud: GameHUD
## camera properties forward to the shared CameraRig (ui/shared/camera_rig.gd)
var cam_pitch: float:
	get: return cam.pitch if cam else 0.9025
	set(v): if cam: cam.pitch = v
var cam_dist: float:
	get: return cam.dist if cam else 9.68
	set(v): if cam: cam.dist = v; cam.max_dist = maxf(cam.max_dist, v)
var cam_override: Vector3:
	get: return cam.override_point if cam else Vector3.INF
	set(v): if cam: cam.override_point = v
var stick := Vector2.ZERO
var cam_stick: Vector2:
	get: return cam.cam_stick if cam else Vector2.ZERO
	set(v): if cam: cam.cam_stick = v
var surface_func: Callable          # func(pos: Vector3) -> "grass" | "pave"
var _step_state := {}
var floor_y := 0.0
var walking := false
var running := false
var frozen := false
var near: Interactable
var sitting := false
var busy := false
var walk_cap_t := 0.0
var move_sp := 0.0
var _cap: CollisionShape3D

func _ready() -> void:
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = R; cap.height = 1.6
	cs.shape = cap; cs.position.y = 0.8; add_child(cs); _cap = cs
	hero = DemoCharacter.new(); add_child(hero)
	apply_look()
	hero.play("idle", 0.0)
	Game.character_changed.connect(apply_look)   # auto-disconnects when the player is freed

## persistent character: built by the hook from the bedroom creator, rebuilt on Game.character_changed
func apply_look(c: Dictionary = {}) -> void:
	Game.apply_character(self, c)
	if hero.player.current_animation == "": hero.play("idle", 0.0)
	# body size follows the creator (child / short / tall): capsule height = model scale
	var sc := CharacterHook.body_scale(hero)
	if _cap: (_cap.shape as CapsuleShape3D).height = maxf(1.6 * sc, 2.0 * R + 0.05); _cap.position.y = 0.8 * sc


func attach_camera(c: CameraRig, dist: float, pitch: float) -> void:
	cam = c; c.setup(self, dist, pitch, 4.0, dist * 2.0)

func face(yaw: float) -> void: hero.rotation.y = yaw

## v34 open world (World API): scripted walk in a straight line (story code moves the ONE hero; never spawns one)
func move_to(p: Vector3, yaw := INF) -> void:
	busy = true
	# in a house room the hero is lent to the room (red's OwLink): move the hero itself, else this body
	var body: Node3D = self if hero.get_parent() == self else hero
	var to := Vector3(p.x, body.global_position.y, p.z)
	hero.player.play("walk", 0.3)
	var t := 0.0
	while is_instance_valid(body) and body.is_inside_tree() and Vector2(to.x - body.global_position.x, to.z - body.global_position.z).length() > 0.08 and t < 20.0:
		var dt := 1.0 / 60.0
		var d := to - body.global_position; d.y = 0
		hero.global_rotation.y = lerp_angle(hero.global_rotation.y, atan2(d.x, d.z), 1.0 - exp(-12.0 * dt))
		body.global_position += d.normalized() * minf(WALK * dt, d.length())
		t += dt
		await get_tree().process_frame
	PlayerController.stop_if_walking(hero)
	if yaw != INF: face(yaw)
	busy = false
## v34 open world: put the hero at a door / spot id (World.spot) - only for skip_travel (car, bus, ambulance)
func place_at(id: String) -> void:
	var w = load("res://scripts/core/world.gd")
	var p: Vector3 = w.spot(id)
	var wd = w.get_world()
	if wd: floor_y = 0.07 if wd.region_at(p) == "street" else p.y
	global_position = Vector3(p.x, floor_y, p.z)
	var y: float = w.spot_yaw(id)
	if y != INF: face(y)

func _physics_process(dt: float) -> void:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D): v.x += 1
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S): v.y += 1
	if stick.length() > 0.05: v = stick
	if v.length() > 1.0: v = v.normalized()
	if frozen or busy or sitting or Game.busy: v = Vector2.ZERO
	walk_cap_t -= dt
	var amt := v.length()
	running = false
	if amt > 0.12:
		var dir := Vector3(v.x, 0, v.y).normalized().rotated(Vector3.UP, cam.yaw if cam else 0.0)
		# PlayerController.step() feel (the house's controller), on a physics body
		move_sp = move_toward(move_sp, WALK * clampf(amt / PlayerController.FULL, 0.35, 1.0), 6.0 * dt)
		velocity = dir * move_sp
		hero.rotation.y = lerp_angle(hero.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * dt))
		if hero.player.current_animation != "walk": hero.player.play("walk", 0.3)
		hero.player.speed_scale = PlayerController.walk_rate(hero, move_sp)
		if not walking and walk_cap_t <= 0.0:
			walk_cap_t = 25.0
			var w := get_tree().current_scene
			if w and w.has_method("caption_if_free"): w.caption_if_free("I am walking.")
		walking = true
	else:
		velocity = Vector3.ZERO; move_sp = 0.0
		if walking and not busy: PlayerController.stop_if_walking(hero)
		walking = false
	if _bump.length() > 0.05: velocity += _bump; _bump = _bump.move_toward(Vector3.ZERO, 6.0 * dt)
	if not busy and not sitting: move_and_slide()
	if not sitting: global_position.y = floor_y
	var ap := hero.player
	if Footsteps.contact(ap, hero.anim_length(ap.current_animation) if ap.current_animation != "" else 0.0, _step_state):
		Footsteps.player_step(self, surface_func.call(_planting_foot()) if surface_func.is_valid() else "pave")
	_scan()

func _scan() -> void:
	var best: Interactable = null; var bd := INF
	for n in get_tree().get_nodes_in_group("interact"):
		var it := n as Interactable
		if not it.enabled or not it.is_visible_in_tree(): continue
		var d := Vector2(it.global_position.x - global_position.x, it.global_position.z - global_position.z).length()
		if d < it.radius and d < bd: bd = d; best = it
	if busy: return
	if best != near:
		near = best
		if hud: hud.set_near(near)

func use() -> void:
	if hud: hud.on_action()

## bedroom-style verb: walk to the object's spot, face it, then run the verb
func perform(it: Interactable, cb: Callable) -> void:
	if busy or Game.busy or not is_instance_valid(it): return
	busy = true
	if it.walk_to and not sitting:
		var target := Vector3(it.global_position.x, floor_y, it.global_position.z)
		var t := 0.0
		if Vector2(target.x - global_position.x, target.z - global_position.z).length() > 0.2:
			hero.play("walk", 0.2, 1.0)
			while t < 3.0:
				var d := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
				if d.length() < 0.12: break
				velocity = d.normalized() * minf(WALK, d.length() * 4.0 + 0.3)
				hero.rotation.y = lerp_angle(hero.rotation.y, atan2(d.x, d.z), 0.25)
				move_and_slide(); global_position.y = floor_y
				await get_tree().physics_frame; t += 1.0 / 60.0
			velocity = Vector3.ZERO; hero.play("idle", 0.2)
		var f := it.focus_point() - global_position
		var yaw := atan2(f.x, f.z); var t2 := 0.0
		while t2 < 0.35:
			hero.rotation.y = lerp_angle(hero.rotation.y, yaw, 0.3); await get_tree().process_frame; t2 += get_process_delta_time()
	busy = false
	near = null; _scan()
	await cb.call()
	near = null; _scan()

var _bump := Vector3.ZERO
var _bump_cap := 0.0
## a moving vehicle touched the player: small shove + caption
func bumped(v: Vector3) -> void:
	_bump = v.limit_length(3.0) * 0.6
	if Time.get_ticks_msec() / 1000.0 > _bump_cap and hud: _bump_cap = Time.get_ticks_msec() / 1000.0 + 6.0; (get_tree().current_scene.caption("Be careful! A car is coming.") if get_tree().current_scene.has_method("caption") else hud.caption("Be careful! A car is coming."))

func sit_at(p: Vector3, yaw: float) -> void:
	sitting = true; global_position = p; hero.rotation.y = yaw; hero.play("sit_idle", 0.3)

func stand_up() -> void:
	sitting = false; global_position += Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y)) * 0.55; hero.play("idle", 0.3)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER]: use()
		elif e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_5 and hud and hud.chips.get_child_count() > e.physical_keycode - KEY_1 + 1:
			(hud.chips.get_child(e.physical_keycode - KEY_1 + 1) as Button).pressed.emit()

## house.27: surface under the foot that is landing NOW (lower foot bone), no caching -> sound switches on the very step
func _planting_foot() -> Vector3:
	var sk: Skeleton3D = hero.skeleton if hero else null
	if sk:
		var best := Vector3.ZERO; var by := 1e9
		for bn in ["Foot.L", "Foot.R", "foot.L", "foot.R", "LeftFoot", "RightFoot"]:
			var i := sk.find_bone(bn)
			if i >= 0:
				var gp: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
				if gp.y < by: by = gp.y; best = gp
		if by < 1e8: return best
	return global_position + Vector3(sin(hero.rotation.y), 0, cos(hero.rotation.y)) * 0.3
