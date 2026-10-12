extends Node3D
## 浴室のドアの外の玄関ホールと、自分の部屋（TASK-10）。座標は部屋と同じ（この節点は原点に置く）。
##
##   Hall    … x -0.9〜0.9, z 1.3〜2.4、天井 2.2。浴室のドアの外。右の壁（x 0.9〜1.0）の出入口 z 1.5〜2.2 から自室へ
##   OwnRoom … x 1.0〜4.0, z -1.2〜2.4（約3.0×3.6m）、天井 2.4。左の壁の手前側は浴室の右の壁を共有する。
##             奥の壁（z -1.3〜-1.2、外壁）に掃き出し窓（x 1.8〜3.2）。窓の外がベランダ（exterior.gd）
## 狭い一人暮らしの部屋に、美術館・カードショップ・大型玩具店ほどの収集物を詰める（壁際と上方に密集、中央は通路）：
##   右の壁一面の本棚／左の壁のカード展示ケース（下に机と椅子）／奥の壁と手前の壁のフィギュア棚／
##   大きな多面体の宝石（台座つき）／大小の額装絵画／小さな寝床
## 本とカードは MultiMesh で軽く作る。当たり判定は大きな家具ごとの単純な箱だけ。展示品の取得や個別操作はなし。

const MeshKit := preload("res://scripts/mesh_kit.gd")

# 素材（docs/assets.md の ASSETS-30）
const TEX_GRANITE := preload("res://assets/textures/surfaces/surface_01.png")
const TEX_BASALT := preload("res://assets/textures/surfaces/surface_02.png")
const TEX_SANDSTONE := preload("res://assets/textures/surfaces/surface_03.png")
const TEX_PURPLE := preload("res://assets/textures/surfaces/surface_04.png")
const TEX_WALLPAPER := preload("res://assets/textures/surfaces/surface_06.png")
const TEX_SHELF_WOOD := preload("res://assets/textures/surfaces/surface_09.png")
const TEX_CURTAIN := preload("res://assets/textures/surfaces/surface_12.png")
const TEX_PAINTING_A := preload("res://assets/textures/surfaces/surface_13.png")
const TEX_PAINTING_B := preload("res://assets/textures/surfaces/surface_14.png")
const TEX_CARD_BACK := preload("res://assets/textures/surfaces/surface_15.png")
const BOOK_COUNT := 15
const BOOK_H := 0.26              # 表紙を見せて置く本の高さ（m）
const BOOK_T := 0.028             # 厚み

const ROOM := AABB(Vector3(1.0, 0.0, -1.2), Vector3(3.0, 2.4, 3.6))
const HALL := AABB(Vector3(-0.9, 0.0, 1.3), Vector3(1.8, 2.2, 1.1))
const DOORWAY_Z := Vector2(1.5, 2.2)
const DOORWAY_H := 2.0
const WALL_T := 0.1
const WINDOW_X := Vector2(1.8, 3.2)
const WINDOW_TOP := 2.0
const WINDOW_SLIDE := 0.68
const WINDOW_TIME := 0.5

var window_open := false
var window_busy := false
var window_panel: Node3D   # 外側のレールの引き違い窓（開けると右へ）
var curtain: Node3D        # 窓の内側のカーテン。閉じているとベランダから部屋は見えず、窓を開けると一緒に右へ寄る
var _rng := RandomNumberGenerator.new()
var _body: StaticBody3D


func _ready() -> void:
	_rng.seed = 1010
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_body.collision_layer = MeshKit.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_build_hall()
	_build_room_shell()
	_build_window()
	_build_bookshelf()
	_build_card_case()
	_build_desk_and_chair()
	_build_figure_shelves()
	_build_gem()
	_build_paintings()
	_build_bed()
	_build_specimens()
	_build_lights()


## 壁などの静的な箱（見た目と当たり判定）。
func _solid(size: Vector3, center: Vector3, m: Material, node_name := "") -> MeshInstance3D:
	MeshKit.shape_box(_body, size, center)
	return MeshKit.box(self, size, center, m, node_name)


# ---------------------------------------------------------------- 玄関ホール

func _build_hall() -> void:
	var wall := MeshKit.mat("hall_wall", Color(0.82, 0.8, 0.76))
	var floor_m := MeshKit.mat("hall_floor", Color(0.5, 0.36, 0.24), 0.7)
	var ceil_m := MeshKit.mat("ceiling", Color(0.95, 0.95, 0.95))
	var z0 := HALL.position.z
	var z1 := HALL.end.z
	var cz := (z0 + z1) * 0.5
	var d := z1 - z0
	_solid(Vector3(2.0, WALL_T, d), Vector3(0.0, -WALL_T * 0.5, cz), floor_m)
	_solid(Vector3(2.0, WALL_T, d), Vector3(0.0, HALL.end.y + WALL_T * 0.5, cz), ceil_m)
	_solid(Vector3(WALL_T, HALL.end.y, d), Vector3(-0.95, HALL.end.y * 0.5, cz), wall)          # 左
	_solid(Vector3(2.0, HALL.end.y, WALL_T), Vector3(0.0, HALL.end.y * 0.5, z1 + WALL_T * 0.5), wall)   # 突き当たり
	# 右の壁（自室との境）。出入口 z 1.5〜2.2、高さ 2.0 を空ける
	var rx := 0.95
	_solid(Vector3(WALL_T, HALL.end.y, DOORWAY_Z.x - z0), Vector3(rx, HALL.end.y * 0.5, (z0 + DOORWAY_Z.x) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y, z1 - DOORWAY_Z.y), Vector3(rx, HALL.end.y * 0.5, (DOORWAY_Z.y + z1) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y - DOORWAY_H, DOORWAY_Z.y - DOORWAY_Z.x), Vector3(rx, (DOORWAY_H + HALL.end.y) * 0.5, (DOORWAY_Z.x + DOORWAY_Z.y) * 0.5), wall)


