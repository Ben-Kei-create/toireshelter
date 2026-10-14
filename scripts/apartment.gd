extends Node3D
## 浴室のドアの外の玄関ホールと、自分の部屋（TASK-10）。座標は部屋と同じ（この節点は原点に置く）。
##
##   Hall    … x -0.9〜0.9, z 1.3〜2.4、天井 2.2。浴室のドアの外。右の壁（x 0.9〜1.0）の出入口 z 1.5〜2.2 から自室へ
##   OwnRoom … x 1.0〜5.5, z -1.2〜2.4（約4.5×3.6m）、天井 2.4。左の壁の手前側は浴室の右の壁を共有する。
##             奥の壁（z -1.3〜-1.2、外壁）に掃き出し窓（x 1.8〜3.2）。窓の外がベランダ（exterior.gd）
## 狭い一人暮らしの部屋に、美術館・カードショップ・大型玩具店ほどの収集物を詰める（壁際と上方に密集、中央は通路）：
##   右の壁の半分の本棚（長さ1.7m・高さ1.18m）／左の壁のカード展示ケース（下に机と椅子）／奥の壁と手前の壁のフィギュア棚／
##   大きな多面体の宝石（台座つき）／大小の額装絵画／小さな寝床
## 本とカードは MultiMesh で軽く作る。当たり判定は大きな家具ごとの単純な箱だけ。展示品の取得や個別操作はなし。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const BooksScript := preload("res://scripts/books.gd")
const KotatsuScript := preload("res://scripts/kotatsu.gd")
const HallFusumaScript := preload("res://scripts/hall_fusuma.gd")
const AirconScript := preload("res://scripts/aircon.gd")
const FanScript := preload("res://scripts/fan.gd")
const UfoCatcherScript := preload("res://scripts/ufo_catcher.gd")
const ClosetScript := preload("res://scripts/closet.gd")
const KitchenScript := preload("res://scripts/kitchen.gd")
const OdditiesScript := preload("res://scripts/oddities.gd")
const CellarScript := preload("res://scripts/cellar.gd")
const SmallPropsScript := preload("res://scripts/small_props.gd")
const MiniGameScript := preload("res://scripts/mini_game.gd")
const AquariumScript := preload("res://scripts/aquarium.gd")
const RadioScript := preload("res://scripts/radio.gd")
const RecordPlayerScript := preload("res://scripts/record_player.gd")
const WallClockScript := preload("res://scripts/wall_clock.gd")
const IntercomScript := preload("res://scripts/intercom.gd")
const CalendarScript := preload("res://scripts/calendar.gd")
const CharacterScript := preload("res://scripts/character.gd")
const BasementScript := preload("res://scripts/basement.gd")

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
const BOOK_COUNT := 12   # 本棚に表紙を見せる本（3冊ずつ×4段）。残りの3冊（13〜15）は本棚の上に平積み
const CARD_FRONT_COUNT := 8       # card_front_01〜08（ASSETS-24）
const ART_DIR := "res://assets/textures/collection/"
const BOOK_H := 0.26              # 表紙を見せて置く本の高さ（m）
const BOOK_T := 0.028             # 厚み

const ROOM := AABB(Vector3(1.0, 0.0, -1.2), Vector3(4.5, 2.4, 3.6))   # x 1.0〜5.5（奥行きを 1.5m 広げた）
const HALL := AABB(Vector3(-0.9, 0.0, 1.3), Vector3(1.8, 2.2, 1.1))
const DOORWAY_Z := Vector2(1.5, 2.2)
const DOORWAY_H := 2.0
const FRONT_DOOR_Z := Vector2(1.5, 2.2)   # 玄関ドア（ホールの左の壁）の開口
const FRONT_DOOR_H := 2.0
const WALL_T := 0.1
const TATAKI_X := Vector2(-1.0, -0.45)   # 玄関の三和土（5cm 低い）の x の範囲
const TATAKI_Z0 := 1.45                   # 三和土の北の端（南は壁）
const WINDOW_X := Vector2(1.8, 3.2)
const WINDOW_TOP := 2.0
const WINDOW_SLIDE := 0.68
const WINDOW_TIME := 0.5

var window_open := false
var window_locked := false   # ベランダ側から、部屋の鍵がないと開かない（浴室がせり上がったあとに施錠。room.gd の rise_unit）
var hall_fusuma: Node3D       # ホールと自室の境のふすま（hall_fusuma.gd）
signal curtain_changed(closed: bool)
var window_busy := false
var window_panel: Node3D   # 外側のレールの引き違い窓（開けると右へ）
var hall_ceiling: MeshInstance3D          # ホールの天井（浴室が上がったあと、突き破られて消える）
var hall_ceiling_shape: CollisionShape3D
var curtain: Node3D        # 窓の内側の遮光カーテン。閉じているとベランダから部屋は見えない。窓とは別に、部屋の中からクリックで開け閉めする
var cellar: Node3D         # 床下の貯蔵庫の蓋（cellar.gd）
var small_props: Node3D    # じゅうたん・トランプ・サイコロなどの小物（small_props.gd）
var aquarium: Node3D       # 水槽（aquarium.gd）
var radio: Node3D          # ラジオ（radio.gd）
var record_player: Node3D  # レコードプレーヤーと壁のレコード盤（record_player.gd）
var wall_clock: Node3D     # 壁掛け時計（wall_clock.gd）
var figures: Array = []      # 棚のフィギュア（コルク銃の的）{node, out, down}
var figures_down := 0
var basement: Node3D       # 地下室（basement.gd。階段が現れるまで見えない）
var standee: Node3D        # 主人公の等身大パネル（character.gd）
var calendar: Node3D       # 壁掛けカレンダー（calendar.gd）
var intercom: Node3D       # インターホン（intercom.gd。玄関ホールの奥の壁）
var tv_game: Node2D        # テレビで遊べる小さなゲーム（mini_game.gd。SubViewport の中）
var tv_on := true          # テレビの電源（リモコンで切り替え）
var _tv_mat: StandardMaterial3D
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
	hall_fusuma = HallFusumaScript.new()
	add_child(hall_fusuma)
	_build_movie_posters()
	_build_corkboard()
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
	_build_toy_boxes()
	_build_cartridges()
	_build_room_stickers()
	_build_novelties()
	_build_tv_corner()
	_build_life_papers()
	_build_ufo_catcher()
	_build_living()
	_build_extras()
	_build_hall_slippers()
	_build_lights()


## 壁などの静的な箱（見た目と当たり判定）。
func _solid(size: Vector3, center: Vector3, m: Material, node_name := "") -> MeshInstance3D:
	MeshKit.shape_box(_body, size, center)
	return MeshKit.box(self, size, center, m, node_name)


## 浴室が天井の高さまで上がったあと、ホールの天井が抜ける（上の浴室の扉から、暗いホールの床を見下ろせるように）。
func open_hall_ceiling() -> void:
	if hall_ceiling:
		hall_ceiling.visible = false
	if hall_ceiling_shape:
		hall_ceiling_shape.disabled = true


# ---------------------------------------------------------------- 玄関ホール

func _build_hall() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var wall := MeshKit.mat("hall_wall", Color(0.82, 0.8, 0.76))
	var floor_m := MeshKit.mat("hall_floor", Color(0.5, 0.36, 0.24), 0.7)
	var ceil_m := MeshKit.mat("ceiling", Color(0.95, 0.95, 0.95))
	var z0 := HALL.position.z
	var z1 := HALL.end.z
	var cz := (z0 + z1) * 0.5
	var d := z1 - z0
	# 床：扉のそばは「三和土（たたき）」。5cm 低い灰色のタイルで、木の床との境に上がり框（暗い木の段）。靴を脱ぐ場所
	var tx := TATAKI_X   # 三和土の x の範囲（壁の外側から 木の床まで）
	var tz0 := TATAKI_Z0
	var tataki_m := MeshKit.tiled_mat("tataki_tile", _tataki_texture(), 0.3, Color.WHITE, 0.8)
	_solid(Vector3(tx.y - tx.x, WALL_T, z1 - tz0), Vector3((tx.x + tx.y) * 0.5, -0.05 - WALL_T * 0.5, (tz0 + z1) * 0.5), tataki_m, "HallTataki")
	_solid(Vector3(1.0 - tx.y, WALL_T, d), Vector3((tx.y + 1.0) * 0.5, -WALL_T * 0.5, cz), floor_m, "HallFloor")
	_solid(Vector3(tx.y - tx.x, WALL_T, tz0 - z0), Vector3((tx.x + tx.y) * 0.5, -WALL_T * 0.5, (z0 + tz0) * 0.5), floor_m, "HallFloorNorth")
	var kamachi := MeshKit.mat("kamachi", Color(0.25, 0.15, 0.09), 0.5)
	MeshKit.box(self, Vector3(0.05, 0.053, z1 - tz0), Vector3(tx.y + 0.025, -0.0235, (tz0 + z1) * 0.5), kamachi, "Kamachi")
	MeshKit.box(self, Vector3(tx.y - tx.x, 0.053, 0.05), Vector3((tx.x + tx.y) * 0.5, -0.0235, tz0 - 0.025), kamachi, "KamachiNorth")
	# 壁の下の隙間をふさぐ（扉の開口は空けたまま）
	var skirt := MeshKit.mat("hall_skirt", Color(0.3, 0.28, 0.26), 0.8)
	MeshKit.box(self, Vector3(0.1, 0.05, FRONT_DOOR_Z.x - tz0), Vector3(-0.95, -0.025, (tz0 + FRONT_DOOR_Z.x) * 0.5), skirt, "TatakiSkirtA")
	MeshKit.box(self, Vector3(0.1, 0.05, z1 - FRONT_DOOR_Z.y), Vector3(-0.95, -0.025, (FRONT_DOOR_Z.y + z1) * 0.5), skirt, "TatakiSkirtB")
	var hc_size := Vector3(2.0, WALL_T, d)
	var hc_center := Vector3(0.0, HALL.end.y + WALL_T * 0.5, cz)
	hall_ceiling = MeshKit.box(self, hc_size, hc_center, ceil_m, "HallCeiling")
	hall_ceiling_shape = MeshKit.shape_box(_body, hc_size, hc_center)
	# 左の壁（廊下との境）。玄関ドアの開口 z 1.5〜2.2、高さ 2.0 を空ける（ドアは front_door.gd）
	_solid(Vector3(WALL_T, HALL.end.y, FRONT_DOOR_Z.x - z0), Vector3(-0.95, HALL.end.y * 0.5, (z0 + FRONT_DOOR_Z.x) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y, z1 - FRONT_DOOR_Z.y), Vector3(-0.95, HALL.end.y * 0.5, (FRONT_DOOR_Z.y + z1) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y - FRONT_DOOR_H, FRONT_DOOR_Z.y - FRONT_DOOR_Z.x), Vector3(-0.95, (FRONT_DOOR_H + HALL.end.y) * 0.5, (FRONT_DOOR_Z.x + FRONT_DOOR_Z.y) * 0.5), wall)
	_solid(Vector3(2.0, HALL.end.y, WALL_T), Vector3(0.0, HALL.end.y * 0.5, z1 + WALL_T * 0.5), wall)   # 突き当たり
	# 右の壁（自室との境）。出入口 z 1.5〜2.2、高さ 2.0 を空ける
	var rx := 0.95
	_solid(Vector3(WALL_T, HALL.end.y, DOORWAY_Z.x - z0), Vector3(rx, HALL.end.y * 0.5, (z0 + DOORWAY_Z.x) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y, z1 - DOORWAY_Z.y), Vector3(rx, HALL.end.y * 0.5, (DOORWAY_Z.y + z1) * 0.5), wall)
	_solid(Vector3(WALL_T, HALL.end.y - DOORWAY_H, DOORWAY_Z.y - DOORWAY_Z.x), Vector3(rx, (DOORWAY_H + HALL.end.y) * 0.5, (DOORWAY_Z.x + DOORWAY_Z.y) * 0.5), wall)
	MeshKit.auto_round = true

