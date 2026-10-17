## StreetObject: interactive outdoor object with states. Local front = +Z; the player stands at `spot`.
## kinds: mailbox, bench, bin, streetlight, shop_door, cafe, gate, car, tap, traffic_light
## Every verb shows an A1 present-continuous caption (TR in scripts/world/lines.gd, English voice clip).
class_name StreetObject
extends Node3D

@export_enum("mailbox", "bench", "bin", "streetlight", "shop_door", "cafe", "gate", "car", "tap", "traffic_light") var kind := "bench"
@export var shop_id := ""
@export var color := Color(0.40, 0.56, 0.76)

const WOOD := Color(0.72, 0.56, 0.40)
const DARK := Color(0.22, 0.23, 0.26)
const WHITE := Color(0.96, 0.95, 0.93)
const GLASS := Color(0.62, 0.74, 0.86)
var S := {}                 # state
var parts := {}             # moving nodes
var it: Interactable
var body: StaticBody3D

func _ready() -> void:
	body = StaticBody3D.new(); add_child(body)
	it = Interactable.new(); it.radius = 1.6; it.position = Vector3(0, 0, 0.9); add_child(it)
	it.verbs = _verbs; it.focus = Vector3.INF
	call("_build_" + kind)
	if it and it.focus == Vector3.INF: it.focus = global_position + Vector3(0, 0.8, 0)

func W() -> Node: return get_tree().current_scene
func say(en: String) -> void:
	if W().has_method("caption"): W().caption(en)

