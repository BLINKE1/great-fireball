"""Smoke: o Blender renderiza headless nesta maquina? (cubo -> PNG transparente)
  blender --background --python tools/rig3d/_smoke.py
"""
import bpy, os, math
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
eng_ok = None
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        sc.render.engine = eng; eng_ok = eng; break
    except Exception as e:
        print("engine falhou:", eng, e)
print("[smoke] engine =", eng_ok)

bpy.ops.mesh.primitive_cube_add(size=2)
cam_d = bpy.data.cameras.new("c"); cam = bpy.data.objects.new("c", cam_d)
sc.collection.objects.link(cam); cam.location = (4, -4, 3)
cam.rotation_euler = (math.radians(60), 0, math.radians(45)); sc.camera = cam
sun_d = bpy.data.lights.new("s", "SUN"); sun = bpy.data.objects.new("s", sun_d)
sc.collection.objects.link(sun); sun.rotation_euler = (math.radians(50), 0, 0)

sc.render.resolution_x = 256; sc.render.resolution_y = 256
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
out = os.path.abspath("tools/rig3d/out/_smoke.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("[smoke] salvou:", out, "existe?", os.path.exists(out))
