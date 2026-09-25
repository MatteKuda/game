shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// Polished mall marble: large slabs with soft veins, thin grout and a glossy sheen. World space.
uniform vec3 base_color : source_color = vec3(0.95, 0.92, 0.87);
uniform vec3 vein_color : source_color = vec3(0.62, 0.57, 0.52);
uniform vec3 inlay : source_color = vec3(0.12, 0.54, 0.52);
uniform float tile = 2.0;
uniform float inlay_every = 4.0;
varying vec3 wpos;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p){ float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++){ v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	vec2 p = wpos.xz / tile;
	vec2 id = floor(p);
	vec2 f = fract(p) - 0.5;
	float rot = h21(id) * 6.28;
	vec2 q = mat2(vec2(cos(rot), sin(rot)), vec2(-sin(rot), cos(rot))) * (wpos.xz * 0.7);
	float v = abs(sin(q.x * 2.2 + fbm(q * 1.3 + id) * 5.0));
	float vein = 1.0 - smoothstep(0.0, 0.09, v);
	vec3 col = base_color * (0.96 + h21(id + 4.0) * 0.06);
	col = mix(col, vein_color, vein * 0.45);
	col = mix(col, vein_color, (fbm(wpos.xz * 1.7) - 0.5) * 0.18);
	// accent inlay strip every few slabs
	vec2 big = wpos.xz / (tile * inlay_every);
	vec2 bf = abs(fract(big) - 0.5);
	float band = 1.0 - smoothstep(0.005, 0.012, min(bf.x, bf.y) - 0.0);
	col = mix(col, inlay, band * 0.9);
	float e = max(abs(f.x), abs(f.y));
	float g = smoothstep(0.488, 0.497, e);
	col = mix(col, vein_color * 0.8, g);
	ALBEDO = col;
	ROUGHNESS = mix(0.14, 0.4, g + vein * 0.2);
	SPECULAR = 0.6;
}
