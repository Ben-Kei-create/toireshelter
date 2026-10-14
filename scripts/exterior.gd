extends Node3D
## 浴室の外側（TASK-10）：換気経路・ベランダ・建物の外壁・向かいのマンション。座標は部屋と同じ（この節点は原点に置く）。
##
## 換気経路（上から見た形。床 y=2.5、内寸の高さ 0.6m。小さな換気口の奥が妙に広い）：
##   E（入口）  x -0.95〜-0.45, z -1.2〜-0.6   … 浴室の換気口（x -0.82〜-0.62, z -1.12〜-0.92）の真上
##   A（横の管）x -0.95〜 2.2,  z -0.6〜 0.0   … 浴室の天井裏から自室の天井裏へ（角1）
##   B（出口側）x  1.6 〜 2.2,  z -1.3〜-0.6   … 外壁（z=-1.3）の出口へ（角2）。出口は y 2.5〜3.1
## ベランダ：x 1.3〜3.7（幅2.4m）、z -2.1〜-1.3（奥行き0.8m）、床 y=0。両端に隔て板、手すりの高さ 1.1m。
##   着地点は出口の真下（x 1.7, z -1.7）。すぐ右が自室の掃き出し窓（x 1.8〜3.2、apartment.gd）
## 外壁（自分の建物）は z=-1.32〜-1.30。窓と換気経路の出口だけ開いている。上下の階のベランダは背景だけ。
## 向かいのマンション：外壁の手前の面が z=-4.4（手すりから約2.3m、窓から約3.1m）。背景だけで入れない。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const BreakerScript := preload("res://scripts/breaker.gd")
const TEX_DUCT := preload("res://assets/textures/surfaces/surface_07.png")
const TEX_FACADE := preload("res://assets/textures/surfaces/surface_10.png")
const STREET := "res://assets/textures/street/"
const TEX_AIRCON := preload("res://assets/textures/street/ext_material_01.png")       # 室外機の正面（ファン）
const TEX_AIRCON_GRILLE := preload("res://assets/textures/street/ext_material_02.png")
const TEX_PIPE_TAPE := preload("res://assets/textures/street/ext_material_03.png")    # 配管の化粧テープ
const TEX_CONCRETE := preload("res://assets/textures/street/ext_material_04.png")     # 路面・電柱
const TEX_STUCCO := preload("res://assets/textures/street/ext_material_05.png")       # 自分の建物の外壁
const TEX_DARK_WOOD := preload("res://assets/textures/street/ext_material_06.png")    # 手すりの笠木・店の庇
const TEX_VENT := preload("res://assets/textures/street/ext_material_07.png")         # 外壁の換気口
const TEX_CAUTION := preload("res://assets/textures/street/ext_material_08.png")      # 「吹出口をふさがない」

const DUCT_FLOOR := 2.5
const DUCT_TOP := 3.1
const DUCT_T := 0.05
const DUCT_E := AABB(Vector3(-0.95, DUCT_FLOOR, -1.2), Vector3(0.5, 0.6, 0.6))
const DUCT_A := AABB(Vector3(-0.95, DUCT_FLOOR, -0.6), Vector3(3.15, 0.6, 0.6))
const DUCT_B := AABB(Vector3(1.6, DUCT_FLOOR, -1.3), Vector3(0.6, 0.6, 0.7))
const VENT_HOLE := Rect2(Vector2(-0.82, -1.12), Vector2(0.2, 0.2))   # x, z
const DUCT_START := Vector3(-0.7, DUCT_FLOOR, -0.32)    # 換気口から入ったときの足元（横の管の中。+x へそのまま進める）
const DUCT_EXIT_EDGE_Z := -1.0                          # これより外（-z）で「ベランダへ降りる」
const BALCONY := AABB(Vector3(1.3, -0.12, -2.1), Vector3(2.4, 2.6, 0.8))
const BALCONY_LANDING := Vector3(1.7, 0.0, -1.7)
const FACADE_Z := -1.30
const FACADE_T := 0.02
const WINDOW_X := Vector2(1.8, 3.2)
const WINDOW_TOP := 2.0
const FLOOR_PITCH := 3.4      # 上下の階の間隔（背景）
const OPPOSITE_Z := -4.4

## KO線：右手（+x）の遠くを走る、ゆっくりした電車の高架。背景だけ。
const KO_X := 22.0
const KO_DECK_Y := -1.2
const KO_SPEED := 2.6
const GROUND_Y := -4.0 * FLOOR_PITCH   # 街の地面（廊下と同じ）。503 は 5 階なので、4 階ぶん（13.6m）下が 1 階
const STREET_DROP := GROUND_Y + 2.0 * FLOOR_PITCH   # 路地の高さを、もとの 2 階ぶん下から 1 階まで下げた量（-6.8）
const ENTRANCE_X := -1.85                       # 1 階の入口（アーチ）の中心 x。廊下・エレベーターの真下
const ENTRANCE_HALF := 0.75                     # アーチの口の半幅
const ENTRANCE_H := 2.9                         # 入口の穴の高さ（アーチの頂点より上）
const VENDING_POS := Vector3(2.6, GROUND_Y, FACADE_Z - FACADE_T - 0.36)   # ベランダ（x 1.3〜3.7）の真下の、白い自動販売機
const POLE_POS := Vector3(0.45, 0.0, -2.55)

var _rng := RandomNumberGenerator.new()
var facade_dy := 0.0                   # 外壁の出口の穴が、もとの高さからどれだけ上にあるか
var ladder_down := false               # ボロボロのはしごを、ダクトの出口から下ろした
var breaker: Node3D                    # ベランダのブレーカー（breaker.gd）。ヒューズを差すと、部屋の電気がつく
var vending_machine: Node3D            # ベランダの真下の白い自動販売機（真のクリアの場所）
var _ladder: Node3D
var _ko_train: Node3D
var _ko_z := -150.0
var _ko_wait := 4.0


func _ready() -> void:
	_rng.seed = 2610
	_build_ko_line()
	_build_east_view()
	_build_duct()
	_build_facade()
	_build_balcony()
	_build_opposite()
	_build_street()
	_build_lights()


## ベランダ（手すりから身を乗り出すところも含む）の内か。
static func in_balcony(p: Vector3) -> bool:
	return p.x > BALCONY.position.x - 0.2 and p.x < BALCONY.end.x + 0.2 and p.z > BALCONY.position.z - 0.6 and p.z < FACADE_Z + 0.1 and p.y > -0.4 and p.y < 2.6


func _process(delta: float) -> void:
	if _ko_train == null:
		return
	if _ko_z > 60.0:
		_ko_train.visible = false
		_ko_wait -= delta
		if _ko_wait <= 0.0:
			_ko_z = -150.0
			_ko_wait = 14.0
	else:
		_ko_train.visible = true
		_ko_z += KO_SPEED * delta
	_ko_train.position.z = _ko_z


