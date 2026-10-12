extends SceneTree
## ヘッドレス自動検証（実キーボード・マウスの操作確認の代わりにはならない）。
## 実行: Godot --headless --path . --script res://tests/smoke_test.gd
## 照準判定・取得→修理→脱出→再プレイ・一時停止/再開を、スクリプトから直接呼び出して確認する。

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var main := current_scene
	var player = main.player
	var room = main.room
	var driver_pos: Vector3 = room.driver_node.global_position

	# --- 照準：対象から視点を外して即クリック（物理フレームを挟まない）
	player.global_position = Vector3(0.2, 0.0, 0.3)
	await _frames(3)
	_aim(player, driver_pos)
	await physics_frame
	await physics_frame
	_check(player.get_focused() != null, "照準を合わせると表示用の判定にドライバーが入る")
	_aim(player, driver_pos + Vector3(-1.5, 1.2, 0.0))   # 視点を外す
	_check(player.get_focused() != null, "（再現）視点変更直後は表示用キャッシュが古い対象を返す")
	player.try_interact()
	_check(not main.has_driver, "視点を外した直後のクリックでは拾わない")

	# --- 壁越しの遮断：右の壁の外から狙う
	var saved: Vector3 = player.global_position
	player.global_position = Vector3(1.25, 0.0, 0.05)
	_aim(player, driver_pos)
	player.try_interact()
	_check(not main.has_driver, "壁越しには拾えない")
	player.global_position = saved

	# --- 換気口：初期位置（床）から見上げて調べられる。通常の距離 1.8m より遠い
	var vent_body: Node3D = room.get_node("Vent/Collision")
	var vent_pos: Vector3 = vent_body.global_position + Vector3(0.0, -0.02, 0.0)
	player.global_position = room.spawn_position
	_aim(player, vent_pos)
	var vent_dist: float = player.camera.global_position.distance_to(vent_pos)
	player.try_interact()
	_check(main.hud._message_label.text == main.MESSAGES["vent"] and vent_dist > player.INTERACT_RANGE,
			"初期位置から換気口を調べられる（距離 %.2fm）" % vent_dist)

	# --- 換気口：天井の上からは天井に遮られる
	main.hud._message_label.text = ""
	player.global_position = vent_body.global_position + Vector3(0.0, 0.0, 0.0)   # 目の高さが天井より上
	_aim(player, vent_pos)
	player.try_interact()
	_check(main.hud._message_label.text == "", "天井越しには換気口を調べられない")

	# --- ほかの対象の操作距離は伸びていない：レイが便器に当たる点が 1.8m より遠い位置から
	player.global_position = Vector3(0.65, 0.0, 1.0)
	_aim(player, Vector3(-0.6, 0.85, 0.0))   # タンク上部
	player.ray.force_raycast_update()
	var toilet_hit: Node = player.ray.get_collider()
	var hit_dist: float = player.ray.global_position.distance_to(player.ray.get_collision_point())
	player.try_interact()
	_check(toilet_hit == room.get_node("Toilet/Collision") and hit_dist > player.INTERACT_RANGE
			and main.hud._message_label.text == "",
			"便器は当たり点が 1.8m より遠いと調べられない（当たり点まで %.2fm）" % hit_dist)
	player.global_position = saved

	# --- ドアの広告：広告を狙うと poster、広告の外側（下）を狙うと従来どおり door
	var msgs: Dictionary = main.MESSAGES
	var poster: Node3D = room.door_pivot.get_node("Visual/Poster")
	player.global_position = Vector3(0.0, 0.0, 0.3)
	main.hud._message_label.text = ""
	_aim(player, poster.global_position)
	player.try_interact()
	_check(main.hud._message_label.text == msgs["poster"], "ドアの広告を調べられる")
	main.hud._message_label.text = ""
	_aim(player, room.door_pivot.global_position + Vector3(0.35, 0.6, 0.0))
	player.try_interact()
	_check(main.hud._message_label.text == msgs["door_locked"], "広告の外側を狙うとドアを調べられる")
	main.hud._message_label.text = ""
	_aim(player, room.door_pivot.global_position + Vector3(0.62, 0.95, 0.0))   # ドアノブ付近
	player.try_interact()
	_check(main.hud._message_label.text == msgs["door_locked"], "ドアノブ付近もドアとして反応する")

	# --- 広告：閉じたドアの外（廊下）からは、ドアに遮られて広告を調べられない
	player.global_position = Vector3(0.0, 0.0, 2.0)
	_aim(player, poster.global_position)
	_check(player.get_focused(true) == room.door_body, "廊下側からは広告ではなくドアに当たる")

	# --- 入浴剤：タンクの上に浮かず、はみ出さずに置かれている
	var powder: Node3D = room.get_node("BathPowder/Visual")
	var pp: Vector3 = powder.global_position
	var r: float = room.LID_RADIUS
	_check(is_equal_approx(pp.y, 0.925) and pp.x - r >= -0.9 and pp.x + r <= -0.7 and pp.z - r >= -0.2 and pp.z + r <= 0.2,
			"入浴剤の容器がタンク上面に収まっている (%s)" % pp)

	# --- 入浴剤を調べられる／壁の外からは調べられない
	var powder_mid := pp + Vector3(0.0, 0.08, 0.0)
	player.global_position = Vector3(0.0, 0.0, 0.3)
	main.hud._message_label.text = ""
	_aim(player, powder_mid)
	player.try_interact()
	_check(main.hud._message_label.text == msgs["bath_powder"], "入浴剤の容器を調べられる")
	player.global_position = Vector3(-1.3, 0.0, -0.08)
	_aim(player, powder_mid)
	var behind = player.get_focused(true)
	_check(behind == null, "左の壁の外からは入浴剤を調べられない")
	player.global_position = saved

	# --- 画像はミップマップ付きで取り込まれている
	_check(room.POSTER_TEX.get_image().has_mipmaps() and room.LABEL_TEX.get_image().has_mipmaps(),
			"広告・ラベルの画像にミップマップがある")

	# --- 照準を合わせてクリックすると拾える
	_aim(player, driver_pos)
	player.try_interact()
	_check(main.has_driver, "照準を合わせたクリックで拾える")
	await _frames(2)

	# --- ドア修理
	var door_pos: Vector3 = room.door_pivot.global_position + Vector3(0.35, 0.95, 0.0)
	player.global_position = Vector3(0.0, 0.0, 0.5)
	await _frames(3)
	_aim(player, door_pos)
	player.try_interact()
	_check(main.door_open, "ドライバー所持でドアを直せる")

	# --- 一時停止・再開
	main._pause()
	_check(paused and main.paused, "一時停止でツリーが止まる")
	var menu_size: Vector2 = main.hud._pause_menu.size
	_check(menu_size.x >= 640.0 and menu_size.y >= 360.0, "一時停止メニューが全画面に広がる (%s)" % menu_size)
	main._resume()
	_check(not paused and not main.paused, "再開でツリーが動く")

	# --- 出口通過
	await _seconds(1.4)
	for i in 120:
		player.velocity = Vector3.ZERO
		player.global_position = player.global_position.move_toward(Vector3(0.0, 0.05, 2.4), 0.03)
		await physics_frame
		if main.cleared:
			break
	_check(main.cleared, "廊下に出るとクリアになる")

	# --- 再プレイ
	main._retry()
	await _frames(10)
	var main2 := current_scene
	_check(main2 != main and not main2.has_driver and not main2.door_open and not main2.cleared,
			"「もう一度」で初期状態に戻る")
	_check(main2.room.driver_node != null, "再プレイ後にドライバーが元の位置にある")

	print("SMOKE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _aim(player: Node3D, point: Vector3) -> void:
	# マウス操作と同じく、本体の yaw とカメラの pitch を変える
	var eye: Vector3 = player.global_position + Vector3(0.0, player.EYE_HEIGHT, 0.0)
	var d := point - eye
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	player._pitch = pitch
	player.camera.rotation.x = pitch


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(t: float) -> void:
	await create_timer(t).timeout
