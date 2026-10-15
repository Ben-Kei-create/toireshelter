extends SceneTree
## 段階 6-2 の検証：吹き矢（材料＋使い切った芯＋毛だまり）→ ベランダから向かいの的（目の高さ 160cm 以上で見える）→ コイン 8。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/stage6b_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m := current_scene
	m.credits_enabled = false
	m.ride_speed = 20.0
	return m


func _aim(main: Node, at: Vector3) -> void:
	var p = main.player
	var d: Vector3 = at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	p._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.camera.rotation.x = p._pitch
	await physics_frame


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	var Ext = main.ExteriorScript
	for id in ["blowgun_part", "tp_core2", "lint"]:
		main.add_item(id)
	main.select_item(0)
	main.use_selected()
	_check(main.inventory == ["blowgun"], "吹き矢の材料＋使い切った芯＋毛だまりで、吹き矢ができる（%s）" % str(main.inventory))
	main.select_item(0)
	main.use_selected()
	_check(main.hud._message_label.text == main.STAGE5["blowgun_need_balcony"] and main.darts_used == 0, "ベランダ以外では撃てない")
	room.exterior.set_blowgun_sign_visible(false)
	main.player.global_position = Vector3(2.4, 0.0, -1.7)
	main.player.set_eye_height(1.4)
	await physics_frame
	await _aim(main, Ext.SIGN_POS)
	main.use_selected()
	_check(main.darts_used == 1 and not room.exterior.sign_hit and main.hud._message_label.text == main.STAGE5["blowgun_hidden"], "目の高さが低いと、的は庇に隠れて見えない（当たらない）")
	main.player.set_eye_height(1.7)
	await physics_frame
	await _aim(main, Ext.SIGN_POS)
	main.use_selected()
	await create_timer(0.3).timeout
	_check(room.exterior.sign_hit and main.darts_used == 2, "目の高さ 170 cm なら、的に当たる")
	await create_timer(0.3).timeout
	_check(room.exterior.dart_coin != null, "コインが、ベランダの床に落ちる")
	var c0: int = main.coin_count
	main._on_interact_requested(room.exterior.dart_coin.get_node("DartCoinArea"))
	_check(main.coin_count == c0 + 1 and room.exterior.dart_coin_taken, "コインを拾う（8 枚目）")
	await _aim(main, Ext.SIGN_POS + Vector3(2.5, 0.0, 0.0))
	main.use_selected()
	_check(room.exterior.darts.size() == 3, "外れた矢も、壁に残る")
	main.darts_used = main.DARTS_MAX
	main.use_selected()
	_check(main.hud._message_label.text == main.STAGE5["blowgun_out"], "100 本使うと、矢がなくなる")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	await process_frame
	_check(main.darts_used == main.DARTS_MAX and main.room.exterior.sign_hit and main.room.exterior.dart_coin == null and main.room.exterior.dart_coin_taken, "復元しても、同じ（コインは取りずみ）")
	print("STAGE6B TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
