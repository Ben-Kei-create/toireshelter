extends Node3D
## 床下の貯蔵庫（食べ物を入れておく小さな穴。階段はない）。床にはめ込んだ板の蓋で、引き手をつまんで開け閉めする。
## 原点は穴の中心の床面。穴は 0.6m 四方、深さ 0.5m。apartment.gd が床板をこの穴の形に切り分けている（HOLE）。
##
##   蓋を閉めている … 蓋が床の一部（当たり判定あり）。調べる判定は蓋の上（id cellar）
##   蓋を開けている … 蓋が北側の縁を軸に立ち上がり、穴が開く。穴の中は棚と、壺・缶詰・米袋・瓶。
##                    穴の上は「体だけを止める板」でふさぐ（落ちない）。中身を調べる判定は穴の上（id cellar_goods）
## main.gd からは fixture として使う：get_prompt(id)／interact(id) が文章のキーを返す。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

## 床の穴（部屋の座標。x の範囲, z の範囲）。床板の切り分けと同じ値を使う
const HOLE_X := Vector2(4.0, 4.6)
const HOLE_Z := Vector2(1.0, 1.6)
const DEPTH := 0.5
const OPEN_ANGLE := -100.0   # 蓋を開く角度（°）。北の縁を軸に立ち上がる

var is_open := false
var lid: Node3D
var _lid_body: StaticBody3D
var _guard: StaticBody3D
var _goods_area: Area3D
var _item_areas: Array = []     # 中身ひとつずつの判定（開けているときだけ有効）
## 食べ物の「惣菜」：持って運んで冷蔵庫に入れる。全部（7つ）入れると床の底板が外れて、地下への階段が現れる。
const FOODS := {
	"cellar_can_0": ["ツナ缶", ["CanB0"]],
	"cellar_can_1": ["コーン缶", ["CanB1"]],
	"cellar_can_2": ["桃缶", ["CanB2"]],
	"cellar_honey": ["はちみつの瓶", ["Jar0", "JarLid0"]],
	"cellar_pickle": ["ピクルスの瓶", ["Jar2", "JarLid2"]],
	"cellar_crock": ["ぬか漬けの壺", ["Crock", "CrockLid"]],
	"cellar_potato": ["じゃがいも", ["Potato0", "Potato1", "Potato2"]],
}
signal stairs_revealed          # 階段が現れた（basement.gd が地下を見せる）
signal descend_requested        # 階段を降りる（main.gd が移動する）
var carrying_id := ""           # いま手に持っている食べ物
var carrying_name := ""
var removed: Array = []         # 床下から出した食べ物（持っているか、冷蔵庫に入れた）
var stored: Array = []          # 冷蔵庫に入れた食べ物
var stairs_open := false
var _stairs_area: Area3D
var _tween: Tween


