extends Node3D
## 便器：本体（くぼみと少量の水）・便座リング・蓋。蓋と便座は後ろの蝶番を軸に開閉する。
## 座標は部屋と同じ（この節点は原点に置く）。左の壁 x=-0.9 にタンクをつけ、便器は +x を向く。
##
##   Toilet/Visual            … タンク・本体・水
##   Toilet/SeatPivot         … 便座リング（蝶番 x=-0.645, y=0.40）。子に照準用の判定 SeatArea
##   Toilet/LidPivot          … 蓋（蝶番 x=-0.675, y=0.43）。子に照準用の判定 LidArea
##   Toilet/TankLid           … 貯水タンクの陶器の蓋（蝶番なし）。子に照準用の判定 TankLidArea。
##                              開けると持ち上げ → 浴槽側へずらす → 立てる → 向きを変える → タンクと浴槽の間の壁際に下ろす
##   Toilet/LeverPivot        … タンク正面の洗浄レバー（flush_lever）。クリックで水を流す
##   Toilet/Collision         … 移動を止める本体とタンクの箱（interact_id = toilet）
##
## 水を流す（約4.7秒）：レバーが下がる → タンクの排水弁が開き、タンクの水位が下がる（浮き玉も下がる）→
## 便器の水が渦を巻いて一度上がって下がる → 排水弁が閉じ、タンクが再給水されて元の水位へ戻る。
## 流している間のクリックは無視する。人が座っている間（occupied）は蓋と便座を開閉できない。
##
## 開いた蓋はタンクの手前、上げた便座は蓋の手前に立つ（角度と蝶番の位置で重ならないようにしてある）。
## 蓋を閉じるときは、便座が上がっていれば先に便座を下ろしてから蓋を下ろす（蓋が便座を突き抜けない）。
## アニメーション中のクリックは無視する。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const WALL_X := -0.9
const RIM_Y := 0.40            # 便器の縁の高さ（便座の下面）
const LID_HINGE := Vector3(-0.675, 0.43, 0.0)
const SEAT_HINGE := Vector3(-0.645, RIM_Y, 0.0)
const LID_OPEN_DEG := 88.0
const SEAT_OPEN_DEG := 80.0
const SWING_TIME := 0.4

# 貯水タンク（外形 x -0.9〜-0.7, y 0.475〜0.925, z -0.2〜0.2。上の 0.025 が蓋）
const TANK_BOTTOM := 0.475
const TANK_BODY_TOP := 0.90
const TANK_WALL := 0.015
const TANK_WATER_Y := 0.80
const TANK_LID_SIZE := Vector3(0.21, 0.025, 0.41)
const TANK_LID_CLOSED := Vector3(WALL_X + 0.105, TANK_BODY_TOP + 0.0125, 0.0)
# 開けた蓋の置き場所：タンク（z ≥ -0.2）と浴槽（z ≤ -0.45）の間、左の壁に立てかける。
# 立てると 長さ0.41 が縦、幅0.21 が z、厚さ0.025 が x になる
const TANK_LID_PARKED := Vector3(WALL_X + 0.0225, 0.206, -0.325)
const TANK_LID_PARKED_ROT := Vector3(deg_to_rad(-90.0), deg_to_rad(90.0), 0.0)
const TANK_LIFT_Y := 1.0     # 持ち上げる高さ（蓋の中心）。タンク上面より上、上の棚より下
const TANK_MOVE_TIMES := [0.25, 0.3, 0.25, 0.2, 0.3]   # 持ち上げ・ずらす・立てる・向きを変える・下ろす
const TANK_WATER_LOW := 0.53
const BOWL_WATER_Y := 0.236
const LEVER_DOWN_DEG := 25.0    # 取っ手の先（+z）が下がる向き
const FLUSH_DRAIN_TIME := 1.2
const FLUSH_REFILL_TIME := 3.0
var lid_open := false
var seat_up := false
var busy := false
var tank_open := false
var tank_busy := false
var flushing := false
var occupied := false   # 人が座っている（main.gd が設定）

var lid_pivot: Node3D
var seat_pivot: Node3D
var tank_lid: Node3D
var lever_pivot: Node3D
var tank_water: MeshInstance3D
var tank_float: MeshInstance3D
var flapper: MeshInstance3D
var bowl_water: MeshInstance3D
var bowl_swirl: MeshInstance3D


