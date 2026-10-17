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

## fix33 (Yasin: ALL lighting = blue): ONE derived Environment on the World's WorldEnvironment, refreshed every 0.2 s
## (and at once when the live place changes). It follows the live room's own `env` (so its lamp / power-cut / party
## tuning still works) scaled down for the open world (the v33 rooms were closed boxes with a dark outside; here the sky
## and the open south side made every room glare white), and it follows the clock: WorldState.daylight() dims the sun,
## the ambient and the sky colour, so 18:00 is dusk and 23:30 is night (street, places and the windows of the rooms).
const ROOM_AMB_K := 0.62     # room ambient x this
const ROOM_EXP := 0.78       # tonemap exposure in rooms (v33 rooms: 0.95)
const ROOM_SUN_K := 0.55     # room sun x this (it comes through the window)
const ROOM_EXP_BY := {"bathroom": 0.6}   # fix33: white tiles + the ceiling lamp blew the bathroom out to white at 0.78
const PLACE_AMB := 0.55   # 00:12: no ceiling light any more (was 0.42)
const PLACE_EXP := 0.8
const STREET_AMB := 0.5
const STREET_EXP := 0.62
const SKY_DAY := Color(0.72, 0.82, 0.92)
const SKY_DUSK := Color(0.85, 0.62, 0.48)
const SKY_NIGHT := Color(0.05, 0.07, 0.14)
var _out: Environment
var _rs_e := -1.0
var _rs_raw := 0.0   # last room sun energy the room itself wrote (we scale what the room wants)

static func sky_for(d: float) -> Color:
	return SKY_NIGHT.lerp(SKY_DUSK, clampf(d * 2.5, 0.0, 1.0)).lerp(SKY_DAY, clampf((d - 0.35) / 0.4, 0.0, 1.0))

func _derive(src: Environment, amb_k: float, amb_add: float, expo: float, d: float, adj: Environment = null) -> void:
	if _out == null:
		_out = Environment.new(); _out.background_mode = Environment.BG_COLOR
		_out.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; _out.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_out.set_meta("ow_fog", true); _out.fog_enabled = false
	_out.background_color = sky_for(d)
	if src:
		_out.ambient_light_color = src.ambient_light_color
		_out.ambient_light_energy = src.ambient_light_energy * amb_k + amb_add
		_out.glow_enabled = src.glow_enabled
	else:
		_out.ambient_light_color = Color(1.0, 0.97, 0.93).lerp(Color(0.55, 0.62, 0.9), 1.0 - d)
		_out.ambient_light_energy = amb_k * (0.25 + 0.75 * d) + amb_add
	_out.tonemap_exposure = expo
	var a: Environment = adj if adj else src
	if a:   # story looks (day-6 storm darkening, lightning flash) are tweened on the place's own env: carry them over
		_out.adjustment_brightness = a.adjustment_brightness; _out.adjustment_saturation = a.adjustment_saturation; _out.adjustment_contrast = a.adjustment_contrast
		_out.adjustment_enabled = a.adjustment_enabled or not is_equal_approx(a.adjustment_brightness, 1.0) or not is_equal_approx(a.adjustment_saturation, 1.0)
	else: _out.adjustment_enabled = false
	if we.environment != _out: we.environment = _out

