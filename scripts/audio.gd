extends Node
## Voice (pre-rendered Piper clips → TTS fallback), music, SFX, microphone recording. Never blocks.
signal spoke(text: String)

var index: Dictionary = {}
var voice_files: Array = []   # voice/voice_000.bin, voice_001.bin ... (chunks < 24 MB)
var voice_player: AudioStreamPlayer
var queue: Array = []          # [{"stream":..} or {"tts": text}]
var tts_ok := false
var tts_voice := ""
var sfx_player: AudioStreamPlayer
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var current_music := ""
var music_on := true
var mic_player: AudioStreamPlayer
var record_effect: AudioEffectRecord
var mic_ok := false
var stats := {"clip": 0, "tts": 0, "silent": 0}
var missing: Array = []   # house.17 QA: lines spoken without a narrator clip

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var f := FileAccess.open("res://data/voice_index.json", FileAccess.READ)
	if f:
		index = JSON.parse_string(f.get_as_text())
	reopen_banks()
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	voice_player.finished.connect(_next)
	sfx_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050
	gen.buffer_length = 1.0
	sfx_player.stream = gen
	add_child(sfx_player)
	sfx_player.play()
	music_a = AudioStreamPlayer.new(); music_b = AudioStreamPlayer.new()
	# v32 polish (blue): music runs on its own "Music" bus so it can duck under speech without touching the crossfades
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(); AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music"); AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for m in [music_a, music_b]:
		m.volume_db = -80; m.bus = "Music"
		add_child(m)
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var v := DisplayServer.tts_get_voices_for_language("en")
		if v.size() > 0:
			tts_voice = v[0]
		tts_ok = v.size() > 0 or DisplayServer.tts_get_voices().size() > 0
	_setup_mic()

