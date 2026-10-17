## v32 blue: gradual wall / building fade (Yasin's universal rule: south walls fade to transparent when the player or the
## camera is near, then fade back). Red owns the shared helper scripts/props/wall_fade.gd; every blue caller goes through step()
## below, which now delegates to red's WallFade.step().
## Usage (preload, no class_name):  const WallFade := preload("res://scripts/places/wall_fade_adapter.gd")
##   WallFade.step(mesh, hidden, dt)   # call every frame; hidden = true fades out, false fades back in
extends RefCounted

const SPEED := 3.0   # alpha per second (about 0.33 s for a full fade)

const RED := preload("res://scripts/props/wall_fade.gd")   # red's shared helper (english-game-red v32-polish-red 87e2d4a), copied unchanged

static func step(g: GeometryInstance3D, hidden: bool, dt: float, speed := SPEED) -> void:
	RED.step(g, hidden, dt, speed)
