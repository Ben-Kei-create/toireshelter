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
const FLOOR_COLOR := Color(0.33, 0.34, 0.35)
const PORCELAIN_COLOR := Color(0.92, 0.92, 0.92)

var spawn_position := Vector3(0.0, 0.05, 0.75)
var door_pivot: Node3D
var door_body: StaticBody3D
var driver_node: Node3D
var exit_area: Area3D

var _mat_cache := {}


func _ready() -> void:
	_build_environment()
	_build_shell()
	_build_wall_details()
	_build_corridor()
	_build_bathtub()
	_build_toilet()
	_build_sink_and_mirror()
	_build_vent()
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
	env.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.ambient_light_energy = 0.35
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var room_light := OmniLight3D.new()
	room_light.name = "RoomLight"
	# 少し入口寄りに置き、設備の手前側の面を照らして奥・下に影を落とす（影はこの1灯だけ）
	room_light.position = Vector3(0.15, 2.05, 0.35)
	room_light.light_color = Color(1.0, 0.98, 0.95)
	room_light.light_energy = 0.85
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
	_static_box(shell, "WallRight", Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(half_w + WALL_T * 0.5, ROOM_H * 0.5, 0), wall_mat)

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
	for pos in _seam_positions(ROOM_D):   # 左右の壁（z 方向）
		_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(-half_w + DETAIL_GAP + seam_t * 0.5, ROOM_H * 0.5, pos), seam_mat)
		_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(half_w - DETAIL_GAP - seam_t * 0.5, ROOM_H * 0.5, pos), seam_mat)
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
	# 奥の壁沿い。幅いっぱい、奥行き0.75、高さ0.55
	var f := _fixture("Bathtub", "bathtub")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var size := Vector3(ROOM_W, 0.55, 0.75)
	var center := Vector3(0, size.y * 0.5, -ROOM_D * 0.5 + size.z * 0.5)
	_mesh_box(visual, size, center, _mat("porcelain", PORCELAIN_COLOR, 0.3))
	_mesh_box(visual, Vector3(size.x - 0.16, 0.02, size.z - 0.16), Vector3(0, size.y + 0.001, center.z), _mat("tub_inner", Color(0.7, 0.8, 0.86), 0.3))
	# 蛇口
	_mesh_box(visual, Vector3(0.06, 0.06, 0.12), Vector3(0.6, 0.75, -ROOM_D * 0.5 + 0.06), _mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8))
	_shape_box(body, size, center)


func _build_toilet() -> void:
	# 左の壁沿い。タンクを壁につけ、便器は +x 方向（部屋の中央）を向く
	var f := _fixture("Toilet", "toilet")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var porcelain := _mat("porcelain", PORCELAIN_COLOR, 0.3)
	var wx := -ROOM_W * 0.5
	var tank_size := Vector3(0.2, 0.45, 0.4)
	var tank_center := Vector3(wx + 0.1, 0.7, 0.0)
	var bowl_size := Vector3(0.5, 0.4, 0.36)
	var bowl_center := Vector3(wx + 0.35, 0.2, 0.0)
	_mesh_box(visual, tank_size, tank_center, porcelain)
	_mesh_box(visual, bowl_size, bowl_center, porcelain)
	_mesh_box(visual, Vector3(0.46, 0.04, 0.38), Vector3(wx + 0.36, 0.42, 0.0), _mat("seat", Color(0.86, 0.86, 0.86), 0.4))
	_mesh_box(visual, Vector3(0.06, 0.02, 0.03), Vector3(wx + 0.17, 0.88, 0.14), _mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8))
	_shape_box(body, tank_size, tank_center)
	_shape_box(body, bowl_size, bowl_center)


func _build_sink_and_mirror() -> void:
	# 右の壁沿い。下が空いたペデスタル型。床（洗面台の下）にドライバーを置く
	var f := _fixture("Sink", "sink")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var porcelain := _mat("porcelain", PORCELAIN_COLOR, 0.3)
	var metal := _mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var wx := ROOM_W * 0.5
	var basin_size := Vector3(0.38, 0.15, 0.5)
	var basin_center := Vector3(wx - 0.19, 0.775, 0.1)
	var leg_size := Vector3(0.1, 0.7, 0.12)
	var leg_center := Vector3(wx - 0.05, 0.35, 0.1)
	_mesh_box(visual, basin_size, basin_center, porcelain)
	_mesh_box(visual, Vector3(0.28, 0.02, 0.38), Vector3(wx - 0.18, 0.851, 0.1), _mat("basin_inner", Color(0.82, 0.86, 0.88), 0.3))
	_mesh_box(visual, leg_size, leg_center, porcelain)
	_mesh_box(visual, Vector3(0.04, 0.12, 0.04), Vector3(wx - 0.04, 0.91, 0.1), metal)
	_mesh_box(visual, Vector3(0.12, 0.03, 0.03), Vector3(wx - 0.09, 0.96, 0.1), metal)
	_shape_box(body, basin_size, basin_center)
	_shape_box(body, leg_size, leg_center)

	# 鏡（仮の材質。リアルタイム反射なし）
	var m := _fixture("Mirror", "mirror")
	var m_visual: Node3D = m[0]
	var m_body: StaticBody3D = m[1]
	var mirror_size := Vector3(0.02, 0.5, 0.4)
	var mirror_center := Vector3(wx - 0.01, 1.4, 0.1)
	_mesh_box(m_visual, Vector3(0.015, 0.54, 0.44), Vector3(wx - 0.005, 1.4, 0.1), _mat("frame_dark", Color(0.3, 0.3, 0.32)))
	_mesh_box(m_visual, mirror_size, mirror_center, _mat("mirror", Color(0.72, 0.78, 0.82), 0.08, 0.6))
	_shape_box(m_body, mirror_size, mirror_center)


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
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	return mi


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
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = center
	body.add_child(cs)


func _mat(key: String, color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_mat_cache[key] = m
	return m
