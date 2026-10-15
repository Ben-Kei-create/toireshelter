extends Node3D
## 洗面台：右の壁に付けた小さなボウル（くぼみ・排水口・ゴム栓・水面）、蛇口、下の排水管とトラップ。
## 座標は部屋と同じ（この節点は原点に置く）。床（ボウルの下）にはドライバーが落ちている。
##
## 水位 level は 0（空）〜1（満水）。浴槽と同じく流量の差で計算する:
##   蛇口が出ている間  +1/FILL_TIME 毎秒
##   栓が抜けている間  -1/DRAIN_TIME 毎秒
## 満水の水面は縁より 2cm 下（WATER_MAX_Y）で止まる。水面に当たり判定はなく、栓の操作を遮らない。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const FaucetScript := preload("res://scripts/faucet.gd")
const TEX_PIPE := preload("res://assets/textures/surfaces/surface_08.png")
const TEX_PIPE_WALLPAPER := preload("res://assets/textures/surfaces/surface_05.png")

const FILL_TIME := 12.0
const DRAIN_TIME := 8.0

const WALL_X := 0.9
const Z := 0.1                                    # ボウルの中心（壁沿いの方向）
const OUTER := AABB(Vector3(0.52, 0.74, -0.15), Vector3(0.38, 0.11, 0.5))   # ボウルの外形（上面 y=0.85）
const CAVITY_X := Vector2(0.555, 0.825)           # くぼみ（奥の縁は蛇口の台として広め）
const CAVITY_Z := Vector2(-0.11, 0.31)
const BOTTOM_Y := 0.76
const WATER_MIN_Y := BOTTOM_Y + 0.003
const WATER_MAX_Y := 0.83                         # 縁 0.85 の 2cm 下
const DRAIN_POS := Vector3(0.69, BOTTOM_Y, Z)     # くぼみの中央。排水管はここから下りる
const PLUG_OUT_POS := Vector3(0.76, BOTTOM_Y, Z - 0.09)
const PLUG_RADIUS := 0.017
const PLUG_HEIGHT := 0.012

const SOAP_POS := Vector3(0.64, BOTTOM_Y, Z + 0.18)   # 溶かすとき、くぼみの底に置く位置
const SOAP_FLOOR := Vector3(0.6, 0.0, 0.05)           # 固形せっけんが落ちている床（洗面台の下）
const SOAP_SOAK_LEVEL := 0.4                            # この水位以上に浸かると溶けはじめる
const SOAP_TIME := 8.0                                  # 浸かり続けて溶けきるまで（秒）
const COIN_RADIUS := 0.0118
const DRAIN_HOLE_RADIUS := 0.0105   # 十円玉（半径 1.18cm）のほうが少し大きい：栓にしたとき、穴をふさいで輪にのる
const COIN_SEAT_Y := 0.0060         # 栓をしたときの十円玉の中心の高さ（穴の黒い円盤の上面 0.005 の上にのる）

signal soap_dissolved

## 栓は初めからない（排水口はむき出し）。十円玉を排水口に置くとふたになり、水が溜まる。
var level := 0.0
var plug_in := false       # 排水口が塞がれているか（＝十円玉のふた）
var soap_soak := 0.0       # せっけんが水に浸かった時間（秒）
var soap_gone := false
var soap_taken := false     # 床から拾った
var soap_in_bowl := false   # 洗面台の水に入れた
var sinker_taken := false

var faucet: FaucetScript
var _water: MeshInstance3D
var _plug: Node3D
var _soap: Node3D
var _floor_soap: Node3D
var _floor_soap_area: Area3D
var _sinker_area: Area3D
var _sinker: Node3D


func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_bowl(visual)
	_build_pipes(visual)
	_build_plug()
	_build_faucet()

	_water = MeshInstance3D.new()
	_water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(CAVITY_X.y - CAVITY_X.x - 0.004, CAVITY_Z.y - CAVITY_Z.x - 0.004)
	_water.mesh = plane
	_water.material_override = MeshKit.water_surface_mat()
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.position = Vector3((CAVITY_X.x + CAVITY_X.y) * 0.5, WATER_MIN_Y, (CAVITY_Z.x + CAVITY_Z.y) * 0.5)
	add_child(_water)
	_update_water()


func _process(delta: float) -> void:
	advance(delta)