static func norm(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		var c := ch.unicode_at(0)
		if (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == "'":
			out += ch
		else:
			out += " "
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out.strip_edges()

func has_clip(text: String) -> bool:
	return index.has(norm(text))

## narrator-voices: optional narrator packs (voice_m/ Male, voice_c/ Boy, voice_g/ Girl), each with its own index
## data/voice_index_<v>.json (same norm keys / format as data/voice_index.json). Only narrator/player lines are in them
## (never "v_<voice> ..." character clips). A line missing from the chosen pack falls back to the default ljspeech clip.
const NARRATORS := ["f", "m", "c", "g"]   # Female (default ljspeech) / Male / Boy / Girl
var narrator := "f"
var alt_index: Dictionary = {}
var alt_files: Array = []
var alt_stats := {"alt": 0, "fallback": 0}
func set_narrator(v: String) -> void:
	narrator = v if NARRATORS.has(v) else "f"
	alt_index = {}; alt_files.clear()
	if narrator == "f": return
	var f := FileAccess.open("res://data/voice_index_%s.json" % narrator, FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary: alt_index = d
	var ci := 0
	while FileAccess.file_exists("res://voice_%s/voice_%s_%03d.bin" % [narrator, narrator, ci]):
		alt_files.append(FileAccess.open("res://voice_%s/voice_%s_%03d.bin" % [narrator, narrator, ci], FileAccess.READ))
		ci += 1
	print("Audio: narrator=%s lines=%d chunks=%d" % [narrator, alt_index.size(), alt_files.size()])

func _alt_clip(key: String) -> AudioStream:
	if narrator == "f" or key.begins_with("v_") or not alt_index.has(key): return null
	var e: Array = alt_index[key]
	var c := int(e[0])
	if c >= alt_files.size() or alt_files[c] == null: return null
	var vf: FileAccess = alt_files[c]
	vf.seek(int(e[1]))
	return AudioStreamOggVorbis.load_from_buffer(vf.get_buffer(int(e[2])))

## v31: the selected narrator pack's clip for a narrator/player line (null for the default female narrator or a missing line).
## For callers that play lines from their own banks (bathroom, bk extras, word clips, outdoor .ogg) so the narrator setting is universal.
func narrator_alt(text: String) -> AudioStream:
	return _alt_clip(norm(text))

func _clip(key: String) -> AudioStream:
	if narrator != "f" and not key.begins_with("v_"):
		var a := _alt_clip(key)
		if a: alt_stats.alt += 1; return a
		if index.has(key): alt_stats.fallback += 1
	if not index.has(key):
		return null
	var e: Array = index[key]
	var c := int(e[0])
	if c >= voice_files.size() or voice_files[c] == null:
		return null
	var vf: FileAccess = voice_files[c]
	vf.seek(int(e[1]))
	return AudioStreamOggVorbis.load_from_buffer(vf.get_buffer(int(e[2])))

func envelope(text: String) -> PackedByteArray:
	var k := norm(text)
	if not index.has(k):
		return PackedByteArray()
	return Marshalls.base64_to_raw(index[k][3])

## Speak text. interrupt=true clears anything queued. Returns immediately.
## v11: every voice item (clip or device TTS) is queued and played strictly one after another.
var tts_busy := false
var _tts_serial := 0
var voice_log: Array = []      # {"what", "start", "end"} in seconds, for QA (no overlap, order)
var _cur_log := -1

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _end_cur() -> void:
	if _cur_log >= 0 and _cur_log < voice_log.size() and voice_log[_cur_log].end < 0: voice_log[_cur_log].end = _now()
	_cur_log = -1

func stop_all() -> void:
	queue.clear(); voice_player.stop(); _end_cur(); cur_group = ""
	if tts_ok: DisplayServer.tts_stop()
	tts_busy = false; _tts_serial += 1

func _kick() -> void:
	if not voice_player.playing and not tts_busy: _next()

## spell a word letter by letter (queued, no interruption between letters)
func spell(word: String) -> void:
	for ch in word:
		var st := _clip("letter " + ch.to_lower())
		if st: queue.append({"stream": st, "what": "letter " + ch.to_lower()})
		elif tts_ok: queue.append({"tts": ch, "what": "letter " + ch.to_lower()})
	_kick()

## a free word (a name) through device TTS, queued like a clip
func say_tts(text: String) -> void:
	if tts_ok and text != "": queue.append({"tts": text, "what": text}); _kick()

func wait_idle(max_s := 15.0) -> void:
	var t0 := _now()
	while is_speaking() and _now() - t0 < max_s: await get_tree().process_frame

var cur_group := ""   # house.19: group of the line playing now ("" = in-world narration, never cut)
## house.19: lesson channel. Cancel every queued/playing line whose group starts with prefix (only lesson pages use groups).
func cancel_group(prefix := "lesson") -> void:
	if prefix == "": return
	queue = queue.filter(func(it): return not String(it.get("group", "")).begins_with(prefix))
	if cur_group != "" and cur_group.begins_with(prefix):
		cur_group = ""
		if voice_player.playing: voice_player.stop()
		if tts_busy:
			if tts_ok: DisplayServer.tts_stop()
			tts_busy = false; _tts_serial += 1
		_next()

## a page-scoped lesson line: may be cut by cancel_group() when the player changes page
func say_group(text: String, group: String) -> void:
	var n := queue.size(); say(text)
	for i in range(n, queue.size()): queue[i]["group"] = group

func say(text: String, interrupt := true) -> void:
	if text.strip_edges() == "":
		return
	# house.17: global voice queue - a new line NEVER cuts the current one (interrupt is ignored)
	var st := _clip(norm(text))
	if st:
		queue.append({"stream": st, "what": text})
		stats.clip += 1
	elif tts_ok:
		queue.append({"tts": text, "what": text})
		stats.tts += 1
	else:
		stats.silent += 1
	if not st and not missing.has(text): missing.append(text)
	spoke.emit(text)
	_kick()

## house.26: a family member / doctor line in that character's own Piper voice ("v_<voice> <line>" clips); falls back to the narrator
func say_as(text: String, voice: String) -> void:
	var st := _clip("v_%s %s" % [voice, norm(text)]) if voice != "" else null
	if st: queue.append({"stream": st, "what": text}); stats.clip += 1; spoke.emit(text); _kick()
	else: say(text)

var _sherpa = null
var _sherpa_ok := -1   # -1 unknown, 0 failed, 1 ready
func _device_tts(text: String) -> AudioStream:
	if _sherpa_ok == 0: return null
	if _sherpa_ok == -1:
		_sherpa_ok = 0
		if not Engine.has_singleton("SherpaTts"): return null
		_sherpa = Engine.get_singleton("SherpaTts")
		var dst := "user://tts"
		var tag := "1"   # house.28: re-extract when the downloaded speech pack changes
		for p in Packs.local_manifest().get("packs", []):
			if String(p.file) == "speech.pck": tag = String(p.sha256)
		if FileAccess.get_file_as_string(dst + "/.copied") != tag:
			_copy_dir("res://tts", dst)
			var mk := FileAccess.open(dst + "/.copied", FileAccess.WRITE); if mk: mk.store_string(tag)
		if not _sherpa.init(ProjectSettings.globalize_path(dst)): return null
		_sherpa_ok = 1
	var pcm: PackedByteArray = _sherpa.generate(text)
	if pcm.size() < 100: return null
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = int(_sherpa.getSampleRate()); w.stereo = false; w.data = pcm
	return w

func _copy_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for f in DirAccess.get_files_at(src):
		var b := FileAccess.get_file_as_bytes(src + "/" + f)
		var o := FileAccess.open(dst + "/" + f, FileAccess.WRITE); if o: o.store_buffer(b)
	for d in DirAccess.get_directories_at(src): _copy_dir(src + "/" + d, dst + "/" + d)

## house.26: "My name is <Name>." in the narrator voice as ONE clip when the name is in the bundled name list, else narrator + device TTS
func say_name(name: String) -> void:
	# house.27: on-device ljspeech (sherpa-onnx Android plugin) for ANY name; bundled clips / TTS are the fallback
	var gen := _device_tts("My name is %s." % name)
	if gen: queue.append({"stream": gen, "what": "My name is " + name}); _kick(); return
	var st := _clip(norm("My name is " + name))
	if st: queue.append({"stream": st, "what": "My name is " + name}); _kick()
	else:
		say("My name is")
		if tts_ok: say_tts(name)

func letter(l: String) -> void:
	tone(500.0 + (l.to_upper().unicode_at(0) - 65) * 18.0, 0.5, 0.25)
	var st := _clip("letter " + l.to_lower())
	if st:
		queue.append({"stream": st, "what": "letter " + l.to_lower()})
	elif tts_ok:
		queue.append({"tts": l, "what": "letter " + l.to_lower()})
	_kick()

func _next() -> void:
	_end_cur()
	if queue.is_empty() or voice_player.playing or tts_busy:
		return
	var item: Dictionary = queue.pop_front()
	cur_group = String(item.get("group", ""))
	voice_log.append({"what": item.get("what", ""), "start": _now(), "end": -1.0}); _cur_log = voice_log.size() - 1
	if voice_log.size() > 200: voice_log.pop_front(); _cur_log -= 1
	if item.has("stream"):
		voice_player.stream = item.stream
		voice_player.play()
	else:
		tts_busy = true; _tts_serial += 1
		DisplayServer.tts_speak(item.tts, tts_voice, 70, 1.0, 0.95, 0, false)
		_tts_wait(_tts_serial, item.tts)

## TTS has no reliable finished callback on all platforms: wait at least an estimate, then until the engine says it stopped
func _tts_wait(serial: int, text: String) -> void:
	var t0 := _now()
	await get_tree().create_timer(0.35 + text.length() * 0.06).timeout
	while serial == _tts_serial and DisplayServer.tts_is_speaking() and _now() - t0 < 6.0:
		await get_tree().create_timer(0.05).timeout
	if serial != _tts_serial: return
	tts_busy = false
	_next()

## house.17: rooms with their own voice banks queue their clips here too (one queue for the whole game)
func say_stream(st: AudioStream, what: String) -> void:
	if st == null: return
	queue.append({"stream": st, "what": what}); stats.clip += 1; spoke.emit(what); _kick()

func is_speaking() -> bool:
	return voice_player.playing or tts_busy or not queue.is_empty()

## Simple decaying sine (SFX). Never blocks: drops frames if the buffer is full.
func tone(freq: float, dur := 0.07, amp := 0.4) -> void:
	var pb := sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	var n := mini(int(22050 * dur), pb.get_frames_available())
	for i in n:
		var t := float(i) / 22050.0
		var env := minf(1.0, t * 200.0) * (1.0 - t / dur)
		var s := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.0 * t)) * env * amp
		pb.push_frame(Vector2(s, s))

func click() -> void:
	tone(880.0, 0.06, 0.35)

func good() -> void:
	tone(1046.0, 0.15, 0.3)

func bad() -> void:
	tone(180.0, 0.25, 0.4)

# ---------------------------------------------------------------- music
func music(name: String) -> void:
	if name == current_music:
		return
	current_music = name
	var path := "res://music/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var st: AudioStreamOggVorbis = load(path)
	st.loop = true
	var old := music_a if music_a.playing else music_b
	var nw := music_b if old == music_a else music_a
	nw.stream = st
	nw.volume_db = -40
	nw.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nw, "volume_db", music_db if music_on else -80.0, 1.2)
	tw.tween_property(old, "volume_db", -80.0, 1.2)
	tw.chain().tween_callback(func(): if old != nw: old.stop())

