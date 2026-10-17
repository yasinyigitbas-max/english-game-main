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
var panel: PanelContainer; var en_l: Label; var tr_l: Label

func _ready() -> void:
	layer = 40
	panel = PanelContainer.new();panel.name = "StoryCaption"; var sb: = StyleBoxFlat.new();sb.bg_color = Color(0.1, 0.12, 0.18, 0.82);sb.set_corner_radius_all(18);sb.set_content_margin_all(14);panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5; panel.anchor_right = 0.5; panel.anchor_top = 1; panel.anchor_bottom = 1
	panel.offset_left = -430; panel.offset_right = 430; panel.offset_top = -120; panel.offset_bottom = -20; add_child(panel)
	var v := VBoxContainer.new(); panel.add_child(v)
	en_l = Label.new(); en_l.add_theme_font_size_override("font_size", 26); en_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; en_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(en_l)
	tr_l = Label.new(); tr_l.add_theme_font_size_override("font_size", 18); tr_l.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0)); tr_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tr_l)
	panel.visible = false

static func tr_of(en: String) -> String:
	if TR.has(en): return TR[en]
	var d = App.load_json("res://data/extra_lines.json")
	return String(d.get(en, "")) if d is Dictionary else ""

## show + speak; waits until it has been fully spoken (who = speaker prefix, caption only)
func line(en: String, who := "", pause := 0.7, voice := "") -> void:
	await Audio.wait_idle(15.0)
	en_l.text = (who + ": " if who != "" else "") + en; tr_l.text = tr_of(en); panel.visible = true
	if voice != "": Audio.say_as(en, voice)
	else: Audio.say(en)
	await get_tree().create_timer(0.2).timeout
	await Audio.wait_idle(15.0)
	await get_tree().create_timer(pause).timeout

func hide_caption() -> void: panel.visible = false




static func add_skip_button(test_page: Control, on_skip: Callable) -> Button:
	var row: = HBoxContainer.new();row.name = "SkipRow";row.alignment = BoxContainer.ALIGNMENT_END;row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b: = Button.new();b.name = "SkipTest";b.text = "Testi geç" if App.tr_on() else "Skip test"
	b.custom_minimum_size = Vector2(170, 56);b.add_theme_font_size_override("font_size", 20);b.focus_mode = Control.FOCUS_NONE
	var sb: = StyleBoxFlat.new();sb.bg_color = Color(0.93, 0.52, 0.44);sb.set_corner_radius_all(14);sb.set_content_margin_all(8)
	for st in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE);b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect( func(): b.disabled = true;Audio.click();Audio.cancel_group("lesson");on_skip.call())
	row.add_child(b);test_page.add_child(row)
	return b


static func mark_skipped(key: String) -> void :
	var d = App.load_save().get("tests_skipped", {})
	if not d is Dictionary: d = {}
	d = d.duplicate();d[key] = true;App.patch_save({"tests_skipped": d})
