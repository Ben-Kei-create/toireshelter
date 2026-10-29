extends Node3D
## 玄関ホールと自室の境の出入口（x 0.95、z 1.5〜2.2、高さ 2.0）の引き戸。和室のようなふすま 1 枚。
## 閉まっていると、部屋が見えず、通れない。開けると、壁の中（z の小さい側）へ引き込まれる。ホールからも自室からも、クリックで開け閉めできる。
## fixture として get_prompt_text／interact を持つ。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

const CENTER := Vector3(0.95, 0.0, 1.85)
const W := 0.72
const H := 2.0
const SLIDE := 0.72

var open := false
var busy := false
var _panel: Node3D
var _blocker: StaticBody3D


func _ready() -> void:
	name = "HallFusuma"
	position = CENTER
	var cream := MeshKit.mat("fusuma_cream", Color(0.93, 0.9, 0.8), 0.9)
	var frame := MeshKit.mat("fusuma_frame", Color(0.16, 0.13, 0.1), 0.7)
	var deco := MeshKit.mat("fusuma_deco", Color(0.7, 0.82, 0.88), 0.9)
	_panel = Node3D.new()
	_panel.name = "Panel"
	add_child(_panel)
	MeshKit.box(_panel, Vector3(0.04, H - 0.02, W - 0.02), Vector3(0, H * 0.5, 0), cream, "Cloth")
	for dz in [-W * 0.5 + 0.01, W * 0.5 - 0.01]:
		MeshKit.box(_panel, Vector3(0.05, H, 0.02), Vector3(0, H * 0.5, dz), frame, "Stile")
	for dy in [0.01, H - 0.01]:
		MeshKit.box(_panel, Vector3(0.05, 0.02, W), Vector3(0, dy, 0), frame, "Rail")
	for sx in [-1.0, 1.0]:
		MeshKit.box(_panel, Vector3(0.002, 0.12, 0.5), Vector3(sx * 0.021, 0.45, 0), deco, "Deco")
		MeshKit.box(_panel, Vector3(0.012, 0.07, 0.016), Vector3(sx * 0.024, 1.0, -W * 0.5 + 0.1), frame, "Handle")
	_blocker = StaticBody3D.new()
	_blocker.name = "Blocker"
	_blocker.collision_layer = MeshKit.LAYER_WORLD
	_blocker.collision_mask = 0
	add_child(_blocker)
	MeshKit.shape_box(_blocker, Vector3(0.1, H, W), Vector3(0, H * 0.5, 0))
	var area := MeshKit.interact_area(self, "HallFusumaArea", "hall_fusuma", self)
	MeshKit.shape_box(area, Vector3(0.5, H, W), Vector3(0, H * 0.5, 0))


func get_prompt_text(_id: String) -> String:
	if busy:
		return ""
	return "左クリック：ふすまを閉める" if open else "左クリック：ふすまを開ける"


func interact(_id: String) -> String:
	if busy:
		return ""
	set_open(not open)
	return ""


## 開け閉め。instant なら演出なし（保存からの復元）。
func set_open(on: bool, instant := false) -> void:
	open = on
	_blocker.collision_layer = 0 if on else MeshKit.LAYER_WORLD
	var target := -SLIDE if on else 0.0
	if instant:
		_panel.position.z = target
		return
	busy = true
	Sfx.play("slide")
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_panel, "position:z", target, 0.7)
	tw.tween_callback(func() -> void: busy = false)
