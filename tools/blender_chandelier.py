"""
宮殿のシャンデリアを、Blender で作って、glb に書き出すスクリプト。

使い方（Blender 3.6 以降。4.x でも動く想定）：
    blender --background --python tools/blender_chandelier.py -- assets/models/chandelier.glb

書き出したら、ゲームに取り込む（Godot が自動で読む）：
    1. assets/models/chandelier.glb に置く（上のコマンドのとおり）
    2. Godot で一度、プロジェクトを開く（または `Godot --headless --path . --import`）
    3. ゲームを起動する → ファイルがあれば、コードで作った仮のシャンデリアの代わりに、これが使われる

約束ごと（ゲーム側がこれを見て動く）：
  - 単位は m、原点＝天井の吊り元、下向きが「下」（Blender の -Z。書き出しで Y-up に変わる）。
  - 大きさ：直径 1.6 m、天井から下へ 0.45 m まで（部屋の天井は 2.2 m、頭より高く）。
  - 名前が「Bulb」で始まるメッシュ（Bulb_Center、Bulb_Candle_1 …）は、ゲーム側が灯りのマテリアルに差し替える
    （白／青に変わる、電球のスイッチと同じ動き）。**Bulb_Center は、外せる大きな電球**（ゲーム側が、見えなくする）。
  - それ以外の金・クリスタルは、このマテリアルのまま。
  - 影は、ゲーム側で落とさない設定にする。

自分で手直しするとき：下の PARAMS の数字を変える（段の数・腕の本数・クリスタルの数など）。
"""
import math
import sys

import bpy
import bmesh
from mathutils import Vector

# ---------------------------------------------------------------- 設定
PARAMS = {
    "tiers": [  # (半径, 高さ(下向きが負), 腕の本数, 回転オフセット)
        (0.80, -0.14, 12, 0.0),
        (0.64, -0.17, 12, math.pi / 12),
        (0.48, -0.20, 8, math.pi / 8),
        (0.30, -0.24, 6, math.pi / 6),
        (0.15, -0.27, 4, math.pi / 4),
    ],
    "arm_radius": 0.008,
    "crystals_per_arm": 3,
    "ring_swag_beads": 7,
    "outer_ring_crystals": 36,
    "crown_height": 0.0,
}

out_path = "assets/models/chandelier.glb"
if "--" in sys.argv:
    rest = sys.argv[sys.argv.index("--") + 1:]
    if rest:
        out_path = rest[0]

