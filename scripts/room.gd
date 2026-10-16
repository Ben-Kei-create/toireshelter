extends Node3D
## ユニットバスと、ドアの外の短い廊下をコードで組み立てる。
##
## 座標系（単位 m）:
##   室内  x: -0.9〜0.9（幅1.8） / y: 0〜2.2（高さ2.2） / z: -1.2〜1.2（奥行き2.4）
##   入口ドアは z = +1.2 側の壁。外側（+z）に廊下があり、そこが出口。
##
## 各設備は次の構成にしている（後で GLB に差し替えやすくするため）:
##   <設備名> (Node3D)
##     ├ Visual (Node3D)          … 見た目だけ。GLB に差し替えるならここを入れ替える
##     └ Collision (StaticBody3D) … 当たり判定と「調べる」対象。メタデータ interact_id を持つ

const MeshKit := preload("res://scripts/mesh_kit.gd")
const Sfx := preload("res://scripts/sfx.gd")
const ToiletScript := preload("res://scripts/toilet.gd")
const BathtubScript := preload("res://scripts/bathtub.gd")
const FaucetScript := preload("res://scripts/faucet.gd")
const SuppliesScript := preload("res://scripts/supplies.gd")
const SinkScript := preload("res://scripts/sink.gd")
const MirrorCabinetScript := preload("res://scripts/mirror_cabinet.gd")
const TowelScript := preload("res://scripts/towel.gd")
const ApartmentScript := preload("res://scripts/apartment.gd")
const ExteriorScript := preload("res://scripts/exterior.gd")
const BathRemoteScript := preload("res://scripts/bath_remote.gd")
const ToiletPanelScript := preload("res://scripts/toilet_panel.gd")
const ShowerCurtainScript := preload("res://scripts/shower_curtain.gd")
const FrontDoorScript := preload("res://scripts/front_door.gd")
const CorridorScript := preload("res://scripts/corridor.gd")
const ElevatorCarScript := preload("res://scripts/elevator_car.gd")
const EntranceScript := preload("res://scripts/entrance.gd")
const FigureStickersScript := preload("res://scripts/figure_stickers.gd")
const LiquorCellarScript := preload("res://scripts/liquor_cellar.gd")
const JapaneseRoomScript := preload("res://scripts/japanese_room.gd")
const Stage4ItemsRef := preload("res://scripts/stage4_items.gd")
const SkyClockScript := preload("res://scripts/sky_clock.gd")
const LightSwitchScript := preload("res://scripts/light_switch.gd")
const BathDoorControlScript := preload("res://scripts/bath_door_control.gd")
const BathWearScript := preload("res://scripts/bath_wear.gd")
const PaintingMapScript := preload("res://scripts/painting_map.gd")
const AmbientSoundScript := preload("res://scripts/ambient_sound.gd")

const LAYER_WORLD := 1      # 壁・設備（プレイヤーがぶつかる）
const LAYER_INTERACT := 2   # 拾える小物（ぶつからない、照準だけ当たる）
const LAYER_PLAYER := 8     # プレイヤー（layer 4）

const ROOM_W := 1.8
const ROOM_D := 2.4
const ROOM_H := 2.2
const WALL_T := 0.1
const DOOR_W := 0.7
const DOOR_H := 1.9
const DOOR_OPEN_DEG := -90.0

## トイレは、黒と赤を基調にした、宮殿のような美術館の部屋（清潔感のある、深紅の壁・黒い漆の腰壁・金の縁・シャンデリア）。
const WALL_COLOR := Color(0.3, 0.035, 0.05)    # 深紅
const SEAM_COLOR := Color(0.62, 0.46, 0.16)    # 金の縁
const CAULK_COLOR := Color(0.62, 0.47, 0.17)   # 金の目地
const BLACK_LACQUER := Color(0.04, 0.025, 0.03)
const GOLD := Color(0.66, 0.5, 0.17)
const PANEL_TARGET_W := 0.6   # パネル幅の目安。壁の長さを割り切れる枚数に丸める
const DETAIL_GAP := 0.002     # 壁面から浮かせる量（面の重なりによるちらつき防止）
const VENT_SIZE := 0.24
const VENT_RANGE := 2.4       # 換気口だけ床から見上げて届くよう、操作距離を個別に伸ばす

const POSTER_TEX := preload("res://assets/textures/door_poster_plumber.png")
const LABEL_TEX := preload("res://assets/textures/yubroman_label.png")
const TOWEL_TEX := preload("res://assets/textures/towel_fabric.png")             # 512x512 継ぎ目なし
const LAMINATE_TEX := preload("res://assets/textures/bath/bath_material_10.png")   # 棚の化粧板（307x307、継ぎ目なし）
const TOOTHPASTE_TEX := preload("res://assets/textures/toothpaste_label.png")   # 271x512
const POSTER_SIZE := Vector2(0.25, 0.354)   # 768x1086px（A判比）
const POSTER_HINGE_X := 0.32                # 蝶番からの距離（ドアノブ側を避ける）
const POSTER_CENTER_Y := 1.40
const POWDER_RADIUS := 0.05
const POWDER_HEIGHT := 0.15
const LID_RADIUS := 0.052
const LID_HEIGHT := 0.025
const LABEL_HEIGHT := 0.10                  # 1024x320px を円周 0.317m に巻く
const FLOOR_COLOR := Color(0.55, 0.54, 0.52)    # 淡いグレージュ。壁より少し暗く、彩度を低く
const FLOOR_TEX := preload("res://assets/textures/surfaces/surface_11.png")
const FLOOR_TEX_AVG := Color(0.77, 0.73, 0.67)   # 画像の平均色（実測）。これで割って、平均が FLOOR_COLOR になるよう着色する
const PORCELAIN_COLOR := Color(0.92, 0.92, 0.92)

var spawn_position := Vector3(0.0, 0.05, 0.75)
var door_pivot: Node3D
var door_body: StaticBody3D
var door_area: Area3D          # ドアを直したあとの開け閉め用の判定（開いて通れるようになった扉にも当たる）
var door_unlocked := false     # ドライバーで直した
var door_swung := false        # 今、開いている
var door_busy := false
var driver_node: Node3D
var apartment: ApartmentScript
var exterior: ExteriorScript
var front_door: FrontDoorScript
var sky_clock: SkyClockScript
var light_switch: Node3D
# トイレの電球：自室のスイッチで入り切りする。消してからつけ直す回数が PURPLE_AFTER に達すると紫色になる（そのまま）
const BULB_POS := Vector3(0.15, 2.17, 0.35)   # シャンデリアの吊り元（天井）
const BATH_LIGHT_ENERGY := 0.7   # 深紅と黒の壁は光を吸うので、少し明るく
const BATH_LIGHT_COLOR := Color(1.0, 0.89, 0.76)
const PURPLE_LIGHT_COLOR := Color(0.25, 0.4, 1.0)   # 青い蛍光灯（名前は旧仕様のまま：紫→青）
const PURPLE_AFTER := 4
var bath_light: OmniLight3D
var bath_light_on := true
var bath_light_cycles := 0     # 消してからつけ直した回数
var bath_purple := false
var _bulb_mat: StandardMaterial3D
const PREVIEW_CAR_POS := Vector3(0.0, -80.0, 0.0)
const WASHITSU_POS := Vector3(40.0, -80.0, 0.0)   # 隣の和室（ほかの場所から遠く離して置く。こたつの壁の穴から、暗転して移る）
var washitsu: Node3D
const ENTRANCE_POS := Vector3(-1.85, -13.6, -2.9)   # 外壁（z -1.3）にアーチ、突き当たり（z 6.4）が廊下のエレベーターの真下
var corridor: CorridorScript
var vent_cover: Node3D
var bath_remote: BathRemoteScript
var toilet_panel: ToiletPanelScript
var shower_curtain: ShowerCurtainScript
var bath_powder_taken := false
var paper_taken := false
var paper_fixture: Node3D
var vent_open := false
const BUCKET_R := 0.17
const BUCKET_H := 0.30         # 風呂桶の高さ。逆さにして乗ると、目の高さがこれだけ上がる
const BUCKET_TUB_LOCAL := Vector3(-0.05, 0.10, 0.0)   # 浴槽ローカルで、入ったときの足元（main.gd の TUB_FEET_LOCAL と同じ）
var bucket_taken := false
var bucket_in_tub := false
## --- 浴室がせり上がる（第 2 幕）。浴室（と換気ダクト）の節点だけを持ち上げる。ホール・自室・ベランダの座標は変えない。
signal unit_risen
const RISE_H := 2.2            # 上がる高さ（m）＝浴室の高さ。扉の床がホールの天井の高さになり、ホールの床は遠く下に見える。体は出られない
const RISE_TIME := 8.0
const BLACKOUT_AMBIENT := 0.01   # 停電のあとの環境光の倍率（真っ暗）
const UNIT_EXCLUDE := ["WorldEnvironment", "SkyClock", "HallLight", "Apartment", "BathLightSwitch", "Exterior",
		"FrontDoor", "Corridor", "AmbientSound", "Fishing", "Pedestal", "DoorDebris", "FuseHatch", "DoorwayBlocker", "ElevatorCar", "Entrance", "DoorKnob", "LiquorCellar", "JapaneseRoom", "PlacedLadder"]
var risen := false
var rising := false
var rise_offset := 0.0         # いまの上昇量（m）。浴室と換気ダクトの座標にこれを足す
var power_on := true           # 自室・ホールの電気（ユニット専用の浴室の電球は別系統）
var wood_stick: Node3D
var _unit: Array = []          # [節点, もとの y]
var _rise_player: Node3D
var _pedestal: MeshInstance3D
var _door_broken := false
var _power_energy := {}
var toilet: ToiletScript
var bathtub: BathtubScript
var sink: SinkScript
var sink_faucet: FaucetScript
var mirror_cabinet: MirrorCabinetScript
var towel: TowelScript
var supplies: SuppliesScript


func _ready() -> void:
	_build_environment()
	_build_shell()
	_build_wall_details()
	_build_palace_trim()
	_build_painting()
	_build_height_gauge()
	# 玄関ホール・自室（apartment.gd）と、換気経路・ベランダ・外景（exterior.gd）
	apartment = ApartmentScript.new()
	apartment.name = "Apartment"
	add_child(apartment)
	# 浴室の電気のスイッチ（自室の壁。浴室の中にはない）
	light_switch = LightSwitchScript.new()
	light_switch.name = "BathLightSwitch"
	light_switch.room = self
	add_child(light_switch)
	exterior = ExteriorScript.new()
	exterior.name = "Exterior"
	add_child(exterior)
	# 玄関ドア（玄関ホールの左の壁）と、その外の5階の共用廊下・下南澤の街並み
	front_door = FrontDoorScript.new()
	front_door.name = "FrontDoor"
	add_child(front_door)
	corridor = CorridorScript.new()
	corridor.name = "Corridor"
	add_child(corridor)
	# エレベーターの箱の中（ほかの場所から遠く離して置く。乗っている間だけ、ここへ移る）と、1 階の入口・玄関ホール
	# （廊下・エレベーターの真下。路地から建物へ +z の向きに入るので、180 度回して置く）。浴室がせり上がっても動かさない（UNIT_EXCLUDE）
	var car := ElevatorCarScript.new()
	car.name = "ElevatorCar"
	car.position = PREVIEW_CAR_POS
	add_child(car)
	washitsu = JapaneseRoomScript.new()
	washitsu.name = "JapaneseRoom"
	washitsu.position = WASHITSU_POS
	add_child(washitsu)
	var entrance := EntranceScript.new()
	entrance.name = "Entrance"
	entrance.position = ENTRANCE_POS
	entrance.rotation.y = PI
	add_child(entrance)
	_build_bath_bulb()
	_build_bathtub()
	_build_toilet()
	_build_sink_and_mirror()
	_build_vent()
	_build_floor_drain()
	_build_bath_bucket()
	_build_knob()
	shower_curtain = ShowerCurtainScript.new()
	shower_curtain.name = "ShowerCurtain"
	add_child(shower_curtain)
	bathtub.curtain = shower_curtain
	_build_towel()
	_build_bath_powder()
	# トイレまわりの生活用品（ペーパーホルダー・棚の予備ロールと洗剤・ラバーカップとブラシ・点検シール）
	supplies = SuppliesScript.new()
	supplies.name = "Supplies"
	add_child(supplies)
	_build_paper()   # ドライバーは床に落ちていない：入浴剤の玉の中（bathtub.gd）
	_build_door()
	# 経年感の汚れ・傷（見た目だけ。設備がすべてできてから貼る）
	var wear := BathWearScript.new()
	wear.name = "BathWear"
	add_child(wear)
	FigureStickersScript.paste(self)   # 置物の絵のシールを、排水口のまわりなどにペタペタ貼る
	var ambient := AmbientSoundScript.new()   # 換気扇・しずく・遠くの路地（コードで作った小さな環境音）
	ambient.name = "AmbientSound"
	add_child(ambient)