## 水位を delta 秒ぶん進める（テストからも呼ぶ）。
func advance(delta: float) -> void:
	var rate := 0.0
	if soap_in_bowl and not soap_gone and level >= SOAP_SOAK_LEVEL:
		soap_soak = minf(SOAP_TIME, soap_soak + delta)
		_update_soap()
		if soap_soak >= SOAP_TIME:
			_dissolve_soap()
	if faucet.is_on:
		rate += 1.0 / FILL_TIME
	if not plug_in:
		rate -= 1.0 / DRAIN_TIME
	level = clampf(level + rate * delta, 0.0, 1.0)
	_update_water()


func water_y() -> float:
	return lerpf(WATER_MIN_Y, WATER_MAX_Y, level)


## 十円玉のふたを置く／取る。
func set_plug(inserted: bool) -> void:
	plug_in = inserted
	_plug.visible = inserted
	_plug.position = DRAIN_POS + Vector3(0.0, COIN_SEAT_Y, 0.0)


func _update_soap() -> void:
	if _soap == null:
		return
	var k := 1.0 - soap_soak / SOAP_TIME * 0.85
	_soap.scale = Vector3(k, maxf(k, 0.3), k)
	_soap.visible = soap_in_bowl and not soap_gone


func _dissolve_soap() -> void:
	soap_gone = true
	_soap.visible = false
	_sinker.visible = not sinker_taken
	_set_area(_sinker_area, not sinker_taken)
	soap_dissolved.emit()


func take_sinker() -> void:
	sinker_taken = true
	_sinker.visible = false
	_set_area(_sinker_area, false)


func take_soap() -> void:
	soap_taken = true
	_floor_soap.visible = false
	_set_area(_floor_soap_area, false)


## せっけんを水に入れる。結果："ok" / "dry"（ふたをして水を溜めてからでないと沈まない）。
func place_soap() -> String:
	if not plug_in or level < SOAP_SOAK_LEVEL:
		return "dry"
	soap_in_bowl = true
	_update_soap()
	return "ok"


func _set_area(a: Area3D, on: bool) -> void:
	if a:
		a.collision_layer = MeshKit.LAYER_INTERACT if on else 0


## セーブから戻す。
func restore(coin_on: bool, soaked: float, gone: bool, taken: bool, p_soap_taken := false, p_in_bowl := false) -> void:
	soap_soak = soaked
	soap_gone = gone
	sinker_taken = taken
	soap_in_bowl = p_in_bowl
	soap_taken = p_soap_taken or p_in_bowl or gone
	_floor_soap.visible = not soap_taken
	_set_area(_floor_soap_area, not soap_taken)
	_update_soap()
	_sinker.visible = gone and not taken
	_set_area(_sinker_area, gone and not taken)
	set_plug(coin_on)


func _update_water() -> void:
	if _water == null:
		return
	_water.visible = level > 0.0005
	_water.position.y = water_y()
	faucet.stream_floor_y = water_y() if _water.visible else BOTTOM_Y


# ---------------------------------------------------------------- 組み立て