func col(size: Vector3, pos: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs; cs.position = pos; body.add_child(cs); return cs

func part(name_: String, pivot: Vector3, k: MeshKit) -> Node3D:
	var n := Node3D.new(); n.position = pivot; add_child(n); k.commit(n); parts[name_] = n; return n

func swing(n: Node3D, prop: String, to: float, t := 0.4) -> void:
	create_tween().tween_property(n, prop, to, t).set_trans(Tween.TRANS_SINE)

func _verbs() -> Array: return call("_v_" + kind)

# ------------------------------------------------------------------ mailbox
func _build_mailbox() -> void:
	it.obj_name = "mailbox"; S = {"open": false, "mail": true}
	var k := MeshKit.new()
	k.box(Vector3(0.08, 1.0, 0.08), Vector3(0, 0.5, 0), DARK)
	k.box(Vector3(0.34, 0.3, 0.5), Vector3(0, 1.15, 0), color)
	k.box(Vector3(0.3, 0.02, 0.46), Vector3(0, 1.01, 0), DARK)
	k.box(Vector3(0.04, 0.2, 0.04), Vector3(0.19, 1.25, -0.12), Color(0.85, 0.4, 0.35))
	k.commit(self)
	var lid := MeshKit.new(); lid.box(Vector3(0.34, 0.3, 0.03), Vector3(0, 0.15, 0), color.darkened(0.1))
	part("lid", Vector3(0, 1.0, 0.26), lid)
	var lt := MeshKit.new(); lt.box(Vector3(0.22, 0.02, 0.3), Vector3(0, 0, 0), WHITE); part("letter", Vector3(0, 1.04, 0.05), lt)
	col(Vector3(0.4, 1.4, 0.55), Vector3(0, 0.7, 0)); it.focus = to_global(Vector3(0, 1.1, 0))

func _v_mailbox() -> Array:
	var v := []
	if not S.open: v.append(["Open the mailbox", func(): S.open = true; swing(parts.lid, "rotation:x", 1.5); say("I am opening the mailbox.")])
	else:
		if S.mail: v.append(["Check the mail", func():
			S.mail = false; say("I am checking the mail."); swing(parts.letter, "position:z", 0.5, 0.5)
			await get_tree().create_timer(2.6).timeout; parts.letter.visible = false; say("I have a letter!")])
		v.append(["Close the mailbox", func(): S.open = false; swing(parts.lid, "rotation:x", 0.0); say("I am closing the mailbox.")])
	return v

# ------------------------------------------------------------------ bench
func _build_bench() -> void:
	it.obj_name = "bench"
	var k := MeshKit.new()
	for i in 3: k.box(Vector3(1.7, 0.05, 0.13), Vector3(0, 0.45, -0.15 + i * 0.15), WOOD)
	for i in 2: k.box(Vector3(1.7, 0.12, 0.04), Vector3(0, 0.62 + i * 0.16, -0.26), WOOD)
	for sx in [-0.75, 0.75]:
		k.box(Vector3(0.06, 0.45, 0.45), Vector3(sx, 0.22, 0), DARK); k.box(Vector3(0.06, 0.5, 0.05), Vector3(sx, 0.7, -0.27), DARK)
	k.commit(self); col(Vector3(1.8, 0.9, 0.5), Vector3(0, 0.45, 0)); it.position = Vector3(0.45, 0, 0.75)
	it.focus = to_global(Vector3(0.45, 0.5, 2.0)); it.walk_to = true

func _v_bench() -> Array:
	var p: WorldPlayer = W().player
	if p.sitting: return [["Stand up", func(): p.stand_up(); say("I am standing up.")]]
	return [["Sit on the bench", func(): p.sit_at(to_global(Vector3(0.45, 0, 0.05)), global_rotation.y); say("I am sitting on the bench.")]]

# ------------------------------------------------------------------ bin
func _build_bin() -> void:
	it.obj_name = "bin"; S = {"open": false}
	var k := MeshKit.new()
	k.cyl(0.28, 0.9, Vector3(0, 0.45, 0), Color(0.40, 0.56, 0.76), 12, 0.3)
	k.box(Vector3(0.3, 0.06, 0.05), Vector3(0, 0.6, 0.29), WHITE)
	k.commit(self)
	var lid := MeshKit.new(); lid.cyl(0.32, 0.06, Vector3(0, 0.03, 0.3), DARK, 12); part("lid", Vector3(0, 0.9, -0.3), lid)
	var rub := MeshKit.new(); rub.sphere(0.12, Vector3.ZERO, Color(0.30, 0.30, 0.33), 0.8, 6, 3); part("bag", Vector3(0.35, 0.95, 0.75), rub).visible = false
	col(Vector3(0.6, 1, 0.6), Vector3(0, 0.5, 0)); it.focus = to_global(Vector3(0, 0.8, 0))

func _v_bin() -> Array:
	if not S.open: return [["Open the bin", func(): S.open = true; swing(parts.lid, "rotation:x", -1.9); say("I am opening the bin.")]]
	return [["Throw away the rubbish", func():
			parts.bag.visible = true; parts.bag.position = Vector3(0.0, 1.0, 0.6); say("I am throwing away the rubbish.")
			var tw := create_tween(); tw.tween_property(parts.bag, "position", Vector3(0, 0.95, 0), 0.5); tw.tween_property(parts.bag, "position:y", 0.4, 0.3)
			await tw.finished; parts.bag.visible = false],
		["Close the bin", func(): S.open = false; swing(parts.lid, "rotation:x", 0.0); say("I am closing the bin.")]]

# ------------------------------------------------------------------ streetlight (time of day)
func _build_streetlight() -> void:
	it.obj_name = "streetlight"
	var k := MeshKit.new(); k.box(Vector3(0.3, 0.45, 0.2), Vector3(0, 0.5, 0), Color(0.55, 0.60, 0.62)); k.box(Vector3(0.12, 0.08, 0.02), Vector3(0, 0.6, 0.11), Color(0.95, 0.78, 0.35))
	k.commit(self); it.position = Vector3(0, 0, 0.8); it.focus = to_global(Vector3(0, 3.5, 0))

func _v_streetlight() -> Array:
	if WorldState.phase() in ["evening", "night"] and (WorldState.hour() >= 20 or WorldState.hour() < 6):
		return [["Wait for the morning", func(): WorldState.minutes = 7.5 * 60.0; say("It is morning. The streetlights are off.")]]
	return [["Look at the streetlight", func(): say("I am looking at the streetlight.")],
		["Wait for the night", func(): WorldState.minutes = 21.0 * 60.0; say("It is night. The streetlights are on.")]]

# ------------------------------------------------------------------ shop door
func _build_shop_door() -> void:
	it.obj_name = "shop"; S = {"open": false}
	var d := MeshKit.new(); d.box(Vector3(1.1, 2.1, 0.05), Vector3(0.55, 1.05, 0), GLASS); d.box(Vector3(1.1, 0.1, 0.06), Vector3(0.55, 0.05, 0), color)
	d.box(Vector3(0.05, 0.4, 0.06), Vector3(0.95, 1.05, 0.04), DARK)
	part("door", Vector3(-0.55, 0, 0.1), d)
	var sign := Label3D.new(); Lines.set_sign(sign, "OPEN", "AÇIK"); sign.font = load("res://fonts/Nunito.ttf"); sign.font_size = 40; sign.pixel_size = 0.004
	sign.modulate = Color(0.16, 0.55, 0.36); sign.position = Vector3(0.55, 1.6, 0.04); sign.outline_size = 6; parts.door.add_child(sign)
	it.position = Vector3(0, 0, 1.0); it.focus = to_global(Vector3(0, 1.2, 0))
	_defer_interior_check.call_deferred()

## v31 QA (blue): the building behind this door/board has a real interior (Lot.interior_scene) -> the Lot's own
## "Go inside" entrance is the way in; the old street mini-shop verbs would bypass the interior (and charge separately).
func _interior_lot() -> Node:
	var id := shop_id if shop_id != "" else ("cafe" if kind == "cafe" else "")
	if id == "" or get_parent() == null: return null
	for c in get_parent().get_children():
		if c.get("lot_id") == id and String(c.get("interior_scene")) != "": return c
	return null

func _defer_interior_check() -> void:
	if kind == "shop_door" and _interior_lot() != null: it.enabled = false

func _v_shop_door() -> Array:
	if not S.open: return [["Open the door", func(): S.open = true; swing(parts.door, "rotation:y", -1.6); say("I am opening the shop door.")]]
	var v := []
	for item in Economy.shop_items(shop_id).slice(0, 3):
		var id: String = item.id; var nm: String = item.item.get("name", id)
		v.append(["Buy %s (%s)" % [nm, Economy.format(item.price)], func():
			if Economy.buy(id, shop_id): say("I am buying %s %s." % ["an" if nm[0] in "aeiou" else "some" if nm in ["bread", "milk", "water"] else "a", nm])
			else: say("I do not have enough money.")])
	v.append(["Close the door", func(): S.open = false; swing(parts.door, "rotation:y", 0.0); say("I am closing the shop door.")])
	return v

# ------------------------------------------------------------------ cafe: menu board + tables
func _build_cafe() -> void:
	it.obj_name = "café menu"
	# blue fix: the A-board stood at the node origin, 0.5 m in front of the cafe's door spawn (lot:cafe) right on its path.
	# It now stands beside the path (local x 1.65, path is +-1.1), at the street end of the lot, still facing the street (+Z);
	# the doorway, the 1.5 m in front of it and the spawn are clear. The tables (+-2.2, -0.6) stay where they were.
	var B := Vector3(1.65, 0, 0.35)
	var k := MeshKit.new()
	k.box(Vector3(0.7, 1.0, 0.05), B + Vector3(0, 0.55, 0), DARK, 0); k.box(Vector3(0.62, 0.9, 0.06), B + Vector3(0, 0.57, 0.01), Color(0.25, 0.30, 0.28))
	for sx in [-0.33, 0.33]: k.box(Vector3(0.04, 1.1, 0.04), B + Vector3(sx, 0.55, -0.05), WOOD)
	for t in [Vector3(-2.2, 0, -0.6), Vector3(2.2, 0, -0.6)]:
		k.cyl(0.4, 0.04, t + Vector3(0, 0.74, 0), WHITE, 14); k.cyl(0.04, 0.72, t + Vector3(0, 0.37, 0), DARK, 6)
		k.cyl(0.04, 0.12, t + Vector3(0.1, 0.81, 0), WHITE, 8)
		for sx in [-0.65, 0.65]:
			k.box(Vector3(0.4, 0.05, 0.4), t + Vector3(sx, 0.45, 0), WOOD); k.box(Vector3(0.05, 0.45, 0.4), t + Vector3(sx * 1.45, 0.67, 0), WOOD)
			for lx in [-0.15, 0.15]: k.box(Vector3(0.03, 0.45, 0.03), t + Vector3(sx + lx, 0.22, 0), DARK)
		col(Vector3(2.0, 1, 0.9), t + Vector3(0, 0.5, 0))
	k.commit(self)
	var l := Label3D.new(); Lines.set_sign(l, "MENU\ncoffee 2.50\ntea 2.00\ncake 3.00", "MENÜ\nkahve 2.50\nçay 2.00\nkek 3.00"); l.font = load("res://fonts/Nunito.ttf"); l.font_size = 30; l.pixel_size = 0.0035
	l.position = B + Vector3(0, 0.62, 0.05); l.outline_size = 0; add_child(l)
	col(Vector3(0.8, 1.1, 0.2), B + Vector3(0, 0.55, 0)); it.position = B + Vector3(0, 0, 0.9); it.focus = to_global(B + Vector3(0, 0.7, 0))

func _v_cafe() -> Array:
	var lot := _interior_lot()
	if lot != null:   # v31 QA (blue): the café has an interior; ordering happens inside (no separate street charge)
		return [["Read the menu", func(): say("I am reading the menu.")], ["Go inside", func(): lot._on_enter()]]
	return [["Read the menu", func(): say("I am reading the menu."); await get_tree().create_timer(2.6).timeout;say("Coffee is two pounds fifty.")], 
		["Order a coffee (%s)" % Economy.format(250), func():
			if Economy.spend(250, "coffee"): say("I am ordering a coffee.")
			else: say("I do not have enough money.")]]

# ------------------------------------------------------------------ garden gate
func _build_gate() -> void:
	it.obj_name = "garden gate"; S = {"open": false}
	var k := MeshKit.new()
	for sx in [-0.85, 0.85]: k.box(Vector3(0.14, 1.05, 0.14), Vector3(sx, 0.52, 0), WHITE); k.box(Vector3(0.18, 0.05, 0.18), Vector3(sx, 1.07, 0), WHITE)
	k.commit(self)
	var g := MeshKit.new()
	for i in 6: g.box(Vector3(0.07, 0.85, 0.04), Vector3(0.12 + i * 0.28, 0.5, 0), WHITE)
	for y in [0.3, 0.7]: g.box(Vector3(1.55, 0.06, 0.03), Vector3(0.8, y, -0.03), WHITE)
	part("leaf", Vector3(-0.78, 0, 0), g)
	S.col = col(Vector3(1.6, 1.0, 0.15), Vector3(0, 0.5, 0)); it.position = Vector3(0, 0, -0.9); it.radius = 1.5
	it.focus = to_global(Vector3(0, 0.6, 0))
	# usable from both sides: a second marker on the street side
	var it2 := Interactable.new(); it2.radius = 1.5; it2.position = Vector3(0, 0, 0.9); it2.verbs = _verbs; it2.obj_name = it.obj_name; add_child(it2)
	it2.focus = it.focus

func _v_gate() -> Array:
	if not S.open: return [["Open the gate", func(): S.open = true; S.col.disabled = true; swing(parts.leaf, "rotation:y", 1.7); say("I am opening the gate.")]]
	return [["Close the gate", func(): S.open = false; S.col.disabled = false; swing(parts.leaf, "rotation:y", 0.0); say("I am closing the gate.")]]

## v28 blue: the gate swings open by itself when the player walks (or a cutscene runs) up to it; the collider blocks while closed
func _gate_auto() -> void:
	if S.open: return
	var w := W(); var p = w.get("player") if w else null
	if not (p is Node3D): return
	var busy: bool = w.get("mode") == "busy"
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d < (2.3 if busy else 1.4):
		S.open = true; S.col.disabled = true
		var away := -1.0 if to_local(p.global_position).z < 0.0 else 1.0   # swing away from the player
		swing(parts.leaf, "rotation:y", 1.7 * away, 0.35); Audio.sfx("creak1", -8.0)
		if not busy: say("I am opening the gate.")

# ------------------------------------------------------------------ my car (door opens toward -X, driver side)
func _build_car() -> void:
	it.obj_name = "my car"; S = {"locked": true, "open": false}
	# v32: polished CarKit model (sedan, cabin shifted +0.2 like before) + blob shadow; door stays a separate part
	var k := CarKit.new(); k.car(color, 0.2, 0); k.commit(self); CarKit.add_shadow(self, Vector2(2.3, 4.9))
	var paint := CarKit.paint_for(color)
	var d := CarKit.new()
	d.box(CarKit.PAINT, Vector3(0.05, 0.56, 1.1), Vector3(-0.005, 0.02, 0.55), paint)
	d.box(CarKit.GLASS, Vector3(0.04, 0.4, 0.98), Vector3(0, 0.52, 0.55), Color.WHITE)
	d.box(CarKit.PAINT, Vector3(0.05, 0.035, 1.0), Vector3(-0.005, 0.315, 0.55), Color(0.82, 0.83, 0.85))
	d.box(CarKit.PAINT, Vector3(0.03, 0.035, 0.14), Vector3(-0.04, 0.2, 0.9), Color(0.82, 0.83, 0.85))
	var dn := Node3D.new(); dn.position = Vector3(-0.93, 0.6, -0.3); add_child(dn); d.commit(dn); parts["door"] = dn
	col(Vector3(1.9, 1.5, 4.3), Vector3(0, 0.75, 0))
	it.position = Vector3(-1.6, 0, 0.3); it.radius = 1.6; it.focus = to_global(Vector3(-0.9, 1.0, 0.3))

func _v_car() -> Array:
	if S.locked: return [["Unlock the car", func(): S.locked = false; say("I am unlocking my car.")]]
	if not S.open: return [["Open the car door", func(): S.open = true; swing(parts.door, "rotation:y", -1.1); say("I am opening the car door.")],
		["Lock the car", func(): S.locked = true; say("I am locking my car.")]]
	var out: Array = []
	for d in car_destinations():
		var dd: Dictionary = d
		out.append([dd.label, func(): _drive(dd)])
	out.append(["Close the car door", func(): S.open = false; swing(parts.door, "rotation:y", 0.0); say("I am closing the car door.")])
	return out

## v25: destinations from the house job (save.json "state".job via CharacterHook.state, jobs.json like the phone)
static func car_destinations() -> Array:
	var st := CharacterHook.state()
	var job := String(st.get("job", ""))
	var out: Array = []
	if WorldState.day >= 2:   # v31 day 2: the job option (work.json label) or the hospital check-up
		var lbl := "Go to work"
		if ResourceLoader.exists("res://scripts/story/work.gd"): lbl = load("res://scripts/story/work.gd").car_label(job, CharacterHook.is_child(st))
		var sv = App.load_save().get("story", {})
		var dd: Array = [] if (sv is Dictionary and bool(sv.get("day2_work_done", false))) else [{"label": lbl, "place": "school" if lbl == "Go to school" else ("the shop" if lbl == "Go shopping" else "work"), "day2": "work"}]   # v30.5: once
		if not (sv is Dictionary and bool(sv.get("day2_hospital_done", false))): dd.append({"label": "Go to the hospital", "place": "the hospital", "day2": "hospital"})   # v30.5: once
		return dd
	if CharacterHook.is_child(st) or job in ["student", "schoolchild", "teacher"]:
		out.append({"label": "Go to school", "place": "school", "soon": true})
	elif job != "":
		var place := _workplace(job)
		out.append({"label": "Go to work (%s)" % place.trim_prefix("the "), "place": place, "soon": true})
	out.append({"label": "Go to the mall", "place": "the mall", "soon": true})
	out.append({"label": "Go to the hospital", "place": "the hospital", "soon": true})
	return out

static func _workplace(job: String) -> String:
	if FileAccess.file_exists("res://data/jobs.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/jobs.json"))
		if d is Dictionary:
			for j in d.get("jobs", []):
				if String(j.get("id", "")) == job or String(j.get("en", "")) == job:
					var m := RegEx.create_from_string("at (the [^.]+)\\.").search(String(j.get("start", "")))
					if m: return m.get_string(1)
	return "work"

