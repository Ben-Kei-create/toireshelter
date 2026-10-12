extends Node3D
## 5階の共用廊下（玄関ドアの外）と、その西側に広がる下北沢（異世界）の街並み。座標は部屋と同じ（この節点は原点に置く）。
##
## 上から見た配置（図：部屋と通路と外の景色）
##        N（-z）                          自室・浴室はこの右（東）
##   ┌──────────────┐ z=-1.3  北の端（壁）
##   │ 西の手すり     │ 東の壁 x=-1.0：浴室の壁・玄関ホールの壁（玄関ドア z 1.5〜2.2 = 505）
##   │ x=-2.7         │ z 2.4 から南は、ほかの部屋の玄関ドア 504（z 3.5）・503（z 5.2）
##   └─── エレベーター ┘ z=6.4  南の端（エレベーター。手すり側が下北沢の街並み）
## 廊下は幅1.7m（x -2.7〜-1.0）、天井 2.6m、長さ 7.7m（z -1.3〜6.4）。西側は腰壁（1.1m）の上が開いていて、街並みが見える。
## 街並み：5階の高さから、道を挟んだ低い建物の屋根と看板、その向こうの高い建物、遠景の影。地面は 4 階ぶん（13.6m）下。
## 見た目だけの背景（街は入れない）。廊下の中は歩ける。外へ落ちないよう、手すりの位置に高い壁の当たり判定がある。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const STREET := "res://assets/textures/street/"
const TEX_CONCRETE := preload("res://assets/textures/street/ext_material_04.png")
const TEX_STUCCO := preload("res://assets/textures/street/ext_material_05.png")
const TEX_FACADE := preload("res://assets/textures/surfaces/surface_10.png")
const TEX_METAL := preload("res://assets/textures/bath/bath_material_04.png")   # 横縞の金属（エレベーターの扉）
const FLOOR_PITCH := 3.4

const X0 := -2.7
const X1 := -1.0
const Z0 := -1.3
const Z1 := 6.4
const H := 2.6
const GROUND_Y := -4.0 * FLOOR_PITCH

var _rng := RandomNumberGenerator.new()


## 足元 p が廊下の中か（玄関ドアの敷居 x -1.0 より外）。
static func in_corridor(p: Vector3) -> bool:
	return p.x < X1 - 0.05 and p.x > X0 - 0.05 and p.z > Z0 and p.z < Z1 + 0.05 and p.y > -0.3 and p.y < 2.3


func _ready() -> void:
	_rng.seed = 5050
	MeshKit.auto_round = false
	_build_shell()
	_build_east_wall()
	_build_doors()
	_build_elevator()
	_build_lights()
	_build_town()
	MeshKit.auto_round = true


func _solid(parent: Node3D, body: StaticBody3D, size: Vector3, center: Vector3, m: Material, node_name := "") -> void:
	MeshKit.box(parent, size, center, m, node_name)
	MeshKit.shape_box(body, size, center)


func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	add_child(shell)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	shell.add_child(body)
	var w := X1 - X0
	var l := Z1 - Z0
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + Z1) * 0.5
	var floor_m := MeshKit.tiled_mat("corr_floor", TEX_CONCRETE, 1.0, Color(0.8, 0.8, 0.78), 0.9)
	var wall_m := MeshKit.tiled_mat("corr_stucco", TEX_STUCCO, 1.5, Color(0.9, 0.88, 0.84), 0.95)
	var ceil_m := MeshKit.mat("corr_ceiling", Color(0.82, 0.82, 0.8), 0.9)
	_solid(shell, body, Vector3(w + 0.2, 0.2, l + 0.1), Vector3(cx - 0.05, -0.1, cz), floor_m, "Floor")
	MeshKit.box(shell, Vector3(w + 0.2, 0.2, l + 0.2), Vector3(cx - 0.05, H + 0.1, cz), ceil_m, "Ceiling")
	# 北の端と南の端（エレベーターのある壁）
	_solid(shell, body, Vector3(w + 0.2, H, 0.1), Vector3(cx - 0.05, H * 0.5, Z0 - 0.05), wall_m, "NorthWall")
	_solid(shell, body, Vector3(w + 0.2, H, 0.1), Vector3(cx - 0.05, H * 0.5, Z1 + 0.05), wall_m, "SouthWall")
	# 西の腰壁（コンクリート 1.1m）と笠木の手すり。その上は開いているが、体は出られない（見えない壁を天井まで）
	var parapet := MeshKit.tiled_mat("corr_parapet", TEX_CONCRETE, 1.0, Color(0.72, 0.72, 0.7), 0.95)
	MeshKit.box(shell, Vector3(0.14, 1.1, l), Vector3(X0 + 0.07, 0.55, cz), parapet, "Parapet")
	MeshKit.box(shell, Vector3(0.2, 0.05, l), Vector3(X0 + 0.07, 1.125, cz), MeshKit.mat("corr_cap", Color(0.45, 0.45, 0.46), 0.5, 0.5), "Cap")
	MeshKit.shape_box(body, Vector3(0.2, H, l), Vector3(X0 + 0.07, H * 0.5, cz))
	# 壁の上端（2.2〜2.6）は街側にも壁があるように見えるのを避け、柱だけ（北と南の端、中央）
	var col_m := MeshKit.tiled_mat("corr_col", TEX_STUCCO, 1.5, Color(0.85, 0.83, 0.8), 0.95)
	for zz in [Z0 + 0.1, (Z0 + Z1) * 0.5, Z1 - 0.1]:
		MeshKit.box(shell, Vector3(0.2, H - 1.1, 0.2), Vector3(X0 + 0.07, 1.1 + (H - 1.1) * 0.5, zz), col_m, "Pillar")
	# 排水の溝（西の腰壁の足元）
	MeshKit.box(shell, Vector3(0.1, 0.01, l - 0.2), Vector3(X0 + 0.3, 0.006, cz), MeshKit.mat("corr_gutter", Color(0.18, 0.18, 0.18), 0.9), "Gutter")


