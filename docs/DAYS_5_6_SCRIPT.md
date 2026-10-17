# Days 5-6 — full English script (v33 blue)

Generated from `data/day5.json` / `data/day6.json` by `tools/days56/make_script_doc.py`; edit `tools/days56/days56_content.py`, then re-run the content, voice and doc scripts.
Turkish (TR toggle, text only) is shown in *italics*. **Objective** = top-left Objectives entry + camera pan + spoken line. ✔ = the right answer (wrong answers show feedback and get greyed out). `[action]` = stage direction.

## Day 5

### 1. Alarm (bedroom)
- **Narrator:** It is a new day. / My alarm is ringing. (caption, present continuous)
- **Objective:** Turn off the alarm.  *Alarmı kapat.*
- **Me:** Good morning! I'm going to the corner shop today.  *Günaydın! Bugün köşedeki markete gidiyorum.*
- **Objective:** Go to the bathroom.  *Banyoya git.*

### 2. Bathroom
- **Objective:** Wash your face and brush your teeth.  *Yüzünü yıka ve dişlerini fırçala.*
- **Me:** I feel fresh now.  *Şimdi kendimi zinde hissediyorum.*
- **Objective:** Go to the living room.  *Oturma odasına git.*

### 3. Breakfast (living-room table)
- **Objective:** Have breakfast with your family.  *Ailenle kahvaltı yap.*
- **Family member 1:** Morning! Did you sleep well?  *Günaydın! İyi uyudun mu?*
- **Me:** Yes, thanks. I slept really well.  *Evet, teşekkürler. Çok iyi uyudum.*
- **Family member 2:** We're out of milk and bread. Can you go to the corner shop today?  *Süt ve ekmeğimiz bitti. Bugün köşedeki markete gidebilir misin?*
- **Me:** Sure, no problem. I'll go after breakfast.  *Tabii, sorun değil. Kahvaltıdan sonra giderim.*
- **Family member 1:** Thanks! Here's a shopping bag.  *Teşekkürler! Al, bir alışveriş çantası.*

**Grammar review at the table** (narrator reads; first try counts):
1. Every morning I ___ breakfast with my family. — (have / am having / had) ✔ **have** — read: "Every morning I have breakfast with my family."  *Her sabah ailemle kahvaltı yaparım.*
2. Look! The cat ___ my toast! — (is eating / eats / ate) ✔ **is eating** — read: "Look! The cat is eating my toast!"  *Bak! Kedi tostumu yiyor!*
3. We're out of milk. I ___ go to the shop. — (have to / has to / having to) ✔ **have to** — read: "We're out of milk. I have to go to the shop."  *Sütümüz bitti. Markete gitmem gerekiyor.*
- **Objective:** Go outside.  *Dışarı çık.*

### 4. Outing — the corner shop (lost child)
- **Objective:** Walk to the corner shop.  *Köşedeki markete yürü.*
- `[child_appears]`
- **Narrator:** Oh! A little boy is crying near the door.  *Aa! Kapının yanında küçük bir çocuk ağlıyor.*
- **Objective:** Help the little boy.  *Küçük çocuğa yardım et.*
- **Choice:** What do you say to the boy?  *Çocuğa ne dersin?*
  - ✔ "Hi! Are you OK?"  *Merhaba! İyi misin?*
  - ✘ "Stop crying!"  *Ağlamayı kes!* → Not quite. That isn't kind. He's scared.  *Bu nazik değil. Çok korkmuş.*
  - ✘ "Where's your phone?"  *Telefonun nerede?* → Not quite. He's very young. Ask if he's OK first.  *O çok küçük. Önce iyi olup olmadığını sor.*
- **Boy (child_m voice):** No... I can't find my mum.  *Hayır... Annemi bulamıyorum.*
- **Me:** Oh no. What's your name?  *Olamaz. Adın ne?*
- **Boy (child_m voice):** I'm Leo.  *Ben Leo.*
- **Me:** Hi, Leo. Don't worry. I'm going to help you.  *Merhaba Leo. Merak etme. Sana yardım edeceğim.*
- **Objective:** Ask the shop assistant for help.  *Mağaza görevlisinden yardım iste.*
- `[walk_to_assistant]`
- **Choice:** What do you say to the shop assistant?  *Mağaza görevlisine ne dersin?*
  - ✔ "Excuse me, can you help us? This boy is lost."  *Affedersiniz, bize yardım edebilir misiniz? Bu çocuk kaybolmuş.*
  - ✘ "Can I have a bag, please?"  *Bir poşet alabilir miyim, lütfen?* → Not quite. That's not the problem right now. The boy is lost.  *Şu an sorun bu değil. Çocuk kaybolmuş.*
  - ✘ "How much is the bread?"  *Ekmek ne kadar?* → Not quite. Not now! Tell the assistant about the lost boy.  *Şimdi değil! Görevliye kayıp çocuktan bahset.*
