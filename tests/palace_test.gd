extends SceneTree
## トイレ（宮殿風）：ひまわりの絵・ボタン・地図、シャンデリアの電球（外すと真っ暗）、金色の設備。
## 実行: Godot --headless --path . --script res://tests/palace_test.gd

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
	var pm = room.painting_map
	_check(pm != null and pm.get_node_or_null("Painting/PaintingArea") != null and pm.get_node_or_null("Button/ButtonArea") != null, "ひまわりの絵と、下のボタンがある")
	_check(pm.get_node("Painting/PaintingArea").collision_layer != 0 and pm.get_node("FloorMap/MapArea").collision_layer == 0, "はじめは絵が前にあり、地図は調べられない")
	main._on_interact_requested(pm.get_node("Button/ButtonArea"))
	await create_timer(1.2).timeout
	_check(pm.slid and pm.painting.position.y > 0.4 and pm.get_node("FloorMap/MapArea").collision_layer != 0, "ボタンを押すと、絵が上へスライドして、地図が出る")
	main._on_interact_requested(pm.get_node("FloorMap/MapArea"))
	_check(main.hud._message_label.text == main.STAGE5["floor_map_look"] and main.progress.has_note("floor_map"), "地図を調べると、5 階の地図（ノートに残る）")
	var texts := []
	for l in pm.find_children("*", "Label3D", true, false):
		texts.append((l as Label3D).text)
	_check(texts.has("501") and texts.has("503") and texts.has("505") and texts.has("いまここ") and texts.has("おばあちゃん"), "地図に、501〜505 と、いまここ・おばあちゃんがある")
	main._on_interact_requested(pm.get_node("Button/ButtonArea"))
	await create_timer(1.2).timeout
	_check(not pm.slid and pm.get_node("FloorMap/MapArea").collision_layer == 0, "もう一度押すと、絵がもどる")
	# シャンデリア
	var fx: Node3D = room.get_node("BathBulb")
	var span := 0.0
	for c in fx.get_children():
		if c is Node3D:
			span = maxf(span, absf((c as Node3D).position.x))
	_check(span > 0.6, "シャンデリアは、宮殿のように大きい（半径 %.2f m）" % span)
	var ry0: float = fx.rotation.y
	await create_timer(0.5).timeout
	_check(fx.rotation.y > ry0, "シャンデリアは、ゆっくり回る")
	_check(room.bath_light.light_energy > 0.4 and room.bulb_present, "電球がはまっていると、灯りがつく")
	main._on_interact_requested(room.bulb_area)
	_check(not room.bulb_present and main.inventory.has("chandelier_bulb") and room.bath_light.light_energy == 0.0, "電球を外せる。灯りが消える")
	room.update_bulb_darkness(true)
	_check(room.sky_clock.unit_dark < 0.05, "電球がないと、トイレの中は真っ暗（環境光が落ちる）")
	room.update_bulb_darkness(false)
	_check(room.sky_clock.unit_dark == 1.0, "トイレの外では、環境光は変わらない")
	var key: String = room.set_bath_light(false)
	key = room.set_bath_light(true)
	_check(key == "bath_light_nobulb" and room.bath_light.light_energy == 0.0, "電球がないと、スイッチを入れてもつかない")
	main.select_item(main.inventory.find("chandelier_bulb"))
	print("PALACE TEST: %s (%d failure(s))" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