## 東の端の建物の向こうの景色：遠くまで続く地面と、低い影の街並み（空や虚無が抜けないように）。
func _build_east_view() -> void:
	MeshKit.auto_round = false
	var v := Node3D.new()
	v.name = "EastView"
	add_child(v)
	MeshKit.box(v, Vector3(140.0, 0.2, 200.0), Vector3(8.4 + 70.0, GROUND_Y - 0.1, -60.0), MeshKit.mat("east_ground", Color(0.3, 0.3, 0.33), 1.0), "Ground")
	var dark := MeshKit.mat("east_far", Color(0.2, 0.22, 0.28), 1.0)
	var lit := MeshKit.mat("east_lit", Color(1.0, 0.85, 0.6), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.8, 0.55)
	lit.emission_energy_multiplier = 0.9
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	for i in 60:
		var x := rng.randf_range(12.0, 110.0)
		if absf(x - KO_X) < 5.0:
			continue
		var z := rng.randf_range(-150.0, 10.0)
		var top := rng.randf_range(-9.0, 6.0) if x > 40.0 else rng.randf_range(-10.0, -4.0)
		var w := rng.randf_range(4.0, 9.0)
		var d := rng.randf_range(4.0, 9.0)
		MeshKit.box(v, Vector3(w, top - GROUND_Y, d), Vector3(x, (top + GROUND_Y) * 0.5, z), dark, "Far")
		if rng.randf() < 0.7:
			MeshKit.box(v, Vector3(0.05, 0.6, 0.8), Vector3(x - w * 0.5 - 0.03, top - rng.randf_range(1.0, 5.0), z + rng.randf_range(-1.5, 1.5)), lit, "FarLight")
	MeshKit.auto_round = true


## 高架の KO線（右手の遠く）：高架の橋脚・床・防護壁、架線の柱、4 両の電車。電車はゆっくり南北に走る。
func _build_ko_line() -> void:
	MeshKit.auto_round = false
	var r := Node3D.new()
	r.name = "KoLine"
	r.position = Vector3(KO_X, 0.0, 0.0)
	add_child(r)
	var concrete := MeshKit.mat("ko_concrete", Color(0.62, 0.6, 0.57), 0.9)
	var length := 170.0
	var zc := -60.0
	MeshKit.box(r, Vector3(4.6, 0.9, length), Vector3(0, KO_DECK_Y - 0.45, zc), concrete, "Deck")
	MeshKit.box(r, Vector3(3.6, 0.4, length), Vector3(0, KO_DECK_Y + 0.2, zc), MeshKit.mat("ko_ballast", Color(0.45, 0.43, 0.4), 1.0), "Ballast")
	for x in [-0.72, 0.72]:
		MeshKit.box(r, Vector3(0.1, 0.12, length), Vector3(x, KO_DECK_Y + 0.46, zc), MeshKit.mat("ko_rail", Color(0.7, 0.7, 0.73), 0.4, 0.6), "Rail")
	for x in [-2.3, 2.3]:
		MeshKit.box(r, Vector3(0.2, 0.7, length), Vector3(x, KO_DECK_Y + 0.35, zc), MeshKit.mat("ko_parapet", Color(0.7, 0.68, 0.65), 0.9), "Parapet")
	var h := KO_DECK_Y - 0.9 - GROUND_Y
	var z := -140.0
	while z < 30.0:
		for x in [-1.5, 1.5]:
			MeshKit.box(r, Vector3(1.1, h, 1.1), Vector3(x, GROUND_Y + h * 0.5, z), MeshKit.mat("ko_pillar", Color(0.58, 0.56, 0.54), 0.9), "Pillar")
		MeshKit.box(r, Vector3(4.2, 0.6, 1.3), Vector3(0, KO_DECK_Y - 1.2, z), concrete, "Beam")
		z += 9.0
	var pole := MeshKit.mat("ko_pole", Color(0.5, 0.52, 0.55), 0.5, 0.4)
	z = -140.0
	while z < 30.0:
		MeshKit.cylinder(r, 0.12, 6.0, Vector3(-1.9, KO_DECK_Y + 3.0, z), pole, "CatenaryPole")
		MeshKit.box(r, Vector3(2.4, 0.1, 0.1), Vector3(-0.7, KO_DECK_Y + 5.8, z), pole, "Arm")
		z += 10.0
	MeshKit.box(r, Vector3(0.04, 0.04, length), Vector3(0, KO_DECK_Y + 5.6, zc), MeshKit.mat("ko_wire", Color(0.15, 0.15, 0.17), 0.6), "Wire")
	_ko_train = Node3D.new()
	_ko_train.name = "Train"
	_ko_train.position = Vector3(0, KO_DECK_Y + 0.62, _ko_z)
	r.add_child(_ko_train)
	for i in 4:
		var car := Node3D.new()
		car.position = Vector3(0, 1.3, -i * 6.4)
		_ko_train.add_child(car)
		MeshKit.box(car, Vector3(2.5, 2.5, 6.0), Vector3.ZERO, MeshKit.mat("ko_body", Color(0.93, 0.92, 0.86), 0.6), "Body")
		MeshKit.box(car, Vector3(2.52, 0.35, 6.02), Vector3(0, -0.5, 0), MeshKit.mat("ko_stripe", Color(0.15, 0.5, 0.5), 0.6), "Stripe")
		MeshKit.box(car, Vector3(2.55, 0.85, 5.2), Vector3(0, 0.45, 0), MeshKit.mat("ko_window", Color(0.22, 0.3, 0.4), 0.3), "Windows")
		for w in 3:
			MeshKit.box(car, Vector3(2.56, 0.9, 0.06), Vector3(0, 0.45, -1.8 + w * 1.8), MeshKit.mat("ko_body", Color(0.93, 0.92, 0.86), 0.6), "Pillar")
		var glow := MeshKit.mat("ko_inside", Color(1.0, 0.92, 0.7), 0.5)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.9, 0.65)
		glow.emission_energy_multiplier = 0.6
		MeshKit.box(car, Vector3(2.4, 0.1, 5.2), Vector3(0, -0.2, 0), glow, "Inside")
	MeshKit.auto_round = true


## ボロボロのはしごを、ダクトの出口（高さ top_y）からベランダの床まで下ろす。上の端を軸に、伸びて落ちる。
func lower_ladder(top_y: float, instant := false) -> void:
	if ladder_down:
		return
	ladder_down = true
	_ladder = Node3D.new()
	_ladder.name = "Ladder"
	_ladder.position = Vector3(1.66, top_y, FACADE_Z - FACADE_T - 0.07)
	add_child(_ladder)
	var rust := MeshKit.mat("ladder_rust", Color(0.45, 0.31, 0.2), 0.9, 0.3)
	var length := top_y + 0.02
	MeshKit.auto_round = false
	for x in [-0.16, 0.16]:
		MeshKit.box(_ladder, Vector3(0.035, length, 0.03), Vector3(x, -length * 0.5, 0), rust, "Rail")
	var i := 0
	var y := 0.15
	while y < length - 0.1:
		if i % 5 != 2:   # 3 本に 1 本くらい、段が抜けている
			var rung := MeshKit.box(_ladder, Vector3(0.32, 0.025, 0.025), Vector3(0, -y, 0.0), rust, "Rung")
			if i % 7 == 3:   # 傾いて、ぶら下がっている段
				rung.rotation.z = 0.28
				rung.position.x = 0.03
		y += 0.3
		i += 1
	MeshKit.auto_round = true
	if instant:
		return
	_ladder.scale.y = 0.02
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ladder, "scale:y", 1.0, 1.3)


# ---------------------------------------------------------------- 換気経路

