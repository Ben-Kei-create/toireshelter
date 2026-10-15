extends Node3D
## 隣の和室（おばあちゃんの家）。こたつの中の壁をツルハシで壊すと行ける。暗くて質素。原点は部屋の中心の床（x ±1.8、z ±1.35、天井 2.3）。
##   北の壁の床の間：掛け軸（目の高さがぴったり 142 cm のとき、バラバラの墨が犬→猿→キジの影絵に揃う）と、家宝（栞を 3 枚、順に差す）、おばあちゃんの写真
##   東の壁の高い所：神棚。南の壁の高い所：欄間（彫刻）。足元：ざぶとんと、低いテーブル（下南澤の 3D マップ）。はしご（拾える）。
##   西の壁の低い所：こたつの中へ戻る穴。南の壁の根もとに、ねずみ穴。暗い隅（東南）に、コインが 1 枚（ライターで見える）。
## 照明は置かない（真っ暗。main.gd が環境光を落とす）。ライターか松明の明かりで見て回る。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Silhouettes := preload("res://scripts/silhouettes.gd")
const Stage4Items := preload("res://scripts/stage4_items.gd")

const HX := 1.8
const HZ := 1.35
const H := 2.3
const SPAWN := Vector3(-1.25, 0.05, 0.25)         # こたつの穴から出てきた位置（東を向く）
const HOLE_POS := Vector3(-HX + 0.02, 0.0, 0.25)    # 西の壁の穴
const SCROLL_POS := Vector3(-0.75, 1.25, -HZ + 0.03)
const SCROLL_EYE := 1.42                           # この目の高さ（m）で見ると、影絵が揃う
const SCROLL_TOLERANCE := 0.025

var scroll_overlay: MeshInstance3D          # 揃った影絵（目の高さがぴったりのときだけ見える）
var heirloom: Node3D
var heirloom_slots: Array = []              # 差し込み口の灯り（3 つ）
var heirloom_open := false
var slots_filled := 0                       # 差し込んだ栞の数
var photo_prop: Node3D
var photo_taken := false
var ladder_prop: Node3D
var ladder_taken := false
var coin_prop: Node3D
var coin_taken := false

static var _tatami: ImageTexture


