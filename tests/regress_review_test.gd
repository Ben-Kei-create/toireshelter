extends SceneTree
## レビュー指摘の回帰：報酬の取引中は保存を後回し（購入・メダル交換・クレーン）／取引中は置けない／所持品 9 個以上の表示／ノートのスクロールと移動停止。
## 実行: Godot --headless --path . --script res://tests/regress_review_test.gd

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


func _run() -> void:
	var main = await _fresh()
	var room = main.room
	# ---- 購入：演出中は保存が後回しで、置けない
	main.give_yen100()
	main.player.set_eye_height(1.6)
	main.select_item(main.inventory.find("yen100"))
	main._use_vending()
	_check(main.txn == 1 and main.inventory.has("yen100"), "購入の演出中は、取引中で、百円玉は手元にある")
	main.progress.save()
	_check(main.progress.save_deferred, "演出中の保存は、後回しになる（途中の状態が保存されない）")
	main._drop_selected()
	_check(main.placed_items.is_empty() and main.inventory.has("yen100"), "演出中は、Gで百円玉を置けない")
	main = await _fresh()   # 購入の演出は、そのまま続けない（新しく始める）
	room = main.room
	# ---- メダル交換：交換が終わるまで、メダルは手元に残る
	main.add_item("medal")
	main.room.set_power(true)
	main._use_medal("ufo_catcher")
	_check(main.txn == 1 and main.inventory.has("medal"), "メダル交換中は、取引中で、メダルが残る")
	await create_timer(0.4).timeout
	_check(main.txn == 0 and not main.inventory.has("medal"), "交換が終わると、メダルが百円玉に変わり、取引が終わる")
	# ---- クレーン：景品が持ち物に入るまで、取引中
	main.coin_count = 1
	main.add_item("ufo_coin")
	var ufo = room.apartment.ufo_catcher
	ufo.interact("ufo_catcher")
	_check(main.txn == 1, "クレーンのプレイ中は、取引中")
	var guard := 0
	while (main.txn > 0 or ufo.busy) and guard < 900:
		await physics_frame
		guard += 1
		if main.txn > 0 and not ufo.busy and not main._prize_pending:
			await process_frame
	_check(main.txn == 0 and main.inventory.has("flashlight") and ufo.taken == 1, "景品が持ち物に入ってから、取引が終わる（景品を受け取れる）")
	# ---- 所持品 9 個
	var ids := ["magnifier", "earplugs", "home_key", "lighter", "flashlight", "hand_mirror", "crystal", "pickaxe", "tp_core"]
	main.inventory.clear()
	for id in ids:
		main.inventory.append(id)
		main.items_found[id] = true
	main.select_item(8)
	_check(main.hud.inv_off == 1 and main.hud._slot_labels[7].text.contains("9  "), "9 個目を選ぶと、所持品欄が一つずれて、選んだ物が見える（%s）" % main.hud._slot_labels[7].text)
	main.select_item(0)
	_check(main.hud.inv_off == 0, "最初の物を選ぶと、元に戻る")
	# ---- ノート：スクロールと移動停止
	for i in 40:
		main.progress.add_note("n%d" % i, "メモ%d" % i, "手がかりの長い文章 %d：あいうえおかきくけこさしすせそたちつてと" % i, "手がかり")
	var ev := InputEventAction.new()
	ev.action = "notebook"
	ev.pressed = true
	main._unhandled_input(ev)
	await process_frame
	await process_frame
	_check(main.hud.is_notebook_open() and not main.player.controls_enabled, "ノートを開いている間は、体が動かない")
	_check(main.hud.notebook_scroll_max() > 200, "ノートは、長い記録がスクロールできる（余り %d px）" % main.hud.notebook_scroll_max())
	main.hud.notebook_scroll(100000.0)
	await process_frame
	_check(main.hud._notebook_scroll.scroll_vertical > 200, "いちばん下（新しい記録）まで進める")
	main.hud.notebook_scroll(-100000.0)
	await process_frame
	_check(main.hud._notebook_scroll.scroll_vertical == 0, "いちばん上（古い記録）へ戻れる")
	main._unhandled_input(ev)
	_check(not main.hud.is_notebook_open() and main.player.controls_enabled, "閉じると、また動ける")
	print("REGRESS REVIEW TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
