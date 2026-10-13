extends Node3D
## 押入れ（自室の奥の壁の右寄り）。ふとんと座布団が入っていて、その隣にクレーンゲームが置いてある。
## 原点は押入れの中心の床。幅 1.5m（x 3.95〜5.45）、奥行き 0.8m（z -1.2〜-0.4）、高さ 2.0m ＋ 上の天袋 0.4m。ローカル +z が部屋側。
##
##   左の仕切り … 中段の棚の上にふとん3枚、下に座布団が積んである
##   右の仕切り … クレーンゲーム（ufo_catcher.gd）が立っている
##   襖2枚（前後2本のレール）… 2枚いっしょに左か右に寄せる。最初は左に寄せてあり、クレーンゲームが見える。
##                              クリックで右へ寄せると、ふとんが見えて、クレーンゲームは襖に隠れる
## 襖は体の判定を持たない代わりに、押入れの前面に体だけを止める透明な板（LAYER_BODY_ONLY）を置いて、中へ歩いて入れないようにしている。
## 襖を右へ寄せている間は、クレーンゲームの前に襖があるので照準が届かない（襖の判定が手前）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const UfoCatcherScript := preload("res://scripts/ufo_catcher.gd")

const CENTER := Vector3(4.7, 0.0, -0.8)
const W := 1.5
const D := 0.8
const H := 2.0
const FLOOR_T := 0.05
const SLIDE_X := 0.375   # 襖の中心（左 -0.375、右 +0.375）

var crane_visible := true   # 襖が左に寄っていて、右半分（クレーンゲーム）が見える
var busy := false
var ufo: Node3D
var mahjong_box: Node3D
var _panels: Array = []
var _area: Area3D


