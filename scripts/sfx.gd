extends Node
## 効果音。音声ファイルがなくても鳴るよう、起動時にコードで波形を作る（生成 AI 不使用）。
## ほんものの音声ファイルに差し替えたいときは、assets/textures ではなく assets/audio/sfx/<名前>.ogg（または .wav / .mp3）を置くだけ。
## 同じ名前のファイルがあれば、そちらが優先される（コードの変更は要らない）。
##
## 名前：click（スイッチ・ボタン） thunk（ドアが閉まる） creak（ドアが開く） cloth（カーテン） slide（窓の開閉）
##       beep（エアコンのピッ） rustle（座る・こたつ） page（本のページ） pop（拾う） step（足音）
##       chime（クレーンゲームで取れた） buzz（外れた） clunk（アームがつかむ・景品が落ちる） flush（水を流す）
## 使い方：Sfx.play("click")、Sfx.play("step", 0.9, -6.0)（高さの倍率、音量 dB）。節点がなければ何もしない（テスト用）。

const AudioSettings := preload("res://scripts/audio_settings.gd")
const MIX := 22050
const NAMES := ["click", "thunk", "creak", "cloth", "slide", "beep", "rustle", "page", "pop", "step", "chime", "buzz", "clunk", "flush", "strum", "ring", "tick", "crack", "sizzle", "ignite", "static", "plop", "intercom"]
const MASTER_DB := -10.0

static var instance: Node

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


## 名前の音の波形（3D の音源に持たせる用）。節点がなければ null。
static func stream_for(sound: String) -> AudioStream:
	if instance and is_instance_valid(instance):
		return instance._streams.get(sound)
	return null


static func play(sound: String, pitch := 1.0, db := 0.0) -> void:
	if instance and is_instance_valid(instance):
		instance._play(sound, pitch, db)


func _ready() -> void:
	instance = self
	_rng.seed = 777
	for i in 8:
		var p := AudioStreamPlayer.new()
		AudioSettings.ensure_buses()
		p.bus = "SFX"
		p.volume_db = MASTER_DB
		add_child(p)
		_players.append(p)
	for n in NAMES:
		_streams[n] = _load_or_make(n)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _play(sound: String, pitch: float, db: float) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = MASTER_DB + db
	p.play()


