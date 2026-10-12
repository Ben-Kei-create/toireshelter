extends Node3D
## 浴室の経年感（汚れ・傷・水の跡）。見た目だけで、当たり判定も調べる判定も付けない（照準を遮らない）。
## 座標は部屋と同じ（この節点は原点に置く）。画像は assets/textures/bath/bath_decal_02〜10（透過付き）。
##
## 置き場所には理由をつけてある：
##   水が流れる所   … シャワーのスライドバーの下（水垢の筋）、風呂桶の下（水の輪）、洗面台の上（石けんの飛沫）
##   人が触る所     … 鏡の扉の取っ手のそば（指紋）
##   足や物が当たる所 … 浴槽の前面の下・入口の前の床・入口側の壁の下（擦り傷）
##   金属が濡れる所 … タオル掛けの留め具の下・壁と床の境目（サビ）
##   古くなる所     … 天井際（塗装の欠け）、隅の壁（ひび）、昔何かを貼っていた跡（テープ跡）
## どれも数字や文字の手がかりではない。操作・判定・説明は変えない。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const MirrorCabinetScript := preload("res://scripts/mirror_cabinet.gd")

const DECAL_DIR := "res://assets/textures/bath/bath_decal_%02d.png"
const LIFT := 0.0015   # 面から浮かせる量（重なりのちらつき防止）

const WASHCLOTH_TEX := preload("res://assets/textures/bath/bath_material_08.png")   # ウォッシュクロス（緑の編み地）

static var _mats := {}
static var _shade_line: GradientTexture2D
static var _shade_blob: GradientTexture2D


func _ready() -> void:
	var room := get_parent()
	_build_walls()
	_build_floor()
	_build_fixtures()
	_build_mirror(room)
	_build_washcloth()
	_build_photo()
	# 浴室用のスリッパ（右の壁ぎわ、入口の手前。洗面台・風呂桶・用具の台から離れている）
	MeshKit.slipper_pair(self, Vector3(0.68, 0.0, 0.98), -6.0, Color(0.55, 0.78, 0.82), Color(0.9, 0.9, 0.88), "BathSlippers")
	_build_contact_shadows()


## 画像 n（02〜10）を、面の法線 normal の向きに貼る。h：高さ（m、幅は画像の比率）、roll：面内の傾き（度）、
## tint：画像の線が淡いので少し暗くしたり、錆に色を乗せたりする。
func decal(parent: Node3D, n: int, h: float, pos: Vector3, normal: Vector3, roll := 0.0, tint := Color.WHITE) -> MeshInstance3D:
	var tex: Texture2D = load(DECAL_DIR % n)
	var key := "%d_%s" % [n, tint.to_html()]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = tint
		m.roughness = 0.9
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	var q := QuadMesh.new()
	q.size = Vector2(h * tex.get_width() / tex.get_height(), h)
	var mi := MeshInstance3D.new()
	mi.name = "Wear%02d_%d" % [n, parent.get_child_count()]
	mi.mesh = q
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nn := normal.normalized()
	var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-nn, up) * Basis(Vector3.BACK, deg_to_rad(roll))
	mi.position = pos + nn * LIFT
	parent.add_child(mi, true)
	return mi


