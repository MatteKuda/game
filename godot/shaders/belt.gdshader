shader_type spatial;
render_mode diffuse_lambert_wrap;
// Checkout conveyor: dark rubber with ribs that scroll while a customer pays.
uniform float offset = 0.0;
void fragment(){
	float r = fract(UV.x * 18.0 + offset * 6.0);
	float rib = smoothstep(0.0, 0.08, r) * (1.0 - smoothstep(0.12, 0.2, r));
	ALBEDO = mix(vec3(0.09, 0.1, 0.12), vec3(0.2, 0.22, 0.25), rib);
	ROUGHNESS = 0.7;
}
