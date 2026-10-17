# Open world (house.34ow) - phase 1 skeleton

Only gameplay scene: `scenes/world.tscn` (`scripts/core/world.gd`, class `World`). `App.GAME_SCENE` now points to it (New game / Continue).
Everything is built once in `World._ready` and never freed, rebuilt or shifted. One `WorldPlayer` ("Hero"), one `CameraRig`
driven by blue's ShoulderCam, one HUD. No change_scene, no fade while walking.

## Places (fixed world positions)
| id | scene | position | yaw |
|---|---|---|---|
| street | WorldGrid, every block of city.json spawned at load | grid cells | - |
| livingroom | res://livingroom.tscn | HOUSE_AT (-5.35, 0.1, -0.4) | 0 |
| bedroom | res://main.tscn | HOUSE_AT + (0, 0, -6.0) | 0 |
| bathroom | res://bathroom.tscn | HOUSE_AT + (5.95, 0, -4.75) | 0 |
| cafe | scenes/places/cafe.tscn | (8.5, 0.07, 32.5) | PI |
| shop | scenes/places/shop.tscn | (-3.0, 0.07, 33.5) | PI |
| hospital | ward from scripts/story/hospital.gd `_room()` (scripts/world/ow_places.gd) | (0, 0, -84) | PI |
| school | work.gd `_room` + `_set_classroom_student` (category study) | (42, 0, -84) | 0 |
| work | work.gd `_room` + `_set_<setting>` of the player's job category (office if none / school) | (-42, 0, -84) | 0 |
hospital/school/work stand on a north strip (z -62..-110, own road at z -70) OUTSIDE the town fence: reached by `World.skip_travel` until day 8.
The street lots `home`, `cafe`, `corner_shop` lose their solid building box/collider/fake door; the interior stands there.
House rooms are instanced with the House.SHELL meta (geometry + furniture), place scenes with `ow_shell` (build()+_room()).
All rooms/places run with process DISABLED in phase 1 (no story yet; NPCs hold pose). Rooms get colliders from their
thin tall wall boxes + `obstacles` rects. Region = room AABB (cafe/shop: floor rect), else "street".

## Doors (World.doors, class World.WorldDoor)
ids: `bed_bath`, `bed_living`, `bath_living`, `front` (house -> street), `cafe`, `shop`, `hospital`, `school`, `work`.
Fixed spots (`World.spot(id)` / `hero.place_at(id)`, with yaw): `home_car`, `home_bed`, `home_front`, `hospital_ward` (beside the bed), `hospital_car`, `school_desk`, `school_car`, `work_desk`, `work_car`. The leaves are the rooms' own hinged
meshes (cafe/shop: a real 1.3 m opening was cut in the front wall + new leaf). Auto-open when the hero is < 1.6 m, close > 3.2 m.
API: `open()`, `close()`, `is_open`, `walk_through(hero)` (awaitable), `auto`.

## API (real, in scripts/core/world.gd; red builds on this)
- `World.inst` / `World.get_world()`; lookups `World.room(id)`, `World.door(id)`, `World.hero_node()`, `region_at(p)`, `World.current_region()`
- signals on the world: `entered(region, from)`, `left(region)`, `active_changed(place, on)`; `last_door` (set by goto)
- `await World.goto(place, door_id = "")`: walk to the near side of the door (straight line), open, through. Chain doors for multi-room paths.
- doors: `open()`, `close()`, `is_open`, `auto` (proximity open/close; set false for scripted doors), `await walk_through(hero)`, `center()`
- hero (WorldPlayer): `await move_to(pos, yaw = INF)` scripted walk; `place_at(id)` (spot / door / place id; sets floor height + yaw)
- `await World.pan(at, secs = 2.6)`: objective pan on the ONE camera, framing hero + target (guide_cam meta, honoured by ShoulderCam)
- `await World.skip_travel(dest_spot)`: car / bus / ambulance only: fade black, place_at, fade in, no card (the ONLY gameplay fade)
- near-only activity: places farther than ACTIVE_R 45 m are hidden; `World.set_live(place)` marks a place running story code: it
  is processed only while active (all places are process-DISABLED until red marks them live)
- `Game.go_to(path)` shim: inside world.tscn old scene paths map to World (rooms/cafe/shop -> goto, street -> goto front,
  hospital/work -> skip_travel to `<place>_car`, child -> school_car). Temporary until red's port drops scene paths.
- fences: `World.fences` node, up while `WorldState.day < 8` (checked every 0.2 s), colliders off on day 8.

## Culling (phase 1, untuned)
small props visibility_range_end 70 m (street) / 30 m (interiors), omni/spot lights off beyond 14 m from hero, no omni shadows,
sun shadow 30 m. Fences (construction barriers at the grid edge until day 8) are built but untuned. Blue: occluders + tuning.

## Ownership
black: world.gd assembly, doors, places layout. red: story port (days 1-7, room scripts, hospital/school flows) onto this API.
blue: camera (shoulder cam), cafe/shop/work interiors and exteriors, wall fade, culling.
