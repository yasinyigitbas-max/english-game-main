extends Control
## house.28 first-start downloader: "Downloading lessons…" with progress, SHA-256 check, retry, mobile-data prompt.
const NEXT := "res://menu.tscn"
var http: HTTPRequest
var bar: ProgressBar
var label: Label
var sub: Label
var btns: HBoxContainer
var remote := {}
var queue: Array = []
var cur := {}
var done_bytes := 0
var total_bytes := 0

func _ready() -> void:
	if Packs.bundled():
		_go.call_deferred(); return
	var bg := ColorRect.new(); bg.color = Color(0.11, 0.15, 0.22); bg.set_anchors_preset(PRESET_FULL_RECT); add_child(bg)
	var v := VBoxContainer.new(); v.set_anchors_preset(PRESET_CENTER); v.custom_minimum_size = Vector2(760, 0)
	v.position = Vector2(-380, -110); v.add_theme_constant_override("separation", 18); add_child(v)
	label = Label.new(); label.text = "Downloading lessons… (Dersler indiriliyor…)"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 34); v.add_child(label)
	bar = ProgressBar.new(); bar.custom_minimum_size = Vector2(760, 40); bar.max_value = 1.0; v.add_child(bar)
	sub = Label.new(); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sub.add_theme_font_size_override("font_size", 24)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(sub)
	btns = HBoxContainer.new(); btns.alignment = BoxContainer.ALIGNMENT_CENTER; btns.add_theme_constant_override("separation", 24); v.add_child(btns)
	http = HTTPRequest.new(); http.timeout = 30.0; http.use_threads = true; add_child(http)
	http.request_completed.connect(_on_done)
	_fetch_manifest()

func _status(t: String) -> void: sub.text = t

func _buttons(list: Array) -> void:
	for c in btns.get_children(): c.queue_free()
	for b in list:
		var x := Button.new(); x.text = b[0]; x.custom_minimum_size = Vector2(300, 72)
		x.add_theme_font_size_override("font_size", 26); x.pressed.connect(b[1]); btns.add_child(x)

func _fetch_manifest() -> void:
	_buttons([]); _status("Checking for lessons… (Kontrol ediliyor…)")
	cur = {}
	http.download_file = ""
	if http.request(Packs.MANIFEST_URL) != OK: _offline()

func _offline() -> void:
	if Packs.mount_local() and Packs.all_ready():
		Packs.refresh_autoloads(); _go(); return
	_status("No internet connection. Connect to the internet and try again.\n(İnternet bağlantısı yok. Bağlanıp tekrar deneyin.)")
	_buttons([["Try again (Tekrar dene)", _fetch_manifest]])
	get_tree().create_timer(6.0).timeout.connect(func(): if is_instance_valid(self) and cur.is_empty() and btns.get_child_count(): _fetch_manifest())

func _on_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if cur.is_empty():   # manifest
		if result != HTTPRequest.RESULT_SUCCESS or code != 200: _offline(); return
		var d = JSON.parse_string(body.get_string_from_utf8())
		if not (d is Dictionary) or not d.has("packs"): _offline(); return
		remote = d; _plan(); return
	var part := Packs.DIR + "/" + Packs.local_name(cur) + ".part"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(part); _retry_pack(); return
	if FileAccess.get_sha256(part) != String(cur.sha256).to_lower():
		DirAccess.remove_absolute(part); _retry_pack(); return
	var dst := Packs.DIR + "/" + Packs.local_name(cur)   # new file name per version, never over a mounted pack
	DirAccess.rename_absolute(part, dst)
	done_bytes += int(cur.size); cur = {}
	_next_pack()

func _retry_pack() -> void:
	_status("Download failed. Retrying… (İndirme başarısız. Tekrar deneniyor…)")
	_buttons([["Try again (Tekrar dene)", func(): _buttons([]); _start(cur)]])
	var c := cur
	get_tree().create_timer(5.0).timeout.connect(func(): if is_instance_valid(self) and cur == c and btns.get_child_count(): _buttons([]); _start(c))

## Only changed or missing packs are downloaded (SHA-256 compared to the remote manifest).
func _plan() -> void:
	queue.clear(); total_bytes = 0; done_bytes = 0
	var local := {}
	for p in Packs.local_manifest().get("packs", []): local[p.file] = p
	for p in remote.packs:
		var path := Packs.DIR + "/" + Packs.local_name(p)
		if FileAccess.file_exists(path) and FileAccess.open(path, FileAccess.READ).get_length() == int(p.size): continue
		queue.append(p); total_bytes += int(p.size)
	if queue.is_empty(): _finish(); return
	var mb := "%.0f MB" % (total_bytes / 1048576.0)
	if Packs.is_metered():
		_status("You are on mobile data. Download %s now?\n(Mobil veri kullanıyorsunuz. %s indirilsin mi?)" % [mb, mb])
		_buttons([["Download (İndir)", _next_pack], ["Wait for Wi-Fi (Wi-Fi bekle)", _wait_wifi]])
	else:
		_next_pack()

func _wait_wifi() -> void:
	_status("Waiting for Wi-Fi… (Wi-Fi bekleniyor…)")
	_buttons([["Download now (Şimdi indir)", _next_pack]])
	_poll_wifi()

func _poll_wifi() -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(self) or not cur.is_empty() or btns.get_child_count() == 0: return
	if not Packs.is_metered(): _buttons([]); _next_pack()
	else: _poll_wifi()

func _next_pack() -> void:
	_buttons([])
	if queue.is_empty(): _finish(); return
	_start(queue.pop_front())

func _start(p: Dictionary) -> void:
	cur = p
	_status("%s (%.0f MB)" % [String(p.file), int(p.size) / 1048576.0])
	http.download_file = Packs.DIR + "/" + Packs.local_name(p) + ".part"
	if http.request(String(p.url)) != OK: _retry_pack()

func _process(_dt: float) -> void:
	if bar and not cur.is_empty() and total_bytes > 0:
		bar.value = float(done_bytes + http.get_downloaded_bytes()) / float(total_bytes)

func _finish() -> void:
	bar.value = 1.0
	var f := FileAccess.open(Packs.DIR + "/manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(remote)); f = null
	if not Packs.mount_local() or not Packs.all_ready():
		_status("Could not open the lesson files. (Ders dosyaları açılamadı.)")
		_buttons([["Try again (Tekrar dene)", _fetch_manifest]]); return
	Packs.refresh_autoloads(); _go()

func _go() -> void:
	if "--qa-packs" in OS.get_cmdline_user_args(): _qa_verify(); return
	get_tree().change_scene_to_file(NEXT)

## QA only: every sampled voice key must read exactly the expected bytes through the mounted packs
func _qa_verify() -> void:
	var exp = JSON.parse_string(FileAccess.get_file_as_string("res://tools/expected_md5.json"))
	var bad := 0
	for k in exp:
		var e: Array = Audio.index[k]; var vf: FileAccess = Audio.voice_files[int(e[0])]
		var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_MD5); vf.seek(int(e[1])); ctx.update(vf.get_buffer(int(e[2])))
		if ctx.finish().hex_encode() != exp[k]: bad += 1; print("QAPACK BAD ", k)
	var st := Audio._clip("i am picking up my phone")
	print("QAPACK mounted=", Packs.mounted.keys(), " files=", DirAccess.get_files_at(Packs.DIR), " checked=", exp.size(), " bad=", bad, " sample_len=", st.get_length() if st else -1.0)
	get_tree().quit()