func _build_walls() -> void:
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	# 奥の壁（+z 向き）
	# 昔何かを貼っていたテープ跡。浴槽の上、シャワーバー（x=0.2）から離れた左寄り
	decal(walls, 3, 0.15, Vector3(-0.42, 1.38, -1.2), Vector3.BACK, 2.0, Color(0.9, 0.85, 0.78))
	# シャワーのスライドバーの根元から垂れた水垢（バー x=0.2、上端 1.85）
	decal(walls, 5, 0.42, Vector3(0.2, 1.62, -1.2), Vector3.BACK, 0.0, Color(0.85, 0.82, 0.76))
	# 蛇口の下の水垢（蛇口 x=0.55、y=0.70）
	decal(walls, 5, 0.12, Vector3(0.55, 0.625, -1.2), Vector3.BACK, 0.0, Color(0.85, 0.82, 0.76))
	# 天井際の塗装の欠け（湿気がたまる）と、換気口と反対の隅のひび
	decal(walls, 2, 0.13, Vector3(0.66, 2.1, -1.2), Vector3.BACK, 12.0, Color(0.95, 0.92, 0.86))
	decal(walls, 10, 0.34, Vector3(-0.7, 1.72, -1.2), Vector3.BACK, 0.0, Color(0.5, 0.45, 0.4))
	# 左の壁（+x 向き）：タオル掛けの留め具（z=0.50、y=1.15）の下に錆、床際にも錆
	decal(walls, 7, 0.13, Vector3(-0.9, 1.07, 0.50), Vector3.RIGHT, 0.0, Color(1, 1, 1))
	decal(walls, 7, 0.14, Vector3(-0.9, 0.085, 0.83), Vector3.RIGHT, 0.0, Color(0.9, 0.85, 0.8))
	# 右の壁（-x 向き）：洗面台の上の石けんの飛沫、入口側の壁の下の擦り傷
	decal(walls, 6, 0.15, Vector3(0.9, 0.99, 0.27), Vector3.LEFT, 20.0, Color(0.95, 0.95, 0.92))
	decal(walls, 9, 0.12, Vector3(0.9, 0.24, 0.92), Vector3.LEFT, 8.0, Color(0.55, 0.5, 0.45))


func _build_floor() -> void:
	var floor_root := Node3D.new()
	floor_root.name = "Floor"
	add_child(floor_root)
	# 風呂桶（0.74, -0.31）の下の水の輪。輪の中心を桶の底に合わせる
	decal(floor_root, 4, 0.27, Vector3(0.74, 0.0, -0.31), Vector3.UP, 20.0, Color(0.85, 0.82, 0.76))
	# 浴槽の縁からこぼれた石けんの飛沫
	decal(floor_root, 6, 0.2, Vector3(0.28, 0.0, -0.36), Vector3.UP, -30.0, Color(0.95, 0.95, 0.92))
	# 入口の前で靴下や足が擦れる所
	decal(floor_root, 9, 0.22, Vector3(0.08, 0.0, 0.98), Vector3.UP, 70.0, Color(0.45, 0.42, 0.38))


func _build_fixtures() -> void:
	var fx := Node3D.new()
	fx.name = "Fixtures"
	add_child(fx)
	# 浴槽の前面（+z 向き、z=-0.45）の下：足や風呂桶が当たる
	decal(fx, 9, 0.14, Vector3(-0.3, 0.17, -0.45), Vector3.BACK, -8.0, Color(0.5, 0.45, 0.4))
	# 洗面台の棚の上：コップの水の輪（コップ x=0.845、z=0.26）
	decal(fx, 4, 0.085, Vector3(0.845, 1.0755, 0.26), Vector3.UP, 0.0, Color(0.8, 0.78, 0.72))


func _build_mirror(room: Node) -> void:
	# 鏡の扉の取っ手のそば（扉の z 端）の指紋。扉の子にして、開け閉めに合わせて動く。
	var cabinet: Node = room.get("mirror_cabinet")
	if cabinet == null:
		return
	var pivot: Node3D = cabinet.get("door_pivot")
	var oy: Vector2 = MirrorCabinetScript.Y_RANGE
	var h := oy.y - oy.x
	# 鏡面は扉のローカル x=-0.002。-x 向き
	decal(pivot, 8, 0.1, Vector3(-0.0022, h * 0.5 - 0.06, 0.40), Vector3.LEFT, 10.0, Color(0.6, 0.6, 0.6))
	decal(pivot, 8, 0.07, Vector3(-0.0022, h * 0.5 + 0.10, 0.37), Vector3.LEFT, -25.0, Color(0.6, 0.6, 0.6))



