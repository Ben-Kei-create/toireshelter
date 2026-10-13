extends Node3D
## 古いラジオ（窓の下の小さな丸椅子の上）。左クリックでつけて、もう一度ごとにチャンネルが変わり、最後に消える。
## 音はぜんぶコードで作る（ゆったりしたコード・ピアノ風の小曲・言葉にならない話し声のニュース・時報）。最初に選んだときに作る。
## 原点は椅子の脚元の床。向きは +z（部屋側）。音は 3D（ラジオの位置から）で、バスは Ambient。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

const CENTER := Vector3(3.6, 0.0, -0.9)
const STOOL_H := 0.36
const MIX := 22050
const LOOP := 8.0
const CHANNELS := ["chords", "piano", "news", "pips"]

var channel := -1               # -1 は消えている
var _player: AudioStreamPlayer3D
var _lamp_mat: StandardMaterial3D
var _needle: Node3D
var _waves := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = CENTER
	MeshKit.auto_round = false
	var wood := MeshKit.mat("radio_wood", Color(0.45, 0.3, 0.18), 0.6)
	var stool := MeshKit.mat("radio_stool", Color(0.75, 0.6, 0.4), 0.7)
	MeshKit.cylinder(self, 0.16, 0.025, Vector3(0, STOOL_H - 0.0125, 0), stool, "StoolSeat")
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var leg := MeshKit.cylinder(self, 0.014, STOOL_H, Vector3(cos(a) * 0.11, STOOL_H * 0.5, sin(a) * 0.11), stool, "StoolLeg")
		leg.rotation = Vector3(-sin(a) * 0.12, 0, cos(a) * 0.12)
	var y := STOOL_H
	MeshKit.box(self, Vector3(0.28, 0.17, 0.11), Vector3(0, y + 0.085, 0), wood, "Body")
	# スピーカー（左）と目盛り（右）
	var grill := MeshKit.mat("radio_grill", Color(0.2, 0.15, 0.1), 0.9)
	MeshKit.box(self, Vector3(0.11, 0.12, 0.004), Vector3(-0.075, y + 0.085, 0.057), grill, "Grill")
	for k in 6:
		MeshKit.box(self, Vector3(0.1, 0.002, 0.002), Vector3(-0.075, y + 0.04 + k * 0.016, 0.0595), MeshKit.mat("radio_grill_line", Color(0.55, 0.45, 0.3), 0.6), "GrillLine")
	var dial := MeshKit.mat("radio_dial", Color(0.92, 0.88, 0.7), 0.5)
	MeshKit.box(self, Vector3(0.1, 0.04, 0.003), Vector3(0.06, y + 0.12, 0.057), dial, "Dial")
	_needle = Node3D.new()
	_needle.position = Vector3(0.06, y + 0.12, 0.0595)
	add_child(_needle)
	MeshKit.box(_needle, Vector3(0.002, 0.036, 0.001), Vector3.ZERO, MeshKit.mat("radio_needle", Color(0.85, 0.15, 0.1), 0.4), "Needle")
	_needle.position.x = 0.02
	var knob := MeshKit.mat("radio_knob", Color(0.1, 0.1, 0.1), 0.4)
	for kx in [0.035, 0.09]:
		MeshKit.cylinder(self, 0.016, 0.014, Vector3(kx, y + 0.055, 0.062), knob, "Knob").rotation.x = PI * 0.5
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.3, 0.12, 0.05)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.55, 0.15)
	_lamp_mat.emission_energy_multiplier = 0.0
	MeshKit.sphere(self, 0.006, Vector3(0.115, y + 0.14, 0.058), _lamp_mat)
	# アンテナ
	var ant := MeshKit.cylinder(self, 0.0025, 0.3, Vector3(0.1, y + 0.17 + 0.1, -0.03), MeshKit.mat("radio_ant", Color(0.75, 0.75, 0.78), 0.3, 0.8), "Antenna")
	ant.rotation.z = -0.3
	_player = AudioStreamPlayer3D.new()
	_player.name = "Sound"
	_player.bus = "Ambient"
	_player.position = Vector3(0, y + 0.1, 0.05)
	_player.unit_size = 2.0
	_player.max_distance = 9.0
	_player.volume_db = -8.0
	add_child(_player)
	var a2 := MeshKit.interact_area(self, "RadioArea", "radio", self)
	MeshKit.shape_box(a2, Vector3(0.34, 0.5, 0.2), Vector3(0, y + 0.2, 0))
	MeshKit.auto_round = true


func get_prompt(_id: String) -> String:
	return "radio_on" if channel < 0 else "radio_next"