- **Shop assistant (joe voice):** Oh dear! Of course. I'm going to make an announcement. Can you describe him for me?  *Aman! Tabii ki. Bir anons yapacağım. Onu bana tarif edebilir misin?*
- `[look_at_child]`
- **Choice:** Describe the boy.  *Çocuğu tarif et.*
  - ✔ "He's about five. He's got short brown hair."  *Yaklaşık beş yaşında. Kısa kahverengi saçları var.*
  - ✘ "He's about five. He's got long blond hair."  *Yaklaşık beş yaşında. Uzun sarı saçları var.* → Not quite. Look again. His hair is short and brown.  *Tekrar bak. Saçı kısa ve kahverengi.*
  - ✘ "He's very old. He's got a big beard."  *Çok yaşlı. Büyük bir sakalı var.* → Not quite. No! He's a little boy.  *Hayır! O küçük bir çocuk.*
- **Shop assistant (joe voice):** Great. And what's he wearing?  *Harika. Peki ne giyiyor?*
- **Choice:** What's he wearing?  *Ne giyiyor?*
  - ✔ "He's wearing a yellow T-shirt."  *Sarı bir tişört giyiyor.*
  - ✘ "He's wearing a red coat."  *Kırmızı bir mont giyiyor.* → Not quite. Look again. His T-shirt is yellow.  *Tekrar bak. Tişörtü sarı.*
  - ✘ "He's wearing a green hat."  *Yeşil bir şapka takıyor.* → Not quite. Look again. He isn't wearing a hat.  *Tekrar bak. Şapka takmıyor.*
- `[announce]`
- **Shop assistant (joe voice):** Attention, please! We've got a little boy called Leo at the front of the shop. He's about five, and he's wearing a yellow T-shirt.  *Dikkat lütfen! Mağazanın önünde Leo adında küçük bir çocuk var. Yaklaşık beş yaşında ve sarı bir tişört giyiyor.*
- **Boy (child_m voice):** I'm scared.  *Korkuyorum.*
- **Objective:** Help Leo feel better.  *Leo'nun kendini daha iyi hissetmesine yardım et.*
- **Choice:** What do you say to Leo?  *Leo'ya ne dersin?*
  - ✔ "It's OK, Leo. Your mum's coming soon."  *Sorun yok Leo. Annen birazdan gelir.*
  - ✘ "I'm going home now. Bye!"  *Ben şimdi eve gidiyorum. Hoşça kal!* → Not quite. Don't leave him alone! Stay with him.  *Onu yalnız bırakma! Yanında kal.*
  - ✘ "Your mum isn't coming."  *Annen gelmiyor.* → Not quite. That isn't kind. Say something nice.  *Bu nazik değil. Güzel bir şey söyle.*
- **Boy (child_m voice):** OK. Thank you.  *Tamam. Teşekkür ederim.*
- `[mum_enters]`
- **Narrator:** A woman is running into the shop.  *Bir kadın koşarak markete giriyor.*
- **Woman (amy voice):** Excuse me! I'm looking for my little boy!  *Affedersiniz! Küçük oğlumu arıyorum!*
- **Objective:** Find Leo's mum.  *Leo'nun annesini bul.*
- **Choice:** What do you ask her?  *Ona ne sorarsın?*
  - ✔ "What's his name?"  *Adı ne?*
  - ✘ "What's your favourite colour?"  *En sevdiğin renk ne?* → Not quite. That doesn't help. Ask about her son.  *Bu yardımcı olmaz. Oğlunu sor.*
  - ✘ "Do you like this shop?"  *Bu marketi seviyor musun?* → Not quite. Not now! Ask about her son.  *Şimdi değil! Oğlunu sor.*
