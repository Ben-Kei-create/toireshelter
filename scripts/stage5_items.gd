extends RefCounted
## 段階 5 の持ち物の拡大モデル：つかみ取りの景品 8 つ（小さな懐中電灯・虫眼鏡・磁石付きの釣り針・耳栓・パックご飯・家の鍵・吹き矢の材料・麻雀牌の東と中）、
## 悪口本（黒塗り・流したあと）、白紙のトランプ、金庫の景品一覧表。見た目だけ。

const MeshKit := preload("res://scripts/mesh_kit.gd")


static func flashlight_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.015, 0.1, Vector3.ZERO, MeshKit.mat("fl_body", Color(0.2, 0.22, 0.28), 0.4, 0.6), "Body", -1.0, 12)
	MeshKit.cylinder(n, 0.022, 0.03, Vector3(0, 0.065, 0), MeshKit.mat("fl_head", Color(0.65, 0.66, 0.7), 0.3, 0.85), "Head", 0.016, 12)
	var lens := MeshKit.mat("fl_lens", Color(1.0, 0.95, 0.7), 0.2)
	lens.emission_enabled = true
	lens.emission = Color(1.0, 0.95, 0.7)
	lens.emission_energy_multiplier = 1.0
	MeshKit.cylinder(n, 0.018, 0.004, Vector3(0, 0.082, 0), lens, "Lens", -1.0, 12)
	return n


static func magnifier_model() -> Node3D:
	var n := Node3D.new()
	var rim := MeshKit.mat("mag_rim", Color(0.2, 0.18, 0.15), 0.4, 0.5)
	var glass := MeshKit.mat("mag_glass", Color(0.8, 0.92, 0.98, 0.4), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	MeshKit.cylinder(n, 0.045, 0.006, Vector3(0, 0.08, 0), rim, "Rim", -1.0, 20).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.04, 0.007, Vector3(0, 0.08, 0.001), glass, "Glass", -1.0, 20).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.009, 0.09, Vector3(0, 0.0, 0), MeshKit.mat("mag_handle", Color(0.5, 0.32, 0.18), 0.7), "Handle", 0.007, 8)
	return n


static func magnet_hook_model() -> Node3D:
	var n := Node3D.new()
	var steel := MeshKit.mat("hook_steel", Color(0.7, 0.72, 0.75), 0.3, 0.9)
	MeshKit.cylinder(n, 0.003, 0.08, Vector3.ZERO, steel, "Shank", -1.0, 6)
	var t := TorusMesh.new()
	t.inner_radius = 0.012
	t.outer_radius = 0.018
	var hook := MeshInstance3D.new()
	hook.mesh = t
	hook.material_override = steel
	hook.position = Vector3(0.015, -0.04, 0)
	hook.rotation.x = deg_to_rad(90.0)
	n.add_child(hook)
	var red := MeshKit.mat("magnet_red", Color(0.85, 0.15, 0.12), 0.4)
	var blue := MeshKit.mat("magnet_blue", Color(0.2, 0.3, 0.85), 0.4)
	MeshKit.box(n, Vector3(0.03, 0.016, 0.016), Vector3(-0.012, 0.05, 0), red, "MagnetN")
	MeshKit.box(n, Vector3(0.03, 0.016, 0.016), Vector3(0.018, 0.05, 0), blue, "MagnetS")
	return n


static func earplugs_model() -> Node3D:
	var n := Node3D.new()
	var m := MeshKit.mat("earplug", Color(0.98, 0.6, 0.18), 0.8)
	for sx in [-0.02, 0.02]:
		MeshKit.cylinder(n, 0.012, 0.03, Vector3(sx, 0, 0), m, "Plug", 0.007, 10)
	MeshKit.pipe(n, [Vector3(-0.02, 0.016, 0), Vector3(0, 0.04, 0), Vector3(0.02, 0.016, 0)], 0.0018, MeshKit.mat("earplug_cord", Color(0.2, 0.2, 0.22), 0.8))
	return n


static func home_key_model() -> Node3D:
	var n := Node3D.new()
	var steel := MeshKit.mat("homekey_steel", Color(0.78, 0.78, 0.82), 0.25, 0.9)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.013
	ring.outer_radius = 0.024
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = steel
	ring_mi.position = Vector3(0, 0.055, 0)
	ring_mi.rotation.x = deg_to_rad(90.0)
	n.add_child(ring_mi)
	MeshKit.box(n, Vector3(0.01, 0.08, 0.004), Vector3(0, 0.0, 0), steel, "Shaft")
	for k in 4:
		MeshKit.box(n, Vector3(0.016, 0.007, 0.004), Vector3(0.012, -0.03 + k * 0.012, 0), steel, "Tooth%d" % k)
	MeshKit.box(n, Vector3(0.03, 0.02, 0.003), Vector3(0.0, 0.078, 0), MeshKit.mat("homekey_tag", Color(0.9, 0.3, 0.25), 0.6), "Tag")
	return n


