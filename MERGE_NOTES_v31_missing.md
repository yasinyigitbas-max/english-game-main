# v31-missing (red): earlier red handoffs not yet in english-game-main v31.1

**UNTESTED.** Godot was not run for this check; only a headless parse was done, if one was possible.

## Check against english-game-main main (6cdb7f3)
| red handoff | in v31.1? |
|---|---|
| v31-day2-hospital f69f512 | yes (hospital_day2.gd is superseded by 1648f0c, which is in main; qa_v31_day2.gd identical) |
| v31-fixes d057bc3 | yes (all plants waterable; the day gate is in main as `maxi(WorldState.day, App.day) >= 2`, which is stricter than the red version) |
| v304-bedroom-mirror-flash 07ba138 | yes (`_cine_close_room`, shot_at seed; main also adds `_reveal_room_deferred` for the day-2 door pan) |
| v305-hospital-tr-decor e3ddbd7 | yes (decor_bedroom.gd, the main.gd hook, phone.gd `title_tr`, can_should/body_day2 `title_tr`) |
| v306-hospital-closeups 1648f0c | yes (hospital.gd / hospital_day2.gd byte-identical; extra_lines.json has the v306 keys) |
| v31-evening-day3 c22ef0e | yes (all files identical or later black/APK versions) |
| **v304-mirror-flash ca862e5 (bathroom)** | **NO.** Not in the requested list, but it is a separate red handoff and its code is missing |

Only the MERGE_NOTES_*.md, STATUS.txt and shots/ files of those handoffs are not in main; that is documentation only.

## Ported here: v304 bathroom mirror prompt (ca862e5), re-applied onto black's v31.1 bathroom.gd
- `_build_env()`: removed the deferred `create_timer(0.5) -> _stable_lights`.
- `_ready()`: `_stable_lights()` runs synchronously right after `_apply_states()`, so the omni lights are final from frame 0
  (no shader-variant recompile when the mirror pan starts).
- `_mirror_prompt(todo)`: kept black's `Life.guide_to(...)` with the todo list. Only the camera shot changed: it now frames the
  player and the mirror together. at = lerp(mirror, hero + 0.9 m, 0.6), and pos = (at.x + 1.3, 2.45, max(hero.z, at.z) + 1.5),
  clamped inside the room. This replaces the old fixed mirror close-up.
- Red's other ca862e5 changes (own cam_shot, removed Objectives calls) came from the pre-black bathroom base. They were NOT ported.