var music_db := -14.0
func set_volumes(music_lin: float, voice_lin: float) -> void:
	music_db = linear_to_db(maxf(0.001, music_lin)) - 11.0
	music_on = music_lin > 0.01
	if voice_player:
		voice_player.volume_db = linear_to_db(maxf(0.001, voice_lin))
	for m in [music_a, music_b]:
		if m and m.playing and m.volume_db > -60:
			m.volume_db = music_db if music_on else -80.0

func set_music_on(on: bool) -> void:
	music_on = on
	for m in [music_a, music_b]:
		if m.playing and m.stream:
			m.volume_db = -14.0 if on and m.stream.resource_path.ends_with(current_music + ".ogg") else -80.0

# ---------------------------------------------------------------- microphone
# Root cause of the earlier "recording does nothing" bug: the Record bus was MUTED, and Godot skips the
# effects of a muted bus, so AudioEffectRecord never received samples. Now the bus is at -80 dB AFTER the
# effects (capture -> record), the mic stream runs continuously once opened (live level meter), and
# Android asks for RECORD_AUDIO at runtime.
var capture_effect: AudioEffectCapture
var mic_level := 0.0          # 0..1 smoothed peak
var mic_peak_seen := 0.0      # max level since mic opened
var mic_open_time := 0.0
var mic_status := "closed"    # closed | open | no_input | denied | disabled
var record_started := 0.0

