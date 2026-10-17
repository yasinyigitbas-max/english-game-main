"""vocabtest: Piper en_US-ljspeech-medium clips for every vocab-test line -> new chunk voice/voice_NNN.bin + entries in data/voice_index.json;
also registers EN->TR captions in data/extra_lines.json and option TR in data/vocab_test.json. Same pipeline as build_voice.py."""
import json, re, os, io, wave, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = lambda *a: os.path.join(ROOT, *a)
TR = {"brush your teeth":"dişlerini fırçalamak","put toothpaste on it":"üstüne diş macunu sürmek","put it on a toothbrush":"diş fırçasına sürmek","dry your face":"yüzünü kurulamak","dry your hands":"ellerini kurulamak","drink water":"su içmek","wash it":"onu yıkamak","use the toilet":"tuvaleti kullanmak","flush it":"sifonu çekmek","look at your face":"yüzüne bakmak","clean it":"onu temizlemek","take a bath":"banyo yapmak","have a shower":"duş almak","sleep in it":"içinde uyumak","make the bed":"yatağı toplamak","sleep on it":"üstünde uyumak","put your head on it":"başını üstüne koymak","call a friend":"bir arkadaşı aramak","send a message":"mesaj göndermek","send an email":"e-posta göndermek","work on it":"onunla çalışmak","watch TV":"televizyon izlemek","turn it on":"onu açmak","turn on the TV":"televizyonu açmak","change the channel":"kanalı değiştirmek","read it":"onu okumak","open it":"onu açmak","sit on it":"üstüne oturmak","watch TV on it":"üstünde televizyon izlemek","drink tea":"çay içmek","drink coffee":"kahve içmek","put on make-up":"makyaj yapmak","put it on your lips":"dudaklarına sürmek","take your medicine":"ilacını almak","open the bottle":"şişeyi açmak","feed the cat":"kediyi beslemek","play with the cat":"kediyle oynamak","get on the bus":"otobüse binmek","wait for the bus":"otobüsü beklemek","squeeze it":"onu sıkmak","dry your hair":"saçını kurulamak","hang it up":"onu asmak","put a toothbrush in it":"içine diş fırçası koymak","look in it":"içine bakmak","comb your hair in front of it":"önünde saçını taramak","wash your body":"vücudunu yıkamak","wake up in it":"içinde uyanmak","lie on it":"üstüne uzanmak","take a photo":"fotoğraf çekmek","answer a call":"bir aramaya cevap vermek","look for a job":"iş aramak","watch the news":"haberleri izlemek","turn it off":"onu kapatmak","turn off the TV":"televizyonu kapatmak","pick it up":"onu almak","read a story":"bir hikâye okumak","close it":"onu kapatmak","take a pill":"bir hap almak","close the bottle":"şişeyi kapatmak","pet the cat":"kediyi sevmek","take the bus":"otobüse binmek","get off the bus":"otobüsten inmek","fill it":"onu doldurmak","fill it with water":"suyla doldurmak","get out of it":"ondan kalkmak","hug it":"ona sarılmak","call your boss":"patronunu aramak","read a message":"bir mesaj okumak","write an email":"e-posta yazmak","watch a video":"video izlemek","watch a film":"film izlemek","put it on the shelf":"rafa koymak","hold it":"onu tutmak","drink water with it":"onunla su içmek","give it water":"ona su vermek","take the bus to work":"işe otobüsle gitmek"}
d = json.load(open(P("data/vocab_test.json"), encoding="utf8"))
lines = {"Get a notebook and a pencil. Let's take notes.": "Bir defter ve kalem al. Hadi not alalım.", "That is right!": "Doğru!", "Try again.": "Tekrar dene.",
         "You should study the words again.": "Kelimeleri tekrar çalışmalısın.", "Your score.": "Puanın."}
for k in ("quiz", "quiz_b", "quiz_c"):
    for q in d[k]:
        q["tr_opts"] = [TR.get(o, "") for o in q["opts"]]
        lines["What can you do with %s?" % q["obj"]] = "%s ile ne yapabilirsin?" % q["tr"].capitalize()
        lines["You can %s and %s." % (q["opts"][0], q["opts"][1])] = "Bununla %s ve %s." % (TR[q["opts"][0]], TR[q["opts"][1]]) if False else "Şunları yapabilirsin: %s ve %s." % (TR[q["opts"][0]], TR[q["opts"][1]])
        lines["You can %s and %s." % (q["opts"][1], q["opts"][0])] = "Şunları yapabilirsin: %s ve %s." % (TR[q["opts"][1]], TR[q["opts"][0]])
json.dump(d, open(P("data/vocab_test.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
ex = json.load(open(P("data/extra_lines.json"), encoding="utf8"))
for e, t in lines.items(): ex.setdefault(e, t)
json.dump(ex, open(P("data/extra_lines.json"), "w", encoding="utf8"), ensure_ascii=False, indent=1)
def norm(s): s = re.sub(r"[^a-z0-9']", " ", s.lower()); return re.sub(" +", " ", s).strip()
idx = json.load(open(P("data/voice_index.json")))
ci = 0
while os.path.exists(P("voice/voice_%03d.bin" % ci)): ci += 1
todo = [l for l in lines if norm(l) not in idx]
from piper import PiperVoice
voice = PiperVoice.load("/workspace/build_assets/piper/en_US-ljspeech-medium.onnx")
out = bytearray()
for l in todo:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w: voice.synthesize_wav(l, w)
    open("/tmp/v.wav", "wb").write(buf.getvalue())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/v.wav", "-ar", "22050", "-c:a", "libvorbis", "-q:a", "1", "/tmp/v.ogg"], check=True)
    data = open("/tmp/v.ogg", "rb").read(); idx[norm(l)] = [ci, len(out), len(data), ""]; out += data
if todo: open(P("voice/voice_%03d.bin" % ci), "wb").write(out)
json.dump(idx, open(P("data/voice_index.json"), "w"))
print(len(lines), "lines,", len(todo), "new ->", "voice_%03d.bin" % ci, len(out), "bytes")
