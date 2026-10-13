extends Node3D
## 自室の小物：床のじゅうたん、こたつの上のトランプ・箱・サイコロ・湯のみ・リモコン、床に散らばったカード、ティッシュ箱、雑誌の山、寝床のくま。
## 絵はすべてコードで描く（外部の画像なし）。調べる判定は小物ごとに1つ（id は rug / cards / card_box / dice / cup / tv_remote / tissue / magazines / teddy）。
## cards と dice は main.gd が「めくる」「振る」を毎回違う結果で返す。tv_remote はテレビの電源（apartment.gd の tv_on）。
## 当たり判定はない（小さな物。じゅうたんは床に 1.2cm の厚みで敷くだけ）。
## 座標は部屋と同じ。こたつ（kotatsu.gd）の天板は CENTER + (0, 0.40, 0)。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const KotatsuScript := preload("res://scripts/kotatsu.gd")

const RUG_CENTER := Vector3(2.6, 0.0, 0.7)
const RUG_SIZE := Vector2(2.3, 1.9)
const SUITS := ["spade", "heart", "diamond", "club"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_NAMES := {"spade": "スペード", "heart": "ハート", "diamond": "ダイヤ", "club": "クラブ"}

var tv_remote_node: Node3D
var _steam: Array = []
var _age := 0.0
const STEAM_TIME := 150.0


func _ready() -> void:
	MeshKit.auto_round = false
	_build_rug()
	_build_table_items()
	_build_floor_items()
	MeshKit.auto_round = true


func _process(delta: float) -> void:
	_age += delta
	for i in _steam.size():
		var p: MeshInstance3D = _steam[i]
		p.visible = _age < STEAM_TIME
		if p.visible:
			var k := fmod(_age * 0.4 + i / 3.0, 1.0)
			p.position = Vector3(sin(_age + i * 2.0) * 0.008, 0.07 + k * 0.1, cos(_age * 0.8 + i) * 0.008)
			p.scale = Vector3.ONE * (0.6 + k)
			(p.material_override as StandardMaterial3D).albedo_color.a = 0.28 * (1.0 - k) * clampf((STEAM_TIME - _age) / 30.0, 0.0, 1.0)


## 小物の調べる判定（箱）。id と、親の中での大きさ・位置。
func _area(parent: Node3D, id: String, size: Vector3, center: Vector3) -> void:
	var a := MeshKit.interact_area(parent, "Area_" + id, id)
	MeshKit.shape_box(a, size, center)


# ---------------------------------------------------------------- じゅうたん

func _build_rug() -> void:
	var root := Node3D.new()
	root.name = "Rug"
	root.position = RUG_CENTER
	add_child(root)
	var q := QuadMesh.new()
	q.size = RUG_SIZE
	var m := StandardMaterial3D.new()
	m.albedo_texture = _rug_texture()
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var top := MeshInstance3D.new()
	top.name = "Top"
	top.mesh = q
	top.material_override = m
	top.rotation.x = -PI * 0.5
	top.position.y = 0.0125
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(top)
	# 縁の厚み（暗い色）
	var edge := MeshKit.mat("rug_edge", Color(0.2, 0.1, 0.1), 1.0)
	MeshKit.box(root, Vector3(RUG_SIZE.x, 0.012, RUG_SIZE.y), Vector3(0, 0.006, 0), edge, "Pad")
	# 房（短い辺の両端）
	var fringe := MeshKit.mat("rug_fringe", Color(0.9, 0.85, 0.7), 1.0)
	for sz in [-1.0, 1.0]:
		MeshKit.box(root, Vector3(RUG_SIZE.x - 0.04, 0.004, 0.05), Vector3(0, 0.002, sz * (RUG_SIZE.y * 0.5 + 0.025)), fringe, "Fringe")
	var a := MeshKit.interact_area(root, "Area_rug", "rug")
	MeshKit.shape_box(a, Vector3(RUG_SIZE.x, 0.03, RUG_SIZE.y), Vector3(0, 0.015, 0))
	a.set_meta("interact_range", 2.4)


## 赤地に紺の縁と、クリーム色のひし形の模様。230×190（1px = 1cm）。
func _rug_texture() -> ImageTexture:
	var w := 230
	var h := 190
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var red := Color(0.55, 0.13, 0.14)
	var navy := Color(0.12, 0.15, 0.3)
	var cream := Color(0.9, 0.82, 0.6)
	var gold := Color(0.78, 0.6, 0.25)
	for y in h:
		for x in w:
			var c := red
			var e := mini(mini(x, w - 1 - x), mini(y, h - 1 - y))   # 縁からの距離
			if e < 10:
				c = navy
				if e == 3 or e == 4:
					c = cream
			elif e < 14:
				c = gold
			elif e < 22:
				# 縁の内側の帯：小さな三角の連なり
				var t := posmod(x + y, 12) if (x + y) % 24 < 12 else 12 - posmod(x + y, 12)
				c = navy if t < 6 else red
			else:
				var u := posmod(x, 36) - 18
				var v := posmod(y, 36) - 18
				var d := absi(u) + absi(v)
				if d < 8:
					c = cream
				elif d < 12:
					c = navy
				elif d == 17 or d == 18:
					c = gold.darkened(0.2)
				# 格子の交点に小さな点
				if absi(u) + absi(v) > 30:
					c = gold
			# 織りのざらつき
			var n := 0.035 * sin(x * 2.9) * sin(y * 3.3)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- こたつの上

func _build_table_items() -> void:
	var top_y := KotatsuScript.TOP
	var c := KotatsuScript.CENTER
	var root := Node3D.new()
	root.name = "TableItems"
	root.position = Vector3(c.x, top_y, c.z)
	add_child(root)
	# トランプの扇：5枚を、一端を軸に広げる（表向き）
	var fan := Node3D.new()
	fan.name = "CardFan"
	fan.position = Vector3(-0.17, 0.0, -0.1)
	fan.rotation.y = deg_to_rad(20.0)
	root.add_child(fan)
	var suits := ["spade", "heart", "diamond", "club", "heart"]
	var ranks := ["A", "K", "7", "10", "Q"]
	for i in 5:
		var card := _card(suits[i], ranks[i], true)
		card.position = Vector3(0, 0.0015 * (i + 1), 0)
		card.rotation.y = deg_to_rad(-30.0 + i * 15.0)
		fan.add_child(card)
		card.get_child(0).position.z = -0.0325   # 軸は札の下の端（中心を半分ずらす）
		card.get_child(1).position.z = -0.0325
	_area(fan, "cards", Vector3(0.17, 0.04, 0.12), Vector3(0, 0.02, -0.03))
	# 山札（裏向き）とケース
	var deck := Node3D.new()
	deck.name = "Deck"
	deck.position = Vector3(-0.27, 0.0, 0.1)
	deck.rotation.y = deg_to_rad(-12.0)
	root.add_child(deck)
	for i in 4:
		var cd := _card("spade", "A", false)
		cd.position = Vector3(0, 0.0015 * (i + 1), 0)
		deck.add_child(cd)
	_area(deck, "cards", Vector3(0.07, 0.03, 0.09), Vector3(0, 0.015, 0))
	var box := Node3D.new()
	box.name = "CardBox"
	box.position = Vector3(-0.25, 0.0, 0.25)
	box.rotation.y = deg_to_rad(25.0)
	root.add_child(box)
	MeshKit.box(box, Vector3(0.065, 0.03, 0.095), Vector3(0, 0.015, 0), MeshKit.mat("cardbox_body", Color(0.75, 0.15, 0.15), 0.5), "Body")
	MeshKit.box(box, Vector3(0.067, 0.008, 0.097), Vector3(0, 0.032, -0.008), MeshKit.mat("cardbox_lid", Color(0.68, 0.12, 0.12), 0.5), "Lid")
	MeshKit.box(box, Vector3(0.04, 0.001, 0.05), Vector3(0, 0.0365, -0.008), MeshKit.mat("cardbox_label", Color(0.95, 0.9, 0.7), 0.6), "Label")
	_area(box, "card_box", Vector3(0.08, 0.05, 0.11), Vector3(0, 0.025, 0))
	# サイコロ2つ
	var dice := Node3D.new()
	dice.name = "Dice"
	dice.position = Vector3(0.2, 0.0, -0.2)
	root.add_child(dice)
	_die(dice, Vector3(0, 0, 0), 20.0, 5)
	_die(dice, Vector3(0.045, 0, 0.025), -35.0, 3)
	_area(dice, "dice", Vector3(0.09, 0.04, 0.06), Vector3(0.02, 0.02, 0.01))
	# 湯のみ
	var cup := Node3D.new()
	cup.name = "Cup"
	cup.position = Vector3(0.28, 0.0, 0.0)
	root.add_child(cup)
	MeshKit.cylinder(cup, 0.03, 0.065, Vector3(0, 0.0325, 0), MeshKit.mat("cup_body", Color(0.88, 0.9, 0.85), 0.35), "Body", 0.036)
	MeshKit.cylinder(cup, 0.031, 0.002, Vector3(0, 0.058, 0), MeshKit.mat("cup_tea", Color(0.45, 0.5, 0.2), 0.2), "Tea")
	MeshKit.cylinder(cup, 0.031, 0.012, Vector3(0, 0.012, 0), MeshKit.mat("cup_foot_band", Color(0.25, 0.4, 0.55), 0.4), "Band", 0.03)
	_area(cup, "cup", Vector3(0.08, 0.08, 0.08), Vector3(0, 0.04, 0))
	# 湯気：はじめの 150 秒だけ、ゆらゆら昇って薄れる（そのあとお茶は冷める）
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1, 1, 1, 0.25)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var puff := MeshKit.sphere(cup, 0.014, Vector3(0, 0.07, 0), sm)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_steam.append(puff)
	# テレビのリモコン
	var rem := Node3D.new()
	rem.name = "TvRemote"
	rem.position = Vector3(0.05, 0.0, 0.29)
	rem.rotation.y = deg_to_rad(-70.0)
	root.add_child(rem)
	tv_remote_node = rem
	MeshKit.box(rem, Vector3(0.045, 0.016, 0.17), Vector3(0, 0.008, 0), MeshKit.mat("remote_body", Color(0.12, 0.12, 0.13), 0.5), "Body")
	MeshKit.box(rem, Vector3(0.012, 0.003, 0.012), Vector3(-0.01, 0.0175, -0.065), MeshKit.mat("remote_power", Color(0.85, 0.15, 0.15), 0.4), "Power")
	for i in 6:
		MeshKit.box(rem, Vector3(0.011, 0.003, 0.011), Vector3(-0.01 + (i % 2) * 0.02, 0.0175, -0.035 + (i / 2) * 0.022), MeshKit.mat("remote_btn", Color(0.45, 0.45, 0.5), 0.5), "Button")
	_area(rem, "tv_remote", Vector3(0.06, 0.04, 0.19), Vector3(0, 0.02, 0))


