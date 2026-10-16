extends SceneTree
## 段階 0（土台）の回帰テスト：推理ノート・幕の目次・目の高さのキー（[ と ]）・神の声モードの表示。
## 実行: Godot --headless --path . --script res://tests/notebook_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	var progress = main.progress
	var hud = main.hud
	main._on_eye_height_changed(1.5)   # 設定ファイルの目の高さが前のテストの値でも、同じ状態から始める
	main.hud.set_eye_height_ui(1.5)

	# 推理ノート
	_check(progress.notes.is_empty(), "はじめはノートが空")
	_check(progress.add_note("t1", "題1", "本文1", "手がかり"), "ノートに書き足せる")
	_check(not progress.add_note("t1", "題1", "本文1"), "同じ id は二度書かれない")
	progress.add_note("t2", "題2", "本文2", "パスワード")
	_check(progress.notes.size() == 2, "ノートは 2 件")
	var text: String = progress.notes_text()
	_check(text.find("題2") < text.find("題1") and text.find("題1") >= 0, "新しいものが上に並ぶ")
	_check(text.find("【パスワード】") >= 0, "種類が付く")

	# 調べると自動で書かれる手がかり（既存の貼り紙）
	var n0: int = progress.notes.size()
	progress.add_note("tub_note", "浴槽の紙", "『ここまで来たか。』")
	_check(progress.has_note("tub_note") and progress.notes.size() == n0 + 1, "貼り紙の手がかりが書かれる")
	_check(main.NOTE_CLUES.has("shelf_note") and main.NOTE_CLUES.has("tank_note"), "棚の紙・タンクの紙も登録されている")

	# 幕の目次
	_check(progress.chapter == 0 and progress.chapter_name() == "第1幕　ユニットバス", "はじめは第 1 幕")
	var lines: String = progress.chapter_lines()
	_check(lines.find("▶　第1幕") == 0 and lines.find("？？？") > 0 and lines.find("第2幕") < 0, "先の幕は「？？？」")
	progress.set_chapter(1)
	_check(progress.chapter == 1 and progress.chapter_lines().find("✓　第1幕") == 0, "幕が進み、終えた幕にチェックが付く")
	progress.set_chapter(0)
	_check(progress.chapter == 1, "幕は戻らない")

	# 開閉（N）
	_key(KEY_N)
	await process_frame
	await process_frame
	_check(hud.is_notebook_open(), "N でノートが開く")
	_check(hud._notebook_body.text.find("題1") >= 0 and hud._notebook_chapters.text.find("▶　第2幕") >= 0, "本文と目次が表示される")
	_key(KEY_N)
	await process_frame
	await process_frame
	_check(not hud.is_notebook_open(), "もう一度 N で閉じる")

	# 保存と復元
	var snap: Dictionary = progress.snapshot()
	_check(snap.notes.size() == progress.notes.size() and int(snap.chapter) == 1, "保存にノートと幕が入る")
	progress.notes.clear()
	progress.chapter = 0
	progress.apply(snap)
	_check(progress.has_note("t2") and progress.chapter == 1, "読み込むとノートと幕が戻る")

	# 目の高さのキー
	var h0: float = main.player.eye_height
	_key(KEY_BRACKETRIGHT)
	await process_frame
	await process_frame
	_check(is_equal_approx(main.player.eye_height, minf(h0 + 0.02, 1.7)), "] で目の高さが上がる（%.2f → %.2f）" % [h0, main.player.eye_height])
	_key(KEY_BRACKETLEFT)
	_key(KEY_BRACKETLEFT)
	await process_frame
	await process_frame
	_check(is_equal_approx(main.player.eye_height, h0 - 0.02), "[ で下がる（%.2f）" % main.player.eye_height)
	for i in 30:
		main._unhandled_input(_make_action("eye_up"))
	_check(is_equal_approx(main.player.eye_height, 1.7), "上限は 170 cm")
	for i in 40:
		main._unhandled_input(_make_action("eye_down"))
	_check(is_equal_approx(main.player.eye_height, 1.3), "下限は 130 cm")
	_check(is_equal_approx(hud._height_slider.value, 130.0), "設定のスライダーも合う")

	main._on_eye_height_changed(1.5)   # 設定ファイルを元の高さに戻す（ほかのテストに影響させない）
	# 神の声モード（表示の名前）
	_check(hud._hints_check.text.begins_with("ヒント"), "設定の項目名は「ヒント」（簡素化）")
	print("NOTEBOOK TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _make_action(name: String) -> InputEventAction:
	var a := InputEventAction.new()
	a.action = name
	a.pressed = true
	return a


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
