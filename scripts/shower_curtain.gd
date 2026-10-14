extends Node3D
## 浴槽とトイレの間のシャワーカーテン。浴槽の手前の縁の内側にレールを渡し、半透明のカーテンを下げる。
## クリックで閉める（浴槽の幅いっぱいに広がる）／開ける（左端＝トイレ側へ寄る）。初期状態は開いている。
## 寄せる側を左にしたのは、右（洗面台側）だと寄せた布が右の壁の浴室リモコンへの照準をさえぎるため。
## 布は浴槽の内側（z -0.57）に、縁より下（0.30m）まで垂らす。タンクの蓋を外すときの経路（z -0.53 より手前）と重ならない。
## 座標は部屋と同じ（この節点は原点に置く）。
##
##   ShowerCurtain/Rail     … レール（見た目だけ）
##   ShowerCurtain/Cloth    … 布。原点を左端に置き、x 方向の縮み（scale.x）で寄せる。半透明なので向こうが透けて見える
##   ShowerCurtain/CurtainArea … 照準の判定。タオルと同じく、開け終わってから寄せた位置へ、閉め始めに全幅へ移す。
##                               閉じている間は浴槽の中の物（栓・蛇口など）への照準をさえぎる
## 体を止める判定はない（布なので、移動演出は通り抜ける）。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const CLOTH_TEX := preload("res://assets/textures/bath/bath_material_09.png")   # Shower curtain

const X_RANGE := Vector2(-0.88, 0.88)
const Z := -0.57             # 浴槽の手前の内壁（z -0.53）の内側、縁（上端 0.55）より上に下げる
const RAIL_Y := 1.95
const BOTTOM_Y := 0.30          # 浴槽の内側へ垂らす（縁 0.55 より下まで。外から見下ろしても下をくぐれない）
const FOLDS := 10
const OPEN_SCALE := 0.13     # 開けたとき（左端に寄せた）の幅の割合
const SLIDE_TIME := 0.45

const DIGITS := "7305"          # パスワード①（黒電話・のちの鍵）。濡れたときだけ、カーテンに浮かぶ
const WET_TIME := 30.0          # 濡れてから乾いて消えるまで（秒）

signal digits_revealed

var wet := 0.0                 # 濡れの残り（秒）。0 で乾いて数字が消える
var digits_seen := false
var shower: Object             # 浴槽のシャワー（faucet.gd）。つながっていれば、出ている間にカーテンへかけられる
var _digits: Label3D
var closed := false
var busy := false
var cloth: Node3D
var _area_shape: CollisionShape3D


func _ready() -> void:
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.pipe(self, [Vector3(X_RANGE.x - 0.02, RAIL_Y, Z), Vector3(X_RANGE.y + 0.02, RAIL_Y, Z)], 0.009, metal)
	cloth = Node3D.new()
	cloth.name = "Cloth"
	cloth.position = Vector3(X_RANGE.x, 0.0, Z)
	cloth.scale.x = OPEN_SCALE
	add_child(cloth)
	var m := MeshKit.tiled_mat("shower_curtain", CLOTH_TEX, 0.35, Color(1, 1, 1, 0.55), 0.8).duplicate() as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_world_triplanar = true   # 寄せても模様が縮まないよう、世界座標で貼る
	var w := X_RANGE.y - X_RANGE.x
	var fw := w / FOLDS
	var h := RAIL_Y - 0.03 - BOTTOM_Y
	for i in FOLDS:
		# ひだ：板を交互に少し前後へ傾ける
		var panel := MeshKit.box(cloth, Vector3(fw * 1.02, h, 0.002), Vector3(fw * (i + 0.5), BOTTOM_Y + h * 0.5, 0.0), m)
		panel.rotation.y = deg_to_rad(14.0 if i % 2 == 0 else -14.0)
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# レールのリング
	for i in FOLDS + 1:
		MeshKit.sphere(cloth, 0.012, Vector3(fw * i, RAIL_Y - 0.012, 0.0), metal)
	_digits = Label3D.new()
	_digits.name = "Digits"
	_digits.text = " ".join(DIGITS.split(""))
	_digits.font_size = 96
	_digits.pixel_size = 0.0016
	_digits.modulate = Color(0.85, 0.92, 1.0, 0.0)
	_digits.outline_size = 0
	_digits.shaded = false
	_digits.double_sided = true
	_digits.render_priority = 3
	_digits.position = Vector3(0.0, 1.25, Z + 0.05)
	_digits.visible = false
	add_child(_digits)
	var area := MeshKit.interact_area(self, "CurtainArea", "shower_curtain", self)
	_area_shape = MeshKit.shape_box(area, Vector3.ONE, Vector3.ZERO)
	_area_shape.shape = BoxShape3D.new()
	_place_area(false)


func _process(delta: float) -> void:
	if wet > 0.0:
		wet = maxf(0.0, wet - delta)
	_update_digits()


func _update_digits() -> void:
	var a := clampf(wet / 6.0, 0.0, 1.0) * 0.8 if closed else 0.0
	_digits.visible = a > 0.01
	_digits.modulate.a = a


## 手に持ったシャワーを閉じたカーテンにかける（シャワーが出ているときだけ）。濡れた間は数字が浮かぶ。
func spray() -> void:
	wet = WET_TIME
	if shower:
		shower.set_on(false)   # かけ終えたら止める（カーテン越しには蛇口に手が届かないため）
	_update_digits()
	if not digits_seen:
		digits_seen = true
		digits_revealed.emit()


func can_spray() -> bool:
	return closed and not busy and shower != null and shower.is_on


func toggle() -> void:
	if busy:
		return
	busy = true
	closed = not closed
	if closed:
		_place_area(true)   # 閉め始めた時点で、浴槽の中への照準をさえぎる
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cloth, "scale:x", 1.0 if closed else OPEN_SCALE, SLIDE_TIME)
	tween.tween_callback(func() -> void:
		if not closed:
			_place_area(false)
		busy = false)


func _place_area(full: bool) -> void:
	var w := (X_RANGE.y - X_RANGE.x) * (1.0 if full else OPEN_SCALE)
	var h := RAIL_Y - BOTTOM_Y
	(_area_shape.shape as BoxShape3D).size = Vector3(w, h, 0.06)
	_area_shape.position = Vector3(X_RANGE.x + w * 0.5, BOTTOM_Y + h * 0.5, Z)


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(_id: String) -> String:
	if busy:
		return ""
	if can_spray():
		return "curtain_spray"
	return "curtain_open" if closed else "curtain_close"


func interact(_id: String) -> String:
	if can_spray():
		spray()
		return "curtain_sprayed"
	toggle()
	return ""