# ---------------------------------------------------------------- 床の小物

func _build_floor_items() -> void:
	# 床に散らばったカード（座布団の近く）
	var spill := Node3D.new()
	spill.name = "SpilledCards"
	spill.position = Vector3(3.55, 0.012, 1.15)
	add_child(spill)
	var sp := [["diamond", "3", 0.0, 0.0, 40.0], ["club", "J", 0.07, 0.04, -20.0], ["heart", "9", -0.05, 0.09, 85.0], ["spade", "2", 0.12, -0.06, 10.0]]
	for s in sp:
		var cd := _card(s[0], s[1], true)
		cd.position = Vector3(s[2], 0.0, s[3])
		cd.rotation.y = deg_to_rad(s[4])
		spill.add_child(cd)
	_area(spill, "cards", Vector3(0.3, 0.04, 0.26), Vector3(0.03, 0.02, 0.02))

	# ティッシュ箱：北の壁ぎわ（浴室の壁ぎわの床）
	var tis := Node3D.new()
	tis.name = "TissueBox"
	tis.position = Vector3(3.7, 0.0, -0.25)
	tis.rotation.y = deg_to_rad(15.0)
	add_child(tis)
	MeshKit.box(tis, Vector3(0.24, 0.07, 0.12), Vector3(0, 0.035, 0), MeshKit.mat("tissue_box", Color(0.55, 0.78, 0.88), 0.6), "Box")
	MeshKit.box(tis, Vector3(0.1, 0.002, 0.045), Vector3(0, 0.0705, 0), MeshKit.mat("tissue_slit", Color(0.1, 0.1, 0.12), 0.8), "Slit")
	var tm := MeshKit.mat("tissue_paper", Color(0.97, 0.97, 0.95), 0.9)
	MeshKit.box(tis, Vector3(0.05, 0.03, 0.001), Vector3(0.005, 0.085, 0), tm, "Sheet").rotation.z = deg_to_rad(8.0)
	_area(tis, "tissue", Vector3(0.26, 0.12, 0.14), Vector3(0, 0.06, 0))

	# 雑誌の山：3冊
	var mag := Node3D.new()
	mag.name = "Magazines"
	mag.position = Vector3(4.97, 0.0, 0.95)
	mag.rotation.y = deg_to_rad(-8.0)
	add_child(mag)
	var mcols := [Color(0.25, 0.45, 0.7), Color(0.85, 0.5, 0.25), Color(0.3, 0.6, 0.45)]
	for i in 3:
		var m := MeshKit.box(mag, Vector3(0.21, 0.008, 0.29), Vector3(0.006 * i, 0.004 + 0.0085 * i, 0), MeshKit.mat("mag_%d" % i, mcols[i], 0.6), "Mag")
		m.rotation.y = deg_to_rad(6.0 * (i - 1))
	MeshKit.box(mag, Vector3(0.15, 0.001, 0.05), Vector3(0.012, 0.0265, -0.08), MeshKit.mat("mag_title", Color(0.95, 0.92, 0.85), 0.6), "Title")
	MeshKit.box(mag, Vector3(0.1, 0.001, 0.02), Vector3(0.012, 0.0265, -0.02), MeshKit.mat("mag_sub", Color(0.2, 0.2, 0.25), 0.6), "Sub")
	_area(mag, "magazines", Vector3(0.24, 0.05, 0.32), Vector3(0, 0.025, 0))

	# 床の「またげる」小物（体を止めない）：脱ぎ捨てた服・ダンベル・ペットボトル・レジ袋。水槽を本棚の上へ移して空いた床に
	var cl := Node3D.new()
	cl.name = "Clothes"
	cl.position = Vector3(4.45, 0.0, 0.5)
	cl.rotation.y = deg_to_rad(25.0)
	add_child(cl)
	MeshKit.box(cl, Vector3(0.34, 0.025, 0.28), Vector3(0, 0.0125, 0), MeshKit.mat("cloth_shirt", Color(0.3, 0.45, 0.65), 0.95), "Shirt").rotation.y = deg_to_rad(10.0)
	MeshKit.box(cl, Vector3(0.2, 0.04, 0.34), Vector3(0.06, 0.04, 0.02), MeshKit.mat("cloth_pants", Color(0.28, 0.28, 0.32), 0.95), "Pants").rotation.y = deg_to_rad(-30.0)
	MeshKit.box(cl, Vector3(0.1, 0.03, 0.06), Vector3(-0.13, 0.065, 0.04), MeshKit.mat("cloth_sock", Color(0.9, 0.9, 0.85), 0.95), "Sock")
	_area(cl, "clothes", Vector3(0.4, 0.14, 0.38), Vector3(0, 0.07, 0))
	var db := Node3D.new()
	db.name = "Dumbbell"
	db.position = Vector3(4.8, 0.0, 0.62)
	db.rotation.y = deg_to_rad(70.0)
	add_child(db)
	var iron := MeshKit.mat("dumbbell_iron", Color(0.12, 0.12, 0.14), 0.4, 0.7)
	var bar := MeshKit.cylinder(db, 0.012, 0.3, Vector3(0, 0.05, 0), iron, "Bar")
	bar.rotation.z = PI * 0.5
	for sx in [-1.0, 1.0]:
		MeshKit.cylinder(db, 0.05, 0.05, Vector3(sx * 0.13, 0.05, 0), iron, "Weight").rotation.z = PI * 0.5
	_area(db, "dumbbell", Vector3(0.36, 0.12, 0.12), Vector3(0, 0.06, 0))
	var bt := Node3D.new()
	bt.name = "Bottle"
	bt.position = Vector3(4.2, 0.0, 0.38)
	bt.rotation.y = deg_to_rad(-40.0)
	add_child(bt)
	var bm := MeshKit.cylinder(bt, 0.035, 0.2, Vector3(0, 0.035, 0), MeshKit.mat("bottle_body", Color(0.65, 0.85, 0.9), 0.3), "Body")
	bm.rotation.z = PI * 0.5
	var cap := MeshKit.cylinder(bt, 0.016, 0.03, Vector3(0.115, 0.035, 0), MeshKit.mat("bottle_cap", Color(0.2, 0.45, 0.8), 0.4), "Cap")
	cap.rotation.z = PI * 0.5
	_area(bt, "bottle", Vector3(0.26, 0.1, 0.1), Vector3(0.0, 0.04, 0))
	var bag := Node3D.new()
	bag.name = "ShoppingBag"
	bag.position = Vector3(3.95, 0.0, 1.35)
	bag.rotation.y = deg_to_rad(15.0)
	add_child(bag)
	var bagm := MeshKit.sphere(bag, 0.12, Vector3(0, 0.1, 0), MeshKit.mat("bag_white", Color(0.95, 0.95, 0.92), 0.85))
	bagm.scale = Vector3(1.0, 0.9, 0.8)
	var leek := MeshKit.cylinder(bag, 0.012, 0.3, Vector3(0.05, 0.28, 0.0), MeshKit.mat("bag_leek", Color(0.55, 0.78, 0.4), 0.7), "Leek")
	leek.rotation.z = deg_to_rad(-18.0)
	_area(bag, "bag", Vector3(0.3, 0.4, 0.26), Vector3(0, 0.2, 0))

	# くま：寝床の上、枕のそばに座っている（本棚の前だと本の表紙を隠すので）
	var bear := Node3D.new()
	bear.name = "Teddy"
	bear.position = Vector3(3.05, 0.24, 2.0)
	bear.rotation.y = deg_to_rad(15.0)
	add_child(bear)
	var fur := MeshKit.mat("teddy_fur", Color(0.62, 0.42, 0.25), 0.95)
	var pale := MeshKit.mat("teddy_pale", Color(0.85, 0.7, 0.5), 0.95)
	var dark := MeshKit.mat("teddy_dark", Color(0.06, 0.05, 0.05), 0.5)
	MeshKit.sphere(bear, 0.09, Vector3(0, 0.09, 0), fur).scale = Vector3(1.0, 1.05, 0.9)
	MeshKit.sphere(bear, 0.06, Vector3(0, 0.085, -0.055), pale)
	MeshKit.sphere(bear, 0.07, Vector3(0, 0.21, 0), fur)
	MeshKit.sphere(bear, 0.03, Vector3(0, 0.195, -0.06), pale)
	MeshKit.sphere(bear, 0.01, Vector3(0, 0.205, -0.088), dark)
	for sx in [-1.0, 1.0]:
		MeshKit.sphere(bear, 0.025, Vector3(sx * 0.05, 0.268, 0.005), fur)             # 耳
		MeshKit.sphere(bear, 0.008, Vector3(sx * 0.026, 0.225, -0.062), dark)          # 目
		MeshKit.sphere(bear, 0.03, Vector3(sx * 0.1, 0.12, -0.01), fur)                # 腕
		MeshKit.sphere(bear, 0.038, Vector3(sx * 0.055, 0.03, -0.08), fur).scale = Vector3(1.0, 0.8, 1.3)   # 脚
	_area(bear, "teddy", Vector3(0.26, 0.3, 0.24), Vector3(0, 0.15, -0.02))


