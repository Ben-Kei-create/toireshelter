extends Node3D
## トイレまわりの生活用品（TASK-06）。座標は部屋と同じ（この節点は原点に置く）。すべて調べられるが、取得はできない。
##
##   PaperHolder   … 左の壁 z=+0.30・高さ0.70。座った人の右手側。使用中のロールと垂れた紙
##   SupplyShelf   … タンクの上の壁の棚（上面 y=1.35）。包装された予備ロール（SpareRoll）と洗剤（Cleaner）
##   CleaningStand … 手前左の床の隅。ラバーカップ（Plunger）とトイレブラシ（Brush）を、
##                   持ち手を垂直に、台の前端から同じ距離・同じ間隔で並べる
##   VentSticker   … 天井の換気口の横に下向きに貼った点検シール（操作距離 2.4m）
##
## 当たり判定：細い物には付けない。床の収納台だけ、体がめり込まないよう単純な箱を1つ付け、
## 調べる判定（interact）はその箱より少し大きくして、照準が先に当たるようにしてある。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const ROLL_WRAP_TEX := preload("res://assets/textures/spare_roll_wrap.png")             # 1024x320
const CLEANER_TEX := preload("res://assets/textures/toilet_cleaner_label.png")         # 320x512
const STICKER_TEX := preload("res://assets/textures/vent_inspection_sticker.png")      # 256x160

const WALL_X := -0.9
const HOLDER_POS := Vector3(WALL_X, 0.70, 0.30)
const SHELF_TOP := 1.35
const SHELF_DEPTH := 0.15
const SHELF_Z := Vector2(-0.2, 0.2)
const STAND_CENTER := Vector3(-0.80, 0.0, 1.06)
const STAND_SIZE := Vector3(0.13, 0.025, 0.26)
const ITEM_X := -0.80                   # ラバーカップとブラシの中心（台の前端から 0.065）
const ITEM_Z := [0.995, 1.125]          # 台の両端から 0.065、間隔 0.13
const STICKER_CENTER := Vector3(-0.53, 2.2, -1.02)
const STICKER_SIZE := Vector2(0.10, 0.0625)
const STICKER_RANGE := 2.4

var plunger: Node3D
var brush: Node3D


func _ready() -> void:
	_build_paper_holder()
	_build_shelf()
	_build_stand()
	_build_sticker()


func _build_paper_holder() -> void:
	var root := Node3D.new()
	root.name = "PaperHolder"
	root.position = HOLDER_POS
	add_child(root)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var paper := MeshKit.mat("paper", Color(0.97, 0.97, 0.95), 0.95)
	var r := 0.055
	var roll_x := 0.012 + r + 0.006   # 壁の台座＋すき間
	MeshKit.box(root, Vector3(0.012, 0.08, 0.15), Vector3(0.006, 0.0, 0.0), metal, "Plate")
	for zz in [-0.062, 0.062]:
		MeshKit.box(root, Vector3(roll_x + 0.012, 0.012, 0.008), Vector3((roll_x + 0.012) * 0.5, 0.0, zz), metal)
	var cover := MeshKit.box(root, Vector3(roll_x + r * 0.7, 0.003, 0.13), Vector3((roll_x + r * 0.7) * 0.5, r + 0.012, 0.0), metal, "Cover")
	cover.rotation.z = deg_to_rad(-8.0)
	var roll := MeshKit.cylinder(root, r, 0.105, Vector3(roll_x, 0.0, 0.0), paper, "Roll", -1.0, 24)
	roll.rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(roll, 0.02, 0.106, Vector3.ZERO, MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9), "Core")
	# ロールの手前（部屋側）から垂れた紙
	MeshKit.box(root, Vector3(0.0015, 0.12, 0.103), Vector3(roll_x + r - 0.001, -0.06, 0.0), paper, "Sheet")
	var area := MeshKit.interact_area(root, "HolderArea", "paper_holder")
	MeshKit.shape_box(area, Vector3(roll_x + r + 0.01, 0.2, 0.15), Vector3((roll_x + r + 0.01) * 0.5, -0.04, 0.0))