- **Woman (amy voice):** Leo. He's five, and he's wearing a yellow T-shirt.  *Leo. Beş yaşında ve sarı bir tişört giyiyor.*
- **Me:** He's here! He's safe.  *Burada! O güvende.*
- `[reunite]`
- **Boy (child_m voice):** Mum!  *Anne!*
- **Woman (amy voice):** Leo! There you are! I was so worried.  *Leo! İşte buradasın! Çok endişelendim.*
- **Narrator:** Leo is hugging his mum.  *Leo annesine sarılıyor.*
- `[photo]`
- **Woman (amy voice):** Thank you so much for helping him!  *Ona yardım ettiğin için çok teşekkür ederim!*
- **Me:** You're welcome. Bye, Leo!  *Rica ederim. Hoşça kal, Leo!*
- **Boy (child_m voice):** Bye! Thank you!  *Hoşça kal! Teşekkürler!*
- **Shop assistant (joe voice):** Well done. That was really kind of you.  *Aferin. Çok nazik davrandın.*
- **Narrator:** Well done! You helped Leo find his mum.  *Aferin! Leo'nun annesini bulmasına yardım ettin.*
- `[npcs_leave]`
- **Objective:** Go home.  *Eve git.* / Go inside.  *İçeri gir.*

### 5. Evening couch talk
- **Objective:** Talk to your family.  *Ailenle konuş.*
- **Family member 1:** You're back! How was the shop?  *Döndün! Market nasıldı?*
- **Me:** It was quite an adventure!  *Tam bir maceraydı!*
- **Choice:** Tell your family what happened.  *Ailene ne olduğunu anlat.*
  - ✔ "A little boy got lost in the shop."  *Markette küçük bir çocuk kayboldu.*
  - ✘ "A little boy gets lost in the shop."  *Markette küçük bir çocuk kaybolur.* → Not quite. It happened today, so use the past simple: got lost.  *Bugün oldu, o yüzden geçmiş zaman kullan: got lost.*
  - ✘ "A little boy is get lost in the shop."  *Markette küçük bir çocuk kayboluyor.* → Not quite. Use the past simple: got lost.  *Geçmiş zaman kullan: got lost.*
- **Family member 2:** Oh no! Is he OK?  *Olamaz! O iyi mi?*
- **Choice:** Answer your family.  *Ailene cevap ver.*
  - ✔ "Yes. We found his mum."  *Evet. Annesini bulduk.*
  - ✘ "Yes. We find his mum."  *Evet. Annesini buluruz.* → Not quite. Use the past simple: find becomes found.  *Geçmiş zaman kullan: find -> found.*
  - ✘ "Yes. We finded his mum."  *Evet. Annesini bulduk.* → Not quite. Find is irregular: found, not finded.  *Find düzensiz bir fiil: finded değil, found.*
- **Family member 1:** Well done! That was really kind of you.  *Aferin! Çok nazik davrandın.*
- **Family member 2:** Did you get the milk and bread?  *Süt ve ekmeği aldın mı?*
- **Me:** Yes, I did. They're in the kitchen.  *Evet, aldım. Mutfaktalar.*
- `[photo]`
- **Family member 1:** You must be tired. Time for bed!  *Yorgun olmalısın. Yatma vakti!*
- **Me:** Good night!  *İyi geceler!*
- **Objective:** Go to bed.  *Yatağa git.*

### 6. Polaroids (in bed)
- **Objective:** Look at the photos of your day.  *Gününün fotoğraflarına bak.*
- `[d5_breakfast]` I had breakfast with my family.  *Ailemle kahvaltı yaptım.*
- `[d5_shop]` I helped a lost boy at the shop.  *Markette kaybolmuş bir çocuğa yardım ettim.*
- `[d5_couch]` I talked to my family.  *Ailemle konuştum.*
- **Narrator:** Helped, found, talked: this is the past simple.  *Helped, found, talked: bu geçmiş zaman.*

### 7. Bedtime test (10 questions, 3 rotating versions, answers shuffled, narrator reads)
- **Objective:** Take the bedtime test.  *Yatmadan önce testi çöz.*
- Questions come from red's shared no-repeat bank (topics describing_people, clothes_present_continuous, asking_for_help, past_simple) once it exists; until then from these local versions:

