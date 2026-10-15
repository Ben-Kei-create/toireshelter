extends Node3D
## こたつ（自室の真ん中）。座れて、座ってから中に入れる。座卓の天板・こたつ布団・ヒーター・みかんの鉢・座布団2枚。
## 原点はこたつの中心の床。座標は部屋と同じ（apartment.gd が CENTER に置く）。
##
##   座る  … 立ったままこたつや座布団を狙って E（「こたつに座る」）。近いほうの座布団に座る（SEATS）
##   入る  … 座った状態で、こたつを狙って左クリック（「こたつに入る」）。布団の中（暗く、ヒーターの赤い光）に入って見回せる
##   出る  … 中から E で座った姿勢へ。座った姿勢から E で立つ
## 座布団は北（窓側）・西（左の壁のカセットの台側）・東（宝石の台座の側。クレーンゲームを押入れに移したので空いた）の3か所。南（寝床）は体が入らないので置かない。
## 座っている間は体の当たり判定を切る（player.gd の固定姿勢）。中に入ると小さな体（高さ0.4m）で這って動け、布団の外へ出ると立つ（main.gd）。
## 中にいる間は本体の当たり判定を切る（set_solid）。こたつ布団の内側が見えるよう、布団は両面描く。
## 判定：こたつ本体（体を止める箱、調べる対象 kotatsu）と、座布団の調べる判定（kotatsu）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const TEX_FABRIC := preload("res://assets/textures/surfaces/surface_12.png")

const CENTER := Vector3(2.6, 0.0, 0.78)
const TOP := 0.40            # 天板の上面
const BLANKET := 1.1         # こたつ布団の一辺
const EYE_SEATED := 0.85     # 座布団に座ったときの目の高さ
const EYE_INSIDE := 0.27     # 布団の中の目の高さ
const OUT_DISTANCE := 0.58   # 中心からこれより遠く（x か z）へ出ると、布団（半幅 0.55）の外へ抜けたことにする。南は寝床（z 1.58）が近いので、体の半径 0.2 を足して届く距離にしてある。東は宝石の台座で行き止まり
## 座る場所：[座布団の中心（床）, 向き（rotation.y）, 立つ位置の候補, 布団の中の足元]
const SEATS := [
	{"name": "north", "feet": Vector3(2.6, 0.0, 0.05), "yaw": PI, "exits": [Vector3(2.6, 0.0, -0.5), Vector3(2.9, 0.0, -0.45), Vector3(2.3, 0.0, -0.5)], "inside": Vector3(2.6, 0.0, 0.55)},
	{"name": "west", "feet": Vector3(1.8, 0.0, 0.78), "yaw": -PI * 0.5, "exits": [Vector3(1.8, 0.0, 0.78), Vector3(1.8, 0.0, 0.55), Vector3(1.8, 0.0, 1.0)], "inside": Vector3(2.25, 0.0, 0.78)},
	{"name": "east", "feet": Vector3(3.4, 0.0, 0.62), "yaw": PI * 0.5, "exits": [Vector3(3.5, 0.0, 0.5), Vector3(3.45, 0.0, 0.3), Vector3(3.5, 0.0, 0.62)], "inside": Vector3(2.95, 0.0, 0.7)},
]


var body: StaticBody3D


## 本体の当たり判定を入れる／切る（中を這う間は切る）。
func set_solid(solid: bool) -> void:
	body.collision_layer = MeshKit.LAYER_WORLD if solid else 0


