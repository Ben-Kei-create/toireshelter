extends RefCounted
## 段階 4 の持ち物の拡大モデル：手かがみ・ツルハシ・結晶・栞（犬・猿・キジ）・ライター・はしご・家宝の写真・ご飯と卵と TKG。見た目だけ。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Silhouettes := preload("res://scripts/silhouettes.gd")


static func hand_mirror_model() -> Node3D:
	var n := Node3D.new()
	var rim := MeshKit.mat("hm_rim", Color(0.78, 0.62, 0.25), 0.3, 0.8)
	var glass := MeshKit.mat("hm_glass", Color(0.8, 0.9, 0.98), 0.05, 0.95)
	MeshKit.cylinder(n, 0.06, 0.008, Vector3(0, 0.09, 0), rim, "Rim", -1.0, 24).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.052, 0.01, Vector3(0, 0.09, 0.002), glass, "Glass", -1.0, 24).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.011, 0.1, Vector3(0, 0.0, 0), rim, "Handle", 0.008, 10)
	return n


static func pickaxe_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.014, 0.5, Vector3.ZERO, MeshKit.mat("pick_wood", Color(0.5, 0.36, 0.22), 0.8), "Handle", 0.012, 8)
	var iron := MeshKit.mat("pick_iron", Color(0.38, 0.4, 0.44), 0.4, 0.7)
	MeshKit.box(n, Vector3(0.26, 0.03, 0.03), Vector3(0, 0.25, 0), iron, "Head")
	MeshKit.box(n, Vector3(0.05, 0.05, 0.035), Vector3(0, 0.24, 0), iron, "Collar")
	for sx in [-1.0, 1.0]:
		var tip := MeshKit.cylinder(n, 0.012, 0.07, Vector3(sx * 0.15, 0.25, 0), iron, "Tip", 0.0, 6)
		tip.rotation.z = -sx * deg_to_rad(90.0)
	return n


static func crystal_model() -> Node3D:
	var n := Node3D.new()
	var m := MeshKit.mat("crystal", Color(0.55, 0.4, 0.95, 0.72), 0.1, 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.45, 0.3, 0.9)
	m.emission_energy_multiplier = 0.5
	for i in 4:
		var c := MeshKit.cylinder(n, 0.016 + 0.004 * (i % 2), 0.07 + 0.03 * i, Vector3(0.02 * (i - 1.5), 0.04 + 0.012 * i, 0.01 * (i % 2)), m, "Shard", 0.0, 6)
		c.rotation.z = deg_to_rad(-12.0 + 8.0 * i)
	return n


## 栞：細長い紙に、影絵と房。kind：dog／monkey／pheasant。
static func bookmark_model(kind: String) -> Node3D:
	var n := Node3D.new()
	var paper := MeshKit.mat("bm_paper", Color(0.93, 0.88, 0.72), 0.9)
	MeshKit.box(n, Vector3(0.05, 0.16, 0.003), Vector3.ZERO, paper, "Card")
	var q := QuadMesh.new()
	q.size = Vector2(0.045, 0.045)
	var m := StandardMaterial3D.new()
	m.albedo_texture = Silhouettes.texture(kind)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = Vector3(0, 0.02, 0.002)
	n.add_child(mi)
	MeshKit.cylinder(n, 0.004, 0.05, Vector3(0, -0.095, 0), MeshKit.mat("bm_tassel", Color(0.7, 0.15, 0.15), 0.8), "Tassel", 0.0, 6)
	return n


static func lighter_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.035, 0.06, 0.012), Vector3.ZERO, MeshKit.mat("lighter_body", Color(0.8, 0.2, 0.15), 0.4, 0.4), "Body")
	MeshKit.box(n, Vector3(0.033, 0.014, 0.011), Vector3(0, 0.037, 0), MeshKit.mat("lighter_cap", Color(0.75, 0.75, 0.78), 0.3, 0.9), "Cap")
	return n


static func ladder_model() -> Node3D:
	var n := Node3D.new()
	var wood := MeshKit.mat("ladder_wood", Color(0.55, 0.4, 0.26), 0.85)
	for sx in [-0.18, 0.18]:
		MeshKit.box(n, Vector3(0.04, 2.3, 0.04), Vector3(sx, 1.15, 0), wood, "Rail")
	for i in 8:
		MeshKit.box(n, Vector3(0.36, 0.035, 0.035), Vector3(0, 0.25 + i * 0.28, 0), wood, "Rung")
	return n


## 家宝の写真『おふくろのTKG』。
static func photo_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.14, 0.1, 0.004), Vector3.ZERO, MeshKit.mat("photo_white", Color(0.95, 0.94, 0.9), 0.8), "Frame")
	MeshKit.box(n, Vector3(0.12, 0.075, 0.005), Vector3(0, 0.005, 0.0005), MeshKit.mat("photo_img", Color(0.9, 0.78, 0.42), 0.7), "Image")
	MeshKit.cylinder(n, 0.028, 0.006, Vector3(0, 0.005, 0.004), MeshKit.mat("photo_rice", Color(0.97, 0.96, 0.92), 0.6), "Rice", -1.0, 16).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.013, 0.006, Vector3(0, 0.008, 0.007), MeshKit.mat("photo_yolk", Color(0.98, 0.75, 0.12), 0.4), "Yolk", -1.0, 12).rotation.x = deg_to_rad(90.0)
	return n


static func rice_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.12, 0.035, 0.09), Vector3.ZERO, MeshKit.mat("rice_pack", Color(0.95, 0.95, 0.97), 0.5), "Pack")
	MeshKit.box(n, Vector3(0.1, 0.004, 0.07), Vector3(0, 0.02, 0), MeshKit.mat("rice_lid", Color(0.3, 0.55, 0.85), 0.5), "Lid")
	return n


static func egg_model() -> Node3D:
	var n := Node3D.new()
	var e := MeshKit.sphere(n, 0.028, Vector3.ZERO, MeshKit.mat("egg_shell", Color(0.93, 0.85, 0.72), 0.5))
	e.scale = Vector3(1.0, 1.25, 1.0)
	return n


static func tkg_model(hot: bool) -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.05, 0.035, Vector3.ZERO, MeshKit.mat("bowl", Color(0.35, 0.45, 0.65), 0.4), "Bowl", 0.032, 18)
	MeshKit.cylinder(n, 0.046, 0.02, Vector3(0, 0.022, 0), MeshKit.mat("tkg_rice", Color(0.97, 0.96, 0.92), 0.6), "Rice", 0.042, 18)
	var yolk := MeshKit.mat("tkg_yolk", Color(0.98, 0.72, 0.1) if hot else Color(0.85, 0.7, 0.3), 0.4)
	MeshKit.sphere(n, 0.022, Vector3(0, 0.04, 0), yolk).scale = Vector3(1.0, 0.5, 1.0)
	return n
