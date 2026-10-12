extends Node3D
## トイレ（浴室）の電気のスイッチ。自室の左の壁、出入口（玄関ホールへ）のすぐ北側（x 1.0、z 1.3、高さ 1.25m）。
## 浴室の中にスイッチはない（部屋から入り切りする）。クリックで電気を消す／つける。
## 消してからつけ直すことを何度も繰り返すと、電球が紫色（紫外線のような光）になる（room.gd の set_bath_light）。
## 判定は小さな箱1つ。座標は部屋と同じ（この節点は原点に置く）。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const POS := Vector3(1.006, 1.25, 1.3)

var room: Node
var _rocker: MeshInstance3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	position = POS
	var plate := MeshKit.mat("switch_plate", Color(0.93, 0.92, 0.88), 0.5)
	MeshKit.box(self, Vector3(0.012, 0.12, 0.075), Vector3(0.006, 0, 0), plate, "Plate")
	_rocker = MeshKit.box(self, Vector3(0.01, 0.045, 0.034), Vector3(0.016, 0.0, 0.0), MeshKit.mat("switch_rocker", Color(0.97, 0.97, 0.95), 0.4), "Rocker")
	# 入っている間だけ光る小さな表示灯（オレンジ）
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.9, 0.5, 0.1)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.55, 0.1)
	_lamp = MeshKit.box(self, Vector3(0.006, 0.01, 0.01), Vector3(0.013, 0.045, 0.0), _lamp_mat, "Pilot")
	var area := MeshKit.interact_area(self, "SwitchArea", "bath_light_switch", self)
	MeshKit.shape_box(area, Vector3(0.05, 0.14, 0.1), Vector3(0.025, 0, 0))
	_refresh()


func _refresh() -> void:
	var on: bool = room.bath_light_on
	_rocker.rotation.z = deg_to_rad(8.0 if on else -8.0)
	_lamp_mat.emission_energy_multiplier = 1.5 if on else 0.0
	_lamp_mat.albedo_color = Color(0.9, 0.5, 0.1) if on else Color(0.35, 0.3, 0.25)


func get_prompt(_id: String) -> String:
	return "bath_light_off" if room.bath_light_on else "bath_light_on"


func interact(_id: String) -> String:
	var key: String = room.set_bath_light(not room.bath_light_on)
	_refresh()
	return key
