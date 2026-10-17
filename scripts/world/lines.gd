## All outdoor English lines (A1, present continuous) with Turkish translations (shown with the TR button).
## tools/build_voice.py renders an English Piper clip for every key into voice/ (no Turkish voice).
class_name Lines
extends RefCounted

const TR := {
	"Wow, such a nice day!": "Vay, ne güzel bir gün!", "Look! A cat is sitting on the road.": "Bak! Yolda bir kedi oturuyor.", "Go away, kitty! Move!": "Git buradan, pisi! Kaç!", "I am running to the cat!": "Kediye doğru koşuyorum!",
	"Look! A cat is on the road.": "Bak! Yolda bir kedi var.", "Oh no! A bus is coming!": "Olamaz! Bir otobüs geliyor!",
	"My phone battery is low. I should charge it.": "Telefonumun şarjı az. Şarj etmeliyim.",
	"I'm outside now.": "Şimdi dışarıdayım.",
	"I am getting in my car.": "Arabama biniyorum.", "I am driving to school.": "Okula arabayla gidiyorum.",
	"I am driving to work.": "İşe arabayla gidiyorum.", "I am driving to the mall.": "Alışveriş merkezine arabayla gidiyorum.",
	"I am driving to the hospital.": "Hastaneye arabayla gidiyorum.", "Coming soon.": "Çok yakında.",
	"Go to school": "Okula git", "Go to work": "İşe git", "Go shopping": "Alışverişe git", "Go to the mall": "Alışveriş merkezine git", "Go to the hospital": "Hastaneye git",
	"Be careful! A car is coming.": "Dikkat et! Bir araba geliyor.",
	"Hi! I am looking at the apples.": "Selam! Elmalara bakıyorum.", "Hello! I am waiting for my friend.": "Merhaba! Arkadaşımı bekliyorum.",
	"Good morning! I am eating a sandwich.": "Günaydın! Sandviç yiyorum.", "Hi! I am talking to my friend.": "Selam! Arkadaşımla konuşuyorum.",
	"Hello! I am going home.": "Merhaba! Eve gidiyorum.", "Hi! I am going to school.": "Selam! Okula gidiyorum.",
	"Walk to the street.": "Sokağa yürü.", "I am looking at my phone.": "Telefonuma bakıyorum.",
	"Maple Street": "Akçaağaç Sokağı", "City Park": "Şehir Parkı", "Oak Avenue": "Meşe Caddesi", "Birch Road": "Huş Yolu",
	"Park Road": "Park Yolu", "Market Square": "Çarşı Meydanı", "Living room": "Oturma odası", "Bedroom": "Yatak odası", "Bathroom": "Banyo",
	"I am outside. Let's walk to the street.": "Dışarıdayım. Hadi sokağa yürüyelim.",
	"I am walking.": "Yürüyorum.", "I am running.": "Koşuyorum.",
	"I am going inside.": "İçeri giriyorum.", "I am going outside.": "Dışarı çıkıyorum.", "I am at home.": "Evdeyim.", "Go to the front door.": "Ön kapıya git.",
	"I am knocking on the door.": "Kapıyı çalıyorum.", "Nobody is at home.": "Evde kimse yok.",
	"I am opening the mailbox.": "Posta kutusunu açıyorum.", "I am checking the mail.": "Postaları kontrol ediyorum.",
	"I have a letter!": "Bir mektubum var!", "I am closing the mailbox.": "Posta kutusunu kapatıyorum.",
	"I am sitting on the bench.": "Bankta oturuyorum.", "I am standing up.": "Ayağa kalkıyorum.",
	"I am opening the bin.": "Çöp kutusunu açıyorum.", "I am throwing away the rubbish.": "Çöpü atıyorum.",
	"I am closing the bin.": "Çöp kutusunu kapatıyorum.",
	"I am looking at the streetlight.": "Sokak lambasına bakıyorum.",
	"It is night. The streetlights are on.": "Gece oldu. Sokak lambaları yanıyor.",
	"It is morning. The streetlights are off.": "Sabah oldu. Sokak lambaları söndü.",
	"I am opening the shop door.": "Dükkânın kapısını açıyorum.", "I am closing the shop door.": "Dükkânın kapısını kapatıyorum.",
	"I am buying an apple.": "Bir elma alıyorum.", "I am buying some bread.": "Biraz ekmek alıyorum.",
	"I am buying some milk.": "Biraz süt alıyorum.", "I am buying some water.": "Biraz su alıyorum.",
	"I am buying some eggs.": "Biraz yumurta alıyorum.", "I do not have enough money.": "Yeterli param yok.",
	"I am reading the menu.": "Menüyü okuyorum.", "Coffee is two pounds fifty.": "Kahve iki pound elli peni.", 
	"I am ordering a coffee.": "Bir kahve sipariş ediyorum.",
	"I am opening the gate.": "Bahçe kapısını açıyorum.", "I am closing the gate.": "Bahçe kapısını kapatıyorum.",
	"I am unlocking my car.": "Arabamın kilidini açıyorum.", "I am locking my car.": "Arabamı kilitliyorum.",
	"I am opening the car door.": "Arabanın kapısını açıyorum.", "I am closing the car door.": "Arabanın kapısını kapatıyorum.",
	"I am turning on the tap.": "Musluğu açıyorum.", "I am watering the flowers.": "Çiçekleri suluyorum.",
	"I am turning off the tap.": "Musluğu kapatıyorum.",
	"I am pressing the button.": "Düğmeye basıyorum.", "I am waiting for the green man.": "Yeşil ışığı bekliyorum.",
	"I am crossing the street.": "Karşıya geçiyorum.",
	"I am reading the timetable.": "Saat çizelgesini okuyorum.",
	"I am getting on the bus.": "Otobüse biniyorum.", "I am paying the fare.": "Bilet ücretini ödüyorum.",
	"I am getting off the bus.": "Otobüsten iniyorum.", "I am waiting for the bus.": "Otobüsü bekliyorum.",
	"I am saying hello.": "Merhaba diyorum.",
	"Hello! I am waiting for the bus.": "Merhaba! Otobüsü bekliyorum.",
	"Hi! I am reading a book.": "Selam! Kitap okuyorum.",
	"Good morning! I am selling fruit.": "Günaydın! Meyve satıyorum.",
	"Hello! I am drinking coffee.": "Merhaba! Kahve içiyorum.",
	"Hi! I am walking to the park.": "Selam! Parka yürüyorum.",
	"Hello! I am going to the shop.": "Merhaba! Dükkâna gidiyorum.",
	"Good morning! I am walking my dog.": "Günaydın! Köpeğimi gezdiriyorum.",
	"Hi! I am going to work.": "Selam! İşe gidiyorum.",
	"The car is stopping.": "Araba duruyor.",
}

