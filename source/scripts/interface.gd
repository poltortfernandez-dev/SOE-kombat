extends CanvasLayer

const IVORY := Color("#f7efdb")
const GOLD := Color("#ffc568")
const INK := Color("#130f12")
const RED := Color("#a42622")
const DIM := Color("#c9c0af")
const BLUE := Color("#9cd6de")
const BAR_WIDTH := 469.0
const RIGHT_BAR_END := 1181.0
const STYLES := ["Ronin de bronce", "Samurái de marfil", "Guerrero carmesí", "Guardián del bosque", "Viajero índigo", "Guardián de jade"]
var base: Control
var selector_open := false
var headline := FontVariation.new()

func _init() -> void:
	headline.base_font = SANS
	headline.variation_embolden = 1.2
	headline.variation_transform = Transform2D(Vector2(0.94,0),Vector2(0,1),Vector2.ZERO)
const SANS := preload("res://art/fonts/Barlow-Medium.ttf")
var health: Array[ColorRect] = []
var hp_text: Array[Label] = []
var clock_label: Label
var notice: Label
var feedback: Array[Label] = []
var flash_time := [0.0,0.0]
var notice_time := 0.0
var combo_labels: Array[Label] = []
var combo_timers := [0.0,0.0]
var damage_bars: Array[ColorRect] = []
var health_targets := [100.0,100.0]

func clear() -> void:
	selector_open = false
	if base:
		remove_child(base)
		base.queue_free()
	base = Control.new()
	add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.clear()
	hp_text.clear()
	feedback.clear()
	combo_labels.clear()
	damage_bars.clear()

func rect(x: float, y: float, w: float, h: float, color: Color) -> ColorRect:
	var item := ColorRect.new()
	item.color = color
	item.position = Vector2(x,y)
	item.size = Vector2(w,h)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(item)
	return item

