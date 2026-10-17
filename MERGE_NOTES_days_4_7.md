# v33-days-4-7-red (red): days 4 and 7 + shared bedtime test bank

Base: english-game-red `v32-polish-red` de3218f. Not run in Godot (QA owns the box): reviewed by reading only.

## 1. Shared no-repeat bedtime test bank (for blue's days 5 / 6 too)
Files: `scripts/story/test_bank.gd` (class_name TestBank, but reference it by PATH), `data/test_bank.json`.
```gdscript
const TB := preload("res://scripts/story/test_bank.gd")
var qs: Array = TB.draw(5, 10)                  # 10 questions of day 5, never used before
var res: Array = await TB.run_test(m, m.phone, 5) # full phone test page -> [score, total]
```
- `TB.draw(day:int, n:int = 10, topics:Array = [], ver:int = -1) -> Array` of `{id, day, v, topic, q, opts, a, say, tr}`
  (opts shuffled, `a` = index of the right option in the shuffled opts, question order shuffled).
  Order: (1) unused questions of the day's CURRENT version, (2) unused questions of its other versions,
  (3) unused review questions of EARLIER days with the same topics, (4) only if all of that is used up: the day's least
  recently used questions (a test is never empty). Every draw marks its ids as used and rotates the day's version
  (0 -> 1 -> 2 -> 0), so Retake gets a new set. `topics = []` = all topics of the day; unknown topics = the whole day.
- Save: `save.json "test_bank" = {"used": [ids, most recent last], "ver": {"4": 1, ...}}` (App.patch_save; survives
  continue / reload).
- `TB.questions(day, topics := [])`, `TB.version(day)`, `TB.used_ids()`, `TB.is_used(id)`, `TB.mark_used(ids)`,
  `TB.reset(day := 0)` (0 = all).
- `TB.run_test(host, phone, day, {"n": 10, "topics": [], "key": "TestBank_d5"})`: same rules as d2/d3_night_test.gd:
  notebook reminder once (not on Retake), answers wait for the narrator, feedback + TR, score page, "You should study the
  grammar again." when half or more are wrong, Retake (= fresh draw), Continue, shared skip button (`tests_skipped.<key>`).
  host must have `caption(t, speak)` (main.gd / livingroom.gd do). The phone must exist; it is opened if needed.
- Data: one entry per question, `id` unique (`d5_01`...), `day`, `v` (0/1/2), `topic`, `q` (`___` = gap), `opts`, `a`, `say`,
  `tr`. Seeded: day 2 (18, from day2_evening.json quiz/quiz_b/quiz_c), day 3 (18, from day3_evening.json), day 4 (30),
  day 7 (30). **Blue: append 30 entries for day 5 and day 6 (10 per version)** and add each `say` -> TR to
  data/extra_lines.json. Topics in use: past_simple, countable, how_many_much, cafe_order, containers, there_is_are,
  prepositions, power_cut, party (list in the json `topics`).
- d2/d3_night_test.gd are unchanged (they still use their own 6-question sets).
