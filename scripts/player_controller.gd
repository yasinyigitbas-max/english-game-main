class_name PlayerController
## house.16 universal player controller (the bedroom's): walk only, max 1.955 m/s, walk clip rate-matched so the
## heel-toe walk (DemoCharacter foot fix) never slides. Used by main.gd, bathroom.gd and livingroom.gd.
## Host needs: hero (DemoCharacter), move_sp, resolve(p), _face(d, dt).
const WALK := 1.955
const WALK_CLIP := 1.7
const FULL := 0.64          # stick length that gives full walk speed

static func walk_rate(hero, sp: float) -> float:
	return clampf(sp / (WALK_CLIP * hero.model.scale.y), 0.5, 1.8)

## one frame of stick walking along world direction d (stick length sl)
static func step(host, d: Vector3, sl: float, dt: float) -> void:
	var hero = host.hero
	host.move_sp = move_toward(host.move_sp, WALK * clampf(sl / FULL, 0.35, 1.0), 6.0 * dt)
	host.hero.position = host.resolve(hero.position + d.normalized() * host.move_sp * dt)
	host._face(d, dt)
	if hero.player.current_animation != "walk": hero.player.play("walk", 0.3)
	hero.player.speed_scale = walk_rate(hero, host.move_sp)

static func stop_if_walking(hero) -> void:
	if hero.player.current_animation in ["walk", "run"]:
		hero.player.speed_scale = 1.0; hero.play("idle", 0.25)
