extends Node3D

const Fighter = preload("res://scripts/fighter.gd")
const Audio = preload("res://scripts/sound.gd")
const Interface = preload("res://scripts/interface.gd")
const LEVELS := ["Aprendiz", "Rival", "Maestro"]
const ROUND_TIME := 60.0
enum Phase { MENU, INTRO, FIGHT, PAUSE, RESULT, LOBBY }

var net = (preload("res://scripts/web_online.gd") if OS.has_feature("web") else preload("res://scripts/online.gd")).new()
var phase := Phase.MENU
var chosen := 0
var opponent_choice := 1
var level := 1
var player := Fighter.new()
var cpu := Fighter.new()
var ui := Interface.new()
var audio := Audio.new()
var camera := Camera3D.new()
var time_left := ROUND_TIME
var intro_left := 0.0
var freeze := 0.0
var shake := 0.0
var buffered := 0
var buffer_left := 0.0
var rethink := 0.0
var ai_direction := 0.0
var ai_guard := false
var result := ""
var fx := preload("res://scripts/impact_fx.gd").new()
var combo := [0,0]
var combo_age := [0.0,0.0]

func _ready() -> void:
	build_stage()
	add_child(player)
	add_child(cpu)
	player.rival=cpu
	cpu.rival=player
	add_child(audio)
	add_child(fx)
	add_child(ui)
	net.name = "Online"
	add_child(net)
	menu()

var framing_x := 0.0

func build_stage() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.9
	camera.position = Vector3(0,2.15,10)
	add_child(camera)
	camera.current = true
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = .8
	camera.environment = env
	var backdrop := Sprite3D.new()
	backdrop.texture = preload("res://art/dojo-niebla.jpg")
	backdrop.pixel_size = maxf(10.8/backdrop.texture.get_width(),6.2/backdrop.texture.get_height())
	backdrop.position = Vector3(0,2.15,-1)
	backdrop.shaded = false
	backdrop.modulate = Color(0.91,0.74,0.72)
	backdrop.render_priority = -4
	add_child(backdrop)
	for side in [-1,1]:
		var brazier := preload("res://scripts/brazier.gd").new()
		brazier.position = Vector3(side * 4.58,0.38,-0.68)
		add_child(brazier)
		brazier.assemble(0.0 if side < 0 else 4.7)
	var ember := QuadMesh.new()
	ember.size = Vector2(0.012,0.024)
	var fire := StandardMaterial3D.new()
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.vertex_color_use_as_albedo = true
	ember.material = fire
	var drift := CPUParticles3D.new()
	drift.mesh = ember
	drift.amount = 44
	drift.lifetime = 4.2
	drift.preprocess = 4.2
	drift.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drift.emission_box_extents = Vector3(5.4,0.7,0.06)
	drift.position = Vector3(0,0.25,-0.4)
	drift.direction = Vector3(0.32,1,0)
	drift.spread = 18
	drift.gravity = Vector3.ZERO
	drift.initial_velocity_min = 0.45
	drift.initial_velocity_max = 1.05
	drift.color = Color("#ff9854")
	add_child(drift)

func frame_fighters(dt: float, immediate := false) -> void:
	camera.position = Vector3(sin(shake*140)*shake*.33,2.15,10)
	camera.rotation = Vector3.ZERO

func menu() -> void:
	if net.is_inside_tree():
		net.close()
	phase = Phase.MENU
	freeze = 0
	shake = 0
	framing_x = 0.0
	camera.position = Vector3(0,2.15,10)
	camera.rotation = Vector3.ZERO
	player.reset(chosen, 1, -2.3)
	player.scale = Vector3.ONE * 1.48
	cpu.reset(opponent_choice,-1,2.3)
	cpu.visible=true
	cpu.scale=Vector3.ONE*1.48
	ui.menu(self)

func choose(index: int) -> void:
	if index == opponent_choice:
		opponent_choice=chosen
	chosen = index
	menu()

