extends Node3D
## 小さなキッチン（自室の手前の壁＝南の壁の右寄り、x 4.0〜4.84 の台と x 4.85〜5.45 の冷蔵庫）。
## 流し台・ガスコンロ（やかん）・吊り戸棚・レンジフード・冷蔵庫。装飾と「調べる」だけ（水は出ない・火はつかない）。
## 座標は部屋と同じ（この節点は原点に置く）。体を止める当たり判定は、流し・コンロの台と冷蔵庫の箱。調べる対象：kitchen_sink / kitchen_stove / fridge。
##
## 画像（assets/textures/kitchen/、ユーザー作成・生成 AI 使用）：
##   kitchen_cabinet … 引き出しと両開き扉の台の正面（台の前面に、比率のまま貼る。幅 0.84m × 高さ 0.9m）
##   kitchen_counter … 天板の石目（0.5m で繰り返す。継ぎ目が出ないよう半分ずらして混ぜてある）
##   kitchen_sink    … 流しの真上からの絵（天板の上に平らに貼る）
##   kitchen_faucet  … 蛇口の横からの絵（流しの奥に、部屋側へ向けて立てる）
##   kitchen_stove   … コンロの真上からの絵（天板の右に平らに貼る）。左の火口の上にやかん

const MeshKit := preload("res://scripts/mesh_kit.gd")
const TEX_DIR := "res://assets/textures/kitchen/kitchen_%s.png"

const WALL_Z := 2.4
const COUNTER_H := 0.9      # 台の高さ（天板の下面）
const SLAB_T := 0.02        # 天板の厚み
const DEPTH := 0.6
const X0 := 3.998           # 台の左端（西）
const WIDTH := 0.844        # 台の幅（正面の絵の比率から）
const TOP := COUNTER_H + SLAB_T


