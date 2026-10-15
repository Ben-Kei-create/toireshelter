extends Node3D
## ベランダのブレーカー（外壁に付いた灰色の箱）。蓋はねじ止め：ドライバーをひねって（F）開く。開くと、ヒューズを差せる（F）。
## ヒューズを差すと、部屋の電気がつく（main.gd が受け取る）。蓋とヒューズの順序はどちらでもよい：先にヒューズを入れようとすると
## 「蓋がねじで閉まっている」と言われ、先に蓋を開けておけば、すぐ差せる。
## fixture として get_prompt_text／interact を持つ。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

signal fuse_inserted

var cover_open := false
var lighter_taken := false
var _lighter_node: Node3D
var fuse_in := false
var _cover: Node3D
var _fuse_node: Node3D
var _screw: Node3D


func _ready() -> void:
	name = "Breaker"
	var grey := MeshKit.mat("breaker_grey", Color(0.55, 0.57, 0.58), 0.6, 0.3)
	var dark := MeshKit.mat("breaker_dark", Color(0.1, 0.1, 0.12), 0.7)
	# 箱（外壁から手前へ出る）。ローカル -z がベランダ側
	MeshKit.box(self, Vector3(0.3, 0.38, 0.1), Vector3(0, 0, -0.05), grey, "Box")
	# 中：ブレーカーのつまみ三つと、ヒューズのソケット
	MeshKit.box(self, Vector3(0.26, 0.34, 0.01), Vector3(0, 0, -0.098), dark, "Inside")
	for i in 3:
		MeshKit.box(self, Vector3(0.035, 0.07, 0.02), Vector3(-0.07 + i * 0.07, 0.08, -0.106), MeshKit.mat("breaker_switch", Color(0.85, 0.85, 0.85), 0.5), "Switch")
	var socket := MeshKit.box(self, Vector3(0.1, 0.03, 0.02), Vector3(0, -0.08, -0.106), MeshKit.mat("breaker_socket", Color(0.3, 0.3, 0.32), 0.6), "Socket")
	socket.name = "Socket"
	_fuse_node = Node3D.new()
	_fuse_node.name = "InsertedFuse"
	_fuse_node.position = Vector3(0, -0.08, -0.12)
	_fuse_node.visible = false
	add_child(_fuse_node)
	var Items := preload("res://scripts/stage3_items.gd")
	_fuse_node.add_child(Items.fuse_model())
	# 蓋（左側の蝶番）。真ん中にねじが一本
	_cover = Node3D.new()
	_cover.name = "Cover"
	_cover.position = Vector3(-0.15, 0, -0.103)
	add_child(_cover)
	MeshKit.box(_cover, Vector3(0.3, 0.38, 0.012), Vector3(0.15, 0, -0.006), grey, "Plate")
	_screw = Node3D.new()
	_screw.position = Vector3(0.15, 0.0, -0.016)
	_cover.add_child(_screw)
	var sc := MeshKit.cylinder(_screw, 0.016, 0.008, Vector3.ZERO, MeshKit.mat("breaker_screw", Color(0.7, 0.7, 0.72), 0.3, 0.8), "Screw", -1.0, 10)
	sc.rotation.x = deg_to_rad(90.0)
	MeshKit.box(_screw, Vector3(0.026, 0.004, 0.004), Vector3(0, 0, -0.005), MeshKit.mat("breaker_slot", Color(0.1, 0.1, 0.1), 0.8), "Slot")
	MeshKit.box(_screw, Vector3(0.004, 0.026, 0.004), Vector3(0, 0, -0.005), MeshKit.mat("breaker_slot", Color(0.1, 0.1, 0.1), 0.8), "Slot2")
	# 箱の底の隅のライター（蓋を開けると見える）
	_lighter_node = Node3D.new()
	_lighter_node.name = "Lighter"
	_lighter_node.position = Vector3(0.09, -0.15, -0.1)
	_lighter_node.rotation = Vector3(0, 0, deg_to_rad(75.0))
	_lighter_node.visible = false
	add_child(_lighter_node)
	var Stage4Items := preload("res://scripts/stage4_items.gd")
	_lighter_node.add_child(Stage4Items.lighter_model())
	var la := MeshKit.interact_area(_lighter_node, "LighterArea", "lighter")
	la.collision_layer = 0
	MeshKit.shape_box(la, Vector3(0.1, 0.1, 0.08), Vector3.ZERO)
	var area := MeshKit.interact_area(self, "BreakerArea", "breaker", self)
	MeshKit.shape_box(area, Vector3(0.34, 0.42, 0.2), Vector3(0, 0, -0.1))


func get_prompt_text(_id: String) -> String:
	return "左クリック：ブレーカーを調べる"


## 左クリック：状態に合った説明のキーを返す（main.gd の ENDING3 ではなく MESSAGES のキー）。
func interact(_id: String) -> String:
	if fuse_in:
		return "breaker_done"
	if not cover_open:
		return "breaker_closed"
	return "breaker_no_fuse"


## ドライバーでねじを回す（F）：蓋が開く。
func open_cover() -> bool:
	if cover_open:
		return false
	cover_open = true
	Sfx.play("click")
	if not lighter_taken:
		_lighter_node.visible = true
		(_lighter_node.get_node("LighterArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_screw, "rotation:z", TAU * 2.0, 0.7)
	tw.chain().tween_property(_cover, "rotation:y", deg_to_rad(-105.0), 0.7)
	return true


## ヒューズを差す（F）。蓋が閉まっていると差せない。
func insert_fuse() -> String:
	if fuse_in:
		return "done"
	if not cover_open:
		return "closed"
	fuse_in = true
	_fuse_node.visible = true
	Sfx.play("clunk")
	fuse_inserted.emit()
	return "ok"


func take_lighter() -> void:
	lighter_taken = true
	_lighter_node.visible = false
	(_lighter_node.get_node("LighterArea") as Area3D).collision_layer = 0


## 保存からの復元（演出なし）。
func restore(p_cover_open: bool, p_fuse_in: bool, p_lighter_taken := false) -> void:
	cover_open = p_cover_open
	fuse_in = p_fuse_in
	lighter_taken = p_lighter_taken
	_lighter_node.visible = cover_open and not lighter_taken
	(_lighter_node.get_node("LighterArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT if _lighter_node.visible else 0
	_cover.rotation.y = deg_to_rad(-105.0) if cover_open else 0.0
	_fuse_node.visible = fuse_in
