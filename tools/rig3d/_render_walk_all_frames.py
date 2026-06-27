"""Renderiza TODOS os 24 frames do walk cycle (pra montar GIF depois).
Usa o cache de cloth ja bakeado em soph_walk_test.blend."""
import bpy, os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_walk_test.blend")
OUT = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "walk_test")

bpy.ops.wm.open_mainfile(filepath=BLEND)

cam = bpy.data.objects.get("cam_3q")
sc = bpy.context.scene
sc.camera = cam
sc.render.resolution_x = 384  # menor pro gif rodar leve
sc.render.resolution_y = 576
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"

for f in range(1, 25):
    sc.frame_set(f)
    out_png = os.path.join(OUT, f"walk_full_f{f:02d}.png")
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print(f"[render] f{f:02d} -> {out_png}")

print("[done] 24 frames OK")
