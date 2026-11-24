extends Node

# Only the receiving machine simulates combat. The challenger sends controls.
const PORT := 37819
const PREFIX := "DOJO2"
const ROOM_ATTEMPTS := 3
const ROOM_ATTEMPT_TIME := 24.0
const ROOM_PROBE_TIME := 4.0
enum State { OFF, LOBBY, DIALING, WAITING, OFFER, MATCH, CREATING, ROOM }
var state := State.OFF
var game
var socket: MultiplayerPeer
var connector := preload("res://scripts/room_connector.gd").new()
var via_code := false
var direct_tab := false
var join_url := ""
var retry_delay := 0.0
var room_secret := ""
var room_port := 0
var room_attempt := 0
var candidate := ""
var probe: WebSocketPeer
var probe_timer := 0.0
var probe_delay := 0.0
var guest_targets := Vector2.ZERO
var has_guest_frame := false
var room_code := ""
var hosting := false
var opponent := 0
var offered_card := ""
var input_age := 0.0
var remote_name := ""
var remote_fighter := 0
var message := ""
var timeout := 0.0
var snapshot_time := 0.0
var move_axis := 0
var guard := false
var strike := 0
var strike_age := 0.0
var own_ready := false
var other_ready := false
var round_id := 0
var nickname := "Karateka"
var address := ""
var key := ""
var dial_key := ""
var friends := {}
var profile_path := "user://dojo_amigos_v2.cfg"
var port := PORT

func _ready() -> void:
	game = get_parent()
	var config := ConfigFile.new()
	config.load(profile_path)
	nickname = str(config.get_value("yo","nombre",nickname))
	address = str(config.get_value("yo","direccion",""))
	key = str(config.get_value("yo","clave",""))
	if key.length() != 24:
		key = Crypto.new().generate_random_bytes(12).hex_encode()
	var stored = config.get_value("yo","amigos",{})
	if stored is Dictionary:
		for id in stored:
			if stored[id] is String:
				var parts := parse_card(stored[id])
				if not parts.is_empty() and parts[4] == id:
					friends[id] = stored[id]
	if address.is_empty():
		for ip in IP.get_local_addresses():
			if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254.") and not ip.contains(":"):
				address = ip
				break
	multiplayer.connected_to_server.connect(connected)
	multiplayer.connection_failed.connect(func(): lost("No se pudo conectar. Comprueba que la sala sigue abierta y vuelve a intentarlo."))
	multiplayer.server_disconnected.connect(lost.bind("Tu compañero ha salido de la sala."))
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.peer_connected.connect(peer_joined)

func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("yo","nombre",nickname)
	config.set_value("yo","direccion",address)
	config.set_value("yo","clave",key)
	config.set_value("yo","amigos",friends)
	var temp := profile_path + ".tmp"
	if config.save(temp) != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(profile_path)) == OK

func clean_name(s: String) -> String:
	return s.strip_edges().replace("|","").replace("\n"," ").replace("\r"," ").left(24)

func card() -> String:
	return "%s|%s|%s|%d|%s" % [PREFIX,nickname,address,port,key]

func parse_card(s: String) -> PackedStringArray:
	var parts := s.strip_edges().split("|")
	if parts.size() != 5 or parts[0] != PREFIX or clean_name(parts[1]).is_empty():
		return []
	if not parts[2].is_valid_ip_address() or not parts[3].is_valid_int() or int(parts[3]) < 1 or int(parts[3]) > 65535:
		return []
	if parts[4].length() != 24 or not parts[4].is_valid_hex_number(false):
		return []
	return parts

func set_profile(alias_text: String, host: String) -> bool:
	if clean_name(alias_text).is_empty() or not host.strip_edges().is_valid_ip_address():
		message = "Escribe un nombre y una dirección IP válida."
		return false
	nickname = clean_name(alias_text)
	address = host.strip_edges()
	if not save():
		message = "No se pudo guardar el perfil en este equipo."
		return false
	return true

