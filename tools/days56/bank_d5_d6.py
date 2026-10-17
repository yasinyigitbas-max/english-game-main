"""v33 (blue): the 60 day-5 / day-6 bedtime questions for red's shared TestBank (data/test_bank.json, 10 per version).
Writes data/test_bank_d5_d6.json (only these 60, for merging), appends them to data/test_bank.json (red's file from
english-game-red v33-days-4-7-red 6258836; the bank reads only that path), mirrors them into data/day5.json / day6.json
quiz / quiz_b / quiz_c (voice builder + script doc) and adds every `say` -> TR to their "lines".
Entry: [topic, q, [right, wrong, wrong], say, tr]."""
import json
D5 = [[  # v0
 ["describing_people", "He ___ short brown hair.", ["has got", "have got", "is got"], "He's got short brown hair.", "Kısa kahverengi saçları var."],
 ["describing_people", "What ___ she look like?", ["does", "is", "do"], "What does she look like?", "Neye benziyor?"],
 ["clothes", "He's ___ a yellow T-shirt.", ["wearing", "wear", "wears"], "He's wearing a yellow T-shirt.", "Sarı bir tişört giyiyor."],
 ["clothes", "Her shoes ___ red.", ["are", "is", "am"], "Her shoes are red.", "Ayakkabıları kırmızı."],
 ["asking_for_help", "Excuse me, ___ you help me?", ["can", "do", "are"], "Excuse me, can you help me?", "Affedersiniz, bana yardım edebilir misiniz?"],
 ["asking_for_help", "This boy ___ lost.", ["is", "are", "am"], "This boy is lost.", "Bu çocuk kaybolmuş."],
 ["reassuring", "Don't worry. ___ safe now.", ["You're", "Your", "You"], "Don't worry. You're safe now.", "Merak etme. Artık güvendesin."],
 ["reassuring", "It's OK. I'm ___.", ["here", "hear", "her"], "It's OK. I'm here.", "Sorun yok. Buradayım."],
 ["present_continuous", "Leo ___ near the door.", ["is crying", "cries", "crying"], "Leo's crying near the door.", "Leo kapının yanında ağlıyor."],
 ["present_continuous", "We ___ for his mum.", ["are looking", "is looking", "looking"], "We're looking for his mum.", "Annesini arıyoruz."]], [  # v1
 ["describing_people", "My sister ___ curly black hair.", ["has got", "have got", "is"], "My sister's got curly black hair.", "Kız kardeşimin kıvırcık siyah saçları var."],
 ["describing_people", "He ___ tall. He's short.", ["isn't", "aren't", "not"], "He isn't tall. He's short.", "Uzun boylu değil. Kısa boylu."],
 ["clothes", "Look! The man ___ a red coat.", ["is wearing", "wear", "are wearing"], "Look! The man's wearing a red coat.", "Bak! Adam kırmızı bir mont giyiyor."],
 ["clothes", "She ___ wearing a hat.", ["isn't", "aren't", "don't"], "She isn't wearing a hat.", "Şapka takmıyor."],
 ["asking_for_help", "Could you ___ me, please?", ["help", "helps", "helping"], "Could you help me, please?", "Bana yardım edebilir misiniz, lütfen?"],
 ["asking_for_help", "I ___ find my mum.", ["can't", "don't can", "not can"], "I can't find my mum.", "Annemi bulamıyorum."],
 ["reassuring", "Don't cry. Your mum ___ coming.", ["is", "are", "am"], "Don't cry. Your mum's coming.", "Ağlama. Annen geliyor."],
 ["reassuring", "Don't ___ scared.", ["be", "are", "is"], "Don't be scared.", "Korkma."],
 ["present_continuous", "I ___ wearing my blue jeans today.", ["am", "is", "are"], "I'm wearing my blue jeans today.", "Bugün mavi kotumu giyiyorum."],
 ["present_continuous", "What ___ you doing?", ["are", "do", "is"], "What are you doing?", "Ne yapıyorsun?"]], [  # v2
 ["describing_people", "They ___ got brown eyes.", ["have", "has", "is"], "They've got brown eyes.", "Kahverengi gözleri var."],
 ["describing_people", "How old ___ he?", ["is", "are", "has"], "How old is he?", "Kaç yaşında?"],
 ["clothes", "She ___ a green dress today.", ["is wearing", "wearing", "wear"], "She's wearing a green dress today.", "Bugün yeşil bir elbise giyiyor."],
 ["clothes", "His trousers ___ blue.", ["are", "is", "am"], "His trousers are blue.", "Pantolonu mavi."],
 ["asking_for_help", "Excuse me, ___ the shop assistant?", ["where's", "who's", "what's"], "Excuse me, where's the shop assistant?", "Affedersiniz, mağaza görevlisi nerede?"],
 ["asking_for_help", "___ I help you?", ["Can", "Do", "Am"], "Can I help you?", "Yardım edebilir miyim?"],
 ["reassuring", "It's OK. Don't ___.", ["worry", "worried", "worries"], "It's OK. Don't worry.", "Sorun yok. Merak etme."],
 ["reassuring", "You're very ___.", ["brave", "bravely", "braves"], "You're very brave.", "Çok cesursun."],
 ["present_continuous", "His mum ___ into the shop.", ["is running", "runs", "running"], "His mum's running into the shop.", "Annesi koşarak markete giriyor."],
 ["present_continuous", "They ___ crying now.", ["aren't", "isn't", "don't"], "They aren't crying now.", "Artık ağlamıyorlar."]]]
