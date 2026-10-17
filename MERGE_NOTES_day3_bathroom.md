# MERGE NOTES v32 (red) - day-3 morning: bathroom objective + bathroom door + town pan

Branch `v32-day3-bathroom` off `v31-evening-day3` (c22ef0e). **UNTESTED**: Godot was not run (code review only; no QA run, no screenshots).
No file outside this repo was needed: the "trying" block is in `scripts/main.gd`, which is already on the branch.
`/workspace/english_game_3dv2`, `/workspace/story_red_v31`, `/workspace/story_red_v31b` were only read.

## Bug 1: "Take a shower." immediately replaced by "Go to the living room."
Root cause: `main.gd objective()` has no day-3 case. The bathroom step there is `not App.bath_done and WorldState.day < 2`
(v31: no bathroom requirement on day 2+), so on day 3 it always falls through to `"Go to the living room."`.
`_advance(false)` runs from `_continue_game()` (every bedroom entry) and again in the bathroom-door action (`"door"` branch,
`S.door_opened = true; _advance(false)`), so `_set_mission("Go to the living room.")` overwrote the `Take a shower.` objective
that `Day3Morning` had just given (and spoke it). Day3Morning only re-adds its objective when its id is missing, so both showed / flipped.

Fix (living room objective is gated on the SHOWER, not on entering the bathroom):
- `scripts/main.gd:1877` `objective()`: `if _day3_stage() == "shower": return ["Take a shower.", ""]`.
- `scripts/main.gd:1842-1845` new `_day3_stage()` (story.d3 via `Day3Morning.stage()`, day 3+ only).
- `story.d3` goes `"shower" -> "living"` only in `Day3Morning._on_bath_action()` when the bathroom's `last_dur` has
  `takeshower` (the Take a shower action finished). Then "I feel fresh and clean." and the usual
  `Life.guide_to` pan onto the bathroom door with "Go to the living room." (unchanged code).
- `scripts/story/day3_morning.gd:103-105` new match case `["shower", "living"], ["shower", "outside"]`: when the player walks
  past the bathroom without showering, the objective stays "Take a shower." (objective + sound, no pan, no living-room step).

## Bug 2: bathroom door says "I am trying to open the door."
Root cause: `scripts/main.gd:666` (`verbs()` for the bedroom->bathroom `door`): the chip is the "try" variant when
`S.door_locked or not S.has_phone`. "Take your phone first" is a day-1 rule, but on day 3 the phone is still on the end table
charging from the night before ("Charge my phone." / `charge_phone()` sets `S.has_phone = false`), so the bathroom chip
showed the blocked "I am trying to open the door." line. (`S.door_locked` itself is false on day 3; `door_rule()` only needs
mirror + job + family. The bathroom's own doors are open on day 2+ already: `bathroom.gd` `WorldState.day < 2` checks.)
No WorldState flag / day-2 bath flag involved; `App.bath_done` is not read for the bathroom door at all.
Fix: `scripts/main.gd:666` -> `S.door_locked or (not S.has_phone and WorldState.day < 2)` (same day rule as `s_locked()`).
Day 1 is unchanged.

## O8 kept: "Charge my phone." objective
This branch did not have black's v31.1 O8 fix. Every `Objectives.set_list([_cur])` in day3_morning.gd (old lines 51 and 63,
and the `"list": [_cur]` passed to Life.guide_to) dropped Life's `charge` entry. Also `Life.guide_to` -> `main._set_mission()`
rewrites the list with the objective only.
- `scripts/story/day3_morning.gd:11` `_charge` cache; `:55-73` new `_list()` ([current objective] + charge entry) and
  `_keep_charge()` (re-adds "Charge my phone." / "Telefonumu şarj et." when a room rewrote the list, unless the phone is now
  charging or full, i.e. Life completed it).
- `:52` (old 51), `:84` (old 63), `:87` use `_list()`; `:88` `_keep_charge()` after every guide.
- If black's O8 version is merged too, keep either one; they do the same thing (charge entry next to the day-3 objective).

