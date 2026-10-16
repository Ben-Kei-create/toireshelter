extends Node3D
## 隣の和室（おばあちゃんの家）。こたつの中の壁をツルハシで壊すと行ける。暗くて質素。原点は部屋の中心の床（x ±1.8、z ±1.35、天井 2.3）。
##   北の壁の床の間：掛け軸（目の高さがぴったり 142 cm のとき、バラバラの墨が犬→猿→キジの影絵に揃う）と、家宝（栞を 3 枚、順に差す）、おばあちゃんの写真
##   東の壁の高い所：神棚。南の壁の高い所：欄間（彫刻）。足元：ざぶとんと、低いテーブル（下南澤の 3D マップ）。はしご（拾える）。
##   西の壁の低い所：こたつの中へ戻る穴。南の壁の根もとに、ねずみ穴。暗い隅（東南）に、コインが 1 枚（ライターで見える）。
## 照明は置かない（真っ暗。main.gd が環境光を落とす）。ライターか松明の明かりで見て回る。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Silhouettes := preload("res://scripts/silhouettes.gd")
const Stage4Items := preload("res://scripts/stage4_items.gd")
const Sfx := preload("res://scripts/sfx.gd")

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
	_build_butsudan()
	_build_lanterns()
	_build_attic()
	_build_night_details()
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
	# 天井：北側に、横に長いすき間（のぞき穴）をあけてある。見上げると、屋根裏の部屋の列が見える
	var cw := HX * 2.0 + 0.2
	var slot_z0 := -1.15
	var slot_z1 := -0.65
	var slot_x := 1.5
	MeshKit.box(self, Vector3(cw, 0.1, (HZ + 0.1) - slot_z1), Vector3(0, H + 0.05, (slot_z1 + HZ + 0.1) * 0.5), wood, "CeilingSouth")
	MeshKit.box(self, Vector3(cw, 0.1, slot_z0 - (-HZ - 0.1)), Vector3(0, H + 0.05, (slot_z0 - HZ - 0.1) * 0.5), wood, "CeilingNorth")
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(cw * 0.5 - slot_x, 0.1, slot_z1 - slot_z0), Vector3(sx * (slot_x + (cw * 0.5 - slot_x) * 0.5), H + 0.05, (slot_z0 + slot_z1) * 0.5), wood, "CeilingSide")
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


## ねずみ穴は、目の高さが低い（130〜140 cm）ときだけ見える・調べられる。
const MOUSE_EYE_MAX := 1.4