static func blowgun_part_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.012, 0.05, Vector3.ZERO, MeshKit.mat("bg_pipe", Color(0.78, 0.74, 0.62), 0.6), "Mouthpiece", 0.009, 12).rotation.z = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.014, 0.012, Vector3(0.03, 0, 0), MeshKit.mat("bg_cap", Color(0.3, 0.3, 0.34), 0.4, 0.6), "Cap", -1.0, 12).rotation.z = deg_to_rad(90.0)
	return n


static func mahjong_tiles_model() -> Node3D:
	var n := Node3D.new()
	var body := MeshKit.mat("mj_tile", Color(0.96, 0.95, 0.88), 0.4)
	var back := MeshKit.mat("mj_back", Color(0.12, 0.45, 0.28), 0.5)
	for i in 2:
		MeshKit.box(n, Vector3(0.026, 0.036, 0.016), Vector3(-0.018 + i * 0.036, 0, 0), body, "Tile%d" % i)
		MeshKit.box(n, Vector3(0.026, 0.036, 0.006), Vector3(-0.018 + i * 0.036, 0, -0.011), back, "Back%d" % i)
	return n


## 悪口本：黒く塗りつぶされた本。流したあとは、水に濡れて黒が落ち、文字が読める。
static func bad_book_model(wet: bool) -> Node3D:
	var n := Node3D.new()
	var cover := MeshKit.mat("badbook_wet" if wet else "badbook_black", Color(0.28, 0.27, 0.3) if wet else Color(0.02, 0.02, 0.025), 0.5)
	MeshKit.box(n, Vector3(0.15, 0.2, 0.035), Vector3.ZERO, cover, "Book")
	MeshKit.box(n, Vector3(0.14, 0.19, 0.03), Vector3(0.003, 0, 0), MeshKit.mat("badbook_pages", Color(0.55, 0.52, 0.45) if wet else Color(0.04, 0.04, 0.04), 0.9), "Pages")
	return n


## 白紙のトランプ：青い光の下では、点の数が光って見える（dots）。普通の光では、ただの白いカード。
static func blank_card_model(dots: int, lit: bool) -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.07, 0.1, 0.003), Vector3.ZERO, MeshKit.mat("blank_card", Color(0.96, 0.95, 0.92), 0.7), "Card")
	if lit:
		var glow := MeshKit.mat("blank_card_dot", Color(0.3, 0.5, 1.0), 0.4)
		glow.emission_enabled = true
		glow.emission = Color(0.3, 0.5, 1.0)
		glow.emission_energy_multiplier = 2.2
		for i in dots:
			var col := i % 3
			var row := i / 3
			MeshKit.cylinder(n, 0.008, 0.002, Vector3(-0.02 + col * 0.02, 0.03 - row * 0.022, 0.002), glow, "Dot%d" % i, -1.0, 10).rotation.x = deg_to_rad(90.0)
	return n


static func tp_core_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.02, 0.105, Vector3.ZERO, MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9), "Core", -1.0, 16).rotation.x = deg_to_rad(90.0)
	return n


static func telescope_model() -> Node3D:
	var n := Node3D.new()
	var core := MeshKit.cylinder(n, 0.02, 0.105, Vector3.ZERO, MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9), "Tube", -1.0, 16)
	core.rotation.x = deg_to_rad(90.0)
	var m := MeshKit.mat("crystal", Color(0.55, 0.4, 0.95, 0.72), 0.1, 0.1)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.45, 0.3, 0.9)
	m.emission_energy_multiplier = 0.6
	MeshKit.cylinder(n, 0.019, 0.012, Vector3(0, 0, -0.055), m, "Lens", -1.0, 16).rotation.x = deg_to_rad(90.0)
	return n


static func blowgun_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.cylinder(n, 0.02, 0.105, Vector3.ZERO, MeshKit.mat("paper_core", Color(0.7, 0.6, 0.48), 0.9), "Tube", -1.0, 16).rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(n, 0.016, 0.03, Vector3(0, 0, 0.07), MeshKit.mat("blowgun_mouth", Color(0.9, 0.9, 0.92), 0.4, 0.6), "Mouth", -1.0, 12).rotation.x = deg_to_rad(90.0)
	return n


static func medal_model() -> Node3D:
	var n := Node3D.new()
	var m := MeshKit.mat("medal_gold", Color(0.9, 0.75, 0.25), 0.3, 0.7)
	MeshKit.cylinder(n, 0.03, 0.005, Vector3.ZERO, m, "Medal", -1.0, 24).rotation.x = deg_to_rad(90.0)
	return n


static func prize_list_model() -> Node3D:
	var n := Node3D.new()
	MeshKit.box(n, Vector3(0.12, 0.17, 0.003), Vector3.ZERO, MeshKit.mat("prize_paper", Color(0.93, 0.9, 0.78), 0.9), "Paper")
	for i in 8:
		MeshKit.box(n, Vector3(0.08, 0.004, 0.0012), Vector3(0, 0.07 - i * 0.017, 0.002), MeshKit.mat("prize_line", Color(0.2, 0.18, 0.16), 0.9), "Line%d" % i)
	return n