func _build_shelf() -> void:
	var shelf := Node3D.new()
	shelf.name = "SupplyShelf"
	add_child(shelf)
	var white := MeshKit.mat("shelf", Color(0.95, 0.95, 0.93), 0.4)
	var t := 0.018
	var zc := (SHELF_Z.x + SHELF_Z.y) * 0.5
	var zl := SHELF_Z.y - SHELF_Z.x
	MeshKit.box(shelf, Vector3(SHELF_DEPTH, t, zl), Vector3(WALL_X + SHELF_DEPTH * 0.5, SHELF_TOP - t * 0.5, zc), white, "Board")
	for zz in [SHELF_Z.x + 0.03, SHELF_Z.y - 0.03]:
		MeshKit.box(shelf, Vector3(0.1, 0.07, 0.012), Vector3(WALL_X + 0.05, SHELF_TOP - t - 0.035, zz), white)

	# 包装された予備ロール：側面に包装の画像を一周巻く。文字のある中央を +x（部屋側）、継ぎ目を壁側に
	var roll := Node3D.new()
	roll.name = "SpareRoll"
	roll.position = Vector3(WALL_X + 0.07, SHELF_TOP, 0.09)
	shelf.add_child(roll)
	var rr := 0.058
	var rh := 0.114
	MeshKit.cylinder(roll, rr, rh, Vector3(0, rh * 0.5, 0), MeshKit.mat("roll_wrap_plain", Color(0.98, 0.97, 0.93), 0.6), "Body", -1.0, 32)
	var wrap := MeshInstance3D.new()
	wrap.name = "Wrap"
	wrap.mesh = MeshKit.band(rr + 0.0008, rr + 0.0008, rh, 0.0, TAU, 48)
	wrap.material_override = MeshKit.texture_mat("spare_roll_wrap", ROLL_WRAP_TEX, 0.6)
	wrap.position = Vector3(0, rh * 0.5, 0)
	roll.add_child(wrap)
	var roll_area := MeshKit.interact_area(roll, "SpareRollArea", "spare_roll")
	MeshKit.shape_box(roll_area, Vector3(rr * 2.0, rh, rr * 2.0), Vector3(0, rh * 0.5, 0))

	# トイレ用洗剤：箱形のボトル＋斜めの注ぎ口＋キャップ。正面（+x）にラベル
	var bottle := Node3D.new()
	bottle.name = "Cleaner"
	bottle.position = Vector3(WALL_X + 0.07, SHELF_TOP, -0.09)
	shelf.add_child(bottle)
	var body := Vector3(0.055, 0.19, 0.085)
	MeshKit.box(bottle, body, Vector3(0, body.y * 0.5, 0), MeshKit.mat("cleaner_body", Color(0.8, 0.9, 0.83), 0.35), "Body")
	MeshKit.cylinder(bottle, 0.016, 0.03, Vector3(0, body.y + 0.015, 0), MeshKit.mat("cleaner_body", Color(0.8, 0.9, 0.83), 0.35), "Neck")
	var nozzle := MeshKit.cylinder(bottle, 0.01, 0.05, Vector3(0.016, body.y + 0.045, 0), MeshKit.mat("cleaner_cap", Color(0.16, 0.42, 0.32), 0.4), "Nozzle")
	nozzle.rotation.z = deg_to_rad(-50.0)   # 注ぎ口は部屋側へ傾ける
	var label := MeshInstance3D.new()
	label.name = "Label"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.112)
	label.mesh = quad
	label.material_override = MeshKit.texture_mat("toilet_cleaner_label", CLEANER_TEX, 0.5)
	label.position = Vector3(body.x * 0.5 + 0.001, 0.09, 0)
	label.rotation.y = deg_to_rad(90.0)   # QuadMesh の表（+z）を +x へ
	bottle.add_child(label)
	var bottle_area := MeshKit.interact_area(bottle, "CleanerArea", "toilet_cleaner")
	MeshKit.shape_box(bottle_area, Vector3(body.x + 0.01, body.y + 0.07, body.z + 0.01), Vector3(0, (body.y + 0.07) * 0.5, 0))


