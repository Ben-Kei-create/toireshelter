extends RefCounted
## 主人公の「自分の目から見える体」。ちょー雑な3Dで、下を向いたときに見える：ワインレッドの長いコートと、クリーム色のベスト（首のまわりは目に近すぎるので作っていない）、
## コートの袖と手（金の指輪）、ズボンと革靴。ユーザーのキャラクター画（assets/textures/character/）の色と服装に合わせた。
## 第三者から見える姿は切り抜き画像（character.gd：等身大パネル・鏡の顔）で、これは自分の視点だけのためのもの。
## 当たり判定・影なし。player.gd が足元に付け、歩くと脚と腕が振れ、しゃがむと縮み、座る・浴槽・こたつ・ダクトの姿勢では隠す。
## 座標は player のローカル（足元が原点、前が -z）。目は y 1.5・z 0。体は目より少し後ろ（+z）に置いて、頭のなかにめり込まないようにしてある。

const MeshKit := preload("res://scripts/mesh_kit.gd")

## 戻り値：ルート節点。meta に "legs"（左右の脚）と "arms"（左右の腕）を持つ。
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "BodyRig"
	root.position = Vector3(0.0, 0.0, -0.08)   # 少し前へ（真下を向くと胸が見え、少し前を見ると脚と靴の先が見える）
	var wine := MeshKit.mat("body_coat", Color(0.33, 0.12, 0.17), 0.85)
	var wine2 := MeshKit.mat("body_trousers", Color(0.28, 0.1, 0.15), 0.85)
	var cream := MeshKit.mat("body_cream", Color(0.92, 0.88, 0.78), 0.9)
	var skin := MeshKit.mat("body_skin", Color(0.42, 0.28, 0.19), 0.7)
	var gold := MeshKit.mat("body_gold", Color(0.85, 0.7, 0.3), 0.3, 0.9)
	var shoe := MeshKit.mat("body_shoe", Color(0.16, 0.06, 0.05), 0.4)
	# 胴：コートの胸（目の下）。前の合わせに、ベストのクリーム色とボタン、首のまわりに金の首飾り
	var chest := MeshKit.box(root, Vector3(0.44, 0.5, 0.2), Vector3(0.0, 1.15, 0.2), wine, "Chest")
	MeshKit.box(root, Vector3(0.14, 0.42, 0.01), Vector3(0.0, 1.17, 0.095), cream, "Vest")
	for k in 3:
		MeshKit.sphere(root, 0.007, Vector3(0.0, 1.2 - k * 0.07, 0.088), shoe)
	# コートのすそ（長い）：腰から太ももまで
	MeshKit.box(root, Vector3(0.46, 0.42, 0.22), Vector3(0.0, 0.72, 0.17), wine, "CoatSkirt")
	chest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 脚（左右）：腰を軸に前後へ振る。ズボンはゆったり、革靴の先が前へ
	var legs: Array = []
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "Leg%s" % ("L" if side < 0.0 else "R")
		leg.position = Vector3(side * 0.11, 0.9, 0.0)
		root.add_child(leg)
		MeshKit.box(leg, Vector3(0.17, 0.82, 0.19), Vector3(0.0, -0.41, 0.0), wine2, "Trouser")
		MeshKit.box(leg, Vector3(0.14, 0.07, 0.31), Vector3(0.0, -0.865, -0.07), shoe, "Shoe")
		MeshKit.box(leg, Vector3(0.14, 0.012, 0.31), Vector3(0.0, -0.9, -0.07), MeshKit.mat("body_sole", Color(0.05, 0.03, 0.03), 0.8), "Sole")
		MeshKit.box(leg, Vector3(0.03, 0.03, 0.06), Vector3(0.0, -0.84, -0.17), gold, "Buckle")
		legs.append(leg)
	# 腕（左右）：肩を軸に前後へ振る。コートの袖と、手（金の指輪）
	var arms: Array = []
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm%s" % ("L" if side < 0.0 else "R")
		arm.position = Vector3(side * 0.28, 1.38, 0.18)
		root.add_child(arm)
		MeshKit.box(arm, Vector3(0.12, 0.5, 0.13), Vector3(0.0, -0.25, -0.04), wine, "Sleeve")
		MeshKit.box(arm, Vector3(0.07, 0.025, 0.07), Vector3(0.0, -0.51, -0.04), cream, "Cuff")
		MeshKit.box(arm, Vector3(0.075, 0.1, 0.045), Vector3(0.0, -0.585, -0.04), skin, "Hand")
		MeshKit.box(arm, Vector3(0.078, 0.008, 0.048), Vector3(0.0, -0.56, -0.04), gold, "Ring")
		arm.rotation.x = deg_to_rad(-8.0)   # 少し前へ
		arms.append(arm)
	root.set_meta("legs", legs)
	root.set_meta("arms", arms)
	return root


## 歩く速さ（0〜1）と歩行の位相に合わせて、脚と腕を振る。
static func animate(rig: Node3D, walk: float, phase: float) -> void:
	var swing := sin(phase) * 0.55 * walk
	var legs: Array = rig.get_meta("legs")
	var arms: Array = rig.get_meta("arms")
	(legs[0] as Node3D).rotation.x = swing
	(legs[1] as Node3D).rotation.x = -swing
	(arms[0] as Node3D).rotation.x = deg_to_rad(-8.0) - swing * 0.7
	(arms[1] as Node3D).rotation.x = deg_to_rad(-8.0) + swing * 0.7
