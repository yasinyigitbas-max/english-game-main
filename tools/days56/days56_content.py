"""Days 5 + 6 content -> data/day5.json, data/day6.json (+ docs/DAYS_5_6_SCRIPT.md via make_script_doc.py).
# NOTE: after re-running this, run tools/days56/bank_d5_d6.py (it writes the bedtime quiz_* / bank entries into data/day5.json + day6.json).
Step types (read by scripts/story/day5_common.gd run_steps):
  {"who": me|narr|fam0|fam1|<npc>, "en", "tr"}   a line (me = "Me:" caption, narrator voice; narr = plain caption)
  {"obj": tag, "en", "tr"}                         an objective: Life.guide_to(ctx target(tag)) + wait for ctx reach(tag)
  {"choice": {...}}                                choice panel (prompt, options with feedback, retry until the right one)
  {"do": tag}                                      a scripted action in the day's code (spawn, walk, sfx, photo ...)
  {"review": true}                                 the breakfast review questions ("review")
Run: python3 tools/days56/days56_content.py"""
import json, os
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def L(who, en, tr): return {"who": who, "en": en, "tr": tr}
def O(tag, en, tr): return {"obj": tag, "en": en, "tr": tr}
def D(tag): return {"do": tag}
def opt(en, tr, ok=False, fb="", fb_tr="", do=""):
    o = {"en": en, "tr": tr, "ok": ok}
    if fb: o["fb"] = fb; o["fb_tr"] = fb_tr
    if do: o["do"] = do
    return o
def C(prompt, prompt_tr, opts, **kw): return {"choice": dict({"prompt": prompt, "prompt_tr": prompt_tr, "opts": opts}, **kw)}
def Q(q, opts, say, tr): return {"q": q, "opts": opts, "a": 0, "say": say, "tr": tr}

COMMON_LINES = {
    "It is a new day.": "Yeni bir gün.", "My alarm is ringing.": "Alarmım çalıyor.", "I am turning off the alarm.": "Alarmı kapatıyorum.",
    "Turn off the alarm.": "Alarmı kapat.", "Go to the bathroom.": "Banyoya git.", "Go to the living room.": "Oturma odasına git.",
    "Have breakfast with your family.": "Ailenle kahvaltı yap.", "Have breakfast.": "Kahvaltı yap.",
    "I am sitting at the table.": "Masada oturuyorum.", "I am having breakfast.": "Kahvaltı yapıyorum.",
    "Let's do a quick review at the table.": "Masada kısa bir tekrar yapalım.", "Choose the right words.": "Doğru kelimeleri seç.",
    "That is right!": "Doğru!", "Not quite.": "Tam değil.", "Breakfast is over.": "Kahvaltı bitti.", "The table is clearing itself.": "Masa kendi kendine toplanıyor.",
    "Go outside.": "Dışarı çık.", "Go home.": "Eve git.", "Go inside.": "İçeri gir.", "Talk to your family.": "Ailenle konuş.",
    "I am sitting on the sofa.": "Kanepede oturuyorum.", "Go to bed.": "Yatmaya git.", "I am going to bed.": "Yatmaya gidiyorum.",
    "I am lying in bed.": "Yatakta yatıyorum.", "Look at the photos of your day.": "Gününün fotoğraflarına bak.",
    "I am dreaming about my day.": "Günümü rüyamda görüyorum.", "Take the bedtime test.": "Yatmadan önce testi çöz.",
    "Now the bedtime test. Ten questions.": "Şimdi yatmadan önceki test. On soru.", "Good night!": "İyi geceler!", "I am sleeping.": "Uyuyorum.",
    "I had breakfast with my family.": "Ailemle kahvaltı yaptım.", "I talked to my family.": "Ailemle konuştum.",
    "Get a notebook and a pencil. Let's take notes.": "Bir defter ve kalem al. Hadi not alalım.", "You should study the grammar again.": "Dilbilgisi konusunu tekrar çalışmalısın.",
    "I am getting up.": "Kalkıyorum.", "I feel fresh and clean.": "Kendimi temiz ve zinde hissediyorum.",
    "Day 5": "5. Gün", "Day 6": "6. Gün", "Day 7": "7. Gün", "Me": "Ben",
}

