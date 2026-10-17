# v32-npc-pose (red): NPCs and the player keep their pose while talking. Merge notes

**STATUS: UNTESTED.** Godot was not run and there was no QA. This comes from reading the code only.
Base: branch `v306-hospital-closeups`. File contents come from `/workspace/story_red_v31b`. `npc.gd` is byte-identical in story_red_v31, story_red_v31b and english_game_3dv2. Both hunks were dry-run patched (`patch --dry-run`) on a temporary copy of the english_game_3dv2 `work.gd` / `npc.gd` and applied cleanly. english_game_3dv2 itself was NOT edited.

## Rule (Yasin)
NPCs, including family members, colleagues, customers and pupils, KEEP their current pose and animation when you talk to them. Commit 2 (approved by Yasin) applies the same rule to the **player** while they speak. Standing stays standing, sitting stays sitting, and idle stays idle. A pose change is allowed only in an explicitly scripted scene.

## Root cause
The shared talk code played the library clip `"talk"` on the NPC for the length of its line. Then it played the old clip again:
- `scripts/world/npc.gd:50` (old) `if anim != "sit_idle": hero.play("talk", 0.2)`, then `:53` restores `anim`/`walk`. This is the outdoor/street NPC "Say hello" routine.
- `scripts/story/work.gd:143` (old) `if pose == "idle": npc.play("talk", 0.25)`, then `:150` `npc.play(pose, 0.3)`. This is every colleague, customer or pupil line in the day-2 work routine.

`"talk"` is Mixamo **"Talking"** (`character/animations/retarget.py`: `("Talking","talk")`), and that is a **seated** clip. In `characters/men_library.glb` the Hips translation y is about **0.54 m** for `talk`, compared with 0.49 m for `sit_idle` and 0.86–0.88 m for `idle`. So every standing NPC visibly sat down for its line and stood back up when its old clip came back. That is exactly the bug that was reported.
The living-room family (`livingroom.gd` `_say_as()` / `_fam_verb()` -> `_talk_nod()`) only nods the Head bone and never changes a clip. It already follows the rule and is unchanged. Breakfast, TV and hospital poses are scripted with `sit_down()` / `_stand_npc()` / `play()` and are untouched.

## Fix: one shared routine
New `scripts/core/npc_talk.gd`. It is used through `preload` and has no `class_name`, so it does not need a global-class-cache refresh (see the Day2After note in MERGE_NOTES_v306).
- `TALK_CLIP` (line 22): the seated `"talk"` clip name. Callers that read it from data send it to begin()/end() instead of playing it.
- `is_seated(ch)` (line 28): true if the meta `seat` is set, or if the current clip is `sit_idle`, `talk`, `typing` or `stand_to_sit`, or starts with `sit`.
- `begin(ch, look_at, scripted_pose := "")` (line 35): it **never plays a clip** unless a scripted pose is asked for. Standing characters turn their body toward the player (0.4 s yaw tween). Seated characters, or characters with meta `lock_yaw`, turn only the head/neck (`bone_offsets["Neck"]`, clamped to ±0.7 rad, skipped while the breakfast eat loop owns Neck). The character also gives a subtle repeating head nod (`bone_offsets["Head"]`, 0.12 rad, about every 2.3 s) on top of whatever clip is playing.
- `end(ch, st)` (line 62): stops the nod and eases the neck back. It restores the previous clip **only** if `begin()` played a scripted pose.
- **Opt-in for scripted cases:** `NpcTalk.begin(ch, pos, "<clip>")`, `ch.set_meta("scripted_pose", "<clip>")`, or `NPC.scripted_pose = "<clip>"` (new var, npc.gd:48).

## File:line changes
| File | Lines (new file) | Change | Owner / touches |
|---|---|---|---|
| `scripts/core/npc_talk.gd` | 1–71 | NEW shared talk routine (NPCs + player). `TALK_CLIP` const at 22 (commit 2) | new file, no owner conflict |
| `scripts/world/npc.gd` | 43–60 (`_talk()`) | removed `hero.play("talk")` and the clip restore. Now `NpcTalk.begin/end`. Added `const NpcTalk` (47) and `var scripted_pose` (48). A walker still pauses on the sidewalk in `idle` (its standing pose, no foot sliding) and walks on at its own `speed / 1.7` | outdoor world / NPC code (shared world file, identical in all three trees, no owner tag found) |
| `scripts/story/work.gd` | 119 (`_do_task`) | `_face()` body spin only when the person is not seated (seated pupils, the patient on the bed and the salon client now turn only their head) | red v31 day-2 story file (`work.gd`) |
| `scripts/story/work.gd` | 121, 123–124, 130–131 (`_do_task`, commit 2) | **player**: a task with anim `"talk"` (work.json, 13 tasks such as "Ask a question", "Serve the customer", "Pay") no longer plays the seated clip. `NpcTalk.begin(player.hero, <npc or station focus>)` keeps the current clip (idle), turns the player toward the NPC and nods. `NpcTalk.end()` runs after the line, and the old `play("idle")` reset is skipped for these tasks. All other task anims (typing, pick_up, phone_call, run ...) are unchanged | same |
| `scripts/story/work.gd` | 144, 147, 154 (`_npc_line`) | `const NpcTalk`. `npc.play("talk")` replaced by `NpcTalk.begin()`. `npc.play(pose)` replaced by `NpcTalk.end()` | same |
| `.gitignore` | end | allow-list for the 3 scripts + this note | — |

Not touched: `livingroom.gd` (Blue also edits it, and it is already compliant), `character.gd`, `world_exterior.gd`, `npc_spot.gd`, scenes, data.

## Risks / follow-ups (not done)
- **Player side: fixed in commit 2.** I grepped the player's talk/pose calls game-wide (story_red_v31b, story_red_v31, english_game_3dv2: scripts, scenes, data). The player gets the seated `talk` clip in only one place, `work.gd` `_do_task` (data-driven from work.json). The other player clip calls do not use `talk`: `livingroom.gd` / `main.gd` / `bathroom.gd` `gesture()` (pick_up / open_door), `player.gd` (walk / idle / sit_idle in `sit_at`), `story_accident.gd`, `polaroid_renderer.gd` (no caller passes `talk`), and the bedroom/breakfast scripted sit/stand. The player's own lines elsewhere (`say_line`, `_say_me`, `caption`) never change a clip. Scripted player seating (breakfast `sit_down`, desk, bed, `sit_idle` work tasks) is unchanged.
- `scenes/blocks/block_park.tscn` "Talker1" uses `anim = "talk"` as its *ambient* clip, so it is seated-looking at ground level. That is its authored pose and is kept. It now counts as seated, so it gets a head turn only.
- `NpcSpot` has no `scripted_pose` export yet. To author it per spot, add `@export var scripted_pose` to npc_spot.gd and copy it in `world_exterior.npc_acquire()`.
- Head/Neck bone axes (`Vector3.UP` yaw on Neck, `Vector3.RIGHT` nod on Head) follow the existing `_talk_nod()` / breakfast-loop usage. The yaw sign and limits have not been checked visually.
