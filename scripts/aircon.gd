extends Node3D
## 自室の天井埋め込み型のエアコン（天井の真ん中、こたつの真上）。クリックで入り切り。見た目と動きだけ。
## つけると四方の羽が下へ開き、緑の表示灯が点き、ひらひらの吹き流し（4本）が揺れる。
## 原点は天井の面（y 2.4）の真下、この節点を置いた位置。座標は部屋と同じ。

const MeshKit := preload("res://scripts/mesh_kit.gd")

var is_on := false
var _flaps: Array = []
var _streamers: Array = []
var _led_mat: StandardMaterial3D
var _t := 0.0
var _open := 0.0   # 羽の開き 0〜1


func _ready() -> void:
	MeshKit.auto_round = false
	var white := MeshKit.mat("aircon_white", Color(0.93, 0.94, 0.95), 0.4)
	var grey := MeshKit.mat("aircon_grey", Color(0.55, 0.57, 0.6), 0.6)
	# 本体：天井から 0.1m 下がる白い箱と、中の暗い吹出口
	MeshKit.box(self, Vector3(0.7, 0.1, 0.7), Vector3(0, -0.05, 0), white, "Body")
	MeshKit.box(self, Vector3(0.5, 0.01, 0.5), Vector3(0, -0.103, 0), MeshKit.mat("aircon_vent", Color(0.15, 0.16, 0.18), 0.9), "Vent")
	MeshKit.box(self, Vector3(0.22, 0.012, 0.22), Vector3(0, -0.108, 0), grey, "Intake")
	# 四方の羽（ヒンジは吹出口の外側の辺）
	for k in 4:
		var pivot := Node3D.new()
		pivot.name = "FlapPivot%d" % k
		pivot.rotation.y = k * PI * 0.5
		pivot.position = Vector3(0, -0.1, 0)
		add_child(pivot)
		var hinge := Node3D.new()
		hinge.position = Vector3(0.0, 0.0, 0.3)
		pivot.add_child(hinge)
		MeshKit.box(hinge, Vector3(0.44, 0.008, 0.07), Vector3(0, 0, -0.035), white, "Flap")
		_flaps.append(hinge)
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.2, 1.0, 0.4)
	_led_mat.emission_energy_multiplier = 0.0
	MeshKit.box(self, Vector3(0.025, 0.006, 0.012), Vector3(0.3, -0.103, 0.3), _led_mat, "Led")
	# 吹き流し（細いひらひら）
	for k in 4:
		var s := MeshKit.box(self, Vector3(0.012, 0.28, 0.003), Vector3(-0.3 + k * 0.2, -0.24, 0.0), MeshKit.mat("aircon_streamer", Color(0.9, 0.95, 1.0, 0.85), 0.8), "Streamer")
		s.visible = false
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_streamers.append(s)
	# 調べる判定（本体の下面）
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_INTERACT
	body.collision_mask = 0
	body.set_meta("interact_id", "aircon")
	body.set_meta("fixture", self)
	add_child(body)
	MeshKit.shape_box(body, Vector3(0.74, 0.14, 0.74), Vector3(0, -0.07, 0))
	MeshKit.auto_round = true


func _process(delta: float) -> void:
	var target := 1.0 if is_on else 0.0
	_open = move_toward(_open, target, delta * 2.0)
	for h in _flaps:
		(h as Node3D).rotation.x = deg_to_rad(_open * 55.0)
	if is_on:
		_t += delta
	for i in _streamers.size():
		var s: Node3D = _streamers[i]
		s.visible = _open > 0.6
		s.rotation.z = sin(_t * 2.2 + i * 1.3) * 0.25 * _open
		s.rotation.x = sin(_t * 1.7 + i * 0.7) * 0.3 * _open


func get_prompt(_id: String) -> String:
	return "aircon_off" if is_on else "aircon_on"


func interact(_id: String) -> String:
	is_on = not is_on
	_led_mat.emission_energy_multiplier = 2.0 if is_on else 0.0
	return "aircon_on" if is_on else "aircon_off"
