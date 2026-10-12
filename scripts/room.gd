extends Node3D
## ユニットバスと、ドアの外の短い廊下をコードで組み立てる。
##
## 座標系（単位 m）:
##   室内  x: -0.9〜0.9（幅1.8） / y: 0〜2.2（高さ2.2） / z: -1.2〜1.2（奥行き2.4）
##   入口ドアは z = +1.2 側の壁。外側（+z）に廊下があり、そこが出口。
##
## 各設備は次の構成にしている（後で GLB に差し替えやすくするため）:
##   <設備名> (Node3D)
##     ├ Visual (Node3D)          … 見た目だけ。GLB に差し替えるならここを入れ替える
##     └ Collision (StaticBody3D) … 当たり判定と「調べる」対象。メタデータ interact_id を持つ

const MeshKit := preload("res://scripts/mesh_kit.gd")
const ToiletScript := preload("res://scripts/toilet.gd")
const BathtubScript := preload("res://scripts/bathtub.gd")
const FaucetScript := preload("res://scripts/faucet.gd")
const SuppliesScript := preload("res://scripts/supplies.gd")
const SinkScript := preload("res://scripts/sink.gd")
const MirrorCabinetScript := preload("res://scripts/mirror_cabinet.gd")
const TowelScript := preload("res://scripts/towel.gd")

const LAYER_WORLD := 1      # 壁・設備（プレイヤーがぶつかる）
const LAYER_INTERACT := 2   # 拾える小物（ぶつからない、照準だけ当たる）
const LAYER_PLAYER := 8     # プレイヤー（layer 4）

const ROOM_W := 1.8
const ROOM_D := 2.4
const ROOM_H := 2.2
const WALL_T := 0.1
const DOOR_W := 0.7
const DOOR_H := 1.9
const DOOR_OPEN_DEG := -90.0

const WALL_COLOR := Color(0.82, 0.78, 0.65)   # 少し黄ばんだアイボリーの樹脂パネル
const SEAM_COLOR := Color(0.6, 0.57, 0.47)
const CAULK_COLOR := Color(0.55, 0.55, 0.53)   # ゴム目地
const PANEL_TARGET_W := 0.6   # パネル幅の目安。壁の長さを割り切れる枚数に丸める
const DETAIL_GAP := 0.002     # 壁面から浮かせる量（面の重なりによるちらつき防止）
const VENT_SIZE := 0.24
const VENT_RANGE := 2.4       # 換気口だけ床から見上げて届くよう、操作距離を個別に伸ばす

const POSTER_TEX := preload("res://assets/textures/door_poster_plumber.png")
const LABEL_TEX := preload("res://assets/textures/yubroman_label.png")
const TOWEL_TEX := preload("res://assets/textures/towel_fabric.png")             # 512x512 継ぎ目なし
const TOOTHPASTE_TEX := preload("res://assets/textures/toothpaste_label.png")   # 271x512
const POSTER_SIZE := Vector2(0.25, 0.354)   # 768x1086px（A判比）
const POSTER_HINGE_X := 0.32                # 蝶番からの距離（ドアノブ側を避ける）
const POSTER_CENTER_Y := 1.40
const POWDER_RADIUS := 0.05
const POWDER_HEIGHT := 0.15
const LID_RADIUS := 0.052
const LID_HEIGHT := 0.025
const LABEL_HEIGHT := 0.10                  # 1024x320px を円周 0.317m に巻く
const FLOOR_COLOR := Color(0.55, 0.54, 0.52)    # 淡いグレージュ。壁より少し暗く、彩度を低く
const PORCELAIN_COLOR := Color(0.92, 0.92, 0.92)

var spawn_position := Vector3(0.0, 0.05, 0.75)
var door_pivot: Node3D
var door_body: StaticBody3D
var driver_node: Node3D
var exit_area: Area3D
var toilet: ToiletScript
var bathtub: BathtubScript
var sink: SinkScript
var sink_faucet: FaucetScript
var mirror_cabinet: MirrorCabinetScript
var towel: TowelScript
var supplies: SuppliesScript


func _ready() -> void:
	_build_environment()
	_build_shell()
	_build_wall_details()
	_build_corridor()
	_build_bathtub()
	_build_toilet()
	_build_sink_and_mirror()
	_build_vent()
	_build_floor_drain()
	_build_towel()
	_build_bath_powder()
	# トイレまわりの生活用品（ペーパーホルダー・棚の予備ロールと洗剤・ラバーカップとブラシ・点検シール）
	supplies = SuppliesScript.new()
	supplies.name = "Supplies"
	add_child(supplies)
	_build_driver()
	_build_door()
	_build_exit()


