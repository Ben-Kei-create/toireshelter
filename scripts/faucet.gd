extends Node3D
## 蛇口：クリックで水を出す／止める。吐水口の先から真下へ細い水流を表示する（流体シミュレーションなし）。
## 見た目（本体・吐水口・レバー）は持ち主が組み立て、setup() で吐水口の位置とレバーを渡す。
## stream_floor_y（ワールド y）まで水流を伸ばす。浴槽は水位に合わせて毎フレーム更新する。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const LEVER_ON_DEG := 35.0
const STREAM_SPEED := 2.5   # 水流の模様が流れる速さ

var is_on := false
var stream_floor_y := 0.0

var _spout_tip := Vector3.ZERO   # ローカル座標
var _lever: Node3D
var _stream: MeshInstance3D
var _stream_mat: StandardMaterial3D
var _stream_radius := 0.005


## tip: 吐水口の先（この節点のローカル座標）／lever: 開閉に合わせて X 軸回りに傾ける節点
func setup(tip: Vector3, floor_y: float, lever: Node3D, radius := 0.005) -> void:
	_spout_tip = tip
	stream_floor_y = floor_y
	_lever = lever
	_stream_radius = radius


func _ready() -> void:
	_stream_mat = MeshKit.new_stream_mat()
	var mesh := CylinderMesh.new()
	mesh.top_radius = _stream_radius
	mesh.bottom_radius = _stream_radius * 0.8
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	_stream = MeshInstance3D.new()
	_stream.name = "Stream"
	_stream.mesh = mesh
	_stream.material_override = _stream_mat
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stream)
	_update_stream()


func _process(delta: float) -> void:
	if is_on:
		_stream_mat.uv1_offset.y -= delta * STREAM_SPEED
	_update_stream()


func set_on(on: bool) -> void:
	if is_on == on:
		return
	is_on = on
	if _lever:
		var tween := create_tween()
		tween.tween_property(_lever, "rotation:x", deg_to_rad(LEVER_ON_DEG) if on else 0.0, 0.15)
	_update_stream()


## 水流の長さ（m）。止まっている／下端が吐水口より上なら 0。
func stream_length() -> float:
	if not is_on or not is_inside_tree():
		return 0.0
	return maxf(0.0, to_global(_spout_tip).y - stream_floor_y)


func _update_stream() -> void:
	if _stream == null:
		return
	var length := stream_length()
	_stream.visible = length > 0.002
	if _stream.visible:
		_stream.position = _spout_tip - Vector3(0.0, length * 0.5, 0.0)
		_stream.scale = Vector3(1.0, length, 1.0)


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(_id: String) -> String:
	return "water_off" if is_on else "water_on"


func interact(_id: String) -> String:
	set_on(not is_on)
	return ""
