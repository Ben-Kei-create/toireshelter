extends SceneTree
## 段階2の検証：十円玉→洗面台のふた→せっけん→おもり→浴槽のふた→お湯→玉が溶ける→ドライバー、
## 毛だまり、カーテンの数字、鏡文字のメモ、青い光。
## 実行: Godot --headless --path . --script res://tests/stage2_test.gd

var _failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(10)
	var main := current_scene
	var room = main.room
	var sink = room.sink
	var tub = room.bathtub
	var towel = room.towel

	_check(not sink.plug_in and tub.lid == "none" and not tub.plug_in, "洗面台も浴槽も、最初は栓がない")
	_check(not main.has_driver and room.driver_node == null, "ドライバーは床に落ちていない")
	# 十円玉
	var scratch: Node = towel.get_node("ScratchArea")
	main._on_interact_requested(scratch)
	_check(main.inventory.has("ten_yen") and not towel.has_coin, "タオルの裏の傷から十円玉を拾う")
	# 洗面台：ふた→水→せっけん（床で拾って、水に沈める）
	_check(sink.get_node("FloorSoap").visible and not sink.get_node("Sinker/SinkerArea").collision_layer, "せっけんは床に落ちている。おもりの判定はまだない")
	main._on_interact_requested(sink.get_node("FloorSoap/Pickup"))
	_check(main.inventory.has("soap") and main.selected_item() != "soap", "せっけんを拾う（拾っただけでは手に持たない）")
	_check(sink.place_soap() == "dry", "水がないと沈められない")
	sink.set_plug(true)
	main.remove_item("ten_yen")
	sink.faucet.set_on(true)
	sink.advance(sink.FILL_TIME)
	_check(sink.level > 0.9, "ふたをすると水が溜まる")
	sink.advance(sink.SOAP_TIME + 1.0)
	_check(not sink.soap_gone, "せっけんを入れる前は溶けない")
	_check(sink.place_soap() == "ok", "せっけんを水に入れる")
	main.remove_item("soap")
	sink.advance(sink.SOAP_TIME + 1.0)
	_check(sink.soap_gone and sink.get_node("Sinker").visible and sink.get_node("Sinker/SinkerArea").collision_layer != 0, "せっけんが溶けて、おもりが現れる（判定もできる）")
	main._on_interact_requested(sink.get_node("Sinker/SinkerArea"))
	_check(main.inventory.has("sinker"), "おもりを拾える")
	sink.faucet.set_on(false)
	main._on_interact_requested(sink.get_node("PlugArea"))
	_check(not sink.plug_in and main.inventory.has("ten_yen"), "十円玉を取り戻せる（水が抜ける）")
	# 浴槽：十円玉だけでは浮く
	_check(tub.put_lid(false) == "coin", "十円玉でふたをする")
	tub.faucet.set_on(true)
	tub.advance(tub.FILL_TIME)
	_check(tub.level <= tub.COIN_CAP + 0.001, "十円玉だけだと水位が上がらない")
	_check(tub.put_lid(true) == "full", "おもりを載せる")
	tub.advance(tub.FILL_TIME)
	_check(tub.level > 0.9, "おもりを載せると水が溜まる")
	tub.faucet.set_on(false)
	# 入浴剤の玉：水では溶けず、お湯で溶ける
	tub.level = 0.5
	tub.powder = 0.5
	tub.reserve_ball()
	tub.sink_ball()
	tub.advance(10.0)
	_check(tub.ball == "sunk", "水だけでは玉は溶けない")
	tub.start_reheat()
	tub.advance(tub.BALL_DISSOLVE + 0.5)
	_check(tub.ball == "gone" and tub.get_node("TubDriver").visible, "お湯（追い焚き）で玉が溶け、ドライバーが現れる")
	main._on_interact_requested(tub.get_node("TubDriver/Pickup"))
	_check(main.has_driver and main.inventory.has("driver"), "ドライバーを拾う")
	_check(tub.get_node("TubDriver/Pickup").collision_layer == 0, "拾ったあとは判定が消える")
	# 毛だまり
	main.has_lint = true
	tub.drop_lint()
	main._on_interact_requested(tub.get_node("Lint/Pickup"))
	_check(main.inventory.has("lint"), "毛だまりを拾う")
	# カーテンの数字：浴槽の中でシャワーを手に取り、視線の先（弧を描く水）を閉じたカーテンに当てる
	var cur = room.shower_curtain
	cur.toggle()
	await create_timer(0.7).timeout
	var cam: Camera3D = main.player.camera
	tub.hold_shower(cam)
	var from_p: Vector3 = tub.to_global(Vector3(0.0, 1.0, 0.0))
	var to_p: Vector3 = cur.to_global(Vector3(0.0, 1.3, cur.Z))
	main.player.global_position = from_p - Vector3(0, 1.0, 0)
	cam.global_position = from_p
	cam.look_at(to_p + Vector3(0, 0.15, 0))
	for i in 90:
		tub._update_held_shower(0.02)
	_check(cur.wet > 0.0 and cur.digits_seen, "手に持ったシャワーの水がカーテンに当たると、数字が浮かぶ")
	cam.look_at(from_p + Vector3(0, 0, -3.0))
	cur.wet = 0.0
	tub._update_held_shower(0.5)
	_check(cur.wet == 0.0, "別の方を向けていれば、カーテンは濡れない")
	tub.release_shower()
	_check(not tub.shower.is_on and not tub.shower_held, "シャワーを戻すと止まる")
	# 鏡文字のメモ
	main._on_interact_requested(room.get_node("MirrorPaper/Collision"))
	_check(main.inventory.has("paper"), "メモを拾う")
	# 青い光
	var keys := []
	for i in 4:
		room.set_bath_light(false)
		keys.append(room.set_bath_light(true))
	_check(room.bath_purple and keys[-1] == "bath_light_purple", "4回で青い光になる")
	for i in 4:
		room.set_bath_light(false)
		keys.append(room.set_bath_light(true))
	_check(not room.bath_purple and keys[-1] == "bath_light_normal", "さらに4回で白に戻る")
	# セーブの往復
	var snap: Dictionary = main.progress._stage2_snapshot()
	_check(snap.tub_lid == "full" and snap.ball == "gone" and snap.curtain_digits_seen, "セーブに段階2の状態が入る")
	print("STAGE2 TEST: ", "PASS" if _failures == 0 else "FAIL", " (", _failures, " failure(s))")
	quit(1 if _failures > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_failures += 1
