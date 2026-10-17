extends "res://scripts/qa_flow.gd"
## v32.1: typed player + family names in the chosen narrator's own model (generateNarrator) for f/m/c/g, via the real
## New Game -> mirror name entry -> creation path. Desktop has no SherpaTts plugin -> a logging mock with the same API.
var mock
var fails := 0
var said321 := []
func cur() -> Node: return get_tree().current_scene
func scene_is(p: String, t := 30.0) -> bool:
	return await wait_until(func(): return cur() != null and cur().scene_file_path == p, t)

func _ready() -> void:
	if name != "QAV321Root":
		var n = (get_script() as Script).new(); n.name = "QAV321Root"; get_tree().root.add_child.call_deferred(n); return
	process_mode = Node.PROCESS_MODE_ALWAYS
	mock = load("res://tools/qa_v321/mock_sherpa.gd").new()
	Audio._sherpa = mock
	Audio.spoke.connect(func(t): said321.append(t); print("V321 SAY | ", t))
	run321.call_deferred()

func ok2(c: bool, t: String) -> void:
	ok(c, t); if not c: fails += 1
func gens(v: String, text: String) -> int:
	return mock.calls.filter(func(c): return c[0] == "gen" and c[2] == text).filter(func(c): return c[1] == v).size()
func gens_other(v: String, text: String) -> int:
	return mock.calls.filter(func(c): return c[0] == "gen" and c[2] == text and c[1] != v).size()

func pressed(nm: String) -> void:
	var b := btn_named(m.side, nm); if b: b.pressed.emit()

func play(tag: String, gender: String, age: String, want: String, pname: String, fname: String) -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
	await scene_is("res://menu.tscn", 20.0); await w(0.8)
	btn_text(cur(), ["Yeni Oyun", "New Game"]).pressed.emit()
	ok2(await scene_is("res://main.tscn", 20.0), tag + ": New Game -> bedroom")
	m = cur()
	ok2(await wait_until(func(): return m.mode == "play", 45.0), tag + ": wake-up -> play")
	for v in m.verbs("alarm"):
		if v[2] == "off": m.do_verb("alarm", v)
	await wait_until(func(): return m.mission == "Look in the mirror." and m.mode == "play", 30.0); await w(0.5)
	for v in m.verbs("mirror"):
		if v[2] == "look": m.do_verb("mirror", v)
	ok2(await wait_until(func(): return m.side != null and m.side.find_child("Letters", true, false) != null, 30.0), tag + ": name entry")
	await w(0.8)
	for L in pname.to_upper(): pressed("Key_" + L); await w(0.2)
	ok2(m.S.name == pname, tag + ": typed player name %s" % m.S.name)
	var pre_narr: String = Audio.narrator
	pressed("DoneName")
	await wait_until(func(): return m.side != null and m.side.find_child("DoneLook", true, false) != null, 40.0)
	await w(1.0)
	ok2(gens(pre_narr, "My name is %s." % pname) >= 1, tag + ": player name (before look) via generateNarrator in current narrator %s" % pre_narr)
	m.S.gender = gender; m.S.age = age
	pressed("DoneLook")
	ok2(await wait_until(func(): return m.mode == "play", 25.0), tag + ": creation done")
	ok2(Audio.narrator == want and String(App.settings.narrator) == want, tag + ": narrator from creation = %s (want %s)" % [Audio.narrator, want])
	# player name again in the chosen narrator (the room-entry / re-intro path) + typed family name (phone family editor path)
	mock.calls.clear()
	Audio.say_name(pname); Audio.say_this_is(fname)
	await Audio.wait_idle(); await w(0.3)
	ok2(gens(want, "My name is %s." % pname) == 1 and gens_other(want, "My name is %s." % pname) == 0, tag + ": 'My name is %s' -> generateNarrator(%s) only" % [pname, want])
	ok2(gens(want, "This is %s." % fname) == 1 and gens_other(want, "This is %s." % fname) == 0, tag + ": 'This is %s' -> generateNarrator(%s) only" % [fname, want])
	ok2(mock.calls.filter(func(c): return c[0] == "init" and c[1] != want).is_empty(), tag + ": initNarrator only for %s" % want)
	for f in String(mock.narratorFiles(want)).split(","):
		ok2(FileAccess.file_exists("user://tts/" + f), tag + ": model copied user://tts/" + f)
	var logged := Audio.voice_log.filter(func(e): return e.what == "This is %s" % fname)
	ok2(logged.size() == 1, tag + ": family-name line played once from the queue")
	# bundled common name: the chosen narrator's own pack clip (no TTS)
	mock.calls.clear(); Audio.say_this_is("Emma"); await Audio.wait_idle()
	print("V321 Emma via ", "clip" if mock.calls.is_empty() else "generateNarrator")
	# model failure: caption only, never another voice
	mock.fail[want] = 1; Audio._sherpa_ok[want] = 0; Audio.voice_log.clear()
	Audio.say_this_is("Qwerty"); await Audio.wait_idle(); await w(0.2)
	ok2(Audio.voice_log.filter(func(e): return String(e.what).contains("Qwerty")).is_empty(), tag + ": model failed -> name not voiced in any other voice")
	mock.fail.erase(want); Audio._sherpa_ok.erase(want)

func run321() -> void:
	await w(1.0)
	ok2(not Engine.has_singleton("SherpaTts"), "desktop: no SherpaTts plugin (mock injected)")
	await play("f", "women", "adult", "f", "Zandor", "Brixley")
	await play("m", "men", "adult", "m", "Quorin", "Velmora")
	await play("c", "men", "child", "c", "Jaxtyn", "Orvella")
	await play("g", "women", "child", "g", "Tamsyn", "Krellan")
	print("V321 DONE fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