D6 = [[  # v0
 ["weather", "It's ___ today. Take an umbrella.", ["rainy", "sunny", "hot"], "It's rainy today. Take an umbrella.", "Bugün hava yağmurlu. Şemsiye al."],
 ["weather", "What's the weather ___?", ["like", "likes", "liking"], "What's the weather like?", "Hava nasıl?"],
 ["future_will", "I think it ___ rain tonight.", ["will", "is", "does"], "I think it'll rain tonight.", "Sanırım bu gece yağmur yağacak."],
 ["future_will", "I ___ call my family.", ["will", "am", "do"], "I'll call my family.", "Ailemi arayacağım."],
 ["going_to", "Look at those clouds! It ___ rain.", ["is going to", "going to", "goes to"], "Look at those clouds! It's going to rain.", "Şu bulutlara bak! Yağmur yağacak."],
 ["going_to", "We ___ going to wait here.", ["are", "is", "am"], "We're going to wait here.", "Burada bekleyeceğiz."],
 ["asking_for_help", "Excuse me, ___ the next bus?", ["when's", "who's", "what's"], "Excuse me, when's the next bus?", "Affedersiniz, bir sonraki otobüs ne zaman?"],
 ["asking_for_help", "___ you pick me up, please?", ["Can", "Do", "Are"], "Can you pick me up, please?", "Beni alabilir misin, lütfen?"],
 ["suggestions", "___ wait under the shelter.", ["Let's", "Let", "Lets"], "Let's wait under the shelter.", "Durağın altında bekleyelim."],
 ["suggestions", "Why ___ we call a taxi?", ["don't", "doesn't", "not"], "Why don't we call a taxi?", "Neden bir taksi çağırmıyoruz?"]], [  # v1
 ["weather", "It's very ___. My umbrella's flying away!", ["windy", "sunny", "snowy"], "It's very windy. My umbrella's flying away!", "Hava çok rüzgarlı. Şemsiyem uçuyor!"],
 ["weather", "It's cold and white outside. It's ___.", ["snowy", "sunny", "hot"], "It's cold and white outside. It's snowy.", "Dışarısı soğuk ve beyaz. Hava karlı."],
 ["future_will", "Don't worry. I ___ help you.", ["will", "am", "do"], "Don't worry. I'll help you.", "Merak etme. Sana yardım edeceğim."],
 ["future_will", "The bus ___ come for forty minutes.", ["won't", "willn't", "doesn't will"], "The bus won't come for forty minutes.", "Otobüs kırk dakika gelmeyecek."],
 ["going_to", "I'm ___ take a taxi.", ["going to", "go to", "going"], "I'm going to take a taxi.", "Taksiye bineceğim."],
 ["going_to", "___ you going to walk home?", ["Are", "Do", "Is"], "Are you going to walk home?", "Eve yürüyecek misin?"],
 ["asking_for_help", "Excuse me, ___ the bus broken?", ["is", "does", "are"], "Excuse me, is the bus broken?", "Affedersiniz, otobüs bozuk mu?"],
 ["asking_for_help", "Could you ___ my dad, please?", ["call", "calls", "calling"], "Could you call my dad, please?", "Babamı arayabilir misiniz, lütfen?"],
 ["suggestions", "How about ___ your family?", ["calling", "call", "to call"], "How about calling your family?", "Aileni aramaya ne dersin?"],
 ["suggestions", "We ___ stay dry.", ["should", "should to", "shoulds"], "We should stay dry.", "Kuru kalmalıyız."]], [  # v2
 ["weather", "I can hear thunder. It's ___!", ["stormy", "sunny", "warm"], "I can hear thunder. It's stormy!", "Gök gürültüsü duyuyorum. Hava fırtınalı!"],
 ["weather", "It's ___ and hot. Let's go to the beach!", ["sunny", "rainy", "stormy"], "It's sunny and hot. Let's go to the beach!", "Hava güneşli ve sıcak. Hadi plaja gidelim!"],
 ["future_will", "Mum ___ pick us up.", ["will", "is", "does"], "Mum will pick us up.", "Annem bizi alacak."],
 ["future_will", "___ the storm stop soon?", ["Will", "Does", "Is"], "Will the storm stop soon?", "Fırtına yakında dinecek mi?"],
 ["going_to", "They ___ going to walk in the rain.", ["aren't", "isn't", "not"], "They aren't going to walk in the rain.", "Yağmurda yürümeyecekler."],
 ["going_to", "What ___ you going to do?", ["are", "do", "is"], "What are you going to do?", "Ne yapacaksın?"],
 ["asking_for_help", "Can you help me? Yes, I ___.", ["can", "do", "am"], "Can you help me? Yes, I can.", "Bana yardım edebilir misin? Evet, edebilirim."],
 ["asking_for_help", "How long ___ we have to wait?", ["do", "does", "are"], "How long do we have to wait?", "Ne kadar beklememiz gerekiyor?"],
 ["suggestions", "Let's ___ walk. It's too far.", ["not", "don't", "no"], "Let's not walk. It's too far.", "Yürümeyelim. Çok uzak."],
 ["suggestions", "You ___ walk in a storm.", ["shouldn't", "should to", "not should"], "You shouldn't walk in a storm.", "Fırtınada yürümemelisin."]]]