# ---------------------------------------------------------------- カードとサイコロ

## 札1枚。子0＝紙の本体（白い箱／裏は青）、子1＝表の絵（表向きのみ）。原点は札の中心の下面、長辺が z。
func _card(suit: String, rank: String, face_up: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Card"
	var body := MeshKit.box(n, Vector3(0.044, 0.0012, 0.065), Vector3(0, 0.0006, 0),
			MeshKit.mat("card_paper", Color(0.96, 0.95, 0.9), 0.5) if face_up else _card_back_mat(), "Paper")
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(0.044, 0.065)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _card_face(suit, rank)
	fm.roughness = 0.5
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = q
	face.material_override = fm
	face.rotation.x = -PI * 0.5
	face.position = Vector3(0, 0.0013, 0)
	face.visible = face_up
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(face)
	return n


static var _card_cache := {}
static var _back_mat: StandardMaterial3D


func _card_back_mat() -> StandardMaterial3D:
	if _back_mat == null:
		var img := Image.create(32, 48, false, Image.FORMAT_RGB8)
		for y in 48:
			for x in 32:
				var c := Color(0.15, 0.25, 0.55)
				if x < 3 or x > 28 or y < 3 or y > 44:
					c = Color(0.95, 0.95, 0.92)
				elif (x + y) % 6 < 2 or (x - y + 48) % 6 < 2:
					c = Color(0.85, 0.85, 0.9)
				img.set_pixel(x, y, c)
		_back_mat = StandardMaterial3D.new()
		_back_mat.albedo_texture = ImageTexture.create_from_image(img)
		_back_mat.roughness = 0.5
		# 箱のUVは面ごとに全面を使うので、上面だけ模様が出れば足りる
	return _back_mat


## 札の表（40×58）：白地に、中央の大きな柄と、左上・右下の小さな柄（文字は描かない。柄の数で見分ける）。
static func _card_face(suit: String, rank: String) -> ImageTexture:
	var key := suit + rank
	if _card_cache.has(key):
		return _card_cache[key]
	var w := 40
	var h := 58
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.96, 0.92))
	for x in w:
		for y in h:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				img.set_pixel(x, y, Color(0.7, 0.7, 0.7))
	var col := Color(0.8, 0.1, 0.12) if suit == "heart" or suit == "diamond" else Color(0.1, 0.1, 0.13)
	_pip(img, suit, Vector2(w * 0.5, h * 0.5), 11.0, col)
	_pip(img, suit, Vector2(7.0, 8.0), 4.0, col)
	_pip(img, suit, Vector2(w - 7.0, h - 8.0), 4.0, col)
	# ランクは中央の柄の上に、A は1本・数札は短い棒の数（最大 5）・J Q K は王冠の三角
	var bars := mini(5, int(rank) if rank.is_valid_int() else 0)
	for i in bars:
		for dx in 3:
			for dy in 2:
				img.set_pixel(13 + i * 4 + dx - 2 + 2, 20 + dy, col)
	if rank == "A":
		for dy in 3:
			for dx in 3:
				img.set_pixel(19 + dx, 20 + dy, col)
	if rank in ["J", "Q", "K"]:
		for i in 12:
			var hh := 1 + (i % 4 if i % 4 < 2 else 3 - i % 4)
			for dy in hh * 2:
				img.set_pixel(14 + i * 1, 22 - dy, col)
	var t := ImageTexture.create_from_image(img)
	_card_cache[key] = t
	return t


