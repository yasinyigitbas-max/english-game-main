## v33 (blue): THIN ADAPTER to red bot's shared no-repeat question bank (days 5 + 6 bedtime tests). Do not add questions here.
## TODO(red bank): red's shared bank did not exist yet (2026-10-17 13:50: no bank / no_repeat / question_bank / QuestionBank in any
##   english-game-red branch or in english-game-main; red exposes it ~15:45 with its days 4/7 work). When it lands, point _bank() at it
##   and confirm the call in draw() (currently: bank.draw(topics, n, key) -> Array of {q, opts, a, say, tr}). Until then the day's
##   own three rotating versions (data/day5.json / day6.json quiz, quiz_b, quiz_c) are used.
class_name Day56Bank
extends RefCounted

const AUTOLOADS := ["QuestionBank", "QBank", "SharedBank"]
const SCRIPTS := ["res://scripts/core/question_bank.gd", "res://scripts/story/question_bank.gd", "res://scripts/question_bank.gd"]

static func _bank() -> Object:
	var root := (Engine.get_main_loop() as SceneTree).root
	for nm in AUTOLOADS: if root.has_node(nm): return root.get_node(nm)
	for p in SCRIPTS: if ResourceLoader.exists(p): return load(p)
	return null

## n questions for the bedtime test of `day`; version 0..2 rotates (and Retake asks for the next version)
static func draw(key: String, day: int, topics: Array, n: int, version: int, local: Array) -> Array:
	var b := _bank()
	if b:
		for fn in ["draw", "draw_questions", "pick"]:   # TODO(red bank): keep only the real one
			if b.has_method(fn):
				var r = b.call(fn, topics, n, key)
				if r is Array and r.size() >= mini(n, 5):
					print("D56 bank: %s.%s day %d -> %d questions" % [b, fn, day, r.size()])
					return r.slice(0, n)
	if local.is_empty(): return []
	return (local[version % local.size()] as Array).slice(0, n)

static func source() -> String: return "red bank" if _bank() != null else "local fallback (TODO red bank)"
