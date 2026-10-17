extends "res://scripts/qa_flow.gd"
## v31 system QA (blue): --mode=world | places | day3   [--tr]   shots -> /workspace/qa31b/<mode>_<tag>_*.png
## Real saves (--save-path=...) and a separate user:// (XDG_DATA_HOME) are set by the runner (tools/qa31b/run.sh).
var tag := "en"
var mode := "world"
var said_b := []
var obj_seen := []
var errs := []

func _ready() -> void:
	if name != "QA31B":
		var n = (get_script() as Script).new(); n.name = "QA31B"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args(): if a.begins_with("--mode="): mode = a.substr(7)
	var tr := "--tr" in OS.get_cmdline_user_args()
	App.save_tr(tr); tag = "tr" if tr else "en"
	shot_dir = "/workspace/qa31b/%s_%s_" % [mode, tag]; DirAccess.make_dir_recursive_absolute("/workspace/qa31b")
	Audio.spoke.connect(func(t): said_b.append(t); print("QA31B SAY ", "OK  " if _voiced(t) else "MISS", " | ", t))
	Objectives.changed.connect(func():
		for it in Objectives.items:
			var s := "%s|%s" % [it.id, it.en]
			if not s in obj_seen: obj_seen.append(s); print("QA31B OBJ ", s))
	await w(1.0); WorldState.load_game()
	match mode:
		"world": await run_world()
		"places": await run_places_full()
		"day3": await run_day3()
	var miss := []
	for s in said_b: if not _voiced(s) and not s in miss: miss.append(s)
	print("QA31B MISSING_VOICE ", JSON.stringify(miss))
	var pc := log.filter(func(l): return l.begins_with("PASS")).size(); var fc := log.filter(func(l): return l.begins_with("FAIL")).size()
	print("QA31B TOTAL %d PASS %d FAIL mode=%s tag=%s" % [pc, fc, mode, tag]); get_tree().quit()

func trchk(where: String) -> void:
	if App.tr_on():
		await w(0.6); var out := []; tr_scan(get_tree().root, out)
		print("QA31B TRSEEN @", where, " ", str(out.slice(0, 5)))
		await ovl_check(where)
	else: await tr_check(where)

func world() -> Node: return get_tree().current_scene
func to_world(spawn: String) -> bool:
	Game.go_to(Game.WORLD_SCENE, spawn)
	var r := await _scene_is(Game.WORLD_SCENE, 40.0)
	await w(3.0); return r
func lots() -> Array:
	return get_tree().get_nodes_in_group("lots")

