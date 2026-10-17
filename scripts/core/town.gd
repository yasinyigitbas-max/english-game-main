extends RefCounted
## v33 whole town (built on the v32wh whole house, scripts/core/house.gd). The outdoor street (world_exterior), the three
## house rooms, the cafe and the shop all live in ONE scene tree; walking through a building door swaps which of them is
## "live" with no change_scene / loading:
##   * the live place is current_scene, sits at the world origin and runs exactly its v32 code (_live_ready);
##   * every other member is a "shell" (meta house_shell, process disabled -> its physics bodies are removed too):
##       - house rooms next to a live house room: geometry-only shells, visible, cheap lighting (house.gd, unchanged);
##       - everything else: hidden (visible = false: no draw calls, no shadows, no interactables - player._scan skips
##         hidden ones). Interiors are never drawn from the street (the street's own building meshes - walls / roof -
##         stand in for them) and the street is never drawn from an interior (dark outside, house.gd / _dark_place).
##   * the street keeps its streamed city blocks while you are inside: leaving the live street frees the old scene
##     node (so its HUD / camera / traffic / NPCs / story coroutines go away exactly like change_scene did) but the
##     WorldGrid with its loaded blocks is handed to the new street shell, so coming back out loads nothing.
##   * the cafe / shop shells are empty until entered (their whole v32 _ready runs on entry, as before).
## Every member is placed at its real spot in the street frame (XF): house rooms inside the home lot, the cafe and
## shop interiors behind their street doors (rotated to face the street). Hidden shells' transforms are cosmetic.
## Switch the whole feature off with ENABLED = false: every door goes back to the v32wh behaviour.
const House := preload("res://scripts/core/house.gd")
const ENABLED := true
const WORLD := "res://scenes/world_exterior.tscn"
const CAFE := "res://scenes/places/cafe.tscn"
const SHOP := "res://scenes/places/shop.tscn"
const PLACES := [WORLD, CAFE, SHOP]
## the living room origin in the street frame: block_home's Home lot (11.9 x 12.4 at (-3, -3.6)); the house's front wall
## (living room z = 3) on the lot's front face (z 2.6), its front door (x 2.35, the house centre) on the lot's door (x -3)
const HOUSE_AT := Vector3(-5.35, 0.1, -0.4)
## cafe / shop interiors: door (local +Z, z = room.y / 2) on the lot's door; lots in block_shops (cell 0,1 -> z + 40) face -Z
const PLACE_AT := {
	CAFE: Vector3(8.5, 0.07, 32.5),    # lot "cafe" (7 x 7 at 8.5, -8), room 10 x 8, turned to face -Z
	SHOP: Vector3(-3.0, 0.07, 33.5),   # lot "corner_shop" (10 x 8 at -3, -7.5), room 14 x 10, turned to face -Z
}
## where the street shell streams its first blocks when it has to be built from scratch (the door it will be entered by)
const WORLD_FIRST := {CAFE: Vector3(8.5, 0, 27.0), SHOP: Vector3(-3.0, 0, 27.0)}
const HOME_DOOR := Vector3(-3.0, 0, 5.0)
static var _grid_hand: Node = null      # the old street's WorldGrid, waiting for the new street shell
static var _filling := false

static func is_member(path: String) -> bool: return ENABLED and (House.is_room(path) or path in PLACES)
static func xf(path: String) -> Transform3D:
	if House.is_room(path): return Transform3D(Basis(), HOUSE_AT + (House.OFS[path] as Vector3))
	if PLACE_AT.has(path): return Transform3D(Basis(Vector3.UP, PI), PLACE_AT[path])
	return Transform3D.IDENTITY

## street / cafe / shop script, top of _ready: true = this is a shell (stop there)
static func shell_ready(n: Node) -> bool:
	if not House.is_shell(n): return false
	n.process_mode = Node.PROCESS_MODE_DISABLED; n.visible = false
	if n.scene_file_path == WORLD: _world_shell(n)
	return true

## street / cafe / shop script, end of the live _ready (house rooms: House.live_ready calls ensure via House._ensure)
static func live_ready(n: Node) -> void:
	if not is_member(n.scene_file_path): return
	if not n.has_meta("wh_hooked"):
		n.set_meta("wh_hooked", true); n.tree_exiting.connect(func(): House._on_live_exit(n))
	if n.scene_file_path != WORLD: _dark_place(n)
	(func(): ensure(n)).call_deferred()

## a building door (Game.go_to): walk through it in the same scene. false = not a town door, the caller changes scene.
static func go(from: Node, path: String) -> bool:
	if not ENABLED or from == null or not is_instance_valid(from) or not from.is_inside_tree(): return false
	var tree := from.get_tree()
	if tree.current_scene != from or path == from.scene_file_path: return false
	if not (is_member(from.scene_file_path) and is_member(path)): return false
	var target := House._find(tree, path)
	if target == null: return false
	(func(): _swap(from, target)).call_deferred()
	return true