func add_friend(raw: String) -> void:
	var parts := parse_card(raw)
	if parts.is_empty() or parts[4] == key:
		message = "Pega una tarjeta DOJO2 válida de otro jugador."
	else:
		friends[parts[4]] = raw.strip_edges()
		message = "Amigo guardado." if save() else "No se pudo guardar la lista."
	show_lobby()

func forget(id: String) -> void:
	friends.erase(id)
	message = "Contacto eliminado." if save() else "No se pudo guardar la lista."
	show_lobby()

func _exit_tree() -> void:
	connector.stop()

func close() -> void:
	reset_probe()
	connector.stop()
	via_code = false
	room_secret = ""
	room_code = ""
	join_url = ""
	retry_delay = 0
	state = State.OFF
	opponent = 0
	offered_card = ""
	timeout = 0
	if socket:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		socket.close()
		socket = null
	hosting = false

func lobby(note := "") -> void:
	close()
	game.phase = game.Phase.LOBBY
	game.cpu.visible = false
	state = State.LOBBY
	message = note
	if not direct_tab:
		show_lobby()
		return
	var listener := ENetMultiplayerPeer.new()
	socket = listener
	if listener.create_server(port,1) == OK:
		hosting = true
		multiplayer.multiplayer_peer = socket
	else:
		socket = null
		message += " No se puede recibir en UDP %d. Aún puedes invitar a otro equipo." % port
	show_lobby()

func show_lobby() -> void:
	game.ui.online_lobby(game)

func invite(id: String) -> void:
	if state != State.LOBBY or not friends.has(id):
		return
	var parts := parse_card(friends[id])
	if parts.is_empty():
		return
	close()
	state = State.DIALING
	dial_key = parts[4]
	remote_name = clean_name(parts[1])
	var client := ENetMultiplayerPeer.new()
	socket = client
	if client.create_client(parts[2],int(parts[3])) != OK:
		lobby("No se pudo iniciar la conexión.")
		return
	multiplayer.multiplayer_peer = socket
	timeout = 10
	message = "Conectando con " + remote_name + "…"
	show_lobby()

func peer_joined(id: int) -> void:
	if hosting and state == State.CREATING:
		return
	if hosting and (opponent != 0 or state not in [State.LOBBY,State.ROOM]):
		socket.disconnect_peer(id)
		return
	if hosting:
		opponent = id
		timeout = 6

func connected() -> void:
	if state != State.DIALING:
		return
	opponent = 1
	state = State.WAITING
	timeout = 35
	message = "Esperando que tu compañero acepte…"
	if via_code:
		room_knock.rpc_id(1,room_secret,nickname,game.chosen)
	else:
		offer.rpc_id(1,dial_key,card(),game.chosen)
	show_lobby()

@rpc("any_peer","reliable")
func offer(target_key: String, sender_card: String, fighter: int) -> void:
	if not hosting or state != State.LOBBY or remote_sender() != opponent:
		return
	var sender := parse_card(sender_card)
	if target_key != key or fighter not in range(game.player.NAMES.size()) or sender.is_empty() or sender[4] == key:
		return
	state = State.OFFER
	offered_card = sender_card
	remote_name = clean_name(sender[1])
	remote_fighter = fighter
	timeout = 30
	message = remote_name + " te invita a un combate."
	show_lobby()

func accept(remember := false) -> void:
	if state != State.OFFER or not hosting:
		return
	if remember:
		var sender := parse_card(offered_card)
		friends[sender[4]] = offered_card
		if not save():
			message = "No se pudo guardar el contacto. Puedes aceptar sin guardarlo."
			show_lobby()
			return
	begin_round()

func begin_round() -> void:
	if remote_fighter == game.chosen:
		remote_fighter=(remote_fighter+1)%game.player.NAMES.size()
	round_id += 1
	send_rpc("begin",[round_id,game.chosen,remote_fighter,nickname])
	play_round(round_id,game.chosen,remote_fighter)

@rpc("authority","reliable")
func begin(number: int, left: int, right: int, alias_text: String) -> void:
	if hosting or state not in [State.WAITING, State.MATCH] or left == right or left not in range(game.player.NAMES.size()) or right not in range(game.player.NAMES.size()):
		return
	remote_name = clean_name(alias_text)
	play_round(number,left,right)

