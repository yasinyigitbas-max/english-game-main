## v28 blue: a hand towel held in the hand. 50x90 cm towel folded in half lengthwise (25 cm wide) and draped over the hand,
## so it hangs ~40 cm on both sides. A segmented cloth strip (SurfaceTool), always hanging in world down, swaying with a vertex
## shader that is kicked by the hand's movement. Terry look: a procedural noise normal map (CC0, made in code). No external assets.
extends Node3D

const W := 0.25        # folded width
const HANG := 0.40     # hanging length on each side
const R := 0.035       # radius over the hand
const SEG_L := 28
const SEG_W := 6
var colour := Color(0.40, 0.56, 0.76)
var _mat: ShaderMaterial
var _last := Vector3.ZERO
var _swing := Vector2.ZERO
var _vel := Vector2.ZERO

const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color;
uniform sampler2D terry : hint_normal;
uniform vec2 swing = vec2(0.0);
uniform float hang = 0.4;
void vertex() {
	float d = clamp(-VERTEX.y / hang, 0.0, 1.0);
	float k = d * d;
	VERTEX.x += swing.x * k * 0.12 + sin(TIME * 1.7 + VERTEX.y * 6.0) * 0.004 * k;
	VERTEX.z += swing.y * k * 0.12 + sin(TIME * 1.3 + VERTEX.x * 9.0) * 0.006 * k;
}
void fragment() {
	float band = step(0.93, UV.y) + step(UV.y, 0.07);
	vec3 c = mix(albedo.rgb, albedo.rgb * 0.8 + vec3(0.15), clamp(band, 0.0, 1.0));
	ALBEDO = c * (0.94 + 0.06 * texture(terry, UV * vec2(3.0, 9.0)).r);
	NORMAL_MAP = texture(terry, UV * vec2(3.0, 9.0)).rgb;
	NORMAL_MAP_DEPTH = 1.6;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
"""

func _ready() -> void:
	var mi := MeshInstance3D.new(); mi.mesh = _build(); add_child(mi)
	var tex := NoiseTexture2D.new(); tex.width = 256; tex.height = 256; tex.seamless = true; tex.as_normal_map = true; tex.bump_strength = 6.0
	var fn := FastNoiseLite.new(); fn.noise_type = FastNoiseLite.TYPE_CELLULAR; fn.frequency = 0.09; tex.noise = fn
	var sh := Shader.new(); sh.code = SHADER
	_mat = ShaderMaterial.new(); _mat.shader = sh
	_mat.set_shader_parameter("albedo", colour); _mat.set_shader_parameter("terry", tex); _mat.set_shader_parameter("hang", HANG)
	mi.material_override = _mat
	_last = global_position

## the strip's centre line: down the front, over the hand (half circle), down the back
func _path(u: float) -> Vector3:
	var arc := PI * R
	var total := HANG * 2.0 + arc
	var s := u * total
	if s < HANG: return Vector3(0, -(HANG - s), R)
	s -= HANG
	if s < arc:
		var a := s / R
		return Vector3(0, sin(a) * R * 0.6, cos(a) * R)
	s -= arc
	return Vector3(0, -s, -R - s * 0.06)   # the back side falls a little away from the front

func _build() -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEG_L:
		for j in SEG_W:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for v in q:
				var u: float = float(v[0]) / SEG_L; var w: float = float(v[1]) / SEG_W
				var p := _path(u)
				var x := (w - 0.5) * W
				p.x = x
				p.z += sin(w * PI) * 0.006 * (1.0 if p.z > 0 else -1.0)   # soft bulge across the width
				st.set_uv(Vector2(w, u)); st.add_vertex(p)
	st.generate_normals(); st.generate_tangents()
	return st.commit()

func _process(dt: float) -> void:
	# hang in world down, keep the yaw of the hand
	# v29 review: read the yaw from the parent (hand bone) - reading our own basis fed back the last frame and froze the yaw
	var pb: Basis = (get_parent() as Node3D).global_transform.basis if get_parent() is Node3D else global_transform.basis
	var f := pb.x; f.y = 0
	if f.length() < 0.01: f = Vector3.RIGHT
	global_transform.basis = Basis(f.normalized(), Vector3.UP, f.normalized().cross(Vector3.UP)).orthonormalized()
	# swing: a damped spring driven by the hand's acceleration
	var v := (global_position - _last) / maxf(dt, 0.001); _last = global_position
	var lv := Vector2(global_transform.basis.x.dot(v), global_transform.basis.z.dot(v))
	_vel += (-_swing * 40.0 - _vel * 5.0 - lv * 2.5) * dt
	_swing += _vel * dt; _swing = _swing.limit_length(1.2)
	_mat.set_shader_parameter("swing", _swing)
