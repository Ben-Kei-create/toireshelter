extends CharacterBody3D
## 一人称プレイヤー。WASD移動・マウス視点・照準先の判定・姿勢（立つ／しゃがむ／座る／浴槽内）。
## ジャンプ・頭の揺れはなし。
##
## 姿勢は pose で一つだけ持ち、操作が混ざらないようにする:
##   WALK       … 立って歩く（目の高さ 1.5m、体の高さ 1.6m）
##   CROUCH     … しゃがむ（目の高さ 0.6m、体の高さ 0.7m、移動は遅い）。C で切り替え。立つ前に頭上を確かめる
##   SEATED     … 便器に座っている（決まった位置から見回すだけ。歩けない・しゃがめない）
##   IN_TUB     … 浴槽の中（決まった位置から見回すだけ）
##   DUCT       … 換気経路の中（低い姿勢で這う。目 0.38m・体 0.5m・半径 0.2m・速さ 0.7m/s。立ち上がれない）
##   KOTATSU_SEAT … こたつの座布団に座っている（決まった位置から見回すだけ。目の高さ 0.85m）
##   KOTATSU_IN   … こたつの布団の中。這って動ける（WASD、速さ 0.6m/s、目の高さ 0.27m、体の高さ 0.4m・半径 0.2m）。布団の外へ出ると立つ
##   TRANSITION … 座る／立つ／浴槽に入る／出るの移動演出中（見回し・操作・移動すべて無効）
## SEATED / IN_TUB / TRANSITION の間は体の当たり判定を切り、重力もかけない（決まった位置に置くため）。
## 足元（このノードの原点）はどの姿勢でも床の高さで、体の形は足元から上に伸ばす。

signal interact_requested(target: Object)
signal crouch_blocked   # 頭上が狭くて立てなかった

enum Pose { WALK, CROUCH, SEATED, IN_TUB, TRANSITION, DUCT, KOTATSU_SEAT, KOTATSU_IN }

const Sfx := preload("res://scripts/sfx.gd")

const SPEED := 1.8
const CROUCH_SPEED := 0.8
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 9.8
const INTERACT_RANGE := 1.8       # 通常の対象を調べられる距離
const INTERACT_RANGE_MAX := 2.4   # レイの長さ。対象ごとの interact_range メタの上限
const EYE_HEIGHT := 1.5
const CROUCH_EYE_HEIGHT := 0.6
const EYE_HEIGHT_MIN := 1.3
const EYE_HEIGHT_MAX := 1.7
const BODY_RADIUS := 0.25
const BODY_HEIGHT := 1.6
const CROUCH_BODY_HEIGHT := 0.7
const EYE_LERP_SPEED := 8.0       # 目の高さの追従（大きいほど速い）
const PITCH_LIMIT_DEG := 85.0
const MOVE_TIME := 0.6            # 座る／浴槽に入るときの移動演出の長さ
const DUCT_SPEED := 0.7
const KOTATSU_SPEED := 0.6        # こたつの中を這う速さ
const KOTATSU_BODY_HEIGHT := 0.4
const KOTATSU_BODY_RADIUS := 0.2
const STEP_DISTANCE := 0.62       # 足音を鳴らす歩幅（しゃがむ・這うときは短い）
const DUCT_EYE_HEIGHT := 0.38
const DUCT_BODY_HEIGHT := 0.5
const DUCT_BODY_RADIUS := 0.2

var controls_enabled := true
var pose: Pose = Pose.WALK
var camera: Camera3D
var ray: RayCast3D
var _pitch := 0.0
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _eye_target := EYE_HEIGHT
var eye_height := EYE_HEIGHT          # 立っているときの目の高さ（設定で変えられる。EYE_HEIGHT_MIN〜MAX）
var _settled_pose: Pose = Pose.WALK   # 移動演出が終わったあとの姿勢
var _step_acc := 0.0


func _ready() -> void:
	collision_layer = 8   # layer 4: player
	collision_mask = 1 | 16   # layer 1: world / layer 5: 体だけを止める板（照準のレイは通す）

	_capsule = CapsuleShape3D.new()
	_capsule.radius = BODY_RADIUS
	_capsule.height = BODY_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.name = "Collision"
	_shape.shape = _capsule
	_shape.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	add_child(_shape)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.fov = 80.0
	camera.near = 0.03
	add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0.0, 0.0, -INTERACT_RANGE_MAX)
	ray.collision_mask = 1 | 2   # world + interact
	ray.collide_with_bodies = true
	ray.collide_with_areas = true
	camera.add_child(ray)
	ray.add_exception(self)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or pose == Pose.TRANSITION:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY,
				deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
		camera.rotation.x = _pitch
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			# ウィンドウ外クリック等でマウスが外れていたら、まず掴み直すだけ
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		try_interact()
	elif event.is_action_pressed("crouch"):
		get_viewport().set_input_as_handled()
		# 入力を受けた時点の姿勢で分岐し、1回の入力につき toggle_crouch() を1回だけ呼ぶ
		var was := pose
		if was == Pose.WALK or was == Pose.CROUCH:
			if not toggle_crouch() and was == Pose.CROUCH:
				crouch_blocked.emit()


