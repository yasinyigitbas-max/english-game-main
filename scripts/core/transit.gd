## Transit (autoload): bus stops, routes, timetable stub, fares, plus the shared RoadNetwork graph.
## Data: res://data/world/transit.json. Stops get their exact world position from BusStop lots when blocks load.
##   Transit.next_departures("stop_home", 3)   Transit.ride("bus_1", "stop_home", "stop_market")
extends Node

signal stop_registered(stop_id: String)
signal ride_started(route_id: String, from_id: String, to_id: String)

const DATA_PATH := "res://data/world/transit.json"
var stops := {}        # id -> {name, name_tr, pos: Vector3, road_node: int}
var routes := {}       # id -> {name, color, fare, stops: [ids], first: "06:00", last: "23:00", headway: 15, leg_minutes: 3}
var roads := RoadNetwork.new()
var tickets := 0       # prepaid rides (future: travel card)

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else {}
	if d is Dictionary:
		for s in d.get("stops", []):
			stops[s.id] = {"name": s.name, "name_tr": s.get("name_tr", ""), "pos": Vector3(s.pos[0], 0, s.pos[1]), "road_node": -1}
		for r in d.get("routes", []): routes[r.id] = r
		var g: Dictionary = d.get("grid", {})
		roads.build_grid(int(g.get("block_size", 40)), Vector2i(g.get("min", [-2, -1])[0], g.get("min", [-2, -1])[1]),
			Vector2i(g.get("max", [2, 1])[0], g.get("max", [2, 1])[1]))
	for id in stops: stops[id].road_node = roads.nearest_node(stops[id].pos)

## called by a BusStop lot when its block loads: exact position from the scene
func register_stop(id: String, pos: Vector3, nm := "") -> void:
	if not stops.has(id): stops[id] = {"name": nm if nm != "" else id, "name_tr": "", "pos": pos, "road_node": -1}
	stops[id].pos = pos; stops[id].road_node = roads.nearest_node(pos); stop_registered.emit(id)

func routes_at(stop_id: String) -> Array:
	return routes.keys().filter(func(r): return stop_id in routes[r].stops)

func _hm(s: String) -> int: var p := s.split(":"); return int(p[0]) * 60 + int(p[1])

## next N departures (minutes since midnight) of every route at a stop: [{route, minute, text}]
func next_departures(stop_id: String, n := 3) -> Array:
	var out := []; var now := int(WorldState.minutes)
	for rid in routes_at(stop_id):
		var r: Dictionary = routes[rid]; var idx: int = r.stops.find(stop_id)
		var off: int = int(r.offsets[idx]) if r.has("offsets") else idx * int(r.get("leg_minutes", 3))
		var t := _hm(r.get("first", "06:00")) + off; var last := _hm(r.get("last", "23:00")) + off
		var k := 0
		var hw: int = int(r.get("headway", 15))
		var dw: int = int(r.get("dwell", 0))      # a bus standing at the stop is still listed
		if t < now - dw: t += int(ceilf(float(now - dw - t) / float(hw))) * hw
		while t <= last and k < n:
			if t >= now - dw: out.append({"route": rid, "minute": t, "text": "%02d:%02d" % [t / 60, t % 60]}); k += 1
			t += int(r.get("headway", 15))
	out.sort_custom(func(a, b): return a.minute < b.minute)
	return out.slice(0, n)

## stub ride: pays the fare, advances the clock, returns the destination position (caller moves the player)
func ride(route_id: String, from_id: String, to_id: String) -> Variant:
	var r: Dictionary = routes.get(route_id, {})
	if r.is_empty() or not (from_id in r.stops and to_id in r.stops): return null
	if tickets > 0: tickets -= 1
	elif not Economy.spend(int(r.get("fare", 150)), "bus " + route_id): return null
	WorldState.minutes += absi(r.stops.find(to_id) - r.stops.find(from_id)) * int(r.get("leg_minutes", 3))
	ride_started.emit(route_id, from_id, to_id)
	return stops[to_id].pos

## road path for a bus between two stops (list of Vector3 along road centre lines)
func route_path(route_id: String) -> PackedVector3Array:
	var pts := PackedVector3Array(); var ids: Array = routes.get(route_id, {}).get("stops", [])
	for i in range(ids.size() - 1):
		pts.append_array(roads.path(stops[ids[i]].pos, stops[ids[i + 1]].pos))
	return pts

func to_dict() -> Dictionary: return {"tickets": tickets}
func from_dict(d: Dictionary) -> void: tickets = int(d.get("tickets", 0))
