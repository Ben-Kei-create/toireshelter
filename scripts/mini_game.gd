extends Node2D
## テレビで遊べる小さなゲーム。320×180 の SubViewport の中で動き、その絵がテレビの画面になる。
## ソフトは5本（台のケース。mode で切り替える）：ラケット対戦（pong）、ブロック崩し（blocks）、へび（snake）、よけゲー（dodge）、読み込めないディスク（nodisc）。
## 遊んでいないとき（デモ）は自動で動いて見せる。遊ぶと W／S・A／D（矢印キー）で操作する（input：x が左右、y が上下）。
## ロゴ・実在のゲーム名は使わない。文字は半角の英数字だけ（フォントに左右されない）。
## ゲームの進行は step(delta) だけで進み、テストから時間を送って確かめられる。

const W := 320.0
const H := 180.0
const MODES := ["pong", "blocks", "snake", "dodge", "nodisc"]
const TITLES := {"pong": "PONG", "blocks": "BLOCKS", "snake": "SNAKE", "dodge": "DODGE", "nodisc": "NO DISC"}
const HELP := {"pong": "W/S  MOVE", "blocks": "A/D  MOVE", "snake": "WASD  STEER", "dodge": "A/D  MOVE", "nodisc": ""}

var mode := "pong"
var playing := false          # 遊んでいる（false のときはデモ）
var input := Vector2.ZERO     # x：-1 左／1 右、y：-1 上／1 下
var message := ""             # 勝ち負けの表示
var _message_time := 0.0
var score := 0
var hits := 0                 # 打ち返し・ブロックを壊した数など（テスト用）

# --- pong
const PADDLE := Vector2(5.0, 30.0)
const BALL := 5.0
const WIN_SCORE := 5
const PLAYER_SPEED := 130.0
const CPU_SPEED := 78.0
var left_y := H * 0.5
var right_y := H * 0.5
var ball := Vector2(W * 0.5, H * 0.5)
var vel := Vector2(110.0, 50.0)
var score_left := 0
var score_right := 0
var _serve_wait := 0.6

# --- blocks
const BRICK_COLS := 10
const BRICK_ROWS := 5
const BRICK := Vector2(28.0, 8.0)
const BR_PADDLE := Vector2(44.0, 5.0)
var bricks: Array = []        # true のブロックが残っている
var br_x := W * 0.5
var br_ball := Vector2(W * 0.5, 150.0)
var br_vel := Vector2(60.0, -90.0)
var lives := 3
var _br_wait := 0.8

# --- snake
const CELL := 10
const GRID := Vector2i(32, 18)
var snake: Array = []
var snake_dir := Vector2i(1, 0)
var _snake_next := Vector2i(1, 0)
var food := Vector2i(20, 9)
var _snake_t := 0.0

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
		"pong":
			score_left = 0
			score_right = 0
			left_y = H * 0.5
			right_y = H * 0.5
			_serve(1.0)
		"blocks":
			bricks = []
			for r in BRICK_ROWS:
				var row := []
				for c in BRICK_COLS:
					row.append(true)
				bricks.append(row)
			br_x = W * 0.5
			lives = 3
			_br_serve()
		"snake":
			snake = [Vector2i(8, 9), Vector2i(7, 9), Vector2i(6, 9)]
			snake_dir = Vector2i(1, 0)
			_snake_next = snake_dir
			_snake_t = 0.0
			_place_food()
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
		"pong":
			_step_pong(delta)
		"blocks":
			_step_blocks(delta)
		"snake":
			_step_snake(delta)
		"dodge":
			_step_dodge(delta)


func _end(text: String) -> void:
	message = text
	_message_time = 2.5


# ---------------------------------------------------------------- ラケット対戦

func _serve(dir: float) -> void:
	ball = Vector2(W * 0.5, H * 0.5)
	var ang := _rng.randf_range(-0.5, 0.5)
	vel = Vector2(cos(ang) * 110.0 * dir, sin(ang) * 110.0)
	_serve_wait = 0.7


func _step_pong(delta: float) -> void:
	if playing:
		left_y += input.y * PLAYER_SPEED * delta
	else:
		left_y = move_toward(left_y, ball.y, CPU_SPEED * 1.1 * delta)
	right_y = move_toward(right_y, ball.y + sin(Time.get_ticks_msec() * 0.002) * 6.0, CPU_SPEED * delta)
	left_y = clampf(left_y, PADDLE.y * 0.5, H - PADDLE.y * 0.5)
	right_y = clampf(right_y, PADDLE.y * 0.5, H - PADDLE.y * 0.5)
	if _serve_wait > 0.0:
		_serve_wait -= delta
		return
	ball += vel * delta
	if ball.y < BALL * 0.5:
		ball.y = BALL * 0.5
		vel.y = absf(vel.y)
	elif ball.y > H - BALL * 0.5:
		ball.y = H - BALL * 0.5
		vel.y = -absf(vel.y)
	var lx := 14.0 + PADDLE.x
	var rx := W - 14.0 - PADDLE.x
	if vel.x < 0.0 and ball.x < lx + BALL * 0.5 and ball.x > lx - PADDLE.x - BALL and absf(ball.y - left_y) < PADDLE.y * 0.5 + BALL * 0.5:
		_bounce(left_y, 1.0)
	elif vel.x > 0.0 and ball.x > rx - BALL * 0.5 and ball.x < rx + PADDLE.x + BALL and absf(ball.y - right_y) < PADDLE.y * 0.5 + BALL * 0.5:
		_bounce(right_y, -1.0)
	if ball.x < -BALL:
		score_right += 1
		_scored(1.0)
	elif ball.x > W + BALL:
		score_left += 1
		_scored(-1.0)