## 世界の点 p のほうへ視点を向ける（ゲームを始めるときなど）。
func look_at_point(p: Vector3) -> void:
	var d := p - camera.global_position
	rotation.y = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-PITCH_LIMIT_DEG), deg_to_rad(PITCH_LIMIT_DEG))
	camera.rotation.x = _pitch


func _process(delta: float) -> void:
	# 立つ／しゃがむときの目の高さは滑らかに追従させる（移動演出中は Tween が動かす）
	if pose == Pose.WALK or pose == Pose.CROUCH:
		camera.position.y = lerpf(camera.position.y, _eye_target, 1.0 - exp(-EYE_LERP_SPEED * delta))


func _physics_process(delta: float) -> void:
	if not is_walking():
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length() > 0.001:
		dir = dir.normalized()
	var speed := SPEED
	if pose == Pose.CROUCH:
		speed = CROUCH_SPEED
	elif pose == Pose.DUCT:
		speed = DUCT_SPEED
	elif pose == Pose.KOTATSU_IN:
		speed = KOTATSU_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	# 足音（歩く・しゃがむ・這うとき。歩幅ごとに小さく1回）
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.2:
		_step_acc += Vector2(velocity.x, velocity.z).length() * delta
		var stride := STEP_DISTANCE * (0.6 if pose != Pose.WALK else 1.0)
		if _step_acc >= stride:
			_step_acc = 0.0
			_play_step()


## 立っているときの目の高さを変える（設定の「身長」）。立っていれば、目の高さは滑らかに追従する。
func set_eye_height(h: float) -> void:
	eye_height = clampf(h, EYE_HEIGHT_MIN, EYE_HEIGHT_MAX)
	if pose == Pose.WALK:
		_eye_target = eye_height


## 足元の素材ごとの足音：[音の名前, 高さの倍率, 音量の加減 dB, 重ねる音（なければ空）]。素材は surface_fn（足元 → 素材名）が返す。
const STEP_SOUNDS := {
	"wood": ["step", 1.0, 0.0, ""],
	"tile": ["step", 1.4, 1.0, "tick"],
	"rug": ["step", 0.7, -5.0, ""],
	"hollow": ["thunk", 1.3, -14.0, ""],
	"concrete": ["step", 1.2, 1.5, "tick"],
	"metal": ["clunk", 1.5, -13.0, ""],
}
var surface_fn := Callable()   # 足元の位置 → 素材名（main.gd が設定。なければ wood）


func _play_step() -> void:
	var kind := "wood"
	if surface_fn.is_valid():
		kind = String(surface_fn.call(global_position))
	var def: Array = STEP_SOUNDS.get(kind, STEP_SOUNDS["wood"])
	var db := (-9.0 if pose == Pose.WALK else -15.0) + float(def[2])
	Sfx.play(def[0], float(def[1]) * randf_range(0.9, 1.1), db)
	if def[3] != "":
		Sfx.play(def[3], randf_range(0.8, 1.0), db - 4.0)


## 自分の足で動ける姿勢（立つ／しゃがむ／換気経路で這う）か。
func is_walking() -> bool:
	return pose == Pose.WALK or pose == Pose.CROUCH or pose == Pose.DUCT or pose == Pose.KOTATSU_IN


# ---------------------------------------------------------------- しゃがむ

## しゃがむ／立つ。立つときは頭上に立った体が入る空間があるか確かめ、なければ立たない（false を返す）。
func toggle_crouch() -> bool:
	if pose == Pose.WALK:
		_set_body_height(CROUCH_BODY_HEIGHT)
		pose = Pose.CROUCH
		_eye_target = CROUCH_EYE_HEIGHT
		return true
	if pose == Pose.CROUCH:
		if not is_space_free(global_position, BODY_HEIGHT):
			return false
		_set_body_height(BODY_HEIGHT)
		pose = Pose.WALK
		_eye_target = eye_height
		return true
	return false


