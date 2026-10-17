"""v9 content: data/jobs.json (71 jobs in 13 sectors), data/family.json, data/extra_lines.json (every spoken line -> Turkish).
Run: python3 tools/gen_content.py  (then tools/make_phone_icons.py and tools/build_voice.py)"""
import json, os, itertools
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SECTORS = [  # id, English, Turkish, glyph, colour top, colour bottom
 ("health", "Health", "Sağlık", "cross", (255, 120, 130), (225, 70, 95)),
 ("education", "Education", "Eğitim", "gradcap", (255, 196, 70), (240, 140, 40)),
 ("food", "Food", "Yemek", "chefhat", (255, 150, 90), (235, 95, 60)),
 ("transport", "Transport", "Ulaşım", "bus", (90, 170, 255), (50, 110, 230)),
 ("safety", "Safety", "Güvenlik", "shield", (80, 110, 220), (35, 55, 150)),
 ("shops", "Shops & Sales", "Mağaza ve satış", "bag", (190, 120, 240), (130, 70, 200)),
 ("office", "Office & Business", "Ofis ve iş dünyası", "building", (120, 140, 170), (75, 90, 120)),
 ("tech", "Technology", "Teknoloji", "code", (70, 200, 220), (30, 140, 180)),
 ("arts", "Arts & Media", "Sanat ve medya", "palette", (250, 120, 200), (200, 70, 160)),
 ("building", "Building & Repair", "İnşaat ve tamir", "hardhat", (255, 200, 60), (230, 150, 30)),
 ("farming", "Farming & Nature", "Tarım ve doğa", "leaf", (130, 210, 90), (60, 160, 70)),
 ("care", "Beauty & Care", "Güzellik ve bakım", "heart", (255, 150, 180), (230, 100, 140)),
 ("sports", "Sports", "Spor", "ball", (100, 210, 150), (40, 160, 110)),
 ("notwork", "Not working", "Çalışmıyorum", "cup", (150, 165, 190), (100, 115, 145)),
]
# sector, en, tr, second sentence, routine workplace (None = "I start work."), Turkish locative, shift, glyph
J = [
 ("health", "doctor", "doktor", "I work at a hospital.", "at the hospital", "Hastanede", "day", "stethoscope"),
 ("health", "nurse", "hemşire", "I work at a hospital.", "at the hospital", "Hastanede", "early", "nursecap"),
 ("health", "dentist", "diş hekimi", "I work at a dental clinic.", "at the dental clinic", "Diş kliniğinde", "day", "tooth"),
 ("health", "pharmacist", "eczacı", "I work in a pharmacy.", "in the pharmacy", "Eczanede", "day", "pill"),
 ("health", "vet", "veteriner", "I work at an animal clinic.", "at the animal clinic", "Hayvan kliniğinde", "day", "paw"),
 ("health", "paramedic", "acil sağlık görevlisi", "I work in an ambulance.", "at the ambulance station", "Ambulans istasyonunda", "early", "ambulance"),
 ("education", "teacher", "öğretmen", "I work at a school.", "at the school", "Okulda", "day", "board"),
 ("education", "lecturer", "öğretim görevlisi", "I work at a university.", "at the university", "Üniversitede", "day", "gradcap"),
 ("education", "librarian", "kütüphaneci", "I work in a library.", "in the library", "Kütüphanede", "day", "books"),
 ("education", "nursery teacher", "anaokulu öğretmeni", "I work at a nursery school.", "at the nursery school", "Anaokulunda", "day", "blocks"),
 ("food", "cook", "aşçı", "I work in a restaurant kitchen.", "in the kitchen", "Mutfakta", "day", "chefhat"),
 ("food", "chef", "şef", "I work in a restaurant.", "in the restaurant", "Restoranda", "late", "pan"),
 ("food", "waiter", "garson", "I work in a café.", "in the café", "Kafede", "late", "cloche"),
 ("food", "baker", "fırıncı", "I work in a bakery.", "in the bakery", "Fırında", "early", "bread"),
 ("food", "barista", "barista", "I work in a coffee shop.", "in the coffee shop", "Kahve dükkânında", "early", "cup"),
 ("food", "butcher", "kasap", "I work in a butcher's shop.", "in the butcher's shop", "Kasap dükkânında", "early", "cleaver"),
 ("transport", "bus driver", "otobüs şoförü", "I drive a bus.", "at the bus station", "Otobüs garajında", "early", "bus"),
 ("transport", "taxi driver", "taksi şoförü", "I drive a taxi.", "in my taxi", "Taksimde", "day", "taxi"),
 ("transport", "pilot", "pilot", "I fly planes.", "at the airport", "Havalimanında", "early", "plane"),
 ("transport", "flight attendant", "kabin memuru", "I work on a plane.", "at the airport", "Havalimanında", "early", "suitcase"),
 ("transport", "train driver", "makinist", "I drive a train.", "at the train station", "Tren istasyonunda", "early", "train"),
 ("transport", "delivery driver", "kurye", "I deliver parcels.", "at the warehouse", "Depoda", "day", "box"),
 ("safety", "police officer", "polis memuru", "I work at a police station.", "at the police station", "Karakolda", "day", "star"),
 ("safety", "firefighter", "itfaiyeci", "I work at a fire station.", "at the fire station", "İtfaiye istasyonunda", "day", "flame"),
 ("safety", "soldier", "asker", "I am in the army.", "at the army base", "Askeri üste", "early", "shieldstar"),
 ("safety", "security guard", "güvenlik görevlisi", "I work at a bank.", "at the bank", "Bankada", "late", "shield"),
 ("safety", "lifeguard", "cankurtaran", "I work at a swimming pool.", "at the swimming pool", "Yüzme havuzunda", "day", "buoy"),
 ("shops", "shop assistant", "satış görevlisi", "I work in a shop.", "in the shop", "Dükkânda", "day", "bag"),
 ("shops", "cashier", "kasiyer", "I work in a supermarket.", "in the supermarket", "Süpermarkette", "day", "cart"),
 ("shops", "market seller", "pazarcı", "I work at a market.", "at the market", "Pazarda", "early", "stall"),
 ("shops", "florist", "çiçekçi", "I work in a flower shop.", "in the flower shop", "Çiçekçide", "day", "flower"),
 ("shops", "bookseller", "kitapçı", "I work in a bookshop.", "in the bookshop", "Kitapçıda", "day", "book"),
 ("office", "office worker", "ofis çalışanı", "I work in an office.", "in the office", "Ofiste", "day", "building"),
 ("office", "accountant", "muhasebeci", "I work in an office.", "in the office", "Ofiste", "day", "calculator"),
 ("office", "secretary", "sekreter", "I work in an office.", "in the office", "Ofiste", "day", "envelope"),
 ("office", "manager", "müdür", "I work for a big company.", "at the company", "Şirkette", "day", "tie"),
 ("office", "lawyer", "avukat", "I work at a law firm.", "at the law firm", "Hukuk bürosunda", "day", "scales"),
 ("office", "receptionist", "resepsiyonist", "I work at a hotel.", "at the hotel", "Otelde", "day", "bell"),
 ("office", "bank clerk", "banka memuru", "I work in a bank.", "in the bank", "Bankada", "day", "bank"),
 ("tech", "software developer", "yazılımcı", "I write computer programs.", "at the tech company", "Teknoloji şirketinde", "day", "code"),
 ("tech", "engineer", "mühendis", "I work in a factory.", "at the factory", "Fabrikada", "day", "gear"),
 ("tech", "web designer", "web tasarımcısı", "I make websites.", "at home", "Evde", "day", "monitor"),
 ("tech", "scientist", "bilim insanı", "I work in a laboratory.", "in the laboratory", "Laboratuvarda", "day", "flask"),
 ("tech", "IT technician", "bilgi işlem teknisyeni", "I fix computers.", "in the office", "Ofiste", "day", "laptop"),
 ("arts", "artist", "ressam", "I work in a studio.", "in my studio", "Atölyemde", "day", "palette"),
 ("arts", "musician", "müzisyen", "I play in a band.", "at the music studio", "Müzik stüdyosunda", "late", "note"),
 ("arts", "singer", "şarkıcı", "I sing on stage.", "at the concert hall", "Konser salonunda", "late", "mic"),
 ("arts", "actor", "oyuncu", "I work in a theatre.", "at the theatre", "Tiyatroda", "late", "masks"),
 ("arts", "photographer", "fotoğrafçı", "I take photos.", "in my studio", "Stüdyomda", "day", "camera"),
 ("arts", "journalist", "gazeteci", "I write for a newspaper.", "at the newspaper office", "Gazete ofisinde", "day", "newspaper"),
 ("arts", "writer", "yazar", "I write books.", "at home", "Evde", "day", "pen"),
 ("building", "builder", "inşaat işçisi", "I work on a building site.", "on the building site", "Şantiyede", "early", "hardhat"),
 ("building", "electrician", "elektrikçi", "I work in people's homes.", None, None, "day", "bolt"),
 ("building", "plumber", "tesisatçı", "I work in people's homes.", None, None, "early", "drop"),
 ("building", "mechanic", "tamirci", "I work in a garage.", "at the garage", "Tamirhanede", "day", "wrench"),
 ("building", "carpenter", "marangoz", "I work in a workshop.", "in the workshop", "Atölyede", "day", "hammer"),
 ("building", "painter", "boyacı", "I paint houses.", None, None, "day", "roller"),
 ("farming", "farmer", "çiftçi", "I work on a farm.", "on the farm", "Çiftlikte", "early", "tractor"),
 ("farming", "gardener", "bahçıvan", "I work in a park.", "in the park", "Parkta", "early", "leaf"),
 ("farming", "fisherman", "balıkçı", "I work on a boat.", "on my boat", "Teknemde", "early", "fish"),
 ("farming", "zookeeper", "hayvan bakıcısı", "I work at a zoo.", "at the zoo", "Hayvanat bahçesinde", "early", "paw"),
 ("care", "hairdresser", "kuaför", "I work at a hair salon.", "at the hair salon", "Kuaför salonunda", "day", "scissors"),
 ("care", "barber", "berber", "I work in a barber's shop.", "in the barber's shop", "Berber dükkânında", "day", "comb"),
 ("care", "care worker", "bakım görevlisi", "I work in a care home.", "in the care home", "Bakım evinde", "early", "heart"),
 ("care", "babysitter", "çocuk bakıcısı", "I look after children.", None, None, "day", "pram"),
 ("care", "cleaner", "temizlikçi", "I clean offices.", "in the office building", "Ofis binasında", "early", "bucket"),
 ("sports", "footballer", "futbolcu", "I play for a football team.", "at the training ground", "Antrenman sahasında", "day", "ball"),
 ("sports", "coach", "antrenör", "I work at a sports club.", "at the sports club", "Spor kulübünde", "day", "whistle"),
 ("sports", "fitness instructor", "fitness eğitmeni", "I work at a gym.", "at the gym", "Spor salonunda", "early", "dumbbell"),
 ("sports", "tennis player", "tenisçi", "I play tennis every day.", "at the tennis club", "Tenis kulübünde", "day", "racket"),
 ("sports", "swimming teacher", "yüzme öğretmeni", "I work at a swimming pool.", "at the swimming pool", "Yüzme havuzunda", "day", "waves"),
]
VOW = "aıoueiöüAIOUEİÖÜ"
def tr_im(w):  # Turkish 1st person copula with vowel harmony: doktor -> doktorum, hemşire -> hemşireyim
    last = [c for c in w if c in "aıoueiöüâ"][-1]
    v = {"a": "ı", "ı": "ı", "â": "ı", "e": "i", "i": "i", "o": "u", "u": "u", "ö": "ü", "ü": "ü"}[last]
    return w + ("y" if w[-1] in "aıoueiöüâ" else "") + v + "m"