static func _pip(img: Image, suit: String, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r * 1.4), int(c.y + r * 1.4) + 1):
		for x in range(int(c.x - r * 1.4), int(c.x + r * 1.4) + 1):
			if x < 1 or y < 1 or x >= img.get_width() - 1 or y >= img.get_height() - 1:
				continue
			var p := Vector2(x, y) - c
			var u := p / r   # おおよそ -1.4〜1.4
			var inside := false
			match suit:
				"diamond":
					inside = absf(u.x) * 0.8 + absf(u.y) < 1.1
				"heart":
					inside = (Vector2(u.x - 0.5, u.y + 0.35).length() < 0.62) or (Vector2(u.x + 0.5, u.y + 0.35).length() < 0.62) \
							or (u.y > -0.4 and u.y < 1.0 and absf(u.x) < 1.1 - (u.y + 0.4) * 0.8)
				"spade":
					inside = (Vector2(u.x - 0.5, u.y - 0.2).length() < 0.62) or (Vector2(u.x + 0.5, u.y - 0.2).length() < 0.62) \
							or (u.y > -1.0 and u.y < 0.3 and absf(u.x) < 1.1 - (0.3 - u.y) * 0.85) \
							or (u.y > 0.6 and u.y < 1.1 and absf(u.x) < 0.25 + (u.y - 0.6) * 0.8)
				"club":
					inside = (Vector2(u.x, u.y + 0.5).length() < 0.5) or (Vector2(u.x - 0.55, u.y - 0.15).length() < 0.5) \
							or (Vector2(u.x + 0.55, u.y - 0.15).length() < 0.5) or (u.y > 0.1 and u.y < 1.1 and absf(u.x) < 0.2 + maxf(0.0, u.y - 0.7) * 0.8)
			if inside:
				img.set_pixel(x, y, col)