# ----------------------------------------------------------------------------------------------------------- DAY 5
D5 = {
    "day": 5, "test_key": "Day5Bed", "bank_topics": ["describing_people", "clothes_present_continuous", "asking_for_help", "past_simple"],
    "alarm_after": L("me", "Good morning! I'm going to the corner shop today.", "Günaydın! Bugün köşedeki markete gidiyorum."),
    "bath": {"obj": "sink", "key": "routine", "en": "Wash your face and brush your teeth.", "tr": "Yüzünü yıka ve dişlerini fırçala.",
             "done": L("me", "I feel fresh now.", "Şimdi kendimi zinde hissediyorum.")},
    "breakfast": [
        L("fam0", "Morning! Did you sleep well?", "Günaydın! İyi uyudun mu?"),
        L("me", "Yes, thanks. I slept really well.", "Evet, teşekkürler. Çok iyi uyudum."),
        L("fam1", "We're out of milk and bread. Can you go to the corner shop today?", "Süt ve ekmeğimiz bitti. Bugün köşedeki markete gidebilir misin?"),
        L("me", "Sure, no problem. I'll go after breakfast.", "Tabii, sorun değil. Kahvaltıdan sonra giderim."),
        L("fam0", "Thanks! Here's a shopping bag.", "Teşekkürler! Al, bir alışveriş çantası."),
        {"review": True},
    ],
    "review": [
        Q("Every morning I ___ breakfast with my family.", ["have", "am having", "had"], "Every morning I have breakfast with my family.", "Her sabah ailemle kahvaltı yaparım."),
        Q("Look! The cat ___ my toast!", ["is eating", "eats", "ate"], "Look! The cat is eating my toast!", "Bak! Kedi tostumu yiyor!"),
        Q("We're out of milk. I ___ go to the shop.", ["have to", "has to", "having to"], "We're out of milk. I have to go to the shop.", "Sütümüz bitti. Markete gitmem gerekiyor."),
    ],
    "outing": O("shop", "Walk to the corner shop.", "Köşedeki markete yürü."),
    "event": [
        D("child_appears"),
        L("narr", "Oh! A little boy is crying near the door.", "Aa! Kapının yanında küçük bir çocuk ağlıyor."),
        O("child", "Help the little boy.", "Küçük çocuğa yardım et."),
        C("What do you say to the boy?", "Çocuğa ne dersin?", [
            opt("Hi! Are you OK?", "Merhaba! İyi misin?", True),
            opt("Stop crying!", "Ağlamayı kes!", fb="That isn't kind. He's scared.", fb_tr="Bu nazik değil. Çok korkmuş."),
            opt("Where's your phone?", "Telefonun nerede?", fb="He's very young. Ask if he's OK first.", fb_tr="O çok küçük. Önce iyi olup olmadığını sor."),
        ]),
        L("child", "No... I can't find my mum.", "Hayır... Annemi bulamıyorum."),
        L("me", "Oh no. What's your name?", "Olamaz. Adın ne?"),
        L("child", "I'm Leo.", "Ben Leo."),
        L("me", "Hi, Leo. Don't worry. I'm going to help you.", "Merhaba Leo. Merak etme. Sana yardım edeceğim."),
        O("assistant", "Ask the shop assistant for help.", "Mağaza görevlisinden yardım iste."),
        D("walk_to_assistant"),
        C("What do you say to the shop assistant?", "Mağaza görevlisine ne dersin?", [
            opt("Excuse me, can you help us? This boy is lost.", "Affedersiniz, bize yardım edebilir misiniz? Bu çocuk kaybolmuş.", True),
            opt("Can I have a bag, please?", "Bir poşet alabilir miyim, lütfen?", fb="That's not the problem right now. The boy is lost.", fb_tr="Şu an sorun bu değil. Çocuk kaybolmuş."),
            opt("How much is the bread?", "Ekmek ne kadar?", fb="Not now! Tell the assistant about the lost boy.", fb_tr="Şimdi değil! Görevliye kayıp çocuktan bahset."),
        ]),
        L("assistant", "Oh dear! Of course. I'm going to make an announcement. Can you describe him for me?", "Aman! Tabii ki. Bir anons yapacağım. Onu bana tarif edebilir misin?"),
        D("look_at_child"),
        C("Describe the boy.", "Çocuğu tarif et.", [
            opt("He's about five. He's got short brown hair.", "Yaklaşık beş yaşında. Kısa kahverengi saçları var.", True),
            opt("He's about five. He's got long blond hair.", "Yaklaşık beş yaşında. Uzun sarı saçları var.", fb="Look again. His hair is short and brown.", fb_tr="Tekrar bak. Saçı kısa ve kahverengi."),
            opt("He's very old. He's got a big beard.", "Çok yaşlı. Büyük bir sakalı var.", fb="No! He's a little boy.", fb_tr="Hayır! O küçük bir çocuk."),
        ]),
        L("assistant", "Great. And what's he wearing?", "Harika. Peki ne giyiyor?"),
        C("What's he wearing?", "Ne giyiyor?", [
            opt("He's wearing a yellow T-shirt.", "Sarı bir tişört giyiyor.", True),
            opt("He's wearing a red coat.", "Kırmızı bir mont giyiyor.", fb="Look again. His T-shirt is yellow.", fb_tr="Tekrar bak. Tişörtü sarı."),
            opt("He's wearing a green hat.", "Yeşil bir şapka takıyor.", fb="Look again. He isn't wearing a hat.", fb_tr="Tekrar bak. Şapka takmıyor."),
        ]),
        D("announce"),
        L("assistant", "Attention, please! We've got a little boy called Leo at the front of the shop. He's about five, and he's wearing a yellow T-shirt.",
          "Dikkat lütfen! Mağazanın önünde Leo adında küçük bir çocuk var. Yaklaşık beş yaşında ve sarı bir tişört giyiyor."),
        L("child", "I'm scared.", "Korkuyorum."),
        O("child", "Help Leo feel better.", "Leo'nun kendini daha iyi hissetmesine yardım et."),
        C("What do you say to Leo?", "Leo'ya ne dersin?", [
            opt("It's OK, Leo. Your mum's coming soon.", "Sorun yok Leo. Annen birazdan gelir.", True),
            opt("I'm going home now. Bye!", "Ben şimdi eve gidiyorum. Hoşça kal!", fb="Don't leave him alone! Stay with him.", fb_tr="Onu yalnız bırakma! Yanında kal."),
            opt("Your mum isn't coming.", "Annen gelmiyor.", fb="That isn't kind. Say something nice.", fb_tr="Bu nazik değil. Güzel bir şey söyle."),
        ]),
        L("child", "OK. Thank you.", "Tamam. Teşekkür ederim."),
        D("mum_enters"),
        L("narr", "A woman is running into the shop.", "Bir kadın koşarak markete giriyor."),
        L("mum", "Excuse me! I'm looking for my little boy!", "Affedersiniz! Küçük oğlumu arıyorum!"),
        O("mum", "Find Leo's mum.", "Leo'nun annesini bul."),
        C("What do you ask her?", "Ona ne sorarsın?", [
            opt("What's his name?", "Adı ne?", True),
            opt("What's your favourite colour?", "En sevdiğin renk ne?", fb="That doesn't help. Ask about her son.", fb_tr="Bu yardımcı olmaz. Oğlunu sor."),
            opt("Do you like this shop?", "Bu marketi seviyor musun?", fb="Not now! Ask about her son.", fb_tr="Şimdi değil! Oğlunu sor."),
        ]),
        L("mum", "Leo. He's five, and he's wearing a yellow T-shirt.", "Leo. Beş yaşında ve sarı bir tişört giyiyor."),
        L("me", "He's here! He's safe.", "Burada! O güvende."),
        D("reunite"),
        L("child", "Mum!", "Anne!"),
        L("mum", "Leo! There you are! I was so worried.", "Leo! İşte buradasın! Çok endişelendim."),
        L("narr", "Leo is hugging his mum.", "Leo annesine sarılıyor."),
        D("photo"),
        L("mum", "Thank you so much for helping him!", "Ona yardım ettiğin için çok teşekkür ederim!"),
        L("me", "You're welcome. Bye, Leo!", "Rica ederim. Hoşça kal, Leo!"),
        L("child", "Bye! Thank you!", "Hoşça kal! Teşekkürler!"),
        L("assistant", "Well done. That was really kind of you.", "Aferin. Çok nazik davrandın."),
        L("narr", "Well done! You helped Leo find his mum.", "Aferin! Leo'nun annesini bulmasına yardım ettin."),
        D("npcs_leave"),
    ],
    "couch": [
        L("fam0", "You're back! How was the shop?", "Döndün! Market nasıldı?"),
        L("me", "It was quite an adventure!", "Tam bir maceraydı!"),
        C("Tell your family what happened.", "Ailene ne olduğunu anlat.", [
            opt("A little boy got lost in the shop.", "Markette küçük bir çocuk kayboldu.", True),
            opt("A little boy gets lost in the shop.", "Markette küçük bir çocuk kaybolur.", fb="It happened today, so use the past simple: got lost.", fb_tr="Bugün oldu, o yüzden geçmiş zaman kullan: got lost."),
            opt("A little boy is get lost in the shop.", "Markette küçük bir çocuk kayboluyor.", fb="Use the past simple: got lost.", fb_tr="Geçmiş zaman kullan: got lost."),
        ]),
        L("fam1", "Oh no! Is he OK?", "Olamaz! O iyi mi?"),
        C("Answer your family.", "Ailene cevap ver.", [
            opt("Yes. We found his mum.", "Evet. Annesini bulduk.", True),
            opt("Yes. We find his mum.", "Evet. Annesini buluruz.", fb="Use the past simple: find becomes found.", fb_tr="Geçmiş zaman kullan: find -> found."),
            opt("Yes. We finded his mum.", "Evet. Annesini bulduk.", fb="Find is irregular: found, not finded.", fb_tr="Find düzensiz bir fiil: finded değil, found."),
        ]),
        L("fam0", "Well done! That was really kind of you.", "Aferin! Çok nazik davrandın."),
        L("fam1", "Did you get the milk and bread?", "Süt ve ekmeği aldın mı?"),
        L("me", "Yes, I did. They're in the kitchen.", "Evet, aldım. Mutfaktalar."),
        D("photo"),
        L("fam0", "You must be tired. Time for bed!", "Yorgun olmalısın. Yatma vakti!"),
        L("me", "Good night!", "İyi geceler!"),
    ],
    "recap": [["d5_breakfast", "I had breakfast with my family."], ["d5_shop", "I helped a lost boy at the shop."], ["d5_couch", "I talked to my family."]],
    "recap_end": L("narr", "Helped, found, talked: this is the past simple.", "Helped, found, talked: bu geçmiş zaman."),
    "quiz": [
        Q("He ___ short brown hair.", ["has got", "have got", "is got"], "He has got short brown hair.", "Kısa kahverengi saçları var."),
        Q("Leo ___ a yellow T-shirt today.", ["is wearing", "wears", "wearing"], "Leo is wearing a yellow T-shirt today.", "Leo bugün sarı bir tişört giyiyor."),
        Q("___ you help me, please?", ["Can", "Do", "Are"], "Can you help me, please?", "Bana yardım edebilir misiniz, lütfen?"),
        Q("Yesterday I ___ a lost boy.", ["helped", "help", "helps"], "Yesterday I helped a lost boy.", "Dün kaybolmuş bir çocuğa yardım ettim."),
        Q("We ___ his mum near the door.", ["found", "finded", "find"], "We found his mum near the door.", "Annesini kapının yanında bulduk."),
        Q("What ___ she look like?", ["does", "is", "do"], "What does she look like?", "Görünüşü nasıl?"),
        Q("She's got long hair ___ blue eyes.", ["and", "but", "or"], "She's got long hair and blue eyes.", "Uzun saçları ve mavi gözleri var."),
        Q("Don't worry. Your mum ___ coming.", ["is", "are", "am"], "Don't worry. Your mum is coming.", "Merak etme. Annen geliyor."),
        Q("Excuse me, ___ is the checkout?", ["where", "who", "what"], "Excuse me, where is the checkout?", "Affedersiniz, kasa nerede?"),
        Q("The boy ___ scared, but now he's happy.", ["was", "were", "is"], "The boy was scared, but now he's happy.", "Çocuk korkmuştu ama şimdi mutlu."),
    ],
    "quiz_b": [
        Q("My sister ___ curly black hair.", ["has got", "have got", "is"], "My sister has got curly black hair.", "Kız kardeşimin kıvırcık siyah saçları var."),
        Q("Look! The man ___ a red coat.", ["is wearing", "wear", "are wearing"], "Look! The man is wearing a red coat.", "Bak! Adam kırmızı bir mont giyiyor."),
        Q("Could you ___ me, please?", ["help", "helps", "helping"], "Could you help me, please?", "Bana yardım edebilir misiniz, lütfen?"),
        Q("I ___ to the corner shop yesterday.", ["went", "go", "goed"], "I went to the corner shop yesterday.", "Dün köşedeki markete gittim."),
        Q("Yesterday the little boy ___ for his mum.", ["looked", "look", "looks"], "Yesterday the little boy looked for his mum.", "Dün küçük çocuk annesini aradı."),
        Q("He's tall ___ he's got glasses.", ["and", "or", "but"], "He's tall and he's got glasses.", "Uzun boylu ve gözlüğü var."),
        Q("___ is your name?", ["What", "Where", "How"], "What is your name?", "Adın ne?"),
        Q("I ___ wearing my blue jeans now.", ["am", "is", "are"], "I am wearing my blue jeans now.", "Şu an mavi kot pantolonumu giyiyorum."),
        Q("Thank you so much! You're ___.", ["welcome", "welcomed", "welcomes"], "Thank you so much! You're welcome.", "Çok teşekkür ederim! Rica ederim."),
        Q("The shop assistant ___ very kind.", ["was", "were", "are"], "The shop assistant was very kind.", "Mağaza görevlisi çok nazikti."),
    ],
    "quiz_c": [
        Q("They ___ got brown eyes.", ["have", "has", "is"], "They have got brown eyes.", "Kahverengi gözleri var."),
        Q("She ___ a green dress today.", ["is wearing", "wearing", "wear"], "She is wearing a green dress today.", "Bugün yeşil bir elbise giyiyor."),
        Q("Excuse me, can you ___ me?", ["help", "to help", "helped"], "Excuse me, can you help me?", "Affedersiniz, bana yardım edebilir misiniz?"),
        Q("Leo ___ his mum in the shop.", ["lost", "losed", "loses"], "Leo lost his mum in the shop.", "Leo markette annesini kaybetti."),
        Q("His mum ___ into the shop.", ["ran", "runned", "run"], "His mum ran into the shop.", "Annesi koşarak markete girdi."),
        Q("How old ___ he?", ["is", "are", "am"], "How old is he?", "Kaç yaşında?"),
        Q("He ___ about five years old.", ["is", "has", "does"], "He is about five years old.", "Yaklaşık beş yaşında."),
        Q("We ___ wearing coats because it's cold.", ["are", "is", "am"], "We are wearing coats because it's cold.", "Hava soğuk olduğu için mont giyiyoruz."),
        Q("Don't cry. ___ OK.", ["It's", "Its", "It"], "Don't cry. It's OK.", "Ağlama. Sorun yok."),
        Q("We ___ happy at the end.", ["were", "was", "are"], "We were happy at the end.", "Sonunda mutluyduk."),
    ],
    "speakers": {"child": ["Boy", "Çocuk", "child_m"], "mum": ["Woman", "Kadın", "amy"], "assistant": ["Shop assistant", "Görevli", "joe"]},
}

