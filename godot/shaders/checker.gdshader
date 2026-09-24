shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Glazed checkerboard shop tiles with bevelled grout, slight per-tile tone and sheen.
uniform vec3 color_a : source_color = vec3(0.93, 0.86, 0.72);
uniform vec3 color_b : source_color = vec3(0.78, 0.36, 0.22);
uniform vec3 grout : source_color = vec3(0.45, 0.38, 0.33);
uniform float tile = 0.5;
varying vec3 wpos;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wpos.xz / tile;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float checker = mod(id.x + id.y, 2.0);
	vec3 col = mix(color_a, color_b, checker);
	col *= 0.94 + h21(id) * 0.1;
	float e = max(abs(f.x), abs(f.y));
	float g = smoothstep(0.455, 0.49, e);
	float bevel = smoothstep(0.38, 0.455, e) * (1.0 - g);
	col = mix(col, col * 0.86, bevel);
	col = mix(col, grout, g);
	ALBEDO = col;
	ROUGHNESS = mix(0.22, 0.9, g);
	SPECULAR = 0.55;
}
