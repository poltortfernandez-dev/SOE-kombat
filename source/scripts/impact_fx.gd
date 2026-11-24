extends Node3D

const POOL_SIZE := 4
var sparks: Array[CPUParticles3D] = []
var drops: Array[CPUParticles3D] = []
var next := 0
var splashes: Array[MeshInstance3D] = []
var splash_ages := [1.0,1.0,1.0,1.0]

func _ready() -> void:
	for blood in [false,true]:
		var material := ShaderMaterial.new()
		material.shader = preload("res://art/impact_mote.gdshader")
		material.set_shader_parameter("droplets",blood)
		material.render_priority = 2
		var quad := QuadMesh.new()
		quad.material = material
		quad.size = Vector2(.058,.028) if blood else Vector2(.105,.022)
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color.WHITE,Color.WHITE,Color(1,.84,.77,0)])
		fade.offsets = PackedFloat32Array([0,.41,1])
		for i in POOL_SIZE:
			var burst := CPUParticles3D.new()
			burst.mesh = quad
			burst.emitting = false
			burst.one_shot = true
			burst.explosiveness = 0.98
			burst.local_coords = false
			burst.lifetime = .30 if blood else .23
			burst.lifetime_randomness = .37
			burst.amount = 10 if blood else 17
			burst.particle_flag_disable_z = true
			burst.spread = 24 if blood else 65
			burst.angle_min = -18
			burst.angle_max = 18
			burst.angular_velocity_min = -110
			burst.angular_velocity_max = 110
			burst.scale_amount_min = .42
			burst.scale_amount_max = 1.17
			burst.gravity = Vector3.DOWN * (5.5 if blood else 3.0)
			burst.color_ramp = fade
			add_child(burst)
			if blood:
				drops.append(burst)
			else:
				sparks.append(burst)
	for i in POOL_SIZE:
		var splash := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(1.8,1.2)
		splash.mesh = plane
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://art/hit_splash.gdshader")
		mat.render_priority = 3
		splash.material_override = mat
		splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splash.position = Vector3(0,2,-2)
		add_child(splash)
		splashes.append(splash)
	# Warm both shaders while the first selection screen is visible.
	for pool in [drops,sparks]:
		pool[0].color = Color(1,1,1,0)
		pool[0].position = Vector3(0,2,-2)
		pool[0].restart()

func burst(at: Vector3, blocked: bool, facing := 1, heavy := false) -> void:
	var index := next
	var effect := sparks[index] if blocked else drops[index]
	if not blocked:
		var splash := splashes[index]
		splash.global_position = at+Vector3(0,0,.32)
		splash_ages[index] = 0.
		splash.material_override.set_shader_parameter("age",0.)
		splash.material_override.set_shader_parameter("direction",float(facing))
		splash.material_override.set_shader_parameter("strength",1.1 if heavy else .9)
		splash.visible = true
		set_process(true)
	next = (next + 1) % POOL_SIZE
	effect.global_position = at + Vector3(0,0,.12)
	effect.color = Color("#ffd486") if blocked else Color("#dc3c45")
	effect.direction = Vector3(float(facing) * (-.72 if blocked else 1.),.46,0).normalized()
	effect.amount = (12 if heavy else 8) if not blocked else 17
	effect.initial_velocity_min = 1.5 if heavy else 1.05
	effect.initial_velocity_max = 3.3 if heavy else 2.7
	effect.restart()


func _process(dt: float) -> void:
	var active := false
	for i in splashes.size():
		if splash_ages[i] >= .32:
			splashes[i].visible = false
			continue
		splash_ages[i] += dt
		splashes[i].material_override.set_shader_parameter("age",splash_ages[i])
		active = true
	if not active:
		set_process(false)
