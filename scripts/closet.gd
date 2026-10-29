extends Node3D
## 押入れ（自室の奥の壁の右寄り）。ふとんと座布団が入っていて、その隣にクレーンゲームが置いてある。
## 原点は押入れの中心の床。幅 1.5m（x 3.95〜5.45）、奥行き 0.8m（z -1.2〜-0.4）、高さ 2.0m ＋ 上の天袋 0.4m。ローカル +z が部屋側。
##
##   左の仕切り … 中段の棚の上にふとん3枚、下に座布団が積んである
##   右の仕切り … クレーンゲーム（ufo_catcher.gd）が立っている
##   襖2枚（前後2本のレール）… 2枚いっしょに左か右に寄せる。最初は左に寄せてあり、クレーンゲームが見える。
##                              クリックで右へ寄せると、ふとんが見えて、クレーンゲームは襖に隠れる
## 襖は体の判定を持たない代わりに、押入れの前面に体だけを止める透明な板（LAYER_BODY_ONLY）を置いて、中へ歩いて入れないようにしている。
## 襖を右へ寄せている間は、クレーンゲームの前に襖があるので照準が届かない（襖の判定が手前）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Stage5Items := preload("res://scripts/stage5_items.gd")
const UfoCatcherScript := preload("res://scripts/ufo_catcher.gd")

const CENTER := Vector3(4.7, 0.0, -0.8)
const W := 1.5
const D := 0.8
const H := 2.0
const FLOOR_T := 0.05
const SLIDE_X := 0.375   # 襖の中心（左 -0.375、右 +0.375）

## 襖は 2 枚。左の襖（手前のレール）は左の仕切り（ふとん）を、右の襖（奥のレール）は右の仕切り（クレーンゲーム）をふさぐ。
## はじめは両方しまっている（closed）。左の襖をクリックすると、手前へ右へ寄って、ふとんの仕切りが開く（futon）。
## 右の襖をクリックすると、奥を左へ寄って、クレーンゲームの仕切りが開く（crane）。開けた側を、もう一度クリックすると、両方しまる。
var state := "closed"
var crane_visible: bool:   # 右の仕切り（クレーンゲーム）が開いている
	get:
		return state == "crane"
var futon_visible: bool:   # 左の仕切り（ふとん）が開いている
	get:
		return state == "futon"
var busy := false
var safe_node: Node3D
var safe_door: Node3D
var safe_open := false
var safe_slots: Array = []        # 置いたカードの点の数（順に）
var _safe_markers: Array = []
const SAFE_ORDER := [8, 6, 4, 2]  # 点の多い順に置く
var ufo: Node3D
var mahjong_box: Node3D
var _panels: Array = []
var _area: Area3D


