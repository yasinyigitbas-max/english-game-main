## house.25: story overlay - caption (EN + TR) at the bottom, one narrator line at a time over Audio's queue (never cut off)
class_name StoryUI
extends CanvasLayer

const TR := {
	"How are your legs?": "Bacakların nasıl?", "How are your arms?": "Kolların nasıl?", "My arm hurts a little.": "Kolum biraz acıyor.", "How is your chest?": "Göğsün nasıl?", "How are your ears?": "Kulakların nasıl?", "How are your eyes?": "Gözlerin nasıl?", "Good. You are fine. You can go home.": "Güzel. İyisin. Eve gidebilirsin.",   # v28 body check
	"Wow, such a nice day!": "Vay, ne güzel bir gün!", "Look! A cat is sitting on the road.": "Bak! Yolda bir kedi oturuyor.", "Go away, kitty! Move!": "Git buradan, pisi! Kaç!", "I am running to the cat!": "Kediye doğru koşuyorum!",
	"Look! A cat is on the road.": "Bak! Yolda bir kedi var.", "Oh no! A bus is coming!": "Olamaz! Bir otobüs geliyor!",
	"Where am I?": "Neredeyim?", "Can you hear me?": "Beni duyabiliyor musun?", "Yes, I can.": "Evet, duyabiliyorum.",
	"Can you see the flashlight?": "El fenerini görebiliyor musun?", "Yes, I can see it.": "Evet, görebiliyorum.",
	"Don't worry. He is completely fine.": "Merak etmeyin. O tamamen iyi.", "Don't worry. She is completely fine.": "Merak etmeyin. O tamamen iyi.",
	"The bus driver braked on time.": "Otobüs şoförü zamanında fren yaptı.", "The cat is fine, too.": "Kedi de iyi.",
	"Thank you, doctor!": "Teşekkürler, doktor!", "Can you get up?": "Kalkabilir misin?", "You should rest for one full day.": "Bir gün boyunca dinlenmelisin.",
	"Let's go home.": "Hadi eve gidelim.", "I am at home now.": "Şimdi evdeyim.", "Let's review the lessons.": "Hadi dersleri tekrar edelim.",
	"Now the big test. Ten questions.": "Şimdi büyük test. On soru.", "I am tired. I should rest.": "Yorgunum. Dinlenmeliyim.",
	"I am dreaming about yesterday.": "Dünü rüyamda görüyorum.", "I had breakfast.": "Kahvaltı yaptım.", "I had an accident.": "Bir kaza geçirdim.",
	"I was at the hospital.": "Hastanedeydim.", "I went home.": "Eve gittim.", "I was fine in the end.": "Sonunda iyiydim.",
	"This is the past simple. Have becomes had. Go becomes went. Am and is become was.": "Bu geçmiş zaman. have -> had, go -> went, am / is -> was.",
	"It is a new day.": "Yeni bir gün.", "My phone is ringing.": "Telefonum çalıyor.", "Hello! What happened yesterday?": "Merhaba! Dün ne oldu?",
	"Put the words in the right order.": "Kelimeleri doğru sıraya koy.", "Oh no! I am happy you are fine. See you soon.": "Olamaz! İyi olduğuna sevindim. Görüşürüz.",
	"Coming soon.": "Yakında.", "My phone battery is low. I should charge it.": "Telefonumun şarjı az. Şarj etmeliyim.",
	"Skip the review": "Tekrarı atla", "Get a notebook and a pencil. Let's take notes.": "Bir defter ve kalem al. Hadi not alalım.",
}
var panel: PanelContainer; var en_l: Label; var tr_l: Label; var tr_btn: Button

## v32-polish UNIVERSAL CAPTION RULE: ONE bottom-centre caption box on screen at a time, ONE standard look (the breakfast /
## shared-HUD box: dark 0.08/0.10/0.16 @ 0.72, radius 22, EN 30 bold white, TR 22 light blue, TR button INSIDE the box).
## Every caption box joins group "caption_box"; showing one (claim) hides every other one, so the narrator caption and the
## player-action caption behave as one queue (the newest line replaces the old one in the same place).
const CAP_GROUP := "caption_box"
static func claim(box: CanvasItem) -> void:
	if box == null or not box.is_inside_tree(): return
	if not box.is_in_group(CAP_GROUP): box.add_to_group(CAP_GROUP)
	for o in box.get_tree().get_nodes_in_group(CAP_GROUP):
		if o != box and o is CanvasItem and (o as CanvasItem).visible: (o as CanvasItem).visible = false