func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_body(visual)
	_build_seat()
	_build_lid()
	_build_tank_lid()

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "toilet")
	body.set_meta("fixture", self)
	add_child(body)
	var tank_h := TANK_BODY_TOP - TANK_BOTTOM   # 蓋の部分は蓋の判定に任せる
	MeshKit.shape_box(body, Vector3(0.2, tank_h, 0.4), Vector3(WALL_X + 0.1, TANK_BOTTOM + tank_h * 0.5, 0.0))   # タンク
	MeshKit.shape_box(body, Vector3(0.4, RIM_Y, 0.36), Vector3(-0.5, RIM_Y * 0.5, 0.0))   # 本体


func _build_body(visual: Node3D) -> void:
	var porcelain := MeshKit.mat("porcelain", Color(0.92, 0.92, 0.92), 0.3)
	var inner := MeshKit.mat("bowl_inner", Color(0.82, 0.83, 0.84), 0.25)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	# 貯水タンク（中空。蓋は別ノード）とレバー
	_build_tank(visual, porcelain, metal)
	_build_lever(metal)
	# 台座と、くぼみの底（上面 y=0.23）
	MeshKit.box(visual, Vector3(0.26, 0.2, 0.22), Vector3(-0.53, 0.1, 0.0), porcelain, "Foot")
	MeshKit.box(visual, Vector3(0.4, 0.05, 0.36), Vector3(-0.5, 0.205, 0.0), inner, "BowlBottom")
	# 縁の壁（内側の開口 x -0.64〜-0.36, z -0.12〜0.12、深さ 0.17）
	var wall_h := RIM_Y - 0.23
	var wy := 0.23 + wall_h * 0.5
	MeshKit.box(visual, Vector3(0.06, wall_h, 0.36), Vector3(-0.67, wy, 0.0), porcelain)
	MeshKit.box(visual, Vector3(0.06, wall_h, 0.36), Vector3(-0.33, wy, 0.0), porcelain)
	MeshKit.box(visual, Vector3(0.28, wall_h, 0.06), Vector3(-0.5, wy, -0.15), porcelain)
	MeshKit.box(visual, Vector3(0.28, wall_h, 0.06), Vector3(-0.5, wy, 0.15), porcelain)
	# 底の排水口（暗い穴）と少量の水
	MeshKit.cylinder(visual, 0.035, 0.002, Vector3(-0.5, 0.231, 0.0), MeshKit.mat("bowl_hole", Color(0.18, 0.2, 0.22), 0.6))
	bowl_water = MeshKit.box(visual, Vector3(0.2, 0.004, 0.16), Vector3(-0.5, BOWL_WATER_Y, 0.0), MeshKit.water_surface_mat(), "BowlWater")
	var water := bowl_water
	# 流しているときだけ見える渦（流れる模様の円盤を回す）
	bowl_swirl = MeshKit.cylinder(visual, 0.07, 0.003, Vector3(-0.5, BOWL_WATER_Y + 0.004, 0.0), MeshKit.new_stream_mat(), "BowlSwirl", -1.0, 20)
	bowl_swirl.visible = false
	bowl_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 蝶番の金具
	for z in [-0.12, 0.12]:
		MeshKit.box(visual, Vector3(0.04, 0.03, 0.03), Vector3(-0.665, RIM_Y + 0.015, z), metal)