func _setup_mic() -> void:
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		mic_status = "disabled"
		return
	var idx := AudioServer.get_bus_index("Record")
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Record")
	capture_effect = AudioEffectCapture.new()
	capture_effect.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, capture_effect, 0)
	record_effect = AudioEffectRecord.new()
	record_effect.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(idx, record_effect, 1)
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, -60.0)   # very quiet playback (not -inf); effects run before the fader and get the full signal
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record"
	add_child(mic_player)
	mic_ok = DisplayServer.get_name() != "headless"
	print("[MIC] enable_input=%s driver=%s mix_rate=%d" % [ProjectSettings.get_setting("audio/driver/enable_input", false), str(ProjectSettings.get_setting("audio/driver/driver", "default")), AudioServer.get_mix_rate()])
	print("[MIC] input devices: %s  current: %s" % [AudioServer.get_input_device_list(), AudioServer.input_device])

func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()

## Select the capture device (persisted by Settings). Restarts the mic stream so the new device is used.
func set_input_device(dev: String) -> void:
	var list := AudioServer.get_input_device_list()
	if list.is_empty():
		print("[MIC] WARNING: input device list is empty — Windows privacy may be blocking Godot (Settings > Privacy & security > Microphone).")
	if dev == "" or (not list.is_empty() and not (dev in list) and dev != "Default"):
		dev = "Default" if list.is_empty() or not ("Default" in list) else list[0]
		if not list.is_empty() and not ("Default" in list):
			dev = list[0]
	AudioServer.input_device = dev
	print("[MIC] input device set to: '%s' (reported: '%s')" % [dev, AudioServer.input_device])
	# Recreate the stream so WASAPI re-opens the capture device.
	if mic_player:
		var was_playing := mic_player.playing
		mic_player.stop()
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = "Record"
		if was_playing or mic_status == "open":
			mic_player.play()
			mic_open_time = Time.get_ticks_msec() / 1000.0
			mic_peak_seen = 0.0
			print("[MIC] stream recreated and restarted")