# ---------------------------------------------------------------- 宮殿のしつらえ

static var _pw: ImageTexture
static var _pf: ImageTexture


## 深紅の壁：ダマスク織り風の、ひし形の格子と小さな花（うすく浮き出す）。
static func _palace_wall_tex() -> ImageTexture:
	if _pw == null:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		var base := Color(0.3, 0.035, 0.05)
		for y in n:
			for x in n:
				var u := float(x) / n
				var v := float(y) / n
				var d := absf(fposmod(u + v, 0.5) - 0.25) + absf(fposmod(u - v, 0.5) - 0.25)   # ひし形の格子
				var c := base
				if d < 0.05:
					c = base.lightened(0.1)
				var fx := fposmod(u, 0.5) - 0.25
				var fy := fposmod(v, 0.5) - 0.25
				if fx * fx + fy * fy < 0.0035:
					c = base.lightened(0.14)
				elif fx * fx + fy * fy < 0.009:
					c = base.darkened(0.12)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_pw = ImageTexture.create_from_image(img)
	return _pw


## 床：黒と深紅の市松模様の大理石、金の目地。
static func _palace_floor_tex() -> ImageTexture:
	if _pf == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		var noise := FastNoiseLite.new()
		noise.frequency = 0.035
		noise.seed = 3
		noise.fractal_octaves = 4
		for y in n:
			for x in n:
				var cx := int(x * 2 / n)
				var cy := int(y * 2 / n)
				var black := (cx + cy) % 2 == 0
				var v := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var vein := absf(noise.get_noise_2d(x * 1.6 + 40.0, y * 1.6)) < 0.04   # 大理石の筋
				var c: Color
				if black:
					c = Color(0.045, 0.04, 0.045).lightened(0.06 * v)
					if vein:
						c = Color(0.35, 0.3, 0.2)
				else:
					c = Color(0.84, 0.8, 0.72).darkened(0.12 * v)
					if vein:
						c = Color(0.55, 0.5, 0.42)
				var gx := x % (n / 2) < 1 or x % (n / 2) > n / 2 - 2
				var gy := y % (n / 2) < 1 or y % (n / 2) > n / 2 - 2
				if gx or gy:
					c = Color(0.12, 0.1, 0.08)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_pf = ImageTexture.create_from_image(img)
	return _pf


static var _pm: ImageTexture


## 腰壁の黒い大理石：黒地に、うっすら金と白の筋。
static func _palace_marble_tex() -> ImageTexture:
	if _pm == null:
		var n := 256
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		var noise := FastNoiseLite.new()
		noise.frequency = 0.02
		noise.seed = 21
		noise.fractal_octaves = 5
		for y in n:
			for x in n:
				var v := noise.get_noise_2d(x, y)
				var c := Color(0.035, 0.03, 0.035).lightened(0.05 * (v * 0.5 + 0.5))
				var vein := absf(v) < 0.025
				if vein:
					c = Color(0.5, 0.4, 0.2)
				elif absf(v - 0.3) < 0.012:
					c = Color(0.3, 0.28, 0.26)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_pm = ImageTexture.create_from_image(img)
	return _pm


## 壁の腰（黒い漆の羽目板）と金のモールディング、天井ぎわの金の縁。
var painting_map: Node3D


## 奥の壁の、ひまわりの絵（上へスライドすると、後ろに 5 階の地図）。
func _build_painting() -> void:
	painting_map = PaintingMapScript.new()
	painting_map.position = Vector3(-0.5, 1.42, -ROOM_D * 0.5 + 0.004)
	add_child(painting_map)


## ドア枠の脇の壁（浴室の内側）の、身長計のシール（130〜170 cm）。調べると、目の高さを変えられることを教える。
func _build_height_gauge() -> void:
	var g := Node3D.new()
	g.name = "HeightGauge"
	g.position = Vector3(-0.62, 0.0, ROOM_D * 0.5 - 0.002)
	add_child(g)
	var paper := _mat("gauge_paper", Color(0.95, 0.9, 0.75), 0.9)
	_mesh_box(g, Vector3(0.1, 0.5, 0.002), Vector3(0, 1.5, 0), paper)
	var ink := _mat("gauge_ink", Color(0.2, 0.1, 0.08), 0.9)
	for k in 5:
		var y := 1.3 + 0.1 * k
		_mesh_box(g, Vector3(0.05, 0.004, 0.003), Vector3(-0.015, y, -0.001), ink)
		var l := Label3D.new()
		l.text = str(130 + 10 * k)
		l.pixel_size = 0.0007
		l.font_size = 40
		l.modulate = Color(0.2, 0.1, 0.08)
		l.shaded = false
		l.position = Vector3(0.02, y, -0.0025)
		l.rotation.y = PI   # 壁は +z 側。部屋の中（-z）へ向ける
		g.add_child(l)
	# 家族の記録：鉛筆の線と、日付（背が伸びた跡）
	var pencil := _mat("gauge_pencil", Color(0.35, 0.35, 0.38), 0.9)
	var marks := [[1.02, "5歳"], [1.18, "小3"], [1.36, "中1"], [1.52, "高1"]]
	for mk in marks:
		_mesh_box(g, Vector3(0.04, 0.003, 0.003), Vector3(0.0, mk[0], -0.001), pencil)
		var pl := Label3D.new()
		pl.text = mk[1]
		pl.pixel_size = 0.0005
		pl.font_size = 36
		pl.modulate = Color(0.3, 0.3, 0.34)
		pl.shaded = false
		pl.position = Vector3(-0.035, mk[0] + 0.012, -0.0025)
		pl.rotation.y = PI
		g.add_child(pl)
	_mesh_box(g, Vector3(0.1, 1.0, 0.0015), Vector3(0, 1.27, 0.0005), paper)
	var a := MeshKit.interact_area(g, "GaugeArea", "height_gauge", null)
	MeshKit.shape_box(a, Vector3(0.14, 0.6, 0.08), Vector3(0, 1.5, -0.04))


## 壁に貼る、金の細い四角い枠（羽目板の飾り）。on_side：左の壁（x 方向に貼る）か奥の壁か。
func _panel_frame(parent: Node3D, c: Vector3, on_side: bool, m: Material, w: float, h: float) -> void:
	var t := 0.012
	var d := 0.002
	if on_side:
		_mesh_box(parent, Vector3(d, t, w), c + Vector3(0, h * 0.5, 0), m)
		_mesh_box(parent, Vector3(d, t, w), c - Vector3(0, h * 0.5, 0), m)
		_mesh_box(parent, Vector3(d, h, t), c + Vector3(0, 0, w * 0.5), m)
		_mesh_box(parent, Vector3(d, h, t), c - Vector3(0, 0, w * 0.5), m)
	else:
		_mesh_box(parent, Vector3(w, t, d), c + Vector3(0, h * 0.5, 0), m)
		_mesh_box(parent, Vector3(w, t, d), c - Vector3(0, h * 0.5, 0), m)
		_mesh_box(parent, Vector3(t, h, d), c + Vector3(w * 0.5, 0, 0), m)
		_mesh_box(parent, Vector3(t, h, d), c - Vector3(w * 0.5, 0, 0), m)


func _build_palace_trim() -> void:
	var trim := Node3D.new()
	trim.name = "PalaceTrim"
	add_child(trim)
	var gold := _mat("palace_frame_gold", GOLD, 0.3, 0.75)
	var lacquer := MeshKit.tiled_mat("palace_marble", _palace_marble_tex(), 0.7, Color(1, 1, 1), 0.25)
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var wh := 0.9   # 腰壁の高さ
	var t := 0.004
	# 奥の壁・左の壁の腰壁（右の壁は鏡裏収納の開口があるので、開口より下の黒い帯だけ）
	# 腰壁は、壁にぴったり貼る（紙・ステッカー・傷など、壁に貼った物の下に隠れない薄さ）
	var tw := 0.0005
	_mesh_box(trim, Vector3(ROOM_W, wh, tw), Vector3(0, wh * 0.5, -hd + tw * 0.5), lacquer)
	_mesh_box(trim, Vector3(tw, wh, ROOM_D), Vector3(-hw + tw * 0.5, wh * 0.5, 0), lacquer)
	_mesh_box(trim, Vector3(ROOM_W, 0.03, 0.012), Vector3(0, wh + 0.015, -hd + 0.009), gold)
	_mesh_box(trim, Vector3(0.012, 0.03, ROOM_D), Vector3(-hw + 0.009, wh + 0.015, 0), gold)
	# 腰壁の、金の縁取りの羽目板（四角い枠）
	for pz in [-0.7, 0.0, 0.7]:
		_panel_frame(trim, Vector3(-hw + 0.0012, 0.45, pz), true, gold, 0.5, 0.5)
	for px in [-0.55, 0.0, 0.55]:
		_panel_frame(trim, Vector3(px, 0.45, -hd + 0.0012), false, gold, 0.42, 0.5)
	# 巾木（金）
	_mesh_box(trim, Vector3(ROOM_W, 0.08, 0.01), Vector3(0, 0.04, -hd + 0.008), gold)
	_mesh_box(trim, Vector3(0.01, 0.08, ROOM_D), Vector3(-hw + 0.008, 0.04, 0), gold)
	# 天井ぎわの金の縁（4 辺）。鏡裏収納の開口より上
	var cy := ROOM_H - 0.045
	_mesh_box(trim, Vector3(ROOM_W, 0.09, 0.03), Vector3(0, cy, -hd + 0.015), gold)
	_mesh_box(trim, Vector3(0.03, 0.09, ROOM_D), Vector3(-hw + 0.015, cy, 0), gold)
	_mesh_box(trim, Vector3(0.03, 0.09, ROOM_D), Vector3(hw - 0.015, cy, 0), gold)
	_mesh_box(trim, Vector3(ROOM_W, 0.09, 0.03), Vector3(0, cy, hd - 0.015), gold)
	# 汚れの絵は、ぜんぶ隠す（清潔に）
	var wear := get_node_or_null("BathWear")
	if wear:
		for g in ["Walls", "Floor", "Fixtures"]:
			var gn := wear.get_node_or_null(g)
			if gn:
				(gn as Node3D).visible = false


# ---------------------------------------------------------------- トイレのシャンデリア（電球の代わり）


var bulb_present := true         # シャンデリアの電球（外せる。外すと、トイレの中は真っ暗）
var _bulb_node: MeshInstance3D
var bulb_area: Area3D


