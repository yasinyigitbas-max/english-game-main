## Footsteps: bedroom-identical step sounds (3dv2 main.gd: Audio.sfx("footstep0N", -10 dB, pitch 0.9..1.1) once per
## foot contact = twice per walk/run cycle, Master bus). Surface "grass" uses footstep_grass0N (same level).
## NPC steps: only within NPC_RANGE of the listener, at most NPC_MAX at once and NPC_GAP s apart (hard cap).
class_name Footsteps
extends RefCounted

const DB := -10.0
const NPC_RANGE := 5.0
const NPC_MAX := 2
const NPC_GAP := 0.3
static var _cache := {}
static var _pool: Array = []
static var _npc_pool: Array = []
static var _npc_last := -10.0
static var log_times: Array = []        # player step timestamps (QA step-rate check)
static var npc_count := 0

static func _stream(surface: String) -> AudioStream:
	var k := "%s%d" % [surface, randi() % 4]
	if not _cache.has(k):   # house.24: grass (soft), tarmac (medium), else the house/pave set
		var nm: String = {"grass": "footstep_grass", "tarmac": "footstep_tarmac", "road": "footstep_tarmac"}.get(surface, "footstep")
		_cache[k] = load("res://sfx/%s0%d.ogg" % [nm, int(k.right(1))])
	return _cache[k]

## per-character phase tracker: call every frame with the AnimationPlayer; returns true on a foot contact
static func contact(ap: AnimationPlayer, length: float, state: Dictionary) -> bool:
	if ap == null or not ap.current_animation in ["walk", "run"] or length <= 0.0: state["ph"] = 1.0; return false
	if ap.get_playing_speed() <= 0.0: state["ph"] = 1.0; return false   # house.18: reversed / frozen walk = no steps
	var ph: float = fmod(ap.current_animation_position / length * 2.0, 1.0)
	var hit: bool = ph < float(state.get("ph", 1.0))
	state["ph"] = ph
	return hit

static func player_step(host: Node, surface: String) -> void:
	if _pool.is_empty():
		for i in 4: var p := AudioStreamPlayer.new(); host.get_tree().root.add_child.call_deferred(p); _pool.append(p)
		return
	var pl: AudioStreamPlayer = _pool.pop_front(); _pool.append(pl)
	if not pl.is_inside_tree(): return
	pl.stream = _stream(surface); pl.volume_db = DB + {"grass": 1.0, "tarmac": 2.5, "road": 2.5}.get(surface, 0.0); pl.pitch_scale = randf_range(0.9, 1.1); pl.play()   # v29 review: measured sample loudness -> same level on every surface
	log_times.append(Time.get_ticks_msec() / 1000.0)
	if log_times.size() > 200: log_times.pop_front()

static func npc_step(host: Node3D, listener: Vector3, surface := "pave") -> void:
	if host.global_position.distance_to(listener) > NPC_RANGE: return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _npc_last < NPC_GAP: return
	var playing := 0
	for p in _npc_pool: if is_instance_valid(p) and p.playing: playing += 1
	if playing >= NPC_MAX: return
	if _npc_pool.size() < NPC_MAX:
		var np := AudioStreamPlayer3D.new(); np.unit_size = 3.0; np.max_distance = NPC_RANGE + 1.0
		host.get_tree().root.add_child(np); _npc_pool.append(np)
	var pl: AudioStreamPlayer3D = null
	for p in _npc_pool: if is_instance_valid(p) and not p.playing: pl = p; break
	if pl == null: return
	pl.global_position = host.global_position; pl.stream = _stream(surface); pl.volume_db = DB; pl.pitch_scale = randf_range(0.9, 1.1); pl.play()
	_npc_last = now; npc_count += 1

## steps per second over the last `window` seconds
static func rate(window := 4.0) -> float:
	var now := Time.get_ticks_msec() / 1000.0; var n := 0
	for t in log_times: if now - t <= window: n += 1
	return n / window

static func clear() -> void:
	_cache.clear()
	for p in _pool + _npc_pool: if is_instance_valid(p): p.queue_free()
	_pool.clear(); _npc_pool.clear()