## Opens the microphone (asks for permission on Android). Returns a status string.
func open_mic() -> String:
	if mic_status == "disabled":
		return mic_status
	if OS.get_name() == "Android":
		var granted := OS.get_granted_permissions()
		if not "android.permission.RECORD_AUDIO" in granted:
			OS.request_permissions()
			OS.request_permission("android.permission.RECORD_AUDIO")
			mic_status = "denied"
			return mic_status   # user answers the system dialog; next tap tries again
	if not mic_ok or mic_player == null:
		mic_status = "no_input"
		return mic_status
	if not mic_player.playing:
		mic_player.play()
		print("[MIC] stream started on device '%s'" % AudioServer.input_device)
		mic_open_time = Time.get_ticks_msec() / 1000.0
		mic_peak_seen = 0.0
	mic_status = "open"
	return mic_status

func close_mic() -> void:
	if mic_player and mic_player.playing and not (record_effect and record_effect.is_recording_active()):
		mic_player.stop()
	mic_status = "closed"

const SILENCE_TIMEOUT := 4.0
## True when the mic has been open > 4 s and never delivered sound (no device / blocked by OS privacy / wrong device).
func mic_silent() -> bool:
	return mic_status == "open" and Time.get_ticks_msec() / 1000.0 - mic_open_time > SILENCE_TIMEOUT and mic_peak_seen < 0.002

var _log_t := 0.0

## v32 polish (blue): music ducks 8 dB under any spoken line (narrator / NPC voices) and comes back smoothly
const DUCK_DB := -8.0
var duck_db := 0.0
func _duck(d: float) -> void:
	var bi := AudioServer.get_bus_index("Music")
	if bi < 0: return
	var talking := voice_player != null and voice_player.playing
	duck_db = move_toward(duck_db, DUCK_DB if talking else 0.0, d * (40.0 if talking else 10.0))   # fast down (0.2 s), slow up (0.8 s)
	AudioServer.set_bus_volume_db(bi, duck_db)

func _process(_d: float) -> void:
	_duck(_d)
	if capture_effect == null or mic_player == null or not mic_player.playing:
		mic_level = lerpf(mic_level, 0.0, 0.2)
		return
	var n := capture_effect.get_frames_available()
	if n <= 0:
		mic_level = lerpf(mic_level, 0.0, 0.1)
		var t0 := Time.get_ticks_msec() / 1000.0
		if t0 - _log_t > 2.0:
			_log_t = t0
			print("[MIC] device='%s' no frames from capture yet (stream playing=%s)" % [AudioServer.input_device, mic_player.playing])
		return
	var buf := capture_effect.get_buffer(n)
	var pk := 0.0
	for f in buf:
		pk = maxf(pk, maxf(absf(f.x), absf(f.y)))
	mic_peak_seen = maxf(mic_peak_seen, pk)
	mic_level = maxf(pk, lerpf(mic_level, pk, 0.3))
	var now := Time.get_ticks_msec() / 1000.0
	if now - _log_t > 1.0:
		_log_t = now
		print("[MIC] device='%s' frames=%d peak=%.4f max_since_open=%.4f" % [AudioServer.input_device, n, pk, mic_peak_seen])

func start_record() -> bool:
	if open_mic() != "open" or record_effect == null:
		return false
	record_effect.set_recording_active(true)
	record_started = Time.get_ticks_msec() / 1000.0
	return true

func stop_record() -> AudioStreamWAV:
	if record_effect == null or not record_effect.is_recording_active():
		return null
	record_effect.set_recording_active(false)
	return record_effect.get_recording()

func play_stream(st: AudioStream) -> void:
	queue.clear()
	voice_player.stream = st
	voice_player.play()

