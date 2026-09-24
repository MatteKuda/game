shader_type spatial;
render_mode diffuse_lambert_wrap;
uniform vec3 color : source_color = vec3(0.29, 0.31, 0.35);
varying vec3 wpos;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h21(i), h21(i+vec2(1,0)), f.x), mix(h21(i+vec2(0,1)), h21(i+vec2(1,1)), f.x), f.y); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float n = vn(wpos.xz * 1.3) * 0.5 + vn(wpos.xz * 6.0) * 0.3 + h21(floor(wpos.xz * 40.0)) * 0.2;
	ALBEDO = color * (0.86 + n * 0.22);
	ROUGHNESS = 0.95;
}
