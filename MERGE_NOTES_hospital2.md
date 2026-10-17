# v33-hospital2-red: MERGE NOTES (red)

Branch `v33-hospital2-red` from main `06a21d2` (v32). Pushed to `yasinyigitbas-max/english-game-red`.

**Testing status.** I made one diagnostic capture of the day-2 hospital visit BEFORE the fixes: `tools/qa_hosp2`, mode `direct`,
xvfb opengl3 at 1600x720, a frame every 0.4 s plus a log line for each frame. All fixes were then written from that capture
and from reading the code. Per Yasin's instruction, there were no per-fix re-runs: the only check after the fixes is the
parse check below (all OK). **None of the fixes has been confirmed in a Godot run yet.** One combined Godot test of all of
red's work follows.

## 1. Day-2 hospital visit (`scripts/story/hospital_day2.gd`)

| # | Bug seen in the capture | Cause | Fix |
|---|---|---|---|
| 1 | Close-ups clip INTO the body. "legs" (camera inside the thigh), "arms" (the forearm fills the frame), "stomach" (hidden behind the thighs), "knees" / "feet" (the bed rail in front). | v306 framing: the distance was `PARTS[word][2] * 0.6`, almost level, straight in front. The seated thighs point at the camera. | Per-part `FRAME` table with distance, elevation and side (`hospital_day2.gd:110`). The camera looks down past the thighs and the rail. The camera position is now `p + (fwd - side*s + up*e).normalized() * d` (`hospital_day2.gd:177`). |
| 2 | "ears", "mouth and teeth" and the moves to "nose" show the back or top of the HAIR. | The camera sat 0.24 m from the head, so the sit_idle sway moved the head out of the shot. | Head close-ups are now 0.45-0.6 m away, from a front three-quarter angle (same `FRAME` table). |
| 3 | The camera flies THROUGH the player: front to back close-up, and nose to wide. | `_cam_to` interpolated in a straight line. | `_detour()` (`hospital_day2.gd:143`) checks whether the move passes within 0.3 m of the body axis (hips to head). If it does, the camera goes round a waypoint on the camera side (`hospital_day2.gd:131`). |
| 4 | After the work-first path, a second caption box can sit over the hospital. | work_summary's StoryUI (layer 121) lives on the scene-tree root and stays until the summary frees itself. | `StoryUI.hide_all()` when the visit starts (`hospital_day2.gd:42`). |
| 5 | A teacher or pupil hears "Now I'm going to work.", then the summary says "I went to school." | The line was hard-coded. | `_go_line()` uses the work.json car label to pick "Now I'm going to school." / "...shopping." / "...work." (`hospital_day2.gd:89`, `:96`). New voice clips for f/m/c/g plus TR (`tools/build_voice_v33_hosp2.py`). |

Kept as they were: one standard bottom caption with TR inside, the player's narrator (all player lines have m/c/g clips,
checked), the doctor in hfc_male, the varied body answers ("okay / all right / strong / ..."), and no talk pose changes
(no npc_talk calls here).

Both entry orders use the same `_run`. The work-first path goes summary, then "Now I'm going to the hospital.", then the
visit, then home_car. The home-first path goes car, then the visit, then the `_go_line()` line, then the summary. The
harness covers both: `--mode=home` and `--mode=work` (real car verbs), and `--mode=direct`.

## 2. Day-2 ending: a stale "Go to the living room." after the family chat (`scripts/main.gd`)
- **Cause:** after the couch talk the player enters the bedroom. Its `_continue_game()` calls `_advance(false)`. `objective()`
  falls through to the default "Go to the living room.", and `_advance` speaks it. The day-2 morning prompt used
  `Life.guide_to`, so the `Life.once("say|main|Go to the living room.")` key for day 2 was still unused.
- **Fix:** `_bed_pending()` (`main.gd:1909`) is true when story.d2_bed_pending / d3_bed_pending is set and bedtime has not
  run. `objective()` then returns "Go to bed." (`main.gd:1951`), the same objective id that bedtime.gd uses. It is never
  spoken by `_advance`, so the living-room line is gone. Day 3 gets the same fix.

## 3. Real sleep pose after "I am sleeping." (`scripts/main.gd`, `bedtime.gd`, `story_home.gd`)
- **Cause:** "lying" was the idle clip's first frame, frozen and turned -90 degrees (`_lie_blend`), with a small Chest offset.
  It looked like a rigid board.
- **Clip:** the men and women libraries both have a 22 s looping `sleep` clip (side-lying, knees bent, breathing). Forward
  kinematics on the glb shows it lies on the FLOOR along its own -X axis, and it tosses over after about 7 s.
