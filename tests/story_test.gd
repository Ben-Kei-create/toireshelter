extends SceneTree
## 物語の検証：こわいメモ 001〜010（欠けた文字）／日記 2 冊／独り言／オープニング。保存と復元も。
## 実行: Godot --headless --path . --script res://tests/story_test.gd

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
	var SD = main.StoryData
	_check(SD.MEMOS.size() == 10, "メモは 10 枚")
	var nums := []
	var chipped := true
	for id in SD.MEMOS:
		nums.append(SD.MEMOS[id][0])
		chipped = chipped and (SD.MEMOS[id][1] as String).contains("■")
	nums.sort()
	_check(nums == ["001", "002", "003", "004", "005", "006", "007", "008", "009", "010"], "番号は 001〜010")
	_check(chipped, "どのメモも、文字が欠けている")
	# 飾りを調べると、メモに気づく
	var area := Area3D.new()
	area.set_meta("interact_id", "teddy")
	main.add_child(area)
	main._on_interact_requested(area)
	await create_timer(0.4).timeout
	await process_frame
	_check(main.memos_found == ["teddy"] and main.progress.has_note("memo_001"), "ぬいぐるみを調べると、メモ 001 が見つかる")
	await create_timer(2.5).timeout
	_check(main.reading, "メモの読む画面が開く")
	main._close_reader()
	# 日記
	main._on_interact_requested(main.room.apartment.get_node("DiaryMine/DiaryArea"))
	_check(main.reading and main.progress.has_note("diary_mine"), "机の上の日記を読める（コタニ）")
	main._close_reader()
	_check(SD.MY_DIARY[0].contains("コタニ") and SD.GRANDMA_DIARY[2].contains("ここを出ていこう"), "日記の中身（コタニ／おばあちゃんが出ていく）")
	main._on_interact_requested(main.room.washitsu.get_node("Table/DiaryGrandma/DiaryArea"))
	_check(main.reading and main.progress.has_note("diary_grandma"), "おばあちゃんの日記を読める")
	main._close_reader()
	await process_frame
	_check(main.hud._message_label.text.contains("インターホン"), "読み終えると、独り言が出る")
	# 独り言
	main.muttered.clear()
	main._last_region = "bath"
	main.player.global_position = main.room.apartment.global_position + Vector3(1, 1, 0)
	main.play_time = 99999.0
	main._mutter_next = 0.0
	await process_frame
	await process_frame
	_check(main._mutter_idle_i >= 1, "しばらく探索すると、勝手に独り言が出る")
	# 保存と復元
	var snap: Dictionary = JSON.parse_string(JSON.stringify(main.progress.snapshot()))
	main = await _fresh()
	main.progress.apply(snap)
	_check(main.memos_found == ["teddy"] and main._mutter_idle_i >= 1, "復元しても、メモ・独り言の進みは同じ")
	# コタニの痕跡
	var kt: Node3D = main.room.apartment.get_node("KotaniTraces")
	for nm in ["Jacket/TraceArea", "Notebook/TraceArea", "Cup/TraceArea", "PillSheet/TraceArea"]:
		main._on_interact_requested(kt.get_node(nm))
	_check(main.progress.has_note("kotani_jacket") and main.progress.has_note("kotani_notebook") and main.progress.has_note("kotani_cup") and main.progress.has_note("kotani_pills"), "コタニの痕跡 4 つが、調べるとノートに残る")
	_check(main.muttered.has("kotani_more"), "3 つ見つけると、「もう一人いた」と独り言")
	# オープニング
	main = await _fresh()
	main._opening_event()
	await create_timer(0.5).timeout
	print("STORY TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