## サイコロ：白い立方体（2cm）。上面と前面に目（黒い小さな球）。
func _die(parent: Node3D, pos: Vector3, yaw: float, top: int) -> void:
	var d := Node3D.new()
	d.name = "Die"
	d.position = pos
	d.rotation.y = deg_to_rad(yaw)
	parent.add_child(d)
	MeshKit.box(d, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.01, 0), MeshKit.mat("die_white", Color(0.96, 0.95, 0.9), 0.35), "Cube")
	var pip := MeshKit.mat("die_pip", Color(0.05, 0.05, 0.06), 0.4)
	var layouts := {1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
			5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]]}
	for p in layouts[top]:
		MeshKit.sphere(d, 0.0022, Vector3(p[0] * 0.005, 0.0205, p[1] * 0.005), pip)
	for p in layouts[7 - top if top != 3 else 4]:
		MeshKit.sphere(d, 0.0022, Vector3(p[0] * 0.005, 0.01 + p[1] * -0.005, -0.0205), pip)


# ---------------------------------------------------------------- 中身を引く

## 山札からランダムな1枚。「スペードのA」のように読み上げる。
static func draw_card(rng: RandomNumberGenerator) -> String:
	var s: String = SUITS[rng.randi() % 4]
	var r: String = RANKS[rng.randi() % 13]
	return "%sの%s" % [SUIT_NAMES[s], r]
