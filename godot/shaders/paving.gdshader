shader_type spatial;
render_mode diffuse_lambert_wrap;
// Kilit parke (interlocking pavers) in two warm tones.
uniform vec3 color_a : source_color = vec3(0.86, 0.8, 0.72);
uniform vec3 color_b : source_color = vec3(0.78, 0.71, 0.63);
uniform float scale = 3.0;
varying vec3 wpos;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wpos.xz * scale;
	vec2 b = vec2(p.x * 0.5, p.y);
	b.x += mod(floor(b.y), 2.0) * 0.5;
	vec2 id = floor(b);
	vec2 f = abs(fract(b) - 0.5);
	float edge = smoothstep(0.42, 0.5, max(f.x, f.y * 0.5 + 0.25 * 0.0 + f.y * 0.5));
	vec3 col = mix(color_a, color_b, step(0.6, h21(id)));
	col *= 0.93 + h21(id + 4.2) * 0.1;
	col = mix(col, col * 0.7, edge);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