func _build_bath_bulb() -> void:
	# 宮殿の大シャンデリア（天井から吊る。直径 1.6m）：三段の枝、曲がった金の腕、クリスタルの房と飾り紐、中央の大きなしずく。
	# 灯りの色の変わり方（白／青）は、電球のときと同じ。影は落とさない。
	var fixture := Node3D.new()
	fixture.name = "BathBulb"
	fixture.position = BULB_POS
	add_child(fixture)
	var gold := _mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	var gold_dark := _mat("palace_gold_dark", Color(0.6, 0.45, 0.16), 0.3, 0.85)
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(1.0, 0.95, 0.8)
	_bulb_mat.emission_enabled = true
	_apply_bath_light()
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.9, 0.95, 1.0, 0.6)
	crystal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal.roughness = 0.03
	crystal.metallic = 0.3
	crystal.emission_enabled = true
	crystal.emission = Color(0.8, 0.88, 1.0)
	crystal.emission_energy_multiplier = 0.25   # きらめき（灯りの色には影響しない）
	# 天井の飾り板と、鎖
	MeshKit.cylinder(fixture, 0.24, 0.03, Vector3(0, 0.015, 0), gold, "CeilingRose", 0.14, 32)
	MeshKit.cylinder(fixture, 0.1, 0.02, Vector3(0, -0.005, 0), gold_dark, "RoseInner", 0.06, 24)
	MeshKit.cylinder(fixture, 0.012, 0.1, Vector3(0, -0.06, 0), gold, "Chain", -1.0, 8)
	# 中央の柱：金の玉をいくつも重ねる
	var cy := -0.1
	for k in 4:
		var r := 0.05 + 0.012 * (k % 2)
		MeshKit.sphere(fixture, r, Vector3(0, cy, 0), gold)
		cy -= r * 1.6
	# 三段の枝（広い段・中の段・小さな段）。腕は、外へ向かって、下がってから、上へ反る（4 つの短い筒でつなぐ）
	var tiers := [[0.8, -0.14, 12, 0.0], [0.5, -0.2, 8, PI / 8.0], [0.26, -0.26, 6, PI / 6.0]]
	var outer_ends: Array = []
	for ti in tiers.size():
		var tr: float = tiers[ti][0]
		var ty: float = tiers[ti][1]
		var n: int = tiers[ti][2]
		var off: float = tiers[ti][3]
		for i in n:
			var ang := TAU * float(i) / float(n) + off
			var dir := Vector3(cos(ang), 0, sin(ang))
			var prev := Vector3(0, ty + 0.03, 0)
			for sgi in 4:
				var u := float(sgi + 1) / 4.0
				var pt := dir * tr * u + Vector3(0, ty + 0.03 * (1.0 - u) - 0.045 * sin(PI * u) + 0.07 * u * u, 0)
				var seg := MeshKit.cylinder(fixture, 0.008, prev.distance_to(pt), (prev + pt) * 0.5, gold, "Arm%d_%d_%d" % [ti, i, sgi], -1.0, 6)
				var d := (pt - prev).normalized()
				seg.basis = Basis(Quaternion(Vector3.UP, d)) if absf(d.dot(Vector3.UP)) < 0.999 else Basis.IDENTITY
				MeshKit.sphere(fixture, 0.012, pt, gold)
				prev = pt
			# 先の受け皿と、ろうそく形の灯り
			MeshKit.cylinder(fixture, 0.03, 0.02, prev + Vector3(0, 0.0, 0), gold, "Cup%d_%d" % [ti, i], 0.014, 12)
			var wax := MeshKit.cylinder(fixture, 0.012, 0.05, prev + Vector3(0, 0.035, 0), MeshKit.mat("chand_wax", Color(0.96, 0.93, 0.85), 0.6), "Wax", -1.0, 8)
			wax.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var fl := MeshKit.sphere(fixture, 0.016, prev + Vector3(0, 0.075, 0), _bulb_mat)
			fl.scale = Vector3(0.75, 1.6, 0.75)
			if ti == 0:
				outer_ends.append(prev)
			# 腕から下がる、クリスタルのしずく（段ごとに 3 つ、長さをかえる）
			for k in 3:
				var cp := dir * (tr * (0.45 + 0.22 * k)) + Vector3(0, ty - 0.02 - 0.03 * k, 0)
				MeshKit.cylinder(fixture, 0.0018, 0.06, cp + Vector3(0, 0.03, 0), gold, "Wire", -1.0, 4)
				var drop := MeshKit.sphere(fixture, 0.02, cp - Vector3(0, 0.02 + 0.02 * float(k % 2), 0), crystal)
				drop.scale = Vector3(0.6, 2.2, 0.6)
	# 外側の輪（金の細い輪）と、輪から垂れる、クリスタルの飾り紐（隣の先端どうしを、たるませてつなぐ）
	var m := outer_ends.size()
	for i in m:
		var p1: Vector3 = outer_ends[i]
		var p2: Vector3 = outer_ends[(i + 1) % m]
		var bar := MeshKit.cylinder(fixture, 0.005, p1.distance_to(p2), (p1 + p2) * 0.5, gold, "RingBar", -1.0, 6)
		var bd := (p2 - p1).normalized()
		bar.basis = Basis(Quaternion(Vector3.UP, bd)) if absf(bd.dot(Vector3.UP)) < 0.999 else Basis.IDENTITY
		for k in 1:  # 輪の上の、大きなしずく
			var mid := (p1 + p2) * 0.5 + Vector3(0, -0.05, 0)
			var big := MeshKit.sphere(fixture, 0.022, mid, crystal)
			big.scale = Vector3(0.7, 2.4, 0.7)
		for k in 6:   # 飾り紐：小さな玉を、たるませて並べる
			var u2 := float(k + 1) / 7.0
			var pb := p1.lerp(p2, u2) + Vector3(0, -0.07 * sin(PI * u2) - 0.03, 0)
			var bead := MeshKit.sphere(fixture, 0.01, pb, crystal)
			bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 中央に、大きなしずく型クリスタルの束（いちばん下は、頭より十分高く）
	for i in 7:
		var a2 := TAU * float(i) / 7.0
		var rp := 0.09 if i > 0 else 0.0
		var pos := Vector3(cos(a2) * rp, -0.3 + (0.0 if i == 0 else 0.03), sin(a2) * rp)
		MeshKit.cylinder(fixture, 0.002, 0.05, pos + Vector3(0, 0.03, 0), gold, "Wire", -1.0, 4)
		var pend := MeshKit.sphere(fixture, 0.03, pos - Vector3(0, 0.03, 0), crystal)
		pend.scale = Vector3(0.55, 2.0 if i == 0 else 1.6, 0.55)
	# 影は落とさない（回る枝の影が、壁に大きな黒い形になって、見づらいので）
	for mi in fixture.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 中央の大きな電球（外せる）
	_bulb_node = MeshKit.sphere(fixture, 0.075, Vector3(0, -0.2, 0), _bulb_mat)
	_bulb_node.name = "Bulb"
	_bulb_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb_area = MeshKit.interact_area(fixture, "BulbArea", "chandelier", null)
	MeshKit.shape_box(bulb_area, Vector3(0.4, 0.3, 0.4), Vector3(0, -0.2, 0))
	bulb_area.set_meta("interact_range", 2.6)


## 電球を外す／はめる。外すと、トイレの中は真っ暗（灯りも環境光も消える）。
func _process(delta: float) -> void:
	# シャンデリアは、ゆっくり回る
	var fx := get_node_or_null("BathBulb") as Node3D
	if fx:
		fx.rotation.y += delta * 0.12


func set_bulb(present: bool) -> void:
	bulb_present = present
	_bulb_node.visible = present
	_apply_bath_light()


## トイレの中にいるとき、電球がなければ環境光を落とす（毎フレーム呼ぶ。変わったときだけ反映）。
func update_bulb_darkness(in_unit: bool) -> void:
	if sky_clock == null:
		return
	var want := 0.01 if (not bulb_present and in_unit) else 1.0
	if not is_equal_approx(sky_clock.unit_dark, want):
		sky_clock.unit_dark = want
		sky_clock.set_time(sky_clock.time)


func _apply_bath_light() -> void:
	var col := PURPLE_LIGHT_COLOR if bath_purple else BATH_LIGHT_COLOR
	bath_light.light_color = col
	var lit := bath_light_on and bulb_present
	bath_light.light_energy = (1.2 if bath_purple else BATH_LIGHT_ENERGY) if lit else 0.0
	_bulb_mat.emission = col
	_bulb_mat.emission_energy_multiplier = 3.0 if lit else 0.0
	_bulb_mat.albedo_color = Color(0.75, 0.55, 1.0) if (bath_purple and lit) else (Color(1.0, 0.95, 0.8) if lit else Color(0.8, 0.8, 0.78))


## 自室のスイッチから呼ばれる。電気を入り切りして、表示する文章のキーを返す。
## 消してからつけ直すのを PURPLE_AFTER 回くり返すと、紫色になる（そのあとはずっと紫）。
func set_bath_light(on: bool) -> String:
	if on == bath_light_on:
		return ""
	bath_light_on = on
	var key := "bath_light_off"
	if on:
		bath_light_cycles += 1
		key = "bath_light_on"
		# PURPLE_AFTER 回ごとに、青い光と白い光が入れ替わる
		if bath_light_cycles % PURPLE_AFTER == 0:
			bath_purple = not bath_purple
			key = "bath_light_purple" if bath_purple else "bath_light_normal"
		elif bath_purple:
			key = "bath_light_on_purple"
	_apply_bath_light()
	if on and not bulb_present:
		return "bath_light_nobulb"
	if on and (key == "bath_light_purple" or key == "bath_light_normal"):
		# ちらつきながら紫に変わる
		var tw := create_tween()
		for i in 3:
			tw.tween_callback(func() -> void: bath_light.light_energy = 0.0)
			tw.tween_interval(0.07)
			tw.tween_callback(func() -> void: bath_light.light_energy = (1.2 if bath_purple else BATH_LIGHT_ENERGY) if bulb_present else 0.0)
			tw.tween_interval(0.09)
	return key


# ---------------------------------------------------------------- 公開API

func remove_driver() -> void:
	if driver_node and is_instance_valid(driver_node):
		driver_node.queue_free()
	driver_node = null


## 換気口の格子の蓋を開ける（奥側の辺を軸に下へ垂れる）。開けたまま（再プレイで閉じる）。
func open_vent() -> void:
	if vent_open:
		return
	vent_open = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(vent_cover, "rotation:x", deg_to_rad(95.0), 0.35)


## 棚の入浴剤（ユブロマン）を取る。
func take_bath_powder() -> void:
	bath_powder_taken = true
	var node: Node3D = get_node("BathPowder")
	node.visible = false
	(node.get_node("Collision") as StaticBody3D).collision_layer = 0


# ---------------------------------------------------------------- 浴室がせり上がる

## 点検レバーを引いたあと。浴室と換気ダクトを RISE_H だけ持ち上げる（約 8 秒、ゴゴゴ）。player も一緒に上げる。
## instant：セーブからの復元用（アニメーションなしで、上がったあとの状態にする）。
func rise_unit(player: Node3D, instant := false) -> void:
	if risen or rising:
		return
	rising = true
	if apartment:
		apartment.window_locked = true   # 浴室がせり上がったあと、ベランダの窓は施錠（部屋の鍵で開く）
	_unit.clear()
	for c in get_children():
		if c is Node3D and not UNIT_EXCLUDE.has(String(c.name)):
			_unit.append([c, (c as Node3D).position.y])
	for n in ["Duct", "DuctLight"]:
		var d := exterior.get_node_or_null(n)
		if d is Node3D:
			_unit.append([d, (d as Node3D).position.y])
	_build_pedestal()
	set_power(false, instant)
	_rise_player = player
	if instant:
		_apply_rise(1.0)
		_finish_rise()
		return
	Sfx.play("rumble")
	_build_rise_effects()
	if "controls_enabled" in player:
		player.controls_enabled = false
	var tw := create_tween()
	tw.tween_method(_apply_rise, 0.0, 1.0, RISE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_finish_rise)


