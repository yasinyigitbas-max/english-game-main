extends Node
## narrator-voices QA (not exported: tools/*). Run: godot --path . res://tools/qa_voices.tscn -- --phase=1|2
## phase 1: clips per voice, fallback, character lines, default unchanged, UI labels (TR/EN), real story scene; sets narrator "c"
## phase 2 (after restart): narrator "c" still selected + loaded
var fails := 0
func ok(c: bool, m: String) -> void:
	print("QAV ", "PASS " if c else "FAIL ", m); if not c: fails += 1

func _bytes(st: AudioStream) -> int: return (st as AudioStreamOggVorbis).packet_sequence.packet_data.size() if st is AudioStreamOggVorbis else -1

func _ready() -> void:
	var phase := "1"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--phase="): phase = a.substr(8)
	while get_tree().current_scene == null or get_tree().current_scene.name != "Menu" and not get_tree().current_scene.has_method("show_settings"): await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	if phase == "2":
		ok(String(App.settings.narrator) == "c", "persisted narrator after restart = %s" % App.settings.narrator)
		ok(Audio.narrator == "c" and Audio.alt_index.size() > 1000, "Audio loaded Boy pack at boot (%d lines)" % Audio.alt_index.size())
		App.set_narrator("f")
		_end(); return
	ok(String(App.settings.narrator) == "f", "fresh user dir: default narrator Female")
	var keys: Array = []
	for k in Audio.index: if not String(k).begins_with("v_"): keys.append(k)
	keys.sort()
	var sample := [keys[0], keys[200], keys[700], keys[1200], keys[keys.size() - 1]]
	# default unchanged: f clips are the original bank bytes
	Audio.set_narrator("f")
	var base := {}
	for k in sample:
		var st := Audio._clip(k); base[k] = st
		ok(st != null and _bytes(st) > 0, "Female clip ok: %s (%.2fs)" % [k, st.get_length() if st else 0.0])
	for v in ["m", "c", "g"]:
		App.set_narrator(v)
		ok(Audio.alt_index.size() > 1000 and Audio.alt_files.size() > 0, "%s pack loaded: %d lines, %d chunks" % [v, Audio.alt_index.size(), Audio.alt_files.size()])
		for k in sample:
			var a0: int = Audio.alt_stats.alt
			var st := Audio._clip(k)
			ok(st != null and st.get_length() > 0.3 and Audio.alt_stats.alt == a0 + 1, "%s clip: %s (%.2fs vs female %.2fs)" % [v, k, st.get_length() if st else 0.0, base[k].get_length()])
		# play several lines for real through the queue
		Audio.voice_log.clear()
		for k in sample.slice(0, 3): Audio.say(k)
		await Audio.wait_idle(30.0); await get_tree().create_timer(0.5).timeout
		var played := Audio.voice_log.filter(func(e): return sample.has(e.what) and e.end > e.start + 0.3).size()
		print("QAV played ", v, ": ", Audio.voice_log.map(func(e): return "%s %.2fs" % [e.what, e.end - e.start]))
		ok(played == 3, "%s: 3 lines played through Audio queue (%d)" % [v, played])
		# fallback: line missing from the pack -> default clip
		var miss: String = sample[2]; var save = Audio.alt_index[miss]; Audio.alt_index.erase(miss)
		var fb0: int = Audio.alt_stats.fallback
		var st2 := Audio._clip(miss)
		ok(st2 != null and is_equal_approx(st2.get_length(), base[miss].get_length()) and Audio.alt_stats.fallback == fb0 + 1, "%s: missing line falls back to default clip" % v)
		Audio.alt_index[miss] = save
		# character voices untouched
		for ck in Audio.index:
			if String(ck).begins_with("v_"):
				Audio.narrator = "f"; var cf := Audio._clip(ck).get_length(); Audio.narrator = v
				var a1: int = Audio.alt_stats.alt
				ok(is_equal_approx(Audio._clip(ck).get_length(), cf) and Audio.alt_stats.alt == a1, "%s: character clip unchanged (%s)" % [v, ck]); break
	# v30.1: no manual narrator selection in the main menu or the pause menu
	var menu := get_tree().current_scene
	for lang in ["tr", "en"]:
		App.settings.lang = lang; menu.show_settings(); await get_tree().process_frame
		ok(menu.find_child("NarratorLabel", true, false) == null and menu.find_child("Narrator_g", true, false) == null, "main menu has no narrator selection (%s)" % lang)
		get_viewport().get_texture().get_image().save_png("user://qa_menu_%s.png" % lang)
	App.settings.lang = "tr"; App.save_settings(); menu.show_title()
	var gs := GDScript.new(); gs.source_code = "extends Node\nvar S := {\"tr\": true, \"voice\": true}\n"; gs.reload()
	var host := Node.new(); host.set_script(gs); add_child(host)
	var gm = load("res://scripts/game_menu.gd").new(); add_child(gm); gm.setup(host, "Bedroom", func(): pass); gm.show_menu(true); gm.settings.visible = true
	await get_tree().process_frame
	var txt := gm.find_children("*", "Label", true, false).map(func(l): return l.text) + gm.find_children("*", "Button", true, false).map(func(b): return b.text)
	ok(not txt.any(func(t): return String(t).contains("Narrator") or String(t).contains("Anlatıcı")), "pause menu has no narrator selection")
	gm.queue_free(); host.queue_free()
	# v30.1: narrator from the character: man Male, woman Female, boy Boy, girl Girl
	for c in [["men", "adult", "m"], ["women", "adult", "f"], ["men", "child", "c"], ["women", "child", "g"]]:
		App.narrator_from_look(c[0], c[1], true)
		ok(Audio.narrator == c[2] and String(App.settings.narrator) == c[2] and (c[2] == "f" or Audio.alt_index.size() > 1000), "character %s/%s -> narrator %s (pack %d lines)" % [c[0], c[1], Audio.narrator, Audio.alt_index.size()])
	# real game scene with Male narrator: story lines must come from the Male pack
	App.set_narrator("m"); Audio.alt_stats = {"alt": 0, "fallback": 0}; Audio.stats.clip = 0
	get_tree().change_scene_to_file(App.GAME_SCENE)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000: await get_tree().process_frame
	print("QAV scene log: ", Audio.voice_log.map(func(e): return e.what).slice(-8))
	ok(Audio.alt_stats.alt > 0, "main scene: narrator lines from Male pack (alt=%d fallback=%d, clips=%d)" % [Audio.alt_stats.alt, Audio.alt_stats.fallback, Audio.stats.clip])
	App.set_narrator("c")   # for phase 2
	_end()

func _end() -> void:
	print("QAV DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