# ----------------------------------------------------------------------------------------------------------- DAY 6
D6 = {
    "day": 6, "test_key": "Day6Bed", "bank_topics": ["weather", "past_simple_irregular", "going_to", "should", "asking_for_help"],
    "alarm_after": L("me", "Good morning! I'm taking the bus into town today.", "Günaydın! Bugün otobüsle şehre gidiyorum."),
    "bath": {"obj": "bath", "key": "takeshower", "en": "Take a shower.", "tr": "Duş al.",
             "done": L("me", "I feel fresh and clean.", "Kendimi temiz ve zinde hissediyorum.")},
    "breakfast": [
        L("fam0", "Morning! Look outside. It's really cloudy today.", "Günaydın! Dışarı bak. Bugün hava çok bulutlu."),
        L("me", "Yeah. I'm taking the bus into town later.", "Evet. Sonra otobüsle şehre gidiyorum."),
        L("fam1", "The forecast says there's going to be a storm this afternoon.", "Hava durumu bu öğleden sonra fırtına olacağını söylüyor."),
        L("me", "Really? Then I'll take my umbrella.", "Gerçekten mi? O zaman şemsiyemi alırım."),
        L("fam0", "Good idea. And call us if you need anything.", "İyi fikir. Bir şeye ihtiyacın olursa bizi ara."),
        {"review": True},
    ],
    "review": [
        Q("Yesterday I ___ a lost boy at the shop.", ["helped", "help", "helping"], "Yesterday I helped a lost boy at the shop.", "Dün markette kaybolmuş bir çocuğa yardım ettim."),
        Q("It's going to rain. You ___ take an umbrella.", ["should", "shoulds", "to should"], "It's going to rain. You should take an umbrella.", "Yağmur yağacak. Şemsiye almalısın."),
        Q("Look at those dark clouds! It ___ rain.", ["is going to", "going to", "are going to"], "Look at those dark clouds! It's going to rain.", "Şu kara bulutlara bak! Yağmur yağacak."),
    ],
    "outing": O("stop", "Go to the bus stop.", "Otobüs durağına git."),
    "event": [
        D("storm_start"),
        L("narr", "The sky is getting dark.", "Gökyüzü kararıyor."),
        D("thunder"),
        L("narr", "The wind is blowing, and it's starting to rain.", "Rüzgar esiyor ve yağmur başlıyor."),
        D("woman_appears"),
        L("woman", "Wow, what terrible weather!", "Vay, ne kötü bir hava!"),
        O("woman", "Talk about the weather.", "Hava hakkında konuş."),
        C("What do you say about the weather?", "Hava hakkında ne dersin?", [
            opt("I know! It's really windy, and it's raining hard.", "Biliyorum! Çok rüzgarlı ve şiddetli yağmur yağıyor.", True),
            opt("Yes, it's sunny and hot today.", "Evet, bugün hava güneşli ve sıcak.", fb="Look at the sky! It isn't sunny.", fb_tr="Gökyüzüne bak! Hava güneşli değil."),
            opt("It's snowing a lot.", "Çok kar yağıyor.", fb="Look again. It's raining, not snowing.", fb_tr="Tekrar bak. Kar değil, yağmur yağıyor."),
        ]),
        L("woman", "Good thing the bus is coming soon.", "İyi ki otobüs birazdan geliyor."),
        D("bus_arrives"),
        L("narr", "The bus is coming.", "Otobüs geliyor."),
        D("bus_breaks"),
        L("narr", "Oh no! The bus is making a strange noise.", "Olamaz! Otobüs garip bir ses çıkarıyor."),
        L("driver", "Sorry, everyone! The bus has broken down. The engine isn't working.", "Herkesten özür dilerim! Otobüs bozuldu. Motor çalışmıyor."),
        O("driver", "Ask the driver for help.", "Şoförden yardım iste."),
        C("What do you ask the driver?", "Şoföre ne sorarsın?", [
            opt("Excuse me, when's the next bus?", "Affedersiniz, bir sonraki otobüs ne zaman?", True),
            opt("Can I drive the bus?", "Otobüsü ben sürebilir miyim?", fb="No, you can't! Ask about the next bus.", fb_tr="Hayır, süremezsin! Bir sonraki otobüsü sor."),
            opt("Why is the sky grey?", "Gökyüzü neden gri?", fb="That doesn't help. Ask the driver about the next bus.", fb_tr="Bu yardımcı olmaz. Şoföre bir sonraki otobüsü sor."),
        ]),
        L("driver", "The next bus is coming in about forty minutes. I'm really sorry.", "Bir sonraki otobüs yaklaşık kırk dakika sonra geliyor. Gerçekten üzgünüm."),
        L("me", "That's OK. It isn't your fault.", "Sorun değil. Sizin suçunuz değil."),
        O("shelter", "Wait under the bus shelter.", "Otobüs durağının altında bekle."),
        D("wait"),
        L("narr", "I'm waiting at the bus stop. It's raining really hard.", "Otobüs durağında bekliyorum. Çok şiddetli yağmur yağıyor."),
        D("time_skip"),
        L("narr", "Ten minutes later...", "On dakika sonra..."),
        L("woman", "This is taking so long. What are you going to do?", "Bu çok uzun sürüyor. Sen ne yapacaksın?"),
        O("me", "Choose what to do.", "Ne yapacağını seç."),
        C("What are you going to do?", "Ne yapacaksın?", [
            opt("I'm going to walk home.", "Eve yürüyeceğim.", fb="Hmm, it's very windy and wet. Walking isn't a good idea right now.", fb_tr="Hmm, hava çok rüzgarlı ve ıslak. Şu an yürümek iyi bir fikir değil."),
            opt("I'm going to call a taxi.", "Taksi çağıracağım.", do="taxi", fb="There aren't any taxis right now. Try something else.", fb_tr="Şu an hiç taksi yok. Başka bir şey dene."),
            opt("I'm going to call my family.", "Ailemi arayacağım.", True),
        ], remove_wrong=True),
        D("phone_out"),
        L("narr", "I'm calling my family.", "Ailemi arıyorum."),
        L("famcall", "Hi! Is everything OK?", "Merhaba! Her şey yolunda mı?"),
        L("me", "Not really. The bus broke down, and it's raining a lot. Can you pick me up?", "Pek değil. Otobüs bozuldu ve çok yağmur yağıyor. Beni alabilir misin?"),
        L("famcall", "Of course! Stay at the bus stop. I'm coming right now.", "Tabii ki! Otobüs durağında kal. Hemen geliyorum."),
        L("me", "Thanks! See you soon.", "Teşekkürler! Görüşürüz."),
        D("phone_away"),
        L("woman", "Lucky you! I'm going to call my husband, too.", "Ne şanslısın! Ben de kocamı arayacağım."),
        D("photo"),
        L("narr", "My family is coming to pick me up.", "Ailem beni almaya geliyor."),
        D("ride_home"),
        L("me", "I'm home again. I'm wet, but I'm safe.", "Yine evdeyim. Islağım ama güvendeyim."),
    ],
    "taxi": [
        L("narr", "I'm calling a taxi.", "Taksi çağırıyorum."),
        L("taxi", "Sorry, all our taxis are busy because of the storm.", "Üzgünüz, fırtına yüzünden bütün taksilerimiz dolu."),
    ],
    "couch": [
        L("fam0", "Come and sit down. You're still wet!", "Gel otur. Hâlâ ıslaksın!"),
        L("me", "What a day!", "Ne gün ama!"),
        L("fam1", "Tell us! What happened?", "Anlat bize! Ne oldu?"),
        C("Tell your family what happened.", "Ailene ne olduğunu anlat.", [
            opt("The bus broke down in the storm.", "Otobüs fırtınada bozuldu.", True),
            opt("The bus breaks down in the storm.", "Otobüs fırtınada bozulur.", fb="It happened today. Use the past simple: broke down.", fb_tr="Bugün oldu. Geçmiş zaman kullan: broke down."),
            opt("The bus breaked down in the storm.", "Otobüs fırtınada bozuldu.", fb="Break is irregular: broke, not breaked.", fb_tr="Break düzensiz bir fiil: breaked değil, broke."),
        ]),
        L("fam0", "Oh no! Were you scared?", "Olamaz! Korktun mu?"),
        C("Answer your family.", "Ailene cevap ver.", [
            opt("A little, but I was OK.", "Biraz, ama iyiydim.", True),
            opt("A little, but I were OK.", "Biraz, ama iyiydim.", fb="With I, we say was: I was OK.", fb_tr="I ile was kullanırız: I was OK."),
            opt("A little, but I am OK yesterday.", "Biraz, ama dün iyiyim.", fb="Use was for the past: I was OK.", fb_tr="Geçmiş için was kullan: I was OK."),
        ]),
        L("fam1", "You did the right thing. You called us.", "Doğru olanı yaptın. Bizi aradın."),
        D("photo"),
        L("fam0", "Let's have some hot tea. Then it's time for bed.", "Biraz sıcak çay içelim. Sonra yatma vakti."),
        L("me", "Good night!", "İyi geceler!"),
    ],
    "recap": [["d6_breakfast", "I had breakfast with my family."], ["d6_storm", "I waited for the bus in the storm."], ["d6_couch", "I talked to my family."]],
    "recap_end": L("narr", "Broke, waited, called: this is the past simple.", "Broke, waited, called: bu geçmiş zaman."),
    "quiz": [
        Q("It's ___ today. Take an umbrella.", ["rainy", "sunny", "hot"], "It's rainy today. Take an umbrella.", "Bugün hava yağmurlu. Şemsiye al."),
        Q("Look at the clouds! It ___ rain.", ["is going to", "going to", "goes to"], "Look at the clouds! It's going to rain.", "Bulutlara bak! Yağmur yağacak."),
        Q("The bus ___ down yesterday.", ["broke", "breaked", "breaks"], "The bus broke down yesterday.", "Otobüs dün bozuldu."),
        Q("You ___ stay inside in a storm.", ["should", "shoulds", "to should"], "You should stay inside in a storm.", "Fırtınada içeride kalmalısın."),
        Q("When ___ the next bus?", ["is", "are", "do"], "When is the next bus?", "Bir sonraki otobüs ne zaman?"),
        Q("I ___ at the bus stop for forty minutes.", ["waited", "waits", "waiting"], "I waited at the bus stop for forty minutes.", "Otobüs durağında kırk dakika bekledim."),
        Q("It's very ___. My umbrella is flying away!", ["windy", "sunny", "snowy"], "It's very windy. My umbrella is flying away!", "Hava çok rüzgarlı. Şemsiyem uçuyor!"),
        Q("___ you pick me up, please?", ["Can", "Do", "Are"], "Can you pick me up, please?", "Beni alabilir misin, lütfen?"),
        Q("Yesterday I ___ my family.", ["called", "call", "calls"], "Yesterday I called my family.", "Dün ailemi aradım."),
        Q("We ___ wet, but we were safe.", ["were", "was", "are"], "We were wet, but we were safe.", "Islaktık ama güvendeydik."),
    ],
    "quiz_b": [
        Q("It's cold and white outside. It's ___.", ["snowy", "sunny", "hot"], "It's cold and white outside. It's snowy.", "Dışarısı soğuk ve bembeyaz. Hava karlı."),
        Q("I'm ___ take a taxi.", ["going to", "go to", "going"], "I'm going to take a taxi.", "Taksiye bineceğim."),
        Q("The driver ___ sorry.", ["was", "were", "is"], "The driver was sorry.", "Şoför üzgündü."),
        Q("It's raining. You ___ walk home.", ["shouldn't", "should to", "not should"], "It's raining. You shouldn't walk home.", "Yağmur yağıyor. Eve yürümemelisin."),
        Q("Excuse me, ___ can I get a taxi?", ["where", "who", "what"], "Excuse me, where can I get a taxi?", "Affedersiniz, nereden taksi bulabilirim?"),
        Q("My dad ___ me up in the car.", ["picked", "pick", "picks"], "My dad picked me up in the car.", "Babam beni arabayla aldı."),
        Q("What's the weather ___ today?", ["like", "likes", "liking"], "What's the weather like today?", "Bugün hava nasıl?"),
        Q("There ___ a big storm yesterday.", ["was", "were", "is"], "There was a big storm yesterday.", "Dün büyük bir fırtına vardı."),
        Q("Don't worry. I ___ coming now.", ["am", "is", "are"], "Don't worry. I am coming now.", "Merak etme. Hemen geliyorum."),
        Q("We ___ hot tea at home.", ["drank", "drinked", "drinks"], "We drank hot tea at home.", "Evde sıcak çay içtik."),
    ],
    "quiz_c": [
        Q("It's ___ and hot. Let's go to the beach!", ["sunny", "rainy", "stormy"], "It's sunny and hot. Let's go to the beach!", "Hava güneşli ve sıcak. Hadi plaja gidelim!"),
        Q("They ___ going to walk in the rain.", ["aren't", "isn't", "not"], "They aren't going to walk in the rain.", "Yağmurda yürümeyecekler."),
        Q("The bus ___ working.", ["isn't", "aren't", "don't"], "The bus isn't working.", "Otobüs çalışmıyor."),
        Q("You look cold. You ___ put on a coat.", ["should", "shouldn't", "can't"], "You look cold. You should put on a coat.", "Üşümüş görünüyorsun. Mont giymelisin."),
        Q("How long ___ we have to wait?", ["do", "does", "are"], "How long do we have to wait?", "Ne kadar beklememiz gerekiyor?"),
        Q("The woman ___ her husband yesterday.", ["called", "calls", "call"], "The woman called her husband yesterday.", "Kadın dün kocasını aradı."),
        Q("I can hear thunder. It's ___!", ["stormy", "sunny", "warm"], "I can hear thunder. It's stormy!", "Gök gürültüsü duyuyorum. Hava fırtınalı!"),
        Q("Can you help me? Yes, I ___.", ["can", "do", "am"], "Can you help me? Yes, I can.", "Bana yardım edebilir misin? Evet, edebilirim."),
        Q("I ___ the bus home yesterday.", ["didn't take", "don't took", "not took"], "I didn't take the bus home yesterday.", "Dün eve otobüsle gitmedim."),
        Q("The storm ___ very loud.", ["was", "were", "are"], "The storm was very loud.", "Fırtına çok gürültülüydü."),
    ],
    "speakers": {"woman": ["Woman", "Kadın", "kristin"], "driver": ["Bus driver", "Otobüs şoförü", "joe_deep"], "taxi": ["Taxi", "Taksi", "amy"]},
}

