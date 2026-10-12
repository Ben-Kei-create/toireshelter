extends Node3D
## 浴槽：内側のくぼみ・水面・排水口とゴム栓（チェーン付き）・浴槽用の蛇口。
## この節点は浴槽の中心（床の高さ）に置く。ローカル座標で外形 x ±0.9, z ±0.375、高さ 0.55。
## 奥（-z）が部屋の奥の壁。
##
## 水位 level は 0（空）〜1（満水）。給水と排水は流量の差で計算する:
##   蛇口が出ている間  +1/FILL_TIME 毎秒
##   栓が抜けている間  -1/DRAIN_TIME 毎秒
## 満水でも水面は縁より 5cm 下（WATER_MAX_Y）で止まり、あふれない。
## 一時停止中は _process が止まるので、水位も水流の模様も止まる。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const FaucetScript := preload("res://scripts/faucet.gd")

const FILL_TIME := 40.0    # 空→満水（秒）
const DRAIN_TIME := 25.0   # 満水→空（秒）。給水より速い

const HALF := Vector3(0.9, 0.55, 0.375)   # 外形の半分（y は高さそのもの）
const WALL := 0.08
const BOTTOM_Y := 0.10                     # くぼみの底
const WATER_MIN_Y := BOTTOM_Y + 0.004
const WATER_MAX_Y := 0.50                  # 満水時の水面（縁 0.55 より下）
const DRAIN_POS := Vector3(0.62, BOTTOM_Y, 0.0)
const PLUG_OUT_POS := Vector3(0.71, BOTTOM_Y, -0.17)
const CHAIN_ANCHOR := Vector3(0.62, 0.42, -HALF.z + WALL + 0.004)   # 奥の内壁のあふれ口
const NOTE_SIZE := Vector2(0.07, 0.035)
const NOTE_POS := Vector3(-0.25, 0.524, HALF.z - WALL)   # 手前の縁の裏（内側の面）。満水 0.50 より上、縁 0.55 より下
const PLUG_RADIUS := 0.024
const PLUG_HEIGHT := 0.016

var level := 0.0
var plug_in := true
var was_filled := false   # 一度でも水が入ったか（「濡れている」表示用）

var faucet: FaucetScript
var _water: MeshInstance3D
var _plug: Node3D
var _chain: Node3D


func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_shell(visual)
	_build_drain(visual)
	_build_plug()
	_build_faucet()
	_build_note()

	_water = MeshInstance3D.new()
	_water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2((HALF.x - WALL) * 2.0 - 0.004, (HALF.z - WALL) * 2.0 - 0.004)
	_water.mesh = plane
	_water.material_override = MeshKit.water_surface_mat()
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if level > 0.02:
		was_filled = true
	_update_water()


func water_y() -> float:
	return lerpf(WATER_MIN_Y, WATER_MAX_Y, level)


func set_plug(inserted: bool) -> void:
	plug_in = inserted
	if inserted:
		_plug.position = DRAIN_POS
		_plug.rotation = Vector3.ZERO
	else:
		# 抜いた栓は排水口の横に転がしておく
		_plug.position = PLUG_OUT_POS + Vector3(0.0, PLUG_RADIUS, 0.0)   # 横倒しで底に接する
		_plug.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
	_layout_chain()


func _update_water() -> void:
	if _water == null:
		return
	_water.visible = level > 0.0005
	_water.position = Vector3(0.0, water_y(), 0.0)
	# 水流は水面まで。水がなければ底まで
	faucet.stream_floor_y = to_global(Vector3(0.0, water_y() if _water.visible else BOTTOM_Y, 0.0)).y


# ---------------------------------------------------------------- 組み立て

func _build_shell(visual: Node3D) -> void:
	var porcelain := MeshKit.mat("porcelain", Color(0.92, 0.92, 0.92), 0.3)
	var inner := MeshKit.mat("tub_inner", Color(0.7, 0.8, 0.86), 0.3)
	var h := HALF.y
	var wall_h := h - BOTTOM_Y
	var wy := BOTTOM_Y + wall_h * 0.5
	var inner_x := HALF.x - WALL
	var parts := [
		# [大きさ, 中心, マテリアル]
		[Vector3(HALF.x * 2.0, BOTTOM_Y, HALF.z * 2.0), Vector3(0.0, BOTTOM_Y * 0.5, 0.0), porcelain],   # 底
		[Vector3(HALF.x * 2.0, wall_h, WALL), Vector3(0.0, wy, -HALF.z + WALL * 0.5), porcelain],     # 奥
		[Vector3(HALF.x * 2.0, wall_h, WALL), Vector3(0.0, wy, HALF.z - WALL * 0.5), porcelain],      # 手前
		[Vector3(WALL, wall_h, (HALF.z - WALL) * 2.0), Vector3(-HALF.x + WALL * 0.5, wy, 0.0), porcelain],
		[Vector3(WALL, wall_h, (HALF.z - WALL) * 2.0), Vector3(HALF.x - WALL * 0.5, wy, 0.0), porcelain],
	]
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "bathtub")
	body.set_meta("fixture", self)
	add_child(body)
	for p in parts:
		MeshKit.box(visual, p[0], p[1], p[2])
		MeshKit.shape_box(body, p[0], p[1])
	# くぼみの底面だけ水色（底の箱の上面から 1mm 上。側面は壁に隠れる）
	MeshKit.box(visual, Vector3(inner_x * 2.0, 0.002, (HALF.z - WALL) * 2.0), Vector3(0.0, BOTTOM_Y - 0.0005, 0.0), inner, "InnerBottom")


