shader_type spatial;
render_mode diffuse_lambert_wrap;
// Rolling metal shutter of a vacant unit: horizontal slats in world space.
uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.83);
varying vec3 wpos;
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float s = fract(wpos.y * 9.0);
	float shade = mix(1.0, 0.62, smoothstep(0.35, 1.0, s));
	ALBEDO = tint * shade;
	METALLIC = 0.45;
	ROUGHNESS = 0.4;
}