## こたつの中を這う状態から、外へ抜けて立つ（立てなければしゃがむ）。体の形を戻す。
func leave_crawl() -> void:
	if pose != Pose.KOTATSU_IN:
		return
	if is_space_free(global_position, BODY_HEIGHT):
		_set_body_height(BODY_HEIGHT)
		pose = Pose.WALK
		_eye_target = eye_height
	else:
		_set_body_height(CROUCH_BODY_HEIGHT)
		pose = Pose.CROUCH
		_eye_target = CROUCH_EYE_HEIGHT


## 足元 feet に、高さ height の体が壁や設備に重ならずに入るか。
func is_space_free(feet: Vector3, height: float, radius: float = BODY_RADIUS) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = capsule
	# 床に接した状態で床と重なったと数えないよう、2cm 浮かせて調べる
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3(0.0, height * 0.5 + 0.02, 0.0))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func _set_body_height(height: float, radius: float = BODY_RADIUS) -> void:
	_capsule.radius = radius
	_capsule.height = height
	_shape.position = Vector3(0.0, height * 0.5, 0.0)


# ---------------------------------------------------------------- 座る・浴槽に入る

## 決まった位置へ短く滑らかに移って、その姿勢（SEATED / IN_TUB）になる。
## feet：足元の位置、yaw：向き、eye：目の高さ（足元から）。
func enter_fixed(target_pose: Pose, feet: Vector3, yaw: float, eye: float) -> void:
	if not is_walking():
		return
	move_to(target_pose, feet, yaw, eye)


## 座っている／浴槽にいる／換気経路にいる状態から、候補の足元のうち最初に空いている所へ立って移る。
## どこも空いていなければ何もせず false。
func leave_fixed(candidates: Array, via: Array = []) -> bool:
	if pose != Pose.SEATED and pose != Pose.IN_TUB and pose != Pose.DUCT and pose != Pose.KOTATSU_SEAT:
		return false
	for c in candidates:
		var feet: Vector3 = c
		if is_space_free(feet, BODY_HEIGHT):
			move_to(Pose.WALK, feet, rotation.y, eye_height, via, true, BODY_HEIGHT, BODY_RADIUS)
			return true
	return false


## 移動演出の共通部分。体の当たり判定を切って、via（足元の経由点）を順に通り feet へ移る。
## 終わると target_pose になる。enable_body なら体の形を (body_h, body_r) にして当たり判定を戻す。
func move_to(target_pose: Pose, feet: Vector3, yaw: float, eye: float, via: Array = [],
		enable_body := false, body_h := BODY_HEIGHT, body_r := BODY_RADIUS) -> void:
	_shape.disabled = true
	_settled_pose = target_pose
	pose = Pose.TRANSITION
	velocity = Vector3.ZERO
	if target_pose == Pose.WALK or target_pose == Pose.CROUCH:
		_eye_target = eye
	var points := via.duplicate()
	points.append(feet)
	# 経由点が多いときは少し長く（1区間あたり最低 0.3 秒）。向きと目の高さは全体の時間で変える
	var total := maxf(MOVE_TIME, 0.3 * points.size())
	var seg := total / points.size()
	var look := create_tween().set_parallel()
	look.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_property(self, "rotation:y", _nearest_angle(rotation.y, yaw), total)
	look.tween_property(camera, "position:y", eye, total)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in points.size():
		tween.tween_property(self, "global_position", points[i], seg)
	tween.tween_callback(func() -> void:
		if enable_body:
			_set_body_height(body_h, body_r)
			_shape.disabled = false
		pose = _settled_pose)


func _nearest_angle(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)


# ---------------------------------------------------------------- 照準

## クリック時の操作。視点を変えた直後でも、今の向きでレイを撃ち直してから判定する。
func try_interact() -> void:
	if pose == Pose.TRANSITION:
		return
	var target := get_focused(true)
	if target:
		interact_requested.emit(target)


## 照準の先にある「調べられる対象」を返す。なければ null。
## 壁など調べられない物に先に当たった場合も null（壁越しに操作できない）。
## force_update=false は前回の物理フレームの結果（表示用）。操作時は true で撃ち直す。
func get_focused(force_update: bool = false) -> Object:
	if not controls_enabled or pose == Pose.TRANSITION:
		return null
	if force_update:
		ray.force_raycast_update()
	if not ray.is_colliding():
		return null
	var collider := ray.get_collider()
	if collider == null or not is_instance_valid(collider):
		return null
	var hit := collider as Node
	if hit == null or hit.is_queued_for_deletion():
		return null
	if not hit.has_meta("interact_id"):
		return null
	# 距離の上限は対象ごと（天井の換気口など）。指定がなければ INTERACT_RANGE
	var max_range: float = hit.get_meta("interact_range", INTERACT_RANGE)
	if ray.global_position.distance_to(ray.get_collision_point()) > max_range:
		return null
	return hit
