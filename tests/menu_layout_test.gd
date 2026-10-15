extends SceneTree
## 一時停止・クリアメニューの配置の回帰テスト。
## 実行: Godot --path . --script res://tests/menu_layout_test.gd（--headless でも可）
## 複数のウィンドウサイズで、背景がビューポート全体に一致し、ボタンが画面内に収まることを確認する。

const SIZES := [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1920, 800), Vector2i(800, 1000)]

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(5)
	var hud = current_scene.hud
	var menus := {"設定": hud._pause_menu, "クリア": hud._clear_menu}

	for win_size in SIZES:
		root.size = win_size
		await _frames(3)
		var view: Rect2 = root.get_visible_rect()
		print("ウィンドウ %s → ビューポート %s" % [win_size, view.size])
		_check(Vector2i(root.size) == win_size, "  ウィンドウサイズが %s になっている" % win_size)
		for menu_name in menus:
			var menu: Control = menus[menu_name]
			hud._pause_menu.visible = menu == hud._pause_menu
			hud._clear_menu.visible = menu == hud._clear_menu
			await _frames(2)
			var rect := menu.get_global_rect()
			_check(rect.position.is_equal_approx(view.position) and rect.size.is_equal_approx(view.size),
					"  %s：背景 %s がビューポート全体と一致" % [menu_name, rect])
			var buttons := 0
			for button in menu.find_children("*", "Button", true, false):
				if button is CheckButton or button.name == "HintAskButton" or button.name == "AdvancedButton":
					continue   # 設定の「オン／オフ」と「神の声にきく」（スクロールの中）は数えない
				buttons += 1
				var b: Rect2 = (button as Control).get_global_rect()
				_check(view.encloses(b) and b.size.x > 0.0 and b.size.y > 0.0,
						"  %s：ボタン「%s」%s が画面内" % [menu_name, button.text, b])
			var expect := 3 if menu == hud._pause_menu else 2   # 設定は「再開」「はじめから」「終了」
			_check(buttons == expect, "  %s：ボタンが%dつある" % [menu_name, expect])

	hud._pause_menu.visible = false
	hud._clear_menu.visible = false
	print("MENU LAYOUT TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame
