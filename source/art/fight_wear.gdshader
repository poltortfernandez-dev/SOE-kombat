shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cells = vec2(1.0);
uniform vec2 cheek = vec2(0.45, 0.125);
uniform float wear : hint_range(0.0, 1.0);
uniform float seed_offset;
uniform int textile;
uniform vec4 thread : source_color = vec4(0.71,0.54,0.28,1.0);

float grain(vec2 p) {
	vec2 tile = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float n = dot(tile, vec2(37.0, 179.0));
	vec4 h = fract(sin(n + vec4(0.0,37.0,179.0,216.0))*1834.341);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment() {
	vec4 base = texture(skin,UV);
	vec2 st = fract(UV*cells);
	vec2 p = st + vec2(seed_offset,0.0);
	float dust = grain(p*94.0) * 0.38 + grain(p*287.0)*0.62;
	vec2 c = (st-cheek)/vec2(0.068,0.037);
	float cheekbone = 1.0-smoothstep(0.25,1.0,length(c));
	float jacket = (1.0-smoothstep(0.05,0.27,distance(st,vec2(0.42,0.52))))*0.48;
	float stain = smoothstep(0.42,0.82,dust)*max(cheekbone,jacket);
	// Woven sleeve panels follow the same UVs as the deforming fabric.
	vec2 panel = (st-vec2(.337,.307))/vec2(.081,.095);
	float sleeve = 1.0-smoothstep(.65,1.,length(panel));
	vec2 loom = vec2(st.x*59.0,st.y*67.0);
	float weave = 0.0;
	if (textile == 1) {
		weave = abs(fract(loom.x+loom.y)-.5);
	} else if (textile == 2) {
		weave = abs(length(fract(loom*.52)-.5)-.42);
	} else {
		weave = min(abs(fract(loom.x+loom.y)-.5),abs(fract(loom.x-loom.y)-.5));
	}
	float stitch = (1.-smoothstep(.035,.14,weave))*sleeve*.35;
	float dirt = wear*stain*.81;
	vec3 soil = mix(vec3(.17,.085,.04),vec3(.25,.065,.028),cheekbone);
	ALBEDO = mix(thread.rgb*mix(.36,1.,base.r),soil,dirt/max(.001,stitch+dirt));
	ALPHA = base.a * clamp(stitch+dirt,0.,1.);
}
