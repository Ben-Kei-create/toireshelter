extends Node2D
## テレビで遊べる小さなゲーム。320×180 の SubViewport の中で動き、その絵がテレビの画面になる。
## ソフトは5本（台のケース。mode で切り替える）：落ちものパズル（tetris）、レースゲーム（racer）、樽よけ・はしご登り（climb）、よけゲー（dodge）、読み込めないディスク（nodisc）。
## 実在のゲームの名前・ロゴ・絵は使わない（形式だけの、似た遊び）。
## 遊んでいないとき（デモ）は自動で動いて見せる。遊ぶと W／S・A／D（矢印キー）で操作する（input：x が左右、y が上下）。
## ロゴ・実在のゲーム名は使わない。文字は半角の英数字だけ（フォントに左右されない）。
## ゲームの進行は step(delta) だけで進み、テストから時間を送って確かめられる。

const W := 320.0
const H := 180.0
const MODES := ["tetris", "racer", "climb", "dodge", "nodisc"]
const TITLES := {"tetris": "FALLING BLOCKS", "racer": "GRAND RACE", "climb": "BARREL CLIMB", "dodge": "DODGE", "nodisc": "NO DISC"}
const HELP := {"tetris": "A/D MOVE  W TURN  S DROP", "racer": "A/D STEER  W BOOST", "climb": "A/D MOVE  W CLIMB/JUMP", "dodge": "A/D  MOVE", "nodisc": ""}

var mode := "tetris"
var playing := false          # 遊んでいる（false のときはデモ）
var input := Vector2.ZERO     # x：-1 左／1 右、y：-1 上／1 下
var message := ""             # 勝ち負けの表示
var _message_time := 0.0
var score := 0
var hits := 0                 # 打ち返し・ブロックを壊した数など（テスト用）

# --- dodge
const DODGE_W := 16.0
var dg_x := W * 0.5
var dg_blocks: Array = []     # {x, y, w, v}
var _dg_spawn := 0.0
var dg_time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset_game()
	queue_redraw()


## ソフトを入れ替える（0〜4）。入れ替えるとデモからやり直す。
func select(i: int) -> void:
	mode = MODES[clampi(i, 0, MODES.size() - 1)]
	playing = false
	message = ""
	reset_game()


## このソフトは遊べるか（読み込めないディスクは遊べない）。
func playable() -> bool:
	return mode != "nodisc"


func start() -> void:
	if not playable():
		return
	playing = true
	message = ""
	_message_time = 0.0
	reset_game()


func stop() -> void:
	playing = false
	input = Vector2.ZERO
	message = ""
	reset_game()


