shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled, skip_vertex_transform;
// 対戦の盤の空（stage_look.gd）。カメラを中心にした球の内側に描く（カメラが動いても、空は付いてくる）。絵は使わない。
// 地平は霞の色（horizon。霞と同じ色にして、遠くの地面とつなぐ）、高いほど空の色（zenith）。
// 日のある側の地平を明るくし、たなびく雲を薄く重ねる。

uniform vec3 zenith : source_color = vec3(0.35, 0.55, 0.85);
uniform vec3 horizon : source_color = vec3(0.70, 0.80, 0.86);
uniform vec3 sun_color : source_color = vec3(1.0);
// 日の向き（日のあるほうを指す、長さ 1 の向き）。
uniform vec3 sun_direction = vec3(0.0, 0.6, -0.8);

varying vec3 dir;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	dir = VERTEX;
	// 向きだけを写す（位置は写さない）。球はいつもカメラを囲む。
	VERTEX = mat3(VIEW_MATRIX) * VERTEX;
	NORMAL = mat3(VIEW_MATRIX) * NORMAL;
}

void fragment() {
	vec3 d = normalize(dir);
	float up = clamp(d.y, 0.0, 1.0);
	vec3 color = mix(horizon, zenith, pow(up, 0.55));
	// 日のある側は、地平が明るい。
	float toward = max(dot(normalize(vec3(d.x, 0.0, d.z) + vec3(0.0001)), normalize(vec3(sun_direction.x, 0.0, sun_direction.z) + vec3(0.0001))), 0.0);
	color += sun_color * 0.16 * pow(toward, 3.0) * pow(1.0 - up, 4.0);
	// たなびく雲（低い空に、横長に）。
	vec2 at = vec2(atan(d.x, d.z) * 3.0 + TIME * 0.003, up * 16.0);
	float cloud = 0.6 * noise(at) + 0.3 * noise(at * 2.1 + 7.3) + 0.1 * noise(at * 4.3 + 1.9);
	float cover = smoothstep(0.52, 0.78, cloud) * smoothstep(0.02, 0.12, up) * smoothstep(0.7, 0.2, up);
	color = mix(color, mix(horizon, vec3(1.0), 0.45) + sun_color * 0.08 * toward, cover * 0.5);
	ALBEDO = color;
}