static func hide_all(tree: SceneTree) -> void:
	for o in tree.get_nodes_in_group(CAP_GROUP): if o is CanvasItem: (o as CanvasItem).visible = false
## standard style for any bottom caption PanelContainer (used here, by hospital_day2 / boss call, and documented for blue)
static func style_box(p: PanelContainer) -> void:
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.10, 0.16, 0.72); sb.set_corner_radius_all(22); sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
static func style_tr_btn(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.31, 0.42, 0.93) if on else Color(1, 1, 1, 0.94); sb.set_corner_radius_all(18); sb.set_content_margin_all(10)
	for k in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(k, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color(1, 1, 1) if on else Color(0.13, 0.16, 0.24))

func _ready() -> void:
	layer = 40
	panel = PanelContainer.new(); panel.name = "StoryCaption"; style_box(panel); panel.add_to_group(CAP_GROUP)
	panel.anchor_left = 0.5; panel.anchor_right = 0.5; panel.anchor_top = 1; panel.anchor_bottom = 1
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -440; panel.offset_right = 440; panel.offset_top = -40; panel.offset_bottom = -24; add_child(panel)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 16); panel.add_child(h)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	en_l = Label.new(); en_l.add_theme_font_size_override("font_size", 30); en_l.add_theme_color_override("font_color", Color(1, 1, 1))
	if UI.get("font_b"): en_l.add_theme_font_override("font", UI.font_b)
	en_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(en_l)
	tr_l = Label.new(); tr_l.add_theme_font_size_override("font_size", 22); tr_l.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0)); tr_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tr_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tr_l)
	tr_btn = Button.new(); tr_btn.name = "Translate"; tr_btn.text = "TR"; tr_btn.focus_mode = Control.FOCUS_NONE; tr_btn.custom_minimum_size = Vector2(76, 56)
	tr_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tr_btn.add_theme_font_size_override("font_size", 22)
	if UI.get("font_b"): tr_btn.add_theme_font_override("font", UI.font_b)
	tr_btn.pressed.connect(_toggle_tr); h.add_child(tr_btn)
	panel.visible = false
	panel.visibility_changed.connect(func(): if panel.visible: claim(panel))
	_sync_tr()

## TR button inside the box: the one persisted flag; the host scene (hospital toggle_tr, room S.tr / _refresh_text) follows
func _toggle_tr() -> void:
	Audio.click()
	var on := not App.tr_on()
	var sc := get_parent()
	if sc and sc.has_method("toggle_tr"): sc.call("toggle_tr", on)
	else:
		App.save_tr(on)
		if sc and sc.get("S") is Dictionary: sc.S["tr"] = on
		if sc and sc.has_method("_refresh_text"): sc.call("_refresh_text")
	_sync_tr()
func _sync_tr() -> void:
	if tr_btn: style_tr_btn(tr_btn, App.tr_on())
	if tr_l: tr_l.visible = App.tr_on() and tr_l.text != ""
func _process(_dt: float) -> void:
	if panel and panel.visible:
		var on := App.tr_on()
		if tr_l.visible != (on and tr_l.text != ""): tr_l.visible = on and tr_l.text != ""
		if not tr_btn.has_meta("on") or tr_btn.get_meta("on") != on: tr_btn.set_meta("on", on); style_tr_btn(tr_btn, on)

static func tr_of(en: String) -> String:
	if TR.has(en): return TR[en]
	var d = App.load_json("res://data/extra_lines.json")
	return String(d.get(en, "")) if d is Dictionary else ""

## show + speak; waits until it has been fully spoken (who = speaker prefix, caption only)
func line(en: String, who := "", pause := 0.7, voice := "") -> void:
	await Audio.wait_idle(15.0)
	en_l.text = (who + ": " if who != "" else "") + en; tr_l.text = tr_of(en); _sync_tr(); panel.visible = true; claim(panel)
	if voice != "": Audio.say_as(en, voice)
	else: Audio.say(en)
	await get_tree().create_timer(0.2).timeout
	await Audio.wait_idle(15.0)
	await get_tree().create_timer(pause).timeout

func hide_caption() -> void: panel.visible = false
## v32-polish SCRAMBLE RULE: show a line being built (silent, no wait) in the same standard box; line() then reuses it
func live(en: String, tr_text := "") -> void:
	en_l.text = en; tr_l.text = tr_text; _sync_tr(); panel.visible = en != ""; claim(panel)




