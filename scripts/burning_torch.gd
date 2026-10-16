extends Node3D
## ベランダに捨てられた、燃える松明。炎と明かりがゆらぐ。extinguish() でぷすっと消える（部屋の電気がついたとき）。

const Items := preload("res://scripts/stage3_items.gd")

var burning := true
var _light: OmniLight3D
var _flame: Node3D
var _t := 0.0


func _ready() -> void:
	name = "BurningTorch"
	var model := Items.torch_model()
	model.rotation.z = deg_to_rad(80.0)   # 床に寝かせる
	add_child(model)
	_flame = model
	_light = OmniLight3D.new()
	_light.position = Vector3(0.18, 0.1, 0)
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.light_energy = 1.3
	_light.omni_range = 2.6
	add_child(_light)


func _process(delta: float) -> void:
	if not burning:
		return
	_t += delta
	_light.light_energy = 1.3 + sin(_t * 17.0) * 0.12 + sin(_t * 7.3) * 0.1


func extinguish() -> void:
	if not burning:
		return
	burning = false
	for c in _flame.find_children("Flame*", "MeshInstance3D", true, false):
		c.visible = false
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 0.0, 0.8)