func _build_duct() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var duct := Node3D.new()
	duct.name = "Duct"
	add_child(duct)
	var metal := MeshKit.tiled_mat("duct_tex", TEX_DUCT, 0.6, Color(0.36, 0.38, 0.42), 0.5)   # 管の中は暗く（もとは 0.85,0.87,0.9）
	var dark := MeshKit.mat("duct_dark", Color(0.08, 0.08, 0.09), 1.0)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	duct.add_child(body)
	var add := func(size: Vector3, center: Vector3, m: Material) -> void:
		MeshKit.box(duct, size, center, m)
		MeshKit.shape_box(body, size, center)

	# 床：浴室の上（x ≤ 0.9）だけ作る。自室の上は自室の天井板（上面 2.5）がそのまま床になる。換気口の穴を空ける
	var fy := DUCT_FLOOR - 0.1
	var h0 := VENT_HOLE.position
	var h1 := VENT_HOLE.end
	var e0 := DUCT_E.position
	var e1 := DUCT_E.end
	_floor(add, Vector2(e0.x, e0.z), Vector2(h0.x, e1.z), fy, metal)       # 穴の左
	_floor(add, Vector2(h1.x, e0.z), Vector2(e1.x, e1.z), fy, metal)       # 穴の右
	_floor(add, Vector2(h0.x, e0.z), Vector2(h1.x, h0.y), fy, metal)       # 穴の奥
	_floor(add, Vector2(h0.x, h1.y), Vector2(h1.x, e1.z), fy, metal)       # 穴の手前
	_floor(add, Vector2(DUCT_A.position.x, DUCT_A.position.z), Vector2(0.9, DUCT_A.end.z), fy, metal)
	# 天井
	for r in [DUCT_E, DUCT_A, DUCT_B]:
		var a: AABB = r
		add.call(Vector3(a.size.x, DUCT_T, a.size.z), Vector3(a.get_center().x, DUCT_TOP + DUCT_T * 0.5, a.get_center().z), metal)
	# 壁（外周。出口 z=-1.3 の x 1.6〜2.2 は開いている）
	var wy := (DUCT_FLOOR + DUCT_TOP) * 0.5
	var wh := DUCT_TOP - DUCT_FLOOR
	var t := DUCT_T
	var walls := [
		[Vector3(0.5, wh, t), Vector3(-0.7, wy, -1.2 - t * 0.5)],          # E の奥
		[Vector3(t, wh, 0.6), Vector3(-0.45 + t * 0.5, wy, -0.9)],         # E の右
		[Vector3(2.05, wh, t), Vector3(0.575, wy, -0.6 - t * 0.5)],        # A の奥（E と B の間）
		[Vector3(t, wh, 0.7), Vector3(1.6 - t * 0.5, wy, -0.95)],          # B の左
		[Vector3(t, wh, 1.3), Vector3(2.2 + t * 0.5, wy, -0.65)],          # B と A の右端
		[Vector3(3.15 + t * 2.0, wh, t), Vector3(0.625, wy, t * 0.5)],     # A の手前
		[Vector3(t, wh, 1.2), Vector3(-0.95 - t * 0.5, wy, -0.6)],         # E と A の左端
	]
	for w in walls:
		add.call(w[0], w[1], metal)
	# 換気口の縦穴の内張り（浴室の天井 2.2 から経路の床 2.5 まで、暗い色）
	var sh := DUCT_FLOOR - 2.2
	var sy := 2.2 + sh * 0.5
	var hc := VENT_HOLE.get_center()
	MeshKit.box(duct, Vector3(0.002, sh, 0.2), Vector3(h0.x + 0.001, sy, hc.y), dark)
	MeshKit.box(duct, Vector3(0.002, sh, 0.2), Vector3(h1.x - 0.001, sy, hc.y), dark)
	MeshKit.box(duct, Vector3(0.2, sh, 0.002), Vector3(hc.x, sy, h0.y + 0.001), dark)
	MeshKit.box(duct, Vector3(0.2, sh, 0.002), Vector3(hc.x, sy, h1.y - 0.001), dark)
	# 体だけを止める透明な板（照準と視線は通す）：外壁の出口（落ちないように）と、床の換気口の穴の上
	var blocker := StaticBody3D.new()
	blocker.name = "BodyBlockers"
	blocker.collision_layer = MeshKit.LAYER_BODY_ONLY
	blocker.collision_mask = 0
	duct.add_child(blocker)
	MeshKit.shape_box(blocker, Vector3(DUCT_B.size.x, wh, 0.02), Vector3(DUCT_B.get_center().x, wy, DUCT_B.position.z - 0.01))
	MeshKit.shape_box(blocker, Vector3(VENT_HOLE.size.x, 0.02, VENT_HOLE.size.y), Vector3(hc.x, DUCT_FLOOR - 0.01, hc.y))
	# 継ぎ目の帯（遠近感の目印）
	var band := MeshKit.mat("duct_band", Color(0.4, 0.42, 0.44), 0.5, 0.3)
	for x in [0.0, 0.8, 1.5]:
		MeshKit.box(duct, Vector3(0.03, 0.004, 0.6), Vector3(x, DUCT_FLOOR + 0.002, -0.3), band)
	# 管の内側に貼られたステッカー（既存の絵のうち、這いながら読める小さな物。見た目だけ）
	var dy := DUCT_FLOOR + 0.3
	var back_wall := [[15, -0.2, 0.17, 4.0], [26, 0.35, 0.2, -6.0], [29, 0.85, 0.17, 5.0], [31, 1.35, 0.2, -3.0]]   # [番号, x, 高さ, 傾き]
	for e in back_wall:
		MeshKit.sticker(duct, e[0], e[2], Vector3(e[1], dy, -0.6), Vector3.BACK, e[3])
	var front_wall := [[16, 0.1, 0.2, -5.0], [21, 0.7, 0.17, 6.0], [34, 1.25, 0.2, -4.0], [24, 1.8, 0.17, 8.0]]
	for e in front_wall:
		MeshKit.sticker(duct, e[0], e[2], Vector3(e[1], dy, 0.0), Vector3.FORWARD, e[3])
	MeshKit.image_quad(duct, MeshKit.prop_tex("sticker_card_3"), Vector2(0.24, 0.24 * 485.0 / 509.0), Vector3(0.4, DUCT_FLOOR + 0.3, 0.0), Vector3.FORWARD, "StickerCard", false, 0.4)   # 配管仙人
	MeshKit.sticker(duct, 22, 0.2, Vector3(2.2, DUCT_FLOOR + 0.3, -1.0), Vector3.LEFT, 3.0)    # 出口の部屋の右の壁（-x を向く）
	MeshKit.sticker(duct, 27, 0.2, Vector3(1.6, DUCT_FLOOR + 0.3, -1.0), Vector3.RIGHT, -5.0)    # 出口の部屋の左の壁（+x を向く）
	MeshKit.sticker(duct, 17, 0.2, Vector3(-0.7, DUCT_FLOOR + 0.3, -1.2), Vector3.BACK, 2.0)    # 換気口のうしろの壁
	MeshKit.sticker(duct, 36, 0.26, Vector3(0.9, DUCT_TOP, -0.3), Vector3.DOWN, 20.0)           # 天井（見上げると読める）
	MeshKit.auto_round = true

func _floor(add: Callable, a: Vector2, b: Vector2, y: float, m: Material) -> void:
	var size := Vector3(b.x - a.x, 0.2, b.y - a.y)
	if size.x <= 0.001 or size.z <= 0.001:
		return
	add.call(size, Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5), m)


## 足元 p が換気経路の中か。
static func in_duct(p: Vector3) -> bool:
	for r in [DUCT_E, DUCT_A, DUCT_B]:
		var a: AABB = r
		if p.x >= a.position.x and p.x <= a.end.x and p.z >= a.position.z and p.z <= a.end.z and p.y > DUCT_FLOOR - 0.2:
			return true
	return false


# ---------------------------------------------------------------- 建物の外壁

## 浴室とダクトが dy だけ上がったあと、外壁の出口の穴を、上がった高さへ移して作り直す（もとの穴はふさがる）。
func set_exit_rise(dy: float) -> void:
	if is_equal_approx(dy, facade_dy):
		return
	var old := get_node_or_null("Facade")
	if old:
		remove_child(old)
		old.queue_free()
	_build_facade(dy)