**Version A**
1. He ___ short brown hair. — (has got / have got / is got) ✔ **has got** — read: "He has got short brown hair."  *Kısa kahverengi saçları var.*
2. Leo ___ a yellow T-shirt today. — (is wearing / wears / wearing) ✔ **is wearing** — read: "Leo is wearing a yellow T-shirt today."  *Leo bugün sarı bir tişört giyiyor.*
3. ___ you help me, please? — (Can / Do / Are) ✔ **Can** — read: "Can you help me, please?"  *Bana yardım edebilir misiniz, lütfen?*
4. Yesterday I ___ a lost boy. — (helped / help / helps) ✔ **helped** — read: "Yesterday I helped a lost boy."  *Dün kaybolmuş bir çocuğa yardım ettim.*
5. We ___ his mum near the door. — (found / finded / find) ✔ **found** — read: "We found his mum near the door."  *Annesini kapının yanında bulduk.*
6. What ___ she look like? — (does / is / do) ✔ **does** — read: "What does she look like?"  *Görünüşü nasıl?*
7. She's got long hair ___ blue eyes. — (and / but / or) ✔ **and** — read: "She's got long hair and blue eyes."  *Uzun saçları ve mavi gözleri var.*
8. Don't worry. Your mum ___ coming. — (is / are / am) ✔ **is** — read: "Don't worry. Your mum is coming."  *Merak etme. Annen geliyor.*
9. Excuse me, ___ is the checkout? — (where / who / what) ✔ **where** — read: "Excuse me, where is the checkout?"  *Affedersiniz, kasa nerede?*
10. The boy ___ scared, but now he's happy. — (was / were / is) ✔ **was** — read: "The boy was scared, but now he's happy."  *Çocuk korkmuştu ama şimdi mutlu.*

**Version B**
1. My sister ___ curly black hair. — (has got / have got / is) ✔ **has got** — read: "My sister has got curly black hair."  *Kız kardeşimin kıvırcık siyah saçları var.*
2. Look! The man ___ a red coat. — (is wearing / wear / are wearing) ✔ **is wearing** — read: "Look! The man is wearing a red coat."  *Bak! Adam kırmızı bir mont giyiyor.*
3. Could you ___ me, please? — (help / helps / helping) ✔ **help** — read: "Could you help me, please?"  *Bana yardım edebilir misiniz, lütfen?*
4. I ___ to the corner shop yesterday. — (went / go / goed) ✔ **went** — read: "I went to the corner shop yesterday."  *Dün köşedeki markete gittim.*
5. Yesterday the little boy ___ for his mum. — (looked / look / looks) ✔ **looked** — read: "Yesterday the little boy looked for his mum."  *Dün küçük çocuk annesini aradı.*
6. He's tall ___ he's got glasses. — (and / or / but) ✔ **and** — read: "He's tall and he's got glasses."  *Uzun boylu ve gözlüğü var.*
7. ___ is your name? — (What / Where / How) ✔ **What** — read: "What is your name?"  *Adın ne?*
8. I ___ wearing my blue jeans now. — (am / is / are) ✔ **am** — read: "I am wearing my blue jeans now."  *Şu an mavi kot pantolonumu giyiyorum.*
9. Thank you so much! You're ___. — (welcome / welcomed / welcomes) ✔ **welcome** — read: "Thank you so much! You're welcome."  *Çok teşekkür ederim! Rica ederim.*
10. The shop assistant ___ very kind. — (was / were / are) ✔ **was** — read: "The shop assistant was very kind."  *Mağaza görevlisi çok nazikti.*

