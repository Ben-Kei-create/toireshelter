extends SceneTree
## クリア画面の記録の回帰テスト（クリアタイム・発見・調べた物・手に入れた物・コイン・ノート・ヒント）。
## 実行: Godot --headless --path . --script res://tests/clear_stats_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	_check(main.format_time(75.0) == "1:15", "時間の表示：75 秒 → 1:15（%s）" % main.format_time(75.0))
	_check(main.format_time(3725.0) == "1:02:05", "時間の表示：3725 秒 → 1:02:05（%s）" % main.format_time(3725.0))
	_check(main.format_time(5.0) == "0:05", "時間の表示：5 秒 → 0:05")

	main.add_item("driver")
	main.add_item("spare_roll")
	main.add_coin(2)
	main.progress.add_note("n1", "題", "本文")
	main.progress.discover("driver")
	main.play_time = 3725.0
	_check(main.items_found.size() >= 3 and main.coins_total == 2, "手に入れた物とコインが数えられる（%d 種類・%d 枚）" % [main.items_found.size(), main.coins_total])
	main.remove_item("driver")
	_check(main.items_found.has("driver"), "手放しても「手に入れた」は残る")

	main._clear("legit")
	await process_frame
	var text: String = main.hud._clear_stats.text
	print(text)
	_check(main.hud._clear_menu.visible, "クリア画面が出る")
	_check(text.find("クリアタイム　1:02:05") == 0, "最初の行はクリアタイム")
	_check(text.find("発見　1 / ") >= 0, "発見の数")
	_check(text.find("調べた物　") >= 0, "調べた物の数")
	_check(text.find("手に入れた物　3 / ") >= 0 or text.find("手に入れた物　4 / ") >= 0, "手に入れた物の種類数")
	_check(text.find("集めたコイン　2 枚") >= 0, "集めたコインの枚数")
	_check(text.find("推理ノート　1 件") >= 0, "ノートの件数")
	_check(text.find("神の声のヒント　0 / 5 回") >= 0, "ヒントの回数")
	_check(main.hud._clear_stats.visible, "記録が見える")

	# 保存と復元
	var snap: Dictionary = main.progress.snapshot()
	main.items_found.clear()
	main.coins_total = 0
	main.progress.apply(snap)
	_check(main.items_found.has("spare_roll") and main.coins_total == 2, "保存から、手に入れた物とコインの数が戻る")
	print("CLEAR STATS TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
