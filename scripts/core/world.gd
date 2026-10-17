class_name World
extends UniversalScene
const _WorldPlacesS := preload("res://scripts/world/world_places.gd")
const TestScreen := preload("res://scripts/core/test_screen.gd")
## v34 open world (phase 1 skeleton, black): ONE gameplay scene. Every place is built once at load at a fixed world
## position and never freed, rebuilt or shifted: the street (all city blocks), the house (bedroom, bathroom, living
## room inside the home lot), the cafe and the shop interiors inside their street lots. One hero (WorldPlayer), one
## camera (CameraRig driven by blue's shoulder camera), one HUD. Doors are the rooms' own hinged leaves: they swing
## open when the hero comes close and close behind, so you see the furnished room behind them. No change_scene, no fade.
## Phase 1 = geometry + walking only: the rooms / places run no story code yet (red ports it onto this API).
## See OPENWORLD_PLAN.md for positions, door ids, the API and the culling setup.
const HouseC := preload("res://scripts/core/house.gd")
const BEDROOM := "res://main.tscn"
const BATHROOM := "res://bathroom.tscn"
const LIVING := "res://livingroom.tscn"
const CAFE := "res://scenes/places/cafe.tscn"
const SHOP := "res://scenes/places/shop.tscn"
## fixed world placement (house: living room origin on the home lot, from the v33 town layout; rooms keep the v32wh offsets)
const HOUSE_AT := Vector3(-5.35, 0.1, -0.4)
const PLACES := {
	"bedroom": [BEDROOM, Vector3(0, 0, -6.0), 0.0], "bathroom": [BATHROOM, Vector3(5.95, 0, -4.75), 0.0], "livingroom": [LIVING, Vector3.ZERO, 0.0],
	"cafe": [CAFE, Vector3(8.5, 0.07, 32.5), PI], "shop": [SHOP, Vector3(-3.0, 0.07, 33.5), PI],
}
const HOME_LOTS := {"home": "livingroom", "cafe": "cafe", "corner_shop": "shop"}
## reserved slots far north (red's OwLink extra places: hospital day 2, child-drive stop; blue's WorldPlaces work)
const RESERVED := {"hospital": Vector3(0, 0, -120), "school": Vector3(120, 0, -120), "work": Vector3(-120, 0, -120)}
const SPOTS := {}
const OWPlaces := preload("res://scripts/world/ow_places.gd")   # hospital / school / work (north strip, behind the fence)
const ACTIVE_R := 45.0           # places farther than this from the hero are hidden (and, once live, not processed)
const FENCE_DAY := 8
const LIGHT_NEAR := 15.0         # omni / spot lights farther than this from the hero are off (Yasin 19:03)
const VIS_END := 28.0            # props, NPCs, street parts, place exteriors: not drawn beyond ~28 m (+ fade margin)
const FAR := 35.0                # camera far plane (Yasin 19:03 draw distance), hidden by depth fog
const FOG_BEGIN := 20.0
const SHADOW_LIGHTS := 2         # only the nearest lights cast shadows
const HOUSE_ROOMS := ["bedroom", "bathroom", "livingroom"]

static var inst: World
signal entered(region: String, from: String)
signal left(region: String)
var env: Environment
var sun: DirectionalLight3D
var grid: WorldGrid
var places := {}          # id -> Node3D (room / place instance)
var regions := {}         # id -> AABB (world)
var doors := {}           # id -> WorldDoor
var region := ""
var last_door := ""
var spots := {}           # fixed spot id -> [world position, yaw]  (place_at / skip_travel targets)
var active := {}          # place id -> bool (near the hero)
signal active_changed(place: String, on: bool)
var _day := -1
var fences: Node3D
var _lights: Array = []
var _t := 0.0

func _ready() -> void:
	inst = self
	WorldState.ensure_loaded(); WorldState.scene = scene_file_path
	_env()
	grid = WorldGrid.new(); grid.name = "Street"; add_child(grid)
	for z in range(grid.bounds_min.y, grid.bounds_max.y + 1):
		for x in range(grid.bounds_min.x, grid.bounds_max.x + 1):
			var c := Vector2i(x, z); if not grid.loaded.has(c): grid._spawn(c, load(grid.scene_for(c)))
	for id in PLACES: _build_place(id)
	_house_shell()
	for lot_id in HOME_LOTS: _open_lot(lot_id, HOME_LOTS[lot_id])
	OWPlaces.build(self)
	_home_spots()
	_build_doors()
	_late_places.call_deferred()   # after the world-mode places' deferred _world_init (they build there)
	_build_fences()
	hud = (load("res://ui/shared/hud.tscn") as PackedScene).instantiate(); add_child(hud)
	player = WorldPlayer.new(); player.name = "Hero"; add_child(player); player.hud = hud; hud.player = player; player.floor_y = 0.07
	player.surface_func = func(_p: Vector3) -> String: return "pave"
	var start: Vector3 = places.bedroom.to_global(Vector3(-0.6, 0, 0.9))
	player.global_position = Vector3(start.x, places.bedroom.global_position.y, start.z); player.face(PI)
	player.floor_y = places.bedroom.global_position.y
	cam = (load("res://ui/shared/camera_rig.tscn") as PackedScene).instantiate(); cam.far = FAR; add_child(cam)
	hud.camera = cam; player.attach_camera(cam, 8.0, 0.82)
	setup_universal("Home", "Ev")
	hud.set_mission("")
	for l in find_children("*", "OmniLight3D", true, false) + find_children("*", "SpotLight3D", true, false): _lights.append(l)
	_cull_setup()
	var _bo: Dictionary = preload("res://scripts/world/world_blue.gd").install(self, {"culling": false, "work": true, "merge": not "--ow-no-merge" in OS.get_cmdline_user_args()})   # blue: wall fade, cafe/shop fronts, merge, door no_fade
	# blue's WorldCulling with the 19:03 draw-distance limits (~28 m; buildings / merged blocks bigger than 30 m stay on, cut by far + fog)
	var wc: Node = load("res://scripts/world/world_culling.gd").new(); wc.set("host", self)
	for kv in [["prop_range", 18.0], ["interior_range", 26.0], ["mid_range", VIS_END], ["far_range", VIS_END + 4.0], ["big_size", 30.0], ["light_range", LIGHT_NEAR], ["shadow_range", 8.0], ["sun_shadow", 24.0]]: wc.set(kv[0], kv[1])
	add_child(wc)
	OwLink.attach(self)   # red: story port (live room / place = current_scene, one hero, travel fades only)
	print("WORLD ready places=%s doors=%s regions=%s lights=%d" % [places.keys(), doors.keys(), regions.keys(), _lights.size()])

