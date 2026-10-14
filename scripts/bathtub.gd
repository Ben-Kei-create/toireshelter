extends Node3D
## 浴槽：内側のくぼみ・水面・排水口とゴム栓（チェーン付き）・浴槽用の蛇口。
## この節点は浴槽の中心（床の高さ）に置く。ローカル座標で外形 x ±0.9, z ±0.375、高さ 0.55。
## 奥（-z）が部屋の奥の壁。
##
## 水位 level は 0（空）〜1（満水）。給水と排水は流量の差で計算する:
##   給水している間    +1/FILL_TIME 毎秒（給水元は「手の蛇口」と「リモコンのふろ自動」。両方でも 1 本分＝二重に数えない）
##   栓が抜けている間  -1/DRAIN_TIME 毎秒
## ふろ自動（auto_filling）は AUTO_LEVEL で止まる。栓を抜く・停止・運転OFF でも止まる。
## 入浴剤：powder は「溶けている粉の量」（満水1杯ぶんの濃さ 1.0 × 水量で数える）。濃さ = powder / level。
##   給水すると水が増えて薄まり、排水では濃さは変わらず、空になると 0 に戻る。
##   色は入れてから REVEAL_TIME 秒かけて現れる（reveal 0→1）。一時停止中は進まない。
## 追い焚き（reheating）：REHEAT_TIME 秒、水面がゆらぎ、吸込口の前に渦が出る（熱の計算はしない）。
## 満水でも水面は縁より 5cm 下（WATER_MAX_Y）で止まり、あふれない。
## 一時停止中は _process が止まるので、水位も水流の模様も止まる。

const MeshKit := preload("res://scripts/mesh_kit.gd")
const FaucetScript := preload("res://scripts/faucet.gd")

const FILL_TIME := 40.0    # 空→満水（秒）
const DRAIN_TIME := 25.0   # 満水→空（秒）。給水より速い
const AUTO_LEVEL := 0.8    # ふろ自動の設定水位
const MIN_POWDER_LEVEL := 0.1
const REHEAT_MIN_LEVEL := 0.3
const REHEAT_TIME := 6.0
const REVEAL_TIME := 2.0
const WATER_COLOR := Color(0.62, 0.8, 0.9, 0.55)
const YUZU_COLOR := Color(0.98, 0.86, 0.42, 0.7)
const PORT_POS := Vector3(-0.6, 0.2, -HALF.z + WALL)   # 循環口（ふろ自動の給水と追い焚きの吸込口。奥の内壁）

const HALF := Vector3(0.9, 0.55, 0.375)   # 外形の半分（y は高さそのもの）
const WALL := 0.08
const BOTTOM_Y := 0.10                     # くぼみの底
const WATER_MIN_Y := BOTTOM_Y + 0.004
const WATER_MAX_Y := 0.50                  # 満水時の水面（縁 0.55 より下）
const DRAIN_POS := Vector3(0.62, BOTTOM_Y, 0.0)
const PLUG_OUT_POS := Vector3(0.71, BOTTOM_Y, -0.17)
const CHAIN_ANCHOR := Vector3(0.62, 0.42, -HALF.z + WALL + 0.004)   # 奥の内壁のあふれ口
const NOTE_SIZE := Vector2(0.045, 0.045)   # bath_note_01（正方形）。満水の水面 0.50 と縁 0.55 の間に収まる大きさ
const NOTE_POS := Vector3(-0.25, 0.524, HALF.z - WALL)   # 手前の縁の裏（内側の面）。満水 0.50 より上、縁 0.55 より下
const PLUG_RADIUS := 0.024
const PLUG_HEIGHT := 0.016

const COIN_CAP := 0.08       # 十円玉だけのふた：浮いてしまうので、この水位より上がらない
const BALL_DISSOLVE := 5.0   # お湯の中で玉が溶けきるまで（秒）
const BALL_POS := Vector3(-0.35, BOTTOM_Y, 0.05)
const COIN_RADIUS := 0.0118

signal ball_dissolved
signal ball_sunk

