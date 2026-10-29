extends SceneTree
## 推理ノートの確認画像。実行: SHOT_DIR=保存先 xvfb-run -a Godot --path . --script res://tests/capture_notebook.gd
func _initialize() -> void:
	_run()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var m := current_scene
	m.progress.add_note("tub_note", "浴槽の紙", "『ここまで来たか。』")
	m.progress.add_note("shelf_note", "棚の裏の紙", "『下からなら見える。』")
	m.progress.add_note("pw1", "カーテンの数字", "うっすらと 4 7 2 1", "パスワード")
	m.progress.set_chapter(1)
	m.hud.toggle_notebook(m.progress.chapter_lines(), m.progress.notes_text())
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("notebook.png"))
	quit()