## 東の壁（x=-1.0）の外側：浴室・玄関ホールの壁には化粧の板を貼り、z 2.4 から南は新しい壁。
## 玄関ドアの開口（z 1.5〜2.2、高さ 2.0）は空けておく。
func _build_east_wall() -> void:
	var wall := Node3D.new()
	wall.name = "EastWall"
	add_child(wall)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	wall.add_child(body)
	var m := MeshKit.tiled_mat("corr_stucco", TEX_STUCCO, 1.5, Color(0.9, 0.88, 0.84), 0.95)
	var t := 0.02   # 浴室・ホールの外壁（面 x=-1.0）に重ねる厚み
	var fx := X1 - t * 0.5
	var dz := Vector2(1.5, 2.2)
	MeshKit.box(wall, Vector3(t, 2.2, dz.x - Z0), Vector3(fx, 1.1, (Z0 + dz.x) * 0.5), m, "CladdingNorth")
	MeshKit.box(wall, Vector3(t, 2.2, 2.4 - dz.y), Vector3(fx, 1.1, (dz.y + 2.4) * 0.5), m, "CladdingHall")
	MeshKit.box(wall, Vector3(t, 0.2, dz.y - dz.x), Vector3(fx, 2.1, (dz.x + dz.y) * 0.5), m, "CladdingLintel")
	# 2.2〜2.6：廊下の上の部分（全長）
	_solid(wall, body, Vector3(0.1, H - 2.2, Z1 - Z0), Vector3(X1 + 0.05 - 0.1, 2.2 + (H - 2.2) * 0.5, (Z0 + Z1) * 0.5), m, "Upper")
	# z 2.4〜6.4：ほかの部屋の側の壁
	_solid(wall, body, Vector3(0.1, 2.2, Z1 - 2.4), Vector3(X1 + 0.05 - 0.1, 1.1, (2.4 + Z1) * 0.5), m, "Neighbors")
	# 巾木
	var skirt := MeshKit.mat("corr_skirt", Color(0.4, 0.38, 0.35), 0.8)
	MeshKit.box(wall, Vector3(0.015, 0.1, Z1 - Z0), Vector3(X1 - 0.0075, 0.05, (Z0 + Z1) * 0.5), skirt, "Skirting")


