extends Node
## house.29: phone "My Family" portraits rendered from each member's real 3D look (CharacterHook.make_family_member).
## Offscreen SubViewport like polaroid_renderer.gd. Cached in memory + user://portraits/<look hash>.png,
## so a member is only re-rendered when its look changes (the hash covers every look field).
const DIR := "user://portraits"
const KEYS := ["role", "pron", "skin", "hcol", "cloth", "hair", "child"]
static var mem := {}
var queue: Array = []   # [key, member, callback]
var busy := false

static func key_of(m: Dictionary) -> String:
	var parts := []
	for k in KEYS: parts.append(str(m.get(k, "")))
	return "|".join(parts).md5_text().substr(0, 16)

## cached texture or null (then call request())
static func cached(m: Dictionary) -> Texture2D:
	var k := key_of(m)
	if mem.has(k): return mem[k]
	var p := DIR + "/%s.png" % k
	if FileAccess.file_exists(p):
		var img := Image.load_from_file(p)
		if img: mem[k] = ImageTexture.create_from_image(img); return mem[k]
	return null

func request(m: Dictionary, cb: Callable) -> void:
	queue.append([key_of(m), m.duplicate(), cb])
	if not busy: _run()

func _run() -> void:
	busy = true
	while not queue.is_empty():
		var job: Array = queue.pop_front()
		if not mem.has(job[0]): await _render(job[0], job[1])
		if mem.has(job[0]) and job[2].is_valid(): job[2].call(mem[job[0]])
	busy = false

func _render(k: String, m: Dictionary) -> void:
	var vp := SubViewport.new(); vp.size = Vector2i(256, 256); vp.own_world_3d = true; vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(vp)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.6
	env.environment = e; vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-25, 25, 0); sun.light_energy = 1.1; vp.add_child(sun)
	var ch := CharacterHook.make_family_member(m)
	if ch == null: vp.queue_free(); return
	vp.add_child(ch)
	for i in 3: await get_tree().process_frame
	if ch.has_method("play"): ch.play("idle", 0.0)
	for i in 3: await get_tree().process_frame
	var head := Vector3(0, 1.6, 0)
	if ch.skeleton and ch.skeleton.find_bone("Head") >= 0:
		head = ch.skeleton.global_transform * ch.skeleton.get_bone_global_pose(ch.skeleton.find_bone("Head")).origin
	var cam := Camera3D.new(); cam.fov = 30.0; vp.add_child(cam)
	var dist := 1.15 if m.get("child", false) else 1.35
	var aim := head + Vector3(0, 0.02, 0)
	cam.look_at_from_position(aim + Vector3(0, 0.05, dist), aim + Vector3(0, -0.06, 0))
	cam.current = true
	for i in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img:
		DirAccess.make_dir_recursive_absolute(DIR); img.save_png(DIR + "/%s.png" % k)
		mem[k] = ImageTexture.create_from_image(img)
	vp.queue_free()