func _bounce(paddle_y: float, dir: float) -> void:
	hits += 1
	var off := clampf((ball.y - paddle_y) / (PADDLE.y * 0.5), -1.0, 1.0)
	var speed := minf(vel.length() * 1.05, 220.0)
	var ang := off * 0.9
	vel = Vector2(cos(ang) * dir, sin(ang)) * speed


func _scored(next_dir: float) -> void:
	if playing and score_left >= WIN_SCORE:
		_end("YOU WIN")
	elif playing and score_right >= WIN_SCORE:
		_end("YOU LOSE")
	elif not playing and maxi(score_left, score_right) >= WIN_SCORE:
		score_left = 0
		score_right = 0
		_serve(next_dir)
	else:
		_serve(next_dir)


# ---------------------------------------------------------------- ブロック崩し

func _br_serve() -> void:
	br_ball = Vector2(br_x, 150.0)
	br_vel = Vector2(_rng.randf_range(-50.0, 50.0), -95.0)
	_br_wait = 0.8


func bricks_left() -> int:
	var n := 0
	for row in bricks:
		for b in row:
			if b:
				n += 1
	return n


func _step_blocks(delta: float) -> void:
	if playing:
		br_x += input.x * 150.0 * delta
	else:
		br_x = move_toward(br_x, br_ball.x, 140.0 * delta)
	br_x = clampf(br_x, BR_PADDLE.x * 0.5, W - BR_PADDLE.x * 0.5)
	if _br_wait > 0.0:
		_br_wait -= delta
		br_ball = Vector2(br_x, 150.0)
		return
	br_ball += br_vel * delta
	if br_ball.x < 3.0:
		br_ball.x = 3.0
		br_vel.x = absf(br_vel.x)
	elif br_ball.x > W - 3.0:
		br_ball.x = W - 3.0
		br_vel.x = -absf(br_vel.x)
	if br_ball.y < 3.0:
		br_ball.y = 3.0
		br_vel.y = absf(br_vel.y)
	# パドル
	var py := 168.0
	if br_vel.y > 0.0 and br_ball.y > py - 3.0 and br_ball.y < py + BR_PADDLE.y + 3.0 and absf(br_ball.x - br_x) < BR_PADDLE.x * 0.5 + 3.0:
		var off := clampf((br_ball.x - br_x) / (BR_PADDLE.x * 0.5), -1.0, 1.0)
		var sp := minf(br_vel.length() * 1.02, 190.0)
		var ang := off * 1.0
		br_vel = Vector2(sin(ang), -cos(ang)) * sp
		br_ball.y = py - 3.0
		hits += 1
	# ブロック
	var gx := int((br_ball.x - 10.0) / (BRICK.x + 1.0))
	var gy := int((br_ball.y - 24.0) / (BRICK.y + 2.0))
	if gx >= 0 and gx < BRICK_COLS and gy >= 0 and gy < BRICK_ROWS and bricks[gy][gx]:
		bricks[gy][gx] = false
		br_vel.y = -br_vel.y
		score += 10
		hits += 1
		if bricks_left() == 0:
			if playing:
				_end("CLEAR!")
			else:
				reset_game()
			return
	# 落とした
	if br_ball.y > H + 4.0:
		lives -= 1
		if lives <= 0:
			if playing:
				_end("GAME OVER")
			else:
				reset_game()
		else:
			_br_serve()


# ---------------------------------------------------------------- へび

func _place_food() -> void:
	for _i in 60:
		var f := Vector2i(_rng.randi_range(0, GRID.x - 1), _rng.randi_range(0, GRID.y - 1))
		if not snake.has(f):
			food = f
			return


func _step_snake(delta: float) -> void:
	if playing:
		if absf(input.x) > 0.5 or absf(input.y) > 0.5:
			var want := Vector2i(int(signf(input.x)), 0) if absf(input.x) >= absf(input.y) else Vector2i(0, int(signf(input.y)))
			if want != -snake_dir and want != Vector2i.ZERO:
				_snake_next = want
	else:
		_snake_next = _snake_ai()
	_snake_t += delta
	if _snake_t < (0.11 if playing else 0.06):
		return
	_snake_t = 0.0
	snake_dir = _snake_next
	var head: Vector2i = snake[0] + snake_dir
	if head.x < 0 or head.y < 0 or head.x >= GRID.x or head.y >= GRID.y or snake.has(head):
		if playing:
			_end("GAME OVER")
		else:
			reset_game()
		return
	snake.push_front(head)
	if head == food:
		score += 1
		hits += 1
		_place_food()
	else:
		snake.pop_back()