func _ready() -> void:
	position = Vector3((HOLE_X.x + HOLE_X.y) * 0.5, 0.0, (HOLE_Z.x + HOLE_Z.y) * 0.5)
	MeshKit.auto_round = false
	var w := HOLE_X.y - HOLE_X.x
	var d := HOLE_Z.y - HOLE_Z.x
	var dark := MeshKit.mat("cellar_wall", Color(0.22, 0.17, 0.13), 0.95)
	var plank := MeshKit.mat("cellar_plank", Color(0.42, 0.3, 0.2), 0.8)
	# 穴の壁（4面）と底。縁取りの枠は床より 5mm 高く
	MeshKit.box(self, Vector3(0.02, DEPTH, d), Vector3(-w * 0.5 - 0.01, -DEPTH * 0.5, 0), dark, "WallW")
	MeshKit.box(self, Vector3(0.02, DEPTH, d), Vector3(w * 0.5 + 0.01, -DEPTH * 0.5, 0), dark, "WallE")
	MeshKit.box(self, Vector3(w + 0.04, DEPTH, 0.02), Vector3(0, -DEPTH * 0.5, -d * 0.5 - 0.01), dark, "WallN")
	MeshKit.box(self, Vector3(w + 0.04, DEPTH, 0.02), Vector3(0, -DEPTH * 0.5, d * 0.5 + 0.01), dark, "WallS")
	MeshKit.box(self, Vector3(w + 0.04, 0.02, d + 0.04), Vector3(0, -DEPTH - 0.01, 0), dark, "Bottom")
	var frame := MeshKit.mat("cellar_frame", Color(0.3, 0.22, 0.15), 0.6)
	MeshKit.box(self, Vector3(w + 0.1, 0.008, 0.05), Vector3(0, 0.004, -d * 0.5 - 0.025), frame, "FrameN")
	MeshKit.box(self, Vector3(w + 0.1, 0.008, 0.05), Vector3(0, 0.004, d * 0.5 + 0.025), frame, "FrameS")
	MeshKit.box(self, Vector3(0.05, 0.008, d), Vector3(-w * 0.5 - 0.025, 0.004, 0), frame, "FrameW")
	MeshKit.box(self, Vector3(0.05, 0.008, d), Vector3(w * 0.5 + 0.025, 0.004, 0), frame, "FrameE")
	_build_goods(plank)
	var glow := OmniLight3D.new()
	glow.name = "CellarLight"
	glow.position = Vector3(0, -0.1, 0)
	glow.light_color = Color(1.0, 0.8, 0.55)
	glow.light_energy = 0.0
	glow.omni_range = 1.2
	glow.shadow_enabled = false
	add_child(glow)

	# 蓋：北の縁（z -d/2）を軸に回る。閉じた状態では上面が床と同じ高さ
	lid = Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0, -d * 0.5)
	add_child(lid)
	var wood := MeshKit.tiled_mat("cellar_lid", load("res://assets/textures/surfaces/surface_09.png"), 0.5, Color(0.85, 0.7, 0.55), 0.7)
	MeshKit.box(lid, Vector3(w - 0.008, 0.03, d - 0.008), Vector3(0, -0.015, d * 0.5), wood, "LidBoard")
	var metal := MeshKit.mat("cellar_ring", Color(0.55, 0.52, 0.45), 0.35, 0.7)
	MeshKit.box(lid, Vector3(0.12, 0.004, 0.03), Vector3(0, 0.002, d - 0.08), MeshKit.mat("cellar_plate", Color(0.3, 0.28, 0.25), 0.4, 0.6), "RingPlate")
	MeshKit.cylinder(lid, 0.035, 0.006, Vector3(0, 0.008, d - 0.08), metal, "Ring")
	# 引き手は穴にして見せる：小さな黒い丸
	MeshKit.cylinder(lid, 0.024, 0.008, Vector3(0, 0.009, d - 0.08), MeshKit.mat("cellar_ringhole", Color(0.05, 0.04, 0.04), 0.9), "RingHole")
	var lid_area := MeshKit.interact_area(lid, "LidArea", "cellar", self)
	MeshKit.shape_box(lid_area, Vector3(w, 0.1, d), Vector3(0, 0.0, d * 0.5))
	lid_area.set_meta("interact_range", 2.2)

	# 当たり判定：蓋（床の一部）と、開けたときの落下止め
	_lid_body = StaticBody3D.new()
	_lid_body.name = "LidBody"
	_lid_body.collision_layer = MeshKit.LAYER_WORLD
	_lid_body.collision_mask = 0
	add_child(_lid_body)
	MeshKit.shape_box(_lid_body, Vector3(w, 0.1, d), Vector3(0, -0.05, 0))
	_guard = StaticBody3D.new()
	_guard.name = "Guard"
	_guard.collision_layer = 0
	_guard.collision_mask = 0
	add_child(_guard)
	MeshKit.shape_box(_guard, Vector3(w, 0.9, d), Vector3(0, 0.4, 0))

	# 中身を調べる判定（開けたときだけ有効）
	_goods_area = MeshKit.interact_area(self, "GoodsArea", "cellar_goods", self)
	_goods_area.collision_layer = 0
	MeshKit.shape_box(_goods_area, Vector3(w, 0.06, d), Vector3(0, -DEPTH + 0.04, 0))   # 一番下。ひとつずつの判定が先に当たる
	MeshKit.auto_round = true


## 穴の中の棚と食べ物：北の壁に棚が2段、床に米袋・壺・瓶。
func _build_goods(plank: Material) -> void:
	_build_goods_meshes(plank)
	_build_item_areas()


func w_hole() -> float:
	return HOLE_X.y - HOLE_X.x


func _add_item_area(id: String, size: Vector3, center: Vector3) -> void:
	var a := MeshKit.interact_area(self, "Item_" + id, id, self)
	MeshKit.shape_box(a, size, center)
	a.collision_layer = 0
	_item_areas.append(a)


