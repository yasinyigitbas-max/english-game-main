extends RefCounted
## v34 open world (black): builds the hospital, school and work places ONCE at fixed world positions, north of the town,
## behind the day-8 fence (reached by World.skip_travel by car / bus / ambulance until the fences come down).
## Geometry comes from the story scenes' own room builders (hospital.gd _room, work.gd _room + _set_<setting>), run on an
## off-tree instance whose script is then dropped (so no story _ready runs here; red's story port drives them later).
## Each place gets a real cut doorway + swinging leaf (World.WorldDoor), colliders, a front sign, its fixed spots.
const HOSP := "res://scripts/story/hospital.gd"
const WORK := "res://scripts/story/work.gd"
const AT := {"hospital": Vector3(0, 0, -84), "school": Vector3(42, 0, -84), "work": Vector3(-42, 0, -84)}

static func build(w: Node3D) -> void:
	_ground(w)
	_hospital(w)
	_work(w, "school", "study")
	var st := CharacterHook.state()
	var cid := String(load(WORK).category_of(String(st.get("job", "")), false))
	if cid in ["study", "teach", ""]: cid = "office"
	_work(w, "work", cid)

## the strip north of the town: grass, a road along the fronts, a car spot in front of each place
static func _ground(w: Node3D) -> void:
	var g := Node3D.new(); g.name = "NorthStrip"; w.add_child(g)
	_slab(g, Vector3(210, 0.1, 48), Vector3(0, -0.05, -86), Color(0.45, 0.64, 0.38))
	_slab(g, Vector3(210, 0.02, 7), Vector3(0, 0.01, -70), Color(0.32, 0.33, 0.36))           # road
	for i in 30: _slab(g, Vector3(2.2, 0.025, 0.15), Vector3(-100 + i * 7, 0.02, -70), Color(0.95, 0.95, 0.9))
	_slab(g, Vector3(210, 0.04, 3), Vector3(0, 0.02, -74.5), Color(0.78, 0.77, 0.74))          # pavement

