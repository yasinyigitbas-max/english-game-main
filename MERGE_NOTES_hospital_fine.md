# v32-hospital-fine: varied "My X is/are ..." answers in both hospital scenes (red)

**UNTESTED.** Godot was not run. Only text constants and the EN->TR table changed (no logic changes).
Branched off `v306-hospital-closeups` (1648f0c). That branch has the newest `hospital.gd` and `hospital_day2.gd`, and it sits
on top of v31.1 (f69f512 = `v31-day2-hospital`, the repo default branch, since the repo has no `main` branch).

## Why
The player answered every body question with "... is/are fine." Each answer now uses a different "being fine" word,
with no word used twice inside one scene. Subject + is/are agreement is kept, because is/are is the point of the exercise:
singular part -> **is**, plural part -> **are**. A1-A2 words only.
"fine" is no longer used in any body answer. Day 1: the doctor then says "Good. You are fine." Day 2: the greeting is "I am fine, thank you.". Neither line was changed.

## Changed lines (old -> new | new TR)
### Day 1: hospital.gd `BODY` (doctor body check after waking up)
| # | Old | New | TR (new) |
|---|-----|-----|----------|
| 1 | My legs are fine. | My legs are strong. | Bacaklarım güçlü. |
| 2 | My chest is fine. | My chest is okay. | Göğsüm fena değil. |
| 3 | My ears are fine. | My ears are good. | Kulaklarım gayet iyi. |
| 4 | My eyes are fine. | My eyes are perfect. | Gözlerim mükemmel. |
| - | My arm hurts a little. | (unchanged) | Kolum biraz acıyor. |

### Day 2: hospital_day2.gd `BODY2` (day-2 visit)
| # | Old | New | TR (new) |
|---|-----|-----|----------|
| 5 | My head is fine. | My head is okay. | Başım fena değil. |
| 6 | My neck is fine. | My neck is all right. | Boynum iyi durumda. |
| 7 | My shoulders are fine. | My shoulders are strong. | Omuzlarım güçlü. |
| 8 | My stomach is fine. | My stomach is not hurting. | Karnım ağrımıyor. |
| 9 | My hands and fingers are fine. | My hands and fingers are perfect. | Ellerim ve parmaklarım mükemmel. |
| 10 | My knees are fine. | My knees are healthy. | Dizlerim sağlıklı. |
| 11 | My feet are fine. | My feet are great. | Ayaklarım harika. |
| 12 | My nose is fine. | My nose is good. | Burnum gayet iyi. |
| - | I am fine, thank you. / My back hurts a little. / I brush my teeth every day. | (unchanged) | |

Words used. Day 1: strong, okay, good, perfect. Day 2: okay, all right, strong, not hurting, perfect, healthy, great, good.
No word repeats inside either scene.

## TR table: data/extra_lines.json
- The 12 old keys were replaced in place by the 12 new keys and TR values above. The file keeps its order and format (indent 1).
- Added a missing TR for an existing day-2 doctor line, which had no Turkish before:
  "Yesterday we checked your legs, arms, chest, ears and eyes." -> "Dün bacaklarına, kollarına, göğsüne, kulaklarına ve gözlerine baktık."
- `scripts/story/story_ui.gd` (full game, not in this repo) has its own `const TR` with the OLD day-1 keys ("My legs are fine." ...).
  `StoryUI.tr_of()` checks that table first and falls back to `extra_lines.json`. The new keys are only in extra_lines, so they get the right TR.
  The old story_ui entries are now dead but harmless. You can delete them when merging.
- Merge: `v31-evening-day3` also edits extra_lines.json, but in other places, so a normal 3-way merge should be clean.

## Quizzes / tests
No quiz or test checks these answers. The day-2 phone test (`data/body_day2.json`) and the day-1 test (`data/can_should.json`)
are about can/should and body words only. `scripts/qa_v31_day2.gd` only looks for "My back hurts", which is unchanged. Nothing to update.

## Voice: NEW CLIPS NEEDED
How voices work (full game `scripts/audio.gd` + `scripts/story/story_ui.gd`): `StoryUI.line(en, who, pause, voice)` calls
`Audio.say(en)` for player ("Me") lines and `Audio.say_as(en, "hfc_male")` for the doctor. `Audio.say` looks up a **pre-rendered Piper clip**
keyed by `Audio.norm(text)` (lowercase, punctuation stripped). It looks in `data/voice_index.json` -> `voice/voice_NNN.bin`
(Ogg Vorbis, en_US-ljspeech-medium = default "f" narrator). For the other narrator voices it uses
`data/voice_index_{m,c,g}.json` -> `voice_{m,c,g}/*.bin` (Male/Boy/Girl, tools/narrator_voices/). If no clip exists, it falls back to
device TTS (`DisplayServer.tts_speak`, the robotic OS voice) or stays silent on platforms without TTS.
So changing the text is NOT enough: all 12 new player lines need clips in all 4 narrator packs (f, m, c, g):
  my legs are strong / my chest is okay / my ears are good / my eyes are perfect / my head is okay / my neck is all right /
  my shoulders are strong / my stomach is not hurting / my hands and fingers are perfect / my knees are healthy /
  my feet are great / my nose is good
(The 12 old "... fine" clips exist in all packs and are simply no longer used.)
Producing them: tools/build_voice.py takes its line list from main.gd TR + extra_lines.json keys, so the new keys get picked up. Or render
only the missing ones as tools/build_voice_day2.py does (new chunk + index merge). Then run tools/narrator_voices/
(collect_lines.py -> render_voices.py -> build_narrator_packs.py) for m/c/g. None of this was run here.
Optional: "Yesterday we checked your legs, arms, chest, ears and eyes." (doctor, hfc_male) is an old line with only a TR change, so its voice is unchanged.

## Files
- scripts/story/hospital.gd: `BODY` (2 lines)
- scripts/story/hospital_day2.gd: `BODY2` (5 lines)
- data/extra_lines.json: 12 keys replaced, 1 added
- MERGE_NOTES_hospital_fine.md: new (allow-listed in .gitignore)