# ---------------------------------------------------------------- シーンを空にする
bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- マテリアル
def make_material(name, color, metallic=0.0, roughness=0.5, alpha=1.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            mat.blend_method = "BLEND"           # Blender 3.x
        except Exception:
            pass
        try:
            mat.surface_render_method = "BLENDED"  # Blender 4.2 以降
        except Exception:
            pass
    if emission is not None:
        key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[key].default_value = (*emission, 1.0)
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


GOLD = make_material("Gold", (0.92, 0.74, 0.32), metallic=1.0, roughness=0.16)
GOLD_DARK = make_material("GoldDark", (0.6, 0.45, 0.16), metallic=1.0, roughness=0.3)
CRYSTAL = make_material("Crystal", (0.9, 0.95, 1.0), metallic=0.0, roughness=0.02, alpha=0.55)
WAX = make_material("Wax", (0.96, 0.93, 0.85), roughness=0.6)
BULB = make_material("Bulb", (1.0, 0.95, 0.8), roughness=0.3, emission=(1.0, 0.85, 0.55), emission_strength=3.0)

gold_objects = []
crystal_objects = []


# ---------------------------------------------------------------- 部品
def link(obj, mat, group=None):
    obj.data.materials.append(mat)
    if group is not None:
        group.append(obj)
    return obj


def sphere(loc, radius, scale=(1, 1, 1), mat=GOLD, name="Sphere", group=None, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=segments, ring_count=max(8, segments // 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.shade_smooth()
    return link(o, mat, group)


def cylinder_between(p1, p2, radius, mat=GOLD, name="Rod", group=None, vertices=8):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    length = d.length
    if length < 1e-6:
        return None
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=length, vertices=vertices, location=(p1 + p2) * 0.5)
    o = bpy.context.active_object
    o.name = name
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = d.to_track_quat("Z", "Y")
    bpy.ops.object.shade_smooth()
    return link(o, mat, group)


def cone(loc, radius1, radius2, depth, mat=GOLD, name="Cone", group=None, vertices=16):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_smooth()
    return link(o, mat, group)


def torus(loc, major, minor, mat=GOLD, name="Torus", group=None, major_seg=48, minor_seg=8):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_radius=major, minor_radius=minor, major_segments=major_seg, minor_segments=minor_seg)
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.shade_smooth()
    return link(o, mat, group)


def crystal_drop(loc, size=0.018, stretch=2.3, name="Drop"):
    """しずく型クリスタル：8 角の、上下がとがった形（双円錐）。loc は、上端の吊り位置。"""
    h = size * stretch * 2.0
    center = (loc[0], loc[1], loc[2] - h * 0.5)
    bm = bmesh.new()
    top = bm.verts.new((0, 0, h * 0.5))
    bottom = bm.verts.new((0, 0, -h * 0.5))
    ring = []
    n = 8
    for i in range(n):
        a = math.tau * i / n
        ring.append(bm.verts.new((math.cos(a) * size, math.sin(a) * size, h * 0.12)))
    for i in range(n):
        bm.faces.new((top, ring[i], ring[(i + 1) % n]))
        bm.faces.new((bottom, ring[(i + 1) % n], ring[i]))
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    o.location = center
    link(o, CRYSTAL, crystal_objects)
    return o


def bezier_points(p0, p1, p2, p3, steps=12):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        a = (1 - t) ** 3
        b = 3 * (1 - t) ** 2 * t
        c = 3 * (1 - t) * t ** 2
        d = t ** 3
        pts.append(Vector((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                           a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1],
                           a * p0[2] + b * p1[2] + c * p2[2] + d * p3[2])))
    return pts


def curved_arm(direction, radius, z, arm_r):
    """中央から外へ、S 字に反る腕。先端の位置を返す。"""
    d = Vector((direction[0], direction[1], 0.0))
    p0 = Vector((0, 0, z + 0.03))
    p3 = d * radius + Vector((0, 0, z + 0.07))
    p1 = d * radius * 0.35 + Vector((0, 0, z - 0.07))
    p2 = d * radius * 0.75 + Vector((0, 0, z - 0.09))
    pts = bezier_points(p0, p1, p2, p3, steps=10)
    for i in range(len(pts) - 1):
        cylinder_between(pts[i], pts[i + 1], arm_r, GOLD, "Arm", gold_objects, vertices=6)
        if i % 3 == 2:
            sphere(pts[i + 1], arm_r * 1.7, mat=GOLD, name="ArmKnob", group=gold_objects, segments=10)
    return pts


# ---------------------------------------------------------------- 組み立て
# 天井の飾り板（原点が天井）
cone((0, 0, -0.012), 0.24, 0.1, 0.05, GOLD, "CeilingRose", gold_objects, vertices=40)
torus((0, 0, -0.03), 0.2, 0.012, GOLD_DARK, "RoseRing", gold_objects)
cylinder_between((0, 0, -0.03), (0, 0, -0.14), 0.012, GOLD, "Chain", gold_objects)

# 中央の柱：金の玉と輪を重ねる
z = -0.15
for k in range(5):
    r = 0.045 + 0.012 * (k % 2)
    sphere((0, 0, z), r, mat=GOLD, name="ColumnBall", group=gold_objects)
    torus((0, 0, z - r * 0.9), r * 1.5, 0.006, GOLD_DARK, "ColumnRing", gold_objects, major_seg=24, minor_seg=6)
    z -= r * 1.7
column_bottom = z

