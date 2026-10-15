extends RefCounted
## 音の設定（全体音量・効果音・環境音）。Esc の設定画面で変え、user://settings.cfg に保存する。
## 音は3つのバス（Master・SFX・Ambient）に分ける。効果音（sfx.gd）は SFX、換気扇・路地・しずく（ambient_sound.gd）は Ambient。
## 音量は 0〜1（0 は無音）。効果音と環境音はそれぞれオン／オフもできる（オフは完全に消す）。

const PATH := "user://settings.cfg"

static var master := 1.0
static var sfx := 1.0
static var ambient := 1.0
static var sfx_on := true
static var ambient_on := true
static var earplugs := false   # 耳栓をつけている（つかみ取りの景品 4）：全体の音が小さくなり、環境音は特に小さくなる


## SFX・Ambient のバスがなければ作る（Master へ流す）。音を鳴らす節点を作る前に呼ぶ。
static func ensure_buses() -> void:
	for n in ["SFX", "Ambient"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
			var rv := AudioEffectReverb.new()   # 部屋の響き（場所ごとに wet を変える）
			rv.room_size = 0.5
			rv.damping = 0.6
			rv.wet = 0.06
			rv.dry = 1.0
			AudioServer.add_bus_effect(i, rv, 0)
			AudioServer.add_bus_effect(i, AudioEffectLowPassFilter.new(), 1)   # こたつの中・座っているときなど、こもらせる
			(AudioServer.get_bus_effect(i, 1) as AudioEffectLowPassFilter).cutoff_hz = 20000.0


## 今いる場所の響き：reverb は 0〜1（浴室は大きく、こたつの中は小さく）、cutoff はこもり（Hz。20000 でこもらない）。効果音と環境音の両方に効く。
static func set_space(reverb: float, cutoff: float) -> void:
	ensure_buses()
	for n in ["SFX", "Ambient"]:
		var i := AudioServer.get_bus_index(n)
		(AudioServer.get_bus_effect(i, 0) as AudioEffectReverb).wet = reverb
		(AudioServer.get_bus_effect(i, 1) as AudioEffectLowPassFilter).cutoff_hz = cutoff


static func set_earplugs(on: bool) -> void:
	earplugs = on
	apply()


static func apply() -> void:
	ensure_buses()
	_set_bus("Master", master * (0.5 if earplugs else 1.0), true)
	_set_bus("SFX", sfx, sfx_on)
	_set_bus("Ambient", ambient * (0.4 if earplugs else 1.0), ambient_on)


static func _set_bus(bus: String, linear: float, enabled: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, not enabled or linear <= 0.0)


## key：master / sfx / ambient（0〜1）、sfx_on / ambient_on（真偽）。
static func set_value(key: String, value: Variant) -> void:
	match key:
		"master":
			master = clampf(float(value), 0.0, 1.0)
		"sfx":
			sfx = clampf(float(value), 0.0, 1.0)
		"ambient":
			ambient = clampf(float(value), 0.0, 1.0)
		"sfx_on":
			sfx_on = bool(value)
		"ambient_on":
			ambient_on = bool(value)
	apply()


static func load_from(cfg: ConfigFile) -> void:
	master = float(cfg.get_value("audio", "master", 1.0))
	sfx = float(cfg.get_value("audio", "sfx", 1.0))
	ambient = float(cfg.get_value("audio", "ambient", 1.0))
	sfx_on = bool(cfg.get_value("audio", "sfx_on", true))
	ambient_on = bool(cfg.get_value("audio", "ambient_on", true))
	apply()


static func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "ambient", ambient)
	cfg.set_value("audio", "sfx_on", sfx_on)
	cfg.set_value("audio", "ambient_on", ambient_on)