## ほかの部屋の玄関ドア（504・503）と、メーターボックス・消火器・非常口の表示。
func _build_doors() -> void:
	var doors := Node3D.new()
	doors.name = "NeighborDoors"
	add_child(doors)
	var leaf_m := MeshKit.mat("fd_leaf", Color(0.42, 0.5, 0.48), 0.55)
	var frame_m := MeshKit.mat("fd_frame", Color(0.32, 0.3, 0.28), 0.6)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	for d in [[3.5, "504"], [5.2, "503"]]:
		var z: float = d[0]
		MeshKit.box(doors, Vector3(0.05, 2.04, 0.76), Vector3(X1 - 0.025, 1.02, z), frame_m, "Frame")
		MeshKit.box(doors, Vector3(0.03, 1.98, 0.7), Vector3(X1 - 0.04, 0.99 + 0.01, z), leaf_m, "Door")
		MeshKit.box(doors, Vector3(0.04, 0.02, 0.02), Vector3(X1 - 0.075, 1.0, z + 0.28), metal, "Lever")
		var eye := MeshKit.cylinder(doors, 0.012, 0.01, Vector3(X1 - 0.056, 1.5, z), metal, "Peephole")
		eye.rotation.z = deg_to_rad(90.0)
		MeshKit.box(doors, Vector3(0.006, 0.07, 0.17), Vector3(X1 - 0.058, 1.68, z), MeshKit.mat("fd_plate", Color(0.9, 0.88, 0.8), 0.6), "Plate")
		var num := Label3D.new()
		num.text = d[1]
		num.font_size = 64
		num.pixel_size = 0.0012
		num.modulate = Color(0.15, 0.12, 0.1)
		num.double_sided = false
		num.position = Vector3(X1 - 0.0615, 1.68, z)
		num.rotation.y = -PI * 0.5
		doors.add_child(num)
	# 向かいの部屋の前：ガスのメーターボックス（灰色の扉）
	MeshKit.box(doors, Vector3(0.12, 0.9, 0.5), Vector3(X1 - 0.06, 1.15, 4.35), MeshKit.mat("meter_box", Color(0.62, 0.64, 0.62), 0.6, 0.3), "MeterBox")
	# 消火器と、非常口の緑の表示（エレベーターの横）
	MeshKit.cylinder(doors, 0.08, 0.38, Vector3(X1 - 0.12, 0.55, 5.85), MeshKit.mat("extinguisher", Color(0.75, 0.1, 0.08), 0.4), "Extinguisher", 0.08)
	MeshKit.box(doors, Vector3(0.18, 0.5, 0.012), Vector3(X1 - 0.12, 0.5, 5.935), MeshKit.mat("fire_box", Color(0.55, 0.12, 0.1), 0.5), "ExtinguisherSign")
	var exit_m := MeshKit.mat("exit_green", Color(0.1, 0.7, 0.35), 0.4)
	exit_m.emission_enabled = true
	exit_m.emission = Color(0.1, 0.8, 0.4)
	exit_m.emission_energy_multiplier = 1.0
	MeshKit.box(doors, Vector3(0.02, 0.18, 0.4), Vector3(X1 - 0.02, 2.35, 6.1), exit_m, "ExitSign")


## 南の端のエレベーター。壁に埋めた二枚扉（閉まっている）、上の階数表示「5」、呼び出しボタンの板。見た目だけ。
func _build_elevator() -> void:
	var el := Node3D.new()
	el.name = "Elevator"
	add_child(el)
	var cx := -1.85
	var z := Z1
	var metal := MeshKit.tiled_mat("elevator_metal", TEX_METAL, 0.5, Color(0.85, 0.85, 0.88), 0.35)
	var frame := MeshKit.mat("elevator_frame", Color(0.28, 0.28, 0.3), 0.4, 0.6)
	MeshKit.box(el, Vector3(1.3, 2.2, 0.02), Vector3(cx, 1.1, z - 0.01), frame, "Surround")
	for s in [-1.0, 1.0]:
		MeshKit.box(el, Vector3(0.57, 2.1, 0.02), Vector3(cx + s * 0.29, 1.05, z - 0.025), metal, "Door")
	MeshKit.box(el, Vector3(0.01, 2.1, 0.02), Vector3(cx, 1.05, z - 0.03), MeshKit.mat("elevator_gap", Color(0.05, 0.05, 0.06), 1.0), "Gap")
	# 階数表示（上）：緑の数字
	var disp := MeshKit.mat("elevator_display", Color(0.05, 0.05, 0.06), 0.4)
	MeshKit.box(el, Vector3(0.22, 0.14, 0.02), Vector3(cx, 2.38, z - 0.01), disp, "Display")
	var five := Label3D.new()
	five.name = "Floor"
	five.text = "5"
	five.font_size = 96
	five.pixel_size = 0.0012
	five.modulate = Color(0.3, 1.0, 0.5)
	five.shaded = false
	five.double_sided = false
	five.position = Vector3(cx, 2.38, z - 0.0215)
	five.rotation.y = PI
	el.add_child(five)
	# 呼び出しボタン（右の壁際）：上下の小さな丸が弱く光る
	MeshKit.box(el, Vector3(0.11, 0.26, 0.015), Vector3(cx + 0.8, 1.1, z - 0.0075), frame, "ButtonPlate")
	var btn := MeshKit.mat("elevator_button", Color(0.95, 0.75, 0.3), 0.3)
	btn.emission_enabled = true
	btn.emission = Color(1.0, 0.7, 0.2)
	btn.emission_energy_multiplier = 0.6
	for yy in [1.16, 1.04]:
		MeshKit.cylinder(el, 0.022, 0.012, Vector3(cx + 0.8, yy, z - 0.02), btn, "Button").rotation.x = deg_to_rad(90.0)