**Version C**
1. They ___ got brown eyes. — (have / has / is) ✔ **have** — read: "They have got brown eyes."  *Kahverengi gözleri var.*
2. She ___ a green dress today. — (is wearing / wearing / wear) ✔ **is wearing** — read: "She is wearing a green dress today."  *Bugün yeşil bir elbise giyiyor.*
3. Excuse me, can you ___ me? — (help / to help / helped) ✔ **help** — read: "Excuse me, can you help me?"  *Affedersiniz, bana yardım edebilir misiniz?*
4. Leo ___ his mum in the shop. — (lost / losed / loses) ✔ **lost** — read: "Leo lost his mum in the shop."  *Leo markette annesini kaybetti.*
5. His mum ___ into the shop. — (ran / runned / run) ✔ **ran** — read: "His mum ran into the shop."  *Annesi koşarak markete girdi.*
6. How old ___ he? — (is / are / am) ✔ **is** — read: "How old is he?"  *Kaç yaşında?*
7. He ___ about five years old. — (is / has / does) ✔ **is** — read: "He is about five years old."  *Yaklaşık beş yaşında.*
8. We ___ wearing coats because it's cold. — (are / is / am) ✔ **are** — read: "We are wearing coats because it's cold."  *Hava soğuk olduğu için mont giyiyoruz.*
9. Don't cry. ___ OK. — (It's / Its / It) ✔ **It's** — read: "Don't cry. It's OK."  *Ağlama. Sorun yok.*
10. We ___ happy at the end. — (were / was / are) ✔ **were** — read: "We were happy at the end."  *Sonunda mutluyduk.*

- Then sleep → Day 6 alarm.

## Day 6

### 1. Alarm (bedroom)
- **Narrator:** It is a new day. / My alarm is ringing. (caption, present continuous)
- **Objective:** Turn off the alarm.  *Alarmı kapat.*
- **Me:** Good morning! I'm taking the bus into town today.  *Günaydın! Bugün otobüsle şehre gidiyorum.*
- **Objective:** Go to the bathroom.  *Banyoya git.*

### 2. Bathroom
- **Objective:** Take a shower.  *Duş al.*
- **Me:** I feel fresh and clean.  *Kendimi temiz ve zinde hissediyorum.*
- **Objective:** Go to the living room.  *Oturma odasına git.*

### 3. Breakfast (living-room table)
- **Objective:** Have breakfast with your family.  *Ailenle kahvaltı yap.*
- **Family member 1:** Morning! Look outside. It's really cloudy today.  *Günaydın! Dışarı bak. Bugün hava çok bulutlu.*
- **Me:** Yeah. I'm taking the bus into town later.  *Evet. Sonra otobüsle şehre gidiyorum.*
- **Family member 2:** The forecast says there's going to be a storm this afternoon.  *Hava durumu bu öğleden sonra fırtına olacağını söylüyor.*
- **Me:** Really? Then I'll take my umbrella.  *Gerçekten mi? O zaman şemsiyemi alırım.*
- **Family member 1:** Good idea. And call us if you need anything.  *İyi fikir. Bir şeye ihtiyacın olursa bizi ara.*

**Grammar review at the table** (narrator reads; first try counts):
1. Yesterday I ___ a lost boy at the shop. — (helped / help / helping) ✔ **helped** — read: "Yesterday I helped a lost boy at the shop."  *Dün markette kaybolmuş bir çocuğa yardım ettim.*
2. It's going to rain. You ___ take an umbrella. — (should / shoulds / to should) ✔ **should** — read: "It's going to rain. You should take an umbrella."  *Yağmur yağacak. Şemsiye almalısın.*
3. Look at those dark clouds! It ___ rain. — (is going to / going to / are going to) ✔ **is going to** — read: "Look at those dark clouds! It's going to rain."  *Şu kara bulutlara bak! Yağmur yağacak.*
- **Objective:** Go outside.  *Dışarı çık.*

### 4. Outing — the bus stop (storm + broken-down bus)
- **Objective:** Go to the bus stop.  *Otobüs durağına git.*
- `[storm_start]`
- **Narrator:** The sky is getting dark.  *Gökyüzü kararıyor.*
- `[thunder]`
- **Narrator:** The wind is blowing, and it's starting to rain.  *Rüzgar esiyor ve yağmur başlıyor.*
- `[woman_appears]`
- **Woman (kristin voice):** Wow, what terrible weather!  *Vay, ne kötü bir hava!*
- **Objective:** Talk about the weather.  *Hava hakkında konuş.*
- **Choice:** What do you say about the weather?  *Hava hakkında ne dersin?*
  - ✔ "I know! It's really windy, and it's raining hard."  *Biliyorum! Çok rüzgarlı ve şiddetli yağmur yağıyor.*
  - ✘ "Yes, it's sunny and hot today."  *Evet, bugün hava güneşli ve sıcak.* → Not quite. Look at the sky! It isn't sunny.  *Gökyüzüne bak! Hava güneşli değil.*
  - ✘ "It's snowing a lot."  *Çok kar yağıyor.* → Not quite. Look again. It's raining, not snowing.  *Tekrar bak. Kar değil, yağmur yağıyor.*
