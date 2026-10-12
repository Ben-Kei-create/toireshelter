extends Node3D
## 鏡裏収納：右の壁の手前に付けた薄い収納箱と、鏡の扉（横の蝶番で開く）。中に棚2段と洗顔料・化粧水・綿棒。
## 座標は部屋と同じ（この節点は原点に置く）。実際の鏡面反射はしない（仮の材質）。
##
##   MirrorCabinet/Box        … 収納箱（背板・側板・天板・底板・棚2段）。当たり判定（world）で、横から中を調べられない
##   MirrorCabinet/DoorPivot  … 扉の蝶番（奥側 = 浴槽側の縁）。子に鏡と照準用の判定 DoorArea（扉と一緒に回る）
##   MirrorCabinet/Items/*    … 中の物（調べる判定つき）。閉じた扉は手前の判定で遮る
##
## 収納箱の下端は 1.28m：棚の歯ブラシ（上端 約1.26m）や蛇口とぶつからない高さ。
## 開閉中（0.45秒）のクリックは無視する。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const WALL_X := 0.9
const DEPTH := 0.10
const FRONT_X := WALL_X - DEPTH             # 収納箱の前面
const Y_RANGE := Vector2(1.28, 1.78)
const Z_RANGE := Vector2(-0.12, 0.32)
const BOARD := 0.012
const SHELF_YS := [1.46, 1.62]              # 中の棚2段（上面）。下段の物（高さ約0.145）が当たらない高さ
const DOOR_T := 0.018
const DOOR_GAP := 0.002                     # 扉と収納箱の前面のすき間
const OPEN_DEG := -100.0                    # 部屋側（-x）へ開く
const SWING_TIME := 0.45

var is_open := false
var busy := false
var door_pivot: Node3D


func _ready() -> void:
	_build_box()
	_build_items()
	_build_door()


func toggle() -> void:
	if busy:
		return
	busy = true
	is_open = not is_open
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door_pivot, "rotation:y", deg_to_rad(OPEN_DEG) if is_open else 0.0, SWING_TIME)
	tween.tween_callback(func() -> void: busy = false)


func _build_box() -> void:
	var box := Node3D.new()
	box.name = "Box"
	add_child(box)
	var white := MeshKit.mat("cabinet", Color(0.95, 0.95, 0.94), 0.5)
	var h := Y_RANGE.y - Y_RANGE.x
	var w := Z_RANGE.y - Z_RANGE.x
	var cy := (Y_RANGE.x + Y_RANGE.y) * 0.5
	var cz := (Z_RANGE.x + Z_RANGE.y) * 0.5
	var cx := (FRONT_X + WALL_X) * 0.5
	var parts := [
		[Vector3(BOARD, h, w), Vector3(WALL_X - BOARD * 0.5, cy, cz)],                 # 背板
		[Vector3(DEPTH, BOARD, w), Vector3(cx, Y_RANGE.x + BOARD * 0.5, cz)],          # 底板
		[Vector3(DEPTH, BOARD, w), Vector3(cx, Y_RANGE.y - BOARD * 0.5, cz)],          # 天板
		[Vector3(DEPTH, h, BOARD), Vector3(cx, cy, Z_RANGE.x + BOARD * 0.5)],          # 側板
		[Vector3(DEPTH, h, BOARD), Vector3(cx, cy, Z_RANGE.y - BOARD * 0.5)],
	]
	for sy in SHELF_YS:
		parts.append([Vector3(DEPTH - BOARD, BOARD * 0.6, w - BOARD * 2.0), Vector3(cx - BOARD * 0.5, sy - BOARD * 0.3, cz)])
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	box.add_child(body)
	for p in parts:
		MeshKit.box(box, p[0], p[1], white)
		MeshKit.shape_box(body, p[0], p[1])


