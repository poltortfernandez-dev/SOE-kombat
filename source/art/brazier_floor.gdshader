shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float phase;
void fragment() {
	vec2 p = vec2((UV.x-.50)*2.,UV.y);
	float y = p.y;
	float f = sin(y*166. + 3.4*sin(y*41.+phase))*.5+.5;
	float width = .24+.21*y;
	float radial = exp(-p.x*p.x/(width*width)-3.0*y);
	float pulse = .85+.15*sin(TIME*4.+phase);
	ALBEDO = vec3(.84,.28,.05);
	ALPHA = (.07+.24*pow(f,3.))*radial*pulse*smoothstep(.0,.18,y)*(1.-smoothstep(.78,1.,y));
}
