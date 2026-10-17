extends Node
## v32-polish QA probe: phone lesson / family / jobs TR visibility (TR on, and TR off -> on).
func _dump(ph: Node, tag: String) -> void:
	var out := []
	var st := [ph]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Label or n is Button:
			var t: String = n.text
			if t != "": out.append("%s%s" % ["" if (n as CanvasItem).is_visible_in_tree() else "[H]", t.replace("\n", "|")])
		for c in n.get_children(): st.append(c)
	print("PROBE ", tag, " TR=", App.tr_on(), " :: ", " ; ".join(out.slice(0, 60)))
func _ready() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var ph = load("res://scripts/phone.gd").new(); ph.visible = true; ph.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(ph)
	await get_tree().process_frame
	App._trf = 0
	ph.start_set(App.load_json("res://data/can_should.json"), "lesson")
	for i in 40: await get_tree().process_frame
	_dump(ph, "lesson_off")
	App._trf = 1
	for i in 20: await get_tree().process_frame
	_dump(ph, "lesson_off_to_on")
	ph.start_set(App.load_json("res://data/can_should.json"), "lesson")
	for i in 20: await get_tree().process_frame
	_dump(ph, "lesson_on")
	ph.les = {}; ph._unlocking = true
	App._trf = 0
	for p in ["jobs", "family"]:
		ph._unlocking = true; ph.show_page(p, false)
		for i in 40: await get_tree().process_frame
		_dump(ph, p + "_off")
		App._trf = 1
		for i in 20: await get_tree().process_frame
		_dump(ph, p + "_off_to_on")
		App._trf = 0
	get_tree().quit()
