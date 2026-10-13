extends SceneTree
## 文字送り・神の声・やさしいヒント・発見の知らせ・簡易セーブの自動検証（ヘッドレス）。
## 実行: TOIRE_SAVE_TEST=1 Godot --headless --path . --script res://tests/progress_test.gd   （保存は、この環境変数があるときだけ動く）
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _fresh() -> Node:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	return current_scene


func _run() -> void:
	if OS.get_environment("TOIRE_SAVE_TEST") != "1":
		print("TOIRE_SAVE_TEST=1 を付けて実行してください")
		quit(2)
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	var main := await _fresh()
	var hud = main.hud
	var pr = main.progress
	check(pr.enabled and not pr.has_save(), "保存が有効で、最初は保存がない")
	# --- 文字送りと神の声
	hud.typing_on = true
	hud.show_message("あいうえおかきくけこ", 4.0)
	check(hud._message_label.visible_characters == 0 and hud._message_panel.visible, "文字送り：最初は 0 文字")
	hud._process(0.1)
	var vc: int = hud._message_label.visible_characters
	check(vc > 0 and vc < 10, "文字送り：少しずつ増える（%d / 10）" % vc)
	check(hud._message_time_left >= 4.0, "読む時間は、出そろってから数え始める")
	hud.finish_typing()
	check(hud._message_label.visible_characters == -1, "全部を一気に見せられる")
	hud.typing_on = false
	hud.show_message("オフのとき")
	check(hud._message_label.visible_characters == -1, "文字送りをオフにすると、一気に出る")
	hud.typing_on = true
	hud.show_message("ヒント", -1.0, "voice")
	check(hud._message_label.text == "『ヒント』" and hud._message_label.get_theme_color("font_color").b > 0.9 and hud._message_label.get_theme_color("font_color").r < 0.9, "神の声：かぎ括弧つきで、うすい紫")
	check(hud._messages[hud._messages.size() - 1] == "『ヒント』", "神の声も履歴に残る")
	# --- 発見
	pr.discover("cellar")
	pr.discover("cellar")
	check(pr.discovered.size() == 1 and hud._disc_panel.visible, "発見：1 回だけ数えて、右上に知らせる")
	check((hud._disc_panel.get_child(0) as Label).text.contains("床下の貯蔵庫") and (hud._disc_panel.get_child(0) as Label).text.contains("/ %d" % pr.total()), "知らせに名前と n / 全体が出る")
	pr.discover("そんなものはない")
	check(pr.discovered.size() == 1, "登録のない物は数えない")
	# --- ヒント
	pr.hints_shown.clear()
	pr.discovered.clear()
	check(pr.force_hint() and pr.hints_shown.has("floor"), "最初のヒントは「床の一部が…」")
	check(hud._message_label.text.begins_with("『そういえば、床の一部が"), "神の声で出る")
	var seq := []
	for i in 12:
		if pr.force_hint():
			seq.append(pr.hints_shown.size())
	check(pr.hints_shown.has("calm") and pr.hints_shown.size() <= 9 and not pr.force_hint(), "出したヒントは二度と出ない（全部出すと、もう出ない）")
	pr.hints_shown.clear()
	pr.discovered["cellar"] = true
	pr.force_hint()
	check(pr.hints_shown.has("food") or pr.hints_shown.has("mj_box"), "状況に合ったヒントが選ばれる（床下を見つけた後は、床のヒントを出さない）")
	check(not pr.hints_shown.has("floor"), "見つけた物のヒントは出さない")
	pr.hints_shown.clear()
	pr.idle_t = pr.IDLE_TIME + 1.0
	pr.since_hint = pr.HINT_GAP + 1.0
	pr.hints_on = false
	pr._process(0.016)
	check(pr.hints_shown.is_empty(), "ヒントをオフにすると出ない")
	pr.hints_on = true
	main.paused = true
	pr._process(0.016)
	check(pr.hints_shown.is_empty() and pr.idle_t == 0.0, "一時停止中は出ず、待ち時間も数えない")
	main.paused = false
	pr.idle_t = pr.IDLE_TIME + 1.0
	pr.since_hint = pr.HINT_GAP + 1.0
	pr._process(0.016)
	check(pr.hints_shown.size() == 1, "同じ場所で何もしないまま時間が過ぎると、独り言が出る")
	pr.idle_t = pr.IDLE_TIME + 1.0
	pr._process(0.016)
	check(pr.hints_shown.size() == 1, "つぎのヒントまで間をあける")
	# --- 保存して、読み込み直す
	pr.discovered.clear()
	pr.hints_shown.clear()
	var apt = main.room.apartment
	main._on_interact_requested(apt.closet.mahjong_box.get_node("MahjongArea"))
	main._on_interact_requested(apt.record_player.get_node("RecordDiscArea"))
	main.add_coin(2)
	var cel = apt.cellar
	cel.set_open(true, false)
	apt.kitchen.interact("fridge_lower")
	await create_timer(0.8).timeout
	for id in cel.FOODS.keys():
		cel.interact(id)
		main._on_interact_requested(apt.kitchen.get_node("InsideArea"))
	check(cel.stairs_open and pr.discovered.has("stairs") and pr.discovered.has("mahjong") and pr.discovered.has("record_disc"), "進めると発見が記録される（階段・麻雀牌・レコード盤）")
	check(pr.has_save(), "拾ったり進めたりすると、保存される")
	var play_t: float = main.play_time
	var inv_before: Array = main.inventory.duplicate()
	var n_disc: int = pr.discovered.size()
	main = await _fresh()
	apt = main.room.apartment
	pr = main.progress
	check(pr.discovered.size() >= n_disc and pr.discovered.has("stairs"), "読み込み後も、発見が残っている")
	check(main.inventory == inv_before and main.coin_count == 2, "持ち物と UFOコインの枚数が戻る %s" % str(main.inventory))
	check(apt.closet.mahjong_box == null or apt.closet.mahjong_box.is_queued_for_deletion(), "拾った麻雀牌は、押入れに戻らない")
	check(apt.record_player.display_taken, "拾ったレコード盤は、床に戻らない")
	check(apt.cellar.stairs_open and apt.cellar.stored.size() == 7 and apt.basement.visible, "冷蔵庫に入れた 7 つと、階段・地下が戻る")
	check(main.play_time >= play_t - 1.0, "プレイ時間が引き継がれる")
	check(main._item_models.has("mahjong") and main._item_models.has("record_disc") and main._item_models.has("ufo_coin"), "持ち物の拡大表示の絵も戻る")
	# 手に持っていた物は、床下の棚へ戻る
	pr.delete_save()
	pr.enabled = true
	main.room.apartment.cellar.stored.clear()
	# 壊れた保存は無視して、はじめから
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	f.store_string("{こわれた")
	f.close()
	main = await _fresh()
	check(main.inventory.is_empty() and not main.progress.discovered.has("stairs"), "壊れた保存は無視して、はじめからになる")
	main.progress.delete_save()
	main.progress.enabled = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save.json"))
	print("failures: %d" % failures)
	quit(1 if failures > 0 else 0)
