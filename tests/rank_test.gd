extends SceneTree
## 神の声にきく（回数制限）とクリアのランク（SSS S A+ A B+ B B- C F）の回帰テスト。
## 実行: Godot --headless --path . --script res://tests/rank_test.gd

const ProgressScript := preload("res://scripts/progress.gd")
var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var R := ProgressScript
	# ランク表：時間で決まり、ヒント 2 回ごとに 1 段下がる。SSS はヒントなしだけ
	_check(R.rank_for(60 * 60, 0) == "SSS", "60 分・ヒントなし → SSS")
	_check(R.rank_for(90 * 60, 0) == "SSS", "ちょうど 90 分 → SSS")
	_check(R.rank_for(100 * 60, 0) == "S", "100 分 → S")
	_check(R.rank_for(100 * 60, 1) == "S", "ヒント 1 回では下がらない")
	_check(R.rank_for(100 * 60, 2) == "A+", "ヒント 2 回で 1 段下がる → A+")
	_check(R.rank_for(100 * 60, 5) == "A", "ヒント 5 回で 2 段下がる → A")
	_check(R.rank_for(60 * 60, 1) == "S", "ヒントを使ったら、SSS にはならない → S")
	_check(R.rank_for(140 * 60, 0) == "A+", "140 分 → A+")
	_check(R.rank_for(170 * 60, 0) == "A", "170 分 → A")
	_check(R.rank_for(200 * 60, 0) == "B+", "200 分 → B+")
	_check(R.rank_for(230 * 60, 0) == "B", "230 分 → B")
	_check(R.rank_for(290 * 60, 0) == "B-", "290 分 → B-")
	_check(R.rank_for(350 * 60, 0) == "C", "350 分 → C")
	_check(R.rank_for(350 * 60, 2) == "F", "350 分・ヒント 2 回 → F")
	_check(R.rank_for(400 * 60, 0) == "F", "6 時間を超えたら F")
	_check(R.rank_for(400 * 60, 5) == "F", "F より下はない")

	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	var pr = main.progress
	var hud = main.hud
	_check(not pr.auto_idle, "自動の独り言は、ふだんオフ（ヒントは設定からきく）")
	_check(pr.hints_used == 0 and pr.hints_left() == pr.HINT_LIMIT, "はじめはのこり %d 回" % pr.HINT_LIMIT)

	pr.hints_on = false
	_check(pr.ask_hint() == "off" and pr.hints_used == 0, "神の声モードがオフなら、きけない")
	pr.hints_on = true
	_check(pr.ask_hint() == "ok" and pr.hints_used == 1, "きくとヒントが出て、1 回ぶん減る")
	_check(hud._message_label.text.begins_with("『"), "神の声の文で出る")
	var left0: int = pr.hints_left()
	# 出せるヒントがなくなると「焦らなくていい」（回数は減らない）
	for i in 12:
		pr.ask_hint()
	_check(pr.hints_used <= pr.HINT_LIMIT, "回数の上限を超えない（%d / %d）" % [pr.hints_used, pr.HINT_LIMIT])
	pr.hints_used = pr.HINT_LIMIT
	pr.hints_shown.clear()
	_check(pr.ask_hint() == "none", "回数がなくなると、きけない")
	_check(hud._message_label.text.find("教えられる") >= 0, "断る一言が出る")

	# 設定の表示
	main._pause()
	await process_frame
	_check(hud._hint_ask.disabled and hud._hint_ask.text.find("のこり 0 回") >= 0, "のこり 0 回の表示で、押せない")
	pr.hints_used = 1
	pr.hints_on = true
	hud.set_hint_ask_ui(pr.hints_left(), true, pr.HINT_LIMIT)
	_check(not hud._hint_ask.disabled and hud._hint_ask.text.find("のこり 4 回") >= 0, "のこり 4 回の表示で、押せる")
	hud.set_hint_ask_ui(pr.hints_left(), false, pr.HINT_LIMIT)
	_check(hud._hint_ask.disabled, "神の声モードがオフなら押せない")
	main._resume()

	# クリア画面
	pr.hints_used = 2
	main.play_time = 100 * 60.0
	main.credits_enabled = false
	main._clear("legit")
	await process_frame
	_check(hud._clear_rank.visible and hud._clear_rank.text == "ランク　A+", "クリア画面にランクが出る（%s）" % hud._clear_rank.text)
	_check(hud._clear_stats.text.find("神の声のヒント　2 / 5 回") >= 0, "ヒントの回数が出る")

	# 保存
	var snap: Dictionary = pr.snapshot()
	pr.hints_used = 0
	pr.apply(snap)
	_check(pr.hints_used == 2, "保存から、使ったヒントの回数が戻る")
	print("RANK TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