static func tatami_tex() -> ImageTexture:
	if _tatami == null:
		var img := Image.create(180, 90, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for y in 90:
			for x in 180:
				var n := rng.randf_range(-0.03, 0.03)
				var c := Color(0.55 + n, 0.55 + n, 0.3 + n * 0.5)
				if (x % 6) < 1:
					c = c.darkened(0.06)   # い草の筋
				if x < 3 or x > 176 or y < 3 or y > 86:
					c = Color(0.16, 0.2, 0.14)   # へり
				img.set_pixel(x, y, c)
		_tatami = ImageTexture.create_from_image(img)
	return _tatami


func _ready() -> void:
	name = "JapaneseRoom"
	MeshKit.auto_round = false
	_build_shell()
	_build_alcove()
	_build_shrine_and_ranma()
	_build_table()
	_build_extras()
	MeshKit.auto_round = true


func _body() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Collision"
	b.collision_layer = MeshKit.LAYER_WORLD
	b.collision_mask = 0
	add_child(b)
	return b


func _solid(body: StaticBody3D, size: Vector3, center: Vector3, m: Material, node_name := "") -> void:
	MeshKit.box(self, size, center, m, node_name)
	MeshKit.shape_box(body, size, center)


func _build_shell() -> void:
	var body := _body()
	var floor_m := MeshKit.tiled_mat("tatami", tatami_tex(), 1.8, Color(0.85, 0.85, 0.8), 0.95)
	var wall := MeshKit.mat("washitsu_wall", Color(0.55, 0.5, 0.4), 0.95)
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	_solid(body, Vector3(HX * 2.0 + 0.2, 0.2, HZ * 2.0 + 0.2), Vector3(0, -0.1, 0), floor_m, "Floor")
	MeshKit.box(self, Vector3(HX * 2.0 + 0.2, 0.1, HZ * 2.0 + 0.2), Vector3(0, H + 0.05, 0), wood, "Ceiling")
	_solid(body, Vector3(HX * 2.0 + 0.2, H, 0.2), Vector3(0, H * 0.5, -HZ - 0.1), wall, "NorthWall")
	_solid(body, Vector3(HX * 2.0 + 0.2, H, 0.2), Vector3(0, H * 0.5, HZ + 0.1), wall, "SouthWall")
	_solid(body, Vector3(0.2, H, HZ * 2.0), Vector3(-HX - 0.1, H * 0.5, 0), wall, "WestWall")
	_solid(body, Vector3(0.2, H, HZ * 2.0), Vector3(HX + 0.1, H * 0.5, 0), wall, "EastWall")
	# 柱と長押（細い木）
	for x in [-HX + 0.05, HX - 0.05]:
		for z in [-HZ + 0.05, HZ - 0.05]:
			MeshKit.box(self, Vector3(0.1, H, 0.1), Vector3(x, H * 0.5, z), wood, "Pillar")
	MeshKit.box(self, Vector3(HX * 2.0, 0.08, 0.04), Vector3(0, 1.95, -HZ + 0.02), wood, "Nageshi")
	MeshKit.box(self, Vector3(HX * 2.0, 0.08, 0.04), Vector3(0, 1.95, HZ - 0.02), wood, "Nageshi")


## 北の壁の床の間：掛け軸・家宝・おばあちゃんの写真。
func _build_alcove() -> void:
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	# 床の間の台（一段高い板）
	MeshKit.box(self, Vector3(2.4, 0.12, 0.5), Vector3(-0.1, 0.06, -HZ + 0.25), wood, "AlcoveFloor")
	# 掛け軸：紙・軸・墨の模様・（ぴったりの高さで揃う）影絵
	var paper := MeshKit.mat("scroll_paper", Color(0.88, 0.82, 0.66), 0.9)
	var cloth := MeshKit.mat("scroll_cloth", Color(0.32, 0.28, 0.22), 0.9)
	var holder := Node3D.new()
	holder.name = "Scroll"
	holder.position = SCROLL_POS
	add_child(holder)
	MeshKit.box(holder, Vector3(0.58, 1.5, 0.008), Vector3(0, 0, 0), cloth, "Backing")
	MeshKit.box(holder, Vector3(0.46, 1.32, 0.004), Vector3(0, 0, 0.006), paper, "Paper")
	var blot := QuadMesh.new()
	blot.size = Vector2(0.44, 1.28)
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = Silhouettes.scroll_blotches()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bmi := MeshInstance3D.new()
	bmi.name = "Blotches"
	bmi.mesh = blot
	bmi.material_override = bm
	bmi.position = Vector3(0, 0, 0.0095)
	holder.add_child(bmi)
	# 揃った影絵：犬 → 猿 → キジ（上から下）。ふだんは見えない
	scroll_overlay = MeshInstance3D.new()
	scroll_overlay.name = "Aligned"
	var combined := Node3D.new()
	scroll_overlay.add_child(combined)
	holder.add_child(scroll_overlay)
	var kinds := ["dog", "monkey", "pheasant"]
	for i in 3:
		var q := QuadMesh.new()
		q.size = Vector2(0.4, 0.4)
		var m := StandardMaterial3D.new()
		m.albedo_texture = Silhouettes.texture(kinds[i])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.0)
		var mi := MeshInstance3D.new()
		mi.name = "Animal%d" % i
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(0, 0.42 - 0.42 * i, 0.012)
		scroll_overlay.add_child(mi)
	MeshKit.box(holder, Vector3(0.6, 0.03, 0.03), Vector3(0, 0.76, 0.01), wood, "TopRod")
	MeshKit.box(holder, Vector3(0.62, 0.04, 0.04), Vector3(0, -0.76, 0.012), wood, "BottomRod")
	var sa := MeshKit.interact_area(holder, "ScrollArea", "scroll")
	MeshKit.shape_box(sa, Vector3(0.62, 1.52, 0.1), Vector3(0, 0, 0.05))
	# 家宝：黒い漆の箱。前に 3 つの差し込み口（栞を順に差す）
	heirloom = Node3D.new()
	heirloom.name = "Heirloom"
	heirloom.position = Vector3(0.55, 0.12, -HZ + 0.25)
	add_child(heirloom)
	var lacquer := MeshKit.mat("heirloom_lacquer", Color(0.06, 0.04, 0.04), 0.2, 0.3)
	var gold := MeshKit.mat("heirloom_gold", Color(0.85, 0.68, 0.25), 0.3, 0.85)
	MeshKit.box(heirloom, Vector3(0.36, 0.2, 0.24), Vector3(0, 0.1, 0), lacquer, "Box")
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.2, -0.12)
	heirloom.add_child(lid)
	MeshKit.box(lid, Vector3(0.38, 0.03, 0.26), Vector3(0, 0.015, 0.13), lacquer, "LidPlate")
	MeshKit.box(lid, Vector3(0.04, 0.02, 0.03), Vector3(0, 0.03, 0.26), gold, "Knob")
	for i in 3:
		var slot := MeshKit.box(heirloom, Vector3(0.05, 0.1, 0.012), Vector3(-0.1 + 0.1 * i, 0.1, 0.122), gold, "Slot%d" % i)
		var inner := MeshKit.box(heirloom, Vector3(0.035, 0.085, 0.004), Vector3(-0.1 + 0.1 * i, 0.1, 0.129), MeshKit.mat("slot_dark", Color(0.02, 0.02, 0.02), 1.0), "SlotInner%d" % i)
		heirloom_slots.append(inner)
	var ha := MeshKit.interact_area(heirloom, "HeirloomArea", "heirloom")
	MeshKit.shape_box(ha, Vector3(0.42, 0.26, 0.3), Vector3(0, 0.13, 0.03))
	# 箱の中の写真（開けたあとに出る）
	photo_prop = Node3D.new()
	photo_prop.name = "Photo"
	photo_prop.position = Vector3(0, 0.215, 0.0)
	photo_prop.rotation.x = -PI * 0.5
	photo_prop.visible = false
	heirloom.add_child(photo_prop)
	photo_prop.add_child(Stage4Items.photo_model())
	var pa := MeshKit.interact_area(photo_prop, "PhotoArea", "heirloom_photo")
	pa.collision_layer = 0
	MeshKit.shape_box(pa, Vector3(0.18, 0.14, 0.1), Vector3.ZERO)
	# おばあちゃんの写真（額）
	var frame := Node3D.new()
	frame.name = "GrandmaPhoto"
	frame.position = Vector3(-1.3, 0.12 + 0.2, -HZ + 0.25)
	add_child(frame)
	MeshKit.box(frame, Vector3(0.24, 0.3, 0.02), Vector3.ZERO, wood, "Frame")
	MeshKit.box(frame, Vector3(0.2, 0.26, 0.004), Vector3(0, 0, 0.011), MeshKit.mat("grandma_bg", Color(0.62, 0.52, 0.38), 0.8), "Photo")
	MeshKit.sphere(frame, 0.035, Vector3(0, 0.03, 0.016), MeshKit.mat("grandma_face", Color(0.85, 0.7, 0.55), 0.8)).scale = Vector3(1, 1.15, 0.2)
	MeshKit.sphere(frame, 0.045, Vector3(0, -0.05, 0.016), MeshKit.mat("grandma_cloth", Color(0.35, 0.3, 0.4), 0.9)).scale = Vector3(1.2, 1, 0.2)
	MeshKit.sphere(frame, 0.02, Vector3(0, 0.075, 0.016), MeshKit.mat("grandma_hair", Color(0.85, 0.85, 0.85), 0.9)).scale = Vector3(1, 0.9, 0.2)
	var ga := MeshKit.interact_area(frame, "GrandmaArea", "grandma_photo")
	MeshKit.shape_box(ga, Vector3(0.26, 0.32, 0.06), Vector3(0, 0, 0.03))


