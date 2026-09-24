shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec3 brick : source_color = vec3(0.72, 0.36, 0.26);
uniform vec3 mortar : source_color = vec3(0.86, 0.8, 0.72);
varying vec3 wpos;
varying vec3 wnorm;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment(){
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	vec2 t = vec2(u / 0.24, wpos.y / 0.085);
	t.x += mod(floor(t.y), 2.0) * 0.5;
	vec2 f = abs(fract(t) - 0.5);
	float m = smoothstep(0.4, 0.5, max(f.x * 0.9, f.y));
	vec3 col = brick * (0.82 + h21(floor(t)) * 0.3);
	ALBEDO = mix(col, mortar, m);
	ROUGHNESS = 0.92;
}
