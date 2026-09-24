shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Warm terrazzo floor with chips, drawn in world space so every tile lines up.
uniform vec3 base_color : source_color = vec3(0.93, 0.87, 0.78);
uniform vec3 chip_a : source_color = vec3(0.88, 0.45, 0.3);
uniform vec3 chip_b : source_color = vec3(0.2, 0.55, 0.52);
uniform vec3 chip_c : source_color = vec3(0.35, 0.33, 0.35);
uniform float tile = 1.0;
varying vec3 wpos;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 h22(vec2 p){ return vec2(h21(p), h21(p + 17.3)); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 uv = wpos.xz * 9.0;
	vec3 col = base_color;
	vec2 cell = floor(uv);
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 c = cell + vec2(float(i), float(j));
		vec2 o = h22(c);
		float r = 0.05 + 0.1 * h21(c + 3.1);
		float d = length(uv - c - o);
		float k = h21(c + 9.7);
		vec3 cc = k < 0.33 ? chip_a : (k < 0.66 ? chip_b : chip_c);
		if (h21(c + 1.3) < 0.22) col = mix(col, mix(cc, base_color, 0.25), smoothstep(r, r - 0.03, d));
	}
	// grout lines of the big tiles
	vec2 g = abs(fract(wpos.xz / tile) - 0.5);
	float grout = smoothstep(0.495, 0.5, max(g.x, g.y));
	col = mix(col, col * 0.82, grout);
	ALBEDO = col;
	ROUGHNESS = 0.42;
	SPECULAR = 0.35;
}