static func _slab(p: Node3D, s: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.position = at
	var m := StandardMaterial3D.new(); m.albedo_color = c; mi.material_override = m; p.add_child(mi); return mi

static func _hospital(w: Node3D) -> void:
	var n: Node3D = load(HOSP).new()
	n.call("_room")
	n.set_script(null); n.name = "Place_hospital"
	for c in n.find_children("*", "Interactable", true, false): c.queue_free()
	n.position = AT.hospital; n.rotation.y = PI   # its -z wall faces the road (+z world); the window wall faces away
	w.add_child(n)
	# the ward door: cut the -z wall (road side, z = -2.6) at x = -1.6 (clear of the bed / monitor)
	_cut(n, Vector3(6, 3, 0.1), Vector3(0, 1.5, -2.6), -1.6, 0.6, Color(0.86, 0.92, 0.91), "z")
	# the hospital block around the ward: a reception box with a sign facing the road
	var doc := DemoCharacter.new(); n.add_child(doc); doc.setup("men"); doc.top_color = Color(0.97, 0.97, 0.97); doc.set_height("medium"); doc._refresh()
	doc.position = Vector3(0.7, 0, 0.9); doc.rotation.y = PI + 0.4; doc.play("idle", 0.0)
	_sign(n, "HOSPITAL", Vector3(0, 3.4, -2.66), Color(0.85, 0.15, 0.15))
	_finish(w, n, "hospital", 6.0, 6.0)
	w.spots["hospital_ward"] = [n.to_global(Vector3(-0.9, 0, -0.6)), 0.0]          # beside the bed
	w.spots["hospital_car"] = [n.to_global(Vector3(-1.6, 0, -9.5)), PI]

static func _work(w: Node3D, id: String, cid: String) -> void:
	var n: Node3D = load(WORK).new()
	var W: Dictionary = App.load_json("res://data/work.json")
	n.set("W", W); n.set("cid", cid); n.set("C", (W.categories[cid] as Dictionary).duplicate(true))
	var C: Dictionary = n.get("C")
	var outdoor: bool = C.setting == "garden"
	n.call("_room", outdoor)
	n.call("_set_" + String(C.setting))
	var room: Vector2 = n.get("room")
	var spots: Array = n.get("spots")
	n.set_script(null); n.name = "Place_" + id
	for c in n.find_children("*", "Interactable", true, false): c.queue_free()
	for c in n.get_children():   # the scene's own 40 m outdoor ground: the strip is the ground here
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and ((c as MeshInstance3D).mesh as BoxMesh).size.x >= 20.0: c.queue_free()
	# its +z front wall (entrance) faces the road
	n.position = AT[id]; n.rotation.y = 0.0
	w.add_child(n)
	var hz := room.y / 2.0
	_cut(n, Vector3(room.x, 2.8, 0.12), Vector3(0, 1.4, hz), 0.0, 0.65, Color(0.93, 0.91, 0.86), "z")
	for c in n.get_children():   # the painted door
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and absf(((c as MeshInstance3D).mesh as BoxMesh).size.x - 1.0) < 0.01 and absf((c as Node3D).position.z - (hz - 0.08)) < 0.02: (c as Node3D).visible = false
	# the people of that place (work.gd _people, without the story hooks)
	for p in C.people:
		var ch := DemoCharacter.new(); n.add_child(ch); ch.setup(String(p[0]))
		if p[1]: ch.set_child(true)
		else: ch.set_height("medium")
		ch._refresh(); ch.position = Vector3(p[3], 0.0, p[4]); ch.set_meta("pose", p[5])
		ch.rotation.y = atan2(-p[3], -p[4] + 0.001) if p[5] != "sit_idle" else (PI if p[4] > -0.5 else 0.0)
		ch.play(String(p[5]), 0.0)
	_sign(n, "SCHOOL" if id == "school" else String(C.get("label", "WORK")).to_upper().left(18), Vector3(0, 3.3, hz + 0.08), Color(0.2, 0.35, 0.7), PI)
	_finish(w, n, id, room.x, room.y)
	var desk: Vector3 = spots[0][0] if spots.size() > 0 else Vector3.ZERO
	w.spots[id + "_desk"] = [n.to_global(desk), 0.0]
	w.spots[id + "_car"] = [n.to_global(Vector3(0, 0, hz + 6.5)), 0.0]

## cut a doorway (2*gap wide, 2.2 m) into the wall box of size s at local p (along x), hang a swinging leaf
static func _cut(n: Node3D, s: Vector3, p: Vector3, x0: float, gap: float, wc: Color, _axis: String) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			var bs: Vector3 = ((c as MeshInstance3D).mesh as BoxMesh).size
			if bs.is_equal_approx(s) and (c as Node3D).position.is_equal_approx(p): (c as Node3D).visible = false; c.set_meta("ow_cut", true)
		if c is StaticBody3D and (c as Node3D).position.is_equal_approx(p): c.queue_free()
	var hx := s.x / 2.0
	var lw := (x0 - gap) - (-hx); var rw := hx - (x0 + gap)
	if lw > 0.01: _wall(n, Vector3(lw, s.y, s.z), Vector3(-hx + lw / 2.0, p.y, p.z), wc)
	if rw > 0.01: _wall(n, Vector3(rw, s.y, s.z), Vector3(x0 + gap + rw / 2.0, p.y, p.z), wc)
	_wall(n, Vector3(gap * 2.0, s.y - 2.2, s.z), Vector3(x0, 2.2 + (s.y - 2.2) / 2.0, p.z), wc)
	var pv := Node3D.new(); pv.name = "OWDoor"; pv.position = Vector3(x0 - gap, 0, p.z); n.add_child(pv)
	var leaf := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(gap * 2.0 - 0.04, 2.15, 0.06); leaf.mesh = bm
	var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.55, 0.38, 0.25); leaf.material_override = mt; leaf.position = Vector3(gap - 0.02, 1.08, 0); pv.add_child(leaf)
	n.set_meta("ow_door", pv)

static func _wall(n: Node3D, s: Vector3, p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s; mi.mesh = bm; mi.position = p
	var m := StandardMaterial3D.new(); m.albedo_color = c; mi.material_override = m; n.add_child(mi)

static func _sign(n: Node3D, text: String, p: Vector3, c: Color, yaw := 0.0) -> void:
	var l := Label3D.new(); l.text = text; l.font_size = 96; l.pixel_size = 0.006; l.modulate = c; l.outline_size = 10; l.position = p; l.rotation.y = yaw + PI
	n.add_child(l)

## colliders for every visible wall-like box (+ big furniture boxes), region, the leaf in the door table
static func _finish(w: Node3D, n: Node3D, id: String, sx: float, sz: float) -> void:
	var body := StaticBody3D.new(); body.name = "OWBody"; n.add_child(body)
	var leaf: Node3D = n.get_meta("ow_door")
	for g in n.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if not (mi.mesh is BoxMesh) or not mi.visible or leaf.is_ancestor_of(mi): continue
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if ab.size.y >= 1.6 and ab.size.y < 6.0 and minf(ab.size.x, ab.size.z) <= 0.35 and maxf(ab.size.x, ab.size.z) >= 0.3 and ab.position.y < 0.5:
			var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = ab.size; cs.shape = bs; body.add_child(cs); cs.global_position = ab.get_center()
	var c0 := n.to_global(Vector3(-sx / 2, 0, -sz / 2)); var c1 := n.to_global(Vector3(sx / 2, 3, sz / 2))
	w.places[id] = n
	w.regions[id] = AABB(Vector3(minf(c0.x, c1.x), 0, minf(c0.z, c1.z)), Vector3(absf(c1.x - c0.x), 3, absf(c1.z - c0.z)))
