extends Node3D
## トイレの操作パネル（TASK-11）。便座の左横（座った本人から見て左下。-z 側、浴槽との間）に付けた袖型のパネル。
## ボタン：おしり／ビデ／止。選択中のランプと「作動中」の表示。身体の描写はしない。
## 着座中だけ作動する。立つと自動で止まる（main.gd が stop() を呼ぶ）。一時停止中と移動演出中は操作できない（main.gd 側）。
## この節点は便器の座る位置の左（部屋の座標）に置き、上面を少し手前（+x）に傾ける。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const UIPanel := preload("res://scripts/ui_panel.gd")

const SIZE := Vector2(0.15, 0.06)   # 上面（横 0.15 は部屋の x＝前後、縦 0.06 は z＝左右）
const PX := Vector2i(300, 120)
const BUTTONS := ["washlet_rear", "washlet_bidet", "washlet_stop"]
const LABELS := ["おしり", "ビデ", "止"]

var toilet: Node3D
var mode := ""   # "" / "rear" / "bidet"

var _lamps: Array[Panel] = []
var _status: Label
var _t := 0.0


func setup(t: Node3D) -> void:
	toilet = t


func _ready() -> void:
	# 箱（便座の横に張り出した袖）。上面にパネル
	var white := MeshKit.mat("seat", Color(0.96, 0.96, 0.95), 0.4)
	MeshKit.box(self, Vector3(SIZE.x + 0.02, 0.05, SIZE.y + 0.02), Vector3(0, -0.025, 0), white, "Body")
	# 便器の本体の横（z=-0.18）へつなぐ金具
	MeshKit.box(self, Vector3(0.05, 0.03, 0.03), Vector3(-0.04, -0.035, 0.035), white, "Bracket")   # z -0.21〜-0.18（便器の側面に接する）
	var face_root := Node3D.new()
	face_root.name = "Top"
	face_root.position = Vector3(0, 0.0015, 0)
	# 上を向いた平面。座って左を見下ろしたとき読めるよう、UI の右を前（+x）、UI の上を外側（-z）にそろえる
	face_root.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	add_child(face_root)
	var made := UIPanel.make(face_root, "Face", PX, Vector2(SIZE.x, SIZE.y))
	var root: Control = made[1]
	UIPanel.rect(root, Vector2.ZERO, Vector2(PX), Color(0.93, 0.93, 0.92), 0)
	_status = UIPanel.label(root, "", Vector2(8, 2), Vector2(284, 28), 18, Color(0.15, 0.4, 0.75))
	var bw := 88
	for i in 3:
		var x := 8 + i * (bw + 10)
		var c := Color(0.85, 0.35, 0.3) if i == 2 else Color(0.35, 0.55, 0.85)
		UIPanel.rect(root, Vector2(x, 34), Vector2(bw, 78), c, 10)
		_lamps.append(UIPanel.rect(root, Vector2(x + bw * 0.5 - 7, 40), Vector2(14, 7), Color(0.3, 0.3, 0.3), 3))
		UIPanel.label(root, LABELS[i], Vector2(x, 52), Vector2(bw, 56), 22, Color(1, 1, 1))
		var center_px := Vector2(x + bw * 0.5, 73)
		# UI の位置 → 上面の部屋座標：UI の右 = +x、UI の上 = -z
		var u := (center_px.x / PX.x - 0.5) * SIZE.x
		var v_up := (0.5 - center_px.y / PX.y) * SIZE.y
		var area := MeshKit.interact_area(self, "Button%d" % i, BUTTONS[i], self)
		MeshKit.shape_box(area, Vector3(SIZE.x * bw / PX.x, 0.012, SIZE.y * 78.0 / PX.y), Vector3(u, 0.006, -v_up))
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_refresh()


func stop() -> void:
	mode = ""
	_refresh()


func _refresh() -> void:
	if toilet and toilet.has_method("set_spray"):
		toilet.set_spray(mode)
	if _status == null:
		return
	var running := not mode.is_empty()
	_status.text = ("%s 作動中" % ("おしり" if mode == "rear" else "ビデ")) if running else ""
	_status.modulate.a = 0.6 + 0.4 * absf(sin(_t * 4.0)) if running else 1.0
	for i in 3:
		var on := (i == 0 and mode == "rear") or (i == 1 and mode == "bidet")
		UIPanel.set_rect_color(_lamps[i], Color(1.0, 0.75, 0.2) if on else Color(0.3, 0.3, 0.3))


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	return id


## 照準を合わせたときの案内：「ボタン名：状態｜クリックしたときの動作」。
func get_prompt_text(id: String) -> String:
	if not toilet.occupied:
		return "%s：座っているときだけ使える" % LABELS[BUTTONS.find(id)]
	match id:
		"washlet_rear":
			return "おしり：%s｜クリックで選択" % ("作動中" if mode == "rear" else "停止中")
		"washlet_bidet":
			return "ビデ：%s｜クリックで選択" % ("作動中" if mode == "bidet" else "停止中")
		"washlet_stop":
			return "止：クリックで洗浄を停止" if not mode.is_empty() else "止：作動していない"
	return ""


func interact(id: String) -> String:
	if not toilet.occupied:
		return "washlet_need_sit"
	var key := ""
	match id:
		"washlet_rear":
			mode = "rear"
			key = "washlet_rear_on"
		"washlet_bidet":
			mode = "bidet"
			key = "washlet_bidet_on"
		"washlet_stop":
			key = "washlet_stopped" if not mode.is_empty() else ""
			mode = ""
	_refresh()
	return key
