# v33-days-4-7-red (red): days 4 and 7 + shared bedtime test bank

Base: english-game-red `v32-polish-red` de3218f. **v33 QA: played start to end in a real Godot 4.7.2 run (see 7).**

## 1. Shared no-repeat bedtime test bank (for blue's days 5 / 6 too)
Files: `scripts/story/test_bank.gd` (class_name TestBank, but reference it by PATH), `data/test_bank.json`.
```gdscript
const TB := preload("res://scripts/story/test_bank.gd")
var qs: Array = TB.draw(5, 10)                  # 10 questions of day 5, never used before
var res: Array = await TB.run_test(m, m.phone, 5) # full phone test page -> [score, total]
```
- `TB.draw(day:int, n:int = 10, topics:Array = [], ver:int = -1) -> Array` of `{id, day, v, topic, q, opts, a, say, tr}`
  (opts shuffled, `a` = index of the right option in the shuffled opts, question order shuffled).
  Order: (1) unused questions of the day's CURRENT version, (2) unused questions of its other versions,
  (3) unused review questions of EARLIER days with the same topics, (4) only if all of that is used up: the day's least
  recently used questions (a test is never empty). Every draw marks its ids as used and rotates the day's version
  (0 -> 1 -> 2 -> 0), so Retake gets a new set. `topics = []` = all topics of the day; unknown topics = the whole day.
- Save: `save.json "test_bank" = {"used": [ids, most recent last], "ver": {"4": 1, ...}}` (App.patch_save; survives
  continue / reload).
- `TB.questions(day, topics := [])`, `TB.version(day)`, `TB.used_ids()`, `TB.is_used(id)`, `TB.mark_used(ids)`,
  `TB.reset(day := 0)` (0 = all).
- `TB.run_test(host, phone, day, {"n": 10, "topics": [], "key": "TestBank_d5"})`: same rules as d2/d3_night_test.gd:
  notebook reminder once (not on Retake), answers wait for the narrator, feedback + TR, score page, "You should study the
  grammar again." when half or more are wrong, Retake (= fresh draw), Continue, shared skip button (`tests_skipped.<key>`).
  host must have `caption(t, speak)` (main.gd / livingroom.gd do). The phone must exist; it is opened if needed.
- Data: one entry per question, `id` unique (`d5_01`...), `day`, `v` (0/1/2), `topic`, `q` (`___` = gap), `opts`, `a`, `say`,
  `tr`. Seeded: day 2 (18, from day2_evening.json quiz/quiz_b/quiz_c), day 3 (18, from day3_evening.json), day 4 (30),
  day 7 (30). **Blue: append 30 entries for day 5 and day 6 (10 per version)** and add each `say` -> TR to
  data/extra_lines.json. Topics in use: past_simple, countable, how_many_much, cafe_order, containers, there_is_are,
  prepositions, power_cut, party (list in the json `topics`).
- d2/d3_night_test.gd are unchanged (they still use their own 6-question sets).
- Retake draws a fresh set, so with 30 questions per day the first test and two Retakes never repeat a question.
  After that, review questions from earlier days fill the set, and only when everything is used do old questions come back.

