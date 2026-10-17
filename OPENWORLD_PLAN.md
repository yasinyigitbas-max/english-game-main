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
The street lots `home`, `cafe`, `corner_shop` lose their solid building box/collider/fake door; the interior stands there.
House rooms are instanced with the House.SHELL meta (geometry + furniture), place scenes with `ow_shell` (build()+_room()).
All rooms/places run with process DISABLED in phase 1 (no story yet; NPCs hold pose). Rooms get colliders from their
thin tall wall boxes + `obstacles` rects. Region = room AABB (cafe/shop: floor rect), else "street".

## Doors (World.doors, class World.WorldDoor)
ids: `bed_bath`, `bed_living`, `bath_living`, `front` (house -> street), `cafe`, `shop`. The leaves are the rooms' own hinged
meshes (cafe/shop: a real 1.3 m opening was cut in the front wall + new leaf). Auto-open when the hero is < 1.6 m, close > 3.2 m.
API: `open()`, `close()`, `is_open`, `walk_through(hero)` (awaitable), `auto`.

## API (minimal, for red)
- `World.get_world()`, `World.room(id)`, `World.door(id)`, `World.hero_node()`, `World.region_at(p)`, signals `entered(region, from)`, `left(region)`, `last_door`
- `World.goto(place, door_id)` (walk through the door, no load), `World.spot(id)` (door / spot / place centre)
- `hero.move_to(pos, yaw)` (awaitable scripted walk), `hero.place_at(id)`
- `World.pan(at, secs)` objective pan (guide_cam temp camera -> ShoulderCam frames hero + target)
- `World.skip_travel(dest)`: car / bus / ambulance only: fade black, place_at(dest), fade in (the ONLY gameplay fade, Yasin 18:12)
- TODO phase 2: Game.go_to shim -> World.goto; hospital/school/work regions (RESERVED slots + SPOTS ids hospital_ward, school_desk, work_desk, home car spot)

## Culling (phase 1, untuned)
small props visibility_range_end 70 m (street) / 30 m (interiors), omni/spot lights off beyond 14 m from hero, no omni shadows,
sun shadow 30 m. Fences (construction barriers at the grid edge until day 8) are built but untuned. Blue: occluders + tuning.

## Ownership
black: world.gd assembly, doors, places layout. red: story port (days 1-7, room scripts, hospital/school flows) onto this API.
blue: camera (shoulder cam), cafe/shop/work interiors and exteriors, wall fade, culling.
