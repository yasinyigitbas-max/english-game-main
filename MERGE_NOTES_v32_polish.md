# v32-polish-red (red)

Base: english-game-main `main` 6cdb7f3, then merged english-game-red `v32-npc-pose-main` (3ae0896) and `v32-day3-evening-main` (2bfca68, includes day3-morning 6c99c2d) -> 53a2d23. Fixes only.
Line numbers below are for the branch head.

## 1. Lesson TR missing (root cause + global fix)
Root cause: `Objectives.tr_guard()` runs every 0.4 s while TR is off and permanently rewrote/hid every Label/Button that had Turkish text in it (its job is "no Turkish visible while TR is off"). It never undid that, so any TR line built or visible while TR was off stayed gone after TR was turned on. On top of that, phone TR labels only re-synced on a flag change while the phone itself was `visible`, and the lesson title was picked once at build time.
- scripts/core/objectives.gd:129 `tr_guard()` with TR on now calls `_trg_restore()`.
- scripts/core/objectives.gd:141-150 new `_trg_restore()`: puts back the original text / visibility (group `trg_mod`, metas trg_orig/trg_new/trg_hid). It only restores text the game code has not changed since.
- scripts/core/objectives.gd:171-180 the guard saves the original before it strips or hides anything.
- scripts/phone.gd:1119-1127 `_process`: every TR label is re-checked each frame, even while the phone is hidden or rebuilding.
- scripts/phone.gd:552-553 lesson header: the EN title is always shown, with a TR line under it (title_tr, else tr) that follows the flag live, plus the tr note.
- scripts/phone.gd:574-582 + 595-603 `_cell_tr()`: any EN lesson cell without its own TR column gets a small TR gloss under the EN (`rows_tr` in the lesson data, else data/extra_lines.json). Shown only while TR is on.
- data/family.json: lessons 1-2 (he/she/it, am/is/are) get `rows_tr`; title_tr added to all 4 family lessons.