# ---------------------------------------------------------------- 自室の外殻

func _build_room_shell() -> void:
	# 自室の壁紙。模様が強くなりすぎないよう小さめ（横 0.3m）で繰り返す
	var wall := MeshKit.tiled_mat("room_wallpaper", MeshKit.faded_texture(TEX_WALLPAPER, 0.4), 0.3, Color.WHITE, 0.9)
	var floor_m := MeshKit.mat("room_floor", Color(0.55, 0.42, 0.3), 0.7)
	var ceil_m := MeshKit.mat("ceiling", Color(0.95, 0.95, 0.95))
	var x0 := ROOM.position.x
	var x1 := ROOM.end.x
	var z0 := ROOM.position.z
	var z1 := ROOM.end.z
	var h := ROOM.end.y
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	_solid(Vector3(x1 - x0 + WALL_T * 2.0, WALL_T, z1 - z0 + WALL_T * 2.0), Vector3(cx, -WALL_T * 0.5, cz), floor_m, "RoomFloor")
	_solid(Vector3(x1 - x0 + WALL_T * 2.0, WALL_T, z1 - z0 + WALL_T * 2.0), Vector3(cx, h + WALL_T * 0.5, cz), ceil_m, "RoomCeiling")
	_solid(Vector3(WALL_T, h, z1 - z0), Vector3(x1 + WALL_T * 0.5, h * 0.5, cz), wall)              # 右
	_solid(Vector3(x1 - x0 + WALL_T * 2.0, h, WALL_T), Vector3(cx, h * 0.5, z1 + WALL_T * 0.5), wall)   # 手前
	# 左の壁：浴室と共有する部分（z -1.2〜1.2）は浴室の壁（高さ 2.2）。その上 2.2〜2.4 と、ホール側の高い部分を足す
	_solid(Vector3(WALL_T, h - 2.2, 2.5), Vector3(0.95, 2.3, -0.05), wall)
	_solid(Vector3(WALL_T, h - HALL.end.y, HALL.end.z - 1.2), Vector3(0.95, (HALL.end.y + h) * 0.5, (1.2 + HALL.end.z) * 0.5), wall)
	# 左の壁の内張り（6mm）：浴室側の壁の外面・天井板の断面・鏡裏収納の背板を自室から隠す。出入口を空ける
	var lx := x0 + 0.003
	var lin := func(z_a: float, z_b: float, y_a: float, y_b: float) -> void:
		MeshKit.box(self, Vector3(0.006, y_b - y_a, z_b - z_a), Vector3(lx, (y_a + y_b) * 0.5, (z_a + z_b) * 0.5), wall)
	lin.call(z0, DOORWAY_Z.x, 0.0, h)
	lin.call(DOORWAY_Z.y, z1, 0.0, h)
	lin.call(DOORWAY_Z.x, DOORWAY_Z.y, DOORWAY_H, h)
	# 奥の壁（外壁）：掃き出し窓（x 1.8〜3.2、高さ 0〜2.0）を空ける
	var bz := z0 - WALL_T * 0.5
	_solid(Vector3(WINDOW_X.x - (x0 - WALL_T), h, WALL_T), Vector3((x0 - WALL_T + WINDOW_X.x) * 0.5, h * 0.5, bz), wall)
	_solid(Vector3(x1 + WALL_T - WINDOW_X.y, h, WALL_T), Vector3((WINDOW_X.y + x1 + WALL_T) * 0.5, h * 0.5, bz), wall)
	_solid(Vector3(WINDOW_X.y - WINDOW_X.x, h - WINDOW_TOP, WALL_T), Vector3((WINDOW_X.x + WINDOW_X.y) * 0.5, (WINDOW_TOP + h) * 0.5, bz), wall)


# ---------------------------------------------------------------- 掃き出し窓

