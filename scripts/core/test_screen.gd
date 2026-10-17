## v33 (Yasin 16:14) UNIVERSAL TEST-SCREEN RULE, caption part. While any test / lesson screen is up (a Control in group
## "test_screen": the phone during lesson / quiz / score pages, the word-order puzzle panels) the ONE bottom-centre caption
## box stays hidden. A line whose text is already visible on that screen never shows the box (no doubled lines). A line that
## is NOT on screen shows the standard box (TR inside, unchanged) only while that line is queued / being spoken, then it
## hides again. Layout-only: it never changes what is said or captioned, only when the existing box is visible.
## Usage (preload, no class_name):  const TestScreen := preload("res://scripts/core/test_screen.gd");  TestScreen.mark(ctrl, true)
extends Node

const GROUP := "test_screen"
const CAP_GROUP := "caption_box"

static func mark(c: Node, on: bool) -> void:
	if c == null: return
	if on:
		if not c.is_in_group(GROUP): c.add_to_group(GROUP)
		if c.is_inside_tree(): ensure(c.get_tree())
	elif c.is_in_group(GROUP): c.remove_from_group(GROUP)

static func ensure(tree: SceneTree) -> void:
	if tree == null or tree.root.get_node_or_null("TestScreenGuard") != null or tree.root.has_meta("tsg_pending"): return
	var g: Node = load("res://scripts/core/test_screen.gd").new(); g.name = "TestScreenGuard"
	tree.root.set_meta("tsg_pending", true); tree.root.add_child.call_deferred(g)

## true while any test screen is visible
static func active(tree: SceneTree) -> bool:
	if tree == null: return false
	for r in tree.get_nodes_in_group(GROUP):
		if r is CanvasItem and (r as CanvasItem).is_visible_in_tree(): return true
	return false

static func norm(t: String) -> String:
	var o := ""; var sp := false
	for ch in t.to_lower():
		var u := ch.unicode_at(0)
		if (u >= 97 and u <= 122) or (u >= 48 and u <= 57) or u > 127: o += ch; sp = false
		elif not sp and o != "": o += " "; sp = true
	return o.strip_edges()

static func strip_who(t: String) -> String:
	var i := t.find(": ")
	if i > 0 and i <= 24 and not t.left(i).contains("."): return t.substr(i + 2)
	return t

var _st := {}   # box instance id -> {en, t0, seen, last}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().root.has_meta("tsg_pending"): get_tree().root.remove_meta("tsg_pending")
	process_priority = 1000   # after the hosts' own _process (a box shown this frame is judged before it is drawn)

func _process(_d: float) -> void:
	var roots: Array = []
	for r in get_tree().get_nodes_in_group(GROUP):
		if r is CanvasItem and (r as CanvasItem).is_visible_in_tree(): roots.append(r)
	if roots.is_empty():
		if not _st.is_empty(): _st.clear()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var screen := ""; var have_screen := false
	for b in get_tree().get_nodes_in_group(CAP_GROUP):
		if not (b is CanvasItem): continue
		var id := b.get_instance_id()
		if not (b as CanvasItem).visible: _st.erase(id); continue
		if b.has_meta("ts_force_until") and Time.get_ticks_msec() < int(b.get_meta("ts_force_until")): continue   # ui33: an off-screen line forced into the box (TestBank _say_off) stays while it is spoken
		var en := _box_text(b)
		var key := norm(strip_who(en))
		if not have_screen: screen = " " + norm(_collect(roots)) + " "; have_screen = true
		if key == "" or screen.contains(key):
			(b as CanvasItem).visible = false; _st.erase(id); continue
		var st: Dictionary = _st.get(id, {})
		if st.is_empty() or st.en != en: st = {"en": en, "t0": now, "seen": false, "last": now}; _st[id] = st
		if _audio_has(strip_who(en)): st.seen = true; st.last = now
		var words := en.split(" ", false).size()
		var read_s := clampf(0.6 + words * 0.38, 1.8, 6.0)
		if (st.seen and now - st.last > 0.35) or (not st.seen and now - st.t0 > read_s):
			(b as CanvasItem).visible = false; _st.erase(id)

## the line is waiting in / playing on the global voice queue
func _audio_has(en: String) -> bool:
	var a := get_node_or_null("/root/Audio")
	if a == null: return false
	var k := norm(en)
	if a.is_speaking() and norm(String(a.get("cur_what"))) == k: return true
	for it in a.get("queue"):
		if it is Dictionary and norm(String(it.get("what", ""))) == k: return true
	return false

## first non-empty Label in the box = the EN line (TR label comes after it)
func _box_text(n: Node) -> String:
	for c in n.get_children():
		if c is Label and String(c.text).strip_edges() != "": return String(c.text)
		var r := _box_text(c)
		if r != "": return r
	return ""

func _collect(roots: Array) -> String:
	var parts := PackedStringArray()
	for r in roots: _walk(r, parts)
	return " | ".join(parts)

func _walk(n: Node, parts: PackedStringArray) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible: return
	if n is Label: parts.append(String(n.text))
	elif n is Button: parts.append(String(n.text))
	elif n is RichTextLabel: parts.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children(): _walk(c, parts)
