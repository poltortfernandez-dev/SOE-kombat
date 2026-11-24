extends Node3D

const NAMES := ["Riki","Paul","Congui","Miro","Moya","Pons"]
const PUNCH := 2
const KICK := 3
const WINDUP := {PUNCH: 0.13, KICK: 0.27}
const REACH := {PUNCH: 1.72, KICK: 2.18}
const DURATION := {PUNCH: 0.40, KICK: 0.70}
const DAMAGE := {PUNCH: 10, KICK: 17}
const SPEED := 2.4

var identity := 0
var facing := 1
var life := 100
var attack := 0
var elapsed := 0.0
var contact := false
var stun := 0.0
var defending := false
var direction := 0.0
var clock := 0.0
var push_velocity := 0.0
var guard_reaction := 0.0
var hit_height := 2.12
var hit_local_x := 0.0
var hit_strength := 0.0
var wear_level := 0.0
var rig := preload("res://scripts/classic_fighter.gd").new()
var rival: Node3D
var shadow := Sprite3D.new()

func _ready() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.09,0.06,0.04,0.67), Color(0.09,0.06,0.04,0)])
	var blur := GradientTexture2D.new()
	blur.gradient = gradient
	blur.fill = GradientTexture2D.FILL_RADIAL
	blur.fill_from = Vector2(0.5, 0.5)
	blur.fill_to = Vector2(1, 0.5)
	shadow.texture = blur
	shadow.pixel_size = 0.022
	shadow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	shadow.render_priority = -1
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.scale = Vector3(1.65,0.115,1)
	shadow.position = Vector3(0, 0.075, -0.04)
	add_child(shadow)
	add_child(rig)
	reset(0, 1, 0)

func reset(who: int, face: int, x: float) -> void:
	identity = who
	facing = face
	position = Vector3(x, 0, 0)
	clock = who * 1.85
	life = 100
	push_velocity = 0
	guard_reaction = 0
	attack = 0
	stun = 0
	defending = false
	direction = 0
	hit_strength = 0
	contact = false
	elapsed = 0
	rig.configure(who,face)
	update_wear(0.0)
	pose(0.0)

func intent(move_dir: float, guard: bool, strike: int) -> void:
	direction = 0
	defending = false
	if stun > 0 or attack != 0 or life <= 0:
		return
	defending = guard
	if guard:
		return
	if strike == PUNCH or strike == KICK:
		attack = strike
		elapsed = 0
		contact = false
	else:
		direction = move_dir

func tick(dt: float) -> int:
	stun = maxf(0, stun - dt)
	guard_reaction = maxf(0,guard_reaction-dt)
	position.x = clampf(position.x + (direction*SPEED+push_velocity)*dt,-4.7,4.7)
	push_velocity=move_toward(push_velocity,0,dt*8.0)
	var strike := 0
	if attack != 0:
		elapsed += dt
		if elapsed >= float(WINDUP[attack]) and not contact:
			contact = true
			strike = attack
		if elapsed >= float(DURATION[attack]):
			attack = 0
	pose(dt)
	return strike

func update_wear(value: float) -> void:
	wear_level = clampf(value,0,1)

func receive(strike: int, world_point := Vector3.INF) -> void:
	var local_point := to_local(rig.chest if not world_point.is_finite() else world_point)
	hit_height = local_point.y
	hit_local_x = local_point.x * facing
	hit_strength = 1.0 if strike == KICK else 0.65
	if defending:
		push_velocity=-facing*.40
		guard_reaction=.13
		pose(0)
		return
	push_velocity=-facing*(1.7 if strike==KICK else 1.05)
	life = maxi(0, life - int(DAMAGE[strike]))
	update_wear(1.0-life*.01)
	attack = 0
	direction = 0
	stun = 0.23 if strike == KICK else 0.15

	pose(0)

func pose(dt: float) -> void:
	clock += dt
	var gap := absf(position.x-rival.position.x) if is_instance_valid(rival) else 2.0
	rig.animate(self,dt,gap)

func touches(target) -> bool:
	var radius := 0.47 if attack == PUNCH else 0.50
	return rig.reach_point.distance_to(target.rig.chest) <= radius or (target.defending and rig.reach_point.distance_to(target.rig.guard_point) <= 0.42)