## 2. Day 4 (power cut) and day 7 (surprise party): files
| file | what |
|---|---|
| scripts/story/day4_routine.gd | Root-node routine driver (extends day3_morning.gd for room detection, guide wrapper and town pans). Stage `story.d4`: start/"" -> shower -> breakfast -> outing -> home -> evening -> bed -> done. `start(tree)` (static, idempotent, days 4 + 7), `main_objective()` (bedroom objective) |
| scripts/story/day4_breakfast.gd | Family breakfast: guide_to the table, auto-sit, eating loop, **review of the previous day** (3 TestBank questions of that day, choice panel, the answer spoken as "Me: ..."), the day's data dialogue, table clears, family goes to the TV, south wall force-faded. Snapshot `d4_breakfast` / `d7_breakfast` |
| scripts/story/day4_shop.gd | Checkout dialogue inside blue's shop. Blue's file is not edited: it waits for blue's exit objective, then: walk to the counter, assistant lines (NpcTalk, own voice, HUD caption), Economy.spend, bag, snapshot `d4_shop` / `d7_shop`, flag `story.d4_shop` |
| scripts/story/day4_evening.gd | Step interpreter (data "evening") + the day-4 power cut: couch (guide_to sofa, sit, family keeps the sit pose, force_fade), props (3 candles, matches, torch), power cut (all lights + TV off, dark ambient kept every frame), guided "Find the torch." / "Light the candles.", torch SpotLight, candle OmniLight (flicker), lights back on, polaroid `d4_candles` ("Take a photo." pan + flash + Life.snap_from), stand up, "Go to bed." |
| scripts/story/day4_talk.gd | Static helpers: fam / me / line / all (everybody), scrambled `puzzle` (built sentence in the ONE caption box with TR, then spoken), `choose` (MC panel), `card` (polaroid card of any size) |
| scripts/story/day4_polaroids.gd | Fallback stills with the player's own character for d4_* and d7_* keys (only when a real snapshot is missing) |
| scripts/story/day4_bedtime.gd | extends bedtime.gd: dream polaroids (data "recap"), TestBank 10-question test, sleep -> **day 5**: silent "Day 5" title, the standard wake lines (`_wake_simple`), `story.d5 = "start"`, `_handoff()` |
| scripts/story/day7_routine.gd | day4_routine with day-7 data (`story.d7`), evening = day7_party.gd |
| scripts/story/day7_party.gd | extends day4_evening: `prepare(lr)` (dark room, family hidden), surprise steps (data "party": reveal, "Surprise!", week photo wall days 1-6, cake), then the couch scrambles + polaroid `d7_party` |
| scripts/story/day7_bedtime.gd | day4_bedtime with day 7 -> day 8 (wake lines, `story.d8 = "start"`, placeholder "Start your day.") |
| data/day4.json, data/day7.json | All lines (`lines` EN -> TR), steps: breakfast / shop / evening / party / week / recap / dream_line, shop price and items |
| data/test_bank.json, scripts/story/test_bank.gd | see 1 |
| data/extra_lines.json | +170 EN -> TR entries (every new visible line, the test-bank sentences, Day 1-8 titles) |

### Day 4 flow
Wake (bedtime.gd day-3 night, unchanged: "I'm waking up." / "I'm getting up.") -> "Take a shower." (pan to the bathroom door, then the shower) -> "I feel fresh and clean." -> "Go to the living room." -> breakfast: review day 3 (café / countable / how much / past simple), then the news: storm tonight, "We need candles and batteries for the torch.", "A torch is a flashlight.", "Can you go to the shop, please?" -> "Go to the shop." (front-door pan, then the outdoor shop pan) -> in the shop: "Are there any candles?" / "There are batteries under the counter. How many do you need?" / £4.50 -> "Go outside." -> "Go back home." (home pan) -> 18:00, "Talk to my family." (sofa pan) -> "Where are the candles?" scramble -> the wind -> **POWER CUT** ("Oh no! The lights went out." "It's a power cut." "It's very dark. I can't see!" "Don't be afraid. Where is the torch?") -> "Find the torch." pan + scramble -> torch on -> "Are there any matches?" -> "Light the candles." pan + scramble -> there is / there are tip -> "Are you afraid?" scramble -> photo by candlelight -> lights back on -> "Go to bed." -> bedtime 4 -> day 5.
English focus: there is / there are (+ any, questions, short answers), prepositions (on, in, under, next to), imperatives (Don't be afraid, Don't worry, Turn on), power-cut words, past simple (went out, bought, lit, came back).

### Day 7 flow
Day 6 (blue) ends with `WorldState.day == 7` -> the routine starts on the first bedroom / living-room entry or main.gd `_advance` (story.d7 "" -> "shower") -> shower -> breakfast: review **day 6** (TestBank day-6 entries; falls back to day 5, then day 4 when blue has not added any) + "It's your first week here!" + "Can you go to the shop, please? We need some milk." ... "Take your time." -> shop (milk, £1.50) -> "Go back home." -> the living room is DARK, nobody there: "Hello? Where is everybody?" -> "Turn on the light." -> the family jumps up behind the sofa and waves, balloons and a "Congratulations!" banner -> "Everybody: Surprise!" -> "You finished your first week. Congratulations!" -> **photo wall of days 1-6** (one card per day from the existing polaroid storage, Life.photo; "What did you do on day N?" -> past-simple answer) -> cake -> couch: 4 past-simple scrambles ("No, I didn't know about the party." ... "The lights went out and we lit candles.") -> present (photo album) -> polaroid `d7_party` -> "Go to bed." -> bedtime 7 (past simple + party test) -> day 8.