func _build_tank(visual: Node3D, porcelain: Material, metal: Material) -> void:
	var tank := Node3D.new()
	tank.name = "Tank"
	visual.add_child(tank)
	var t := TANK_WALL
	var x0 := WALL_X
	var x1 := WALL_X + 0.2
	var wall_y0 := TANK_BOTTOM + 0.02
	var wall_h := TANK_BODY_TOP - wall_y0
	var wy := wall_y0 + wall_h * 0.5
	MeshKit.box(tank, Vector3(0.2, 0.02, 0.4), Vector3(x0 + 0.1, TANK_BOTTOM + 0.01, 0.0), porcelain, "Bottom")
	MeshKit.box(tank, Vector3(t, wall_h, 0.4), Vector3(x1 - t * 0.5, wy, 0.0), porcelain, "Front")
	MeshKit.box(tank, Vector3(t, wall_h, 0.4), Vector3(x0 + t * 0.5, wy, 0.0), porcelain, "Back")
	for zz in [-0.2 + t * 0.5, 0.2 - t * 0.5]:
		MeshKit.box(tank, Vector3(0.2 - t * 2.0, wall_h, t), Vector3(x0 + 0.1, wy, zz), porcelain)

	# 中の部品（簡略化。個別の操作はなし）
	var inner_x := Vector2(x0 + t, x1 - t)
	tank_water = MeshKit.box(tank, Vector3(inner_x.y - inner_x.x - 0.002, 0.003, 0.4 - t * 2.0 - 0.002),
			Vector3((inner_x.x + inner_x.y) * 0.5, TANK_WATER_Y, 0.0), MeshKit.water_surface_mat(), "TankWater")
	tank_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plastic := MeshKit.mat("tank_parts", Color(0.82, 0.84, 0.86), 0.5)
	var rubber := MeshKit.mat("rubber", Color(0.12, 0.12, 0.13), 0.9)
	# 給水弁（ボールタップ）：縦の給水管と、腕の先の浮き玉
	var fill_x := x0 + 0.04
	var fill_z := 0.14
	MeshKit.cylinder(tank, 0.01, 0.35, Vector3(fill_x, wall_y0 + 0.175, fill_z), plastic, "FillValve")
	MeshKit.cylinder(tank, 0.02, 0.03, Vector3(fill_x, 0.855, fill_z), plastic, "FillValveHead")
	MeshKit.pipe(tank, [Vector3(fill_x, 0.85, fill_z), Vector3(x0 + 0.1, 0.815, 0.03)], 0.004, metal)
	tank_float = MeshKit.sphere(tank, 0.03, Vector3(x0 + 0.1, TANK_WATER_Y + 0.005, 0.02), MeshKit.mat("tank_float", Color(0.95, 0.95, 0.95), 0.4))
	tank_float.name = "Float"
	# 排水弁：底の座と黒いゴム弁、オーバーフロー管
	var flush := Vector3(x0 + 0.1, wall_y0, -0.09)
	MeshKit.cylinder(tank, 0.04, 0.01, flush + Vector3(0, 0.005, 0), plastic, "FlushValveSeat")
	flapper = MeshKit.cylinder(tank, 0.033, 0.012, flush + Vector3(0.0, 0.016, 0.0), rubber, "Flapper")
	MeshKit.cylinder(tank, 0.013, 0.33, flush + Vector3(-0.045, 0.165, 0.0), plastic, "OverflowTube")
	# レバーの腕（外のレバーから中へ）と、ゴム弁へ下りるチェーン
	var arm_end := Vector3(x0 + 0.1, 0.86, -0.07)
	MeshKit.pipe(tank, [Vector3(x1 - t, 0.86, 0.14), arm_end], 0.004, metal)
	var chain_mat := MeshKit.mat("chain", Color(0.7, 0.7, 0.72), 0.3, 0.9)
	var chain_bottom := flush + Vector3(0.0, 0.024, 0.0)
	for k in 30:
		MeshKit.sphere(tank, 0.0022, arm_end.lerp(chain_bottom, float(k) / 29.0), chain_mat)
	# 外の給水管：壁からタンクの底へ（止水栓つき）
	MeshKit.pipe(visual, [Vector3(x0 + 0.004, 0.22, fill_z), Vector3(fill_x, 0.22, fill_z), Vector3(fill_x, TANK_BOTTOM, fill_z)], 0.008, metal)
	MeshKit.box(visual, Vector3(0.02, 0.025, 0.03), Vector3(fill_x, 0.27, fill_z), metal, "StopValve")


func _build_lever(metal: Material) -> void:
	# タンク正面（x = -0.7）から出た短い軸と、+z 側へ伸びる取っ手。軸を中心に下へ回す
	lever_pivot = Node3D.new()
	lever_pivot.name = "LeverPivot"
	lever_pivot.position = Vector3(WALL_X + 0.2, 0.865, 0.12)
	add_child(lever_pivot)
	MeshKit.box(lever_pivot, Vector3(0.025, 0.016, 0.016), Vector3(0.0125, 0, 0), metal, "Shaft")
	MeshKit.box(lever_pivot, Vector3(0.012, 0.014, 0.055), Vector3(0.025, 0, 0.0275), metal, "Handle")
	var area := MeshKit.interact_area(lever_pivot, "LeverArea", "flush_lever", self)
	MeshKit.shape_box(area, Vector3(0.04, 0.035, 0.075), Vector3(0.02, 0, 0.025))