func _build_shrine_and_ranma() -> void:
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	var white := MeshKit.mat("kamidana_white", Color(0.85, 0.8, 0.68), 0.8)
	# 神棚（東の壁の高い所）：棚板に、小さな社
	var shelf := Node3D.new()
	shelf.name = "Kamidana"
	shelf.position = Vector3(HX - 0.16, 1.85, 0.2)
	add_child(shelf)
	MeshKit.box(shelf, Vector3(0.3, 0.03, 0.7), Vector3(0, 0, 0), wood, "Board")
	MeshKit.box(shelf, Vector3(0.18, 0.16, 0.24), Vector3(0, 0.095, 0), white, "Shrine")
	var roof := MeshKit.box(shelf, Vector3(0.24, 0.025, 0.32), Vector3(0, 0.19, 0), wood, "Roof")
	roof.rotation.z = 0.0
	MeshKit.box(shelf, Vector3(0.12, 0.1, 0.01), Vector3(-0.092, 0.095, 0), MeshKit.mat("kamidana_door", Color(0.3, 0.2, 0.14), 0.8), "Door")
	var ka := MeshKit.interact_area(shelf, "KamidanaArea", "kamidana")
	MeshKit.shape_box(ka, Vector3(0.34, 0.3, 0.74), Vector3(0, 0.1, 0))
	# 欄間（南の壁の高い所の彫刻）：格子と、波の透かし
	var ranma := Node3D.new()
	ranma.name = "Ranma"
	ranma.position = Vector3(0.2, 2.1, HZ - 0.03)
	add_child(ranma)
	MeshKit.box(ranma, Vector3(1.6, 0.2, 0.03), Vector3.ZERO, wood, "Panel")
	for i in 9:
		MeshKit.box(ranma, Vector3(0.025, 0.16, 0.034), Vector3(-0.7 + i * 0.175, 0, 0.002), MeshKit.mat("ranma_bar", Color(0.45, 0.33, 0.2), 0.7), "Bar")
	var ra := MeshKit.interact_area(ranma, "RanmaArea", "ranma")
	MeshKit.shape_box(ra, Vector3(1.6, 0.24, 0.1), Vector3(0, 0, -0.04))


