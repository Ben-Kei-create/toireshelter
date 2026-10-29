extends Node3D
## トイレまわりの生活用品（TASK-06／TASK-09）。座標は部屋と同じ（この節点は原点に置く）。
## 取得できるのは棚の予備ロールだけ（TASK-09）。ほかは調べるだけ。
##
##   PaperHolder   … 左の壁 z=+0.30・高さ0.70。座った人の右手側。初期状態は芯だけ・カバー閉。
##                   CoverPivot（カバー、蝶番は台座の上端）をクリックで開閉。カバーが開いていて予備ロールを
##                   選んでいるとき、F で交換：芯を外して収納台の脇の小皿（CoreDish）に置き、新しいロールを付ける
##   SupplyShelf   … タンクの上の壁の棚（上面 y=1.35、長さ 0.40m）。手前から見て左から入浴剤（room.gd の BathPowder、
##                   直径0.104）・洗剤（Cleaner、幅0.085）・包装された予備ロール（SpareRoll、直径0.116）を 2〜3cm 間隔で並べる
##   CleaningStand … 手前左の床の隅。ラバーカップ（Plunger）とトイレブラシ（Brush）を、
##                   持ち手を垂直に、台の前端から同じ距離・同じ間隔で並べる
##   VentSticker   … 天井の換気口の横に下向きに貼った点検シール（操作距離 2.4m）
##   ShelfNote     … 棚板の裏（下向き）の小さな紙。棚板には当たり判定があり、上（立った目線）からは遮られる。
##                   座る・しゃがむと目線が棚板より下になり、見上げると見える
##   TankNote      … タンクの真下の壁の小さな紙。立つとタンクに、正面からは便器に遮られ、
##                   しゃがんで便器の入口側から覗くと見える
##
## 当たり判定：細い物には付けない。床の収納台だけ、体がめり込まないよう単純な箱を1つ付け、
## 調べる判定（interact）はその箱より少し大きくして、照準が先に当たるようにしてある。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const ROLL_WRAP_TEX := preload("res://assets/textures/spare_roll_wrap.png")             # 1024x320
const CLEANER_TEX := preload("res://assets/textures/toilet_cleaner_label.png")         # 320x512
const LAMINATE_TEX := preload("res://assets/textures/bath/bath_material_10.png")        # 棚の化粧板
const PAPER_TEX := preload("res://assets/textures/bath/bath_material_06.png")          # トイレットペーパー（ミシン目の型押し）
const STICKER_TEX := preload("res://assets/textures/vent_inspection_sticker.png")      # 256x160

const WALL_X := -0.9
const HOLDER_POS := Vector3(WALL_X, 0.70, 0.30)
const SHELF_TOP := 1.35
const SHELF_DEPTH := 0.15
const SHELF_Z := Vector2(-0.2, 0.2)
const POWDER_Z := -0.13                 # 入浴剤（z -0.182〜-0.078）
const CLEANER_Z := -0.01                # 洗剤（z -0.0525〜0.0325）
const ROLL_Z := 0.12                    # 予備ロール（z 0.062〜0.178）
const STAND_CENTER := Vector3(-0.80, 0.0, 1.06)
const STAND_SIZE := Vector3(0.13, 0.025, 0.26)
const ITEM_X := -0.80                   # ラバーカップとブラシの中心（台の前端から 0.065）
const ITEM_Z := [0.995, 1.125]          # 台の両端から 0.065、間隔 0.13
const STICKER_CENTER := Vector3(-0.53, 2.2, -1.02)
const STICKER_SIZE := Vector2(0.10, 0.0625)
const STICKER_RANGE := 2.4
const ROLL_R := 0.055
const ROLL_X := 0.012 + ROLL_R + 0.006   # ホルダーの台座からロールの中心まで
const COVER_OPEN_DEG := 75.0
const COVER_TIME := 0.3
const INSTALL_TIME := 0.6
const DISH_POS := Vector3(-0.8, 0.0, 0.86)
const SHELF_NOTE_POS := Vector3(-0.83, 1.332, 0.0)
const TANK_NOTE_POS := Vector3(-0.898, 0.42, -0.04)

