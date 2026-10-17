"""v31 cafe + shop content -> data/cafe_shop.json (lessons, 3-version tests, scripted beats, NPC chats, TR)."""
import json
def q(qq, opts, a, say): return {"q": qq, "opts": opts, "a": a, "say": say}
TR = {}
def t(en, tr): TR[en] = tr; return en
cafe = {
 "label": "Cafe", "quiz_after": True, "grammar_ref": "res://data/grammar.json#countable,how_much_many",
 "lesson": [
  {"title": "Countable / uncountable", "title_tr": "Sayılabilen / sayılamayan", "tr": "Sayılabilen: a / an, -s · Sayılamayan: some, -s yok",
   "rows": [["a cup, two cups", "bir fincan, iki fincan"], ["a cookie, three cookies", "bir kurabiye, üç kurabiye"], ["a sandwich, two sandwiches", "bir sandviç, iki sandviç"],
            ["coffee, tea, milk", "kahve, çay, süt (sayılamaz)"], ["sugar, water, juice", "şeker, su, meyve suyu (sayılamaz)"], ["some milk, some cookies", "biraz süt, birkaç kurabiye"]],
   "say": ["a cup, two cups", "a cookie, three cookies", "a sandwich, two sandwiches", "coffee, tea, milk", "sugar, water, juice", "some milk, some cookies"]},
  {"title": "How much? / How many?", "title_tr": "How much? / How many? (ne kadar / kaç tane)", "tr": "much = sayılamayan · many = sayılabilen",
   "rows": [["How much milk do you want?", "Ne kadar süt istersin?"], ["Just a little, please.", "Sadece biraz, lütfen."], ["How many cookies do you want?", "Kaç kurabiye istersin?"],
            ["Two, please.", "İki tane, lütfen."], ["How much sugar? One spoon.", "Ne kadar şeker? Bir kaşık."], ["How many cups? Three cups.", "Kaç fincan? Üç fincan."]],
   "say": ["How much milk do you want?", "Just a little, please.", "How many cookies do you want?", "Two, please.", "How much sugar? One spoon.", "How many cups? Three cups."]},
  {"title": "Ordering", "title_tr": "Sipariş vermek", "tr": "Kafede sipariş",
   "rows": [["What can I get you?", "Ne alırsınız?"], ["I'd like a hot chocolate, please.", "Bir sıcak çikolata istiyorum, lütfen."], ["Can I have a cookie, too?", "Bir kurabiye de alabilir miyim?"],
            ["Is that for here or to go?", "Burada mı, götürmek için mi?"], ["For here, please.", "Burada, lütfen."], ["That's four pounds fifty.", "Dört pound elli ediyor."], ["Here you are.", "Buyurun."]],
   "say": ["What can I get you?", "I'd like a hot chocolate, please.", "Can I have a cookie, too?", "Is that for here or to go?", "For here, please.", "That's four pounds fifty.", "Here you are."]},
 ],
 "quiz": [q("How ___ milk do you want?", ["much", "many"], 0, "How much milk do you want?"), q("How ___ cookies do you want?", ["much", "many"], 1, "How many cookies do you want?"),
          q("I'd like ___ coffee, please.", ["a", "an"], 0, "I'd like a coffee, please."), q("Can I have some ___?", ["water", "waters"], 0, "Can I have some water?"),
          q("Two ___, please.", ["cookie", "cookies"], 1, "Two cookies, please."), q("How ___ sugar? Just a little.", ["much", "many"], 0, "How much sugar? Just a little."),
          q("Is that for here or ___ go?", ["to", "for"], 0, "Is that for here or to go?"), q("___ four pounds, please.", ["That's", "This are"], 0, "That's four pounds, please.")],
 "quiz_b": [q("How ___ cups do we need?", ["much", "many"], 1, "How many cups do we need?"), q("How ___ tea is in the pot?", ["much", "many"], 0, "How much tea is in the pot?"),
          q("Milk is ___.", ["countable", "uncountable"], 1, "Milk is uncountable."), q("A cookie is ___.", ["countable", "uncountable"], 0, "A cookie is countable."),
          q("I'd like ___ orange juice.", ["an", "some"], 1, "I'd like some orange juice."), q("Three ___, please.", ["sandwich", "sandwiches"], 1, "Three sandwiches, please."),
          q("What can I ___ you?", ["get", "got"], 0, "What can I get you?"), q("For here, ___.", ["please", "pleased"], 0, "For here, please.")],
 "quiz_c": [q("How ___ water do you drink?", ["much", "many"], 0, "How much water do you drink?"), q("How ___ muffins are there?", ["much", "many"], 1, "How many muffins are there?"),
          q("Can I have ___ cookie, too?", ["a", "some"], 0, "Can I have a cookie, too?"), q("Coffee is ___.", ["countable", "uncountable"], 1, "Coffee is uncountable."),
          q("We've got two ___ left.", ["muffin", "muffins"], 1, "We've got two muffins left."), q("Just a ___ milk, please.", ["little", "few"], 0, "Just a little milk, please."),
          q("Here you ___.", ["are", "is"], 0, "Here you are."), q("I'd ___ a tea, please.", ["like", "likes"], 0, "I'd like a tea, please.")],
}
shop = {
 "label": "Shop", "quiz_after": True, "grammar_ref": "res://data/grammar.json#countable,how_much_many",
 "lesson": [
  {"title": "In the shop", "title_tr": "Markette", "tr": "Ürünler",
   "rows": [["apples, bananas, oranges", "elmalar, muzlar, portakallar"], ["bread, cheese, milk", "ekmek, peynir, süt"], ["eggs, tomatoes, carrots", "yumurtalar, domatesler, havuçlar"],
            ["rice, water, juice", "pirinç, su, meyve suyu"], ["a bottle of water", "bir şişe su"], ["a loaf of bread", "bir somun ekmek"], ["a box of eggs", "bir kutu yumurta"]],
   "say": ["apples, bananas, oranges", "bread, cheese, milk", "eggs, tomatoes, carrots", "rice, water, juice", "a bottle of water", "a loaf of bread", "a box of eggs"]},
  {"title": "How much? / How many?", "title_tr": "How much? / How many? (ne kadar / kaç tane)", "tr": "How much is it? = Fiyatı ne kadar?",
   "rows": [["How many apples do you need?", "Kaç elmaya ihtiyacın var?"], ["Six, please.", "Altı tane, lütfen."], ["How much cheese do you want?", "Ne kadar peynir istersin?"],
            ["Not much. A small piece.", "Çok değil. Küçük bir parça."], ["How much is the milk?", "Süt ne kadar?"], ["It's one pound twenty.", "Bir pound yirmi."], ["How much are the bananas?", "Muzlar ne kadar?"]],
   "say": ["How many apples do you need?", "Six, please.", "How much cheese do you want?", "Not much. A small piece.", "How much is the milk?", "It's one pound twenty.", "How much are the bananas?"]},
  {"title": "Shopping", "title_tr": "Alışveriş", "tr": "Kasada",
   "rows": [["Excuse me, where's the rice?", "Affedersiniz, pirinç nerede?"], ["It's in aisle two.", "İki numaralı reyonda."], ["Do you have any eggs?", "Hiç yumurtanız var mı?"],
            ["Sorry, there aren't any.", "Üzgünüm, hiç yok."], ["Would you like a bag?", "Poşet ister misiniz?"], ["Yes, please. / No, thanks.", "Evet, lütfen. / Hayır, teşekkürler."], ["That's six pounds forty, please.", "Altı pound kırk, lütfen."]],
   "say": ["Excuse me, where's the rice?", "It's in aisle two.", "Do you have any eggs?", "Sorry, there aren't any.", "Would you like a bag?", "Yes, please.", "No, thanks.", "That's six pounds forty, please."]},
 ],
 "quiz": [q("How ___ apples do you need?", ["much", "many"], 1, "How many apples do you need?"), q("How ___ rice do you want?", ["much", "many"], 0, "How much rice do you want?"),
          q("How much ___ the milk?", ["is", "are"], 0, "How much is the milk?"), q("How much ___ the bananas?", ["is", "are"], 1, "How much are the bananas?"),
          q("a ___ of bread", ["loaf", "bottle"], 0, "a loaf of bread"), q("Do you have ___ eggs?", ["any", "a"], 0, "Do you have any eggs?"),
          q("Bread is ___.", ["countable", "uncountable"], 1, "Bread is uncountable."), q("Would you like a ___?", ["bag", "bags"], 0, "Would you like a bag?")],
 "quiz_b": [q("How ___ cheese do you want?", ["much", "many"], 0, "How much cheese do you want?"), q("How ___ oranges are there?", ["much", "many"], 1, "How many oranges are there?"),
          q("a ___ of water", ["bottle", "loaf"], 0, "a bottle of water"), q("Sorry, there ___ any.", ["aren't", "isn't"], 0, "Sorry, there aren't any."),
          q("Where's the rice? It's ___ aisle two.", ["in", "on"], 0, "It's in aisle two."), q("An apple is ___.", ["countable", "uncountable"], 0, "An apple is countable."),
          q("___ six pounds forty.", ["That's", "Those"], 0, "That's six pounds forty."), q("I need two ___.", ["tomato", "tomatoes"], 1, "I need two tomatoes.")],
 "quiz_c": [q("How ___ water do we need?", ["much", "many"], 0, "How much water do we need?"), q("How ___ eggs do you need?", ["much", "many"], 1, "How many eggs do you need?"),
          q("a ___ of eggs", ["box", "loaf"], 0, "a box of eggs"), q("Rice is ___.", ["countable", "uncountable"], 1, "Rice is uncountable."),
          q("Excuse me, ___ the milk?", ["where's", "where are"], 0, "Excuse me, where's the milk?"), q("It's one pound ___.", ["twenty", "twelfth"], 0, "It's one pound twenty."),
          q("No, ___.", ["thanks", "thank"], 0, "No, thanks."), q("Can I have three ___, please?", ["banana", "bananas"], 1, "Can I have three bananas, please?")],
}
# scripted beats: [speaker, line, TR]  speaker: me / npc id / narr
BEATS = {
 "cafe": {
  "teach": [["narr", "Let's learn how to order food and drinks.", "Hadi yiyecek ve içecek sipariş etmeyi öğrenelim."], ["narr", "Say: I'd like a hot chocolate, please.", "De ki: Bir sıcak çikolata istiyorum, lütfen."],
            ["narr", "Or: Can I have a cookie, please?", "Ya da: Bir kurabiye alabilir miyim, lütfen?"], ["narr", "Milk is uncountable, so we ask: How much milk?", "Süt sayılamaz, bu yüzden sorarız: How much milk?"],
            ["narr", "Cookies are countable, so we ask: How many cookies?", "Kurabiyeler sayılabilir, bu yüzden sorarız: How many cookies?"]],
  "enter": [["me", "What a lovely cafe!", "Ne güzel bir kafe!"], ["me", "It smells like coffee and cake.", "Kahve ve kek kokuyor."]],
  "order": [["barista", "Hi there! What can I get you?", "Merhaba! Ne alırsınız?"], ["me", "Hi! I'd like a hot chocolate, please.", "Merhaba! Bir sıcak çikolata istiyorum, lütfen."],
            ["barista", "Sure. How much milk? A lot or a little?", "Tabii. Ne kadar süt? Çok mu, az mı?"], ["me", "Just a little, please.", "Sadece biraz, lütfen."],
            ["barista", "And how many cookies would you like?", "Peki kaç kurabiye istersiniz?"], ["me", "Two cookies, please.", "İki kurabiye, lütfen."],
            ["barista", "Is that for here or to go?", "Burada mı, götürmek için mi?"], ["me", "For here, please.", "Burada, lütfen."],
            ["barista", "That's four pounds fifty, please.", "Dört pound elli, lütfen."], ["me", "Here you are.", "Buyurun."],
            ["barista", "Thanks! Here's your hot chocolate. Enjoy!", "Teşekkürler! Sıcak çikolatanız. Afiyet olsun!"], ["me", "Thank you! It looks delicious.", "Teşekkürler! Çok lezzetli görünüyor."]],
  "sit": [["me", "I'm sitting at the table. Mmm, it's really good!", "Masada oturuyorum. Mmm, gerçekten çok güzel!"]],
  "done": [["me", "That was great. Time to go.", "Harikaydı. Gitme zamanı."]],
 },
 "shop": {
  "teach": [["narr", "Apples are countable. How many apples? Six apples.", "Elmalar sayılabilir. Kaç elma? Altı elma."],
            ["narr", "Milk is uncountable. How much milk? One bottle of milk.", "Süt sayılamaz. Ne kadar süt? Bir şişe süt."],
            ["narr", "Bread is uncountable too. We say: a loaf of bread.", "Ekmek de sayılamaz. Şöyle deriz: bir somun ekmek."],
            ["narr", "Countable: How many? Uncountable: How much?", "Sayılabilir: How many? Sayılamaz: How much?"]],
  "enter": [["me", "Wow, this shop is big!", "Vay, bu market büyük!"], ["me", "I need some food for home.", "Ev için biraz yiyecek lazım."]],
  "list": [["me", "Let's see my list: apples, milk and bread.", "Listeme bakalım: elma, süt ve ekmek."]],
  "fruit": [["me", "How many apples do I need? Six apples.", "Kaç elmaya ihtiyacım var? Altı elma."]],
  "milk": [["me", "One bottle of milk. That's enough.", "Bir şişe süt. Bu yeterli."]],
  "bread": [["me", "And a loaf of bread. Done!", "Ve bir somun ekmek. Tamam!"]],
  "pay": [["assistant", "Hello! Did you find everything?", "Merhaba! Her şeyi buldunuz mu?"], ["me", "Yes, thanks. How much is it?", "Evet, teşekkürler. Ne kadar?"],
          ["assistant", "Six apples, milk and bread. That's six pounds forty, please.", "Altı elma, süt ve ekmek. Altı pound kırk, lütfen."], ["me", "Here you are.", "Buyurun."],
          ["assistant", "Thank you. Would you like a bag?", "Teşekkürler. Poşet ister misiniz?"], ["me", "Yes, please.", "Evet, lütfen."],
          ["assistant", "Here's your change. Have a nice day!", "Para üstünüz. İyi günler!"], ["me", "Thanks! You too.", "Teşekkürler! Size de."]],
  "done": [["me", "My shopping is done. Let's go home.", "Alışverişim bitti. Hadi eve gidelim."]],
 },
}
NPC = {   # optional chats with customers (each plays once, then a short repeat line)
 "cafe": {
  "c1": [["c1", "Hi! The carrot cake here is amazing.", "Merhaba! Buradaki havuçlu kek harika."], ["me", "Really? How much is it?", "Gerçekten mi? Ne kadar?"], ["c1", "It's only three pounds. Try it!", "Sadece üç pound. Dene!"]],
  "c2": [["c2", "Excuse me, how many sugars are in this?", "Affedersiniz, bunda kaç şeker var?"], ["me", "I don't know. Ask the barista.", "Bilmiyorum. Baristaya sor."], ["c2", "Good idea. Thanks!", "İyi fikir. Teşekkürler!"]],
  "c3": [["c3", "I'm reading and drinking tea. How much tea can one person drink?", "Kitap okuyup çay içiyorum. Bir insan ne kadar çay içebilir?"], ["me", "A lot! I love tea too.", "Çok! Ben de çayı severim."]],
 },
 "shop": {
  "c1": [["c1", "Excuse me, where's the rice?", "Affedersiniz, pirinç nerede?"], ["me", "I think it's in aisle two.", "Sanırım iki numaralı reyonda."], ["c1", "Thanks a lot!", "Çok teşekkürler!"]],
  "c2": [["c2", "Are there any eggs left?", "Hiç yumurta kaldı mı?"], ["me", "Sorry, there aren't any.", "Üzgünüm, hiç yok."], ["c2", "Oh no! I'll come back tomorrow.", "Olamaz! Yarın tekrar gelirim."]],
  "assistant": [["assistant", "Can I help you?", "Yardımcı olabilir miyim?"], ["me", "No, thanks. I'm just looking.", "Hayır, teşekkürler. Sadece bakıyorum."]],
 },
}
NARR = {   # objectives, verb chips, narrator (EN -> TR)
 "Go to the counter.": "Tezgâha git.", "Sit at a table.": "Bir masaya otur.", "Talk to the customers.": "Müşterilerle konuş.", "How to order": "Nasıl sipariş verilir", "My shopping list": "Alışveriş listem",
 "Take a basket.": "Bir sepet al.", "Get six apples.": "Altı elma al.", "Get a bottle of milk.": "Bir şişe süt al.", "Get a loaf of bread.": "Bir somun ekmek al.",
 "Pay at the checkout.": "Kasada öde.", "Go outside.": "Dışarı çık.", "Now a short lesson and test on your phone.": "Şimdi telefonunda kısa bir ders ve test.",
 "Order a drink": "İçecek sipariş et", "Sit down": "Otur", "Talk": "Konuş", "Take a basket": "Sepet al", "Take apples": "Elma al", "Take milk": "Süt al",
 "Take bread": "Ekmek al", "Pay": "Öde", "Go outside": "Dışarı çık", "Cafe": "Kafe", "Shop": "Market",
 "I'm taking a basket.": "Bir sepet alıyorum.", "I'm walking to the counter.": "Tezgâha yürüyorum.", "Well done! You finished the cafe.": "Aferin! Kafeyi bitirdin.",
 "Well done! You finished the shop.": "Aferin! Marketi bitirdin.", "Thanks again! Bye!": "Tekrar teşekkürler! Hoşça kalın!", "Nice to see you again!": "Sizi tekrar görmek güzel!",
}
OUT = {"cafe": cafe, "shop": shop, "beats": BEATS, "npc": NPC, "tr": {}}
for d in (cafe, shop):
    for st in d["lesson"]:
        for r in st["rows"]: OUT["tr"][r[0]] = r[1]
for place in BEATS.values():
    for b in place.values():
        for x in b: OUT["tr"][x[1]] = x[2]
for place in NPC.values():
    for b in place.values():
        for x in b: OUT["tr"][x[1]] = x[2]
OUT["tr"].update(NARR); OUT["tr"].update(TR)
json.dump(OUT, open("data/cafe_shop.json", "w"), ensure_ascii=False, indent=1)
print("ok", len(OUT["tr"]), "tr lines")