## depth fog that ends at the far plane (hides the draw-distance cut); applied to whatever environment is in use
func _fog(e: Environment) -> void:
	if e == null or e.has_meta("ow_fog"): return
	e.set_meta("ow_fog", true)
	e.fog_enabled = false   # build 3.1 (Yasin 19:22): no fog at all, it washed the street + hero white; hard 35 m far plane + ranges only
	return
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_depth_begin = FOG_BEGIN; e.fog_depth_end = FAR - 1.0; e.fog_depth_curve = 1.0
	e.fog_light_color = e.background_color if e.background_mode == Environment.BG_COLOR else Color(0.72, 0.82, 0.92)
	e.fog_light_energy = 1.0; e.fog_sun_scatter = 0.0; e.fog_sky_affect = 1.0; e.fog_density = 1.0

func _env() -> void:
	var we := WorldEnvironment.new(); env = Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.72, 0.82, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(1.0, 0.97, 0.93); env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 0.6
	_fog(env)
	we.environment = env; add_child(we)
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 1.1; add_child(sun)
	sun.look_at_from_position(Vector3(7, 8, -9), Vector3.ZERO)
	sun.directional_shadow_max_distance = 30.0; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

# ------------------------------------------------------------ places
func _build_place(id: String) -> void:
	var d: Array = PLACES[id]
	var ps := load(d[0]) as PackedScene
	var n: Node3D = ps.instantiate()
	n.name = "Place_" + id
	var house := HouseC.is_room(d[0])
	if house: n.set_meta(HouseC.SHELL, true)         # rooms: geometry + furniture only (House.shell_ready)
	else: n.set("world_mode", true); n.set("host", self)   # cafe / shop: blue's full world-mode place (its own real door; red's OwLink starts it)
	n.transform = Transform3D(Basis(Vector3.UP, d[2]), (HOUSE_AT + d[1]) if house else d[1])
	add_child(n)
	if house: HouseC._cheap(n, false)
	n.process_mode = Node.PROCESS_MODE_DISABLED   # phase 1: no room / place logic (red ports it); NPCs hold their pose
	var all: Array = []; _walk(n, all)
	for c in all:
		if c is MeshInstance3D and (c as MeshInstance3D).mesh and ((c as MeshInstance3D).get_aabb().size.x >= 20.0 or (c as MeshInstance3D).get_aabb().size.z >= 20.0):
			(c as MeshInstance3D).visible = false      # each room's own outdoor ground: the street is the ground now
		if c is Label3D: (c as Label3D).visible = false
		if c is WorldEnvironment: (c as WorldEnvironment).environment = null
		if c is DirectionalLight3D: (c as DirectionalLight3D).visible = false
		if c is Camera3D and not (c.get_viewport() is SubViewport): (c as Camera3D).current = false
		if c is CanvasLayer: (c as CanvasLayer).visible = false
	if house: _room_colliders(n); _room_ceiling(n)
	places[id] = n
	if n.get("room") is Vector2:   # cafe / shop: their floor rect (their terrace / props stay street)
		var rm: Vector2 = n.get("room"); var c0 := n.to_global(Vector3(-rm.x / 2, 0, -rm.y / 2)); var c1 := n.to_global(Vector3(rm.x / 2, 3, rm.y / 2))
		regions[id] = AABB(Vector3(minf(c0.x, c1.x), 0, minf(c0.z, c1.z)), Vector3(absf(c1.x - c0.x), 3, absf(c1.z - c0.z)))
	else: regions[id] = _bounds(n)

## fix33 (black): the rooms' tap hint was a 3D billboard hand (fixed world size, no depth test): under the close shoulder
## camera it filled the screen. The 3D sprite now renders on no layer (the rooms keep driving its visible/position) and a
## small 2D HUD hand is drawn where it projects, bobbing, hidden when it is behind the camera or off-screen.
var _hint_layer: CanvasLayer
var _hint: Control
func _tap_hint() -> void:
	var live = OwLink.inst.live if OwLink.inst else null
	var h3: Node3D = live.get("hand3d") if live and is_instance_valid(live) and "hand3d" in live else null
	if h3 and is_instance_valid(h3) and h3 is VisualInstance3D and (h3 as VisualInstance3D).layers != 0:
		(h3 as VisualInstance3D).layers = 0   # rendered by no camera (the room keeps its visible / position as the hint anchor)
	var show := false; var sp := Vector2.ZERO
	var c3 := get_viewport().get_camera_3d()
	var ui_up: bool = String(live.get("mode")) != "play" if live and live.get("mode") != null else false   # busy / cut-scene: no hint
	if not ui_up: ui_up = Objectives._phone_open() or TestScreen.active(get_tree())   # phone pages / tests / puzzles cover the room
	if not ui_up and h3 and is_instance_valid(h3) and h3.is_visible_in_tree() and c3 and not c3.is_position_behind(h3.global_position):
		sp = c3.unproject_position(h3.global_position)
		var vr := get_viewport().get_visible_rect()
		show = vr.grow(-24).has_point(sp)
	if _hint == null:
		if not show: return
		_hint_layer = CanvasLayer.new(); _hint_layer.layer = 4; _hint_layer.name = "TapHint2D"; add_child(_hint_layer)
		var badge := Panel.new(); badge.size = Vector2(52, 52); badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.36, 0.45, 0.86, 0.92); sb.set_corner_radius_all(26); sb.set_border_width_all(3); sb.border_color = Color(1, 1, 1, 0.95)
		sb.shadow_color = Color(0, 0, 0, 0.25); sb.shadow_size = 4; badge.add_theme_stylebox_override("panel", sb)
		var hr := TextureRect.new(); hr.texture = load("res://ui/hand.png"); hr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; hr.position = Vector2(10, 9); hr.size = Vector2(32, 32); hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_child(hr); _hint = badge; _hint_layer.add_child(badge)
	_hint.visible = show
	if show: _hint.position = sp - Vector2(26, 60 + 5.0 * sin(Time.get_ticks_msec() * 0.005))   # canvas coords (unproject_position is in the stretched viewport space)