func _build_bowl(visual: Node3D) -> void:
	var porcelain := MeshKit.mat("palace_gold_body", Color(0.74, 0.55, 0.2), 0.28, 0.8)
	var inner := MeshKit.mat("basin_inner", Color(0.82, 0.86, 0.88), 0.3)
	var o0 := OUTER.position
	var o1 := OUTER.end
	var wall_h := o1.y - BOTTOM_Y
	var wy := BOTTOM_Y + wall_h * 0.5
	var cz := (CAVITY_Z.x + CAVITY_Z.y) * 0.5
	var cl := CAVITY_Z.y - CAVITY_Z.x
	var parts := [
		[Vector3(o1.x - o0.x, BOTTOM_Y - o0.y, o1.z - o0.z), Vector3((o0.x + o1.x) * 0.5, (o0.y + BOTTOM_Y) * 0.5, (o0.z + o1.z) * 0.5)],   # 底
		[Vector3(CAVITY_X.x - o0.x, wall_h, o1.z - o0.z), Vector3((o0.x + CAVITY_X.x) * 0.5, wy, (o0.z + o1.z) * 0.5)],   # 手前の縁
		[Vector3(o1.x - CAVITY_X.y, wall_h, o1.z - o0.z), Vector3((CAVITY_X.y + o1.x) * 0.5, wy, (o0.z + o1.z) * 0.5)],   # 奥（蛇口の台）
		[Vector3(CAVITY_X.y - CAVITY_X.x, wall_h, CAVITY_Z.x - o0.z), Vector3((CAVITY_X.x + CAVITY_X.y) * 0.5, wy, (o0.z + CAVITY_Z.x) * 0.5)],
		[Vector3(CAVITY_X.y - CAVITY_X.x, wall_h, o1.z - CAVITY_Z.y), Vector3((CAVITY_X.x + CAVITY_X.y) * 0.5, wy, (CAVITY_Z.y + o1.z) * 0.5)],
	]
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "sink")
	add_child(body)
	for p in parts:
		MeshKit.box(visual, p[0], p[1], porcelain)
		MeshKit.shape_box(body, p[0], p[1])
	# くぼみの底面だけ薄い水色（底の箱の上面から 1mm 上。側面は縁に隠れる）
	MeshKit.box(visual, Vector3(CAVITY_X.y - CAVITY_X.x, 0.002, cl), Vector3((CAVITY_X.x + CAVITY_X.y) * 0.5, BOTTOM_Y + 0.0, cz), inner, "InnerBottom")
	# 排水口：金属の輪と暗い穴（栓をすると隠れる）
	var metal := MeshKit.mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	MeshKit.cylinder(visual, 0.021, 0.003, DRAIN_POS + Vector3(0, 0.0025, 0), metal, "DrainRing")
	MeshKit.cylinder(visual, DRAIN_HOLE_RADIUS, 0.001, DRAIN_POS + Vector3(0, 0.0045, 0), MeshKit.mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0), "DrainHole")
	# 壁の受け金具
	MeshKit.box(visual, Vector3(0.03, 0.05, 0.4), Vector3(WALL_X - 0.015, 0.715, Z), metal)


func _build_pipes(visual: Node3D) -> void:
	# 排水管：ボウルの底から下りて U 字のトラップを通り、壁へ（当たり判定なし）。
	# U 字の底は低め（約0.36m）。立った目線ではボウルの陰になりやすい
	var pipe_mat := MeshKit.tiled_mat("pipe_tex", TEX_PIPE, 0.12, Color(1.1, 1.1, 1.12), 0.35)
	pipe_mat.metallic = 0.35
	# 配管の裏の壁だけ、配管柄の壁紙（洗面台の下の限られた範囲。浴室全体の樹脂パネルはそのまま）
	var paper := MeshKit.tiled_mat("pipe_wallpaper", TEX_PIPE_WALLPAPER, 0.24, Color.WHITE, 0.9)
	var pw := MeshKit.box(visual, Vector3(0.001, OUTER.position.y - 0.03, OUTER.size.z), Vector3(WALL_X - 0.0005, (OUTER.position.y + 0.03) * 0.5 + 0.0, OUTER.get_center().z), paper, "PipeWallpaper")
	pw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tail_x := DRAIN_POS.x
	var bend_y := 0.40
	var pts := [Vector3(tail_x, OUTER.position.y, Z), Vector3(tail_x, bend_y, Z)]
	var bend_c := Vector3(tail_x + 0.045, bend_y, Z)
	for i in range(1, 7):
		var a := PI * i / 6.0
		pts.append(bend_c + Vector3(-cos(a) * 0.045, -sin(a) * 0.045, 0.0))
	pts.append(Vector3(tail_x + 0.09, 0.47, Z))
	pts.append(Vector3(WALL_X - 0.004, 0.47, Z))
	MeshKit.pipe(visual, pts, 0.016, pipe_mat)
	var flange := MeshKit.cylinder(visual, 0.03, 0.008, Vector3(WALL_X - 0.004, 0.47, Z), pipe_mat)
	flange.rotation.z = deg_to_rad(90.0)


func _build_plug() -> void:
	_plug = Node3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	# 十円玉のふた（排水口の穴よりひと回り大きい円盤。穴をふさぐように、輪の上にはめ込む）
	MeshKit.coin10_disc(_plug, COIN_RADIUS)
	_build_soap()
	# 照準用の判定：栓をした位置と抜いた位置の両方を覆う（水面より下でも当たる）
	var area := MeshKit.interact_area(self, "PlugArea", "sink_plug", self)
	MeshKit.shape_box(area, Vector3(0.08, 0.04, 0.08), DRAIN_POS + Vector3(0, 0.02, 0))
	set_plug(false)