var plunger: Node3D
var brush: Node3D
var cover_open := false
var has_paper := false
var holder_busy := false
var spare_roll_taken := false
const PULL_MAX := 5
var pulls := 0                          # 新しいロールから紙を引いた回数（PULL_MAX で使い切る）
var used_up := false                    # ロールを使い切って、芯だけが残った
var dish_core_taken := false            # 小皿の芯（望遠鏡用）を取った
var core2_taken := false                # ホルダーの芯（吹き矢用）を取った
var _dish_area: Area3D
var cover_pivot: Node3D
var _holder_roll: Node3D
var _holder_core: Node3D
var _dish_core: Node3D
var _spare_roll: Node3D


func _ready() -> void:
	_build_paper_holder()
	_build_shelf()
	_build_stand()
	_build_dish()
	_build_sticker()
	_build_notes()


func _build_paper_holder() -> void:
	var root := Node3D.new()
	root.name = "PaperHolder"
	root.position = HOLDER_POS
	add_child(root)
	var metal := MeshKit.mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	var paper := MeshKit.tiled_mat("toilet_paper", PAPER_TEX, 0.1, Color.WHITE, 0.95)
	var core_mat := MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9)
	MeshKit.box(root, Vector3(0.012, 0.08, 0.15), Vector3(0.006, 0.0, 0.0), metal, "Plate")
	for zz in [-0.062, 0.062]:
		MeshKit.box(root, Vector3(ROLL_X + 0.012, 0.012, 0.008), Vector3((ROLL_X + 0.012) * 0.5, 0.0, zz), metal)
	# カバー：蝶番は台座の上端（z 方向の軸）。閉じると少し下向き、開けると跳ね上がる
	cover_pivot = Node3D.new()
	cover_pivot.name = "CoverPivot"
	cover_pivot.position = Vector3(0.012, ROLL_R + 0.012, 0.0)
	cover_pivot.rotation.z = deg_to_rad(-8.0)
	root.add_child(cover_pivot)
	var cl := ROLL_X + ROLL_R * 0.7 - 0.012
	MeshKit.box(cover_pivot, Vector3(cl, 0.003, 0.13), Vector3(cl * 0.5, 0.0, 0.0), metal, "Cover")
	var cover_area := MeshKit.interact_area(cover_pivot, "CoverArea", "paper_cover", self)
	MeshKit.shape_box(cover_area, Vector3(cl, 0.012, 0.135), Vector3(cl * 0.5, 0.003, 0.0))
	# 初期状態は芯だけ
	_holder_core = MeshKit.cylinder(root, 0.02, 0.105, Vector3(ROLL_X, 0.0, 0.0), core_mat, "CoreOnly", -1.0, 16)
	_holder_core.rotation.x = deg_to_rad(90.0)
	# 交換後のロール（白い紙＋芯＋垂れた紙）。はじめは隠しておく
	_holder_roll = Node3D.new()
	_holder_roll.name = "Roll"
	_holder_roll.position = Vector3(ROLL_X, 0.0, 0.0)
	_holder_roll.visible = false
	root.add_child(_holder_roll)
	var body := MeshKit.cylinder(_holder_roll, ROLL_R, 0.105, Vector3.ZERO, paper, "Paper", -1.0, 24)
	body.rotation.x = deg_to_rad(90.0)
	var inner := MeshKit.cylinder(_holder_roll, 0.02, 0.106, Vector3.ZERO, core_mat, "Core")
	inner.rotation.x = deg_to_rad(90.0)
	MeshKit.box(_holder_roll, Vector3(0.0015, 0.12, 0.103), Vector3(ROLL_R - 0.001, -0.06, 0.0), paper, "Sheet")
	var area := MeshKit.interact_area(root, "HolderArea", "paper_holder", self)
	MeshKit.shape_box(area, Vector3(ROLL_X + ROLL_R + 0.01, 0.13, 0.13), Vector3((ROLL_X + ROLL_R + 0.01) * 0.5, -0.01, 0.0))


