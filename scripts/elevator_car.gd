extends Node3D
## エレベーターの箱の中（ユーザーの写真に合わせた）。原点は床の中心。前の壁（z=+D/2）に二枚扉、その右に操作盤。
## 扉は白い木目で、窓が二つ（左は細く低い・右は広く高い）。窓は網入りガラス。操作盤は、▼5 の表示・ボタン 1〜7・開閉・非常呼び出し。
## 見た目だけ（まだ乗れない）。扉の組み立て（build_doors）は、廊下のエレベーターの扉と 1 階の入口でも使う。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const TEX_DOOR := preload("res://assets/textures/street/photo_elevator_door.png")   # ユーザーの写真から切り出した白い木目

const W := 1.4
const D := 1.35
const H := 2.3
const DOOR_W := 0.8
const DOOR_X := 0.2           # 扉の中心。前（+z）を向くと +x は左手側なので、扉は左、操作盤は右手側（写真と同じ並び）
const PANEL_X := -0.46        # 操作盤の中心

static var _wired_tex: ImageTexture


## 網入りガラス（暗いガラスに、斜めの格子の針金）。
static func wired_glass_mat(glow := false) -> StandardMaterial3D:
	if _wired_tex == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.12, 0.14, 1.0))
		for i in 24:
			for d in [0, 1]:
				img.set_pixel(i, (i + d) % 24, Color(0.62, 0.66, 0.7, 1.0))
				img.set_pixel(i, (23 - i + d) % 24, Color(0.62, 0.66, 0.7, 1.0))
		_wired_tex = ImageTexture.create_from_image(img)
	var key := "wired_glass_glow" if glow else "wired_glass"
	var m := MeshKit.tiled_mat(key, _wired_tex, 0.07, Color(1, 1, 1), 0.3)
	if glow:
		# 向こうの明かりが透けて光る窓（廊下側から見たとき）
		m.albedo_color = Color(0.8, 0.92, 1.0)
		m.emission_enabled = true
		m.emission = Color(0.7, 0.88, 1.0)
		m.emission_energy_multiplier = 0.9
	return m


## 二枚扉。cx：扉の中心の x、y0：床の高さ、face：-1 なら法線が -z（箱の中から前を見る・廊下から南を見る）。
## body：扉の板の材質、glow：窓を光らせるか。左の窓は細く低く、右の窓は広く高い（写真のとおり）。
static func build_doors(parent: Node3D, center: Vector3, body: Material, glow := false, _closed := true) -> Node3D:
	var n := Node3D.new()
	n.name = "Doors"
	n.position = center
	parent.add_child(n)
	var steel := MeshKit.mat("elev_steel", Color(0.72, 0.73, 0.75), 0.35, 0.85)
	var leaf_w := DOOR_W * 0.5 - 0.004
	# 左右の扉（それぞれ 1 つの節点：開けるときは横へ動かす）。手前を向いて左（+x 側）が細く低い窓、右が広く高い窓
	var leaves := [["LeafR", -DOOR_W * 0.25, 0.17, 0.85, 1.2], ["LeafL", DOOR_W * 0.25, 0.12, 0.55, 1.05]]
	for lf in leaves:
		var leaf := Node3D.new()
		leaf.name = lf[0]
		leaf.position = Vector3(float(lf[1]), 0.0, 0.0)
		n.add_child(leaf)
		MeshKit.box(leaf, Vector3(leaf_w, 2.0, 0.04), Vector3(0, 1.0, 0.0), body, "Leaf")
		var win_w: float = lf[2]
		var win_h: float = lf[3]
		var win_y: float = lf[4]
		MeshKit.box(leaf, Vector3(win_w + 0.03, win_h + 0.03, 0.012), Vector3(0, win_y, -0.012), steel, "WindowFrame")
		MeshKit.box(leaf, Vector3(win_w, win_h, 0.012), Vector3(0, win_y, -0.016), wired_glass_mat(glow), "Window")
	# 扉の枠（ステンレス）
	MeshKit.box(n, Vector3(0.04, 2.04, 0.06), Vector3(-DOOR_W * 0.5 - 0.02, 1.02, -0.005), steel, "FrameL")
	MeshKit.box(n, Vector3(0.04, 2.04, 0.06), Vector3(DOOR_W * 0.5 + 0.02, 1.02, -0.005), steel, "FrameR")
	MeshKit.box(n, Vector3(DOOR_W + 0.08, 0.04, 0.06), Vector3(0, 2.02, -0.005), steel, "FrameTop")
	return n


var _doors: Node3D
var _arrow: Label3D
var _floor_label: Label3D


## いま表示する階（▼ の横の数字）。
func set_floor(n: int) -> void:
	if _floor_label:
		_floor_label.text = str(n)


## 扉を開ける（左右へ 0.2m ずつ）。
func open_doors(seconds := 1.2) -> Tween:
	var tw := create_tween().set_parallel(true)
	var l := _doors.get_node("LeafL") as Node3D
	var r := _doors.get_node("LeafR") as Node3D
	tw.tween_property(l, "position:x", DOOR_W * 0.25 + 0.2, seconds)
	tw.tween_property(r, "position:x", -DOOR_W * 0.25 - 0.2, seconds)
	return tw