func _apply_rise(t: float) -> void:
	var target := RISE_H * t
	var d := target - rise_offset
	rise_offset = target
	for e in _unit:
		(e[0] as Node3D).position.y = float(e[1]) + target
	if _rise_player and d != 0.0:
		_rise_player.global_position.y += d
	_update_pedestal()
	if _rise_player and rising and t < 1.0 and "camera" in _rise_player:
		var a := 0.012 * sin(t * PI)   # 山なりに強くなる揺れ
		var cam: Camera3D = _rise_player.camera
		cam.h_offset = randf_range(-a, a)
		cam.v_offset = randf_range(-a, a)
	if _smoke:
		_smoke.position.y = rise_offset - 0.1
	for c in _cracks:
		if not (c[0] as Node3D).visible and rise_offset > float(c[1]):
			(c[0] as Node3D).visible = true
			Sfx.play("crack", 0.6 + randf() * 0.5, -6.0)
	if t > 0.72 and not _door_broken:
		_break_door()


func _finish_rise() -> void:
	rising = false
	risen = true
	if _smoke:
		_smoke.emitting = false
		get_tree().create_timer(4.0).timeout.connect(func() -> void:
			if _smoke:
				_smoke.queue_free()
				_smoke = null)
	for c in _cracks:
		(c[0] as Node3D).visible = true
	if _rise_player and "camera" in _rise_player:
		var cam: Camera3D = _rise_player.camera
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		if "controls_enabled" in _rise_player:
			_rise_player.controls_enabled = true
	# 扉のあった開口の前に、体だけを止める透明な板（照準は通る）。ホールの床は約 0.9m 下に見えるが、出られない
	var blocker := StaticBody3D.new()
	blocker.name = "DoorwayBlocker"
	blocker.collision_layer = MeshKit.LAYER_BODY_ONLY
	blocker.collision_mask = 0
	blocker.position = Vector3(0.0, RISE_H + 1.1, ROOM_D * 0.5)
	add_child(blocker)
	MeshKit.shape_box(blocker, Vector3(DOOR_W + 0.3, 2.4, 0.12), Vector3.ZERO)
	_build_hatch()
	_build_wine_cellar()
	apartment.open_hall_ceiling()      # ホールの天井が抜ける（扉の外を見下ろせる）
	exterior.set_exit_rise(RISE_H)     # 換気ダクトの出口の穴を、上がった高さへ
	bath_light.omni_range = 8.0        # 上がった浴室の電球は、遠く下のホールまで、扉から漏れて届く
	unit_risen.emit()


## せり上がりの演出：もうもうとした煙（浴室の底のまわり）と、柱・ホールの床に走るひび割れ。
var _smoke: CPUParticles3D
var _cracks: Array = []   # [node, 見えはじめる浴室の上がった高さ]


func _build_rise_effects() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.name = "RiseSmoke"
	_smoke.amount = 160
	_smoke.lifetime = 3.2
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(ROOM_W * 0.5 + 0.2, 0.05, ROOM_D * 0.5 + 0.2)
	_smoke.direction = Vector3(0, 1, 0.6)
	_smoke.spread = 40.0
	_smoke.initial_velocity_min = 0.2
	_smoke.initial_velocity_max = 0.7
	_smoke.gravity = Vector3(0, 0.1, 0.1)
	_smoke.scale_amount_min = 0.8
	_smoke.scale_amount_max = 1.8
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(0.72, 0.7, 0.66, 0.0), Color(0.72, 0.7, 0.66, 0.2), Color(0.6, 0.58, 0.55, 0.0)])
	_smoke.color_ramp = grad
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1, 1, 1, 1)
	sm.material = mat
	_smoke.mesh = sm
	_smoke.position = Vector3(0, 0.0, 0.0)
	add_child(_smoke)
	_smoke.emitting = true
	# ひび：ホールの床（浴室の前）と、柱のホール側の面
	_cracks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var fz := ROOM_D * 0.5 + WALL_T
	for k in 7:   # 床
		var root := Node3D.new()
		root.position = Vector3(rng.randf_range(-ROOM_W * 0.5, ROOM_W * 0.5), 0.012, fz + 0.1 + rng.randf() * 0.5)
		root.visible = false
		add_child(root)
		_crack_line(root, rng, Vector3(rng.randf_range(-0.6, 0.6), 0, 1.0).normalized(), rng.randf_range(0.5, 1.1), true)
		_cracks.append([root, 0.1 + k * 0.1])
	for k in 8:   # 柱の面（ホールの床から立ち上がる）
		var root2 := Node3D.new()
		root2.position = Vector3(rng.randf_range(-0.55, 0.9), rng.randf_range(0.25, RISE_H - 0.3), fz - 0.015)
		root2.visible = false
		add_child(root2)
		_crack_line(root2, rng, Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.5, 1.0), 0).normalized(), rng.randf_range(0.3, 0.8), false)
		_cracks.append([root2, root2.position.y + 0.15])


## ひび割れ 1 本：少しずつ向きを変える細い板を、つなげる。flat なら床（xz）、そうでなければ柱の面（xy）。
func _crack_line(parent: Node3D, rng: RandomNumberGenerator, dir: Vector3, length: float, flat: bool) -> void:
	var dark := _mat("crack_dark", Color(0.05, 0.05, 0.06), 1.0)
	var pos := Vector3.ZERO
	var n := 5
	var d := dir
	for i in n:
		var seg := length / n
		var bm := BoxMesh.new()
		bm.size = Vector3(seg, 0.012, 0.006) if flat else Vector3(seg, 0.006, 0.006)
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = dark
		parent.add_child(mi)
		mi.position = pos + d * seg * 0.5
		var ang := atan2(d.z, d.x) if flat else atan2(d.y, d.x)
		if flat:
			mi.rotation.y = -ang
		else:
			mi.rotation.z = ang
		pos += d * seg
		var wob := rng.randf_range(-0.6, 0.6)
		d = (d.rotated(Vector3.UP if flat else Vector3.BACK, wob)).normalized()
		# 枝分かれ
		if i == 2:
			var br := Node3D.new()
			br.position = pos
			parent.add_child(br)
			var bd := d.rotated(Vector3.UP if flat else Vector3.BACK, 0.9 * (1.0 if rng.randf() > 0.5 else -1.0)).normalized()
			var seg2 := length * 0.15
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(seg2, 0.012, 0.006) if flat else Vector3(seg2, 0.006, 0.006)
			var m2 := MeshInstance3D.new()
			m2.mesh = bm2
			m2.material_override = dark
			br.add_child(m2)
			m2.position = bd * seg2 * 0.5
			var a2 := atan2(bd.z, bd.x) if flat else atan2(bd.y, bd.x)
			if flat:
				m2.rotation.y = -a2
			else:
				m2.rotation.z = a2


## 浴室の下の柱（暗いコンクリート）。上がるにつれ、上端が浴室の底について伸びる。
func _build_pedestal() -> void:
	_pedestal = MeshInstance3D.new()
	_pedestal.name = "Pedestal"
	_pedestal.mesh = BoxMesh.new()
	_pedestal.material_override = MeshKit.mat("pedestal", Color(0.17, 0.17, 0.19), 0.9)
	add_child(_pedestal)
	_update_pedestal()


func _update_pedestal() -> void:
	if _pedestal == null:
		return
	var bm := _pedestal.mesh as BoxMesh
	bm.size = Vector3(ROOM_W + WALL_T * 2.0 - 0.04, rise_offset + 1.0, ROOM_D + WALL_T * 2.0 - 0.04)
	_pedestal.position = Vector3(0, (rise_offset - 1.0) * 0.5, 0)


## はしご：和室で拾ったはしごを、ホールから浮き上がった浴室へ立てかける（上り下りできる）。
var ladder_node: Node3D
var ladder_placed := false
const LADDER_TOP := Vector3(0.0, 2.3, 1.31)


func place_ladder() -> void:
	if ladder_placed:
		return
	ladder_placed = true
	ladder_node = Node3D.new()
	ladder_node.name = "PlacedLadder"
	ladder_node.position = Vector3(0.0, 0.0, 1.8)
	ladder_node.rotation.x = deg_to_rad(-12.0)
	add_child(ladder_node)
	ladder_node.add_child(Stage4ItemsRef.ladder_model())
	var a := MeshKit.interact_area(ladder_node, "PlacedLadderArea", "ladder_placed")
	MeshKit.shape_box(a, Vector3(0.5, 2.3, 0.2), Vector3(0, 1.15, 0))


## お酒のセラー：せり上がった浴室の下の柱（ホール側の面）に、はめ込まれている。ただの飾り。射的でヒビだけ入り、九蓮宝燈を出すと割れる。
var wine_cellar: Node3D
var cellar_broken := false   # 九蓮宝燈で割れた（セラーができる前に出しても、あとで割れた姿で現れる）
var cellar_cracks := 0


func _build_wine_cellar() -> void:
	wine_cellar = LiquorCellarScript.new()
	wine_cellar.position = Vector3(-0.9, 0.26, ROOM_D * 0.5 + WALL_T - 0.02)   # 柱の面（左寄り。右には小さな扉）。床につかない高さ
	add_child(wine_cellar)
	var lamp := wine_cellar.get_node("LiquorLight") as OmniLight3D
	_power_energy[lamp] = lamp.light_energy
	if not power_on:   # せり上がりと同時に停電しているので、できたときから消えている
		lamp.light_energy = 0.0
	if cellar_broken or cellar_cracks > 0:
		wine_cellar.restore(cellar_broken, cellar_cracks)


## 九蓮宝燈：セラーのガラスが割れる。まだ柱が現れていなければ、現れたときに割れている。
func break_wine_cellar() -> void:
	cellar_broken = true
	if wine_cellar:
		wine_cellar.break_glass()


## ホール側の柱の面に、小さな扉（ドアノブの穴だけがある）。ドアノブをつけて（F）開ける。中にヒューズがあり、拾える。入れはしない。
var hatch_open := false
var fuse_taken := false
var _hatch_door: Node3D
var _fuse_prop: Node3D
var _fuse_area: Area3D
const FuseItems := preload("res://scripts/stage3_items.gd")


## 壊れたドアノブ：玄関ホールの床に転がっている（浴室が上がったあと、扉の外に見えるが、届かない。ホールに下りて拾う）。
var knob_node: Node3D
var knob_taken := false


func _build_knob() -> void:
	knob_node = Node3D.new()
	knob_node.name = "DoorKnob"
	knob_node.position = Vector3(0.25, 0.03, 1.8)
	add_child(knob_node)
	var model := FuseItems.knob_model()
	model.rotation = Vector3(0, 0.6, deg_to_rad(80.0))
	knob_node.add_child(model)
	var area := MeshKit.interact_area(knob_node, "DoorKnobArea", "door_knob")
	MeshKit.shape_box(area, Vector3(0.2, 0.1, 0.12), Vector3.ZERO)


func take_door_knob() -> void:
	knob_taken = true
	if knob_node:
		knob_node.visible = false
		var a := knob_node.get_node_or_null("DoorKnobArea") as Area3D
		if a:
			a.collision_layer = 0


func _build_hatch() -> void:
	var h := Node3D.new()
	h.name = "FuseHatch"
	h.position = Vector3(0.45, 0.4, ROOM_D * 0.5 + WALL_T - 0.02)
	add_child(h)
	# 枠と、扉の奥のくぼみ（暗い）。くぼみの中にヒューズ
	_mesh_box(h, Vector3(0.5, 0.55, 0.02), Vector3.ZERO, _mat("hatch_frame", Color(0.1, 0.1, 0.11), 0.7))
	_mesh_box(h, Vector3(0.42, 0.47, 0.02), Vector3(0, 0, 0.012), _mat("hatch_inside", Color(0.02, 0.02, 0.03), 1.0))
	_fuse_prop = Node3D.new()
	_fuse_prop.name = "Fuse"
	_fuse_prop.position = Vector3(0.0, -0.1, 0.03)
	_fuse_prop.visible = false
	h.add_child(_fuse_prop)
	_fuse_prop.add_child(FuseItems.fuse_model())
	_fuse_area = MeshKit.interact_area(_fuse_prop, "FuseArea", "fuse")
	_fuse_area.collision_layer = 0
	MeshKit.shape_box(_fuse_area, Vector3(0.12, 0.08, 0.1), Vector3.ZERO)
	# 扉（右の端が蝶番）。ノブの穴がある
	_hatch_door = Node3D.new()
	_hatch_door.name = "HatchDoor"
	_hatch_door.position = Vector3(0.21, 0.0, 0.022)
	h.add_child(_hatch_door)
	_mesh_box(_hatch_door, Vector3(0.42, 0.47, 0.02), Vector3(-0.21, 0, 0), _mat("hatch_panel", Color(0.33, 0.3, 0.27), 0.8))
	var socket := MeshKit.cylinder(_hatch_door, 0.014, 0.03, Vector3(-0.36, 0.0, 0.014), _mat("hatch_socket", Color(0.02, 0.02, 0.02), 1.0), "Socket")
	socket.rotation.x = PI * 0.5
	var area := MeshKit.interact_area(h, "FuseHatchArea", "fuse_hatch")
	MeshKit.shape_box(area, Vector3(0.5, 0.55, 0.08), Vector3(0, 0, 0.03))


