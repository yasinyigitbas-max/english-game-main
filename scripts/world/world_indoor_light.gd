## v34 open world (blue, 3.2 lighting fix): the live room keeps its v33 lighting.
## World._build_place nulls each room's WorldEnvironment and hides its DirectionalLight (one environment / sun in the
## world), so every room was lit by the street setup (ambient 0.55, exposure 0.6, sun 1.1 with 2 splits) = far too
## bright, and the room's own day / lamp ambient tuning (main.gd / livingroom.gd / bathroom.gd `env`, `sun`) went nowhere.
## Here, every 0.2 s: the room / place the hero is in (OwLink.live, else World.region) decides the ONE environment + sun:
##   * house room: its own `env` (the v33 Environment it keeps tuning) on the World's WorldEnvironment, its own `sun`
##     visible, the World sun hidden
##   * café / shop / work: the v33 place lighting (PlaceBase._env values: ambient 0.5, exposure 0.88, sun 0.75)
##   * street: the World's environment and sun as built
extends Node

var host: Node = null
var we: WorldEnvironment
var _next := 0.0
var _cur := ""
var _room_sun: DirectionalLight3D
var _place_env: Environment
var _house_env: Environment   # a house room without its own env yet: the v33 bedroom values
var _sun_e := 1.1
var _sun_shadow_mode := 0

func _ready() -> void:
	name = "WorldIndoorLight"
	if host == null: host = get_parent()
	for c in host.get_children(): if c is WorldEnvironment: we = c; break
	var s: DirectionalLight3D = host.get("sun")
	if s: _sun_e = s.light_energy; _sun_shadow_mode = s.directional_shadow_mode
	_place_env = Environment.new(); _place_env.background_mode = Environment.BG_COLOR; _place_env.background_color = Color(0.86, 0.89, 0.93)
	_place_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; _place_env.ambient_light_color = Color(1.0, 0.95, 0.88); _place_env.ambient_light_energy = 0.5
	_place_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; _place_env.tonemap_exposure = 0.88
	_house_env = Environment.new(); _house_env.background_mode = Environment.BG_COLOR; _house_env.background_color = Color(0.72, 0.82, 0.92)
	_house_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; _house_env.ambient_light_color = Color(1.0, 0.97, 0.93); _house_env.ambient_light_energy = 0.45
	_house_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; _house_env.tonemap_exposure = 0.95

func _live() -> Array:   # [id, node]
	var ol = OwLink.inst if OwLink.active() else null
	if ol and is_instance_valid(ol.get("live")) and String(ol.get("live_id")) != "": return [String(ol.live_id), ol.live]
	var r := String(host.get("region"))
	var pl = host.get("places")
	if pl is Dictionary and pl.has(r): return [r, pl[r]]
	return ["street", null]

func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next or we == null: return
	_next = now + 0.2
	var lv := _live()
	var id: String = lv[0]; var n: Node = lv[1]
	var key := id + str(n.get_instance_id() if n else 0)
	var wsun: DirectionalLight3D = host.get("sun")
	var renv = n.get("env") if n else null
	if not (renv is Environment) and id in OwLink.ROOM_PATH: renv = _house_env
	var rsun = n.get("sun") if n else null
	if key == _cur:
		if renv is Environment and we.environment != renv: we.environment = renv   # the room swapped its env
		return
	_cur = key
	if _room_sun and is_instance_valid(_room_sun): _room_sun.visible = false; _room_sun = null
	if renv is Environment:
		we.environment = renv
		if rsun is DirectionalLight3D and is_instance_valid(rsun):
			_room_sun = rsun; _room_sun.visible = true
			if wsun: wsun.visible = false
		elif wsun: wsun.visible = true; wsun.light_energy = _sun_e * 0.7
	elif n != null and (n.is_in_group("world_places") or id in ["cafe", "shop", "work", "school"]):
		we.environment = _place_env
		if wsun: wsun.visible = true; wsun.light_energy = 0.75
	else:
		we.environment = host.get("env")
		if wsun: wsun.visible = true; wsun.light_energy = _sun_e