func choose_cpu(index: int) -> void:
	if index != chosen:
		opponent_choice=index
	menu()

func start_match(left := -1, right := -1) -> void:
	camera.position.x = 0
	player.scale = Vector3.ONE
	player.reset(chosen if left < 0 else left, 1, -1.65)
	var enemy := opponent_choice if right < 0 else right
	if enemy == player.identity: enemy=(enemy+1)%Fighter.NAMES.size()
	cpu.scale=Vector3.ONE
	cpu.reset(enemy,-1,1.65)
	frame_fighters(0,true)
	cpu.visible = true
	time_left = ROUND_TIME
	intro_left = 1.8
	buffered = 0
	freeze = 0
	shake = 0
	combo=[0,0]
	combo_age=[0.0,0.0]
	rethink = 0
	ai_guard = false
	ai_direction = 0
	phase = Phase.INTRO
	ui.hud(self)
	ui.announce("RONDA 1",1.8)
	audio.play("campana")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	if key == KEY_ESCAPE and online() and phase in [Phase.FIGHT,Phase.INTRO]:
		net.lobby("Has salido del combate.")
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and phase in [Phase.FIGHT, Phase.PAUSE]:
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif phase == Phase.FIGHT and key in [KEY_J, KEY_K]:
		buffered = Fighter.PUNCH if key == KEY_J else Fighter.KICK
		buffer_left = 0.14
		if online() and not net.hosting:
			net.send_rpc("attack_key",[net.round_id,buffered])
			buffered = 0

func toggle_pause() -> void:
	buffered = 0
	if phase == Phase.FIGHT:
		phase = Phase.PAUSE
		ui.pause_menu(self)
	elif phase == Phase.PAUSE:
		phase = Phase.FIGHT
		ui.hud(self)
		ui.update_hud(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == Phase.FIGHT and not online():
		toggle_pause()

func _physics_process(dt: float) -> void:
	if phase in [Phase.FIGHT,Phase.INTRO]:
		frame_fighters(dt)
	if online() and not net.hosting:
		if phase in [Phase.FIGHT,Phase.INTRO]:
			net.guest_tick(dt)
		return
	match phase:
		Phase.MENU:
			player.pose(dt)
			cpu.pose(dt)
		Phase.INTRO:
			intro_left -= dt
			if intro_left <= 0:
				phase = Phase.FIGHT
				ui.announce("¡LUCHA!",0.65)
		Phase.FIGHT:
			fight_tick(dt)
	if online() and phase in [Phase.INTRO,Phase.FIGHT]:
		net.stream_tick(dt)

func online() -> bool:
	return net.state == net.State.MATCH

func fight_tick(dt: float) -> void:
	shake = maxf(0, shake - dt)
	ui.advance(dt)
	if freeze > 0:
		freeze -= dt
		return
	for i in 2:
		combo_age[i]=maxf(0,combo_age[i]-dt)
		if combo_age[i]==0:combo[i]=0
	time_left = maxf(0,time_left - dt)
	if buffer_left <= 0:
		buffered = 0
	var previous_attack := player.attack
	player.intent(axis(),blocking(),buffered)
	if previous_attack == 0 and player.attack != 0:
		buffered = 0
	buffer_left -= dt
	if online():
		net.host_input(dt)
	else:
		cpu_think(dt)
	if player.attack!=0 and player.elapsed==0:feedback("aire","",false)
	if cpu.attack!=0 and cpu.elapsed==0:feedback("aire","",false)
	var strike_p := player.tick(dt)
	var strike_c := cpu.tick(dt)
	var gap := cpu.position.x - player.position.x
	if gap < 1.06:
		var center := clampf((cpu.position.x + player.position.x)*0.5, -4.17, 4.17)
		player.position.x = center - 0.53
		cpu.position.x = center + 0.53
		player.pose(0)
		cpu.pose(0)
	# Sample both contacts before either fighter recoils. Simultaneous hits can trade.
	var player_hit := strike_p != 0 and player.touches(cpu)
	var cpu_hit := strike_c != 0 and cpu.touches(player)
	var player_point := player.rig.reach_point
	var cpu_point := cpu.rig.reach_point
	if player_hit:
		land_strike(player,cpu,strike_p,player_point)
	if cpu_hit:
		land_strike(cpu,player,strike_c,cpu_point)
	ui.update_hud(self)
	if player.life <= 0 or cpu.life <= 0 or time_left <= 0:
		end_match()

func axis() -> float:
	return float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))