## v33 (Yasin 16:37) STANDARD SCRAMBLE PANEL for every word-order puzzle (boss / teacher phone call, day-2 / day-3 couch
## talk): one compact white card sized to its content (no empty white area, no scrolling), sitting low at the bottom-centre
## just ABOVE the caption-box zone, so the ONE bottom-centre caption box (the sentence being built / the completed sentence,
## TR inside) is never covered and the chips never sit under it. Big word chips (64 px) fill the card in centred rows.
## Returns {box, row, askt, buttons} - buttons in pool order; the caller wires the taps (puzzle logic unchanged).
const SCR_CAP_RESERVE := 170.0   # px kept free above the bottom edge for the caption box (1-2 lines + TR)
static func scramble_panel(parent: Node, box_name: String, pool: Array, ask_en := "Put the words in the right order.", ask_tr := "Kelimeleri doğru sıraya koy.") -> Dictionary:
	var box := PanelContainer.new(); box.name = box_name
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(1, 1, 1, 0.96); sb.set_corner_radius_all(20); sb.set_content_margin_all(16); box.add_theme_stylebox_override("panel", sb)
	box.anchor_left = 0.5; box.anchor_right = 0.5; box.anchor_top = 1.0; box.anchor_bottom = 1.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH; box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -500; box.offset_right = 500; box.offset_bottom = -SCR_CAP_RESERVE; box.offset_top = -SCR_CAP_RESERVE
	parent.add_child(box)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); box.add_child(v)
	var ask := Label.new(); ask.name = "Ask"; ask.text = ask_en; ask.add_theme_font_size_override("font_size", 22); ask.add_theme_color_override("font_color", Color(0.4, 0.45, 0.6))
	ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ask)
	var askt := Label.new(); askt.name = "AskTR"; askt.text = ask_tr; askt.add_theme_font_size_override("font_size", 16); askt.add_theme_color_override("font_color", Color(0.35, 0.5, 0.8))
	askt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; askt.visible = ask_tr != ""   # v33.1 (Yasin 17:41): Turkish on learning screens ALWAYS shows; the TR button only controls the caption box; v.add_child(askt)
	var row := HFlowContainer.new(); row.name = "Words"; row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 12); row.add_theme_constant_override("v_separation", 12); v.add_child(row)
	var btns: Array = []
	for wd in pool:
		var b := Button.new(); b.text = String(wd); b.custom_minimum_size = Vector2(96, 64); b.add_theme_font_size_override("font_size", 30); b.focus_mode = Control.FOCUS_NONE
		var ui := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("UI")
		if ui and ui.get("font_b"): b.add_theme_font_override("font", ui.get("font_b"))
		row.add_child(b); btns.append(b)
	# no doubled line: the instruction now on the card leaves the caption box (it was just said there)
	for o in parent.get_tree().get_nodes_in_group(CAP_GROUP):
		if o is CanvasItem and (o as CanvasItem).visible:
			var l0 := (o as Node).find_children("*", "Label", true, false)
			if not l0.is_empty() and (l0[0] as Label).text.strip_edges() == ask_en: (o as CanvasItem).visible = false
	return {"box": box, "row": row, "askt": askt, "buttons": btns}


static func add_skip_button(test_page: Control, on_skip: Callable) -> Button:
	var row: = HBoxContainer.new();row.name = "SkipRow";row.alignment = BoxContainer.ALIGNMENT_END;row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b: = Button.new();b.name = "SkipTest";b.text = "Testi geç" if App.tr_on() else "Skip test"
	b.custom_minimum_size = Vector2(170, 56);b.add_theme_font_size_override("font_size", 20);b.focus_mode = Control.FOCUS_NONE
	var sb: = StyleBoxFlat.new();sb.bg_color = Color(0.93, 0.52, 0.44);sb.set_corner_radius_all(14);sb.set_content_margin_all(8)
	for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE);b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect( func(): b.disabled = true;Audio.click();Audio.cancel_group("lesson");on_skip.call())
	if test_page.has_meta("dock_r") and is_instance_valid(test_page.get_meta("dock_r")):   # v33 test page: bottom-right corner of the dock
		b.custom_minimum_size = Vector2(150, 64); (test_page.get_meta("dock_r") as Control).add_child(b); row.queue_free(); return b
	row.add_child(b);test_page.add_child(row)
	return b


static func mark_skipped(key: String) -> void :
	var d = App.load_save().get("tests_skipped", {})
	if not d is Dictionary: d = {}
	d = d.duplicate();d[key] = true;App.patch_save({"tests_skipped": d})
