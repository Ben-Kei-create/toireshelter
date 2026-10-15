extends RefCounted
## ひとり麻雀（こたつの中で遊ぶ）。自分だけで、13 枚の手牌に 1 枚ずつ引いては 1 枚捨てて、4 つの面子（刻子か順子）と 1 つの雀頭を作る。
## 完成すれば和了（ツモ）。七対子・国士無双も和了。山は 136 枚（東西南北は 4 枚ずつの全 34 種）で、60 回引いて和了れなければ流局。
## 牌の番号：0〜8 萬子、9〜17 筒子、18〜26 索子、27〜30 東南西北、31〜33 白發中。
## 進行はこのクラスだけで決まり、表示と操作は hud.gd と main.gd が担当する（テストからは直接呼べる）。

const KINDS := 34
const MAX_DRAWS := 60

var wall: Array = []
var hand: Array = []         # 手牌 13 枚（並べ替え済み）
var drawn := -1              # いま引いた 1 枚（手牌の右）
var discards: Array = []
var wall_pos := 0
var draws := 0
var state := "idle"          # idle / playing / won / exhausted
var yaku: Array = []         # 和了のときの役の名前
var points := 0
var total_points := 0        # 続けて遊んだ累計
var games := 0
var wins := 0
var puzzle := false          # 詰め麻雀：配牌と山が決まっている（東・中が手に入ったあと）。三手で九蓮宝燈
var _rng := RandomNumberGenerator.new()