## 3. Hooks (the only edits to existing files)
- scripts/main.gd:1908-1909 `objective()`: `Day4Routine.main_objective()` replaces the v32c placeholder line (`d4 == "start"` -> "Start your day."). The day-8 placeholder lives there now.
- scripts/main.gd:1914 `_advance()`: `day4_routine.gd start(get_tree())` (idempotent; this is how day 7 starts after blue's day 6).
- scripts/livingroom.gd:182 `_intro()`: `day7_party.gd prepare(self)` (dark room before the first frame of play).
- scripts/livingroom.gd:183 `_intro()`: `day4_routine.gd start(get_tree())`.
- scripts/story/bedtime.gd:36-38 `hook_bedroom()`: day 4 / day 7 bedtime (`story.d4_bed_pending` / `d7_bed_pending`) -> day4_bedtime.gd / day7_bedtime.gd.
- scripts/story/bedtime.gd:41 `hook_bedroom()`: `day4_routine.gd start()` next to Day3Morning.attach.
- scripts/story/bedtime.gd:209 `_sleep_to_day4()`: starts the day-4 routine instead of `_day4_prompt()` (that function is now unused).

## 4. For blue (days 5 / 6)
- Day 4 -> 5: day4_bedtime.gd sets `WorldState.day = App.day = 5`, `story.d4 = "done"`, `story.d5 = "start"`, plays the silent "Day 5" title and only the standard wake lines in the bedroom, then calls the first static `start(tree)` or `attach(tree)` it finds in `res://scripts/story/day5_routine.gd`, `day5_morning.gd` or `day5.gd`. Without one, main.gd's normal objective shows.
- Day 6 -> 7: set `WorldState.day = App.day = 7` and do the day-7 wake in your day-6 bedtime. Optionally call `load("res://scripts/story/day4_routine.gd").start(get_tree())` after it (main.gd `_advance` and the room hooks also start it). Do not set `story.d7` yourself, or set it to "start".
- Bedtime test: `await preload("res://scripts/story/test_bank.gd").run_test(m, m.phone, 5)`. Add 30 day-5 and 30 day-6 entries to data/test_bank.json.
- Day-7 photo wall / breakfast review read your data defensively: `data/day5*.json` / `day6*.json` `"recap": [[photo_key, caption], ...]` (the same format as day3_evening.json; the first key with an existing photo is used, and its caption must have TR in extra_lines.json). Otherwise `story.d5_recap` / `d6_recap` keys (bedtime.gd stores them) with the caption "I had a good day.", otherwise that day's card is left out. The breakfast review uses your day-6 test-bank entries.

## 5. Lines needing voice clips
Captions use the existing voice path (clip if one exists, else live TTS). New lines:
### Narrator / player voice (Audio.say)
- I feel fresh and clean.
- Take a shower.
- Go to the living room.
- Go to the shop.
- Here is the shop.
- Go back home.
- Here is my home.
- Go outside.
- Have breakfast with your family.
- Have breakfast.
- I am sitting at the table.
- I am having breakfast.
- Breakfast is over.
- Talk to my family.
- I am sitting on the sofa.
- I am standing next to the sofa.
- Find the torch.
- Light the candles.
- Take a photo.
- Click! A photo for my album.
- Turn on the light.
- Look at the cake.
- Go to bed.
- Start your day.
- I am dreaming about my day.
- Now a test about my day. Ten questions.
- Get a notebook and a pencil. Let's take notes.
- Choose the right words.
- That is right!
- Not quite.
- You should study the grammar again.
- Good night!
- I am sleeping.
- I'm waking up.
- I'm getting up.
- A torch is a flashlight.
- Yes, of course!
- I need candles and batteries.
- Yes, please. Are there any candles?
- And I need some batteries for my torch.
- Four, please.
- Here you are.
- Thank you. Goodbye!
- Yes, I did. I bought candles and batteries.
- Put the words in the right order.
- The candles are on the table.
- The wind is very strong tonight.
- Oh no! The lights went out.
- It's a power cut.
- The torch is next to the candles.
- I am turning on the torch.
- Yes, there is a box of matches.
- We are lighting the candles.
- There are three candles on the table.
- There is + one thing. There are + two or more things.
- No, I'm not afraid.
- The lights came back on!
- I took a shower.
- I had breakfast with my family.
- I bought candles and batteries.
- The lights went out. We lit candles.
- Went, bought, lit: this is the past simple.
- Wow! A whole week!
- I need a bottle of milk.
- Can I have a bottle of milk, please?
- Here you are. Thank you!
- No, I didn't know about the party.
- I learned a lot of English.
- My favourite day was day four.
- The lights went out and we lit candles.
- Thank you! What is it?
- I love it! Thank you for the party.
- It is very dark in here.
- Hello? Where is everybody?
- I am turning on the light.
- Wow! A party for me?
- Went, bought, lit: we use the past simple for the past.
- Thank you! It looks delicious.
- I learned will, going to and have to.
- I went to the café and the shop.
- I bought candles. Then the lights went out!
- I had a good day.
- I went to the shop.
- My family had a party for me.
- Had, went, shouted: this is the past simple.

### Family voices (Audio.say_as, each member's Piper voice: amy/kristin/hfc_female/lessac, ryan/joe/hfc_male, child_f/child_m)
- Good morning! Let's review yesterday's English.
- Well done!
- Good try! Let's practise more tonight.
- Listen! The news says there is a big storm tonight.
- Maybe the power will go off.
- We need candles and batteries for the torch.
- Can you go to the shop, please?
- Did you buy the candles?
- Where are the candles?
- Thank you! Now we are ready for the storm.
- It's very dark. I can't see!
- Don't be afraid. Where is the torch?
- Are there any matches?
- Are you afraid?
- Look! It's nice and cosy now.
- Hooray! The power is back.
- Let's blow out the candles.
- It's late. Time for bed.
- Today is day seven. It's your first week here!
- Can you go to the shop, please? We need some milk.
- Thank you! Take your time.
- Come and sit with us.
- Did you know about the party?
- What did you do this week?
- What was your favourite day?
- Why?
- Here is a present for you.
- It's a photo album with our photos.
- Let's take a photo together!
- Surprise!
- Yes! You finished your first week. Congratulations!
- Look! These are our photos from this week.
- And there is a cake for you!
- What did you do on day 1?
- What did you do on day 2?
- What did you do on day 3?
- What did you do on day 4?
- What did you do on day 5?
- What did you do on day 6?

### Shop assistant (blue's shop NPC voice, meta "voice")
- Hello again! Can I help you?
- Yes, there are. Here you are.
- There are batteries under the counter. How many do you need?
- That's four pounds fifty, please.
- Thank you! Be careful in the storm.
- Hello! What would you like today?
- Here you are. That's one pound fifty.
- Have a nice evening!

### Test bank feedback sentences, days 4 + 7 (narrator, Audio.say(q.say))
- There is a candle on the table.
- There are two torches in the drawer.
- Put the candle on the table, please.
- The lights went out.
- Don't be afraid!
- Where is the torch?
- Are there any batteries?
- I bought some candles at the shop.
- It is very dark in here.
- Turn on the torch, please.
- There are some batteries in the box.
- There is a torch under the sink.
- The matches are in the cupboard.
- The power went off in the evening.
- Don't be afraid. It's only a power cut.
- Where is the torch? It's in the drawer.
- Is there a candle? Yes, there is.
- I bought candles and batteries this morning.
- I can't see. It's too dark.
- The candle is next to the window.
- There are no lights in the house.
- There is a box of matches on the shelf.
- The batteries are in the torch now.
- We lit the candles.
- Don't worry. I'm here.
- Where are the candles? They're in the box.
- Are there any matches? No, there aren't.
- The lights came back on.
- I wasn't afraid of the dark.
- The torch is under the bed.
- This week I learned a lot of English.
- My family planned a party.
- Everybody shouted "Surprise!"
- We ate some cake.
- I was very happy.
- We sang songs and danced.
- There were balloons everywhere.
- Did you enjoy the party?
- I went to the shop this afternoon.
- Thank you for the party!
- On day 3, I went to the café.
- On day 4, the lights went out.
- We lit candles in the dark.
- My family hid behind the sofa.
- Did you like the cake? Yes, I did.
- The cake was delicious.
- We took a lot of photos this week.
- I got a present from my family.
- We had the party at home.
- Let's take a photo!
- This week I took a shower every morning.
- I bought candles and batteries on day 4.
- I didn't know about the party.
- The party was a surprise.
- My family decorated the living room.
- We danced and laughed.
- Everybody looked at the photos.
- What did you do on day 3?
- I had a great week!
- There was a big cake on the table.

Family lines are captioned "Name: line" and spoken with `Audio.say_as(en, voice_of(member))`. "Everybody: Surprise!" uses the first member's voice. Player lines are "Me: line" in the narrator voice.

## 6. Untested / risks (nothing was run in Godot)
- Not run or parsed by Godot. Syntax was checked with gdtoolkit `gdparse` (all new files pass). Semantics were checked by reading only. First QA run: watch for GDScript type errors in the new files.
- No `.uid` files for the new scripts: Godot creates them on the first import. Everything loads by path (no new class_name dependency, except `class_name TestBank`, which nothing needs).
- day4_shop.gd depends on blue's shop internals as they are now: `its.exit`, `mode`, `npcs.assistant`, `walk_to`, `cine`/`cine_end`, `hud.caption`, `_mute_next`, and the checkout at shop.gd `CK = (3.6, 0, 2.3)`. If blue changes the repeat-visit flow, the dialogue waits up to 4 min for the exit objective, then is skipped and the routine still continues.
- Power-cut darkness overrides `lr.env.ambient_light_energy` / `lr.sun.light_energy` every frame while dark. The candle / torch lights are positioned from livingroom.gd's coffee table (0.85, 0.44, 0). Check how dark it looks on Android (GL Compatibility) and the light energies.
- Party: the family is teleported behind the sofa (x 3.5) to stand, then re-seated with `family_at_tv_now()` under a black fade. Check that nothing intersects at x 3.5 and that the reveal `cam_shot` framing from the front door is good. Balloons and the banner are simple meshes plus a Label3D (TR entry "Congratulations!").
- Polaroid snapshots (breakfast, shop, candles, party) use guessed offscreen camera offsets. If a frame is bad, delete the user://photos/<key>.png and the day4_polaroids still is used instead.
- Day-1 photo on the wall = "breakfast" (shipped still) etc. Days 5 / 6 depend on blue's data (see 4).
- "My family were on the sofa." (seeded from the existing day-2 test) is BrE plural-agreement. Yasin, please review all new English (data/day4.json, day7.json, test_bank.json days 4 / 7).
- main.gd `objective()` keeps "Start your day." for all of day 8 (same as the old day-4 placeholder) until a day-8 owner replaces it.

## 7. Real-run QA (v33 QA, Godot 4.7.2, xvfb, opengl3, 1600x720, TR on)
Harness: `tools/qa_d47/` (`run.sh <4|7>`: honours /workspace/godot.lock + pgrep, fresh save from `make_save.py`, its own
user:// via XDG_DATA_HOME). `qa_d47.gd` plays the player's part (rooms, shower verb, sofa walk, puzzles, review choices,
shop exit, bedtime test) at 3x speed and screenshots every objective and every spoken line (/tmp/qa_d47/shots_d4|d7).
It checks every step that moves the story forward: top-left objective panel, camera pan (cam_shot / temporary camera) in
the step's window, a spoken line (clip or Piper), exactly ONE bottom-centre caption box with the TR button inside + TR text,
and NO caption box on the test screen. Also: seated NPC pose while lines play, 10 unique test questions, the test screen
(no scroll, answers low), the power-cut brightness, the shop checkout flag, polaroids, the day change.

Results of the last real runs (16:46 day 7, 16:48 Istanbul time day 4): day 7 -> 8: 15/15 PASS. Day 4 -> 5: all PASS except one step:
the day-5 placeholder "Go to the living room." had no pan. That is fixed now (day4_bedtime.gd fallback guide_to) but not re-run.
Each run: 14 objective steps, about 130 spoken lines, 0 caption-box problems, 0 pose problems, 10/10 unique test
questions, test screen with no scroll and low answer buttons, power cut mean luminance 0.10-0.14 dark and 0.29-0.36 with
candles, no script errors from these files. The only engine ERRORs are the box's missing TTS synth at startup and "2
resources still in use at exit". On Yasin's instruction there was NO Godot run after these last edits: the day-7 reveal camera +
cake position, the breakfast controls hide, the day-5 fallback pan. They were parse-checked only (gdtoolkit) and wait
for the combined final test.

Fixed in this pass:
- day3_morning.gd:261 parse error under 4.7.2 (`var pan :=` could not infer the type) -> broke Day3Morning AND
  day4_routine.gd (extends it): days 3, 4, 7 never started. Now `var pan: bool`.
- Outdoor / shop lines were SILENT: UniversalScene.caption -> Voice.say plays clips only (no Piper fallback). New
  `Day3Morning._cap_out()` (day3_morning.gd) for objectives and pan stops in universal scenes; day4_shop.gd `_me()` for
  the player's checkout lines. Shop assistant lines ran 0.2 s apart (voice_idle gives up after 8 s): now Audio.wait_idle.
- livingroom.gd `_advance()`: the room's own "Turn on the TV." / "Sit on the sofa." flashed up for 1 s on day-4/7
  entries -> the Day4/Day7 routine now owns the objective while it lives (one guard line).
- Power cut: the window still showed a bright day sky and the table lamp glowed -> dark storm sky, lamp off, cool moonlit
  ambient (day4_evening.gd `_dark_env` / `_light_env`); lights-on restores everything. The surprise reveal uses it as well.
- On-screen controls (joystick / hand) hidden during the breakfast, couch and party cinematics (Life.guide_to showed
  them again after every pan); back for the sofa walk and at the end.
- Party reveal camera sat inside the south wall (the whole screen was wall) -> TV-side shot of the family behind the
  sofa. The cake was inside the fruit bowl -> free corner of the coffee table.
- story_ui.gd:85 `get_meta("on", null)` printed an ERROR every frame while a StoryUI caption was up -> has_meta check.
- day4_bedtime.gd fallback hand-off (no day-5 code in this branch) now uses guide_to (pan + voice) instead of _advance.
- TestBank (Yasin's test-screen rule): the whole phone screen with no scrolling, answers + skip as low as possible (a gap
  above them), the score buttons at the bottom, and the bottom caption box hidden for the whole test (every test
  line is on the page). `_say_off(t)` shows it only while an off-screen line is spoken.

Blue hand-off checked: day4_bedtime `_handoff()` calls `res://scripts/story/day5_routine.gd` `start(get_tree())` after it
sets story.d5 = "start" (blue's entry). Day 7 from blue: WorldState.day = 7 + story.d7 = "start" -> Day4Routine.start()
-> "shower" (the QA day-7 save starts exactly like this and runs to day 8). The day-7 photo wall reads blue's
data/day5.json / day6.json "recap". data/test_bank.json was not edited here (blue's d5/d6 entries merge cleanly).

Still open / not red's:
- About 60 new lines per day have no voice clip yet and use the live Piper fallback (list in section 5; the QA log
  prints them as PIPER_FALLBACK). Family lines without a "v_<voice>" clip are in the narrator voice.
- world_exterior.gd:43 (blue/black) sets "Walk to the street." on every street entry. It shows for about 2 s before
  red's "Go to the shop." / "Go back home." replaces it.
- The living room's unshaded south-wall stub (livingroom.gd `_south_wall`, SHADING_MODE_UNSHADED) stays light cream
  in the dark room (day-7 entry, power cut) when the default camera looks over it.
- QA screenshots: the viewport image has an alpha channel, so unshaded / alpha-hash areas looked WHITE in PNG viewers
  (it is not in the game). The harness now saves RGB.
- day2_morning.gd uses the same breakfast pan (camera z 3.1, just outside the south wall). It renders fine in game (the
  "white" was the alpha artefact above). Not changed.