func _build_facade(dy := 0.0) -> void:
	facade_dy = dy
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var f := Node3D.new()
	f.name = "Facade"
	add_child(f)
	var wall := MeshKit.tiled_mat("facade_stucco", TEX_STUCCO, 0.8, Color(0.82, 0.8, 0.76), 0.95)
	var z := FACADE_Z - FACADE_T * 0.5
	var x0 := -3.0
	var x1 := 7.0
	var pieces := [
		# [x0, x1, y0, y1]：窓（x 1.8〜3.2, y 0〜2.0）と換気経路の出口（x 1.6〜2.2, y 2.5〜3.1）を空ける
		[x0, x1, GROUND_Y + ENTRANCE_H, 0.0],
		[x0, ENTRANCE_X - ENTRANCE_HALF, GROUND_Y, GROUND_Y + ENTRANCE_H], [ENTRANCE_X + ENTRANCE_HALF, x1, GROUND_Y, GROUND_Y + ENTRANCE_H],
		[x0, WINDOW_X.x, 0.0, WINDOW_TOP], [WINDOW_X.y, x1, 0.0, WINDOW_TOP],
		[x0, x1, WINDOW_TOP, DUCT_FLOOR + dy],
		[x0, DUCT_B.position.x, DUCT_FLOOR + dy, DUCT_TOP + dy], [DUCT_B.end.x, x1, DUCT_FLOOR + dy, DUCT_TOP + dy],
		[x0, x1, DUCT_TOP + dy, 12.0 + dy],
	]
	for p in pieces:
		MeshKit.box(f, Vector3(p[1] - p[0], p[3] - p[2], FACADE_T), Vector3((p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5, z), wall)
	# 換気経路の出口のフード（金属の庇）
	var hood := MeshKit.mat("duct", Color(0.5, 0.52, 0.54), 0.5, 0.3)
	MeshKit.box(f, Vector3(0.7, 0.03, 0.12), Vector3(1.9, DUCT_TOP + dy + 0.02, FACADE_Z - 0.06), hood, "ExitHood")
	# 縦の雨どいと、上下の階のベランダ（背景）
	MeshKit.cylinder(f, 0.04, 28.0, Vector3(1.15, 0.0, FACADE_Z - 0.06), MeshKit.mat("pipe_grey", Color(0.45, 0.45, 0.44), 0.6), "Downpipe", -1.0, 10)
	for k in [-3, -2, -1, 1, 2]:
		var y: float = k * FLOOR_PITCH
		_balcony_shell(f, y, x0, x1, false)
	MeshKit.auto_round = true

# ---------------------------------------------------------------- ベランダ

func _build_balcony() -> void:
	var b := Node3D.new()
	b.name = "Balcony"
	add_child(b)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	b.add_child(body)
	var x0 := BALCONY.position.x
	var x1 := BALCONY.end.x
	var z0 := BALCONY.position.z
	var z1 := FACADE_Z - FACADE_T
	var slab := MeshKit.mat("balcony_floor", Color(0.55, 0.54, 0.5), 0.9)
	# 腰板はすりガラス。下の路地がうっすら透けて見える程度に（以前は 0.85）
	var panel := MeshKit.mat("balcony_panel_own", Color(0.72, 0.74, 0.74, 0.45), 0.4)
	panel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rail := MeshKit.tiled_mat("rail_wood", TEX_DARK_WOOD, 0.4, Color.WHITE, 0.6)
	var add := func(size: Vector3, center: Vector3, m: Material, collide := true) -> void:
		MeshKit.box(b, size, center, m)
		if collide:
			MeshKit.shape_box(body, size, center)
	# 床（自分のベランダは当たり判定あり。両隣は背景）
	add.call(Vector3(x1 - x0, 0.12, z1 - z0), Vector3((x0 + x1) * 0.5, -0.06, (z0 + z1) * 0.5), slab)
	_balcony_shell(b, 0.0, -3.0, x0, true)
	_balcony_shell(b, 0.0, x1, 7.0, true)
	# 手すり：すりガラス風の腰板と上の手すり棒。越えられないよう、見えない壁を 2m まで
	add.call(Vector3(x1 - x0, 1.0, 0.03), Vector3((x0 + x1) * 0.5, 0.5, z0 + 0.015), panel)
	add.call(Vector3(x1 - x0, 0.05, 0.06), Vector3((x0 + x1) * 0.5, 1.08, z0 + 0.015), rail)
	MeshKit.shape_box(body, Vector3(x1 - x0, 1.0, 0.03), Vector3((x0 + x1) * 0.5, 1.6, z0 + 0.015))
	# 隔て板（両端）
	var sep := MeshKit.mat("separator", Color(0.85, 0.85, 0.82), 0.7)
	for x in [x0 - 0.02, x1 + 0.02]:
		add.call(Vector3(0.04, 1.9, z1 - z0), Vector3(x, 0.95, (z0 + z1) * 0.5), sep)
	# 室外機（右端に寄せる）
	# 室外機：狭いベランダらしく、吹出口を窓側（-x）へ向けて右端の隔て板の前に置く
	var unit := Node3D.new()
	unit.name = "AirConUnit"
	unit.position = Vector3(3.45, 0.0, -1.62)
	unit.rotation.y = PI * 0.5   # ローカル -z（正面）を -x へ
	b.add_child(unit)
	var unit_mat := MeshKit.mat("aircon", Color(0.86, 0.85, 0.8), 0.6)
	var usz := Vector3(0.6, 0.45, 0.24)
	MeshKit.box(unit, usz, Vector3(0, 0.05 + usz.y * 0.5, 0), unit_mat, "Body")
	_quad(unit, TEX_AIRCON, Vector2(usz.x - 0.01, usz.y - 0.01), Vector3(0, 0.05 + usz.y * 0.5, -usz.z * 0.5 - 0.001), Vector3(0, PI, 0), "Front")
	_quad(unit, TEX_AIRCON_GRILLE, Vector2(usz.z - 0.02, usz.y - 0.04), Vector3(usz.x * 0.5 + 0.001, 0.05 + usz.y * 0.5, 0), Vector3(0, PI * 0.5, 0), "SideGrille")
	var sticker := _quad(unit, TEX_CAUTION, Vector2(0.16, 0.097), Vector3(0.12, 0.05 + usz.y + 0.001, 0.0), Vector3(-PI * 0.5, 0, 0), "CautionSticker", true)
	sticker.rotation = Vector3(-PI * 0.5, 0, PI)   # 上向きに寝かせ、窓側から読める向き（文字の上が奥）
	MeshKit.box(unit, Vector3(usz.x - 0.04, 0.05, usz.z - 0.02), Vector3(0, 0.025, 0), MeshKit.mat("rail", Color(0.35, 0.36, 0.37), 0.4, 0.6), "Legs")
	MeshKit.shape_box(body, Vector3(usz.z, 0.55, usz.x), unit.position + Vector3(0, 0.275, 0))
	# 冷媒管：化粧テープを巻いた太い管が、室外機の背から外壁へ
	var tape := MeshKit.tiled_mat("pipe_tape", TEX_PIPE_TAPE, 0.12, Color.WHITE, 0.8)
	MeshKit.pipe(b, [unit.position + Vector3(0.0, 0.42, 0.05), Vector3(3.45, 0.8, z1 - 0.06), Vector3(3.6, 1.7, z1 - 0.04)], 0.022, tape)
	# ステッカー：室外機の天板・隔て板・腰板の内側
	MeshKit.sticker(b, 9, 0.12, Vector3(3.4, 0.5 + 0.001, -1.48), Vector3.UP, 20.0)
	MeshKit.sticker(b, 10, 0.12, Vector3(3.55, 0.5 + 0.001, -1.85), Vector3.UP, -12.0)
	MeshKit.sticker(b, 11, 0.16, Vector3(x0, 1.2, -1.7), Vector3.RIGHT, 5.0)
	MeshKit.sticker(b, 12, 0.16, Vector3(x0, 0.85, -1.55), Vector3.RIGHT, -7.0)
	MeshKit.sticker(b, 13, 0.16, Vector3(x1, 1.25, -1.6), Vector3.LEFT, 4.0)
	MeshKit.sticker(b, 14, 0.14, Vector3(2.0, 0.75, z0 + 0.03), Vector3.BACK, -3.0)
	# ブレーカー（窓の左の外壁）。蓋はねじ止め、中のヒューズは抜けている
	breaker = BreakerScript.new()
	breaker.position = Vector3(1.58, 1.38, FACADE_Z - FACADE_T)
	b.add_child(breaker)
	# サンダル（窓の右側の前）と小さな植木鉢（左奥の隅）。見た目だけ
	var sandal := MeshKit.mat("sandal", Color(0.25, 0.32, 0.42), 0.8)
	for dz in [-0.05, 0.07]:
		MeshKit.box(b, Vector3(0.26, 0.025, 0.1), Vector3(2.8, 0.0125, -1.5 + dz), sandal)
	var pot := Node3D.new()
	pot.name = "FlowerPot"
	pot.position = Vector3(1.45, 0.0, -1.98)
	b.add_child(pot)
	MeshKit.cylinder(pot, 0.06, 0.12, Vector3(0, 0.06, 0), MeshKit.mat("terracotta", Color(0.66, 0.36, 0.22), 0.9), "Pot", 0.08)
	MeshKit.sphere(pot, 0.07, Vector3(0, 0.17, 0), MeshKit.mat("leaves", Color(0.25, 0.42, 0.22), 0.9))


## 背景用のベランダ（床・腰板・手すり棒だけ）。collide は自分の階の両隣（当たり判定は手すりの見えない壁が担う）。
func _balcony_shell(parent: Node3D, y: float, x0: float, x1: float, _collide: bool) -> void:
	var z0 := BALCONY.position.z
	var z1 := FACADE_Z - FACADE_T
	MeshKit.box(parent, Vector3(x1 - x0, 0.12, z1 - z0), Vector3((x0 + x1) * 0.5, y - 0.06, (z0 + z1) * 0.5), MeshKit.mat("balcony_floor", Color(0.55, 0.54, 0.5), 0.9))
	var panel := MeshKit.mat("balcony_panel", Color(0.72, 0.74, 0.74, 0.85), 0.4)
	MeshKit.box(parent, Vector3(x1 - x0, 1.0, 0.03), Vector3((x0 + x1) * 0.5, y + 0.5, z0 + 0.015), panel)
	MeshKit.box(parent, Vector3(x1 - x0, 0.05, 0.06), Vector3((x0 + x1) * 0.5, y + 1.08, z0 + 0.015), MeshKit.mat("rail", Color(0.35, 0.36, 0.37), 0.4, 0.6))


# ---------------------------------------------------------------- 向かいのマンション（背景）

func _build_opposite() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var o := Node3D.new()
	o.name = "OppositeBuilding"
	add_child(o)
	# くすんだ外壁（画像を 1.5m 四方で繰り返し、少し暗く）
	var wall := MeshKit.tiled_mat("opposite_wall_tex", TEX_FACADE, 1.5, Color(0.72, 0.7, 0.66), 0.95)
	var x0 := -4.0
	var x1 := 8.0
	MeshKit.box(o, Vector3(x1 - x0, 26.0, 0.3), Vector3((x0 + x1) * 0.5, -1.0, OPPOSITE_Z - 0.15), wall, "Wall")
	# 路地の地面（4階分下＝1階。歩ける）。1 階の入口から自動販売機まで歩く通路
	var alley_m := MeshKit.tiled_mat("alley_concrete", TEX_CONCRETE, 1.2, Color(0.75, 0.75, 0.75), 1.0)
	MeshKit.box(o, Vector3(x1 - x0, 0.1, FACADE_Z - OPPOSITE_Z + 0.6), Vector3((x0 + x1) * 0.5, GROUND_Y - 0.05, (OPPOSITE_Z + FACADE_Z) * 0.5 - 0.3), alley_m, "Alley")
	_build_street_body(x0, x1)
	var glass := MeshKit.mat("opp_glass", Color(0.16, 0.18, 0.2), 0.2, 0.2)
	var lit := MeshKit.mat("opp_lit", Color(1.0, 0.85, 0.6), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.8, 0.55)
	lit.emission_energy_multiplier = 0.9
	var frame := MeshKit.mat("opp_frame", Color(0.6, 0.6, 0.58), 0.6)
	var unit_mat := MeshKit.mat("aircon", Color(0.86, 0.85, 0.8), 0.6)
	var face := OPPOSITE_Z
	for floor_i in range(-2, 3):   # 1階・2階は店（_build_street()）。その上の 3 階・4 階と、503 の高さから上の窓
		var y := floor_i * FLOOR_PITCH
		var x := x0 + 0.6
		while x < x1 - 1.0:
			var w := _rng.randf_range(0.7, 1.2)
			var h := _rng.randf_range(0.9, 1.3)
			var wy := y + 1.0 + h * 0.5
			var is_lit := _rng.randf() < 0.18
			MeshKit.box(o, Vector3(w + 0.08, h + 0.08, 0.03), Vector3(x + w * 0.5, wy, face + 0.015), frame)
			MeshKit.box(o, Vector3(w, h, 0.02), Vector3(x + w * 0.5, wy, face + 0.03), lit if is_lit else glass)
			if _rng.randf() < 0.4:   # 窓の下の室外機
				MeshKit.box(o, Vector3(0.5, 0.45, 0.25), Vector3(x + w * 0.5, y + 0.5, face + 0.125), unit_mat)
				_quad(o, TEX_AIRCON, Vector2(0.49, 0.44), Vector3(x + w * 0.5, y + 0.5, face + 0.252), Vector3.ZERO, "")
			x += w + _rng.randf_range(0.6, 1.3)
	# 縦の配管
	var pipe := MeshKit.mat("pipe_grey", Color(0.45, 0.45, 0.44), 0.6)
	for px in [0.4, 2.1, 5.3]:
		MeshKit.cylinder(o, 0.035, 26.0, Vector3(px, -1.0, face + 0.06), pipe, "", -1.0, 8)
	# 生活灯（小さな外灯）
	var lamp := MeshKit.mat("lamp", Color(1.0, 0.9, 0.7), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.6)
	lamp.emission_energy_multiplier = 2.0
	MeshKit.box(o, Vector3(0.14, 0.2, 0.1), Vector3(3.0, 2.3, face + 0.05), lamp, "Lamp")
	# 電線（建物の間を少し斜めに渡る数本）
	var wire := MeshKit.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	for w in [[Vector3(-2.0, 5.2, FACADE_Z - 0.2), Vector3(6.0, 4.6, OPPOSITE_Z + 0.1)], [Vector3(-1.0, 5.6, OPPOSITE_Z + 0.1), Vector3(7.0, 5.0, FACADE_Z - 0.2)], [Vector3(-3.0, 4.2, -2.9), Vector3(7.5, 4.4, -2.7)]]:
		MeshKit.pipe(o, w, 0.008, wire)
	MeshKit.auto_round = true

# ---------------------------------------------------------------- 路地の店と看板（下南澤の細い路地のような密集感）

## 向かいの建物の1階・2階を店にし、横長の看板（street_sign_h）を掛ける。縦の突き出し看板（street_sign_v）は
## 向かいの壁と自分の建物の壁から路地へ張り出す。看板は夕方でも読めるよう、弱く自己発光させる。
## 自分のベランダの腰板（すりガラス）越しに見下ろすと、2階の看板と突き出し看板、遠くの1階の店が見える。
func _build_street() -> void:
	MeshKit.auto_round = false
	var st := Node3D.new()
	st.name = "Street"
	add_child(st)
	var face := OPPOSITE_Z
	var glass_lit := MeshKit.mat("shop_glass", Color(1.0, 0.86, 0.62), 0.3)
	glass_lit.emission_enabled = true
	glass_lit.emission = Color(1.0, 0.78, 0.5)
	glass_lit.emission_energy_multiplier = 0.7
	var shutter := MeshKit.mat("shutter", Color(0.5, 0.5, 0.5), 0.5, 0.4)
	var awning_wood := MeshKit.tiled_mat("awning_wood", TEX_DARK_WOOD, 0.6, Color.WHITE, 0.7)
	# 店の並び：[x の左端, 幅, 横看板の番号]（1階と2階でずらす）
	var shops := [
		[-3, [-3.6, 1.7, 1], [-1.75, 1.5, 2], [-0.1, 1.9, 3], [1.95, 1.6, 4], [3.7, 1.8, 5], [5.65, 1.9, 6]],
		[-4, [-3.2, 1.9, 7], [-1.1, 1.7, 8], [0.8, 2.0, 9], [3.0, 1.6, 10], [4.8, 1.9, 11], [6.8, 1.0, 12]],
	]
	for row in shops:
		var floor_i: int = row[0]
		var y0: float = floor_i * FLOOR_PITCH
		for k in range(1, row.size()):
			var s: Array = row[k]
			var x: float = s[0]
			var w: float = s[1]
			var cx := x + w * 0.5
			# 間口：明かりの付いたガラス（ところどころシャッター）
			var closed: bool = (int(s[2]) % 5) == 0
			MeshKit.box(st, Vector3(w - 0.2, 2.0, 0.04), Vector3(cx, y0 + 1.1, face + 0.02), shutter if closed else glass_lit)
			# 庇と横看板（看板は庇の上、比率そのまま）
			MeshKit.box(st, Vector3(w - 0.05, 0.06, 0.45), Vector3(cx, y0 + 2.25, face + 0.225), awning_wood)
			var tex: Texture2D = load(STREET + "street_sign_h_%02d.png" % s[2])
			var sw := minf(w - 0.25, 1.25)
			var sh := sw * tex.get_height() / tex.get_width()
			_sign(st, tex, Vector2(sw, sh), Vector3(cx, y0 + 2.35 + sh * 0.5, face + 0.03), Vector3.ZERO)
	# 縦の突き出し看板：[x, 建物（"opp"=向かい / "own"=自分の建物）, 下端の高さ, 番号]
	var vsigns := [
		[-2.9, "opp", -3.0, 1], [-0.95, "opp", -2.8, 2], [1.0, "opp", -3.0, 3], [2.7, "opp", -2.9, 4],
		[4.6, "opp", -3.1, 5], [6.6, "opp", -2.8, 6], [-2.4, "own", -3.0, 7], [-0.6, "own", -2.9, 8],
		[0.9, "own", -6.3, 9], [4.3, "own", -3.0, 10], [5.8, "own", -2.9, 11], [6.9, "opp", -6.2, 12],
	]
	var bracket := MeshKit.mat("sign_bracket", Color(0.25, 0.25, 0.26), 0.5, 0.6)
	for v in vsigns:
		var tex: Texture2D = load(STREET + "street_sign_v_%02d.png" % v[3])
		var h := 1.7
		var w := h * tex.get_width() / tex.get_height()
		var wall_z: float = face if v[1] == "opp" else FACADE_Z - FACADE_T
		var dir := 1.0 if v[1] == "opp" else -1.0   # 壁から路地へ張り出す向き（z）
		var cz := wall_z + dir * (0.12 + w * 0.5)
		var cy: float = v[2] + STREET_DROP + h * 0.5
		# 両面に同じ看板（それぞれ正しい向きで読める）
		_sign(st, tex, Vector2(w, h), Vector3(v[0] + 0.012, cy, cz), Vector3(0, PI * 0.5, 0))
		_sign(st, tex, Vector2(w, h), Vector3(v[0] - 0.012, cy, cz), Vector3(0, -PI * 0.5, 0))
		MeshKit.box(st, Vector3(0.02, h + 0.04, w + 0.04), Vector3(v[0], cy, cz), bracket)
		for yy in [cy + h * 0.45, cy - h * 0.45]:
			MeshKit.box(st, Vector3(0.03, 0.03, 0.14), Vector3(v[0], yy, wall_z + dir * 0.07), bracket)
	# 路地の両端：別の建物が視界をふさぎ、路地はその先で曲がっていく（空が抜けないように）
	_end_building(st, -4.6, 1.0, deg_to_rad(10.0), Color(0.78, 0.82, 0.76), [7, 11])
	_end_building(st, 8.6, -1.0, deg_to_rad(-14.0), Color(0.86, 0.8, 0.7), [2, 12], -3.5)   # 東の端の建物は低く：その上に、KO線が見える
	# 自動販売機：向かいの建物の1階の店先と、自分の建物の1階の壁際
	_vending(st, Vector3(2.9, GROUND_Y, OPPOSITE_Z + 0.36), 0.0, Color(0.78, 0.12, 0.12), [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45])
	vending_machine = _vending(st, VENDING_POS, PI, Color(0.92, 0.93, 0.95), [46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59])
	# 調べる判定（正面の前に張り出す）。真のクリアの場所
	var vm_area := MeshKit.interact_area(vending_machine, "VendingArea", "vending")
	MeshKit.shape_box(vm_area, Vector3(0.9, 1.8, 0.3), Vector3(0, 0.9, 0.35 + 0.1))
	_street_stickers(st)
	# 自分の建物の換気口（各階の同じ位置）
	for k in [-3, -2, -1, 1, 2]:
		_quad(st, TEX_VENT, Vector2(0.3, 0.23), Vector3(1.9, k * FLOOR_PITCH + 2.8, FACADE_Z - FACADE_T - 0.004), Vector3(0, PI, 0), "")
	# 電柱：路地の自分の建物寄り。コンクリートの柱と変圧器、電線は向かいの建物と自分の建物へ
	var pole := MeshKit.tiled_mat("pole_concrete", TEX_CONCRETE, 0.6, Color(0.85, 0.85, 0.85), 0.9)
	var pole_pos := POLE_POS
	var bottom := GROUND_Y
	var top := 5.6
	MeshKit.cylinder(st, 0.15, top - bottom, Vector3(pole_pos.x, (top + bottom) * 0.5, pole_pos.z), pole, "UtilityPole", 0.12, 14)
	MeshKit.cylinder(st, 0.22, 0.75, Vector3(pole_pos.x + 0.3, 3.6, pole_pos.z), MeshKit.mat("transformer", Color(0.55, 0.58, 0.55), 0.5, 0.3), "Transformer")
	MeshKit.box(st, Vector3(1.0, 0.08, 0.08), Vector3(pole_pos.x, top - 0.4, pole_pos.z), MeshKit.mat("sign_bracket", Color(0.25, 0.25, 0.26), 0.5, 0.6), "CrossArm")
	var wire := MeshKit.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	for e in [Vector3(-4.0, 4.9, -2.5), Vector3(8.0, 5.1, -2.6), Vector3(3.0, 4.5, OPPOSITE_Z + 0.05), Vector3(-1.5, 4.0, FACADE_Z - 0.05)]:
		MeshKit.pipe(st, [Vector3(pole_pos.x, top - 0.4, pole_pos.z), (Vector3(pole_pos.x, top - 0.4, pole_pos.z) + e) * 0.5 + Vector3(0, -0.35, 0), e], 0.007, wire)
	MeshKit.auto_round = true


## 自動販売機（幅0.9・高さ1.8・奥行き0.7）。ローカル +z が正面。明るい商品見本の窓・ボタン・取り出し口・硬貨投入口。
## 側面と正面の下にステッカー（stickers の番号）を貼る。背景だけ（当たり判定なし）。
func _vending(parent: Node3D, pos: Vector3, yaw: float, body_col: Color, stickers: Array) -> Node3D:
	var vm := Node3D.new()
	vm.name = "VendingMachine"
	vm.position = pos
	vm.rotation.y = yaw
	parent.add_child(vm)
	var body := MeshKit.mat("vending_%s" % body_col.to_html(false), body_col, 0.4, 0.2)
	var dark := MeshKit.mat("vending_dark", Color(0.08, 0.08, 0.09), 0.6)
	var w := 0.9
	var h := 1.8
	var d := 0.7
	MeshKit.box(vm, Vector3(w, h, d), Vector3(0, h * 0.5, 0), body, "Body")
	MeshKit.box(vm, Vector3(w + 0.02, 0.08, d + 0.02), Vector3(0, 0.04, 0), dark, "Base")
	# 商品見本の窓（光る）と、3段×6列の缶
	var window := MeshKit.mat("vending_window", Color(0.95, 0.96, 1.0), 0.2)
	window.emission_enabled = true
	window.emission = Color(0.92, 0.95, 1.0)
	window.emission_energy_multiplier = 1.4
	MeshKit.box(vm, Vector3(w - 0.12, 0.72, 0.02), Vector3(0, 1.32, d * 0.5 + 0.005), window, "Window")
	var can_cols := [Color(0.85, 0.15, 0.12), Color(0.15, 0.35, 0.75), Color(0.95, 0.75, 0.15), Color(0.2, 0.55, 0.3), Color(0.95, 0.95, 0.95), Color(0.45, 0.25, 0.15)]
	for row in 3:
		for col in 6:
			var c: Color = can_cols[(row * 2 + col) % can_cols.size()]
			var cx := -0.3 + col * 0.12
			var cy := 1.06 + row * 0.23
			MeshKit.cylinder(vm, 0.028, 0.1, Vector3(cx, cy + 0.05, d * 0.5 + 0.035), MeshKit.mat("can_%s" % c.to_html(false), c, 0.3, 0.4), "", -1.0, 10)
			var btn := MeshKit.mat("vending_btn_lit" if (row + col) % 3 else "vending_btn", Color(0.3, 0.9, 0.4) if (row + col) % 3 else Color(0.9, 0.2, 0.2), 0.4)
			btn.emission_enabled = true
			btn.emission = btn.albedo_color
			btn.emission_energy_multiplier = 0.8
			MeshKit.box(vm, Vector3(0.05, 0.02, 0.012), Vector3(cx, cy - 0.025, d * 0.5 + 0.02), btn)
	# 硬貨投入口・お札・取り出し口
	MeshKit.box(vm, Vector3(0.14, 0.22, 0.03), Vector3(0.3, 0.78, d * 0.5 + 0.015), dark, "CoinPanel")
	MeshKit.box(vm, Vector3(0.62, 0.18, 0.04), Vector3(-0.08, 0.28, d * 0.5 + 0.02), dark, "Dispenser")
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.3, d * 0.5 + 0.6)
	lamp.light_color = Color(0.9, 0.95, 1.0)
	lamp.light_energy = 0.6
	lamp.omni_range = 2.5
	vm.add_child(lamp)
	# ステッカー：左右の側面に5〜6枚ずつ、正面の下（取り出し口のまわり）に残り
	var places := [
		[Vector3(w * 0.5, 1.45, 0.15), Vector3.RIGHT, 6.0], [Vector3(w * 0.5, 1.2, -0.12), Vector3.RIGHT, -4.0], [Vector3(w * 0.5, 0.95, 0.18), Vector3.RIGHT, 3.0],
		[Vector3(w * 0.5, 0.7, -0.1), Vector3.RIGHT, -8.0], [Vector3(w * 0.5, 0.45, 0.12), Vector3.RIGHT, 5.0], [Vector3(w * 0.5, 1.62, -0.2), Vector3.RIGHT, -2.0],
		[Vector3(-w * 0.5, 1.4, -0.12), Vector3.LEFT, -5.0], [Vector3(-w * 0.5, 1.15, 0.16), Vector3.LEFT, 4.0], [Vector3(-w * 0.5, 0.9, -0.15), Vector3.LEFT, -3.0],
		[Vector3(-w * 0.5, 0.62, 0.12), Vector3.LEFT, 7.0], [Vector3(-w * 0.5, 0.38, -0.08), Vector3.LEFT, -6.0],
		[Vector3(0.3, 0.52, d * 0.5 + 0.03), Vector3.BACK, 4.0], [Vector3(-0.3, 0.6, d * 0.5), Vector3.BACK, -6.0], [Vector3(0.28, 0.14, d * 0.5), Vector3.BACK, 2.0],
	]
	for i in mini(stickers.size(), places.size()):
		MeshKit.sticker(vm, stickers[i], 0.13, places[i][0], places[i][1], places[i][2])
	return vm


