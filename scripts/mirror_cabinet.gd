extends Node3D
## 鏡裏収納：右の壁の厚み（x 0.9〜1.0）に埋め込んだ収納箱と、鏡の扉（横の蝶番で開く）。中に棚2段と洗顔料・化粧水・綿棒。
## 座標は部屋と同じ（この節点は原点に置く）。実際の鏡面反射はしない（仮の材質）。
## 壁の開口は room.gd が右の壁を分割して空けている（開口は Y_RANGE × Z_RANGE）。
##
##   MirrorCabinet/Box        … 収納箱（背板・内張り・棚2段）。当たり判定（world）で、横から中を調べられない
##   MirrorCabinet/Trim       … 開口のまわりの薄い枠（壁面から 4mm 出る）
##   MirrorCabinet/DoorPivot  … 扉の蝶番（浴槽側の縁）。閉じた扉は開口の中で、鏡面が壁面とほぼ同じ位置。
##                              子に鏡と照準用の判定 DoorArea（扉と一緒に回る）
##   MirrorCabinet/Items/*    … 中の物（調べる判定つき）。閉じた扉は手前の判定で遮る
##   MirrorCabinet/BodyBlocker… 開口の前面の透明な板。プレイヤーの体だけを止め（LAYER_BODY_ONLY）、照準のレイは通す
##
## 開口の下端は 1.28m：棚の歯ブラシ（上端 約1.26m）や蛇口とぶつからない高さ。
## 開閉中（0.45秒）のクリックは無視する。
## 初期状態は施錠：扉の右端（取っ手の下）に、ドライバーで回す溝付きの真鍮の留め具（Lock）。
## 施錠中にクリックすると「開かない」と出るだけ。ドライバーを選んで留め具か扉を狙い F で解錠（main.gd）。
## 留め具には小さな照準の判定（mirror_lock）があり、扉の判定より手前にある。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const CharacterScript := preload("res://scripts/character.gd")
const Stage4Items := preload("res://scripts/stage4_items.gd")

const WALL_X := 0.9                         # 壁面（部屋側）
const BACK_X := 1.0                         # 壁の外側
const DEPTH := BACK_X - WALL_X
const FRONT_X := WALL_X                     # 収納箱の前面 = 壁面
const Y_RANGE := Vector2(1.28, 1.78)
const Z_RANGE := Vector2(-0.12, 0.32)
const BOARD := 0.012
const SHELF_YS := [1.46, 1.62]              # 中の棚2段（上面）。下段の物（高さ約0.145）が当たらない高さ
const DOOR_T := 0.018
const DOOR_GAP := 0.002                     # 扉と内張りのすき間（開閉に必要な分だけ）
const INNER_FRONT_X := WALL_X + DOOR_T + DOOR_GAP   # 扉の裏から奥が棚の空間
const TRIM_W := 0.015
const TRIM_T := 0.004
const OPEN_DEG := -100.0                    # 部屋側（-x）へ開く
const SWING_TIME := 0.45

var is_open := false
var locked := true
var unlocking := false   # 留め具を回している間（この間の F は無視して、メッセージを重ねない）
var busy := false
var door_pivot: Node3D
var reflection: MeshInstance3D   # 鏡に映る主人公の顔（見る角度で向きが変わる）
var reflection_view := ""
var hand_mirror: Node3D          # 上の棚の手かがみ（拾える）。宝石の謎で使う
var lever: Node3D                # 点検レバーの台
var lever_arm: Node3D            # 引くと倒れる腕
var lever_pulled := false
var _door_w := 0.0
var _door_h := 0.0


func _ready() -> void:
	_build_box()
	_build_trim()
	_build_items()
	_build_door()
	_build_body_blocker()


## 留め具を外す（ドライバーで溝を縦に回す演出）。すでに外れていれば何もしない（false）。
func unlock() -> bool:
	if not locked:
		return false
	locked = false
	var lock := door_pivot.get_node_or_null("Lock")
	if lock:
		unlocking = true
		var tween := create_tween()
		tween.tween_property(lock, "rotation:x", deg_to_rad(90.0), 0.3)   # 溝が横 → 縦
		tween.tween_callback(func() -> void: unlocking = false)
	return true


