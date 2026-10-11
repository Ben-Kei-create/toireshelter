extends CharacterBody3D
## 一人称プレイヤー。WASD移動・マウス視点・照準先の判定。
## ジャンプ・視点の揺れはなし。

signal interact_requested(target: Object)

const SPEED := 1.8
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 9.8
const INTERACT_RANGE := 1.8
const EYE_HEIGHT := 1.5
const BODY_RADIUS := 0.25
const BODY_HEIGHT := 1.6
const PITCH_LIMIT_DEG := 85.0

var controls_enabled := true
var camera: Camera3D
var ray: RayCast3D
var _pitch := 0.0


func _ready() -> void:
	collision_layer = 8   # layer 4: player
	collision_mask = 1    # layer 1: world

	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = capsule
	cs.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	add_child(cs)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	camera.fov = 80.0
	camera.near = 0.03
	add_child(camera)
	camera.current = true

	ray = RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0.0, 0.0, -INTERACT_RANGE)
	ray.collision_mask = 1 | 2   # world + interact
	ray.collide_with_bodies = true
	ray.collide_with_areas = true
	camera.add_child(ray)
	ray.add_exception(self)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
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


func _physics_process(delta: float) -> void:
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
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	move_and_slide()


## クリック時の操作。視点を変えた直後でも、今の向きでレイを撃ち直してから判定する。
func try_interact() -> void:
	var target := get_focused(true)
	if target:
		interact_requested.emit(target)


## 照準の先にある「調べられる対象」を返す。なければ null。
## 壁など調べられない物に先に当たった場合も null（壁越しに操作できない）。
## force_update=false は前回の物理フレームの結果（表示用）。操作時は true で撃ち直す。
func get_focused(force_update: bool = false) -> Object:
	if not controls_enabled:
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
	if hit.has_meta("interact_id"):
		return hit
	return null