## 路地（1 階）を歩ける体：地面・向かいの壁・自分の建物の 1 階の壁（入口の穴は空ける）・路地の両端・電柱・自動販売機。
## 1 階の入口を出て、ベランダの下の自動販売機まで歩く通路。見える物は、ほかの関数が作る。
func _build_street_body(x0: float, x1: float) -> void:
	var body := StaticBody3D.new()
	body.name = "StreetBody"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var zc := (OPPOSITE_Z + FACADE_Z) * 0.5
	var zl := FACADE_Z - OPPOSITE_Z
	MeshKit.shape_box(body, Vector3(x1 - x0, 0.2, zl + 3.0), Vector3((x0 + x1) * 0.5, GROUND_Y - 0.1, zc - 1.5))
	MeshKit.shape_box(body, Vector3(x1 - x0, 8.0, 0.3), Vector3((x0 + x1) * 0.5, GROUND_Y + 4.0, OPPOSITE_Z - 0.15))
	for ex in [x0 - 0.15, x1 + 0.15]:
		MeshKit.shape_box(body, Vector3(0.3, 8.0, zl + 3.0), Vector3(ex, GROUND_Y + 4.0, zc - 1.5))
	var wl := (ENTRANCE_X - ENTRANCE_HALF) - x0
	var wr := x1 - (ENTRANCE_X + ENTRANCE_HALF)
	MeshKit.shape_box(body, Vector3(wl, 8.0, 0.3), Vector3(x0 + wl * 0.5, GROUND_Y + 4.0, FACADE_Z - 0.15))
	MeshKit.shape_box(body, Vector3(wr, 8.0, 0.3), Vector3(x1 - wr * 0.5, GROUND_Y + 4.0, FACADE_Z - 0.15))
	var pole_shape := CylinderShape3D.new()
	pole_shape.radius = 0.17
	pole_shape.height = 4.0
	var pole_cs := CollisionShape3D.new()
	pole_cs.shape = pole_shape
	pole_cs.position = Vector3(POLE_POS.x, GROUND_Y + 2.0, POLE_POS.z)
	body.add_child(pole_cs)
	MeshKit.shape_box(body, Vector3(0.9, 1.8, 0.7), VENDING_POS + Vector3(0, 0.9, 0))
	MeshKit.shape_box(body, Vector3(0.9, 1.8, 0.7), Vector3(2.9, GROUND_Y + 0.9, OPPOSITE_Z + 0.36))