func _load_or_make(n: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/audio/sfx/%s.%s" % [n, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return _wave(call("_make_" + n))


func _wave(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.data = bytes
	return w


# ---- 合成の部品

func _buf(seconds: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(MIX * seconds))
	return s


## ローパスをかけた雑音（cutoff が小さいほどこもる）
func _noise(n: int, cutoff: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(n)
	var a := clampf(cutoff, 0.001, 1.0)
	var y := 0.0
	for i in n:
		y += a * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] = y
	return s


func _make_click() -> PackedFloat32Array:
	var s := _buf(0.07)
	var nz := _noise(s.size(), 0.6)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.5 * nz[i] * exp(-t * 180.0) + 0.35 * sin(TAU * 1700.0 * t) * exp(-t * 120.0)
	return s


func _make_thunk() -> PackedFloat32Array:
	var s := _buf(0.3)
	var nz := _noise(s.size(), 0.08)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.9 * sin(TAU * (95.0 - 30.0 * t) * t) * exp(-t * 16.0) + 0.6 * nz[i] * exp(-t * 25.0)
	return s


func _make_creak() -> PackedFloat32Array:
	var s := _buf(0.7)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / MIX
		var f := 150.0 + 40.0 * sin(TAU * 5.0 * t) + 60.0 * t
		ph += TAU * f / MIX
		var env := sin(PI * t / 0.7)
		s[i] = 0.22 * env * (sin(ph) + 0.5 * sin(2.0 * ph) + 0.3 * sin(3.0 * ph))
	return s


func _make_cloth() -> PackedFloat32Array:
	var s := _buf(0.7)
	var nz := _noise(s.size(), 0.12)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 1.4 * nz[i] * sin(PI * t / 0.7) * (0.7 + 0.3 * sin(TAU * 7.0 * t))
	return s


func _make_slide() -> PackedFloat32Array:
	var s := _buf(0.8)
	var nz := _noise(s.size(), 0.05)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 1.6 * nz[i] * sin(PI * t / 0.8) + 0.12 * sin(TAU * (70.0 + 20.0 * t) * t) * sin(PI * t / 0.8)
	return s


func _make_beep() -> PackedFloat32Array:
	var s := _buf(0.16)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.4 * sin(TAU * 1760.0 * t) * minf(1.0, t * 200.0) * exp(-t * 14.0)
	return s


func _make_rustle() -> PackedFloat32Array:
	var s := _buf(0.5)
	var nz := _noise(s.size(), 0.2)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 1.2 * nz[i] * (sin(PI * t / 0.5) * (0.6 + 0.4 * sin(TAU * 11.0 * t)))
	return s


func _make_page() -> PackedFloat32Array:
	var s := _buf(0.18)
	var nz := _noise(s.size(), 0.4)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.9 * nz[i] * sin(PI * t / 0.18) * exp(-t * 6.0)
	return s


func _make_pop() -> PackedFloat32Array:
	var s := _buf(0.12)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / MIX
		ph += TAU * (500.0 + 900.0 * t / 0.12) / MIX
		s[i] = 0.5 * sin(ph) * exp(-t * 28.0)
	return s


func _make_step() -> PackedFloat32Array:
	var s := _buf(0.12)
	var nz := _noise(s.size(), 0.09)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 1.2 * nz[i] * exp(-t * 45.0) + 0.4 * sin(TAU * 70.0 * t) * exp(-t * 40.0)
	return s


func _make_chime() -> PackedFloat32Array:
	var s := _buf(0.9)
	for k in 3:
		var f: float = [784.0, 988.0, 1318.0][k]
		var t0 := k * 0.12
		for i in s.size():
			var t := float(i) / MIX - t0
			if t > 0.0:
				s[i] += 0.28 * sin(TAU * f * t) * exp(-t * 5.0)
	return s


func _make_buzz() -> PackedFloat32Array:
	var s := _buf(0.35)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.25 * sin(TAU * 140.0 * t) * sign(sin(TAU * 140.0 * t)) * exp(-t * 6.0) * (1.0 if t < 0.3 else 0.0)
	return s


func _make_clunk() -> PackedFloat32Array:
	var s := _buf(0.2)
	var nz := _noise(s.size(), 0.15)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.7 * sin(TAU * 210.0 * t) * exp(-t * 28.0) + 0.5 * nz[i] * exp(-t * 60.0)
	return s


func _make_strum() -> PackedFloat32Array:
	var s := _buf(1.6)
	var notes := [82.4, 110.0, 146.8, 196.0, 246.9, 329.6]   # 開放弦 E A D G B E
	for k in notes.size():
		var f: float = notes[k]
		var t0 := k * 0.035
		for i in s.size():
			var t := float(i) / MIX - t0
			if t > 0.0:
				s[i] += 0.12 * (sin(TAU * f * t) + 0.5 * sin(TAU * 2.0 * f * t) + 0.25 * sin(TAU * 3.0 * f * t)) * exp(-t * (2.2 + k * 0.25))
	return s


func _make_ring() -> PackedFloat32Array:
	var s := _buf(1.2)
	for i in s.size():
		var t := float(i) / MIX
		var gate := 1.0 if fmod(t, 0.5) < 0.33 else 0.0   # リリリン、リリリン
		var f := 1180.0 if fmod(t * 38.0, 2.0) < 1.0 else 1480.0
		s[i] = 0.25 * gate * sin(TAU * f * t) * (0.6 + 0.4 * sin(TAU * 30.0 * t))
	return s


func _make_flush() -> PackedFloat32Array:
	var s := _buf(1.6)
	var nz := _noise(s.size(), 0.22)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 1.1 * nz[i] * minf(1.0, t * 8.0) * exp(-pow(t / 1.1, 2.0) * 2.0) * (0.8 + 0.2 * sin(TAU * 6.0 * t))
	return s


func _make_tick() -> PackedFloat32Array:
	var s := _buf(0.07)
	var nz := _noise(s.size(), 0.5)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.5 * nz[i] * exp(-t * 220.0) + 0.3 * sin(TAU * 2600.0 * t) * exp(-t * 260.0)
	return s


func _make_crack() -> PackedFloat32Array:
	var s := _buf(0.22)
	var nz := _noise(s.size(), 0.7)
	var wet := _noise(s.size(), 0.1)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.8 * nz[i] * exp(-t * 150.0) + 0.7 * wet[i] * (exp(-pow((t - 0.08) / 0.05, 2.0)))
	return s


func _make_sizzle() -> PackedFloat32Array:
	var s := _buf(1.4)
	var nz := _noise(s.size(), 0.85)
	for i in s.size():
		var t := float(i) / MIX
		var crackle := 1.0 if _rng.randf() < 0.012 else 0.0
		s[i] = (0.35 * nz[i] * (0.5 + 0.5 * sin(PI * t / 1.4)) + 0.5 * crackle * _rng.randf_range(-1.0, 1.0)) * 0.9
	return s


func _make_ignite() -> PackedFloat32Array:
	var s := _buf(0.7)
	var nz := _noise(s.size(), 0.2)
	for i in s.size():
		var t := float(i) / MIX
		var tick := 0.0
		for k in 3:
			var tk := t - k * 0.11
			if tk > 0.0:
				tick += 0.5 * sin(TAU * 2200.0 * tk) * exp(-tk * 300.0)
		var whoomp := 0.0
		if t > 0.33:
			whoomp = 1.1 * nz[i] * minf(1.0, (t - 0.33) * 40.0) * exp(-(t - 0.33) * 7.0)
		s[i] = tick + whoomp
	return s


func _make_static() -> PackedFloat32Array:
	var s := _buf(0.4)
	var nz := _noise(s.size(), 0.9)
	for i in s.size():
		var t := float(i) / MIX
		s[i] = 0.5 * nz[i] * sin(PI * t / 0.4) * (0.7 + 0.3 * sin(TAU * 40.0 * t))
	return s


func _make_plop() -> PackedFloat32Array:
	var s := _buf(0.15)
	var ph := 0.0
	for i in s.size():
		var t := float(i) / MIX
		ph += TAU * (900.0 - 500.0 * t / 0.15) / MIX
		s[i] = 0.4 * sin(ph) * exp(-t * 30.0)
	return s


## インターホンの「ピンポーン」：高い音のあと、低い音が長く残る。
func _make_intercom() -> PackedFloat32Array:
	var s := _buf(1.4)
	for i in s.size():
		var t := float(i) / MIX
		var a := 0.45 * sin(TAU * 987.8 * t) * exp(-t * 6.0) * (1.0 if t < 0.45 else 0.0)
		var tb := t - 0.45
		var b := 0.0
		if tb > 0.0:
			b = 0.45 * (sin(TAU * 740.0 * tb) + 0.25 * sin(TAU * 1480.0 * tb)) * exp(-tb * 3.2)
		s[i] = a + b
	return s