## つける → 次のチャンネル → ……最後に消える。
func interact(_id: String) -> String:
	channel += 1
	if channel >= CHANNELS.size():
		channel = -1
		_player.stop()
		_lamp_mat.emission_energy_multiplier = 0.0
		_needle.position.x = 0.02
		Sfx.play("click", 0.8)
		return "radio_off"
	Sfx.play("static")
	var name: String = CHANNELS[channel]
	if not _waves.has(name):
		_waves[name] = call("_make_" + name)
	_player.stream = _waves[name]
	_player.play()
	_lamp_mat.emission_energy_multiplier = 2.0
	_needle.position.x = 0.02 + 0.075 * channel / float(CHANNELS.size() - 1) * 0.9
	return "radio_ch%d" % (channel + 1)


func _wave(s: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = s.size()
	return w


func _buf() -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(MIX * LOOP))
	return s


## 全チャンネルにうっすら入る雑音（ラジオらしさ）。
func _hiss(s: PackedFloat32Array, amount: float) -> void:
	_rng.seed = 99
	var y := 0.0
	for i in s.size():
		y += 0.5 * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] += y * amount


## ゆったりしたコード：C△7 → Am7 → F△7 → G。2 秒ずつ。
func _make_chords() -> AudioStreamWAV:
	var s := _buf()
	var chords := [[261.6, 329.6, 392.0, 493.9], [220.0, 261.6, 329.6, 392.0], [174.6, 220.0, 261.6, 329.6], [196.0, 246.9, 293.7, 392.0]]
	for c in 4:
		for f in chords[c]:
			for i in int(MIX * 2.0):
				var t := float(i) / MIX
				var env := minf(1.0, t * 3.0) * minf(1.0, (2.0 - t) * 3.0)
				var idx := (c * int(MIX * 2.0) + i) % s.size()
				s[idx] += 0.07 * env * (sin(TAU * f * t) + 0.3 * sin(TAU * 2.0 * f * t))
	_hiss(s, 0.012)
	return _wave(s)


## ピアノ風の小曲：ペンタトニックの 16 音（0.5 秒ごと）。
func _make_piano() -> AudioStreamWAV:
	var s := _buf()
	var scale := [261.6, 293.7, 329.6, 392.0, 440.0, 523.3]
	var seq := [0, 2, 4, 3, 2, 1, 2, 0, 4, 5, 4, 3, 2, 3, 1, 0]
	for k in 16:
		var f: float = scale[seq[k]]
		for i in int(MIX * 1.2):
			var t := float(i) / MIX
			var idx := (int(k * 0.5 * MIX) + i) % s.size()
			s[idx] += 0.2 * exp(-t * 4.5) * (sin(TAU * f * t) + 0.4 * sin(TAU * 2.0 * f * t) * exp(-t * 3.0) + 0.15 * sin(TAU * 3.0 * f * t))
	_hiss(s, 0.015)
	return _wave(s)


## ニュースの話し声（言葉にならない抑揚）。
func _make_news() -> AudioStreamWAV:
	var s := _buf()
	_rng.seed = 321
	var t := 0.1
	var ph := 0.0
	var f0 := 130.0
	while t < LOOP - 0.5:
		var dur := _rng.randf_range(0.08, 0.2)
		var gap := _rng.randf_range(0.02, 0.1) + (0.5 if _rng.randf() < 0.12 else 0.0)
		f0 = clampf(f0 + _rng.randf_range(-25.0, 25.0), 100.0, 180.0)
		var i0 := int(t * MIX)
		var i1 := int((t + dur) * MIX)
		for i in range(i0, i1):
			var u := float(i - i0) / maxf(1.0, float(i1 - i0))
			ph += TAU * f0 * (1.0 + 0.08 * sin(u * 4.0)) / MIX
			s[i] += 0.3 * sin(PI * u) * (sin(ph) + 0.7 * sin(2.0 * ph) + 0.5 * sin(3.0 * ph) + 0.3 * sin(5.0 * ph))
		t += dur + gap
	_hiss(s, 0.03)
	return _wave(s)


## 時報：ピッ ピッ ピッ ポーン（8 秒周期）。
func _make_pips() -> AudioStreamWAV:
	var s := _buf()
	for k in 4:
		var f := 440.0 if k < 3 else 880.0
		var dur := 0.2 if k < 3 else 0.8
		for i in int(MIX * dur):
			var t := float(i) / MIX
			var idx := (int((2.0 + k) * MIX) + i) % s.size()
			s[idx] += 0.25 * sin(TAU * f * t) * minf(1.0, t * 100.0) * (1.0 if k < 3 else exp(-t * 3.0))
	_hiss(s, 0.02)
	return _wave(s)
