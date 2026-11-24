shader_type spatial;
render_mode unshaded, cull_disabled;
varying vec2 local_plate;
void vertex() {
	local_plate = VERTEX.xz;
}
void fragment() {
	vec3 n = normalize(NORMAL);
	float cast = .96+.04*sin(UV.y*63.+sin(UV.x*22.)*.87);
	float key = max(dot(n,normalize(vec3(-.48,.67,.60))),0.);
	float fire = max(dot(n,normalize(vec3(.3,.85,.32))),0.);
	float spec = pow(max(dot(n,normalize(vec3(-.32,.38,.86))),0.),13.);
	vec3 iron = vec3(.11,.105,.105)*(.72+.66*key) + vec3(.14,.053,.025)*fire*fire;
	vec3 brass = vec3(.23,.13,.075)*(.60+1.3*key) + vec3(.28,.13,.042)*fire;
	vec3 body = mix(iron,brass,COLOR.r)*cast + spec*mix(.09,.22,COLOR.r);
	float ash = sin(local_plate.x*107.+cos(local_plate.y*83.))*sin(local_plate.y*93.);
	vec3 coal = mix(vec3(.18,.055,.018),vec3(.93,.32,.038),smoothstep(.31,.89,ash));
	ALBEDO = mix(body,coal,smoothstep(.1,.8,COLOR.g));
}