## 中身ひとつずつを調べる判定。食べ物（缶詰・瓶・壺・じゃがいも）は持って運べる。米袋は重くて運べず、調べるだけ。
func _build_item_areas() -> void:
	var d := HOLE_Z.y - HOLE_Z.x
	var shelf_z := -d * 0.5 + 0.08
	for i in 3:
		_add_item_area("cellar_can_%d" % i, Vector3(0.09, 0.12, 0.09), Vector3(-0.15 + i * 0.1, -0.34 + 0.07, shelf_z))
	_add_item_area("cellar_honey", Vector3(0.09, 0.12, 0.09), Vector3(-0.2, -0.18 + 0.07, shelf_z))
	_add_item_area("cellar_pickle", Vector3(0.09, 0.12, 0.09), Vector3(0.06, -0.18 + 0.07, shelf_z))
	_add_item_area("cellar_crock", Vector3(0.21, 0.24, 0.21), Vector3(-0.12, -DEPTH + 0.12, 0.1))
	_add_item_area("cellar_sack", Vector3(0.24, 0.18, 0.16), Vector3(0.14, -DEPTH + 0.09, 0.12))
	_add_item_area("cellar_potato", Vector3(0.14, 0.08, 0.16), Vector3(-0.19, -DEPTH + 0.04, -0.08))
	# 階段（底板が外れたあとだけ有効。ひとつずつの判定より上にあり、先に当たる）
	_stairs_area = MeshKit.interact_area(self, "StairsArea", "cellar_stairs", self)
	MeshKit.shape_box(_stairs_area, Vector3(w_hole(), 0.2, d), Vector3(0, -0.3, 0))
	_stairs_area.collision_layer = 0


func _build_goods_meshes(plank: Material) -> void:
	var w := HOLE_X.y - HOLE_X.x
	var d := HOLE_Z.y - HOLE_Z.x
	var shelf_z := -d * 0.5 + 0.08
	for y in [-0.18, -0.34]:
		MeshKit.box(self, Vector3(w - 0.04, 0.015, 0.14), Vector3(0, y, shelf_z), plank, "Shelf")
	var glass := MeshKit.mat("cellar_jar", Color(0.75, 0.55, 0.2), 0.3)
	var green := MeshKit.mat("cellar_pickle", Color(0.45, 0.55, 0.25), 0.3)
	var can_m := MeshKit.mat("cellar_can", Color(0.78, 0.78, 0.8), 0.3, 0.6)
	var label := MeshKit.mat("cellar_can_label", Color(0.8, 0.3, 0.25), 0.6)
	# 上の棚：瓶と缶詰
	for i in 4:
		var x := -0.2 + i * 0.13
		if i % 2 == 0:
			MeshKit.cylinder(self, 0.035, 0.1, Vector3(x, -0.18 + 0.0075 + 0.05, shelf_z), glass if i == 0 else green, "Jar%d" % i)
			MeshKit.cylinder(self, 0.03, 0.015, Vector3(x, -0.18 + 0.0075 + 0.107, shelf_z), can_m, "JarLid%d" % i)
		else:
			MeshKit.cylinder(self, 0.04, 0.11, Vector3(x, -0.18 + 0.0075 + 0.055, shelf_z), can_m, "Can%d" % i)
			MeshKit.cylinder(self, 0.0415, 0.05, Vector3(x, -0.18 + 0.0075 + 0.055, shelf_z), label, "CanLabel%d" % i)
	# 下の棚：缶詰の山
	for i in 3:
		MeshKit.cylinder(self, 0.04, 0.11, Vector3(-0.15 + i * 0.1, -0.34 + 0.0075 + 0.055, shelf_z), can_m, "CanB%d" % i)
	# 床：米袋（白い袋）、漬物の壺（茶）、じゃがいも
	var sack := MeshKit.mat("cellar_sack", Color(0.85, 0.8, 0.68), 0.95)
	MeshKit.box(self, Vector3(0.22, 0.16, 0.14), Vector3(0.14, -DEPTH + 0.08, 0.12), sack, "RiceSack")
	MeshKit.box(self, Vector3(0.12, 0.03, 0.002), Vector3(0.14, -DEPTH + 0.1, 0.12 - 0.071), MeshKit.mat("cellar_sack_band", Color(0.3, 0.45, 0.7), 0.7), "SackBand")
	var crock := MeshKit.mat("cellar_crock", Color(0.4, 0.27, 0.16), 0.5)
	MeshKit.cylinder(self, 0.1, 0.2, Vector3(-0.12, -DEPTH + 0.1, 0.1), crock, "Crock", 0.085)
	MeshKit.cylinder(self, 0.085, 0.02, Vector3(-0.12, -DEPTH + 0.21, 0.1), MeshKit.mat("cellar_crock_lid", Color(0.55, 0.4, 0.25), 0.6), "CrockLid")
	var potato := MeshKit.mat("cellar_potato", Color(0.7, 0.55, 0.35), 0.9)
	var pi := 0
	for p in [Vector2(-0.2, -0.05), Vector2(-0.14, -0.08), Vector2(-0.22, -0.12)]:
		MeshKit.sphere(self, 0.035, Vector3(p.x, -DEPTH + 0.035, p.y), potato).name = "Potato%d" % pi
		pi += 1


