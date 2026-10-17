## RoadNetwork: graph of road nodes (intersections / waypoints) and edges (road segments with lanes + speed).
## Built from the block grid (roads run along block edges); extra nodes/edges can be added from data.
## Future buses and cars ask path(from, to) and follow the returned points, keeping right by `lane_offset`.
class_name RoadNetwork
extends RefCounted

var nodes: Array[Vector3] = []
var edges: Array = []                 # [{a, b, lanes, speed, kind}]
var astar := AStar3D.new()
var block_size := 40
var _index := {}                      # Vector2i grid corner -> node id
const LANE_OFFSET := 2.0              # metres from centre line to lane centre (8 m road, 2 lanes)

func add_node(p: Vector3) -> int:
	var id := nodes.size(); nodes.append(p); astar.add_point(id, p); return id

func add_edge(a: int, b: int, lanes := 2, speed := 8.0, kind := "street") -> void:
	edges.append({"a": a, "b": b, "lanes": lanes, "speed": speed, "kind": kind}); astar.connect_points(a, b, true)

## grid roads: centre lines on block edges x = i*S + S/2, z = j*S + S/2, for blocks min..max (inclusive)
func build_grid(size: int, mn: Vector2i, mx: Vector2i) -> void:
	block_size = size
	var h := size * 0.5
	for j in range(mn.y - 1, mx.y + 1):
		for i in range(mn.x - 1, mx.x + 1):
			_index[Vector2i(i, j)] = add_node(Vector3(i * size + h, 0, j * size + h))
	for c in _index:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if _index.has(c + d): add_edge(_index[c], _index[c + d])

func nearest_node(p: Vector3) -> int:
	return astar.get_closest_point(p) if nodes.size() > 0 else -1

## nearest point on any edge (for snapping stops / spawning cars)
func nearest_on_road(p: Vector3) -> Vector3:
	var best := Vector3.ZERO; var bd := INF
	for e in edges:
		var q := Geometry3D.get_closest_point_to_segment(p, nodes[e.a], nodes[e.b])
		if q.distance_squared_to(p) < bd: bd = q.distance_squared_to(p); best = q
	return best

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_node(from); var b := nearest_node(to)
	if a < 0 or b < 0: return PackedVector3Array()
	return astar.get_point_path(a, b)

func to_dict() -> Dictionary:
	var n := []; for p in nodes: n.append([p.x, p.z])
	return {"nodes": n, "edges": edges}