func set_mouse_hole_visible(on: bool) -> void:
	var m := get_node_or_null("MouseHole") as Node3D
	if m == null or m.visible == on:
		return
	m.visible = on
	(m.get_node("MouseHoleArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT if on else 0


## 掛け軸：目の高さが SCROLL_EYE にぴったりのときだけ、影絵が揃って見える（0〜1）。
func set_scroll_alignment(a: float) -> void:
	for i in 3:
		var mi := scroll_overlay.get_node("Animal%d" % i) as MeshInstance3D
		(mi.material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, clampf(a, 0.0, 1.0))


## 家宝の差し込み口を 1 つ光らせる。
# ---------------------------------------------------------------- 仏壇と、まわる提灯

var butsudan: Node3D
var _candle_lights: Array = []
var _candle_flames: Array = []
var _lanterns: Array = []        # {node, mat, light}
var _lantern_t := 0.0
var festive := false             # 家宝が開いてから、提灯とろうそくが灯る
const LANTERN_N := 22
const LANTERN_Y := 2.05
const LANTERN_INSET := 0.22


## 東の壁の低い所の仏壇：黒漆の戸棚に金の宮殿、位牌が二つ、ろうそく、線香、おりん。
func _build_butsudan() -> void:
	butsudan = Node3D.new()
	butsudan.name = "Butsudan"
	butsudan.position = Vector3(HX - 0.26, 0.0, -0.45)
	butsudan.rotation.y = -PI * 0.5   # ローカル +z（正面）を -x（部屋の中）へ
	add_child(butsudan)
	var lacquer := MeshKit.mat("butsudan_lacquer", Color(0.06, 0.04, 0.04), 0.25, 0.1)
	var gold := MeshKit.mat("butsudan_gold", Color(0.85, 0.68, 0.25), 0.3, 0.8)
	var wood := MeshKit.mat("butsudan_wood", Color(0.2, 0.1, 0.07), 0.5)
	MeshKit.box(butsudan, Vector3(0.9, 0.62, 0.5), Vector3(0, 0.31, 0), lacquer, "Cabinet")
	for sx in [-0.21, 0.21]:   # 下の戸棚の引き戸の取っ手と金の縁
		MeshKit.box(butsudan, Vector3(0.36, 0.5, 0.012), Vector3(sx, 0.31, 0.256), wood, "Door")
		MeshKit.box(butsudan, Vector3(0.02, 0.08, 0.016), Vector3(sx + (-0.14 if sx > 0 else 0.14), 0.31, 0.262), gold, "Handle")
	MeshKit.box(butsudan, Vector3(0.96, 0.04, 0.54), Vector3(0, 0.64, 0), lacquer, "Top")
	# 宮殿（上段）：背板は金、天井に屋根
	MeshKit.box(butsudan, Vector3(0.72, 0.86, 0.04), Vector3(0, 1.1, -0.2), gold, "Back")
	for sx in [-0.37, 0.37]:
		MeshKit.box(butsudan, Vector3(0.04, 0.86, 0.4), Vector3(sx, 1.1, 0.0), lacquer, "Side")
	MeshKit.box(butsudan, Vector3(0.84, 0.05, 0.46), Vector3(0, 1.55, 0.0), lacquer, "Roof")
	MeshKit.box(butsudan, Vector3(0.9, 0.03, 0.5), Vector3(0, 1.595, 0.02), gold, "RoofTrim")
	MeshKit.box(butsudan, Vector3(0.7, 0.025, 0.4), Vector3(0, 0.77, 0.0), wood, "Shelf")
	# 位牌 2 つ
	for sx in [-0.14, 0.14]:
		MeshKit.box(butsudan, Vector3(0.08, 0.2, 0.025), Vector3(sx, 0.89, 0.0), gold, "Ihai")
		MeshKit.box(butsudan, Vector3(0.1, 0.03, 0.05), Vector3(sx, 0.78, 0.0), lacquer, "IhaiBase")
	MeshKit.box(butsudan, Vector3(0.025, 0.04, 0.002), Vector3(-0.14, 0.9, 0.0135), MeshKit.mat("ihai_name", Color(0.05, 0.04, 0.03), 0.9), "Name")
	# 手前の台：ろうそく立て 2 つ、線香立て、おりん
	for sx in [-0.28, 0.28]:
		MeshKit.cylinder(butsudan, 0.022, 0.1, Vector3(sx, 0.7, 0.14), gold, "CandleStand", 0.012, 12)
		MeshKit.cylinder(butsudan, 0.014, 0.08, Vector3(sx, 0.79, 0.14), MeshKit.mat("candle_wax", Color(0.95, 0.9, 0.78), 0.8), "Candle", -1.0, 10)
		var flame := MeshKit.sphere(butsudan, 0.011, Vector3(sx, 0.848, 0.14), MeshKit.mat("candle_flame", Color(1.0, 0.8, 0.4), 0.5))
		flame.scale = Vector3(0.7, 1.5, 0.7)
		var fm := flame.material_override as StandardMaterial3D
		fm.emission_enabled = true
		fm.emission = Color(1.0, 0.65, 0.25)
		fm.emission_energy_multiplier = 0.0
		_candle_flames.append(flame)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(sx, 0.9, 0.2)
		lamp.light_color = Color(1.0, 0.68, 0.32)
		lamp.light_energy = 0.0
		lamp.omni_range = 1.6
		butsudan.add_child(lamp)
		_candle_lights.append(lamp)
	MeshKit.cylinder(butsudan, 0.04, 0.035, Vector3(0, 0.675, 0.16), MeshKit.mat("incense_bowl", Color(0.3, 0.28, 0.25), 0.6, 0.4), "IncenseBowl", 0.05, 16)
	for k in 3:
		MeshKit.cylinder(butsudan, 0.002, 0.1, Vector3(-0.012 + k * 0.012, 0.74, 0.16), MeshKit.mat("incense_stick", Color(0.35, 0.2, 0.12), 0.9), "Incense", -1.0, 6).rotation.z = deg_to_rad(-6.0 + k * 6.0)
	MeshKit.cylinder(butsudan, 0.045, 0.035, Vector3(0.12, 0.66, 0.15), gold, "Rin", 0.06, 20)
	var a := MeshKit.interact_area(butsudan, "ButsudanArea", "butsudan", null)
	MeshKit.shape_box(a, Vector3(1.0, 1.7, 0.6), Vector3(0, 0.85, 0.05))


## 部屋のぐるりの天井ぎわに、提灯が横一列に並んで、ゆっくり回る（走馬灯のように）。
func _build_lanterns() -> void:
	var cord := MeshKit.mat("lantern_cord", Color(0.2, 0.15, 0.1), 0.9)
	var x0 := HX - LANTERN_INSET
	var z0 := HZ - LANTERN_INSET
	for pair in [[Vector3(0, LANTERN_Y + 0.2, -z0), Vector3(x0 * 2.0, 0.01, 0.01)], [Vector3(0, LANTERN_Y + 0.2, z0), Vector3(x0 * 2.0, 0.01, 0.01)],
			[Vector3(-x0, LANTERN_Y + 0.2, 0), Vector3(0.01, 0.01, z0 * 2.0)], [Vector3(x0, LANTERN_Y + 0.2, 0), Vector3(0.01, 0.01, z0 * 2.0)]]:
		MeshKit.box(self, pair[1], pair[0], cord, "LanternRail")
	for i in LANTERN_N:
		var n := Node3D.new()
		n.name = "Lantern%d" % i
		add_child(n)
		var red: bool = i % 2 == 0
		var m := MeshKit.mat("lantern_%d" % (i % 2), Color(0.8, 0.15, 0.1) if red else Color(0.95, 0.9, 0.78), 0.8)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.45, 0.2) if red else Color(1.0, 0.8, 0.5)
		m.emission_energy_multiplier = 0.0
		var body := MeshKit.sphere(n, 0.09, Vector3(0, 0.0, 0), m)
		body.scale = Vector3(1.0, 1.2, 1.0)
		MeshKit.cylinder(n, 0.05, 0.015, Vector3(0, 0.13, 0), MeshKit.mat("lantern_cap", Color(0.08, 0.07, 0.06), 0.7), "Cap", -1.0, 10)
		MeshKit.cylinder(n, 0.05, 0.015, Vector3(0, -0.13, 0), MeshKit.mat("lantern_cap", Color(0.08, 0.07, 0.06), 0.7), "Bottom", -1.0, 10)
		MeshKit.cylinder(n, 0.003, 0.2, Vector3(0, 0.23, 0), cord, "String", -1.0, 4)
		var light: OmniLight3D = null
		if i % 4 == 0:
			light = OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.3)
			light.light_energy = 0.0
			light.omni_range = 1.8
			n.add_child(light)
		_lanterns.append({"node": n, "mat": m, "light": light})
	_place_lanterns()