## Day 3 "Explore the town." camera pan (cafe -> shop -> player)
Root cause: the old target was `player + basis.z * -6` (6 m "ahead"). At the home spawn that is our own house, and
`Life.guide_to`'s exterior temp camera lerps in a straight line from the follow camera, so it flew through the house walls.
Fix: `scripts/story/day3_morning.gd:119-125` the "Explore the town." case now calls `Life.guide_to(null, ...)`
(objective + sound + top-left list, no Life pan; caption first as before), then the new `_town_pan(sc)` (`:129-224`):
- Stops: `grid.find_lot("cafe")` and `grid.find_lot("corner_shop")` (block_shops.tscn, cell (0,1); lot `entrance_global()` +
  facing). Fallback if the block is not streamed in yet: cafe entrance (8.5, 0.07, 27.6), shop entrance (-3, 0.07, 27.6).
  Camera at entrance + 6.5 m out over the road (z ~21, road z 16..24), height 6.5 m, looking at the door.
- Path (never a straight line through buildings): straight UP from the follow camera to CRUISE_Y 14 m (above every roof:
  houses <= ~4.9 m incl. roof, shops 3.4 m, trees ~4 m) -> cruise at 14 m to above the cafe stop -> drop onto the road ->
  "Here is the café." -> along the road to the shop stop (same street; otherwise up / cruise / down) -> "Here is the shop."
  -> up to 14 m -> cruise to above the follow camera -> blend onto the live follow-camera transform -> rig current again.
- Own temporary Camera3D, per-frame moves (no Tween), so a scene change mid-pan cannot leave `_busy` stuck; player frozen via
  `mode = "busy"` and restored to "play". Plays once per outdoor visit; `story.d3 = "done"` after it.
- The new lines avoid "This is ...": `Lines.tr_of()` turns any "This is X." into "Burası X." before extra_lines is read.