var level := 0.0
## 栓は初めからない。lid："none"（排水口がむき出し）／"coin"（十円玉だけ。浮く）／"full"（十円玉＋鉛のおもり）
var lid := "none"
var plug_in := false      # 排水口が塞がれているか（lid が none のときは常に false）
## 入浴剤の玉：""（なし）／"sunk"（底に沈んでいる。水だと溶けない）／"gone"（お湯で溶けた＝ドライバーが現れた）
var ball := ""
var ball_melt := 0.0
var ball_landed := false   # 粉の演出が終わって、玉が底に着いた（演出中に保存しても玉が消えないよう、玉の状態は演出の開始時に決める）
var driver_taken := false
var lint_taken := false
var lint_present := false
var was_filled := false   # 一度でも水が入ったか（「濡れている」表示用）
var auto_filling := false
var auto_done := false    # ふろ自動が設定水位で止まった（表示用）
var reheating := false
var powder := 0.0
var reveal := 0.0
var powder_busy := false
var _reheat_left := 0.0
var reheat_end_reason := ""   # 追い焚きが止まった理由："done"（正常完了）/ "low"（水量不足で中断）/ "stopped"（停止ボタン・運転OFF）
var _t := 0.0
var _water_mat: StandardMaterial3D
var _swirl: MeshInstance3D

var faucet: FaucetScript
var shower: FaucetScript   # 壁のフックに掛けたシャワー。給水は蛇口と同じ1本分（同時でも二重に数えない）
var _water: MeshInstance3D
var _plug: Node3D
var _lid_sinker: Node3D
var _ball: Node3D
var _ball_mat: StandardMaterial3D
var _driver_prop: Node3D
var _lint: Node3D
var _driver_area: Area3D
var _lint_area: Area3D


func _ready() -> void:
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_shell(visual)
	_build_drain(visual)
	_build_plug()
	_build_faucet()
	_build_shower()
	_build_bottles()
	_build_note()
	_build_port()

	_water = MeshInstance3D.new()
	_water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = Vector2((HALF.x - WALL) * 2.0 - 0.004, (HALF.z - WALL) * 2.0 - 0.004)
	_water.mesh = plane
	_water_mat = MeshKit.water_surface_mat().duplicate()   # 入浴剤で色が変わるので浴槽専用
	_water.material_override = _water_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
	_update_water()


func _process(delta: float) -> void:
	advance(delta)
	if shower_held:
		_update_held_shower(delta)


# ---------------------------------------------------------------- 手に持ったシャワー

const SPRAY_SPEED := 3.2     # 水の初速（m/s）。重力で曲がって落ちる
const SPRAY_STEP := 0.05     # 水の粒の時間間隔（秒）
const SPRAY_COUNT := 18

var shower_held := false
var shower_cam: Camera3D
var curtain: Node3D          # 閉じたカーテンに当たったか調べる相手（shower_curtain.gd）
var _shower_home := Transform3D.IDENTITY
var _spray: Array[MeshInstance3D] = []


## シャワーを手に取る。向けた先（視点の向き）へ水が飛び、重力で弧を描く。
func hold_shower(cam: Camera3D) -> void:
	if shower_held:
		return
	shower_held = true
	shower_cam = cam
	_shower_home = shower.transform
	shower.held = true
	(shower.get_node("ShowerArea") as Area3D).collision_layer = 0   # 持っている間は照準をさえぎらない
	shower.set_on(true)
	if _spray.is_empty():
		for i in SPRAY_COUNT:
			var d := MeshKit.sphere(self, 0.012, Vector3.ZERO, shower._stream_mat)
			d.top_level = true
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			d.visible = false
			_spray.append(d)


func release_shower() -> void:
	if not shower_held:
		return
	shower_held = false
	shower.held = false
	(shower.get_node("ShowerArea") as Area3D).collision_layer = MeshKit.LAYER_INTERACT
	shower.transform = _shower_home
	shower.set_on(false)
	for d in _spray:
		d.visible = false