func _build_window() -> void:
	var frame := MeshKit.mat("alu", Color(0.7, 0.71, 0.72), 0.35, 0.6)
	var glass := MeshKit.mat("window_glass", Color(0.7, 0.8, 0.85, 0.25), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var w := (WINDOW_X.y - WINDOW_X.x) * 0.5 + 0.02
	var h := WINDOW_TOP - 0.02
	var bz := ROOM.position.z - WALL_T * 0.5
	# 内側のレールの固定窓（右）
	var fixed := Node3D.new()
	fixed.name = "WindowFixed"
	fixed.position = Vector3(WINDOW_X.y - w * 0.5, 0.0, bz + 0.02)
	add_child(fixed)
	_window_panel_mesh(fixed, w, h, frame, glass)
	MeshKit.shape_box(_body, Vector3(w, h, 0.03), fixed.position + Vector3(0, h * 0.5, 0))
	# 外側のレールの引き違い窓（左。開けると固定窓の後ろへ）
	window_panel = Node3D.new()
	window_panel.name = "WindowSliding"
	window_panel.position = Vector3(WINDOW_X.x + w * 0.5, 0.0, bz - 0.02)
	add_child(window_panel)
	_window_panel_mesh(window_panel, w, h, frame, glass)
	var slide_body := AnimatableBody3D.new()
	slide_body.name = "Collision"
	slide_body.collision_layer = MeshKit.LAYER_WORLD
	slide_body.collision_mask = 0
	slide_body.sync_to_physics = false
	window_panel.add_child(slide_body)
	MeshKit.shape_box(slide_body, Vector3(w, h, 0.03), Vector3(0, h * 0.5, 0))
	for p in [fixed, window_panel]:
		var area := MeshKit.interact_area(p, "WindowArea", "window", self)
		MeshKit.shape_box(area, Vector3(w, h, 0.05), Vector3(0, h * 0.5, 0))
	# 厚手のカーテン（見た目だけ。当たり判定なし）。原点を右端に置き、x 方向の縮みで寄せる
	curtain = Node3D.new()
	curtain.name = "Curtain"
	curtain.position = Vector3(WINDOW_X.y + 0.05, 0.0, ROOM.position.z + 0.06)
	add_child(curtain)
	var cloth := MeshKit.tiled_mat("curtain_tex", TEX_CURTAIN, 0.3, Color.WHITE, 0.95)
	var cw := WINDOW_X.y - WINDOW_X.x + 0.1
	for k in 7:   # ひだ
		var m := MeshKit.box(curtain, Vector3(cw / 7.0, 2.05, 0.02), Vector3(-cw / 7.0 * (k + 0.5), 2.05 * 0.5, 0.012 if k % 2 == 0 else -0.004), cloth)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# レール（床の溝）
	MeshKit.box(self, Vector3(WINDOW_X.y - WINDOW_X.x, 0.01, WALL_T), Vector3((WINDOW_X.x + WINDOW_X.y) * 0.5, 0.005, bz), frame, "Rail")


func _window_panel_mesh(parent: Node3D, w: float, h: float, frame: Material, glass: Material) -> void:
	var f := 0.035
	MeshKit.box(parent, Vector3(w, f, 0.03), Vector3(0, f * 0.5, 0), frame)
	MeshKit.box(parent, Vector3(w, f, 0.03), Vector3(0, h - f * 0.5, 0), frame)
	MeshKit.box(parent, Vector3(f, h, 0.03), Vector3(-w * 0.5 + f * 0.5, h * 0.5, 0), frame)
	MeshKit.box(parent, Vector3(f, h, 0.03), Vector3(w * 0.5 - f * 0.5, h * 0.5, 0), frame)
	var g := MeshKit.box(parent, Vector3(w - f * 2.0, h - f * 2.0, 0.006), Vector3(0, h * 0.5, 0), glass, "Glass")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func toggle_window() -> void:
	if window_busy:
		return
	window_busy = true
	window_open = not window_open
	var start_x := WINDOW_X.x + ((WINDOW_X.y - WINDOW_X.x) * 0.5 + 0.02) * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(window_panel, "position:x", start_x + (WINDOW_SLIDE if window_open else 0.0), WINDOW_TIME)
	tween.parallel().tween_property(curtain, "scale:x", 0.18 if window_open else 1.0, WINDOW_TIME)
	tween.tween_callback(func() -> void: window_busy = false)


func get_prompt(_id: String) -> String:
	if window_busy:
		return ""
	return "window_close" if window_open else "window_open"


func interact(_id: String) -> String:
	toggle_window()
	return ""


# ---------------------------------------------------------------- 本棚（右の壁一面）

func _build_bookshelf() -> void:
	var wood := MeshKit.tiled_mat("shelf_wood_tex", TEX_SHELF_WOOD, 0.5, Color.WHITE, 0.7)
	var x1 := ROOM.end.x
	var depth := 0.3
	var x0 := x1 - depth
	var z0 := -1.1
	var z1 := 2.3
	var top := 2.35
	var levels := 7
	var step := top / levels
	var root := Node3D.new()
	root.name = "Bookshelf"
	add_child(root)
	MeshKit.box(root, Vector3(0.02, top, z1 - z0), Vector3(x1 - 0.01, top * 0.5, (z0 + z1) * 0.5), wood)
	for zz in [z0, z1]:
		MeshKit.box(root, Vector3(depth, top, 0.025), Vector3(x0 + depth * 0.5, top * 0.5, zz), wood)
	for i in levels + 1:
		MeshKit.box(root, Vector3(depth, 0.022, z1 - z0), Vector3(x0 + depth * 0.5, i * step + 0.011, (z0 + z1) * 0.5), wood)
	MeshKit.shape_box(_body, Vector3(depth, top, z1 - z0), Vector3(x0 + depth * 0.5, top * 0.5, (z0 + z1) * 0.5))
	# 本：不揃いな厚さ・高さ・奥行き。ときどき傾いた本や横積み、形の違う箱
	var xforms := []
	var colors := []
	var palette := [Color(0.55, 0.15, 0.12), Color(0.15, 0.25, 0.45), Color(0.2, 0.4, 0.25), Color(0.75, 0.62, 0.3),
			Color(0.3, 0.2, 0.35), Color(0.85, 0.82, 0.75), Color(0.1, 0.1, 0.12), Color(0.6, 0.35, 0.45), Color(0.35, 0.5, 0.55)]
	# 表紙を見せて置く本（15冊）：段1〜5に3冊ずつ。その範囲には背表紙の本を置かない
	var face_out := []   # [段, z の中心, 番号]
	for k in BOOK_COUNT:
		var lv := 1 + k / 3
		var zc: float = [-0.62, 0.48, 1.62][k % 3] + (0.22 if lv % 2 == 0 else 0.0)
		face_out.append([lv, zc, k + 1])
	for i in levels:
		var base := i * step + 0.022
		var z := z0 + 0.03
		while z < z1 - 0.05:
			var skip := false
			for fo in face_out:
				if fo[0] == i and z > fo[1] - 0.14 and z < fo[1] + 0.14:
					z = fo[1] + 0.14
					skip = true
			if skip:
				continue
			var kind := _rng.randf()
			var thick := _rng.randf_range(0.015, 0.06)
			var height := minf(_rng.randf_range(0.14, 0.3), step - 0.04)
			var dep := _rng.randf_range(0.13, 0.26)
			var c: Color = palette[_rng.randi() % palette.size()]
			if kind < 0.1:   # 横積み
				var n := _rng.randi_range(2, 5)
				var w := _rng.randf_range(0.16, 0.24)
				for k in n:
					var tk := _rng.randf_range(0.02, 0.04)
					xforms.append(Transform3D(Basis.from_scale(Vector3(dep, tk, w)), Vector3(x1 - 0.03 - dep * 0.5, base + k * 0.035 + tk * 0.5, z + w * 0.5)))
					colors.append(palette[_rng.randi() % palette.size()])
				z += w + 0.01
				continue
			var tilt := deg_to_rad(_rng.randf_range(-14.0, 14.0)) if kind < 0.2 else 0.0
			var b := Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3(dep, height, thick))
			xforms.append(Transform3D(b, Vector3(x1 - 0.03 - dep * 0.5, base + height * 0.5, z + thick * 0.5)))
			colors.append(c)
			z += thick + (0.012 if tilt != 0.0 else 0.002)
	_multimesh(root, "Books", BoxMesh.new(), xforms, colors, MeshKit.mat("book_base", Color.WHITE, 0.8))
	for fo in face_out:
		_face_out_book(root, fo[2], Vector3(x1 - 0.2, fo[0] * step + 0.022, fo[1]))