func reset_game() -> void:
	score = 0
	hits = 0
	match mode:
		"tetris":
			tt_grid = []
			for r in TT_ROWS:
				tt_grid.append(_tt_empty_row())
			tt_lines = 0
			_bag = []
			tt_next = _tt_pick()
			_tt_spawn()
		"racer":
			rc_x = 160.0
			rc_speed = 90.0
			rc_dist = 0.0
			rc_cars = []
			_rc_spawn = 0.4
		"climb":
			cl_x = 20.0
			cl_level = 0
			cl_y_off = 0.0
			cl_climbing = false
			cl_jump = 0.0
			cl_barrels = []
			_cl_spawn = 1.0
			cl_won = false
		"dodge":
			dg_x = W * 0.5
			dg_blocks = []
			_dg_spawn = 0.4
			dg_time = 0.0


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## 時間を delta 秒進める。
func step(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message = ""
			reset_game()
		return
	match mode:
		"tetris":
			_step_tetris(delta)
		"racer":
			_step_racer(delta)
		"climb":
			_step_climb(delta)
		"dodge":
			_step_dodge(delta)


func _end(text: String) -> void:
	message = text
	_message_time = 2.5


# ---------------------------------------------------------------- 落ちものパズル（tetris）

const TT_SHAPES := {
	"I": [[0, 1], [1, 1], [2, 1], [3, 1]], "O": [[1, 0], [2, 0], [1, 1], [2, 1]], "T": [[1, 0], [0, 1], [1, 1], [2, 1]],
	"S": [[1, 0], [2, 0], [0, 1], [1, 1]], "Z": [[0, 0], [1, 0], [1, 1], [2, 1]], "J": [[0, 0], [0, 1], [1, 1], [2, 1]], "L": [[2, 0], [0, 1], [1, 1], [2, 1]],
}
const TT_KINDS := ["I", "O", "T", "S", "Z", "J", "L"]
const TT_COLS := 10
const TT_ROWS := 18
const TT_CELL := 10.0
var tt_grid: Array = []          # 行（上から）× 列。0 は空き、1〜7 は固まった色
var tt_kind := "T"
var tt_rot := 0
var tt_x := 3
var tt_y := 0
var tt_next := "I"
var tt_lines := 0
var _tt_fall := 0.0
var _tt_move := 0.0
var _tt_prev_up := false
var _tt_target := Vector2i(3, 0)  # デモ：置きたい（x, 回転）
var _tt_ai_t := 0.0
var _bag: Array = []


func _tt_cells(kind: String, rot: int) -> Array:
	var cells: Array = []
	for c in TT_SHAPES[kind]:
		var x: int = c[0]
		var y: int = c[1]
		for r in rot % 4:
			var nx := 3 - y
			y = x
			x = nx
		cells.append(Vector2i(x, y))
	return cells


func _tt_fits(kind: String, rot: int, px: int, py: int, grid: Array = tt_grid) -> bool:
	for c in _tt_cells(kind, rot):
		var gx: int = px + c.x
		var gy: int = py + c.y
		if gx < 0 or gx >= TT_COLS or gy >= TT_ROWS:
			return false
		if gy >= 0 and grid[gy][gx] != 0:
			return false
	return true


func _tt_pick() -> String:
	if _bag.is_empty():
		_bag = TT_KINDS.duplicate()
		_bag.shuffle()
	return _bag.pop_back()


func _tt_spawn() -> bool:
	tt_kind = tt_next
	tt_next = _tt_pick()
	tt_rot = 0
	tt_x = 3
	tt_y = -1
	_tt_fall = 0.0
	_tt_plan()
	return _tt_fits(tt_kind, tt_rot, tt_x, tt_y)


## 固めて、そろった行を消す。消した行数を返す。
func _tt_lock() -> int:
	for c in _tt_cells(tt_kind, tt_rot):
		var gy: int = tt_y + c.y
		if gy >= 0:
			tt_grid[gy][tt_x + c.x] = TT_KINDS.find(tt_kind) + 1
	var cleared_rows := 0
	for r in range(TT_ROWS - 1, -1, -1):
		if not (tt_grid[r] as Array).has(0):
			tt_grid.remove_at(r)
			tt_grid.push_front(_tt_empty_row())
			cleared_rows += 1
			return cleared_rows + _tt_lock_again()
	return 0


func _tt_lock_again() -> int:
	for r in range(TT_ROWS - 1, -1, -1):
		if not (tt_grid[r] as Array).has(0):
			tt_grid.remove_at(r)
			tt_grid.push_front(_tt_empty_row())
			return 1 + _tt_lock_again()
	return 0


func _tt_empty_row() -> Array:
	var row := []
	for i in TT_COLS:
		row.append(0)
	return row


## デモ：すべての置き方を試して、いちばん良い（穴が少なく低い）所を選ぶ。
func _tt_plan() -> void:
	var best := -1.0e9
	for rot in 4:
		for px in range(-3, TT_COLS):
			if not _tt_fits(tt_kind, rot, px, -1):
				continue
			var py := -1
			while _tt_fits(tt_kind, rot, px, py + 1):
				py += 1
			var g: Array = []
			for row in tt_grid:
				g.append((row as Array).duplicate())
			var ok := true
			for c in _tt_cells(tt_kind, rot):
				var gy: int = py + c.y
				if gy < 0:
					ok = false
				else:
					g[gy][px + c.x] = 1
			if not ok:
				continue
			var lines_c := 0
			for row in g:
				if not (row as Array).has(0):
					lines_c += 1
			var heights: Array = []
			var holes := 0
			for cx in TT_COLS:
				var h := 0
				var seen := false
				for r in TT_ROWS:
					if g[r][cx] != 0:
						if not seen:
							h = TT_ROWS - r
							seen = true
					elif seen:
						holes += 1
				heights.append(h)
			var agg := 0
			var bump := 0
			for i in heights.size():
				agg += heights[i]
				if i > 0:
					bump += absi(heights[i] - heights[i - 1])
			var sc := -0.51 * agg + 0.76 * lines_c - 0.36 * holes - 0.18 * bump
			if sc > best:
				best = sc
				_tt_target = Vector2i(px, rot)


func _step_tetris(delta: float) -> void:
	if tt_grid.is_empty():
		return
	var move := 0
	var rotate := false
	var soft := false
	if playing:
		move = int(signf(input.x))
		var up := input.y < -0.5
		rotate = up and not _tt_prev_up
		_tt_prev_up = up
		soft = input.y > 0.5
	else:
		_tt_ai_t -= delta
		if _tt_ai_t <= 0.0:
			_tt_ai_t = 0.07
			if tt_rot % 4 != _tt_target.y % 4:
				rotate = true
			elif tt_x < _tt_target.x:
				move = 1
			elif tt_x > _tt_target.x:
				move = -1
			else:
				soft = true
	if rotate:
		var nr := (tt_rot + 1) % 4
		for kick in [0, -1, 1, -2, 2]:
			if _tt_fits(tt_kind, nr, tt_x + kick, tt_y):
				tt_rot = nr
				tt_x += kick
				break
	_tt_move -= delta
	if move != 0 and _tt_move <= 0.0:
		_tt_move = 0.11
		if _tt_fits(tt_kind, tt_rot, tt_x + move, tt_y):
			tt_x += move
	elif move == 0:
		_tt_move = 0.0
	_tt_fall += delta
	var interval := maxf(0.12, 0.55 - tt_lines * 0.02)
	if soft:
		interval = 0.04
	while _tt_fall >= interval:
		_tt_fall -= interval
		if _tt_fits(tt_kind, tt_rot, tt_x, tt_y + 1):
			tt_y += 1
		else:
			var n := _tt_lock()
			tt_lines += n
			score += [0, 100, 300, 500, 800][mini(n, 4)]
			hits += 1
			if not _tt_spawn():
				if playing:
					_end("GAME OVER")
				else:
					reset_game()
				return
			break


# ---------------------------------------------------------------- レースゲーム（racer）

const RC_ROAD := Vector2(70.0, 250.0)   # 道の左端・右端
const RC_CAR := Vector2(12.0, 20.0)
var rc_x := 160.0
var rc_speed := 90.0
var rc_dist := 0.0
var rc_cars: Array = []                 # {x, y, v}
var _rc_spawn := 0.0


func _step_racer(delta: float) -> void:
	rc_speed = minf(220.0, rc_speed + 6.0 * delta)
	if playing:
		rc_x += input.x * 120.0 * delta
		if input.y < -0.5:
			rc_speed = minf(240.0, rc_speed + 30.0 * delta)
	else:
		var target := rc_x
		for c in rc_cars:
			if float(c.y) > 70.0 and float(c.y) < 150.0 and absf(float(c.x) - rc_x) < RC_CAR.x + 6.0:
				target = rc_x + (50.0 if float(c.x) < rc_x else -50.0)
				if target < RC_ROAD.x + 12.0 or target > RC_ROAD.y - 12.0:
					target = rc_x - (target - rc_x)
		rc_x = move_toward(rc_x, clampf(target, RC_ROAD.x + 10.0, RC_ROAD.y - 10.0), 120.0 * delta)
	rc_x = clampf(rc_x, RC_ROAD.x + RC_CAR.x * 0.5, RC_ROAD.y - RC_CAR.x * 0.5)
	rc_dist += rc_speed * delta
	score = int(rc_dist / 10.0)
	_rc_spawn -= delta
	if _rc_spawn <= 0.0:
		_rc_spawn = _rng.randf_range(0.45, 0.9)
		rc_cars.append({"x": _rng.randf_range(RC_ROAD.x + 10.0, RC_ROAD.y - 10.0), "y": -24.0, "v": _rng.randf_range(40.0, 80.0)})
	for c in rc_cars.duplicate():
		c.y += (rc_speed - float(c.v)) * delta
		if float(c.y) > H + 24.0:
			rc_cars.erase(c)
		elif absf(float(c.y) - 150.0) < RC_CAR.y and absf(float(c.x) - rc_x) < RC_CAR.x:
			if playing:
				_end("CRASH")
			else:
				reset_game()
			return


# ---------------------------------------------------------------- 樽よけ・はしご登り（climb）

const CL_BASE := [162.0, 124.0, 86.0, 48.0]       # 各段の高さ（x=160 のとき）
const CL_SLOPE := [-0.05, 0.06, -0.06, 0.06]      # 傾き（正は右下がり。樽は下る側へ転がる）
const CL_LADDER := [280.0, 40.0, 280.0]           # 段 i → i+1 へのはしごの x
const CL_X := Vector2(10.0, 310.0)
var cl_x := 20.0
var cl_level := 0
var cl_y_off := 0.0          # はしごの途中の高さ（0〜1：下の段から次の段）
var cl_climbing := false
var cl_jump := 0.0           # ジャンプの経過（0 のときは地面）
var cl_barrels: Array = []   # {x, level, dir}
var _cl_spawn := 1.0
var cl_won := false


func cl_floor_y(level: int, x: float) -> float:
	return float(CL_BASE[level]) + float(CL_SLOPE[level]) * (x - 160.0)


func cl_player_pos() -> Vector2:
	if cl_climbing and cl_level < 3:
		return Vector2(cl_x, lerpf(cl_floor_y(cl_level, cl_x), cl_floor_y(cl_level + 1, cl_x), cl_y_off))
	var hop := 0.0
	if cl_jump > 0.0:
		hop = sin(PI * clampf(cl_jump / 0.55, 0.0, 1.0)) * 16.0
	return Vector2(cl_x, cl_floor_y(cl_level, cl_x) - hop)


func _step_climb(delta: float) -> void:
	var mv := 0.0
	var vert := 0.0
	var jump_req := false
	if playing:
		mv = input.x
		vert = input.y
	else:
		# デモ：樽が近ければ跳ぶ。そうでなければ、はしごへ向かって登る
		var lx: float = CL_LADDER[cl_level] if cl_level < 3 else cl_x
		mv = signf(lx - cl_x) if absf(lx - cl_x) > 3.0 else 0.0
		vert = -1.0 if absf(lx - cl_x) <= 3.0 else 0.0
		for b in cl_barrels:
			if int(b.level) == cl_level and absf(float(b.x) - cl_x) < 26.0 and not cl_climbing and cl_jump <= 0.0:
				jump_req = true
	if cl_jump > 0.0:
		cl_jump += delta
		if cl_jump >= 0.55:
			cl_jump = 0.0
	elif cl_climbing:
		cl_y_off = clampf(cl_y_off - vert * 0.9 * delta, 0.0, 1.0)
		if cl_y_off >= 1.0:
			cl_level += 1
			cl_climbing = false
			cl_y_off = 0.0
		elif cl_y_off <= 0.0 and vert > 0.0:
			cl_climbing = false
			cl_y_off = 0.0
	else:
		cl_x = clampf(cl_x + mv * 60.0 * delta, CL_X.x, CL_X.y)
		var near_ladder := cl_level < 3 and absf(cl_x - float(CL_LADDER[cl_level])) < 5.0
		if near_ladder and vert < -0.5:
			cl_climbing = true
			cl_x = float(CL_LADDER[cl_level])
			cl_y_off = 0.001   # 下の段から登りはじめる
		elif vert < -0.5 and not near_ladder:
			cl_jump = 0.001
		if jump_req:
			cl_jump = 0.001
	# 最上段に着いたら、クリア
	if cl_level >= 3 and not cl_won:
		cl_won = true
		score += 500
		if playing:
			_end("CLEAR")
		else:
			reset_game()
		return
	_cl_spawn -= delta
	if _cl_spawn <= 0.0:
		_cl_spawn = _rng.randf_range(1.6, 2.6)
		cl_barrels.append({"x": 40.0, "level": 3, "dir": 1.0})
	var pp := cl_player_pos()
	for b in cl_barrels.duplicate():
		b.x += float(b.dir) * 48.0 * delta
		if float(b.x) > CL_X.y + 6.0 and float(b.dir) > 0.0:
			b.level = int(b.level) - 1
			b.dir = -1.0
		elif float(b.x) < CL_X.x - 6.0 and float(b.dir) < 0.0:
			b.level = int(b.level) - 1
			b.dir = 1.0
		if int(b.level) < 0:
			cl_barrels.erase(b)
			score += 10
			continue
		var by := cl_floor_y(int(b.level), float(b.x)) - 4.0
		if absf(float(b.x) - pp.x) < 6.0 and absf(by - (pp.y - 4.0)) < 7.0:
			if playing:
				_end("GAME OVER")
			else:
				reset_game()
			return


# ---------------------------------------------------------------- よけゲー

func _step_dodge(delta: float) -> void:
	dg_time += delta
	if playing:
		dg_x += input.x * 140.0 * delta
	else:
		# デモ：いちばん近い落ちてくる物から離れる
		var target := dg_x
		var near := 1.0e9
		for b in dg_blocks:
			if b.y < 160.0 and absf(b.x - dg_x) < b.w * 0.5 + DODGE_W and b.y < 168.0 and float(b.y) > 20.0:
				var dy: float = 168.0 - float(b.y)
				if dy < near:
					near = dy
					target = dg_x + (80.0 if b.x < dg_x else -80.0)
		dg_x = move_toward(dg_x, clampf(target, 12.0, W - 12.0), 150.0 * delta)
	dg_x = clampf(dg_x, DODGE_W * 0.5, W - DODGE_W * 0.5)
	_dg_spawn -= delta
	if _dg_spawn <= 0.0:
		_dg_spawn = maxf(0.18, 0.6 - dg_time * 0.01)
		var w := _rng.randf_range(10.0, 26.0)
		dg_blocks.append({"x": _rng.randf_range(w * 0.5, W - w * 0.5), "y": -10.0, "w": w, "v": _rng.randf_range(70.0, 110.0) + dg_time * 1.5})
	for b in dg_blocks.duplicate():
		b.y += float(b.v) * delta
		if b.y > H + 12.0:
			dg_blocks.erase(b)
			score += 1
		elif b.y > 156.0 and b.y < 176.0 and absf(float(b.x) - dg_x) < float(b.w) * 0.5 + DODGE_W * 0.5:
			if playing:
				_end("GAME OVER")
			else:
				reset_game()
			return


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.07, 0.12))
	var font := ThemeDB.fallback_font
	var col := Color(0.55, 1.0, 0.7) if playing else Color(0.6, 0.7, 0.8)
	match mode:
		"tetris":
			_draw_tetris(font, col)
		"racer":
			_draw_racer(font, col)
		"climb":
			_draw_climb(font, col)
		"dodge":
			_draw_dodge(font, col)
		"nodisc":
			if int(Time.get_ticks_msec() / 600) % 2 == 0:
				draw_string(font, Vector2(0, H * 0.5 + 6.0), "NO DISC", HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1.0, 0.5, 0.4))
			draw_string(font, Vector2(0, H * 0.5 + 28.0), "CHECK THE DISC", HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(0.7, 0.75, 0.8))
			return
	if not message.is_empty():
		draw_string(font, Vector2(0, H * 0.5 + 8.0), message, HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color(1.0, 0.95, 0.5))
	elif not playing:
		draw_string(font, Vector2(0, H - 6.0), "%s  DEMO - PRESS E TO PLAY" % TITLES[mode], HORIZONTAL_ALIGNMENT_CENTER, W, 11, Color(0.7, 0.8, 0.9, 0.85))
	else:
		draw_string(font, Vector2(0, H - 3.0), "%s   E  QUIT" % HELP[mode], HORIZONTAL_ALIGNMENT_CENTER, W, 9, Color(0.6, 0.75, 0.9, 0.7))