func _build_lights() -> void:
	var lamp_m := MeshKit.mat("corr_lamp", Color(0.95, 0.98, 1.0), 0.4)
	lamp_m.emission_enabled = true
	lamp_m.emission = Color(0.9, 0.96, 1.0)
	lamp_m.emission_energy_multiplier = 1.5
	for z in [0.5, 3.0, 5.4]:
		MeshKit.box(self, Vector3(0.9, 0.04, 0.16), Vector3(-1.85, H - 0.02, z), lamp_m, "CeilingLamp")
		var l := OmniLight3D.new()
		l.name = "CorridorLight"
		l.position = Vector3(-1.85, H - 0.25, z)
		l.light_color = Color(0.9, 0.96, 1.0)   # 蛍光灯の青白い光（浴室・自室の電球色とは違う）
		l.light_energy = 0.9
		l.omni_range = 4.5
		add_child(l)


# ---------------------------------------------------------------- 下北沢（異世界）の街並み

## 廊下の西側。地面は 4 階ぶん下（GROUND_Y）。道を挟んだ低い建物（屋根と看板が目の高さ近くに見える）、
## その奥の高い建物、遠景の影。看板は路地で使った画像を読めるよう大きめに掛ける。夕方でも読めるよう弱く発光。
func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Town"
	add_child(town)
	var wall := MeshKit.tiled_mat("town_wall", TEX_FACADE, 1.5, Color(0.7, 0.68, 0.64), 0.95)
	var dark := MeshKit.mat("town_far", Color(0.12, 0.14, 0.2), 1.0)
	var glass := MeshKit.mat("town_glass", Color(0.14, 0.16, 0.2), 0.2, 0.2)
	var lit := MeshKit.mat("town_lit", Color(1.0, 0.85, 0.6), 0.6)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.8, 0.55)
	lit.emission_energy_multiplier = 0.9
	# 地面（道）
	MeshKit.box(town, Vector3(400.0, 0.2, 400.0), Vector3(-200.0, GROUND_Y - 0.1, 10.0), MeshKit.tiled_mat("town_road", TEX_CONCRETE, 1.5, Color(0.42, 0.42, 0.42), 1.0), "Road")
	# 建物の列：[東面の x, 中心 z, 幅 z, 屋根の高さ y, 奥行き x]。屋根が低い列が手前（道の向かい）
	var rows := [
		[[-11.0, -12.0, 6.0, -1.5, 6.0], [-11.0, -5.5, 5.0, -5.0, 6.0], [-11.0, 1.0, 7.0, 2.0, 6.0], [-11.0, 8.5, 6.0, -3.0, 6.0],
				[-11.0, 15.0, 6.0, 1.0, 6.0], [-11.0, 22.0, 7.0, -4.5, 6.0], [-11.0, 29.0, 6.0, 0.0, 6.0]],
		[[-18.0, -10.0, 8.0, 9.0, 8.0], [-18.0, 0.0, 9.0, 14.0, 8.0], [-18.0, 10.0, 8.0, 7.0, 8.0], [-18.0, 19.0, 9.0, 12.0, 8.0], [-18.0, 28.0, 8.0, 8.0, 8.0]],
	]
	for r in rows:
		for b in r:
			_building(town, b, wall, glass, lit)
	# 遠景：暗い影の建物と、まばらな明かり
	for i in 14:
		var z := -20.0 + i * 5.2
		var top := _rng.randf_range(10.0, 26.0)
		var depth := 10.0
		MeshKit.box(town, Vector3(depth, top - GROUND_Y, 4.6), Vector3(-30.0 - depth * 0.5 - _rng.randf_range(0.0, 6.0), (top + GROUND_Y) * 0.5, z), dark, "Far")
		for k in 5:
			var wy := _rng.randf_range(GROUND_Y + 6.0, top - 1.0)
			MeshKit.box(town, Vector3(0.05, 0.6, 0.8), Vector3(-30.0, wy, z + _rng.randf_range(-1.8, 1.8)), lit, "FarLight")
	# 看板：手前の列の屋根の近くに縦の突き出し看板と、屋上の大きな横看板（読める大きさ）
	var vsigns := [[-12.0, -3.2, 3], [1.0, -0.5, 5], [15.0, -1.8, 9], [8.5, -5.8, 12], [-5.5, -7.7, 7]]   # [中心 z, 下端の y, 画像番号]
	for v in vsigns:
		var tex: Texture2D = load(STREET + "street_sign_v_%02d.png" % v[2])
		var sh := 2.6
		var sw := sh * tex.get_width() / tex.get_height()
		_sign(town, tex, Vector2(sw, sh), Vector3(-10.95, v[1] + sh * 0.5, v[0]), Vector3(0, PI * 0.5, 0))
	var hsigns := [[-12.0, -1.3, 2], [1.0, 2.2, 6], [29.0, 0.4, 10]]   # 屋上の大きな横看板 [中心 z, 下端の y, 画像番号]
	for v in hsigns:
		var tex: Texture2D = load(STREET + "street_sign_h_%02d.png" % v[2])
		var sw := 3.6
		var sh := sw * tex.get_height() / tex.get_width()
		var s := _sign(town, tex, Vector2(sw, sh), Vector3(-10.95, v[1] + sh * 0.5, v[0]), Vector3(0, PI * 0.5, 0))
		s.name = "RoofSign"
	# 電柱と電線（道の手前側）。柱は地面から 10m
	var pole := MeshKit.tiled_mat("town_pole", TEX_CONCRETE, 0.6, Color(0.85, 0.85, 0.85), 0.9)
	var wire := MeshKit.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	var tops := []
	for pz in [-6.0, 4.0, 14.0, 24.0]:
		var top := GROUND_Y + 10.0
		MeshKit.cylinder(town, 0.14, 10.0, Vector3(-5.5, GROUND_Y + 5.0, pz), pole, "Pole", 0.11, 12)
		MeshKit.box(town, Vector3(1.2, 0.08, 0.08), Vector3(-5.5, top - 0.4, pz), MeshKit.mat("sign_bracket", Color(0.25, 0.25, 0.26), 0.5, 0.6), "CrossArm")
		tops.append(Vector3(-5.5, top - 0.4, pz))
	for i in tops.size() - 1:
		for dx in [-0.5, 0.0, 0.5]:
			var a: Vector3 = tops[i] + Vector3(dx * 0.4, 0, 0)
			var b: Vector3 = tops[i + 1] + Vector3(dx * 0.4, 0, 0)
			MeshKit.pipe(town, [a, (a + b) * 0.5 + Vector3(0, -0.5, 0), b], 0.006, wire)
	_build_ads(town)
	_build_bbq(town)
	# 街だけを照らす太陽（光の届く層をマスクで 2 番に限る。廊下や部屋の中は照らさない）。空の時間で色と強さが変わる
	for c in town.get_children():
		if c is VisualInstance3D:
			(c as VisualInstance3D).layers = 3
	var sun := DirectionalLight3D.new()
	sun.name = "TownSun"
	sun.light_cull_mask = 2
	sun.shadow_enabled = false
	sun.transform.basis = Basis.looking_at(Vector3(-1.0, -0.35, 0.25), Vector3.UP)
	add_child(sun)
	var sun_clock = get_parent().get("sky_clock") if get_parent() else null
	if sun_clock:
		sun_clock.weights_changed.connect(func(_d: float, _s: float, _k: float) -> void:
			sun.light_color = sun_clock.window_color
			sun.light_energy = 0.9 * sun_clock.daylight + 0.15)
		sun_clock.set_time(sun_clock.time)
	# 異世界の月：遠くの空に大きく淡い（光るだけの円盤）
	var moon_m := MeshKit.mat("town_moon", Color(0.95, 0.92, 0.8), 1.0)
	moon_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var moon := MeshKit.sphere(town, 5.0, Vector3(-80.0, 24.0, 16.0), moon_m)
	moon.name = "Moon"
	# 月は夕暮れに向けて現れる（昼は見えない）。空の時間は sky_clock から
	var clock = get_parent().get("sky_clock") if get_parent() else null
	if clock:
		clock.weights_changed.connect(func(_d: float, sunset: float, dusk: float) -> void:
			var a := clampf(dusk + sunset * 0.3, 0.0, 1.0)
			moon_m.albedo_color = Color(0.95, 0.92, 0.8, a)
			moon.visible = a > 0.02)
		clock.set_time(clock.time)


