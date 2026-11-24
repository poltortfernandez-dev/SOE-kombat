shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float weight;
uniform float impact_y;
uniform float severity;
void vertex() {
	float y = 1.-UV.y;
	float planted = smoothstep(.10,.63,y);
	float ribs = exp(-pow((y-impact_y)*4.,2.));
	VERTEX.x -= weight*severity*(.12*planted+.08*ribs);
	VERTEX.y -= weight*severity*.07*ribs;
}
void fragment() {
	vec2 texel=1./vec2(textureSize(sheet,0));
	vec2 atlas=clamp((UV+vec2(2.,1.))/vec2(3.,2.),vec2(2./3.,.5)+texel,vec2(1.)-texel);
	vec4 ink=texture(sheet,atlas);
	ALBEDO=ink.rgb;
	ALPHA=ink.a*weight;
}
