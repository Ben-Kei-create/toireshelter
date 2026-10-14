extends Node3D
## 1 階のマンションの入口（ユーザーの写真に合わせた）。原点は、通りから入る所の床の中心。-z へ進む。
##   z 0〜-4 …… 外のアプローチ。左は黒いレンガの塀（忍び返しのついた鉄の門扉が開いて寄せてある）、右は蔦（つた）の茂み。床は暖かい色のタイル
##   z -4    …… レンガのアーチ（壁灯）。奥に、唐草模様の鉄の内門が開いている
##   z -4〜-9 … 玄関ホール。左の壁に黒い郵便受けがびっしり、上は吹き抜け（明かり取り）。突き当たりにエレベーター（扉の窓が光る）
## 見た目だけ（まだ歩いて来られない）。アーチは CSG で抜く。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const ElevatorCar := preload("res://scripts/elevator_car.gd")

const HALF_W := 0.9          # 通路の幅の半分
const ARCH_Z := -4.0
const SPRING_Y := 1.9        # アーチの曲がりはじめの高さ
const ARCH_R := 0.7
const LOBBY_END_Z := -9.0
const LOBBY_H := 3.1

static var _tile_tex: ImageTexture
static var _brick_tex: ImageTexture

var _rng := RandomNumberGenerator.new()


## 暖かい色の正方形タイル（目地つき）。1 枚が 1 つの絵。
static func tile_tex() -> ImageTexture:
	if _tile_tex == null:
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		var r := RandomNumberGenerator.new()
		r.seed = 77
		var base := Color(0.86, 0.69, 0.5)
		for y in 48:
			for x in 48:
				var n := r.randf_range(-0.025, 0.025)
				var c := Color(base.r + n, base.g + n, base.b + n)
				if x < 2 or y < 2:
					c = Color(0.52, 0.42, 0.33)   # 目地
				img.set_pixel(x, y, c)
		_tile_tex = ImageTexture.create_from_image(img)
	return _tile_tex


## 黒ずんだ小さなレンガ（四段、段ごとに半分ずらす）。
static func brick_tex() -> ImageTexture:
	if _brick_tex == null:
		var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
		var r := RandomNumberGenerator.new()
		r.seed = 91
		img.fill(Color(0.07, 0.06, 0.06))   # 目地
		for row in 4:
			var off := 12 if row % 2 == 1 else 0
			for b in 5:
				var x0 := b * 24 - off
				var tone := r.randf_range(0.85, 1.15)
				var col := Color(0.2 * tone, 0.1 * tone, 0.085 * tone)
				for y in range(row * 8 + 1, row * 8 + 8):
					for x in range(x0 + 1, x0 + 24):
						var xx := posmod(x, 96)
						img.set_pixel(xx, y, col.lerp(Color(0.3, 0.17, 0.14), r.randf() * 0.12))
		_brick_tex = ImageTexture.create_from_image(img)
	return _brick_tex


func _ready() -> void:
	_rng.seed = 1001
	MeshKit.auto_round = false
	_build_ground()
	_build_walls()
	_build_arch()
	_build_gates()
	_build_ivy()
	_build_mailboxes()
	_build_lobby_end()
	_build_lights()
	MeshKit.auto_round = true


func _brick_mat() -> StandardMaterial3D:
	return MeshKit.tiled_mat("ent_brick", brick_tex(), 0.84, Color(0.62, 0.56, 0.56), 0.9)   # 写真のとおり、黒ずんだレンガ


func _iron_mat() -> StandardMaterial3D:
	return MeshKit.mat("ent_iron", Color(0.17, 0.19, 0.23), 0.45, 0.7)