func _process(delta: float) -> void:
	if flushing:
		bowl_swirl.rotation.y -= delta * 9.0
		var m: StandardMaterial3D = bowl_swirl.material_override
		m.uv1_offset.x += delta * 1.5


## 水を流す。流している間は何もしない。
func flush() -> void:
	if flushing:
		return
	flushing = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# レバーを下げ、排水弁を開ける
	tween.tween_property(lever_pivot, "rotation:x", deg_to_rad(LEVER_DOWN_DEG), 0.15)
	tween.parallel().tween_property(flapper, "rotation:z", deg_to_rad(60.0), 0.2)
	tween.tween_callback(func() -> void: bowl_swirl.visible = true)
	# タンクの水位が下がる（浮き玉もついていく）。便器の水は渦を巻いて少し上がる
	tween.tween_method(_set_tank_level, TANK_WATER_Y, TANK_WATER_LOW, FLUSH_DRAIN_TIME)
	tween.parallel().tween_property(bowl_water, "position:y", BOWL_WATER_Y + 0.015, FLUSH_DRAIN_TIME * 0.5)
	tween.parallel().tween_property(lever_pivot, "rotation:x", 0.0, 0.3).set_delay(0.35)
	# 排水弁が閉じ、便器の水が引いて元に戻る。タンクは再給水
	tween.tween_property(flapper, "rotation:z", 0.0, 0.2)
	tween.parallel().tween_property(bowl_water, "position:y", BOWL_WATER_Y - 0.01, 0.5)
	tween.tween_callback(func() -> void: bowl_swirl.visible = false)
	tween.tween_method(_set_tank_level, TANK_WATER_LOW, TANK_WATER_Y, FLUSH_REFILL_TIME)
	tween.parallel().tween_property(bowl_water, "position:y", BOWL_WATER_Y, 1.0)
	tween.tween_callback(func() -> void: flushing = false)


func _set_tank_level(y: float) -> void:
	tank_water.position.y = y
	tank_float.position.y = y + 0.005


## 座れる状態か：蓋が開き、便座が下りていて、動いていない。
func can_sit() -> bool:
	return lid_open and not seat_up and not busy and not occupied


func _build_seat() -> void:
	# 便座リング：蝶番からの長さ 0.37、幅 0.34、厚さ 0.025。開口 x 0.035〜0.30（蝶番基準）, z ±0.115
	seat_pivot = Node3D.new()
	seat_pivot.name = "SeatPivot"
	seat_pivot.position = SEAT_HINGE
	add_child(seat_pivot)
	var seat_mat := MeshKit.mat("seat", Color(0.96, 0.96, 0.95), 0.4)
	var t := 0.025
	var parts := [
		[Vector3(0.035, t, 0.34), Vector3(0.0175, t * 0.5, 0.0)],      # 後ろ
		[Vector3(0.07, t, 0.34), Vector3(0.335, t * 0.5, 0.0)],        # 前
		[Vector3(0.265, t, 0.055), Vector3(0.1675, t * 0.5, -0.1425)], # 左右
		[Vector3(0.265, t, 0.055), Vector3(0.1675, t * 0.5, 0.1425)],
	]
	var area := MeshKit.interact_area(seat_pivot, "SeatArea", "toilet_seat", self)
	for p in parts:
		MeshKit.box(seat_pivot, p[0], p[1], seat_mat)
		MeshKit.shape_box(area, p[0], p[1])


func _build_lid() -> void:
	# 蓋：蝶番からの長さ 0.40、幅 0.36、厚さ 0.02。閉じると便座の 5mm 上に載る
	lid_pivot = Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = LID_HINGE
	add_child(lid_pivot)
	var size := Vector3(0.40, 0.02, 0.36)
	var center := Vector3(0.20, 0.01, 0.0)
	MeshKit.box(lid_pivot, size, center, MeshKit.mat("lid", Color(0.95, 0.95, 0.94), 0.4), "Lid")
	var area := MeshKit.interact_area(lid_pivot, "LidArea", "toilet_lid", self)
	MeshKit.shape_box(area, size, center)