# ---------------------------------------------------------------- 公開API

func remove_driver() -> void:
	if driver_node and is_instance_valid(driver_node):
		driver_node.queue_free()
	driver_node = null


func open_door() -> void:
	if door_body.has_meta("interact_id"):
		door_body.remove_meta("interact_id")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_pivot, "rotation:y", deg_to_rad(DOOR_OPEN_DEG), 1.2)


# ---------------------------------------------------------------- 環境・光

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 電球色（2700〜3000K 相当）で少し薄暗いユニットバス。環境光も暖色にして、影が真っ黒にならないようにする
	env.ambient_light_color = Color(0.8, 0.77, 0.72)
	env.ambient_light_energy = 0.4
	# 明るい白い設備が白飛びして輪郭が消えないよう、トーンマッピングで明るい部分をなだらかに抑える
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var room_light := OmniLight3D.new()
	room_light.name = "RoomLight"
	# 少し入口寄りに置き、設備の手前側の面を照らして奥・下に影を落とす（影はこの1灯だけ）
	room_light.position = Vector3(0.15, 2.05, 0.35)
	room_light.light_color = Color(1.0, 0.89, 0.76)   # 電球色（黄色を乗せすぎない）
	room_light.light_energy = 0.55
	room_light.omni_range = 4.0
	room_light.shadow_enabled = true
	room_light.shadow_bias = 0.03
	add_child(room_light)

	var hall_light := OmniLight3D.new()
	hall_light.name = "HallLight"
	hall_light.position = Vector3(0.0, 2.05, 2.4)
	hall_light.light_color = Color(1.0, 0.92, 0.8)
	hall_light.light_energy = 1.0
	hall_light.omni_range = 3.0
	hall_light.shadow_enabled = false
	add_child(hall_light)


# ---------------------------------------------------------------- 部屋の外殻

func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	add_child(shell)

	# 壁：薄いアイボリー／床：少し暗いグレー／設備：白（PORCELAIN）で明度差をつける
	var wall_mat := _mat("wall", WALL_COLOR)
	var floor_mat := _mat("floor", FLOOR_COLOR, 0.6)
	var ceil_mat := _mat("ceiling", Color(0.95, 0.95, 0.95))

	var outer_w := ROOM_W + WALL_T * 2.0
	var outer_d := ROOM_D + WALL_T * 2.0
	var half_w := ROOM_W * 0.5
	var half_d := ROOM_D * 0.5

	_static_box(shell, "Floor", Vector3(outer_w, WALL_T, outer_d), Vector3(0, -WALL_T * 0.5, 0), floor_mat)
	_static_box(shell, "Ceiling", Vector3(outer_w, WALL_T, outer_d), Vector3(0, ROOM_H + WALL_T * 0.5, 0), ceil_mat)
	_static_box(shell, "WallBack", Vector3(outer_w, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, -half_d - WALL_T * 0.5), wall_mat)
	_static_box(shell, "WallLeft", Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(-half_w - WALL_T * 0.5, ROOM_H * 0.5, 0), wall_mat)
	# 右の壁は鏡裏収納の開口（MirrorCabinetScript.Y_RANGE × Z_RANGE）を空けて4枚に分ける
	var rx := half_w + WALL_T * 0.5
	var oy: Vector2 = MirrorCabinetScript.Y_RANGE
	var oz: Vector2 = MirrorCabinetScript.Z_RANGE
	_static_box(shell, "WallRightLow", Vector3(WALL_T, oy.x, ROOM_D), Vector3(rx, oy.x * 0.5, 0), wall_mat)
	_static_box(shell, "WallRightHigh", Vector3(WALL_T, ROOM_H - oy.y, ROOM_D), Vector3(rx, (oy.y + ROOM_H) * 0.5, 0), wall_mat)
	_static_box(shell, "WallRightBack", Vector3(WALL_T, oy.y - oy.x, oz.x + half_d), Vector3(rx, (oy.x + oy.y) * 0.5, (-half_d + oz.x) * 0.5), wall_mat)
	_static_box(shell, "WallRightFront", Vector3(WALL_T, oy.y - oy.x, half_d - oz.y), Vector3(rx, (oy.x + oy.y) * 0.5, (oz.y + half_d) * 0.5), wall_mat)

	# 前の壁（入口ドアの開口部を空ける）
	var front_z := half_d + WALL_T * 0.5
	var side_w := (outer_w - DOOR_W) * 0.5
	_static_box(shell, "WallFrontL", Vector3(side_w, ROOM_H, WALL_T), Vector3(-(DOOR_W * 0.5 + side_w * 0.5), ROOM_H * 0.5, front_z), wall_mat)
	_static_box(shell, "WallFrontR", Vector3(side_w, ROOM_H, WALL_T), Vector3(DOOR_W * 0.5 + side_w * 0.5, ROOM_H * 0.5, front_z), wall_mat)
	var top_h := ROOM_H - DOOR_H
	_static_box(shell, "WallFrontTop", Vector3(DOOR_W, top_h, WALL_T), Vector3(0, DOOR_H + top_h * 0.5, front_z), wall_mat)

	# ドア枠（見た目のみ）
	var frame_mat := _mat("frame", Color(0.45, 0.33, 0.22))
	var frame := Node3D.new()
	frame.name = "DoorFrame"
	shell.add_child(frame)
	_mesh_box(frame, Vector3(0.04, DOOR_H, WALL_T + 0.02), Vector3(-DOOR_W * 0.5 - 0.02, DOOR_H * 0.5, front_z), frame_mat)
	_mesh_box(frame, Vector3(0.04, DOOR_H, WALL_T + 0.02), Vector3(DOOR_W * 0.5 + 0.02, DOOR_H * 0.5, front_z), frame_mat)
	_mesh_box(frame, Vector3(DOOR_W + 0.08, 0.04, WALL_T + 0.02), Vector3(0, DOOR_H + 0.02, front_z), frame_mat)