func _drive(d: Dictionary) -> void:
	if ChildDrive.wants_drive(d): ChildDrive.depart(self, d); return   # v33 child-drive: a parent drives a child (adults: unchanged below)
	var w := W()
	if not w.has_method("say_line"): return
	if w.player: w.player.busy = true
	await w.say_line("I am getting in my car.")
	var to := "to school" if d.place == "school" else (("to " + String(d.place)) if d.place in ["the mall", "the hospital", "the shop"] else "to work")
	await w.say_line("I am driving %s." % to)
	if w.player: w.player.busy = false
	match String(d.get("day2", "")):   # v31 day 2
		"work":
			w.save_game(); load("res://scripts/story/work_summary.gd").play(get_tree())   # v30.5: black past-tense summary, no 3D routine
		"hospital":
			w.save_game(); _day2_hospital()

## v31: red's day-2 hospital visit entry (HospitalScene.start_day2_visit, static in hospital.gd)
func _day2_hospital() -> void:
	HospitalScene.start_day2_visit(get_tree())

# ------------------------------------------------------------------ water tap + hose
func _build_tap() -> void:
	it.obj_name = "water tap"; S = {"on": false}
	var k := MeshKit.new()
	k.box(Vector3(0.14, 0.18, 0.08), Vector3(0, 0.75, 0), Color(0.75, 0.75, 0.78)); k.box(Vector3(0.05, 0.05, 0.16), Vector3(0, 0.7, 0.1), Color(0.75, 0.75, 0.78))
	k.cyl(0.28, 0.12, Vector3(0.5, 0.3, 0.12), Color(0.35, 0.6, 0.45), 14)
	for i in 6: k.box(Vector3(0.05, 0.05, 0.3), Vector3(0.5 + sin(i) * 0.05, 0.04, 0.35 + i * 0.28), Color(0.35, 0.6, 0.45), i * 0.2)
	k.commit(self)
	var h := MeshKit.new(); h.box(Vector3(0.12, 0.03, 0.03), Vector3.ZERO, Color(0.85, 0.4, 0.35)); part("handle", Vector3(0, 0.87, 0.02), h)
	var fx := CPUParticles3D.new(); fx.amount = 70; fx.lifetime = 0.8; fx.emitting = false; fx.direction = Vector3(0, 0.6, 1); fx.spread = 10
	fx.initial_velocity_min = 2.0; fx.initial_velocity_max = 2.6; fx.gravity = Vector3(0, -9.8, 0); fx.position = Vector3(0.5, 0.2, 2.1)
	var dm := SphereMesh.new(); dm.radius = 0.02; dm.height = 0.04; dm.radial_segments = 4; dm.rings = 2; fx.mesh = dm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.55, 0.78, 1.0, 0.8); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fx.material_override = wm
	add_child(fx); parts.fx = fx
	col(Vector3(0.8, 0.6, 0.5), Vector3(0.4, 0.3, 0.1)); it.position = Vector3(0, 0, 0.75); it.focus = to_global(Vector3(0, 0.75, 0))