func _ready() -> void:
	position = CENTER
	MeshKit.auto_round = false
	var wood := MeshKit.mat("closet_wood", Color(0.72, 0.58, 0.4), 0.7)
	var inner := MeshKit.mat("closet_inner", Color(0.82, 0.76, 0.62), 0.9)
	var half := W * 0.5
	# 床・側板・仕切り・奥の板・天袋
	MeshKit.box(self, Vector3(W, FLOOR_T, D), Vector3(0, FLOOR_T * 0.5, 0), wood, "Floor")
	MeshKit.box(self, Vector3(0.02, H + 0.4, D), Vector3(-half + 0.01, (H + 0.4) * 0.5, 0), wood, "SideL")
	MeshKit.box(self, Vector3(0.02, H + 0.4, D), Vector3(half - 0.01, (H + 0.4) * 0.5, 0), wood, "SideR")
	MeshKit.box(self, Vector3(0.02, H, D), Vector3(0, H * 0.5, 0), wood, "Divider")
	MeshKit.box(self, Vector3(W, H + 0.4, 0.01), Vector3(0, (H + 0.4) * 0.5, -D * 0.5 + 0.005), inner, "Back")
	MeshKit.box(self, Vector3(W, 0.025, D), Vector3(0, H + 0.0125, 0), wood, "TopShelf")
	MeshKit.box(self, Vector3(W, 0.4 - 0.025, 0.02), Vector3(0, H + 0.2125, D * 0.5 - 0.01), inner, "TenbukuroFront")
	for k in 4:   # 天袋の小さな襖（飾り）
		MeshKit.box(self, Vector3(0.36, 0.33, 0.012), Vector3(-0.56 + k * 0.375, H + 0.2125, D * 0.5 + 0.004), MeshKit.mat("fusuma_cream", Color(0.93, 0.9, 0.8), 0.9), "TenbukuroDoor")
	# 左の仕切り：中段の棚、ふとん3枚、下に座布団
	MeshKit.box(self, Vector3(0.73, 0.025, D - 0.02), Vector3(-half * 0.5 - 0.005, 1.0, 0), wood, "Shelf")
	var fab := StandardMaterial3D.new()   # 生地の画像は暗いので、ふとん・座布団は無地のやわらかい色にする
	fab.roughness = 0.95
	var futon_cols := [Color(0.82, 0.76, 0.92), Color(0.95, 0.82, 0.7), Color(0.7, 0.86, 0.82)]
	for k in 3:
		var m := fab.duplicate() as StandardMaterial3D
		m.albedo_color = futon_cols[k]
		var f := MeshKit.box(self, Vector3(0.62 - k * 0.02, 0.17, 0.5), Vector3(-half * 0.5 + 0.02 * (k % 2), 1.0125 + 0.0875 + k * 0.175, 0.02), m, "Futon")
		f.rotation.y = deg_to_rad(2.0 - k * 2.0)
	var zab_cols := [Color(0.8, 0.45, 0.45), Color(0.45, 0.62, 0.75), Color(0.8, 0.72, 0.4), Color(0.62, 0.5, 0.75)]
	for k in 4:
		var m2 := fab.duplicate() as StandardMaterial3D
		m2.albedo_color = zab_cols[k]
		var z := MeshKit.box(self, Vector3(0.46, 0.07, 0.46), Vector3(-half * 0.5 - 0.02 + (k % 2) * 0.04, FLOOR_T + 0.035 + k * 0.075, 0.0), m2, "Zabuton")
		z.rotation.y = deg_to_rad(-6.0 + k * 5.0)
	# ふとんの山の上に、麻雀牌の箱
	mahjong_box = build_mahjong_box()
	mahjong_box.position = Vector3(-half * 0.5 - 0.02, 1.0125 + 0.0875 + 0.35 + 0.085, 0.03)
	mahjong_box.rotation.y = deg_to_rad(8.0)
	add_child(mahjong_box)
	var ma := MeshKit.interact_area(mahjong_box, "MahjongArea", "mahjong", null)
	MeshKit.shape_box(ma, Vector3(0.3, 0.14, 0.2), Vector3(0, 0.05, 0))
	# 白紙のトランプ（3 枚）：棚の手前・座布団の上・床。もう 1 枚は椅子の上
	var card_spots := [Vector3(-0.2, 1.0125 + 0.002, 0.3), Vector3(-0.36, FLOOR_T + 0.3 + 0.002, 0.1), Vector3(-0.1, FLOOR_T + 0.002, 0.3)]
	for k in 3:
		var cn := Node3D.new()
		cn.name = "Card%d" % k
		cn.position = card_spots[k]
		cn.rotation.y = 0.5 + k * 1.1
		add_child(cn)
		var cm := Stage5Items.blank_card_model(0, false)
		cm.rotation.x = deg_to_rad(-90.0)
		cn.add_child(cm)
		var ca := MeshKit.interact_area(cn, "CardArea", "card_pick_%d" % k, null)
		MeshKit.shape_box(ca, Vector3(0.1, 0.06, 0.12), Vector3(0, 0.02, 0))
	_build_safe()
	# 右の仕切り：クレーンゲーム（向きは部屋側 +z）
	ufo = UfoCatcherScript.new()
	ufo.name = "UfoCatcher"
	ufo.position = Vector3(SLIDE_X, FLOOR_T, -0.1)
	add_child(ufo)
	var lamp := OmniLight3D.new()
	lamp.name = "ClosetLight"
	lamp.position = Vector3(0, 1.7, 0.2)
	lamp.light_color = Color(1.0, 0.9, 0.75)
	lamp.light_energy = 0.5
	lamp.omni_range = 1.8
	add_child(lamp)
	# 襖（前後2本のレール）
	var rail := MeshKit.mat("closet_rail", Color(0.4, 0.3, 0.2), 0.7)
	for zz in [D * 0.5 - 0.006, D * 0.5 - 0.034]:
		MeshKit.box(self, Vector3(W, 0.015, 0.02), Vector3(0, FLOOR_T + 0.0075, zz), rail, "Rail")
		MeshKit.box(self, Vector3(W, 0.02, 0.02), Vector3(0, FLOOR_T + 1.97 + 0.01, zz), rail, "Rail")
	var fcream := MeshKit.mat("fusuma_cream", Color(0.93, 0.9, 0.8), 0.9)
	var fframe := MeshKit.mat("fusuma_frame", Color(0.22, 0.17, 0.12), 0.6)
	var deco := MeshKit.mat("fusuma_deco", Color(0.7, 0.78, 0.82), 0.9)
	for k in 2:
		var p := Node3D.new()
		p.name = "Fusuma%d" % (k + 1)
		var zz2: float = D * 0.5 - 0.006 - 0.0125 if k == 0 else D * 0.5 - 0.034 - 0.0125
		p.position = Vector3(-SLIDE_X if k == 0 else SLIDE_X, FLOOR_T + 0.985, zz2)
		add_child(p)
		MeshKit.box(p, Vector3(0.76, 1.95, 0.02), Vector3.ZERO, fcream, "Panel")
		for dx in [-0.375, 0.375]:
			MeshKit.box(p, Vector3(0.02, 1.95, 0.026), Vector3(dx, 0, 0), fframe, "Stile")
		for dy in [-0.975, 0.975]:
			MeshKit.box(p, Vector3(0.76, 0.02, 0.026), Vector3(0, dy, 0), fframe, "Rail")
		MeshKit.box(p, Vector3(0.016, 0.07, 0.03), Vector3(0.3 if k == 0 else -0.3, 0.0, 0.0), fframe, "Handle")
		# 上下に薄い水色の波の飾り
		MeshKit.box(p, Vector3(0.6, 0.12, 0.004), Vector3(0, -0.6, 0.011), deco, "Deco")
		_panels.append(p)
	# 襖の調べる判定：左の襖（id fusuma）と右の襖（id fusuma_r）。開けた側は、寄せた襖の山が反対側に出るので、そちらが「閉める」判定になる
	_area_l = _make_fusuma_area("FusumaArea", "fusuma")
	_area_r = _make_fusuma_area("FusumaAreaR", "fusuma_r")
	_place_areas()
	var blocker := StaticBody3D.new()
	blocker.name = "BodyBlocker"
	blocker.collision_layer = MeshKit.LAYER_BODY_ONLY
	blocker.collision_mask = 0
	add_child(blocker)
	MeshKit.shape_box(blocker, Vector3(W, H, 0.1), Vector3(0, H * 0.5, D * 0.5 + 0.05))
	MeshKit.auto_round = true