func _draw_tetris(font: Font, col: Color) -> void:
	var ox := (W - TT_COLS * TT_CELL) * 0.5
	var palette := [Color(0.4, 0.9, 0.95), Color(0.95, 0.9, 0.35), Color(0.75, 0.45, 0.95), Color(0.45, 0.9, 0.5), Color(0.95, 0.4, 0.4), Color(0.4, 0.55, 0.95), Color(0.95, 0.65, 0.3)]
	draw_rect(Rect2(ox - 2.0, 0, TT_COLS * TT_CELL + 4.0, H), Color(0.1, 0.14, 0.2))
	draw_rect(Rect2(ox, 0, TT_COLS * TT_CELL, H), Color(0.03, 0.05, 0.09))
	for r in TT_ROWS:
		for c in TT_COLS:
			var v: int = tt_grid[r][c]
			if v != 0:
				draw_rect(Rect2(ox + c * TT_CELL + 0.5, r * TT_CELL + 0.5, TT_CELL - 1.0, TT_CELL - 1.0), palette[v - 1])
	for cell in _tt_cells(tt_kind, tt_rot):
		var gy: int = tt_y + cell.y
		if gy >= 0:
			draw_rect(Rect2(ox + (tt_x + cell.x) * TT_CELL + 0.5, gy * TT_CELL + 0.5, TT_CELL - 1.0, TT_CELL - 1.0), palette[TT_KINDS.find(tt_kind)])
	draw_string(font, Vector2(8.0, 20.0), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 10, col)
	draw_string(font, Vector2(8.0, 34.0), str(score), HORIZONTAL_ALIGNMENT_LEFT, 80.0, 14, Color(1, 1, 0.9))
	draw_string(font, Vector2(8.0, 58.0), "LINES %d" % tt_lines, HORIZONTAL_ALIGNMENT_LEFT, 80.0, 10, col)
	draw_string(font, Vector2(ox + TT_COLS * TT_CELL + 14.0, 20.0), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 10, col)
	for cell in _tt_cells(tt_next, 0):
		draw_rect(Rect2(ox + TT_COLS * TT_CELL + 14.0 + cell.x * 8.0, 28.0 + cell.y * 8.0, 7.0, 7.0), palette[TT_KINDS.find(tt_next)])