## 向かいの建物の2階と3階の間の壁、電柱、自分の建物の外壁（換気経路の出口の横）にステッカー。
func _street_stickers(parent: Node3D) -> void:
	var face := OPPOSITE_Z
	var y_band := -0.35 + STREET_DROP   # 2階の看板の上、3階の窓の下
	var opp := [[-3.3, 15], [-2.1, 16], [-0.9, 17], [0.5, 18], [1.6, 19], [3.3, 20], [4.6, 21], [6.0, 22], [7.2, 23]]
	for i in opp.size():
		MeshKit.sticker(parent, opp[i][1], 0.32, Vector3(opp[i][0], y_band + (0.15 if i % 2 else -0.1), face), Vector3.BACK, [-5.0, 4.0, 8.0, -3.0, 6.0][i % 5])
	# 電柱：自分のベランダから見える高さ（重ね貼り）
	var pole := POLE_POS
	var pole_n := [24, 25, 26, 27, 30, 31]
	for i in pole_n.size():
		MeshKit.sticker(parent, pole_n[i], 0.2, Vector3(pole.x, 0.35 + i * 0.27, pole.z + 0.15), Vector3.BACK, [-6.0, 5.0, -2.0, 9.0, -4.0, 3.0][i])
	# 自分の建物の外壁：換気経路の出口の右
	MeshKit.sticker(parent, 28, 0.2, Vector3(2.45, 2.75, FACADE_Z - FACADE_T), Vector3.FORWARD, -4.0)
	MeshKit.sticker(parent, 29, 0.18, Vector3(2.7, 2.55, FACADE_Z - FACADE_T), Vector3.FORWARD, 6.0)