var _area_l: Area3D
var _area_r: Area3D


func _make_fusuma_area(node_name: String, id: String) -> Area3D:
	var a := MeshKit.interact_area(self, node_name, id, self)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(0.76, 1.95, 0.08)
	cs.shape = box
	a.add_child(cs)
	return a


## 判定を、いまの襖の位置に合わせる。左の判定は、左の仕切りが閉まっているか、襖の山が左にあるとき。右の判定は、右の仕切りが閉まっているか、襖の山が右にあるとき。
func _place_areas() -> void:
	var y := FLOOR_T + 0.985
	var z := D * 0.5 - 0.02
	(_area_l.get_node("Shape") as CollisionShape3D).position = Vector3(-SLIDE_X, y, z)
	(_area_r.get_node("Shape") as CollisionShape3D).position = Vector3(SLIDE_X, y, z)
	_area_l.collision_layer = MeshKit.LAYER_INTERACT if state != "futon" else 0
	_area_r.collision_layer = MeshKit.LAYER_INTERACT if state != "crane" else 0


func get_prompt(id: String) -> String:
	if busy:
		return ""
	if state == "closed":
		return "fusuma_open_l" if id == "fusuma" else "fusuma_open_r"
	return "fusuma_close"


func interact(id: String) -> String:
	if busy:
		return ""
	if state == "closed":
		set_state("futon" if id == "fusuma" else "crane")
	else:
		set_state("closed")
	return ""


