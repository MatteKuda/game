shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;
// KayKit palette-atlas bodies re-dressed in our own palette.
// The atlas is 8x4 flat colour cells; each cell gets a role and is re-tinted while keeping its gradient.
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform int roles[32];
uniform float cell_lum[32];
uniform vec3 c_skin : source_color = vec3(0.95, 0.78, 0.65);
uniform vec3 c_hair : source_color = vec3(0.2, 0.13, 0.09);
uniform vec3 c_top : source_color = vec3(0.9, 0.4, 0.3);
uniform vec3 c_top2 : source_color = vec3(0.7, 0.3, 0.2);
uniform vec3 c_bottom : source_color = vec3(0.2, 0.25, 0.4);
uniform vec3 c_shoes : source_color = vec3(0.2, 0.2, 0.22);
uniform vec3 c_accent : source_color = vec3(0.95, 0.7, 0.2);
uniform float flash = 0.0;
void fragment() {
	vec3 src = texture(tex, UV).rgb;
	ivec2 cell = ivec2(clamp(floor(UV * vec2(8.0, 4.0)), vec2(0.0), vec2(7.0, 3.0)));
	int i = cell.y * 8 + cell.x;
	int r = roles[i];
	vec3 col = src;
	if (r > 0) {
		vec3 t = r == 1 ? c_skin : r == 2 ? c_hair : r == 3 ? c_top : r == 4 ? c_top2 : r == 5 ? c_bottom : r == 6 ? c_shoes : c_accent;
		float l = dot(src, vec3(0.299, 0.587, 0.114));
		float k = clamp(l / max(cell_lum[i], 0.02), 0.55, 1.35);
		col = t * mix(1.0, k, 0.8);
	}
	ALBEDO = mix(col, vec3(1.0, 0.95, 0.7), flash);
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
}