func _update_held_shower(delta: float) -> void:
	if shower_cam == null or not is_instance_valid(shower_cam):
		release_shower()
		return
	var cb := shower_cam.global_basis
	var origin := shower_cam.global_position + cb * Vector3(0.12, -0.15, -0.12)
	shower.global_transform = Transform3D(cb * Basis(Vector3.RIGHT, PI * 0.5), origin)
	var fwd := -cb.z
	var v := fwd * SPRAY_SPEED
	var prev := origin
	var ended := false
	var hit_curtain := false
	var floor_y := to_global(Vector3(0.0, water_y() if level > 0.0005 else BOTTOM_Y, 0.0)).y
	for i in SPRAY_COUNT:
		var t := (i + 1) * SPRAY_STEP
		var p := origin + v * t + Vector3(0.0, -0.5 * 9.8 * t * t, 0.0)
		if not ended:
			if curtain != null and curtain.closed:
				var a: Vector3 = curtain.to_local(prev)
				var b: Vector3 = curtain.to_local(p)
				var cz: float = curtain.Z
				if (a.z - cz) * (b.z - cz) <= 0.0 and a.z != b.z:
					var k := (cz - a.z) / (b.z - a.z)
					var h := a.lerp(b, k)
					if h.x >= curtain.X_RANGE.x and h.x <= curtain.X_RANGE.y and h.y >= curtain.BOTTOM_Y and h.y <= curtain.RAIL_Y:
						hit_curtain = true
						ended = true
						p = curtain.to_global(h)
			if not ended and p.y <= floor_y:
				ended = true
				p.y = floor_y
		_spray[i].visible = true
		_spray[i].global_position = p
		_spray[i].scale = Vector3.ONE * (0.8 if ended else 1.0)
		if ended and i > 0 and _spray[i - 1].global_position.is_equal_approx(p):
			_spray[i].visible = false
		prev = p
		if ended:
			for j in range(i + 1, SPRAY_COUNT):
				_spray[j].visible = false
			break
	if hit_curtain and curtain.has_method("wet_hit"):
		curtain.wet_hit(delta)


## 給水しているか（手の蛇口とふろ自動のどちらか）。
func is_filling() -> bool:
	return faucet.is_on or shower.is_on or auto_filling


func concentration() -> float:
	return clampf(powder / level, 0.0, 1.0) if level > 0.0005 else 0.0


## 水位・入浴剤・自動運転・追い焚きを delta 秒ぶん進める（テストからも呼ぶ）。
func advance(delta: float) -> void:
	_t += delta
	var before := level
	var c0 := concentration()
	# 流入と流出を分けて数える（入浴剤の濃さの計算に使う）
	var inflow := delta / FILL_TIME if is_filling() else 0.0
	var outflow := delta / DRAIN_TIME if not plug_in else 0.0
	level = clampf(level + inflow - outflow, 0.0, 1.0)
	if lid == "coin" and plug_in:
		level = minf(level, COIN_CAP)   # 十円玉が浮いて、水が逃げる
	if ball == "sunk" and ball_landed and level >= MIN_POWDER_LEVEL and (auto_filling or reheating):
		ball_melt = minf(BALL_DISSOLVE, ball_melt + delta)   # お湯が回っている間だけ溶ける
		_update_ball()
		if ball_melt >= BALL_DISSOLVE:
			_ball_gone()
	# ふろ自動は設定水位で止まる（手の蛇口が出ていれば、そちらはそのまま）
	if auto_filling and level >= AUTO_LEVEL and before <= AUTO_LEVEL + 0.0001:
		if not faucet.is_on:
			level = maxf(before, minf(level, AUTO_LEVEL))
		auto_filling = false
		auto_done = true
	# 流れ出た水はその時点の濃さぶんの粉を持ち出す。入ってきた水は粉を増やさない（＝薄まる）。
	# 給水と排水を同時に行うと、流量の差で水位が変わりつつ、新しい水のぶん薄まっていく。空になったら色を戻す
	if outflow > 0.0 and powder > 0.0:
		powder = maxf(0.0, powder - c0 * minf(outflow, before + inflow))
	if level <= 0.0005:
		powder = 0.0
		reveal = 0.0
	if powder > 0.0 and reveal < 1.0:
		reveal = minf(1.0, reveal + delta / REVEAL_TIME)
	if reheating:
		_reheat_left -= delta
		if level < REHEAT_MIN_LEVEL:
			reheating = false
			reheat_end_reason = "low"
		elif _reheat_left <= 0.0:
			reheating = false
			reheat_end_reason = "done"
	if level > 0.02:
		was_filled = true
	_update_water()


## ふろ自動を始める。結果："ok" / "plug_open" / "full"。
func start_auto() -> String:
	if not plug_in:
		return "plug_open"
	auto_done = false
	if level >= AUTO_LEVEL - 0.001:
		auto_done = true
		return "full"
	auto_filling = true
	return "ok"


## 追い焚き。結果："ok" / "low"。
func start_reheat() -> String:
	if level < REHEAT_MIN_LEVEL:
		return "low"
	reheating = true
	reheat_end_reason = ""
	_reheat_left = REHEAT_TIME
	return "ok"


