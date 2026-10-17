# v33town: one persistent house (bedroom + bathroom + living room)

Replaces the rejected shell+promote approach (kept on branch `v33-town-shellpromote`). Base: origin/v33 b57e269.

## Model
* Every house room is instanced ONCE per house visit and never freed or rebuilt while the player stays in the house.
  * shell   – never entered yet: geometry only (unchanged v32wh shell).
  * live    – `current_scene`, at the world origin, runs its normal code.
  * dormant – was live before: processing off (also its ALWAYS-mode UI / HUD / pause menu / phone), lights, room UI
    (CanvasLayers), its camera, hero and hand sprite hidden, WorldEnvironment detached, mirror viewports stopped.
    Every node and every state dictionary stays as it was (alarm, lamps, curtains, doors, family, table, ...).
* A door is just walking (`House.go` -> `_swap`): the room left falls asleep, the whole house shifts so the room
  entered is at the origin (floating origin; room code uses room-local == world coordinates), the room entered wakes
  (`_wh_resume`) or, the first time, turns live from its shell (`_live_ready`, as v32wh), its hero takes over at the
  exact spot / facing of the previous one and walks on (1.7 m/s) to the usual "just inside the door" spot
  (`_wh_spawn`), and the camera blends from the old view to the new room camera over 0.9 s (no cut, no fade).
* Coroutines of a dormant room wait (`wait()` holds while dormant); a dormant room shows no caption.
* Leaving the house (street, hospital, main menu, New game) frees every house room, as before.

## Files
* `scripts/core/house.gd` – sleep / wake / swap / walk-in / camera blend (CamBlend + CamPre), `_rooms`, teardown.
* `scripts/main.gd`, `scripts/bathroom.gd`, `scripts/livingroom.gd` – `_wh_resume()` (room-entry steps only: caption,
  objective, story hooks, look / TR from save.json), `_wh_spawn(from)`, `wait()` / `caption()` dormant guards.
  bathroom: the entry objective block moved into `_entry_mission()` (same code).
* `export_presets.cfg` – house.33town, versionCode 44, english_game_house_v33_town.apk.

## Known limits
* Each room still owns its own hero / camera / UI objects (only one of each is ever visible / current / active);
  they hand over seamlessly. A single shared hero node across rooms would need the ~6000-line room code refactored.
* A room never entered yet is still a shell built from default state: through an open door it can look different
  from the save (e.g. the family at breakfast appears when the living room turns live the first time).
* Wall-fade state of a dormant room is frozen as it was when the player left.
* versionCode 44 is lower than v33's 45 (installs over v33 fail without uninstall); 46 would avoid that.

## Open-world rule (Yasin 17:22) - TO IMPLEMENT LATER, not in this build
* Until the game reaches day 8, every street at the edge of the play area is blocked by construction fences / roadwork
  so the player cannot wander off. At day 8 they come down (removed / opened).