## fix33 (black): the house rooms had NO visible ceiling (their roof slab is SHADOWS_ONLY, built for the old top-down
## camera), so blue's shoulder camera looked up into the black. Each roof slab gets a down-facing ceiling quad just under
## it: visible from inside, back-face culled from above (overhead / cine cameras still see in), casts no shadow (daylight unchanged).
func _room_ceiling(n: Node3D) -> void:
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.96, 0.96, 0.95); cm.roughness = 0.95
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not (mi.mesh is BoxMesh): continue
		var sz: Vector3 = (mi.mesh as BoxMesh).size
		if sz.y > 0.15 or sz.x < 2.0 or sz.z < 2.0: continue
		var q := MeshInstance3D.new(); q.name = "OWCeiling"; var qm := QuadMesh.new(); qm.size = Vector2(sz.x - 0.1, sz.z - 0.1); q.mesh = qm
		q.material_override = cm; q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.transform = Transform3D(mi.transform.basis * Basis(Vector3.RIGHT, PI / 2), mi.transform.origin - mi.transform.basis.y * (sz.y / 2.0 + 0.004))
		q.set_meta("no_fade", true); mi.get_parent().add_child(q)

func _walk(n: Node, out: Array) -> void:
	for c in n.get_children(): out.append(c); _walk(c, out)

func _bounds(n: Node3D) -> AABB:
	var ab := AABB(); var first := true
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or not mi.visible: continue
		var b := mi.global_transform * mi.get_aabb()
		if b.size.x > 19.0 or b.size.z > 19.0: continue
		if first: ab = b; first = false
		else: ab = ab.merge(b)
	return ab

## house rooms have no physics (they used a grid): walls (thin tall boxes) and the furniture rectangles become colliders
func _room_colliders(n: Node3D) -> void:
	var body := StaticBody3D.new(); body.name = "OWBody"; n.add_child(body)
	var leaves := []
	for k in ["door", "door_s", "door_bed", "door_bath", "front"]:
		var N = n.get("N")
		if N is Dictionary and N.has(k) and N[k] is Node3D: leaves.append(N[k])
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or not (mi.mesh is BoxMesh): continue
		var skip := false
		for lf in leaves: if lf == mi or (lf as Node).is_ancestor_of(mi): skip = true
		if skip: continue
		var ab := mi.global_transform * mi.get_aabb()
		var s := ab.size
		if s.y >= 1.6 and s.y < 6.0 and minf(s.x, s.z) <= 0.35 and maxf(s.x, s.z) >= 0.3 and ab.position.y < 0.5 + n.global_position.y:
			_box_col(body, ab)
	var obs = n.get("obstacles")
	if obs is Array:
		for r in obs:
			if not (r is Rect2): continue
			var rr: Rect2 = r
			var lo: Vector3 = n.to_global(Vector3(rr.position.x, 0, rr.position.y)); var hi: Vector3 = n.to_global(Vector3(rr.end.x, 1.0, rr.end.y))
			_box_col(body, AABB(Vector3(minf(lo.x, hi.x), lo.y, minf(lo.z, hi.z)), Vector3(absf(hi.x - lo.x), 1.0, absf(hi.z - lo.z))))

func _box_col(body: StaticBody3D, ab: AABB) -> void:
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = ab.size; cs.shape = bs
	body.add_child(cs); cs.global_position = ab.get_center()

## the street lot that holds an interior: its solid building box / collider / fake door go away, the interior stands there
func _open_lot(lot_id: String, place: String) -> void:
	var lot := grid.find_lot(lot_id)
	if lot == null: push_warning("World: lot %s not found" % lot_id); return
	var lc := lot.global_transform * Vector3(0, 1.5, 0)
	for m in get_tree().get_nodes_in_group("fade"):
		if m is MeshInstance3D:
			var ab: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if ab.grow(0.2).has_point(Vector3(lc.x, 1.0, lc.z)) and ab.size.x < 20.0: (m as MeshInstance3D).visible = false; (m as Node).remove_from_group("fade"); m.set_meta("ow_removed", true)
	for cs in lot.get_parent().find_children("*", "CollisionShape3D", true, false):
		if (cs as Node3D).global_position.distance_to(lc) < 0.6: (cs as CollisionShape3D).disabled = true
	if lot.door_pivot: lot.door_pivot.visible = false
	for it in lot.find_children("*", "Interactable", true, false): it.queue_free()
	for c in lot.get_children(): if c is Interactable: c.queue_free()