## 玄関ホールの突き当たりの壁（z=2.4、部屋側 -z を向く）に、映画のポスター8枚を4枚×2段で貼る。紙なので額はなし。
func _build_movie_posters() -> void:
	var root := Node3D.new()
	root.name = "MoviePosters"
	add_child(root)
	# 上段4枚は突き当たりの壁（-z を向く）。下段の4枚は、コルクボードに場所を譲って浴室ドアの左右の壁（+z を向く）へ
	var xs := [0.6, 0.2, -0.2, -0.6]   # ホールの中から見て左（+x）から 01, 02, …
	for i in 4:
		_sign(root, "movie_poster_%02d" % (i + 1), Vector3(xs[i], 1.55, HALL.end.z - 0.003), 0.42, Vector3.FORWARD)
	# [番号, x, y]：右の壁面（x 0.4〜0.9）に 06 と 05（砂時計の惑星）、左（x -0.9〜-0.4）に 07 と 08
	for e in [[6, 0.64, 1.55], [5, 0.64, 1.05], [7, -0.64, 1.55], [8, -0.64, 1.05]]:
		_sign(root, "movie_poster_%02d" % e[0], Vector3(e[1], e[2], HALL.position.z + 0.003), 0.42, Vector3.BACK)


## 突き当たりの壁のコルクボード。レシート・半券・メモなど紙もの12枚を少し傾けてピンで留める。見た目だけ。
## コルクボードの紙は、画鋲1本で留めた紙のように、ごくわずかに揺れる（換気の空気の動き）。見た目だけ。
var books: Node
var closet: Node3D
var kitchen: Node3D
var oddities: Node3D
var kotatsu: Node3D
var aircon: Node3D
var fan: Node3D
var curtain_closed := true      # 遮光カーテン（部屋の中から開け閉めする。最初は閉まっている）
var curtain_busy := false
var window_light: SpotLight3D   # 窓から差す光（空の時間・カーテンの開きで強さが変わる）
var _curtain_shape: BoxShape3D
var ufo_catcher: Node3D
var _swaying: Array = []
var _sway_t := 0.0


func _process(delta: float) -> void:
	_update_curtain_shape()
	var clock = get_parent().get("sky_clock") if get_parent() else null
	if clock and window_light:
		window_light.light_color = clock.window_color
		window_light.light_energy = 1.6 * clock.daylight * (0.08 + 0.92 * curtain_openness())
	_sway_t += delta
	for e in _swaying:
		var mi: MeshInstance3D = e[0]
		var k: int = e[2]
		var a: float = float(e[1]) + 0.7 * sin(_sway_t * (0.5 + 0.07 * k) + k * 1.7) + 0.3 * sin(_sway_t * (1.3 + 0.11 * k))
		mi.rotation.z = deg_to_rad(a)


func _build_corkboard() -> void:
	# 突き当たりの壁（z=2.4、部屋側 -z を向く）の下段、ポスターの下の高さ。ローカル +z がホール側、+x は壁に向かって左
	var root := Node3D.new()
	root.name = "Corkboard"
	root.position = Vector3(0.0, 1.04, HALL.end.z)
	root.rotation.y = PI
	add_child(root)
	var bw := 0.86
	var bh := 0.58
	MeshKit.box(root, Vector3(bw, bh, 0.02), Vector3(0, 0, 0.01), MeshKit.mat("cork", Color(0.62, 0.45, 0.28), 0.95), "Board")
	var frame := MeshKit.mat("cork_frame", Color(0.4, 0.28, 0.18), 0.7)
	for dx in [-bw * 0.5, bw * 0.5]:
		MeshKit.box(root, Vector3(0.02, bh + 0.03, 0.03), Vector3(dx, 0, 0.015), frame)
	for dy in [-bh * 0.5, bh * 0.5]:
		MeshKit.box(root, Vector3(bw + 0.03, 0.02, 0.03), Vector3(0, dy, 0.015), frame)
	# [番号, 板の中での位置（x, y。中心からの m）, 高さ, 傾き°]
	var notes := [
		[1, -0.33, 0.12, 0.17, -4.0], [2, -0.08, 0.18, 0.13, 3.0], [3, 0.24, 0.13, 0.17, 6.0], [4, 0.36, -0.06, 0.15, -3.0],
		[5, -0.31, -0.11, 0.11, 5.0], [6, -0.16, -0.06, 0.16, -8.0], [7, 0.08, -0.02, 0.12, 2.0], [8, 0.27, -0.2, 0.1, 10.0],
		[9, -0.27, -0.23, 0.11, -2.0], [10, 0.02, -0.22, 0.1, -6.0], [11, -0.04, 0.0, 0.0, 0.0], [12, 0.13, 0.17, 0.1, 4.0],
	]
	var pin := MeshKit.mat("pin", Color(0.85, 0.2, 0.2), 0.4)
	for i in notes.size():
		var n: Array = notes[i]
		if n[3] <= 0.0:   # 11 は板の中央の下段へ
			n = [11, 0.15, -0.08, 0.1, -3.0]
		var tex: Texture2D = load("res://assets/textures/street/paper_note_%02d.png" % n[0])
		var h: float = n[3]
		var q := QuadMesh.new()
		q.size = Vector2(h * tex.get_width() / tex.get_height(), h)
		var m := MeshKit.texture_mat("paper_note_%02d" % n[0], tex, 0.9).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		var mi := MeshInstance3D.new()
		mi.name = "PaperNote%02d" % n[0]
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(n[1], n[2], 0.0215 + i * 0.0006)   # 重なりのちらつきを避けて少しずつ手前へ
		mi.rotation.z = deg_to_rad(n[4])
		root.add_child(mi)
		MeshKit.sphere(root, 0.006, mi.position + Vector3(0, h * 0.42, 0.004), pin)
		_swaying.append([mi, n[4], i])   # [紙, 元の傾き°, 位相の種]


# ---------------------------------------------------------------- 自室の外殻

func _build_room_shell() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
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
	# 床：床下の貯蔵庫の穴（cellar.gd の HOLE）を残して4枚に切り分ける
	var hx0 := CellarScript.HOLE_X.x
	var hx1 := CellarScript.HOLE_X.y
	var hz0 := CellarScript.HOLE_Z.x
	var hz1 := CellarScript.HOLE_Z.y
	var fx0 := x0 - WALL_T
	var fx1 := x1 + WALL_T
	var fz0 := z0 - WALL_T
	var fz1 := z1 + WALL_T
	_solid(Vector3(hx0 - fx0, WALL_T, fz1 - fz0), Vector3((fx0 + hx0) * 0.5, -WALL_T * 0.5, cz), floor_m, "RoomFloor")
	_solid(Vector3(fx1 - hx1, WALL_T, fz1 - fz0), Vector3((hx1 + fx1) * 0.5, -WALL_T * 0.5, cz), floor_m, "RoomFloorEast")
	_solid(Vector3(hx1 - hx0, WALL_T, hz0 - fz0), Vector3((hx0 + hx1) * 0.5, -WALL_T * 0.5, (fz0 + hz0) * 0.5), floor_m, "RoomFloorNorth")
	_solid(Vector3(hx1 - hx0, WALL_T, fz1 - hz1), Vector3((hx0 + hx1) * 0.5, -WALL_T * 0.5, (hz1 + fz1) * 0.5), floor_m, "RoomFloorSouth")
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
	MeshKit.auto_round = true

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
	# カーテンの調べる判定（部屋の側。開け閉めで横幅が変わる）
	var carea := MeshKit.interact_area(self, "CurtainArea", "curtain", self)
	_curtain_shape = BoxShape3D.new()
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.shape = _curtain_shape
	carea.add_child(cs)
	_update_curtain_shape()
	# 窓から差す光：窓の内側から部屋の中へ向けた集光灯（影なし。空の色・時間・カーテンの開きで変わる）
	window_light = SpotLight3D.new()
	window_light.name = "WindowLight"
	window_light.position = Vector3(2.5, 2.1, ROOM.position.z + 0.15)
	window_light.spot_angle = 48.0
	window_light.spot_range = 5.0
	window_light.light_energy = 0.0
	add_child(window_light)
	window_light.look_at_from_position(window_light.position, Vector3(2.5, 0.2, 1.0), Vector3.UP)
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
	Sfx.play("slide")
	var start_x := WINDOW_X.x + ((WINDOW_X.y - WINDOW_X.x) * 0.5 + 0.02) * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(window_panel, "position:x", start_x + (WINDOW_SLIDE if window_open else 0.0), WINDOW_TIME)
	tween.tween_callback(func() -> void: window_busy = false)