static func _swap(from: Node, target: Node) -> void:
	if not is_instance_valid(from) or not is_instance_valid(target) or not target.is_inside_tree(): return
	var tree := target.get_tree()
	if from.scene_file_path == WORLD:   # keep the streamed blocks: hand the grid to the street shell built below
		var g = from.get("grid")
		if g is Node and is_instance_valid(g) and g.get_parent() == from:
			from.remove_child(g); _reset_world(g); _grid_hand = g
	House.swapping = true
	from.get_parent().remove_child(from); from.queue_free()   # like change_scene: the place left (and its awaits) goes away
	House.swapping = false
	target.remove_meta("town_loading")
	target.transform = Transform3D.IDENTITY; target.visible = true
	tree.current_scene = target
	target.remove_meta(House.SHELL)
	if House.is_room(target.scene_file_path):
		House._cheap(target, false)
		House._ensure(target, [target])      # the two other rooms next door (+ ensure() below for the rest)
	else:
		target.process_mode = Node.PROCESS_MODE_INHERIT
	ensure(target)                            # rebuild the place left as a shell (the street adopts its grid)
	target.call("_live_ready")

## every other town member exists as a shell, placed relative to the live one; only house rooms next to a live house
## room are drawn
static func ensure(live: Node) -> void:
	if not ENABLED or not is_instance_valid(live) or not live.is_inside_tree() or live.get_tree().current_scene != live: return
	var tree := live.get_tree()
	var lp: String = live.scene_file_path
	if not is_member(lp): return
	var in_house := House.is_room(lp)
	var inv := xf(lp).affine_inverse()
	var missing: Array = []
	for p in House.OFS.keys() + PLACES:
		if p == lp: continue
		var s := House._find(tree, p)
		if s == null:
			if in_house and House.is_room(p): continue          # House._ensure builds those (same frame)
			if p == WORLD and _grid_hand != null: s = _make(tree, p)   # the street left: must exist now to adopt its grid
			else: missing.append(p); continue
		_place(s, inv, in_house)
	if not missing.is_empty() and not _filling: _fill(live, missing)

static func _place(s: Node, inv: Transform3D, in_house: bool) -> void:
	var p: String = s.scene_file_path
	if House.is_room(p) and in_house:
		s.visible = true; return             # house.gd positions it and decides what of it is drawn
	if not s.has_meta("town_loading"): s.transform = inv * xf(p)
	s.visible = false

static func _make(tree: SceneTree, p: String) -> Node:
	var s := (load(p) as PackedScene).instantiate(); s.set_meta(House.SHELL, true)
	if House.is_room(p): s.visible = false   # built hidden (street / place live): no one-frame flash
	tree.root.add_child(s)
	return s

## missing shells are built one per frame (no long frame right after a scene loaded)
static func _fill(live: Node, paths: Array) -> void:
	_filling = true
	var tree := live.get_tree()
	for p in paths:
		await tree.process_frame
		if not is_instance_valid(live) or not live.is_inside_tree() or tree.current_scene != live: break
		if House._find(tree, p) == null:
			var s := _make(tree, p)
			_place(s, xf(live.scene_file_path).affine_inverse(), House.is_room(live.scene_file_path))
	_filling = false
	var cs := tree.current_scene   # the live place may have changed meanwhile: top up around the current one
	if cs and is_member(cs.scene_file_path): ensure(cs)

## street shell: adopt the old street's grid, or stream the blocks around the door it will be entered by (one per frame,
## at the street origin so bus stops / focus points register in street coordinates)
static func _world_shell(w: Node) -> void:
	var g = _grid_hand; _grid_hand = null
	if g != null and is_instance_valid(g):
		w.add_child(g); w.set("grid", g); return
	g = WorldGrid.new(); w.add_child(g); w.set("grid", g)
	var cs := w.get_tree().current_scene
	var at: Vector3 = WORLD_FIRST.get(cs.scene_file_path if cs else "", HOME_DOOR)
	w.set_meta("town_loading", true); w.transform = Transform3D.IDENTITY
	_stream(w, g, at)

static func _stream(w: Node, g, at: Vector3) -> void:
	var tree := w.get_tree()
	for c in g._wanted(g.cell_of(at)):
		await tree.process_frame
		if not is_instance_valid(w) or not is_instance_valid(g) or not House.is_shell(w) or not w.has_meta("town_loading"): return
		if not g.loaded.has(c): g._spawn(c, load(g.scene_for(c)))
	w.remove_meta("town_loading")
	var cs := tree.current_scene
	if cs and is_member(cs.scene_file_path): ensure(cs)

## what change_scene used to reset on the street: open front doors, borrowed NPCs, the grid's follow target
static func _reset_world(g: Node) -> void:
	g.set("target", null)
	for sp in g.find_children("*", "NpcSpot", true, false): sp.set("npc", null)
	for l in g.find_children("*", "Lot", true, false):
		var dp = l.get("door_pivot")
		if dp is Node3D and is_instance_valid(dp): (dp as Node3D).rotation.y = 0.0

## cafe / shop: the space outside the room is dark (was the light grey clear colour)
static func _dark_place(n: Node) -> void:
	for we in n.find_children("*", "WorldEnvironment", false, false):
		var e: Environment = (we as WorldEnvironment).environment
		if e and e.background_mode == Environment.BG_COLOR: e.background_color = Color(0.02, 0.02, 0.03)