def art(w): return "an" if w[0].lower() in "aeiou" else "a"
lines = {}
jobs = []
for s, en, tr, l2, wp, loc, shift, g in J:
    a = art(en)
    w0 = en[0].upper() + en[1:] if not en.isupper() else en
    if en.startswith("IT"): w0 = en
    line = f"{w0}. I am {a} {en}. {l2}"
    now = f"I am {a} {en} now."
    start = f"I start work {wp}." if wp else "I start work."
    lines[line] = ""
    lines[now] = "Artık " + tr_im(tr) + "."
    lines[start] = (f"{loc} işe başlarım." if loc else "İşe başlarım.")
    jobs.append({"id": en, "en": en, "a": a, "tr": tr, "sector": s, "line": line, "now": now, "start": start, "shift": shift, "icon": "j_" + g + "_" + s})
jobs.append({"id": "unemployed", "en": "unemployed", "a": "", "tr": "işsiz", "sector": "notwork", "line": "Unemployed. I am unemployed. I am looking for a job.",
  "now": "I am unemployed now.", "start": "", "shift": "unemployed", "icon": "j_tie_notwork"})
jobs.append({"id": "retired", "en": "retired", "a": "", "tr": "emekli", "sector": "notwork", "line": "Retired. I am retired. I do not work now.",
  "now": "I am retired now.", "start": "", "shift": "retired", "icon": "j_newspaper_notwork"})
