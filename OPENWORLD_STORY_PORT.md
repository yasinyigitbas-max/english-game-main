# OPENWORLD_STORY_PORT (red) — audit of v33 @5d917a5 (includes days 4-7, child-drive, hospital2)

Goal: ONE `scenes/world.tscn`. There is one hero and one camera, and the doors swing for real. The port must remove every `change_scene*`, every second hero/camera and every place-switch fade. State lives in WorldState/save and never reloads.

## Counts (non-QA .gd)
| kind | sites |
|---|---|
| change_scene_to_file (story/gameplay) | 10 (game.gd:24, house.gd:38, hospital.gd:9/170/378, hospital_day2.gd:96, story_accident.gd:147, child_drive.gd:130, + menu/boot 4 = keep) |
| Game.go_to callers (fade+change_scene funnel) | 13 |
| House.go (in-scene room swap, frees old room) | 6 |
| get_tree().current_scene assumptions | 43 (≈30 story/world guards `sc == current_scene`) |
| Game.spawn readers | 7 |
| Game.fade (black/white screen) | 12 (bus, day6 storm ×4, child_drive_stop ×4, world bus) |
| per-scene story/room Camera3D.new | 9 gameplay (main, livingroom, hospital, child_drive_stop, story_accident, place_base ×2, day3_morning tmp, life tmp); viewport cams (mirror, portraits, polaroid, phone preview, vocab_test) = keep |
| reload_current_scene | 1 (livingroom.gd:1769 Restart) |

## Call-site table
| file:line | does now | open world |
|---|---|---|
| core/game.gd:20-26 `go_to` | fade + change_scene + Game.spawn | **shim**: `go_to(path, spawn)` → `World.goto(place_id_from(path), spawn)` (hero.move_to / door walk). There is no fade, and black's API keeps the old signature so the 13 callers still work while they get ported |
| core/game.gd:28 `fade` | full-screen tween | keep it only for the off-screen car/bus skip and sleep (see the driving rule). Remove it from place changes |
| core/house.gd:33-52 `House.go` | swaps room nodes, frees the old room, sets current_scene | → walk through the world door between rooms (`World.door(from,to).walk_through(hero)`). Nothing is freed |
| main.gd:770, :779 | bedroom→living/bath House.go | door walk |
| livingroom.gd:2019 | front door → Game.go_to(WORLD,"lot:home") | the front door opens onto the street: door walk. Keep the `going_out` event |
| livingroom.gd:2020 | living→bedroom/bath House.go | door walk |
| bathroom.gd:814, :824 | bath→bedroom / next House.go | door walk |
| bathroom.gd:179, main.gd:1433-1438 | placement keyed on App.came_from | → `World.on_enter(room, from)` signal. Hero is already at the door, so drop the positional set and keep the story hooks (hospital→Day1, hospital_day2→Day2After) |
| world/lot.gd:123 | lot entrance → Game.go_to(interior) | door walk into the interior (WorldState.player_pos is no longer needed) |
| places/place_base.gd:55, :165/180, :351 | place scene: own cine cam, exit → go_to WORLD | the place is a world region; `_cine_cam` → shared `World.cam.pan()`; leave() = door walk outward |
| places/shop.gd:184, cafe.gd:134 | cut under fade-in | cut becomes a camera pan as the door opens |
| world/world_exterior.gd:39-54 | reads Game.spawn/came_from to place the hero | delete it (hero is persistent). The mission text moves to an on-enter-street hook |
| world/world_exterior.gd:134-145 | bus ride: fade, teleport | **off-screen skip** (driving rule) |
| story/story_accident.gd:43, :147-148 | own cam, → hospital.tscn | hero is placed at the hospital ward door through an off-screen skip ("ambulance" black summary). Use the shared cam |
| story/hospital.gd:9, :30, :170, :378 | change_scene to hospital_day2/main, own cam | hospital is a world region. Day-2 is a state of the same room (no scene). Exits: home via a car **skip** to the front door (state flags day1_done) |
| story/hospital_day2.gd:95-96 | go_to WORLD home_car / next_scene | car skip → home front door |
| story/child_drive.gd:101-131, :349 | drive cutscene, change_scene STOP_SCENE | the drive is never shown: skip to the stop location. child_drive_stop becomes a world spot |
| story/child_drive_stop.gd:30, :52-55, :190-198 | own cam, fades, go_to WORLD home_car | shared cam pan. Return = car skip → home door |
| story/work.gd:54, :96; work_summary.gd:69-71 | work scene; go_to house/world | workplace/school region. Commute = skip summary. Return lands at the front door |
| story/day6_storm.gd:146-149 "time_skip" | fade, +10 min | keep it as a time-only skip card (not a place change) **or** remove: flag |
| story/day6_storm.gd:165-177 "ride_home" | fade, teleport home | car/bus skip → home door |
| story/day3_morning.gd, day4_routine.gd, day5_routine.gd (≈30 `sc == current_scene` guards; Game.spawn reads 55-56/69) | abort when the scene changed | guard → `World.story_epoch`/`hero.region`. `_from` comes from `World.last_door` |
| day3_morning.gd:197, life.gd:223 | temp Camera3D for pan | `World.cam.pan(views)` (no second camera) |
| day2/day3_evening.gd:35/38, day4_breakfast, day4_evening, day5_shop:100-138, day7_party | find room via current_scene, spawn NPCs | `World.room("livingroom")` etc. NPCs get placed/shown in the persistent family set (no instancing per entry; day5 shop child/mum: spawn once, hide after) |
| core/objectives.gd:130-197, life.gd:51/182, door_label.gd:16/28, character_hook.gd:38, npc*.gd, lot.gd:115/229, street_object.gd:27, vehicle.gd:133, player.gd:86/147 | `current_scene` as "the world" | `World` autoload/singleton ref (current_scene == world.tscn anyway, so it is low risk) |
| main.gd:212, livingroom.gd:175 | per-room camera | the single world cam. Room-specific framing becomes `World.cam.set_room_bounds(room)`. Wall fade (`_fade_walls`, wall_fade.gd) runs against that cam |
| main.gd sleep pose (≈845-883, "under the black fade") | night black | sleep animation plays right when lying down, then night = sleep skip card (allowed: time, not place) |
| livingroom.gd:1769 Restart | reload_current_scene | reload world.tscn from save (ok) or remove |
| game_menu.gd:134, main.gd:1446, universal_scene.gd:73, menu.gd:181, downloader.gd:128 | menu/boot | **keep** (out of the world) |