## 襖の状態を変える。closed：両方しまる／futon：左の襖が右へ寄って、ふとんの仕切りが開く／crane：右の襖が左へ寄って、クレーンゲームの仕切りが開く。
func set_state(new_state: String, seconds := 0.8) -> Tween:
	busy = true
	state = new_state
	Sfx.play("slide")
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var x0 := SLIDE_X if new_state == "futon" else -SLIDE_X   # 左の襖
	var x1 := -SLIDE_X if new_state == "crane" else SLIDE_X   # 右の襖
	tw.parallel().tween_property(_panels[0], "position:x", x0, seconds)
	tw.parallel().tween_property(_panels[1], "position:x", x1, seconds)
	tw.tween_callback(func() -> void:
		busy = false
		_place_areas())
	return tw


## 押入れの金庫（左の仕切りの奥の隅）。上面に、カードを置くくぼみが 4 つ。
func _build_safe() -> void:
	safe_node = Node3D.new()
	safe_node.name = "Safe"
	safe_node.position = Vector3(-0.64, FLOOR_T, -0.3)
	add_child(safe_node)
	var body := MeshKit.mat("safe_body", Color(0.22, 0.24, 0.26), 0.45)
	body.metallic = 0.6
	MeshKit.box(safe_node, Vector3(0.2, 0.4, 0.2), Vector3(0, 0.2, 0), body, "SafeBody")
	var recess := MeshKit.mat("safe_recess", Color(0.08, 0.08, 0.09), 0.9)
	for k in 4:
		MeshKit.box(safe_node, Vector3(0.036, 0.004, 0.05), Vector3(-0.066 + k * 0.044, 0.401, 0), recess, "Recess%d" % k)
	safe_door = Node3D.new()
	safe_door.name = "SafeDoor"
	safe_door.position = Vector3(-0.09, 0.2, 0.1)
	safe_node.add_child(safe_door)
	MeshKit.box(safe_door, Vector3(0.18, 0.36, 0.012), Vector3(0.09, 0, 0.006), MeshKit.mat("safe_door", Color(0.3, 0.32, 0.34), 0.4), "Door")
	MeshKit.cylinder(safe_door, 0.03, 0.01, Vector3(0.09, 0, 0.016), MeshKit.mat("safe_dial", Color(0.75, 0.7, 0.5), 0.3), "Dial", -1.0, 16).rotation.x = deg_to_rad(90.0)
	var sa := MeshKit.interact_area(safe_node, "SafeArea", "closet_safe", null)
	MeshKit.shape_box(sa, Vector3(0.24, 0.44, 0.26), Vector3(0, 0.2, 0.03))


