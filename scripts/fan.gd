extends Node3D
## 自室の扇風機（床に立つ、首ふり）。クリックで入り切り。見た目と動きだけ。
## つけると羽根がまわり、首が左右にゆっくり動く。原点は足元（床）。座標は部屋と同じ。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const POLE_H := 0.85

var is_on := false
var _blades: Node3D
var _head: Node3D
var _t := 0.0
var _speed := 0.0   # 羽根の回転（0〜1）


func _ready() -> void:
	MeshKit.auto_round = false
	var white := MeshKit.mat("fan_white", Color(0.92, 0.93, 0.9), 0.5)
	var grey := MeshKit.mat("fan_grey", Color(0.4, 0.42, 0.45), 0.6)
	MeshKit.cylinder(self, 0.17, 0.03, Vector3(0, 0.015, 0), white, "Base")
	MeshKit.cylinder(self, 0.018, POLE_H, Vector3(0, POLE_H * 0.5 + 0.03, 0), grey, "Pole")
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, POLE_H + 0.03, 0)
	add_child(_head)
	# モーターの箱と、前後の網（円の枠）、羽根3枚
	MeshKit.box(_head, Vector3(0.1, 0.1, 0.12), Vector3(0, 0, 0.0), white, "Motor")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.17
	ring.outer_radius = 0.18
	var guard := MeshInstance3D.new()
	guard.name = "Guard"
	guard.mesh = ring
	guard.material_override = grey
	guard.position = Vector3(0, 0, -0.06)
	guard.rotation.x = PI * 0.5
	_head.add_child(guard)
	var guard2 := guard.duplicate() as MeshInstance3D
	guard2.position = Vector3(0, 0, 0.03)
	_head.add_child(guard2)
	for k in 6:
		var spoke := MeshKit.box(_head, Vector3(0.006, 0.34, 0.006), Vector3(0, 0, -0.06), grey, "Spoke")
		spoke.rotation.z = k * PI / 6.0
	_blades = Node3D.new()
	_blades.name = "Blades"
	_blades.position = Vector3(0, 0, -0.045)
	_head.add_child(_blades)
	for k in 3:
		var b := MeshKit.box(_blades, Vector3(0.07, 0.15, 0.004), Vector3(0, 0.085, 0), MeshKit.mat("fan_blade", Color(0.75, 0.88, 0.95, 0.9), 0.4), "Blade")
		var pivot := Node3D.new()
		pivot.rotation.z = k * TAU / 3.0
		_blades.add_child(pivot)
		b.get_parent().remove_child(b)
		pivot.add_child(b)
		b.rotation.x = deg_to_rad(12.0)
	MeshKit.cylinder(_blades, 0.02, 0.02, Vector3(0, 0, 0), white, "Hub").rotation.x = PI * 0.5
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD | MeshKit.LAYER_INTERACT
	body.collision_mask = 0
	body.set_meta("interact_id", "fan")
	body.set_meta("fixture", self)
	add_child(body)
	MeshKit.shape_box(body, Vector3(0.36, POLE_H + 0.3, 0.36), Vector3(0, (POLE_H + 0.3) * 0.5, 0))
	MeshKit.auto_round = true


func _process(delta: float) -> void:
	_speed = move_toward(_speed, 1.0 if is_on else 0.0, delta * 1.2)
	_blades.rotation.z += _speed * 28.0 * delta
	if is_on:
		_t += delta
	_head.rotation.y = sin(_t * 0.6) * deg_to_rad(40.0) * _speed


func get_prompt(_id: String) -> String:
	return "fan_off" if is_on else "fan_on"


func interact(_id: String) -> String:
	is_on = not is_on
	return "fan_on" if is_on else "fan_off"