func toggle() -> void:
	if busy:
		return
	busy = true
	is_open = not is_open
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door_pivot, "rotation:y", deg_to_rad(OPEN_DEG) if is_open else 0.0, SWING_TIME)
	tween.tween_callback(func() -> void: busy = false)


func _build_box() -> void:
	var box := Node3D.new()
	box.name = "Box"
	add_child(box)
	var white := MeshKit.mat("cabinet", Color(0.95, 0.95, 0.94), 0.5)
	var h := Y_RANGE.y - Y_RANGE.x
	var w := Z_RANGE.y - Z_RANGE.x
	var cy := (Y_RANGE.x + Y_RANGE.y) * 0.5
	var cz := (Z_RANGE.x + Z_RANGE.y) * 0.5
	var cx := (FRONT_X + BACK_X) * 0.5
	var parts := [
		[Vector3(BOARD, h, w), Vector3(BACK_X - BOARD * 0.5, cy, cz)],                 # 背板
		[Vector3(DEPTH, BOARD, w), Vector3(cx, Y_RANGE.x + BOARD * 0.5, cz)],          # 底板
		[Vector3(DEPTH, BOARD, w), Vector3(cx, Y_RANGE.y - BOARD * 0.5, cz)],          # 天板
		[Vector3(DEPTH, h, BOARD), Vector3(cx, cy, Z_RANGE.x + BOARD * 0.5)],          # 側板
		[Vector3(DEPTH, h, BOARD), Vector3(cx, cy, Z_RANGE.y - BOARD * 0.5)],
	]
	for sy in SHELF_YS:
		var sd := BACK_X - BOARD - INNER_FRONT_X   # 棚板は扉の裏より奥
		parts.append([Vector3(sd, BOARD * 0.6, w - BOARD * 2.0), Vector3(INNER_FRONT_X + sd * 0.5, sy - BOARD * 0.3, cz)])
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	box.add_child(body)
	for p in parts:
		MeshKit.box(box, p[0], p[1], white)
		MeshKit.shape_box(body, p[0], p[1])


func _build_trim() -> void:
	var trim := Node3D.new()
	trim.name = "Trim"
	add_child(trim)
	var white := MeshKit.mat("cabinet", Color(0.95, 0.95, 0.94), 0.5)
	var x := WALL_X - TRIM_T * 0.5
	var h := Y_RANGE.y - Y_RANGE.x + TRIM_W * 2.0
	var cz := (Z_RANGE.x + Z_RANGE.y) * 0.5
	var w := Z_RANGE.y - Z_RANGE.x
	MeshKit.box(trim, Vector3(TRIM_T, TRIM_W, w + TRIM_W * 2.0), Vector3(x, Y_RANGE.x - TRIM_W * 0.5, cz), white)
	MeshKit.box(trim, Vector3(TRIM_T, TRIM_W, w + TRIM_W * 2.0), Vector3(x, Y_RANGE.y + TRIM_W * 0.5, cz), white)
	MeshKit.box(trim, Vector3(TRIM_T, h, TRIM_W), Vector3(x, (Y_RANGE.x + Y_RANGE.y) * 0.5, Z_RANGE.x - TRIM_W * 0.5), white)
	MeshKit.box(trim, Vector3(TRIM_T, h, TRIM_W), Vector3(x, (Y_RANGE.x + Y_RANGE.y) * 0.5, Z_RANGE.y + TRIM_W * 0.5), white)


func _build_body_blocker() -> void:
	var blocker := StaticBody3D.new()
	blocker.name = "BodyBlocker"
	blocker.collision_layer = MeshKit.LAYER_BODY_ONLY
	blocker.collision_mask = 0
	add_child(blocker)
	MeshKit.shape_box(blocker, Vector3(0.01, Y_RANGE.y - Y_RANGE.x, Z_RANGE.y - Z_RANGE.x),
			Vector3(WALL_X + 0.005, (Y_RANGE.x + Y_RANGE.y) * 0.5, (Z_RANGE.x + Z_RANGE.y) * 0.5))


