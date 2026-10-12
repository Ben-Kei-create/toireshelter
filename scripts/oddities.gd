extends Node3D
## 部屋の変わった小物：黒電話（本棚の上）、ギター（右の壁）、何の動物か分からない剥製4つ（ギターの上の板の釘に刺さっている）、
## 本棚の上の平積みの本3冊（13〜15。表紙を読める）。座標は部屋と同じ（この節点は原点に置く）。
## 装飾と「調べる」だけ。取得・脱出条件には使わない。
##   黒電話      … 本棚の上（x 5.35、z 0.25、高さ 1.18m）。調べると「リリリン」と鳴る（つながらない）
##   ギター      … 右の壁（x 5.5）に掛ける。z 0.3、高さ 1.3〜2.3m（0.78倍）。調べると弦を鳴らす
##   剥製の板    … 右の壁、z 0.75〜1.45、高さ 2.0m。釘 4 本に、毎回同じ形の（乱数の種で固定）変な動物が刺さっている
## 右の壁（x=5.5）の側に立てた node の向きは、ローカル +z が部屋側（-x）、+x が z 方向。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const BooksScript := preload("res://scripts/books.gd")

const WALL_X := 5.5
const SHELF_TOP := 1.18 + 0.011
const TAXIDERMY_COUNT := 4

var books: Node   # 本を読む判定の持ち主（apartment.gd が渡す）


func _ready() -> void:
	MeshKit.auto_round = true
	_build_phone()
	_build_shelf_books()
	var wall := Node3D.new()
	wall.name = "WallItems"
	wall.position = Vector3(WALL_X, 0.0, 0.0)
	wall.rotation.y = -PI * 0.5
	add_child(wall)
	_build_guitar(wall)
	_build_taxidermy(wall)


func _area(parent: Node, node_name: String, interact_id: String, size: Vector3, center: Vector3) -> void:
	var a := MeshKit.interact_area(parent, node_name, interact_id)
	MeshKit.shape_box(a, size, center)


## 黒電話：黒い胴（下の箱と傾いた上の箱）、ダイヤル（指穴10個）、受話器（棒と、両端の丸い送話口・受話口）、コード。
func _build_phone() -> void:
	var root := Node3D.new()
	root.name = "BlackPhone"
	root.position = Vector3(5.34, SHELF_TOP, 0.25)
	root.rotation.y = deg_to_rad(80.0)
	add_child(root)
	var black := MeshKit.mat("phone_black", Color(0.04, 0.04, 0.045), 0.15, 0.1)
	var cream := MeshKit.mat("phone_card", Color(0.9, 0.88, 0.8), 0.7)
	var steel := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.box(root, Vector3(0.22, 0.05, 0.17), Vector3(0, 0.025, 0), black, "Base")
	var top := MeshKit.box(root, Vector3(0.19, 0.05, 0.15), Vector3(0, 0.07, 0), black, "Top")
	top.rotation.x = deg_to_rad(-6.0)
	# ダイヤル：円盤と指穴（円周に10個、角を空けて）
	MeshKit.cylinder(root, 0.062, 0.012, Vector3(0, 0.1, 0.0), cream, "DialPlate", 0.062)
	for k in 10:
		var a := deg_to_rad(40.0 + k * 28.0)
		MeshKit.cylinder(root, 0.01, 0.014, Vector3(cos(a) * 0.045, 0.101, sin(a) * 0.045), black, "FingerHole", 0.01)
	MeshKit.cylinder(root, 0.02, 0.016, Vector3(0, 0.102, 0), black, "DialCenter", 0.02)
	# 受話器：受け台（Y字の2本）の上に横たえる
	for z in [-0.07, 0.07]:
		MeshKit.box(root, Vector3(0.012, 0.03, 0.012), Vector3(0, 0.13, z * 0.55), black, "CradlePost")
	MeshKit.box(root, Vector3(0.012, 0.012, 0.15), Vector3(0, 0.145, 0), black, "Cradle")
	MeshKit.box(root, Vector3(0.04, 0.035, 0.2), Vector3(0, 0.168, 0), black, "Handset")
	for z in [-0.1, 0.1]:
		MeshKit.cylinder(root, 0.035, 0.04, Vector3(0, 0.155, z), black, "Cup", 0.035)
	# コード（本体から机の端へ垂れる）
	MeshKit.pipe(root, [Vector3(0.11, 0.03, 0.0), Vector3(0.16, 0.0, 0.03), Vector3(0.2, -0.04, 0.0)], 0.005, black)
	MeshKit.cylinder(root, 0.006, 0.01, Vector3(0.0, 0.058, -0.0), steel, "Bell", 0.006)
	_area(root, "PhoneArea", "phone_black", Vector3(0.26, 0.2, 0.24), Vector3(0, 0.1, 0))


## 本棚の上に平積みの本3冊（13 影の標本室・14 出口のない地図・15 留守番する宝石）。表紙を上、背（上）を壁側へ。
func _build_shelf_books() -> void:
	var root := Node3D.new()
	root.name = "ShelfTopBooks"
	add_child(root)
	var basis := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))   # 表紙を上に。背が -x（壁と反対側 … 下の注記）
	var zs := [0.75, 0.97, 1.19]
	for i in 3:
		var n: int = [13, 14, 15][i]
		var tex: Texture2D = load("res://assets/textures/books/book_cover_%02d.png" % n)
		var bh := 0.19
		var bw := bh * float(tex.get_width()) / float(tex.get_height())
		var book := Node3D.new()
		book.name = "TopBook%02d" % n
		book.position = Vector3(5.34, SHELF_TOP, zs[i])
		book.rotation.y = deg_to_rad([3.0, -4.0, 2.0][i])
		root.add_child(book)
		MeshKit.box(book, Vector3(bh, 0.026, bw), Vector3(0, 0.013, 0), MeshKit.mat("book_body_%d" % n, Color(0.3, 0.27, 0.24), 0.8), "Body")
		MeshKit.box(book, Vector3(bh - 0.006, 0.02, bw + 0.002), Vector3(0.004, 0.012, 0), MeshKit.mat("book_pages", Color(0.92, 0.89, 0.8), 0.9), "Pages")
		var q := QuadMesh.new()
		q.size = Vector2(bw, bh)
		var cover := MeshInstance3D.new()
		cover.name = "Cover"
		cover.mesh = q
		cover.material_override = MeshKit.texture_mat("book_cover_%02d" % n, tex, 0.7)
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cover.basis = basis
		cover.position = Vector3(0, 0.0265, 0)
		book.add_child(cover)
		var a := MeshKit.interact_area(book, "BookArea", "book_%02d" % n, books)
		MeshKit.shape_box(a, Vector3(bh, 0.04, bw), Vector3(0, 0.02, 0))