# 段の腕・受け皿・ろうそく・灯り・クリスタル
tip_points = []
candle_index = 0
for ti, (tr, ty, n, off) in enumerate(PARAMS["tiers"]):
    for i in range(n):
        a = math.tau * i / n + off
        direction = (math.cos(a), math.sin(a))
        pts = curved_arm(direction, tr, ty, PARAMS["arm_radius"])
        tip = pts[-1]
        if ti == 0:
            tip_points.append(tip)
        # 受け皿・ろうそく・灯り
        cone((tip.x, tip.y, tip.z + 0.005), 0.032, 0.016, 0.022, GOLD, "Cup", gold_objects, vertices=14)
        torus((tip.x, tip.y, tip.z + 0.016), 0.028, 0.004, GOLD, "DripPan", gold_objects, major_seg=16, minor_seg=6)
        c = bpy.ops.mesh.primitive_cylinder_add(radius=0.012, depth=0.05, location=(tip.x, tip.y, tip.z + 0.04), vertices=10)
        wax = bpy.context.active_object
        wax.name = "Wax"
        link(wax, WAX, gold_objects)
        candle_index += 1
        sphere((tip.x, tip.y, tip.z + 0.085), 0.016, scale=(0.75, 0.75, 1.6), mat=BULB, name="Bulb_Candle_%d" % candle_index)
        # 腕の途中から下がるクリスタル
        for k in range(PARAMS["crystals_per_arm"]):
            idx = int(len(pts) * (0.45 + 0.22 * k))
            idx = min(idx, len(pts) - 1)
            p = pts[idx]
            hang = 0.03 + 0.03 * (k % 2)
            cylinder_between((p.x, p.y, p.z), (p.x, p.y, p.z - hang), 0.0018, GOLD, "Wire", gold_objects, vertices=4)
            crystal_drop((p.x, p.y, p.z - hang), 0.019, 2.3, "Drop")

# 外側の輪と、輪のあいだの飾り紐（たるむ玉の列）
outer_r = PARAMS["tiers"][0][0]
ring_z = PARAMS["tiers"][0][1] + 0.07
torus((0, 0, ring_z), outer_r, 0.006, GOLD, "OuterRing", gold_objects, major_seg=96, minor_seg=6)
m = len(tip_points)
for i in range(m):
    p1 = tip_points[i]
    p2 = tip_points[(i + 1) % m]
    for k in range(PARAMS["ring_swag_beads"]):
        u = (k + 1) / (PARAMS["ring_swag_beads"] + 1)
        p = p1.lerp(p2, u)
        sag = 0.07 * math.sin(math.pi * u) + 0.02
        sphere((p.x, p.y, p.z - sag), 0.009, mat=CRYSTAL, name="Bead", group=crystal_objects, segments=8)
    mid = p1.lerp(p2, 0.5)
    crystal_drop((mid.x, mid.y, mid.z - 0.09), 0.022, 2.4, "SwagDrop")
# 輪から垂れる、たくさんの小さなクリスタル
n_out = PARAMS["outer_ring_crystals"]
for i in range(n_out):
    a = math.tau * i / n_out
    x, y = math.cos(a) * outer_r, math.sin(a) * outer_r
    cylinder_between((x, y, ring_z), (x, y, ring_z - 0.04), 0.0015, GOLD, "Wire", gold_objects, vertices=4)
    crystal_drop((x, y, ring_z - 0.04), 0.012, 2.8, "RingDrop")

# 中央の、大きなしずく（いちばん下は、天井から 0.45 m 以内）
sphere((0, 0, column_bottom - 0.02), 0.07, mat=BULB, name="Bulb_Center", segments=24)   # 外せる大きな電球
for i in range(7):
    a = math.tau * i / 7
    rp = 0.1 if i > 0 else 0.0
    x, y = math.cos(a) * rp, math.sin(a) * rp
    zt = column_bottom - 0.05
    cylinder_between((x, y, zt), (x, y, zt - 0.03), 0.002, GOLD, "Wire", gold_objects, vertices=4)
    crystal_drop((x, y, zt - 0.03), 0.028, 2.0 if i == 0 else 1.6, "CenterDrop")

# ---------------------------------------------------------------- まとめる（物の数を減らす）
def join(objs, name):
    objs = [o for o in objs if o and o.name in bpy.data.objects]
    if len(objs) < 2:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    bpy.context.active_object.name = name


join(gold_objects, "Gold")
join(crystal_objects, "Crystals")

# ---------------------------------------------------------------- 書き出し
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_apply=True, export_materials="EXPORT", export_yup=True)
print("書き出した:", out_path)