func _build_items() -> void:
	var items := Node3D.new()
	items.name = "Items"
	add_child(items)
	var x := (INNER_FRONT_X + BACK_X - BOARD) * 0.5
	var floor_y := Y_RANGE.x + BOARD
	# 下の段：化粧水（ボトル）と洗顔料（キャップを下にして立てたチューブ）
	var toner := _item(items, "Toner", "toner", Vector3(x, floor_y, 0.02), Vector3(0.06, 0.15, 0.06))
	MeshKit.cylinder(toner, 0.026, 0.12, Vector3(0, 0.06, 0), MeshKit.mat("toner_body", Color(0.55, 0.72, 0.92), 0.2), "Bottle")
	MeshKit.cylinder(toner, 0.013, 0.025, Vector3(0, 0.1325, 0), MeshKit.mat("toner_cap", Color(0.95, 0.95, 0.96), 0.4), "Cap")
	var wash := _item(items, "FaceWash", "face_wash", Vector3(x, floor_y, 0.17), Vector3(0.05, 0.15, 0.06))
	MeshKit.cylinder(wash, 0.014, 0.022, Vector3(0, 0.011, 0), MeshKit.mat("wash_cap", Color(0.95, 0.55, 0.45), 0.4), "Cap")
	var tube := MeshKit.cylinder(wash, 0.022, 0.11, Vector3(0, 0.022 + 0.055, 0), MeshKit.mat("wash_body", Color(0.98, 0.82, 0.72), 0.5), "Tube", 0.019)
	MeshKit.box(wash, Vector3(0.008, 0.012, 0.042), Vector3(0, 0.022 + 0.11 + 0.006, 0), MeshKit.mat("wash_body", Color(0.98, 0.82, 0.72), 0.5))
	tube.name = "Tube"
	# ラベル（BATH-ASSETS-40）：容器の正面（部屋側 -x）に巻く帯。画像の縦横比のまま
	_label(toner, "bath_label_02", 0.0265, 0.0265, 0.08, 0.06)
	_label(wash, "bath_label_01", 0.0218, 0.0196, 0.07, 0.022 + 0.06)
	# 中の段：綿棒の入れ物（透明に近い円筒）と、上に頭を出した綿棒
	var swabs := _item(items, "CottonSwabs", "cotton_swabs", Vector3(x, SHELF_YS[0], 0.10), Vector3(0.08, 0.1, 0.08))
	var case_mat := MeshKit.mat("swab_case", Color(0.55, 0.8, 0.75), 0.15)
	MeshKit.cylinder(swabs, 0.03, 0.065, Vector3(0, 0.0325, 0), case_mat, "Case")
	var stick := MeshKit.mat("swab_stick", Color(0.97, 0.97, 0.97), 0.8)
	for i in 7:
		var a := TAU * i / 7.0
		var off := Vector3(cos(a) * 0.015, 0, sin(a) * 0.015)
		MeshKit.cylinder(swabs, 0.0025, 0.075, off + Vector3(0, 0.04, 0), stick, "", -1.0, 6)
		MeshKit.sphere(swabs, 0.005, off + Vector3(0, 0.0785, 0), stick)
	_label(swabs, "bath_label_03", 0.0305, 0.0305, 0.05, 0.03)
	# 中の段の奥：点検レバー（赤い握り）。引くと、浴室ごと上がる（main.gd → room.rise_unit）。上がったあとは固まって動かない
	lever = _item(items, "InspectLever", "inspect_lever", Vector3(x, SHELF_YS[0], -0.04), Vector3(0.07, 0.11, 0.07))
	MeshKit.box(lever, Vector3(0.05, 0.012, 0.05), Vector3(0, 0.006, 0), MeshKit.mat("lever_plate", Color(0.32, 0.32, 0.34), 0.5, 0.5), "Plate")
	lever_arm = Node3D.new()
	lever_arm.name = "Arm"
	lever_arm.position = Vector3(0, 0.014, 0)
	lever.add_child(lever_arm)
	MeshKit.cylinder(lever_arm, 0.004, 0.06, Vector3(0, 0.03, 0), MeshKit.mat("lever_rod", Color(0.7, 0.7, 0.72), 0.3, 0.8), "Rod")
	MeshKit.sphere(lever_arm, 0.014, Vector3(0, 0.066, 0), MeshKit.mat("lever_knob", Color(0.85, 0.1, 0.08), 0.35))


	# 上の棚：手かがみ（丸い鏡と柄。寝かせて置いてある）
	hand_mirror = _item(items, "HandMirror", "hand_mirror", Vector3(x, SHELF_YS[1], 0.12), Vector3(0.09, 0.12, 0.14))
	var hm := Stage4Items.hand_mirror_model()
	hm.rotation = Vector3(0, 0, deg_to_rad(90.0))
	hm.position = Vector3(0, 0.012, 0)
	hand_mirror.add_child(hm)