func _ready() -> void:
	position = CENTER
	MeshKit.auto_round = false
	var wood := MeshKit.mat("closet_wood", Color(0.72, 0.58, 0.4), 0.7)
	var inner := MeshKit.mat("closet_inner", Color(0.82, 0.76, 0.62), 0.9)
	var half := W * 0.5
	# 床・側板・仕切り・奥の板・天袋
	MeshKit.box(self, Vector3(W, FLOOR_T, D), Vector3(0, FLOOR_T * 0.5, 0), wood, "Floor")
	MeshKit.box(self, Vector3(0.02, H + 0.4, D), Vector3(-half + 0.01, (H + 0.4) * 0.5, 0), wood, "SideL")
	MeshKit.box(self, Vector3(0.02, H + 0.4, D), Vector3(half - 0.01, (H + 0.4) * 0.5, 0), wood, "SideR")
	MeshKit.box(self, Vector3(0.02, H, D), Vector3(0, H * 0.5, 0), wood, "Divider")
	MeshKit.box(self, Vector3(W, H + 0.4, 0.01), Vector3(0, (H + 0.4) * 0.5, -D * 0.5 + 0.005), inner, "Back")
	MeshKit.box(self, Vector3(W, 0.025, D), Vector3(0, H + 0.0125, 0), wood, "TopShelf")
	MeshKit.box(self, Vector3(W, 0.4 - 0.025, 0.02), Vector3(0, H + 0.2125, D * 0.5 - 0.01), inner, "TenbukuroFront")
	for k in 4:   # 天袋の小さな襖（飾り）
		MeshKit.box(self, Vector3(0.36, 0.33, 0.012), Vector3(-0.56 + k * 0.375, H + 0.2125, D * 0.5 + 0.004), MeshKit.mat("fusuma_cream", Color(0.93, 0.9, 0.8), 0.9), "TenbukuroDoor")
	# 左の仕切り：中段の棚、ふとん3枚、下に座布団
	MeshKit.box(self, Vector3(0.73, 0.025, D - 0.02), Vector3(-half * 0.5 - 0.005, 1.0, 0), wood, "Shelf")
	var fab := StandardMaterial3D.new()   # 生地の画像は暗いので、ふとん・座布団は無地のやわらかい色にする
	fab.roughness = 0.95
	var futon_cols := [Color(0.82, 0.76, 0.92), Color(0.95, 0.82, 0.7), Color(0.7, 0.86, 0.82)]
	for k in 3:
		var m := fab.duplicate() as StandardMaterial3D
		m.albedo_color = futon_cols[k]
		var f := MeshKit.box(self, Vector3(0.62 - k * 0.02, 0.17, 0.5), Vector3(-half * 0.5 + 0.02 * (k % 2), 1.0125 + 0.0875 + k * 0.175, 0.02), m, "Futon")
		f.rotation.y = deg_to_rad(2.0 - k * 2.0)
	var zab_cols := [Color(0.8, 0.45, 0.45), Color(0.45, 0.62, 0.75), Color(0.8, 0.72, 0.4), Color(0.62, 0.5, 0.75)]
	for k in 4:
		var m2 := fab.duplicate() as StandardMaterial3D
		m2.albedo_color = zab_cols[k]
		var z := MeshKit.box(self, Vector3(0.46, 0.07, 0.46), Vector3(-half * 0.5 - 0.02 + (k % 2) * 0.04, FLOOR_T + 0.035 + k * 0.075, 0.0), m2, "Zabuton")
		z.rotation.y = deg_to_rad(-6.0 + k * 5.0)
	# ふとんの山の上に、麻雀牌の箱
	mahjong_box = build_mahjong_box()
	mahjong_box.position = Vector3(-half * 0.5 - 0.02, 1.0125 + 0.0875 + 0.35 + 0.085, 0.03)
	mahjong_box.rotation.y = deg_to_rad(8.0)
	add_child(mahjong_box)
	var ma := MeshKit.interact_area(mahjong_box, "MahjongArea", "mahjong", null)
	MeshKit.shape_box(ma, Vector3(0.3, 0.14, 0.2), Vector3(0, 0.05, 0))
	# 右の仕切り：クレーンゲーム（向きは部屋側 +z）
	ufo = UfoCatcherScript.new()
	ufo.name = "UfoCatcher"
	ufo.position = Vector3(SLIDE_X, FLOOR_T, -0.1)
	add_child(ufo)
	var lamp := OmniLight3D.new()
	lamp.name = "ClosetLight"
	lamp.position = Vector3(0, 1.7, 0.2)
	lamp.light_color = Color(1.0, 0.9, 0.75)
	lamp.light_energy = 0.5
	lamp.omni_range = 1.8
	add_child(lamp)
	# 襖（前後2本のレール）
	var rail := MeshKit.mat("closet_rail", Color(0.4, 0.3, 0.2), 0.7)
	for zz in [D * 0.5 - 0.006, D * 0.5 - 0.034]:
		MeshKit.box(self, Vector3(W, 0.015, 0.02), Vector3(0, FLOOR_T + 0.0075, zz), rail, "Rail")
		MeshKit.box(self, Vector3(W, 0.02, 0.02), Vector3(0, FLOOR_T + 1.97 + 0.01, zz), rail, "Rail")
	var fcream := MeshKit.mat("fusuma_cream", Color(0.93, 0.9, 0.8), 0.9)
	var fframe := MeshKit.mat("fusuma_frame", Color(0.22, 0.17, 0.12), 0.6)
	var deco := MeshKit.mat("fusuma_deco", Color(0.7, 0.78, 0.82), 0.9)
	for k in 2:
		var p := Node3D.new()
		p.name = "Fusuma%d" % (k + 1)
		var zz2: float = D * 0.5 - 0.006 - 0.0125 if k == 0 else D * 0.5 - 0.034 - 0.0125
		p.position = Vector3(-SLIDE_X, FLOOR_T + 0.985, zz2)
		add_child(p)
		MeshKit.box(p, Vector3(0.76, 1.95, 0.02), Vector3.ZERO, fcream, "Panel")
		for dx in [-0.375, 0.375]:
			MeshKit.box(p, Vector3(0.02, 1.95, 0.026), Vector3(dx, 0, 0), fframe, "Stile")
		for dy in [-0.975, 0.975]:
			MeshKit.box(p, Vector3(0.76, 0.02, 0.026), Vector3(0, dy, 0), fframe, "Rail")
		MeshKit.box(p, Vector3(0.016, 0.07, 0.03), Vector3(0.3 if k == 0 else -0.3, 0.0, 0.0), fframe, "Handle")
		# 上下に薄い水色の波の飾り
		MeshKit.box(p, Vector3(0.6, 0.12, 0.004), Vector3(0, -0.6, 0.011), deco, "Deco")
		_panels.append(p)
	# 襖の調べる判定（襖が寄っていない側を除く、襖が出ている側の半分）。体の判定は前面の透明な板
	_area = MeshKit.interact_area(self, "FusumaArea", "fusuma", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.76, 1.95, 0.08)
	cs.shape = box
	_area.add_child(cs)
	_area_cs = cs
	_place_area()
	var blocker := StaticBody3D.new()
	blocker.name = "BodyBlocker"
	blocker.collision_layer = MeshKit.LAYER_BODY_ONLY
	blocker.collision_mask = 0
	add_child(blocker)
	MeshKit.shape_box(blocker, Vector3(W, H, 0.1), Vector3(0, H * 0.5, D * 0.5 + 0.05))
	MeshKit.auto_round = true