lines["Unemployed. I am unemployed. I am looking for a job."] = ""; lines["I am unemployed now."] = "Artık işsizim."
lines["Retired. I am retired. I do not work now."] = ""; lines["I am retired now."] = "Artık emekliyim."
HOME = [  # id, tr, line, now (tr), shift, glyph
 ("student", "öğrenci", "Student. I am a student. I study at a school.", "Artık öğrenciyim.", "student", "gradcap"),
 ("housewife", "ev hanımı", "Housewife. I am a housewife. I work at home.", "Artık ev hanımıyım.", "home", "pan"),
 ("househusband", "ev erkeği", "Househusband. I am a househusband. I work at home.", "Artık ev erkeğiyim.", "home", "bucket"),
 ("stay-at-home parent", "evde çocuk bakan ebeveyn", "Stay-at-home parent. I am a stay-at-home parent. I look after my children at home.", "Artık evde çocuklarıma bakıyorum.", "home", "pram"),
]
for en, tr, line, nowtr, shift, g in HOME:
    a = art(en)
    jobs.append({"id": en, "en": en, "a": a, "tr": tr, "sector": "notwork", "line": line, "now": f"I am {a} {en} now.", "start": "", "shift": shift, "icon": f"j_{g}_notwork"})
    lines[line] = ""; lines[f"I am {a} {en} now."] = nowtr
    J.append(("notwork", en, "", "", "", "", "", g))
