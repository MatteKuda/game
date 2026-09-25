shader_type spatial;
render_mode diffuse_lambert_wrap;
// Escalator steps: ribbed aluminium treads with yellow safety edges, scrolling along UV.x.
uniform float offset = 0.0;
uniform float steps = 14.0;
void fragment(){
	float s = fract(UV.x * steps - offset);
	float rib = step(0.5, fract(UV.y * 22.0));
	vec3 col = mix(vec3(0.46, 0.49, 0.54), vec3(0.62, 0.65, 0.7), rib);
	col *= mix(0.55, 1.0, smoothstep(0.0, 0.08, s));
	float edge = step(UV.y, 0.07) + step(0.93, UV.y) + step(0.9, s);
	col = mix(col, vec3(0.95, 0.7, 0.24), clamp(edge, 0.0, 1.0));
	ALBEDO = col;
	METALLIC = 0.4;
	ROUGHNESS = 0.45;
}