## Driving rule vs "no fades" — DECISION (flag for Yasin)
"No fades" applies to *walking between places*: doors, rooms, town. Car/bus/ambulance trips must never be shown, so they use **one** helper `World.skip_travel(dest_door, summary_en, summary_tr)`. It shows a short black card with an EN line + TR in the caption box ("We drove to the hospital."). Under that card the hero is moved to the outside of the destination door and the clock advances, then the card goes. This is the only full-screen black left, besides sleep/time-skip. Yasin should confirm that a black summary card is acceptable, or say whether he wants a hard cut instead.

## Work order
1. World adapter: shim Game.go_to/House.go → black's goto/door API; remove spawn readers (world_exterior, bathroom:179, main:1433).
2. House rooms: bedroom/bathroom/livingroom door walks, cameras merged, wall-fade on the shared cam, on_enter hooks (days 1-2 hooks, breakfast, scramble).
3. Day routines 3-5 (`current_scene` guards → epoch), temp-cam pans → World.cam.pan.
4. skip_travel helper + bus, day6 storm, work/school commute, work_summary.
5. Hospital (accident→skip, day1/day2 as room states, exit skip).
6. Child-drive (skip) + stop spot.
7. Family/NPC persistent placement (day4 breakfast/evening, day5 shop, day7 party). Bed/sleep, test flows (vocab_test viewport cam kept).
8. QA per day on world.tscn: there must be no change_scene in the tree (grep gate), and the hero instance id must stay the same all the way through.

## API needs from black's skeleton
- `World` singleton: `room(id)`, `region(id)`, `door(id)` with `open()/walk_through(hero)/is_open`, `goto(place_id, door_id)` (path-walk or move_to), `last_door`, signals `entered(region, from)` / `left`.
- `hero`: `move_to(pos, face)`, `place_at(door_id)` (for skips only), `busy` flag.
- One camera: `pan(views)` awaitable, `focus`, `set_bounds(region)`, plus wall/building occlusion fade for any region.
- Region activation (lights/mirror viewports/shadows on only near the hero) to replace House' live-room perf trick.
- Fixed IDs for doors/places listed in OPENWORLD_PLAN.md (hospital ward, school/work desk, child-drive stop, home car spot).
- A hook to keep `Game.go_to` as a compat shim during the migration.

## Risks
1. **Coordinates**: room scripts assume origin-local positions (House put the live room at origin). Every hard-coded Vector3 in main/livingroom/bathroom (thousands of lines) must become room-local (`room.to_global`). This is the biggest piece of work and the place bugs are most likely.
2. Awaits on freed scenes are currently the cancel mechanism (`sc == current_scene` guards, House freeing rooms). In one world nothing frees, so stale coroutines keep running → double captions/voices. Needs an epoch/cancel token.
3. Performance on Android: all rooms + town + mirrors live at once (House freed rooms for this). Region activation is mandatory.
4. Multiple cameras today (room, place cine, hospital, stop, accident, temp pan cams) → camera fights; also the rules on wall-fade and pan-per-step have to be re-verified.
5. The driving rule conflicts with "no fades". Resolved by skip_travel, which needs Yasin's sign-off.
6. Save/resume: WorldState.scene/player_pos semantics change (save only region+pos). Old saves need migrating.
7. The hospital day1→day2 and child-drive stop were separate scenes with their own lighting, so they need world regions in black's layout.
