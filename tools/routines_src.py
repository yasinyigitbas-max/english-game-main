# Work tasks per sector and per job: (verb phrase, Turkish "I ..." form, Turkish imperative). Simple A1 English.
SECTOR = {
 "health": [("see patients", "Hastalara bakarım.", "Hastalara bak."), ("help sick people", "Hasta insanlara yardım ederim.", "Hasta insanlara yardım et."), ("write notes", "Notlar yazarım.", "Notlar yaz.")],
 "education": [("teach a lesson", "Ders veririm.", "Ders ver."), ("check homework", "Ödevleri kontrol ederim.", "Ödevleri kontrol et."), ("meet parents", "Velilerle görüşürüm.", "Velilerle görüş.")],
 "food": [("cook lunch", "Öğle yemeği pişiririm.", "Öğle yemeği pişir."), ("wash the dishes", "Bulaşıkları yıkarım.", "Bulaşıkları yıka."), ("clean the kitchen", "Mutfağı temizlerim.", "Mutfağı temizle.")],
 "transport": [("check the timetable", "Tarifeyi kontrol ederim.", "Tarifeyi kontrol et."), ("drive to the city", "Şehre sürerim.", "Şehre sür."), ("take a break", "Mola veririm.", "Mola ver.")],
 "safety": [("put on my uniform", "Üniformamı giyerim.", "Üniformanı giy."), ("help people", "İnsanlara yardım ederim.", "İnsanlara yardım et."), ("write a report", "Bir rapor yazarım.", "Bir rapor yaz.")],
 "shops": [("open the shop", "Dükkânı açarım.", "Dükkânı aç."), ("help customers", "Müşterilere yardım ederim.", "Müşterilere yardım et."), ("close the shop", "Dükkânı kapatırım.", "Dükkânı kapat.")],
 "office": [("write emails", "E-posta yazarım.", "E-posta yaz."), ("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git."), ("answer the phone", "Telefona cevap veririm.", "Telefona cevap ver.")],
 "tech": [("check my emails", "E-postalarımı kontrol ederim.", "E-postalarını kontrol et."), ("work on the computer", "Bilgisayarda çalışırım.", "Bilgisayarda çalış."), ("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git.")],
 "arts": [("practise", "Pratik yaparım.", "Pratik yap."), ("meet my team", "Ekibimle buluşurum.", "Ekibinle buluş."), ("show my work", "İşimi gösteririm.", "İşini göster.")],
 "building": [("check my tools", "Aletlerimi kontrol ederim.", "Aletlerini kontrol et."), ("go to a house", "Bir eve giderim.", "Bir eve git."), ("fix things", "Bir şeyleri tamir ederim.", "Bir şeyleri tamir et.")],
 "farming": [("feed the animals", "Hayvanları beslerim.", "Hayvanları besle."), ("work outside", "Dışarıda çalışırım.", "Dışarıda çalış."), ("water the plants", "Bitkileri sularım.", "Bitkileri sula.")],
 "care": [("meet my first customer", "İlk müşterimle buluşurum.", "İlk müşterinle buluş."), ("help people", "İnsanlara yardım ederim.", "İnsanlara yardım et."), ("clean the room", "Odayı temizlerim.", "Odayı temizle.")],
 "sports": [("warm up", "Isınırım.", "Isın."), ("train", "Antrenman yaparım.", "Antrenman yap."), ("have a shower", "Duş alırım.", "Duş al.")],
}
JOB = {
 "doctor": [("see patients", "Hastalara bakarım.", "Hastalara bak."), ("check blood tests", "Kan tahlillerini kontrol ederim.", "Kan tahlillerini kontrol et."), ("write prescriptions", "Reçete yazarım.", "Reçete yaz.")],
 "nurse": [("check on patients", "Hastaları kontrol ederim.", "Hastaları kontrol et."), ("give medicine", "İlaç veririm.", "İlaç ver."), ("help the doctor", "Doktora yardım ederim.", "Doktora yardım et.")],
 "dentist": [("check teeth", "Dişleri kontrol ederim.", "Dişleri kontrol et."), ("clean teeth", "Dişleri temizlerim.", "Dişleri temizle."), ("see patients", "Hastalara bakarım.", "Hastalara bak.")],
 "pharmacist": [("open the pharmacy", "Eczaneyi açarım.", "Eczaneyi aç."), ("sell medicine", "İlaç satarım.", "İlaç sat."), ("help customers", "Müşterilere yardım ederim.", "Müşterilere yardım et.")],
 "vet": [("check animals", "Hayvanları kontrol ederim.", "Hayvanları kontrol et."), ("help a sick dog", "Hasta bir köpeğe yardım ederim.", "Hasta bir köpeğe yardım et."), ("talk to pet owners", "Hayvan sahipleriyle konuşurum.", "Hayvan sahipleriyle konuş.")],
 "teacher": [("teach a lesson", "Ders veririm.", "Ders ver."), ("check homework", "Ödevleri kontrol ederim.", "Ödevleri kontrol et."), ("meet parents", "Velilerle görüşürüm.", "Velilerle görüş.")],
 "lecturer": [("teach a class", "Ders veririm.", "Ders ver."), ("read essays", "Ödevleri okurum.", "Ödevleri oku."), ("meet students", "Öğrencilerle görüşürüm.", "Öğrencilerle görüş.")],
 "librarian": [("put books on the shelves", "Kitapları raflara koyarım.", "Kitapları raflara koy."), ("help readers", "Okuyuculara yardım ederim.", "Okuyuculara yardım et."), ("read a story to children", "Çocuklara hikâye okurum.", "Çocuklara hikâye oku.")],
 "nursery teacher": [("play with the children", "Çocuklarla oynarım.", "Çocuklarla oyna."), ("sing songs", "Şarkı söylerim.", "Şarkı söyle."), ("read a story", "Bir hikâye okurum.", "Bir hikâye oku.")],
 "cook": [("cut vegetables", "Sebze doğrarım.", "Sebze doğra."), ("cook lunch", "Öğle yemeği pişiririm.", "Öğle yemeği pişir."), ("clean the kitchen", "Mutfağı temizlerim.", "Mutfağı temizle.")],
 "chef": [("plan the menu", "Menüyü planlarım.", "Menüyü planla."), ("cook dinner", "Akşam yemeği pişiririm.", "Akşam yemeği pişir."), ("check the kitchen", "Mutfağı kontrol ederim.", "Mutfağı kontrol et.")],
 "waiter": [("set the tables", "Masaları hazırlarım.", "Masaları hazırla."), ("take orders", "Sipariş alırım.", "Sipariş al."), ("serve food", "Yemek servis ederim.", "Yemek servis et.")],
 "baker": [("make bread", "Ekmek yaparım.", "Ekmek yap."), ("bake cakes", "Kek pişiririm.", "Kek pişir."), ("sell bread", "Ekmek satarım.", "Ekmek sat.")],
 "barista": [("make coffee", "Kahve yaparım.", "Kahve yap."), ("serve customers", "Müşterilere servis yaparım.", "Müşterilere servis yap."), ("clean the machine", "Makineyi temizlerim.", "Makineyi temizle.")],
 "bus driver": [("drive the bus", "Otobüsü sürerim.", "Otobüsü sür."), ("stop at the bus stops", "Duraklarda dururum.", "Duraklarda dur."), ("help passengers", "Yolculara yardım ederim.", "Yolculara yardım et.")],
 "taxi driver": [("drive my taxi", "Taksimi sürerim.", "Taksini sür."), ("take people to the airport", "İnsanları havalimanına götürürüm.", "İnsanları havalimanına götür."), ("wash my car", "Arabamı yıkarım.", "Arabanı yıka.")],
 "pilot": [("check the plane", "Uçağı kontrol ederim.", "Uçağı kontrol et."), ("fly the plane", "Uçağı uçururum.", "Uçağı uçur."), ("talk to the passengers", "Yolcularla konuşurum.", "Yolcularla konuş.")],
 "flight attendant": [("welcome the passengers", "Yolcuları karşılarım.", "Yolcuları karşıla."), ("serve drinks", "İçecek servis ederim.", "İçecek servis et."), ("help the passengers", "Yolculara yardım ederim.", "Yolculara yardım et.")],
 "train driver": [("check the train", "Treni kontrol ederim.", "Treni kontrol et."), ("drive the train", "Treni sürerim.", "Treni sür."), ("stop at the stations", "İstasyonlarda dururum.", "İstasyonlarda dur.")],
 "delivery driver": [("pick up parcels", "Paketleri alırım.", "Paketleri al."), ("drive the van", "Kamyoneti sürerim.", "Kamyoneti sür."), ("deliver parcels", "Paketleri teslim ederim.", "Paketleri teslim et.")],
 "police officer": [("put on my uniform", "Üniformamı giyerim.", "Üniformanı giy."), ("walk in the streets", "Sokaklarda yürürüm.", "Sokaklarda yürü."), ("help people", "İnsanlara yardım ederim.", "İnsanlara yardım et.")],
 "firefighter": [("check the fire engine", "İtfaiye aracını kontrol ederim.", "İtfaiye aracını kontrol et."), ("practise with my team", "Ekibimle pratik yaparım.", "Ekibinle pratik yap."), ("put out fires", "Yangın söndürürüm.", "Yangın söndür.")],
 "shop assistant": [("open the shop", "Dükkânı açarım.", "Dükkânı aç."), ("help customers", "Müşterilere yardım ederim.", "Müşterilere yardım et."), ("put clothes on the shelves", "Kıyafetleri raflara koyarım.", "Kıyafetleri raflara koy.")],
 "cashier": [("open my till", "Kasamı açarım.", "Kasanı aç."), ("take money", "Para alırım.", "Para al."), ("say thank you to customers", "Müşterilere teşekkür ederim.", "Müşterilere teşekkür et.")],
 "office worker": [("write emails", "E-posta yazarım.", "E-posta yaz."), ("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git."), ("work on the computer", "Bilgisayarda çalışırım.", "Bilgisayarda çalış.")],
 "secretary": [("answer the phone", "Telefona cevap veririm.", "Telefona cevap ver."), ("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git."), ("write emails", "E-posta yazarım.", "E-posta yaz.")],
 "accountant": [("check numbers", "Rakamları kontrol ederim.", "Rakamları kontrol et."), ("work on the computer", "Bilgisayarda çalışırım.", "Bilgisayarda çalış."), ("meet a client", "Bir müşteriyle görüşürüm.", "Bir müşteriyle görüş.")],
 "manager": [("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git."), ("talk to my team", "Ekibimle konuşurum.", "Ekibinle konuş."), ("make a plan", "Bir plan yaparım.", "Bir plan yap.")],
 "receptionist": [("answer the phone", "Telefona cevap veririm.", "Telefona cevap ver."), ("welcome visitors", "Ziyaretçileri karşılarım.", "Ziyaretçileri karşıla."), ("write emails", "E-posta yazarım.", "E-posta yaz.")],
 "software developer": [("write code", "Kod yazarım.", "Kod yaz."), ("test the app", "Uygulamayı test ederim.", "Uygulamayı test et."), ("go to a meeting", "Bir toplantıya giderim.", "Bir toplantıya git.")],
 "journalist": [("read the news", "Haberleri okurum.", "Haberleri oku."), ("talk to people", "İnsanlarla konuşurum.", "İnsanlarla konuş."), ("write a story", "Bir haber yazarım.", "Bir haber yaz.")],
 "musician": [("practise my music", "Müziğimi çalışırım.", "Müziğini çalış."), ("meet the band", "Grupla buluşurum.", "Grupla buluş."), ("play a concert", "Konser veririm.", "Konser ver.")],
 "mechanic": [("check cars", "Arabaları kontrol ederim.", "Arabaları kontrol et."), ("fix a car", "Bir araba tamir ederim.", "Bir araba tamir et."), ("talk to customers", "Müşterilerle konuşurum.", "Müşterilerle konuş.")],
 "plumber": [("check my van", "Kamyonetimi kontrol ederim.", "Kamyonetini kontrol et."), ("go to a house", "Bir eve giderim.", "Bir eve git."), ("fix a pipe", "Bir boru tamir ederim.", "Bir boru tamir et.")],
 "farmer": [("feed the animals", "Hayvanları beslerim.", "Hayvanları besle."), ("drive the tractor", "Traktörü sürerim.", "Traktörü sür."), ("milk the cows", "İnekleri sağarım.", "İnekleri sağ.")],
 "hairdresser": [("wash hair", "Saç yıkarım.", "Saç yıka."), ("cut hair", "Saç keserim.", "Saç kes."), ("talk to customers", "Müşterilerle konuşurum.", "Müşterilerle konuş.")],
 "footballer": [("go to training", "Antrenmana giderim.", "Antrenmana git."), ("run", "Koşarım.", "Koş."), ("play a match", "Maç yaparım.", "Maç yap.")],
 "coach": [("plan the training", "Antrenmanı planlarım.", "Antrenmanı planla."), ("train the team", "Takımı çalıştırırım.", "Takımı çalıştır."), ("watch a match", "Bir maç izlerim.", "Bir maç izle.")],
}
# not working: full day routines (no "START")
FREE = {
 "unemployed": [("07:30", "I wake up.", "Uyanırım."), ("08:00", "I have breakfast with my family.", "Ailemle kahvaltı yaparım."),
   ("09:00", "TASK0", ""), ("10:30", "TASK1", ""), ("12:30", "I have lunch.", "Öğle yemeği yerim."), ("14:00", "TASK2", ""),
   ("16:00", "I go to the gym.", "Spor salonuna giderim."), ("19:00", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("22:30", "I go to bed.", "Yatarım.")],
 "retired": [("08:00", "I wake up.", "Uyanırım."), ("08:30", "I have breakfast.", "Kahvaltı yaparım."),
   ("09:30", "TASK0", ""), ("11:00", "TASK1", ""), ("12:30", "I have lunch.", "Öğle yemeği yerim."), ("15:00", "TASK2", ""),
   ("17:00", "I water my plants.", "Bitkilerimi sularım."), ("19:00", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("22:00", "I go to bed.", "Yatarım.")],
}
JOB["unemployed"] = [("look for a job", "İş ararım.", "İş ara."), ("write a CV", "Bir özgeçmiş yazarım.", "Bir özgeçmiş yaz."), ("go to an interview", "Bir iş görüşmesine giderim.", "Bir iş görüşmesine git.")]
JOB["retired"] = [("read the newspaper", "Gazete okurum.", "Gazete oku."), ("walk in the park", "Parkta yürürüm.", "Parkta yürü."), ("visit my grandchildren", "Torunlarımı ziyaret ederim.", "Torunlarını ziyaret et.")]
SECTOR["notwork"] = JOB["unemployed"]

FREE["student"] = [("07:00", "I wake up.", "Uyanırım."), ("07:30", "I have breakfast with my family.", "Ailemle kahvaltı yaparım."), ("08:00", "I go to school.", "Okula giderim."),
   ("08:30", "TASK0", ""), ("12:30", "I have lunch.", "Öğle yemeği yerim."), ("15:30", "I go home.", "Eve giderim."), ("16:30", "TASK1", ""),
   ("18:00", "TASK2", ""), ("19:30", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("22:00", "I go to bed.", "Yatarım.")]
FREE["home"] = [("06:30", "I wake up.", "Uyanırım."), ("07:00", "I make breakfast for my family.", "Ailem için kahvaltı hazırlarım."), ("08:00", "TASK0", ""),
   ("09:30", "TASK1", ""), ("11:00", "TASK2", ""), ("12:30", "I have lunch.", "Öğle yemeği yerim."), ("15:30", "I pick up the children.", "Çocukları alırım."),
   ("18:00", "TASK3", ""), ("19:00", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("22:30", "I go to bed.", "Yatarım.")]
JOB["student"] = [("go to class", "Derse giderim.", "Derse git."), ("do my homework", "Ödevimi yaparım.", "Ödevini yap."), ("study for an exam", "Sınava çalışırım.", "Sınava çalış.")]
_H = [("take the children to school", "Çocukları okula götürürüm.", "Çocukları okula götür."), ("go shopping", "Alışverişe giderim.", "Alışverişe git."),
      ("clean the house", "Evi temizlerim.", "Evi temizle."), ("cook dinner", "Akşam yemeği pişiririm.", "Akşam yemeği pişir.")]
for k in ["housewife", "househusband", "stay-at-home parent"]: JOB[k] = _H

FREE["child"] = [("07:00", "I wake up.", "Uyanırım."), ("07:30", "I have breakfast with my family.", "Ailemle kahvaltı yaparım."), ("08:00", "I go to school.", "Okula giderim."),
   ("08:30", "TASK0", ""), ("12:00", "I have lunch.", "Öğle yemeği yerim."), ("12:30", "TASK1", ""), ("15:00", "I go home.", "Eve giderim."),
   ("16:00", "TASK2", ""), ("19:00", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("20:30", "I go to bed.", "Yatarım.")]
JOB["schoolchild"] = [("have lessons", "Derslere girerim.", "Derslere gir."), ("play with my friends", "Arkadaşlarımla oynarım.", "Arkadaşlarınla oyna."), ("do my homework", "Ödevimi yaparım.", "Ödevini yap.")]