## 夜の和室：まんなかの大きな紙の提灯、行灯（床の灯り）、月あかりのさす障子の窓。家宝が開くと灯る。
var _big_lantern_mat: StandardMaterial3D
var _andon_mat: StandardMaterial3D
var _night_lights: Array = []


func _build_night_details() -> void:
	var wood := MeshKit.mat("washitsu_wood", Color(0.28, 0.2, 0.14), 0.7)
	# まんなかの大きな提灯（天井から吊る）
	_big_lantern_mat = MeshKit.mat("big_lantern_paper", Color(0.95, 0.82, 0.55), 0.8)
	_big_lantern_mat.emission_enabled = true
	_big_lantern_mat.emission = Color(1.0, 0.7, 0.35)
	_big_lantern_mat.emission_energy_multiplier = 0.0
	var bl := Node3D.new()
	bl.name = "BigLantern"
	bl.position = Vector3(0.0, H - 0.5, 0.2)
	add_child(bl)
	MeshKit.cylinder(bl, 0.003, 0.3, Vector3(0, 0.4, 0), wood, "Cord", -1.0, 4)
	var body := MeshKit.sphere(bl, 0.2, Vector3.ZERO, _big_lantern_mat)
	body.scale = Vector3(1.0, 0.8, 1.0)
	for k in 6:   # 骨の輪
		MeshKit.cylinder(bl, 0.2 * (1.0 - 0.08 * absf(float(k) - 2.5)), 0.006, Vector3(0, (float(k) - 2.5) * 0.055, 0), wood, "Rib", -1.0, 20)
	MeshKit.cylinder(bl, 0.08, 0.025, Vector3(0, 0.17, 0), wood, "CapTop", -1.0, 16)
	MeshKit.cylinder(bl, 0.08, 0.025, Vector3(0, -0.17, 0), wood, "CapBottom", -1.0, 16)
	var ll := OmniLight3D.new()
	ll.position = Vector3(0, -0.05, 0)
	ll.light_color = Color(1.0, 0.72, 0.4)
	ll.light_energy = 0.0
	ll.omni_range = 3.2
	bl.add_child(ll)
	_night_lights.append(ll)
	# 行灯（床の灯り。四角い和紙の箱）：仏壇のそば
	_andon_mat = MeshKit.mat("andon_paper", Color(0.95, 0.85, 0.6), 0.8)
	_andon_mat.emission_enabled = true
	_andon_mat.emission = Color(1.0, 0.72, 0.32)
	_andon_mat.emission_energy_multiplier = 0.0
	var an := Node3D.new()
	an.name = "Andon"
	an.position = Vector3(HX - 0.35, 0.0, 0.55)
	add_child(an)
	MeshKit.box(an, Vector3(0.22, 0.34, 0.22), Vector3(0, 0.34, 0), _andon_mat, "Paper")
	for sx in [-0.11, 0.11]:
		for sz in [-0.11, 0.11]:
			MeshKit.box(an, Vector3(0.018, 0.5, 0.018), Vector3(sx, 0.25, sz), wood, "Leg")
	MeshKit.box(an, Vector3(0.26, 0.02, 0.26), Vector3(0, 0.52, 0), wood, "Top")
	var al := OmniLight3D.new()
	al.position = Vector3(0, 0.36, 0)
	al.light_color = Color(1.0, 0.7, 0.35)
	al.light_energy = 0.0
	al.omni_range = 2.2
	an.add_child(al)
	_night_lights.append(al)
	# 月あかりの障子の窓（南の壁、左寄り）：青い夜の光がもれる
	var sj := Node3D.new()
	sj.name = "ShojiWindow"
	sj.position = Vector3(-1.1, 1.25, HZ - 0.03)
	add_child(sj)
	var moon := MeshKit.mat("shoji_moon", Color(0.5, 0.6, 0.95), 0.9)
	moon.emission_enabled = true
	moon.emission = Color(0.3, 0.45, 0.9)
	moon.emission_energy_multiplier = 0.6
	MeshKit.box(sj, Vector3(0.7, 0.9, 0.01), Vector3(0, 0, 0), moon, "Paper")
	for k in 4:
		MeshKit.box(sj, Vector3(0.012, 0.9, 0.014), Vector3(-0.26 + k * 0.173, 0, -0.004), wood, "Bar")
	for k in 5:
		MeshKit.box(sj, Vector3(0.7, 0.012, 0.014), Vector3(0, -0.36 + k * 0.18, -0.004), wood, "Rail")
	MeshKit.box(sj, Vector3(0.74, 0.04, 0.02), Vector3(0, 0.47, -0.006), wood, "FrameTop")
	MeshKit.box(sj, Vector3(0.74, 0.04, 0.02), Vector3(0, -0.47, -0.006), wood, "FrameBottom")