## cafe / shop: their front wall had a painted door; cut a real 1.3 m opening and hang a swinging leaf in it
func _cut_place_door(n: Node3D) -> void:
	var rm: Vector2 = n.get("room")
	var hx := rm.x / 2.0; var hz := rm.y / 2.0
	for g in n.get_children():
		if g is MeshInstance3D and (g as MeshInstance3D).mesh is BoxMesh:
			var s: Vector3 = ((g as MeshInstance3D).mesh as BoxMesh).size; var p: Vector3 = (g as MeshInstance3D).position
			if absf(p.z - hz) < 0.15 and absf(s.x - rm.x) < 0.05 and s.y >= 2.5: (g as MeshInstance3D).visible = false
			elif absf(p.z - (hz - 0.09)) < 0.03 and absf(s.x - 1.2) < 0.01: (g as MeshInstance3D).visible = false      # painted door
			elif absf(p.z - (hz - 0.125)) < 0.03 and absf(s.x - 0.9) < 0.01: (g as MeshInstance3D).visible = false     # its glass
		if g is StaticBody3D and absf((g as Node3D).position.z - hz) < 0.15 and absf((g as Node3D).position.x) < 0.1: g.queue_free()
	var gap := 0.65
	var wc: Color = (n.call("floor_colors") as Array)[1]
	for sx in [-1.0, 1.0]:
		var w := hx - gap
		n.call("box", Vector3(w, 3.0, 0.14), Vector3(sx * (gap + w / 2.0), 1.5, hz), wc)
	n.call("box", Vector3(gap * 2.0, 0.8, 0.14), Vector3(0, 2.6, hz), wc, false)
	var pv := Node3D.new(); pv.name = "OWDoor"; pv.position = Vector3(-gap, 0, hz); n.add_child(pv)
	var leaf := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(gap * 2.0 - 0.04, 2.15, 0.06); leaf.mesh = bm
	var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.35, 0.25, 0.18); leaf.material_override = mt; leaf.position = Vector3(gap - 0.02, 1.08, 0); pv.add_child(leaf)
	n.set_meta("ow_door", pv)

# ------------------------------------------------------------ doors
## [id, place, N key (or "ow"), open angle, regions a / b]; duplicate leaves (bathroom's copy of the bedroom door) hidden
func _build_doors() -> void:
	var defs := [["bed_bath", "bedroom", "door", 80.0, "bedroom", "bathroom"], ["bed_living", "bedroom", "door_s", -82.0, "bedroom", "livingroom"],
		["bath_living", "bathroom", "door", -82.0, "bathroom", "livingroom"], ["front", "livingroom", "front", 82.0, "livingroom", "street"],
		["cafe", "cafe", "ow", -100.0, "cafe", "street"], ["shop", "shop", "ow", -100.0, "shop", "street"]]
	var bN = places.bathroom.get("N")
	if bN is Dictionary and bN.has("door_bed"): (bN.door_bed as Node3D).visible = false
	for d in defs:
		var n: Node3D = places[d[1]]
		var leaf: Node3D = null
		if d[1] in ["cafe", "shop"]: continue   # world-mode places: _late_places
		if d[2] == "ow": leaf = n.get_meta("ow_door", null)
		else:
			var N = n.get("N")
			if N is Dictionary and N.has(d[2]): leaf = N[d[2]]
		if leaf == null: push_warning("World: no leaf for door " + d[0]); continue
		var dr := WorldDoor.new(); dr.id = d[0]; dr.leaf = leaf; dr.open_angle = deg_to_rad(d[3]); dr.a = d[4]; dr.b = d[5]
		dr.closed_angle = leaf.rotation.y; dr.name = "Door_" + String(d[0]); add_child(dr)
		if d[1] in ["bedroom", "bathroom", "livingroom"]: dr.auto = false   # the room story code opens / locks these (day-1 locked door)
		doors[d[0]] = dr; dr.c0 = dr.center()

## cafe / shop (world mode) built in their deferred _world_init: region = floor rect, door = their FrontDoor hinge
func _late_places() -> void:
	var wp = _WorldPlacesS.get_place("work")   # fix33 (black): preload, not the global class name (stale .godot class cache -> parse error)
	if wp and not places.has("work"): places["work"] = wp
	for id in ["cafe", "shop", "work"]:
		if not places.has(id): continue
		var n: Node3D = places[id]
		var rm: Vector2 = n.get("room"); var c0 := n.to_global(Vector3(-rm.x / 2, 0, -rm.y / 2)); var c1 := n.to_global(Vector3(rm.x / 2, 3, rm.y / 2))
		regions[id] = AABB(Vector3(minf(c0.x, c1.x), 0, minf(c0.z, c1.z)), Vector3(absf(c1.x - c0.x), 3, absf(c1.z - c0.z)))
		var leaf: Node3D = n.get("door_hinge")
		if leaf == null and id == "work": continue
		if leaf == null: push_warning("World: no FrontDoor in " + id); continue
		leaf.set_meta("ow_world_door", true); leaf.set_meta("no_fade", true); leaf.add_to_group("doors")
		var dr := WorldDoor.new(); dr.id = id; dr.leaf = leaf; dr.open_angle = -1.75; dr.auto = id != "work"; dr.a = id; dr.b = "street"
		dr.closed_angle = leaf.rotation.y; dr.name = "Door_" + id; add_child(dr); doors[id] = dr; dr.c0 = dr.center()
	for l in find_children("*", "OmniLight3D", true, false) + find_children("*", "SpotLight3D", true, false): if not l in _lights: _lights.append(l)

