"""Roda cloth sim em cima da anim PRO retargetada (idle ou walk) e renderiza
todos os frames pro gif final.

A nuvem assou as anims Mixamo retargetadas em .glb (bracos abaixados, sem
placeholder). Aqui: importa o glb, aplica o pin map (mesma heuristica do
auto_pin_map.py), bota Cloth modifier, baka pra anim toda, renderiza.

Uso:
  blender --background --python tools/rig3d/make_anim_cloth.py -- idle
  blender --background --python tools/rig3d/make_anim_cloth.py -- walk

Saida:
  tools/rig3d/out/dream_rig/{idle,walk}_pro/frame_NN.png
  tools/rig3d/out/dream_rig/soph_{idle,walk}_pro.blend

Depois:
  python tools/rig3d/_make_gif.py {idle,walk}_pro soph_{idle,walk}_pro
"""

import bpy, os, sys, math
import mathutils as mu

# Reusa heuristica do auto_pin_map (mesma topologia da mesh -> mesmo pin map)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from auto_pin_map import classify_verts, write_vertex_group


REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN_DIR = os.path.join(REPO, "tools", "rig3d", "in")
OUT_DIR = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig")

# Render
RES_W, RES_H = 384, 576
CAM_DIST = 2.6
EL_DEG = 8.0

# Resampling: as anims sao 30fps (180f idle, 56f walk). Renderiza 1 a cada
# REND_STEP frames pra controlar tamanho do gif. step=2 = 15fps = bom pro gif.
REND_STEP = 2


def parse_anim():
    argv = sys.argv
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
        if rest:
            return rest[0].strip().lower()
    return "idle"


def pick_eevee():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            return eng
        except Exception:
            pass
    return None


def import_glb(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    mesh = max(meshes, key=lambda o: len(o.data.vertices))
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    return mesh, arm


def get_action_range(arm):
    """Pega o intervalo de frames da Action ligada ao armature."""
    if arm.animation_data and arm.animation_data.action:
        act = arm.animation_data.action
        fs, fe = act.frame_range
        return int(fs), int(fe), act.name
    return 1, 60, None


def add_cloth(mesh):
    for m in list(mesh.modifiers):
        if m.type == 'CLOTH':
            mesh.modifiers.remove(m)
    cloth = mesh.modifiers.new(name="Cloth", type='CLOTH')
    cs = cloth.settings
    if "cloth_pin" not in mesh.vertex_groups:
        raise RuntimeError("vertex group 'cloth_pin' ausente")
    cs.vertex_group_mass = "cloth_pin"
    cs.mass = 0.3
    cs.tension_stiffness = 30.0
    cs.compression_stiffness = 30.0
    cs.shear_stiffness = 10.0
    cs.bending_stiffness = 5.0
    cs.tension_damping = 5.0
    cs.compression_damping = 5.0
    cs.shear_damping = 5.0
    cs.bending_damping = 0.5
    cs.gravity = (0.0, 0.0, -3.0)
    cloth.collision_settings.use_collision = False
    cloth.collision_settings.use_self_collision = False
    return cloth


def bake_cloth(mesh, frame_start, frame_end):
    cloth = next(m for m in mesh.modifiers if m.type == 'CLOTH')
    pc = cloth.point_cache
    pc.frame_start = frame_start
    pc.frame_end = frame_end

    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end

    print(f"[bake] cloth {frame_start}..{frame_end} ({frame_end - frame_start + 1} frames)")
    try:
        bpy.ops.ptcache.free_bake_all()
    except Exception as e:
        print(f"[bake] free falhou (ignorando): {e}")
    override = bpy.context.copy()
    override['scene'] = bpy.context.scene
    override['active_object'] = mesh
    override['object'] = mesh
    with bpy.context.temp_override(**override):
        bpy.ops.ptcache.bake_all(bake=True)
    print("[bake] OK")


def add_sun_light(center):
    sun_data = bpy.data.lights.new(name="SophSun", type='SUN')
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("SophSun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.location = (center[0] + 2, center[1] - 2, center[2] + 3)
    sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-30))
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.6, 0.6, 0.6, 1.0)
        bg.inputs[1].default_value = 0.5


def setup_camera(name, location, look_at, ortho_scale=1.4):
    cd = bpy.data.cameras.new(name)
    cd.type = 'ORTHO'
    cd.ortho_scale = ortho_scale
    cam = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = location
    direction = mu.Vector(look_at) - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    return cam


def main():
    anim = parse_anim()
    if anim not in ("idle", "walk"):
        raise SystemExit(f"anim invalida: {anim} — use 'idle' ou 'walk'")

    in_glb = os.path.join(IN_DIR, f"soph_{anim}_retargeted.glb")
    if not os.path.exists(in_glb):
        raise SystemExit(f"input nao existe: {in_glb}")

    out_sub = os.path.join(OUT_DIR, f"{anim}_pro")
    os.makedirs(out_sub, exist_ok=True)

    print("=" * 60)
    print(f"ANIM-PRO + CLOTH — {anim.upper()}")
    print(f"input:  {in_glb}")
    print(f"output: {out_sub}")
    print("=" * 60)

    mesh, arm = import_glb(in_glb)
    pick_eevee()
    print(f"[import] mesh={mesh.name} ({len(mesh.data.vertices)}v), arm={arm.name} ({len(arm.data.bones)}b)")

    fs, fe, act_name = get_action_range(arm)
    print(f"[anim] action='{act_name}' frames {fs}..{fe}")

    # Pin map (mesma topologia da base -> mesma classificacao)
    pins, cats, counts = classify_verts(mesh, arm)
    write_vertex_group(mesh, pins)
    print("[pin] cloth_pin gravado")
    for k, v in counts.items():
        if v:
            print(f"  {k:12s} {v:6d} ({100*v/len(pins):5.1f}%)")

    # Cloth + bake
    add_cloth(mesh)
    bake_cloth(mesh, fs, fe)

    # Camera 3/4 depois do bake
    bb = [mesh.matrix_world @ mu.Vector(c) for c in mesh.bound_box]
    cx = sum(v.x for v in bb) / 8.0
    cy = sum(v.y for v in bb) / 8.0
    cz = sum(v.z for v in bb) / 8.0
    center = (cx, cy, cz)
    el_rad = math.radians(EL_DEG)
    cam = setup_camera("cam_3q",
                       (cx + CAM_DIST * 0.7, cy - CAM_DIST * 0.7,
                        cz + CAM_DIST * math.tan(el_rad)),
                       center)
    add_sun_light(center)

    # Render
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.resolution_x = RES_W
    sc.render.resolution_y = RES_H
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"

    out_index = 0
    for f in range(fs, fe + 1, REND_STEP):
        sc.frame_set(f)
        out_png = os.path.join(out_sub, f"frame_{out_index:03d}.png")
        sc.render.filepath = out_png
        bpy.ops.render.render(write_still=True)
        if out_index % 5 == 0 or f >= fe:
            print(f"[render] f{f:03d} -> frame_{out_index:03d}.png")
        out_index += 1

    print(f"[render] {out_index} frames gravados em {out_sub}")

    blend_out = os.path.join(OUT_DIR, f"soph_{anim}_pro.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    print(f"[blend] {blend_out}")
    print("\nPRONTO. Monta o gif com:")
    print(f"  python tools/rig3d/_make_gif.py {anim}_pro soph_{anim}_pro")


if __name__ == "__main__":
    main()
