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
- Run by red's shared no-repeat TestBank (`TB.run_test`); this day's 30 bank entries (`data/test_bank.json` ids d5_01..30, topics asking_for_help, clothes, describing_people, present_continuous, reassuring), 10 per version; Retake draws unused ones:

**Version A**
1. He ___ short brown hair. — (has got / have got / is got) ✔ **has got** — read: "He's got short brown hair."  *Kısa kahverengi saçları var.*  `describing_people`
2. What ___ she look like? — (does / is / do) ✔ **does** — read: "What does she look like?"  *Neye benziyor?*  `describing_people`
3. He's ___ a yellow T-shirt. — (wearing / wear / wears) ✔ **wearing** — read: "He's wearing a yellow T-shirt."  *Sarı bir tişört giyiyor.*  `clothes`
4. Her shoes ___ red. — (are / is / am) ✔ **are** — read: "Her shoes are red."  *Ayakkabıları kırmızı.*  `clothes`
5. Excuse me, ___ you help me? — (can / do / are) ✔ **can** — read: "Excuse me, can you help me?"  *Affedersiniz, bana yardım edebilir misiniz?*  `asking_for_help`
6. This boy ___ lost. — (is / are / am) ✔ **is** — read: "This boy is lost."  *Bu çocuk kaybolmuş.*  `asking_for_help`
7. Don't worry. ___ safe now. — (You're / Your / You) ✔ **You're** — read: "Don't worry. You're safe now."  *Merak etme. Artık güvendesin.*  `reassuring`
8. It's OK. I'm ___. — (here / hear / her) ✔ **here** — read: "It's OK. I'm here."  *Sorun yok. Buradayım.*  `reassuring`
9. Leo ___ near the door. — (is crying / cries / crying) ✔ **is crying** — read: "Leo's crying near the door."  *Leo kapının yanında ağlıyor.*  `present_continuous`
10. We ___ for his mum. — (are looking / is looking / looking) ✔ **are looking** — read: "We're looking for his mum."  *Annesini arıyoruz.*  `present_continuous`