## 路地の突き当たりの建物。x：壁の位置、facing：路地側の向き（+1 = +x を向く）、yaw：少し振って曲がり角に見せる。
## 窓・室外機・配管・縦看板付き。背景だけ（当たり判定なし）。
func _end_building(parent: Node3D, x: float, facing: float, yaw: float, tint: Color, signs: Array, roof := 10.0) -> void:
	var bld := Node3D.new()
	bld.name = "EndBuilding"
	bld.position = Vector3(x, 0.0, (OPPOSITE_Z + FACADE_Z) * 0.5 - 0.4)
	bld.rotation.y = yaw + (0.0 if facing > 0.0 else PI)
	parent.add_child(bld)
	# ローカル +x が路地側。壁の面はローカル x=0、幅（z）5m
	var wall := MeshKit.tiled_mat("end_wall_%s" % tint.to_html(false), TEX_STUCCO, 0.9, tint, 0.95)
	var bottom := GROUND_Y
	var top := roof
	MeshKit.box(bld, Vector3(0.4, top - bottom, 5.0), Vector3(-0.2, (top + bottom) * 0.5, 0), wall, "Wall")
	var glass := MeshKit.mat("opp_glass", Color(0.16, 0.18, 0.2), 0.2, 0.2)
	var lit := MeshKit.mat("opp_lit", Color(1.0, 0.85, 0.6), 0.6)
	var frame := MeshKit.mat("opp_frame", Color(0.6, 0.6, 0.58), 0.6)
	for k in range(-4, 3):
		var y := k * FLOOR_PITCH
		for zz in [-1.4, 0.2, 1.5]:
			var w := _rng.randf_range(0.6, 0.9)
			var h := _rng.randf_range(0.8, 1.1)
			MeshKit.box(bld, Vector3(0.03, h + 0.08, w + 0.08), Vector3(0.015, y + 1.2 + h * 0.5, zz), frame)
			MeshKit.box(bld, Vector3(0.02, h, w), Vector3(0.03, y + 1.2 + h * 0.5, zz), lit if _rng.randf() < 0.3 else glass)
		if k < 1 and _rng.randf() < 0.8:
			var unit_pos := Vector3(0.13, y + 0.6, _rng.randf_range(-1.8, 1.8))
			MeshKit.box(bld, Vector3(0.25, 0.42, 0.5), unit_pos, MeshKit.mat("aircon", Color(0.86, 0.85, 0.8), 0.6))
			_quad(bld, TEX_AIRCON, Vector2(0.49, 0.41), unit_pos + Vector3(0.126, 0, 0), Vector3(0, PI * 0.5, 0), "")
	MeshKit.cylinder(bld, 0.035, top - bottom, Vector3(0.06, (top + bottom) * 0.5, 2.3), MeshKit.mat("pipe_grey", Color(0.45, 0.45, 0.44), 0.6), "", -1.0, 8)
	# 縦の突き出し看板（両面）
	var bracket := MeshKit.mat("sign_bracket", Color(0.25, 0.25, 0.26), 0.5, 0.6)
	var zs := [-0.6, 1.0]
	for i in signs.size():
		var tex: Texture2D = load(STREET + "street_sign_v_%02d.png" % signs[i])
		var h2 := 1.6
		var w2 := h2 * tex.get_width() / tex.get_height()
		var c := Vector3(0.12 + w2 * 0.5, -3.0 + i * 0.4 + h2 * 0.5, zs[i])
		_sign(bld, tex, Vector2(w2, h2), c + Vector3(0, 0, 0.012), Vector3.ZERO)
		_sign(bld, tex, Vector2(w2, h2), c - Vector3(0, 0, 0.012), Vector3(0, PI, 0))
		MeshKit.box(bld, Vector3(w2 + 0.04, h2 + 0.04, 0.02), c, bracket)