func _build_wall_details() -> void:
	# 樹脂パネルの縦の継ぎ目と、隅・床際のゴム目地。見た目だけ（当たり判定なし）
	var details := Node3D.new()
	details.name = "WallDetails"
	add_child(details)
	var seam_mat := _mat("seam", SEAM_COLOR, 0.9)
	var caulk_mat := _mat("caulk", CAULK_COLOR, 0.95)
	var half_w := ROOM_W * 0.5
	var half_d := ROOM_D * 0.5
	var seam_w := 0.006
	var seam_t := 0.004
	var door_clear := DOOR_W * 0.5 + 0.06   # ドア開口の近くには継ぎ目を置かない

	# 縦の継ぎ目：壁の長さを PANEL_TARGET_W 前後の等幅パネルに分ける
	var oy: Vector2 = MirrorCabinetScript.Y_RANGE
	var oz: Vector2 = MirrorCabinetScript.Z_RANGE
	for pos in _seam_positions(ROOM_D):   # 左右の壁（z 方向）
		_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(-half_w + DETAIL_GAP + seam_t * 0.5, ROOM_H * 0.5, pos), seam_mat)
		var rx := half_w - DETAIL_GAP - seam_t * 0.5
		if pos > oz.x - 0.02 and pos < oz.y + 0.02:   # 鏡裏収納の開口にかかる継ぎ目は、開口の上下だけ
			var top := MirrorCabinetScript.TRIM_W
			_mesh_box(details, Vector3(seam_t, oy.x - top, seam_w), Vector3(rx, (oy.x - top) * 0.5, pos), seam_mat)
			_mesh_box(details, Vector3(seam_t, ROOM_H - oy.y - top, seam_w), Vector3(rx, (oy.y + top + ROOM_H) * 0.5, pos), seam_mat)
		else:
			_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(rx, ROOM_H * 0.5, pos), seam_mat)
	for pos in _seam_positions(ROOM_W):   # 奥・手前の壁（x 方向）
		_mesh_box(details, Vector3(seam_w, ROOM_H, seam_t), Vector3(pos, ROOM_H * 0.5, -half_d + DETAIL_GAP + seam_t * 0.5), seam_mat)
		if absf(pos) > door_clear:
			_mesh_box(details, Vector3(seam_w, ROOM_H, seam_t), Vector3(pos, ROOM_H * 0.5, half_d - DETAIL_GAP - seam_t * 0.5), seam_mat)

	# 部屋の四隅の縦目地（隅に収まる細い角材）
	var c := 0.012
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh_box(details, Vector3(c, ROOM_H, c), Vector3(sx * (half_w - c * 0.5), ROOM_H * 0.5, sz * (half_d - c * 0.5)), caulk_mat)

	# 床と壁の境目の目地（下端は床に少し沈めて隙間を出さない）
	var h := 0.014
	var t := 0.008
	var y := h * 0.5 - 0.002
	_mesh_box(details, Vector3(t, h, ROOM_D), Vector3(-half_w + t * 0.5, y, 0.0), caulk_mat)
	_mesh_box(details, Vector3(t, h, ROOM_D), Vector3(half_w - t * 0.5, y, 0.0), caulk_mat)
	_mesh_box(details, Vector3(ROOM_W, h, t), Vector3(0.0, y, -half_d + t * 0.5), caulk_mat)
	var side := half_w - DOOR_W * 0.5   # 手前の壁はドア開口を避けて左右に分ける
	_mesh_box(details, Vector3(side, h, t), Vector3(-half_w + side * 0.5, y, half_d - t * 0.5), caulk_mat)
	_mesh_box(details, Vector3(side, h, t), Vector3(half_w - side * 0.5, y, half_d - t * 0.5), caulk_mat)