**Version B**
1. My sister ___ curly black hair. — (has got / have got / is) ✔ **has got** — read: "My sister's got curly black hair."  *Kız kardeşimin kıvırcık siyah saçları var.*  `describing_people`
2. He ___ tall. He's short. — (isn't / aren't / not) ✔ **isn't** — read: "He isn't tall. He's short."  *Uzun boylu değil. Kısa boylu.*  `describing_people`
3. Look! The man ___ a red coat. — (is wearing / wear / are wearing) ✔ **is wearing** — read: "Look! The man's wearing a red coat."  *Bak! Adam kırmızı bir mont giyiyor.*  `clothes`
4. She ___ wearing a hat. — (isn't / aren't / don't) ✔ **isn't** — read: "She isn't wearing a hat."  *Şapka takmıyor.*  `clothes`
5. Could you ___ me, please? — (help / helps / helping) ✔ **help** — read: "Could you help me, please?"  *Bana yardım edebilir misiniz, lütfen?*  `asking_for_help`
6. I ___ find my mum. — (can't / don't can / not can) ✔ **can't** — read: "I can't find my mum."  *Annemi bulamıyorum.*  `asking_for_help`
7. Don't cry. Your mum ___ coming. — (is / are / am) ✔ **is** — read: "Don't cry. Your mum's coming."  *Ağlama. Annen geliyor.*  `reassuring`
8. Don't ___ scared. — (be / are / is) ✔ **be** — read: "Don't be scared."  *Korkma.*  `reassuring`
9. I ___ wearing my blue jeans today. — (am / is / are) ✔ **am** — read: "I'm wearing my blue jeans today."  *Bugün mavi kotumu giyiyorum.*  `present_continuous`
10. What ___ you doing? — (are / do / is) ✔ **are** — read: "What are you doing?"  *Ne yapıyorsun?*  `present_continuous`

**Version C**
1. They ___ got brown eyes. — (have / has / is) ✔ **have** — read: "They've got brown eyes."  *Kahverengi gözleri var.*  `describing_people`
2. How old ___ he? — (is / are / has) ✔ **is** — read: "How old is he?"  *Kaç yaşında?*  `describing_people`
3. She ___ a green dress today. — (is wearing / wearing / wear) ✔ **is wearing** — read: "She's wearing a green dress today."  *Bugün yeşil bir elbise giyiyor.*  `clothes`
4. His trousers ___ blue. — (are / is / am) ✔ **are** — read: "His trousers are blue."  *Pantolonu mavi.*  `clothes`
5. Excuse me, ___ the shop assistant? — (where's / who's / what's) ✔ **where's** — read: "Excuse me, where's the shop assistant?"  *Affedersiniz, mağaza görevlisi nerede?*  `asking_for_help`
6. ___ I help you? — (Can / Do / Am) ✔ **Can** — read: "Can I help you?"  *Yardım edebilir miyim?*  `asking_for_help`
7. It's OK. Don't ___. — (worry / worried / worries) ✔ **worry** — read: "It's OK. Don't worry."  *Sorun yok. Merak etme.*  `reassuring`
8. You're very ___. — (brave / bravely / braves) ✔ **brave** — read: "You're very brave."  *Çok cesursun.*  `reassuring`
9. His mum ___ into the shop. — (is running / runs / running) ✔ **is running** — read: "His mum's running into the shop."  *Annesi koşarak markete giriyor.*  `present_continuous`
10. They ___ crying now. — (aren't / isn't / don't) ✔ **aren't** — read: "They aren't crying now."  *Artık ağlamıyorlar.*  `present_continuous`

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
- Run by red's shared no-repeat TestBank (`TB.run_test`); this day's 30 bank entries (`data/test_bank.json` ids d6_01..30, topics asking_for_help, future_will, going_to, suggestions, weather), 10 per version; Retake draws unused ones:

**Version A**
1. It's ___ today. Take an umbrella. — (rainy / sunny / hot) ✔ **rainy** — read: "It's rainy today. Take an umbrella."  *Bugün hava yağmurlu. Şemsiye al.*  `weather`
2. What's the weather ___? — (like / likes / liking) ✔ **like** — read: "What's the weather like?"  *Hava nasıl?*  `weather`
3. I think it ___ rain tonight. — (will / is / does) ✔ **will** — read: "I think it'll rain tonight."  *Sanırım bu gece yağmur yağacak.*  `future_will`
4. I ___ call my family. — (will / am / do) ✔ **will** — read: "I'll call my family."  *Ailemi arayacağım.*  `future_will`
5. Look at those clouds! It ___ rain. — (is going to / going to / goes to) ✔ **is going to** — read: "Look at those clouds! It's going to rain."  *Şu bulutlara bak! Yağmur yağacak.*  `going_to`
6. We ___ going to wait here. — (are / is / am) ✔ **are** — read: "We're going to wait here."  *Burada bekleyeceğiz.*  `going_to`
7. Excuse me, ___ the next bus? — (when's / who's / what's) ✔ **when's** — read: "Excuse me, when's the next bus?"  *Affedersiniz, bir sonraki otobüs ne zaman?*  `asking_for_help`
8. ___ you pick me up, please? — (Can / Do / Are) ✔ **Can** — read: "Can you pick me up, please?"  *Beni alabilir misin, lütfen?*  `asking_for_help`
9. ___ wait under the shelter. — (Let's / Let / Lets) ✔ **Let's** — read: "Let's wait under the shelter."  *Durağın altında bekleyelim.*  `suggestions`
10. Why ___ we call a taxi? — (don't / doesn't / not) ✔ **don't** — read: "Why don't we call a taxi?"  *Neden bir taksi çağırmıyoruz?*  `suggestions`

**Version B**
1. It's very ___. My umbrella's flying away! — (windy / sunny / snowy) ✔ **windy** — read: "It's very windy. My umbrella's flying away!"  *Hava çok rüzgarlı. Şemsiyem uçuyor!*  `weather`
2. It's cold and white outside. It's ___. — (snowy / sunny / hot) ✔ **snowy** — read: "It's cold and white outside. It's snowy."  *Dışarısı soğuk ve beyaz. Hava karlı.*  `weather`
3. Don't worry. I ___ help you. — (will / am / do) ✔ **will** — read: "Don't worry. I'll help you."  *Merak etme. Sana yardım edeceğim.*  `future_will`
4. The bus ___ come for forty minutes. — (won't / willn't / doesn't will) ✔ **won't** — read: "The bus won't come for forty minutes."  *Otobüs kırk dakika gelmeyecek.*  `future_will`
5. I'm ___ take a taxi. — (going to / go to / going) ✔ **going to** — read: "I'm going to take a taxi."  *Taksiye bineceğim.*  `going_to`
6. ___ you going to walk home? — (Are / Do / Is) ✔ **Are** — read: "Are you going to walk home?"  *Eve yürüyecek misin?*  `going_to`
7. Excuse me, ___ the bus broken? — (is / does / are) ✔ **is** — read: "Excuse me, is the bus broken?"  *Affedersiniz, otobüs bozuk mu?*  `asking_for_help`
8. Could you ___ my dad, please? — (call / calls / calling) ✔ **call** — read: "Could you call my dad, please?"  *Babamı arayabilir misiniz, lütfen?*  `asking_for_help`
9. How about ___ your family? — (calling / call / to call) ✔ **calling** — read: "How about calling your family?"  *Aileni aramaya ne dersin?*  `suggestions`
10. We ___ stay dry. — (should / should to / shoulds) ✔ **should** — read: "We should stay dry."  *Kuru kalmalıyız.*  `suggestions`

**Version C**
1. I can hear thunder. It's ___! — (stormy / sunny / warm) ✔ **stormy** — read: "I can hear thunder. It's stormy!"  *Gök gürültüsü duyuyorum. Hava fırtınalı!*  `weather`
2. It's ___ and hot. Let's go to the beach! — (sunny / rainy / stormy) ✔ **sunny** — read: "It's sunny and hot. Let's go to the beach!"  *Hava güneşli ve sıcak. Hadi plaja gidelim!*  `weather`
3. Mum ___ pick us up. — (will / is / does) ✔ **will** — read: "Mum will pick us up."  *Annem bizi alacak.*  `future_will`
4. ___ the storm stop soon? — (Will / Does / Is) ✔ **Will** — read: "Will the storm stop soon?"  *Fırtına yakında dinecek mi?*  `future_will`
5. They ___ going to walk in the rain. — (aren't / isn't / not) ✔ **aren't** — read: "They aren't going to walk in the rain."  *Yağmurda yürümeyecekler.*  `going_to`
6. What ___ you going to do? — (are / do / is) ✔ **are** — read: "What are you going to do?"  *Ne yapacaksın?*  `going_to`
7. Can you help me? Yes, I ___. — (can / do / am) ✔ **can** — read: "Can you help me? Yes, I can."  *Bana yardım edebilir misin? Evet, edebilirim.*  `asking_for_help`
8. How long ___ we have to wait? — (do / does / are) ✔ **do** — read: "How long do we have to wait?"  *Ne kadar beklememiz gerekiyor?*  `asking_for_help`
9. Let's ___ walk. It's too far. — (not / don't / no) ✔ **not** — read: "Let's not walk. It's too far."  *Yürümeyelim. Çok uzak.*  `suggestions`
10. You ___ walk in a storm. — (shouldn't / should to / not should) ✔ **shouldn't** — read: "You shouldn't walk in a storm."  *Fırtınada yürümemelisin.*  `suggestions`

- Then sleep → Day 7 (red's `day7_morning.gd`).