func _build_shower() -> void:
	# 奥の壁（ローカル z = -HALF.z）の縦のスライドバーに、シャワーヘッドを下向きに掛ける。ホースは蛇口の本体から
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var wz := -HALF.z
	var bar_x := 0.2
	MeshKit.pipe(self, [Vector3(bar_x, 1.05, wz + 0.035), Vector3(bar_x, 1.85, wz + 0.035)], 0.011, metal)
	for y in [1.05, 1.85]:
		MeshKit.box(self, Vector3(0.03, 0.03, 0.035), Vector3(bar_x, y, wz + 0.0175), metal)
	shower = FaucetScript.new()
	shower.name = "Shower"
	shower.position = Vector3(bar_x, 1.72, wz + 0.035)
	shower.prompt_on = "shower_on"
	shower.prompt_off = "shower_off"
	var hook := MeshKit.box(shower, Vector3(0.04, 0.05, 0.05), Vector3(0, 0, 0.03), metal, "Hook")
	hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 柄と、下を向いた丸いヘッド（散水板は少し暗い）
	var grip := MeshKit.cylinder(shower, 0.013, 0.16, Vector3(0, -0.02, 0.07), metal, "Grip")
	grip.rotation.x = deg_to_rad(55.0)
	var head := MeshKit.cylinder(shower, 0.04, 0.025, Vector3(0, -0.07, 0.14), metal, "Head")
	head.rotation.x = deg_to_rad(-15.0)
	MeshKit.cylinder(shower, 0.034, 0.003, Vector3(0, -0.083, 0.143), MeshKit.mat("shower_face", Color(0.35, 0.36, 0.38), 0.4), "Face").rotation.x = deg_to_rad(-15.0)
	# 水は少し太めの流れ（散水の代わり）
	shower.setup(Vector3(0, -0.09, 0.145), BOTTOM_Y, null, 0.022)
	var area := MeshKit.interact_area(shower, "ShowerArea", "bath_shower", shower)
	MeshKit.shape_box(area, Vector3(0.1, 0.16, 0.2), Vector3(0, -0.04, 0.1))
	add_child(shower)
	# シャワーの水は、蛇口の水流より白く薄く（細かい水の束に見えるように）
	shower._stream_mat.albedo_color = Color(0.92, 0.97, 1.0, 0.32)
	# ホース：蛇口の本体の左端から下へ垂れて、シャワーの柄の下へ
	var hose := MeshKit.mat("hose", Color(0.8, 0.8, 0.82), 0.3, 0.6)
	MeshKit.pipe(self, [Vector3(0.47, 0.68, wz + 0.04), Vector3(0.4, 0.6, wz + 0.07), Vector3(0.28, 0.62, wz + 0.08),
			Vector3(0.21, 0.9, wz + 0.09), Vector3(0.2, 1.3, wz + 0.1), Vector3(0.2, 1.63, wz + 0.11)], 0.008, hose)


func _build_bottles() -> void:
	# 右の縁（ローカル x 0.82〜0.9）の上に、シャンプーとリンスのポンプボトル。調べられる（取得はできない）
	var top := HALF.y
	var specs := [["Shampoo", "shampoo", Color(0.18, 0.32, 0.36), -0.2, true], ["Rinse", "rinse", Color(0.92, 0.9, 0.86), -0.1, false]]
	for sp in specs:
		var b := Node3D.new()
		b.name = sp[0]
		b.position = Vector3(HALF.x - WALL * 0.5, top, sp[3])
		add_child(b)
		var body := MeshKit.mat("bottle_%s" % sp[1], sp[2], 0.35)
		MeshKit.cylinder(b, 0.032, 0.16, Vector3(0, 0.08, 0), body, "Body", 0.03, 20)
		# ラベル（BATH-ASSETS-40 の 04 シャンプー／05 リンス）：正面（浴槽の手前 +z）に、画像の比率のまま巻く
		var ltex: Texture2D = load("res://assets/textures/bath/bath_label_%s.png" % ("04" if sp[4] else "05"))
		var lh := 0.1
		var span := lh * ltex.get_width() / ltex.get_height() / 0.0318
		var label := MeshInstance3D.new()
		label.name = "Label"
		label.mesh = MeshKit.band(0.0322, 0.0314, lh, -PI * 0.5, span, 20)
		label.material_override = MeshKit.texture_mat("bath_label_%s" % ("04" if sp[4] else "05"), ltex, 0.5)
		label.position = Vector3(0, 0.08, 0)
		b.add_child(label)
		MeshKit.cylinder(b, 0.012, 0.03, Vector3(0, 0.175, 0), MeshKit.mat("pump", Color(0.95, 0.95, 0.95), 0.4), "Neck")
		MeshKit.box(b, Vector3(0.05, 0.012, 0.018), Vector3(0.012, 0.196, 0), MeshKit.mat("pump", Color(0.95, 0.95, 0.95), 0.4), "Pump")
		if sp[4]:   # シャンプーの側面のギザギザ（目を閉じても分かる印）
			for k in 6:
				MeshKit.box(b, Vector3(0.004, 0.025, 0.004), Vector3(-0.031, 0.13, -0.012 + k * 0.005), body)
		var area := MeshKit.interact_area(b, sp[0] + "Area", sp[1])
		MeshKit.shape_box(area, Vector3(0.07, 0.21, 0.07), Vector3(0, 0.105, 0))