jobs.append({"id": "schoolchild", "en": "student", "a": "a", "tr": "öğrenci", "sector": "notwork", "line": "I am a student. I go to school.", "now": "I am a student.",
  "start": "", "shift": "child", "icon": "j_gradcap_notwork", "hidden": True})   # automatic job for a child player (no Jobs app)
lines["I am a student. I go to school."] = "Ben bir öğrenciyim. Okula giderim."; lines["I am a student."] = "Ben bir öğrenciyim."
J += [("notwork", "unemployed", "", "", "", "", "", "tie"), ("notwork", "retired", "", "", "", "", "", "newspaper")]
import sys; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from routines_src import SECTOR, JOB, FREE
GROUPS = [  # id, en, tr, glyph, colours, [(sub id, en, tr, glyph, [job ids])]
 ("health", "Health & Care", "Sağlık ve bakım", "cross", (255, 120, 130), (225, 70, 95), [
   ("hospital", "Hospital", "Hastane", "ambulance", ["doctor", "nurse", "paramedic"]),
   ("clinic", "Clinic & Pharmacy", "Klinik ve eczane", "pill", ["dentist", "pharmacist", "vet"]),
   ("care", "Care", "Bakım", "heart", ["care worker", "babysitter", "cleaner"]),
   ("beauty", "Beauty", "Güzellik", "scissors", ["hairdresser", "barber"])]),
 ("school", "School & Books", "Okul ve kitaplar", "gradcap", (255, 196, 70), (240, 140, 40), [
   ("teaching", "Teaching", "Öğretmenlik", "board", ["teacher", "lecturer", "nursery teacher", "swimming teacher"]),
   ("books", "Books", "Kitaplar", "books", ["librarian", "bookseller", "writer"])]),
 ("food", "Food & Shops", "Yemek ve mağazalar", "chefhat", (255, 150, 90), (235, 95, 60), [
   ("kitchen", "Kitchen", "Mutfak", "pan", ["cook", "chef", "baker", "butcher"]),
   ("cafe", "Café & Restaurant", "Kafe ve restoran", "cup", ["waiter", "barista"]),
   ("shops", "Shops", "Mağazalar", "bag", ["shop assistant", "cashier", "market seller", "florist"])]),
 ("transport", "Transport", "Ulaşım", "bus", (90, 170, 255), (50, 110, 230), [
   ("road", "On the road", "Yolda", "taxi", ["bus driver", "taxi driver", "delivery driver"]),
   ("airrail", "Planes & Trains", "Uçak ve tren", "plane", ["pilot", "flight attendant", "train driver"])]),
 ("safety", "Safety & Law", "Güvenlik ve hukuk", "shield", (80, 110, 220), (35, 55, 150), [
   ("safety", "Safety", "Güvenlik", "shieldstar", ["police officer", "firefighter", "soldier", "security guard", "lifeguard"]),
   ("law", "Law", "Hukuk", "scales", ["lawyer"])]),
 ("office", "Office & Business", "Ofis ve iş dünyası", "building", (120, 140, 170), (75, 90, 120), [
   ("office", "Office", "Ofis", "envelope", ["office worker", "secretary", "receptionist", "manager"]),
   ("money", "Money", "Para", "bank", ["accountant", "bank clerk"])]),
 ("build", "Building & Tech", "İnşaat ve teknoloji", "hardhat", (255, 200, 60), (230, 150, 30), [
   ("building", "Building", "İnşaat", "hammer", ["builder", "carpenter", "painter"]),
   ("repair", "Repair", "Tamir", "wrench", ["electrician", "plumber", "mechanic"]),
   ("tech", "Technology", "Teknoloji", "laptop", ["software developer", "web designer", "IT technician", "engineer", "scientist"])]),
 ("arts", "Arts & Sports", "Sanat ve spor", "palette", (250, 120, 200), (200, 70, 160), [
   ("art", "Art & Media", "Sanat ve medya", "camera", ["artist", "photographer", "journalist"]),
   ("stage", "Music & Stage", "Müzik ve sahne", "mic", ["musician", "singer", "actor"]),
   ("sports", "Sports", "Spor", "ball", ["footballer", "coach", "fitness instructor", "tennis player"])]),
 ("nature", "Nature & Animals", "Doğa ve hayvanlar", "leaf", (130, 210, 90), (60, 160, 70), [
   ("farm", "Farm & Garden", "Çiftlik ve bahçe", "tractor", ["farmer", "gardener"]),
   ("animals", "Water & Animals", "Su ve hayvanlar", "fish", ["fisherman", "zookeeper"])]),
 ("home", "At home & Studying", "Evde ve okulda", "house", (150, 165, 190), (100, 115, 145), [
   ("study", "Studying", "Öğrenim", "gradcap", ["student"]),
   ("athome", "At home", "Evde", "house", ["housewife", "househusband", "stay-at-home parent"]),
   ("notworking", "Not working", "Çalışmıyorum", "cup", ["unemployed", "retired"])]),
]
_ids = [x for g in GROUPS for sb in g[6] for x in sb[4]]
assert sorted(_ids) == sorted(j["id"] for j in jobs if not j.get("hidden")), set(j["id"] for j in jobs) ^ set(_ids)
assert len(_ids) == len(set(_ids))
for g in GROUPS:
    for sb in g[6]:
        for x in sb[4]:
            next(j for j in jobs if j["id"] == x).update({"group": g[0], "sub": sb[0]})