func _init(seed_value := -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## 牌の表示：[上の文字, 下の文字, 色]。
static func tile_parts(k: int) -> Array:
	const NUM := ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if k < 9:
		return [NUM[k], "萬", Color(0.75, 0.12, 0.1)]
	if k < 18:
		return [NUM[k - 9], "筒", Color(0.12, 0.3, 0.7)]
	if k < 27:
		return [NUM[k - 18], "索", Color(0.12, 0.5, 0.2)]
	if k < 31:
		return [["東", "南", "西", "北"][k - 27], "", Color(0.1, 0.1, 0.12)]
	return [["白", "發", "中"][k - 31], "", [Color(0.5, 0.5, 0.55), Color(0.1, 0.55, 0.2), Color(0.8, 0.1, 0.1)][k - 31]]


static func tile_name(k: int) -> String:
	var p := tile_parts(k)
	return "%s%s" % [p[0], p[1]]


func start() -> void:
	if puzzle:
		_start_puzzle()
		return
	wall = []
	for k in KINDS:
		for c in 4:
			wall.append(k)
	for i in range(wall.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = wall[i]
		wall[i] = wall[j]
		wall[j] = t
	hand = wall.slice(0, 13)
	hand.sort()
	wall_pos = 13
	discards = []
	yaku = []
	points = 0
	draws = 0
	games += 1
	state = "playing"
	_draw()


## 詰め麻雀：手牌は 一一一二三四 六七八九九 ＋ 東・中。引く牌は 五萬 → 九萬 → 二萬。東と中を順に捨てれば、九蓮宝燈（解は一通り）。
func _start_puzzle() -> void:
	hand = [0, 0, 0, 1, 2, 3, 5, 6, 7, 8, 8, 27, 33]
	hand.sort()
	wall = hand.duplicate()
	wall += [4, 8, 1]
	for i in 70:
		wall.append([28, 29, 30, 31, 32][i % 5])   # そのあとは、役にならない牌ばかり
	wall_pos = 13
	discards = []
	yaku = []
	points = 0
	draws = 0
	games += 1
	state = "playing"
	_draw()


func _draw() -> void:
	drawn = wall[wall_pos]
	wall_pos += 1
	draws += 1
	if is_win(_counts(hand + [drawn])):
		_finish_win()


## 捨てる牌の番号（0〜12 が手牌、13 がいま引いた牌）。捨てたら次を引く。山が尽きたら流局。
func discard(index: int) -> bool:
	if state != "playing":
		return false
	var all: Array = hand + [drawn]
	if index < 0 or index >= all.size():
		return false
	var t: int = all[index]
	all.remove_at(index)
	discards.append(t)
	hand = all
	hand.sort()
	drawn = -1
	if draws >= MAX_DRAWS:
		state = "exhausted"
		return true
	_draw()
	return true


func _finish_win() -> void:
	state = "won"
	wins += 1
	var all: Array = hand + [drawn]
	var c := _counts(all)
	yaku = ["門前清自摸和"]
	points = 1000
	if is_chuuren(c):
		yaku = ["九蓮宝燈"]
		points = 32000
	elif _is_kokushi(c):
		yaku = ["国士無双"]
		points = 8000
	elif _is_chiitoi(c):
		yaku = ["七対子", "門前清自摸和"]
		points = 2400
	else:
		var tanyao := true
		var suits := {}
		var honors := false
		for t in all:
			if t >= 27 or t % 9 == 0 or t % 9 == 8:
				tanyao = false
			if t >= 27:
				honors = true
			else:
				suits[t / 9] = true
		if tanyao:
			yaku.append("断么九")
			points += 1000
		if suits.size() == 1 and not honors:
			yaku.append("清一色")
			points += 5000
		elif suits.size() == 1 and honors:
			yaku.append("混一色")
			points += 2000
	total_points += points


## 手牌 13 枚のとき、あと 1 枚で和了になる牌（待ち）の一覧。
func waits() -> Array:
	var out := []
	var base := _counts(hand)
	for k in KINDS:
		if base[k] >= 4:
			continue
		base[k] += 1
		if is_win(base):
			out.append(k)
		base[k] -= 1
	return out


static func _counts(tiles: Array) -> Array:
	var c := []
	c.resize(KINDS)
	c.fill(0)
	for t in tiles:
		c[t] += 1
	return c


## 14 枚（牌の数の配列）が和了形か：通常（4面子1雀頭）・七対子・国士無双。
static func is_win(c: Array) -> bool:
	var n := 0
	for v in c:
		n += v
	if n != 14:
		return false
	if _is_chiitoi(c) or _is_kokushi(c):
		return true
	for k in KINDS:
		if c[k] >= 2:
			c[k] -= 2
			var ok := _sets(c, 0)
			c[k] += 2
			if ok:
				return true
	return false


## 九蓮宝燈：1 種類の数牌だけで、1 を 3 枚・9 を 3 枚・2〜8 を 1 枚ずつ、あと 1 枚は何でも（14 枚）。
static func is_chuuren(c: Array) -> bool:
	for suit in 3:
		var total := 0
		for k in 9:
			total += int(c[suit * 9 + k])
		if total != 14:
			continue
		if int(c[suit * 9]) < 3 or int(c[suit * 9 + 8]) < 3:
			return false
		for k in range(1, 8):
			if int(c[suit * 9 + k]) < 1:
				return false
		return true
	return false


static func _is_chiitoi(c: Array) -> bool:
	var pairs := 0
	for v in c:
		if v == 2:
			pairs += 1
		elif v != 0:
			return false
	return pairs == 7


static func _is_kokushi(c: Array) -> bool:
	var need := [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]
	var pair := false
	for k in need:
		if c[k] == 0:
			return false
		if c[k] == 2:
			pair = true
	var total := 0
	for k in need:
		total += c[k]
	return pair and total == 14


## 残りの牌を、すべて面子（刻子・順子）に分けられるか。
static func _sets(c: Array, from: int) -> bool:
	var i := from
	while i < KINDS and c[i] == 0:
		i += 1
	if i >= KINDS:
		return true
	if c[i] >= 3:
		c[i] -= 3
		var ok := _sets(c, i)
		c[i] += 3
		if ok:
			return true
	if i < 27 and i % 9 <= 6 and c[i + 1] > 0 and c[i + 2] > 0:
		c[i] -= 1
		c[i + 1] -= 1
		c[i + 2] -= 1
		var ok2 := _sets(c, i)
		c[i] += 1
		c[i + 1] += 1
		c[i + 2] += 1
		if ok2:
			return true
	return false