## ドアノブをつけて、小さな扉を開ける。
func open_hatch(instant := false) -> void:
	if hatch_open:
		return
	hatch_open = true
	if not fuse_taken:
		_fuse_prop.visible = true
		_fuse_area.collision_layer = MeshKit.LAYER_INTERACT
	if instant:
		_hatch_door.rotation.y = deg_to_rad(100.0)
		return
	Sfx.play("click")
	create_tween().tween_property(_hatch_door, "rotation:y", deg_to_rad(100.0), 0.7).set_trans(Tween.TRANS_SINE)


## ヒューズを拾った（見た目と判定を消す）。
func take_fuse() -> void:
	fuse_taken = true
	_fuse_prop.visible = false
	_fuse_area.collision_layer = 0


## 扉がバキッと壊れる：破片がホールへ飛び、枠にギザギザが残り、木の棒が足元に落ちる。
func _break_door() -> void:
	_door_broken = true
	door_pivot.visible = false
	door_body.collision_layer = 0
	door_area.collision_layer = 0
	if door_body.has_meta("interact_id"):
		door_body.remove_meta("interact_id")
	Sfx.play("thunk", 0.6, 2.0)
	Sfx.play("crack", 0.7)
	var wood := _mat("debris_wood", Color(0.58, 0.46, 0.33), 0.85)
	var rng := RandomNumberGenerator.new()
	rng.seed = 903
	var debris := Node3D.new()
	debris.name = "DoorDebris"
	add_child(debris)
	var from := Vector3(0.0, rise_offset + 1.0, ROOM_D * 0.5 + 0.1)
	for i in 9:
		var piece := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.06, 0.3), rng.randf_range(0.02, 0.05), rng.randf_range(0.04, 0.16))
		piece.mesh = bm
		piece.material_override = wood
		piece.position = from + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.5, 0.6), 0.0)
		debris.add_child(piece)
		var land := Vector3(rng.randf_range(-0.8, 0.8), 0.03 + bm.size.y * 0.5, rng.randf_range(1.5, 2.3))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(piece, "position:x", land.x, 0.85)
		tw.tween_property(piece, "position:z", land.z, 0.85)
		tw.tween_property(piece, "position:y", land.y, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(piece, "rotation", Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), rng.randf_range(-3, 3)), 0.85)
	# 枠に残る、ギザギザの板（蝶番の側。浴室といっしょに上がる）
	var shards := Node3D.new()
	shards.name = "BrokenDoor"
	shards.position = Vector3(0, rise_offset, 0)
	add_child(shards)
	for k in 4:
		var shard := _mesh_box(shards, Vector3(0.05, rng.randf_range(0.35, 0.8), 0.03), Vector3(-0.34 + rng.randf_range(0.0, 0.1), 0.4 + k * 0.1, ROOM_D * 0.5 + 0.05), wood)
		shard.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5))
	_unit.append([shards, 0.0])
	# 木の棒（足元に落ちている。拾える）
	wood_stick = Node3D.new()
	wood_stick.name = "WoodStick"
	wood_stick.position = Vector3(-0.1, rise_offset + 0.03, 0.95)
	add_child(wood_stick)
	var stick := MeshKit.cylinder(wood_stick, 0.018, 0.7, Vector3.ZERO, wood, "Stick", 0.014, 8)
	stick.rotation = Vector3(0, 0.3, PI * 0.5)
	var area := MeshKit.interact_area(wood_stick, "WoodStickArea", "wood_stick")
	MeshKit.shape_box(area, Vector3(0.75, 0.08, 0.14), Vector3.ZERO)
	_unit.append([wood_stick, 0.03])


## 木の棒を拾った（見た目と判定を消す）。
func take_wood_stick() -> void:
	if wood_stick and is_instance_valid(wood_stick):
		wood_stick.visible = false
		var a := wood_stick.get_node_or_null("WoodStickArea") as Area3D
		if a:
			a.collision_layer = 0


## 自室とホールの電気を切る（停電）／戻す。ユニット専用の浴室の電球は別系統で、そのまま。
func set_power(on: bool, instant := false) -> void:
	power_on = on
	# 浴室の電球（RoomLight。ユニット専用）は対象外。ホールの灯り、自室の灯り、家電の明かり（押入れ・UFOキャッチャー・こたつ・水槽）を消す
	var lights: Array = [get_node_or_null("HallLight")]
	if apartment:
		for pat in ["RoomLight*", "ClosetLight", "InnerLight", "HeaterLight", "TankLight"]:
			lights.append_array(apartment.find_children(pat, "OmniLight3D", true, false))
	lights.append_array(find_children("LiquorLight", "OmniLight3D", true, false))   # ホールのお酒のセラーの明かり（room の子）
	for l in lights:
		if l == null:
			continue
		if not _power_energy.has(l):
			_power_energy[l] = (l as OmniLight3D).light_energy
		var target: float = float(_power_energy[l]) if on else 0.0
		if instant:
			(l as OmniLight3D).light_energy = target
		else:
			create_tween().tween_property(l, "light_energy", target, 0.6)
	if apartment and not on and apartment.has_method("set_tv_on"):
		apartment.set_tv_on(false)
	# 環境光も落とす：遮光カーテンが閉まっていて、電気もないので、自室とホールは真っ暗（浴室の電球と、窓の外の街の灯りだけ）
	if sky_clock:
		var scale: float = 1.0 if on else BLACKOUT_AMBIENT
		if instant:
			sky_clock.ambient_scale = scale
			sky_clock.set_time(sky_clock.time)
		else:
			create_tween().tween_method(func(v: float) -> void:
				sky_clock.ambient_scale = v
				sky_clock.set_time(sky_clock.time), sky_clock.ambient_scale, scale, 1.2)


## 停電中のカーテンの開け閉め：開けると、月明かりで部屋の輪郭がうっすら見える（環境光をほんの少し戻す）。
const MOONLIGHT_AMBIENT := 0.06


func set_moonlight(on: bool) -> void:
	if power_on or sky_clock == null:
		return
	var target := MOONLIGHT_AMBIENT if on else BLACKOUT_AMBIENT
	create_tween().tween_method(func(v: float) -> void:
		sky_clock.ambient_scale = v
		sky_clock.set_time(sky_clock.time), sky_clock.ambient_scale, target, 1.0)


## 鍵のかかったドアのノブを回す：ガチャガチャと鳴って、ドアが小刻みに揺れる。
func rattle_door() -> void:
	if door_busy or _door_broken or door_pivot == null:
		return
	door_busy = true
	for k in 3:
		Sfx.play("clunk", 1.5 + k * 0.1, -4.0)
		await get_tree().create_timer(0.11).timeout
	var tw := create_tween()
	for k in 6:
		tw.tween_property(door_pivot, "rotation:y", deg_to_rad(1.6 if k % 2 == 0 else -1.2), 0.04)
	tw.tween_property(door_pivot, "rotation:y", 0.0, 0.05)
	tw.tween_callback(func() -> void: door_busy = false)


func open_door() -> void:
	door_unlocked = true
	door_swung = true
	door_busy = true
	door_area.collision_layer = LAYER_INTERACT
	if door_body.has_meta("interact_id"):
		door_body.remove_meta("interact_id")
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(door_pivot, "rotation:y", deg_to_rad(DOOR_OPEN_DEG), 1.2)
	# 開ききったら扉の当たり判定をなくす。開いた扉はホールの左側（玄関ドアの側）を体の幅で通れなくするため、
	# 扉をすり抜けられるようにしている（見た目の扉は残る）
	tween.tween_callback(func() -> void:
		door_busy = false
		if door_swung:
			door_body.collision_layer = 0)


## 直したドアを開けたり閉めたりする（クリック）。閉まっている間は体を止める当たり判定が戻る。
func toggle_door() -> void:
	if door_busy or not door_unlocked:
		return
	door_busy = true
	door_swung = not door_swung
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if door_swung:
		Sfx.play("creak")
		tween.tween_property(door_pivot, "rotation:y", deg_to_rad(DOOR_OPEN_DEG), 0.9)
		tween.tween_callback(func() -> void:
			door_busy = false
			if door_swung:
				door_body.collision_layer = 0)
	else:
		door_body.collision_layer = LAYER_WORLD   # 閉め始めた時点で、扉の体の判定を戻す
		tween.tween_property(door_pivot, "rotation:y", 0.0, 0.9)
		tween.tween_callback(func() -> void:
			Sfx.play("thunk")
			door_busy = false)


# ---------------------------------------------------------------- 環境・光

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.44)   # sky_clock が空の絵に切り替える（絵が読めなかったときの色）
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 電球色（2700〜3000K 相当）で少し薄暗いユニットバス。環境光も暖色にして、影が真っ黒にならないようにする
	env.ambient_light_color = Color(0.8, 0.77, 0.72)
	env.ambient_light_energy = 0.36
	# 明るい白い設備が白飛びして輪郭が消えないよう、トーンマッピングで明るい部分をなだらかに抑える
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	# プレイ時間による空模様（昼 → 夕焼け → 夕暮れ）。時間は main.gd が渡す
	sky_clock = SkyClockScript.new()
	sky_clock.name = "SkyClock"
	add_child(sky_clock)
	sky_clock.setup(env)

	var room_light := OmniLight3D.new()
	bath_light = room_light
	room_light.name = "RoomLight"
	# 少し入口寄りに置き、設備の手前側の面を照らして奥・下に影を落とす（影はこの1灯だけ）
	room_light.position = Vector3(0.15, 2.05, 0.35)   # 電球（BULB_POS）の少し下
	room_light.light_color = Color(1.0, 0.8, 0.55)   # 夜の電球色
	room_light.light_energy = 0.8
	room_light.omni_range = 4.0
	room_light.shadow_enabled = true
	room_light.shadow_bias = 0.03
	add_child(room_light)

	var hall_light := OmniLight3D.new()
	hall_light.name = "HallLight"
	hall_light.position = Vector3(0.0, 2.05, 1.85)
	hall_light.light_color = Color(1.0, 0.92, 0.8)
	hall_light.light_energy = 1.0
	hall_light.omni_range = 3.0
	hall_light.shadow_enabled = false
	add_child(hall_light)


# ---------------------------------------------------------------- 部屋の外殻