- **Woman (kristin voice):** Good thing the bus is coming soon.  *İyi ki otobüs birazdan geliyor.*
- `[bus_arrives]`
- **Narrator:** The bus is coming.  *Otobüs geliyor.*
- `[bus_breaks]`
- **Narrator:** Oh no! The bus is making a strange noise.  *Olamaz! Otobüs garip bir ses çıkarıyor.*
- **Bus driver (joe_deep voice):** Sorry, everyone! The bus has broken down. The engine isn't working.  *Herkesten özür dilerim! Otobüs bozuldu. Motor çalışmıyor.*
- **Objective:** Ask the driver for help.  *Şoförden yardım iste.*
- **Choice:** What do you ask the driver?  *Şoföre ne sorarsın?*
  - ✔ "Excuse me, when's the next bus?"  *Affedersiniz, bir sonraki otobüs ne zaman?*
  - ✘ "Can I drive the bus?"  *Otobüsü ben sürebilir miyim?* → Not quite. No, you can't! Ask about the next bus.  *Hayır, süremezsin! Bir sonraki otobüsü sor.*
  - ✘ "Why is the sky grey?"  *Gökyüzü neden gri?* → Not quite. That doesn't help. Ask the driver about the next bus.  *Bu yardımcı olmaz. Şoföre bir sonraki otobüsü sor.*
- **Bus driver (joe_deep voice):** The next bus is coming in about forty minutes. I'm really sorry.  *Bir sonraki otobüs yaklaşık kırk dakika sonra geliyor. Gerçekten üzgünüm.*
- **Me:** That's OK. It isn't your fault.  *Sorun değil. Sizin suçunuz değil.*
- **Objective:** Wait under the bus shelter.  *Otobüs durağının altında bekle.*
- `[wait]`
- **Narrator:** I'm waiting at the bus stop. It's raining really hard.  *Otobüs durağında bekliyorum. Çok şiddetli yağmur yağıyor.*
- `[time_skip]`
- **Narrator:** Ten minutes later...  *On dakika sonra...*
- **Woman (kristin voice):** This is taking so long. What are you going to do?  *Bu çok uzun sürüyor. Sen ne yapacaksın?*
- **Objective:** Choose what to do.  *Ne yapacağını seç.*
- **Choice:** What are you going to do?  *Ne yapacaksın?*  (wrong answers disappear)
  - ✘ "I'm going to walk home."  *Eve yürüyeceğim.* → Not quite. Hmm, it's very windy and wet. Walking isn't a good idea right now.  *Hmm, hava çok rüzgarlı ve ıslak. Şu an yürümek iyi bir fikir değil.*
  - ✘ "I'm going to call a taxi."  *Taksi çağıracağım.* → Not quite. There aren't any taxis right now. Try something else.  *Şu an hiç taksi yok. Başka bir şey dene.*  `[taxi]`
  - ✔ "I'm going to call my family."  *Ailemi arayacağım.*
- `[phone_out]`
- **Narrator:** I'm calling my family.  *Ailemi arıyorum.*
- **famcall:** Hi! Is everything OK?  *Merhaba! Her şey yolunda mı?*
- **Me:** Not really. The bus broke down, and it's raining a lot. Can you pick me up?  *Pek değil. Otobüs bozuldu ve çok yağmur yağıyor. Beni alabilir misin?*
- **famcall:** Of course! Stay at the bus stop. I'm coming right now.  *Tabii ki! Otobüs durağında kal. Hemen geliyorum.*
- **Me:** Thanks! See you soon.  *Teşekkürler! Görüşürüz.*
- `[phone_away]`
- **Woman (kristin voice):** Lucky you! I'm going to call my husband, too.  *Ne şanslısın! Ben de kocamı arayacağım.*
- `[photo]`
- **Narrator:** My family is coming to pick me up.  *Ailem beni almaya geliyor.*
- `[ride_home]`
- **Me:** I'm home again. I'm wet, but I'm safe.  *Yine evdeyim. Islağım ama güvendeyim.*