func _body(node_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = node_name
	b.collision_layer = MeshKit.LAYER_WORLD
	b.collision_mask = 0
	add_child(b)
	return b


func _solid(body: StaticBody3D, size: Vector3, center: Vector3, m: Material, node_name := "") -> void:
	MeshKit.box(self, size, center, m, node_name)
	MeshKit.shape_box(body, size, center)


func _build_ground() -> void:
	var body := _body("GroundBody")
	var tile := MeshKit.tiled_mat("ent_tile", tile_tex(), 0.3, Color(1, 1, 1), 0.6)
	var len := -LOBBY_END_Z + 1.0
	_solid(body, Vector3(HALF_W * 2.0 + 1.4, 0.2, len), Vector3(0.35, -0.1, -len * 0.5 + 1.0), tile, "Floor")
	# ホールの天井（吹き抜けのところは抜ける）
	var ceil_m := MeshKit.mat("ent_ceiling", Color(0.78, 0.76, 0.72), 0.9)
	MeshKit.box(self, Vector3(HALF_W * 2.0 + 0.2, 0.2, 1.4), Vector3(0, LOBBY_H + 0.1, -4.9), ceil_m, "CeilingA")
	MeshKit.box(self, Vector3(HALF_W * 2.0 + 0.2, 0.2, 0.7), Vector3(0, LOBBY_H + 0.1, -8.65), ceil_m, "CeilingB")
	# 吹き抜けの縁と、その上の明かり取り（明るい窓）
	var sky := MeshKit.mat("ent_skylight", Color(0.95, 0.9, 0.8), 0.5)
	sky.emission_enabled = true
	sky.emission = Color(1.0, 0.92, 0.78)
	sky.emission_energy_multiplier = 2.0
	MeshKit.box(self, Vector3(HALF_W * 2.0, 0.05, 1.4), Vector3(0, LOBBY_H + 1.4, -7.2), sky, "Skylight")
	for s in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.2, 1.4, 1.4), Vector3(s * (HALF_W + 0.1), LOBBY_H + 0.7, -7.2), ceil_m, "ShaftWall")


func _build_walls() -> void:
	var body := _body("WallBody")
	var brick := _brick_mat()
	# 左の塀（外のアプローチ）：レンガ、上に忍び返し
	_solid(body, Vector3(0.2, 2.3, 4.0), Vector3(-HALF_W - 0.1, 1.15, -2.0), brick, "FenceWall")
	var spike := _iron_mat()
	var zz := -0.15
	while zz > -3.9:
		var s := MeshKit.cylinder(self, 0.012, 0.18, Vector3(-HALF_W - 0.1, 2.38, zz), spike, "Spike", 0.001, 6)
		zz -= 0.14
	# 右は蔦の土手（体を止める壁だけ。見た目は _build_ivy）
	MeshKit.shape_box(body, Vector3(0.2, 2.3, 4.0), Vector3(HALF_W + 0.1, 1.15, -2.0))
	_build_night()
	# ホールの左右の壁：左は郵便受けの壁（レンガ）、右は明るいタイル
	_solid(body, Vector3(0.2, LOBBY_H, 5.0), Vector3(-HALF_W - 0.1, LOBBY_H * 0.5, -6.5), _brick_mat(), "LobbyLeft")
	var cream := MeshKit.tiled_mat("ent_wall_tile", tile_tex(), 0.3, Color(1.2, 1.25, 1.3), 0.6)
	_solid(body, Vector3(0.2, LOBBY_H, 5.0), Vector3(HALF_W + 0.1, LOBBY_H * 0.5, -6.5), cream, "LobbyRight")
	_solid(body, Vector3(HALF_W * 2.0 + 0.4, LOBBY_H, 0.2), Vector3(0, LOBBY_H * 0.5, LOBBY_END_Z - 0.1), MeshKit.mat("ent_end_wall", Color(0.82, 0.8, 0.76), 0.85), "EndWall")


## 夜の空：入口のまわりを、暗い紺色のドームで包む（ほかの場所の空が見えないように）。
func _build_night() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.015, 0.02, 0.05)
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	var sphere := SphereMesh.new()
	sphere.radius = 40.0
	sphere.height = 80.0
	var mi := MeshInstance3D.new()
	mi.name = "NightSky"
	mi.mesh = sphere
	mi.material_override = m
	mi.position = Vector3(0, 0, -4)
	add_child(mi)


func _build_arch() -> void:
	# レンガの壁に、半円のアーチの口を抜く
	var comb := CSGCombiner3D.new()
	comb.name = "ArchWall"
	comb.use_collision = true
	comb.collision_layer = MeshKit.LAYER_WORLD
	comb.collision_mask = 0
	comb.position = Vector3(0, 0, ARCH_Z)
	add_child(comb)
	var wall := CSGBox3D.new()
	wall.size = Vector3(HALF_W * 2.0 + 1.6, 3.6, 0.45)
	wall.position = Vector3(0, 1.8, 0)
	wall.material = _brick_mat()
	comb.add_child(wall)
	var lower := CSGBox3D.new()
	lower.operation = CSGShape3D.OPERATION_SUBTRACTION
	lower.size = Vector3(ARCH_R * 2.0, SPRING_Y, 0.8)
	lower.position = Vector3(0, SPRING_Y * 0.5 - 0.01, 0)
	comb.add_child(lower)
	var round_top := CSGCylinder3D.new()
	round_top.operation = CSGShape3D.OPERATION_SUBTRACTION
	round_top.radius = ARCH_R
	round_top.height = 0.8
	round_top.sides = 32
	round_top.rotation.x = deg_to_rad(90.0)
	round_top.position = Vector3(0, SPRING_Y, 0)
	comb.add_child(round_top)
	# アーチの縁に、レンガを立てて並べる（少し出っ張らせる）
	var rim := MeshKit.tiled_mat("ent_brick_rim", brick_tex(), 0.5, Color(1.5, 1.3, 1.2), 0.85)
	var n := 13
	for k in n:
		var a := PI * (k + 0.5) / float(n)
		var rr := ARCH_R + 0.1
		var b := MeshKit.box(self, Vector3(rr * PI / n * 1.02, 0.2, 0.52), Vector3(cos(a) * rr, SPRING_Y + sin(a) * rr, ARCH_Z), rim, "Voussoir")
		b.rotation.z = a - PI * 0.5