func _build_shell() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	var shell := Node3D.new()
	shell.name = "Shell"
	add_child(shell)

	# 壁：薄いアイボリー／床：少し暗いグレー／設備：白（PORCELAIN）で明度差をつける
	var wall_mat := MeshKit.tiled_mat("palace_wall", _palace_wall_tex(), 0.3, Color(1, 1, 1), 0.55)
	# 床：暖かいグレージュの色はそのまま、細かい粒の模様だけ足す
	var floor_mat := MeshKit.tiled_mat("palace_floor", _palace_floor_tex(), 0.8, Color(1, 1, 1), 0.18)
	floor_mat.metallic = 0.12
	var ceil_mat := _mat("palace_ceiling", Color(0.24, 0.16, 0.08), 0.75)

	var outer_w := ROOM_W + WALL_T * 2.0
	var outer_d := ROOM_D + WALL_T * 2.0
	var half_w := ROOM_W * 0.5
	var half_d := ROOM_D * 0.5

	_static_box(shell, "Floor", Vector3(outer_w, WALL_T, outer_d), Vector3(0, -WALL_T * 0.5, 0), floor_mat)
	# 天井：換気口の格子の内側（ExteriorScript.VENT_HOLE）に穴を空け、奥の換気経路へつなぐ
	var hole: Rect2 = ExteriorScript.VENT_HOLE
	var cy := ROOM_H + WALL_T * 0.5
	var cx0 := -outer_w * 0.5
	var cx1 := outer_w * 0.5
	var cz0 := -outer_d * 0.5
	var cz1 := outer_d * 0.5
	_static_box(shell, "CeilingL", Vector3(hole.position.x - cx0, WALL_T, outer_d), Vector3((cx0 + hole.position.x) * 0.5, cy, 0), ceil_mat)
	_static_box(shell, "CeilingR", Vector3(cx1 - hole.end.x, WALL_T, outer_d), Vector3((hole.end.x + cx1) * 0.5, cy, 0), ceil_mat)
	_static_box(shell, "CeilingBack", Vector3(hole.size.x, WALL_T, hole.position.y - cz0), Vector3(hole.get_center().x, cy, (cz0 + hole.position.y) * 0.5), ceil_mat)
	_static_box(shell, "CeilingFront", Vector3(hole.size.x, WALL_T, cz1 - hole.end.y), Vector3(hole.get_center().x, cy, (hole.end.y + cz1) * 0.5), ceil_mat)
	_static_box(shell, "WallBack", Vector3(outer_w, ROOM_H, WALL_T), Vector3(0, ROOM_H * 0.5, -half_d - WALL_T * 0.5), wall_mat)
	_static_box(shell, "WallLeft", Vector3(WALL_T, ROOM_H, ROOM_D), Vector3(-half_w - WALL_T * 0.5, ROOM_H * 0.5, 0), wall_mat)
	# 右の壁は鏡裏収納の開口（MirrorCabinetScript.Y_RANGE × Z_RANGE）を空けて4枚に分ける
	var rx := half_w + WALL_T * 0.5
	var oy: Vector2 = MirrorCabinetScript.Y_RANGE
	var oz: Vector2 = MirrorCabinetScript.Z_RANGE
	_static_box(shell, "WallRightLow", Vector3(WALL_T, oy.x, ROOM_D), Vector3(rx, oy.x * 0.5, 0), wall_mat)
	_static_box(shell, "WallRightHigh", Vector3(WALL_T, ROOM_H - oy.y, ROOM_D), Vector3(rx, (oy.y + ROOM_H) * 0.5, 0), wall_mat)
	_static_box(shell, "WallRightBack", Vector3(WALL_T, oy.y - oy.x, oz.x + half_d), Vector3(rx, (oy.x + oy.y) * 0.5, (-half_d + oz.x) * 0.5), wall_mat)
	_static_box(shell, "WallRightFront", Vector3(WALL_T, oy.y - oy.x, half_d - oz.y), Vector3(rx, (oy.x + oy.y) * 0.5, (oz.y + half_d) * 0.5), wall_mat)

	# 前の壁（入口ドアの開口部を空ける）
	var front_z := half_d + WALL_T * 0.5
	var side_w := (outer_w - DOOR_W) * 0.5
	_static_box(shell, "WallFrontL", Vector3(side_w, ROOM_H, WALL_T), Vector3(-(DOOR_W * 0.5 + side_w * 0.5), ROOM_H * 0.5, front_z), wall_mat)
	_static_box(shell, "WallFrontR", Vector3(side_w, ROOM_H, WALL_T), Vector3(DOOR_W * 0.5 + side_w * 0.5, ROOM_H * 0.5, front_z), wall_mat)
	var top_h := ROOM_H - DOOR_H
	_static_box(shell, "WallFrontTop", Vector3(DOOR_W, top_h, WALL_T), Vector3(0, DOOR_H + top_h * 0.5, front_z), wall_mat)

	# ドア枠（見た目のみ）
	var frame_mat := _mat("palace_frame_gold", GOLD, 0.3, 0.75)
	var frame := Node3D.new()
	frame.name = "DoorFrame"
	shell.add_child(frame)
	_mesh_box(frame, Vector3(0.04, DOOR_H, WALL_T + 0.02), Vector3(-DOOR_W * 0.5 - 0.02, DOOR_H * 0.5, front_z), frame_mat)
	_mesh_box(frame, Vector3(0.04, DOOR_H, WALL_T + 0.02), Vector3(DOOR_W * 0.5 + 0.02, DOOR_H * 0.5, front_z), frame_mat)
	_mesh_box(frame, Vector3(DOOR_W + 0.08, 0.04, WALL_T + 0.02), Vector3(0, DOOR_H + 0.02, front_z), frame_mat)
	MeshKit.auto_round = true

func _build_wall_details() -> void:
	MeshKit.auto_round = false   # 外殻は角を丸めない（合わせ目に溝が出ないように）
	# 樹脂パネルの縦の継ぎ目と、隅・床際のゴム目地。見た目だけ（当たり判定なし）
	var details := Node3D.new()
	details.name = "WallDetails"
	add_child(details)
	var seam_mat := _mat("seam", SEAM_COLOR, 0.9)
	var caulk_mat := _mat("caulk", CAULK_COLOR, 0.95)
	var half_w := ROOM_W * 0.5
	var half_d := ROOM_D * 0.5
	var seam_w := 0.006
	var seam_t := 0.004
	var door_clear := DOOR_W * 0.5 + 0.06   # ドア開口の近くには継ぎ目を置かない

	# 縦の継ぎ目：壁の長さを PANEL_TARGET_W 前後の等幅パネルに分ける
	var oy: Vector2 = MirrorCabinetScript.Y_RANGE
	var oz: Vector2 = MirrorCabinetScript.Z_RANGE
	for pos in _seam_positions(ROOM_D):   # 左右の壁（z 方向）
		_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(-half_w + DETAIL_GAP + seam_t * 0.5, ROOM_H * 0.5, pos), seam_mat)
		var rx := half_w - DETAIL_GAP - seam_t * 0.5
		if pos > oz.x - 0.02 and pos < oz.y + 0.02:   # 鏡裏収納の開口にかかる継ぎ目は、開口の上下だけ
			var top := MirrorCabinetScript.TRIM_W
			_mesh_box(details, Vector3(seam_t, oy.x - top, seam_w), Vector3(rx, (oy.x - top) * 0.5, pos), seam_mat)
			_mesh_box(details, Vector3(seam_t, ROOM_H - oy.y - top, seam_w), Vector3(rx, (oy.y + top + ROOM_H) * 0.5, pos), seam_mat)
		else:
			_mesh_box(details, Vector3(seam_t, ROOM_H, seam_w), Vector3(rx, ROOM_H * 0.5, pos), seam_mat)
	for pos in _seam_positions(ROOM_W):   # 奥・手前の壁（x 方向）
		_mesh_box(details, Vector3(seam_w, ROOM_H, seam_t), Vector3(pos, ROOM_H * 0.5, -half_d + DETAIL_GAP + seam_t * 0.5), seam_mat)
		if absf(pos) > door_clear:
			_mesh_box(details, Vector3(seam_w, ROOM_H, seam_t), Vector3(pos, ROOM_H * 0.5, half_d - DETAIL_GAP - seam_t * 0.5), seam_mat)

	# 部屋の四隅の縦目地（隅に収まる細い角材）
	var c := 0.012
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh_box(details, Vector3(c, ROOM_H, c), Vector3(sx * (half_w - c * 0.5), ROOM_H * 0.5, sz * (half_d - c * 0.5)), caulk_mat)

	# 床と壁の境目の目地（下端は床に少し沈めて隙間を出さない）
	var h := 0.014
	var t := 0.008
	var y := h * 0.5 - 0.002
	_mesh_box(details, Vector3(t, h, ROOM_D), Vector3(-half_w + t * 0.5, y, 0.0), caulk_mat)
	_mesh_box(details, Vector3(t, h, ROOM_D), Vector3(half_w - t * 0.5, y, 0.0), caulk_mat)
	_mesh_box(details, Vector3(ROOM_W, h, t), Vector3(0.0, y, -half_d + t * 0.5), caulk_mat)
	var side := half_w - DOOR_W * 0.5   # 手前の壁はドア開口を避けて左右に分ける
	_mesh_box(details, Vector3(side, h, t), Vector3(-half_w + side * 0.5, y, half_d - t * 0.5), caulk_mat)
	_mesh_box(details, Vector3(side, h, t), Vector3(half_w - side * 0.5, y, half_d - t * 0.5), caulk_mat)


## 長さ length の壁を PANEL_TARGET_W 前後の等幅パネルに分けたときの継ぎ目の位置（中心 0 基準）。
	MeshKit.auto_round = true

func _seam_positions(length: float) -> Array:
	var count := maxi(1, roundi(length / PANEL_TARGET_W))
	var result := []
	for i in range(1, count):
		result.append(-length * 0.5 + length * i / count)
	return result


# ---------------------------------------------------------------- 設備

func _build_bathtub() -> void:
	# 奥の壁沿い。幅いっぱい、奥行き0.75、高さ0.55。くぼみ・水・栓・蛇口は bathtub.gd
	bathtub = BathtubScript.new()
	bathtub.name = "Bathtub"
	bathtub.position = Vector3(0.0, 0.0, -ROOM_D * 0.5 + BathtubScript.HALF.z)
	add_child(bathtub)
	# 給湯器の浴室リモコン：浴槽の右横の壁（x=0.9）、高さ1.05m。部屋側（-x）を向く
	bath_remote = BathRemoteScript.new()
	bath_remote.name = "BathRemote"
	bath_remote.setup(bathtub)
	bath_remote.position = Vector3(ROOM_W * 0.5, 1.05, -0.75)
	bath_remote.rotation.y = -PI * 0.5
	add_child(bath_remote)


func _build_toilet() -> void:
	# 左の壁沿い。タンクを壁につけ、便器は +x 方向（部屋の中央）を向く。蓋と便座の開閉は toilet.gd
	toilet = ToiletScript.new()
	toilet.name = "Toilet"
	add_child(toilet)
	# 操作パネル：便座の左横（座った本人の左下、浴槽側 -z）。上面 y=0.43
	toilet_panel = ToiletPanelScript.new()
	toilet_panel.name = "ToiletPanel"
	toilet_panel.setup(toilet)
	toilet_panel.position = Vector3(-0.42, 0.43, -0.23)
	add_child(toilet_panel)


func _build_sink_and_mirror() -> void:
	# 右の壁の洗面台（くぼみ・栓・貯水と排水・蛇口・排水管）は sink.gd、鏡裏収納は mirror_cabinet.gd
	sink = SinkScript.new()
	sink.name = "Sink"
	add_child(sink)
	sink_faucet = sink.faucet
	_build_sink_shelf(SinkScript.WALL_X, SinkScript.Z)
	mirror_cabinet = MirrorCabinetScript.new()
	mirror_cabinet.name = "MirrorCabinet"
	add_child(mirror_cabinet)