## 低い長方形のテーブルと、その上の下南澤の 3D マップ（ミニチュア）。ざぶとん 2 枚。
func _build_table() -> void:
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	var table := Node3D.new()
	table.name = "Table"
	table.position = Vector3(0.3, 0.0, 0.25)
	add_child(table)
	var body := StaticBody3D.new()
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	table.add_child(body)
	MeshKit.box(table, Vector3(1.3, 0.04, 0.7), Vector3(0, 0.34, 0), wood, "Top")
	for sx in [-0.58, 0.58]:
		for sz in [-0.28, 0.28]:
			MeshKit.box(table, Vector3(0.06, 0.32, 0.06), Vector3(sx, 0.16, sz), wood, "Leg")
	MeshKit.shape_box(body, Vector3(1.3, 0.38, 0.7), Vector3(0, 0.19, 0))
	# 3D マップ：地面の板に、コーポヨシミ・タウンホール・KO 線の高架・茶沢通り・木
	var map := Node3D.new()
	map.name = "TownMap"
	map.position = Vector3(0, 0.36, 0)
	table.add_child(map)
	MeshKit.box(map, Vector3(1.1, 0.02, 0.56), Vector3(0, 0.01, 0), MeshKit.mat("map_ground", Color(0.42, 0.48, 0.34), 0.95), "Ground")
	var road := MeshKit.box(map, Vector3(0.85, 0.004, 0.07), Vector3(0.25, 0.022, 0.0), MeshKit.mat("map_road", Color(0.3, 0.3, 0.33), 0.9), "Road")   # 茶沢通り
	road.rotation.y = deg_to_rad(-20.0)
	MeshKit.box(map, Vector3(1.0, 0.01, 0.04), Vector3(0, 0.07, 0.22), MeshKit.mat("map_deck", Color(0.6, 0.57, 0.52), 0.8), "KoDeck")   # KO 線の高架
	for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		MeshKit.box(map, Vector3(0.015, 0.06, 0.015), Vector3(x, 0.04, 0.22), MeshKit.mat("map_deck", Color(0.6, 0.57, 0.52), 0.8), "KoPillar")
	MeshKit.box(map, Vector3(0.1, 0.01, 0.012), Vector3(-0.1, 0.082, 0.22), MeshKit.mat("map_train", Color(0.8, 0.3, 0.2), 0.6), "Train")
	MeshKit.box(map, Vector3(0.1, 0.17, 0.07), Vector3(-0.15, 0.105, -0.12), MeshKit.mat("map_yoshimi", Color(0.82, 0.76, 0.64), 0.8), "CorpoYoshimi")   # コーポヨシミ
	MeshKit.box(map, Vector3(0.12, 0.1, 0.09), Vector3(0.38, 0.07, -0.14), MeshKit.mat("map_hall", Color(0.78, 0.74, 0.68), 0.8), "TownHall")   # タウンホール
	MeshKit.box(map, Vector3(0.09, 0.14, 0.07), Vector3(-0.42, 0.09, -0.1), MeshKit.mat("map_neighbor", Color(0.72, 0.78, 0.7), 0.8), "Neighbor")
	for p in [Vector2(-0.3, 0.05), Vector2(0.1, -0.2), Vector2(0.5, 0.08), Vector2(-0.5, 0.15)]:
		MeshKit.sphere(map, 0.03, Vector3(p.x, 0.05, p.y), MeshKit.mat("map_tree", Color(0.2, 0.42, 0.2), 0.9))
	var ta := MeshKit.interact_area(table, "TownMapArea", "town_map")
	MeshKit.shape_box(ta, Vector3(1.2, 0.26, 0.64), Vector3(0, 0.46, 0))
	# 座卓の端の日記（おばあちゃんの字）
	var dg := Node3D.new()
	dg.name = "DiaryGrandma"
	dg.position = Vector3(-0.45, 0.36, 0.1)
	dg.rotation.y = -0.3
	table.add_child(dg)
	MeshKit.box(dg, Vector3(0.16, 0.02, 0.22), Vector3(0, 0.01, 0), MeshKit.mat("diary_cover_g", Color(0.2, 0.3, 0.22), 0.8), "Diary")
	MeshKit.box(dg, Vector3(0.15, 0.016, 0.21), Vector3(0.004, 0.01, 0), MeshKit.mat("diary_pages", Color(0.93, 0.9, 0.8), 0.9), "Pages")
	var dga := MeshKit.interact_area(dg, "DiaryArea", "diary_grandma", null)
	MeshKit.shape_box(dga, Vector3(0.2, 0.08, 0.26), Vector3(0, 0.04, 0))
	# ざぶとん
	var zab := MeshKit.mat("washitsu_zabuton", Color(0.42, 0.2, 0.42), 0.95)
	for p in [Vector3(0.3, 0.025, 0.95), Vector3(-0.7, 0.025, 0.25)]:
		var z := MeshKit.box(self, Vector3(0.5, 0.05, 0.5), p, zab, "Zabuton")
		z.rotation.y = 0.1


