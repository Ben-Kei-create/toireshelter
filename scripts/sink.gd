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

var level := 0.0
var plug_in := true

var faucet: FaucetScript
var _water: MeshInstance3D
var _plug: Node3D


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
	if faucet.is_on:
		rate += 1.0 / FILL_TIME
	if not plug_in:
		rate -= 1.0 / DRAIN_TIME
	level = clampf(level + rate * delta, 0.0, 1.0)
	_update_water()


func water_y() -> float:
	return lerpf(WATER_MIN_Y, WATER_MAX_Y, level)


func set_plug(inserted: bool) -> void:
	plug_in = inserted
	if inserted:
		_plug.position = DRAIN_POS
		_plug.rotation = Vector3.ZERO
	else:
		_plug.position = PLUG_OUT_POS + Vector3(0.0, PLUG_RADIUS, 0.0)   # 横倒しで底に置く
		_plug.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)


func _update_water() -> void:
	if _water == null:
		return
	_water.visible = level > 0.0005
	_water.position.y = water_y()
	faucet.stream_floor_y = water_y() if _water.visible else BOTTOM_Y


# ---------------------------------------------------------------- 組み立て

func _build_bowl(visual: Node3D) -> void:
	var porcelain := MeshKit.mat("porcelain", Color(0.92, 0.92, 0.92), 0.3)
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
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.cylinder(visual, 0.021, 0.003, DRAIN_POS + Vector3(0, 0.0025, 0), metal, "DrainRing")
	MeshKit.cylinder(visual, 0.014, 0.001, DRAIN_POS + Vector3(0, 0.0045, 0), MeshKit.mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0), "DrainHole")
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
	var rubber := MeshKit.mat("rubber", Color(0.12, 0.12, 0.13), 0.9)
	MeshKit.cylinder(_plug, PLUG_RADIUS, PLUG_HEIGHT, Vector3(0, PLUG_HEIGHT * 0.5, 0), rubber, "Rubber", PLUG_RADIUS * 0.85)
	MeshKit.box(_plug, Vector3(0.01, 0.008, 0.003), Vector3(0, PLUG_HEIGHT + 0.004, 0),
			MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8), "Knob")
	# 照準用の判定：栓をした位置と抜いた位置の両方を覆う（水面より下でも当たる）
	var area := MeshKit.interact_area(self, "PlugArea", "sink_plug", self)
	var lo := Vector3(minf(DRAIN_POS.x, PLUG_OUT_POS.x) - 0.035, BOTTOM_Y, minf(DRAIN_POS.z, PLUG_OUT_POS.z) - 0.035)
	var hi := Vector3(maxf(DRAIN_POS.x, PLUG_OUT_POS.x) + 0.035, BOTTOM_Y + 0.04, maxf(DRAIN_POS.z, PLUG_OUT_POS.z) + 0.035)
	MeshKit.shape_box(area, hi - lo, (hi + lo) * 0.5)
	set_plug(true)


func _build_faucet() -> void:
	# 奥の縁（蛇口の台）に立つ単水栓。吐水口の先はくぼみの上
	faucet = FaucetScript.new()
	faucet.name = "Faucet"
	faucet.position = Vector3(WALL_X - 0.04, OUTER.end.y, Z)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
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
		return "plug_pull" if plug_in else "plug_insert"
	return "examine"


func interact(id: String) -> String:
	if id == "sink_plug":
		set_plug(not plug_in)
	return ""