func _build_soap() -> void:
	# 固形せっけんは洗面台の下の床に落ちている（拾って、水を溜めた洗面台に入れる）。溶けると中から鉛のおもり
	var sm := MeshKit.mat("soap", Color(0.93, 0.78, 0.8), 0.35)
	_floor_soap = Node3D.new()
	_floor_soap.name = "FloorSoap"
	_floor_soap.position = SOAP_FLOOR + Vector3(0, 0.011, 0)
	_floor_soap.rotation.y = deg_to_rad(35.0)
	add_child(_floor_soap)
	MeshKit.box(_floor_soap, Vector3(0.07, 0.022, 0.045), Vector3.ZERO, sm, "Bar")
	_floor_soap_area = MeshKit.interact_area(_floor_soap, "Pickup", "sink_soap")
	MeshKit.shape_box(_floor_soap_area, Vector3(0.16, 0.08, 0.12), Vector3(0, 0.02, 0))
	# 洗面台に入れたせっけん（判定なし。おもりへの照準をさえぎらない）
	_soap = Node3D.new()
	_soap.name = "Soap"
	_soap.position = SOAP_POS + Vector3(0, 0.011, 0)
	_soap.rotation.y = deg_to_rad(20.0)
	_soap.visible = false
	add_child(_soap)
	MeshKit.box(_soap, Vector3(0.07, 0.022, 0.045), Vector3.ZERO, sm, "Bar")
	_sinker = Node3D.new()
	_sinker.name = "Sinker"
	_sinker.position = SOAP_POS + Vector3(0, 0.009, 0)
	_sinker.visible = false
	add_child(_sinker)
	MeshKit.sphere(_sinker, 0.016, Vector3.ZERO, MeshKit.mat("lead", Color(0.35, 0.36, 0.4), 0.35, 0.8))
	_sinker_area = MeshKit.interact_area(_sinker, "SinkerArea", "sink_sinker")
	MeshKit.shape_box(_sinker_area, Vector3(0.07, 0.05, 0.07), Vector3.ZERO)
	_set_area(_sinker_area, false)


## 固形せっけんの持ち物の拡大モデル。
static func soap_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.1, 0.03, 0.065), Vector3.ZERO, MeshKit.mat("soap_zoom", Color(0.93, 0.78, 0.8), 0.35), "Bar")
	return n


## 鉛のおもりの持ち物の拡大モデル。
static func sinker_model() -> Node3D:
	var n := Node3D.new()
	var m := MeshKit.sphere(n, 0.03, Vector3.ZERO, MeshKit.mat("lead_zoom", Color(0.35, 0.36, 0.4), 0.35, 0.8))
	m.scale = Vector3(1.0, 0.8, 1.0)
	return n


func _build_faucet() -> void:
	# 奥の縁（蛇口の台）に立つ単水栓。吐水口の先はくぼみの上
	faucet = FaucetScript.new()
	faucet.name = "Faucet"
	faucet.position = Vector3(WALL_X - 0.04, OUTER.end.y, Z)
	var metal := MeshKit.mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	MeshKit.box(faucet, Vector3(0.04, 0.12, 0.04), Vector3(0, 0.06, 0), metal)
	MeshKit.box(faucet, Vector3(0.12, 0.03, 0.03), Vector3(-0.05, 0.11, 0), metal)
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 0.12, 0)
	faucet.add_child(lever)
	MeshKit.box(lever, Vector3(0.07, 0.01, 0.016), Vector3(-0.03, 0.005, 0), metal)
	faucet.setup(Vector3(-0.1, 0.095, 0), BOTTOM_Y, lever, 0.004)
	var area := MeshKit.interact_area(faucet, "FaucetArea", "sink_faucet", faucet)
	MeshKit.shape_box(area, Vector3(0.16, 0.1, 0.06), Vector3(-0.04, 0.09, 0))
	add_child(faucet)


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	if id == "sink_plug":
		return "coin10_take" if plug_in else "examine"
	return "examine"


func interact(id: String) -> String:
	return ""