func stop_remote() -> void:
	if reheating:
		reheat_end_reason = "stopped"
	auto_filling = false
	reheating = false
	_reheat_left = 0.0


## 入浴剤を入れる。結果："ok"（演出開始）／"low"（水が足りない）／"busy"。
func add_powder(from: Vector3) -> String:
	if powder_busy:
		return "busy"
	if level < MIN_POWDER_LEVEL:
		return "low"
	powder_busy = true
	reserve_ball()
	# 粉を入れる簡単な演出：小さな粒が水面へ落ちる（容器は投げ込まない）
	var target_y := water_y()
	var grains := Node3D.new()
	grains.name = "PowderGrains"
	add_child(grains)
	var start_local := to_local(from)
	start_local.x = clampf(start_local.x, -HALF.x + WALL + 0.1, HALF.x - WALL - 0.1)
	start_local.z = clampf(start_local.z, -HALF.z + WALL + 0.08, HALF.z - WALL - 0.08)
	start_local.y = maxf(start_local.y, target_y + 0.25)
	var grain_mat := MeshKit.mat("powder_grain", Color(0.98, 0.9, 0.55), 0.8)
	var tween := create_tween().set_parallel()
	for i in 10:
		var g := MeshKit.sphere(grains, 0.006, start_local + Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)), grain_mat)
		tween.tween_property(g, "position:y", target_y, 0.5).set_delay(i * 0.03).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(func() -> void:
		grains.queue_free()
		powder += level   # 濃さ 1.0 ぶん
		sink_ball()
		reveal = 0.0
		powder_busy = false)
	return "ok"


func water_y() -> float:
	return lerpf(WATER_MIN_Y, WATER_MAX_Y, level)


## 十円玉・おもりでふたをする。結果："coin"（十円玉を置いた）／"full"（おもりを載せた）／"already"。
func put_lid(with_sinker: bool) -> String:
	if with_sinker and lid == "coin":
		lid = "full"
		_refresh_lid()
		return "full"
	if lid == "none":
		lid = "full" if with_sinker else "coin"
		plug_in = true
		_refresh_lid()
		return lid
	return "already"


func take_coin_lid() -> void:
	if lid == "coin":
		lid = "none"
		plug_in = false
		_refresh_lid()


func _refresh_lid() -> void:
	_plug.visible = lid != "none"
	_lid_sinker.visible = lid == "full"
	set_plug(plug_in)


func _update_ball() -> void:
	if _ball == null:
		return
	_ball.visible = ball == "sunk" and ball_landed
	var k := 1.0 - ball_melt / BALL_DISSOLVE * 0.8
	_ball.scale = Vector3.ONE * k
	_ball_mat.albedo_color = Color(0.9, 0.7, 0.3).lerp(Color(0.75, 0.45, 0.3), clampf(ball_melt / BALL_DISSOLVE, 0.0, 1.0)) if powder > 0.0 else Color(0.9, 0.7, 0.3)


func _ball_gone() -> void:
	ball = "gone"
	_ball.visible = false
	_driver_prop.visible = not driver_taken
	_set_area(_driver_area, not driver_taken)
	ball_dissolved.emit()


func take_driver() -> void:
	driver_taken = true
	_driver_prop.visible = false
	_set_area(_driver_area, false)


## 入浴剤を入れた瞬間に、玉の状態を決める（まだ見えない）。
func reserve_ball() -> void:
	if ball == "":
		ball = "sunk"
		ball_melt = 0.0
		ball_landed = false


## 粉が水面に着いたあと、玉が底に見えるようになる。
func sink_ball() -> void:
	if ball == "sunk" and not ball_landed:
		ball_landed = true
		_update_ball()
		ball_sunk.emit()


func _set_area(a: Area3D, on: bool) -> void:
	if a:
		a.collision_layer = MeshKit.LAYER_INTERACT if on else 0