## 天井のすき間の上：屋根裏に、小さな部屋が横一列にならび、小さな提灯の列が、そのあいだをゆっくり回っていく。
var _attic_lanterns: Array = []
var _attic_t := 0.0
var _attic_mats: Array = []
const ATTIC_Y := 2.45


func _build_attic() -> void:
	var attic := Node3D.new()
	attic.name = "Attic"
	add_child(attic)
	var beam := MeshKit.mat("attic_beam", Color(0.16, 0.1, 0.07), 0.8)
	var back_z := -1.52
	MeshKit.box(attic, Vector3(HX * 2.0, 1.05, 0.06), Vector3(0, ATTIC_Y + 0.5, back_z - 0.03), beam, "AtticBack")
	MeshKit.box(attic, Vector3(HX * 2.0, 0.05, 0.9), Vector3(0, ATTIC_Y + 1.05, -1.05), beam, "AtticRoof")
	MeshKit.box(attic, Vector3(HX * 2.0, 0.06, 0.36), Vector3(0, ATTIC_Y - 0.03, -1.34), beam, "AtticFloor")   # 部屋の列の足もとだけ（すき間はふさがない）
	var wall_cols := [Color(0.85, 0.78, 0.6), Color(0.6, 0.75, 0.6), Color(0.85, 0.6, 0.62), Color(0.62, 0.68, 0.85), Color(0.9, 0.82, 0.5), Color(0.5, 0.45, 0.55)]
	var n := 6
	var rw := 0.5
	for i in n:
		var cx := (float(i) - float(n - 1) * 0.5) * (rw + 0.05)
		var rm := Node3D.new()
		rm.name = "AtticRoom%d" % i
		rm.position = Vector3(cx, ATTIC_Y, back_z)
		attic.add_child(rm)
		var wc: Color = wall_cols[i]
		MeshKit.box(rm, Vector3(rw, 0.58, 0.02), Vector3(0, 0.3, 0.01), MeshKit.mat("attic_wall_%d" % i, wc, 0.9), "Wall")
		MeshKit.box(rm, Vector3(rw, 0.015, 0.34), Vector3(0, 0.01, 0.17), MeshKit.mat("attic_floor", Color(0.55, 0.45, 0.3), 0.9), "Floor")
		MeshKit.box(rm, Vector3(0.02, 0.58, 0.34), Vector3(-rw * 0.5, 0.3, 0.17), beam, "SideL")
		MeshKit.box(rm, Vector3(0.02, 0.58, 0.34), Vector3(rw * 0.5, 0.3, 0.17), beam, "SideR")
		MeshKit.box(rm, Vector3(rw, 0.02, 0.34), Vector3(0, 0.6, 0.17), beam, "Top")
		# 小さな家具：卓・ふとん・本棚・窓・人影など、部屋ごとにちがう
		match i % 3:
			0:
				MeshKit.box(rm, Vector3(0.18, 0.07, 0.12), Vector3(-0.08, 0.05, 0.18), MeshKit.mat("attic_table", Color(0.4, 0.26, 0.15), 0.8), "Table")
				MeshKit.box(rm, Vector3(0.05, 0.05, 0.05), Vector3(-0.08, 0.115, 0.18), MeshKit.mat("attic_cup", Color(0.9, 0.9, 0.85), 0.5), "Cup")
			1:
				MeshKit.box(rm, Vector3(0.3, 0.04, 0.2), Vector3(0.0, 0.035, 0.18), MeshKit.mat("attic_futon", Color(0.85, 0.7, 0.7), 0.9), "Futon")
				MeshKit.box(rm, Vector3(0.08, 0.03, 0.06), Vector3(-0.1, 0.07, 0.18), MeshKit.mat("attic_pillow", Color(0.95, 0.95, 0.9), 0.9), "Pillow")
			_:
				MeshKit.box(rm, Vector3(0.14, 0.3, 0.06), Vector3(0.12, 0.17, 0.05), MeshKit.mat("attic_shelf", Color(0.35, 0.22, 0.12), 0.8), "Shelf")
				MeshKit.box(rm, Vector3(0.1, 0.1, 0.01), Vector3(-0.1, 0.35, 0.022), MeshKit.mat("attic_window", Color(0.4, 0.55, 0.75), 0.5), "Window")
		if i == 4:   # 一つだけ、小さな人影が、こちらを向いている
			MeshKit.box(rm, Vector3(0.05, 0.14, 0.02), Vector3(0.0, 0.09, 0.28), MeshKit.mat("attic_figure", Color(0.03, 0.03, 0.04), 1.0), "Figure")
			MeshKit.sphere(rm, 0.028, Vector3(0.0, 0.2, 0.28), MeshKit.mat("attic_figure", Color(0.03, 0.03, 0.04), 1.0))
		# 部屋の灯り（部屋ごとの小さな光る板）
		var glow := MeshKit.mat("attic_glow_%d" % i, Color(1.0, 0.85, 0.55), 0.5)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.75, 0.4)
		glow.emission_energy_multiplier = 0.0
		MeshKit.box(rm, Vector3(0.1, 0.012, 0.1), Vector3(0.0, 0.585, 0.17), glow, "Lamp")
		_attic_mats.append(glow)
	# 提灯の列：部屋の前をゆっくり横へ進み、端でぐるりと奥へ回って戻る（輪になって回る）
	for k in 9:
		var ln := Node3D.new()
		ln.name = "AtticLantern%d" % k
		attic.add_child(ln)
		var red: bool = k % 2 == 0
		var m := MeshKit.mat("lantern_%d" % (k % 2), Color(0.8, 0.15, 0.1) if red else Color(0.95, 0.9, 0.78), 0.8)
		var body := MeshKit.sphere(ln, 0.05, Vector3.ZERO, m)
		body.scale = Vector3(1.0, 1.2, 1.0)
		_attic_lanterns.append(ln)
	_place_attic_lanterns()


