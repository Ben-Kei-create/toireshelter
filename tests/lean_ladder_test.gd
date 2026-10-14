extends SceneTree
## 段階 1c：ボロボロのはしご（ダクトの出口から下ろす）／ベランダの手すりから身を乗り出す／右手の KO線。
## 実行: Godot --headless --path . --script res://tests/lean_ladder_test.gd

const Pose := preload("res://scripts/player.gd").Pose
const Ext := preload("res://scripts/exterior.gd")
var _failures := 0


func _initialize() -> void:
	_run()


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _aim(player: Node3D, point: Vector3) -> void:
	var d: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	player._pitch = pitch
	player.camera.rotation.x = pitch


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var room = main.room
	var ext = room.exterior
	var player = main.player

	# KO線：高架と電車がある。電車は動く
	var ko: Node3D = ext.get_node_or_null("KoLine")
	_check(ko != null and ko.get_node_or_null("Train") != null and ko.get_node_or_null("Deck") != null, "KO線の高架と電車がある")
	_check(ko.position.x > Ext.BALCONY.end.x + 10.0, "右手（+x）の遠くにある（x=%.0f）" % ko.position.x)
	var z0: float = ext._ko_z
	ext._process(1.0)
	_check(ext._ko_z > z0, "電車がゆっくり走る（%.1f → %.1f m）" % [z0, ext._ko_z])
	_check(ext.get_node_or_null("EastView") != null, "東の端の建物の向こうに、遠くの景色がある（空が抜けない）")

	# はしご
	_check(not ext.ladder_down and ext.get_node_or_null("Ladder") == null, "はじめは、はしごを下ろしていない")
	ext.lower_ladder(Ext.DUCT_FLOOR + 0.9, true)
	var lad = ext.get_node("Ladder")
	_check(ext.ladder_down and lad.get_child_count() >= 6, "はしごが下りる（部品 %d 個）" % lad.get_child_count())
	_check(is_equal_approx(lad.position.y, Ext.DUCT_FLOOR + 0.9), "上の端は、ダクトの出口の高さ（浴室が上がった分も足す）")
	var rungs := 0
	for c in lad.get_children():
		if c is MeshInstance3D and (c.mesh as BoxMesh).size.is_equal_approx(Vector3(0.32, 0.025, 0.025)):
			rungs += 1
	_check(rungs >= 5 and rungs < int((Ext.DUCT_FLOOR + 0.9) / 0.3), "段は抜けている（%d 本）" % rungs)
	var snap: Dictionary = main.progress.snapshot()
	_check(bool(snap.ladder_down), "保存に、はしごを下ろしたが入る")

	# 身を乗り出す
	player.global_position = Vector3(2.5, 0.0, -1.75)
	await _seconds(0.3)
	player.rotation.y = 0.0
	_aim(player, Vector3(2.5, 0.9, Ext.BALCONY.position.z + 0.14))
	await _seconds(0.2)
	var t = player.get_focused(true)
	_check(t != null and String(t.get_meta("interact_id", "")) == "fish_spot", "手すりを狙える（釣り場の判定）")
	_check(main._action_for(t) == "lean_out" and main.ACTION_PROMPTS["lean_out"].find("乗り出す") >= 0, "「E：手すりから身を乗り出す」")
	main.do_action()
	await _seconds(1.2)
	_check(player.pose == Pose.LEAN, "身を乗り出す姿勢になる")
	_check(player.global_position.z < Ext.BALCONY.position.z - 0.2, "体が手すりの外へ出る（z=%.2f）" % player.global_position.z)
	_check(main._action_for(null) == "lean_back" and main.ACTION_PROMPTS["lean_back"] != "", "「E：身を戻す」")
	_check(not player.is_walking(), "乗り出している間は歩けない")
	# 右手（東）を見ると、KO線のことを言う
	player.rotation.y = -PI * 0.5
	player.camera.rotation.x = 0.0
	player._pitch = 0.0
	await _seconds(0.3)
	_check(main._ko_seen and main.progress.discovered.has("ko_line") and main.progress.has_note("ko_line"), "右手を見ると、KO線に気づく（発見・ノート）")
	main.do_action()
	await _seconds(1.2)
	_check(player.pose == Pose.WALK and Ext.in_balcony(player.global_position), "戻ると、ベランダに立っている（%s）" % player.global_position)
	_check(player.global_position.z > Ext.BALCONY.position.z, "手すりの内側")

	# 保存から読み込み直すと、はしごは下りたまま
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var m2 = current_scene
	m2.progress.apply(snap)
	await process_frame
	_check(m2.room.exterior.ladder_down and m2.room.exterior.get_node_or_null("Ladder") != null, "読み込むと、はしごは下りている")
	print("LEAN LADDER TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
