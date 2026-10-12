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

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2610
	_build_duct()
	_build_facade()
	_build_balcony()
	_build_opposite()
	_build_street()
	_build_lights()


# ---------------------------------------------------------------- 換気経路

func _build_duct() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var duct := Node3D.new()
	duct.name = "Duct"
	add_child(duct)
	var metal := MeshKit.tiled_mat("duct_tex", TEX_DUCT, 0.6, Color(0.85, 0.87, 0.9), 0.5)
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

func _build_facade() -> void:
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
		[x0, x1, -8.0, 0.0],
		[x0, WINDOW_X.x, 0.0, WINDOW_TOP], [WINDOW_X.y, x1, 0.0, WINDOW_TOP],
		[x0, x1, WINDOW_TOP, DUCT_FLOOR],
		[x0, DUCT_B.position.x, DUCT_FLOOR, DUCT_TOP], [DUCT_B.end.x, x1, DUCT_FLOOR, DUCT_TOP],
		[x0, x1, DUCT_TOP, 12.0],
	]
	for p in pieces:
		MeshKit.box(f, Vector3(p[1] - p[0], p[3] - p[2], FACADE_T), Vector3((p[0] + p[1]) * 0.5, (p[2] + p[3]) * 0.5, z), wall)
	# 換気経路の出口のフード（金属の庇）
	var hood := MeshKit.mat("duct", Color(0.5, 0.52, 0.54), 0.5, 0.3)
	MeshKit.box(f, Vector3(0.7, 0.03, 0.12), Vector3(1.9, DUCT_TOP + 0.02, FACADE_Z - 0.06), hood, "ExitHood")
	# 縦の雨どいと、上下の階のベランダ（背景）
	MeshKit.cylinder(f, 0.04, 20.0, Vector3(1.15, 2.0, FACADE_Z - 0.06), MeshKit.mat("pipe_grey", Color(0.45, 0.45, 0.44), 0.6), "Downpipe", -1.0, 10)
	for k in [-2, -1, 1, 2]:
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
	MeshKit.box(o, Vector3(x1 - x0, 20.0, 0.3), Vector3((x0 + x1) * 0.5, 2.0, OPPOSITE_Z - 0.15), wall, "Wall")
	# 路地の地面（2階分下）
	MeshKit.box(o, Vector3(x1 - x0, 0.1, OPPOSITE_Z - BALCONY.position.z + 0.8), Vector3((x0 + x1) * 0.5, -2.0 * FLOOR_PITCH - 0.05, (OPPOSITE_Z + FACADE_Z) * 0.5), MeshKit.tiled_mat("alley_concrete", TEX_CONCRETE, 1.2, Color(0.75, 0.75, 0.75), 1.0), "Alley")
	var glass := MeshKit.mat("opp_glass", Color(0.16, 0.18, 0.2), 0.2, 0.2)
	var lit := MeshKit.mat("opp_lit", Color(1.0, 0.85, 0.6), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.8, 0.55)
	lit.emission_energy_multiplier = 0.9
	var frame := MeshKit.mat("opp_frame", Color(0.6, 0.6, 0.58), 0.6)
	var unit_mat := MeshKit.mat("aircon", Color(0.86, 0.85, 0.8), 0.6)
	var face := OPPOSITE_Z
	for floor_i in range(0, 3):   # 1階・2階は店（_build_street()）
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
		MeshKit.cylinder(o, 0.035, 20.0, Vector3(px, 2.0, face + 0.06), pipe, "", -1.0, 8)
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

