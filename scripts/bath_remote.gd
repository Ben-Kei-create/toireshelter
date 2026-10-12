extends Node3D
## 給湯器の浴室リモコン（TASK-11）。浴槽の右横の壁（x=0.9）に埋め込み風に付ける。表示とボタンの文字は Godot の UI で描く。
## ボタン：運転／ふろ自動／追い焚き／停止。温度表示は 40℃ 固定（上げ下げなし）。
##   運転      … 電源の入／切。切ると自動運転と追い焚きも止まる
##   ふろ自動  … 運転中・栓が閉じていれば、循環口から設定水位（浴槽の AUTO_LEVEL）まで給水して止まる
##   追い焚き  … 運転中・水が REHEAT_MIN_LEVEL 以上あれば、作動表示と水面の演出（熱の計算はしない）
##   停止      … ふろ自動と追い焚きを止める
## この節点はパネルの中心（壁面）に置き、ローカル +z が部屋側。ボタンごとに照準の判定（Area3D）を持つ。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const UIPanel := preload("res://scripts/ui_panel.gd")

const SIZE := Vector2(0.18, 0.12)
const PX := Vector2i(360, 240)
const BUTTONS := ["remote_power", "remote_auto", "remote_reheat", "remote_stop"]
const LABELS := ["運転", "ふろ自動", "追い焚き", "停止"]

var bathtub: Node3D
var power := false

var _display: Label
var _status: Label
var _lamps: Array[Panel] = []
var _screen: Panel


func setup(tub: Node3D) -> void:
	bathtub = tub


func _ready() -> void:
	# 本体（壁から少し出た薄い箱）と、表面の UI
	MeshKit.box(self, Vector3(SIZE.x + 0.016, SIZE.y + 0.016, 0.012), Vector3(0, 0, 0.006), MeshKit.mat("remote_body", Color(0.92, 0.92, 0.9), 0.4), "Body")
	var made := UIPanel.make(self, "Face", PX, SIZE)
	var root: Control = made[1]
	var face: MeshInstance3D = made[2]
	face.position = Vector3(0, 0, 0.0125)
	UIPanel.rect(root, Vector2.ZERO, Vector2(PX), Color(0.93, 0.93, 0.91), 0)
	_screen = UIPanel.rect(root, Vector2(20, 14), Vector2(320, 96), Color(0.2, 0.24, 0.2), 6)
	_display = UIPanel.label(root, "", Vector2(30, 14), Vector2(170, 96), 56, Color(0.65, 0.95, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	_status = UIPanel.label(root, "", Vector2(180, 14), Vector2(150, 96), 22, Color(0.65, 0.95, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	var bw := 78
	for i in 4:
		var x := 14 + i * (bw + 8)
		UIPanel.rect(root, Vector2(x, 126), Vector2(bw, 100), Color(0.78, 0.8, 0.82), 8)
		_lamps.append(UIPanel.rect(root, Vector2(x + bw * 0.5 - 8, 136), Vector2(16, 8), Color(0.4, 0.4, 0.4), 3))
		UIPanel.label(root, LABELS[i], Vector2(x, 150), Vector2(bw, 70), 20 if LABELS[i].length() <= 2 else 17, Color(0.12, 0.12, 0.14))
		# 照準の判定（ボタンの位置に合わせた薄い箱）
		var center_px := Vector2(x + bw * 0.5, 176)
		var local := Vector3((center_px.x / PX.x - 0.5) * SIZE.x, (0.5 - center_px.y / PX.y) * SIZE.y, 0.016)
		var area := MeshKit.interact_area(self, "Button%d" % i, BUTTONS[i], self)
		MeshKit.shape_box(area, Vector3(SIZE.x * bw / PX.x, SIZE.y * 100.0 / PX.y, 0.01), local)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if bathtub == null or _display == null:
		return
	UIPanel.set_rect_color(_screen, Color(0.2, 0.24, 0.2) if power else Color(0.12, 0.13, 0.12))
	_display.text = "40℃" if power else ""
	var status := ""
	if power:
		if bathtub.reheating:
			status = "追い焚き中"
		elif bathtub.auto_filling:
			status = "お湯はり中"
		elif bathtub.auto_done:
			status = "お湯はり完了"
		else:
			status = "運転中"
	_status.text = status
	var on := [power, power and bathtub.auto_filling, power and bathtub.reheating, false]
	for i in 4:
		UIPanel.set_rect_color(_lamps[i], Color(0.3, 0.95, 0.4) if on[i] and i == 0 else (Color(1.0, 0.6, 0.15) if on[i] else Color(0.4, 0.4, 0.4)))


func status_text() -> String:
	return _status.text


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	return id   # main.gd の PROMPTS に "remote_power" などがある


## 押したボタンの動作。結果の説明文のキーを返す（なければ空）。
func interact(id: String) -> String:
	match id:
		"remote_power":
			power = not power
			if not power:
				bathtub.stop_remote()
		"remote_auto":
			if not power:
				return "remote_off"
			match bathtub.start_auto():
				"plug_open":
					return "remote_plug_open"
				"full":
					return "remote_already_full"
		"remote_reheat":
			if not power:
				return "remote_off"
			if bathtub.start_reheat() == "low":
				return "remote_need_water"
		"remote_stop":
			bathtub.stop_remote()
	_refresh()
	return ""