## 画像を貼った板（看板）。弱く自己発光させ、透過部分は抜く。
func _sign(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := _quad(parent, tex, size, pos, rot, "", true)
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.35
	return mi


## 画像1枚の板。rot は向き（オイラー角）。alpha=true なら透過部分を抜く。
func _quad(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, rot: Vector3, node_name: String, alpha := false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	if not node_name.is_empty():
		mi.name = node_name
	mi.mesh = q
	var m := MeshKit.texture_mat("ext_%s" % tex.resource_path.get_file(), tex, 0.8).duplicate() as StandardMaterial3D
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _build_lights() -> void:
	var balcony_light := OmniLight3D.new()
	balcony_light.name = "BalconyLight"
	balcony_light.position = Vector3(2.5, 2.3, -1.7)
	balcony_light.light_color = Color(0.85, 0.9, 1.0)
	balcony_light.light_energy = 0.6
	balcony_light.omni_range = 3.5
	add_child(balcony_light)
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "AlleyLampLight"
	lamp_light.position = Vector3(3.0, 2.1, OPPOSITE_Z + 0.4)
	lamp_light.light_color = Color(1.0, 0.82, 0.6)
	lamp_light.light_energy = 0.9
	lamp_light.omni_range = 4.0
	add_child(lamp_light)
	for p in [Vector3(-0.6, 2.95, -0.6), Vector3(0.8, 2.95, -0.3), Vector3(1.9, 2.95, -0.9)]:
		var l := OmniLight3D.new()
		l.name = "DuctLight"
		l.position = p
		l.light_color = Color(0.75, 0.8, 0.85)
		l.light_energy = 0.35
		l.omni_range = 1.6
		add_child(l)