class WorldDoor extends Node:
	var id := ""
	var leaf: Node3D
	var open_angle := 1.4
	var closed_angle := 0.0
	var a := ""; var b := ""
	var is_open := false
	var auto := true
	var _tw: Tween
	var c0 := Vector3.INF     # doorway centre (taken while closed: the leaf moves when open)
	func center() -> Vector3:
		if c0 != Vector3.INF: return c0
		var ab := AABB(); var first := true
		for m in leaf.find_children("*", "MeshInstance3D", true, false):
			var x: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if first: ab = x; first = false
			else: ab = ab.merge(x)
		return ab.get_center() if not first else leaf.global_position
	func open() -> void:
		if is_open: return
		is_open = true; Audio.sfx("doorOpen_1", -4.0); _swing(open_angle)
	func close() -> void:
		if not is_open: return
		is_open = false; _swing(closed_angle)
	func _swing(to: float) -> void:
		if _tw and _tw.is_valid(): _tw.kill()
		_tw = create_tween(); _tw.tween_property(leaf, "rotation:y", to, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	## story: open and let the hero walk through to the other side (phase 2: path walk)
	func walk_through(h: Node3D) -> void:
		open(); await leaf.get_tree().create_timer(0.4).timeout
		var c := center(); var d := Vector3(c.x - h.global_position.x, 0, c.z - h.global_position.z)
		var to := Vector3(c.x, h.global_position.y, c.z) + d.normalized() * 1.0
		if h.has_method("move_to"): await h.move_to(to)

# ------------------------------------------------------------ fences (construction barriers on every street at the edge until day 8)
func _build_fences() -> void:
	fences = Node3D.new(); fences.name = "Fences"; add_child(fences)
	var lo := grid.cell_center(grid.bounds_min) - Vector3.ONE * grid.block_size * 0.5
	var hi := grid.cell_center(grid.bounds_max) + Vector3.ONE * grid.block_size * 0.5
	var stripe := StandardMaterial3D.new(); stripe.albedo_color = Color(0.95, 0.45, 0.1)
	var white := StandardMaterial3D.new(); white.albedo_color = Color(0.96, 0.96, 0.94)
	var body := StaticBody3D.new(); fences.add_child(body)
	var inset := 1.5
	var edges := [[Vector3(lo.x + inset, 0, lo.z + inset), Vector3(hi.x - inset, 0, lo.z + inset)], [Vector3(lo.x + inset, 0, hi.z - inset), Vector3(hi.x - inset, 0, hi.z - inset)],
		[Vector3(lo.x + inset, 0, lo.z + inset), Vector3(lo.x + inset, 0, hi.z - inset)], [Vector3(hi.x - inset, 0, lo.z + inset), Vector3(hi.x - inset, 0, hi.z - inset)]]
	for e in edges:
		var p0: Vector3 = e[0]; var p1: Vector3 = e[1]; var L := p0.distance_to(p1); var dir := (p1 - p0).normalized()
		var yaw := atan2(dir.x, dir.z) + PI / 2
		var n := int(L / 2.2)
		for i in n:
			var p := p0 + dir * (i + 0.5) * (L / n)
			for j in 2:
				var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(2.0, 0.22, 0.05); bar.mesh = bm
				bar.material_override = stripe if (i + j) % 2 == 0 else white; bar.position = p + Vector3(0, 0.55 + j * 0.42, 0); bar.rotation.y = yaw; fences.add_child(bar)
			for sx in [-0.9, 0.9]:
				var leg := MeshInstance3D.new(); var lm := BoxMesh.new(); lm.size = Vector3(0.06, 1.1, 0.5); leg.mesh = lm; leg.material_override = white
				leg.position = p + Vector3(0, 0.55, 0) + Vector3(cos(yaw), 0, -sin(yaw)) * sx * -1.0; leg.rotation.y = yaw; fences.add_child(leg)
			if i % 4 == 0:
				var cone := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.18; cm.height = 0.55; cone.mesh = cm
				cone.material_override = stripe; cone.position = p + Vector3(0, 0.28, 0) - Vector3(sin(yaw), 0, cos(yaw)) * 0.8; fences.add_child(cone)
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(L, 2.0, 0.4); cs.shape = bs; body.add_child(cs)
		cs.position = (p0 + p1) / 2 + Vector3(0, 1, 0); cs.rotation.y = yaw
	_fences_for_day()

func _fences_for_day() -> void:
	_day = WorldState.day
	var up := WorldState.day < FENCE_DAY
	fences.visible = up
	for cs in fences.find_children("*", "CollisionShape3D", true, false): (cs as CollisionShape3D).disabled = not up

# ------------------------------------------------------------ culling / activation
func _cull_setup() -> void:
	for g in grid.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		var ab: AABB = gi.get_aabb() if gi is VisualInstance3D else AABB()
		if ab.size.length() < 6.0: gi.visibility_range_end = VIS_END; gi.visibility_range_end_margin = 5.0
	for id in places:
		for g in (places[id] as Node).find_children("*", "GeometryInstance3D", true, false):
			var gi2 := g as GeometryInstance3D
			if gi2.get_aabb().size.length() < 1.2: gi2.visibility_range_end = 20.0; gi2.visibility_range_end_margin = 3.0
	for l in _lights: (l as Light3D).shadow_enabled = false

func _process(dt: float) -> void:
	_tap_hint()
	_t -= dt
	if _t > 0.0 or player == null: return
	_t = 0.2
	var hp := hero_pos()
	if WorldState.day != _day: _fences_for_day()
	_street_check(hp)
	indoor_vis = _indoor_visible(region_at(hp))
	if not indoor_vis.is_empty():   # fix33: the room the CAMERA is in stays drawn too (shoulder cam still behind the hero in the room he just left)
		var vc := get_viewport().get_camera_3d()
		if vc:
			var cp := vc.global_position
			for id in HOUSE_ROOMS:
				var ab: AABB = regions.get(id, AABB())
				if ab.size != Vector3.ZERO and cp.x >= ab.position.x and cp.x <= ab.end.x and cp.z >= ab.position.z and cp.z <= ab.end.z: indoor_vis[id] = true
	for id in places:
		if not regions.has(id): continue
		var ab: AABB = regions[id]
		var c := ab.get_center(); var near := Vector2(c.x - hp.x, c.z - hp.z).length() - ab.size.length() * 0.5 < ACTIVE_R
		if indoor_vis.size() > 0 and id in HOUSE_ROOMS + ["cafe", "shop", "work"] and not indoor_vis.has(id): near = false   # indoors: only rooms seen through open doors
		if active.get(id, null) != near:
			active[id] = near
			(places[id] as Node3D).visible = near
			if (places[id] as Node).has_meta("ow_live"): (places[id] as Node).process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
			active_changed.emit(id, near)
	var lit := []
	for l in _lights:
		if not is_instance_valid(l) or l is DirectionalLight3D: continue
		var dl := (l as Node3D).global_position.distance_to(hp)
		var near := dl < LIGHT_NEAR
		if not l.has_meta("ow_vis"): l.set_meta("ow_vis", (l as Light3D).visible)
		(l as Light3D).visible = near and bool(l.get_meta("ow_vis"))
		if (l as Light3D).visible and (l as Node3D).is_visible_in_tree(): lit.append([dl, l])
		else: (l as Light3D).shadow_enabled = false
	lit.sort_custom(func(x, y): return x[0] < y[0])
	for i in lit.size(): (lit[i][1] as Light3D).shadow_enabled = i < SHADOW_LIGHTS
	_limit_camera()
	for id in doors:
		var dr: WorldDoor = doors[id]
		if not dr.auto: continue
		var dd := Vector2(dr.center().x - hp.x, dr.center().z - hp.z).length()
		if dd < 1.6: dr.open()
		elif dd > 3.2: dr.close()
	var r := region_at(hp)
	if r != region:
		var old := region; region = r
		if old != "": left.emit(old)
		entered.emit(r, old)
		player.floor_y = places[r].global_position.y if places.has(r) and PLACES.has(r) and HouseC.is_room(String(PLACES[r][0])) else 0.07
		if hud.has_method("set_place"): hud.set_place(r.capitalize(), "")

var indoor_vis := {}
## indoors (house room / cafe / shop / work): the current room + every room reachable through OPEN doors ({} = outdoors)
func _indoor_visible(r: String) -> Dictionary:
	if r == "street" or r == "" or not places.has(r) or r in ["hospital", "school"]: return {}
	var seen := {r: true}; var todo := [r]
	while not todo.is_empty():
		var cur: String = todo.pop_back()
		for d in doors.values():
			var dr: WorldDoor = d
			if not (dr.a == cur or dr.b == cur): continue
			if not (dr.is_open or absf(wrapf(dr.leaf.rotation.y - dr.closed_angle, -PI, PI)) > 0.15): continue
			var o := dr.b if dr.a == cur else dr.a
			if o == "street": continue   # the street stays drawn (windows), cut by the far plane + fog
			if not seen.has(o): seen[o] = true; todo.append(o)
	return seen

## the camera in use (World rig, OwLink's room camera, story cameras): far plane FAR + fog on its environment
func _limit_camera() -> void:
	var c := get_viewport().get_camera_3d()
	if c and c.far > FAR: c.far = FAR
	var we := get_viewport().find_world_3d()
	if we and we.environment: _fog(we.environment)
	if c and c.environment: _fog(c.environment)

## street arrival (OwLink._street_hooks): the street's own objective like v33 world_exterior._ready (rooms' missions such
## as "Turn on the TV." must not stay on the HUD outside). Not after a café / shop visit or a car arrival, nor while a
## day-3..7 director owns the list.
func street_objective(door: String) -> void:
	if door in ["cafe", "shop", "cafe_door", "shop_door", "lot:cafe", "lot:corner_shop", "home_car"] or _story_obj_active(): return
	var keep: Array = []
	for it in Objectives.items: if it is Dictionary and String(it.get("id", "")) == "charge": keep.append(it)
	Objectives.set_list(["Walk to the street."] + keep)
	if hud and hud.has_method("set_mission"): hud.set_mission("Walk to the street.")

func _story_obj_active() -> bool:
	for n in ["Day3Morning", "Day4Routine", "Day7Routine", "Day56Routine"]:
		if get_tree().root.has_node(n): return true
	var st = App.load_save().get("story", {})
	var d := maxi(WorldState.day, App.day)
	return st is Dictionary and d >= 3 and d <= 7 and not String(st.get("d%d" % d, "")) in ["", "done"]

func _street_check(hp: Vector3) -> void:
	if not Objectives.has("Walk to the street.") or region_at(hp) != "street": return
	var lp := hp - grid.cell_center(grid.cell_of(hp))
	if absf(lp.x) > CityBlock.INNER or absf(lp.z) > CityBlock.INNER:
		Objectives.complete("Walk to the street.")
		if hud and hud.has_method("set_mission") and Objectives.items.is_empty(): hud.set_mission("")

## the ONE hero's world position (in a house room red's OwLink lends the hero to the room: the WorldPlayer body stays behind)
func hero_pos() -> Vector3:
	var h = player.hero if player else null
	return (h as Node3D).global_position if h is Node3D and (h as Node3D).is_inside_tree() else player.global_position

func region_at(p: Vector3) -> String:
	# fix33 (blue): the house room bounds overlap (each room's mesh bounds reach into its neighbours: the bedroom box
	# covered most of the living room), and the FIRST match won: the region stayed "bedroom" in the living room, so the
	# living room was culled (indoor_vis) = the couch / evening / party cameras showed the street through an invisible room.
	# Now: the live OwLink room when the hero is inside it, else the match whose floor rect is smallest.
	var live_id := String(OwLink.inst.live_id) if OwLink.active() else ""
	if live_id in HOUSE_ROOMS and is_instance_valid(OwLink.inst.live): return live_id   # house rooms change only through OwLink (doors)
	var best := "street"; var best_a := INF
	for id in regions:
		var ab: AABB = regions[id]
		if p.x >= ab.position.x and p.x <= ab.end.x and p.z >= ab.position.z and p.z <= ab.end.z:
			if id == live_id: return id
			var a := ab.size.x * ab.size.z
			if a < best_a: best_a = a; best = id
	return best

## fix33 (blue, int d1): from the street the house was the living room's bare grey south wall (the lot's own house mesh is
## hidden by _open_lot so the real rooms show): a painted facade (one-sided, outward: invisible from inside the rooms), window
## frames + glass beside the front door, a skirting and a pitched roof over the three rooms (above their ceilings, no shadow)
func _house_shell() -> void:
	var lr = places.get("livingroom")
	if not (lr is Node3D): return
	var root := Node3D.new(); root.name = "HouseShell"; add_child(root); root.global_transform = (lr as Node3D).global_transform
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color(0.93, 0.86, 0.74); paint.roughness = 0.9
	var trim := StandardMaterial3D.new(); trim.albedo_color = Color(0.97, 0.97, 0.95)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(0.32, 0.45, 0.58); glass.roughness = 0.1; glass.metallic = 0.4
	var roofm := StandardMaterial3D.new(); roofm.albedo_color = Color(0.62, 0.3, 0.24); roofm.roughness = 0.85
	var z := 3.03; var x0 := -3.65; var x1 := 8.35; var d0 := 1.85; var d1 := 2.85; var h := 2.6
	var q := func(sz: Vector2, pos: Vector3, m: Material) -> void:
		var mi := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = sz; mi.mesh = qm; mi.material_override = m
		mi.position = pos; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.set_meta("no_fade", true); root.add_child(mi)
	q.call(Vector2(d0 - x0, h), Vector3((x0 + d0) / 2, h / 2, z), paint)
	q.call(Vector2(x1 - d1, h), Vector3((d1 + x1) / 2, h / 2, z), paint)
	q.call(Vector2(d1 - d0 + 0.02, h - 2.2), Vector3((d0 + d1) / 2, 2.2 + (h - 2.2) / 2, z), paint)
	for wx in [-1.6, 0.4, 4.6, 6.6]:   # window frames + glass (y 1.0 .. 2.0)
		q.call(Vector2(1.3, 1.15), Vector3(wx, 1.5, z + 0.006), trim)
		q.call(Vector2(1.12, 0.97), Vector3(wx, 1.5, z + 0.012), glass)
		q.call(Vector2(0.05, 0.97), Vector3(wx, 1.5, z + 0.016), trim)
	q.call(Vector2(x1 - x0, 0.22), Vector3((x0 + x1) / 2, 0.11, z + 0.004), trim)
	# pitched roof: ridge along x over the bedroom / living-room wall line (z -3), eaves 0.35 m out
	var zs := -9.35; var ze := 3.35; var zr := -3.0; var rh := 1.7
	for side in [[zs, zr], [zr, ze]]:
		var za: float = side[0]; var zb: float = side[1]
		var run := absf(zb - za); var ln := sqrt(run * run + rh * rh)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(x1 - x0 + 0.7, 0.1, ln); mi.mesh = bm; mi.material_override = roofm
		var ang := atan2(rh, run) * (1.0 if zb > za and zb == ze else -1.0)
		mi.position = Vector3((x0 + x1) / 2, h + 0.1 + rh / 2, (za + zb) / 2); mi.rotation.x = ang
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.set_meta("no_fade", true); root.add_child(mi)

## fix33 (blue): the house rooms' inner floor rects (room-local x0, x1, z0, z1); unlike the mesh bounds they do not overlap
const ROOM_RECT := {"bedroom": [-3.5, 3.5, -3.0, 3.0], "bathroom": [-2.25, 2.25, -1.75, 1.75], "livingroom": [-3.5, 8.2, -3.0, 3.0]}
static func room_rect_at(p: Vector3, margin := 0.0) -> String:
	if inst == null: return ""
	for id in ROOM_RECT:
		var n = inst.places.get(id)
		if not (n is Node3D): continue
		var q: Vector3 = (n as Node3D).to_local(p); var rr: Array = ROOM_RECT[id]
		if q.x >= rr[0] - margin and q.x <= rr[1] + margin and q.z >= rr[2] - margin and q.z <= rr[3] + margin: return id
	return ""
static func room_rect_at_id(p: Vector3, id: String, margin: float) -> bool:
	var n = inst.places.get(id) if inst else null
	if not (n is Node3D) or not ROOM_RECT.has(id): return false
	var q: Vector3 = (n as Node3D).to_local(p); var rr: Array = ROOM_RECT[id]
	return q.x >= rr[0] - margin and q.x <= rr[1] + margin and q.z >= rr[2] - margin and q.z <= rr[3] + margin

# ------------------------------------------------------------ home spots
func _home_spots() -> void:
	var lot := grid.find_lot("home")
	var liv: Node3D = places.livingroom
	spots["home_car"] = [lot.global_transform * Vector3(3.2, 0, 6.5) if lot else liv.to_global(Vector3(3, 0, 6)), 0.0]
	spots["home_bed"] = [places.bedroom.to_global(Vector3(-0.6, 0, 0.9)), PI]
	spots["home_front"] = [liv.to_global(Vector3(0, 0, 4.2)), 0.0]

# ------------------------------------------------------------ API (see OPENWORLD_PLAN.md; red builds on this)
static func get_world() -> World: return inst if is_instance_valid(inst) else null
static func room(id: String) -> Node3D: return inst.places.get(id) if inst else null
static func door(id: String) -> WorldDoor: return inst.doors.get(id) if inst else null
static func hero_node() -> WorldPlayer: return inst.player if inst else null
static func current_region() -> String: return inst.region if inst else ""
static func is_active(place: String) -> bool: return bool(inst.active.get(place, false)) if inst else false
## mark a place as running story logic: it then processes only while the hero is near (ACTIVE_R)
static func set_live(place: String, on := true) -> void:
	if inst == null or not inst.places.has(place): return
	var n: Node = inst.places[place]
	if on: n.set_meta("ow_live", true)
	else: n.remove_meta("ow_live")
	n.process_mode = Node.PROCESS_MODE_INHERIT if on and inst.is_active(place) else Node.PROCESS_MODE_DISABLED

## walk the ONE hero into a place: to the near side of its door (straight line), open it, through it. No load, no fade.
## door_id empty = the first door of that place. Straight-line walk: chain doors for multi-room paths (bedroom -> street:
## goto("livingroom", "bed_living") then goto("street", "front")). Awaitable.
static func goto(place: String, door_id := "") -> void:
	if inst == null: return
	var dr: WorldDoor = inst.doors.get(door_id) if door_id != "" else null
	if dr == null:
		for d in inst.doors.values(): if (d as WorldDoor).a == place or (d as WorldDoor).b == place: dr = d; break
	if dr == null: return
	var h := inst.player; var c := dr.center(); var hp := inst.hero_pos()
	var v := Vector3(hp.x - c.x, 0, hp.z - c.z)
	if v.length() > 1.0: await h.move_to(c + v.normalized() * 0.9)
	await dr.walk_through(h)
	inst.last_door = dr.id

## car / bus / ambulance trips: the ONLY gameplay fade (Yasin 18:12): black, hero.place_at(dest), back in. No card text.
## dest = a spot id (home_car, hospital_car, school_car, work_car, hospital_ward, school_desk, work_desk, home_bed ...) or a door id
static func skip_travel(dest: String) -> void:
	if inst == null: return
	inst.player.busy = true
	var fc = Game.get("_fade")
	var old_c: Color = fc.color if fc else Color.BLACK
	if fc: fc.color = Color(0, 0, 0, old_c.a)   # TRUE black (Game's overlay is light grey)
	await Game.fade(1.0, 0.45)
	inst.player.place_at(dest)
	var sc = inst.get_tree().root.get_node_or_null("ShoulderCam")
	if sc and sc.get("pos") != null: sc.set("pos", Vector3.INF); sc.set("yaw", inst.player.hero.rotation.y + PI)
	await inst.get_tree().create_timer(0.35).timeout
	await Game.fade(0.0, 0.45)
	if fc: fc.color = Color(old_c.r, old_c.g, old_c.b, 0.0)
	inst.player.busy = false

## objective pan, awaitable: the one shoulder camera frames hero + target (blue's ShoulderCam honours guide_cam), then back
static func pan(at: Vector3, secs := 2.6) -> void:
	if inst == null: return
	var tmp := Camera3D.new(); tmp.set_meta("guide_cam", true); tmp.set_meta("guide_at", at); inst.add_child(tmp)
	tmp.global_transform = inst.cam.global_transform; tmp.current = true
	await inst.get_tree().create_timer(secs).timeout
	if is_instance_valid(inst.cam): inst.cam.current = true
	tmp.queue_free()

## world position (+ yaw) of a spot / door / place id
const ALIAS := {"lot:home": "front", "front_door": "front", "lot:cafe": "cafe", "cafe_door": "cafe", "lot:corner_shop": "shop", "shop_door": "shop", "work_door": "work"}
static func spot(id: String) -> Vector3:
	if inst == null: return Vector3.ZERO
	var ss := _street_side(id)
	if not ss.is_empty(): return ss[0]
	if inst.spots.has(id): return inst.spots[id][0]
	if inst.doors.has(id): return (inst.doors[id] as WorldDoor).center()
	if inst.places.has(id) and inst.regions.has(id): return (inst.regions[id] as AABB).get_center()
	return Vector3.INF   # unknown id: place_at leaves the hero where he is
static func spot_yaw(id: String) -> float:
	if inst == null: return INF
	var ss := _street_side(id)
	if not ss.is_empty(): return ss[1]
	return float(inst.spots[id][1]) if inst.spots.has(id) else INF

## fix33 (black): the street side of a street door (alias or the door id itself, e.g. "front" / "cafe" / "shop"):
## [pos 1.6 m out from the door centre on the street, yaw facing the street (away from the door)]. A trip home used to land on
## the door CENTRE ("front" was not an alias), i.e. inside the living-room region: the room went live with its stale mission.
static func _street_side(id: String) -> Array:
	var did: String = ALIAS.get(id, id)
	if not inst.doors.has(did): return []
	var dr: WorldDoor = inst.doors[did]
	if dr.b != "street" and dr.a != "street": return []
	var inside: String = dr.a if dr.b == "street" else dr.b
	var c := dr.center()
	var ic: Vector3 = (inst.regions[inside] as AABB).get_center() if inst.regions.has(inside) else c
	var out := Vector3(c.x - ic.x, 0, c.z - ic.z); out = out.normalized() if out.length() > 0.05 else Vector3(0, 0, 1)
	var p := c + out * 1.6
	if inst.regions.has(inside):   # make sure the spot is really outside the room box
		var ab: AABB = inst.regions[inside]
		var k := 0
		while ab.has_point(Vector3(p.x, 1.0, p.z)) and k < 10: p += out * 0.3; k += 1
	p.y = 0.07
	return [p, atan2(out.x, out.z)]

## Game.go_to shim (temporary, until red's port drops the scene paths): old scene path -> World walk / skip_travel
const SHIM := {"res://main.tscn": "bedroom", "res://bathroom.tscn": "bathroom", "res://livingroom.tscn": "livingroom",
	"res://scenes/world_exterior.tscn": "street", "res://scenes/places/cafe.tscn": "cafe", "res://scenes/places/shop.tscn": "shop",
	"res://scenes/hospital.tscn": "hospital", "res://scenes/hospital_day2.tscn": "hospital", "res://scenes/work.tscn": "work"}
static func shim_go_to(path: String, _spawn_id := "") -> bool:
	if inst == null or not SHIM.has(path): return false
	var place: String = SHIM[path]
	if place in ["hospital", "school", "work"]:
		var dest := place + "_car"
		if place == "work" and CharacterHook.is_child(CharacterHook.state()): dest = "school_car"
		await skip_travel(dest)
		if place == "hospital" and OwLink.active(): await OwLink.enter("hospital", "street")   # red's hospital (reserved slot)
	elif place == "street": await goto("street", "front")
	else: await goto(place)
	return true