func _ready() -> void:
	position = CENTER
	MeshKit.auto_round = false
	var wood := MeshKit.tiled_mat("kotatsu_wood", MeshKit.faded_texture(load("res://assets/textures/surfaces/surface_09.png"), 0.7), 0.5, Color(0.9, 0.78, 0.62), 0.6)
	var half := BLANKET * 0.5
	# 天板（布団の上）と、見えない脚
	MeshKit.box(self, Vector3(0.75, 0.035, 0.75), Vector3(0, TOP - 0.0175, 0), wood, "Top")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.04, 0.34, 0.04), Vector3(sx * 0.32, 0.18, sz * 0.32), wood, "Leg")
	# こたつ布団：上の面と、四方に垂れる面。両面を描く（中に入ったとき内側が見える）
	var fab := StandardMaterial3D.new()
	fab.albedo_texture = TEX_FABRIC
	fab.albedo_color = Color(1.0, 0.82, 0.72)
	fab.uv1_triplanar = true
	fab.uv1_scale = Vector3.ONE / 0.4
	fab.roughness = 0.95
	fab.cull_mode = BaseMaterial3D.CULL_DISABLED
	fab.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	MeshKit.box(self, Vector3(BLANKET, 0.03, BLANKET), Vector3(0, TOP - 0.05, 0), fab, "BlanketTop")
	for side in [[Vector3(half, 0.19, 0), Vector3(0.025, 0.36, BLANKET)], [Vector3(-half, 0.19, 0), Vector3(0.025, 0.36, BLANKET)],
			[Vector3(0, 0.19, half), Vector3(BLANKET, 0.36, 0.025)], [Vector3(0, 0.19, -half), Vector3(BLANKET, 0.36, 0.025)]]:
		MeshKit.box(self, side[1], side[0], fab, "BlanketSide")
	# 内側：ヒーター（天板の裏）と、赤い光
	var heater_mat := StandardMaterial3D.new()
	heater_mat.albedo_color = Color(0.9, 0.25, 0.1)
	heater_mat.emission_enabled = true
	heater_mat.emission = Color(1.0, 0.3, 0.1)
	heater_mat.emission_energy_multiplier = 2.0
	MeshKit.box(self, Vector3(0.28, 0.03, 0.28), Vector3(0, TOP - 0.065, 0), heater_mat, "Heater")
	MeshKit.box(self, Vector3(0.36, 0.01, 0.36), Vector3(0, TOP - 0.045, 0), MeshKit.mat("kotatsu_frame", Color(0.2, 0.2, 0.2), 0.6), "HeaterFrame")
	var glow := OmniLight3D.new()
	glow.name = "HeaterLight"
	glow.position = Vector3(0, 0.28, 0)
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 0.8
	glow.omni_range = 1.1
	add_child(glow)
	# 天板の上：みかんの鉢
	var bowl_mat := MeshKit.mat("kotatsu_bowl", Color(0.85, 0.9, 0.92), 0.4)
	MeshKit.cylinder(self, 0.09, 0.05, Vector3(0.08, TOP + 0.025, 0.1), bowl_mat, "Bowl", 0.06)
	var orange := MeshKit.mat("mikan", Color(0.95, 0.5, 0.1), 0.6)
	for p in [Vector2(0.05, 0.08), Vector2(0.12, 0.12), Vector2(0.09, 0.05), Vector2(0.08, 0.14)]:
		MeshKit.sphere(self, 0.034, Vector3(p.x, TOP + 0.075, p.y), orange)
	# 鉢の中の携帯電話：みかんの間に差し込まれていて、画面が少し斜めに覗く。調べられる（phone_mobile）
	var phone := Node3D.new()
	phone.name = "MobilePhone"
	phone.position = Vector3(0.1, TOP + 0.075, 0.1)
	phone.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(25.0), deg_to_rad(8.0))
	add_child(phone)
	MeshKit.box(phone, Vector3(0.07, 0.145, 0.008), Vector3(0, 0.03, 0), MeshKit.mat("mobile_body", Color(0.12, 0.12, 0.14), 0.3, 0.4), "Body")
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.05, 0.08, 0.14)
	screen.emission_enabled = true
	screen.emission = Color(0.2, 0.35, 0.6)
	screen.emission_energy_multiplier = 0.5
	MeshKit.box(phone, Vector3(0.062, 0.128, 0.002), Vector3(0, 0.03, 0.0045), screen, "Screen")
	var parea := MeshKit.interact_area(phone, "PhoneArea", "phone_mobile")
	MeshKit.shape_box(parea, Vector3(0.1, 0.18, 0.06), Vector3(0, 0.03, 0))
	# 座布団（床に平らに置く。調べる判定つき）
	var cush_cols := [Color(0.35, 0.5, 0.6), Color(0.7, 0.35, 0.35), Color(0.4, 0.55, 0.4)]
	for i in SEATS.size():
		var s: Dictionary = SEATS[i]
		var local: Vector3 = (s.feet as Vector3) - CENTER
		var cushion := MeshKit.box(self, Vector3(0.38, 0.06, 0.38), local + Vector3(0, 0.03, 0), MeshKit.mat("cushion_%d" % i, cush_cols[i], 0.95), "Cushion")
		cushion.rotation.y = s.yaw
		var area := MeshKit.interact_area(self, "CushionArea%d" % i, "kotatsu")
		MeshKit.shape_box(area, Vector3(0.42, 0.12, 0.42), local + Vector3(0, 0.06, 0))
	# 本体の当たり判定（体を止める。調べる対象）
	body = StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "kotatsu")
	add_child(body)
	MeshKit.shape_box(body, Vector3(BLANKET - 0.26, 0.42, BLANKET - 0.26), Vector3(0, 0.21, 0))   # 布団より一回り小さい（脚が布団にめり込む程度。狭い通路を残すため）
	_build_inner_wall()
	_build_headphones()
	MeshKit.auto_round = true


