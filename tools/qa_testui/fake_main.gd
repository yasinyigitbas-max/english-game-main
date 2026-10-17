## QA stand-in for a room host (main.gd / room_phone): font, S, caption(), caption_live(), phone_event()
extends Node
var font_b: FontVariation
var S := {"name": "Yasin", "job": "teacher", "family": [], "lesson_done": false, "tr": true, "voice": true, "age": "adult"}
var ui: StoryUI
var extra := {}
func _init() -> void:
	font_b = FontVariation.new(); font_b.base_font = load("res://fonts/Nunito.ttf")
	font_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
func caption(t: String, speak := true) -> void:
	ui.en_l.text = t; ui.tr_l.text = StoryUI.tr_of(t); ui._sync_tr(); ui.panel.visible = t != ""
	if t != "": StoryUI.claim(ui.panel)
	if speak and t != "": Audio.say(t)
func caption_live(line: String, tr_line := "") -> void:
	ui.live(line, tr_line)
func phone_event(_e: String) -> void: pass
func extra_tr(t: String) -> String: return StoryUI.tr_of(t)
func is_child() -> bool: return false
func member_saved() -> void: pass
func _say_me(en: String, _tr: String) -> void: caption("Me: " + en, false)
