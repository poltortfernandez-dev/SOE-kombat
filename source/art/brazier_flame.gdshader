shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float phase = 0.0;

float hash(vec2 p) {
	vec3 v = fract(vec3(p.xyx) * 0.1031);
	v += dot(v, v.yzx + 33.33);
	return fract((v.x + v.y) * v.z);
}
float noise_value(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),u.x),u.y);
}
float plume(vec2 p, float t, float seed) {
	float y = p.y;
	vec2 advect = vec2(p.x * 4.4 + seed, y * 2.9 - t);
	float curl = noise_value(advect);
	float ripple = noise_value(advect * 2.25 + vec2(curl * 2.4,-t * .34));
	float fine = noise_value(vec2(p.x*21.+ripple*2.,y*6.3-t*2.1+seed));
	float width = (1.-y)*.58+.025;
	float sway = (curl-.50)*(.32+.49*y);
	float d = abs(p.x - sway) / max(.02,width);
	return clamp(1.-d + (ripple-.49)*1.25 + (fine-.5)*.32 - .33*y,0.,1.);
}

void fragment() {
	float t = TIME * 1.35 + phase;
	vec2 p = vec2((UV.x - .5)*2.,1.-UV.y);
	float y = p.y;
	float layer = plume(p,t,phase);
	float back = plume(vec2(p.x*1.13+.13,y*1.06),t*.84,16.2);
	float grain = noise_value(vec2(p.x*9.2 + 11.,y*7.5-t*2.));
	float height_fade = (1.-smoothstep(.77,.99,y)) * smoothstep(.005,.09,y);
	float alpha = (.70*smoothstep(.015,.26,layer)+.23*smoothstep(.03,.46,back))*height_fade;
	float hot = layer*(.57+.48*grain)*(1.-.22*y);
	vec3 amber = mix(vec3(.55,.12,.035),vec3(1.,.45,.10),smoothstep(.03,.45,hot));
	amber = mix(amber,vec3(1.,.89,.52),smoothstep(.45,.92,hot));
	float halo = exp(-6.*p.x*p.x - 4.2*y*y)*(.115+.045*grain)*smoothstep(0.,.14,y);
	ALBEDO = mix(vec3(.97,.23,.055),amber,smoothstep(.03,.30,alpha));
	ALPHA = max(halo,alpha);
}
