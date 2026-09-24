shader_type spatial;
render_mode diffuse_lambert_wrap;
// Metro tiles on the lower wall, painted plaster above; uses world position.
uniform vec3 tile_color : source_color = vec3(0.97, 0.95, 0.9);
uniform vec3 paint_color : source_color = vec3(0.99, 0.93, 0.82);
uniform vec3 trim_color : source_color = vec3(0.12, 0.54, 0.52);
uniform float tile_height = 1.3;
varying vec3 wpos;
varying vec3 wnorm;
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment(){
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	float y = wpos.y;
	vec3 col = paint_color;
	if (y < tile_height) {
		vec2 t = vec2(u / 0.3, y / 0.15);
		t.x += mod(floor(t.y), 2.0) * 0.5;
		vec2 f = abs(fract(t) - 0.5);
		float grout = smoothstep(0.44, 0.5, max(f.x * 0.5 / 0.5, f.y));
		col = mix(tile_color, tile_color * 0.8, grout);
	}
	float trim = step(tile_height, y) * step(y, tile_height + 0.08);
	col = mix(col, trim_color, trim);
	ALBEDO = col;
	ROUGHNESS = y < tile_height ? 0.25 : 0.85;
	SPECULAR = y < tile_height ? 0.6 : 0.2;
}