## デモ用：りんごのほうへ、壁と自分を避けて進む。
func _snake_ai() -> Vector2i:
	var head: Vector2i = snake[0]
	var options := [snake_dir, Vector2i(snake_dir.y, -snake_dir.x), Vector2i(-snake_dir.y, snake_dir.x)]
	var best: Vector2i = snake_dir
	var best_d := 1.0e9
	for o in options:
		var n: Vector2i = head + o
		if n.x < 0 or n.y < 0 or n.x >= GRID.x or n.y >= GRID.y or snake.has(n):
			continue
		var d := float(absi(n.x - food.x) + absi(n.y - food.y))
		if d < best_d:
			best_d = d
			best = o
	return best


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
		"pong":
			_draw_pong(font, col)
		"blocks":
			_draw_blocks(font, col)
		"snake":
			_draw_snake(font, col)
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


func _draw_pong(font: Font, col: Color) -> void:
	for i in 12:
		draw_rect(Rect2(W * 0.5 - 1.0, 6.0 + i * 15.0, 2.0, 8.0), Color(0.25, 0.4, 0.55))
	draw_rect(Rect2(0, 0, W, 3), Color(0.25, 0.4, 0.55))
	draw_rect(Rect2(0, H - 3, W, 3), Color(0.25, 0.4, 0.55))
	draw_rect(Rect2(14.0, left_y - PADDLE.y * 0.5, PADDLE.x, PADDLE.y), col)
	draw_rect(Rect2(W - 14.0 - PADDLE.x, right_y - PADDLE.y * 0.5, PADDLE.x, PADDLE.y), Color(1.0, 0.7, 0.5))
	draw_rect(Rect2(ball.x - BALL * 0.5, ball.y - BALL * 0.5, BALL, BALL), Color(1.0, 1.0, 0.9))
	draw_string(font, Vector2(W * 0.5 - 50.0, 30.0), str(score_left), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, col)
	draw_string(font, Vector2(W * 0.5 + 10.0, 30.0), str(score_right), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, Color(1.0, 0.7, 0.5))


func _draw_blocks(font: Font, col: Color) -> void:
	var cols := [Color(0.9, 0.35, 0.35), Color(0.95, 0.65, 0.3), Color(0.95, 0.9, 0.35), Color(0.4, 0.85, 0.5), Color(0.4, 0.65, 0.95)]
	for r in BRICK_ROWS:
		for c in BRICK_COLS:
			if bricks[r][c]:
				draw_rect(Rect2(10.0 + c * (BRICK.x + 1.0), 24.0 + r * (BRICK.y + 2.0), BRICK.x, BRICK.y), cols[r])
	draw_rect(Rect2(br_x - BR_PADDLE.x * 0.5, 168.0, BR_PADDLE.x, BR_PADDLE.y), col)
	draw_rect(Rect2(br_ball.x - 3.0, br_ball.y - 3.0, 6.0, 6.0), Color(1.0, 1.0, 0.9))
	draw_string(font, Vector2(8.0, 14.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, col)
	draw_string(font, Vector2(W - 88.0, 14.0), "LIVES %d" % lives, HORIZONTAL_ALIGNMENT_RIGHT, 80.0, 11, col)


func _draw_snake(font: Font, col: Color) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.09, 0.1))
	draw_rect(Rect2(food.x * CELL + 1.0, food.y * CELL + 1.0, CELL - 2.0, CELL - 2.0), Color(1.0, 0.4, 0.35))
	for i in snake.size():
		var s: Vector2i = snake[i]
		draw_rect(Rect2(s.x * CELL + 1.0, s.y * CELL + 1.0, CELL - 2.0, CELL - 2.0), col if i == 0 else col.darkened(0.25))
	draw_string(font, Vector2(8.0, 14.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, Color(0.8, 0.9, 1.0, 0.8))


func _draw_dodge(font: Font, col: Color) -> void:
	for b in dg_blocks:
		draw_rect(Rect2(float(b.x) - float(b.w) * 0.5, float(b.y) - 4.0, float(b.w), 8.0), Color(1.0, 0.6, 0.4))
	draw_rect(Rect2(dg_x - DODGE_W * 0.5, 160.0, DODGE_W, 10.0), col)
	draw_rect(Rect2(dg_x - 2.0, 156.0, 4.0, 4.0), col)
	draw_string(font, Vector2(8.0, 14.0), "SCORE %d" % score, HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, Color(0.8, 0.9, 1.0, 0.8))