func _build_stand() -> void:
	var stand := Node3D.new()
	stand.name = "CleaningStand"
	stand.position = STAND_CENTER
	add_child(stand)
	var tray_mat := MeshKit.mat("stand_tray", Color(0.82, 0.83, 0.84), 0.5)
	MeshKit.box(stand, STAND_SIZE, Vector3(0, STAND_SIZE.y * 0.5, 0), tray_mat, "Tray")
	var base_y := STAND_SIZE.y

	# ラバーカップ：赤いゴムのカップ（下が広い）＋木の持ち手（垂直）
	plunger = Node3D.new()
	plunger.name = "Plunger"
	plunger.position = Vector3(ITEM_X - STAND_CENTER.x, base_y, ITEM_Z[0] - STAND_CENTER.z)
	stand.add_child(plunger)
	MeshKit.cylinder(plunger, 0.06, 0.07, Vector3(0, 0.035, 0), MeshKit.mat("plunger_rubber", Color(0.55, 0.1, 0.1), 0.7), "Cup", 0.03)
	MeshKit.cylinder(plunger, 0.011, 0.40, Vector3(0, 0.07 + 0.2, 0), MeshKit.mat("wood", Color(0.62, 0.45, 0.28), 0.7), "Handle", -1.0, 12)

	# トイレブラシ：ケース（円筒）から持ち手が垂直に出ている。ブラシの先はケースの中
	brush = Node3D.new()
	brush.name = "Brush"
	brush.position = Vector3(ITEM_X - STAND_CENTER.x, base_y, ITEM_Z[1] - STAND_CENTER.z)
	stand.add_child(brush)
	MeshKit.cylinder(brush, 0.045, 0.12, Vector3(0, 0.06, 0), MeshKit.mat("brush_case", Color(0.9, 0.9, 0.9), 0.4), "Case")
	MeshKit.cylinder(brush, 0.009, 0.34, Vector3(0, 0.03 + 0.17, 0), MeshKit.mat("brush_handle", Color(0.95, 0.95, 0.95), 0.4), "Handle", -1.0, 12)
	MeshKit.cylinder(brush, 0.012, 0.03, Vector3(0, 0.03 + 0.34 + 0.015, 0), MeshKit.mat("brush_cap", Color(0.3, 0.55, 0.75), 0.4), "Grip", -1.0, 12)

	# 体がめり込まない程度の単純な箱（world）。照準は、これより大きい調べる判定に先に当たる
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	stand.add_child(body)
	MeshKit.shape_box(body, Vector3(0.10, 0.45, 0.22), Vector3(0, 0.225, 0))
	var half_z := STAND_SIZE.z * 0.5
	for spec in [["PlungerArea", "plunger", -half_z, 0.0], ["BrushArea", "toilet_brush", 0.0, half_z]]:
		var area := MeshKit.interact_area(stand, spec[0], spec[1])
		var z0: float = spec[2]
		var z1: float = spec[3]
		MeshKit.shape_box(area, Vector3(0.14, 0.50, z1 - z0), Vector3(0, 0.25, (z0 + z1) * 0.5))


func _build_sticker() -> void:
	# 天井から 2mm 下に下向きに貼る。部屋の中から奥を見上げたときに正立するよう、画像の上を +z（部屋側）に向ける
	var sticker := MeshInstance3D.new()
	sticker.name = "VentSticker"
	var quad := QuadMesh.new()
	quad.size = STICKER_SIZE
	sticker.mesh = quad
	sticker.material_override = MeshKit.texture_mat("vent_sticker", STICKER_TEX, 0.7)
	sticker.position = STICKER_CENTER - Vector3(0, 0.002, 0)
	sticker.rotation.x = deg_to_rad(90.0)   # 表（+z）を下（-y）へ、画像の上（+y）を +z へ
	add_child(sticker)
	var area := MeshKit.interact_area(self, "VentStickerArea", "vent_sticker")
	area.set_meta("interact_range", STICKER_RANGE)
	MeshKit.shape_box(area, Vector3(STICKER_SIZE.x, 0.006, STICKER_SIZE.y), STICKER_CENTER - Vector3(0, 0.003, 0))