ROUT = {
 "day": [("07:00", "I wake up.", "Uyanırım."), ("07:30", "I have breakfast with my family.", "Ailemle kahvaltı yaparım."), ("08:15", "I go to work.", "İşe giderim."),
         ("09:00", "START", ""), ("12:30", "I have lunch.", "Öğle yemeği yerim."), ("17:00", "I finish work.", "İşi bitiririm."), ("17:30", "I go home.", "Eve giderim."),
         ("19:00", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("20:00", "I watch TV.", "Televizyon izlerim."), ("22:30", "I go to bed.", "Yatarım.")],
 "early": [("05:00", "I wake up.", "Uyanırım."), ("05:30", "I have breakfast.", "Kahvaltı yaparım."), ("06:00", "I go to work.", "İşe giderim."),
         ("06:30", "START", ""), ("11:30", "I have lunch.", "Öğle yemeği yerim."), ("14:30", "I finish work.", "İşi bitiririm."), ("15:00", "I go home.", "Eve giderim."),
         ("18:30", "I have dinner with my family.", "Ailemle akşam yemeği yerim."), ("19:30", "I read a book.", "Kitap okurum."), ("21:30", "I go to bed.", "Yatarım.")],
 "late": [("08:30", "I wake up.", "Uyanırım."), ("09:00", "I have breakfast with my family.", "Ailemle kahvaltı yaparım."), ("12:30", "I have lunch at home.", "Evde öğle yemeği yerim."),
         ("13:30", "I go to work.", "İşe giderim."), ("14:00", "START", ""), ("18:00", "I have dinner at work.", "İşte akşam yemeği yerim."), ("22:00", "I finish work.", "İşi bitiririm."),
         ("22:30", "I go home.", "Eve giderim."), ("23:00", "I watch TV.", "Televizyon izlerim."), ("23:30", "I go to bed.", "Yatarım.")],
}
# day frames: START = "I start work ...", TASK0-2 = the job's own work tasks
ROUT["day"][4:4] = [("10:00", "TASK0", ""), ("11:30", "TASK1", "")]; ROUT["day"].insert(7, ("14:00", "TASK2", ""))
ROUT["early"][4:4] = [("07:30", "TASK0", ""), ("09:30", "TASK1", "")]; ROUT["early"].insert(7, ("12:30", "TASK2", ""))
ROUT["late"][5:5] = [("15:00", "TASK0", ""), ("16:30", "TASK1", "")]; ROUT["late"].insert(8, ("19:00", "TASK2", ""))
ROUT.update(FREE)
for k in ROUT:
    for t, e, r in ROUT[k]:
        if e != "START" and not e.startswith("TASK"): lines[e] = r
def tk(t): return {"i": "I " + t[0] + ".", "do": t[0][0].upper() + t[0][1:] + ".", "i_tr": t[1], "do_tr": t[2]}
TASKS = {"sectors": {k: [tk(t) for t in v] for k, v in SECTOR.items()}, "jobs": {k: [tk(t) for t in v] for k, v in JOB.items()}}
for grp in TASKS.values():
    for v in grp.values():
        for t in v: lines[t["i"]] = t["i_tr"]; lines[t["do"]] = t["do_tr"]
assert all(j["id"] in JOB or j["sector"] in SECTOR for j in jobs)
json.dump({"frames": ROUT, **TASKS}, open(f"{ROOT}/data/routines.json", "w"), ensure_ascii=False, indent=1)
# ---- family
F = [("mother", "she", "anne"), ("father", "he", "baba"), ("sister", "she", "kız kardeş"), ("brother", "he", "erkek kardeş"),
     ("grandmother", "she", "büyükanne"), ("grandfather", "he", "büyükbaba"), ("wife", "she", "eş (karı)"), ("husband", "he", "eş (koca)"),
     ("daughter", "she", "kız evlat"), ("son", "he", "oğul"), ("aunt", "she", "teyze / hala"), ("uncle", "he", "amca / dayı"), ("cousin", "", "kuzen")]
P = [("dog", "köpek"), ("cat", "kedi"), ("bird", "kuş"), ("fish", "balık"), ("rabbit", "tavşan"), ("hamster", "hamster"), ("turtle", "kaplumbağa")]
ADJ = [("kind", "nazik"), ("funny", "komik"), ("friendly", "arkadaş canlısı"), ("cheerful", "neşeli"), ("clever", "zeki"), ("brave", "cesur"),
       ("quiet", "sessiz"), ("shy", "utangaç"), ("calm", "sakin"), ("lazy", "tembel"), ("strict", "katı"), ("noisy", "gürültücü")]
PL = {"wife": "wives", "fish": "fish", "hamster": "hamsters"}
TRP = {"he": "O", "she": "O", "it": "O"}
lines["This is"] = "Bu"
for r, p, tr in F:
    for pr in ([p] if p else ["he", "she"]):
        lines[f"{pr.capitalize()} is my {r}."] = f"O benim {tr}."
for r, tr in P: lines[f"It is my {r}."] = f"O benim {tr}."
for pr in ["he", "she", "it"]:
    for a, atr in ADJ: lines[f"{pr.capitalize()} is {a}."] = f"O {atr}."
    for (a, atr), (b, btr) in itertools.combinations(ADJ, 2): lines[f"{pr.capitalize()} is {a} and {b}."] = f"O {atr} ve {btr}."
lines["They are my family."] = "Onlar benim ailem."
LESSON = [
 {"title": "I, you, he, she, it, we, they", "tr": "Özne zamirleri", "rows": [["I", "ben"], ["you", "sen / siz"], ["he", "o (erkek)"], ["she", "o (kadın)"], ["it", "o (hayvan, eşya)"], ["we", "biz"], ["they", "onlar"]],
  "say": ["I, you, he, she, it, we, they."]},
 {"title": "He, she or it?", "tr": "Türkçede hepsi “o”. İngilizcede üç farklı kelime var.", "rows": [["he", "a man or a boy: He is my father."], ["she", "a woman or a girl: She is my mother."], ["it", "an animal or a thing: It is my dog."]],
  "say": ["He is my father.", "She is my mother.", "It is my dog."]},
 {"title": "am, is, are", "tr": "“to be” fiili: am / is / are", "rows": [["I am", "We are"], ["you are", "they are"], ["he is", "she is"], ["it is", ""]],
  "say": ["I am, you are, he is, she is, it is, we are, they are."]},
 {"title": "Examples", "tr": "Örnekler", "rows": [["She is my mother.", "O benim annem."], ["It is my dog.", "O benim köpeğim."], ["They are my brothers.", "Onlar benim erkek kardeşlerim."], ["We are a family.", "Biz bir aileyiz."]],
  "say": ["She is my mother.", "It is my dog.", "They are my brothers.", "We are a family."]},
]
QUIZ = [
 {"q": "This is my mother. ___ is kind.", "opts": ["He", "She", "It"], "a": 1, "say": "She is kind."},
 {"q": "This is my cat. ___ is funny.", "opts": ["He", "She", "It"], "a": 2, "say": "It is funny."},
 {"q": "Tom and Ben ___ my brothers.", "opts": ["is", "am", "are"], "a": 2, "say": "Tom and Ben are my brothers."},
]
tr_say = {"I, you, he, she, it, we, they.": "Ben, sen, o, o, o, biz, onlar.", "He is my father.": "O benim babam.", "She is my mother.": "O benim annem.",
          "It is my dog.": "O benim köpeğim.", "I am, you are, he is, she is, it is, we are, they are.": "", "They are my brothers.": "Onlar benim erkek kardeşlerim.",
          "We are a family.": "Biz bir aileyiz.", "She is kind.": "O nazik.", "It is funny.": "O komik.", "Tom and Ben are my brothers.": "Tom ve Ben benim erkek kardeşlerim."}
lines.update(tr_say)
for lv in LESSON:
    for s in lv["say"]: lines.setdefault(s, "")
json.dump({"sectors": [{"id": s[0], "en": s[1], "tr": s[2], "icon": "s_" + s[0]} for s in SECTORS], "jobs": jobs, "groups": [{"id": g[0], "en": g[1], "tr": g[2], "icon": "grp_" + g[0], "subs": [{"id": sb[0], "en": sb[1], "tr": sb[2], "icon": "sub_" + sb[0], "jobs": sb[4]} for sb in g[6]]} for g in GROUPS]}, open(f"{ROOT}/data/jobs.json", "w"), ensure_ascii=False, indent=1)
json.dump({"roles": [{"id": r, "pron": p, "tr": tr, "pet": False, "plural": PL.get(r, r + "s")} for r, p, tr in F] + [{"id": r, "pron": "it", "tr": tr, "pet": True, "plural": PL.get(r, r + "s")} for r, tr in P],
           "adjectives": [{"en": a, "tr": t} for a, t in ADJ], "lesson": LESSON, "quiz": QUIZ}, open(f"{ROOT}/data/family.json", "w"), ensure_ascii=False, indent=1)
json.dump(lines, open(f"{ROOT}/data/extra_lines.json", "w"), ensure_ascii=False, indent=0)
json.dump({"sectors": [[s[0], s[3], s[4], s[5]] for s in SECTORS], "glyphs": sorted({(j[7], j[0]) for j in J}), "tiles": [["grp_" + g[0], g[3], g[4], g[5]] for g in GROUPS] + [["sub_" + sb[0], sb[3], g[4], g[5]] for g in GROUPS for sb in g[6]]}, open("/tmp/icon_spec.json", "w"))
print(len(jobs), "jobs,", len(lines), "lines")