func blocking() -> bool:
	return Input.is_key_pressed(KEY_L) or Input.is_key_pressed(KEY_SPACE)

func cpu_think(dt: float) -> void:
	rethink -= dt
	var gap := cpu.position.x - player.position.x
	var strike := 0
	if rethink <= 0:
		rethink = [0.48,0.29,0.17][level] * randf_range(0.82,1.35)
		ai_guard = false
		ai_direction = 0
		var under_attack := player.attack != 0 and gap < 2.35
		if under_attack and randf() < float([0.16,0.48,0.73][level]):
			ai_guard = true
		elif gap > 1.85:
			ai_direction = -1
			if gap < 2.14 and randf() < 0.45:
				strike = Fighter.KICK
		elif randf() < float([0.44,0.68,0.86][level]):
			strike = Fighter.PUNCH if gap < 1.72 and randf() < 0.64 else Fighter.KICK
		else:
			ai_direction = 1 if randf() < 0.62 else -1
	if gap < 1.15 and ai_direction < 0:
		ai_direction = 0
	cpu.intent(ai_direction, ai_guard, strike)

func resolve_strike(attacker: Fighter, target: Fighter, strike: int) -> void:
	if strike == 0 or attacker.attack != strike or attacker.life == 0:
		return
	if not attacker.touches(target):
		return
	land_strike(attacker,target,strike,attacker.rig.reach_point)

func land_strike(attacker: Fighter, target: Fighter, strike: int, hit_position: Vector3) -> void:
	var guarded := target.defending
	# Match the original painted fist and high-kick contact heights.
	hit_position = target.rig.chest + Vector3(target.facing*.25,.30 if strike == Fighter.PUNCH else .53,.18)
	if guarded:
		hit_position = target.rig.guard_point
	target.receive(strike,hit_position)
	fx.burst(hit_position,guarded,attacker.facing,strike == Fighter.KICK)
	if online() and net.hosting:
		net.send_rpc("contact_fx",[net.round_id,hit_position,guarded,attacker.facing,strike])
	var side:=0 if attacker==player else 1
	combo[1-side] = 0
	if guarded:
		combo[side] = 0
	else:
		combo[side]+=1
		combo_age[side]=1.3
		if combo[side]>1:ui.combo_hit(combo[side],side==0)
	freeze = 0.045 if guarded else 0.066
	shake = 0.07 if guarded else 0.13
	if guarded:
		feedback("guardia","Bloqueo", target == player)
	else:
		feedback("puño" if strike == Fighter.PUNCH else "patada","Puño" if strike == Fighter.PUNCH else "Patada", attacker == player)

func feedback(sound: String, caption: String, left: bool) -> void:
	audio.play(sound)
	if not caption.is_empty():
		ui.signal_hit(caption,left)
	if online() and net.hosting:
		net.send_rpc("impact",[net.round_id,sound,caption,left])

func end_match() -> void:
	phase = Phase.RESULT
	if player.life == cpu.life:
		result = "Empate"
	else:
		result = "Victoria" if player.life > cpu.life else "Derrota"
	if online():
		if net.hosting:
			net.send_rpc("finish",[net.round_id,player.life,cpu.life,time_left])
		elif result != "Empate":
			result = "Victoria" if cpu.life > player.life else "Derrota"
	audio.play("campana")
	ui.end_screen(self, result, "Tiempo agotado" if time_left <= 0 else "Fin del combate")
