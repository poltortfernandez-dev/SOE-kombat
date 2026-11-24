shader_type canvas_item;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	float height = clamp(local.y / 84.0, 0.0, 1.0);
	float grain = 0.026 * sin(local.y * 2.8 + 0.6 * sin(local.x * 0.19));
	vec3 upper = mix(vec3(1.0, 0.98, 0.85), vec3(0.99, 0.84, 0.58), height);
	vec3 lower = mix(vec3(0.69, 0.41, 0.23), vec3(1.0, 0.87, 0.65), height);
	COLOR.rgb = mix(upper, lower, smoothstep(0.47, 0.53, height)) + grain;
}