## 長さ length の壁を PANEL_TARGET_W 前後の等幅パネルに分けたときの継ぎ目の位置（中心 0 基準）。
func _seam_positions(length: float) -> Array:
	var count := maxi(1, roundi(length / PANEL_TARGET_W))
	var result := []
	for i in range(1, count):
		result.append(-length * 0.5 + length * i / count)
	return result


func _build_corridor() -> void:
	# ドアの外の廊下（脱出先）。z: 1.3〜3.3, x: -1.0〜1.0
	var hall := Node3D.new()
	hall.name = "Corridor"
	add_child(hall)
	var wall_mat := _mat("hall_wall", Color(0.82, 0.8, 0.76))
	var floor_mat := _mat("hall_floor", Color(0.5, 0.36, 0.24), 0.7)
	var ceil_mat := _mat("ceiling", Color(0.95, 0.95, 0.95))
	var z0 := ROOM_D * 0.5 + WALL_T
	var depth := 2.0
	var cz := z0 + depth * 0.5
	var inner_w := 2.0
	_static_box(hall, "HallFloor", Vector3(inner_w + WALL_T * 2.0, WALL_T, depth), Vector3(0, -WALL_T * 0.5, cz), floor_mat)
	_static_box(hall, "HallCeiling", Vector3(inner_w + WALL_T * 2.0, WALL_T, depth), Vector3(0, ROOM_H + WALL_T * 0.5, cz), ceil_mat)
	_static_box(hall, "HallWallL", Vector3(WALL_T, ROOM_H, depth), Vector3(-inner_w * 0.5 - WALL_T * 0.5, ROOM_H * 0.5, cz), wall_mat)
	_static_box(hall, "HallWallR", Vector3(WALL_T, ROOM_H, depth), Vector3(inner_w * 0.5 + WALL_T * 0.5, ROOM_H * 0.5, cz), wall_mat)
	_static_box(hall, "HallWallEnd", Vector3(inner_w + WALL_T * 2.0, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, z0 + depth + WALL_T * 0.5), wall_mat)


# ---------------------------------------------------------------- 設備

func _build_bathtub() -> void:
	# 奥の壁沿い。幅いっぱい、奥行き0.75、高さ0.55。くぼみ・水・栓・蛇口は bathtub.gd
	bathtub = BathtubScript.new()
	bathtub.name = "Bathtub"
	bathtub.position = Vector3(0.0, 0.0, -ROOM_D * 0.5 + BathtubScript.HALF.z)
	add_child(bathtub)


func _build_toilet() -> void:
	# 左の壁沿い。タンクを壁につけ、便器は +x 方向（部屋の中央）を向く。蓋と便座の開閉は toilet.gd
	toilet = ToiletScript.new()
	toilet.name = "Toilet"
	add_child(toilet)


func _build_sink_and_mirror() -> void:
	# 右の壁の洗面台（くぼみ・栓・貯水と排水・蛇口・排水管）は sink.gd、鏡裏収納は mirror_cabinet.gd
	sink = SinkScript.new()
	sink.name = "Sink"
	add_child(sink)
	sink_faucet = sink.faucet
	_build_sink_shelf(SinkScript.WALL_X, SinkScript.Z)
	mirror_cabinet = MirrorCabinetScript.new()
	mirror_cabinet.name = "MirrorCabinet"
	add_child(mirror_cabinet)


func _build_sink_shelf(wx: float, z: float) -> void:
	# 鏡の下の小さな棚：歯ブラシ立て・歯ブラシ2本・キャップ付きの歯磨き粉（架空の無地）。見た目だけ
	var shelf := Node3D.new()
	shelf.name = "SinkShelf"
	add_child(shelf)
	var top := 1.075
	_mesh_box(shelf, Vector3(0.11, 0.015, 0.44), Vector3(wx - 0.055, top - 0.0075, z), _mat("shelf", Color(0.95, 0.95, 0.93), 0.4))
	var cup_pos := Vector3(wx - 0.055, top, z + 0.16)
	MeshKit.cylinder(shelf, 0.03, 0.09, cup_pos + Vector3(0, 0.045, 0), _mat("cup", Color(0.62, 0.8, 0.7), 0.5), "Cup", 0.033)
	var brushes := [[Color(0.2, 0.45, 0.85), -12.0, -0.01], [Color(0.9, 0.45, 0.6), 14.0, 0.01]]
	for b in brushes:
		var brush := Node3D.new()
		brush.name = "Toothbrush"
		brush.position = cup_pos + Vector3(0, 0.01, b[2])
		brush.rotation = Vector3(deg_to_rad(b[1]), 0.0, deg_to_rad(-8.0))
		shelf.add_child(brush)
		var handle_mat := _mat("brush_%s" % b[0].to_html(false), b[0], 0.4)
		_mesh_box(brush, Vector3(0.012, 0.17, 0.008), Vector3(0, 0.085, 0), handle_mat)
		_mesh_box(brush, Vector3(0.012, 0.025, 0.012), Vector3(-0.006, 0.16, 0), _mat("bristle", Color(0.97, 0.97, 0.97), 0.9))
	# 歯磨き粉：棚の上に寝かせたチューブ（キャップ側 r=0.015 → 潰した端 r=0.012 の先細り）。
	# ラベル画像はチューブの正面（部屋側の斜め上）に約200°巻く。裏側は画像の地色に近い単色、キャップは青の単色
	var tube := Node3D.new()
	tube.name = "Toothpaste"
	tube.position = Vector3(wx - 0.06, top + 0.015, z - 0.06)
	tube.rotation.x = deg_to_rad(90.0)
	shelf.add_child(tube)
	var body_mat := _mat("paste_body", Color(0.96, 0.95, 0.91), 0.5)
	MeshKit.cylinder(tube, 0.015, 0.12, Vector3.ZERO, body_mat, "Body", 0.012)
	# 帯の範囲：チューブのローカル y -0.05〜0.04（上 = 潰した端、下 = キャップ側。縦書きの上がつぶした端）
	var y0 := -0.05
	var y1 := 0.04
	var r0 := lerpf(0.015, 0.012, (y0 + 0.06) / 0.12) + 0.0006   # 本体より 0.6mm 外側
	var r1 := lerpf(0.015, 0.012, (y1 + 0.06) / 0.12) + 0.0006
	# 幅 = 高さ 0.09 × 縦横比 271/512 ≒ 0.048m → 平均半径 0.0137m で約 200°
	var span := (y1 - y0) * (271.0 / 512.0) / ((r0 + r1) * 0.5)
	var label := MeshInstance3D.new()
	label.name = "Label"
	label.mesh = MeshKit.band(r0, r1, y1 - y0, deg_to_rad(135.0), span, 24)
	label.material_override = _texture_mat("toothpaste_label", TOOTHPASTE_TEX, 0.5)
	label.position = Vector3(0, (y0 + y1) * 0.5, 0)
	tube.add_child(label)
	MeshKit.cylinder(tube, 0.009, 0.018, Vector3(0, -0.069, 0), _mat("paste_cap", Color(0.15, 0.32, 0.68), 0.4), "Cap")
	_mesh_box(tube, Vector3(0.03, 0.012, 0.004), Vector3(0, 0.066, 0), body_mat)


