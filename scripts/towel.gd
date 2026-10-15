extends Node3D
## タオル掛けとタオル（TASK-09）。左の壁、便器と入口の間。タオルをクリックするとバーの上で入口側へずれ、
## 裏の壁の小さな引っかき傷が見える。もう一度クリックで元に戻る。タオルは所持品にしない。
## この節点はバーの付け根（壁面、高さ 1.15m、z=0.72）に置く。ローカル +x が部屋側、+z が入口側。
##
##   TowelBar/Cloth        … 見た目（布の物理シミュレーションなし。ずらすと入口側へ寄って幅が縮む＝たぐり寄せた形）
##   TowelBar/TowelArea    … タオルの照準判定（towel）。見た目と別に動かす：
##                           ずらし終わってから寄せた位置へ、戻すときは動き始めに元の位置へ。
##                           タオルが傷を覆っている間は、必ず判定が傷の手前にある
##   TowelBar/Scratches    … 壁の浅い不規則な線（見た目だけ、数字や暗号ではない）
##   TowelBar/ScratchArea  … 傷の照準判定（towel_scratch）。タオル越しには当たらない

const MeshKit := preload("res://scripts/mesh_kit.gd")
const TOWEL_TEX := preload("res://assets/textures/towel_fabric.png")
const SCRATCH_TEX := preload("res://assets/textures/bath/bath_decal_01.png")   # 透過付き（BATH-ASSETS-40）

const OUT := 0.06              # バーの壁からの出幅
const WIDTH := 0.34
const FRONT_LEN := 0.46
const BACK_LEN := 0.3
const FOLD_R := 0.022
const SLID_Z := 0.12           # ずらしたときの布の中心（入口側）
const SLID_SCALE := 0.55       # ずらしたときの幅の縮み
const SLIDE_TIME := 0.4

var slid := false
var has_coin := true      # 傷のくぼみに十円玉が挟まっている
var coin_node: Node3D
var busy := false
var cloth: Node3D
var _towel_area: Area3D
var _towel_shape: CollisionShape3D


func _ready() -> void:
	_build_bar()
	_build_cloth()
	_build_scratches()
	_build_coin()


func toggle() -> void:
	if busy:
		return
	busy = true
	slid = not slid
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not slid:
		_place_area(false)   # 戻し始めた時点で傷は覆われていく
	tween.tween_property(cloth, "position:z", SLID_Z if slid else 0.0, SLIDE_TIME)
	tween.parallel().tween_property(cloth, "scale:z", SLID_SCALE if slid else 1.0, SLIDE_TIME)
	tween.tween_callback(func() -> void:
		if slid:
			_place_area(true)
		busy = false)


func _place_area(is_slid: bool) -> void:
	var box := _towel_shape.shape as BoxShape3D
	box.size = Vector3(FOLD_R * 2.0 + 0.01, FRONT_LEN + 0.03, WIDTH * (SLID_SCALE if is_slid else 1.0))
	_towel_shape.position = Vector3(OUT, -FRONT_LEN * 0.5 + 0.01, SLID_Z if is_slid else 0.0)


func _build_bar() -> void:
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.pipe(self, [Vector3(OUT, 0, -0.23), Vector3(OUT, 0, 0.23)], 0.008, metal)
	for zz in [-0.22, 0.22]:
		MeshKit.box(self, Vector3(OUT, 0.012, 0.012), Vector3(OUT * 0.5, 0, zz), metal)


func _build_cloth() -> void:
	cloth = Node3D.new()
	cloth.name = "Cloth"
	add_child(cloth)
	# 布地は画像を 0.2m 四方で繰り返す（トリプラナー投影なので、箱・円柱のどの面でも同じ細かさ）。縁取りは同じ布地を暗くしたもの
	var fabric := MeshKit.tiled_mat("towel", TOWEL_TEX, 0.2)
	var hem := MeshKit.tiled_mat("towel_hem", TOWEL_TEX, 0.2, Color(0.78, 0.8, 0.84))
	var t := 0.009
	var fold := MeshKit.cylinder(cloth, FOLD_R, WIDTH, Vector3(OUT, 0, 0), fabric, "Fold", -1.0, 16)
	fold.rotation.x = deg_to_rad(90.0)
	MeshKit.box(cloth, Vector3(t, FRONT_LEN, WIDTH), Vector3(OUT + FOLD_R - t * 0.5, -FRONT_LEN * 0.5, 0), fabric, "Front")
	MeshKit.box(cloth, Vector3(t, BACK_LEN, WIDTH), Vector3(OUT - FOLD_R + t * 0.5, -BACK_LEN * 0.5, 0), fabric, "Back")
	MeshKit.box(cloth, Vector3(t + 0.004, 0.035, WIDTH + 0.004), Vector3(OUT + FOLD_R - t * 0.5, -FRONT_LEN + 0.02, 0), hem, "Hem")
	_towel_area = MeshKit.interact_area(self, "TowelArea", "towel", self)
	_towel_shape = MeshKit.shape_box(_towel_area, Vector3.ONE, Vector3.ZERO)
	_towel_shape.shape = BoxShape3D.new()
	_place_area(false)


