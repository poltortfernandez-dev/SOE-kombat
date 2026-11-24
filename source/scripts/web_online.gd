extends "res://scripts/online.gd"

var bridge
var packet_age := 0.0
var heartbeat := 0.0

func _ready() -> void:
	game = get_parent()
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/peerjs.min.js"),true)
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/moro_net.js"),true)
	bridge = JavaScriptBridge.get_interface("MoroNet")
	var config := ConfigFile.new()
	if config.load(profile_path) == OK:
		nickname = clean_name(str(config.get_value("yo","nombre",nickname)))

func close() -> void:
	if bridge:
		bridge.close()
	super.close()
	packet_age = 0
	heartbeat = 0

func _exit_tree() -> void:
	if bridge:
		bridge.close()

func lobby(note := "") -> void:
	close()
	game.phase = game.Phase.LOBBY
	game.cpu.visible = false
	state = State.LOBBY
	direct_tab = false
	message = note
	show_lobby()

func lost(note: String) -> void:
	if state != State.OFF:
		lobby(note)

func create_room(alias_text: String) -> void:
	if state != State.LOBBY:
		return
	if not bridge:
		message = "No se pudo cargar la conexión web. Recarga la página."
		show_lobby()
		return
	close()
	nickname = clean_name(alias_text)
	if nickname.is_empty(): nickname = "Karateka"
	save()
	via_code = true
	hosting = true
	state = State.CREATING
	message = "Abriendo tu sala gratuita…"
	timeout = 40
	bridge.create()
	show_lobby()

func join_room(code: String, alias_text: String) -> void:
	if state != State.LOBBY:
		return
	var pattern := RegEx.new()
	pattern.compile("^MK-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$")
	var normalized := code.strip_edges().to_upper()
	if not pattern.search(normalized):
		message = "Pega el código completo MK-XXXXXX-XXXXXX de tu compañero."
		show_lobby()
		return
	if not bridge:
		message = "No se pudo cargar la conexión web. Recarga la página."
		show_lobby()
		return
	close()
	nickname = clean_name(alias_text)
	if nickname.is_empty(): nickname = "Karateka"
	save()
	via_code = true
	hosting = false
	state = State.DIALING
	timeout = 40
	message = "Conectando con tu compañero…"
	bridge.join(normalized)
	show_lobby()

func send_rpc(method: String, arguments: Array) -> void:
	if not bridge:
		return
	var wire := []
	for value in arguments:
		if value is Vector3:
			wire.append([value.x,value.y,value.z])
		else:
			wire.append(value)
	bridge.send(method,JSON.stringify(wire))

func remote_sender() -> int:
	return 2 if hosting else 1

func _process(dt: float) -> void:
	if not bridge or state == State.OFF:
		return
	var pending = JSON.parse_string(str(bridge.poll()))
	if pending is Array:
		for event in pending:
			if event is Dictionary:
				handle_event(event)
			if state in [State.OFF,State.LOBBY]:
				return
	if state == State.MATCH:
		packet_age += dt
		heartbeat -= dt
		if heartbeat <= 0:
			send_rpc("ping",[round_id])
			heartbeat = 2
		if packet_age > 20:
			lost("La conexión lleva demasiado tiempo sin responder. Cread una sala nueva.")
			return
		if not hosting and has_guest_frame:
			var weight := 1.0-exp(-40.0*dt)
			game.player.position.x = lerpf(game.player.position.x,guest_targets.x,weight)
			game.cpu.position.x = lerpf(game.cpu.position.x,guest_targets.y,weight)
	if timeout > 0:
		timeout -= dt
		if timeout <= 0:
			lost("La invitación ha caducado. Vuelve a crear o unirte a una sala.")

func handle_event(event: Dictionary) -> void:
	match event.get("event",""):
		"room":
			if hosting and state == State.CREATING:
				room_code = str(event.get("code",""))
				state = State.ROOM
				timeout = 0
				message = "Sala abierta. Comparte el código y mantén esta pestaña abierta."
				show_lobby()
		"connected":
			opponent = 2 if hosting else 1
			if not hosting and state == State.DIALING:
				state = State.WAITING
				timeout = 50
				send_rpc("hello",[1,nickname,game.chosen])
				message = "Conectado. Esperando que el anfitrión acepte…"
				show_lobby()
			elif hosting and state == State.ROOM:
				timeout = 10
		"data":
			var packet = event.get("payload")
			if packet is Dictionary:
				dispatch(packet)
		"error":
			lost(str(event.get("message","La conexión no está disponible.")))

