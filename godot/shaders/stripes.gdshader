shader_type spatial;
render_mode diffuse_lambert_wrap, cull_disabled;
// Striped awning fabric (stripes along UV.x) with a slightly darker underside.
uniform vec3 color_a : source_color = vec3(0.88, 0.4, 0.24);
uniform vec3 color_b : source_color = vec3(1.0, 0.95, 0.86);
uniform float count = 8.0;
void fragment(){
	float s = step(0.5, fract(UV.x * count));
	vec3 col = mix(color_a, color_b, s);
	if (!FRONT_FACING) col *= 0.72;
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
