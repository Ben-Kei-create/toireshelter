extends Node2D
## テレビで遊べる小さなゲーム（ラケットでボールを打ち返す対戦）。320×180 の SubViewport の中で動き、その絵がテレビの画面になる。
## 遊んでいないとき（デモ）は両方のラケットを自動で動かして見せる。遊ぶと左のラケットを上下キー（W／S か ↑／↓）で動かし、先に 5 点取ったほうが勝ち。
## ロゴ・実在のゲーム名は使わない。文字は半角の英数字だけ（フォントに左右されない）。
## ゲームの進行は step(delta) だけで進み、テストから時間を送って確かめられる。

const W := 320.0
const H := 180.0
const PADDLE := Vector2(5.0, 30.0)
const BALL := 5.0
const WIN_SCORE := 5
const PLAYER_SPEED := 130.0
const CPU_SPEED := 78.0

var playing := false          # 遊んでいる（false のときはデモ）
var player_dir := 0.0         # -1 上／0／1 下
var left_y := H * 0.5
var right_y := H * 0.5
var ball := Vector2(W * 0.5, H * 0.5)
var vel := Vector2(110.0, 50.0)
var score_left := 0
var score_right := 0
var message := ""             # 勝ち負けの表示（"YOU WIN" / "YOU LOSE"）
var _message_time := 0.0
var _serve_wait := 0.6
var hits := 0                 # 打ち返した回数（テスト用）


func _ready() -> void:
	_serve(1.0)
	queue_redraw()


func start() -> void:
	playing = true
	score_left = 0
	score_right = 0
	message = ""
	_message_time = 0.0
	left_y = H * 0.5
	_serve(1.0)


func stop() -> void:
	playing = false
	player_dir = 0.0
	score_left = 0
	score_right = 0
	message = ""
	_serve(1.0)


func _serve(dir: float) -> void:
	ball = Vector2(W * 0.5, H * 0.5)
	var ang := randf_range(-0.5, 0.5)
	vel = Vector2(cos(ang) * 110.0 * dir, sin(ang) * 110.0)
	_serve_wait = 0.7


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


## 時間を delta 秒進める。
func step(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message = ""
			score_left = 0
			score_right = 0
			_serve(1.0)
		return
	# ラケット
	if playing:
		left_y += player_dir * PLAYER_SPEED * delta
	else:
		left_y = move_toward(left_y, ball.y, CPU_SPEED * 1.1 * delta)
	right_y = move_toward(right_y, ball.y + sin(Time.get_ticks_msec() * 0.002) * 6.0, CPU_SPEED * delta)
	left_y = clampf(left_y, PADDLE.y * 0.5, H - PADDLE.y * 0.5)
	right_y = clampf(right_y, PADDLE.y * 0.5, H - PADDLE.y * 0.5)
	if _serve_wait > 0.0:
		_serve_wait -= delta
		return
	ball += vel * delta
	# 上下の壁
	if ball.y < BALL * 0.5:
		ball.y = BALL * 0.5
		vel.y = absf(vel.y)
	elif ball.y > H - BALL * 0.5:
		ball.y = H - BALL * 0.5
		vel.y = -absf(vel.y)
	# ラケットで打ち返す（当たった位置で角度が変わり、少しずつ速くなる）
	var lx := 14.0 + PADDLE.x
	var rx := W - 14.0 - PADDLE.x
	if vel.x < 0.0 and ball.x < lx + BALL * 0.5 and ball.x > lx - PADDLE.x - BALL and absf(ball.y - left_y) < PADDLE.y * 0.5 + BALL * 0.5:
		_bounce(left_y, 1.0)
	elif vel.x > 0.0 and ball.x > rx - BALL * 0.5 and ball.x < rx + PADDLE.x + BALL and absf(ball.y - right_y) < PADDLE.y * 0.5 + BALL * 0.5:
		_bounce(right_y, -1.0)
	# 得点
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
		message = "YOU WIN"
		_message_time = 2.5
	elif playing and score_right >= WIN_SCORE:
		message = "YOU LOSE"
		_message_time = 2.5
	elif not playing and maxi(score_left, score_right) >= WIN_SCORE:
		score_left = 0
		score_right = 0
		_serve(next_dir)
	else:
		_serve(next_dir)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.04, 0.07, 0.12))
	for i in 12:
		draw_rect(Rect2(W * 0.5 - 1.0, 6.0 + i * 15.0, 2.0, 8.0), Color(0.25, 0.4, 0.55))
	draw_rect(Rect2(0, 0, W, 3), Color(0.25, 0.4, 0.55))
	draw_rect(Rect2(0, H - 3, W, 3), Color(0.25, 0.4, 0.55))
	var col := Color(0.55, 1.0, 0.7) if playing else Color(0.6, 0.7, 0.8)
	draw_rect(Rect2(14.0, left_y - PADDLE.y * 0.5, PADDLE.x, PADDLE.y), col)
	draw_rect(Rect2(W - 14.0 - PADDLE.x, right_y - PADDLE.y * 0.5, PADDLE.x, PADDLE.y), Color(1.0, 0.7, 0.5))
	draw_rect(Rect2(ball.x - BALL * 0.5, ball.y - BALL * 0.5, BALL, BALL), Color(1.0, 1.0, 0.9))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(W * 0.5 - 50.0, 30.0), str(score_left), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, col)
	draw_string(font, Vector2(W * 0.5 + 10.0, 30.0), str(score_right), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 24, Color(1.0, 0.7, 0.5))
	if not message.is_empty():
		draw_string(font, Vector2(0, H * 0.5 + 8.0), message, HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color(1.0, 0.95, 0.5))
	elif not playing:
		draw_string(font, Vector2(0, H - 14.0), "DEMO  - PRESS E TO PLAY", HORIZONTAL_ALIGNMENT_CENTER, W, 12, Color(0.7, 0.8, 0.9, 0.8))
	else:
		draw_string(font, Vector2(0, H - 10.0), "W/S  MOVE   E  QUIT", HORIZONTAL_ALIGNMENT_CENTER, W, 10, Color(0.6, 0.75, 0.9, 0.7))