## v32b: day-3 town cues (cafe / shop / home), after "Explore the town."
Hooked only from `scripts/story/day3_morning.gd`. **No blue file touched** (blue's `cafe-shop` / `shop-apples-inside` branches
were read from a separate read-only clone, `/workspace/blue_ro_d3`).
Blue's signals used (read-only, `scripts/places/place_base.gd` on blue's cafe-shop branch):
- exit: `PlaceBase.leave()` sets `App.came_from = place_id` ("cafe" / "shop") and calls `Game.go_to(Game.WORLD_SCENE, "lot:cafe" / "lot:corner_shop")`
  (blue's newer world_exterior also maps spawns "cafe_door" / "shop_door"; both are accepted)
- interiors: `res://scenes/places/cafe.tscn` / `shop.tscn` (blue's completion flags are `places.cafe.done` / `places.shop.done`; not
  required here: entering the place counts as visited, the cue plays when the player comes back out)
- Note: blue's entry hook (`interior_scene = ...` on the CornerShop / Cafe lots in block_shops.tscn) is still pending on blue's side;
  until it is merged the cafe / shop cannot be entered and only "Explore the town." shows.

Stages / flags (save.json "story"): `d3` = "shower" -> "living" -> "outside" -> **"town"** (after the Explore pan; was "done")
-> **"home"** (both visited) -> "done" (back in the house). Visited flags: **`d3_cafe`**, **`d3_shop`** (bool).

Flow:
- Leave the cafe first -> objective **"Go to the shop."** + pan to the shop. Leave the shop first -> **"Go to the café."** + pan to the cafe.
- Leave the second place -> stage "home", **"Go back home."** + pan to our house (stop over the road in front of it, z ~19, 9 m high).
- Back in the house (living room via the front door, or any house room) in stage "home" -> `Objectives.complete("Go back home.")`, d3 = "done".
- Outside again without having just left a place: the current step as an objective only, no pan. In the house during "town": same, no pan.
- Pans: the cue calls `Life.guide_to(null, text, {id, tr, list})` (objective + notify sound + top-left list, the same API every
  objective uses), then the shared over-the-roofs path `_pan()` (rise to 14 m -> cruise -> drop onto the road in front of the lot ->
  hold -> rise -> cruise -> blend back onto the follow camera). Life's own straight-line exterior pan is not used (it clips walls).
- One bottom caption box: every line goes through the scene's one caption queue (`sc.caption`); the cue line is captioned once
  before the pan and the hold at the stop adds no second caption. No StoryUI / extra caption panels.

Code (scripts/story/day3_morning.gd):
- `:29-40` `_kind()`: blue's `/places/cafe*` / `/places/shop*` scenes -> "cafe" / "shop"; only `world_exterior.tscn` is "outside";
  everything else (hospital, work, QA) -> "other" (no cues / pans there; it used to count as "outside").
- `:43` `_from`; `:54-58` on a scene change: read `App.came_from` / `Game.spawn` at once, and mark the place visited when its
  interior opens (stage town/home).
- `:102` `_enter()` returns at once for cafe / shop / other (no 30 s `_wait_free` inside blue's cinematics).
- `:130-148` "Explore the town." now uses `_pan()` with two stops and sets d3 = "town"; new match cases for town / home.
- `:150-253` pan code generalised: `LOT_FB` fallbacks (home, cafe, corner_shop), `_lot_view(sc, lot_id, line)` places the stop
  over the road in front of ANY lot (from the lot's block cell and facing: cafe 6.6 m out, home 15.5 m out), `_pan(sc, stops)`.
- `:255-285` `flag()` / `set_flag()` (story flags), `_mark_place()`, `_town_next()`, `_town_cue()`.
- scripts/qa_v31c.gd `:119-131`: the end check expects d3 "town" (was "done") and adds a simulated cafe exit -> "Go to the shop.",
  shop exit -> "Go back home." + stage "home", then the living room -> "done" (fakes PlaceBase.leave(), no interiors needed).
- Known limit: `App.came_from` stays "cafe"/"shop" until another scene sets it, so a reload of the outdoor scene right after a
  visit would re-cue (marking is idempotent; one pan per scene instance).

## v32c: day-3 evening (family couch talk) -> day-3 bedtime -> DAY 4
UNTESTED (Godot not run). Modelled on day2_evening.gd / day2_evening.json / bedtime.gd. No blue / black file touched.

Flow:
1. Player comes home through the front door after BOTH places (story.d3 "home", d3_cafe + d3_shop) -> living room:
   `Life.guide_to` pan onto the sofa, objective **"Talk to my family."** ("Ailemle konuş."), kept on the list until the couch.
2. At the couch: d3_couch_done + d3_bed_pending, `Life.event("home")` (18:00), the player sits on a FREE sofa seat (or stands
   next to the sofa when the family fills it; day 2 could sit on top of a family member), couch shot, couch snapshot `d3_couch`.
3. Talk: family "How was your day?" -> me "It was a good day." -> "Put the words in the right order." -> 7 family question /
   scrambled-word puzzle pairs (data/day3_evening.json "talk"): Where did you go? -> I went to the café. / What did you order?
   -> I'd like a hot chocolate, please. / How many cookies did you have? -> I had two cookies. / And then? -> I went to the shop.
   / How many apples did you buy? -> I bought six apples. (+ "Apples are countable, so we ask: How many apples?") / How much milk
   did you buy? -> I bought a bottle of milk. (+ "Milk is uncountable, so we ask: How much milk?") / I bought a loaf of bread.
   Then "Thank you for the shopping! Well done.", "You must be tired. Go to bed.", me "Good night!", stand up.
   (Sentences match blue's cafe order = hot chocolate + two cookies, and blue's shopping list = six apples, milk, bread.)
4. `Life.guide_to` pan onto the bedroom door, **"Go to bed."** (kept on the list). A continued game re-shows it (start() -> bed_prompt()).
5. Bedroom: `Bedtime` with `night = 3`: "Go to bed." pan onto the bed, lie down (bed_lock), dream polaroids d3_shower /
   d3_cafe / d3_shop / d3_couch (real couch snapshot; player-look stills from d3_polaroids.gd otherwise) + "Went, ordered,
   bought: this is the past simple.", test d3_night_test.gd (3 versions x 6: cafe order, countable / uncountable, how many /
   how much, past simple; Retake, grammar tip, Skip, quiz_ver key "Day3Shop"), "Good night!", "I am sleeping.", fade.
6. DAY 4: `Life.advance_day(true)` (+ forced `WorldState.day = 4`, App.day = 4, save "day" 4 if it was not 4), 07:00, silent
   "Day 4" title (TR "4. Gün"), no alarm; wake with ONLY **"I'm waking up."** (sit up, edge) then **"I'm getting up."** (stand).
7. Placeholder day-4 first objective: `Life.guide_to` pan onto the living-room door, **"Start your day."** ("Gününe başla.");
   story.d4 = "start"; main.gd objective() keeps it on day 4+ while d4 == "start" (replace when day 4 is designed).

Rules: one bottom caption box (lr.caption / lr._say_as / lr._say_me in the living room; StoryUI caption with the room panel
hidden during the dream, as on day 2; m.caption on waking); the puzzle is the centre panel (Objectives.ovl_register) like day 2.
NPCs keep their pose: the family is put on the TV seats (`family_at_tv_now()`), and while the evening runs
`Day3Evening._process` re-applies `sit_down(node, seat, false)` to any seated family member whose clip is no longer sit_idle.

Flags (save.json "story"): d3_couch_done, d3_bed_pending, d3_couch_told, d3_recap, d3_night_score, d3_bedtime_done, d4 = "start".

Files:
- NEW scripts/story/day3_evening.gd (`class_name Day3Evening`; entry `Day3Evening.start(get_tree())`; start/ready_to_run/run/_ask/
  _sit/bed_prompt/_process (objective keeper + pose keeper)/_line/_snap_couch/_puzzle (keeps "?" and commas))
- NEW data/day3_evening.json (lines EN->TR, talk, recap, quiz / quiz_b / quiz_c)
- NEW scripts/story/d3_night_test.gd (= d2_night_test.gd with DATA = day3_evening.json, KEY = "Day3Shop")
- NEW scripts/story/d3_polaroids.gd (extends d2_polaroids.gd: d3_shower, d3_cafe, d3_shop, d3_couch stills)
- scripts/story/bedtime.gd: `:7-10` header, `:22` `night`, `:33-35` day-3 hook in hook_bedroom, `:86-94` day-3 recap list,
  `:109-110` d3 stills, `:123` closing line, `:127` d%d_recap, `:155-156` d%d_night_test / score, `:168` night 3 -> `_sleep_to_day4`,
  `:189-226` `_sleep_to_day4`, `_wake_simple`, `_day4_prompt`, `:228-240` `_day_title(speak)` (day 4 silent). Day 2 unchanged.
- scripts/livingroom.gd `:191` hook line in `_intro()`: `load("res://scripts/story/day3_evening.gd").start(get_tree())`
- scripts/main.gd `:1842-1845` `_story_str()`, `:1883` day-4 placeholder objective in `objective()`
- scripts/qa_v31c.gd `:131` checks "Talk to my family." after the town cues (the couch talk itself is not driven by QA)
- data/extra_lines.json: +33 entries (every new line, incl. test feedback sentences, "Day 4")
- .gitignore: allow-list for the 4 new files

### VOICE NEEDS v32c (none of these are in english_game_3dv2/data/voice_index*.json)
Narrator / player (narrator packs f/m/c/g):
- Talk to my family.
- It was a good day.
- I went to the café.
- I'd like a hot chocolate, please.
- I had two cookies.
- I went to the shop.
- I bought six apples.
- I bought a bottle of milk.
- I bought a loaf of bread.
- Apples are countable, so we ask: How many apples?
- Milk is uncountable, so we ask: How much milk?
- I am standing next to the sofa.
- I took a shower.
- Went, ordered, bought: this is the past simple.
- I'm waking up.
- I'm getting up.
- Start your day.
Family (Audio.say_as, each family member's voice):
- Where did you go?
- What did you order?
- How many cookies did you have?
- And then?
- How many apples did you buy?
- How much milk did you buy?
- Thank you for the shopping! Well done.
Test feedback (narrator reads q.say), new: Apples are countable. / Milk is uncountable. / Can I have a cookie, please? /
How many cookies would you like? / How much is the coffee? / How many apples did you buy? / How much milk did you buy? /
I ordered a hot chocolate. / I took a shower in the morning. (the other q.say lines are in the lists above)
Reused from the v31c list (also still to render): How was your day? / You must be tired. Go to bed. (family) / Good night! /
I am dreaming about my day. / Now a short test about my day. / I am sleeping. / I talked to my family. / Put the words in the
right order. (voiced) / I am sitting on the sofa. (voiced) / Go to bed. / I am going to bed. / I am lying in bed.

## New player-visible lines (TR in data/extra_lines.json, +2 entries v32 / +3 entries v32b)
- "Here is the café." -> "İşte kafe."
- "Here is the shop." -> "İşte dükkân."
- v32b: "Go to the café." -> "Kafeye git.", "Go to the shop." -> "Dükkâna git.", "Go back home." -> "Eve dön."
(Already had TR: "Take a shower." / "Go to the living room." / "Explore the town." / "I feel fresh and clean." / "Charge my phone.")

## VOICE NEEDS (narrator packs f/m/c/g)
- Here is the café.
- Here is the shop.
- Go to the café.   (v32b)
- Go to the shop.   (v32b)
- Go back home.     (v32b)
(none of the five is in data/voice_index*.json yet)

## Files
- scripts/main.gd (lines 666, 1842-1845, 1877)
- scripts/story/day3_morning.gd
- data/extra_lines.json
- scripts/qa_v31c.gd (v32b: day-3 end checks for the town cues)
- MERGE_NOTES_day3_bathroom.md, .gitignore (allow-list)

## Status
UNTESTED (v32, v32b and v32c). Suggested QA: qa_v31c day-3 leg: after the alarm the list must stay "Take a shower." (+ "Charge my phone." if
present) through bedroom -> bathroom door -> bathroom; the bathroom chip must read "I am opening the door."; "Go to the living
room." only after Take a shower; outside: the pan shows the cafe then the shop and returns to the player without entering walls.
v32b: run qa_v31c (the day-3 tail now covers the cafe / shop / home cues); with blue's interiors merged, enter + leave each place.
v32c: from "Talk to my family.": solve the 7 puzzles (TR off / on), check the family stays seated, Go to bed. -> dream (4 cards) ->
test (Skip + Retake) -> Day 4 title -> only "I'm waking up." / "I'm getting up." -> "Start your day." pan; WorldState.day == 4.

## Port to english-game-main (v31.1), branch v32-day3-morning-main
- O8: english-game-main already has black's v31.1 O8 fix in `scripts/core/objectives.gd` (`set_list()` / `clear()` keep the
  `charge` entry while the phone is not charging and the battery is under 30 %; Life adds it under 15 % and completes it when
  charging). That covers every day-3 `set_list([_cur])` and `Life.guide_to(..., {"list": [_cur]})`, so the red `_charge` /
  `_list()` / `_keep_charge()` code above was NOT ported. Only black's version is kept.
- The "Explore the town." block conflicted with v31.1 (which calls `_guide(sc, at, ...)` with the default speak). The v32
  version (target null, speak false, cafe -> shop pan, stage "town") replaces it.
