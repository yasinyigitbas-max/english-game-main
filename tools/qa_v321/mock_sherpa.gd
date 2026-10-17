extends RefCounted
## desktop stand-in for the Android SherpaTts plugin (same method names / file lists as SherpaTts.java); logs every call
var calls: Array = []
var fail := {}
func _model(v: String) -> String: return "joe" if v == "m" else ("kokoro" if v in ["c", "g"] else "lj")
func narratorFiles(v: String) -> String:
	match _model(v):
		"joe": return "en_US-joe-medium.onnx,tokens_joe.txt"
		"kokoro": return "kokoro/model.onnx,kokoro/voices.bin,kokoro/tokens.txt"
	return "en_US-ljspeech-medium.onnx,tokens.txt"
func initNarrator(dir: String, v: String) -> bool:
	calls.append(["init", v, dir]); print("MOCK initNarrator ", v, " ", dir); return not fail.has(v)
func generateNarrator(v: String, text: String) -> PackedByteArray:
	calls.append(["gen", v, text]); print("MOCK generateNarrator ", v, " | ", text)
	var b := PackedByteArray(); b.resize(22050); return b
func getSampleRate() -> int: return 22050
