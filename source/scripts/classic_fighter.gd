extends Node3D

const SHEETS := ["riki","paul","congui","miro","moya","pons"]
const HEIGHT := 3.35
const STRIKE_BLEND := 0.055
const WALK_BLEND := 0.075

static func sheet_path(id: int) -> String:
	return "res://art/classic/%s.png" % SHEETS[id]

var visual := MeshInstance3D.new()
var material := ShaderMaterial.new()
var who := -1
var face := 1
var frames: Array[AtlasTexture] = []
var reach_point := Vector3.ZERO
var chest := Vector3.ZERO
var guard_point := Vector3.ZERO
var current_pose := 0
var previous_pose := 0
var blend_elapsed := 0.0
var blend_duration := STRIKE_BLEND

func configure(id: int, facing: int) -> void:
	face = facing
	if not visual.is_inside_tree():
		add_child(visual)
		var plane := QuadMesh.new()
		visual.mesh = plane
		visual.position.y = HEIGHT*.5
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material.shader = preload("res://art/pose_transition.gdshader")
		visual.material_override = material
	if who != id:
		who = id
		var sheet: Texture2D = load(sheet_path(id))
		frames.clear()
		var cell := Vector2(sheet.get_width()/3.0,sheet.get_height()/2.0)
		(visual.mesh as QuadMesh).size = Vector2(HEIGHT*cell.x/cell.y,HEIGHT)
		for index in 6:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(Vector2(index % 3,index / 3)*cell,cell)
			frames.append(frame)
		material.set_shader_parameter("poses",sheet)
	visual.scale.x = face
	current_pose = 0
	previous_pose = 0
	material.set_shader_parameter("current_pose",0)
	material.set_shader_parameter("previous_pose",0)
	finish_transition()

func finish_transition() -> void:
	blend_elapsed = blend_duration
	material.set_shader_parameter("transition",1.0)
	set_process(false)

func change_pose(next_pose: int) -> void:
	if current_pose == next_pose:
		return
	previous_pose = current_pose
	current_pose = next_pose
	blend_elapsed = 0.0
	blend_duration = WALK_BLEND if next_pose in [0,1] and previous_pose in [0,1] else STRIKE_BLEND
	material.set_shader_parameter("previous_pose",previous_pose)
	material.set_shader_parameter("current_pose",current_pose)
	material.set_shader_parameter("transition",0.0)
	set_process(true)

func _process(dt: float) -> void:
	blend_elapsed = minf(blend_elapsed+dt,blend_duration)
	var fraction := blend_elapsed/blend_duration
	material.set_shader_parameter("transition",fraction*fraction*(3.0-2.0*fraction))
	if blend_elapsed >= blend_duration:
		finish_transition()

func animate(f, _dt: float, gap: float) -> void:
	var frame := 0
	if f.stun > 0 or f.life <= 0:
		frame = 5
	elif f.defending:
		frame = 4
	elif f.attack != 0:
		if f.elapsed >= f.WINDUP[f.attack]*.64 and f.elapsed <= f.DURATION[f.attack]*.78:
			frame = 2 if f.attack == f.PUNCH else 3
	elif absf(f.direction) > .01:
		frame = 1 if sin(f.clock*13) > 0 else 0
	change_pose(frame)
	# The strike is fully visible at contact, including low-frame-rate clients.
	if f.attack != 0 and f.elapsed >= f.WINDUP[f.attack] and frame in [2,3]:
		finish_transition()
	chest = to_global(Vector3(0,2.12,0))
	guard_point = to_global(Vector3(face*.31,2.22,0))
	var extension: float = f.REACH.get(f.attack,1.0)
	reach_point = to_global(Vector3(face*minf(maxf(.35,gap-.29),extension-.20),2.12,0))
