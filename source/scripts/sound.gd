extends Node

var voices: Array[AudioStreamPlayer] = []
var sounds := {}
var slot := 0

func _ready() -> void:
	for i in 8:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for kind in ["puño", "patada", "guardia", "aire", "campana"]:
		sounds[kind] = synth(kind)

func play(kind: String) -> void:
	var voice := voices[slot]
	slot = (slot + 1) % voices.size()
	voice.stream = sounds[kind]
	voice.volume_db = -12 if kind=="aire" else -8
	voice.pitch_scale = randf_range(.93,1.07) if kind!="campana" else 1.0
	voice.play()

func synth(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var length := 1.45 if kind == "campana" else (0.34 if kind=="patada" else 0.25)
	var bytes := PackedByteArray()
	var count := int(length * rate)
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 341
	var filtered := 0.0
	var previous := 0.0
	for i in count:
		var t := float(i) / rate
		var grit := noise.randf_range(-1,1)
		var high_pass := grit - previous
		previous = grit
		filtered = lerpf(filtered, grit, 0.35)
		var wave := 0.0
		match kind:
			"campana":
				wave = (sin(TAU*196*t)*exp(-2.5*t)+.45*sin(TAU*589*t)*exp(-4*t)+.23*sin(TAU*1357*t)*exp(-6*t))*.48
			"aire":
				wave = filtered*sin(PI*t/length)*(.42+.16*sin(TAU*60*t))
			"guardia":
				wave = .43 * high_pass * exp(-64*t) + .49*sin(TAU*243*t)*exp(-43*t) + .18*filtered*exp(-17*t)
			_:
				var kick := kind == "patada"
				var base := 53 if kick else 83
				var low := sin(TAU*base*t+7.*(1.-exp(-42.*t)))
				var cloth := filtered * exp(-16*t)
				var slap := .38*high_pass*exp(-85*t)
				wave = .70*low*exp(-(20 if kick else 30)*t) + slap + .47*cloth
		bytes.encode_s16(i*2, int(clampf(wave * minf(1,t*480),-1,1) * 30000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
