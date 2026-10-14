extends SceneTree
## 設定を開いている間は、セリフ・案内・知らせ・持ち物欄を隠し、閉じると戻す。神の声の音が登録されている。
## 実行: Godot --headless --path . --script res://tests/pause_overlay_test.gd

const SfxClass := preload("res://scripts/sfx.gd")
var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 6:
		await process_frame
	var main = current_scene
	var hud = main.hud
	hud.show_message("テストのセリフ", 30.0)
	hud.show_discovery("テスト", 1, 22)
	hud.set_prompt("テストの案内")
	hud.set_carry("運んでいる：テスト")
	await process_frame
	var panels := {"セリフ": hud._message_panel, "案内": hud._prompt_panel, "発見の知らせ": hud._disc_panel, "運んでいる": hud._carry_label, "操作の案内": hud._hint_label, "持ち物欄": hud._inventory_bar}
	for k in panels:
		if k == "案内" or k == "運んでいる":
			continue   # この 2 つは main が毎フレーム書き換える（テストでは見えない）
		_check(panels[k].visible, "設定の前は「%s」が見えている" % k)
	main._pause()
	await process_frame
	for k in panels:
		_check(not panels[k].visible, "設定の間は「%s」が隠れる" % k)
	main._resume()
	await process_frame
	_check(hud._message_panel.visible and hud._hint_label.visible and hud._inventory_bar.visible, "閉じると、セリフ・案内・持ち物欄が戻る")
	# 神の声の音
	_check(SfxClass.NAMES.has("voice"), "神の声の音が登録されている")
	var sfx = main.get_node("Sfx")
	var st: AudioStreamWAV = sfx._streams.get("voice")
	_check(st != null and st.data.size() > 22050 * 2, "神の声の音の波形がある（%d バイト）" % (st.data.size() if st else 0))
	# ラジオの謎の声とは別の波形
	_check(SfxClass.stream_for("voice") != null, "音の名前から取れる")
	print("PAUSE OVERLAY TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
