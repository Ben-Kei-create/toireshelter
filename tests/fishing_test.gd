extends SceneTree
## ベランダの釣り（釣り竿・釣り場・釣れる物・釣果・4つ目の持ち物欄）の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/fishing_test.gd
var failures := 0


func check(ok: bool, label: String) -> void:
	print("  %s   %s" % ["OK" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	var main := current_scene
	var f = main.fishing
	var player = main.player
	var F := preload("res://scripts/fishing.gd")
	# --- 釣り竿
	var rod_area: Area3D = f.get_node("RodProp/RodArea")
	check(rod_area.get_meta("interact_id") == "fishing_rod" and f.get_node("RodProp").global_position.x > 3.55, "釣り竿は室外機のうしろ（隔て板ぎわ）に立てかけてある")
	var unit: Node3D = main.get_node("Room").find_child("AirConUnit", true, false)
	check(unit != null and absf(f.get_node("RodProp").global_position.x - unit.global_position.x) < 0.4 and f.get_node("RodProp").global_position.x > unit.global_position.x, "室外機のすぐ東（後ろ側）にある")
	check(main.PROMPT_PICKUP == main._prompt_for(rod_area), "拾える案内が出る")
	check(F.CATCHES.size() == 28 and main.ITEMS.has("fishing_rod"), "釣れる物は 28 種類。釣り竿は持ち物")
	# 竿を拾う前は釣れない
	var spot: Area3D = f.get_node("SpotArea")
	check(main.PROMPTS[f.get_prompt("fish_spot")] == "左クリック：調べる" and f.interact("fish_spot") == "fish_need_rod" and f.state == "idle", "竿がないうちは手すりを調べるだけ")
	main._on_interact_requested(rod_area)
	check(main.inventory.has("fishing_rod") and f.has_rod and not f.get_node("RodProp").visible and rod_area.collision_layer == 0, "拾うと持ち物に入り、ベランダの竿は消える")
	check(main.inventory.size() == 1 and main.hud._slot_labels.size() == 6, "持ち物欄は6つ")
	# 4つ持てる
	main.add_item("driver")
	main.add_item("spare_roll")
	main.add_item("bath_powder")
	check(main.inventory.size() == 4 and main.hud._slot_labels[3].text.contains("ユブロマン"), "4つ持てる")
	main.remove_item("driver")
	main.remove_item("spare_roll")
	main.remove_item("bath_powder")
	check(main._item_models.has("fishing_rod"), "釣り竿の拡大モデルがある")
	# --- 釣り
	player.global_position = Vector3(2.5, 0, -1.9)
	check(main.PROMPTS[f.get_prompt("fish_spot")] == "左クリック：釣り糸を垂らす", "竿を持つと「釣り糸を垂らす」")
	check(f.interact("fish_spot") == "fish_cast_msg" and f.state == "waiting" and f._line.visible and f._bobber.visible, "糸を垂らす（糸と浮きが見える）")
	await create_timer(1.4).timeout
	check(f._line_len > 7.0, "糸は路地の地面近くまで伸びる（%.1f m）" % f._line_len)
	check(f.interact("fish_spot") == "fish_early" and f.state == "idle" and not f._line.visible, "早く引き上げると、何も釣れず戻る")
	f.interact("fish_spot")
	check(f._wait >= 2.4 and f._wait <= 6.1, "待ち時間は 2.5〜6 秒（%.1f 秒）" % f._wait)
	f._wait = 0.0
	await process_frame
	await process_frame
	check(f.state == "bite" and main.PROMPTS[f.get_prompt("fish_spot")] == "左クリック：引き上げる！", "浮きが跳ねたら「引き上げる！」")
	var key: String = f.interact("fish_spot")
	check(key == "fishing_text" and f.state == "reeling" and f.caught.size() == 1, "引き上げると何か釣れる")
	var txt: String = f.format_message(key, main.MESSAGES[key])
	check(txt.contains("釣り上げた") and txt.contains("釣果：1 / 28") and txt.contains("（はじめて）"), "文章に名前と説明と釣果が出る")
	await create_timer(1.6).timeout
	check(f.state == "idle" and not f._line.visible, "引き上げが終わると、また釣れる状態")
	check(main.hud._catch_label.text.begins_with("釣果：1 / 28"), "設定画面の釣果が更新される")
	# 逃げられる
	f.interact("fish_spot")
	f._wait = 0.0
	await process_frame
	await process_frame
	f._wait = 0.0
	await process_frame
	check(f.state == "idle" and not f._line.visible, "4 秒のうちに引き上げないと逃げられる")
	# 歩き去ると自動でやめる
	f.interact("fish_spot")
	player.global_position = Vector3(1.5, 0, -1.9)
	player.global_position.x = f._cast_x + 3.0
	await process_frame
	await process_frame
	check(f.state == "idle", "釣り場から離れると糸を上げる")
	# --- 釣れる物の分布
	var rng := RandomNumberGenerator.new()
	var kinds := {"ゴミ": 0, "お宝": 0, "アイテム": 0}
	var seen := {}
	for i in 3000:
		var p: Array = f._pick()
		kinds[p[0]] += 1
		seen[p[1]] = true
	check(kinds["ゴミ"] > kinds["アイテム"] and kinds["アイテム"] > kinds["お宝"] and kinds["お宝"] > 200, "ゴミが多く、アイテム、お宝の順に少ない（%s）" % str(kinds))
	check(seen.size() == 28, "28 種類ぜんぶ釣れる（%d）" % seen.size())
	var kinds_ok := true
	for c in F.CATCHES:
		kinds_ok = kinds_ok and c[0] in ["ゴミ", "お宝", "アイテム"] and String(c[2]).length() > 5 and int(c[3]) > 0
	check(kinds_ok, "どの釣れる物にも種類・説明・重みがある")
	var treasure := F.CATCHES.filter(func(c): return c[0] == "お宝").size()
	var junk := F.CATCHES.filter(func(c): return c[0] == "ゴミ").size()
	check(junk == 12 and treasure == 7 and F.CATCHES.size() - junk - treasure == 9, "ゴミ12・お宝7・アイテム9")
	print("fishing_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
