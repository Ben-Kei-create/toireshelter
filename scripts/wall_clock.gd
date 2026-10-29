extends Node3D
## 壁掛け時計。針は実際の時刻（パソコンの時計）を指し、1 秒ごとに小さなカチッという音がする。
## 原点は壁に掛けた面の中心。文字盤は -z を向く（置くときに回して部屋側へ向ける）。apartment.gd が東の壁の冷蔵庫の上に掛ける。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

var hour_hand: Node3D
var minute_hand: Node3D
var second_hand: Node3D
var _tick: AudioStreamPlayer3D
var _last_second := -1


func _ready() -> void:
	MeshKit.auto_round = false
	var face := MeshKit.mat("clock_face", Color(0.96, 0.95, 0.9), 0.5)
	var frame := MeshKit.mat("clock_frame", Color(0.15, 0.1, 0.07), 0.5)
	var ink := MeshKit.mat("clock_ink", Color(0.08, 0.08, 0.1), 0.5)
	var r := 0.16
	# 文字盤（-z を向く円盤）と枠
	var disc := MeshKit.cylinder(self, r, 0.03, Vector3(0, 0, -0.015), frame, "Frame")
	disc.rotation.x = PI * 0.5
	# 文字盤の絵（ユーザー作成・生成 AI 使用。絵に描いてあった針は消してある）。針は実際の時刻で動く
	MeshKit.image_quad(self, MeshKit.prop_tex("wall_clock_face"), Vector2(r * 2.0, r * 2.0), Vector3(0, 0, -0.0315), Vector3.FORWARD, "FacePicture", false, 0.5)
	hour_hand = _hand(0.08, 0.008, ink, -0.035)
	minute_hand = _hand(0.12, 0.005, ink, -0.037)
	second_hand = _hand(0.13, 0.002, MeshKit.mat("clock_second", Color(0.85, 0.12, 0.1), 0.4), -0.039)
	MeshKit.sphere(self, 0.007, Vector3(0, 0, -0.04), ink)
	_tick = AudioStreamPlayer3D.new()
	_tick.name = "TickSound"
	_tick.bus = "Ambient"
	_tick.unit_size = 0.8
	_tick.max_distance = 5.0
	_tick.volume_db = -22.0
	add_child(_tick)
	MeshKit.auto_round = true
	var a2 := MeshKit.interact_area(self, "ClockArea", "wall_clock")
	MeshKit.shape_box(a2, Vector3(0.34, 0.34, 0.08), Vector3(0, 0, -0.03))
	a2.set_meta("interact_range", 3.0)
	_update(true)


## 針：長さ len、中心から前に伸びる。回転は z 軸まわり（部屋側＝-z から見て時計回りが正）。
func _hand(len: float, width: float, m: Material, z: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0, 0, z)
	add_child(n)
	MeshKit.box(n, Vector3(width, len, 0.002), Vector3(0, len * 0.5 - 0.01, 0), m, "Hand")
	return n


func _process(_delta: float) -> void:
	_update(false)


func _update(force: bool) -> void:
	var t := Time.get_datetime_dict_from_system()
	var sec: int = t.second
	if sec == _last_second and not force:
		return
	_last_second = sec
	second_hand.rotation.z = TAU * sec / 60.0
	minute_hand.rotation.z = TAU * (t.minute + sec / 60.0) / 60.0
	hour_hand.rotation.z = TAU * ((t.hour % 12) + t.minute / 60.0) / 12.0
	if _tick.stream == null:
		_tick.stream = Sfx.stream_for("tick")
	if _tick.stream != null and is_inside_tree() and not force:
		_tick.play()


## いま指している時刻の文章（調べたとき）。
func time_text() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%d時%02d分" % [t.hour, t.minute]