## translation with patterns for lines that contain numbers / names
static func tr_of(en: String) -> String:
	if TR.has(en): return TR[en]
	if en.begins_with("The next bus is at "): return "Bir sonraki otobüs saati: %s." % en.trim_prefix("The next bus is at ").trim_suffix(".")
	if en.begins_with("I am driving ") and en.ends_with("."):   # "I am driving %s." (subject dropped in Turkish)
		var to := en.trim_prefix("I am driving ").trim_suffix(".")
		var dst := {"to school": "Okula", "to work": "İşe", "to the mall": "Alışveriş merkezine", "to the hospital": "Hastaneye", "to the shop": "Dükkana", "home": "Eve"}
		return "%s arabayla gidiyorum." % dst.get(to, to.trim_prefix("to ").capitalize())
	if en.begins_with("This is "): return "Burası %s." % en.trim_prefix("This is ").trim_suffix(".")
	return ""

## v28 blue: in-world signs that swap their text with the HUD TR toggle (ui/shared/hud.gd set_tr calls Lines.apply_signs)
static func set_sign(lbl: Label3D, en: String, tr: String) -> void:
	lbl.text = en; lbl.set_meta("en", en); lbl.set_meta("tr", tr); lbl.add_to_group("tr_sign")

static func apply_signs(tree: SceneTree, on: bool) -> void:
	for n in tree.get_nodes_in_group("tr_sign"):
		if n is Label3D: n.text = String(n.get_meta("tr" if on else "en", n.text))