func _build_dish() -> void:
	# 収納台の脇（ホルダー寄り）の床の小皿。交換で外した芯をここに置く
	var dish := Node3D.new()
	dish.name = "CoreDish"
	dish.position = DISH_POS
	add_child(dish)
	MeshKit.cylinder(dish, 0.055, 0.012, Vector3(0, 0.006, 0), MeshKit.mat("dish", Color(0.86, 0.86, 0.84), 0.4), "Plate", 0.06)
	_dish_core = MeshKit.cylinder(dish, 0.02, 0.105, Vector3(0, 0.012 + 0.02, 0), MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9), "Core", -1.0, 16)
	_dish_core.rotation.x = deg_to_rad(90.0)
	_dish_core.visible = false
	_dish_area = MeshKit.interact_area(dish, "DishCoreArea", "dish_core", null)
	MeshKit.shape_box(_dish_area, Vector3(0.14, 0.06, 0.07), Vector3(0, 0.035, 0))
	_dish_area.collision_layer = 0


## カバーを開ける／閉める。
func toggle_cover() -> void:
	if holder_busy:
		return
	holder_busy = true
	cover_open = not cover_open
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cover_pivot, "rotation:z", deg_to_rad(COVER_OPEN_DEG if cover_open else -8.0), COVER_TIME)
	tween.tween_callback(func() -> void: holder_busy = false)


## 予備ロールを付ける。結果："ok"（演出開始。呼び出し側が予備ロールを消費する）／"cover_closed"／"busy"／"full"。
func install_roll() -> String:
	if holder_busy:
		return "busy"
	if has_paper:
		return "full"
	if not cover_open:
		return "cover_closed"
	holder_busy = true
	has_paper = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 芯を手前へ外して消し、小皿に置く → 新しいロールを付ける
	tween.tween_property(_holder_core, "position:x", ROLL_X + 0.08, INSTALL_TIME * 0.4)
	tween.tween_callback(func() -> void:
		_holder_core.visible = false
		_dish_core.visible = not dish_core_taken
		if not dish_core_taken:
			_dish_area.collision_layer = MeshKit.LAYER_INTERACT
		_holder_roll.visible = true
		_holder_roll.scale = Vector3(0.3, 0.3, 0.3))
	tween.tween_property(_holder_roll, "scale", Vector3.ONE, INSTALL_TIME * 0.6)
	tween.tween_callback(func() -> void: holder_busy = false)
	return "ok"


## 新しいロールから紙を引く。"first"（最初の 1 回）／"pull"／"out"（使い切った）／"core"（残った芯を取った）／""（何もない）。
func pull_paper() -> String:
	if used_up and not core2_taken:
		core2_taken = true
		_holder_core.visible = false
		return "core"
	if not has_paper or holder_busy:
		return ""
	pulls += 1
	if pulls >= PULL_MAX:
		has_paper = false
		used_up = true
		_holder_roll.visible = false
		_holder_core.position.x = ROLL_X
		_holder_core.visible = true
		return "out"
	return "first" if pulls == 1 else "pull"


## 小皿の芯を取る（見た目と判定を消す）。
func take_dish_core() -> void:
	dish_core_taken = true
	_dish_core.visible = false
	_dish_area.collision_layer = 0


## 保存からの復元：ロールの状態を、演出なしで合わせる。
func restore_paper(installed: bool, n_pulls: int, is_used_up: bool, dish_taken: bool, c2_taken: bool) -> void:
	dish_core_taken = dish_taken
	core2_taken = c2_taken
	if not installed:
		return
	_holder_core.visible = false
	has_paper = not is_used_up
	pulls = n_pulls
	used_up = is_used_up
	_holder_roll.visible = not is_used_up
	_holder_roll.scale = Vector3.ONE
	if is_used_up and not c2_taken:
		_holder_core.position.x = ROLL_X
		_holder_core.visible = true
	_dish_core.visible = not dish_taken
	_dish_area.collision_layer = 0 if dish_taken else MeshKit.LAYER_INTERACT


