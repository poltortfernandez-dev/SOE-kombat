shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform bool droplets = false;
void fragment() {
	vec2 p = UV * 2. - 1.;
	float radius = dot(p,p);
	float edge = 1.0-smoothstep(.42,1.0,radius);
	float wet = 0.0;
	ALBEDO = COLOR.rgb + vec3(wet,wet*.65,wet*.57);
	ALPHA = COLOR.a * edge;
}