## 毛だまりが取れて排水口の近くに残る。
func drop_lint() -> void:
	lint_present = not lint_taken
	_lint.visible = lint_present
	_set_area(_lint_area, lint_present)


func take_lint() -> void:
	lint_taken = true
	lint_present = false
	_lint.visible = false
	_set_area(_lint_area, false)


## セーブから戻す。
func restore(p_lid: String, p_plug_in: bool, p_ball: String, p_melt: float, p_driver_taken: bool, p_lint_present: bool, p_lint_taken: bool) -> void:
	lid = p_lid
	plug_in = p_plug_in and p_lid != "none"
	ball = p_ball
	ball_melt = p_melt
	driver_taken = p_driver_taken
	lint_taken = p_lint_taken
	lint_present = p_lint_present
	_refresh_lid()
	_update_ball()
	ball_landed = ball == "sunk" or ball == "gone"
	_update_ball()
	_driver_prop.visible = ball == "gone" and not driver_taken
	_set_area(_driver_area, _driver_prop.visible)
	_lint.visible = lint_present
	_set_area(_lint_area, lint_present)


func set_plug(inserted: bool) -> void:
	if lid == "none":
		inserted = false
	plug_in = inserted
	if not inserted:
		auto_filling = false   # 栓を抜いたらふろ自動は止まる
	if inserted:
		_plug.position = DRAIN_POS + Vector3(0, 0.003, 0)
	else:
		_plug.position = PLUG_OUT_POS   # 外したふたは排水口の横に置いておく
	_plug.rotation = Vector3.ZERO


func _update_water() -> void:
	if _water == null:
		return
	_water.visible = level > 0.0005
	var wobble := sin(_t * 9.0) * 0.003 if reheating else 0.0
	_water.position = Vector3(0.0, water_y() + wobble, 0.0)
	_water_mat.albedo_color = WATER_COLOR.lerp(YUZU_COLOR, concentration() * reveal)
	if _swirl:
		_swirl.visible = _water.visible and (reheating or auto_filling) and water_y() > PORT_POS.y - 0.12
		_swirl.position.y = water_y() + 0.003
		_swirl.rotation.y = _t * 4.0
	# 水流は水面まで。水がなければ底まで
	faucet.stream_floor_y = to_global(Vector3(0.0, water_y() if _water.visible else BOTTOM_Y, 0.0)).y
	if shower:
		shower.stream_floor_y = faucet.stream_floor_y


# ---------------------------------------------------------------- 組み立て

func _build_shell(visual: Node3D) -> void:
	var porcelain := MeshKit.mat("porcelain", Color(0.92, 0.92, 0.92), 0.3)
	var inner := MeshKit.mat("tub_inner", Color(0.7, 0.8, 0.86), 0.3)
	var h := HALF.y
	var wall_h := h - BOTTOM_Y
	var wy := BOTTOM_Y + wall_h * 0.5
	var inner_x := HALF.x - WALL
	var parts := [
		# [大きさ, 中心, マテリアル]
		[Vector3(HALF.x * 2.0, BOTTOM_Y, HALF.z * 2.0), Vector3(0.0, BOTTOM_Y * 0.5, 0.0), porcelain],   # 底
		[Vector3(HALF.x * 2.0, wall_h, WALL), Vector3(0.0, wy, -HALF.z + WALL * 0.5), porcelain],     # 奥
		[Vector3(HALF.x * 2.0, wall_h, WALL), Vector3(0.0, wy, HALF.z - WALL * 0.5), porcelain],      # 手前
		[Vector3(WALL, wall_h, (HALF.z - WALL) * 2.0), Vector3(-HALF.x + WALL * 0.5, wy, 0.0), porcelain],
		[Vector3(WALL, wall_h, (HALF.z - WALL) * 2.0), Vector3(HALF.x - WALL * 0.5, wy, 0.0), porcelain],
	]
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = MeshKit.LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", "bathtub")
	body.set_meta("fixture", self)
	add_child(body)
	for p in parts:
		MeshKit.box(visual, p[0], p[1], p[2])
		MeshKit.shape_box(body, p[0], p[1])
	# くぼみの底面だけ水色（底の箱の上面から 1mm 上。側面は壁に隠れる）
	MeshKit.box(visual, Vector3(inner_x * 2.0, 0.002, (HALF.z - WALL) * 2.0), Vector3(0.0, BOTTOM_Y - 0.0005, 0.0), inner, "InnerBottom")


