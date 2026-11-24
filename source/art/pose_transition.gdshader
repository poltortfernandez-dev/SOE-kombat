shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D poses : source_color, filter_linear_mipmap, repeat_disable;
uniform int previous_pose;
uniform int current_pose;
uniform float transition : hint_range(0.,1.) = 1.;

vec4 pose_color(int index, vec2 local_uv) {
	vec2 cell = vec2(float(index % 3),float(index / 3));
	vec2 margin = 0.5 / vec2(textureSize(poses,0));
	vec2 atlas_uv = (local_uv+cell)/vec2(3.,2.);
	atlas_uv = clamp(atlas_uv,cell/vec2(3.,2.)+margin,(cell+1.)/vec2(3.,2.)-margin);
	return texture(poses,atlas_uv);
}

void fragment() {
	vec4 current = pose_color(current_pose,UV);
	vec4 previous = pose_color(previous_pose,UV);
	// Mix premultiplied colors so transparent edges retain the original color.
	float alpha = mix(previous.a,current.a,transition);
	vec3 color = mix(previous.rgb*previous.a,current.rgb*current.a,transition);
	ALBEDO = color / max(alpha,0.0001);
	ALPHA = alpha;
}
