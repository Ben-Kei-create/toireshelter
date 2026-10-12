extends Node3D
## 玄関ドア（5階の共用廊下への出口）。玄関ホールの左の壁（x=-0.95）、z 1.5〜2.2（幅0.7m）、高さ2.0m。
## 蝶番はホールの奥側（z=2.2）。外（廊下、-x）へ開く。クリックで開け、開けたままになる（再プレイで閉じる）。
## 施錠も仕掛けもない。外へ出るとクリア（main.gd が廊下の区画で判定する）。
## 座標は部屋と同じ（この節点は原点に置く）。
##
##   FrontDoor/Frame       … 枠（見た目だけ）
##   FrontDoor/Pivot/Leaf  … 扉。Pivot を回して開く。Leaf は当たり判定（world）つきで、調べる対象（front_door）

const MeshKit := preload("res://scripts/mesh_kit.gd")

const X := -0.95
const Z := Vector2(1.5, 2.2)
const H := 2.0
const OPEN_DEG := 100.0
const SWING_TIME := 0.8

var is_open := false
var busy := false
var pivot: Node3D


func _ready() -> void:
	var w := Z.y - Z.x
	var frame_mat := MeshKit.mat("fd_frame", Color(0.32, 0.3, 0.28), 0.6)
	for zz in [Z.x - 0.02, Z.y + 0.02]:
		MeshKit.box(self, Vector3(0.14, H + 0.04, 0.04), Vector3(X, (H + 0.04) * 0.5, zz), frame_mat, "Jamb")
	MeshKit.box(self, Vector3(0.14, 0.04, w + 0.08), Vector3(X, H + 0.02, (Z.x + Z.y) * 0.5), frame_mat, "Lintel")
	# 敷居：ホールの床から廊下の床へ、わずかな金属の板
	MeshKit.box(self, Vector3(0.14, 0.01, w), Vector3(X, 0.005, (Z.x + Z.y) * 0.5), MeshKit.mat("fd_sill", Color(0.6, 0.6, 0.58), 0.4, 0.6), "Sill")
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(X, 0.0, Z.y - 0.01)
	add_child(pivot)
	var leaf_w := w - 0.03
	var leaf_h := H - 0.02
	var leaf_mat := MeshKit.mat("fd_leaf", Color(0.42, 0.5, 0.48), 0.55)
	var body := StaticBody3D.new()
	body.name = "Leaf"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "front_door")
	body.set_meta("fixture", self)
	pivot.add_child(body)
	var center := Vector3(0.0, leaf_h * 0.5 + 0.01, -leaf_w * 0.5)
	MeshKit.box(pivot, Vector3(0.04, leaf_h, leaf_w), center, leaf_mat, "Panel")
	MeshKit.shape_box(body, Vector3(0.04, leaf_h, leaf_w), center)
	# 両面のレバーハンドル、のぞき穴、郵便受けの板、部屋番号
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	for side in [-1.0, 1.0]:
		MeshKit.box(pivot, Vector3(0.05, 0.02, 0.02), Vector3(side * 0.045, 1.0, -leaf_w + 0.07), metal, "Lever")
		MeshKit.box(pivot, Vector3(0.012, 0.12, 0.04), Vector3(side * 0.022, 1.0, -leaf_w + 0.07), metal, "Rose")
	var eye := MeshKit.cylinder(pivot, 0.012, 0.01, Vector3(-0.022, 1.5, -leaf_w * 0.5), metal, "Peephole")
	eye.rotation.z = deg_to_rad(90.0)
	MeshKit.box(pivot, Vector3(0.008, 0.04, 0.22), Vector3(-0.022, 0.95, -leaf_w * 0.5), metal, "MailSlot")
	var plate := MeshKit.box(pivot, Vector3(0.006, 0.07, 0.17), Vector3(-0.023, 1.68, -leaf_w * 0.5), MeshKit.mat("fd_plate", Color(0.9, 0.88, 0.8), 0.6), "Plate")
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var num := Label3D.new()
	num.name = "RoomNumber"
	num.text = "505"
	num.font_size = 64
	num.pixel_size = 0.0012
	num.modulate = Color(0.15, 0.12, 0.1)
	num.outline_size = 0
	num.double_sided = false
	num.position = Vector3(-0.0265, 1.68, -leaf_w * 0.5)
	num.rotation.y = -PI * 0.5   # 表を廊下側（-x）へ
	pivot.add_child(num)


func get_prompt(_id: String) -> String:
	if is_open or busy:
		return ""
	return "front_door_open"


func interact(_id: String) -> String:
	if is_open or busy:
		return ""
	busy = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "rotation:y", deg_to_rad(OPEN_DEG), SWING_TIME)
	tween.tween_callback(func() -> void:
		is_open = true
		busy = false)
	return ""