func _build_note() -> void:
	# 手前の縁の裏に貼った小さな紙（仮の見た目：無地）。内側を向いているので、通路からは縁に遮られて見えず、
	# 浴槽に入って見回すと見える（姿勢で表示を切り替えず、位置と遮蔽物だけで見え方を作る）。取得はできない
	var quad := QuadMesh.new()
	quad.size = NOTE_SIZE
	var note := MeshInstance3D.new()
	note.name = "TubNote"
	note.mesh = quad
	var nm := MeshKit.texture_mat("bath_note_01", load("res://assets/textures/bath/bath_note_01.png"), 0.9).duplicate() as StandardMaterial3D
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR   # 紙の縁の外（透明）を抜く
	note.material_override = nm
	note.position = NOTE_POS - Vector3(0, 0, 0.0012)
	note.rotation.y = PI   # 表（+z）を浴槽の内側（-z）へ
	add_child(note)
	var area := MeshKit.interact_area(self, "TubNoteArea", "tub_note")
	MeshKit.shape_box(area, Vector3(NOTE_SIZE.x, NOTE_SIZE.y, 0.004), NOTE_POS - Vector3(0, 0, 0.002))


func _build_port() -> void:
	# 循環口：奥の内壁の丸い金具。ふろ自動・追い焚きのときは前の水面に渦が出る
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var port := MeshKit.cylinder(self, 0.035, 0.012, PORT_POS + Vector3(0, 0, 0.006), metal, "CirculationPort")
	port.rotation.x = deg_to_rad(90.0)
	MeshKit.cylinder(port, 0.018, 0.014, Vector3.ZERO, MeshKit.mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0))
	_swirl = MeshKit.cylinder(self, 0.09, 0.002, Vector3(PORT_POS.x, 0.0, PORT_POS.z + 0.12), MeshKit.new_stream_mat(), "PortSwirl", -1.0, 18)
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swirl.visible = false


func _build_drain(visual: Node3D) -> void:
	# 金属の輪・暗い穴・十字の格子。栓をすると栓で隠れる
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	var dark := MeshKit.mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0)
	MeshKit.cylinder(visual, 0.028, 0.003, DRAIN_POS + Vector3(0, 0.0015, 0), metal, "DrainRing")
	MeshKit.cylinder(visual, 0.02, 0.001, DRAIN_POS + Vector3(0, 0.0035, 0), dark, "DrainHole")
	MeshKit.box(visual, Vector3(0.04, 0.002, 0.004), DRAIN_POS + Vector3(0, 0.005, 0), metal)
	MeshKit.box(visual, Vector3(0.004, 0.002, 0.04), DRAIN_POS + Vector3(0, 0.005, 0), metal)
	# あふれ口のプレート（チェーンの留め具）
	var plate := MeshKit.cylinder(visual, 0.03, 0.006, CHAIN_ANCHOR + Vector3(0, 0, -0.001), metal, "Overflow")
	plate.rotation.x = deg_to_rad(90.0)


func _build_plug() -> void:
	# 十円玉のふた（＋載せた鉛のおもり）。チェーンも栓もない
	_plug = Node3D.new()
	_plug.name = "Plug"
	add_child(_plug)
	MeshKit.cylinder(_plug, COIN_RADIUS, 0.0016, Vector3(0, 0.0008, 0), MeshKit.mat("coin10", Color(0.62, 0.36, 0.2), 0.4, 0.7), "Coin")
	_lid_sinker = Node3D.new()
	_lid_sinker.name = "LidSinker"
	_plug.add_child(_lid_sinker)
	MeshKit.sphere(_lid_sinker, 0.011, Vector3(0, 0.011, 0), MeshKit.mat("lead", Color(0.35, 0.36, 0.4), 0.35, 0.8))

	# 照準用の判定：ふたをした位置と外した位置の両方を覆う
	var area := MeshKit.interact_area(self, "PlugArea", "bath_plug", self)
	var lo := Vector3(minf(DRAIN_POS.x, PLUG_OUT_POS.x) - 0.04, BOTTOM_Y, minf(DRAIN_POS.z, PLUG_OUT_POS.z) - 0.04)
	var hi := Vector3(maxf(DRAIN_POS.x, PLUG_OUT_POS.x) + 0.04, BOTTOM_Y + 0.06, maxf(DRAIN_POS.z, PLUG_OUT_POS.z) + 0.04)
	MeshKit.shape_box(area, hi - lo, (hi + lo) * 0.5)
	_build_props()
	_refresh_lid()


