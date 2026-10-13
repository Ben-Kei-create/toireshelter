extends SceneTree
## 自分の視点の体（ちょー雑な3D）の確認画像。SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_body.gd
var main
var p


func _initialize() -> void:
	_run()


func _shot(name: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	main = current_scene
	main.hud._message_panel.visible = false
	p = main.player
	p.set_physics_process(false)
	p.global_position = Vector3(2.0, 0.0, 1.0)
	p.rotation = Vector3.ZERO
	for pitch in [-85.0, -60.0, -35.0]:
		p.camera.rotation.x = deg_to_rad(pitch)
		await _shot("body_pitch_%d" % int(-pitch))
	quit()