## 手かがみを拾った（見た目と判定を消す）。
func take_hand_mirror() -> void:
	if hand_mirror and is_instance_valid(hand_mirror):
		hand_mirror.visible = false
		var a := hand_mirror.get_node_or_null("HandMirrorArea") as Area3D
		if a:
			a.collision_layer = 0


## 円筒の容器の正面（-x）に、画像の比率のまま巻くラベル。r0/r1：下端・上端の半径、h：高さ、cy：中心の高さ。
func _label(parent: Node3D, file: String, r0: float, r1: float, h: float, cy: float) -> void:
	var tex: Texture2D = load("res://assets/textures/bath/%s.png" % file)
	var w := h * tex.get_width() / tex.get_height()
	var span := w / ((r0 + r1) * 0.5)
	var mi := MeshInstance3D.new()
	mi.name = "Label"
	mi.mesh = MeshKit.band(r0, r1, h, PI, span, 20)
	mi.material_override = MeshKit.texture_mat(file, tex, 0.5)
	mi.position = Vector3(0, cy, 0)
	parent.add_child(mi)


## 中の物の節点と、それを覆う調べる判定（底の中心が pos、判定の大きさ size）。
func _item(parent: Node3D, node_name: String, interact_id: String, pos: Vector3, size: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	var area := MeshKit.interact_area(n, node_name + "Area", interact_id)
	MeshKit.shape_box(area, size, Vector3(0, size.y * 0.5, 0))
	return n


func _build_door() -> void:
	# 扉は開口の内張りの内側に収まる（すき間 DOOR_GAP）。蝶番は浴槽側（-z）の縁の壁面の位置。
	# 扉のローカル座標：x は 0（鏡面 = 壁面）〜 DOOR_T（壁の奥）、z は 0〜幅。-100° 回すと部屋側（-x）へ開く
	var z0 := Z_RANGE.x + BOARD + DOOR_GAP
	var z1 := Z_RANGE.y - BOARD - DOOR_GAP
	var y0 := Y_RANGE.x + BOARD + DOOR_GAP
	var y1 := Y_RANGE.y - BOARD - DOOR_GAP
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(WALL_X, y0, z0)
	add_child(door_pivot)
	var h := y1 - y0
	var w := z1 - z0
	MeshKit.box(door_pivot, Vector3(DOOR_T, h, w), Vector3(DOOR_T * 0.5, h * 0.5, w * 0.5),
			MeshKit.mat("cabinet", Color(0.95, 0.95, 0.94), 0.5), "Frame")   # 扉の本体と裏は白
	# 鏡面（仮の材質）。壁面から 1mm 手前、縁を 1.5cm 残す
	MeshKit.box(door_pivot, Vector3(0.002, h - 0.03, w - 0.03), Vector3(-0.001, h * 0.5, w * 0.5),
			MeshKit.mat("mirror", Color(0.72, 0.78, 0.82), 0.08, 0.6), "Mirror")
	_build_reflection(h, w)
	# 取っ手代わりの小さなつまみ（蝶番と反対側の縁）
	MeshKit.box(door_pivot, Vector3(0.01, 0.05, 0.012), Vector3(-0.005, h * 0.5, w - 0.02),
			MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8), "Knob")
	# 鍵：扉の右端（取っ手の下）の小さな金具とつまみ（施錠中は横向き）
	var lock := Node3D.new()
	lock.name = "Lock"
	lock.position = Vector3(-0.006, h * 0.5 - 0.06, w - 0.02)
	door_pivot.add_child(lock)
	var brass := MeshKit.mat("brass", Color(0.78, 0.65, 0.35), 0.3, 0.8)
	var plate := MeshKit.cylinder(lock, 0.011, 0.006, Vector3(-0.003, 0, 0), brass, "Plate", -1.0, 20)
	plate.rotation.z = deg_to_rad(90.0)
	# マイナスの溝（施錠中は横向き）
	MeshKit.box(lock, Vector3(0.002, 0.0025, 0.017), Vector3(-0.0062, 0, 0), MeshKit.mat("lock_slot", Color(0.12, 0.1, 0.06), 0.8), "Slot")
	var lock_area := MeshKit.interact_area(lock, "LockArea", "mirror_lock", self)
	MeshKit.shape_box(lock_area, Vector3(0.016, 0.03, 0.03), Vector3(-0.006, 0, 0))
	var area := MeshKit.interact_area(door_pivot, "DoorArea", "mirror_door", self)
	MeshKit.shape_box(area, Vector3(DOOR_T + 0.012, h, w), Vector3(DOOR_T * 0.5 - 0.006, h * 0.5, w * 0.5))


