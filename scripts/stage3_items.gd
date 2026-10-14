extends RefCounted
## 段階 3 の持ち物の拡大モデルと、燃える松明（ベランダに捨てた松明）。見た目だけ。

const MeshKit := preload("res://scripts/mesh_kit.gd")


static func match_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.004, 0.09, Vector3.ZERO, MeshKit.mat("match_wood", Color(0.82, 0.68, 0.42), 0.8), "Stick", -1.0, 6)
	MeshKit.sphere(n, 0.008, Vector3(0, 0.048, 0), MeshKit.mat("match_head", Color(0.78, 0.12, 0.08), 0.6))
	n.rotation.z = deg_to_rad(40.0)
	return n


static func key_model() -> Node3D:
	var n := Node3D.new()
	var brass := MeshKit.mat("key_brass", Color(0.78, 0.6, 0.2), 0.35, 0.8)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.012
	ring.outer_radius = 0.022
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = brass
	ring_mi.position = Vector3(0, 0.05, 0)
	ring_mi.rotation.x = deg_to_rad(90.0)
	n.add_child(ring_mi)
	MeshKit.box(n, Vector3(0.008, 0.07, 0.006), Vector3(0, 0.0, 0), brass, "Shaft")
	MeshKit.box(n, Vector3(0.02, 0.008, 0.006), Vector3(0.012, -0.03, 0), brass, "Tooth1")
	MeshKit.box(n, Vector3(0.016, 0.008, 0.006), Vector3(0.01, -0.015, 0), brass, "Tooth2")
	return n


## 松明（木の棒の先に炎）。拡大表示と、手に持ったときの見た目に使う。
static func torch_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.016, 0.5, Vector3.ZERO, MeshKit.mat("torch_wood", Color(0.5, 0.38, 0.26), 0.85), "Stick", 0.013, 8)
	MeshKit.cylinder(n, 0.026, 0.07, Vector3(0, 0.28, 0), MeshKit.mat("torch_char", Color(0.12, 0.08, 0.06), 0.9), "Char", 0.018, 8)
	_flame(n, Vector3(0, 0.36, 0))
	return n


static func _flame(parent: Node3D, pos: Vector3) -> void:
	var outer := MeshKit.mat("flame_outer", Color(1.0, 0.45, 0.1), 0.5)
	outer.emission_enabled = true
	outer.emission = Color(1.0, 0.45, 0.1)
	outer.emission_energy_multiplier = 2.5
	var inner := MeshKit.mat("flame_inner", Color(1.0, 0.9, 0.5), 0.5)
	inner.emission_enabled = true
	inner.emission = Color(1.0, 0.9, 0.5)
	inner.emission_energy_multiplier = 3.0
	var f1 := MeshKit.cylinder(parent, 0.028, 0.1, pos + Vector3(0, 0.04, 0), outer, "Flame", 0.0, 8)
	f1.name = "Flame"
	MeshKit.cylinder(parent, 0.014, 0.06, pos + Vector3(0, 0.025, 0), inner, "FlameCore", 0.0, 8)


static func knob_model() -> Node3D:
	var n := Node3D.new()
	var brass := MeshKit.mat("knob_brass", Color(0.85, 0.65, 0.22), 0.3, 0.8)
	brass.emission_enabled = true   # 暗い中でも、床で小さく光って見つけやすい
	brass.emission = Color(0.9, 0.7, 0.25)
	brass.emission_energy_multiplier = 0.45
	MeshKit.sphere(n, 0.04, Vector3(0, 0.03, 0), brass)
	MeshKit.cylinder(n, 0.01, 0.04, Vector3(0, -0.015, 0), brass, "Neck", -1.0, 10)
	MeshKit.box(n, Vector3(0.016, 0.03, 0.006), Vector3(0, -0.05, 0), MeshKit.mat("knob_spindle", Color(0.55, 0.55, 0.58), 0.4, 0.7), "Spindle")
	n.rotation.z = deg_to_rad(15.0)
	return n


static func fuse_model() -> Node3D:
	var n := Node3D.new()
	var glass := MeshKit.mat("fuse_glass", Color(0.85, 0.9, 0.95, 0.6), 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	MeshKit.cylinder(n, 0.009, 0.05, Vector3.ZERO, glass, "Body", -1.0, 10).rotation.z = deg_to_rad(90.0)
	var cap := MeshKit.mat("fuse_cap", Color(0.8, 0.8, 0.84), 0.3, 0.85)
	cap.emission_enabled = true
	cap.emission = Color(0.8, 0.85, 1.0)
	cap.emission_energy_multiplier = 0.4
	for sx in [-0.026, 0.026]:
		MeshKit.cylinder(n, 0.01, 0.012, Vector3(sx, 0, 0), cap, "Cap", -1.0, 10).rotation.z = deg_to_rad(90.0)
	MeshKit.box(n, Vector3(0.05, 0.0015, 0.0015), Vector3.ZERO, MeshKit.mat("fuse_wire", Color(0.6, 0.6, 0.6), 0.4, 0.9), "Wire")
	return n