# ------------------------------------------------------------------ outdoor world
func run_world() -> void:
	App.came_from = "livingroom"
	ok(await to_world("lot:home"), "world loaded at lot:home")
	var ws = world()
	await shot("01_home_street"); await trchk("world start")
	ok(ws.find_child("*Accident*", true, false) == null and not ws.get_children().any(func(c): return c.get_script() and String(c.get_script().resource_path).ends_with("story_accident.gd")), "day 3: no accident cutscene / cat story re-run")
	# ---- traffic
	var p0: Array = ws.cars.map(func(c): return c.global_position)
	await w(3.0)
	var moved := 0
	for i in ws.cars.size(): if ws.cars[i].global_position.distance_to(p0[i]) > 0.5: moved += 1
	ok(moved >= 2, "traffic: %d/%d cars moved in 3 s" % [moved, ws.cars.size()])
	var stuck := 0
	for c in ws.cars + ws.buses: if c.global_position.y < -1.0 or c.global_position.y > 2.0: stuck += 1
	ok(stuck == 0, "vehicles on the road surface (bad y: %d)" % stuck)
	# collisions between cars (overlap)
	var overlap := 0
	for i in ws.cars.size():
		for j in range(i + 1, ws.cars.size()): if ws.cars[i].global_position.distance_to(ws.cars[j].global_position) < 2.0: overlap += 1
	ok(overlap == 0, "no overlapping cars (%d pairs)" % overlap)
	# ---- bus: jump the clock to a scheduled stop time, check doors / board verb, ride and the fare
	var b = ws.bus
	var r: Dictionary = Transit.routes.bus_1
	print("QA31B BUS route ", r.stops, " fare ", r.get("fare"), " headway ", b.headway, " arr ", b.arr)
	var found := false
	for k in 200:
		await w(0.25)
		for vb in ws.buses: if vb.at_stop != "": b = vb; found = true
		if found: break
		if k % 20 == 19: WorldState.minutes += 1.0; for vb in ws.buses: vb.sync(WorldState.minutes)
	ok(found, "a bus reached a stop (at_stop=%s, clock %s)" % [b.at_stop, WorldState.clock_text()])
	if found:
		ws.player.global_position = b.board.global_position + Vector3(0.5, 0, 0.5); ws.cam.focus = ws.player.global_position
		await w(0.6); await shot("02_bus_at_stop")
		ok(b.board.enabled, "bus board verb enabled at the stop")
		var money0 := Economy.wallet
		var cl0 := WorldState.minutes
		await ws._ride(b)
		await w(2.0); await shot("03_bus_after_ride")
		ok(Economy.wallet == money0 - int(r.fare), "bus fare paid (%d -> %d)" % [money0, Economy.wallet])
		ok(WorldState.minutes > cl0, "clock advanced by the ride (%s)" % WorldState.clock_text())
		ok(not ws.player.busy, "player free after the ride")
	# ---- lots / doors
	await to_world("lot:home")
	ws = world()
	var lot_n := 0; var no_entr := []
	for l in lots():
		lot_n += 1
		if l.kind in ["house", "home", "shop"] and l.find_children("*", "Interactable", true, false).is_empty(): no_entr.append(l.lot_id)
	ok(lot_n > 0 and no_entr.is_empty(), "lots loaded: %d, all buildings have an entrance %s" % [lot_n, str(no_entr)])
	for l in lots():
		print("QA31B LOT ", l.lot_id, " kind=", l.kind, " interior=", l.interior_scene, " entr=", l.entrance_global().snapped(Vector3.ONE * 0.1))
	# a neighbour house: knock
	var hs = null
	for l in lots(): if l.kind == "house" and l.interior_scene == "": hs = l; break
	if hs:
		ws.player.global_position = hs.entrance_global() + hs.global_transform.basis.z * 0.8; ws.cam.focus = ws.player.global_position
		var s0 := said_b.size()
		await hs._on_enter(); await w(1.5)
		await shot("04_knock")
		ok(said_b.slice(s0).has("Nobody is at home."), "neighbour door: knock -> 'Nobody is at home.' (%s)" % str(said_b.slice(s0)))
		var it: Interactable = hs.find_children("*", "Interactable", true, false)[0]
		print("QA31B KNOCK verbs ", it.verb_list().map(func(v): return v[0]))
	# ---- the car on the home lot (day 3)
	var car = null
	for o in ws.find_children("*", "StreetObject", true, false): if o.kind == "car": car = o; break
	ok(car != null, "player's car exists on the home lot")
	if car:
		var its: Array = car.find_children("*", "Interactable", true, false)
		var vl := []
		for it in its: vl += it.verb_list().map(func(v): return v[0])
		print("QA31B CAR verbs ", vl)
		ws.player.global_position = car.global_position + Vector3(2.2, 0, 0); ws.cam.focus = ws.player.global_position
		await w(0.8); await shot("05_car")
	# ---- day / night
	var m0 := WorldState.minutes
	WorldState.minutes = 22.0 * 60.0; await w(1.5)
	var lit: int = ws.lamp_lights.filter(func(l): return l.visible).size()
	ok(ws.day_k() == 0.0 and ws.sun.light_energy < 0.3 and lit > 0, "night: sun %.2f, %d street lamps lit" % [ws.sun.light_energy, lit])
	await shot("06_night")
	WorldState.minutes = 19.75 * 60.0; await w(1.0); await shot("07_dusk")
	WorldState.minutes = m0; await w(1.0)
	ok(ws.day_k() == 1.0 and ws.lamp_lights.all(func(l): return not l.visible), "day again: lamps off")
	# ---- needs + battery + clock strip
	var lbl: Label = Life._lbl
	Life.needs.hunger = 0.7; Life.needs.thirst = 0.65
	WorldState.minutes += 1.0; await w(0.8)
	ok(lbl.visible and lbl.text.contains("!"), "needs shown on the clock strip: %s" % lbl.text.replace("\n", " | "))
	await shot("08_needs")
	Life.battery = 14.0; Life._warned = false
	WorldState.minutes += 1.0
	ok(await wait_until(func(): return Objectives.has("charge") or Objectives.has("Charge my phone."), 15.0), "battery < 15%: 'Charge my phone.' objective")
	await w(2.0); await shot("09_battery_low"); await trchk("battery low")
	Life.battery = 0.0; WorldState.minutes += 2.0; await w(0.6)
	ok(Life.battery == 0.0, "battery floors at 0")
	# phone at 0% battery
	ws.open_phone(); await w(3.0)
	var ph = ws.room_phone.phone
	print("QA31B PHONE at 0%% visible=", ph.visible, " page=", ph.page)
	await shot("10_phone_battery0")
	if ph.visible: ph.close(true); await w(1.0)
	Life.battery = 80.0
	# ---- phone
	await wait_until(func(): return ws.mode == "play", 10.0)
	ws.open_phone(); var op := await wait_until(func(): return ph.visible, 15.0)
	await w(1.5)
	ok(op, "phone opens outside")
	await shot("11_phone_home"); await trchk("phone home")
	var ck = ph.find_child("StatusClock", true, false)
	ok(ck != null and ck.text == WorldState.clock_text(), "phone status clock = game clock (%s vs %s)" % [ck.text if ck else "-", WorldState.clock_text()])
	var big: Array = ph.find_children("*", "Label", true, false).filter(func(l): return l.is_visible_in_tree() and l.text.contains(":") and l.text.length() <= 5)
	print("QA31B PHONE home clock labels ", big.map(func(l): return l.text), " game ", WorldState.clock_text(), " day ", WorldState.day)
	for a in ["grammar", "words", "me", "calendar", "family"]:
		var bt = ph.find_child("App_" + a, true, false)
		if bt == null: continue
		bt.pressed.emit(); await w(1.2)
		ok(ph.page == a or ph.page != "home", "phone app %s opens (page %s)" % [a, ph.page])
		await shot("12_phone_" + a)
		ph.show_page("home"); await w(0.6)
	ph.close(true); await w(1.2)
	ok(not ph.visible and await wait_until(func(): return ws.mode == "play", 10.0), "phone closes, back to play")
	# ---- home door: in and out
	var home = ws.grid.find_lot("home")
	if home:
		ws.player.global_position = home.entrance_global() + home.global_transform.basis.z * 0.8
		Objectives.add("charge", "Charge my phone.", "Telefonumu şarj et.")
		App.came_from = "livingroom"; await to_world("lot:home"); await w(1.0)
		ok(Objectives.has("charge"), "world reload keeps 'Charge my phone.' %s" % [Objectives.items.map(func(i): return i.id)])
		ws = world(); home = ws.grid.find_lot("home")
		ws.player.global_position = home.entrance_global() + home.global_transform.basis.z * 0.8
		var had_charge: bool = Objectives.has("charge")
		home._on_enter()
		ok(await _scene_is(Game.HOUSE_FRONT_DOOR_SCENE, 30.0), "home door -> living room")
		await w(3.0); await shot("13_home_inside")
		App.came_from = "livingroom"; ok(await to_world("lot:home"), "back outside")
		var d: float = world().player.global_position.distance_to(world().grid.find_lot("home").entrance_global())
		ok(d < 3.0, "spawned at the home door (%.1f m)" % d)
		await shot("14_home_back_out")
		print("QA31B OBJ after home round trip ", Objectives.items.map(func(i): return i.id))
		print("QA31B INFO house round trip keeps charge objective: ", Objectives.has("charge"), " (had ", had_charge, ") -> black livingroom._set_mission")
	# ---- walk the player along the street for a bit (fade, NPC LOD, footsteps) and check FPS-ish
	ws = world()
	var t0 := Time.get_ticks_msec(); var fr0 := Engine.get_frames_drawn()
	for k in 40:
		ws.stick = Vector2(0, -1); await w(0.1)
	ws.stick = Vector2.ZERO
	var fps := (Engine.get_frames_drawn() - fr0) / ((Time.get_ticks_msec() - t0) / 1000.0)
	print("QA31B FPS walking ", fps, " npcs ", ws.npc_pool.size())
	await shot("15_walk")