**If the player picks “Call a taxi” (the taxi line is busy):**
- **Narrator:** I'm calling a taxi.  *Taksi çağırıyorum.*
- **Taxi (amy voice):** Sorry, all our taxis are busy because of the storm.  *Üzgünüz, fırtına yüzünden bütün taksilerimiz dolu.*
- **Objective:** Go home.  *Eve git.* / Go inside.  *İçeri gir.*

### 5. Evening couch talk
- **Objective:** Talk to your family.  *Ailenle konuş.*
- **Family member 1:** Come and sit down. You're still wet!  *Gel otur. Hâlâ ıslaksın!*
- **Me:** What a day!  *Ne gün ama!*
- **Family member 2:** Tell us! What happened?  *Anlat bize! Ne oldu?*
- **Choice:** Tell your family what happened.  *Ailene ne olduğunu anlat.*
  - ✔ "The bus broke down in the storm."  *Otobüs fırtınada bozuldu.*
  - ✘ "The bus breaks down in the storm."  *Otobüs fırtınada bozulur.* → Not quite. It happened today. Use the past simple: broke down.  *Bugün oldu. Geçmiş zaman kullan: broke down.*
  - ✘ "The bus breaked down in the storm."  *Otobüs fırtınada bozuldu.* → Not quite. Break is irregular: broke, not breaked.  *Break düzensiz bir fiil: breaked değil, broke.*
- **Family member 1:** Oh no! Were you scared?  *Olamaz! Korktun mu?*
- **Choice:** Answer your family.  *Ailene cevap ver.*
  - ✔ "A little, but I was OK."  *Biraz, ama iyiydim.*
  - ✘ "A little, but I were OK."  *Biraz, ama iyiydim.* → Not quite. With I, we say was: I was OK.  *I ile was kullanırız: I was OK.*
  - ✘ "A little, but I am OK yesterday."  *Biraz, ama dün iyiyim.* → Not quite. Use was for the past: I was OK.  *Geçmiş için was kullan: I was OK.*
- **Family member 2:** You did the right thing. You called us.  *Doğru olanı yaptın. Bizi aradın.*
- `[photo]`
- **Family member 1:** Let's have some hot tea. Then it's time for bed.  *Biraz sıcak çay içelim. Sonra yatma vakti.*
- **Me:** Good night!  *İyi geceler!*
- **Objective:** Go to bed.  *Yatağa git.*

### 6. Polaroids (in bed)
- **Objective:** Look at the photos of your day.  *Gününün fotoğraflarına bak.*
- `[d6_breakfast]` I had breakfast with my family.  *Ailemle kahvaltı yaptım.*
- `[d6_storm]` I waited for the bus in the storm.  *Fırtınada otobüs bekledim.*
- `[d6_couch]` I talked to my family.  *Ailemle konuştum.*
- **Narrator:** Broke, waited, called: this is the past simple.  *Broke, waited, called: bu geçmiş zaman.*

### 7. Bedtime test (10 questions, 3 rotating versions, answers shuffled, narrator reads)
- **Objective:** Take the bedtime test.  *Yatmadan önce testi çöz.*
- Questions come from red's shared no-repeat bank (topics weather, past_simple_irregular, going_to, should, asking_for_help) once it exists; until then from these local versions:

**Version A**
1. It's ___ today. Take an umbrella. — (rainy / sunny / hot) ✔ **rainy** — read: "It's rainy today. Take an umbrella."  *Bugün hava yağmurlu. Şemsiye al.*
2. Look at the clouds! It ___ rain. — (is going to / going to / goes to) ✔ **is going to** — read: "Look at the clouds! It's going to rain."  *Bulutlara bak! Yağmur yağacak.*
3. The bus ___ down yesterday. — (broke / breaked / breaks) ✔ **broke** — read: "The bus broke down yesterday."  *Otobüs dün bozuldu.*
4. You ___ stay inside in a storm. — (should / shoulds / to should) ✔ **should** — read: "You should stay inside in a storm."  *Fırtınada içeride kalmalısın.*
5. When ___ the next bus? — (is / are / do) ✔ **is** — read: "When is the next bus?"  *Bir sonraki otobüs ne zaman?*
6. I ___ at the bus stop for forty minutes. — (waited / waits / waiting) ✔ **waited** — read: "I waited at the bus stop for forty minutes."  *Otobüs durağında kırk dakika bekledim.*
7. It's very ___. My umbrella is flying away! — (windy / sunny / snowy) ✔ **windy** — read: "It's very windy. My umbrella is flying away!"  *Hava çok rüzgarlı. Şemsiyem uçuyor!*
8. ___ you pick me up, please? — (Can / Do / Are) ✔ **Can** — read: "Can you pick me up, please?"  *Beni alabilir misin, lütfen?*
9. Yesterday I ___ my family. — (called / call / calls) ✔ **called** — read: "Yesterday I called my family."  *Dün ailemi aradım.*
10. We ___ wet, but we were safe. — (were / was / are) ✔ **were** — read: "We were wet, but we were safe."  *Islaktık ama güvendeydik.*