## RMS envelope (20 ms frames, 0..255) of a 16-bit recording.
static func wav_envelope(w: AudioStreamWAV) -> PackedByteArray:
	var out := PackedByteArray()
	if w == null or w.format != AudioStreamWAV.FORMAT_16_BITS:
		return out
	var ch := 2 if w.stereo else 1
	var data := w.data
	var hop := int(w.mix_rate * 0.02) * ch * 2
	var i := 0
	while i + hop <= data.size():
		var acc := 0.0
		var n := 0
		var j := i
		while j < i + hop:
			var v := data.decode_s16(j) / 32768.0
			acc += v * v
			n += 1
			j += 2 * ch
		out.append(mini(255, int(sqrt(acc / maxf(1, n)) * 1200.0)))
		i += hop
	return out

## Similarity 0..100 of two loudness envelopes (trimmed silence, DTW). This compares rhythm/length/stress,
## NOT the actual words: it is not speech recognition.
static func compare_envelopes(a: PackedByteArray, b: PackedByteArray) -> int:
	var ta := _trim(a); var tb := _trim(b)
	if ta.size() < 3 or tb.size() < 3:
		return 0
	var n := ta.size(); var m := tb.size()
	var ma := 1.0; var mb := 1.0
	for v in ta: ma = maxf(ma, v)
	for v in tb: mb = maxf(mb, v)
	var prev := PackedFloat32Array(); prev.resize(m + 1); prev.fill(1e9); prev[0] = 0
	for i in range(1, n + 1):
		var cur := PackedFloat32Array(); cur.resize(m + 1); cur.fill(1e9)
		for j in range(1, m + 1):
			var d := absf(ta[i - 1] / ma - tb[j - 1] / mb)
			cur[j] = d + minf(prev[j], minf(cur[j - 1], prev[j - 1]))
		prev = cur
	var dist: float = prev[m] / float(n + m)
	var len_ratio := float(mini(n, m)) / float(maxi(n, m))
	return clampi(int((1.0 - dist * 2.5) * 70.0 + len_ratio * 30.0), 0, 100)

static func _trim(e: PackedByteArray) -> PackedByteArray:
	var s := 0; var t := e.size() - 1
	while s < e.size() and e[s] < 12: s += 1
	while t > s and e[t] < 12: t -= 1
	return e.slice(s, t + 1) if t >= s else PackedByteArray()

# ---------------------------------------------------------------- sound effects (Kenney CC0 + generated)
var _sfx_pool: Array = []
var _sfx_cache := {}
var sfx_log: Array = []
## v30.2 playtest: every water sound (tap, shower, watering, splash, flush, trickle) at 50 % volume (-6 dB)
const WATER_SFX := ["water", "water_drops", "trickle", "shower_loop"]
const WATER_DB := -6.0
## v32 (Yasin 13:49): tap / sink water at 20 % of its previous volume (-14 dB on top of WATER_DB)
const TAP_DB := -14.0
func tap_sfx(db := 0.0, pitch := 1.0) -> void:
	sfx("water", db + TAP_DB, pitch)
func sfx(name: String, db := 0.0, pitch := 1.0) -> void:
	sfx_log.append(name)
	if not _sfx_cache.has(name):
		var path := "res://sfx/%s.ogg" % name
		_sfx_cache[name] = load(path) if ResourceLoader.exists(path) else null
	if _sfx_cache[name] == null: return
	if _sfx_pool.is_empty():
		for i in 8:
			var pl := AudioStreamPlayer.new(); add_child(pl); _sfx_pool.append(pl)
	var pl: AudioStreamPlayer = _sfx_pool.pop_front(); _sfx_pool.append(pl)
	pl.stream = _sfx_cache[name]; pl.volume_db = db + (WATER_DB if name in WATER_SFX else 0.0); pl.pitch_scale = pitch; pl.play()

## house.28: (re)open voice banks; called again after downloaded packs are mounted.
func reopen_banks() -> void:
	voice_files.clear()
	# v31: gap-tolerant (a missing chunk number no longer hides the later ones; _clip() skips null chunks)
	var last := -1
	for ci in 32: if FileAccess.file_exists("res://voice/voice_%03d.bin" % ci): last = ci
	for ci in last + 1:
		voice_files.append(FileAccess.open("res://voice/voice_%03d.bin" % ci, FileAccess.READ) if FileAccess.file_exists("res://voice/voice_%03d.bin" % ci) else null)
	set_narrator(narrator)   # v30: narrator banks (narrator.pck) are mounted with the other packs -> reopen them too