## 棚の予備ロールを取る（見た目と照準判定を消す）。
func take_spare_roll() -> void:
	spare_roll_taken = true
	_spare_roll.visible = false
	var area: Area3D = _spare_roll.get_node("SpareRollArea")
	area.collision_layer = 0


func _build_shelf() -> void:
	var shelf := Node3D.new()
	shelf.name = "SupplyShelf"
	add_child(shelf)
	var white := MeshKit.mat("shelf", Color(0.95, 0.95, 0.93), 0.4)
	var t := 0.018
	var zc := (SHELF_Z.x + SHELF_Z.y) * 0.5
	var zl := SHELF_Z.y - SHELF_Z.x
	MeshKit.box(shelf, Vector3(SHELF_DEPTH, t, zl), Vector3(WALL_X + SHELF_DEPTH * 0.5, SHELF_TOP - t * 0.5, zc), MeshKit.tiled_mat("shelf_laminate", LAMINATE_TEX, 0.3, Color.WHITE, 0.45), "Board")
	# 棚板の当たり判定（体は届かない高さ。上から棚板の裏の紙を狙う照準を遮るため）
	var board_body := StaticBody3D.new()
	board_body.name = "BoardCollision"
	board_body.collision_layer = MeshKit.LAYER_WORLD
	board_body.collision_mask = 0
	shelf.add_child(board_body)
	MeshKit.shape_box(board_body, Vector3(SHELF_DEPTH, t, zl), Vector3(WALL_X + SHELF_DEPTH * 0.5, SHELF_TOP - t * 0.5, zc))
	for zz in [SHELF_Z.x + 0.03, SHELF_Z.y - 0.03]:
		MeshKit.box(shelf, Vector3(0.1, 0.07, 0.012), Vector3(WALL_X + 0.05, SHELF_TOP - t - 0.035, zz), white)

	# 包装された予備ロール：側面に包装の画像を一周巻く。文字のある中央を +x（部屋側）、継ぎ目を壁側に
	var roll := Node3D.new()
	_spare_roll = roll
	roll.name = "SpareRoll"
	roll.position = Vector3(WALL_X + SHELF_DEPTH * 0.5, SHELF_TOP, ROLL_Z)
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
	bottle.position = Vector3(WALL_X + SHELF_DEPTH * 0.5, SHELF_TOP, CLEANER_Z)
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


func _build_notes() -> void:
	# 隠し場所の小さな紙（仮の見た目：無地の紙）。取得はできない。謎の進行には結び付けない
	var paper := MeshKit.note_mat()
	# 棚板の裏：下向き
	var shelf_note := _note(paper, "ShelfNote", "shelf_note", Vector2(0.07, 0.05), SHELF_NOTE_POS - Vector3(0, 0.0012, 0))
	shelf_note.rotation.x = deg_to_rad(90.0)
	var sa := MeshKit.interact_area(self, "ShelfNoteArea", "shelf_note")
	MeshKit.shape_box(sa, Vector3(0.07, 0.004, 0.05), SHELF_NOTE_POS - Vector3(0, 0.002, 0))
	# タンクの真下の壁：部屋側（+x）向き
	var tank_note := _note(paper, "TankNote", "tank_note", Vector2(0.07, 0.05), TANK_NOTE_POS + Vector3(0.0012, 0, 0))
	tank_note.rotation.y = deg_to_rad(90.0)
	var ta := MeshKit.interact_area(self, "TankNoteArea", "tank_note")
	MeshKit.shape_box(ta, Vector3(0.004, 0.05, 0.07), TANK_NOTE_POS + Vector3(0.002, 0, 0))


func _note(mat: Material, node_name: String, _id: String, size: Vector2, pos: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


# ---------------------------------------------------------------- main.gd から呼ばれる（ペーパーホルダー）

func get_prompt(id: String) -> String:
	if id == "paper_cover":
		if holder_busy:
			return ""
		return "cover_close" if cover_open else "cover_open"
	return "examine"


func interact(id: String) -> String:
	if id == "paper_cover":
		toggle_cover()
		return ""
	return "paper_holder" if has_paper else "paper_holder_empty"