def walk(steps, out):
    for s in steps:
        if "en" in s and "who" in s: out[s["en"]] = s["tr"]
        if "obj" in s: out[s["en"]] = s["tr"]
        if "choice" in s:
            c = s["choice"]; out[c["prompt"]] = c["prompt_tr"]
            for o in c["opts"]:
                out[o["en"]] = o["tr"]
                if o.get("fb"): out[o["fb"]] = o["fb_tr"]
for d in (D5, D6):
    lines = dict(COMMON_LINES)
    walk([d["alarm_after"], d["bath"]["done"], d["outing"], d["recap_end"]], lines)
    lines[d["bath"]["en"]] = d["bath"]["tr"]
    for k in ("breakfast", "event", "couch", "taxi"): walk(d.get(k, []), lines)
    for q in d["review"]: lines[q["say"]] = q["tr"]
    for r in d["recap"]: lines.setdefault(r[1], "")
    lines["Helped, found, talked: this is the past simple."] = "Helped, found, talked: bu geçmiş zaman."
    lines["I helped a lost boy at the shop."] = "Markette kaybolmuş bir çocuğa yardım ettim."
    lines["I waited for the bus in the storm."] = "Fırtınada otobüs bekledim."
    d["lines"] = lines
    json.dump(d, open(f"{R}/data/day{d['day']}.json", "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("day", d["day"], len(lines), "lines")