func plate(points: PackedVector2Array, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	base.add_child(shape)

func shade(horizontal: bool, dark: Color, light: Color, region: Rect2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([dark, light])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_to = Vector2.RIGHT if horizontal else Vector2.DOWN
	var panel := TextureRect.new()
	panel.texture = tex
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.position = region.position
	panel.size = region.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(panel)

func label(value: String, x: float, y: float, w: float, h: float, pt: int, color: Color = IVORY, serif := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var item := Label.new()
	item.text = value
	item.position = Vector2(x,y)
	item.size = Vector2(w,h)
	item.add_theme_font_override("font",headline if serif else SANS)
	item.add_theme_font_size_override("font_size",pt)
	item.add_theme_color_override("font_color",color)
	item.horizontal_alignment = alignment
	item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(item)
	return item

func style(fill: Color, stroke: Color, width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(width)
	return box

func button(value: String, x: int, y: int, w: int, h: int, action: Callable, active := false, main := false) -> Button:
	var item := Button.new()
	item.text = value
	item.position = Vector2(x,y)
	item.size = Vector2(w,h)
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.add_theme_font_override("font",SANS)
	item.add_theme_font_size_override("font_size",19 if main else 17)
	var fill := RED if main else (Color("#643623") if active else Color("#242025"))
	item.add_theme_stylebox_override("normal",style(fill,GOLD if active else Color("#65645a")))
	item.add_theme_stylebox_override("hover",style(fill.lightened(0.12),GOLD))
	item.add_theme_stylebox_override("pressed",style(RED,GOLD))
	item.add_theme_stylebox_override("disabled",style(Color("#141820"),Color("#514c4b")))
	var focus := style(Color.TRANSPARENT,IVORY,2)
	focus.draw_center = false
	item.add_theme_stylebox_override("focus",focus)
	item.add_theme_color_override("font_color",IVORY)
	item.pressed.connect(action)
	base.add_child(item)
	return item

func pick_level(game, index: int) -> void:
	game.level = index
	menu(game)

var editing_rival := false
var portraits := {}

func set_slot(game, rival: bool) -> void:
	editing_rival = rival
	menu(game)

func portrait(id: int) -> Texture2D:
	if portraits.has(id):
		return portraits[id]
	var rig_script = preload("res://scripts/classic_fighter.gd")
	portraits[id] = load("res://art/classic/portraits/%s.png" % rig_script.SHEETS[id])
	return portraits[id]

func portrait_rect(parent: Node, id: int, origin: Vector2, extent: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = portrait(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.position = origin
	pic.size = extent
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(pic)
	return pic

func menu(game) -> void:
	var keep_position := Vector2(-1,-1)
	if selector_open:
		var previous := base.get_viewport().gui_get_focus_owner()
		if previous is Button and previous.get_parent() == base:
			keep_position = previous.position
	clear()
	selector_open = true
	shade(false,Color("#0b0b0cdd"),Color.TRANSPARENT,Rect2(0,0,1280,125))
	shade(true,Color("#120a08d9"),Color.TRANSPARENT,Rect2(0,0,370,500))
	shade(true,Color.TRANSPARENT,Color("#0c1114d9"),Rect2(910,0,370,500))
	label("MORO KOMBAT",40,18,360,40,31,GOLD,true)
	label("SELECCIONA LUCHADORES",850,24,388,28,15,DIM,false,HORIZONTAL_ALIGNMENT_RIGHT)
	label("VS",596,230,88,58,42,GOLD,true,HORIZONTAL_ALIGNMENT_CENTER)
	var fighters: Array = [game.chosen,game.opponent_choice]
	for i in 2:
		var x := 48 if i == 0 else 844
		var identity: int = fighters[i]
		var active := (i == 1) == editing_rival
		var accent := GOLD if i == 0 else BLUE
		var align := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var slot := button("",x,423,388,63,set_slot.bind(game,i == 1),active)
		slot.add_theme_stylebox_override("normal",style(Color(0.03,0.025,0.025,.35),accent if active else Color.TRANSPARENT))
		slot.accessibility_name = ("Elegir tu luchador" if i == 0 else "Elegir rival") + ", " + game.player.NAMES[identity]
		label("TÚ" if i == 0 else "RIVAL / CPU",x+12,426,364,18,13,accent,false,align)
		label(game.player.NAMES[identity].to_upper(),x+12,443,364,39,31,IVORY,true,align)
	shade(false,Color.TRANSPARENT,Color("#09090af5"),Rect2(0,480,1280,240))
	var count: int = game.player.NAMES.size()
	var step := 102
	var card_width := 96
	var origin := (1280-count*step+6)/2
	for i in count:
		var x := origin+i*step
		var selected: bool = i == game.chosen or i == game.opponent_choice
		var accent := GOLD if i == game.chosen else BLUE
		var pick: Callable = game.choose_cpu.bind(i) if editing_rival else game.choose.bind(i)
		var item := button("",x,501,card_width,122,pick,selected)
		item.add_theme_stylebox_override("normal",style(Color("#151416"),accent if selected else Color("#6f6252"),2 if selected else 1))
		item.add_theme_stylebox_override("disabled",style(Color("#151416"),accent,2))
		item.accessibility_name = game.player.NAMES[i]
		portrait_rect(item,i,Vector2(3,3),Vector2(card_width-6,91))
		label(game.player.NAMES[i].to_upper(),x,596,card_width,25,15,accent if selected else IVORY,true,HORIZONTAL_ALIGNMENT_CENTER)
		if selected:
			rect(x,498,card_width,3,accent)
			label("P1" if i == game.chosen else "CPU",x+card_width-36,501,32,21,12,INK,true,HORIZONTAL_ALIGNMENT_CENTER)
		item.tooltip_text = game.player.NAMES[i] + " · " + STYLES[i]
		item.disabled = i == (game.chosen if editing_rival else game.opponent_choice)
	label("DIFICULTAD",46,647,100,33,13,DIM)
	for i in 3:
		button(game.LEVELS[i],154+i*109,644,103,39,pick_level.bind(game,i),i == game.level)
	button("Online por código" if OS.has_feature("web") else "Multijugador y amigos",524,644,270,42,game.net.lobby)
	var next_focus := button("KOMBATIR",974,640,261,48,game.start_match,false,true)
	label("Elige TÚ o RIVAL y pulsa un retrato",370,686,540,23,14,DIM,false,HORIZONTAL_ALIGNMENT_CENTER)
	for control in base.get_children():
		if control is Button and control.position == keep_position and not control.disabled:
			next_focus = control
			break
	next_focus.grab_focus()

func hud(game) -> void:
	clear()
	shade(false,Color("#21171add"),Color.TRANSPARENT,Rect2(0,0,1280,144))
	for i in 2:
		var left := i == 0
		var accent := GOLD if left else BLUE
		var x := 99 if left else 712
		var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		var f = game.player if left else game.cpu
		var side: String = "JUGADOR" if left else "CPU   /   " + game.LEVELS[game.level].to_upper()
		if game.online():
			var mine: bool = left == game.net.hosting
			side = "TÚ   /   " + game.net.nickname if mine else game.net.remote_name
		var corner := 28 if left else 1252
		var direction := 1 if left else -1
		plate([Vector2(corner,18),Vector2(corner+direction*551,18),Vector2(corner+direction*537,82),Vector2(corner,82)],Color("#1b171aeb"))
		var photo_x := 32 if left else 1188
		rect(photo_x-2,16,64,69,Color("#755d43") if left else Color("#54666b"))
		rect(photo_x,18,60,65,Color("#252025"))
		portrait_rect(base,f.identity,Vector2(photo_x,18),Vector2(60,65))
		label(side,x,17,BAR_WIDTH,17,13,accent,false,align)
		label(f.NAMES[f.identity].to_upper(),x,33,BAR_WIDTH,31,28,IVORY,true,align)
		rect(x-1,66,BAR_WIDTH+2,14,Color("#705743"))
		rect(x,67,BAR_WIDTH,12,Color("#32252b"))
		damage_bars.append(rect(x,67,BAR_WIDTH,12,Color("#ae4733")))
		health.append(rect(x,67,BAR_WIDTH,12,accent))
		for mark in range(1,4):
			rect(x+roundf(BAR_WIDTH*mark/4.),67,1,12,Color("#1c141866"))
		health_targets[i]=100
		var hp_align := HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		hp_text.append(label("100",x,30,BAR_WIDTH,35,18,IVORY,false,hp_align))
		combo_labels.append(label("",x,88,BAR_WIDTH,36,27,GOLD,true,align))
		combo_labels[i].add_theme_constant_override("outline_size",3)
		combo_labels[i].add_theme_color_override("font_outline_color",INK)
		combo_timers[i]=0
		feedback.append(label("",x,87,BAR_WIDTH,31,20,IVORY,true,hp_align))
		feedback[i].add_theme_constant_override("outline_size",3)
		feedback[i].add_theme_color_override("font_outline_color",INK)
		flash_time[i]=0
	plate([Vector2(574,15),Vector2(706,15),Vector2(685,82),Vector2(595,82)],Color("#a77e4d"))
	plate([Vector2(577,17),Vector2(703,17),Vector2(683,79),Vector2(597,79)],INK)
	clock_label = label("60",596,15,88,61,46,IVORY,true,HORIZONTAL_ALIGNMENT_CENTER)
	notice = label("",0,140,1280,90,54,IVORY,true,HORIZONTAL_ALIGNMENT_CENTER)
	notice.add_theme_color_override("font_shadow_color", Color("#31231c"))
	notice.add_theme_constant_override("shadow_offset_y",2)
	shade(false,Color.TRANSPARENT,Color(0.035,0.05,0.04,0.93),Rect2(0,645,1280,75))
	label("A / D   Desplazarse       J   Puño       K   Patada       Mantén L o espacio   Bloqueo       Esc   " + ("Salir del duelo" if game.online() else "Pausa"),0,665,1280,47,18,IVORY,false,HORIZONTAL_ALIGNMENT_CENTER)

func announce(value: String, duration := 2.0) -> void:
	notice.text = value
	notice_time = duration

func advance(dt: float) -> void:
	notice_time -= dt
	for i in combo_labels.size():
		combo_timers[i]=maxf(0,combo_timers[i]-dt)
		combo_labels[i].modulate.a=clampf(combo_timers[i]*3,0,1)
		var target_width: float=health_targets[i]*BAR_WIDTH/100.
		damage_bars[i].size.x=move_toward(damage_bars[i].size.x,target_width,dt*130)
		if i==1:damage_bars[i].position.x=RIGHT_BAR_END-damage_bars[i].size.x
	if notice_time <= 0:
		notice.text = ""
	for i in 2:
		flash_time[i] -= dt
		feedback[i].modulate.a = clampf(flash_time[i]*5,0,1)

func combo_hit(count: int,left: bool) -> void:
	var side:=0 if left else 1
	if side>=combo_labels.size():return
	combo_labels[side].text="%d GOLPES" % count
	combo_timers[side]=1.4

func signal_hit(value: String, left: bool) -> void:
	var i := 0 if left else 1
	feedback[i].text = value
	flash_time[i] = 0.48
	feedback[i].modulate.a = 1

func update_hud(game) -> void:
	clock_label.text = str(ceili(game.time_left))
	for i in 2:
		var hp: int = game.player.life if i == 0 else game.cpu.life
		health_targets[i]=hp
		health[i].size.x = BAR_WIDTH * hp / 100
		if i == 1:
			health[i].position.x = RIGHT_BAR_END - health[i].size.x
		hp_text[i].text = str(hp)

func dialog(title: String, detail: String) -> void:
	clear()
	rect(0,0,1280,720,Color(0.045,0.06,0.05,0.63))
	rect(382,182,516,356,INK)
	rect(382,182,516,3,GOLD)
	label(detail,402,214,476,40,17,GOLD,false,HORIZONTAL_ALIGNMENT_CENTER)
	label(title,402,259,476,79,54,IVORY,true,HORIZONTAL_ALIGNMENT_CENTER)

func pause_menu(game) -> void:
	dialog("Pausa","DOJO DE LA NIEBLA")
	button("Continuar",460,355,360,54,game.toggle_pause,false,true).grab_focus()
	button("Volver a la selección",460,425,360,45,game.menu)

func end_screen(game, title: String, reason: String) -> void:
	dialog(title.to_upper(), reason + "   ·   " + str(game.player.life) + "  /  " + str(game.cpu.life) + " PV")
	if game.online():
		var replay := button("Esperando al rival…" if game.net.own_ready else "Pedir revancha",460,355,360,54,game.net.replay,false,true)
		replay.disabled = game.net.own_ready
		button("Volver a la sala",460,425,360,45,game.net.lobby)
		return
	button("Revancha",460,355,360,54,game.start_match,false,true).grab_focus()
	button("Cambiar luchador o dificultad",460,425,360,45,game.menu)

func field(value: String, hint: String, x: int, y: int, width: int, limit: int) -> LineEdit:
	var text_box := LineEdit.new()
	text_box.position = Vector2(x,y)
	text_box.size = Vector2(width,42)
	text_box.max_length = limit
	text_box.placeholder_text = hint
	text_box.text = value
	base.add_child(text_box)
	return text_box

func online_lobby(game) -> void:
	clear()
	var net = game.net
	rect(64,38,1152,645,Color("#181e1b"))
	rect(64,38,1152,4,GOLD)
	label("SALA DE AMIGOS",98,60,760,62,39,IVORY,true)
	button("Volver al dojo",986,66,194,42,game.menu)
	var status := label(net.message,98,568,1080,90,18,GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if net.state == net.State.ROOM:
		label("Código de tu sala",100,156,820,50,32,IVORY,true)
		var code := field(net.room_code,"",100,224,805,120)
		code.editable = false
		button("Copiar código",925,224,250,44,func():
			DisplayServer.clipboard_set(net.room_code)
			status.text = "Código copiado. Envíalo por tu chat habitual.")
		button("Cerrar sala",100,330,250,48,net.lobby)
		return
	if net.state != net.State.LOBBY:
		label(net.message,100,170,1060,90,29,IVORY,true)
		status.text = ""
		if net.state == net.State.OFFER:
			button("Aceptar combate",100,292,270,50,net.accept,false,true).grab_focus()
			if not net.via_code:
				button("Aceptar y guardar amigo",390,292,340,50,net.accept.bind(true))
			button("Rechazar",750,292,195,50,net.decline)
		else:
			button("Cancelar invitación",100,292,270,50,net.lobby)
		return
	if not net.direct_tab:
		label("Jugar con un código",100,150,680,52,34,IVORY,true)
		label("Tu nombre",100,225,320,26,16,GOLD)
		var alias_box := field(net.nickname,"Nombre de jugador",100,258,400,24)
		button("Crear sala",100,337,400,54,func(): net.create_room(alias_box.text),false,true)
		label("Comparte el código que aparecerá aquí.",100,399,440,40,17,DIM)
		label("Código de tu compañero",620,225,520,26,16,GOLD)
		var entry := field("","MK-XXXXXX-XXXXXX" if OS.has_feature("web") else "Pega el código DOJO3…",620,258,550,120)
		button("Unirme a la sala",620,337,550,54,func(): net.join_room(entry.text,alias_box.text))
		if OS.has_feature("web"):
			label("Elegid personaje antes de entrar. Mantened ambas pestañas abiertas.",100,453,1080,35,17,DIM)
			label("Conexión directa WebRTC · Servicio de salas gratuito de PeerJS",100,493,1080,35,16,DIM)
		else:
			label("La sala usa una conexión temporal gratuita de Cloudflare.",100,480,760,42,17,DIM)
			button("Amigos y conexión directa",770,487,400,46,net.select_tab.bind(true))
		return
	button("Salas con código",770,67,200,41,net.select_tab.bind(false))
	label("Mi tarjeta de jugador",99,119,490,44,29,IVORY,true)
	label("Nombre",100,167,190,22,13,DIM)
	label("IP para recibir invitaciones",300,167,272,22,13,DIM)
	var nick := field(net.nickname,"Tu nombre",100,190,190,24)
	var ip := field(net.address,"IP pública, local o de VPN",300,190,272,64)
	button("Copiar mi tarjeta",100,246,472,44,func():
		if net.set_profile(nick.text,ip.text):
			DisplayServer.clipboard_set(net.card())
			net.message = "Tarjeta copiada. Compártela con tu compañero."
		status.text = net.message)
	label("En la misma wifi, usa tu IP local. Por internet, usa tu IP\npública con UDP %d redirigido, o la IP de tu VPN.\nPermanece en esta sala para recibir invitaciones." % net.port,100,305,493,102,16,DIM)
	label("Añadir un amigo",100,430,480,40,26,IVORY,true)
	var incoming := field("","Pega la tarjeta DOJO2 de tu compañero",100,484,367,180)
	button("Guardar",475,484,98,42,func(): net.add_friend(incoming.text))
	label("Mis amigos",637,133,500,48,29,IVORY,true)
	var list := ItemList.new()
	list.position = Vector2(638,190)
	list.size = Vector2(540,250)
	var ids: Array = net.friends.keys()
	for id in ids:
		var parts = net.parse_card(net.friends[id])
		list.add_item(parts[1] if not parts.is_empty() else "Tarjeta inválida")
	base.add_child(list)
	if not ids.is_empty():
		list.select(0)
	else:
		label("Guarda una tarjeta para invitar a tu primer amigo.",654,208,515,46,17,DIM)
	var challenge := button("Invitar a combatir",638,466,308,48,func():
		if list.is_anything_selected():
			if net.set_profile(nick.text,ip.text):
				net.invite(ids[list.get_selected_items()[0]])
			else:
				status.text = net.message,false,true)
	var remove := button("Quitar de la lista",960,466,216,48,func():
		if list.is_anything_selected():
			net.forget(ids[list.get_selected_items()[0]]))
	challenge.disabled = ids.is_empty()
	remove.disabled = ids.is_empty()