func _build_floor_drain() -> void:
	# 浴室の床の排水口（浴槽の排水とは別。床に流れた水用）。格子の隙間から暗い穴が見える。見た目だけ
	var drain := Node3D.new()
	drain.name = "FloorDrain"
	drain.position = Vector3(-0.15, 0.0, -0.33)
	add_child(drain)
	var metal := _mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var s := 0.1
	var fw := 0.008
	_mesh_box(drain, Vector3(s - fw * 2.0, 0.001, s - fw * 2.0), Vector3(0, 0.0015, 0), _mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0))
	for sd in [-1.0, 1.0]:
		_mesh_box(drain, Vector3(s, 0.004, fw), Vector3(0, 0.002, sd * (s - fw) * 0.5), metal)
		_mesh_box(drain, Vector3(fw, 0.004, s - fw * 2.0), Vector3(sd * (s - fw) * 0.5, 0.002, 0), metal)
	for i in 5:
		var x := -0.034 + 0.017 * i
		_mesh_box(drain, Vector3(0.004, 0.003, s - fw * 2.0), Vector3(x, 0.0025, 0), metal)


func _build_towel() -> void:
	# 左の壁、便器と入口の間のタオル掛け。クリックでタオルが横へずれ、裏の傷が見える（towel.gd）
	towel = TowelScript.new()
	towel.name = "TowelBar"
	towel.position = Vector3(-ROOM_W * 0.5, 1.15, 0.72)
	add_child(towel)


func _build_vent() -> void:
	# 天井の奥・左の隅（浴槽の上）の小さな換気口。
	#   Vent/Visual/Frame … オフホワイトの枠（天井に固定）
	#   Vent/Visual/Cover … 暗い内部＋格子の蓋。原点を奥側の辺に置き、将来ここを軸に開けられる
	#   Vent/Collision    … 調べる対象（interact_range で操作距離を個別に設定）
	var f := _fixture("Vent", "vent")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	body.set_meta("interact_range", VENT_RANGE)
	var s := VENT_SIZE
	var center := Vector3(-ROOM_W * 0.5 + 0.06 + s * 0.5, ROOM_H, -ROOM_D * 0.5 + 0.06 + s * 0.5)
	visual.position = center
	body.position = center

	var frame := Node3D.new()
	frame.name = "Frame"
	visual.add_child(frame)
	var frame_mat := _mat("vent_frame", Color(0.9, 0.89, 0.85), 0.7)
	var fw := 0.02    # 枠の幅
	var fh := 0.012   # 枠の厚み（天井から下に出る分）
	var fy := -fh * 0.5
	_mesh_box(frame, Vector3(s, fh, fw), Vector3(0, fy, -s * 0.5 + fw * 0.5), frame_mat)
	_mesh_box(frame, Vector3(s, fh, fw), Vector3(0, fy, s * 0.5 - fw * 0.5), frame_mat)
	_mesh_box(frame, Vector3(fw, fh, s - fw * 2.0), Vector3(-s * 0.5 + fw * 0.5, fy, 0), frame_mat)
	_mesh_box(frame, Vector3(fw, fh, s - fw * 2.0), Vector3(s * 0.5 - fw * 0.5, fy, 0), frame_mat)

	var cover := Node3D.new()
	cover.name = "Cover"
	cover.position = Vector3(0, 0, -s * 0.5 + fw)   # 蝶番にする奥側の辺
	visual.add_child(cover)
	var inner := s - fw * 2.0
	# 奥の暗がり（天井面から 3mm 下げ、天井とのちらつきを避ける）
	_mesh_box(cover, Vector3(inner, 0.002, inner), Vector3(0, -0.004, inner * 0.5), _mat("vent_dark", Color(0.12, 0.12, 0.13), 1.0))
	# 格子（枠より少し奥）
	var grille_mat := _mat("vent_grille", Color(0.6, 0.6, 0.58), 0.6)
	var slats := 7
	for i in slats:
		var x := -inner * 0.5 + inner * (i + 0.5) / slats
		_mesh_box(cover, Vector3(0.006, 0.006, inner), Vector3(x, -0.009, inner * 0.5), grille_mat)

	_shape_box(body, Vector3(s, 0.03, s), Vector3(0, -0.015, 0))