**Version B**
1. It's cold and white outside. It's ___. — (snowy / sunny / hot) ✔ **snowy** — read: "It's cold and white outside. It's snowy."  *Dışarısı soğuk ve bembeyaz. Hava karlı.*
2. I'm ___ take a taxi. — (going to / go to / going) ✔ **going to** — read: "I'm going to take a taxi."  *Taksiye bineceğim.*
3. The driver ___ sorry. — (was / were / is) ✔ **was** — read: "The driver was sorry."  *Şoför üzgündü.*
4. It's raining. You ___ walk home. — (shouldn't / should to / not should) ✔ **shouldn't** — read: "It's raining. You shouldn't walk home."  *Yağmur yağıyor. Eve yürümemelisin.*
5. Excuse me, ___ can I get a taxi? — (where / who / what) ✔ **where** — read: "Excuse me, where can I get a taxi?"  *Affedersiniz, nereden taksi bulabilirim?*
6. My dad ___ me up in the car. — (picked / pick / picks) ✔ **picked** — read: "My dad picked me up in the car."  *Babam beni arabayla aldı.*
7. What's the weather ___ today? — (like / likes / liking) ✔ **like** — read: "What's the weather like today?"  *Bugün hava nasıl?*
8. There ___ a big storm yesterday. — (was / were / is) ✔ **was** — read: "There was a big storm yesterday."  *Dün büyük bir fırtına vardı.*
9. Don't worry. I ___ coming now. — (am / is / are) ✔ **am** — read: "Don't worry. I am coming now."  *Merak etme. Hemen geliyorum.*
10. We ___ hot tea at home. — (drank / drinked / drinks) ✔ **drank** — read: "We drank hot tea at home."  *Evde sıcak çay içtik.*

**Version C**
1. It's ___ and hot. Let's go to the beach! — (sunny / rainy / stormy) ✔ **sunny** — read: "It's sunny and hot. Let's go to the beach!"  *Hava güneşli ve sıcak. Hadi plaja gidelim!*
2. They ___ going to walk in the rain. — (aren't / isn't / not) ✔ **aren't** — read: "They aren't going to walk in the rain."  *Yağmurda yürümeyecekler.*
3. The bus ___ working. — (isn't / aren't / don't) ✔ **isn't** — read: "The bus isn't working."  *Otobüs çalışmıyor.*
4. You look cold. You ___ put on a coat. — (should / shouldn't / can't) ✔ **should** — read: "You look cold. You should put on a coat."  *Üşümüş görünüyorsun. Mont giymelisin.*
5. How long ___ we have to wait? — (do / does / are) ✔ **do** — read: "How long do we have to wait?"  *Ne kadar beklememiz gerekiyor?*
6. The woman ___ her husband yesterday. — (called / calls / call) ✔ **called** — read: "The woman called her husband yesterday."  *Kadın dün kocasını aradı.*
7. I can hear thunder. It's ___! — (stormy / sunny / warm) ✔ **stormy** — read: "I can hear thunder. It's stormy!"  *Gök gürültüsü duyuyorum. Hava fırtınalı!*
8. Can you help me? Yes, I ___. — (can / do / am) ✔ **can** — read: "Can you help me? Yes, I can."  *Bana yardım edebilir misin? Evet, edebilirim.*
9. I ___ the bus home yesterday. — (didn't take / don't took / not took) ✔ **didn't take** — read: "I didn't take the bus home yesterday."  *Dün eve otobüsle gitmedim.*
10. The storm ___ very loud. — (was / were / are) ✔ **was** — read: "The storm was very loud."  *Fırtına çok gürültülüydü.*

- Then sleep → Day 7 (red's `day7_morning.gd`).