# ---------------------------------------------------------------- 路地の店と看板（下北沢の細い路地のような密集感）

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
		[-1, [-3.6, 1.7, 1], [-1.75, 1.5, 2], [-0.1, 1.9, 3], [1.95, 1.6, 4], [3.7, 1.8, 5], [5.65, 1.9, 6]],
		[-2, [-3.2, 1.9, 7], [-1.1, 1.7, 8], [0.8, 2.0, 9], [3.0, 1.6, 10], [4.8, 1.9, 11], [6.8, 1.0, 12]],
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
		var cy: float = v[2] + h * 0.5
		# 両面に同じ看板（それぞれ正しい向きで読める）
		_sign(st, tex, Vector2(w, h), Vector3(v[0] + 0.012, cy, cz), Vector3(0, PI * 0.5, 0))
		_sign(st, tex, Vector2(w, h), Vector3(v[0] - 0.012, cy, cz), Vector3(0, -PI * 0.5, 0))
		MeshKit.box(st, Vector3(0.02, h + 0.04, w + 0.04), Vector3(v[0], cy, cz), bracket)
		for yy in [cy + h * 0.45, cy - h * 0.45]:
			MeshKit.box(st, Vector3(0.03, 0.03, 0.14), Vector3(v[0], yy, wall_z + dir * 0.07), bracket)
	# 路地の両端：別の建物が視界をふさぎ、路地はその先で曲がっていく（空が抜けないように）
	_end_building(st, -4.6, 1.0, deg_to_rad(10.0), Color(0.78, 0.82, 0.76), [7, 11])
	_end_building(st, 8.6, -1.0, deg_to_rad(-14.0), Color(0.86, 0.8, 0.7), [2, 12])
	# 自分の建物の換気口（各階の同じ位置）
	for k in [-2, -1, 1, 2]:
		_quad(st, TEX_VENT, Vector2(0.3, 0.23), Vector3(1.9, k * FLOOR_PITCH + 2.8, FACADE_Z - FACADE_T - 0.004), Vector3(0, PI, 0), "")
	# 電柱：路地の自分の建物寄り。コンクリートの柱と変圧器、電線は向かいの建物と自分の建物へ
	var pole := MeshKit.tiled_mat("pole_concrete", TEX_CONCRETE, 0.6, Color(0.85, 0.85, 0.85), 0.9)
	var pole_pos := Vector3(0.45, 0.0, -2.55)
	var bottom := -2.0 * FLOOR_PITCH
	var top := 5.6
	MeshKit.cylinder(st, 0.15, top - bottom, Vector3(pole_pos.x, (top + bottom) * 0.5, pole_pos.z), pole, "UtilityPole", 0.12, 14)
	MeshKit.cylinder(st, 0.22, 0.75, Vector3(pole_pos.x + 0.3, 3.6, pole_pos.z), MeshKit.mat("transformer", Color(0.55, 0.58, 0.55), 0.5, 0.3), "Transformer")
	MeshKit.box(st, Vector3(1.0, 0.08, 0.08), Vector3(pole_pos.x, top - 0.4, pole_pos.z), MeshKit.mat("sign_bracket", Color(0.25, 0.25, 0.26), 0.5, 0.6), "CrossArm")
	var wire := MeshKit.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	for e in [Vector3(-4.0, 4.9, -2.5), Vector3(8.0, 5.1, -2.6), Vector3(3.0, 4.5, OPPOSITE_Z + 0.05), Vector3(-1.5, 4.0, FACADE_Z - 0.05)]:
		MeshKit.pipe(st, [Vector3(pole_pos.x, top - 0.4, pole_pos.z), (Vector3(pole_pos.x, top - 0.4, pole_pos.z) + e) * 0.5 + Vector3(0, -0.35, 0), e], 0.007, wire)
	MeshKit.auto_round = true


## 路地の突き当たりの建物。x：壁の位置、facing：路地側の向き（+1 = +x を向く）、yaw：少し振って曲がり角に見せる。
## 窓・室外機・配管・縦看板付き。背景だけ（当たり判定なし）。
func _end_building(parent: Node3D, x: float, facing: float, yaw: float, tint: Color, signs: Array) -> void:
	var bld := Node3D.new()
	bld.name = "EndBuilding"
	bld.position = Vector3(x, 0.0, (OPPOSITE_Z + FACADE_Z) * 0.5 - 0.4)
	bld.rotation.y = yaw + (0.0 if facing > 0.0 else PI)
	parent.add_child(bld)
	# ローカル +x が路地側。壁の面はローカル x=0、幅（z）5m
	var wall := MeshKit.tiled_mat("end_wall_%s" % tint.to_html(false), TEX_STUCCO, 0.9, tint, 0.95)
	var bottom := -2.0 * FLOOR_PITCH
	var top := 10.0
	MeshKit.box(bld, Vector3(0.4, top - bottom, 5.0), Vector3(-0.2, (top + bottom) * 0.5, 0), wall, "Wall")
	var glass := MeshKit.mat("opp_glass", Color(0.16, 0.18, 0.2), 0.2, 0.2)
	var lit := MeshKit.mat("opp_lit", Color(1.0, 0.85, 0.6), 0.6)
	var frame := MeshKit.mat("opp_frame", Color(0.6, 0.6, 0.58), 0.6)
	for k in range(-2, 3):
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
