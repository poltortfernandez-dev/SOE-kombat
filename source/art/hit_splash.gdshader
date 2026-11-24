shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float age = 1.;
uniform float direction = 1.;
uniform float strength = 1.;

void fragment() {
	vec2 p = (UV-vec2(.5))*vec2(1.8,1.2);
	p.x *= direction;
	float ink = 0.;
	for (int i=0;i<9;i++) {
		float n = float(i);
		float speed = 1.1 + fract(n*.618)*1.5;
		vec2 velocity = vec2(speed, -.4-fract(n*.371)*1.4);
		vec2 center = velocity*age + vec2(0.,2.8*age*age);
		float radius = (.020+fract(n*.731)*.021)*strength;
		vec2 delta = p-center;
		delta.x *= .72;
		ink = max(ink,1.-smoothstep(radius*.65,radius,length(delta)));
	}
	float fade = 1.-smoothstep(.18,.32,age);
	ALBEDO = vec3(.88,.055,.095);
	ALPHA = ink*fade*step(.0,age);
}