## ギター：胴（大小2つの円盤とくびれ）・指板・ヘッド・糸巻き・6本の弦・サウンドホール。壁の釘に掛け、少し傾ける。
func _build_guitar(wall: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Guitar"
	root.position = Vector3(0.3, 1.74, 0.0)
	root.rotation.z = deg_to_rad(8.0)
	root.scale = Vector3.ONE * 0.78   # 本棚の上（1.19m）から天井（2.4m）の間に収まる大きさ
	wall.add_child(root)
	var wood := MeshKit.mat("guitar_wood", Color(0.78, 0.5, 0.25), 0.35)
	var dark := MeshKit.mat("guitar_dark", Color(0.12, 0.08, 0.06), 0.5)
	var steel := MeshKit.mat("guitar_string", Color(0.85, 0.85, 0.82), 0.2, 0.8)
	var lower := MeshKit.cylinder(root, 0.17, 0.07, Vector3(0, -0.27, 0.05), wood, "BodyLower", 0.17)
	lower.rotation.x = PI * 0.5
	var upper := MeshKit.cylinder(root, 0.13, 0.07, Vector3(0, -0.07, 0.05), wood, "BodyUpper", 0.13)
	upper.rotation.x = PI * 0.5
	MeshKit.box(root, Vector3(0.2, 0.16, 0.07), Vector3(0, -0.15, 0.05), wood, "Waist")
	var hole := MeshKit.cylinder(root, 0.05, 0.004, Vector3(0, -0.15, 0.088), dark, "SoundHole", 0.05)
	hole.rotation.x = PI * 0.5
	MeshKit.box(root, Vector3(0.1, 0.02, 0.012), Vector3(0, -0.33, 0.092), dark, "Bridge")
	MeshKit.box(root, Vector3(0.05, 0.62, 0.025), Vector3(0, 0.27, 0.05), dark, "Neck")
	MeshKit.box(root, Vector3(0.075, 0.16, 0.02), Vector3(0, 0.67, 0.05), dark, "Headstock")
	for k in 6:
		MeshKit.box(root, Vector3(0.002, 1.0, 0.002), Vector3(-0.0125 + k * 0.005, 0.2, 0.097), steel, "String")
	for k in 6:
		var peg_x := -0.045 if k < 3 else 0.045
		MeshKit.box(root, Vector3(0.02, 0.014, 0.012), Vector3(peg_x, 0.63 + (k % 3) * 0.04, 0.05), steel, "Peg")
	_area(root, "GuitarArea", "guitar", Vector3(0.42, 1.05, 0.14), Vector3(0, 0.12, 0.06))


## 剥製の板：暗い板に釘4本。それぞれに「何の動物か分からない」剥製が刺さっている（乱数の種を固定）。
func _build_taxidermy(wall: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TaxidermyBoard"
	root.position = Vector3(1.1, 2.0, 0.0)
	wall.add_child(root)
	MeshKit.box(root, Vector3(0.8, 0.2, 0.03), Vector3(0, 0, 0.015), MeshKit.mat("taxi_board", Color(0.25, 0.17, 0.12), 0.7), "Board")
	var steel := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	for i in TAXIDERMY_COUNT:
		var x := -0.3 + i * 0.2
		var peg := MeshKit.cylinder(root, 0.008, 0.28, Vector3(x, 0, 0.17), steel, "Peg", 0.008)
		peg.rotation.x = PI * 0.5
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242 + i * 17
		var animal := Node3D.new()
		animal.name = "Animal%d" % (i + 1)
		animal.position = Vector3(x, 0, 0.17)
		animal.rotation = Vector3(0, rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4))
		root.add_child(animal)
		_weird_animal(animal, rng)
	_area(root, "TaxidermyArea", "taxidermy", Vector3(0.9, 0.34, 0.34), Vector3(0, 0, 0.17))


## 何の動物か分からない剥製：胴（つぶれた球）、頭（球）、目（数も大きさもばらばら）、耳・角・くちばし・しっぽ・脚（本数も向きもばらばら）。
func _weird_animal(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var fur := Color.from_hsv(rng.randf(), rng.randf_range(0.15, 0.5), rng.randf_range(0.35, 0.8))
	var fm := MeshKit.mat("fur_%s" % fur.to_html(false), fur, 0.95)
	var dark := MeshKit.mat("taxi_dark", Color(0.08, 0.06, 0.05), 0.5)
	var eye_white := MeshKit.mat("taxi_eye", Color(0.95, 0.93, 0.8), 0.3)
	var body := MeshKit.sphere(parent, 0.07, Vector3.ZERO, fm)
	body.scale = Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.7, 1.3), rng.randf_range(0.9, 1.5))
	var head_pos := Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(0.05, 0.1), rng.randf_range(0.02, 0.07))
	var head := MeshKit.sphere(parent, rng.randf_range(0.035, 0.06), head_pos, fm)
	head.scale = Vector3(rng.randf_range(0.8, 1.2), rng.randf_range(0.8, 1.2), rng.randf_range(0.9, 1.4))
	for k in rng.randi_range(1, 4):   # 目（1〜4個）
		var ep := head_pos + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.02, 0.04), 0.035 + rng.randf_range(0.0, 0.02))
		var er := rng.randf_range(0.009, 0.02)
		MeshKit.sphere(parent, er, ep, eye_white)
		MeshKit.sphere(parent, er * 0.5, ep + Vector3(0, 0, er * 0.8), dark)
	for k in rng.randi_range(0, 3):   # 耳か角（細長い円柱）
		var c := MeshKit.cylinder(parent, rng.randf_range(0.006, 0.014), rng.randf_range(0.05, 0.12), head_pos + Vector3(rng.randf_range(-0.05, 0.05), 0.06, rng.randf_range(-0.02, 0.02)), fm if rng.randf() < 0.5 else dark, "Horn", 0.006)
		c.rotation = Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.9, 0.9))
	if rng.randf() < 0.6:   # くちばしか鼻先
		var beak := MeshKit.cylinder(parent, 0.02, 0.06, head_pos + Vector3(0, -0.015, 0.075), MeshKit.mat("taxi_beak", Color(0.85, 0.65, 0.2), 0.5), "Beak", 0.003)
		beak.rotation.x = PI * 0.5
	var tail := MeshKit.cylinder(parent, 0.012, rng.randf_range(0.08, 0.18), Vector3(0, -0.04, -0.12), fm, "Tail", 0.004)
	tail.rotation.x = rng.randf_range(0.3, 1.4)
	for k in rng.randi_range(3, 8):   # 脚（本数も向きもばらばら）
		var leg := MeshKit.cylinder(parent, 0.008, rng.randf_range(0.05, 0.12), Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.09, -0.03), rng.randf_range(-0.07, 0.07)), dark, "Leg", 0.006)
		leg.rotation = Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
