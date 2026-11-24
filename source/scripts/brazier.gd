extends Node3D

func assemble(phase: float) -> void:
	var stand := MeshInstance3D.new()
	stand.mesh = turned_iron()
	stand.rotation.x = deg_to_rad(10)
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stand)
	var flame_material := ShaderMaterial.new()
	flame_material.shader = preload("res://art/brazier_flame.gdshader")
	flame_material.set_shader_parameter("phase",phase)
	flame_material.render_priority = -1
	var fire := QuadMesh.new()
	fire.size = Vector2(0.94,1.16)
	fire.material = flame_material
	var flame := MeshInstance3D.new()
	flame.mesh = fire
	flame.position.y = 1.24
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	var reflection := QuadMesh.new()
	reflection.size = Vector2(1.55,.61)
	var reflected_fire := ShaderMaterial.new()
	reflected_fire.shader = preload("res://art/brazier_floor.gdshader")
	reflected_fire.render_priority = -3
	reflected_fire.set_shader_parameter("phase",phase)
	reflection.material = reflected_fire
	var floor_light := MeshInstance3D.new()
	floor_light.mesh = reflection
	floor_light.position = Vector3(0,-.23,.015)
	floor_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_light)

# Radius, height, brass trim, and live coals. One indexed surface per brazier.
func turned_iron() -> ArrayMesh:
	var rings := [
		Vector4(.39,.00,.04,0), Vector4(.40,.025,.20,0), Vector4(.36,.049,.18,0),
		Vector4(.33,.065,.02,0), Vector4(.30,.095,.05,0), Vector4(.20,.12,.04,0),
		Vector4(.14,.18,.1,0), Vector4(.10,.31,.08,0), Vector4(.135,.32,.72,0),
		Vector4(.135,.345,.65,0), Vector4(.10,.355,.06,0), Vector4(.12,.45,.05,0),
		Vector4(.19,.49,.10,0), Vector4(.28,.56,.08,0), Vector4(.35,.65,.12,0),
		Vector4(.366,.662,.85,0), Vector4(.375,.687,.65,0), Vector4(.357,.706,.4,0),
		Vector4(.337,.692,.08,0), Vector4(.295,.682,.00,1), Vector4(.0001,.696,.00,1)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 32
	for ring in rings.size()-1:
		var lower: Vector4 = rings[ring]
		var upper: Vector4 = rings[ring+1]
		var dy := upper.y-lower.y
		var dr := upper.x-lower.x
		for j in SIDES+1:
			var angle := TAU * j / SIDES
			var cs := cos(angle)
			var sn := sin(angle)
			for profile: Vector4 in [lower,upper]:
				surface.set_normal(Vector3(dy*cs,-dr,dy*sn).normalized())
				surface.set_uv(Vector2(float(j)/SIDES,profile.y))
				surface.set_color(Color(profile.z,profile.w,0))
				surface.add_vertex(Vector3(profile.x*cs,profile.y,profile.x*sn))
			if j < SIDES:
				var a := ring*(SIDES+1)*2+j*2
				for index in [a,a+2,a+1,a+1,a+2,a+3]:
					surface.add_index(index)
	var material := ShaderMaterial.new()
	material.shader = preload("res://art/brazier_metal.gdshader")
	surface.set_material(material)
	return surface.commit()
