extends RefCounted
## こたつの中のヘッドホンで聞こえる音：はじめに、誰かの話し声（こもっていて、内容は聞き取れない）。そのあと、独特な BGM がくり返し流れる。
## 音は合成。作るのに数秒かかるので、拾ったときにスレッドで作っておく（generate_async）。

const MIX := 22050
const VOICE_SEC := 13.0
const BGM_SEC := 28.0

var stream: AudioStreamWAV
var _thread: Thread


func generate_async() -> void:
	if stream != null or _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_build)


## 作り終わっていれば true（終わったスレッドは回収する）。
func ready() -> bool:
	if stream != null:
		return true
	if _thread != null and not _thread.is_alive():
		_thread.wait_to_finish()
		_thread = null
	return stream != null


func build_now() -> void:
	if stream == null:
		_build()


func _build() -> void:
	var voice := _voice()
	var bgm := _bgm()
	var all := PackedFloat32Array()
	all.append_array(voice)
	all.append_array(bgm)
	var bytes := PackedByteArray()
	bytes.resize(all.size() * 2)
	for i in all.size():
		bytes.encode_s16(i * 2, int(clampf(all[i], -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX
	w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = voice.size()
	w.loop_end = all.size()
	stream = w


## 二人の話し声：低い声と高い声が、かわるがわる、もごもごと。ローパスでこもらせ、テープのようなノイズを足す。内容は分からない。
func _voice() -> PackedFloat32Array:
	var n := int(VOICE_SEC * MIX)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var vowels := [[800.0, 1250.0], [300.0, 2300.0], [330.0, 800.0], [500.0, 1900.0], [500.0, 900.0]]
	var t := 0.4
	var who := 0
	var ph := 0.0
	while t < VOICE_SEC - 1.0:
		var base := 118.0 if who == 0 else 212.0
		var syllables := rng.randi_range(3, 7)
		for k in syllables:
			var v: Array = vowels[rng.randi_range(0, 4)]
			var dur := rng.randf_range(0.11, 0.24)
			var i0 := int(t * MIX)
			var i1 := mini(int((t + dur) * MIX), n)
			var f0 := base * rng.randf_range(0.88, 1.15)
			for i in range(i0, i1):
				var u := float(i - i0) / maxf(1.0, float(i1 - i0))
				var env := sin(PI * u)
				ph += TAU * f0 * (1.0 + 0.03 * sin(TAU * 6.0 * float(i) / MIX)) / MIX
				var val := 0.0
				for h in range(1, 9):
					var fh := f0 * float(h)
					var wgt := exp(-pow((fh - float(v[0])) / 170.0, 2.0)) + 0.5 * exp(-pow((fh - float(v[1])) / 250.0, 2.0)) + 0.03
					val += wgt * sin(ph * float(h)) / float(h)
				s[i] += 0.2 * env * val
			t += dur + rng.randf_range(0.01, 0.06)
		t += rng.randf_range(0.5, 1.1)
		who = 1 - who
	# こもらせる（ローパス）と、テープのノイズ
	var lp := 0.0
	for i in n:
		lp += (s[i] - lp) * 0.16
		s[i] = lp * 1.6 + rng.randf_range(-1.0, 1.0) * 0.006
	# 最後に、すっと静かになる
	for i in range(n - int(0.8 * MIX), n):
		s[i] *= float(n - i) / (0.8 * MIX)
	return s


## 独特な BGM：低いうなりと、オルゴールのような、少しずれた旋律。前の音の余韻が、ループのつなぎ目をまたぐ。
func _bgm() -> PackedFloat32Array:
	var n := int(BGM_SEC * MIX)
	var s := PackedFloat32Array()
	s.resize(n)
	# うなり：A2 と E3（わずかにずらした 2 本）
	for i in n:
		var t := float(i) / MIX
		var trem := 0.8 + 0.2 * sin(TAU * 0.11 * t)
		s[i] += trem * (0.05 * sin(TAU * 110.0 * t) + 0.04 * sin(TAU * 110.7 * t) + 0.03 * sin(TAU * 164.8 * t) + 0.02 * sin(TAU * 220.5 * t))
	# 旋律：[開始（秒）, 周波数]。少し足りない・ずれた間隔、最後は解決しない
	var notes := [[0.0, 440.0], [1.8, 523.25], [3.4, 659.25], [5.6, 587.33], [7.2, 440.0], [9.7, 493.88], [11.0, 392.0], [13.4, 523.25],
			[15.1, 740.0], [16.6, 659.25], [18.9, 587.33], [20.2, 440.0], [22.0, 466.16], [23.7, 392.0], [25.4, 440.0], [26.6, 311.13]]
	for nt in notes:
		var f: float = nt[1]
		var i0 := int(float(nt[0]) * MIX)
		var len_i := int(3.2 * MIX)
		for j in len_i:
			var t2 := float(j) / MIX
			var env := exp(-t2 * 1.5) * minf(1.0, t2 * 200.0)
			var val := sin(TAU * f * t2) + 0.35 * sin(TAU * f * 2.0 * t2) * exp(-t2 * 2.0) + 0.14 * sin(TAU * f * 3.01 * t2) * exp(-t2 * 3.0) + 0.08 * sin(TAU * f * 4.2 * t2) * exp(-t2 * 5.0)
			s[(i0 + j) % n] += 0.16 * env * val
	# うしろの小さな反響（ループをまたぐ）
	var dry := s.duplicate()
	for tap in [[0.29, 0.28], [0.61, 0.18], [0.97, 0.1]]:
		var d := int(float(tap[0]) * MIX)
		for i in n:
			s[i] += float(tap[1]) * dry[(i - d + n) % n]
	return s