## こたつの中を進んだ先の壁（東の側）。ツルハシで壊すと、隣の和室へ続く穴が開く（main.gd）。
var wall_broken := false
var _wall_node: Node3D
var _hole_node: Node3D
var _wall_body: StaticBody3D
const WALL_LOCAL := Vector3(0.5, 0.0, -0.1)
const Stage5Items := preload("res://scripts/stage5_items.gd")
var headphones_node: Node3D


## こたつの中の床に落ちているヘッドホン（拾える）。
func _build_headphones() -> void:
	headphones_node = Node3D.new()
	headphones_node.name = "Headphones"
	headphones_node.position = Vector3(-0.22, 0.045, 0.2)
	headphones_node.rotation = Vector3(deg_to_rad(80.0), 0.6, 0.0)
	add_child(headphones_node)
	headphones_node.add_child(Stage5Items.headphones_model())
	var a := MeshKit.interact_area(headphones_node, "HeadphonesArea", "headphones", null)
	MeshKit.shape_box(a, Vector3(0.24, 0.12, 0.2), Vector3(0, 0.04, 0))


func take_headphones() -> void:
	if headphones_node:
		headphones_node.visible = false
		var a := headphones_node.get_node_or_null("HeadphonesArea") as Area3D
		if a:
			a.collision_layer = 0



func _build_inner_wall() -> void:
	_wall_node = Node3D.new()
	_wall_node.name = "InnerWall"
	_wall_node.position = WALL_LOCAL
	add_child(_wall_node)
	var plaster := MeshKit.mat("inner_wall", Color(0.62, 0.56, 0.46), 0.95)
	MeshKit.box(_wall_node, Vector3(0.05, 0.38, 0.62), Vector3(0, 0.19, 0), plaster, "Plaster")
	# ひび割れ（細い黒い線）
	var crack := MeshKit.mat("inner_crack", Color(0.12, 0.1, 0.09), 1.0)
	for c in [[0.0, 0.2, 0.25, 0.3], [0.05, 0.12, -0.2, 0.18], [-0.05, 0.28, 0.1, 0.2]]:
		var seg := MeshKit.box(_wall_node, Vector3(0.006, 0.003, c[3]), Vector3(-0.027, c[1], c[0] if false else c[2] * 0.5), crack, "Crack")
		seg.rotation.x = c[0]
	_wall_body = StaticBody3D.new()
	_wall_body.collision_layer = MeshKit.LAYER_WORLD
	_wall_body.collision_mask = 0
	_wall_node.add_child(_wall_body)
	MeshKit.shape_box(_wall_body, Vector3(0.05, 0.38, 0.62), Vector3(0, 0.19, 0))
	var a := MeshKit.interact_area(_wall_node, "InnerWallArea", "kotatsu_wall")
	MeshKit.shape_box(a, Vector3(0.2, 0.4, 0.66), Vector3(-0.1, 0.2, 0))
	# 穴（壊したあと）：暗い口と、床のがれき
	_hole_node = Node3D.new()
	_hole_node.name = "InnerHole"
	_hole_node.position = WALL_LOCAL
	_hole_node.visible = false
	add_child(_hole_node)
	MeshKit.box(_hole_node, Vector3(0.05, 0.3, 0.46), Vector3(0, 0.17, 0), MeshKit.mat("hole_dark", Color(0.01, 0.01, 0.01), 1.0), "Hole")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in 8:
		var r := MeshKit.box(_hole_node, Vector3(rng.randf_range(0.03, 0.07), rng.randf_range(0.02, 0.05), rng.randf_range(0.03, 0.07)), Vector3(rng.randf_range(-0.2, -0.05), 0.02, rng.randf_range(-0.28, 0.28)), plaster, "Rubble")
		r.rotation = Vector3(rng.randf_range(-1, 1), rng.randf_range(0, TAU), rng.randf_range(-1, 1))
	var ha := MeshKit.interact_area(_hole_node, "InnerHoleArea", "kotatsu_hole")
	ha.collision_layer = 0
	MeshKit.shape_box(ha, Vector3(0.2, 0.34, 0.5), Vector3(-0.1, 0.17, 0))


## ツルハシで壁を壊す。
func break_wall(instant := false) -> void:
	if wall_broken:
		return
	wall_broken = true
	_wall_node.visible = false
	_wall_body.collision_layer = 0
	(_wall_node.get_node("InnerWallArea") as Area3D).collision_layer = 0
	_hole_node.visible = true
	(_hole_node.get_node("InnerHoleArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT


## 足元 p から一番近い座る場所の番号。
static func nearest_seat(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in SEATS.size():
		var d: float = ((SEATS[i].feet as Vector3) - p).length()
		if d < best_d:
			best_d = d
			best = i
	return best
