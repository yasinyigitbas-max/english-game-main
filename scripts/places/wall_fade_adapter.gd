## v32 blue: gradual wall / building fade (Yasin's universal rule: south walls fade to transparent when the player or the
## camera is near, then fade back). Red owns the shared helper scripts/props/wall_fade.gd; it did not exist yet on
## english-game-red (checked all branches, 2026-10-17). Every blue caller goes through step() below, so swapping in red's
## helper later means changing only the body of step().
## Usage (preload, no class_name):  const WallFade := preload("res://scripts/places/wall_fade_adapter.gd")
##   WallFade.step(mesh, hidden, dt)   # call every frame; hidden = true fades out, false fades back in
extends RefCounted

const SPEED := 3.0   # alpha per second (about 0.33 s for a full fade)

static func step(g: GeometryInstance3D, hidden: bool, dt: float, speed := SPEED) -> void:
	if g == null or not is_instance_valid(g): return
	var a: float = float(g.get_meta("wf_a", 1.0))
	var to := 0.0 if hidden else 1.0
	if is_equal_approx(a, to) and g.has_meta("wf_a"): return
	a = move_toward(a, to, dt * speed); g.set_meta("wf_a", a)
	if not g.has_meta("wf_cast"): g.set_meta("wf_cast", g.cast_shadow)
	if a >= 0.999:   # fully back: original material, opaque pipeline, shadows
		if g.has_meta("wf_orig"): g.material_override = g.get_meta("wf_orig")
		g.visible = true; g.cast_shadow = g.get_meta("wf_cast")
		return
	var fm: StandardMaterial3D = g.get_meta("wf_mat") if g.has_meta("wf_mat") else null
	if fm == null:
		var base: Material = g.material_override
		if base == null and g is MeshInstance3D and (g as MeshInstance3D).mesh and (g as MeshInstance3D).mesh.get_surface_count() > 0:
			base = (g as MeshInstance3D).get_active_material(0)
		g.set_meta("wf_orig", g.material_override)
		fm = (base.duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.set_meta("wf_mat", fm)
	fm.albedo_color.a = a
	g.material_override = fm
	g.visible = a > 0.001
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
