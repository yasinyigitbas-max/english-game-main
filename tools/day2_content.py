"""v31 day 2 morning content -> data/day2_morning.json (lesson, table dialogue, 3 x 10 test, TR lines).
Edit here (or the JSON directly) - the game reads only data/day2_morning.json."""
import json, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lesson = [
 {"title": "Have to: things I must do", "tr": "have to: yapmam gereken şeyler (he / she / it -> has to)",
  "rows": [["I have to go to work.", "İşe gitmem gerekiyor."], ["I have to go to school.", "Okula gitmem gerekiyor."],
           ["She has to rest.", "Dinlenmesi gerekiyor."], ["Do you have to work today?", "Bugün çalışman gerekiyor mu?"]]},
 {"title": "Going to: my plans", "tr": "going to: planlar (am / is / are + going to)",
  "rows": [["I am going to visit the hospital.", "Hastaneyi ziyaret edeceğim."], ["We are going to have breakfast.", "Kahvaltı yapacağız."],
           ["He is going to drive the car.", "Arabayı sürecek."], ["Are you going to see the doctor?", "Doktora görünecek misin?"]]},
 {"title": "Will: future, promises, quick decisions", "tr": "will: gelecek, sözler, ani kararlar",
  "rows": [["I will see the doctor today.", "Bugün doktoru göreceğim."], ["I will call you later.", "Seni sonra arayacağım."],
           ["It will be fine.", "İyi olacak."], ["Will you be okay?", "İyi olacak mısın?"]]},
 {"title": "Short forms: will", "tr": "Kısa biçimler: will -> 'll, will not -> won't",
  "rows": [["I'll call you.", "I will -> I'll"], ["You'll be fine.", "you will -> you'll"], ["He'll drive. She'll help.", "he will -> he'll, she will -> she'll"],
           ["We'll eat. They'll come.", "we will -> we'll, they will -> they'll"], ["It'll be okay.", "it will -> it'll"], ["I won't be late.", "will not -> won't"]]},
 {"title": "Short forms: going to", "tr": "Kısa biçimler: am / is / are -> 'm / 's / 're",
  "rows": [["I'm going to rest.", "I am -> I'm"], ["You're going to work.", "you are -> you're"], ["He's going to drive. She's going to cook.", "he is -> he's, she is -> she's"],
           ["We're going to eat. They're going to wait.", "we are -> we're, they are -> they're"], ["She isn't going to work today.", "is not -> isn't"], ["They aren't going to come.", "are not -> aren't"]]},
 {"title": "Short forms: have to", "tr": "Kısa biçimler: do not -> don't, does not -> doesn't",
  "rows": [["I don't have to cook today.", "Bugün yemek yapmam gerekmiyor. (do not -> don't)"], ["He doesn't have to work today.", "Bugün çalışması gerekmiyor. (does not -> doesn't)"],
           ["Gonna = going to.", "Sadece konuşmada, gündelik dil. Yazıda 'going to' yaz."], ["I'm gonna eat. (spoken only)", "Gündelik konuşma: I'm going to eat."]]},
]
for st in lesson: st["say"] = [r[0] for r in st["rows"]]
# table dialogue (between lesson and test). who: "me" (narrator voice, "Me:" caption) | "fam0" / "fam1" (family members in their voices).
# {have_to} = the job-based line below. With one family member fam1 -> fam0; with none, only the "me" lines are said.
dialogue = [
 {"who": "fam0", "en": "Good morning! How are you today?", "tr": "Günaydın! Bugün nasılsın?"},
 {"who": "me", "en": "I'm fine, thanks.", "tr": "İyiyim, teşekkürler."},
 {"who": "fam1", "en": "What are you going to do today?", "tr": "Bugün ne yapacaksın?"},
 {"who": "me", "en": "{have_to}"},
 {"who": "fam0", "en": "You have to rest too!", "tr": "Dinlenmen de lazım!"},
 {"who": "me", "en": "I'm going to visit the hospital.", "tr": "Hastaneye gideceğim."},
 {"who": "fam1", "en": "Will you be okay?", "tr": "İyi olacak mısın?"},
 {"who": "me", "en": "Yes. I'll see the doctor today.", "tr": "Evet. Bugün doktoru göreceğim."},
 {"who": "fam0", "en": "Good. Call us later!", "tr": "Güzel. Sonra bizi ara!"},
 {"who": "me", "en": "I will. Don't worry. I won't be late.", "tr": "Ararım. Merak etmeyin. Geç kalmayacağım."},
]
have_to = {
 "work": {"en": "I have to go to work today.", "tr": "Bugün işe gitmem gerekiyor."},
 "school": {"en": "I have to go to school today.", "tr": "Bugün okula gitmem gerekiyor."},
 "home": {"en": "I have to do the housework today.", "tr": "Bugün ev işlerini yapmam gerekiyor."},
 "unemployed": {"en": "I have to look for a job today.", "tr": "Bugün iş aramam gerekiyor."},
 "retired": {"en": "I have to go to the market today.", "tr": "Bugün pazara gitmem gerekiyor."},
}
job_group = {"student": "school", "schoolchild": "school", "housewife": "home", "househusband": "home", "stay-at-home parent": "home",
             "unemployed": "unemployed", "retired": "retired"}