## 建物1棟：東面（+x、廊下を向く）に窓の格子を並べる。b = [東面の x, 中心 z, 幅 z, 屋根の y, 奥行き x]。
func _building(parent: Node3D, b: Array, wall: Material, glass: Material, lit: Material) -> void:
	var xf: float = b[0]
	var zc: float = b[1]
	var wz: float = b[2]
	var top: float = b[3]
	var depth: float = b[4]
	var hgt := top - GROUND_Y
	MeshKit.box(parent, Vector3(depth, hgt, wz - 0.3), Vector3(xf - depth * 0.5, GROUND_Y + hgt * 0.5, zc), wall, "Building")
	# 屋上の縁
	MeshKit.box(parent, Vector3(depth, 0.3, wz - 0.3), Vector3(xf - depth * 0.5, top + 0.15, zc), MeshKit.mat("town_roof", Color(0.4, 0.4, 0.4), 0.9), "Roof")
	var floors := int(hgt / FLOOR_PITCH)
	var cols := int((wz - 0.3) / 1.6)
	for f in range(1, floors):
		for c in cols:
			if _rng.randf() < 0.12:
				continue
			var z := zc - (wz - 0.3) * 0.5 + (c + 0.5) * (wz - 0.3) / cols
			var is_lit := _rng.randf() < 0.22
			MeshKit.box(parent, Vector3(0.04, 1.1, 0.9), Vector3(xf + 0.02, GROUND_Y + f * FLOOR_PITCH + 1.4, z), lit if is_lit else glass, "Window")