## 浴槽の縁（トイレ側）に畳んで置いた緑のウォッシュクロス。縁は幅 0.08m なので 0.075m 幅に畳んでいる。
## 見た目だけ（照準・当たり判定なし）。縁の上面 y=0.55、手前の内壁は z -0.53。
func _build_washcloth() -> void:
	var root := Node3D.new()
	root.name = "Washcloth"
	root.position = Vector3(-0.62, 0.55, -0.49)
	root.rotation.y = deg_to_rad(7.0)
	add_child(root)
	var m := MeshKit.tiled_mat("washcloth", WASHCLOTH_TEX, 0.1, Color(1, 1, 1), 0.95)
	var a := MeshKit.box(root, Vector3(0.15, 0.011, 0.072), Vector3(0, 0.0055, 0), m, "Folded")
	a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b := MeshKit.box(root, Vector3(0.13, 0.008, 0.066), Vector3(0.006, 0.015, 0.001), m, "FoldTop")
	b.rotation.y = deg_to_rad(-4.0)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- 接地影（AO の代わり）
## GL Compatibility では SSAO が使えないので、壁と床・壁と壁・壁と天井の合わせ目に、
## 暗い透明グラデーションの薄い板を置いて、隅の暗さを足す。見た目だけで、影は落とさない。

func _shade_mat(blob: bool, alpha: float) -> StandardMaterial3D:
	var key := "shade_%s_%.2f" % [blob, alpha]
	if _mats.has(key):
		return _mats[key]
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.08, 0.05, 0.02, alpha), Color(0.08, 0.05, 0.02, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	if blob:
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 1.0)
	else:
		t.fill = GradientTexture2D.FILL_LINEAR
		t.fill_from = Vector2(0.5, 1.0)   # 板の下端（壁・床に接する縁）が最も濃い
		t.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = -1
	_mats[key] = m
	return m