func _ready() -> void:
	MeshKit.auto_round = false
	var steel := MeshKit.mat("kitchen_steel", Color(0.78, 0.8, 0.82), 0.3, 0.7)
	var dark := MeshKit.mat("kitchen_dark", Color(0.1, 0.1, 0.11), 0.5)
	var white := MeshKit.mat("kitchen_white", Color(0.94, 0.94, 0.95), 0.4)
	var cream := MeshKit.mat("kitchen_cream", Color(0.86, 0.8, 0.66), 0.7)
	var cz := WALL_Z - DEPTH * 0.5
	var half := WIDTH * 0.5
	var cx := X0 + half
	# 台（流し側とコンロ側の2つの箱。同じ色。前面に絵を貼る）
	_body("KitchenSink", "kitchen_sink", Vector3(half, TOP, DEPTH), Vector3(X0 + half * 0.5, TOP * 0.5, cz))
	_body("KitchenStove", "kitchen_stove", Vector3(half, TOP, DEPTH), Vector3(X0 + half * 1.5, TOP * 0.5, cz))
	MeshKit.box(self, Vector3(WIDTH, COUNTER_H, DEPTH), Vector3(cx, COUNTER_H * 0.5, cz), cream, "Cabinet")
	_quad("cabinet", Vector2(WIDTH, COUNTER_H), Vector3(cx, COUNTER_H * 0.5, WALL_Z - DEPTH - 0.002), Basis(Vector3.UP, PI), false, "CabinetFront")
	# 天板（石目）
	var top_mat := MeshKit.tiled_mat("kitchen_counter", load(TEX_DIR % "counter"), 0.5, Color.WHITE, 0.6)
	MeshKit.box(self, Vector3(WIDTH + 0.02, SLAB_T, DEPTH + 0.02), Vector3(cx, COUNTER_H + SLAB_T * 0.5, cz - 0.01), top_mat, "Top")
	# 天板の上の絵：流しは左（西）、コンロは右（東）。上から見た絵を、奥（壁側）が絵の上になるよう寝かせる
	var flat := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	var sink_x := X0 + half * 0.5
	var stove_x := X0 + half * 1.5
	_quad("sink", Vector2(0.38, 0.38 * 595.0 / 934.0), Vector3(sink_x, TOP + 0.002, cz), flat, false, "SinkTop")
	_quad("stove", Vector2(0.4, 0.4 * 668.0 / 1011.0), Vector3(stove_x, TOP + 0.002, cz), flat, true, "StoveTop")
	# 蛇口：流しの奥に、部屋側（-z）へ向けて立てる（絵の左が部屋から見て左）
	_quad("faucet", Vector2(0.17, 0.17 * 631.0 / 961.0), Vector3(sink_x + 0.02, TOP + 0.058, WALL_Z - 0.09), Basis(Vector3.UP, PI), true, "Faucet")
	# やかん：左の火口の上（絵の左の火口は、絵の左端から 25%、上から 50% のあたり）
	var kettle := MeshKit.mat("kitchen_kettle", Color(0.85, 0.35, 0.3), 0.3, 0.4)
	var burner_x := stove_x + (0.5 - 0.25) * 0.4
	MeshKit.cylinder(self, 0.07, 0.12, Vector3(burner_x, TOP + 0.075, cz), kettle, "Kettle", 0.06)
	MeshKit.sphere(self, 0.016, Vector3(burner_x, TOP + 0.145, cz), dark)
	# 吊り戸棚とレンジフード
	MeshKit.box(self, Vector3(WIDTH * 0.5, 0.6, 0.32), Vector3(X0 + half * 0.5, 1.72, WALL_Z - 0.16), cream, "WallCabinet")
	MeshKit.box(self, Vector3(WIDTH * 0.5, 0.04, 0.5), Vector3(X0 + half * 1.5, 1.45, WALL_Z - 0.25), steel, "Hood")
	MeshKit.box(self, Vector3(0.18, 0.5, 0.18), Vector3(X0 + half * 1.5, 1.75, WALL_Z - 0.09), steel, "HoodDuct")
	# 冷蔵庫（x 4.85〜5.45）：二段の扉
	_body("Fridge", "fridge", Vector3(0.6, 1.7, 0.62), Vector3(5.15, 0.85, WALL_Z - 0.31))
	MeshKit.box(self, Vector3(0.6, 1.7, 0.62), Vector3(5.15, 0.85, WALL_Z - 0.31), white, "FridgeBody")
	MeshKit.box(self, Vector3(0.56, 0.01, 0.01), Vector3(5.15, 1.15, WALL_Z - 0.625), MeshKit.mat("kitchen_seam", Color(0.5, 0.5, 0.52), 0.6), "Seam")
	MeshKit.box(self, Vector3(0.015, 0.4, 0.02), Vector3(5.38, 1.4, WALL_Z - 0.64), steel, "HandleUpper")
	MeshKit.box(self, Vector3(0.015, 0.5, 0.02), Vector3(5.38, 0.75, WALL_Z - 0.64), steel, "HandleLower")
	for k in 5:
		MeshKit.box(self, Vector3(0.05, 0.05, 0.006), Vector3(5.0 + (k % 3) * 0.1, 1.45 + (k / 3) * 0.1, WALL_Z - 0.632), MeshKit.mat("magnet_%d" % k, Color.from_hsv(k * 0.18, 0.6, 0.9), 0.5), "Magnet")
	MeshKit.auto_round = true


## 画像1枚の板（比率は呼び出し側で size に入れる）。basis で向きを決め、透過の縁は alpha scissor で抜く。影は落とさない。
func _quad(file: String, size: Vector2, pos: Vector3, basis: Basis, double_sided: bool, node_name: String) -> MeshInstance3D:
	var tex: Texture2D = load(TEX_DIR % file)
	var q := QuadMesh.new()
	q.size = size
	var m := MeshKit.texture_mat("kitchen_%s" % file, tex, 0.6).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = basis
	mi.position = pos
	add_child(mi)
	return mi


func _body(node_name: String, interact_id: String, size: Vector3, center: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = MeshKit.LAYER_WORLD
	b.collision_mask = 0
	b.set_meta("interact_id", interact_id)
	add_child(b)
	MeshKit.shape_box(b, size, center)
	return b