func _sign(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := MeshKit.texture_mat("town_%s" % tex.resource_path.get_file(), tex, 0.8).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- 広告（ポスター）と屋上のバーベキュー会場

const POSTER_DIR := "res://assets/textures/collection/movie_poster_%02d.png"


## 広告のポスター板：暗い枠に、映画のポスター（比率そのまま、高さ h）を貼り、弱く光らせる。rot_y は向き（0＝+z、PI*0.5＝+x）。
func _billboard(parent: Node3D, n: int, center: Vector3, h: float, rot_y: float) -> void:
	var tex: Texture2D = load(POSTER_DIR % n)
	var w := h * tex.get_width() / tex.get_height()
	var board := Node3D.new()
	board.name = "Billboard%02d" % n
	board.position = center
	board.rotation.y = rot_y
	parent.add_child(board)
	MeshKit.box(board, Vector3(w + 0.3, h + 0.3, 0.1), Vector3(0, 0, -0.05), MeshKit.mat("ad_frame", Color(0.16, 0.16, 0.18), 0.5, 0.4), "Frame")
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var m := MeshKit.texture_mat("ad_poster_%02d" % n, tex, 0.7).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission_texture = tex
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.4
	var mi := MeshInstance3D.new()
	mi.name = "Poster"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0, 0.005)
	board.add_child(mi)
	# 上端の照明灯（光る細い棒）
	var lamp := MeshKit.mat("ad_lamp", Color(1.0, 0.95, 0.8), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.92, 0.7)
	lamp.emission_energy_multiplier = 1.5
	MeshKit.box(board, Vector3(w * 0.7, 0.05, 0.05), Vector3(0, h * 0.5 + 0.2, 0.06), lamp, "Lamp")


## 外の建物の広告：奥の高い建物の壁に大きなポスター3枚、手前の建物の屋上に「広告塔」（四角い柱の3面にポスター）2本。
## どれも見た目だけで、行けない。
func _build_ads(town: Node3D) -> void:
	# [中心 z、下端の y、ポスター番号]：奥の列の東面（x -18）。高さ 4.2m
	for a in [[-10.0, 3.2, 5], [0.0, 6.0, 2], [10.0, 2.5, 8]]:
		_billboard(town, a[2], Vector3(-17.9, a[1] + 2.1, a[0]), 4.2, PI * 0.5)
	# 屋上の広告塔：[中心 z、屋根の上面の y、ポスター番号（+x 面、+z 面、-z 面）]
	for t in [[-5.5, -4.7, [4, 6, 7]], [22.0, -4.2, [3, 1, 2]]]:
		var tower := Node3D.new()
		tower.name = "AdTower"
		tower.position = Vector3(-13.5, t[1], t[0])
		town.add_child(tower)
		MeshKit.box(tower, Vector3(1.7, 3.0, 1.7), Vector3(0, 1.5, 0), MeshKit.mat("ad_column", Color(0.25, 0.25, 0.28), 0.5, 0.3), "Column")
		MeshKit.box(tower, Vector3(1.9, 0.12, 1.9), Vector3(0, 3.06, 0), MeshKit.mat("ad_frame", Color(0.16, 0.16, 0.18), 0.5, 0.4), "Cap")
		var faces := [[Vector3(0.86, 1.5, 0), PI * 0.5], [Vector3(0, 1.5, 0.86), 0.0], [Vector3(0, 1.5, -0.86), PI]]
		for k in 3:
			_billboard(tower, t[2][k], faces[k][0], 2.1, faces[k][1])


