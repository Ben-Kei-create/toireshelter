extends Node3D
## トイレの奥の壁の額縁の絵（ひまわり）。下の小さなボタンを押すと、絵が上へスライドして、後ろから、このマンション 5 階の地図が出てくる。
## 絵と地図は、コードで描く（ひまわり：花びらの輪と種の円、花瓶）。原点は壁の面（絵の中心の高さ）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")

const SIZE := Vector2(0.5, 0.38)
const SLIDE := 0.46          # 絵が上へ動く量
const SLIDE_TIME := 0.9

var painting: Node3D
var slid := false
var busy := false
var map_node: Node3D
static var _tex: ImageTexture


## ひまわりの絵を描く（256×192）。
static func sunflower_texture() -> ImageTexture:
	if _tex != null:
		return _tex
	var w := 256
	var h := 192
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var t := float(y) / h
			img.set_pixel(x, y, Color(0.86, 0.84, 0.72).lerp(Color(0.62, 0.7, 0.78), 1.0 - t * 1.3 if t < 0.77 else 0.0) if t < 0.77 else Color(0.5, 0.36, 0.22))
	# 花瓶
	for y in range(120, 188):
		var half := 22.0 + 12.0 * sin(float(y - 120) / 68.0 * PI) 
		for x in range(int(128.0 - half), int(128.0 + half)):
			if x >= 0 and x < w:
				var shade := 0.85 + 0.15 * sin(float(x) * 0.12)
				img.set_pixel(x, y, Color(0.22, 0.38, 0.55) * shade)
	var flowers := [[128, 66, 34], [78, 80, 26], [178, 82, 27], [104, 38, 22], [158, 34, 21], [52, 116, 18], [204, 118, 18]]
	for f in flowers:
		var fx: int = f[0]
		var fy: int = f[1]
		var r: int = f[2]
		# 茎
		var x0 := float(fx)
		for y in range(fy, 125):
			var xx := int(lerpf(x0, 128.0, float(y - fy) / float(125 - fy)))
			for dx in 2:
				if xx + dx >= 0 and xx + dx < w:
					img.set_pixel(xx + dx, y, Color(0.25, 0.5, 0.2))
		# 葉
		for k in 2:
			var lx := int(lerpf(x0, 128.0, 0.55)) + (-1 if k == 0 else 1) * 12
			var ly := fy + int(float(125 - fy) * 0.55)
			for yy in range(-5, 6):
				for xx in range(-12, 13):
					if float(xx * xx) / 144.0 + float(yy * yy) / 25.0 < 1.0:
						var px := lx + xx
						var py := ly + yy
						if px >= 0 and px < w and py >= 0 and py < h:
							img.set_pixel(px, py, Color(0.2, 0.46, 0.18))
		# 花びら（外側の黄色の輪）と、中心の種
		for yy in range(-r - 6, r + 7):
			for xx in range(-r - 6, r + 7):
				var d := sqrt(float(xx * xx + yy * yy))
				var ang := atan2(float(yy), float(xx))
				var edge := float(r) * (0.82 + 0.28 * absf(sin(ang * 6.0)))
				var px := fx + xx
				var py := fy + yy
				if px < 0 or px >= w or py < 0 or py >= h:
					continue
				if d < float(r) * 0.42:
					var seed_c := Color(0.32, 0.2, 0.08)
					if int(float(xx) * 0.7 + float(yy) * 0.7) % 3 == 0:
						seed_c = Color(0.2, 0.12, 0.05)
					img.set_pixel(px, py, seed_c)
				elif d < edge:
					img.set_pixel(px, py, Color(0.98, 0.78, 0.12) if d > float(r) * 0.55 else Color(0.85, 0.55, 0.08))
	_tex = ImageTexture.create_from_image(img)
	return _tex