func play_round(number: int, left: int, right: int) -> void:
	state = State.MATCH
	timeout = 0
	own_ready = false
	other_ready = false
	move_axis = 0
	guard = false
	strike = 0
	round_id = number
	has_guest_frame = false
	game.start_match(left,right)

func peer_left(id: int) -> void:
	if id == opponent and state == State.ROOM:
		opponent = 0
		timeout = 0
		return
	if id == opponent:
		lost("Tu compañero ha salido.")

func lost(note: String) -> void:
	if state != State.OFF:
		# Defer replacement until SceneMultiplayer has finished polling this peer.
		var old := socket
		restore.call_deferred(old,note)

func restore(old: MultiplayerPeer, note: String) -> void:
	if old != socket or state == State.OFF:
		return
	if via_code and state == State.DIALING and timeout > 2.0:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		socket.close()
		socket = null
		retry_delay = 1.5
		message = "Esperando a que la sala sea accesible…"
		show_lobby()
		return
	lobby(note)

func _process(dt: float) -> void:
	if retry_delay > 0:
		retry_delay -= dt
		if retry_delay <= 0 and state == State.DIALING:
			connect_room_socket()
	if state == State.CREATING:
		poll_room_setup(dt)
		return
	if via_code and state == State.MATCH and not hosting and has_guest_frame:
		var weight := 1.0 - exp(-55.0 * dt)
		game.player.position.x = lerpf(game.player.position.x,guest_targets.x,weight)
		game.cpu.position.x = lerpf(game.cpu.position.x,guest_targets.y,weight)
	if via_code and hosting and not OS.is_process_running(connector.pid):
		lobby("El conector gratuito se ha cerrado. Vuelve a crear la sala.")
		return
	if timeout > 0:
		timeout -= dt
		if timeout <= 0:
			if state == State.ROOM and opponent != 0:
				var idle_peer := opponent
				opponent = 0
				socket.disconnect_peer(idle_peer)
				return
			lobby("La invitación ha caducado. Comprueba que el otro equipo esté accesible.")

@rpc("any_peer","call_remote","unreliable_ordered",1)
func controls(number: int, axis: int, block: bool) -> void:
	if valid_input(number):
		input_age = 0.0
		move_axis = clampi(axis,-1,1)
		guard = block

@rpc("any_peer","reliable")
func attack_key(number: int, action: int) -> void:
	if valid_input(number) and action in [2,3]:
		strike = action
		strike_age = 0.14

func valid_input(number: int) -> bool:
	return hosting and state == State.MATCH and round_id == number and remote_sender() == opponent and game.phase == game.Phase.FIGHT

func guest_tick(dt: float) -> void:
	if game.phase == game.Phase.FIGHT:
		game.ui.advance(dt)
	snapshot_time -= dt
	if snapshot_time <= 0:
		snapshot_time = 1.0/30
		send_rpc("controls",[round_id,int(game.axis()),game.blocking()])

func host_input(dt: float) -> void:
	input_age += dt
	if input_age > 0.5:
		move_axis = 0
		guard = false
	if strike_age <= 0:
		strike = 0
	var was_idle: bool = game.cpu.attack == 0
	game.cpu.intent(move_axis,guard,strike)
	strike_age -= dt
	if was_idle and game.cpu.attack != 0:
		strike = 0

func stream_tick(dt: float) -> void:
	snapshot_time -= dt
	if snapshot_time <= 0:
		snapshot_time = 1.0/30
		send_rpc("frame",[round_id,game.phase,game.time_left,pack_fighter(game.player),pack_fighter(game.cpu)])

func pack_fighter(f) -> PackedFloat32Array:
	return [f.position.x, f.life, f.attack, f.elapsed, f.stun, int(f.defending), f.direction, f.clock, f.hit_height, f.hit_local_x, f.hit_strength, f.guard_reaction]

