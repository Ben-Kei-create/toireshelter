extends RefCounted
## 置物の絵（assets/textures/figures/fig_01〜48.png。透明な背景の切り抜き）の使い方。
##   ornament() … 動かない置物。2 枚の板を十字に組んで立たせる（どの向きからでも絵が見える）。コルク銃で撃っても、びくともしない。
##   sticker()  … ペタペタ貼るシール。壁や床に、絵を平らに貼る。
## 置物 9 点（ORNAMENTS）と、シール 39 点（STICKERS）に分けて使う（合わせて 48 点）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const DIR := "res://assets/textures/figures/"

## 置物にする絵（やさしい形のもの）：手のひらの太陽・貝の扉・市松のうさぎ・みかんの家・サボテンの頭像・眠る三日月・折り鶴・渦巻きの本棚・黒猫と白猫。
const ORNAMENTS := [2, 3, 5, 6, 7, 8, 10, 11, 12]
## 残りは、シールにして貼る。
const STICKERS := [1, 4, 9, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48]

static var _mats := {}


static func texture(i: int) -> Texture2D:
	return load(DIR + "fig_%02d.png" % i)


static func _material(i: int) -> StandardMaterial3D:
	if not _mats.has(i):
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture(i)
		m.roughness = 0.7
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[i] = m
	return _mats[i]


## 動かない置物。pos は足元（台の上面）、h は高さ（m）、yaw はまわす向き。
static func ornament(parent: Node3D, i: int, h: float, pos: Vector3, yaw := 0.0) -> Node3D:
	var tex := texture(i)
	var w := h * float(tex.get_width()) / float(tex.get_height())
	var n := Node3D.new()
	n.name = "Ornament%02d" % i
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	for k in 2:
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		var mi := MeshInstance3D.new()
		mi.name = "Face%d" % k
		mi.mesh = q
		mi.material_override = _material(i)
		mi.position = Vector3(0, h * 0.5, 0)
		mi.rotation.y = PI * 0.5 * k
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	# 足元の小さな影
	var shadow := MeshKit.cylinder(n, w * 0.38, 0.002, Vector3(0, 0.001, 0), MeshKit.mat("ornament_shadow", Color(0.05, 0.04, 0.04, 0.55), 1.0), "Shadow", -1.0, 16)
	(shadow.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# 調べる判定（撃っても動かない）
	var area := MeshKit.interact_area(n, "OrnamentArea", "ornament")
	MeshKit.shape_box(area, Vector3(w, h, w * 0.5), Vector3(0, h * 0.5, 0))
	return n


## 壁や床にペタペタ貼るシール。normal は貼る面の向き（面から外向き）、roll は傾き（度）。
static func sticker(parent: Node3D, i: int, h: float, pos: Vector3, normal: Vector3, roll := 0.0) -> MeshInstance3D:
	var tex := texture(i)
	var q := QuadMesh.new()
	q.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
	var mi := MeshInstance3D.new()
	mi.name = "FigureSticker%02d" % i
	mi.mesh = q
	mi.material_override = _material(i)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nn := normal.normalized()
	var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-nn, up) * Basis(Vector3.BACK, deg_to_rad(roll))
	mi.position = pos + nn * 0.0015
	parent.add_child(mi)
	return mi