func _draw_racer(font: Font, col: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.35, 0.16))
	draw_rect(Rect2(RC_ROAD.x, 0, RC_ROAD.y - RC_ROAD.x, H), Color(0.22, 0.22, 0.25))
	draw_rect(Rect2(RC_ROAD.x - 3.0, 0, 3.0, H), Color(0.95, 0.95, 0.95))
	draw_rect(Rect2(RC_ROAD.y, 0, 3.0, H), Color(0.95, 0.95, 0.95))
	var off := fmod(rc_dist, 30.0)
	for i in 8:
		draw_rect(Rect2((RC_ROAD.x + RC_ROAD.y) * 0.5 - 1.0, -30.0 + i * 30.0 + off, 2.0, 14.0), Color(0.9, 0.85, 0.4))
	for i in 6:
		var ty := fmod(-20.0 + i * 40.0 + rc_dist * 0.8, H + 40.0) - 20.0
		draw_circle(Vector2(30.0, ty), 7.0, Color(0.08, 0.28, 0.1))
		draw_circle(Vector2(W - 30.0, ty + 18.0), 7.0, Color(0.08, 0.28, 0.1))
	for c in rc_cars:
		_draw_f1(Vector2(float(c.x), float(c.y)), Color(0.95, 0.75, 0.2))
	_draw_f1(Vector2(rc_x, 150.0), Color(0.9, 0.2, 0.2))
	draw_string(font, Vector2(8.0, 14.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, Color(1, 1, 0.9))
	draw_string(font, Vector2(W - 88.0, 14.0), "%d KM/H" % int(rc_speed * 1.4), HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 11, Color(1, 1, 0.9))


func _draw_f1(pos: Vector2, body: Color) -> void:
	draw_rect(Rect2(pos.x - 6.0, pos.y - 4.0, 12.0, 14.0), body)       # 車体
	draw_rect(Rect2(pos.x - 2.0, pos.y - 10.0, 4.0, 8.0), body)         # ノーズ
	draw_rect(Rect2(pos.x - 8.0, pos.y - 9.0, 16.0, 2.0), body.darkened(0.3))   # 前翼
	draw_rect(Rect2(pos.x - 7.0, pos.y + 8.0, 14.0, 2.0), body.darkened(0.3))   # 後翼
	for dx in [-8.0, 5.0]:
		draw_rect(Rect2(pos.x + dx, pos.y - 6.0, 3.0, 6.0), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(pos.x + dx, pos.y + 3.0, 3.0, 7.0), Color(0.05, 0.05, 0.05))
	draw_circle(Vector2(pos.x, pos.y + 1.0), 2.2, Color(0.95, 0.95, 0.9))   # ドライバー


func _draw_climb(font: Font, col: Color) -> void:
	for lv in 4:
		var a := Vector2(CL_X.x, cl_floor_y(lv, CL_X.x))
		var b := Vector2(CL_X.y, cl_floor_y(lv, CL_X.y))
		draw_line(a, b, Color(0.85, 0.3, 0.35), 4.0)
		draw_line(a + Vector2(0, 3), b + Vector2(0, 3), Color(0.55, 0.15, 0.2), 1.5)
	for i in 3:
		var lx: float = CL_LADDER[i]
		var y0 := cl_floor_y(i, lx)
		var y1 := cl_floor_y(i + 1, lx)
		draw_line(Vector2(lx - 4.0, y0), Vector2(lx - 4.0, y1), Color(0.5, 0.85, 0.95), 1.5)
		draw_line(Vector2(lx + 4.0, y0), Vector2(lx + 4.0, y1), Color(0.5, 0.85, 0.95), 1.5)
		var yy := y1
		while yy < y0:
			draw_line(Vector2(lx - 4.0, yy), Vector2(lx + 4.0, yy), Color(0.5, 0.85, 0.95), 1.0)
			yy += 5.0
	# 大きなゴリラ（最上段の左）
	var kx := 24.0
	var ky := cl_floor_y(3, kx) - 14.0
	draw_rect(Rect2(kx - 12.0, ky - 8.0, 24.0, 18.0), Color(0.55, 0.32, 0.2))
	draw_rect(Rect2(kx - 7.0, ky - 16.0, 14.0, 10.0), Color(0.62, 0.38, 0.24))
	draw_rect(Rect2(kx - 4.0, ky - 13.0, 3.0, 3.0), Color(1, 1, 0.9))
	draw_rect(Rect2(kx + 1.0, ky - 13.0, 3.0, 3.0), Color(1, 1, 0.9))
	draw_rect(Rect2(kx - 16.0, ky - 4.0, 5.0, 10.0), Color(0.5, 0.28, 0.18))
	draw_rect(Rect2(kx + 11.0, ky - 4.0, 5.0, 10.0), Color(0.5, 0.28, 0.18))
	# ゴール（最上段の右の人影）
	draw_rect(Rect2(290.0, cl_floor_y(3, 290.0) - 14.0, 6.0, 12.0), Color(1.0, 0.6, 0.8))
	for bl in cl_barrels:
		draw_circle(Vector2(float(bl.x), cl_floor_y(int(bl.level), float(bl.x)) - 4.0), 4.0, Color(0.85, 0.55, 0.25))
		draw_line(Vector2(float(bl.x) - 3.0, cl_floor_y(int(bl.level), float(bl.x)) - 4.0), Vector2(float(bl.x) + 3.0, cl_floor_y(int(bl.level), float(bl.x)) - 4.0), Color(0.4, 0.22, 0.1), 1.0)
	var pp := cl_player_pos()
	draw_rect(Rect2(pp.x - 3.0, pp.y - 10.0, 6.0, 10.0), Color(0.3, 0.5, 0.95))   # 体
	draw_rect(Rect2(pp.x - 3.0, pp.y - 14.0, 6.0, 4.0), Color(0.95, 0.8, 0.65))   # 顔
	draw_rect(Rect2(pp.x - 4.0, pp.y - 15.0, 8.0, 2.0), Color(0.9, 0.2, 0.2))     # ぼうし
	draw_string(font, Vector2(8.0, 12.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 10, Color(1, 1, 0.9))


func _draw_dodge(font: Font, col: Color) -> void:
	for b in dg_blocks:
		draw_rect(Rect2(float(b.x) - float(b.w) * 0.5, float(b.y) - 4.0, float(b.w), 8.0), Color(1.0, 0.6, 0.4))
	draw_rect(Rect2(dg_x - DODGE_W * 0.5, 160.0, DODGE_W, 10.0), col)
	draw_rect(Rect2(dg_x - 2.0, 156.0, 4.0, 4.0), col)
	draw_string(font, Vector2(8.0, 14.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, Color(0.8, 0.9, 1.0, 0.8))
