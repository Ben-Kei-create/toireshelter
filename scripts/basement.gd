extends Node3D
## 地下室（床下の貯蔵庫の底の、さらに下）。貯蔵庫の食べ物を全部冷蔵庫に入れると底板が外れ、ここへ降りる階段が現れる。
## 部屋の床（y 0）の下 2.1m：急な階段（8 段）が穴の真下から西へ下り、その先の狭い部屋の小さな机に、手紙が1枚だけ置いてある。
## 階段の昇り降りは歩かずに、決まった経路を滑らかに移る（main.gd が move_to で移す。穴が 0.6m と狭いため）。
## 最初は見えない（visible = false）。cellar.gd が階段を出したときに見せる。
##   Basement/Letter … 手紙（id basement_letter。読める）
##   Basement/UpArea … 階段の下の「上へ戻る」判定（id basement_up）

const MeshKit := preload("res://scripts/mesh_kit.gd")

signal ascend_requested

const FLOOR_Y := -2.1
const TOP_Y := -0.5            # 階段の一番上（貯蔵庫の穴の底）
const X_TOP := 4.6             # 階段の東端（穴の東の縁）
const STEPS := 8
const RISE := 0.2
const RUN := 0.3
const ROOM_X := Vector2(0.9, 2.2)   # 部屋の x
const ROOM_Z := Vector2(0.5, 2.1)
const CORR_Z := Vector2(0.9, 1.7)   # 階段と通路の z
const FEET := Vector3(1.95, FLOOR_Y, 1.3)          # 降りたあとの足元
const STAIR_EXIT := Vector3(4.3, 0.0, 0.62)        # 上がったあとの足元（穴のすぐ北。南側は台所の台で埋まる）
## 昇り降りの経路（足元）。穴の真上から階段の下まで
const PATH_DOWN := [Vector3(4.3, 0.0, 1.3), Vector3(4.3, -0.5, 1.3), Vector3(3.7, -1.1, 1.3), Vector3(3.0, -1.6, 1.3), Vector3(2.4, FLOOR_Y, 1.3)]

var letter: Node3D
var _light: OmniLight3D


