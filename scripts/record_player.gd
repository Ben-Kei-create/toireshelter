extends Node3D
## レコードプレーヤー（部屋の西の壁ぎわの低い台）と、その上の壁に飾ってあるレコード盤。
## 壁のレコード盤を拾って（8 番目までの持ち物）、プレーヤーの前で左クリックするとターンテーブルにのり、古いジャズが流れる。
## 音はぜんぶコードで作る（スイング、ウォーキングベース、ピアノのコンピング、ミュートのトランペット風の旋律、ライドシンバル、針のパチパチ）。最初に置いたときに作る。
## 原点は台の足元の床。向きは +z（部屋側）。音は 3D で、バスは Ambient。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal disc_set

const CENTER := Vector3(1.52, 0.0, 0.62)
const WALL_LOCAL_Z := -0.384         # 壁の面（ローカル z）。西の壁 x=1.136
const MIX := 16000
const BPM := 120.0
const BARS := 8

var holding := false                  # 壁のレコード盤を持っている（main が毎フレーム教える）
var loaded := false                   # ターンテーブルに盤がのっている
var playing := false
var display_taken := false
var _platter: Node3D
var _arm: Node3D
var _disc_on_platter: Node3D
var _display: Node3D
var _player: AudioStreamPlayer3D
var _wave_cache: AudioStreamWAV
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	position = CENTER
	rotation.y = PI * 0.5
	MeshKit.auto_round = false
	var wood := MeshKit.mat("rp_wood", Color(0.42, 0.27, 0.16), 0.6)
	var dark := MeshKit.mat("rp_dark", Color(0.1, 0.1, 0.11), 0.5)
	var metal := MeshKit.mat("rp_metal", Color(0.75, 0.75, 0.78), 0.3, 0.8)
	var cloth := MeshKit.mat("rp_cloth", Color(0.55, 0.4, 0.25), 0.95)
	# 台（脚つきの低い棚）：天板 0.5 × 0.42、高さ 0.52
	var top_y := 0.52
	MeshKit.box(self, Vector3(0.42, 0.03, 0.5), Vector3(0, top_y - 0.015, 0), wood, "Top")
	MeshKit.box(self, Vector3(0.40, 0.02, 0.48), Vector3(0, 0.22, 0), wood, "LowShelf")
	for sx in [-0.185, 0.185]:
		for sz in [-0.225, 0.225]:
			MeshKit.box(self, Vector3(0.03, top_y - 0.03, 0.03), Vector3(sx, (top_y - 0.03) * 0.5, sz), wood, "Leg")
	# 下の段に、レコードの入った箱（飾り）
	for k in 5:
		var sleeve := MeshKit.mat("rp_sleeve_%d" % k, [Color(0.7, 0.3, 0.25), Color(0.25, 0.4, 0.55), Color(0.85, 0.75, 0.4), Color(0.3, 0.3, 0.32), Color(0.5, 0.65, 0.5)][k], 0.8)
		MeshKit.box(self, Vector3(0.012, 0.26, 0.3), Vector3(-0.08 + k * 0.03, 0.36, 0.0), sleeve, "Sleeve")
	# ターンテーブル本体
	MeshKit.box(self, Vector3(0.38, 0.05, 0.44), Vector3(0, top_y + 0.025, 0.0), wood, "Plinth")
	MeshKit.box(self, Vector3(0.36, 0.006, 0.42), Vector3(0, top_y + 0.053, 0.0), dark, "PlinthTop")
	_platter = Node3D.new()
	_platter.name = "Platter"
	_platter.position = Vector3(-0.02, top_y + 0.056, 0.0)
	add_child(_platter)
	MeshKit.cylinder(_platter, 0.14, 0.012, Vector3(0, 0.006, 0), metal, "PlatterPlate")
	MeshKit.cylinder(_platter, 0.136, 0.003, Vector3(0, 0.0135, 0), MeshKit.mat("rp_mat", Color(0.12, 0.12, 0.13), 0.9), "Mat")
	MeshKit.cylinder(_platter, 0.004, 0.02, Vector3(0, 0.02, 0), metal, "Spindle")
	# ターンテーブルにのせた盤（置くまで隠す）
	_disc_on_platter = _make_disc(0.13)
	_disc_on_platter.position = Vector3(0, 0.0165, 0)
	_disc_on_platter.visible = false
	_platter.add_child(_disc_on_platter)
	# トーンアーム（右奥に支点）。止まっているときは外側、流れているときは盤の上
	_arm = Node3D.new()
	_arm.name = "ToneArm"
	_arm.position = Vector3(0.14, top_y + 0.085, -0.17)
	add_child(_arm)
	MeshKit.cylinder(self, 0.022, 0.03, Vector3(0.14, top_y + 0.07, -0.17), metal, "ArmBase")
	var arm_bar := MeshKit.cylinder(_arm, 0.003, 0.26, Vector3(0, 0, 0.13), metal, "ArmBar")
	arm_bar.rotation.x = PI * 0.5
	MeshKit.box(_arm, Vector3(0.016, 0.01, 0.03), Vector3(0, -0.003, 0.27), dark, "Head")
	MeshKit.cylinder(_arm, 0.01, 0.025, Vector3(0, 0, -0.03), dark, "Counterweight").rotation.x = PI * 0.5
	_set_arm(false)
	# つまみとスイッチ
	MeshKit.cylinder(self, 0.012, 0.012, Vector3(-0.15, top_y + 0.06, 0.2), metal, "Knob")
	MeshKit.cylinder(self, 0.012, 0.012, Vector3(-0.11, top_y + 0.06, 0.2), metal, "Knob2")
	# ほこりよけのカバー（開いて立ててある。後ろの縁に細い板）
	var lid := MeshKit.box(self, Vector3(0.38, 0.012, 0.2), Vector3(0, top_y + 0.15, -0.22), MeshKit.mat("rp_lid", Color(0.7, 0.85, 0.9, 0.35), 0.2), "Lid")
	(lid.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lid.rotation.x = deg_to_rad(-75.0)
	lid.position = Vector3(0, top_y + 0.17, -0.25)
	# 音と判定
	_player = AudioStreamPlayer3D.new()
	_player.name = "Sound"
	_player.bus = "Ambient"
	_player.position = Vector3(0, top_y + 0.1, 0.05)
	_player.unit_size = 2.2
	_player.max_distance = 10.0
	_player.volume_db = -6.0
	add_child(_player)
	var a := MeshKit.interact_area(self, "RecordPlayerArea", "record_player", self)
	MeshKit.shape_box(a, Vector3(0.44, 0.22, 0.5), Vector3(0, top_y + 0.1, 0))
	_build_display()
	MeshKit.auto_round = true


## 壁に飾ってあるレコード盤：木の額に黒い盤と赤いラベル。台の真上の壁（ローカル z = 壁）
func _build_display() -> void:
	_display = Node3D.new()
	_display.name = "RecordDisplay"
	_display.position = Vector3(0, 1.45, WALL_LOCAL_Z + 0.02)
	add_child(_display)
	var frame := MeshKit.mat("rp_frame", Color(0.3, 0.2, 0.12), 0.6)
	MeshKit.box(_display, Vector3(0.36, 0.36, 0.03), Vector3.ZERO, frame, "Frame")
	MeshKit.box(_display, Vector3(0.32, 0.32, 0.005), Vector3(0, 0, 0.016), MeshKit.mat("rp_backing", Color(0.88, 0.82, 0.68), 0.9), "Backing")
	var disc := _make_disc(0.14)
	disc.rotation.x = PI * 0.5
	disc.position = Vector3(0, 0, 0.022)
	_display.add_child(disc)
	# 盤の面が部屋側（+z）を向くように _make_disc の軸（y）を z へ倒してある
	var area := MeshKit.interact_area(self, "RecordDiscArea", "record_disc", null)
	area.position = _display.position + Vector3(0, 0, 0.03)
	MeshKit.shape_box(area, Vector3(0.38, 0.38, 0.1), Vector3.ZERO)


## レコード盤（黒い盤、溝の同心円、赤いラベル、中心の穴）。軸は y。
func _make_disc(radius: float) -> Node3D:
	return disc_model(radius)


static func disc_model(radius: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Disc"
	var black := MeshKit.mat("disc_black", Color(0.04, 0.04, 0.045), 0.25, 0.1)
	MeshKit.cylinder(n, radius, 0.004, Vector3(0, 0.002, 0), black, "Vinyl")
	for k in 3:   # 溝
		MeshKit.cylinder(n, radius * (0.9 - k * 0.12), 0.0006, Vector3(0, 0.0043, 0), MeshKit.mat("disc_groove_%d" % k, Color(0.1 + 0.02 * k, 0.1 + 0.02 * k, 0.11 + 0.02 * k), 0.15), "Groove%d" % k)
	MeshKit.cylinder(n, radius * 0.36, 0.0008, Vector3(0, 0.0048, 0), MeshKit.mat("disc_label", Color(0.78, 0.18, 0.14), 0.6), "Label")
	MeshKit.cylinder(n, radius * 0.1, 0.001, Vector3(0, 0.005, 0), MeshKit.mat("disc_hole", Color(0.88, 0.82, 0.68), 0.8), "Hole")
	return n


## 持ち物の拡大表示用（縦に立てて見せる）。
static func zoom_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "DiscModel"
	var d := disc_model(0.14)
	d.rotation.x = PI * 0.5
	holder.add_child(d)
	holder.scale = Vector3.ONE * 1.6
	return holder


func take_display() -> void:
	display_taken = true
	if _display:
		_display.queue_free()
		_display = null
	var a := get_node_or_null("RecordDiscArea")
	if a:
		a.queue_free()


# ---------------------------------------------------------------- プレーヤー

func get_prompt(_id: String) -> String:
	if not loaded:
		return "record_set" if holding else "record_empty"
	return "record_stop" if playing else "record_play"


func interact(_id: String) -> String:
	if not loaded:
		if not holding:
			Sfx.play("click")
			return "record_empty"
		loaded = true
		_disc_on_platter.visible = true
		Sfx.play("plop")
		disc_set.emit()
		_start()
		return "record_set"
	Sfx.play("click")
	if playing:
		_stop()
		return "record_stopped"
	_start()
	return "record_started"


func _start() -> void:
	playing = true
	_set_arm(true)
	if _wave_cache == null:
		_wave_cache = _make_jazz()
	_player.stream = _wave_cache
	_player.play()


func _stop() -> void:
	playing = false
	_set_arm(false)
	_player.stop()


func _set_arm(on: bool) -> void:
	_arm.rotation.y = deg_to_rad(18.0 if on else -2.0)


func _process(delta: float) -> void:
	if playing:
		_platter.rotation.y -= delta * TAU * 33.0 / 60.0


# ---------------------------------------------------------------- 音（古いジャズ）

func _wave(s: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in s:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(s.size() * 2)
	for i in s.size():
		bytes.encode_s16(i * 2, int(clampf(s[i] / peak * 0.8, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = s.size()
	return w


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## 8 小節（Dm7 | G7 | Cmaj7 | A7 | Dm7 | G7 | Cmaj7 | Cmaj7 ← 2 小節で1コード）を 120 BPM のスウィングで。
func _make_jazz() -> AudioStreamWAV:
	var beat := 60.0 / BPM
	var total := BARS * 4 * beat
	var n := int(total * MIX)
	var s := PackedFloat32Array()
	s.resize(n)
	_rng.seed = 1927
	# [根音, コードトーン（半音）, 旋律に使う音階]
	var chords := [
		[50, [0, 3, 7, 10], [0, 2, 3, 5, 7, 9, 10]],    # Dm7（ドリアン）
		[43, [0, 4, 7, 10], [0, 2, 4, 5, 7, 9, 10]],    # G7
		[48, [0, 4, 7, 11], [0, 2, 4, 5, 7, 9, 11]],    # Cmaj7
		[45, [0, 4, 7, 10], [0, 1, 4, 5, 7, 8, 10]],    # A7(♭9)
		[50, [0, 3, 7, 10], [0, 2, 3, 5, 7, 9, 10]],
		[43, [0, 4, 7, 10], [0, 2, 4, 5, 7, 9, 10]],
		[48, [0, 4, 7, 11], [0, 2, 4, 5, 7, 9, 11]],
		[48, [0, 4, 7, 11], [0, 2, 4, 5, 7, 9, 11]],
	]
	# ウォーキングベース：4 分音符ごとに 根音 → 5度 → 3度 → 次の根音の半音下
	for bar in BARS:
		var c: Array = chords[bar]
		var nxt: Array = chords[(bar + 1) % BARS]
		var root: int = c[0] - 12
		var tones: Array = c[1]
		var picks := [root, root + tones[2], root + tones[1] + (12 if tones[1] < 2 else 0), nxt[0] - 12 + (1 if nxt[0] <= c[0] else -1)]
		for b in 4:
			_pluck(s, (bar * 4 + b) * beat, _hz(picks[b]), beat * 0.9, 0.45)
	# ピアノのコンピング：1 拍目のウラ（スウィング）と 3 拍目の頭、ときどき 4 拍目のウラ
	for bar in BARS:
		var c2: Array = chords[bar]
		var base: int = c2[0] + 12
		var hits := [[0.0 + 2.0 / 3.0, 0.6], [2.0, 0.5], [3.0 + 2.0 / 3.0, 0.4]]
		for h in hits:
			if _rng.randf() < 0.18 and h[0] > 3.0:
				continue
			for t in c2[1]:
				_keys(s, (bar * 4 + h[0]) * beat, _hz(base + t + (12 if t < 3 else 0)), beat * 0.6, 0.13 * h[1])
	# 旋律（ミュートのトランペット風）：スウィングの 8 分音符。休符をはさみながら音階を上下する
	var pos := 4
	var t_note := 0.0
	while t_note < BARS * 4.0 - 0.5:
		var bar_i := int(t_note / 4.0)
		var c3: Array = chords[bar_i]
		var scale: Array = c3[2]
		var dur_eighths: int = [1, 1, 1, 2, 2, 3][_rng.randi() % 6]
		var step: int = [-2, -1, -1, 1, 1, 2, 0][_rng.randi() % 7]
		pos = clampi(pos + step, 0, scale.size() - 1 + 4)
		if _rng.randf() < 0.22:
			t_note += dur_eighths * 0.5
			continue
		var oct := pos / scale.size()
		var midi: int = c3[0] + 24 + scale[pos % scale.size()] + 12 * (oct - 1)
		var swing := (1.0 / 6.0) if int(t_note * 2.0) % 2 == 1 else 0.0
		_horn(s, (t_note + swing) * beat, _hz(midi), dur_eighths * 0.5 * beat * 0.85, 0.2)
		t_note += dur_eighths * 0.5
	# ライドシンバル：「チーン・チン・チカ」のスウィングのパターン
	for b in BARS * 4:
		_ride(s, b * beat, 0.5)
		if b % 2 == 1:
			_ride(s, (b + 2.0 / 3.0 - 0.0) * beat - beat * 0.0, 0.3)
	# 2 拍・4 拍のハイハット
	for b in BARS * 4:
		if b % 2 == 1:
			_click(s, b * beat, 0.25)
	_lowpass(s, 0.28)
	_crackle(s)
	return _wave(s)


func _add(s: PackedFloat32Array, idx: int, v: float) -> void:
	s[posmod(idx, s.size())] += v


func _pluck(s: PackedFloat32Array, t0: float, f: float, dur: float, amp: float) -> void:
	var n := int(dur * MIX)
	var i0 := int(t0 * MIX)
	for i in n:
		var t := float(i) / MIX
		var env := exp(-t * 5.0) * minf(1.0, t * 150.0)
		_add(s, i0 + i, amp * env * (sin(TAU * f * t) + 0.35 * sin(TAU * 2.0 * f * t)))


func _keys(s: PackedFloat32Array, t0: float, f: float, dur: float, amp: float) -> void:
	var n := int(dur * MIX)
	var i0 := int(t0 * MIX)
	for i in n:
		var t := float(i) / MIX
		var env := exp(-t * 6.0) * minf(1.0, t * 300.0)
		_add(s, i0 + i, amp * env * (sin(TAU * f * t) + 0.4 * sin(TAU * 2.0 * f * t) * exp(-t * 4.0) + 0.1 * sin(TAU * 3.0 * f * t)))


func _horn(s: PackedFloat32Array, t0: float, f: float, dur: float, amp: float) -> void:
	var n := int(dur * MIX)
	var i0 := int(t0 * MIX)
	var ph := 0.0
	for i in n:
		var t := float(i) / MIX
		var vib := 1.0 + 0.012 * sin(TAU * 5.2 * t) * minf(1.0, t * 3.0)
		ph += TAU * f * vib / MIX
		var env := minf(1.0, t * 40.0) * minf(1.0, (dur - t) * 25.0) * (0.75 + 0.25 * exp(-t * 3.0))
		_add(s, i0 + i, amp * env * (sin(ph) + 0.55 * sin(2.0 * ph) + 0.35 * sin(3.0 * ph) + 0.15 * sin(4.0 * ph)))


func _ride(s: PackedFloat32Array, t0: float, amp: float) -> void:
	var n := int(0.22 * MIX)
	var i0 := int(t0 * MIX)
	for i in n:
		var t := float(i) / MIX
		_add(s, i0 + i, amp * 0.09 * exp(-t * 22.0) * _rng.randf_range(-1.0, 1.0))


func _click(s: PackedFloat32Array, t0: float, amp: float) -> void:
	var n := int(0.05 * MIX)
	var i0 := int(t0 * MIX)
	for i in n:
		var t := float(i) / MIX
		_add(s, i0 + i, amp * 0.12 * exp(-t * 90.0) * _rng.randf_range(-1.0, 1.0))


func _lowpass(s: PackedFloat32Array, k: float) -> void:
	var y := 0.0
	for pass_i in 2:
		for i in s.size():
			y += k * (s[i] - y)
			if pass_i == 1:
				s[i] = y


func _crackle(s: PackedFloat32Array) -> void:
	var y := 0.0
	for i in s.size():
		y += 0.3 * (_rng.randf_range(-1.0, 1.0) - y)
		s[i] += y * 0.006
		if _rng.randf() < 0.0006:
			s[i] += _rng.randf_range(-0.06, 0.06)