func _place_attic_lanterns() -> void:
	var span := 3.0     # 列の長さ
	var loop := span * 2.0 + 0.8
	for i in _attic_lanterns.size():
		var d := fposmod(_attic_t + loop * float(i) / float(_attic_lanterns.size()), loop)
		var pos: Vector3
		if d < span:
			pos = Vector3(-span * 0.5 + d, ATTIC_Y + 0.48, -1.12)          # 手前の列（右へ）
		elif d < span + 0.4:
			pos = Vector3(span * 0.5, ATTIC_Y + 0.48, lerpf(-1.12, -1.4, (d - span) / 0.4))
		elif d < span * 2.0 + 0.4:
			pos = Vector3(span * 0.5 - (d - span - 0.4), ATTIC_Y + 0.48, -1.4)   # 奥の列（左へ）
		else:
			pos = Vector3(-span * 0.5, ATTIC_Y + 0.48, lerpf(-1.4, -1.12, (d - span * 2.0 - 0.4) / 0.4))
		(_attic_lanterns[i] as Node3D).position = pos


func _perimeter_point(d: float) -> Vector3:
	var x0 := HX - LANTERN_INSET
	var z0 := HZ - LANTERN_INSET
	var per := 4.0 * (x0 + z0)
	d = fposmod(d, per)
	var w := 2.0 * x0
	var h := 2.0 * z0
	if d < w:
		return Vector3(-x0 + d, LANTERN_Y, -z0)
	d -= w
	if d < h:
		return Vector3(x0, LANTERN_Y, -z0 + d)
	d -= h
	if d < w:
		return Vector3(x0 - d, LANTERN_Y, z0)
	d -= w
	return Vector3(-x0, LANTERN_Y, z0 - d)