func _ready() -> void:
	visible = false
	MeshKit.auto_round = false
	var concrete := MeshKit.mat("basement_concrete", Color(0.42, 0.4, 0.38), 0.95)
	var floor_m := MeshKit.mat("basement_floor", Color(0.3, 0.28, 0.26), 0.9)
	var wood := MeshKit.mat("basement_wood", Color(0.5, 0.36, 0.22), 0.7)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	var solid := func(size: Vector3, center: Vector3, m: Material, nm := "") -> void:
		MeshKit.box(self, size, center, m, nm)
		MeshKit.shape_box(body, size, center)
	var h := -0.1 - FLOOR_Y   # 床下の天井（部屋の床板の下）まで
	var cy := (FLOOR_Y - 0.1) * 0.5 - 0.0
	# 部屋の床・壁・天井
	solid.call(Vector3(ROOM_X.y - ROOM_X.x, 0.1, ROOM_Z.y - ROOM_Z.x), Vector3((ROOM_X.x + ROOM_X.y) * 0.5, FLOOR_Y - 0.05, (ROOM_Z.x + ROOM_Z.y) * 0.5), floor_m, "RoomFloor")
	solid.call(Vector3(ROOM_X.y - ROOM_X.x, 0.06, ROOM_Z.y - ROOM_Z.x), Vector3((ROOM_X.x + ROOM_X.y) * 0.5, -0.13, (ROOM_Z.x + ROOM_Z.y) * 0.5), concrete, "RoomCeiling")
	solid.call(Vector3(0.1, h, ROOM_Z.y - ROOM_Z.x), Vector3(ROOM_X.x - 0.05, FLOOR_Y + h * 0.5, (ROOM_Z.x + ROOM_Z.y) * 0.5), concrete, "WallW")
	solid.call(Vector3(ROOM_X.y - ROOM_X.x, h, 0.1), Vector3((ROOM_X.x + ROOM_X.y) * 0.5, FLOOR_Y + h * 0.5, ROOM_Z.x - 0.05), concrete, "WallN")
	solid.call(Vector3(ROOM_X.y - ROOM_X.x, h, 0.1), Vector3((ROOM_X.x + ROOM_X.y) * 0.5, FLOOR_Y + h * 0.5, ROOM_Z.y + 0.05), concrete, "WallS")
	# 部屋の東の壁（通路の口をはさんだ両側）。ここが空いていると、地下から空が見えてしまう
	solid.call(Vector3(0.1, h, CORR_Z.x - ROOM_Z.x), Vector3(ROOM_X.y + 0.05, FLOOR_Y + h * 0.5, (ROOM_Z.x + CORR_Z.x) * 0.5), concrete, "WallE_N")
	solid.call(Vector3(0.1, h, ROOM_Z.y - CORR_Z.y), Vector3(ROOM_X.y + 0.05, FLOOR_Y + h * 0.5, (CORR_Z.y + ROOM_Z.y) * 0.5), concrete, "WallE_S")
	# 通路（階段の部分）：床下の天井は部屋の床板、壁は両脇
	var x_bot := X_TOP - RUN * STEPS   # 階段の西端（床に着く所）
	solid.call(Vector3(X_TOP - ROOM_X.y, 0.1, CORR_Z.y - CORR_Z.x), Vector3((ROOM_X.y + X_TOP) * 0.5, FLOOR_Y - 0.05, (CORR_Z.x + CORR_Z.y) * 0.5), floor_m, "CorridorFloor")
	solid.call(Vector3(X_TOP - ROOM_X.y, h, 0.1), Vector3((ROOM_X.y + X_TOP) * 0.5, FLOOR_Y + h * 0.5, CORR_Z.x - 0.05), concrete, "CorridorN")
	solid.call(Vector3(X_TOP - ROOM_X.y, h, 0.1), Vector3((ROOM_X.y + X_TOP) * 0.5, FLOOR_Y + h * 0.5, CORR_Z.y + 0.05), concrete, "CorridorS")
	solid.call(Vector3(0.1, h, CORR_Z.y - CORR_Z.x + 0.2), Vector3(X_TOP + 0.05, FLOOR_Y + h * 0.5, (CORR_Z.x + CORR_Z.y) * 0.5), concrete, "CorridorE")
	# 階段：木の段（見た目だけ。昇り降りは経路で移す）
	for i in STEPS:
		var top := TOP_Y - RISE * i
		var th := top - FLOOR_Y
		MeshKit.box(self, Vector3(RUN, th, CORR_Z.y - CORR_Z.x - 0.02), Vector3(X_TOP - RUN * (i + 0.5), FLOOR_Y + th * 0.5, (CORR_Z.x + CORR_Z.y) * 0.5), wood, "Step%d" % i)
	# 机と手紙
	solid.call(Vector3(0.5, 0.04, 0.4), Vector3(1.35, FLOOR_Y + 0.7, 1.3), wood, "Table")
	for sx in [-0.21, 0.21]:
		for sz in [-0.16, 0.16]:
			MeshKit.box(self, Vector3(0.04, 0.68, 0.04), Vector3(1.35 + sx, FLOOR_Y + 0.34, 1.3 + sz), wood, "TableLeg")
	letter = Node3D.new()
	letter.name = "Letter"
	letter.position = Vector3(1.35, FLOOR_Y + 0.7 + 0.021, 1.3)
	letter.rotation.y = deg_to_rad(12.0)
	add_child(letter)
	MeshKit.box(letter, Vector3(0.2, 0.002, 0.14), Vector3.ZERO, MeshKit.mat("letter_paper", Color(0.96, 0.93, 0.82), 0.9), "Paper")
	for k in 4:
		MeshKit.box(letter, Vector3(0.14, 0.0005, 0.004), Vector3(0.0, 0.0012, -0.04 + k * 0.025), MeshKit.mat("letter_ink", Color(0.2, 0.2, 0.25), 0.9), "Line%d" % k)
	var la := MeshKit.interact_area(letter, "LetterArea", "basement_letter")
	MeshKit.shape_box(la, Vector3(0.26, 0.08, 0.2), Vector3(0, 0.03, 0))
	la.set_meta("interact_range", 2.4)
	# 電球（ひとつだけ）
	MeshKit.cylinder(self, 0.003, 0.3, Vector3(1.35, -0.3, 1.3), MeshKit.mat("bulb_cord", Color(0.1, 0.1, 0.1), 0.6), "Cord")
	var bulb := StandardMaterial3D.new()
	bulb.albedo_color = Color(1.0, 0.92, 0.7)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.85, 0.5)
	bulb.emission_energy_multiplier = 2.0
	MeshKit.sphere(self, 0.035, Vector3(1.35, -0.5, 1.3), bulb)
	_light = OmniLight3D.new()
	_light.name = "BulbLight"
	_light.position = Vector3(1.35, -0.55, 1.3)
	_light.light_color = Color(1.0, 0.85, 0.55)
	_light.light_energy = 1.8
	_light.omni_range = 4.5
	_light.shadow_enabled = false
	add_child(_light)
	# 階段の下の「上へ戻る」判定（階段の側面を狙う）
	var up := MeshKit.interact_area(self, "UpArea", "basement_up", self)
	MeshKit.shape_box(up, Vector3(0.7, 0.8, 0.8), Vector3(x_bot - 0.05, FLOOR_Y + 0.5, 1.3))
	up.set_meta("interact_range", 2.4)
	MeshKit.auto_round = true


func get_prompt(_id: String) -> String:
	return "basement_up_go"


func interact(_id: String) -> String:
	ascend_requested.emit()
	return ""


## 階段が現れたとき、地下を見せる。
func reveal() -> void:
	visible = true