func _build_bath_powder() -> void:
	# タンクの上の壁の棚（supplies.gd、上面 y=1.35）に置く粉末入浴剤の容器。
	# タンクの蓋を開けられるよう、TASK-07 でタンクの上から棚へ移した。
	#   BathPowder/Visual/Body  … 本体の円筒（クリーム色の蓋とは別ノード）
	#   BathPowder/Visual/Label … ラベル専用の帯。UV を自前で巻き、文字のある中央を +x（通路側）、継ぎ目を壁側に向ける
	#   BathPowder/Visual/Lid   … 蓋（将来開けられるよう別ノード）
	var f := _fixture("BathPowder", "bath_powder")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var base := Vector3(SuppliesScript.WALL_X + SuppliesScript.SHELF_DEPTH * 0.5, SuppliesScript.SHELF_TOP, SuppliesScript.POWDER_Z)
	visual.position = base
	body.position = base

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = POWDER_RADIUS
	body_mesh.bottom_radius = POWDER_RADIUS
	body_mesh.height = POWDER_HEIGHT
	body_mesh.radial_segments = 32
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = body_mesh
	body_mi.material_override = _mat("powder_body", Color(0.93, 0.72, 0.55), 0.6)
	body_mi.position = Vector3(0, POWDER_HEIGHT * 0.5, 0)
	visual.add_child(body_mi)

	var label := MeshInstance3D.new()
	label.name = "Label"
	label.mesh = _label_band(POWDER_RADIUS + 0.001, LABEL_HEIGHT, 48)
	label.material_override = _texture_mat("powder_label", LABEL_TEX, 0.6)
	label.position = Vector3(0, POWDER_HEIGHT * 0.5, 0)
	visual.add_child(label)

	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = LID_RADIUS
	lid_mesh.bottom_radius = LID_RADIUS
	lid_mesh.height = LID_HEIGHT
	lid_mesh.radial_segments = 32
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = lid_mesh
	lid.material_override = _mat("powder_lid", Color(0.96, 0.93, 0.82), 0.5)
	lid.position = Vector3(0, POWDER_HEIGHT + LID_HEIGHT * 0.5, 0)
	visual.add_child(lid)

	var shape := CylinderShape3D.new()
	shape.radius = LID_RADIUS
	shape.height = POWDER_HEIGHT + LID_HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, (POWDER_HEIGHT + LID_HEIGHT) * 0.5, 0)
	body.add_child(cs)


## 入浴剤のラベル帯：一周巻き、u=0.5（文字のある中央）を +x（通路側）、継ぎ目を -x（壁側）に向ける。
func _label_band(radius: float, height: float, segments: int) -> ArrayMesh:
	return MeshKit.band(radius, radius, height, 0.0, TAU, segments)


func _build_driver() -> void:
	# 洗面台の下の床。照準で狙いやすいよう、判定を見た目より少し大きくしている
	driver_node = Node3D.new()
	driver_node.name = "Screwdriver"
	# 実寸：柄 長さ10cm・直径3.2cm、軸 長さ11cm・直径6mm。床に寝かせ、柄の下端が床に接する
	driver_node.position = Vector3(ROOM_W * 0.5 - 0.3, 0.0, 0.05)
	driver_node.rotation.y = deg_to_rad(25.0)
	add_child(driver_node)

	var visual := Node3D.new()
	visual.name = "Visual"
	driver_node.add_child(visual)
	var handle_r := 0.016
	var axis_y := handle_r   # 柄の中心の高さ
	# 柄は床の灰色・設備の白と区別できる赤橙。洗面台の影でも見えるよう弱く自己発光させる
	var handle_mat := _mat("handle", Color(0.92, 0.22, 0.05), 0.5)
	handle_mat.emission_enabled = true
	handle_mat.emission = Color(0.92, 0.22, 0.05)
	handle_mat.emission_energy_multiplier = 0.25
	_mesh_cylinder_x(visual, handle_r, 0.1, Vector3(-0.05, axis_y, 0.0), handle_mat)
	_mesh_cylinder_x(visual, handle_r + 0.001, 0.015, Vector3(-0.07, axis_y, 0.0), _mat("grip", Color(0.08, 0.08, 0.08), 0.8))
	_mesh_cylinder_x(visual, handle_r + 0.001, 0.015, Vector3(-0.03, axis_y, 0.0), _mat("grip", Color(0.08, 0.08, 0.08), 0.8))
	_mesh_cylinder_x(visual, 0.003, 0.11, Vector3(0.055, axis_y, 0.0), _mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8))

	var area := Area3D.new()
	area.name = "Pickup"
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interact_id", "driver")
	driver_node.add_child(area)
	_shape_box(area, Vector3(0.28, 0.1, 0.14), Vector3(0.0, 0.03, 0.0))


