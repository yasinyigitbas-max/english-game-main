## house.16 shared phone host for the rooms outside the bedroom (bathroom, living room).
## Uses exactly the bedroom's phone UI (scripts/phone.gd: jobs / calendar / family / lessons) and the bedroom's
## pocket-phone sequence (scripts/pocket_phone.gd) on the shared HUD phone button. State lives in user://save.json
## ("state" = the bedroom's S), so everything done on the phone here is seen in every room.
extends Node

var host: Node            # the room script (hero, cam, mode, stick, caption())
var S := {"name": "", "job": "", "family": [], "lesson_done": false, "calendar_seen": false, "door_opened": false,
	"created": false, "has_phone": false, "door_locked": true, "age": "adult", "tr": false, "voice": true}
var phone: Control
var phone_btn: Button
var pocket: Node
var font_b: FontVariation
var notify_app := ""
var extra := {}
signal phone_done

func setup(h: Node, parent: Control, btn: Button, set_cam := Callable()) -> void:
	host = h; phone_btn = btn
	_load()
	font_b = FontVariation.new(); font_b.base_font = load("res://fonts/Nunito.ttf")
	font_b.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	phone = load("res://scripts/phone.gd").new(); phone.main = self; phone.visible = false
	parent.add_child(phone)
	phone.job_chosen.connect(_on_job_chosen)
	phone.lesson_finished.connect(func(): S.lesson_done = true; save())
	phone.family_saved.connect(_on_family_saved)
	phone.calendar_opened.connect(func():
		if not S.calendar_seen and (not S.family.is_empty() or is_child()): S.calendar_seen = true; save())
	for c in btn.pressed.get_connections(): btn.pressed.disconnect(c.callable)
	btn.pressed.connect(func(): if host.mode == "play": Audio.click(); open_phone())
	pocket = load("res://scripts/pocket_phone.gd").new(); add_child(pocket)
	pocket.character = host.hero; pocket.camera = host.cam
	if set_cam.is_valid(): pocket.set_camera = set_cam
	notify_app = _objective_app()

func _process(_d: float) -> void:
	if phone_btn:
		var hide: bool = phone.visible or (pocket and pocket.busy)
		phone_btn.modulate.a = 0.0 if hide else 1.0; phone_btn.disabled = hide

func _load() -> void:
	var d := _read()
	if d.get("state") is Dictionary:
		for k in d.state: S[k] = d.state[k]
	S.has_phone = bool(d.get("has_phone", S.get("has_phone", false)))
	App.has_phone = S.has_phone

func _read() -> Dictionary:
	if not FileAccess.file_exists(App.SAVE_PATH): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(App.SAVE_PATH))
	return d if d is Dictionary else {}

## writes S back into save.json, keeping the bedroom's pos/yaw and other keys
func save() -> void:
	var d := _read()
	if d.is_empty(): d = {"version": 1}
	d.state = S; d.has_phone = S.has_phone; d.family_breakfast = App.family_breakfast
	var f := FileAccess.open(App.SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(d, "\t"))

func open_phone() -> void:
	if host.mode != "play" or phone.visible or pocket.busy: return
	if not S.has_phone:
		caption("My phone is in the bedroom."); return
	host.mode = "busy"; host.stick = Vector2.ZERO
	if host.has_method("_hide_chips"): host._hide_chips()
	if "hand3d" in host and host.hand3d: host.hand3d.visible = false
	await Audio.wait_idle(12.0)   # house.17: wait for the current announcement
	caption("I am looking at my phone.")
	var first: String = "jobs" if S.job == "" else ("calendar" if is_child() and not S.calendar_seen else ("family" if S.family.is_empty() else ("calendar" if notify_app == "calendar" else "home")))
	pocket.open_ui = func(r: Rect2):
		_closed_wait()
		await phone.open(r, first)
		await phone_done
	await pocket.use()
	notify_app = _objective_app()
	host.mode = "play"
	if host.has_method("_update_hand"): host._update_hand()

func _closed_wait() -> void:
	await phone.closed
	phone_done.emit()

# ---- interface phone.gd expects from its main (same as main.gd)
func caption(t: String, speak := true) -> void:
	if host and host.has_method("caption"):
		if host.get_method_argument_count("caption") >= 2: host.caption(t, speak)   # house.29
		elif speak: host.caption(t)

func extra_tr(t: String) -> String:
	if extra.is_empty():
		var d = App.load_json("res://data/extra_lines.json"); extra = d if d is Dictionary else {"_": ""}
	var r: String = extra.get(t, "")
	if r == "" and t.begins_with("I weigh ") and t.ends_with(" kilos."): r = "%s kiloyum." % t.trim_prefix("I weigh ").trim_suffix(" kilos.")   # v29.1
	if r == "" and t.begins_with("My name is ") and t.ends_with("."): r = "Benim adım %s." % t.trim_prefix("My name is ").trim_suffix(".")
	return r

func is_child() -> bool: return S.get("age", "adult") == "child"
func member_saved() -> void: save()
func door_rule() -> bool: return not (S.created and S.job != "" and not S.family.is_empty())

func _objective_app() -> String:
	if not S.created: return ""
	if WorldState.day > 1 and not S.calendar_seen: S.calendar_seen = true
	if S.job == "": return "jobs"
	if is_child() and not S.calendar_seen: return "calendar"
	if not S.lesson_done or S.family.is_empty(): return "family"
	if not S.calendar_seen: return "calendar"
	return ""

func phone_event(p: String) -> void:
	if p == "family" and phone.page == "lesson": p = "lesson"
	match p:
		"jobs": caption("I am choosing my job." if S.job == "" else "I am opening the Jobs app.")
		"grammar": caption("I am learning grammar.")
		"words": caption("I am learning new words.")
		"me": pass   # house.17: "I am looking at my phone." only once per open (said on open)
		"lesson":
			if phone.les.is_empty(): caption("I am learning about he, she and it.")   # house.17: not for the breakfast lesson
		"quiz": caption("I am answering a question.")
		"family": caption("I am adding my family.")
		"member": caption("I am adding a family member.")
		"calendar": caption("I am looking at my calendar.")

func todo() -> Array:
	return [["Turn off the alarm.", true], ["Look in the mirror.", S.created], ] + ([] if is_child() else [["Choose a job.", S.job != ""]]) + [
		["Learn he, she and it.", S.lesson_done], ["Add your family.", not S.family.is_empty()], ["Open the Calendar.", S.calendar_seen],
		["Open the door.", S.door_opened], ["Explore the house.", false]] + \
		(phone.tasks(S.job).map(func(t): return [t.do, false]) if S.job != "" else [])

func _on_job_chosen(id: String) -> void:
	S.job = id; S.door_locked = door_rule()
	caption(phone.job(id).get("now", "I am a %s now." % id))
	save()

func _on_family_saved() -> void:
	S.door_locked = door_rule()
	App.family_breakfast = true
	save()
	caption("This is my family.")
	Audio.sfx("metalClick", 3.0, 1.15)
	if host.has_method("spawn_family_breakfast") and not S.family.is_empty(): host.spawn_family_breakfast(S.family)
