# MERGE NOTES - v33 child drive (red) - branch `v33-child-drive-red` (from main 06a21d2, v32)

A CHILD player (creator age "child", Boy / Girl) never drives and never leaves the family screen without a mom or a dad.
Adults: every hook is `if ChildDrive.<check>(): <child flow>` placed ABOVE the untouched v32 line, and every check is
false for adults (`ChildDrive.active()` = child player AND a mother/father in state.family). The adult code paths are
byte-for-byte v32. Verified with the v32 adult day-2 regression (`qa_v32int run_d2`, hospital first).

## New files (no conflicts expected)
- `scripts/story/child_drive.gd` (class_name ChildDrive): who drives (first `mother` / `father` in state.family), the
  child's driving lines, voice + TR helpers, family-screen hint, the escort, the home departure and the drive back
  into the home driveway (world_exterior), seats / doors / paths / camera-follow drive.
- `scripts/story/child_drive_stop.gd` + `scenes/child_drive_stop.tscn`: the street in front of the destination
  (HOSPITAL / SCHOOL / OFFICE / SHOP sign, TR under it when TR is on). "leave": out of the door, walk to the car,
  get in, drive off. "arrive": drive in, stop, both get out, objective + pan to the door, walk in side by side.
- `voice_drive/<f|m|c|g|amy|ryan>/<md5(text)[:12]>.ogg`: only the NEW lines (rendered by
  `tools/build_voice_child_drive.py`, same Piper models and filters as the narrator packs). Separate folder, so
  `data/voice_index*.json` and the voice banks are not touched (they will merge cleanly with v33-days-4-7).
- `tools/qa_child_drive/` (QA only, excluded from the APK by `tools/*`).

## Small hooks in existing files
| file | hook |
|---|---|
| `scripts/world/street_object.gd` `_drive` | first line: `if ChildDrive.wants_drive(d): ChildDrive.depart(self, d); return` (day-2 trips, child with a parent) |
| `scripts/world/world_exterior.gd` | after `d2.run()`: `ChildDrive.escort(self)`; new `elif _home_car and ChildDrive.arriving_home()` line above the v32 `elif _home_car` |
| `scripts/story/hospital_day2.gd` | child: `ChildDrive.trip(..., "hospital", "work"/"home")` after the v32 "Now I'm going to work." line / instead of the home_car jump |
| `scripts/story/work_summary.gd` | child: `ChildDrive.trip(..., "work", "hospital"/"home", true)` (the summary's black screen covers the switch) |
| `scripts/story/work.gd` | `say_line(ChildDrive.child_line(...))`: "I am driving home." -> "My mom/dad is driving me home." for a child |
| `scripts/phone.gd` | `_needs_parent()` / `_parent_block()`: close(), close(true), back(), show_page() (Home / any app), family_done() blocked on the family / member pages; Done dims and shows the hint |
| `scripts/main.gd`, `scripts/room_phone.gd` | `_family_ok()` replaces `not S.family.is_empty()` in door_rule / objective / first phone page / todo (adults: identical) |
| `data/extra_lines.json` | 25 TR lines inserted at the TOP of the file (other branches append at the end) |

## Flow (child)
Day-2 morning: Mom/Dad comes out of the front door with the child and walks beside them ("Go to the car." as v32).
Car chips (v32) -> parent: "Get in the car, please." -> child walks round to the passenger door, parent to the
driver's door, both doors open (passenger door = mirrored panel), stand_to_sit -> sit_idle, doors close,
"Put on your seat belt." / "Let's go!", drive down the driveway and onto the street (camera follows),
"My mom is driving me to the hospital." (objective top-left + TR) -> stop scene: car drives in, "The car is stopping.",
"We are here.", both get out, "I am closing the car door.", objective "Go to the hospital." + pan to the door,
"We are here. Let's go in.", walk in together -> v32 hospital_day2. After the visit (v32 "Now I'm going to work.")
-> stop scene leave -> "My mom is driving me to school." -> arrive at SCHOOL -> v32 work_summary -> leave ->
"Let's go home." / "My mom is driving me home." -> world_exterior: the car drives along the street and turns into
the home driveway, "We are home.", both get out, v32 "Go inside and talk to my family." + pan; the parent walks
beside the child to the door.
Driving lines: "My mom/dad is driving me to school / to the hospital / to work / home / to the shop."
(TR "Annem/Babam beni okula / hastaneye / işe / eve / dükkana götürüyor."). The child never says "I am driving ...".

## Voices
Child lines: the selected narrator pack clip (c/g/m) if it exists, else `voice_drive/<narrator>/`, else silent; f uses
the normal Voice path. Never another voice. Parent lines: `v_amy` / `v_ryan` pack clips if they exist, else
`voice_drive/amy|ryan/` (mother = amy, father = ryan, as hospital.gd).

## Notes / risks
- The trips between places play in the stop scene (no hospital / school lot exists in the city grid); the cut
  between "driving off" and "arriving" is a 0.5 s fade to black while driving (no teleport on screen).
- Home arrival leaves the family car parked nose-to-house (it drove in forwards). The next scene load resets it.
- `scripts/qa_flow.gd:1283` (old v31 QA) still expects "I am driving to school." for its own fixture; not a game path.
- `work.gd`'s line is only used by the old 3D work routine (day 2 uses work_summary); its child variant has TR but its
  clip is voice_drive only through ChildDrive (work.gd's own say_line may play it silently for c/g narrators).
- A child save from before v33 with family but no mom/dad: the bedroom door locks again until a parent is added
  (that is the hard rule); the drive then falls back to the v32 adult flow only if no parent exists.