## 屋上のバーベキュー会場（超簡易）。手前の列の建物（中心 z 15、屋根の上面 y 1.3）の屋根に、木の床・グリル2台・長いテーブルと椅子・
## パラソル・クーラーボックス・電球の飾りと、楽しそうな人影4つ。電球と炭は光る。行けない（当たり判定なし）。
func _build_bbq(town: Node3D) -> void:
	var root := Node3D.new()
	root.name = "RooftopBBQ"
	root.position = Vector3(-14.0, 1.3, 15.0)
	town.add_child(root)
	var wood := MeshKit.mat("bbq_deck", Color(0.55, 0.4, 0.27), 0.8)
	var dark := MeshKit.mat("bbq_dark", Color(0.12, 0.12, 0.13), 0.6)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.box(root, Vector3(5.0, 0.08, 5.0), Vector3(0, 0.04, 0), wood, "Deck")
	# 手すり（東と北と南の縁）
	for z in [-2.4, 2.4]:
		MeshKit.box(root, Vector3(5.0, 0.05, 0.05), Vector3(0, 1.0, z), metal, "Rail")
	MeshKit.box(root, Vector3(0.05, 0.05, 4.9), Vector3(2.45, 1.0, 0), metal, "Rail")
	for z in [-2.4, -1.2, 0.0, 1.2, 2.4]:
		MeshKit.box(root, Vector3(0.05, 1.0, 0.05), Vector3(2.45, 0.5, z), metal, "Post")
	# グリル2台（奥側）。炭は赤く光る
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.8, 0.2, 0.05)
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.35, 0.1)
	coal.emission_energy_multiplier = 2.0
	for z in [-1.4, -0.2]:
		MeshKit.box(root, Vector3(0.6, 0.5, 0.9), Vector3(-1.6, 0.33, z), dark, "Grill")
		MeshKit.box(root, Vector3(0.5, 0.04, 0.8), Vector3(-1.6, 0.6, z), coal, "Coals")
		MeshKit.box(root, Vector3(0.52, 0.01, 0.82), Vector3(-1.6, 0.63, z), metal, "Grate")
	# 長いテーブルと椅子
	var cloth := MeshKit.mat("bbq_cloth", Color(0.85, 0.3, 0.3), 0.9)
	MeshKit.box(root, Vector3(0.9, 0.05, 2.6), Vector3(0.6, 0.8, 1.0), cloth, "Table")
	for p in [Vector2(0.2, -0.2), Vector2(1.0, -0.2), Vector2(0.2, 2.2), Vector2(1.0, 2.2)]:
		MeshKit.box(root, Vector3(0.05, 0.74, 0.05), Vector3(p.x, 0.43, p.y), wood, "Leg")
	var chair := MeshKit.mat("bbq_chair", Color(0.3, 0.45, 0.55), 0.8)
	for k in 3:
		for sx in [-0.4, 1.6]:
			MeshKit.box(root, Vector3(0.4, 0.05, 0.4), Vector3(sx + 0.0, 0.45, 0.1 + k * 0.85), chair, "Chair")
			MeshKit.box(root, Vector3(0.04 if sx < 0 else 0.04, 0.4, 0.4), Vector3(sx - 0.2 if sx < 0 else sx + 0.2, 0.68, 0.1 + k * 0.85), chair, "ChairBack")
	# 皿・紙コップ・ビン（小さな箱）
	var plate := MeshKit.mat("bbq_plate", Color(0.95, 0.95, 0.9), 0.5)
	for k in 6:
		MeshKit.box(root, Vector3(0.2, 0.015, 0.2), Vector3(0.45 + (k % 2) * 0.3, 0.84, 0.0 + k * 0.4), plate, "Plate")
	var cup := MeshKit.mat("bbq_cup", Color(0.3, 0.7, 0.4), 0.5)
	for k in 4:
		MeshKit.cylinder(root, 0.04, 0.12, Vector3(0.6, 0.9, 0.1 + k * 0.6), cup, "Bottle")
	# クーラーボックス
	MeshKit.box(root, Vector3(0.8, 0.45, 0.45), Vector3(-1.9, 0.3, 1.8), MeshKit.mat("bbq_cooler", Color(0.2, 0.45, 0.8), 0.5), "Cooler")
	MeshKit.box(root, Vector3(0.82, 0.05, 0.47), Vector3(-1.9, 0.55, 1.8), MeshKit.mat("bbq_cooler_lid", Color(0.9, 0.9, 0.92), 0.5), "CoolerLid")
	# パラソル
	MeshKit.cylinder(root, 0.03, 2.4, Vector3(1.9, 1.28, 1.0), metal, "ParasolPole")
	var umb := CylinderMesh.new()
	umb.top_radius = 0.02
	umb.bottom_radius = 1.5
	umb.height = 0.45
	umb.radial_segments = 12
	var um := MeshInstance3D.new()
	um.name = "Parasol"
	um.mesh = umb
	um.material_override = MeshKit.mat("bbq_parasol", Color(0.92, 0.35, 0.3), 0.8)
	um.position = Vector3(1.9, 2.65, 1.0)
	root.add_child(um)
	# 電球の飾り（四隅の柱の間にたるませた線に、小さな光る球）
	var bulb := MeshKit.mat("bbq_bulb", Color(1.0, 0.9, 0.6), 0.4)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.85, 0.5)
	bulb.emission_energy_multiplier = 3.0
	var wire := MeshKit.mat("wire", Color(0.08, 0.08, 0.08), 0.8)
	for z in [-2.4, 2.4]:
		MeshKit.box(root, Vector3(0.06, 2.6, 0.06), Vector3(-2.4, 1.3, z), metal, "LightPole")
		MeshKit.box(root, Vector3(0.06, 2.6, 0.06), Vector3(2.4, 1.3, z), metal, "LightPole")
	for z in [-2.4, 2.4]:
		var a := Vector3(-2.4, 2.55, z)
		var b := Vector3(2.4, 2.55, z)
		MeshKit.pipe(root, [a, Vector3(0, 2.3, z), b], 0.008, wire)
		for i in 9:
			var t := float(i + 1) / 10.0
			var sag := 2.55 - 0.25 * (1.0 - pow(2.0 * t - 1.0, 2.0))
			MeshKit.sphere(root, 0.05, Vector3(lerpf(a.x, b.x, t), sag - 0.05, z), bulb)
	# 人影（円柱の体と丸い頭）：グリルのそばに2人、テーブルに2人
	var colors := [Color(0.85, 0.35, 0.3), Color(0.3, 0.5, 0.8), Color(0.9, 0.75, 0.3), Color(0.4, 0.7, 0.5)]
	var spots := [Vector3(-0.9, 0.0, -0.8), Vector3(-0.9, 0.0, 0.3), Vector3(0.6, 0.0, 0.1), Vector3(-0.4, 0.0, 1.9)]
	for i in 4:
		var f := Node3D.new()
		f.name = "Guest%d" % (i + 1)
		f.position = spots[i] + Vector3(0, 0.08, 0)
		root.add_child(f)
		MeshKit.cylinder(f, 0.17, 0.8, Vector3(0, 0.6, 0), MeshKit.mat("guest_%d" % i, colors[i], 0.8), "Body")
		MeshKit.cylinder(f, 0.09, 0.5, Vector3(0.0, 0.25, 0), dark, "Legs")
		MeshKit.sphere(f, 0.12, Vector3(0, 1.13, 0), MeshKit.mat("guest_skin", Color(0.9, 0.75, 0.62), 0.8))
	# 電球と炭のあかり（暖色。建物の屋根のまわりをほんのり）
	var warm := OmniLight3D.new()
	warm.name = "BbqLight"
	warm.position = Vector3(0, 2.2, 0)
	warm.light_color = Color(1.0, 0.75, 0.45)
	warm.light_energy = 1.4
	warm.omni_range = 7.0
	root.add_child(warm)
	var sign_label := Label3D.new()
	sign_label.name = "BbqSign"
	sign_label.text = "BBQ"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.012
	sign_label.modulate = Color(1.0, 0.85, 0.5)
	sign_label.shaded = false
	sign_label.double_sided = true
	sign_label.position = Vector3(2.5, 1.75, 0.0)
	sign_label.rotation.y = PI * 0.5
	root.add_child(sign_label)