func _build_note() -> void:
	# 手前の縁の裏に貼った小さな紙（仮の見た目：無地）。内側を向いているので、通路からは縁に遮られて見えず、
	# 浴槽に入って見回すと見える（姿勢で表示を切り替えず、位置と遮蔽物だけで見え方を作る）。取得はできない
	var quad := QuadMesh.new()
	quad.size = NOTE_SIZE
	var note := MeshInstance3D.new()
	note.name = "TubNote"
	note.mesh = quad
	note.material_override = MeshKit.note_mat()
	note.position = NOTE_POS - Vector3(0, 0, 0.0012)
	note.rotation.y = PI   # 表（+z）を浴槽の内側（-z）へ
	add_child(note)
	var area := MeshKit.interact_area(self, "TubNoteArea", "tub_note")
	MeshKit.shape_box(area, Vector3(NOTE_SIZE.x, NOTE_SIZE.y, 0.004), NOTE_POS - Vector3(0, 0, 0.002))


func _build_drain(visual: Node3D) -> void:
	# 金属の輪・暗い穴・十字の格子。栓をすると栓で隠れる
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var dark := MeshKit.mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0)
	MeshKit.cylinder(visual, 0.028, 0.003, DRAIN_POS + Vector3(0, 0.0015, 0), metal, "DrainRing")
	MeshKit.cylinder(visual, 0.02, 0.001, DRAIN_POS + Vector3(0, 0.0035, 0), dark, "DrainHole")
	MeshKit.box(visual, Vector3(0.04, 0.002, 0.004), DRAIN_POS + Vector3(0, 0.005, 0), metal)
	MeshKit.box(visual, Vector3(0.004, 0.002, 0.04), DRAIN_POS + Vector3(0, 0.005, 0), metal)
	# あふれ口のプレート（チェーンの留め具）
	var plate := MeshKit.cylinder(visual, 0.03, 0.006, CHAIN_ANCHOR + Vector3(0, 0, -0.001), metal, "Overflow")
	plate.rotation.x = deg_to_rad(90.0)


func _build_plug() -> void:
	_plug = Node3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	var rubber := MeshKit.mat("rubber", Color(0.12, 0.12, 0.13), 0.9)
	MeshKit.cylinder(_plug, PLUG_RADIUS, PLUG_HEIGHT, Vector3(0, PLUG_HEIGHT * 0.5, 0), rubber, "Rubber", PLUG_RADIUS * 0.85)
	MeshKit.box(_plug, Vector3(0.012, 0.008, 0.003), Vector3(0, PLUG_HEIGHT + 0.004, 0),
			MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8), "Eye")
	_chain = Node3D.new()
	_chain.name = "Chain"
	add_child(_chain)

	# 照準用の判定：栓をした位置と抜いた位置の両方を覆う
	var area := MeshKit.interact_area(self, "PlugArea", "bath_plug", self)
	var lo := Vector3(minf(DRAIN_POS.x, PLUG_OUT_POS.x) - 0.04, BOTTOM_Y, minf(DRAIN_POS.z, PLUG_OUT_POS.z) - 0.04)
	var hi := Vector3(maxf(DRAIN_POS.x, PLUG_OUT_POS.x) + 0.04, BOTTOM_Y + 0.06, maxf(DRAIN_POS.z, PLUG_OUT_POS.z) + 0.04)
	MeshKit.shape_box(area, hi - lo, (hi + lo) * 0.5)
	set_plug(true)


## あふれ口から内壁を下り、底を這って栓の上の輪まで、細かい玉を並べる。
func _layout_chain() -> void:
	for c in _chain.get_children():
		c.queue_free()
	var eye := _plug.position + (_plug.basis * Vector3(0, PLUG_HEIGHT + 0.006, 0))
	var corner := Vector3(eye.x, BOTTOM_Y + 0.003, CHAIN_ANCHOR.z + 0.002)
	var path := [CHAIN_ANCHOR + Vector3(0, -0.03, 0.003), corner, eye]
	var link_mat := MeshKit.mat("chain", Color(0.7, 0.7, 0.72), 0.3, 0.9)
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var count := maxi(1, int(a.distance_to(b) / 0.009))
		for k in count:
			MeshKit.sphere(_chain, 0.0025, a.lerp(b, float(k) / count), link_mat)


func _build_faucet() -> void:
	# 奥の壁（ローカル z = -HALF.z）に付けた混合水栓。吐水口の先はくぼみの上
	faucet = FaucetScript.new()
	faucet.name = "Faucet"
	faucet.position = Vector3(0.55, 0.70, -HALF.z)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.box(faucet, Vector3(0.16, 0.05, 0.05), Vector3(0, 0, 0.025), metal, "Body")
	MeshKit.box(faucet, Vector3(0.03, 0.025, 0.15), Vector3(0, -0.03, 0.09), metal, "Spout")
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 0.025, 0.025)
	faucet.add_child(lever)
	MeshKit.box(lever, Vector3(0.02, 0.012, 0.09), Vector3(0, 0.006, 0.045), metal)
	faucet.setup(Vector3(0, -0.045, 0.155), BOTTOM_Y, lever, 0.006)
	var area := MeshKit.interact_area(faucet, "FaucetArea", "bath_faucet", faucet)
	MeshKit.shape_box(area, Vector3(0.18, 0.12, 0.19), Vector3(0, 0.0, 0.095))
	add_child(faucet)


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	if id == "bath_plug":
		return "plug_pull" if plug_in else "plug_insert"
	return "examine"


func interact(id: String) -> String:
	match id:
		"bath_plug":
			set_plug(not plug_in)
			return ""
		_:
			if level > 0.02:
				return "bathtub_water"
			return "bathtub_wet" if was_filled else "bathtub"
