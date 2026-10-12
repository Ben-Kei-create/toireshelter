extends Node3D
## 環境音（音声ファイルなし。起動時にコードで波形を作る）。どれも小さな音で、操作や判定には関わらない。
##   換気扇の低い唸り … 換気口（浴槽の上、天井の左奥）から。3D 音で、浴室を出ると遠のく
##   蛇口のしずく     … 浴槽の蛇口から 5〜11 秒おきに1滴。蛇口が出ている間は鳴らさない
##   遠くの路地       … ベランダの外の路地から、さわさわとした人通りの気配（ごく小さく）
## 一時停止中は Room ごと止まる（節点は Room の子）。

const MIX_RATE := 22050
const VENT_POS := Vector3(-0.72, 2.1, -1.02)
const DRIP_POS := Vector3(0.55, 0.62, -1.13)
const ALLEY_POS := Vector3(2.5, 1.0, -4.5)

var _drip: AudioStreamPlayer3D
var _next := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260
	_add_loop("VentHum", _hum(), VENT_POS, -40.0, 1.5, 4.0)   # 換気扇：ブーという単音ではなく、ごく小さな空気の流れの音
	_add_loop("AlleyMurmur", _murmur(), ALLEY_POS, -32.0, 4.0, 14.0)
	_drip = AudioStreamPlayer3D.new()
	_drip.name = "Drip"
	_drip.stream = _drip_wave()
	_drip.position = DRIP_POS
	_drip.volume_db = -20.0
	_drip.unit_size = 1.5
	_drip.max_distance = 5.0
	add_child(_drip)


func _process(delta: float) -> void:
	_next -= delta
	if _next > 0.0:
		return
	_next = _rng.randf_range(5.0, 11.0)
	var room := get_parent()
	var tub: Object = room.get("bathtub") if room else null
	if tub and tub.get("faucet") and tub.faucet.is_on:
		return
	_drip.pitch_scale = _rng.randf_range(0.9, 1.15)
	_drip.play()


func _add_loop(node_name: String, stream: AudioStreamWAV, pos: Vector3, db: float, unit: float, max_d: float) -> void:
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = stream
	p.position = pos
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_d
	p.autoplay = true
	add_child(p)


func _wave(samples: PackedFloat32Array, loop: bool, mix_rate := MIX_RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = mix_rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## 換気扇の空気の音：低い単音（ブー）にならないよう、100〜600Hz の整数 Hz の正弦をたくさん重ねた「ふぅ」という柔らかい流れ。2 秒の周期波形。
func _hum() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var parts := []
	for k in 36:
		var f := float(_rng.randi_range(100, 600))
		parts.append([f, _rng.randf() * TAU, 1.0 / sqrt(f / 100.0), float(_rng.randi_range(1, 3))])
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for p in parts:
			v += (0.65 + 0.35 * sin(TAU * 0.5 * t * p[3] + p[1])) * p[2] * sin(TAU * p[0] * t + p[1])
		s[i] = v * 0.03
	return _wave(s, true, rate)


## 2 秒の周期波形。整数 Hz の正弦をたくさん重ねた、さわさわした雑音（高い音ほど弱く）。
func _murmur() -> AudioStreamWAV:
	var rate := 11025
	var n := rate * 2
	var s := PackedFloat32Array()
	s.resize(n)
	var parts := []
	for k in 48:
		var f := float(_rng.randi_range(120, 2400))
		parts.append([f, _rng.randf() * TAU, 1.0 / sqrt(f / 120.0), _rng.randf_range(0.2, 1.2)])
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for p in parts:
			# 各成分をゆっくり強弱させる（整数 Hz×0.5 の周期なので 2 秒でつながる）
			var env := 0.6 + 0.4 * sin(TAU * 0.5 * t * round(p[3] * 2.0) + p[1])
			v += env * p[2] * sin(TAU * p[0] * t + p[1])
		s[i] = v * 0.045
	return _wave(s, true, rate)


func _drip_wave() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * (700.0 + 1500.0 * exp(-t * 45.0)) / MIX_RATE
		var echo := 0.0
		if t > 0.11:
			echo = 0.3 * exp(-(t - 0.11) * 30.0) * sin(phase * 0.8)
		s[i] = 0.7 * exp(-t * 22.0) * sin(phase) + echo
	return _wave(s, false)
