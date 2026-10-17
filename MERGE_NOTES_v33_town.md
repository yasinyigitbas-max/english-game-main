# v33 whole town (branch v33-wholetown-black) - house.33town, versionCode 44

Experimental build on top of the v32wh whole house. **Isolated and revertable**: one switch,
`scripts/core/town.gd` `const ENABLED := true` -> `false` gives back the exact v32wh door behaviour;
reverting the branch commit removes it completely.

## What changes
* The street (`scenes/world_exterior.tscn`), the three house rooms, the cafe and the shop are one scene tree.
  `Game.go_to()` between two of them (the home lot door, the living-room front door, cafe / shop doors in and out)
  swaps the live place in place (`Town.go`) instead of `change_scene_to_file`. Room-to-room doors keep using
  `House.go` (unchanged v32wh mechanism).
* Live place = `current_scene`, at the world origin, runs its exact v32 code (`_live_ready` = the old `_ready`).
* Shells (meta `house_shell`, `PROCESS_MODE_DISABLED` -> physics bodies removed, no processing):
  * house rooms next to a live house room: drawn (v32wh geometry shells, cheap lighting) - unchanged;
  * everything else: `visible = false` (no draw calls / shadows; `player._scan` ignores hidden interactables).
    From the street you only ever see the street's own building meshes (walls / roof), never an exposed interior;
    from inside, the space outside the room is dark (house: v32wh dark-outside; cafe / shop: clear colour made dark).
* Leaving the street frees the street scene node exactly like change_scene did (HUD, camera, traffic, NPCs, story
  coroutines all go), but its `WorldGrid` with the loaded city blocks is handed to the new street shell, so coming
  back out instantiates no blocks. On hand-over: the grid's follow target is cleared, NPC spots forget their
  (freed) NPCs, lot front doors swing shut (what the rebuild used to reset).
* Cafe / shop shells are empty until entered; their whole v32 `_ready` runs on entry (same as before).
* Missing shells are created one per frame after a place goes live; a fresh street shell streams its 3x3 blocks one
  per frame at the street origin (bus stops / focus points register in street coordinates).
* Every member has its real spot in the street frame (`Town.xf`): house rooms inside the home lot
  (living room origin at (-5.35, 0.1, -0.4)), the cafe interior behind the cafe lot door, the shop behind the
  shop door (both turned 180 degrees to face the street). Hidden shells' transforms are cosmetic.

## Not merged (still change scene, as before)
Hospital (day 1 accident, day 2 visit), work / school / shopping trip (car), menu: they have no door in the street
(they are reached by a cutscene or the car), so there is nothing to walk through. Leaving to them frees the whole
town (`House._on_live_exit`); coming back rebuilds it.

## Known behaviour differences
* Street objects keep their state while you are indoors (an opened mailbox / bin / gate stays open when you come
  back out; v32 rebuilt the street, so they reset). Story / save state is unaffected.
* Memory: the street's blocks stay resident while indoors, the house rooms stay resident while outdoors.