func _build_extras() -> void:
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	# こたつの中へ戻る穴（西の壁の低い所）
	var hole := Node3D.new()
	hole.name = "ReturnHole"
	hole.position = Vector3(-HX + 0.01, 0.0, 0.25)
	add_child(hole)
	MeshKit.box(hole, Vector3(0.02, 0.5, 0.6), Vector3(0, 0.25, 0), MeshKit.mat("hole_dark", Color(0.01, 0.01, 0.01), 1.0), "Hole")
	var ha := MeshKit.interact_area(hole, "ReturnHoleArea", "washitsu_hole")
	MeshKit.shape_box(ha, Vector3(0.3, 0.6, 0.7), Vector3(0.1, 0.3, 0))
	# ねずみ穴（南の壁の根もと）
	var mouse := Node3D.new()
	mouse.name = "MouseHole"
	mouse.position = Vector3(-1.0, 0.0, HZ - 0.02)
	add_child(mouse)
	var mh := MeshKit.cylinder(mouse, 0.06, 0.02, Vector3(0, 0.06, 0), MeshKit.mat("hole_dark", Color(0.01, 0.01, 0.01), 1.0), "Hole", -1.0, 14)
	mh.rotation.x = deg_to_rad(90.0)
	var ma := MeshKit.interact_area(mouse, "MouseHoleArea", "mouse_hole")
	MeshKit.shape_box(ma, Vector3(0.2, 0.2, 0.15), Vector3(0, 0.08, -0.05))
	# はしご（北の壁に立てかけてある）
	ladder_prop = Node3D.new()
	ladder_prop.name = "Ladder"
	ladder_prop.position = Vector3(1.45, 0.0, -HZ + 0.12)
	ladder_prop.rotation.x = deg_to_rad(-8.0)
	add_child(ladder_prop)
	ladder_prop.add_child(Stage4Items.ladder_model())
	var la := MeshKit.interact_area(ladder_prop, "LadderArea", "ladder_prop")
	MeshKit.shape_box(la, Vector3(0.5, 2.3, 0.2), Vector3(0, 1.15, 0))
	# コイン（暗い隅の床。ライターで見える）
	coin_prop = Node3D.new()
	coin_prop.name = "Coin"
	coin_prop.position = Vector3(1.5, 0.012, 1.05)
	add_child(coin_prop)
	var FishingScript := preload("res://scripts/fishing.gd")
	var cm := FishingScript.coin_model()
	cm.rotation.x = deg_to_rad(90.0)
	cm.scale = Vector3(0.6, 0.6, 0.6)
	coin_prop.add_child(cm)
	var ca := MeshKit.interact_area(coin_prop, "CoinArea", "washitsu_coin")
	MeshKit.shape_box(ca, Vector3(0.14, 0.08, 0.14), Vector3.ZERO)