## 金庫のくぼみにカードを置く。順番が違えば全部はね返る（false）。4 枚そろうと開く。
func place_card(dots: int) -> bool:
	var want: int = SAFE_ORDER[safe_slots.size()]
	if dots != want:
		reset_safe()
		return false
	safe_slots.append(dots)
	_add_marker(safe_slots.size() - 1)
	if safe_slots.size() >= SAFE_ORDER.size():
		open_safe()
	return true


func _add_marker(k: int) -> void:
	var m := MeshKit.box(safe_node, Vector3(0.034, 0.006, 0.048), Vector3(-0.066 + k * 0.044, 0.405, 0), MeshKit.mat("blank_card", Color(0.96, 0.95, 0.92), 0.7), "Placed%d" % k)
	_safe_markers.append(m)


func reset_safe() -> void:
	safe_slots.clear()
	for m in _safe_markers:
		(m as Node).queue_free()
	_safe_markers.clear()


func open_safe(instant := false) -> void:
	safe_open = true
	if instant:
		safe_door.rotation.y = deg_to_rad(-110.0)
		return
	Sfx.play("chime", 0.9)
	create_tween().tween_property(safe_door, "rotation:y", deg_to_rad(-110.0), 1.0).set_trans(Tween.TRANS_SINE)


func hide_card(k: int) -> void:
	var n := get_node_or_null("Card%d" % k) as Node3D
	if n:
		n.visible = false
		var a := n.get_node_or_null("CardArea") as Area3D
		if a:
			a.collision_layer = 0


func take_mahjong() -> void:
	if mahjong_box:
		mahjong_box.queue_free()
		mahjong_box = null


## 麻雀牌の箱（深緑のケース、金の留め具、ふたの上にこぼれた牌が2枚）。拡大表示にも使う。
static func build_mahjong_box() -> Node3D:
	var n := Node3D.new()
	n.name = "MahjongBox"
	var green := MeshKit.mat("mj_case", Color(0.12, 0.3, 0.2), 0.5)
	var gold := MeshKit.mat("mj_gold", Color(0.85, 0.7, 0.3), 0.3, 0.7)
	MeshKit.box(n, Vector3(0.26, 0.06, 0.17), Vector3(0, 0.03, 0), green, "Case")
	MeshKit.box(n, Vector3(0.265, 0.004, 0.175), Vector3(0, 0.035, 0), MeshKit.mat("mj_seam", Color(0.05, 0.12, 0.08), 0.6), "Seam")
	for sx in [-0.06, 0.06]:
		MeshKit.box(n, Vector3(0.02, 0.014, 0.004), Vector3(sx, 0.04, 0.087), gold, "Clasp")
	MeshKit.box(n, Vector3(0.05, 0.012, 0.03), Vector3(0, 0.066, 0), gold, "Plate")
	var ivory := MeshKit.mat("mj_ivory", Color(0.95, 0.93, 0.82), 0.4)
	var back := MeshKit.mat("mj_back", Color(0.18, 0.5, 0.35), 0.5)
	for k in 2:
		var t := Node3D.new()
		t.position = Vector3(-0.1 + k * 0.045, 0.06 + 0.009, 0.03)
		t.rotation.y = deg_to_rad(20.0 - k * 55.0)
		n.add_child(t)
		MeshKit.box(t, Vector3(0.024, 0.017, 0.032), Vector3(0, 0, 0), ivory, "Tile")
		MeshKit.box(t, Vector3(0.024, 0.006, 0.032), Vector3(0, -0.0055, 0), back, "TileBack")
		MeshKit.image_quad(t, MeshKit.prop_tex("mj_33" if k == 0 else "mj_27"), Vector2(0.024, 0.032), Vector3(0, 0.0086, 0), Vector3.UP, "TileFace", false, 0.4)
	return n


static func mahjong_zoom_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "MahjongModel"
	var b := build_mahjong_box()
	b.scale = Vector3.ONE * 2.2
	holder.add_child(b)
	return holder