## 壁際の帯：center の位置に、normal を向いた面（床なら UP）で、along 方向に length、inward 方向に width。
## 帯の濃い縁は inward の反対側（壁側）。
func _strip(parent: Node3D, center: Vector3, normal: Vector3, along: Vector3, inward: Vector3, length: float, width: float, alpha: float) -> void:
	var x := along.normalized()
	var y := inward.normalized()
	var z := normal.normalized()
	if x.cross(y).dot(z) < 0.0:
		x = -x
	var q := QuadMesh.new()
	q.size = Vector2(length, width)
	var mi := MeshInstance3D.new()
	mi.name = "Shade"
	mi.mesh = q
	mi.material_override = _shade_mat(false, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = Basis(x, y, z)
	mi.position = center + z * 0.0008
	parent.add_child(mi)


func _blob(parent: Node3D, center: Vector3, size: Vector2, alpha: float) -> void:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "ShadeBlob"
	mi.mesh = q
	mi.material_override = _shade_mat(true, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	mi.position = center + Vector3.UP * 0.0006
	parent.add_child(mi)


func _build_contact_shadows() -> void:
	var root := Node3D.new()
	root.name = "ContactShade"
	add_child(root)
	var hw := 0.9
	var hd := 1.2
	var hh := 2.2
	var w := 0.16
	# 床と壁の合わせ目（床の上、壁から w の幅）
	_strip(root, Vector3(-hw + w * 0.5, 0.0, 0.375), Vector3.UP, Vector3.BACK, Vector3.RIGHT, 1.65, w, 0.3)   # 左（トイレ側）
	_strip(root, Vector3(hw - w * 0.5, 0.0, 0.375), Vector3.UP, Vector3.BACK, Vector3.LEFT, 1.65, w, 0.3)    # 右（洗面台側）
	_strip(root, Vector3(0.0, 0.0, -0.45 + w * 0.5), Vector3.UP, Vector3.RIGHT, Vector3.BACK, 1.8, w, 0.32)  # 浴槽の前
	_strip(root, Vector3(-0.63, 0.0, hd - w * 0.5), Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, 0.54, w, 0.3)   # 入口の左右の足元
	_strip(root, Vector3(0.63, 0.0, hd - w * 0.5), Vector3.UP, Vector3.RIGHT, Vector3.FORWARD, 0.54, w, 0.3)
	# 壁と天井の合わせ目（天井に近い壁の上端）
	var tw := 0.14
	_strip(root, Vector3(0.0, hh - tw * 0.5, -hd), Vector3.BACK, Vector3.RIGHT, Vector3.DOWN, 1.8, tw, 0.22)
	_strip(root, Vector3(-hw, hh - tw * 0.5, 0.0), Vector3.RIGHT, Vector3.BACK, Vector3.DOWN, 2.4, tw, 0.22)
	_strip(root, Vector3(hw, hh - tw * 0.5, 0.0), Vector3.LEFT, Vector3.BACK, Vector3.DOWN, 2.4, tw, 0.22)
	# 壁と壁の隅（縦の帯）。ドア側の隅は開口があるので奥の2隅と、手前の両脇だけ
	var vw := 0.09
	for sx in [-1.0, 1.0]:
		_strip(root, Vector3(sx * (hw - vw * 0.5), hh * 0.5, -hd), Vector3.BACK, Vector3.UP, Vector3(-sx, 0, 0), hh, vw, 0.2)
		_strip(root, Vector3(sx * hw, hh * 0.5, -hd + vw * 0.5), Vector3(-sx, 0, 0), Vector3.UP, Vector3.BACK, hh, vw, 0.2)
	# 置いてある物の下の丸い影
	_blob(root, Vector3(0.74, 0.0, -0.31), Vector2(0.36, 0.36), 0.4)   # 風呂桶
	_blob(root, Vector3(-0.8, 0.0, 1.06), Vector2(0.28, 0.4), 0.4)     # トイレ用具の台


## 洗面台の右、入口側の壁の小さな額（room_overhead_01：部屋を上から描いた絵）。
## 右の壁（x=0.9）の z 0.55〜0.89、高さ 1.3m。入口の動線（z 1.0 以降）と洗面台（z 0.35 まで）の間で、物も通路も覆わない。
## 実際の間取りを保証する図でも手がかりでもない、飾りの絵。見た目だけ（調べる判定なし）。
func _build_photo() -> void:
	var tex: Texture2D = load("res://assets/textures/room/room_overhead_01.png")
	var w := 0.30
	var h := w * tex.get_height() / tex.get_width()
	var root := Node3D.new()
	root.name = "OverheadPicture"
	root.position = Vector3(0.9, 1.3, 0.72)
	add_child(root)
	var frame_mat := MeshKit.mat("photo_frame", Color(0.16, 0.13, 0.11), 0.6)
	var fw := 0.012
	MeshKit.box(root, Vector3(0.012, h + fw * 2.0, fw), Vector3(-0.006, 0, -(w * 0.5 + fw * 0.5)), frame_mat, "FrameL")
	MeshKit.box(root, Vector3(0.012, h + fw * 2.0, fw), Vector3(-0.006, 0, w * 0.5 + fw * 0.5), frame_mat, "FrameR")
	MeshKit.box(root, Vector3(0.012, fw, w), Vector3(-0.006, h * 0.5 + fw * 0.5, 0), frame_mat, "FrameT")
	MeshKit.box(root, Vector3(0.012, fw, w), Vector3(-0.006, -(h * 0.5 + fw * 0.5), 0), frame_mat, "FrameB")
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.name = "Picture"
	mi.mesh = q
	mi.material_override = MeshKit.texture_mat("room_overhead_01", tex, 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(-0.0045, 0, 0)
	mi.rotation.y = -PI * 0.5   # 表を部屋側（-x）へ
	root.add_child(mi)
