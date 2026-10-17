## v33 (red): DAY 4 / DAY 7 SHOPPING TRIP inside blue's corner shop (scenes/places/shop.tscn, scripts/places/shop.gd).
## Blue's shop is not edited. On a repeat visit blue's run() goes straight to its "Go outside." exit objective; we wait for
## that (exit target enabled + mode "play"), then play our checkout dialogue (data "shop" in data/day4.json / day7.json):
## walk to the counter, the assistant (NpcTalk: keeps the pose) and the player talk, pay (Economy), take the bag, snapshot
## for the polaroid, then control comes back with the "Go outside." objective (blue's exit door still works).
## ENTRY (Day4Routine._enter on the shop scene): var s = load(this).new(); s.sc = sc; s.data_path = ...; sc.add_child(s); await s.run()
extends Node

const NpcTalk := preload("res://scripts/core/npc_talk.gd")
const CK := Vector3(3.6, 0, 2.3)   # = shop.gd CK (checkout counter centre)
var sc: Node
var data_path := "res://data/day4.json"
var D := {}

func _w(t: float) -> void: await get_tree().create_timer(t, false).timeout

func run() -> bool:
	D = App.load_json(data_path); D = D if D is Dictionary else {}
	var t0 := Time.get_ticks_msec()
	sc.set_meta("story_hold", true)   # build 3.2: shop.gd holds its "Go outside." until our checkout is done
	while is_instance_valid(sc) and Time.get_ticks_msec() - t0 < 240000:
		if sc.has_meta("ow_exit_ready"): break
		await get_tree().process_frame
	if not is_instance_valid(sc) or not sc.is_inside_tree(): return false
	await Audio.wait_idle(10.0); await _w(0.8)
	if not is_instance_valid(sc): return false
	sc.busy(true)
	var a = sc.npcs.get("assistant") if sc.get("npcs") is Dictionary else null
	var cam_on := false
	for e in D.get("shop", []):
		if not is_instance_valid(sc): return false
		var what := String(e.get("do", ""))
		match what:
			"counter":
				await sc.walk_to(CK + Vector3(-0.85, 0, -0.2), PI / 2)
				await sc.cine(CK + Vector3(-1.6, 1.8, 1.4), CK + Vector3(0.3, 1.2, -0.3), 1.2); cam_on = true
			"pay":
				var price := int(D.get("shop_price", 0))
				if price > 0 and Economy.spend(price, String(D.get("shop_reason", "shop"))):
					var inv: Dictionary = D.get("shop_items", {})
					for k in inv: Economy.inventory[k] = int(Economy.inventory.get(k, 0)) + int(inv[k])
				sc.hero.play("pick_up", 0.25); Audio.sfx("place_coins", -6.0); Audio.sfx("place_till", -8.0)
				await _w(0.7); sc.hero.play("idle", 0.3)
			"bag":
				Audio.sfx("place_bag", -6.0)
				if ResourceLoader.exists("res://props/places/food/bag.glb"): sc.hero.hold_item("res://props/places/food/bag.glb", "long", 0.42, true)
			"snap":
				var p: Vector3 = sc.hero.global_position
				var at := p + Vector3(0, 1.0, 0); var eye := p + Vector3(0.9, 1.6, 1.5)
				Life.snap_from(String(D.get("shop_photo", "d4_shop")), Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye), 50.0)
			_:
				var en := String(e.get("en", ""))
				if en == "": continue
				if String(e.get("who", "me")) == "assistant" and a is DemoCharacter: await _npc(a, en)
				else: await _me(en)
	if cam_on and is_instance_valid(sc): await sc.cine_end()
	var sv = App.load_save().get("story", {}); sv = sv.duplicate() if sv is Dictionary else {}
	sv[String(D.get("shop_flag", "d4_shop"))] = true; App.patch_save({"story": sv})
	if not is_instance_valid(sc): return true
	sc.busy(false)
	sc.remove_meta("story_hold")   # build 3.2: shop.gd now sets "Go outside." (once, after buying)
	return true

## player line: Voice.say is silent without a clip, so those lines go to Audio.say (narrator clip / Piper fallback)
func _me(en: String) -> void:
	await Audio.wait_idle(12.0)
	if not is_instance_valid(sc): return
	if Voice.has_clip(en) or not sc.S.get("voice", true): await sc.say_line(en); return
	sc.caption(en, false); Audio.say(en)
	await _w(0.2); await Audio.wait_idle(12.0); await _w(0.25)

## assistant line: own Piper voice, the shared HUD caption box (TR inside), NpcTalk = turn + nod, pose unchanged
func _npc(a: DemoCharacter, en: String) -> void:
	await Audio.wait_idle(12.0)
	if not is_instance_valid(sc): return
	var st: Dictionary = NpcTalk.begin(a, sc.hero.global_position)
	sc._mute_next = true; sc.hud.caption(en, 6.0); sc._mute_next = false
	if sc.S.get("voice", true):
		Audio.say_as(en, String(a.get_meta("voice", "")))
		await _w(0.2); await Audio.wait_idle(12.0); await _w(0.25)   # v33 QA: voice_idle gave up after 8 s (lines ran 0.2 s apart)
	else: await _w(2.2)
	NpcTalk.end(a, st)
