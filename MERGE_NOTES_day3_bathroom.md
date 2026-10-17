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
UNTESTED (v32 and v32b). Suggested QA: qa_v31c day-3 leg: after the alarm the list must stay "Take a shower." (+ "Charge my phone." if
present) through bedroom -> bathroom door -> bathroom; the bathroom chip must read "I am opening the door."; "Go to the living
room." only after Take a shower; outside: the pan shows the cafe then the shop and returns to the player without entering walls.
v32b: run qa_v31c (the day-3 tail now covers the cafe / shop / home cues); with blue's interiors merged, enter + leave each place.

## Port to english-game-main (v31.1), branch v32-day3-morning-main
- O8: english-game-main already has black's v31.1 O8 fix in `scripts/core/objectives.gd` (`set_list()` / `clear()` keep the
  `charge` entry while the phone is not charging and the battery is under 30 %; Life adds it under 15 % and completes it when
  charging). That covers every day-3 `set_list([_cur])` and `Life.guide_to(..., {"list": [_cur]})`, so the red `_charge` /
  `_list()` / `_keep_charge()` code above was NOT ported. Only black's version is kept.
- The "Explore the town." block conflicted with v31.1 (which calls `_guide(sc, at, ...)` with the default speak). The v32
  version (target null, speak false, cafe -> shop pan, stage "town") replaces it.
