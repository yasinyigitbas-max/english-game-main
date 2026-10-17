extends "res://scripts/qa_flow.gd"
## v31 QA: universal narrator in the bathroom / outdoor / word clips.
## godot ... res://qa_boot.tscn -- --qa-v31fix --save-path=<any created-character save>
func run_v31fix() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await w(1.0)
	App.came_from = "bedroom"
	get_tree().change_scene_to_file("res://bathroom.tscn"); await w(4.0)
	var b = get_tree().current_scene
	ok(b.scene_file_path == "res://bathroom.tscn", "bathroom loaded")
	for v in ["m", "c", "g"]:
		Audio.set_narrator(v)
		for t in ["Wash your face.", "Brush your teeth."]:
			await Audio.wait_idle(10.0)
			var alt = Audio.narrator_alt(t); var own = b._vclip("en:" + t)
			var n0: int = Audio.voice_log.size()
			b.say(t); await w(0.3)
			var played = Audio.voice_player.stream
			ok(alt != null and played != null and is_equal_approx(played.get_length(), alt.get_length()) and (own == null or not is_equal_approx(alt.get_length(), own.get_length())),
				"A bathroom narrator=%s '%s' plays the pack clip (pack %.2fs, played %.2fs, bathroom-female %.2fs)" % [v, t, alt.get_length() if alt else -1.0, played.get_length() if played else -1.0, own.get_length() if own else -1.0])
	Audio.set_narrator("m")
	for t in ["I'm outside now.", "Walk to the street."]:
		ok(Audio.narrator_alt(t) != null or not FileAccess.file_exists(Voice.clip_path(t)), "A outdoor line '%s' has a male pack clip" % t)
	ok(Audio.narrator_alt("alarm clock") != null, "A word clip 'alarm clock' has a male pack clip")
	Audio.set_narrator("f")
	print("V31FIX fails=", log.filter(func(l): return l.begins_with("FAIL")).size()); get_tree().quit()