## 表紙を部屋側（-x）へ向けて立てた本。表紙の画像は正面だけ。厚み・背表紙・裏表紙は単色の箱。
func _face_out_book(root: Node3D, n: int, base: Vector3) -> void:
	var tex: Texture2D = load("res://assets/textures/books/book_cover_%02d.png" % n)
	var w := BOOK_H * float(tex.get_width()) / float(tex.get_height())
	var book := Node3D.new()
	book.name = "Book%02d" % n
	book.position = base
	book.rotation.z = deg_to_rad(-7.0)   # 少し後ろ（壁側）へもたせかける
	root.add_child(book)
	var body_col := _rng.randf_range(0.2, 0.5)
	MeshKit.box(book, Vector3(BOOK_T, BOOK_H, w), Vector3(BOOK_T * 0.5, BOOK_H * 0.5, 0), MeshKit.mat("book_body_%d" % n, Color(body_col, body_col * 0.9, body_col * 0.8), 0.8), "Body")
	MeshKit.box(book, Vector3(BOOK_T - 0.004, BOOK_H - 0.006, w - 0.003), Vector3(BOOK_T * 0.5, BOOK_H * 0.5, 0.002), MeshKit.mat("book_pages", Color(0.92, 0.89, 0.8), 0.9), "Pages")
	var quad := QuadMesh.new()
	quad.size = Vector2(w, BOOK_H)
	var cover := MeshInstance3D.new()
	cover.name = "Cover"
	cover.mesh = quad
	cover.material_override = MeshKit.texture_mat("book_cover_%02d" % n, tex, 0.7)
	cover.position = Vector3(-0.0008, BOOK_H * 0.5, 0)
	cover.rotation.y = -PI * 0.5   # 表（+z）を -x（部屋側）へ。画像の左が部屋から見て左（+z 側）
	book.add_child(cover)


