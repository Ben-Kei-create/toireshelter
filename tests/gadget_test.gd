extends SceneTree
## 玄関の三和土・トイレのカバーとスリッパ・温水洗浄の水・テレビ裏の配線・換気扇の「弱中狂」・コルク銃の射的・主人公の等身大パネルと鏡の顔の自動検証（ヘッドレス可）。
## 実行: Godot --headless --path . --script res://tests/gadget_test.gd
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
	var apt = main.room.apartment
	var player = main.player
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	# --- 玄関の三和土
	var tataki: Node3D = apt.get_node("HallTataki")
	var wood: Node3D = apt.get_node("HallFloor")
	check(absf(tataki.position.y + 0.1) < 0.001 and absf(wood.position.y + 0.05) < 0.001, "三和土は木の床より 5cm 低い")
	check((tataki as MeshInstance3D).get_active_material(0) != (wood as MeshInstance3D).get_active_material(0), "三和土は灰色のタイル、木の床とは色が違う")
	check(apt.get_node("Kamachi") != null and apt.get_node("KamachiNorth") != null, "境に上がり框（暗い木の段）がある")
	var ray_t := PhysicsRayQueryParameters3D.create(Vector3(-0.7, 1.0, 1.9), Vector3(-0.7, -0.5, 1.9), 1)
	var ray_w := PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.0, 1.9), Vector3(0.0, -0.5, 1.9), 1)
	check(absf(space.intersect_ray(ray_t).position.y + 0.05) < 0.002 and absf(space.intersect_ray(ray_w).position.y) < 0.002, "三和土の床は y -0.05、木の床は y 0")
	# 段を実際に歩いて越えられる（上りも下りも）
	player.global_position = Vector3(-0.2, 0.02, 1.9)
	player.rotation = Vector3(0, PI * 0.5, 0)   # -x へ
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.x < -0.6 and absf(player.global_position.y + 0.05) < 0.03, "木の床から三和土へ降りられる（x %.2f・y %.2f）" % [player.global_position.x, player.global_position.y])
	player.rotation = Vector3(0, -PI * 0.5, 0)   # +x へ
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.x > -0.3 and absf(player.global_position.y) < 0.03, "三和土から上がり框を上がれる（x %.2f・y %.2f）" % [player.global_position.x, player.global_position.y])
	var shoes: Node3D = apt.get_node("Shoes")
	check(absf(shoes.position.y + 0.05) < 0.001 and shoes.position.x < -0.45, "靴は三和土の上に脱いである")
	var slip: Node3D = apt.get_node("HallSlippers")
	check(slip.position.x > -0.45 and slip.position.y == 0.0, "スリッパは上がり框の上（木の床）にある")
	# --- トイレのカバーとスリッパ
	var t = main.room.toilet
	check(t.seat_pivot.find_child("SeatCover", true, false) != null and t.lid_pivot.find_child("LidCover", true, false) != null, "便座カバーと蓋カバーがある（便座・蓋について動く）")
	var bs: Node3D = main.room.get_node("BathWear/BathSlippers")
	check(bs.find_children("*", "Label3D", true, false).size() == 2 and bs.get_node("SlippersArea").get_meta("interact_id") == "toilet_slippers" and main.MESSAGES.has("toilet_slippers"), "トイレ用のスリッパ（「WC」の文字つき・調べられる）")
	# --- 温水洗浄の水
	var panel = main.room.toilet_panel
	check(not t.get_node("Spray_rear").visible and not t.get_node("Spray_bidet").visible and not t.get_node("SpraySound").playing, "ふだんは水は出ていない")
	t.occupied = true   # 着座中だけ作動する
	panel.interact("washlet_rear")
	await process_frame
	check(t.spray_mode == "rear" and t.get_node("Spray_rear").visible and not t.get_node("Spray_bidet").visible and t.get_node("SpraySound").playing, "おしり：後ろへ広がる水が出て、水の音が鳴る")
	check(t.get_node("Spray_rear").get_child_count() == 5, "おしりの水は5本の筋")
	panel.interact("washlet_bidet")
	await process_frame
	check(t.spray_mode == "bidet" and t.get_node("Spray_bidet").visible and not t.get_node("Spray_rear").visible and t.get_node("Spray_bidet").get_child_count() == 3, "ビデ：前へ細く出る（3本）")
	panel.stop()
	await process_frame
	check(t.spray_mode == "" and not t.get_node("Spray_bidet").visible and not t.get_node("SpraySound").playing, "止める／立つと水は止まる")
	# --- テレビ裏の配線
	var cab: Node3D = apt.get_node("TvCorner/TvCables")
	check(cab.get_child_count() >= 10 and cab.get_node("PowerStrip") != null, "テレビの裏に細いケーブルが何本もからまっている（電源タップつき）")
	check(cab.find_children("*", "CollisionObject3D", true, false).is_empty(), "配線は体を止めない（当たり判定なし）")
	# --- 換気扇「弱・中・狂」
	var k = apt.kitchen
	check(k.hood_level == 0 and not k._hood_sound.playing, "換気扇は最初止まっている")
	check(main.PROMPTS[k.get_prompt("hood_2")] == "左クリック：換気扇のボタン", "案内")
	var keys := [k.interact("hood_1"), k.interact("hood_2"), k.interact("hood_3")]
	check(keys == ["hood_1", "hood_2", "hood_3"] and k.hood_level == 3, "弱・中・狂 を順に押せる")
	var vol := [0.0, 0.0, 0.0]
	k.interact("hood_1")
	vol[0] = k._hood_sound.volume_db
	k.interact("hood_2")
	vol[1] = k._hood_sound.volume_db
	k.interact("hood_3")
	vol[2] = k._hood_sound.volume_db
	check(vol[0] < vol[1] and vol[1] < vol[2] and k._hood_sound.playing and k._hood_sound.pitch_scale > 1.5, "弱＜中＜狂 の順に音が大きくなり、狂は高く激しい")
	var rot0: float = k._hood_fan.rotation.y
	k._hood_step(0.1)
	var rot_kyo: float = absf(k._hood_fan.rotation.y - rot0)
	k.interact("hood_1")
	rot0 = k._hood_fan.rotation.y
	k._hood_step(0.1)
	check(rot_kyo > absf(k._hood_fan.rotation.y - rot0) * 3.0, "狂は羽が速く回る")
	k.interact("hood_3")
	var shaking := false
	for i in 20:
		k._hood_step(0.016)
		shaking = shaking or k._hood.position.distance_to(k._hood_base) > 0.0005
	check(shaking and k._hood_lamp_mat.emission_energy_multiplier > 0.4, "狂：フードが震え、ランプが点滅する")
	check(k.interact("hood_3") == "hood_off" and k.hood_level == 0 and not k._hood_sound.playing and k._hood.position.is_equal_approx(k._hood_base), "同じボタンをもう一度押すと止まる（震えも止まる）")
	for key in ["hood_1", "hood_2", "hood_3", "hood_off"]:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	# --- コルク銃と射的
	var gun_area: Area3D = k.gun_area
	check(gun_area.get_meta("interact_id") == "cork_gun" and k.cork_gun.position.y > 1.7 and k.cork_gun.position.z - 0.235 < 1.78, "細長いピストルが冷蔵庫の上にあり、銃口が縁から少しはみ出している")
	check(main._prompt_for(gun_area) == main.PROMPT_PICKUP, "拾える案内")
	check(main.hud._slot_labels.size() == 8, "持ち物欄は8つ（1〜8 キー）")
	var tgt: Array = apt.figures
	check(tgt.size() == 40, "棚のフィギュア 40 体が的になる")
	main._on_interact_requested(apt.figures[0].node.get_node("FigureArea"))
	check(main.hud._message_label.text.contains("撃ち落とせ"), "銃がないと、フィギュアは調べるだけ")
	main._on_interact_requested(gun_area)
	check(main.inventory.has("cork_gun") and not k.cork_gun.visible and gun_area.collision_layer == 0 and main._item_models.has("cork_gun"), "拾うと持ち物に入る")
	main.select_item(main.inventory.find("cork_gun"))
	check(main._use_prompt(null) == "F：コルク銃を撃つ", "F で撃つ案内")
	var fig: Node3D = apt.figures[2].node
	var fig_y: float = fig.position.y
	player.global_position = Vector3(1.4, 0.0, -0.4)
	main._gun_cool = 0.0
	main._on_interact_requested(fig.get_node("FigureArea"))   # 銃を持って、フィギュアをクリック
	check(apt.figures[2].down and apt.figures_down == 1 and main.hud._message_label.text.contains("1 個目"), "撃つとフィギュアが落ちる（1個目）")
	await create_timer(1.2).timeout
	check(fig.position.y < fig_y - 0.2, "落ちたフィギュアは棚より下に落ち着く（y %.2f → %.2f）" % [fig_y, fig.position.y])
	check(fig.get_node("FigureArea").collision_layer == 0, "落ちたフィギュアはもう狙えない")
	main._gun_cool = 0.0
	main._fire(fig.get_node("FigureArea"))
	check(apt.figures_down == 1, "同じフィギュアは二度は落ちない")
	main._gun_cool = 0.0
	main._fire(null)
	check(main.hud._message_label.text.contains("はね返った"), "外れるとコルクが飛んでいくだけ")
	main._gun_cool = 0.0
	var f2: Node3D = apt.figures[30].node
	var y2: float = f2.position.y
	main._fire(f2.get_node("FigureArea"))
	await create_timer(1.2).timeout
	check(apt.figures_down == 2 and f2.position.y < y2 - 0.3 and f2.position.y > -0.02, "手前の壁（寝床の上）のフィギュアも落ちる（寝床の上に落ち着く y %.2f）" % f2.position.y)
	for key in ["cork_gun", "figure"]:
		check(main.MESSAGES.has(key), "%s の文章" % key)
	# --- 主人公の等身大パネルと鏡の顔
	var CH := preload("res://scripts/character.gd")
	for n in ["body_front", "body_three_quarter", "body_side", "body_back_three_quarter", "body_back", "head_front", "head_three_quarter", "head_side"]:
		var img := CH.tex(n).get_image()
		check(img.get_pixel(1, 1).a < 0.05 and img.get_pixel(img.get_width() / 2, img.get_height() / 2).a > 0.9, "%s は背景が透明に切り抜かれている" % n)
	check(CH.head_view(0.0)[0] == "head_front" and CH.head_view(30.0)[0] == "head_three_quarter" and CH.head_view(-70.0)[0] == "head_side" and CH.head_view(-70.0)[1] == true, "見る角度で顔の向きが変わる（正面・斜め・横）")
	check(CH.body_view(0.0)[0] == "body_front" and CH.body_view(90.0)[0] == "body_side" and CH.body_view(180.0)[0] == "body_back", "全身も角度で変わる")
	var st: Node3D = apt.standee
	check(st.get_node("Front") != null and st.get_node("Back") != null and st.get_node("Collision").get_meta("interact_id") == "standee" and main.MESSAGES.has("standee"), "等身大パネル（表と裏・当たり判定・調べる）")
	check(not player.is_space_free(Vector3(3.8, 0.0, 2.08), 1.6), "パネルは体を止める")
	var mc = main.room.mirror_cabinet
	check(mc.reflection != null and mc.reflection.get_parent() == mc.door_pivot, "鏡に顔が映る（扉についている）")
	var cam: Camera3D = player.camera
	player.set_physics_process(false)
	player.global_position = Vector3(0.2, 0.0, 0.1)
	player.rotation = Vector3(0, PI * 0.5, 0)
	await process_frame
	await process_frame
	check(mc.reflection_view == "head_front" and mc.reflection.material_override.albedo_color.a > 0.5, "鏡の正面に立つと正面の顔が映る")
	player.global_position = Vector3(0.0, 0.0, 0.9)   # 鏡の横の離れた位置（斜めから）
	await process_frame
	await process_frame
	check(mc.reflection_view != "head_front", "斜めから見ると顔の向きが変わる（%s）" % mc.reflection_view)
	player.global_position = Vector3(0.2, 0.0, 2.0)   # 鏡の真横を外れる
	await process_frame
	await process_frame
	check(mc.reflection.material_override.albedo_color.a < 0.3, "鏡から大きく外れると映らない")
	check(main.hud.get_node("Root/PauseMenu/Portrait") != null, "設定画面に主人公の肖像がある")
	# --- 自分の目から見える体（ちょー雑な3D）
	var rig: Node3D = player.body_rig
	player.set_physics_process(true)
	player.pose = player.Pose.WALK
	await process_frame
	check(rig != null and rig.visible and rig.get_meta("legs").size() == 2 and rig.get_meta("arms").size() == 2, "歩く姿勢では体（胴・脚・腕）が見える")
	check(rig.find_children("*", "CollisionObject3D", true, false).is_empty(), "体に当たり判定はない")
	var shoe_y: float = rig.get_node("LegL/Shoe").global_position.y
	check(shoe_y < 0.1 and rig.get_node("Chest").global_position.y < player.camera.global_position.y, "革靴は足元に、胸は目より下にある")
	var c: Camera3D = player.camera
	var chest_pos: Vector3 = c.to_local(rig.get_node("Chest").global_position)
	check(chest_pos.z < 0.2 and chest_pos.z > -0.3 and chest_pos.y < -0.1, "胸は目のすぐ下にある（真下を向くと見える：奥行き %.2f・高さ %.2f）" % [chest_pos.z, chest_pos.y])
	player.pose = player.Pose.CROUCH
	await process_frame
	check(rig.visible and rig.scale.y < 0.5, "しゃがむと体が縮む")
	for pz in [player.Pose.SEATED, player.Pose.IN_TUB, player.Pose.KOTATSU_SEAT, player.Pose.KOTATSU_IN, player.Pose.DUCT]:
		player.pose = pz
		await process_frame
		check(not rig.visible, "座る・浴槽・こたつ・ダクトの姿勢では体を隠す（%d）" % pz)
	player.pose = player.Pose.WALK
	var CB := preload("res://scripts/character_body.gd")
	CB.animate(rig, 1.0, PI * 0.5)
	check(absf(rig.get_node("LegL").rotation.x + rig.get_node("LegR").rotation.x) < 0.001 and absf(rig.get_node("LegL").rotation.x) > 0.3, "歩くと左右の脚が逆に振れる")
	CB.animate(rig, 0.0, 1.0)
	check(absf(rig.get_node("LegL").rotation.x) < 0.001, "止まると脚は振れない")
	print("gadget_test: ", "OK" if failures == 0 else "%d FAILED" % failures)
	quit(1 if failures > 0 else 0)