- **Fix:** `sleep_pose()` (`main.gd:870`) replaces the flat pose RIGHT AFTER the line:
  - It plays `sleep` and resets the model tilt.
  - It rotates the body so the head-to-feet direction matches the flat pose.
  - It moves the head/feet midpoint and the hips height onto the flat pose's spot on the mattress. This is bone-based, so it
    works for man, woman, boy and girl (child scale included).
  - Only the calm part (1.9-5.4 s) plays, ping-ponging at 0.55 speed (`_sleep_pingpong`), so there is no rolling off the bed.
    The existing Chest breathing runs on top.
  - `end_sleep_pose()` puts the flat pose back under the black fade, so the morning get-up flow (`bedsit_up`) is unchanged.
    `bedsit_up` also calls it as a safety net.
- **Call sites:**
  - Day 2 and day 3: `bedtime.gd:164`, straight after "I am sleeping." is spoken, before the 0.9 s pause.
  - Day 1: `story_home.gd:46`, after "I am tired. I should rest."
  - The flat pose comes back under the black at `bedtime.gd` (after the fade) and `story_home.gd:52`.
- **bed_lock:** the guards in bedtime.gd:42 and story_home.gd:221 skip while `m.sleep_clip` is true. Otherwise they snap the
  body back to flat every frame.
- `_apply_character` no longer re-flattens a sleeping body. `_continue_game` clears `sleep_clip`.

## 4. Day-3 evening chat: the hot chocolate answer (`data/day3_evening.json`)
- **Changed:** only the "What did you order?" answer. It was "I'd like a hot chocolate, please." and is now
  **"I had a hot chocolate." / "Sıcak çikolata içtim."** (scramble and spoken line). No other answers were touched. The cafe
  order is fixed (hot chocolate + 2 cookies, `cafe.gd:171`), so it matches what the player ordered.
- **Voice and TR:** new clips for f/m/c/g, plus TR in day3_evening.json "lines" and extra_lines.json.

## 5. Day-2 school: the same black summary as work (`work_summary.gd`, `street_object.gd`)
- **Already shared:** the summary trigger was already shared. Both "Go to school" and "Go to work" carry `day2: "work"`, so
  they go to `work_summary.play`. `lines_for()` already says "I went to school." plus the pupil/teacher tasks.
  red's child-drive branch (`child_drive_stop.gd`) also ends in `work_summary.play`, so it stays compatible.
- **Gap fixed:** `car_destinations()` checked only `WorldState.day`. With `App.day == 2` but WorldState.day still 1, it fell
  back to the "soon" chips, which have no summary. It now uses `maxi(WorldState.day, App.day)` (`street_object.gd:242`).
- **Added:** a TR line under each summary line when TR is on (`work_summary.gd:44`). Added the missing TR strings: "I said
  hello.", "I wrote in my notebook.", "I checked the homework.".

## Merge notes / risks
- **Conflicts with v33-child-drive-red:**
  - `hospital_day2.gd:89`: I changed the `ui.line("Now I'm going to work.")` line, and child-drive inserts a line right after
    it. This is a trivial conflict: keep both (my `_go_line()` plus their ChildDrive line).
  - `work_summary.gd`: no overlap (my hunk is in the lines loop; theirs is in the routing).
  - `street_object.gd`: theirs is in `_drive`, mine in `car_destinations`; no overlap.
- **Voice:**
  - New clips were appended to voice/voice_009.bin and voice_{m,c,g}/voice_*_002.bin, plus the indexes.
  - **The Android voice packs (packs release) must be rebuilt** for phones to get them. Otherwise phones play silence or
    fall back for these 3 lines.
  - `tools/build_voice_v33_hosp2.py` only renders lines that have no clip yet.
- **Not verified in a run (the combined test should look at these):**
  - the new close-up frames;
  - the sleep clip on the bed for all 4 bodies, especially that the fitted pose does not sink into the mattress;
  - the day-2 ending with no living-room line;
  - the day-3 chat.
- **Harness:** `tools/qa_hosp2/qa_hosp2.tscn`. Modes:
  - `home` / `work` / `direct`: the hospital visit.
  - `end`: day-2 ending, from home_car through the family chat, bedtime, sleep and day 3.
  - `d3eve`: day-3 evening chat, bedtime night 3 and sleep. Takes `--gender=` / `--age=`.

  It logs spoken lines with their scene and narrator, plus captions, TR, box count, camera and anims. The parse check is
  `tools/qa_hosp2/parse_check.gd`.
- Untouched: the night-3 phone quiz item "I'd ___ a hot chocolate, please." It is a cafe-phrase test, not the chat.