func _multimesh(parent: Node3D, node_name: String, mesh: Mesh, xforms: Array, colors: Array, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	material.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = material
	parent.add_child(mmi)
	return mmi


# ---------------------------------------------------------------- カード展示ケース（左の壁）

func _build_card_case() -> void:
	var root := Node3D.new()
	root.name = "CardCase"
	add_child(root)
	var x0 := ROOM.position.x + 0.006   # 左の壁の内張りの手前
	var depth := 0.13
	var z0 := -0.95
	var z1 := 1.1
	var y0 := 0.95
	var y1 := 2.25
	var frame := MeshKit.mat("case_frame", Color(0.12, 0.12, 0.14), 0.4, 0.4)
	var back := MeshKit.mat("case_back", Color(0.12, 0.16, 0.3), 0.8)
	var glass := MeshKit.mat("case_glass", Color(0.8, 0.9, 1.0, 0.12), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cz := (z0 + z1) * 0.5
	var cy := (y0 + y1) * 0.5
	MeshKit.box(root, Vector3(0.01, y1 - y0, z1 - z0), Vector3(x0 + 0.005, cy, cz), back)
	for yy in [y0, y1]:
		MeshKit.box(root, Vector3(depth, 0.025, z1 - z0), Vector3(x0 + depth * 0.5, yy, cz), frame)
	for zz in [z0, z1]:
		MeshKit.box(root, Vector3(depth, y1 - y0, 0.025), Vector3(x0 + depth * 0.5, cy, zz), frame)
	var g := MeshKit.box(root, Vector3(0.005, y1 - y0, z1 - z0), Vector3(x0 + depth, cy, cz), glass, "Glass")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.shape_box(_body, Vector3(depth, y1 - y0, z1 - z0), Vector3(x0 + depth * 0.5, cy, cz))
	# 段とカード（仮の独自図形）。カードは少し後ろに傾けて立てる
	var rows := 5
	var card_xf := []
	var card_col := []
	var back_xf := []
	var sym := {"disc": [[], []], "tri": [[], []], "diamond": [[], []]}
	var shelf := MeshKit.mat("case_shelf", Color(0.7, 0.75, 0.8, 0.5), 0.1)
	shelf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var card_palette := [Color(0.95, 0.92, 0.85), Color(0.85, 0.9, 0.95), Color(0.95, 0.85, 0.85), Color(0.2, 0.2, 0.25)]
	var sym_palette := [Color(0.9, 0.3, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.75, 0.15), Color(0.3, 0.7, 0.4), Color(0.6, 0.3, 0.8)]
	for r in rows:
		var sy := y0 + 0.03 + r * ((y1 - y0 - 0.05) / rows)
		MeshKit.box(root, Vector3(depth - 0.02, 0.008, z1 - z0 - 0.05), Vector3(x0 + depth * 0.5, sy - 0.004, cz), shelf)
		var z := z0 + 0.06
		while z < z1 - 0.06:
			var tilt := Basis(Vector3.FORWARD, deg_to_rad(-12.0))
			var pos := Vector3(x0 + 0.05, sy + 0.045, z)
			card_xf.append(Transform3D(tilt * Basis.from_scale(Vector3(0.004, 0.088, 0.063)), pos))
			card_col.append(card_palette[_rng.randi() % card_palette.size()])
			if _rng.randf() < 0.3:   # 3枚に1枚ほどは裏向き（裏面の模様）
				back_xf.append(Transform3D(tilt * Basis(Vector3.UP, PI * 0.5), pos + tilt * Vector3(0.0025, 0, 0)))
				z += 0.075
				continue
			var keys := sym.keys()
			var key: String = keys[_rng.randi() % keys.size()]
			var face := pos + tilt * Vector3(0.004, 0.005, 0.0)
			var s := _rng.randf_range(0.022, 0.034)
			var rot := Basis(Vector3.RIGHT, deg_to_rad(_rng.randf_range(0.0, 60.0)))
			sym[key][0].append(Transform3D(tilt * Basis(Vector3.FORWARD, deg_to_rad(90.0)) * rot * Basis.from_scale(Vector3(s, 0.002, s)), face))
			sym[key][1].append(sym_palette[_rng.randi() % sym_palette.size()])
			z += 0.075
	_multimesh(root, "Cards", BoxMesh.new(), card_xf, card_col, MeshKit.mat("card_base", Color.WHITE, 0.6))
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(0.063, 0.088)
	var back_mat := MeshKit.texture_mat("card_back", TEX_CARD_BACK, 0.6).duplicate() as StandardMaterial3D
	_multimesh(root, "CardBacks", back_quad, back_xf, back_xf.map(func(_x): return Color.WHITE), back_mat)
	back_mat.vertex_color_use_as_albedo = false
	var disc := CylinderMesh.new()
	disc.radial_segments = 16
	disc.rings = 1
	var tri := CylinderMesh.new()
	tri.radial_segments = 3
	tri.rings = 1
	var dia := CylinderMesh.new()
	dia.radial_segments = 4
	dia.rings = 1
	var meshes := {"disc": disc, "tri": tri, "diamond": dia}
	for key in sym:
		_multimesh(root, "Symbols_" + key, meshes[key], sym[key][0], sym[key][1], MeshKit.mat("symbol_base_" + key, Color.WHITE, 0.5))


# ---------------------------------------------------------------- 机と椅子

func _build_desk_and_chair() -> void:
	var wood := MeshKit.mat("desk_wood", Color(0.6, 0.48, 0.34), 0.6)
	var x0 := ROOM.position.x + 0.14   # カード展示ケースの手前
	var desk := Node3D.new()
	desk.name = "Desk"
	add_child(desk)
	MeshKit.box(desk, Vector3(0.5, 0.03, 0.75), Vector3(x0 + 0.25, 0.72, -0.55), wood)
	for p in [Vector3(x0 + 0.03, 0, -0.9), Vector3(x0 + 0.47, 0, -0.9), Vector3(x0 + 0.03, 0, -0.2), Vector3(x0 + 0.47, 0, -0.2)]:
		MeshKit.box(desk, Vector3(0.03, 0.71, 0.03), p + Vector3(0, 0.355, 0), wood)
	MeshKit.box(desk, Vector3(0.22, 0.15, 0.03), Vector3(x0 + 0.2, 0.82, -0.75), MeshKit.mat("lamp_shade", Color(0.2, 0.2, 0.22), 0.5), "Lamp")
	MeshKit.shape_box(_body, Vector3(0.5, 0.75, 0.75), Vector3(x0 + 0.25, 0.375, -0.55))
	var chair := Node3D.new()
	chair.name = "Chair"
	add_child(chair)
	var cx := x0 + 0.72
	MeshKit.box(chair, Vector3(0.38, 0.04, 0.38), Vector3(cx, 0.45, -0.55), wood)
	MeshKit.box(chair, Vector3(0.04, 0.4, 0.38), Vector3(cx + 0.17, 0.67, -0.55), wood)
	for dx in [-0.16, 0.16]:
		for dz in [-0.16, 0.16]:
			MeshKit.box(chair, Vector3(0.03, 0.45, 0.03), Vector3(cx + dx, 0.225, -0.55 + dz), wood)
	MeshKit.shape_box(_body, Vector3(0.38, 0.85, 0.38), Vector3(cx, 0.425, -0.55))


# ---------------------------------------------------------------- フィギュア棚

func _build_figure_shelves() -> void:
	var root := Node3D.new()
	root.name = "Figures"
	add_child(root)
	var white := MeshKit.mat("fig_shelf", Color(0.95, 0.95, 0.94), 0.4)
	# 奥の壁（窓の左、机の上）：3段
	var back_z := ROOM.position.z
	for i in 3:
		var y := 1.05 + i * 0.42
		MeshKit.box(root, Vector3(0.72, 0.02, 0.2), Vector3(1.44, y - 0.01, back_z + 0.1), white)
		_figure_row(root, Vector3(1.12, y, back_z + 0.1), Vector3(0.11, 0, 0), 6)
	MeshKit.shape_box(_body, Vector3(0.72, 1.3, 0.2), Vector3(1.44, 1.7, back_z + 0.1))
	# 手前の壁の高い所（寝床の上）：2段
	var front_z := ROOM.end.z
	for i in 2:
		var y := 1.6 + i * 0.4
		MeshKit.box(root, Vector3(1.4, 0.02, 0.18), Vector3(2.9, y - 0.01, front_z - 0.09), white)
		_figure_row(root, Vector3(2.3, y, front_z - 0.09), Vector3(0.12, 0, 0), 11)


## 独自の形のフィギュアを並べる（輪の頭、三本脚、積み重ねた円すい、一つ目の箱）。
func _figure_row(root: Node3D, start: Vector3, step: Vector3, count: int) -> void:
	var colors := [Color(0.9, 0.3, 0.25), Color(0.25, 0.55, 0.9), Color(0.95, 0.8, 0.2), Color(0.35, 0.75, 0.45),
			Color(0.75, 0.4, 0.85), Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.18)]
	for i in count:
		var c: Color = colors[_rng.randi() % colors.size()]
		var m := MeshKit.mat("fig_%s" % c.to_html(false), c, 0.4)
		var accent := MeshKit.mat("fig_%s" % colors[(i + 3) % colors.size()].to_html(false), colors[(i + 3) % colors.size()], 0.4)
		var p := start + step * i
		var f := Node3D.new()
		f.position = p
		root.add_child(f)
		match _rng.randi() % 4:
			0:   # 輪の頭
				MeshKit.cylinder(f, 0.022, 0.12, Vector3(0, 0.06, 0), m, "", 0.016, 12)
				var torus := TorusMesh.new()
				torus.inner_radius = 0.022
				torus.outer_radius = 0.036
				var ring := MeshInstance3D.new()
				ring.mesh = torus
				ring.material_override = accent
				ring.position = Vector3(0, 0.16, 0)
				ring.rotation.x = deg_to_rad(90.0)
				f.add_child(ring)
			1:   # 三本脚
				MeshKit.sphere(f, 0.035, Vector3(0, 0.12, 0), m)
				for k in 3:
					var a := TAU * k / 3.0
					var leg := MeshKit.cylinder(f, 0.006, 0.11, Vector3(cos(a) * 0.022, 0.05, sin(a) * 0.022), accent, "", -1.0, 6)
					leg.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
			2:   # 積み重ねた円すい
				for k in 3:
					MeshKit.cylinder(f, 0.035 - k * 0.009, 0.05, Vector3(0, 0.025 + k * 0.045, 0), m if k % 2 == 0 else accent, "", 0.004, 10)
			_:   # 一つ目の箱
				MeshKit.box(f, Vector3(0.06, 0.09, 0.06), Vector3(0, 0.045, 0), m)
				MeshKit.sphere(f, 0.016, Vector3(0, 0.06, 0.032), accent)


# ---------------------------------------------------------------- 大きな多面体の宝石

func _build_gem() -> void:
	var root := Node3D.new()
	root.name = "Gem"
	root.position = Vector3(3.3, 0.0, 1.15)
	add_child(root)
	MeshKit.box(root, Vector3(0.42, 0.5, 0.42), Vector3(0, 0.25, 0), MeshKit.mat("plinth", Color(0.9, 0.9, 0.88), 0.4), "Plinth")
	var gem := SphereMesh.new()
	gem.radius = 0.36
	gem.height = 0.8
	gem.radial_segments = 6
	gem.rings = 3
	# 表面の模様は紫の鉱物の画像（不透明）。つやと反射は材質の数値で付ける
	var m := StandardMaterial3D.new()
	m.albedo_texture = TEX_PURPLE
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE / 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.metallic = 0.35
	m.roughness = 0.12
	m.clearcoat_enabled = true
	m.clearcoat = 0.8
	m.emission_enabled = true
	m.emission = Color(0.45, 0.15, 0.8)
	m.emission_energy_multiplier = 0.2
	var mi := MeshInstance3D.new()
	mi.name = "Stone"
	mi.mesh = gem
	mi.material_override = m
	mi.position = Vector3(0, 0.5 + 0.4, 0)
	mi.rotation = Vector3(deg_to_rad(12.0), deg_to_rad(20.0), 0)
	root.add_child(mi)
	MeshKit.shape_box(_body, Vector3(0.42, 1.3, 0.42), root.position + Vector3(0, 0.65, 0))


# ---------------------------------------------------------------- 額装絵画（仮の抽象模様）

func _build_paintings() -> void:
	var root := Node3D.new()
	root.name = "Paintings"
	add_child(root)
	# [中心, 大きさ（横, 縦）, 向き（壁の法線の方向）]
	var list := [
		[Vector3(1.6, 1.25, ROOM.end.z), Vector2(0.86, 0.76), Vector3.FORWARD, TEX_PAINTING_A],   # 手前の壁、大きな絵（画像 408×359）
		[Vector3(3.45, 0.75, ROOM.position.z), Vector2(0.4, 0.5), Vector3.BACK],     # 奥の壁、窓の右（小）
		[Vector3(3.45, 1.4, ROOM.position.z), Vector2(0.46, 0.405), Vector3.BACK, TEX_PAINTING_B],
		[Vector3(3.45, 2.0, ROOM.position.z), Vector2(0.4, 0.4), Vector3.BACK],
		[Vector3(2.5, 2.2, ROOM.position.z), Vector2(1.2, 0.28), Vector3.BACK],     # 窓の上の横長
		[Vector3(1.44, 0.95 + 1.3 + 0.0, ROOM.position.z), Vector2(0.0, 0.0), Vector3.BACK],
	]
	var frame_cols := [Color(0.75, 0.6, 0.25), Color(0.1, 0.1, 0.1), Color(0.95, 0.95, 0.95)]
	var art_cols := [Color(0.85, 0.3, 0.2), Color(0.2, 0.35, 0.7), Color(0.95, 0.85, 0.3), Color(0.15, 0.55, 0.45), Color(0.9, 0.9, 0.85), Color(0.3, 0.15, 0.3)]
	for item in list:
		var size: Vector2 = item[1]
		if size.x <= 0.0:
			continue
		var n: Vector3 = item[2]
		var p := Node3D.new()
		p.position = item[0] + n * 0.02
		p.basis = Basis.looking_at(-n)   # ローカル -z が壁の中、+z が部屋側
		root.add_child(p)
		var fm := MeshKit.mat("frame_%d" % (_rng.randi() % 3), frame_cols[_rng.randi() % 3], 0.5, 0.3)
		MeshKit.box(p, Vector3(size.x, size.y, 0.03), Vector3.ZERO, fm)
		if item.size() > 3:   # 絵の画像を貼る（額の内側。縦横比は画像に合わせてある）
			var q := QuadMesh.new()
			q.size = Vector2(size.x - 0.08, size.y - 0.08)
			var art := MeshInstance3D.new()
			art.name = "Art"
			art.mesh = q
			art.material_override = MeshKit.texture_mat("painting_%s" % (item[3] as Texture2D).resource_path.get_file(), item[3], 0.85)
			art.position = Vector3(0, 0, 0.0165)
			p.add_child(art)
			continue
		MeshKit.box(p, Vector3(size.x - 0.08, size.y - 0.08, 0.005), Vector3(0, 0, 0.016), MeshKit.mat("canvas", Color(0.92, 0.9, 0.84), 0.9))
		for k in _rng.randi_range(3, 5):
			var c: Color = art_cols[_rng.randi() % art_cols.size()]
			var w := _rng.randf_range(0.15, 0.6) * (size.x - 0.1)
			var hh := _rng.randf_range(0.15, 0.6) * (size.y - 0.1)
			var ox := _rng.randf_range(-0.5, 0.5) * (size.x - 0.1 - w)
			var oy := _rng.randf_range(-0.5, 0.5) * (size.y - 0.1 - hh)
			MeshKit.box(p, Vector3(w, hh, 0.003), Vector3(ox, oy, 0.02 + k * 0.001), MeshKit.mat("art_%s" % c.to_html(false), c, 0.8))


# ---------------------------------------------------------------- 寝床

func _build_bed() -> void:
	var root := Node3D.new()
	root.name = "Bed"
	add_child(root)
	var z1 := ROOM.end.z
	MeshKit.box(root, Vector3(1.5, 0.12, 0.8), Vector3(2.85, 0.06, z1 - 0.42), MeshKit.mat("futon_base", Color(0.35, 0.3, 0.28), 0.9))
	MeshKit.box(root, Vector3(1.45, 0.12, 0.75), Vector3(2.85, 0.18, z1 - 0.42), MeshKit.mat("futon", Color(0.8, 0.78, 0.72), 0.95))
	MeshKit.box(root, Vector3(0.35, 0.1, 0.55), Vector3(3.4, 0.29, z1 - 0.42), MeshKit.mat("pillow", Color(0.9, 0.9, 0.92), 0.95))
	MeshKit.box(root, Vector3(0.9, 0.05, 0.78), Vector3(2.55, 0.265, z1 - 0.42), MeshKit.mat("blanket", Color(0.45, 0.55, 0.65), 0.95))
	MeshKit.shape_box(_body, Vector3(1.5, 0.3, 0.8), Vector3(2.85, 0.15, z1 - 0.42))


# ---------------------------------------------------------------- 岩石の標本（机の上の小さなトレー）

func _build_specimens() -> void:
	var root := Node3D.new()
	root.name = "RockSpecimens"
	root.position = Vector3(ROOM.position.x + 0.14 + 0.32, 0.735, -0.38)
	add_child(root)
	MeshKit.box(root, Vector3(0.12, 0.012, 0.3), Vector3(0, 0.006, 0), MeshKit.mat("tray_wood", Color(0.5, 0.38, 0.26), 0.7), "Tray")
	var rocks := [["Granite", TEX_GRANITE, -0.09, 0.035], ["Basalt", TEX_BASALT, 0.0, 0.03], ["Sandstone", TEX_SANDSTONE, 0.09, 0.033]]
	for r in rocks:
		var mesh := SphereMesh.new()
		mesh.radius = r[3]
		mesh.height = r[3] * 1.4
		mesh.radial_segments = 7   # 角ばった石らしく、少ない分割
		mesh.rings = 4
		var m := StandardMaterial3D.new()
		m.albedo_texture = r[1]
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE / 0.08
		m.roughness = 0.85
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var mi := MeshInstance3D.new()
		mi.name = r[0]
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3(0, 0.012 + r[3] * 0.65, r[2])
		mi.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4))
		root.add_child(mi)
		MeshKit.box(root, Vector3(0.002, 0.012, 0.04), Vector3(-0.059, 0.016, r[2]), MeshKit.mat("specimen_label", Color(0.95, 0.94, 0.88), 0.9))


func _build_lights() -> void:
	var l := OmniLight3D.new()
	l.name = "RoomLightOwn"
	l.position = Vector3(2.5, 2.25, 0.6)
	l.light_color = Color(1.0, 0.88, 0.74)
	l.light_energy = 0.7
	l.omni_range = 4.5
	add_child(l)
	var g := OmniLight3D.new()
	g.name = "GemGlow"
	g.position = Vector3(3.15, 1.0, 0.95)
	g.light_color = Color(0.6, 0.35, 1.0)
	g.light_energy = 0.4
	g.omni_range = 1.4
	add_child(g)


## 足元 p が自室の中か（出入口の敷居と窓の敷居は含めない）。
static func in_room(p: Vector3) -> bool:
	return p.x > ROOM.position.x + 0.02 and p.x < ROOM.end.x and p.z > ROOM.position.z + 0.02 and p.z < ROOM.end.z and p.y < 2.0


static func in_hall(p: Vector3) -> bool:
	return p.x > HALL.position.x and p.x < 1.0 and p.z > 1.2 and p.z < HALL.end.z and p.y < 2.0
