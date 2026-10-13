extends Node3D
## 環境音（音声ファイルなし。起動時にコードで波形を作る）。どれも小さな音で、操作や判定には関わらない。
##   換気扇の低い唸り … 換気口（浴槽の上、天井の左奥）から。3D 音で、浴室を出ると遠のく
##   蛇口のしずく     … 浴槽の蛇口から 5〜11 秒おきに1滴。蛇口が出ている間は鳴らさない
##   遠くの路地       … ベランダの外の路地から、さわさわとした人通りの気配（ごく小さく）
##   隣や上の部屋の生活音 … 壁ごしの低い足音・水道管・くぐもった話し声・遠いドアの音。ランダムに、夜（窓の光が弱いほど）は少し増える
## 一時停止中は Room ごと止まる（節点は Room の子）。

const MIX_RATE := 22050
const VENT_POS := Vector3(-0.72, 2.1, -1.02)
const DRIP_POS := Vector3(0.55, 0.62, -1.13)
const ALLEY_POS := Vector3(2.5, 1.0, -4.5)

const AudioSettings := preload("res://scripts/audio_settings.gd")
var _drip: AudioStreamPlayer3D
var _neighbor: AudioStreamPlayer3D
var _neighbor_waves := {}
var _neighbor_next := 20.0
var last_neighbor := ""   # 最後に鳴らした隣の音の種類（テスト用）
var _next := 4.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260
	_add_loop("VentHum", _hum(), VENT_POS, -50.0, 1.5, 3.0)   # 換気扇：ブーという単音ではなく、ごく小さな空気の流れの音
	_add_loop("AlleyMurmur", _murmur(), ALLEY_POS, -32.0, 4.0, 14.0)
	AudioSettings.ensure_buses()
	_drip = AudioStreamPlayer3D.new()
	_drip.bus = "Ambient"
	_drip.name = "Drip"
	_drip.stream = _drip_wave()
	_drip.position = DRIP_POS
	_drip.volume_db = -20.0
	_drip.unit_size = 1.5
	_drip.max_distance = 5.0
	add_child(_drip)
	_neighbor = AudioStreamPlayer3D.new()
	_neighbor.name = "Neighbor"
	_neighbor.bus = "Ambient"
	_neighbor.unit_size = 2.5
	_neighbor.max_distance = 12.0
	add_child(_neighbor)
	_neighbor_waves = {"thump": _thump(), "pipe": _pipe(), "voices": _voices(), "door": _far_door()}
	_neighbor_next = _rng.randf_range(12.0, 30.0)


func _process(delta: float) -> void:
	_neighbor_next -= delta
	if _neighbor_next <= 0.0:
		play_neighbor()
		var room := get_parent()
		var clk: Object = room.get("sky_clock") if room else null
		var night: float = 1.0 - (clk.daylight if clk else 1.0)   # 夜ほど短い間隔
		_neighbor_next = _rng.randf_range(35.0, 80.0) * (1.0 - 0.5 * clampf(night, 0.0, 1.0))
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
	p.bus = "Ambient"
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


## 隣や上の部屋の音を1つ鳴らす（kind が空ならランダム）。壁の外や天井の位置から、小さく。
func play_neighbor(kind := "") -> void:
	if kind.is_empty():
		kind = ["thump", "pipe", "voices", "door"][_rng.randi() % 4]
	last_neighbor = kind
	var pos := Vector3(_rng.randf_range(1.5, 5.0), 2.7, _rng.randf_range(-0.8, 1.8))   # 天井の上（上の階）
	if kind == "voices" or kind == "door":
		pos = Vector3(6.0, 1.3, _rng.randf_range(-0.8, 1.8))   # 東の壁の外（隣の部屋）
	_neighbor.global_position = pos
	_neighbor.stream = _neighbor_waves[kind]
	_neighbor.volume_db = -22.0 if kind != "voices" else -26.0
	_neighbor.play()


## 上の階の低い足音：2歩。
func _thump() -> AudioStreamWAV:
	var n := int(MIX_RATE * 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var nz := _lp_noise(n, 0.05)
	for step in 2:
		var t0 := 0.05 + step * 0.45
		for i in n:
			var t := float(i) / MIX_RATE - t0
			if t > 0.0:
				s[i] += 0.9 * sin(TAU * (70.0 - 20.0 * t) * t) * exp(-t * 14.0) + 0.5 * nz[i] * exp(-t * 18.0)
	return _wave(s, false)


## 壁の中の水道管：ゴボゴボとうなる音。
func _pipe() -> AudioStreamWAV:
	var n := int(MIX_RATE * 2.2)
	var s := PackedFloat32Array()
	s.resize(n)
	var nz := _lp_noise(n, 0.07)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := sin(PI * t / 2.2)
		s[i] = env * (0.6 * nz[i] * (0.5 + 0.5 * sin(TAU * 7.0 * t)) + 0.12 * sin(TAU * (110.0 + 25.0 * sin(TAU * 1.3 * t)) * t))
	return _wave(s, false)


## 隣の部屋のくぐもった話し声（言葉にならない抑揚だけ）。
func _voices() -> AudioStreamWAV:
	var n := int(MIX_RATE * 2.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var t := 0.0
	var ph := 0.0
	var f0 := 150.0
	while t < 2.5:
		var dur := _rng.randf_range(0.1, 0.22)
		var gap := _rng.randf_range(0.03, 0.12)
		f0 = clampf(f0 + _rng.randf_range(-30.0, 30.0), 110.0, 210.0)
		var i0 := int(t * MIX_RATE)
		var i1 := mini(n, int((t + dur) * MIX_RATE))
		for i in range(i0, i1):
			var u := float(i - i0) / maxf(1.0, float(i1 - i0))
			ph += TAU * f0 * (1.0 + 0.1 * sin(u * 3.0)) / MIX_RATE
			s[i] = 0.35 * sin(PI * u) * (sin(ph) + 0.6 * sin(2.0 * ph) + 0.35 * sin(3.0 * ph))
		t += dur + gap
	return _wave(s, false)


## 遠くでドアが閉まる音。
func _far_door() -> AudioStreamWAV:
	var n := int(MIX_RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var nz := _lp_noise(n, 0.04)
	for i in n:
		var t := float(i) / MIX_RATE
		s[i] = 0.8 * sin(TAU * (90.0 - 30.0 * t) * t) * exp(-t * 12.0) + 0.6 * nz[i] * exp(-t * 20.0)
	return _wave(s, false)


func _lp_noise(n: int, cutoff: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	for i in n:
		y += cutoff * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] = y * 3.0
	return s