func _v_tap() -> Array:
	if not S.on: return [["Turn on the tap", func(): S.on = true; swing(parts.handle, "rotation:z", 1.5); parts.fx.emitting = true; say("I am turning on the tap.")]]
	return [["Water the flowers", func(): say("I am watering the flowers.")],
		["Turn off the tap", func(): S.on = false; swing(parts.handle, "rotation:z", 0.0); parts.fx.emitting = false; say("I am turning off the tap.")]]

# ------------------------------------------------------------------ traffic light + crosswalk button
## centre = middle of the zebra crossing, the road runs along local X. Poles on both curbs.
## state for cars: "green" | "yellow" | "red". Vehicles read car_state() and stop_s() via group "traffic_lights".
var light_mats := {}
var cycle_t := 0.0
func _build_traffic_light() -> void:
	add_to_group("traffic_lights"); S = {"car": "green", "t": 0.0, "req": false}
	it.queue_free(); it = null
	for c in ["red", "yellow", "green", "ped_red", "ped_green"]:
		var m := StandardMaterial3D.new(); m.emission_enabled = true; m.roughness = 0.6; light_mats[c] = m
	var k := MeshKit.new(); var lamps := {"red": MeshKit.new(), "yellow": MeshKit.new(), "green": MeshKit.new(), "ped_red": MeshKit.new(), "ped_green": MeshKit.new()}
	for side in [-1, 1]:
		var p := Vector3(2.9, 0, side * 4.6)
		k.cyl(0.06, 3.2, p + Vector3(0, 1.6, 0), DARK, 8)
		k.box(Vector3(0.3, 0.85, 0.22), p + Vector3(0, 2.75, 0), DARK)
		for i in 3: lamps[["red", "yellow", "green"][i]].box(Vector3(0.18, 0.18, 0.26), p + Vector3(0, 3.02 - i * 0.26, 0), Color(1, 1, 1))
		k.box(Vector3(0.24, 0.5, 0.2), p + Vector3(-0.2 * 0 , 1.95, 0) + Vector3(0, 0, 0), DARK)
		lamps.ped_red.box(Vector3(0.16, 0.16, 0.22), p + Vector3(0, 2.05, 0), Color(1, 1, 1))
		lamps.ped_green.box(Vector3(0.16, 0.16, 0.22), p + Vector3(0, 1.85, 0), Color(1, 1, 1))
		k.box(Vector3(0.16, 0.24, 0.12), p + Vector3(0, 1.1, side * 0.1), Color(0.95, 0.78, 0.35))
		var bi := Interactable.new(); bi.obj_name = "crossing button"; bi.radius = 1.5; bi.position = p + Vector3(-0.5, 0, side * 0.75)
		bi.verbs = _v_traffic_light; add_child(bi); bi.focus = to_global(p + Vector3(0, 1.1, 0))
		col(Vector3(0.2, 3, 0.2), p + Vector3(0, 1.5, 0))
	k.commit(self)
	for c in lamps:
		var mi: MeshInstance3D = lamps[c].commit(self, false); mi.material_override = light_mats[c]
	_set_lights()