## 鏡に映る顔。鏡面の 2.5mm 手前に顔のアップを貼り、見る人の位置で向きと横の位置を変える（見る人が鏡の横に外れると薄れて消える）。
func _build_reflection(h: float, w: float) -> void:
	_door_w = w
	_door_h = h
	reflection = CharacterScript.quad("head_front", 0.34)
	reflection.name = "Reflection"
	reflection.rotation.y = -PI * 0.5   # 鏡面の向き（-x）
	reflection.position = Vector3(-0.0025, h * 0.5 - 0.02, w * 0.5)
	var m := reflection.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.82, 0.9, 0.95, 0.9)   # 鏡の色を少し乗せる
	door_pivot.add_child(reflection)


func _process(_delta: float) -> void:
	if reflection == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var normal: Vector3 = door_pivot.global_transform.basis * Vector3(-1, 0, 0)
	var to_cam: Vector3 = cam.global_position - reflection.global_position
	var flat := Vector2(to_cam.x, to_cam.z)
	var n2 := Vector2(normal.x, normal.z).normalized()
	var angle := rad_to_deg(atan2(n2.cross(flat), n2.dot(flat)))
	var view: Array = CharacterScript.head_view(angle)
	var name: String = view[0]
	if reflection_view != name:
		reflection_view = name
		var t := CharacterScript.tex(name)
		var q := reflection.mesh as QuadMesh
		q.size = Vector2(0.34 * float(t.get_width()) / float(t.get_height()), 0.34)
		(reflection.material_override as StandardMaterial3D).albedo_texture = t
	var mat := reflection.material_override as StandardMaterial3D
	# 鏡に映ると左右が反転する。向きの反転は、見る側（angle の符号）と鏡の反転の両方
	var flip: bool = not bool(view[1])
	mat.uv1_scale = Vector3(-1.0 if flip else 1.0, 1.0, 1.0)
	mat.uv1_offset = Vector3(1.0 if flip else 0.0, 0.0, 0.0)
	# 見る人の位置（扉の幅の中）に顔を寄せ、外れたら消える
	var local: Vector3 = door_pivot.to_local(cam.global_position)
	reflection.position.z = clampf(local.z, 0.13, _door_w - 0.13)
	var outside := maxf(0.0, maxf(-local.z, local.z - _door_w))
	var facing := normal.dot(to_cam.normalized())
	mat.albedo_color.a = 0.9 * clampf(1.0 - outside / 0.5, 0.0, 1.0) * clampf(facing * 4.0, 0.0, 1.0)


# ---------------------------------------------------------------- main.gd から呼ばれる

## 点検レバーを引いた見た目（腕が手前へ倒れる）。
func pull_lever_visual(instant := false) -> void:
	lever_pulled = true
	var target := deg_to_rad(55.0)
	if instant:
		lever_arm.rotation.z = target
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lever_arm, "rotation:z", target, 0.4)


func get_prompt(_id: String) -> String:
	if busy:
		return ""
	if locked:
		return "examine"
	return "cabinet_close" if is_open else "cabinet_open"


func interact(_id: String) -> String:
	if locked:
		return "cabinet_locked"
	toggle()
	return ""