func _ready() -> void:
	name = "PaintingMap"
	var gold := MeshKit.mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	# 地図（絵の後ろの壁）
	map_node = Node3D.new()
	map_node.name = "FloorMap"
	map_node.position = Vector3(0, 0, 0.004)
	add_child(map_node)
	_build_map(map_node, gold)
	# 絵（額縁つき）：前へ少し出ていて、上へスライドする
	painting = Node3D.new()
	painting.name = "Painting"
	painting.position = Vector3(0, 0, 0.02)
	add_child(painting)
	var canvas := MeshKit.image_quad(painting, sunflower_texture(), SIZE - Vector2(0.04, 0.04), Vector3(0, 0, 0.012), Vector3.BACK, "Canvas", false, 0.7)
	(canvas.material_override as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var f := 0.028
	MeshKit.box(painting, Vector3(SIZE.x, f, 0.03), Vector3(0, SIZE.y * 0.5 - f * 0.5, 0.01), gold, "FrameTop")
	MeshKit.box(painting, Vector3(SIZE.x, f, 0.03), Vector3(0, -SIZE.y * 0.5 + f * 0.5, 0.01), gold, "FrameBottom")
	MeshKit.box(painting, Vector3(f, SIZE.y, 0.03), Vector3(-SIZE.x * 0.5 + f * 0.5, 0, 0.01), gold, "FrameLeft")
	MeshKit.box(painting, Vector3(f, SIZE.y, 0.03), Vector3(SIZE.x * 0.5 - f * 0.5, 0, 0.01), gold, "FrameRight")
	MeshKit.box(painting, Vector3(SIZE.x - 0.04, SIZE.y - 0.04, 0.008), Vector3(0, 0, 0.004), MeshKit.mat("painting_back", Color(0.1, 0.06, 0.04), 0.9), "Back")
	var pa := MeshKit.interact_area(painting, "PaintingArea", "sunflower_painting", null)
	MeshKit.shape_box(pa, Vector3(SIZE.x, SIZE.y, 0.08), Vector3(0, 0, 0.03))
	# 下の小さなボタン（金の枠に赤い丸）
	var bt := Node3D.new()
	bt.name = "Button"
	bt.position = Vector3(0, -SIZE.y * 0.5 - 0.06, 0.012)
	add_child(bt)
	MeshKit.cylinder(bt, 0.022, 0.012, Vector3(0, 0, 0), gold, "Rim", -1.0, 16).rotation.x = deg_to_rad(90.0)
	var red := MeshKit.mat("painting_button", Color(0.75, 0.08, 0.1), 0.3)
	MeshKit.cylinder(bt, 0.015, 0.016, Vector3(0, 0, 0.004), red, "Cap", -1.0, 16).rotation.x = deg_to_rad(90.0)
	var ba := MeshKit.interact_area(bt, "ButtonArea", "painting_button", null)
	MeshKit.shape_box(ba, Vector3(0.1, 0.1, 0.08), Vector3(0, 0, 0.03))
	# 地図を調べる判定（絵がどいたあとだけ有効）
	var ma := MeshKit.interact_area(map_node, "MapArea", "floor_map", null)
	MeshKit.shape_box(ma, Vector3(SIZE.x, SIZE.y, 0.06), Vector3(0, 0, 0.03))
	ma.collision_layer = 0


## 5 階の地図：部屋 501〜505 が横一列にならび、その前に共用廊下。左端に階段、右端にエレベーター。503（ここ）に印。
func _build_map(parent: Node3D, gold: Material) -> void:
	var w := SIZE.x - 0.03
	var h := SIZE.y - 0.03
	MeshKit.box(parent, Vector3(w + 0.012, h + 0.012, 0.004), Vector3.ZERO, gold, "MapFrame")
	MeshKit.box(parent, Vector3(w, h, 0.004), Vector3(0, 0, 0.003), MeshKit.mat("map_paper", Color(0.93, 0.88, 0.74), 0.9), "MapPaper")
	var ink := MeshKit.mat("map_ink", Color(0.2, 0.12, 0.08), 0.9)
	var room_w := w / 5.2
	var x0 := -w * 0.5 + 0.012
	var rooms := ["501", "502", "503", "504", "505"]
	var notes := {"502": "お隣", "503": "いまここ", "504": "おばあちゃん"}
	for i in 5:
		var cx := x0 + room_w * (i + 0.5) + 0.002 * i
		var fill: Material = MeshKit.mat("map_room", Color(0.82, 0.75, 0.6), 0.9)
		if rooms[i] == "503":
			fill = MeshKit.mat("map_room_here", Color(0.85, 0.25, 0.22), 0.7)
		MeshKit.box(parent, Vector3(room_w - 0.006, h * 0.5, 0.003), Vector3(cx, h * 0.2, 0.0055), fill, "Room" + rooms[i])
		_label(parent, rooms[i], Vector3(cx, h * 0.27, 0.008), 0.0085, Color(0.15, 0.08, 0.05))
		if notes.has(rooms[i]):
			_label(parent, notes[rooms[i]], Vector3(cx, h * 0.14, 0.008), 0.0052, Color(0.15, 0.08, 0.05) if rooms[i] != "503" else Color(1, 0.95, 0.85))
		MeshKit.box(parent, Vector3(0.012, 0.004, 0.0035), Vector3(cx, h * 0.2 - h * 0.25 + 0.002, 0.007), ink, "Door" + rooms[i])   # 玄関の戸
	# 共用廊下
	MeshKit.box(parent, Vector3(w - 0.02, h * 0.18, 0.003), Vector3(0, -h * 0.16, 0.0055), MeshKit.mat("map_corridor", Color(0.7, 0.66, 0.58), 0.9), "Corridor")
	_label(parent, "共用廊下", Vector3(0, -h * 0.16, 0.008), 0.0058, Color(0.25, 0.2, 0.15))
	MeshKit.box(parent, Vector3(room_w * 0.9, h * 0.22, 0.003), Vector3(x0 + room_w * 0.5 - 0.005, -h * 0.37, 0.0055), MeshKit.mat("map_stairs", Color(0.6, 0.62, 0.66), 0.9), "Stairs")
	_label(parent, "階段", Vector3(x0 + room_w * 0.5 - 0.005, -h * 0.37, 0.008), 0.0058, Color(0.1, 0.1, 0.14))
	MeshKit.box(parent, Vector3(room_w * 0.9, h * 0.22, 0.003), Vector3(-x0 - room_w * 0.5 + 0.005, -h * 0.37, 0.0055), MeshKit.mat("map_elev", Color(0.5, 0.55, 0.5), 0.9), "Elevator")
	_label(parent, "EV", Vector3(-x0 - room_w * 0.5 + 0.005, -h * 0.37, 0.008), 0.0065, Color(0.05, 0.1, 0.05))
	_label(parent, "コーポヨシミ　5 F", Vector3(0, h * 0.44, 0.008), 0.0075, Color(0.3, 0.15, 0.1))


func _label(parent: Node3D, text: String, pos: Vector3, px: float, col: Color) -> void:
	if px <= 0.0:
		return
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px * 0.1
	l.font_size = 40
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	l.shaded = false
	l.double_sided = false
	parent.add_child(l)


## 絵を上へスライドさせる／もとへ戻す。
func toggle() -> void:
	if busy:
		return
	busy = true
	slid = not slid
	Sfx.play("slide", 0.9)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(painting, "position:y", SLIDE if slid else 0.0, SLIDE_TIME)
	tw.tween_callback(func() -> void:
		busy = false
		var pa := get_node("Painting/PaintingArea") as Area3D
		pa.collision_layer = MeshKit.LAYER_INTERACT if not slid else 0
		(map_node.get_node("MapArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT if slid else 0)
	if slid:
		(get_node("Painting/PaintingArea") as Area3D).collision_layer = 0


func set_slid(on: bool) -> void:
	if slid == on:
		return
	slid = on
	painting.position.y = SLIDE if on else 0.0
	(get_node("Painting/PaintingArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT if not on else 0
	(map_node.get_node("MapArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT if on else 0