func get_prompt(id: String) -> String:
	if id == "curtain":
		return "" if curtain_busy else ("curtain_open" if curtain_closed else "curtain_close")
	if window_busy:
		return ""
	return "window_close" if window_open else "window_open"


func interact(id: String) -> String:
	if id == "curtain":
		toggle_curtain()
		return ""
	toggle_window()
	return ""


## 遮光カーテンの開け閉め（部屋の中から）。閉まっていると、窓から差す光がほぼ消える。
func toggle_curtain() -> void:
	if curtain_busy:
		return
	curtain_busy = true
	curtain_closed = not curtain_closed
	Sfx.play("cloth")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(curtain, "scale:x", 1.0 if curtain_closed else 0.18, 0.9)
	tween.tween_callback(func() -> void: curtain_busy = false)
	curtain_changed.emit(curtain_closed)


func _update_curtain_shape() -> void:
	var cw := (WINDOW_X.y - WINDOW_X.x + 0.1) * curtain.scale.x
	_curtain_shape.size = Vector3(maxf(cw, 0.05), 2.05, 0.08)
	(_curtain_shape as Shape3D).emit_changed()
	var cs: CollisionShape3D = get_node("CurtainArea/Shape")
	cs.position = Vector3(curtain.position.x - cw * 0.5, 1.025, curtain.position.z)


## カーテンの開き具合（0＝閉まっている、1＝開いている）。
func curtain_openness() -> float:
	return clampf((1.0 - curtain.scale.x) / 0.82, 0.0, 1.0)


# ---------------------------------------------------------------- 本棚（右の壁一面）

func _build_bookshelf() -> void:
	var wood := MeshKit.tiled_mat("shelf_wood_tex", TEX_SHELF_WOOD, 0.5, Color.WHITE, 0.7)
	var x1 := ROOM.end.x
	var depth := 0.3
	var x0 := x1 - depth
	var z0 := -0.2     # 本棚は半分の大きさ：長さ 1.7m、高さ 1.18m、4段
	var z1 := 1.5
	var top := 1.18
	var levels := 4
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
		var lv := k / 3
		var zc: float = [z0 + 0.3, (z0 + z1) * 0.5, z1 - 0.3][k % 3]
		face_out.append([lv, zc, k + 1])
	# 本は1冊（または横積み1山）ごとに、傾きを含めた実際の占有範囲（z の幅と高さ）を先に計算し、
	# 表紙を見せる本の予約範囲・側板・棚の高さに収まるときだけ置く。入らなければ次の空きへずらす（FIX-12）
	var inner_z0 := z0 + 0.0125 + 0.004   # 側板の内側
	var inner_z1 := z1 - 0.0125 - 0.004
	var max_h := step - 0.022 - 0.012      # 棚板の下面までの余裕
	for i in levels:
		var base := i * step + 0.022
		var blocked := []   # この段の予約範囲 [z0, z1]
		for fo in face_out:
			if fo[0] == i:
				blocked.append([fo[1] - 0.14, fo[1] + 0.14])
		var z := inner_z0
		while z < inner_z1 - 0.012:
			var kind := _rng.randf()
			var dep := _rng.randf_range(0.13, 0.26)
			var c: Color = palette[_rng.randi() % palette.size()]
			var items := []   # [Transform3D, Color]
			var span := 0.0   # この本（山）が占める z の幅
			if kind < 0.1:   # 横積み
				var w := _rng.randf_range(0.16, 0.24)
				var n := _rng.randi_range(2, 5)
				var y := 0.0
				for k in n:
					var tk := _rng.randf_range(0.02, 0.04)
					if y + tk > max_h:
						break
					items.append([Transform3D(Basis.from_scale(Vector3(dep, tk, w)), Vector3(x1 - 0.03 - dep * 0.5, base + y + tk * 0.5, 0.0)), palette[_rng.randi() % palette.size()]])
					y += tk + 0.003
				span = w
			else:
				var thick := _rng.randf_range(0.015, 0.06)
				var height := minf(_rng.randf_range(0.14, 0.3), max_h)
				var tilt := deg_to_rad(_rng.randf_range(-14.0, 14.0)) if kind < 0.2 else 0.0
				# 傾けた本の z の幅と高さ（底の角を棚板に付ける）
				span = thick * cos(absf(tilt)) + height * sin(absf(tilt))
				var book_h := thick * sin(absf(tilt)) + height * cos(absf(tilt))
				if book_h > max_h:
					tilt = 0.0
					span = thick
					book_h = height
				var b := Basis(Vector3.RIGHT, tilt) * Basis.from_scale(Vector3(dep, height, thick))
				items.append([Transform3D(b, Vector3(x1 - 0.03 - dep * 0.5, base + book_h * 0.5, 0.0)), c])
			# 占有範囲 [z, z + span] が予約範囲・側板にかかるなら、その先の空きへずらしてやり直す
			var z_end := z + span
			if z_end > inner_z1:
				break
			var moved := false
			for bl in blocked:
				if z_end > bl[0] and z < bl[1]:
					z = bl[1] + 0.004
					moved = true
					break
			if moved:
				continue
			for it in items:
				var t: Transform3D = it[0]
				t.origin.z = z + span * 0.5   # 占有範囲の中央
				xforms.append(t)
				colors.append(it[1])
			z = z_end + _rng.randf_range(0.001, 0.004)
	_multimesh(root, "Books", BoxMesh.new(), xforms, colors, MeshKit.mat("book_base", Color.WHITE, 0.8))
	for fo in face_out:
		_face_out_book(root, fo[2], Vector3(x1 - 0.2, fo[0] * step + 0.022, fo[1]))
	# 本を読む（books.gd）：表紙の本ごとの判定と、背表紙の本の段ごとの判定。判定は棚の前面（x0）の手前に薄く置く
	# （棚の本体の当たり判定より手前にないと、照準が届かない）。表紙の本の判定は段の判定より手前（x0-0.03）
	books = BooksScript.new()
	books.name = "Books"
	books.shelf_step = step
	books.shelf_z0 = z0
	books.levels = levels
	add_child(books)
	var areas := Node3D.new()
	areas.name = "BookAreas"
	root.add_child(areas)
	for i in levels:
		var a := MeshKit.interact_area(areas, "Level%d" % i, "shelf_books", books)
		MeshKit.shape_box(a, Vector3(0.02, step - 0.035, z1 - z0 - 0.06), Vector3(x0 - 0.012, i * step + 0.022 + (step - 0.022) * 0.5, (z0 + z1) * 0.5))
	for fo in face_out:
		var tex: Texture2D = load("res://assets/textures/books/book_cover_%02d.png" % fo[2])
		var w := BOOK_H * float(tex.get_width()) / float(tex.get_height())
		var a := MeshKit.interact_area(areas, "Book%02d" % fo[2], "book_%02d" % fo[2], books)
		MeshKit.shape_box(a, Vector3(0.02, BOOK_H, w), Vector3(x0 - 0.03, fo[0] * step + 0.022 + BOOK_H * 0.5, fo[1]))


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
	var fronts := []
	for i in CARD_FRONT_COUNT:
		fronts.append([])
	var front_i := _rng.randi() % CARD_FRONT_COUNT
	var shelf := MeshKit.mat("case_shelf", Color(0.7, 0.75, 0.8, 0.5), 0.1)
	shelf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var card_palette := [Color(0.95, 0.92, 0.85), Color(0.85, 0.9, 0.95), Color(0.95, 0.85, 0.85), Color(0.2, 0.2, 0.25)]
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
			# 表向きのカード：card_front_01〜08 のどれかを正面に貼る（同じ絵が並びすぎないよう順番に回す）
			var n := front_i % CARD_FRONT_COUNT
			front_i += 1
			fronts[n].append(Transform3D(tilt * Basis(Vector3.UP, PI * 0.5), pos + tilt * Vector3(0.0025, 0, 0)))
			z += 0.075
	_multimesh(root, "Cards", BoxMesh.new(), card_xf, card_col, MeshKit.mat("card_base", Color.WHITE, 0.6))
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(0.063, 0.088)
	var back_mat := MeshKit.texture_mat("card_back", TEX_CARD_BACK, 0.6).duplicate() as StandardMaterial3D
	_multimesh(root, "CardBacks", back_quad, back_xf, back_xf.map(func(_x): return Color.WHITE), back_mat)
	back_mat.vertex_color_use_as_albedo = false
	# 表の絵（画像の比率を保つ：高さ 0.088m に合わせて幅を決める）
	for i in CARD_FRONT_COUNT:
		if fronts[i].is_empty():
			continue
		var tex: Texture2D = load(ART_DIR + "card_front_%02d.png" % (i + 1))
		var q := QuadMesh.new()
		q.size = Vector2(0.088 * tex.get_width() / tex.get_height(), 0.088)
		var m := MeshKit.texture_mat("card_front_%02d" % (i + 1), tex, 0.5).duplicate() as StandardMaterial3D
		_multimesh(root, "CardFronts%02d" % (i + 1), q, fronts[i], fronts[i].map(func(_x): return Color.WHITE), m)
		m.vertex_color_use_as_albedo = false
	# 展示札「本日も非売品」（ケースの上の枠の正面）
	_sign(root, "collection_label_07", Vector3(x0 + depth + 0.004, y1 + 0.05, cz + 0.55), 0.09, Vector3.RIGHT)


