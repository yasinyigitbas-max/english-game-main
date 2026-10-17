## Voice (autoload): English Piper line for a caption, through the house's ONE global voice queue (Audio autoload,
## scripts/audio.gd): a new line never cuts or drops the current one. House clips (data/voice_index.json) are used
## when the line exists there; outdoor lines use res://voice/<md5 first 12>.ogg (tools/build_voice.py).
## No Turkish voice: Turkish is TR text only.
extends Node

var enabled := true

static func clip_path(en: String) -> String: return "res://voice/%s.ogg" % en.md5_text().substr(0, 12)

func has_clip(en: String) -> bool: return Audio.has_clip(en)   # v33 (red): the chosen narrator's clip

func say(en: String) -> void:
	if not enabled or en.strip_edges() == "": return
	Audio.say(en)   # v33 (red): universal narrator - Audio.own_clip (chosen voice only; f: same ljspeech model on device; else silent)

func clip_len(en: String) -> float:
	var p := clip_path(en)
	var st = load(p) if ResourceLoader.exists(p) else null   # blue v29: null guard
	return (st as AudioStream).get_length() if st is AudioStream else 2.0

func busy() -> bool: return Audio.is_speaking()
