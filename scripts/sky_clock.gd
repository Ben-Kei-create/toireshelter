extends Node
## プレイ時間による空模様の変化。窓の外・ベランダ・廊下から見える空を、3枚の全天の絵（昼・夕焼け・夕暮れ）の混ぜ合わせで描く。
## 時間は main.gd が一時停止中を除いたプレイ時間（秒）を渡す（set_time）。時間の流れ（秒）：
##   0〜120      昼（青空）
##   120〜300    昼 → 夕焼け（なめらかに）
##   300〜420    夕焼け
##   420〜600    夕焼け → 夕暮れ
##   600〜       夕暮れ（青紫の空とわずかな赤）
## 空以外にも反映する：環境光の色と強さ、窓から差す光（daylight と window_color。apartment.gd の窓の灯りが使う）、
## 廊下から見える月（夕暮れに現れる。corridor.gd が weights_changed を受ける）。
## 絵は assets/textures/sky/sky_day・sky_sunset・sky_dusk.png（1774×887、ユーザー作成、生成 AI 使用）。

signal weights_changed(day: float, sunset: float, dusk: float)

const SHADER := """
shader_type sky;
uniform sampler2D day_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sunset_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dusk_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 w = vec3(1.0, 0.0, 0.0);
void sky() {
	vec3 d = normalize(EYEDIR);
	vec2 uv = vec2(atan(d.x, -d.z) / TAU + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
	vec3 c = textureLod(day_tex, uv, 0.5).rgb * w.x + textureLod(sunset_tex, uv, 0.5).rgb * w.y + textureLod(dusk_tex, uv, 0.5).rgb * w.z;
	COLOR = c;
}
"""

const T_DAY_END := 120.0
const T_SUNSET_START := 300.0
const T_SUNSET_END := 420.0
const T_DUSK_START := 600.0

# 昼・夕焼け・夕暮れそれぞれの環境光（色、強さ）、窓から差す光（色、強さ）
const AMBIENT := [[Color(0.82, 0.8, 0.78), 0.42], [Color(0.85, 0.72, 0.62), 0.4], [Color(0.62, 0.62, 0.78), 0.34]]
const WINDOW := [[Color(0.88, 0.94, 1.0), 1.0], [Color(1.0, 0.62, 0.38), 0.65], [Color(0.45, 0.5, 0.9), 0.25]]

var time := 0.0
var ambient_scale := 1.0                 # 環境光の倍率（停電のあと、部屋の中が真っ暗になるよう小さくする）
var weights := Vector3(1.0, 0.0, 0.0)   # 昼・夕焼け・夕暮れの割合（合計 1）
var daylight := 1.0                      # 窓から差す光の強さ（昼 1.0）
var window_color := Color.WHITE
var _env: Environment
var _mat: ShaderMaterial


func setup(env: Environment) -> void:
	_env = env
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("day_tex", load("res://assets/textures/sky/sky_day.png"))
	_mat.set_shader_parameter("sunset_tex", load("res://assets/textures/sky/sky_sunset.png"))
	_mat.set_shader_parameter("dusk_tex", load("res://assets/textures/sky/sky_dusk.png"))
	var sky := Sky.new()
	sky.sky_material = _mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	set_time(0.0)


## プレイ時間 t（秒）の空にする。
func set_time(t: float) -> void:
	time = maxf(t, 0.0)
	var a := smoothstep(T_DAY_END, T_SUNSET_START, time)    # 昼から夕焼けへ
	var b := smoothstep(T_SUNSET_END, T_DUSK_START, time)   # 夕焼けから夕暮れへ
	weights = Vector3((1.0 - a), a * (1.0 - b), a * b)
	if _mat == null:
		return
	_mat.set_shader_parameter("w", weights)
	var amb := Color(0, 0, 0)
	var amb_e := 0.0
	var win := Color(0, 0, 0)
	var win_e := 0.0
	for i in 3:
		var k: float = [weights.x, weights.y, weights.z][i]
		amb += (AMBIENT[i][0] as Color) * k
		amb_e += float(AMBIENT[i][1]) * k
		win += (WINDOW[i][0] as Color) * k
		win_e += float(WINDOW[i][1]) * k
	_env.ambient_light_color = amb
	_env.ambient_light_energy = amb_e * ambient_scale
	window_color = win
	daylight = win_e
	weights_changed.emit(weights.x, weights.y, weights.z)