func _place_lanterns() -> void:
	var per := 4.0 * ((HX - LANTERN_INSET) + (HZ - LANTERN_INSET))
	for i in _lanterns.size():
		var n: Node3D = _lanterns[i].node
		n.position = _perimeter_point(_lantern_t + per * float(i) / float(_lanterns.size()))
		n.rotation.z = 0.04 * sin(_lantern_t * 2.0 + i)


func _process(delta: float) -> void:
	if _lanterns.is_empty():
		return
	_lantern_t += delta * (0.22 if festive else 0.05)
	_place_lanterns()
	_attic_t += delta * (0.18 if festive else 0.03)
	_place_attic_lanterns()
	if festive:
		var fl := 1.0 + 0.08 * sin(_lantern_t * 40.0) + 0.05 * sin(_lantern_t * 23.0)
		for l in _candle_lights:
			(l as OmniLight3D).light_energy = 0.35 * fl


## 提灯とろうそくに灯りをともす（家宝が開いたあと）。
func set_festive(on: bool) -> void:
	festive = on
	for l in _lanterns:
		(l.mat as StandardMaterial3D).emission_energy_multiplier = 1.6 if on else 0.0
		if l.light:
			(l.light as OmniLight3D).light_energy = 0.28 if on else 0.0
	if _big_lantern_mat:
		_big_lantern_mat.emission_energy_multiplier = 1.8 if on else 0.0
		_andon_mat.emission_energy_multiplier = 1.8 if on else 0.0
		for nl in _night_lights:
			(nl as OmniLight3D).light_energy = 0.55 if on else 0.0
	for am in _attic_mats:
		(am as StandardMaterial3D).emission_energy_multiplier = 2.0 if on else 0.0
	for f in _candle_flames:
		((f as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if on else 0.0
	if not on:
		for lt in _candle_lights:
			(lt as OmniLight3D).light_energy = 0.0
	if on:
		Sfx.play("chime", 0.6, -8.0)


func light_slot(i: int) -> void:
	if i >= 0 and i < heirloom_slots.size():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.4)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.3)
		m.emission_energy_multiplier = 1.4
		(heirloom_slots[i] as MeshInstance3D).material_override = m


## 家宝の蓋が開いて、写真が見える。提灯とろうそくに灯りがともる。
func open_heirloom(instant := false) -> void:
	if heirloom_open:
		return
	heirloom_open = true
	set_festive(true)
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
