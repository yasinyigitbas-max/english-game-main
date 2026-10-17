// bk make-up overlay (black bot). CUSTOM0 = rest-pose head-mesh position (xyz) + w = 1 on skin surfaces.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, depth_prepass_alpha;
uniform float blush : hint_range(0.0, 1.0) = 0.0;
uniform float lip : hint_range(0.0, 1.0) = 0.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 blush_col : source_color = vec3(0.92, 0.42, 0.45);
uniform vec3 lip_col : source_color = vec3(0.72, 0.10, 0.20);
uniform vec3 shadow_col : source_color = vec3(0.55, 0.33, 0.58);
uniform float eye_x = 0.040;
uniform float eye_y = 1.696;
uniform float mouth_y = 1.606;
uniform float cheek_y = 1.655;
uniform float cheek_x = 0.062;
uniform float front_z = 0.11;
varying vec4 rp;
void vertex() { rp = CUSTOM0; }
float blob(vec2 d, vec2 r, float soft) { return 1.0 - smoothstep(1.0 - soft, 1.0, length(d / r)); }
void fragment() {
	if (rp.w < 0.5) discard;
	vec3 p = rp.xyz;
	float front = smoothstep(front_z - 0.02, front_z + 0.01, p.z);
	float ax = abs(p.x);
	float b = blob(vec2(ax - cheek_x, p.y - cheek_y), vec2(0.024, 0.017), 0.8) * blush * 0.55;
	float s = blob(vec2(ax - eye_x, p.y - (eye_y + 0.012)), vec2(0.026, 0.011), 0.6) * shadow * 0.75;
	float l = blob(vec2(p.x, p.y - mouth_y), vec2(0.019, 0.0065), 0.35) * lip * 0.92;
	vec3 c = vec3(0.0); float a = 0.0;
	if (b > 0.0) { c = blush_col; a = b; }
	if (s > a) { c = mix(c, shadow_col, s); a = max(a, s); }
	if (l > 0.02) { c = mix(c, lip_col, clamp(l * 1.2, 0.0, 1.0)); a = max(a, l); }
	a *= front;
	if (a < 0.003) discard;
	ALBEDO = c; ALPHA = a; ROUGHNESS = 0.7;
}