func close_doors_now() -> void:
	(_doors.get_node("LeafL") as Node3D).position.x = DOOR_W * 0.25
	(_doors.get_node("LeafR") as Node3D).position.x = -DOOR_W * 0.25


func _ready() -> void:
	MeshKit.auto_round = false
	_build_shell()
	_build_panel()
	_build_light()
	MeshKit.auto_round = true


func _wall_mat() -> StandardMaterial3D:
	return MeshKit.tiled_mat("elev_wood", TEX_DOOR, 0.45, Color(0.97, 0.97, 0.95), 0.7)


func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	add_child(shell)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	shell.add_child(body)
	var wall := _wall_mat()
	var floor_m := MeshKit.mat("elev_floor", Color(0.27, 0.27, 0.29), 0.8)
	var steel := MeshKit.mat("elev_steel", Color(0.72, 0.73, 0.75), 0.35, 0.85)
	_solid(shell, body, Vector3(W + 0.2, 0.2, D + 0.2), Vector3(0, -0.1, 0), floor_m, "Floor")
	MeshKit.box(shell, Vector3(W + 0.2, 0.1, D + 0.2), Vector3(0, H + 0.05, 0), MeshKit.mat("elev_ceiling", Color(0.9, 0.9, 0.88), 0.8), "Ceiling")
	_solid(shell, body, Vector3(W + 0.2, H, 0.1), Vector3(0, H * 0.5, -D * 0.5 - 0.05), wall, "BackWall")
	_solid(shell, body, Vector3(0.1, H, D), Vector3(-W * 0.5 - 0.05, H * 0.5, 0), wall, "LeftWall")
	_solid(shell, body, Vector3(0.1, H, D), Vector3(W * 0.5 + 0.05, H * 0.5, 0), wall, "RightWall")
	# 前の壁：扉の左（細い）・扉の右（操作盤のある幅）・扉の上
	var fz := D * 0.5 + 0.05
	var dl := DOOR_X - DOOR_W * 0.5 - 0.04
	var dr := DOOR_X + DOOR_W * 0.5 + 0.04
	_solid(shell, body, Vector3(dl + W * 0.5, H, 0.1), Vector3((dl - W * 0.5) * 0.5, H * 0.5, fz), wall, "FrontLeft")
	_solid(shell, body, Vector3(W * 0.5 - dr, H, 0.1), Vector3((dr + W * 0.5) * 0.5, H * 0.5, fz), wall, "FrontRight")
	_solid(shell, body, Vector3(dr - dl, H - 2.06, 0.1), Vector3((dl + dr) * 0.5, 2.06 + (H - 2.06) * 0.5, fz), wall, "FrontTop")
	# 閉まった扉（箱の内側の面に合わせる）
	_doors = build_doors(shell, Vector3(DOOR_X, 0.0, D * 0.5 - 0.02), _wall_mat(), false, true)
	# 扉の外（廊下の暗がり）：窓の向こうに見える
	MeshKit.box(shell, Vector3(DOOR_W + 0.4, 2.1, 0.02), Vector3(DOOR_X, 1.05, D * 0.5 + 0.12), MeshKit.mat("elev_beyond", Color(0.16, 0.14, 0.12), 0.9), "Beyond")
	# 手すり（後ろの壁）
	MeshKit.box(shell, Vector3(1.0, 0.035, 0.035), Vector3(0, 0.9, -D * 0.5 + 0.05), steel, "Handrail")
	for xx in [-0.45, 0.45]:
		MeshKit.box(shell, Vector3(0.03, 0.03, 0.06), Vector3(xx, 0.9, -D * 0.5 + 0.03), steel, "HandrailPost")


func _solid(parent: Node3D, body: StaticBody3D, size: Vector3, center: Vector3, m: Material, node_name := "") -> void:
	MeshKit.box(parent, size, center, m, node_name)
	MeshKit.shape_box(body, size, center)


func _label(text: String, size: int, px: float, color: Color, pos: Vector3, node_name := "") -> Label3D:
	var l := Label3D.new()
	l.name = node_name if not node_name.is_empty() else "Text"
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = color
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = PI   # 前の壁（+z）に付けた物を、箱の中（-z 側）から見る向き
	add_child(l)
	return l