func apply_fighter(f, data: PackedFloat32Array) -> void:
	var new_life := clampi(int(data[1]),0,100)
	if f.life != new_life:
		f.update_wear(1.0-new_life*.01)
	f.life = new_life
	f.attack = int(data[2]) if int(data[2]) in [2,3] else 0
	f.elapsed = data[3]
	f.stun = data[4]
	f.defending = data[5] != 0
	f.direction = data[6]
	f.clock = data[7]
	if data.size() >= 12:
		f.hit_height = data[8]
		f.hit_local_x = data[9]
		f.hit_strength = data[10]
		f.guard_reaction = data[11]
	f.pose(0)

@rpc("authority","call_remote","unreliable_ordered",2)
func frame(number: int, phase: int, remaining: float, left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	if state != State.MATCH or number != round_id or game.phase == game.Phase.RESULT or left.size() not in [8,12] or right.size()!=left.size():
		return
	if phase not in [game.Phase.FIGHT,game.Phase.INTRO]:
		return
	if phase == game.Phase.FIGHT and game.phase == game.Phase.INTRO:
		game.ui.announce("¡Combate!",0.5)
	game.phase = phase
	game.time_left = remaining
	guest_targets = Vector2(left[0],right[0])
	if not via_code or not has_guest_frame:
		game.player.position.x = guest_targets.x
		game.cpu.position.x = guest_targets.y
	has_guest_frame = true
	apply_fighter(game.player,left)
	apply_fighter(game.cpu,right)
	game.ui.update_hud(game)

@rpc("authority","reliable")
func contact_fx(number: int, at: Vector3, guarded: bool, facing: int, strike_type: int) -> void:
	if state == State.MATCH and number == round_id and game.phase == game.Phase.FIGHT:
		game.fx.burst(at,guarded,facing,strike_type == game.Fighter.KICK)

@rpc("authority","reliable")
func impact(number: int, sound: String, caption: String, left: bool) -> void:
	if state == State.MATCH and number == round_id and game.phase == game.Phase.FIGHT and sound in ["guardia","puño","patada","aire"]:
		game.audio.play(sound)
		if not caption.is_empty():
			game.ui.signal_hit(caption,left)

@rpc("authority","reliable")
func finish(number: int, left: int, right: int, remaining: float) -> void:
	if state == State.MATCH and round_id == number:
		game.player.life = left
		game.cpu.life = right
		game.time_left = remaining
		game.end_match()

func replay() -> void:
	if state != State.MATCH or game.phase != game.Phase.RESULT or own_ready:
		return
	own_ready = true
	send_rpc("want_replay",[round_id])
	game.ui.end_screen(game,game.result,"Esperando revancha")
	if hosting and other_ready:
		begin_round()

@rpc("any_peer","reliable")
func want_replay(number: int) -> void:
	if state != State.MATCH or number != round_id or remote_sender() != opponent or game.phase != game.Phase.RESULT:
		return
	other_ready = true
	if hosting and own_ready:
		begin_round()
	elif not own_ready:
		game.ui.end_screen(game,game.result,"Tu compañero pide revancha")

func decline() -> void:
	if state == State.OFFER:
		send_rpc("declined",[])
		state = State.WAITING
		message = "Invitación rechazada."
		timeout = 1.0
		show_lobby()

@rpc("authority","reliable")
func declined() -> void:
	if state == State.WAITING and not hosting:
		lost("Tu compañero ha rechazado la invitación.")

func select_tab(direct: bool) -> void:
	direct_tab = direct
	lobby()

func create_room(alias_text: String) -> void:
	if state != State.LOBBY:
		return
	close()
	nickname = clean_name(alias_text)
	if nickname.is_empty():
		nickname = "Karateka"
	save()
	var ws := WebSocketMultiplayerPeer.new()
	var local_port := 0
	for attempt in 8:
		local_port = randi_range(49152,65535)
		if ws.create_server(local_port,"127.0.0.1") == OK:
			break
		local_port = 0
	if local_port == 0:
		lobby("No se pudo abrir la sala local. Inténtalo otra vez.")
		return
	socket = ws
	multiplayer.multiplayer_peer = socket
	multiplayer.server_relay = false
	via_code = true
	hosting = true
	room_secret = Crypto.new().generate_random_bytes(10).hex_encode()
	room_port = local_port
	room_attempt = 0
	state = State.CREATING
	start_room_tunnel()

func reset_probe() -> void:
	if probe:
		probe.close()
		probe = null
	candidate = ""
	probe_delay = 0

func start_room_tunnel() -> void:
	reset_probe()
	connector.stop()
	room_attempt += 1
	if not connector.start(room_port):
		lobby("No se pudo iniciar el conector. Comprueba que has extraído el paquete completo.")
		return
	timeout = ROOM_ATTEMPT_TIME
	message = "Comprobando la sala desde internet…" if room_attempt == 1 else "Probando otra ruta automáticamente (%d/%d)…" % [room_attempt,ROOM_ATTEMPTS]
	show_lobby()

func poll_room_setup(dt: float) -> void:
	timeout -= dt
	if timeout <= 0 or not OS.is_process_running(connector.pid):
		if room_attempt < ROOM_ATTEMPTS:
			start_room_tunnel()
		else:
			lobby("El servicio gratuito no abrió una ruta accesible. Puedes volver a intentarlo.")
		return
	if candidate.is_empty():
		candidate = connector.ready_slug(dt)
		if candidate.is_empty():
			return
	if probe:
		probe.poll()
		probe_timer -= dt
		var connection := probe.get_ready_state()
		if connection == WebSocketPeer.STATE_OPEN:
			probe.close()
			probe = null
			for peer_id in multiplayer.get_peers():
				socket.disconnect_peer(peer_id)
			room_code = "DOJO3." + candidate + "." + room_secret
			state = State.ROOM
			timeout = 0
			message = "Sala verificada. Comparte el código con tu compañero."
			show_lobby()
		elif connection == WebSocketPeer.STATE_CLOSED or probe_timer <= 0:
			probe.close()
			probe = null
			probe_delay = 1.0
		return
	probe_delay -= dt
	if probe_delay <= 0:
		probe = WebSocketPeer.new()
		probe_timer = ROOM_PROBE_TIME
		if probe.connect_to_url("wss://" + candidate + ".trycloudflare.com") != OK:
			probe = null
			probe_delay = 1.0

func join_room(code: String, alias_text: String) -> void:
	if state != State.LOBBY:
		return
	var pattern := RegEx.new()
	pattern.compile("^dojo3\\.([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)\\.([a-f0-9]{20})$")
	var result := pattern.search(code.strip_edges().to_lower())
	if not result:
		message = "Código inválido. Pega el código DOJO3 completo."
		show_lobby()
		return
	close()
	nickname = clean_name(alias_text)
	if nickname.is_empty():
		nickname = "Karateka"
	save()
	via_code = true
	room_secret = result.get_string(2)
	join_url = "wss://" + result.get_string(1) + ".trycloudflare.com"
	state = State.DIALING
	message = "Conectando con la sala…"
	timeout = 35
	show_lobby()
	connect_room_socket()

func connect_room_socket() -> void:
	var ws := WebSocketMultiplayerPeer.new()
	ws.handshake_timeout = 5.0
	socket = ws
	if ws.create_client(join_url) != OK:
		socket = null
		retry_delay = 1.5
		return
	multiplayer.multiplayer_peer = socket

@rpc("any_peer","reliable")
func room_knock(secret: String, alias_text: String, fighter: int) -> void:
	if not via_code or not hosting or state != State.ROOM or remote_sender() != opponent:
		return
	if secret != room_secret or fighter not in range(game.player.NAMES.size()) or clean_name(alias_text).is_empty():
		var rejected := opponent
		opponent = 0
		timeout = 0
		socket.disconnect_peer(rejected)
		return
	state = State.OFFER
	remote_name = clean_name(alias_text)
	remote_fighter = fighter
	message = remote_name + " quiere entrar en tu dojo."
	timeout = 35
	show_lobby()


func send_rpc(method: String, arguments: Array) -> void:
	callv("rpc_id",[opponent,method]+arguments)

func remote_sender() -> int:
	return multiplayer.get_remote_sender_id()