func _v_traffic_light() -> Array:
	return [["Press the button", func():
		if S.car == "green": S.req = true; S.t = 0.0
		say("I am pressing the button."); await get_tree().create_timer(2.4).timeout; say("I am waiting for the green man.")]]

func _process(dt: float) -> void:
	if kind == "gate": _gate_auto(); return
	if kind != "traffic_light": return
	S.t += dt
	match S.car:
		"green": if (S.req and S.t > 2.0) or S.t > 40.0: S.car = "yellow"; S.t = 0.0; S.req = false; _set_lights()
		"yellow": if S.t > 2.0: S.car = "red"; S.t = 0.0; _set_lights()
		"red": if S.t > 9.0: S.car = "green"; S.t = 0.0; _set_lights()

func _set_lights() -> void:
	var on := {"red": S.car == "red", "yellow": S.car == "yellow", "green": S.car == "green", "ped_green": S.car == "red", "ped_red": S.car != "red"}
	var cols := {"red": Color(0.95, 0.25, 0.2), "yellow": Color(1.0, 0.75, 0.2), "green": Color(0.25, 0.85, 0.4), "ped_red": Color(0.95, 0.25, 0.2), "ped_green": Color(0.25, 0.85, 0.4)}
	for c in light_mats:
		var m: StandardMaterial3D = light_mats[c]
		m.albedo_color = cols[c] if on[c] else cols[c].darkened(0.75); m.emission = cols[c]; m.emission_energy_multiplier = 2.5 if on[c] else 0.0

func car_state() -> String: return S.get("car", "green")
## world-space centre of the crossing and the road direction it crosses
func center() -> Vector3: return global_position
func road_dir() -> Vector3: return global_transform.basis.x
