extends SceneTree
## タイトル画面の回帰テスト。
## 実行: TOIRE_TITLE=1 Godot --headless --path . --script res://tests/title_test.gd
## 確認：起動時にタイトルが出てゲームは止まっている／背景のカメラが回る／エレベーターと電車が動く／
##       設定は「もどる」だけでゲームの再開にならない／はじめるで画面が消えて遊べる／難易度の選択がない。

var _failures := 0


func _initialize() -> void:
	OS.set_environment("TOIRE_TITLE", "1")
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(8)
	var main = current_scene
	var title = main._title
	_check(title != null and main.title_active(), "起動時にタイトル画面が出る")
	if title == null:
		quit(1)
		return
	_check(paused, "タイトルの間、ゲームは止まっている")
	_check(not main.player.controls_enabled, "タイトルの間、操作は無効")
	var names := []
	for b in title.buttons():
		names.append(b.text)
	_check(names == ["はじめる", "設定", "終了"], "ボタンは「はじめる」「設定」「終了」だけ（難易度なし） %s" % [names])
	_check((title.find_child("Title", true, false) as Label).text == "コーポヨシミ", "題名は「コーポヨシミ」")
	_check(title.find_children("*", "Label3D", true, false).size() >= 3, "マンションの看板がある")

	# 背景：カメラが周回し、エレベーターと電車が動く
	var cam: Camera3D = title._camera
	var p0 := cam.global_position
	var e0: float = title._elevator.position.y
	var t0: float = title._train_x
	await _wait(4.0)
	_check(cam.global_position.distance_to(p0) > 0.5, "カメラがマンションのまわりを回る（%.2f m 動いた）" % cam.global_position.distance_to(p0))
	var radius0 := Vector2(p0.x, p0.z).length()
	var radius1 := Vector2(cam.global_position.x, cam.global_position.z).length()
	_check(absf(radius0 - radius1) < 1.0, "回る半径は変わらない（%.1f → %.1f）" % [radius0, radius1])
	_check(cam.global_position.y > 18.0, "俯瞰（高さ %.1f m）" % cam.global_position.y)
	_check(not is_equal_approx(title._elevator.position.y, e0), "エレベーターが動く")
	_check(title._train_x > t0, "KO線が走る")
	_check(title.find_children("*", "CPUParticles3D", true, false).size() >= 1, "BBQの煙がある")

	# 設定：「もどる」だけ。閉じてもゲームは再開しない
	title.settings_requested.emit()
	await _frames(2)
	var hud = main.hud
	_check(hud._pause_menu.visible, "設定が開く")
	_check(hud._resume_button.text == "もどる" and not hud._restart_button.visible and not hud._quit_button.visible,
			"設定は「もどる」だけ（はじめから・終了は出ない）")
	hud._resume_button.pressed.emit()
	await _frames(2)
	_check(not hud._pause_menu.visible and main._title != null and paused, "「もどる」でタイトルに戻る（ゲームは止まったまま）")

	# はじめる
	title.buttons()[0].pressed.emit()
	await _wait(1.2)
	_check(main._title == null and not main.title_active(), "はじめるでタイトルが消える")
	_check(not paused, "ゲームが動き出す")
	_check(main.player.controls_enabled, "操作が有効になる")
	_check(hud._resume_button.text == "再開" and hud._restart_button.visible, "設定は通常の形に戻る")
	_check(hud._dot.visible, "照準が戻る")
	print("TITLE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout
