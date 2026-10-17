# v33-red-combined (red) - merge notes

Base: main 06a21d2 + v33-hospital2-red (fe7fe58) + v33-child-drive-red (2f679de) + v33-days-4-7-red (60a7d37).
Conflicts: hospital_day2.gd (kept both: `_go_line()` + child-drive), data/extra_lines.json (key union, no differing values).
days-4-7 was branched from de3218f (before v32): its "deletions" of v32 files (voice_009.bin, voice_<v>_002.bin,
build_voice_v32.py, qa_v32int ...) are NOT deletions in the 3-way merge - the merged tree keeps all of them.

## Fixes found by the combined test (and Yasin's later requirements)
| area | change |
|---|---|
| bedtime tests (d2 / d3 night test, TestBank) | phone.gd's empty-page watchdog (house.24.2) rebuilt the PHONE's own he/she/it quiz over a scripted test page that has no "Options" node (score page, word puzzles) after 2 s, then forced page "score" -> `close(true)` opened the family page -> bedtime hung. Tests now set `ph.set_meta("ext_test")`; the watchdog skips it. |
| TestBank test screen | caption gap (CAPGAP_MIN 112 px) stayed under the phone during tests -> answer buttons at 470/720. With `ext_test` the gap is 8 px: full screen, low buttons. |
| child drive (Yasin) | NO visible drive / camera follow / sign-street arrival / escort for a child: the child uses the adult flow exactly (car chips -> black -> hospital / work summary -> home_car spawn). Only the lines change: "My mom/dad is driving me to the hospital / to school / ..." (car line via `ChildDrive.child_line`, work->hospital line and hospital->work line via `ChildDrive.drive_line`). The child-creation parent block (phone family screen) stays. child_drive.gd's depart/trip/arrive code is now unused (left in place, no hooks). |
| hospital close-ups (Yasin) | `_fit_dist()` + FIT table: the arrow tip is on the part at the frame centre and the camera distance is the smallest that keeps the part's whole FIT set (e.g. neck + top of the head) inside the safe area (58 % half-height: under the part label, above the caption box; 75 % half-width). Distances / head offsets scale with the body (`_k()` = model scale: child 0.66, heights). |
| child on the exam bed (Yasin) | `HospitalScene._fit_to_bed(anchor)`: a body with model scale != 1 is moved so its Hips (day-2 sitting) / Head (day-1 lying) sit where the scale-1 body has them -> the child sits ON the mattress (legs hang) / head on the pillow. |
| universal narrator (Yasin) | `Audio.own_clip(text)` = the ONE lookup for narrator/player lines: f = house index, outdoor voice/<md5>.ogg, voice_own/f, voice_drive/f; m/c/g = pack, voice_own/<v>/<md5(norm)>.ogg, voice_drive/<v>/. `Audio.say`, `Voice.say`, `bathroom.say`, `ChildDrive.speak_child` all use it. `_clip()` never falls back to the f clip under m/c/g. NPC lines without their own v_ clip keep the old fallback (say_as). |
| voice data | The Boy/Girl packs are Kokoro (af_sky / af_heart + pitch chain, CREDITS house.30.2) but chunk 002 of c/g (43 v32 lines + 3 v33 lines) and voice_drive/c,g were rendered with Piper joe/kristin = the voice change Yasin heard (hospital "fine" answers, day-3 lines, drive lines). tools/build_voice_v33_own.py re-renders them with the packs' own Kokoro chain and renders the 269 day-4/7 lines that had no clip in ANY narrator into voice_own/{f,m,c,g} (f ljspeech, m joe, c/g Kokoro). |
| sleep pose standard (Yasin) | main.gd: `bedsit_to_lie()` ends in `sleep_pose()`; `_pose_sleep()` (every lying state: bed locks, day-1 back from the hospital, morning start, day 4/7 bedtimes via bedtime.gd) = `_pose_flat()` + `sleep_pose()`. `_pose_flat()` (old rigid frame) only for fitting and under the black before the get-up (`end_sleep_pose`, restores the exact flat transform). |
| "Go to the living room." after the day-2 chat | shared `Bedtime.pending()` (any day: d<N>_bed_pending and not d<N>_bedtime_done) used by main.gd objective() and bathroom.gd (entry mission, after washing / brushing, routine caption) -> "Go to bed." instead. Other sources checked: day3_morning (day >= 3 only), day4_routine (days 4/7/8, own "Go to bed."), objectives.gd (TR dict only), hud / world_exterior / front door (no such line). |
| QA harness | qa_hosp2: `ui.panel` guard, `--gender/--age` for home/work, new `--mode=d1` (day-1 home story). qa_v32int: accepts the job-specific "Now I'm going to school." / child drive lines. |

## Packaging
voice_own/ (12 MB, 1072 ogg) and voice_drive/ are NOT in export_presets' exclude_filter -> they ship in the base APK.
If they should live in the narrator pack instead, add them to the pack builder (black).