def q(s, opts, tr, blank=None):
    w = blank or opts[0]; assert w in s, (s, w)
    return {"q": s.replace(w, "___", 1), "opts": opts, "a": 0, "say": s, "tr": tr}
quiz = [
 q("I have to go to work today.", ["have to", "has to", "having to"], "Bugün işe gitmem gerekiyor."),
 q("She has to rest.", ["has to", "have to", "haves to"], "Dinlenmesi gerekiyor."),
 q("I'm going to visit the hospital.", ["I'm", "I'll", "I"], "Hastaneyi ziyaret edeceğim."),
 q("I'll see the doctor today.", ["I'll", "I'm", "I won"], "Bugün doktoru göreceğim."),
 q("We are going to have breakfast.", ["are", "is", "am"], "Kahvaltı yapacağız."),
 q("It'll be fine.", ["It'll", "It's will", "It"], "İyi olacak."),
 q("He is going to drive the car.", ["drive", "drives", "driving"], "Arabayı sürecek."),
 q("I won't be late.", ["won't", "willn't", "don't will"], "Geç kalmayacağım."),
 q("Are you going to see the doctor?", ["Are", "Do", "Will"], "Doktora görünecek misin?"),
 q("He doesn't have to work today.", ["doesn't", "don't", "isn't"], "Bugün çalışması gerekmiyor."),
]
quiz_b = [
 q("I have to go to school today.", ["have to", "has to", "am have to"], "Bugün okula gitmem gerekiyor."),
 q("He has to work today.", ["has to", "have to", "is have"], "Bugün çalışması gerekiyor."),
 q("I am going to visit my doctor.", ["to", "for", "at"], "Doktorumu ziyaret edeceğim.", blank="to"),
 q("I will call you later.", ["call", "calls", "calling"], "Seni sonra arayacağım."),
 q("She's going to drive.", ["She's", "She'll", "She"], "Araba sürecek."),
 q("We'll help you.", ["We'll", "We're", "We"], "Sana yardım edeceğiz."),
 q("Do you have to go to work?", ["have to", "has to", "having to"], "İşe gitmen gerekiyor mu?"),
 q("I don't have to cook today.", ["don't", "doesn't", "not"], "Bugün yemek yapmam gerekmiyor."),
 q("They aren't going to come.", ["aren't", "isn't", "don't"], "Gelmeyecekler."),
 q("Will you be okay?", ["be", "are", "is"], "İyi olacak mısın?"),
]
quiz_c = [
 q("You have to rest too!", ["have to", "has to", "to have"], "Dinlenmen de lazım!"),
 q("My mother has to go to work.", ["has to", "have to", "haves"], "Annemin işe gitmesi gerekiyor."),
 q("I'm going to visit the hospital.", ["visit", "visits", "visiting"], "Hastaneyi ziyaret edeceğim."),
 q("They'll see the doctor at ten.", ["They'll", "They're", "They"], "Saat onda doktoru görecekler."),
 q("We're going to eat breakfast.", ["We're", "We'll", "We"], "Kahvaltı yapacağız."),
 q("Don't worry. I'll be fine.", ["I'll", "I'm", "I"], "Merak etme. İyi olacağım.", blank="I'll"),
 q("We are going to drive to the hospital.", ["going", "go", "goes"], "Hastaneye arabayla gideceğiz."),
 q("She isn't going to work today.", ["isn't", "aren't", "won't"], "Bugün çalışmayacak."),
 q("Does she have to work today?", ["Does", "Do", "Is"], "Bugün çalışması gerekiyor mu?"),
 q("He won't be late.", ["won't", "isn't will", "don't"], "Geç kalmayacak."),
]
for v in (quiz, quiz_b, quiz_c): assert len(v) == 10
lines = {  # captions / mission / narrator lines of the day-2 morning (TR shown only with the TR toggle)
 "Go to the living room.": "Oturma odasına git.",
 "Have breakfast with your family.": "Ailenle kahvaltı yap.",
 "Have breakfast.": "Kahvaltı yap.",
 "I am going to the living room.": "Oturma odasına gidiyorum.",
 "I am sitting at the table.": "Masada oturuyorum.",
 "I am having breakfast.": "Kahvaltı yapıyorum.",
 "Let's learn will, going to and have to.": "Hadi will, going to ve have to öğrenelim.",
 "Now the test. Ten questions.": "Şimdi test. On soru.",
 "Choose the right words.": "Doğru kelimeleri seç.",
 "That is right!": "Doğru!", "Not quite.": "Tam değil.",
 "You should study the grammar again.": "Dilbilgisi konusunu tekrar çalışmalısın.",
 "Breakfast is over.": "Kahvaltı bitti.",
 "The table is clearing itself.": "Masa kendiliğinden toplanıyor.",
 "Go outside to the car.": "Dışarı çık, arabaya git.",
 "Go to the car.": "Arabaya git.",
 "I am walking to my car.": "Arabama yürüyorum.",
}
for d in dialogue:
    if "tr" in d: lines[d["en"]] = d["tr"]
for h in have_to.values(): lines[h["en"]] = h["tr"]
out = {"label": "Will, going to, have to", "quiz_after": False, "lesson": lesson, "dialogue": dialogue, "have_to": have_to,
       "job_group": job_group, "quiz": quiz, "quiz_b": quiz_b, "quiz_c": quiz_c, "lines": lines}
json.dump(out, open(os.path.join(R, "data/day2_morning.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
print("ok")