func _build_door() -> void:
	# 蝶番は開口部の左端。外側（+z）へ開く
	var front_z := ROOM_D * 0.5 + WALL_T * 0.5
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(-DOOR_W * 0.5, 0.0, front_z)
	add_child(door_pivot)

	var visual := Node3D.new()
	visual.name = "Visual"
	door_pivot.add_child(visual)
	var panel_size := Vector3(DOOR_W - 0.01, DOOR_H - 0.01, 0.04)
	var panel_center := Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0.0)
	_mesh_box(visual, panel_size, panel_center, _mat("door", Color(0.62, 0.5, 0.38), 0.7))
	var knob_mat := _mat("knob", Color(0.8, 0.72, 0.45), 0.3, 0.8)
	_mesh_box(visual, Vector3(0.05, 0.05, 0.06), Vector3(DOOR_W - 0.08, 0.95, -0.05), knob_mat)
	_mesh_box(visual, Vector3(0.05, 0.05, 0.06), Vector3(DOOR_W - 0.08, 0.95, 0.05), knob_mat)

	door_body = StaticBody3D.new()
	door_body.name = "Collision"
	door_body.collision_layer = LAYER_WORLD
	door_body.collision_mask = 0
	door_body.set_meta("interact_id", "door")
	door_pivot.add_child(door_body)
	_shape_box(door_body, panel_size, panel_center)

	_build_door_poster(visual, panel_size.z * 0.5)


func _build_door_poster(door_visual: Node3D, half_thickness: float) -> void:
	# 部屋側の面（ローカル -z）から 2mm 浮かせて貼る。DoorPivot の子なので開閉に追従する
	var face_z := -half_thickness - DETAIL_GAP
	var center := Vector3(POSTER_HINGE_X, POSTER_CENTER_Y, face_z)
	var quad := QuadMesh.new()
	quad.size = POSTER_SIZE
	var mi := MeshInstance3D.new()
	mi.name = "Poster"
	mi.mesh = quad
	mi.material_override = _texture_mat("poster", POSTER_TEX, 0.9)
	mi.position = center
	mi.rotation.y = PI   # QuadMesh の表は +z。部屋側（-z）へ向ける
	door_visual.add_child(mi)

	# 調べる判定：ドアの判定の手前に重ねる薄い板（interact レイヤー＝ぶつからない）。
	# レイは手前の広告に先に当たり、広告の外側を狙えばドアに当たる。
	var area := Area3D.new()
	area.name = "PosterCollision"
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interact_id", "poster")
	door_pivot.add_child(area)
	_shape_box(area, Vector3(POSTER_SIZE.x, POSTER_SIZE.y, 0.006), Vector3(center.x, center.y, -half_thickness - 0.003))


func _build_exit() -> void:
	# 廊下に入ったらクリア。ドアが閉じている間は物理的に入れない
	exit_area = Area3D.new()
	exit_area.name = "ExitArea"
	exit_area.collision_layer = 0
	exit_area.collision_mask = LAYER_PLAYER
	exit_area.monitoring = true
	exit_area.monitorable = false
	exit_area.position = Vector3(0.0, 1.0, 2.4)
	add_child(exit_area)
	_shape_box(exit_area, Vector3(2.0, 2.0, 1.6), Vector3.ZERO)


# ---------------------------------------------------------------- ヘルパー

func _fixture(fixture_name: String, interact_id: String) -> Array:
	var root := Node3D.new()
	root.name = fixture_name
	add_child(root)
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", interact_id)
	root.add_child(body)
	return [visual, body]


func _static_box(parent: Node, node_name: String, size: Vector3, center: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	_mesh_box(body, size, center, material)
	_shape_box(body, size, center)
	return body


func _mesh_box(parent: Node, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	return MeshKit.box(parent, size, center, material)


## X 軸方向に寝かせた円柱（ドライバーの柄・軸用）。
func _mesh_cylinder_x(parent: Node, radius: float, length: float, center: Vector3, material: Material) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 16
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = material
	mi.position = center
	mi.rotation.z = deg_to_rad(90.0)
	parent.add_child(mi)
	return mi


func _shape_box(body: CollisionObject3D, size: Vector3, center: Vector3) -> void:
	MeshKit.shape_box(body, size, center)


func _texture_mat(key: String, tex: Texture2D, roughness: float) -> StandardMaterial3D:
	return MeshKit.texture_mat(key, tex, roughness)


func _mat(key: String, color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	return MeshKit.mat(key, color, roughness, metallic)