var _area_cs: CollisionShape3D


func _place_area() -> void:
	# 襖が出ている側：クレーンゲームが見えている（襖が左）なら左半分、ふとんが見えている（襖が右）なら右半分
	_area_cs.position = Vector3(-SLIDE_X if crane_visible else SLIDE_X, FLOOR_T + 0.985, D * 0.5 - 0.02)


func get_prompt(_id: String) -> String:
	if busy:
		return ""
	return "fusuma_right" if crane_visible else "fusuma_left"


func interact(_id: String) -> String:
	if busy:
		return ""
	busy = true
	crane_visible = not crane_visible
	Sfx.play("slide")
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target_x := -SLIDE_X if crane_visible else SLIDE_X
	for i in _panels.size():
		tw.parallel().tween_property(_panels[i], "position:x", target_x + (0.02 * i), 0.8)
	tw.tween_callback(func() -> void:
		busy = false
		_place_area())
	return ""


func take_mahjong() -> void:
	if mahjong_box:
		mahjong_box.queue_free()
		mahjong_box = null


## 麻雀牌の箱（深緑のケース、金の留め具、ふたの上にこぼれた牌が2枚）。拡大表示にも使う。
static func build_mahjong_box() -> Node3D:
	var n := Node3D.new()
	n.name = "MahjongBox"
	var green := MeshKit.mat("mj_case", Color(0.12, 0.3, 0.2), 0.5)
	var gold := MeshKit.mat("mj_gold", Color(0.85, 0.7, 0.3), 0.3, 0.7)
	MeshKit.box(n, Vector3(0.26, 0.06, 0.17), Vector3(0, 0.03, 0), green, "Case")
	MeshKit.box(n, Vector3(0.265, 0.004, 0.175), Vector3(0, 0.035, 0), MeshKit.mat("mj_seam", Color(0.05, 0.12, 0.08), 0.6), "Seam")
	for sx in [-0.06, 0.06]:
		MeshKit.box(n, Vector3(0.02, 0.014, 0.004), Vector3(sx, 0.04, 0.087), gold, "Clasp")
	MeshKit.box(n, Vector3(0.05, 0.012, 0.03), Vector3(0, 0.066, 0), gold, "Plate")
	var ivory := MeshKit.mat("mj_ivory", Color(0.95, 0.93, 0.82), 0.4)
	var back := MeshKit.mat("mj_back", Color(0.18, 0.5, 0.35), 0.5)
	for k in 2:
		var t := Node3D.new()
		t.position = Vector3(-0.1 + k * 0.045, 0.06 + 0.009, 0.03)
		t.rotation.y = deg_to_rad(20.0 - k * 55.0)
		n.add_child(t)
		MeshKit.box(t, Vector3(0.024, 0.017, 0.032), Vector3(0, 0, 0), ivory, "Tile")
		MeshKit.box(t, Vector3(0.024, 0.006, 0.032), Vector3(0, -0.0055, 0), back, "TileBack")
	return n


static func mahjong_zoom_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "MahjongModel"
	var b := build_mahjong_box()
	b.scale = Vector3.ONE * 2.2
	holder.add_child(b)
	return holder