func _build_panel() -> void:
	var steel := MeshKit.mat("elev_steel", Color(0.72, 0.73, 0.75), 0.35, 0.85)
	var z := D * 0.5 - 0.004
	# ステンレスの板（縦長）
	MeshKit.box(self, Vector3(0.2, 1.3, 0.012), Vector3(PANEL_X, 1.3, z), steel, "PanelPlate")
	# 階の表示（白い小窓に、▼ と 5）
	MeshKit.box(self, Vector3(0.12, 0.16, 0.01), Vector3(PANEL_X, 1.84, z - 0.008), MeshKit.mat("elev_display", Color(0.9, 0.9, 0.88), 0.4), "Display")
	_arrow = _label("▼", 64, 0.0006, Color(0.15, 0.15, 0.17), Vector3(PANEL_X, 1.885, z - 0.0145), "Arrow")
	_floor_label = _label("5", 96, 0.0007, Color(0.2, 0.2, 0.22), Vector3(PANEL_X, 1.82, z - 0.0145), "Floor")
	# スピーカーの穴（二列の短いスリット）
	for xx in [-0.03, 0.03]:
		for k in 3:
			MeshKit.box(self, Vector3(0.04, 0.004, 0.004), Vector3(PANEL_X + xx, 1.7 - k * 0.012, z - 0.008), MeshKit.mat("elev_slot", Color(0.08, 0.08, 0.09), 0.9), "Slot")
	# 銘板：用途・定員・積載・禁煙
	MeshKit.box(self, Vector3(0.15, 0.1, 0.006), Vector3(PANEL_X, 1.56, z - 0.008), MeshKit.mat("elev_plate", Color(0.06, 0.06, 0.07), 0.6), "Plate")
	_label("用途　乗　用\n定員　 6 名\n積載 450 Kg\n　　禁　煙", 40, 0.00042, Color(0.92, 0.92, 0.9), Vector3(PANEL_X, 1.56, z - 0.0125), "PlateText")
	# 非常呼び出し（赤い電話のボタン）
	var bezel := MeshKit.cylinder(self, 0.026, 0.008, Vector3(PANEL_X, 1.42, z - 0.008), steel, "CallBezel")
	bezel.rotation.x = deg_to_rad(90.0)
	var red := MeshKit.mat("elev_call_red", Color(0.75, 0.1, 0.08), 0.4)
	red.emission_enabled = true
	red.emission = Color(0.8, 0.1, 0.05)
	red.emission_energy_multiplier = 0.5
	MeshKit.cylinder(self, 0.016, 0.004, Vector3(PANEL_X, 1.42, z - 0.013), red, "CallRed").rotation.x = deg_to_rad(90.0)
	# 行き先ボタン：左の列 4・3・2、右の列 7・6・5。その下に 1（点灯）
	var rows := [[1.3, "4", "7"], [1.22, "3", "6"], [1.14, "2", "5"]]
	for r in rows:
		_button(Vector3(PANEL_X + 0.045, r[0], z), r[1], false)   # 前を向いて左の列（+x 側）
		_button(Vector3(PANEL_X - 0.045, r[0], z), r[2], false)
	_button(Vector3(PANEL_X, 1.04, z), "1", true)
	# 開く・閉じる
	_button(Vector3(PANEL_X + 0.045, 0.94, z), "◀▶", false)
	_button(Vector3(PANEL_X - 0.045, 0.94, z), "▶◀", false)
	# 下の鍵つきの小さな蓋
	MeshKit.box(self, Vector3(0.14, 0.26, 0.006), Vector3(PANEL_X, 0.7, z - 0.008), MeshKit.mat("elev_service", Color(0.62, 0.63, 0.65), 0.4, 0.7), "ServiceCover")
	_label("非常時\n取扱い", 28, 0.0004, Color(0.2, 0.2, 0.22), Vector3(PANEL_X, 0.76, z - 0.0125), "ServiceText")


func _button(pos: Vector3, text: String, lit: bool) -> void:
	var steel := MeshKit.mat("elev_steel", Color(0.72, 0.73, 0.75), 0.35, 0.85)
	var ring := MeshKit.cylinder(self, 0.027, 0.01, pos + Vector3(0, 0, -0.008), steel, "ButtonRing")
	ring.rotation.x = deg_to_rad(90.0)
	var face_m := MeshKit.mat("elev_button_lit" if lit else "elev_button", Color(0.82, 0.83, 0.85) if not lit else Color(1.0, 0.95, 0.82), 0.3, 0.6 if not lit else 0.2)
	if lit:
		face_m.emission_enabled = true
		face_m.emission = Color(1.0, 0.85, 0.55)
		face_m.emission_energy_multiplier = 1.4
	var face := MeshKit.cylinder(self, 0.022, 0.006, pos + Vector3(0, 0, -0.0135), face_m, "Button")
	face.rotation.x = deg_to_rad(90.0)
	_label(text, 56 if text.length() == 1 else 36, 0.00045, Color(0.12, 0.12, 0.14), pos + Vector3(0, 0, -0.0175), "Digit")


func _build_light() -> void:
	var lamp := MeshKit.mat("elev_lamp", Color(1.0, 0.98, 0.92), 0.4)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.96, 0.88)
	lamp.emission_energy_multiplier = 1.6
	MeshKit.box(self, Vector3(0.9, 0.02, 0.9), Vector3(0, H - 0.01, 0), lamp, "CeilingLamp")
	var l := OmniLight3D.new()
	l.name = "CarLight"
	l.position = Vector3(0, H - 0.3, -0.1)
	l.light_color = Color(1.0, 0.96, 0.88)
	l.light_energy = 0.9
	l.omni_range = 3.5
	add_child(l)