func _build_sink_shelf(wx: float, z: float) -> void:
	# 鏡の下の小さな棚：歯ブラシ立て・歯ブラシ2本・キャップ付きの歯磨き粉（架空の無地）。見た目だけ
	var shelf := Node3D.new()
	shelf.name = "SinkShelf"
	add_child(shelf)
	var top := 1.075
	_mesh_box(shelf, Vector3(0.11, 0.015, 0.44), Vector3(wx - 0.055, top - 0.0075, z), MeshKit.tiled_mat("shelf_laminate", LAMINATE_TEX, 0.3, Color.WHITE, 0.45))
	var cup_pos := Vector3(wx - 0.055, top, z + 0.16)
	MeshKit.cylinder(shelf, 0.03, 0.09, cup_pos + Vector3(0, 0.045, 0), _mat("cup", Color(0.62, 0.8, 0.7), 0.5), "Cup", 0.033)
	var brushes := [[Color(0.2, 0.45, 0.85), -12.0, -0.01], [Color(0.9, 0.45, 0.6), 14.0, 0.01]]
	for b in brushes:
		var brush := Node3D.new()
		brush.name = "Toothbrush"
		brush.position = cup_pos + Vector3(0, 0.01, b[2])
		brush.rotation = Vector3(deg_to_rad(b[1]), 0.0, deg_to_rad(-8.0))
		shelf.add_child(brush)
		var handle_mat := _mat("brush_%s" % b[0].to_html(false), b[0], 0.4)
		_mesh_box(brush, Vector3(0.012, 0.17, 0.008), Vector3(0, 0.085, 0), handle_mat)
		_mesh_box(brush, Vector3(0.012, 0.025, 0.012), Vector3(-0.006, 0.16, 0), _mat("bristle", Color(0.97, 0.97, 0.97), 0.9))
	# 髭剃り：棚の上に寝かせた T 字の剃刀（見た目＋調べる判定）
	var razor := Node3D.new()
	razor.name = "Razor"
	razor.position = Vector3(wx - 0.05, top + 0.006, z + 0.15)
	shelf.add_child(razor)
	var razor_handle := MeshKit.cylinder(razor, 0.006, 0.11, Vector3.ZERO, _mat("razor", Color(0.25, 0.4, 0.75), 0.4), "Handle")
	razor_handle.rotation.x = deg_to_rad(90.0)
	MeshKit.box(razor, Vector3(0.038, 0.01, 0.012), Vector3(0, 0.002, -0.058), _mat("razor_head", Color(0.85, 0.86, 0.88), 0.3, 0.6), "Head")
	var razor_area := MeshKit.interact_area(razor, "RazorArea", "razor")
	MeshKit.shape_box(razor_area, Vector3(0.05, 0.03, 0.13), Vector3(0, 0.005, -0.005))
	# 歯磨き粉：棚の上に寝かせたチューブ（キャップ側 r=0.015 → 潰した端 r=0.012 の先細り）。
	# ラベル画像はチューブの正面（部屋側の斜め上）に約200°巻く。裏側は画像の地色に近い単色、キャップは青の単色
	var tube := Node3D.new()
	tube.name = "Toothpaste"
	tube.position = Vector3(wx - 0.06, top + 0.015, z - 0.06)
	tube.rotation.x = deg_to_rad(90.0)
	shelf.add_child(tube)
	var body_mat := _mat("paste_body", Color(0.96, 0.95, 0.91), 0.5)
	MeshKit.cylinder(tube, 0.015, 0.12, Vector3.ZERO, body_mat, "Body", 0.012)
	# 帯の範囲：チューブのローカル y -0.05〜0.04（上 = 潰した端、下 = キャップ側。縦書きの上がつぶした端）
	var y0 := -0.05
	var y1 := 0.04
	var r0 := lerpf(0.015, 0.012, (y0 + 0.06) / 0.12) + 0.0006   # 本体より 0.6mm 外側
	var r1 := lerpf(0.015, 0.012, (y1 + 0.06) / 0.12) + 0.0006
	# 幅 = 高さ 0.09 × 縦横比 271/512 ≒ 0.048m → 平均半径 0.0137m で約 200°
	var span := (y1 - y0) * (271.0 / 512.0) / ((r0 + r1) * 0.5)
	var label := MeshInstance3D.new()
	label.name = "Label"
	label.mesh = MeshKit.band(r0, r1, y1 - y0, deg_to_rad(135.0), span, 24)
	label.material_override = _texture_mat("toothpaste_label", TOOTHPASTE_TEX, 0.5)
	label.position = Vector3(0, (y0 + y1) * 0.5, 0)
	tube.add_child(label)
	MeshKit.cylinder(tube, 0.009, 0.018, Vector3(0, -0.069, 0), _mat("paste_cap", Color(0.15, 0.32, 0.68), 0.4), "Cap")
	_mesh_box(tube, Vector3(0.03, 0.012, 0.004), Vector3(0, 0.066, 0), body_mat)


func _build_bath_bucket() -> void:
	# 風呂桶：浴槽と洗面台の間の床の隅（右の壁際）。調べられる。体を止める判定はない（小さいので）
	var root := Node3D.new()
	root.name = "BathBucket"
	root.position = Vector3(0.74, 0.0, -0.31)
	add_child(root)
	var plastic := MeshKit.mat("bucket", Color(0.62, 0.78, 0.86), 0.35)
	var r := BUCKET_R
	var h := BUCKET_H
	MeshKit.cylinder(root, r * 0.88, 0.008, Vector3(0, 0.004, 0), plastic, "Bottom", -1.0, 24)
	# 側面：内側が見えるよう、少し広がった筒を薄い帯で作る（底は上の円板）
	for k in 24:
		var a := TAU * k / 24.0
		var seg := MeshKit.box(root, Vector3(0.006, h, 2.0 * r * sin(PI / 24.0) + 0.004), Vector3(cos(a) * r * 0.94, h * 0.5, sin(a) * r * 0.94), plastic)
		seg.rotation = Vector3(0, -a, deg_to_rad(-6.0))
	var rim := TorusMesh.new()
	rim.inner_radius = r - 0.004
	rim.outer_radius = r + 0.006
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = plastic
	rim_mi.position = Vector3(0, h, 0)
	root.add_child(rim_mi)
	var area := MeshKit.interact_area(root, "BucketArea", "bath_bucket")
	MeshKit.shape_box(area, Vector3(r * 2.0, h, r * 2.0), Vector3(0, h * 0.5, 0))


## 風呂桶を拾った（見た目と判定を消す）。
func take_bucket() -> void:
	bucket_taken = true
	var n := get_node_or_null("BathBucket") as Node3D
	if n:
		n.visible = false
		var a := n.get_node_or_null("BucketArea") as Area3D
		if a:
			a.collision_layer = 0


## 風呂桶を逆さにして、浴槽の底（入ったときの足元）に置く。上に乗ると、目の高さが BUCKET_H だけ上がり、天井の換気口に手が届く。
func place_bucket_in_tub() -> void:
	if bucket_in_tub:
		return
	bucket_in_tub = true
	var n := Node3D.new()
	n.name = "BucketInTub"
	n.position = BUCKET_TUB_LOCAL
	bathtub.add_child(n)
	var plastic := MeshKit.mat("bucket", Color(0.62, 0.78, 0.86), 0.35)
	MeshKit.cylinder(n, BUCKET_R * 0.94, BUCKET_H, Vector3(0, BUCKET_H * 0.5, 0), plastic, "Body", BUCKET_R * 0.88, 24)   # 逆さ：ふちが下、底が上
	MeshKit.cylinder(n, BUCKET_R * 0.9, 0.008, Vector3(0, BUCKET_H + 0.002, 0), MeshKit.mat("bucket_top", Color(0.52, 0.68, 0.78), 0.4), "Top", -1.0, 24)
	var rim := TorusMesh.new()
	rim.inner_radius = BUCKET_R - 0.004
	rim.outer_radius = BUCKET_R + 0.008
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = plastic
	rim_mi.position = Vector3(0, 0.008, 0)
	n.add_child(rim_mi)


func _build_floor_drain() -> void:
	# 浴室の床の排水口（浴槽の排水とは別。床に流れた水用）。格子の隙間から暗い穴が見える。見た目だけ
	var drain := Node3D.new()
	drain.name = "FloorDrain"
	drain.position = Vector3(-0.15, 0.0, -0.33)
	add_child(drain)
	var metal := _mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9)
	var s := 0.1
	var fw := 0.008
	_mesh_box(drain, Vector3(s - fw * 2.0, 0.001, s - fw * 2.0), Vector3(0, 0.0015, 0), _mat("drain_hole", Color(0.05, 0.05, 0.06), 1.0))
	for sd in [-1.0, 1.0]:
		_mesh_box(drain, Vector3(s, 0.004, fw), Vector3(0, 0.002, sd * (s - fw) * 0.5), metal)
		_mesh_box(drain, Vector3(fw, 0.004, s - fw * 2.0), Vector3(sd * (s - fw) * 0.5, 0.002, 0), metal)
	for i in 5:
		var x := -0.034 + 0.017 * i
		_mesh_box(drain, Vector3(0.004, 0.003, s - fw * 2.0), Vector3(x, 0.0025, 0), metal)


func _build_towel() -> void:
	# 左の壁、便器と入口の間のタオル掛け。クリックでタオルが横へずれ、裏の傷が見える（towel.gd）
	towel = TowelScript.new()
	towel.name = "TowelBar"
	towel.position = Vector3(-ROOM_W * 0.5, 1.15, 0.72)
	add_child(towel)


func _build_vent() -> void:
	# 天井の奥・左の隅（浴槽の上）の小さな換気口。
	#   Vent/Visual/Frame … オフホワイトの枠（天井に固定）
	#   Vent/Visual/Cover … 暗い内部＋格子の蓋。原点を奥側の辺に置き、将来ここを軸に開けられる
	#   Vent/Collision    … 調べる対象（interact_range で操作距離を個別に設定）
	var f := _fixture("Vent", "vent")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	body.set_meta("interact_range", VENT_RANGE)
	var s := VENT_SIZE
	var center := Vector3(-ROOM_W * 0.5 + 0.06 + s * 0.5, ROOM_H, -ROOM_D * 0.5 + 0.06 + s * 0.5)
	visual.position = center
	body.position = center

	var frame := Node3D.new()
	frame.name = "Frame"
	visual.add_child(frame)
	var frame_mat := _mat("vent_frame", Color(0.9, 0.89, 0.85), 0.7)
	var fw := 0.02    # 枠の幅
	var fh := 0.012   # 枠の厚み（天井から下に出る分）
	var fy := -fh * 0.5
	_mesh_box(frame, Vector3(s, fh, fw), Vector3(0, fy, -s * 0.5 + fw * 0.5), frame_mat)
	_mesh_box(frame, Vector3(s, fh, fw), Vector3(0, fy, s * 0.5 - fw * 0.5), frame_mat)
	_mesh_box(frame, Vector3(fw, fh, s - fw * 2.0), Vector3(-s * 0.5 + fw * 0.5, fy, 0), frame_mat)
	_mesh_box(frame, Vector3(fw, fh, s - fw * 2.0), Vector3(s * 0.5 - fw * 0.5, fy, 0), frame_mat)

	var cover := Node3D.new()
	vent_cover = cover
	cover.name = "Cover"
	cover.position = Vector3(0, 0, -s * 0.5 + fw)   # 蝶番にする奥側の辺
	visual.add_child(cover)
	var inner := s - fw * 2.0
	# 奥の暗がり（天井面から 3mm 下げ、天井とのちらつきを避ける）
	_mesh_box(cover, Vector3(inner, 0.002, inner), Vector3(0, -0.004, inner * 0.5), _mat("vent_dark", Color(0.12, 0.12, 0.13), 1.0))
	# 格子（枠より少し奥）
	var grille_mat := _mat("vent_grille", Color(0.6, 0.6, 0.58), 0.6)
	var slats := 7
	for i in slats:
		var x := -inner * 0.5 + inner * (i + 0.5) / slats
		_mesh_box(cover, Vector3(0.006, 0.006, inner), Vector3(x, -0.009, inner * 0.5), grille_mat)

	_shape_box(body, Vector3(s, 0.03, s), Vector3(0, -0.015, 0))