func _build_gates() -> void:
	var iron := _iron_mat()
	# 外の門扉：開いて、左の塀に寄せてある（高さ 2.1、幅 1.2、縦の棒と二本の横木、上に飾り）
	var g := Node3D.new()
	g.name = "OuterGate"
	g.position = Vector3(-HALF_W + 0.04, 0, -1.2)
	g.rotation.y = deg_to_rad(88.0)
	add_child(g)
	_gate_leaf(g, 1.2, 2.1, true)
	# 内の門扉：アーチの奥で、開いて斜めに立っている。唐草の輪が並ぶ
	var g2 := Node3D.new()
	g2.name = "InnerGate"
	g2.position = Vector3(ARCH_R - 0.04, 0, ARCH_Z - 0.35)
	g2.rotation.y = deg_to_rad(-62.0)
	add_child(g2)
	_gate_leaf(g2, 0.75, 1.8, false)


## 鉄の門扉 1 枚。原点が蝶番の足元で、+x 方向へ幅。
func _gate_leaf(parent: Node3D, w: float, h: float, spiky: bool) -> void:
	var iron := _iron_mat()
	for rail_y in [0.1, h * 0.55, h - 0.05]:
		MeshKit.box(parent, Vector3(w, 0.05, 0.04), Vector3(w * 0.5, rail_y, 0), iron, "Rail")
	for side in [0.0, w]:
		MeshKit.box(parent, Vector3(0.05, h, 0.05), Vector3(side, h * 0.5, 0), iron, "Stile")
	var bars := int(w / 0.11)
	for i in bars:
		var x := w * (i + 0.5) / float(bars)
		MeshKit.box(parent, Vector3(0.016, h - 0.1, 0.016), Vector3(x, h * 0.5, 0), iron, "Bar")
		if spiky:
			MeshKit.cylinder(parent, 0.012, 0.1, Vector3(x, h + 0.02, 0), iron, "Tip", 0.001, 6)
	# 唐草の輪（下の段に並べる）
	for i in 3:
		var t := TorusMesh.new()
		t.inner_radius = w * 0.1
		t.outer_radius = w * 0.1 + 0.012
		var mi := MeshInstance3D.new()
		mi.name = "Scroll"
		mi.mesh = t
		mi.material_override = iron
		mi.rotation.x = deg_to_rad(90.0)
		mi.position = Vector3(w * (0.2 + 0.3 * i), h * 0.3, 0)
		parent.add_child(mi)


func _build_ivy() -> void:
	var holder := Node3D.new()
	holder.name = "Ivy"
	add_child(holder)
	var dark := MeshKit.mat("ivy_dark", Color(0.1, 0.2, 0.08), 0.9)
	var mid := MeshKit.mat("ivy_mid", Color(0.2, 0.36, 0.12), 0.85)
	var light := MeshKit.mat("ivy_light", Color(0.42, 0.55, 0.2), 0.8)
	# 蔦が這う壁（暗いレンガ）
	var wall_body := _body("IvyWallBody")
	_solid(wall_body, Vector3(0.2, 2.6, 4.0), Vector3(HALF_W + 0.9, 1.3, -2.0), _brick_mat(), "IvyWall")
	for i in 260:
		var m: Material = [dark, dark, dark, mid, mid, light][_rng.randi_range(0, 5)]
		var r := _rng.randf_range(0.05, 0.12)
		var p := Vector3(HALF_W + _rng.randf_range(0.05, 0.75), _rng.randf_range(0.1, 2.4), _rng.randf_range(-3.85, -0.15))
		var s := MeshKit.sphere(holder, r, p, m)
		s.scale = Vector3(1.0, 0.55, 1.0)
		s.rotation = Vector3(_rng.randf() * PI, _rng.randf() * PI, _rng.randf() * PI)