## 画像のラベル・札を、normal の向きに貼る（高さ h、幅は画像の比率から）。
func _sign(parent: Node3D, file: String, pos: Vector3, h: float, normal: Vector3) -> MeshInstance3D:
	var tex: Texture2D = load(ART_DIR + file + ".png")
	var q := QuadMesh.new()
	q.size = Vector2(h * tex.get_width() / tex.get_height(), h)
	var mi := MeshInstance3D.new()
	mi.name = file
	mi.mesh = q
	mi.material_override = MeshKit.texture_mat(file, tex, 0.7)
	mi.position = pos
	mi.basis = Basis.looking_at(-normal)   # 表（+z）を normal の向きへ
	parent.add_child(mi)
	return mi


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
		_figure_row(root, Vector3(1.12, y, back_z + 0.1), Vector3(0.11, 0, 0), 6, 1.0)
	MeshKit.shape_box(_body, Vector3(0.72, 1.3, 0.2), Vector3(1.44, 1.7, back_z + 0.1))
	# 手前の壁の高い所（寝床の上）：2段
	var front_z := ROOM.end.z
	for i in 2:
		var y := 1.6 + i * 0.4
		MeshKit.box(root, Vector3(1.4, 0.02, 0.18), Vector3(2.9, y - 0.01, front_z - 0.09), white)
		_figure_row(root, Vector3(2.3, y, front_z - 0.09), Vector3(0.12, 0, 0), 11, -1.0)