# ------------------------------------------------------------------ cafe + shop entered from the street, full flow
func run_places_full() -> void:
	for lid in ["corner_shop", "cafe"]:
		var pid := "shop" if lid == "corner_shop" else "cafe"
		var scn := "res://scenes/places/%s.tscn" % pid
		App.came_from = "livingroom"
		ok(await to_world("lot:" + lid), "%s: world at the lot" % pid)
		var ws = world()
		var lot = ws.grid.find_lot(lid)
		ok(lot != null and lot.interior_scene == scn, "%s: lot interior %s" % [pid, lot.interior_scene if lot else "-"])
		if lot == null: continue
		var ents: Array = lot.find_children("*", "Interactable", true, false)
		var vlist: Array = ents[0].verb_list() if ents.size() > 0 else []
		print("QA31B ", pid, " door verbs ", vlist.map(func(v): return v[0]))
		ok(vlist.size() > 0 and String(vlist[0][0]) == "Go inside", "%s: street door offers 'Go inside' (%s)" % [pid, str(vlist.map(func(v): return v[0]))])
		var near := []
		for o in ws.find_children("*", "Interactable", true, false):
			if o.enabled and o.is_visible_in_tree() and o.global_position.distance_to(lot.entrance_global()) < 2.5 and not o in ents: near.append([o.get_parent().name, o.verb_list().map(func(v): return v[0])])
		print("QA31B ", pid, " other interactables at the door ", near)
		ws.player.global_position = lot.entrance_global() + lot.global_transform.basis.z * 0.8; ws.cam.focus = ws.player.global_position
		await w(1.0); await shot(pid + "_00_door")
		if pid == "cafe": Objectives.add("charge", "Charge my phone.", "Telefonumu şarj et.")   # must survive the visit
		var money0 := Economy.wallet
		if vlist.size() > 0: (vlist[0][1] as Callable).call()   # the player's verb, like tapping the chip
		else: lot._on_enter()
		ok(await _scene_is(scn, 30.0), "%s: entered from the street" % pid)
		var sc = world()
		await w(1.5); await shot(pid + "_01_inside")
		var ph = sc.room_phone.phone
		var seen := {}; var t := 0; var skipped := false; var retook := false; var cine := 0; var checkout_shot := false
		while t < 2400:
			await w(0.25); t += 1
			if not is_instance_valid(sc) or world() != sc: break
			if sc._cine_cam != null and cine < 6 and t % 10 == 0: cine += 1; await shot("%s_02_cine_%d" % [pid, cine])
			if ph.visible and ph.page == "lesson" and not Audio.is_speaking():
				var nb = ph.find_child("LessonNext", true, false)
				if nb and not nb.disabled: nb.pressed.emit()
				continue
			if ph.visible and ph.page == "quiz":
				var sk = ph.find_child("SkipTest", true, false)
				if retook and sk and not skipped: skipped = true; await shot(pid + "_04_test"); sk.pressed.emit(); continue
				var row = ph.find_child("Options", true, false)
				if row and not Audio.is_speaking() and not ph._answering:
					var q: Dictionary = ph._qz()[ph.quiz_i]
					var btns: Array = row.get_children().filter(func(bb): return bb is Button and not bb.disabled)
					if btns.size() == row.get_child_count():
						var wrong: int = 1 - int(q.a) if q.opts.size() == 2 else (int(q.a) + 1) % q.opts.size()
						(row.get_child(wrong if not ph.quiz_wrong else int(q.a)) as Button).pressed.emit()
				continue
			if ph.visible and ph.page == "score" and not retook:
				await Audio.wait_idle(10.0)
				for bb in ph.find_children("*", "Button", true, false): if "Retake" in bb.text: retook = true; bb.pressed.emit(); break
				continue
			if sc.mode == "play" and sc._mark_target != null:
				var id := ""
				for k in sc.its: if sc.its[k] == sc._mark_target: id = k
				if id != "" and not seen.has(id):
					seen[id] = true
					await shot("%s_03_obj_%s" % [pid, id]); await trchk(pid + " obj " + id)
					if id == "exit":
						var money1 := Economy.wallet
						print("QA31B ", pid, " wallet ", money0, " -> ", money1, " inv ", Economy.inventory)
						if pid == "cafe": ok(money0 - money1 == 450, "cafe: charged GBP 4.50 (%d -> %d)" % [money0, money1])
						else: ok(money0 - money1 > 0 and Economy.inventory.size() > 0, "shop: paid %d, inventory %s" % [money0 - money1, str(Economy.inventory)])
					sc.qa_use(id)
					if id == "exit": break
		ok(seen.has("exit"), "%s: full first visit to the exit (objectives %s)" % [pid, str(seen.keys())])
		ok(skipped and retook, "%s: retake then skip" % pid)
		ok(await _scene_is(Game.WORLD_SCENE, 30.0), "%s: leave() -> street" % pid)
		await w(3.0)
		var lot2 = world().grid.find_lot(lid)
		var d: float = world().player.global_position.distance_to(lot2.entrance_global()) if lot2 else 99.0
		ok(d < 3.0, "%s: back at its door (%.1f m)" % [pid, d])
		if pid == "cafe": ok(Objectives.has("charge"), "cafe: 'Charge my phone.' kept through the visit")
		ok(not Objectives.has("Walk to the street."), "%s: no stale 'Walk to the street.' after the visit %s" % [pid, str(Objectives.items.map(func(i): return i.en))])
		await shot(pid + "_05_back_outside"); await trchk(pid + " back outside")
		# second visit: no repeat of the cinematic, money not charged again
		var money2 := Economy.wallet
		lot2._on_enter(); await _scene_is(scn, 30.0); var sc2 = world(); await w(6.0)
		await shot(pid + "_06_second_visit")
		ok(sc2._cine_cam == null and Economy.wallet == money2, "%s: second visit, no cinematic / no charge (wallet %d)" % [pid, Economy.wallet])
		var t2 := 0
		while t2 < 120 and not (sc2.mode == "play" and sc2._mark_target != null): await w(0.25); t2 += 1
		var id2 := ""
		for k in sc2.its: if sc2.its[k] == sc2._mark_target: id2 = k
		ok(id2 == "exit", "%s: second visit goes straight to 'Go outside.' (%s)" % [pid, id2])
		if id2 != "": sc2.qa_use(id2)
		await _scene_is(Game.WORLD_SCENE, 30.0); await w(2.0)