TOPICS = {"describing_people": "Describing people", "clothes": "Clothes (wearing)", "asking_for_help": "Asking for help",
          "reassuring": "Reassuring someone", "present_continuous": "Present continuous", "weather": "Weather",
          "future_will": "Future: will / won't", "going_to": "Future: going to", "suggestions": "Suggestions (Let's, Why don't we, How about, should)"}
ent = []
for day, V in ((5, D5), (6, D6)):
    n = 0
    for v, qs in enumerate(V):
        assert len(qs) == 10
        for t, q, o, s, tr in qs:
            n += 1; assert "___" in q and len(o) == 3
            ent.append({"id": "d%d_%02d" % (day, n), "day": day, "v": v, "topic": t, "q": q, "opts": o, "a": 0, "say": s, "tr": tr})
json.dump({"_doc": "v33 (blue): day 5 + day 6 entries for data/test_bank.json (same format; also appended there).", "topics": TOPICS, "questions": ent},
          open("data/test_bank_d5_d6.json", "w"), ensure_ascii=False, indent=1)
tb = json.load(open("data/test_bank.json"))
tb["questions"] = [q for q in tb["questions"] if q["day"] not in (5, 6)] + ent
for k, v in TOPICS.items(): tb["topics"].setdefault(k, v)
json.dump(tb, open("data/test_bank.json", "w"), ensure_ascii=False, indent=1)
for day in (5, 6):
    p = "data/day%d.json" % day; d = json.load(open(p))
    mine = [e for e in ent if e["day"] == day]
    for v, k in enumerate(("quiz", "quiz_b", "quiz_c")):
        d[k] = [{kk: e[kk] for kk in ("q", "opts", "a", "say", "tr", "topic")} for e in mine if e["v"] == v]
    d["bank_topics"] = sorted({e["topic"] for e in mine})
    for e in mine: d["lines"][e["say"]] = e["tr"]
    json.dump(d, open(p, "w"), ensure_ascii=False, indent=1)
print(len(ent), "entries;", len(tb["questions"]), "in test_bank.json")