func _build_bath_powder() -> void:
	# タンクの上の壁の棚（supplies.gd、上面 y=1.35）に置く粉末入浴剤の容器。
	# タンクの蓋を開けられるよう、TASK-07 でタンクの上から棚へ移した。
	#   BathPowder/Visual/Body  … 本体の円筒（クリーム色の蓋とは別ノード）
	#   BathPowder/Visual/Label … ラベル専用の帯。UV を自前で巻き、文字のある中央を +x（通路側）、継ぎ目を壁側に向ける
	#   BathPowder/Visual/Lid   … 蓋（将来開けられるよう別ノード）
	var f := _fixture("BathPowder", "bath_powder")
	var visual: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var base := Vector3(SuppliesScript.WALL_X + SuppliesScript.SHELF_DEPTH * 0.5, SuppliesScript.SHELF_TOP, SuppliesScript.POWDER_Z)
	visual.position = base
	body.position = base

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = POWDER_RADIUS
	body_mesh.bottom_radius = POWDER_RADIUS
	body_mesh.height = POWDER_HEIGHT
	body_mesh.radial_segments = 32
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = body_mesh
	body_mi.material_override = _mat("powder_body", Color(0.93, 0.72, 0.55), 0.6)
	body_mi.position = Vector3(0, POWDER_HEIGHT * 0.5, 0)
	visual.add_child(body_mi)

	var label := MeshInstance3D.new()
	label.name = "Label"
	label.mesh = _label_band(POWDER_RADIUS + 0.001, LABEL_HEIGHT, 48)
	label.material_override = _texture_mat("powder_label", LABEL_TEX, 0.6)
	label.position = Vector3(0, POWDER_HEIGHT * 0.5, 0)
	visual.add_child(label)

	var lid_mesh := CylinderMesh.new()
	lid_mesh.top_radius = LID_RADIUS
	lid_mesh.bottom_radius = LID_RADIUS
	lid_mesh.height = LID_HEIGHT
	lid_mesh.radial_segments = 32
	var lid := MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = lid_mesh
	lid.material_override = _mat("powder_lid", Color(0.96, 0.93, 0.82), 0.5)
	lid.position = Vector3(0, POWDER_HEIGHT + LID_HEIGHT * 0.5, 0)
	visual.add_child(lid)

	var shape := CylinderShape3D.new()
	shape.radius = LID_RADIUS
	shape.height = POWDER_HEIGHT + LID_HEIGHT
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, (POWDER_HEIGHT + LID_HEIGHT) * 0.5, 0)
	body.add_child(cs)


## 入浴剤のラベル帯：一周巻き、u=0.5（文字のある中央）を +x（通路側）、継ぎ目を -x（壁側）に向ける。
func _label_band(radius: float, height: float, segments: int) -> ArrayMesh:
	return MeshKit.band(radius, radius, height, 0.0, TAU, segments)


const PAPER_POS := Vector3(-0.897, 1.65, 0.45)   # 左の壁に貼ったメモ（鏡文字）
const PAPER_TEXT := "Everything goes\ndown the drain.\n\nFLUSH"


## 鏡文字のメモの見た目。mirrored が true なら裏返し（そのままでは読めない）。
static func paper_model(mirrored: bool) -> Node3D:
	var n := Node3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.17)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.95, 0.94, 0.88)
	pm.roughness = 0.9
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sheet := MeshInstance3D.new()
	sheet.mesh = q
	sheet.material_override = pm
	n.add_child(sheet)
	var label := Label3D.new()
	label.text = PAPER_TEXT
	label.font_size = 36
	label.pixel_size = 0.0018
	label.modulate = Color(0.1, 0.1, 0.14)
	label.outline_size = 0
	label.shaded = false
	label.double_sided = true
	label.position = Vector3(0, 0, 0.002)
	label.scale.x = -1.0 if mirrored else 1.0
	n.add_child(label)
	return n


func _build_paper() -> void:
	var f := _fixture("MirrorPaper", "mirror_paper")
	var vis: Node3D = f[0]
	var body: StaticBody3D = f[1]
	var paper := paper_model(true)
	paper.rotation.y = PI * 0.5   # 表を部屋側（+x）へ
	vis.position = PAPER_POS
	vis.add_child(paper)
	body.position = PAPER_POS
	_shape_box(body, Vector3(0.02, 0.19, 0.14), Vector3.ZERO)
	paper_fixture = f[0].get_parent()


func take_paper() -> void:
	paper_taken = true
	if paper_fixture and is_instance_valid(paper_fixture):
		paper_fixture.queue_free()
	paper_fixture = null


func _build_driver() -> void:
	# 洗面台の下の床。照準で狙いやすいよう、判定を見た目より少し大きくしている
	driver_node = Node3D.new()
	driver_node.name = "Screwdriver"
	# 実寸：柄 長さ10cm・直径3.2cm、軸 長さ11cm・直径6mm。床に寝かせ、柄の下端が床に接する
	driver_node.position = Vector3(ROOM_W * 0.5 - 0.3, 0.0, 0.05)
	driver_node.rotation.y = deg_to_rad(25.0)
	add_child(driver_node)

	var visual := Node3D.new()
	visual.name = "Visual"
	driver_node.add_child(visual)
	var handle_r := 0.016
	var axis_y := handle_r   # 柄の中心の高さ
	# 柄は床の灰色・設備の白と区別できる赤橙。洗面台の影でも見えるよう弱く自己発光させる
	var handle_mat := _mat("handle", Color(0.92, 0.22, 0.05), 0.5)
	handle_mat.emission_enabled = true
	handle_mat.emission = Color(0.92, 0.22, 0.05)
	handle_mat.emission_energy_multiplier = 0.25
	_mesh_cylinder_x(visual, handle_r, 0.1, Vector3(-0.05, axis_y, 0.0), handle_mat)
	_mesh_cylinder_x(visual, handle_r + 0.001, 0.015, Vector3(-0.07, axis_y, 0.0), _mat("grip", Color(0.08, 0.08, 0.08), 0.8))
	_mesh_cylinder_x(visual, handle_r + 0.001, 0.015, Vector3(-0.03, axis_y, 0.0), _mat("grip", Color(0.08, 0.08, 0.08), 0.8))
	_mesh_cylinder_x(visual, 0.003, 0.11, Vector3(0.055, axis_y, 0.0), _mat("palace_gold_metal", Color(0.92, 0.74, 0.32), 0.2, 0.9))

	var area := Area3D.new()
	area.name = "Pickup"
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interact_id", "driver")
	driver_node.add_child(area)
	_shape_box(area, Vector3(0.28, 0.1, 0.14), Vector3(0.0, 0.03, 0.0))


func _build_door() -> void:
	# 蝶番は開口部の左端。外側（+z）へ開く
	var front_z := ROOM_D * 0.5 + WALL_T * 0.5
	door_pivot = Node3D.new()
	door_pivot.name = "DoorPivot"
	door_pivot.position = Vector3(-DOOR_W * 0.5, 0.0, front_z)
	add_child(door_pivot)

	var visual := Node3D.new()
	visual.name = "Visual"
	door_pivot.add_child(visual)
	var panel_size := Vector3(DOOR_W - 0.01, DOOR_H - 0.01, 0.04)
	var panel_center := Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0.0)
	_mesh_box(visual, panel_size, panel_center, _mat("palace_door", BLACK_LACQUER, 0.25, 0.1))
	for pz in [-0.021, 0.021]:   # 扉の金の縁取りと、赤い飾り板
		_mesh_box(visual, Vector3(DOOR_W - 0.16, DOOR_H - 0.3, 0.004), Vector3(DOOR_W * 0.5, DOOR_H * 0.5, pz), _mat("palace_door_red", Color(0.45, 0.05, 0.07), 0.4))
		_mesh_box(visual, Vector3(DOOR_W - 0.12, 0.014, 0.006), Vector3(DOOR_W * 0.5, DOOR_H - 0.14, pz), _mat("palace_frame_gold", GOLD, 0.3, 0.75))
		_mesh_box(visual, Vector3(DOOR_W - 0.12, 0.014, 0.006), Vector3(DOOR_W * 0.5, 0.14, pz), _mat("palace_frame_gold", GOLD, 0.3, 0.75))
	var knob_mat := _mat("knob", Color(0.9, 0.7, 0.25), 0.25, 0.9)
	_mesh_box(visual, Vector3(0.05, 0.05, 0.06), Vector3(DOOR_W - 0.08, 0.95, -0.05), knob_mat)
	_mesh_box(visual, Vector3(0.05, 0.05, 0.06), Vector3(DOOR_W - 0.08, 0.95, 0.05), knob_mat)

	door_body = StaticBody3D.new()
	door_body.name = "Collision"
	door_body.collision_layer = LAYER_WORLD
	door_body.collision_mask = 0
	door_body.set_meta("interact_id", "door")
	door_pivot.add_child(door_body)
	_shape_box(door_body, panel_size, panel_center)
	# 直したあとの開け閉め用の判定（最初は無効。扉と一緒に回る）
	var control := BathDoorControlScript.new()
	control.name = "DoorControl"
	control.room = self
	add_child(control)
	door_area = Area3D.new()
	door_area.name = "DoorArea"
	door_area.collision_layer = 0
	door_area.collision_mask = 0
	door_area.monitoring = false
	door_area.set_meta("interact_id", "bath_door")
	door_area.set_meta("fixture", control)
	door_pivot.add_child(door_area)
	_shape_box(door_area, panel_size + Vector3(0.0, 0.0, 0.02), panel_center)

	_build_door_poster(visual, panel_size.z * 0.5)


func _build_door_poster(door_visual: Node3D, half_thickness: float) -> void:
	# 部屋側の面（ローカル -z）から 2mm 浮かせて貼る。DoorPivot の子なので開閉に追従する
	var face_z := -half_thickness - DETAIL_GAP
	var center := Vector3(POSTER_HINGE_X, POSTER_CENTER_Y, face_z)
	var quad := QuadMesh.new()
	quad.size = POSTER_SIZE
	var mi := MeshInstance3D.new()
	mi.name = "Poster"
	mi.mesh = quad
	mi.material_override = _texture_mat("poster", POSTER_TEX, 0.9)
	mi.position = center
	mi.rotation.y = PI   # QuadMesh の表は +z。部屋側（-z）へ向ける
	door_visual.add_child(mi)

	# 調べる判定：ドアの判定の手前に重ねる薄い板（interact レイヤー＝ぶつからない）。
	# レイは手前の広告に先に当たり、広告の外側を狙えばドアに当たる。
	var area := Area3D.new()
	area.name = "PosterCollision"
	area.collision_layer = LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("interact_id", "poster")
	door_pivot.add_child(area)
	_shape_box(area, Vector3(POSTER_SIZE.x, POSTER_SIZE.y, 0.006), Vector3(center.x, center.y, -half_thickness - 0.003))


# ---------------------------------------------------------------- ヘルパー

func _fixture(fixture_name: String, interact_id: String) -> Array:
	var root := Node3D.new()
	root.name = fixture_name
	add_child(root)
	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	body.set_meta("interact_id", interact_id)
	root.add_child(body)
	return [visual, body]


func _static_box(parent: Node, node_name: String, size: Vector3, center: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	parent.add_child(body)
	_mesh_box(body, size, center, material)
	_shape_box(body, size, center)
	return body


func _mesh_box(parent: Node, size: Vector3, center: Vector3, material: Material) -> MeshInstance3D:
	return MeshKit.box(parent, size, center, material)


## X 軸方向に寝かせた円柱（ドライバーの柄・軸用）。
func _mesh_cylinder_x(parent: Node, radius: float, length: float, center: Vector3, material: Material) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 16
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = material
	mi.position = center
	mi.rotation.z = deg_to_rad(90.0)
	parent.add_child(mi)
	return mi


func _shape_box(body: CollisionObject3D, size: Vector3, center: Vector3) -> void:
	MeshKit.shape_box(body, size, center)


func _texture_mat(key: String, tex: Texture2D, roughness: float) -> StandardMaterial3D:
	return MeshKit.texture_mat(key, tex, roughness)


func _mat(key: String, color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	return MeshKit.mat(key, color, roughness, metallic)