func _build_mailboxes() -> void:
	# 左の壁の郵便受け：黒い小さな扉が縦横に並ぶ。ところどころに白や黄色のシール、丸い鍵穴
	var holder := Node3D.new()
	holder.name = "Mailboxes"
	add_child(holder)
	var steel := MeshKit.mat("mail_black", Color(0.1, 0.1, 0.11), 0.5, 0.6)
	var edge := MeshKit.mat("mail_edge", Color(0.04, 0.04, 0.045), 0.7, 0.3)
	var label_w := MeshKit.mat("mail_label_w", Color(0.92, 0.92, 0.9), 0.8)
	var label_y := MeshKit.mat("mail_label_y", Color(0.9, 0.78, 0.25), 0.8)
	var knob := MeshKit.mat("mail_knob", Color(0.55, 0.55, 0.58), 0.35, 0.85)
	var x := -HALF_W
	for block in 2:
		var z0 := -5.0 - block * 2.0
		for col in 8:
			for row in 7:
				var z := z0 - col * 0.22
				var y := 0.75 + row * 0.16
				MeshKit.box(holder, Vector3(0.06, 0.15, 0.21), Vector3(x + 0.03, y, z), steel, "Box")
				MeshKit.box(holder, Vector3(0.062, 0.006, 0.212), Vector3(x + 0.031, y + 0.078, z), edge, "Seam")
				MeshKit.cylinder(holder, 0.008, 0.01, Vector3(x + 0.065, y - 0.02, z + 0.06), knob, "Lock", -1.0, 8).rotation.z = deg_to_rad(90.0)
				var roll := _rng.randf()
				if roll < 0.22:
					MeshKit.box(holder, Vector3(0.004, 0.035, 0.09), Vector3(x + 0.062, y + 0.035, z - 0.01), label_w if roll < 0.14 else label_y, "Label")
	# 郵便受けの上の壁に、細い金属の帯
	MeshKit.box(holder, Vector3(0.04, 0.05, 4.0), Vector3(x + 0.02, 1.95, -6.9), MeshKit.mat("mail_band", Color(0.6, 0.6, 0.62), 0.4, 0.8), "Band")


func _build_lobby_end() -> void:
	# 突き当たりのエレベーター：暗い扉、窓が光る（写真のとおり）
	var body := MeshKit.mat("ent_elev_door", Color(0.13, 0.14, 0.16), 0.5, 0.3)
	ElevatorCar.build_doors(self, Vector3(0.0, 0.0, LOBBY_END_Z + 0.04), body, true, true).rotation.y = PI
	# 消火器と、黒い台
	MeshKit.box(self, Vector3(0.32, 0.12, 0.32), Vector3(-0.65, 0.06, LOBBY_END_Z + 0.3), MeshKit.mat("ent_stand", Color(0.06, 0.06, 0.07), 0.6), "ExtinguisherStand")
	MeshKit.cylinder(self, 0.07, 0.4, Vector3(-0.65, 0.32, LOBBY_END_Z + 0.3), MeshKit.mat("extinguisher", Color(0.75, 0.1, 0.08), 0.4), "Extinguisher", 0.07)


func _build_lights() -> void:
	# アーチの壁灯（暖色）：二つ並んだ小さな球の灯り
	var warm := MeshKit.mat("ent_lamp_warm", Color(1.0, 0.92, 0.75), 0.4)
	warm.emission_enabled = true
	warm.emission = Color(1.0, 0.85, 0.55)
	warm.emission_energy_multiplier = 3.0
	for dx in [-0.07, 0.07]:
		MeshKit.sphere(self, 0.06, Vector3(-ARCH_R - 0.08 + dx, 2.3, ARCH_Z + 0.35), warm)
	var l := OmniLight3D.new()
	l.name = "ArchLight"
	l.position = Vector3(-0.4, 2.2, ARCH_Z + 0.5)
	l.light_color = Color(1.0, 0.85, 0.6)
	l.light_energy = 2.2
	l.omni_range = 6.0
	add_child(l)
	# 玄関ホールの明かり（白い）と、吹き抜けからの光
	for z in [-5.5, -7.2]:
		var h := OmniLight3D.new()
		h.name = "LobbyLight"
		h.position = Vector3(0, LOBBY_H - 0.3, z)
		h.light_color = Color(1.0, 0.95, 0.85)
		h.light_energy = 1.2
		h.omni_range = 5.0
		add_child(h)
	# 外のアプローチ：足元をぼんやり照らす
	var o := OmniLight3D.new()
	o.name = "ApproachLight"
	o.position = Vector3(0, 2.5, -1.5)
	o.light_color = Color(1.0, 0.9, 0.7)
	o.light_energy = 0.8
	o.omni_range = 5.0
	add_child(o)