func _process(_dt: float) -> void:
	# Yasin 00:12: the bright centre / ceiling light of every room and place (bedroom, bathroom, living room x2, café,
	# shop, hospital, work) is gone on every day: whatever a room / story script switches, it stays off
	for l in get_tree().get_nodes_in_group("ow_no_ceiling"):
		if (l as Light3D).visible: (l as Light3D).visible = false
		if (l as Light3D).light_energy != 0.0: (l as Light3D).light_energy = 0.0
	_sun_gate()
	if we == null: return
	var lv := _live()
	var id: String = lv[0]; var n: Node = lv[1]
	var key := id + str(n.get_instance_id() if n else 0)
	var now := Time.get_ticks_msec() / 1000.0
	if now < _next and key == _cur: return
	_next = now + 0.2
	var d := WorldState.daylight()
	var wsun: DirectionalLight3D = host.get("sun")
	var renv = n.get("env") if n else null
	var rsun = n.get("sun") if n else null
	var house := id in OwLink.ROOM_PATH
	if n and (id in OwLink.ROOM_PATH or n.is_in_group("world_places") or id in ["cafe", "shop"]):   # fix33: ONE environment - the live room's / place's own WorldEnvironment is switched off (its Environment
		# object stays the source we derive from); two active WorldEnvironments flip-flopped between visits
		for wv in n.find_children("*", "WorldEnvironment", true, false):
			var wn := wv as WorldEnvironment
			if wn != we and wn.environment != null and not (wn.get_viewport() is SubViewport): wn.environment = null
	if key != _cur:
		_cur = key
		if _room_sun and is_instance_valid(_room_sun): _room_sun.visible = false; _room_sun = null
		_rs_e = -1.0
	if house:
		# the clock: at dusk / night the ambient drops to 40 % and the exposure a little (the room's warm lamps carry the
		# evening: rooms read as night, the 18:00 storm evening no longer looks like daytime), the window sun goes to 0
		var nf := 1.0 - smoothstep(0.12, 0.65, d)   # 0 day .. 1 night (18:00 = 0.3 -> ~0.7)
		_derive(renv if renv is Environment else _house_env, ROOM_AMB_K * (1.0 - 0.6 * nf), 0.12, float(ROOM_EXP_BY.get(id, ROOM_EXP)) * (1.0 - 0.18 * nf), d)
		_out.ambient_light_color = _out.ambient_light_color.lerp(Color(0.62, 0.66, 0.9), 0.55 * nf)   # moonlit fill; the lamps stay warm
		_window_sky(n, key, d)
		# Yasin 23:58: NO extra light on room entry. The room's own DirectionalLight "sun" used to be switched on here for
		# every room the player entered (it blew the scene out): it stays off; the room keeps only its own lamps, the world
		# sun keeps its outdoor value (nothing changes at the door).
		if rsun is DirectionalLight3D and is_instance_valid(rsun): (rsun as DirectionalLight3D).visible = false
		if wsun: wsun.visible = false   # Yasin 00:21: no sun in a building
	elif n != null and (n.is_in_group("world_places") or id in ["cafe", "shop", "work", "school"]):
		_derive(null, PLACE_AMB, 0.12, PLACE_EXP, d)   # shops / café: their own lights + a floor of ambient (lit at night)
		if wsun: wsun.visible = false   # Yasin 00:21: no sun in a building
	else:
		var he: Environment = host.get("env")
		_derive(null, STREET_AMB, 0.04, STREET_EXP, d, he)
		var storm := clampf((1.0 - he.adjustment_brightness) / 0.38, 0.0, 1.0) if he else 0.0   # day-6 storm (it tweens brightness 1 -> 0.62)
		if storm > 0.0: _out.background_color = _out.background_color.lerp(Color(0.4, 0.43, 0.48), storm)
		if wsun: wsun.visible = d > 0.02 and n == null and id == "street"; wsun.light_energy = _sun_e * d * (1.0 - 0.8 * storm)

## fix33: the rooms' window views are unshaded ui/sky.png quads (livingroom N.sky, the bedroom's sky quad): they
## showed a bright day sky at 18:00 / 23:30. Tinted to the clock; a darker tint the room set itself (closed curtains,
## the day-4 power cut) is kept.
var _sky_key := ""
var _sky_mats: Array = []
func _window_sky(n: Node, key: String, d: float) -> void:
	if n == null: return
	if key != _sky_key:
		_sky_key = key; _sky_mats.clear()
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var sm = (m as MeshInstance3D).material_override
			if sm is StandardMaterial3D and (sm as StandardMaterial3D).albedo_texture and String((sm as StandardMaterial3D).albedo_texture.resource_path).ends_with("ui/sky.png"): _sky_mats.append(sm)
	var tint := Color(1, 1, 1).lerp(Color(0.95, 0.68, 0.55), clampf((0.75 - d) / 0.4, 0.0, 1.0)).lerp(Color(0.1, 0.12, 0.24), clampf((0.4 - d) / 0.35, 0.0, 1.0))
	for sm in _sky_mats:
		if not is_instance_valid(sm): continue
		var c: Color = (sm as StandardMaterial3D).albedo_color
		if c.get_luminance() > tint.get_luminance() + 0.02 or (sm as StandardMaterial3D).has_meta("ow_tint") and c.is_equal_approx((sm as StandardMaterial3D).get_meta("ow_tint")):
			(sm as StandardMaterial3D).albedo_color = tint; (sm as StandardMaterial3D).set_meta("ow_tint", tint)

## Yasin 00:21: the sun only outdoors. Every frame (idempotent): the World's sun is on only while the hero is outdoors
## (no live house room / place / hospital / school / work, World region street); every OTHER DirectionalLight (room,
## place, hospital, work suns) is always off, so no room or story script can bring sunlight into a building. Indoors the
## window light is only the window quads.
var _dirs: Array = []
var _dirs_t := 0.0
func _sun_gate() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _dirs_t:
		_dirs_t = now + 1.0
		_dirs = get_tree().root.find_children("*", "DirectionalLight3D", true, false)
	var wsun = host.get("sun") if host else null
	var lv := _live()
	var outdoors: bool = String(lv[0]) == "street" and lv[1] == null
	for l in _dirs:
		if not is_instance_valid(l) or (l as Node).get_viewport() is SubViewport: continue
		var on: bool = outdoors and l == wsun
		if not on and (l as Light3D).visible: (l as Light3D).visible = false
		elif on and not (l as Light3D).visible and WorldState.daylight() > 0.02: (l as Light3D).visible = true