func _build_items() -> void:
	var items := Node3D.new()
	items.name = "Items"
	add_child(items)
	var x := FRONT_X + DEPTH * 0.45
	var floor_y := Y_RANGE.x + BOARD
	# 下の段：化粧水（ボトル）と洗顔料（キャップを下にして立てたチューブ）
	var toner := _item(items, "Toner", "toner", Vector3(x, floor_y, 0.02), Vector3(0.06, 0.15, 0.06))
	MeshKit.cylinder(toner, 0.026, 0.12, Vector3(0, 0.06, 0), MeshKit.mat("toner_body", Color(0.55, 0.72, 0.92), 0.2), "Bottle")
	MeshKit.cylinder(toner, 0.013, 0.025, Vector3(0, 0.1325, 0), MeshKit.mat("toner_cap", Color(0.95, 0.95, 0.96), 0.4), "Cap")
	var wash := _item(items, "FaceWash", "face_wash", Vector3(x, floor_y, 0.17), Vector3(0.05, 0.15, 0.06))
	MeshKit.cylinder(wash, 0.014, 0.022, Vector3(0, 0.011, 0), MeshKit.mat("wash_cap", Color(0.95, 0.55, 0.45), 0.4), "Cap")
	var tube := MeshKit.cylinder(wash, 0.022, 0.11, Vector3(0, 0.022 + 0.055, 0), MeshKit.mat("wash_body", Color(0.98, 0.82, 0.72), 0.5), "Tube", 0.019)
	MeshKit.box(wash, Vector3(0.008, 0.012, 0.042), Vector3(0, 0.022 + 0.11 + 0.006, 0), MeshKit.mat("wash_body", Color(0.98, 0.82, 0.72), 0.5))
	tube.name = "Tube"
	# 中の段：綿棒の入れ物（透明に近い円筒）と、上に頭を出した綿棒
	var swabs := _item(items, "CottonSwabs", "cotton_swabs", Vector3(x, SHELF_YS[0], 0.10), Vector3(0.08, 0.1, 0.08))
	var case_mat := MeshKit.mat("swab_case", Color(0.55, 0.8, 0.75), 0.15)
	MeshKit.cylinder(swabs, 0.032, 0.065, Vector3(0, 0.0325, 0), case_mat, "Case")
	var stick := MeshKit.mat("swab_stick", Color(0.97, 0.97, 0.97), 0.8)
	for i in 7:
		var a := TAU * i / 7.0
		var off := Vector3(cos(a) * 0.016, 0, sin(a) * 0.016)
		MeshKit.cylinder(swabs, 0.0025, 0.075, off + Vector3(0, 0.04, 0), stick, "", -1.0, 6)
		MeshKit.sphere(swabs, 0.005, off + Vector3(0, 0.0785, 0), stick)


## 中の物の節点と、それを覆う調べる判定（底の中心が pos、判定の大きさ size）。
func _item(parent: Node3D, node_name: String, interact_id: String, pos: Vector3, size: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	var area := MeshKit.interact_area(n, node_name + "Area", interact_id)
	MeshKit.shape_box(area, size, Vector3(0, size.y * 0.5, 0))
	return n


func _build_door() -> void:
	# 蝶番は奥側（z = Z_RANGE.x）の前面の角。扉は +z 方向へ広がり、閉じると収納箱の前面を覆う
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(FRONT_X - DOOR_GAP, Y_RANGE.x, Z_RANGE.x)
	add_child(door_pivot)
	var h := Y_RANGE.y - Y_RANGE.x
	var w := Z_RANGE.y - Z_RANGE.x
	var size := Vector3(DOOR_T, h, w)
	var center := Vector3(-DOOR_T * 0.5, h * 0.5, w * 0.5)
	MeshKit.box(door_pivot, size, center, MeshKit.mat("cabinet", Color(0.95, 0.95, 0.94), 0.5), "Frame")   # 扉の本体と裏は白
	# 鏡面（仮の材質）。枠より 2mm 手前、縁を 2cm 残す
	MeshKit.box(door_pivot, Vector3(0.002, h - 0.04, w - 0.04), Vector3(-DOOR_T - 0.001, h * 0.5, w * 0.5),
			MeshKit.mat("mirror", Color(0.72, 0.78, 0.82), 0.08, 0.6), "Mirror")
	# 取っ手代わりの小さなつまみ（蝶番と反対側の縁）
	MeshKit.box(door_pivot, Vector3(0.012, 0.05, 0.012), Vector3(-DOOR_T - 0.006, h * 0.5, w - 0.02),
			MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8), "Knob")
	var area := MeshKit.interact_area(door_pivot, "DoorArea", "mirror_door", self)
	MeshKit.shape_box(area, Vector3(DOOR_T + 0.008, h, w), Vector3(-DOOR_T * 0.5 - 0.004, h * 0.5, w * 0.5))


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(_id: String) -> String:
	if busy:
		return ""
	return "cabinet_close" if is_open else "cabinet_open"


func interact(_id: String) -> String:
	toggle()
	return ""
