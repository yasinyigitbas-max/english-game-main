# v32 cars: drop-in merge notes

**UNTESTED:** Godot was not run (user's instruction). I checked the syntax by reading the code only. Run the game once before shipping.

## Files
- `scripts/world/car_kit.gd`: NEW. `class_name CarKit` builds the polished vehicle meshes and the blob shadow.
- `scripts/world/vehicle.gd`: only `_build_mesh()` changed. It now uses CarKit for the car and the bus.
- `scripts/world/street_object.gd`: only the mesh part of `_build_car()` changed ("my car" on the home lot).
- `scripts/story/day2_car.gd`: unchanged. It only finds the StreetObject of kind "car".

Copy the three files over the game's files. `mesh_kit.gd` is still used (bus doors), and it is unchanged.

## What did not change
- Public API and vars of Vehicle (`setup`, `set_schedule`, `sync`, `project`, `pos_at`, `fwd`, `lane_loop`, `color`, `is_bus`, `half_len`, `doors`, `board`, `body`, ...). The driving, traffic, timetable, sway and push logic are byte-identical.
- Node names: `Body` (it sways), the bus door nodes (meta `z0`, they slide on Z), the route Label3D, and `parts["door"]` on "my car" (same pivot (-0.93, 0.6, -0.3), swings on rotation:y).
- Colliders: `col(Vector3(1.9, 1.5, 4.3), ...)` and the Interactable placement are unchanged.
- Footprint: car 1.8 x 4.2 m with the roof at about 1.46 m. Bus 2.5 x 11 m with the roof at 3.0 m. `half_len` stays 2.1 and 5.5.

## Added nodes
- `Shadow` (an unshaded alpha PlaneMesh, no shadow casting) on the Vehicle root and on the StreetObject.
- `CarMesh` (MeshInstance3D) under `Body` / StreetObject. It replaces the old unnamed MeshKit mesh.

## Look
- Rounded lower body: a bevelled side profile with a sloped hood and trunk. Tapered greenhouse with dark tinted glass, a painted roof, pillars and chrome belt lines.
- Wheels: tyres, silver 5-spoke rims, chrome hubcaps and dark wheel arches.
- Front: bumpers, grille with a chrome bar, emissive (unshaded) headlights with chrome bezels, and amber indicators.
- Rear: red taillights and reverse lights.
- Sides: mirrors, door seams, chrome handles and side skirts. License plates with an EU strip, front and rear.
- Paint is metallic 0.5 / roughness 0.3. The requested colour snaps to the nearest of 11 realistic paints. Traffic cars alternate between sedan and hatchback, picked from the colour.
- Bus: blue and white livery, window band with pillars, windshield, destination display, roof and AC unit, mirrors on arms, and the same detailing.

## Draw calls
Each vehicle is one mesh with 4 surfaces (paint, matte trim, glass, lights), plus 1 shadow quad. All materials are static and shared. "My car" door: +2. Bus doors: +1 each (MeshKit).