func integer(value, minimum: int, maximum: int) -> bool:
	return (
		(value is float or value is int) and is_finite(float(value))
		and float(value) == floor(float(value)) and value >= minimum and value <= maximum)

func scalar(value, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum

func fighter_packet(value) -> bool:
	if not value is Array or value.size() != 12:
		return false
	return scalar(value[0],-4.7,4.7) and integer(value[1],0,100) and integer(value[2],0,3) and scalar(value[3],0,10) and scalar(value[4],0,1) and integer(value[5],0,1) and scalar(value[6],-1,1) and scalar(value[7],0,100000000) and scalar(value[8],-10,10) and scalar(value[9],-10,10) and scalar(value[10],0,1) and scalar(value[11],0,1)

func dispatch(packet: Dictionary) -> void:
	var method = packet.get("method")
	var args = packet.get("args")
	if not method is String or not args is Array or args.size() > 6:
		return
	var allowed: Array = ["hello","controls","attack_key","want_replay","ping"] if hosting else ["begin","frame","contact_fx","impact","finish","declined","want_replay","ping"]
	if method not in allowed:
		return
	match method:
		"hello":
			if state != State.ROOM or args.size()!=3 or args[0]!=1 or not args[1] is String or not integer(args[2],0,game.player.NAMES.size()-1):
				return
			if clean_name(args[1]).is_empty():
				return
			remote_name = clean_name(args[1])
			remote_fighter = int(args[2])
			state = State.OFFER
			timeout = 45
			message = remote_name + " quiere combatir contigo."
			show_lobby()
		"begin":
			if args.size()!=4 or not integer(args[0],1,1000000) or not integer(args[1],0,5) or not integer(args[2],0,5) or not args[3] is String:
				return
			begin(int(args[0]),int(args[1]),int(args[2]),args[3])
		"controls":
			if args.size()!=3 or not integer(args[0],1,1000000) or not integer(args[1],-1,1) or not args[2] is bool:
				return
			controls(int(args[0]),int(args[1]),args[2])
		"attack_key":
			if args.size()!=2 or not integer(args[0],1,1000000) or not integer(args[1],2,3):
				return
			attack_key(int(args[0]),int(args[1]))
		"frame":
			if args.size()!=5 or not integer(args[0],1,1000000) or not integer(args[1],0,6) or not scalar(args[2],0,60) or not fighter_packet(args[3]) or not fighter_packet(args[4]):
				return
			frame(int(args[0]),int(args[1]),float(args[2]),PackedFloat32Array(args[3]),PackedFloat32Array(args[4]))
		"contact_fx":
			if args.size()!=5 or not integer(args[0],1,1000000) or not args[1] is Array or args[1].size()!=3 or not args[2] is bool or not integer(args[3],-1,1) or not integer(args[4],2,3):
				return
			for component in args[1]:
				if not scalar(component,-10,10): return
			contact_fx(int(args[0]),Vector3(args[1][0],args[1][1],args[1][2]),args[2],int(args[3]),int(args[4]))
		"impact":
			if args.size()!=4 or not integer(args[0],1,1000000) or not args[1] is String or not args[2] is String or args[2].length()>32 or not args[3] is bool:
				return
			impact(int(args[0]),args[1],args[2],args[3])
		"finish":
			if args.size()!=4 or not integer(args[0],1,1000000) or not integer(args[1],0,100) or not integer(args[2],0,100) or not scalar(args[3],0,60):
				return
			finish(int(args[0]),int(args[1]),int(args[2]),float(args[3]))
		"want_replay":
			if args.size()!=1 or not integer(args[0],1,1000000):
				return
			want_replay(int(args[0]))
		"declined":
			if not args.is_empty(): return
			declined()
		"ping":
			if args.size()!=1 or not integer(args[0],1,1000000) or int(args[0])!=round_id:
				return
	packet_age = 0.0