func _build_tank_lid() -> void:
	tank_lid = Node3D.new()
	tank_lid.name = "TankLid"
	tank_lid.position = TANK_LID_CLOSED
	add_child(tank_lid)
	MeshKit.box(tank_lid, TANK_LID_SIZE, Vector3.ZERO, MeshKit.mat("porcelain", Color(0.92, 0.92, 0.92), 0.3), "Lid")
	var area := MeshKit.interact_area(tank_lid, "TankLidArea", "tank_lid", self)
	MeshKit.shape_box(area, TANK_LID_SIZE + Vector3(0.006, 0.006, 0.006), Vector3.ZERO)


## タンクの蓋を開ける（横の壁際へ置く）／戻す。陶器の蓋なので蝶番では回さず、持ち上げて動かす。
## 経路は上の棚・入浴剤・開いた便器の蓋・ペーパーホルダーと交わらない（テストで毎フレーム確認）。
func toggle_tank() -> void:
	if tank_busy:
		return
	tank_busy = true
	tank_open = not tank_open
	var lifted := Vector3(TANK_LID_CLOSED.x, TANK_LIFT_Y, TANK_LID_CLOSED.z)
	var beside := Vector3(TANK_LID_CLOSED.x + 0.005, TANK_LIFT_Y, TANK_LID_PARKED.z)
	var stood := Vector3(TANK_LID_PARKED_ROT.x, 0.0, 0.0)
	var tween := _swing_tween()
	var d: Array = TANK_MOVE_TIMES
	if tank_open:
		tween.tween_property(tank_lid, "position", lifted, d[0])
		tween.tween_property(tank_lid, "position", beside, d[1])
		tween.tween_property(tank_lid, "rotation", stood, d[2])
		tween.tween_property(tank_lid, "rotation", TANK_LID_PARKED_ROT, d[3])
		tween.tween_property(tank_lid, "position", TANK_LID_PARKED, d[4])
	else:
		tween.tween_property(tank_lid, "position", beside, d[4])
		tween.tween_property(tank_lid, "rotation", stood, d[3])
		tween.tween_property(tank_lid, "rotation", Vector3.ZERO, d[2])
		tween.tween_property(tank_lid, "position", lifted, d[1])
		tween.tween_property(tank_lid, "position", TANK_LID_CLOSED, d[0])
	tween.tween_callback(func() -> void: tank_busy = false)


## 蓋を開ける／閉める。閉じるときに便座が上がっていれば、先に便座を下ろす。
func toggle_lid() -> void:
	if busy:
		return
	busy = true
	var tween := _swing_tween()
	if lid_open:
		if seat_up:
			seat_up = false
			tween.tween_property(seat_pivot, "rotation:z", 0.0, SWING_TIME)
		lid_open = false
		tween.tween_property(lid_pivot, "rotation:z", 0.0, SWING_TIME)
	else:
		lid_open = true
		tween.tween_property(lid_pivot, "rotation:z", deg_to_rad(LID_OPEN_DEG), SWING_TIME)
	tween.tween_callback(func() -> void: busy = false)


## 便座を上げる／下ろす。蓋が閉じているときは何もしない（便座は蓋の下）。
func toggle_seat() -> void:
	if busy or not lid_open:
		return
	busy = true
	seat_up = not seat_up
	var tween := _swing_tween()
	tween.tween_property(seat_pivot, "rotation:z", deg_to_rad(SEAT_OPEN_DEG) if seat_up else 0.0, SWING_TIME)
	tween.tween_callback(func() -> void: busy = false)


func _swing_tween() -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	if id == "toilet":
		return "examine"
	if id == "flush_lever":
		return "" if flushing else "flush"
	if id == "tank_lid":
		if tank_busy:
			return ""
		return "tank_close" if tank_open else "tank_open"
	if busy or occupied:
		return ""
	if id == "toilet_seat" and lid_open:
		return "seat_down" if seat_up else "seat_up"
	return "lid_close" if lid_open else "lid_open"


func interact(id: String) -> String:
	match id:
		"toilet":
			return "toilet"
		"tank_lid":
			toggle_tank()
		"flush_lever":
			flush()
		"toilet_lid":
			if not occupied:
				toggle_lid()
		"toilet_seat":
			if occupied:
				return ""
			# 蓋が閉じているときに便座の縁を狙った場合は、蓋を開ける
			if lid_open:
				toggle_seat()
			else:
				toggle_lid()
	return ""