func is_closed() -> bool:
	return not is_open


func get_prompt(id: String) -> String:
	if id == "cellar_goods":
		return "cellar_examine"
	if id == "cellar_stairs":
		return "cellar_stairs_go"
	if FOODS.has(id):
		return "cellar_carry"
	if id == "cellar_sack":
		return "cellar_look"
	return "cellar_close" if is_open else "cellar_open"


## 蓋を開け閉めする（id は cellar）／中身を調べる・運ぶ。戻り値は main.gd の MESSAGES のキー。
func interact(id: String) -> String:
	if id == "cellar_goods":
		return "cellar_goods"
	if id == "cellar_stairs":
		descend_requested.emit()
		return ""
	if FOODS.has(id):
		return _carry(id)
	if id == "cellar_sack":
		return "cellar_sack"
	set_open(not is_open)
	return "cellar_opened" if is_open else "cellar_closed"


func format_message(_key: String, text: String) -> String:
	return text.replace("{food}", carrying_name).replace("{left}", str(FOODS.size() - stored.size()))


## 食べ物をひとつ手に持つ（いちどにひとつ）。棚・床から消え、冷蔵庫に入れるまで持ち歩く。
func _carry(id: String) -> String:
	if removed.has(id):
		return ""
	if not carrying_id.is_empty():
		return "cellar_carry_full"
	for nm in FOODS[id][1]:
		(get_node(nm) as Node3D).visible = false
	removed.append(id)
	carrying_id = id
	carrying_name = FOODS[id][0]
	_refresh_areas()
	Sfx.play("pop", 1.1, -4.0)
	return "cellar_carry_taken"


## 持っている食べ物を冷蔵庫に入れた。全部そろったら階段が現れる。入れた数を返す。
func food_stored() -> int:
	stored.append(carrying_id)
	carrying_id = ""
	carrying_name = ""
	if stored.size() >= FOODS.size() and not stairs_open:
		reveal_stairs()
	return stored.size()


## 底板が外れて、地下への階段が現れる。
func reveal_stairs() -> void:
	stairs_open = true
	(get_node("Bottom") as Node3D).visible = false
	Sfx.play("clunk", 0.7)
	_refresh_areas()
	stairs_revealed.emit()


func _refresh_areas() -> void:
	for a in _item_areas:
		var cid: String = (a as Area3D).get_meta("interact_id")
		var gone: bool = removed.has(cid)
		(a as Area3D).collision_layer = MeshKit.LAYER_INTERACT if (is_open and not gone) else 0
	if _stairs_area:
		_stairs_area.collision_layer = MeshKit.LAYER_INTERACT if (is_open and stairs_open) else 0


func set_open(open: bool, animate := true) -> void:
	is_open = open
	_lid_body.collision_layer = 0 if open else MeshKit.LAYER_WORLD
	_guard.collision_layer = MeshKit.LAYER_BODY_ONLY if open else 0
	_goods_area.collision_layer = MeshKit.LAYER_INTERACT if open else 0
	_refresh_areas()
	var target := deg_to_rad(OPEN_ANGLE) if open else 0.0
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(lid, "rotation:x", target, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		lid.rotation.x = target
	($CellarLight as OmniLight3D).light_energy = 0.6 if open else 0.0