func _build_scratches() -> void:
	# タオルに隠れる範囲（入口から遠い側、z -0.15〜-0.03、高さ 0.78〜1.0m）に、細い線を数本。
	# 角度と長さは手で決めた固定値（毎回同じ見た目）
	var root := Node3D.new()
	root.name = "Scratches"
	add_child(root)
	# 傷の画像（透過付き）を、壁面の 1.5mm 手前の薄い板に貼る。GL Compatibility でも描けるよう、デカールではなく QuadMesh。
	# 細い線が縮小で消えないよう、ミップマップ付きの線形フィルタ＋半透明の合成。影は落とさない
	var q := QuadMesh.new()
	var h := 0.24
	q.size = Vector2(h * SCRATCH_TEX.get_width() / SCRATCH_TEX.get_height(), h)
	var m := StandardMaterial3D.new()
	m.albedo_texture = SCRATCH_TEX
	m.albedo_color = Color(1.0, 0.9, 0.62)   # 黒い腰壁の上でも見えるよう、明るい金色の線にして、ほんのり光らせる
	m.emission_enabled = true
	m.emission_texture = SCRATCH_TEX
	m.emission = Color(1.0, 0.82, 0.45)
	m.emission_energy_multiplier = 1.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.name = "ScratchDecal"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0015, -0.27, -0.09)
	mi.rotation.y = PI * 0.5   # 表（+z）を部屋側（+x）へ
	root.add_child(mi)
	var area := MeshKit.interact_area(self, "ScratchArea", "towel_scratch")
	MeshKit.shape_box(area, Vector3(0.004, 0.2, 0.12), Vector3(0.002, -0.27, -0.09))


## 傷のくぼみに挟まった古い十円玉（壁に立てて挟まっている。タオルをずらすと見える）。
func _build_coin() -> void:
	coin_node = Node3D.new()
	coin_node.name = "Coin"
	coin_node.position = Vector3(0.004, -0.27, -0.09)
	add_child(coin_node)
	var disc := MeshKit.cylinder(coin_node, 0.0118, 0.0016, Vector3.ZERO, _bright_coin_mat(), "Disc")
	disc.rotation.z = deg_to_rad(90.0)   # 円盤の面を部屋側（+x）へ


func take_coin() -> void:
	has_coin = false
	if coin_node and is_instance_valid(coin_node):
		coin_node.visible = false


## 十円玉の持ち物の拡大モデル（洗面台・浴槽に置く見た目にも使う）。
## 十円玉の色：金と赤の部屋でも埋もれないよう、明るい銅色に、ほんのり自分で光らせる。
static func _bright_coin_mat() -> StandardMaterial3D:
	var m := MeshKit.mat("coin10", Color(0.98, 0.8, 0.32), 0.12, 0.95)   # メダルのような、つやのある金色
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.28)
	m.emission_energy_multiplier = 0.5
	return m


static func coin_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.0235, 0.004, Vector3.ZERO, _bright_coin_mat(), "Disc", -1.0, 32)
	# 縁のふちどり（メダルのように、少し盛り上がる）と、真ん中の浮き彫り
	var rim := MeshKit.cylinder(n, 0.0238, 0.0052, Vector3.ZERO, MeshKit.mat("coin10_rim", Color(1.0, 0.86, 0.4), 0.1, 1.0), "Rim", -1.0, 32)
	rim.scale = Vector3(1.0, 1.0, 1.0)
	MeshKit.cylinder(n, 0.019, 0.0058, Vector3.ZERO, _bright_coin_mat(), "Face", -1.0, 32)
	return n


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(_id: String) -> String:
	if busy:
		return ""
	return "towel_back" if slid else "towel_slide"


func interact(_id: String) -> String:
	toggle()
	return ""