## 棚のフィギュアをコルク銃で撃ち落とす。node は figures の中のフィギュア。落ちる間は倒れて、下の面（机・寝床・床）に落ち着く。
func knock_figure(node: Node3D) -> bool:
	for fg in figures:
		if fg.node != node or fg.down:
			continue
		fg.down = true
		figures_down += 1
		var area := node.get_node("FigureArea") as Area3D
		area.collision_layer = 0
		var out: float = fg.out
		var from := node.position
		# 落ちる先：棚から 0.2m 手前の真下に、いちばん上の面（机・寝床・床）
		var land_xz := Vector3(from.x + randf_range(-0.05, 0.05), from.y, from.z + out * 0.22)
		var q := PhysicsRayQueryParameters3D.create(land_xz, land_xz + Vector3(0, -3.0, 0), 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var floor_y: float = hit.position.y if not hit.is_empty() else 0.0
		var tw := create_tween()
		tw.tween_property(node, "rotation:x", out * deg_to_rad(80.0), 0.18).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(node, "position:z", from.z + out * 0.08, 0.18)
		tw.tween_property(node, "position", Vector3(land_xz.x, floor_y + 0.03, land_xz.z), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "rotation:z", randf_range(-1.2, 1.2), 0.4)
		tw.tween_callback(func() -> void: Sfx.play("clunk", randf_range(0.9, 1.3), -3.0))
		tw.tween_property(node, "position:y", floor_y + 0.06, 0.08)
		tw.tween_property(node, "position:y", floor_y + 0.03, 0.08)
		return true
	return false


## 独自の形のフィギュアを並べる（輪の頭、三本脚、積み重ねた円すい、一つ目の箱）。
func _figure_row(root: Node3D, start: Vector3, step: Vector3, count: int, out_dir: float) -> void:
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
		# コルク銃の的：調べられ（figure）、銃で撃つと棚から落ちる
		var fa := MeshKit.interact_area(f, "FigureArea", "figure")
		MeshKit.shape_box(fa, Vector3(0.09, 0.18, 0.09), Vector3(0, 0.08, 0))
		figures.append({"node": f, "out": out_dir, "down": false})
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
	MeshKit.box(root, Vector3(0.36, 0.42, 0.36), Vector3(0, 0.21, 0), MeshKit.mat("plinth", Color(0.9, 0.9, 0.88), 0.4), "Plinth")
	var gem := SphereMesh.new()
	gem.radius = 0.27   # ひと回り小さく（もとは 0.36）
	gem.height = 0.6
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
	mi.position = Vector3(0, 0.42 + 0.3, 0)
	mi.rotation = Vector3(deg_to_rad(12.0), deg_to_rad(20.0), 0)
	root.add_child(mi)
	MeshKit.shape_box(_body, Vector3(0.36, 1.05, 0.36), root.position + Vector3(0, 0.525, 0))
	# 展示札「触ると普通」（台座の正面＝部屋の中央側 -x）
	_sign(root, "collection_label_08", Vector3(-0.181, 0.25, 0.0), 0.12, Vector3.LEFT)
	MeshKit.image_quad(root, MeshKit.prop_tex("sticker_card_1"), Vector2(0.15, 0.15 * 485.0 / 511.0), Vector3(0, 0.21, -0.1815), Vector3.FORWARD, "StickerCard", false, 0.4)   # 石焼き大魔王（台座の北の面）


# ---------------------------------------------------------------- 額装絵画（仮の抽象模様）

func _art(n: int) -> Texture2D:
	return load(ART_DIR + "collection_art_%02d.png" % n)


## 額の外寸：絵の部分（高さ h - 0.08）を画像の比率に合わせ、まわりに 4cm ずつの額
func _art_size(n: int, h: float) -> Vector2:
	var tex := _art(n)
	return Vector2((h - 0.08) * tex.get_width() / tex.get_height() + 0.08, h)


func _room_art(n: int) -> Texture2D:
	return load("res://assets/textures/room/room_art_%02d.png" % n)


func _room_art_size(n: int, h: float) -> Vector2:
	var tex := _room_art(n)
	return Vector2((h - 0.08) * tex.get_width() / tex.get_height() + 0.08, h)


func _build_paintings() -> void:
	var root := Node3D.new()
	root.name = "Paintings"
	add_child(root)
	# [中心, 大きさ（横, 縦）, 向き（壁の法線の方向）]
	var list := [
		# ASSETS-20：既存の額11か所のうち7か所を room_art_01〜07 に差し替え（額の内寸を絵の比率 614:768 に合わせる）
		[Vector3(1.6, 1.25, ROOM.end.z), _room_art_size(1, 0.84), Vector3.FORWARD, _room_art(1)],   # 手前の壁、大きな絵（紫の鉱石の月と街）
		[Vector3(3.45, 0.75, ROOM.position.z), _art_size(1, 0.5), Vector3.BACK, _art(1)],   # 奥の壁、窓の右（ASSETS-24 の絵）
		[Vector3(3.45, 1.4, ROOM.position.z), _room_art_size(2, 0.46), Vector3.BACK, _room_art(2)],
		[Vector3(3.45, 2.0, ROOM.position.z), _art_size(2, 0.4), Vector3.BACK, _art(2)],
		# 寝床の上（手前の壁、フィギュア棚の下）に小さな絵を4枚
		[Vector3(2.35, 1.05, ROOM.end.z), _room_art_size(3, 0.4), Vector3.FORWARD, _room_art(3)],
		[Vector3(2.72, 1.05, ROOM.end.z), _room_art_size(4, 0.4), Vector3.FORWARD, _room_art(4)],
		[Vector3(3.09, 1.05, ROOM.end.z), _room_art_size(5, 0.4), Vector3.FORWARD, _room_art(5)],
		[Vector3(3.46, 1.05, ROOM.end.z), _room_art_size(6, 0.4), Vector3.FORWARD, _room_art(6)],
		# 絵 A の上に2枚
		[Vector3(1.38, 2.0, ROOM.end.z), _room_art_size(7, 0.36), Vector3.FORWARD, _room_art(7)],
		[Vector3(1.82, 2.0, ROOM.end.z), _art_size(8, 0.36), Vector3.FORWARD, _art(8)],
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
	MeshKit.image_quad(root, MeshKit.prop_tex("sticker_card_2"), Vector2(0.2, 0.2 * 485.0 / 508.0), Vector3(3.25, 0.62, z1 - 0.0015), Vector3.FORWARD, "StickerCard", false, 0.4)   # 留守番天使（枕の上の壁）
	var bed_area := MeshKit.interact_area(root, "BedArea", "bed")
	MeshKit.shape_box(bed_area, Vector3(1.5, 0.12, 0.8), Vector3(2.85, 0.36, z1 - 0.42))


# ---------------------------------------------------------------- 岩石の標本（机の上の小さなトレー）

func _build_specimens() -> void:
	var root := Node3D.new()
	root.name = "RockSpecimens"
	root.position = Vector3(ROOM.position.x + 0.14 + 0.32, 0.735, -0.38)
	add_child(root)
	MeshKit.box(root, Vector3(0.12, 0.012, 0.3), Vector3(0, 0.006, 0), MeshKit.mat("tray_wood", Color(0.5, 0.38, 0.26), 0.7), "Tray")
	var rocks := [["Granite", TEX_GRANITE, -0.09, 0.035, "collection_label_04"], ["Basalt", TEX_BASALT, 0.0, 0.03, "collection_label_05"],
			["Sandstone", TEX_SANDSTONE, 0.09, 0.033, "collection_label_06"]]
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
		# 標本の札（ASSETS-24 のラベル 04〜06）を、トレーの手前（部屋側 +x）の縁に立てる
		var tag := _sign(root, r[4], Vector3(0.061, 0.012 + 0.024, r[2]), 0.048, Vector3.RIGHT)
		tag.rotation.z = 0.0


# ---------------------------------------------------------------- 玩具の箱（机の下。正面にラベル 01〜03）

func _build_toy_boxes() -> void:
	var root := Node3D.new()
	root.name = "ToyBoxes"
	add_child(root)
	var x := ROOM.position.x + 0.14 + 0.2   # 机の天板の下、壁寄り（通路にかからない）
	var zs := [-0.82, -0.58, -0.34]
	for i in 3:
		var size := Vector3(0.2, 0.0, 0.2)
		var tex: Texture2D = load(ART_DIR + "collection_label_%02d.png" % (i + 1))
		size.y = size.z * tex.get_height() / tex.get_width()   # 正面の比率をラベルに合わせる
		var col := MeshKit.mat("toybox_%d" % i, [Color(0.9, 0.75, 0.3), Color(0.85, 0.45, 0.35), Color(0.2, 0.3, 0.6)][i], 0.7)
		MeshKit.box(root, size, Vector3(x, size.y * 0.5, zs[i]), col, "ToyBox%02d" % (i + 1))
		_sign(root, "collection_label_%02d" % (i + 1), Vector3(x + size.x * 0.5 + 0.0015, size.y * 0.5, zs[i]), size.y - 0.004, Vector3.RIGHT)


# ---------------------------------------------------------------- ゲームのカセット（左の壁の低い台。ラベル cart_label_01〜08）

func _build_cartridges() -> void:
	var root := Node3D.new()
	root.name = "Cartridges"
	add_child(root)
	var x0 := ROOM.position.x + 0.006
	var depth := 0.28
	var z0 := 0.0
	var z1 := 1.06
	var top := 0.42
	var wood := MeshKit.tiled_mat("shelf_wood_tex", TEX_SHELF_WOOD, 0.5, Color.WHITE, 0.7)
	MeshKit.box(root, Vector3(depth, top, z1 - z0), Vector3(x0 + depth * 0.5, top * 0.5, (z0 + z1) * 0.5), wood, "Rack")
	MeshKit.shape_box(_body, Vector3(depth, top, z1 - z0), Vector3(x0 + depth * 0.5, top * 0.5, (z0 + z1) * 0.5))
	var shell := MeshKit.mat("cart_shell", Color(0.55, 0.55, 0.58), 0.6)
	var body := Vector3(0.022, 0.09, 0.12)   # 厚み・高さ・幅
	for i in 8:
		var tex: Texture2D = load(ART_DIR + "cart_label_%02d.png" % (i + 1))
		var cart := Node3D.new()
		cart.name = "Cart%02d" % (i + 1)
		cart.position = Vector3(x0 + 0.12, top, z0 + 0.07 + i * 0.13)
		cart.rotation.z = deg_to_rad(-8.0)   # 少し壁側へもたせかける
		root.add_child(cart)
		MeshKit.box(cart, body, Vector3(0, body.y * 0.5, 0), shell, "Shell")
		for k in 4:   # 上のつかみの溝
			MeshKit.box(cart, Vector3(body.x + 0.002, 0.003, body.z - 0.01), Vector3(0, body.y - 0.006 - k * 0.006, 0), MeshKit.mat("cart_groove", Color(0.42, 0.42, 0.45), 0.7))
		var q := QuadMesh.new()
		var lw := body.z - 0.012
		q.size = Vector2(lw, lw * tex.get_height() / tex.get_width())
		var m := MeshKit.texture_mat("cart_label_%02d" % (i + 1), tex, 0.6).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR   # 角の丸み（透明）を抜く
		var label := MeshInstance3D.new()
		label.name = "Label"
		label.mesh = q
		label.material_override = m
		label.position = Vector3(body.x * 0.5 + 0.0008, body.y * 0.42, 0)
		label.rotation.y = PI * 0.5   # 表を +x（部屋側）へ
		cart.add_child(label)


## 自室のステッカー：カセットの台の正面、宝石の台座の横、本棚の端の板、椅子の背、机の天板。見た目だけ。
func _build_room_stickers() -> void:
	var root := Node3D.new()
	root.name = "RoomStickers"
	add_child(root)
	var rack_x := ROOM.position.x + 0.006 + 0.28
	MeshKit.sticker(root, 1, 0.13, Vector3(rack_x, 0.2, 0.2), Vector3.RIGHT, -6.0)
	MeshKit.sticker(root, 2, 0.13, Vector3(rack_x, 0.26, 0.55), Vector3.RIGHT, 4.0)
	MeshKit.sticker(root, 3, 0.1, Vector3(rack_x, 0.15, 0.85), Vector3.RIGHT, 8.0)
	MeshKit.sticker(root, 4, 0.12, Vector3(3.3, 0.3, 1.15 - 0.21), Vector3.FORWARD, -5.0)
	MeshKit.sticker(root, 5, 0.12, Vector3(3.3, 0.22, 1.15 + 0.21), Vector3.BACK, 6.0)
	MeshKit.sticker(root, 6, 0.14, Vector3(3.85, 1.35, 2.3 - 0.0125), Vector3.FORWARD, 3.0)
	MeshKit.sticker(root, 7, 0.12, Vector3(ROOM.position.x + 0.14 + 0.72 + 0.19, 0.72, -0.55), Vector3.RIGHT, -4.0)
	MeshKit.sticker(root, 8, 0.1, Vector3(ROOM.position.x + 0.14 + 0.38, 0.735 + 0.0005, -0.85), Vector3.UP, 15.0)


## 机の天板の右端（椅子側、標本トレーの手前）に、雑貨の絵を小さなアクリルスタンドとして立てる。
## 絵は novelty_06・01・10（透過付き）を画像の比率のまま板に貼り、足元に薄い透明の台を付けた。
## 立体のおもちゃではなく平らな絵の立て札（正面 +x、少し角度をずらす）。見た目だけ（当たり判定・調べる対象なし）。
## 机の天板 x 1.14〜1.64、上面 y 0.735、トレーは x 1.40〜1.52 までなので、x 1.585 に並べると物を覆わない。
func _build_novelties() -> void:
	var root := Node3D.new()
	root.name = "Novelties"
	add_child(root)
	var top := 0.735
	var x := ROOM.position.x + 0.14 + 0.445
	# [番号, z, 高さ m, 向きの傾き°]
	var items := [[6, -0.74, 0.075, -12.0], [1, -0.60, 0.095, 8.0], [10, -0.42, 0.09, -5.0]]
	var base_mat := MeshKit.mat("standee_base", Color(0.85, 0.9, 0.92, 0.55), 0.2)
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for it in items:
		var tex: Texture2D = load("res://assets/textures/room/novelty_%02d.png" % it[0])
		var h: float = it[2]
		var w := h * tex.get_width() / tex.get_height()
		var item := Node3D.new()
		item.name = "Standee%02d" % it[0]
		item.position = Vector3(x, top, it[1])
		item.rotation.y = deg_to_rad(it[3])
		root.add_child(item)
		var q := QuadMesh.new()
		q.size = Vector2(w, h)
		var m := MeshKit.texture_mat("novelty_%02d" % it[0], tex, 0.7).duplicate() as StandardMaterial3D
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.name = "Picture"
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(0, h * 0.5 + 0.004, 0)
		mi.rotation.y = PI * 0.5   # 表（+z）を +x へ
		item.add_child(mi)
		MeshKit.box(item, Vector3(0.04, 0.004, w * 0.8), Vector3(0.0, 0.002, 0), base_mat, "Base")


## 三和土のタイルの絵：灰色の石のタイルと目地（64×64、0.3m で繰り返す）。
func _tataki_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var v := 0.46 + 0.05 * sin(x * 1.7 + y * 0.9) * sin(y * 2.1)
			if x % 32 < 2 or y % 32 < 2:
				v = 0.3
			img.set_pixel(x, y, Color(v, v * 1.02, v * 1.05))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## 玄関ホール：木の床の上がり框のそば（-x 側、三和土のすぐ東）にスリッパ。見た目だけ。
func _build_hall_slippers() -> void:
	MeshKit.slipper_pair(self, Vector3(-0.28, 0.0, 1.78), 8.0, Color(0.92, 0.88, 0.72), Color(0.6, 0.45, 0.32), "HallSlippers")
	_build_shoes()


## 玄関の靴：扉のそばの床に、脱ぎっぱなしのスニーカー（片方は倒れている）と革靴。体を止めない見た目の小物で、調べられる（shoes）。
func _build_shoes() -> void:
	var root := Node3D.new()
	root.name = "Shoes"
	root.position = Vector3(-0.78, -0.05, 2.0)   # 三和土の上（床より 5cm 低い）
	add_child(root)
	var sole_w := MeshKit.mat("shoe_sole_white", Color(0.92, 0.92, 0.9), 0.7)
	var navy := MeshKit.mat("shoe_navy", Color(0.2, 0.25, 0.45), 0.8)
	var leather := MeshKit.mat("shoe_leather", Color(0.18, 0.1, 0.07), 0.45)
	var black_s := MeshKit.mat("shoe_sole_black", Color(0.05, 0.05, 0.05), 0.8)
	# スニーカー（左は立っていて、右は横に倒れている）
	var left := Node3D.new()
	left.position = Vector3(0.0, 0.0, 0.0)
	left.rotation.y = deg_to_rad(15.0)
	root.add_child(left)
	MeshKit.box(left, Vector3(0.27, 0.025, 0.1), Vector3(0, 0.0125, 0), sole_w, "Sole")
	MeshKit.box(left, Vector3(0.16, 0.07, 0.09), Vector3(-0.045, 0.06, 0), navy, "Upper")
	MeshKit.sphere(left, 0.045, Vector3(0.07, 0.04, 0), navy).scale = Vector3(1.5, 0.8, 1.0)
	var right := Node3D.new()
	right.position = Vector3(0.0, 0.0, 0.17)
	right.rotation = Vector3(deg_to_rad(80.0), deg_to_rad(-25.0), 0.0)
	root.add_child(right)
	MeshKit.box(right, Vector3(0.27, 0.025, 0.1), Vector3(0, 0.0125, 0), sole_w, "Sole")
	MeshKit.box(right, Vector3(0.16, 0.07, 0.09), Vector3(-0.045, 0.06, 0), navy, "Upper")
	right.position.y = 0.05
	# 革靴（そろえて置いてある）
	var dress := Node3D.new()
	dress.position = Vector3(0.18, 0.0, 0.34)
	dress.rotation.y = deg_to_rad(-5.0)
	root.add_child(dress)
	for dz in [-0.065, 0.065]:
		MeshKit.box(dress, Vector3(0.28, 0.02, 0.085), Vector3(0, 0.01, dz), black_s, "Sole")
		MeshKit.box(dress, Vector3(0.17, 0.06, 0.08), Vector3(-0.05, 0.05, dz), leather, "Upper")
		MeshKit.sphere(dress, 0.04, Vector3(0.065, 0.035, dz), leather).scale = Vector3(1.6, 0.8, 1.0)
	var a := MeshKit.interact_area(root, "ShoesArea", "shoes")
	MeshKit.shape_box(a, Vector3(0.45, 0.14, 0.62), Vector3(0.05, 0.07, 0.2))


## 生活小物の紙（LIFE-12）：life_paper_02（砂時計の惑星の半券）と 07（石好きの会の会員証）。
##   02 … 玄関ホールの浴室ドアの右、映画ポスター「砂時計の惑星」の下（x 0.64、高さ 0.70m）に画鋲で留めた半券
##   07 … 机の天板の右端、標本トレーの手前（x 1.58、z -0.27）に平らに置いた会員証（標本トレーは x 1.40〜1.52）
## どちらも「調べる」だけの飾り（取得・暗証番号・脱出条件には使わない）。照準の判定は画像の大きさの薄い箱1つ。
## 03・05・08・10 は、シートの絵が指定の文章と合わないため置いていない（保管）。
func _build_life_papers() -> void:
	var root := Node3D.new()
	root.name = "LifePapers"
	add_child(root)
	var pin := MeshKit.mat("pin", Color(0.85, 0.2, 0.2), 0.4)
	# 02：壁（突き当たり、-z を向く）
	var stub := _life_paper(root, 2, 0.16, Vector3(0.64, 0.70, HALL.position.z + 0.003), Vector3.BACK, 4.0, "life_paper_02")
	MeshKit.sphere(root, 0.006, stub.position + Vector3(0.004, 0.05, 0.005), pin)
	# 07：机の上（+y を向く）。長辺を z 方向に
	_life_paper(root, 7, 0.11, Vector3(ROOM.position.x + 0.14 + 0.44, 0.735 + 0.002, -0.27), Vector3.UP, 90.0 + 12.0, "life_paper_07")


## 紙の画像（assets/textures/life/life_paper_NN.png、透過付き）を、面の法線 normal を向けて貼り、調べる判定を付ける。
## width：画像の横幅（m。高さは比率から）。見た目の紙は影を落とさない。
func _life_paper(parent: Node3D, n: int, width: float, pos: Vector3, normal: Vector3, roll: float, interact_id: String) -> MeshInstance3D:
	var tex: Texture2D = load("res://assets/textures/life/life_paper_%02d.png" % n)
	var q := QuadMesh.new()
	q.size = Vector2(width, width * tex.get_height() / tex.get_width())
	var m := MeshKit.texture_mat("life_paper_%02d" % n, tex, 0.9).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	var mi := MeshInstance3D.new()
	mi.name = "LifePaper%02d" % n
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nn := normal.normalized()
	var up := Vector3.UP if absf(nn.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mi.basis = Basis.looking_at(-nn, up) * Basis(Vector3.BACK, deg_to_rad(roll))
	mi.position = pos
	parent.add_child(mi)
	var area := MeshKit.interact_area(parent, "LifePaper%02dArea" % n, interact_id)
	var long_side := maxf(q.size.x, q.size.y)
	var box := MeshKit.shape_box(area, Vector3(long_side, long_side, 0.02), Vector3.ZERO)
	area.basis = mi.basis
	area.position = pos + nn * 0.01
	return mi


## こたつ・天井のエアコン・扇風機・小さな勉強机（装飾と動きのみ。kotatsu.gd・aircon.gd・fan.gd）。
##   こたつ   … 部屋の真ん中（x 2.6、z 0.78、布団 1.1m 四方）。座布団は北と西。西側（カセットの台・勉強机）との間に体が通れる道（幅 0.15m の余裕）を残す
##   エアコン … 天井の真ん中（こたつの真上）。扇風機 … 窓の右の床（x 3.0、z -0.85）
##   勉強机   … 左の壁ぎわ、玄関ホールへの出入口の北（x 1.0〜1.4、z 1.1〜1.5、高さ 0.6m の小さな机と、机の下に入れた小さな椅子）。机の上に本棚と同じ本3冊（読める）
## 本棚（x 3.7〜）・クレーンゲーム（x 3.05〜）・机・窓・出入口の通路をふさがない位置。
func _build_living() -> void:
	kotatsu = KotatsuScript.new()
	kotatsu.name = "Kotatsu"
	add_child(kotatsu)
	aircon = AirconScript.new()
	aircon.name = "Aircon"
	aircon.position = Vector3(KotatsuScript.CENTER.x, ROOM.end.y, KotatsuScript.CENTER.z)
	add_child(aircon)
	fan = FanScript.new()
	fan.name = "Fan"
	fan.position = Vector3(3.0, 0.0, -0.85)
	add_child(fan)
	# 小さな勉強机：左の壁に沿わせる。天板 0.4(x)×0.4(z)、高さ 0.6m。上に小さなスタンド・ノート・鉛筆立て
	var desk := Node3D.new()
	desk.name = "StudyDesk"
	add_child(desk)
	var wood := MeshKit.mat("study_wood", Color(0.78, 0.62, 0.42), 0.6)
	var x0 := ROOM.position.x + 0.01
	MeshKit.box(desk, Vector3(0.4, 0.03, 0.4), Vector3(x0 + 0.2, 0.585, 1.3), wood, "Top")
	for p in [Vector2(0.03, 1.12), Vector2(0.37, 1.12), Vector2(0.03, 1.48), Vector2(0.37, 1.48)]:
		MeshKit.box(desk, Vector3(0.03, 0.57, 0.03), Vector3(x0 + p.x, 0.285, p.y), wood, "Leg")
	MeshKit.box(desk, Vector3(0.34, 0.1, 0.012), Vector3(x0 + 0.2, 0.5, 1.115), wood, "Apron")
	MeshKit.shape_box(_body, Vector3(0.4, 0.6, 0.4), Vector3(x0 + 0.2, 0.3, 1.3))
	var lamp_m := MeshKit.mat("study_lamp", Color(0.9, 0.45, 0.4), 0.5)
	MeshKit.cylinder(desk, 0.05, 0.015, Vector3(x0 + 0.06, 0.608, 1.18), lamp_m, "LampBase")
	MeshKit.cylinder(desk, 0.008, 0.2, Vector3(x0 + 0.06, 0.71, 1.18), lamp_m, "LampArm")
	MeshKit.box(desk, Vector3(0.1, 0.04, 0.08), Vector3(x0 + 0.06, 0.82, 1.2), lamp_m, "LampShade")
	# 机の上の本3冊（本棚の表紙の本と同じ。狙って読める）：03 椅子の渡り鳥・12 一人分の宇宙・10 石の育て方。
	# 表紙を上に、背（上）を壁側に、横に3冊並べる（机は 0.4m 角）
	var book_basis := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	var yaws := [4.0, -3.0, 5.0]
	for i in 3:
		var n: int = [3, 12, 10][i]
		var tex: Texture2D = load("res://assets/textures/books/book_cover_%02d.png" % n)
		var bh := 0.17
		var bw := bh * float(tex.get_width()) / float(tex.get_height())
		var book := Node3D.new()
		book.name = "DeskBook%02d" % n
		book.position = Vector3(x0 + 0.2, 0.6, 1.3 + (i - 1) * (bw + 0.008))
		book.rotation.y = deg_to_rad(yaws[i])
		desk.add_child(book)
		MeshKit.box(book, Vector3(bh, 0.024, bw), Vector3(0, 0.012, 0), MeshKit.mat("book_body_%d" % n, Color(0.3, 0.27, 0.24), 0.8), "Body")
		MeshKit.box(book, Vector3(bh - 0.006, 0.018, bw + 0.002), Vector3(0.004, 0.011, 0), MeshKit.mat("book_pages", Color(0.92, 0.89, 0.8), 0.9), "Pages")
		var q := QuadMesh.new()
		q.size = Vector2(bw, bh)
		var cover := MeshInstance3D.new()
		cover.name = "Cover"
		cover.mesh = q
		cover.material_override = MeshKit.texture_mat("book_cover_%02d" % n, tex, 0.7)
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cover.basis = book_basis
		cover.position = Vector3(0, 0.0245, 0)
		book.add_child(cover)
		var area := MeshKit.interact_area(book, "BookArea", "book_%02d" % n, books)
		MeshKit.shape_box(area, Vector3(bh, 0.04, bw), Vector3(0, 0.02, 0))
	MeshKit.cylinder(desk, 0.03, 0.08, Vector3(x0 + 0.33, 0.64, 1.18), MeshKit.mat("study_cup", Color(0.4, 0.6, 0.7), 0.5), "PencilCup")
	# 小さな椅子（座面 0.32m 角、高さ 0.32m）。机の手前（部屋側）
	var stool := Node3D.new()
	stool.name = "StudyStool"
	stool.position = Vector3(x0 + 0.32, 0.0, 1.3)
	desk.add_child(stool)
	MeshKit.box(stool, Vector3(0.28, 0.03, 0.28), Vector3(0, 0.3, 0), MeshKit.mat("study_stool", Color(0.4, 0.55, 0.5), 0.7), "Seat")
	for p in [Vector2(-0.11, -0.11), Vector2(0.11, -0.11), Vector2(-0.11, 0.11), Vector2(0.11, 0.11)]:
		MeshKit.box(stool, Vector3(0.025, 0.285, 0.025), Vector3(p.x, 0.1425, p.y), wood, "Leg")
	MeshKit.shape_box(_body, Vector3(0.28, 0.32, 0.28), stool.position + Vector3(0, 0.16, 0))


## 超簡易のクレーンゲーム（ufo_catcher.gd）。部屋の右奥、本棚の手前（x 3.3、z 0.0、幅0.5×奥行き0.5。z -0.25〜0.25）。
## 本棚（x 3.7〜）との間に 0.15m。表紙の本（z 0.38〜0.58 と -0.5〜-0.3 など）は斜めから狙える、窓（x 1.8〜3.2、奥の壁）・宝石（z 0.94〜）・机からは離れていて、通路と本棚の判定をふさがない。
## 正面は部屋の中央側（-x）。
func _build_ufo_catcher() -> void:
	# クレーンゲームは押入れの中（closet.gd）。ここでは押入れ・キッチン・変わった小物（黒電話・ギター・剥製・平積みの本）を作る
	closet = ClosetScript.new()
	closet.name = "Closet"
	add_child(closet)
	ufo_catcher = closet.ufo
	kitchen = KitchenScript.new()
	kitchen.name = "Kitchen"
	add_child(kitchen)
	oddities = OdditiesScript.new()
	oddities.name = "Oddities"
	oddities.books = books
	add_child(oddities)


## テレビ台・テレビ・ゲーム機・ゲームのソフト（手前の壁の左側、大きな絵の下）。
## 台は x 1.10〜2.06、奥行き 0.32（z 2.08〜2.40）、高さ 0.34。出入口（x 1.0・z 1.5〜2.2）の動線は z 2.08 までで、台の手前は空く。
## 大きな絵（下端 y 0.83）の下に収まる高さ（テレビの上端 0.79）。寝床（x 2.1〜）には触れない。
## 左の室：ゲーム機（白い横置きの本体）、右の室：ソフトのケース5本（文字・ロゴのない無地の背）。天板：テレビと白いコントローラ。
## テレビの画面は、コードで描いた小さな絵（空と丘。ロゴなし）を弱く光らせている。
## 台の当たり判定は1つの箱。装飾のみで、調べる判定・取得・脱出条件はなし。実在の機種名・商標は入れていない。
func _build_tv_corner() -> void:
	var root := Node3D.new()
	root.name = "TvCorner"
	add_child(root)
	var z1 := ROOM.end.z
	var x0 := 1.10
	var x1 := 2.06
	var depth := 0.32
	var h := 0.34
	var cz := z1 - depth * 0.5
	var wood := MeshKit.tiled_mat("shelf_wood_tex", TEX_SHELF_WOOD, 0.5, Color.WHITE, 0.7)
	var t := 0.02
	var cx := (x0 + x1) * 0.5
	var w := x1 - x0
	MeshKit.box(root, Vector3(w, t, depth), Vector3(cx, h - t * 0.5, cz), wood, "Top")
	MeshKit.box(root, Vector3(w, t, depth), Vector3(cx, t * 0.5 + 0.03, cz), wood, "Bottom")
	for sx in [x0 + t * 0.5, x1 - t * 0.5, cx + 0.12]:
		MeshKit.box(root, Vector3(t, h - 0.03, depth), Vector3(sx, 0.03 + (h - 0.03) * 0.5, cz), wood, "Side")
	MeshKit.box(root, Vector3(w, h - 0.03, 0.01), Vector3(cx, 0.03 + (h - 0.03) * 0.5, z1 - 0.005), MeshKit.mat("tv_back", Color(0.2, 0.17, 0.14), 0.9), "Back")
	for fx in [x0 + 0.04, x1 - 0.04]:
		MeshKit.box(root, Vector3(0.035, 0.03, 0.035), Vector3(fx, 0.015, z1 - 0.06), wood, "Foot")
	MeshKit.shape_box(_body, Vector3(w, h, depth), Vector3(cx, h * 0.5, cz))
	# ゲーム機：左の室（x x0+t 〜 cx+0.12-t/2）の中に横置き。白い外装、黒い中央の帯、青い小さなランプ
	var white := MeshKit.mat("console_white", Color(0.93, 0.94, 0.96), 0.4)
	var black := MeshKit.mat("console_black", Color(0.08, 0.08, 0.1), 0.5)
	var cons_x := (x0 + t + cx + 0.12 - t * 0.5) * 0.5
	var floor_y := 0.03 + t
	var con := Node3D.new()
	con.name = "Console"
	con.position = Vector3(cons_x, floor_y, z1 - 0.17)
	root.add_child(con)
	MeshKit.box(con, Vector3(0.36, 0.034, 0.24), Vector3(0, 0.05, 0), white, "ShellMid")
	MeshKit.box(con, Vector3(0.36, 0.016, 0.24), Vector3(0, 0.082, 0), white, "ShellTop")
	MeshKit.box(con, Vector3(0.36, 0.016, 0.24), Vector3(0, 0.018, 0), white, "ShellBottom")
	MeshKit.box(con, Vector3(0.352, 0.036, 0.236), Vector3(0, 0.05, 0.002), black, "Core")
	MeshKit.box(con, Vector3(0.36, 0.03, 0.24), Vector3(0, 0.05, -0.004), white, "ShellFace")
	MeshKit.box(con, Vector3(0.352, 0.016, 0.006), Vector3(0, 0.05, -0.121), black, "Slot")
	var lamp := MeshKit.mat("console_lamp", Color(0.3, 0.6, 1.0), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(0.3, 0.6, 1.0)
	lamp.emission_energy_multiplier = 1.2
	MeshKit.box(con, Vector3(0.012, 0.004, 0.002), Vector3(0.13, 0.036, -0.122), lamp, "Lamp")
	# ソフト：右の室に立てた5本。無地の色の背（ロゴなし）、高さ 0.19・厚み 0.015・奥行き 0.135
	var cols := [Color(0.2, 0.35, 0.75), Color(0.75, 0.25, 0.25), Color(0.25, 0.6, 0.45), Color(0.9, 0.78, 0.3), Color(0.25, 0.25, 0.3)]
	var gx0 := cx + 0.12 + t * 0.5 + 0.03
	for i in cols.size():
		var g := Node3D.new()
		g.name = "Game%02d" % (i + 1)
		g.position = Vector3(gx0 + i * 0.0165, floor_y, z1 - 0.17)
		g.rotation.z = deg_to_rad(-6.0) if i == cols.size() - 1 else 0.0
		root.add_child(g)
		MeshKit.box(g, Vector3(0.015, 0.19, 0.135), Vector3(0, 0.095, 0), MeshKit.mat("game_case_%d" % i, cols[i], 0.5), "Case")
		MeshKit.box(g, Vector3(0.0165, 0.012, 0.0), Vector3(0, 0.15, -0.0676), MeshKit.mat("game_stripe", Color(0.95, 0.95, 0.95), 0.5), "Stripe")
		# ケースを調べるとそのソフトに入れ替わる（id game_case_N）
		var ga := MeshKit.interact_area(g, "CaseArea", "game_case_%d" % i)
		MeshKit.shape_box(ga, Vector3(0.017, 0.2, 0.14), Vector3(0, 0.1, 0))
	# ゲームソフトのケース7つ：台の前の床に重ねてある（表紙つき。ユーザー作成・生成 AI 使用。架空のゲーム）
	# 重ならないよう、2列（4つ＋3つ）に並べる。台（前面 z 2.08）の前の床、手前の通路（x 1.1〜）の脇
	var cover_at := [[1.22, 1.93, 6.0], [1.42, 1.93, -4.0], [1.62, 1.93, 5.0], [1.82, 1.93, -6.0], [1.32, 1.66, -5.0], [1.52, 1.66, 4.0], [1.72, 1.66, -3.0]]
	var cover_tex := ["game_cover_1", "game_cover_2", "game_cover_3", "game_cover_4", "jacket_kotatsu_mahjong", "jacket_chika_nanadan", "jacket_rusu_record"]
	for i in 7:
		var ct := MeshKit.prop_tex(cover_tex[i])
		var cw := 0.2 * ct.get_width() / ct.get_height()
		var cn := Node3D.new()
		cn.name = "GameCover%d" % (i + 1)
		cn.position = Vector3(cover_at[i][0], 0.0, cover_at[i][1])
		cn.rotation.y = deg_to_rad(cover_at[i][2])
		root.add_child(cn)
		MeshKit.box(cn, Vector3(cw, 0.012, 0.2), Vector3(0, 0.006, 0), MeshKit.mat("game_cover_box", Color(0.08, 0.08, 0.1), 0.5), "Case")
		var cq := MeshKit.image_quad(cn, ct, Vector2(cw, 0.2), Vector3(0, 0.0123, 0), Vector3.UP, "Cover", false, 0.4)
		cq.rotation.y = PI   # 絵の上が奥（+z）。北から見て読める向き
		var ca := MeshKit.interact_area(cn, "CoverArea", "game_cover_%d" % (i + 1))
		MeshKit.shape_box(ca, Vector3(cw, 0.04, 0.2), Vector3(0, 0.02, 0))
	# 天板：テレビ（台座つき）と白いコントローラ
	var tv := Node3D.new()
	tv.name = "Tv"
	tv.position = Vector3(cx - 0.08, h, z1 - 0.17)
	root.add_child(tv)
	MeshKit.box(tv, Vector3(0.22, 0.012, 0.15), Vector3(0, 0.006, 0), MeshKit.mat("tv_black", Color(0.08, 0.08, 0.09), 0.4), "Foot")
	MeshKit.box(tv, Vector3(0.05, 0.05, 0.03), Vector3(0, 0.035, 0.02), MeshKit.mat("tv_black", Color(0.08, 0.08, 0.09), 0.4), "Neck")
	var sw := 0.72
	var sh := 0.405
	var bz := 0.025
	MeshKit.box(tv, Vector3(sw + 0.03, sh + 0.03, 0.04), Vector3(0, 0.06 + (sh + 0.03) * 0.5, 0.02), MeshKit.mat("tv_black", Color(0.08, 0.08, 0.09), 0.4), "Bezel")
	var q := QuadMesh.new()
	q.size = Vector2(sw, sh)
	var sm := StandardMaterial3D.new()
	# 画面の絵は SubViewport の中で動く小さなゲーム（デモ → 遊べる）。電源を切ると消える
	var vp := SubViewport.new()
	vp.name = "TvViewport"
	vp.size = Vector2i(320, 180)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	tv_game = MiniGameScript.new()
	tv_game.name = "MiniGame"
	vp.add_child(tv_game)
	var tex: Texture2D = vp.get_texture()
	sm.albedo_texture = tex
	sm.emission_enabled = true
	sm.emission_texture = tex
	sm.emission_energy_multiplier = 0.7
	sm.roughness = 0.25
	_tv_mat = sm
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	screen.mesh = q
	screen.material_override = sm
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.position = Vector3(0, 0.06 + (sh + 0.03) * 0.5, -0.0003 - 0.0)
	screen.rotation.y = PI   # 表を部屋側（-z）へ
	tv.add_child(screen)
	var pad := Node3D.new()
	pad.name = "Controller"
	pad.position = Vector3(cx + 0.36, h, z1 - 0.12)
	pad.rotation.y = deg_to_rad(-15.0)
	root.add_child(pad)
	MeshKit.box(pad, Vector3(0.15, 0.03, 0.09), Vector3(0, 0.015, 0), white, "Body")
	MeshKit.box(pad, Vector3(0.04, 0.032, 0.1), Vector3(-0.05, 0.016, 0.0), black, "GripL")
	MeshKit.box(pad, Vector3(0.04, 0.032, 0.1), Vector3(0.05, 0.016, 0.0), black, "GripR")
	_build_tv_cables(root, x0, cx, h, z1)
	# 調べる判定：テレビ・ゲーム機・コントローラ（どれもゲームを始める。id tv_play）
	var ta := MeshKit.interact_area(tv, "TvArea", "tv_play")
	MeshKit.shape_box(ta, Vector3(sw + 0.03, sh + 0.03, 0.06), Vector3(0, 0.06 + (sh + 0.03) * 0.5, 0.02))
	ta.set_meta("interact_range", 2.4)
	var ca := MeshKit.interact_area(con, "ConsoleArea", "tv_play")
	MeshKit.shape_box(ca, Vector3(0.36, 0.1, 0.24), Vector3(0, 0.05, 0))
	var pa := MeshKit.interact_area(pad, "PadArea", "tv_play")
	MeshKit.shape_box(pa, Vector3(0.16, 0.05, 0.1), Vector3(0, 0.02, 0))


## テレビの後ろの配線：電源・HDMI・アンテナ・ゲーム機のケーブルが、台の上のテレビの裏でからまり合い、台の左の脇から床へ垂れて、電源タップにつながっている。
## 細いケーブル（半径 4mm）を曲げた管で作る。見た目だけ（体を止めない・調べる判定もなし）。
func _build_tv_cables(root: Node3D, x0: float, cx: float, h: float, z1: float) -> void:
	var cab := Node3D.new()
	cab.name = "TvCables"
	root.add_child(cab)
	var cols := [Color(0.06, 0.06, 0.07), Color(0.85, 0.85, 0.82), Color(0.15, 0.15, 0.18), Color(0.7, 0.2, 0.2), Color(0.2, 0.3, 0.55), Color(0.06, 0.06, 0.07)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for k in cols.size():
		var m := MeshKit.mat("tv_cable_%d" % k, cols[k], 0.5)
		var sx := cx - 0.3 + rng.randf() * 0.5            # テレビの裏の出どころ
		var pts := [
			Vector3(sx, h + 0.12, z1 - 0.2),
			Vector3(sx - 0.1 + rng.randf() * 0.2, h + 0.02, z1 - 0.1 + rng.randf() * 0.04),
			Vector3(sx - 0.25 + rng.randf() * 0.25, h + 0.012, z1 - 0.045),
			Vector3(x0 + 0.1 + rng.randf() * 0.15, h + 0.012, z1 - 0.03 - rng.randf() * 0.03),
			Vector3(x0 - 0.005, h - 0.04, z1 - 0.05),
			Vector3(x0 - 0.02 - rng.randf() * 0.04, 0.12, z1 - 0.06 - rng.randf() * 0.05),
			Vector3(x0 - 0.06 - rng.randf() * 0.12, 0.012, z1 - 0.12 - rng.randf() * 0.1),
			Vector3(x0 - 0.18 + rng.randf() * 0.1, 0.012, z1 - 0.2 - rng.randf() * 0.08),
			Vector3(x0 - 0.22 + rng.randf() * 0.2, 0.012, z1 - 0.3 + rng.randf() * 0.1),
		]
		MeshKit.pipe(cab, pts, 0.004, m)
	# 電源タップ（床）と、からまった束ね目
	var strip := MeshKit.box(cab, Vector3(0.3, 0.025, 0.06), Vector3(x0 - 0.1, 0.0125, z1 - 0.28), MeshKit.mat("tv_strip", Color(0.9, 0.9, 0.88), 0.5), "PowerStrip")
	strip.rotation.y = deg_to_rad(14.0)
	for k in 4:
		MeshKit.box(cab, Vector3(0.025, 0.004, 0.02), Vector3(x0 - 0.2 + k * 0.045, 0.027, z1 - 0.3 + k * 0.01), MeshKit.mat("tv_strip_hole", Color(0.1, 0.1, 0.1), 0.6), "Outlet")
	MeshKit.sphere(cab, 0.012, Vector3(x0 - 0.04, 0.05, z1 - 0.08), MeshKit.mat("tv_tie", Color(0.9, 0.5, 0.15), 0.6))   # 結束バンドの結び目


## テレビ画面の中心（世界座標）。
func tv_screen_position() -> Vector3:
	return $TvCorner/Tv.global_position + Vector3(0.0, 0.06 + 0.2175, 0.0)


## 床下の貯蔵庫・じゅうたん・小物（トランプなど）。
func _build_extras() -> void:
	cellar = CellarScript.new()
	cellar.name = "Cellar"
	add_child(cellar)
	small_props = SmallPropsScript.new()
	small_props.name = "SmallProps"
	add_child(small_props)
	aquarium = AquariumScript.new()
	aquarium.name = "Aquarium"
	add_child(aquarium)
	radio = RadioScript.new()
	radio.name = "Radio"
	add_child(radio)
	record_player = RecordPlayerScript.new()
	record_player.name = "RecordPlayer"
	add_child(record_player)
	basement = BasementScript.new()
	basement.name = "Basement"
	add_child(basement)
	cellar.stairs_revealed.connect(basement.reveal)
	standee = CharacterScript.build_standee(1.7)
	standee.position = Vector3(3.8, 0.0, 2.08)   # 寝床と台所のあいだの隅。表は部屋の中（-x）へ
	standee.rotation.y = -PI * 0.5
	add_child(standee)
	calendar = CalendarScript.new()
	calendar.name = "Calendar"
	calendar.position = Vector3(3.8, 1.72, ROOM.end.z - 0.001)   # 南の壁、寝床と台所のあいだ。文字は部屋側（-z）へ
	calendar.rotation.y = PI
	add_child(calendar)
	intercom = IntercomScript.new()
	intercom.name = "Intercom"
	intercom.lights_root = get_parent()
	add_child(intercom)
	wall_clock = WallClockScript.new()
	wall_clock.name = "WallClock"
	wall_clock.position = Vector3(ROOM.end.x - 0.001, 2.0, 1.95)   # 東の壁、冷蔵庫の上。文字盤は部屋の中（-x）へ
	wall_clock.rotation.y = PI * 0.5
	add_child(wall_clock)


## テレビの電源。切ると画面が黒くなる。
func set_tv_on(on: bool) -> void:
	tv_on = on
	if _tv_mat == null:
		return
	_tv_mat.albedo_color = Color.WHITE if on else Color(0.03, 0.03, 0.035)
	_tv_mat.emission_enabled = on
	if tv_game:
		tv_game.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## テレビ画面の絵（いまは使わない。SubViewport のゲーム画面に置き換えた）：空のグラデーションと、重なる丘、小さな太陽（ロゴ・文字なし）。160×90。
func _tv_picture() -> ImageTexture:
	var w := 160
	var h := 90
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var f := float(y) / h
		for x in w:
			var c := Color(0.35, 0.55, 0.85).lerp(Color(0.95, 0.75, 0.6), f)
			var d := Vector2(x - 118.0, y - 24.0).length()
			if d < 9.0:
				c = Color(1.0, 0.95, 0.7)
			var hill1 := 62.0 + 7.0 * sin(x * 0.07)
			var hill2 := 72.0 + 6.0 * sin(x * 0.11 + 2.0)
			if y > hill1:
				c = Color(0.3, 0.55, 0.4)
			if y > hill2:
				c = Color(0.18, 0.4, 0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _build_lights() -> void:
	# 奥行きを広げた右半分（x 3.7〜5.5）にも灯りを置く
	var l2 := OmniLight3D.new()
	l2.name = "RoomLightEast"
	l2.position = Vector3(4.6, 2.25, 0.5)
	l2.light_color = Color(1.0, 0.88, 0.74)
	l2.light_energy = 0.7
	l2.omni_range = 4.5
	add_child(l2)
	var l := OmniLight3D.new()
	l.name = "RoomLightOwn"
	l.position = Vector3(2.5, 2.25, 0.6)
	l.light_color = Color(1.0, 0.88, 0.74)
	l.light_energy = 0.7
	l.omni_range = 4.5
	add_child(l)
	var g := OmniLight3D.new()
	g.name = "GemGlow"
	g.position = Vector3(3.15, 0.9, 0.95)
	g.light_color = Color(0.6, 0.35, 1.0)
	g.light_energy = 0.4
	g.omni_range = 1.4
	add_child(g)


## 足元 p が自室の中か（出入口の敷居と窓の敷居は含めない）。
static func in_room(p: Vector3) -> bool:
	return p.x > ROOM.position.x + 0.02 and p.x < ROOM.end.x and p.z > ROOM.position.z + 0.02 and p.z < ROOM.end.z and p.y < 2.0


static func in_hall(p: Vector3) -> bool:
	return p.x > HALL.position.x and p.x < 1.0 and p.z > 1.2 and p.z < HALL.end.z and p.y < 2.0
