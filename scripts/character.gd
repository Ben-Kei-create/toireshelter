extends RefCounted
## 主人公のキャラクター（ユーザー作成の設定画を切り抜いたもの。生成 AI 使用）。
## 画像は assets/textures/character/：全身 5 方向（body_front／three_quarter／side／back_three_quarter／back）と、顔のアップ 3 方向（head_front／three_quarter／side）。
## どれも背景を透明に切り抜いてある（設定画の灰色の背景を縁からたどって抜いた）。
## 使う所：自室の等身大パネル（表と裏）、浴室の鏡に映る顔（見る角度で顔の向きが変わる）、設定画面の肖像。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const DIR := "res://assets/textures/character/"

static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR + name + ".png")
	return _cache[name]


## 切り抜きの板（絵の比率のまま、高さ h）。透過の縁は alpha scissor で抜く。
static func quad(name: String, h: float) -> MeshInstance3D:
	var t := tex(name)
	var q := QuadMesh.new()
	q.size = Vector2(h * float(t.get_width()) / float(t.get_height()), h)
	var m := MeshKit.texture_mat("character_" + name, t, 0.85).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	var mi := MeshInstance3D.new()
	mi.name = "Cut_" + name
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 見る角度（度。0＝正面、プラスは右から）に合う顔のアップ：[画像名, 左右反転するか]。
static func head_view(angle_deg: float) -> Array:
	var a := absf(angle_deg)
	var flip := angle_deg < 0.0
	if a < 18.0:
		return ["head_front", false]
	if a < 52.0:
		return ["head_three_quarter", flip]
	return ["head_side", flip]


## 見る角度に合う全身：[画像名, 左右反転するか]。
static func body_view(angle_deg: float) -> Array:
	var a := absf(angle_deg)
	var flip := angle_deg < 0.0
	if a < 20.0:
		return ["body_front", false]
	if a < 65.0:
		return ["body_three_quarter", flip]
	if a < 115.0:
		return ["body_side", flip]
	if a < 160.0:
		return ["body_back_three_quarter", flip]
	return ["body_back", false]


## 等身大パネル：表（正面）と裏（後ろ姿）を背中合わせに貼った厚紙の立て看板。原点は足元の中心、表は +z。
## 台座の足つき。体を止める当たり判定（薄い箱）と、調べる判定（standee）つき。
static func build_standee(height: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Standee"
	var front := quad("body_front", height)
	front.name = "Front"
	front.position = Vector3(0, height * 0.5 + 0.02, 0.004)
	root.add_child(front)
	var back := quad("body_back", height)
	back.name = "Back"
	back.position = Vector3(0, height * 0.5 + 0.02, -0.004)
	back.rotation.y = PI
	root.add_child(back)
	var foot := MeshKit.mat("standee_foot", Color(0.35, 0.3, 0.25), 0.8)
	for sx in [-0.14, 0.14]:
		MeshKit.box(root, Vector3(0.05, 0.02, 0.26), Vector3(sx, 0.01, 0.0), foot, "Foot")
	var w: float = (front.mesh as QuadMesh).size.x
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "standee")
	root.add_child(body)
	MeshKit.shape_box(body, Vector3(w * 0.9, height, 0.05), Vector3(0, height * 0.5 + 0.02, 0))
	return root
