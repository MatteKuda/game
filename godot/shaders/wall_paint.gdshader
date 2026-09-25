shader_type spatial;
render_mode diffuse_lambert_wrap;
// Interior wall: saturated paint above, vertical wood wainscot below, chunky skirting.
uniform vec3 paint : source_color = vec3(0.24, 0.62, 0.6);
uniform vec3 wood : source_color = vec3(0.5, 0.29, 0.17);
uniform vec3 rail : source_color = vec3(0.96, 0.9, 0.78);
uniform vec3 skirt : source_color = vec3(0.2, 0.15, 0.13);
uniform float wainscot = 1.1;
uniform float base_y = 0.0;
varying vec3 wpos;
varying vec3 wnorm;
float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex(){ wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment(){
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	float y = wpos.y - base_y;
	vec3 col = paint * (0.96 + 0.04 * sin(u * 0.7 + y));
	float rough = 0.85;
	if (y < wainscot) {
		float plank = floor(u / 0.18);
		float fu = fract(u / 0.18);
		col = wood * (0.85 + h21(vec2(plank, 1.0)) * 0.25);
		col *= 0.92 + 0.08 * sin(y * 40.0 + plank * 3.0);
		col = mix(col, wood * 0.55, smoothstep(0.9, 1.0, fu));
		rough = 0.6;
	}
	if (y > wainscot && y < wainscot + 0.07) { col = rail; rough = 0.4; }
	if (y < 0.16) { col = skirt; rough = 0.5; }
	ALBEDO = col;
	ROUGHNESS = rough;
}