## 2. TR glosses on the family-creation tabs (Who/Name/Look/Personality chips), the he/she/it and am/is/are buttons, and the job screens
Root cause: the same destructive tr_guard (#1). The tile/chip TR labels were plain labels, so whether they survived depended on guard timing ("randomly missing").
- scripts/phone.gd:193 `_l()`: every label in the TR colour (TR_C) is registered with `_trl`, so every phone TR gloss follows the one flag, live. This covers chips (friendly=arkadaş canlısı, cheerful=neşeli, shy=utangaç, strict=katı, noisy=gürültücü; data is already in data/family.json), job tiles, job detail, crumbs, hints and quiz hints.
- scripts/phone.gd:442 (tile) and the `_chip` TR label go through `_trl`.
- The he/she/it and am/is/are practice buttons get TR via `rows_tr` (#1).

## 3. Shared wall fade: scripts/props/wall_fade.gd (NEW)
API (preload, no class_name): `const WallFade := preload("res://scripts/props/wall_fade.gd")`
- `WallFade.attach(host, cam, player) -> Node`: one manager per scene. cam/player can be Node3D or a Callable that returns a Vector3.
- `register(wall_node, opt := {})`: a GeometryInstance3D, or a Node3D whose meshes all fade together. opt: `min_a` (0.12), `near_cam` (1.2 m), `near_player` (1.0 m), `eye` (1.2 m), `shadows` (true = alpha-hash so shadows are kept).
- `unregister(wall)`, `is_registered(wall)`, `enabled`.
- `force_fade(on: bool)`: scripted scenes. Every registered wall fades to min_a, and back when off (still gradual).
- Alpha is gradual: a wall between the camera and the player fully fades; the camera or the player being near the wall fades it partly, by distance. It moves at 3 alpha/s.
- Static, for blue's adapter: `WallFade.step(g, hidden, dt, speed := 3.0)` has the same signature and behaviour as `scripts/places/wall_fade_adapter.gd` step() on english-game-blue v32-blue (5375290): hidden -> alpha 0/invisible, original material back at 1. `WallFade.step_to(g, alpha, dt, speed, shadows)` takes any target alpha. Uses the same metas (wf_a, wf_mat, wf_orig, wf_cast).
- **Blue adapter integration:** replace the body of the adapter's step() with `preload("res://scripts/props/wall_fade.gd").step(g, hidden, dt, speed)`. Or register buildings with a manager node and get the distance-based gradual fade plus force_fade.
Applied:
- Bedroom: scripts/main.gd:1980-1986 (`_wall_fade_setup`, called at main.gd:335 after `_south_wall`). The south walls were removed from the old `_fade_walls` loop at main.gd:1106. The mirror cinematic is untouched: `_cine_mirror`/`_cine_close_room` use the separate shadow-only `N.closed` boxes.
- Living room: scripts/livingroom.gd:2220-2226 (+ call after `_south_wall`, line 631), old loop at livingroom.gd:1587. Day-1 breakfast `force_fade(true)` at livingroom.gd:254 (before the guide_to pan) and `false` at livingroom.gd:335.
- Bathroom: scripts/bathroom.gd:117-123 (walls_s + setup), the south low wall pieces at bathroom.gd:395-396, the south door frame at bathroom.gd:594.
- Day-2 breakfast: scripts/story/day2_morning.gd:43 force on, :94 force off.

## 4. One bottom caption box (standard style, TR button inside)
- scripts/story/story_ui.gd:26-90: the StoryUI caption now uses the standard HUD/breakfast box (bg 0.08/0.10/0.16 @ 0.72, radius 22, pad 12, EN 30 bold white, TR 22 light blue) with the TR button INSIDE the box. New static helpers `StoryUI.claim(box)`, `StoryUI.hide_all(tree)`, `StoryUI.style_box(panel)`, `StoryUI.style_tr_btn(btn, on)`. Every caption box is in group `caption_box`; showing one hides all the others, so narrator and player-action captions share one slot and the newest line wins. This matches blue's place captions, which already use the shared HUD box (ui/shared/hud.gd).
- scripts/main.gd:1199, scripts/livingroom.gd:1716, ui/shared/hud.gd:76: the room/HUD caption boxes join the group and claim when shown.
- Day-1 hospital: scripts/story/hospital.gd:61-63, the TR button is now the one inside the caption box (it was bottom-left on its own layer); hospital.gd:78. hospital_day2 inherits this.
- Tests: scripts/main.gd:1828-1831 and scripts/room_phone.gd:121-122. "I am answering a question." / "I am learning about he, she and it." are only for the family lesson, not for scripted lessons and tests (review, big test, day-2 test, breakfast). story_home.gd:39 hides the narrator box before the big-test page.
- Dream review: scripts/story/story_home.gd:25 hides "Let's review the lessons." right before the review screen. The stray "I am learning about he, she and it." is gone (main.gd:1828).
- Boss call: scripts/story/story_home.gd:182, the Decline/Answer bar moved up (-360..-220) so the standard caption box (now StoryUI standard) never covers the labels.
- Interact prompt: ui/shared/hud.gd:202, the title panel above the chips was removed ("Take Apples" showed 2 boxes).

## 5. Day-2 bedroom<->bathroom door starts closed
- scripts/main.gd:1369 `S.door = "closed"` on load. The door was saved "open" on day 1, so it started open on day 2. Opening still uses the normal interaction.
- scripts/bathroom.gd:1433 both bathroom doors start closed on entering.

## 6. Wake-up lines
- scripts/main.gd:905-929 `get_up_sequence()`: only "I'm waking up." then "I'm getting up." Each stays up at least 2 s and until its voice ends (`_readable`). The "I am standing up." caption and its voice call are removed. TR already exists in data/extra_lines.json (Uyanıyorum. / Kalkıyorum.).
- scripts/qa.gd:536 expectation updated.

## 7. Day-2 breakfast objective pan
- scripts/story/day2_morning.gd:43-46 uses `Life.guide_to` (same table shot as day 1). guide_to also sets the mission and the Objectives entry.

## 8. Mirror "Spell your name" field
- scripts/main.gd:1490-1508: the field is 56 px tall (no vertical panel padding), font 34, vertically centred, with a blinking caret `|` (0.5 s Timer, `_name_show()`).

## 9. Books seated on shelves
Shelf tops measured from props/furniture/bookcaseOpen.glb: y = 0.13 / 0.37 / 0.61 / 0.85 of 0.88.
- scripts/main.gd:478-482 bedroom bookcase books + red shelf book (were 0.16 m above the boards).
- scripts/livingroom.gd:857-860 living-room bookcase books + red shelf book (were 0.17 m above).
- Other books (desk, side table, wall shelves, sideboard) were already on their surfaces. The bathroom has no books.

## Other
- NPCs keep their pose: scripts/world/npc.gd:47-59 routes through NpcTalk (verified, from v32-npc-pose-main).
- QA probe: tools/qa_tr_probe.gd/.tscn (export-excluded tools folder).
- New player-visible lines: none needing voice. The only new UI text is the "TR" button label and TR glosses (data only).
