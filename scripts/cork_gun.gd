extends RefCounted
## コルク銃（細長いおもちゃのピストル）。冷蔵庫の上に、銃口を少しはみ出させて横たわっている。拾うと持ち物になり、F で撃つ。
## build()：見た目（原点は銃の中心、銃口が -z）。台の上でも、持ち物の拡大表示でも同じものを使う。

const MeshKit := preload("res://scripts/mesh_kit.gd")

const LENGTH := 0.42


static func build() -> Node3D:
	var n := Node3D.new()
	n.name = "CorkGun"
	var steel := MeshKit.mat("gun_steel", Color(0.32, 0.33, 0.36), 0.3, 0.8)
	var wood := MeshKit.mat("gun_wood", Color(0.5, 0.3, 0.16), 0.6)
	var dark := MeshKit.mat("gun_dark", Color(0.1, 0.1, 0.11), 0.4, 0.5)
	var gold := MeshKit.mat("gun_brass", Color(0.78, 0.62, 0.3), 0.3, 0.8)
	# 細長い銃身（-z が銃口）と、その下の銃身ごしの筒、木の機関部、グリップ
	var barrel := MeshKit.cylinder(n, 0.009, 0.26, Vector3(0, 0.02, -0.08), steel, "Barrel")
	barrel.rotation.x = PI * 0.5
	var muzzle := MeshKit.cylinder(n, 0.011, 0.012, Vector3(0, 0.02, -0.21), dark, "Muzzle")
	muzzle.rotation.x = PI * 0.5
	var tube := MeshKit.cylinder(n, 0.006, 0.18, Vector3(0, 0.0, -0.1), steel, "Tube")
	tube.rotation.x = PI * 0.5
	MeshKit.box(n, Vector3(0.03, 0.045, 0.16), Vector3(0, 0.005, 0.07), wood, "Body")
	MeshKit.box(n, Vector3(0.026, 0.07, 0.04), Vector3(0, -0.04, 0.14), wood, "Grip").rotation.x = deg_to_rad(-18.0)
	MeshKit.box(n, Vector3(0.006, 0.02, 0.012), Vector3(0, -0.012, 0.04), dark, "Trigger")
	MeshKit.box(n, Vector3(0.006, 0.014, 0.05), Vector3(0, -0.02, 0.06), steel, "Guard")
	MeshKit.box(n, Vector3(0.008, 0.022, 0.012), Vector3(0, 0.035, 0.145), steel, "Hammer").rotation.x = deg_to_rad(20.0)
	MeshKit.box(n, Vector3(0.032, 0.008, 0.02), Vector3(0, 0.03, 0.0), gold, "Sight")
	# コルクの栓（銃口に詰めてある）
	var cork := MeshKit.cylinder(n, 0.008, 0.02, Vector3(0, 0.02, -0.225), MeshKit.mat("gun_cork", Color(0.75, 0.58, 0.38), 0.9), "Cork")
	cork.rotation.x = PI * 0.5
	return n


## 持ち物の拡大表示用：横向きに寝かせて、小さくした銃。
static func zoom_model() -> Node3D:
	var holder := Node3D.new()
	holder.name = "GunModel"
	var g := build()
	g.rotation.y = PI * 0.5
	g.scale = Vector3.ONE * 0.45
	holder.add_child(g)
	return holder