# ------------------------------------------------------------------ day 3 morning (red's story) from a real day-3 save
func run_day3() -> void:
	ok(Day3Morning.stage() == "shower", "save: day 3, d3=shower (day %d)" % WorldState.day)
	App.came_from = ""; App.continue_requested = true
	get_tree().change_scene_to_file("res://main.tscn"); await _scene_is("res://main.tscn")
	m = world()
	ok(await wait_until(func(): return Objectives.has("Take a shower."), 40.0), "day 3: Take a shower.")
	await w(2.0); await shot("01_shower_obj"); await trchk("d3 bedroom")
	await wait_until(func(): return m.mode == "play", 20.0)
	App.came_from = "bedroom"; get_tree().change_scene_to_file("res://bathroom.tscn"); await _scene_is("res://bathroom.tscn")
	var bt = world(); await w(4.0); await shot("02_bath")
	await wait_until(func(): return bt.mode == "play", 30.0)
	for v in bt.verbs("bath"): if v[2] == "takeshower": bt.do_verb("bath", v); break
	ok(await wait_until(func(): return Objectives.has("Go to the living room."), 150.0), "after the shower: Go to the living room.")
	await w(2.0); await shot("03_after_shower"); await trchk("d3 bathroom")
	await wait_until(func(): return bt.mode == "play", 30.0)
	App.came_from = "bathroom"; get_tree().change_scene_to_file("res://livingroom.tscn"); await _scene_is("res://livingroom.tscn")
	ok(await wait_until(func(): return Objectives.has("Go outside."), 40.0), "living room: Go outside.")
	await w(2.0); await shot("04_living"); await trchk("d3 living")
	App.came_from = "livingroom"; Game.go_to(Game.WORLD_SCENE, "lot:home")
	ok(await wait_until(func(): return Objectives.has("Explore the town."), 60.0), "outside: Explore the town.")
	await w(2.0); await shot("05_outside"); await trchk("d3 outside")
	ok(not Objectives.has("Walk to the street."), "no leftover 'Walk to the street.' with 'Explore the town.' %s" % str(Objectives.items.map(func(i): return i.en)))
	await w(5.0)
	ok(Day3Morning.stage() == "done", "d3 stage done")
	await shot("05b_outside_later")
	var cam3 = get_viewport().get_camera_3d()
	ok(cam3 == world().cam, "outside: follow camera active again after the pans (%s)" % (cam3.name if cam3 else "-"))
	# reload test: save + continue keeps the day-3 state
	world().save_game()
	print("QA31B D3 save story ", App.load_save().get("story", {}).get("d3"), " day ", App.load_save().get("day"))
	# after day 3 is done: a bedroom continue must not restart the shower objective
	App.came_from = ""; get_tree().change_scene_to_file("res://main.tscn"); await _scene_is("res://main.tscn"); await w(6.0)
	ok(not Objectives.has("Take a shower."), "d3 done: no shower objective again on continue %s" % str(Objectives.items.map(func(i): return i.en)))
	await shot("06_bedroom_after")