## 底に沈む玉・玉が溶けて現れるドライバー・取れた毛だまり。
func _build_props() -> void:
	_ball = Node3D.new()
	_ball.name = "Ball"
	_ball.position = BALL_POS + Vector3(0, 0.035, 0)
	_ball.visible = false
	add_child(_ball)
	_ball_mat = MeshKit.mat("bath_ball", Color(0.9, 0.7, 0.3), 0.4)
	MeshKit.sphere(_ball, 0.035, Vector3.ZERO, _ball_mat)
	_driver_prop = Node3D.new()
	_driver_prop.name = "TubDriver"
	_driver_prop.position = BALL_POS + Vector3(0, 0.016, 0)
	_driver_prop.rotation.y = deg_to_rad(25.0)
	_driver_prop.visible = false
	add_child(_driver_prop)
	var vis := Node3D.new()
	vis.name = "Visual"
	_driver_prop.add_child(vis)
	var hm := MeshKit.mat("handle", Color(0.92, 0.22, 0.05), 0.5)
	hm.emission_enabled = true
	hm.emission = Color(0.92, 0.22, 0.05)
	hm.emission_energy_multiplier = 0.25
	var h := MeshKit.cylinder(vis, 0.016, 0.1, Vector3(-0.05, 0, 0), hm)
	h.rotation.z = deg_to_rad(90.0)
	var sh := MeshKit.cylinder(vis, 0.003, 0.11, Vector3(0.055, 0, 0), MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8))
	sh.rotation.z = deg_to_rad(90.0)
	_driver_area = MeshKit.interact_area(_driver_prop, "Pickup", "tub_driver")
	MeshKit.shape_box(_driver_area, Vector3(0.28, 0.1, 0.14), Vector3(0, 0.02, 0))
	_set_area(_driver_area, false)
	_lint = Node3D.new()
	_lint.name = "Lint"
	_lint.position = DRAIN_POS + Vector3(-0.1, 0.012, 0.12)
	_lint.visible = false
	add_child(_lint)
	var lm := MeshKit.mat("lint", Color(0.55, 0.52, 0.5), 0.95)
	for off in [Vector3.ZERO, Vector3(0.015, -0.003, 0.01), Vector3(-0.012, -0.004, 0.012)]:
		MeshKit.sphere(_lint, 0.014, off, lm)
	_lint_area = MeshKit.interact_area(_lint, "Pickup", "tub_lint")
	MeshKit.shape_box(_lint_area, Vector3(0.1, 0.06, 0.1), Vector3.ZERO)
	_set_area(_lint_area, false)


func _build_faucet() -> void:
	# 奥の壁（ローカル z = -HALF.z）に付けた混合水栓。吐水口の先はくぼみの上
	faucet = FaucetScript.new()
	faucet.name = "Faucet"
	faucet.position = Vector3(0.55, 0.70, -HALF.z)
	var metal := MeshKit.mat("metal", Color(0.75, 0.75, 0.78), 0.25, 0.8)
	MeshKit.box(faucet, Vector3(0.16, 0.05, 0.05), Vector3(0, 0, 0.025), metal, "Body")
	MeshKit.box(faucet, Vector3(0.03, 0.025, 0.15), Vector3(0, -0.03, 0.09), metal, "Spout")
	var lever := Node3D.new()
	lever.name = "Lever"
	lever.position = Vector3(0, 0.025, 0.025)
	faucet.add_child(lever)
	MeshKit.box(lever, Vector3(0.02, 0.012, 0.09), Vector3(0, 0.006, 0.045), metal)
	faucet.setup(Vector3(0, -0.045, 0.155), BOTTOM_Y, lever, 0.006)
	var area := MeshKit.interact_area(faucet, "FaucetArea", "bath_faucet", faucet)
	MeshKit.shape_box(area, Vector3(0.18, 0.12, 0.19), Vector3(0, 0.0, 0.095))
	add_child(faucet)


# ---------------------------------------------------------------- main.gd から呼ばれる

func get_prompt(id: String) -> String:
	if id == "bath_plug":
		if lid == "none":
			return "examine"
		return "lid_remove" if plug_in else "lid_set"
	return "examine"


func interact(id: String) -> String:
	match id:
		"bath_plug":
			if lid == "none":
				return "tub_no_plug"
			if lid == "coin":
				return "tub_take_coin"   # 十円玉だけのふたは、取り戻せる（洗面台で使う前に置いてしまっても詰まない）
			set_plug(not plug_in)
			return ""
		_:
			if level > 0.02:
				return "bathtub_yuzu" if powder > 0.0 else "bathtub_water"
			return "bathtub_wet" if was_filled else "bathtub"
