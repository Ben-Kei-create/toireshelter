extends Node3D
## 小さなキッチン（自室の手前の壁＝南の壁の右寄り、x 3.95〜5.45）。流し台・ガスコンロ・やかん・吊り戸棚・レンジフード・冷蔵庫。
## 装飾と「調べる」だけ（水は出ない・火はつかない）。座標は部屋と同じ（この節点は原点に置く）。
## 体を止める当たり判定は、流し・コンロの台と冷蔵庫の箱。調べる対象：kitchen_sink / kitchen_stove / fridge。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const WALL_Z := 2.4
const COUNTER_H := 0.85
const DEPTH := 0.6


func _ready() -> void:
	MeshKit.auto_round = false
	var cab := MeshKit.mat("kitchen_cabinet", Color(0.88, 0.86, 0.8), 0.6)
	var steel := MeshKit.mat("kitchen_steel", Color(0.78, 0.8, 0.82), 0.3, 0.7)
	var dark := MeshKit.mat("kitchen_dark", Color(0.1, 0.1, 0.11), 0.5)
	var white := MeshKit.mat("kitchen_white", Color(0.94, 0.94, 0.95), 0.4)
	var cz := WALL_Z - DEPTH * 0.5
	# 流し台とコンロの台（x 3.95〜4.85）
	var base := _body("KitchenSink", "kitchen_sink", Vector3(0.45, COUNTER_H, DEPTH), Vector3(4.175, COUNTER_H * 0.5, cz))
	MeshKit.box(self, Vector3(0.45, COUNTER_H, DEPTH), Vector3(4.175, COUNTER_H * 0.5, cz), cab, "SinkCabinet")
	var base2 := _body("KitchenStove", "kitchen_stove", Vector3(0.45, COUNTER_H, DEPTH), Vector3(4.625, COUNTER_H * 0.5, cz))
	MeshKit.box(self, Vector3(0.45, COUNTER_H, DEPTH), Vector3(4.625, COUNTER_H * 0.5, cz), cab, "StoveCabinet")
	MeshKit.box(self, Vector3(0.9, 0.035, DEPTH + 0.02), Vector3(4.4, COUNTER_H + 0.0175, cz - 0.01), steel, "Top")
	# 扉の取っ手
	for x in [4.175, 4.625]:
		MeshKit.box(self, Vector3(0.012, 0.16, 0.012), Vector3(x + 0.18, 0.62, cz - DEPTH * 0.5 - 0.006), steel, "Handle")
	# 流しのくぼみと蛇口
	MeshKit.box(self, Vector3(0.36, 0.01, 0.4), Vector3(4.175, COUNTER_H + 0.037, cz), dark, "Basin")
	MeshKit.cylinder(self, 0.015, 0.2, Vector3(4.175, COUNTER_H + 0.14, WALL_Z - 0.08), steel, "Faucet", 0.015)
	var spout := MeshKit.box(self, Vector3(0.02, 0.02, 0.13), Vector3(4.175, COUNTER_H + 0.235, WALL_Z - 0.15), steel, "Spout")
	spout.rotation.x = deg_to_rad(-6.0)
	# コンロ：2口とつまみ、やかん
	for x in [4.54, 4.7]:
		MeshKit.cylinder(self, 0.06, 0.012, Vector3(x, COUNTER_H + 0.041, cz + 0.02), dark, "Burner", 0.06)
		MeshKit.cylinder(self, 0.035, 0.016, Vector3(x, COUNTER_H + 0.05, cz + 0.02), steel, "BurnerCap", 0.035)
	var kettle := MeshKit.mat("kitchen_kettle", Color(0.85, 0.35, 0.3), 0.3, 0.4)
	MeshKit.cylinder(self, 0.075, 0.13, Vector3(4.54, COUNTER_H + 0.12, cz + 0.02), kettle, "Kettle", 0.065)
	MeshKit.sphere(self, 0.018, Vector3(4.54, COUNTER_H + 0.205, cz + 0.02), dark)
	MeshKit.box(self, Vector3(0.012, 0.06, 0.012), Vector3(4.54, COUNTER_H + 0.03, cz - 0.1), dark, "Knob")
	# 吊り戸棚とレンジフード
	MeshKit.box(self, Vector3(0.45, 0.6, 0.32), Vector3(4.175, 1.72, WALL_Z - 0.16), cab, "WallCabinet")
	MeshKit.box(self, Vector3(0.45, 0.04, 0.5), Vector3(4.625, 1.45, WALL_Z - 0.25), steel, "Hood")
	MeshKit.box(self, Vector3(0.18, 0.5, 0.18), Vector3(4.625, 1.75, WALL_Z - 0.09), steel, "HoodDuct")
	# 冷蔵庫（x 4.85〜5.45）：二段の扉
	var fr := _body("Fridge", "fridge", Vector3(0.6, 1.7, 0.62), Vector3(5.15, 0.85, WALL_Z - 0.31))
	MeshKit.box(self, Vector3(0.6, 1.7, 0.62), Vector3(5.15, 0.85, WALL_Z - 0.31), white, "FridgeBody")
	MeshKit.box(self, Vector3(0.56, 0.01, 0.01), Vector3(5.15, 1.15, WALL_Z - 0.625), MeshKit.mat("kitchen_seam", Color(0.5, 0.5, 0.52), 0.6), "Seam")
	MeshKit.box(self, Vector3(0.015, 0.4, 0.02), Vector3(5.38, 1.4, WALL_Z - 0.64), steel, "HandleUpper")
	MeshKit.box(self, Vector3(0.015, 0.5, 0.02), Vector3(5.38, 0.75, WALL_Z - 0.64), steel, "HandleLower")
	# 冷蔵庫のマグネット（小さな色板）
	for k in 5:
		MeshKit.box(self, Vector3(0.05, 0.05, 0.006), Vector3(5.0 + (k % 3) * 0.1, 1.45 + (k / 3) * 0.1, WALL_Z - 0.632), MeshKit.mat("magnet_%d" % k, Color.from_hsv(k * 0.18, 0.6, 0.9), 0.5), "Magnet")
	MeshKit.auto_round = true


func _body(node_name: String, interact_id: String, size: Vector3, center: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = MeshKit.LAYER_WORLD
	b.collision_mask = 0
	b.set_meta("interact_id", interact_id)
	add_child(b)
	MeshKit.shape_box(b, size, center)
	return b