## 掛け軸：目の高さが SCROLL_EYE にぴったりのときだけ、影絵が揃って見える（0〜1）。
func set_scroll_alignment(a: float) -> void:
	for i in 3:
		var mi := scroll_overlay.get_node("Animal%d" % i) as MeshInstance3D
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(a, 0.0, 1.0))


## 家宝の差し込み口を 1 つ光らせる。
func light_slot(i: int) -> void:
	if i >= 0 and i < heirloom_slots.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.4)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.3)
		m.emission_energy_multiplier = 1.4
		(heirloom_slots[i] as MeshInstance3D).material_override = m


## 家宝の蓋が開いて、写真が見える。
func open_heirloom(instant := false) -> void:
	if heirloom_open:
		return
	heirloom_open = true
	var lid := heirloom.get_node("Lid") as Node3D
	if instant:
		lid.rotation.x = deg_to_rad(-100.0)
	else:
		create_tween().tween_property(lid, "rotation:x", deg_to_rad(-100.0), 0.8).set_trans(Tween.TRANS_SINE)
	if not photo_taken:
		photo_prop.visible = true
		(photo_prop.get_node("PhotoArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT


func take_photo() -> void:
	photo_taken = true
	photo_prop.visible = false
	(photo_prop.get_node("PhotoArea") as Area3D).collision_layer = 0


func take_ladder() -> void:
	ladder_taken = true
	ladder_prop.visible = false
	(ladder_prop.get_node("LadderArea") as Area3D).collision_layer = 0


func take_coin() -> void:
	coin_taken = true
	coin_prop.visible = false
	(coin_prop.get_node("CoinArea") as Area3D).collision_layer = 0
