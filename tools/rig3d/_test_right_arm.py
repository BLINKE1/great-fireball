"""Testa 4 combinacoes pro RightArm — renderiza 1 frame pra cada.
Left fica fixo com rz=-72 (sabemos que funciona)."""
import bpy, os, math

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_cloth_test.blend")
OUT = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "arm_tests")
os.makedirs(OUT, exist_ok=True)

TESTS = [
    ("rz_pos",  (0, 0,  72)),
    ("ry_pos",  (0, 72,  0)),
    ("ry_neg",  (0, -72, 0)),
    ("rx_pos",  (72, 0,  0)),
    ("rx_neg",  (-72, 0, 0)),
    ("rz_pos_ry_neg", (0, -45, 72)),  # combo
]

bpy.ops.wm.open_mainfile(filepath=IN)

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))
cam = bpy.data.objects.get("cam_3q") or bpy.data.objects.get("cam_front")

# Remove cloth modifier — pose teste, nao precisa simular (e o cloth bakeado em
# T-pose ja vai dar problema com nova pose). Mostramos so o skin deformado.
for m in list(mesh.modifiers):
    if m.type == 'CLOTH':
        mesh.modifiers.remove(m)

bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='POSE')

la = arm.pose.bones.get("mixamorig:LeftArm")
ra = arm.pose.bones.get("mixamorig:RightArm")

# Left sempre rz=-72
la.rotation_mode = 'XYZ'
la.rotation_euler = (0, 0, math.radians(-72))

sc = bpy.context.scene
sc.camera = cam
sc.render.resolution_x = 384
sc.render.resolution_y = 576
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"

for name, (rx, ry, rz) in TESTS:
    ra.rotation_mode = 'XYZ'
    ra.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bpy.context.view_layer.update()
    out_png = os.path.join(OUT, f"right_{name}.png")
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print(f"[test] {name} rx={rx} ry={ry} rz={rz} -> {out_png}")

print("[done]")
