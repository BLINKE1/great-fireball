"""Cloth test — roda sim de pano no mesh ja com pin map aplicado e renderiza
alguns frames pra Will ver se a robe drapeja certo.

Entrada:
  tools/rig3d/out/dream_rig/soph_auto_pin.blend
  (gerado por auto_pin_map.py — ja tem vertex group 'cloth_pin')

Saidas:
  tools/rig3d/out/dream_rig/cloth_test_f{01,30,60}_{front,3q}.png  (6 PNGs)
  tools/rig3d/out/dream_rig/soph_cloth_test.blend (cena com cache da sim)

Estrategia (atalho do Will, DREAM_RIG_FREE.md):
  - Cloth + gravidade + pin group SEM collision do corpo
  - Camera 3/4 fixa, oclusao esconde penetracao na malha interna
  - Resultado: setup rapido, bake rapido, mesmo frame final

Pra rodar:
  blender --background --python tools/rig3d/cloth_test.py
"""

import bpy, os, math
import mathutils as mu


REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN_BLEND = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_auto_pin.blend")
OUT_DIR = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig")

# Quantos frames de sim. Cloth precisa de uns 30-60 pra assentar com gravidade.
SIM_FRAMES = 60
RENDER_FRAMES = [1, 30, 60]   # T-pose, meio do cair, assentado
RES_W, RES_H = 512, 768
CAM_DIST = 2.6
EL_DEG = 8.0


def pick_eevee():
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            sc.render.engine = eng
            return eng
        except Exception:
            pass
    return None


def find_soph_mesh():
    """Pega o maior mesh (mesmo criterio do auto_pin_map)."""
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    if not meshes:
        raise RuntimeError("nenhum mesh na cena")
    return max(meshes, key=lambda o: len(o.data.vertices))


def clean_scene_junk(soph_mesh):
    """Remove icospheres, default cubes, e cameras antigas que ficam de carona
    do BlenderMCP ou de runs anteriores. Soph + armature sao preservados."""
    junk_count = 0
    soph_arm = None
    # Acha armature ligada ao mesh (modifier Armature)
    for m in soph_mesh.modifiers:
        if m.type == 'ARMATURE' and m.object:
            soph_arm = m.object
            break

    to_remove = []
    for o in bpy.data.objects:
        if o is soph_mesh or o is soph_arm:
            continue
        # Remove cameras antigas, icospheres, default cubes
        if o.type == 'CAMERA':
            to_remove.append(o)
        elif o.type == 'MESH' and o.name.lower().startswith(('icosphere', 'cube', 'sphere')):
            to_remove.append(o)
        elif o.type == 'LIGHT':
            to_remove.append(o)  # vamos adicionar uma sun nova

    for o in to_remove:
        bpy.data.objects.remove(o, do_unlink=True)
        junk_count += 1
    print(f"[clean] removidos {junk_count} objetos (cameras, icospheres, lights antigas)")


def add_sun_light(center):
    """Sun light pra Material Preview / render nao sair preto."""
    sun_data = bpy.data.lights.new(name="SophSun", type='SUN')
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("SophSun", sun_data)
    bpy.context.scene.collection.objects.link(sun)
    sun.location = (center[0] + 2, center[1] - 2, center[2] + 3)
    sun.rotation_euler = (math.radians(45), math.radians(20), math.radians(-30))
    # World ambient claro pra nao sair com sombras pretas
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.6, 0.6, 0.6, 1.0)
        bg.inputs[1].default_value = 0.5


def add_cloth_modifier(mesh_obj):
    """Adiciona Cloth no mesh com pin group = 'cloth_pin', sem collision do corpo."""
    # Remove cloth anterior se houver
    for m in list(mesh_obj.modifiers):
        if m.type == 'CLOTH':
            mesh_obj.modifiers.remove(m)

    cloth = mesh_obj.modifiers.new(name="Cloth", type='CLOTH')
    cs = cloth.settings

    # Pin group: vertex group que o auto_pin_map criou
    if "cloth_pin" not in mesh_obj.vertex_groups:
        raise RuntimeError("mesh nao tem vertex group 'cloth_pin' — rode auto_pin_map.py antes")
    cs.vertex_group_mass = "cloth_pin"

    # Preset "robe de maga firme" — balanca, mas nao vira gel.
    # Anterior (bending=0.5, gravity=-9.81 com pin 0.2) virou a Soph numa panqueca
    # de 43cm. Subi bending e reduzi gravidade pra teste estatico em T-pose.
    cs.mass = 0.3
    cs.tension_stiffness = 30.0   # era 15.0
    cs.compression_stiffness = 30.0
    cs.shear_stiffness = 10.0
    cs.bending_stiffness = 5.0    # era 0.5 (10x mais rigido contra dobrar)
    cs.tension_damping = 5.0
    cs.compression_damping = 5.0
    cs.shear_damping = 5.0
    cs.bending_damping = 0.5

    # Gravidade reduzida (-3 em vez de -9.81) — pano vai cair, mas sem espremer
    cs.gravity = (0.0, 0.0, -3.0)

    # Sem self-collision (caro) — comeca simples
    cloth.collision_settings.use_collision = False
    cloth.collision_settings.use_self_collision = False

    # Point cache: bake do frame 1 ate SIM_FRAMES
    pc = cloth.point_cache
    pc.frame_start = 1
    pc.frame_end = SIM_FRAMES

    return cloth


def bake_cloth(mesh_obj):
    """Bake do cache do cloth modifier."""
    # Selecionar mesh e setar como ativo (bake_all requer)
    bpy.ops.object.select_all(action='DESELECT')
    mesh_obj.select_set(True)
    bpy.context.view_layer.objects.active = mesh_obj

    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = SIM_FRAMES

    print(f"[bake] simulando {SIM_FRAMES} frames de cloth... (pode demorar)")
    # Override no contexto pro bake achar o modifier certo
    override = bpy.context.copy()
    override['scene'] = bpy.context.scene
    override['active_object'] = mesh_obj
    override['object'] = mesh_obj
    with bpy.context.temp_override(**override):
        bpy.ops.ptcache.bake_all(bake=True)
    print(f"[bake] OK")


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


def render_frame(cam, frame, out_png):
    sc = bpy.context.scene
    sc.frame_set(frame)
    sc.camera = cam
    sc.render.resolution_x = RES_W
    sc.render.resolution_y = RES_H
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = out_png
    bpy.ops.render.render(write_still=True)


def main():
    print("=" * 60)
    print("CLOTH TEST — robe drape sim")
    print("=" * 60)
    print(f"Input:  {IN_BLEND}")
    print(f"Output: {OUT_DIR}")

    if not os.path.exists(IN_BLEND):
        raise RuntimeError(f"input nao existe: {IN_BLEND} — rode auto_pin_map.py primeiro")

    # Abrir .blend com o pin map ja aplicado
    bpy.ops.wm.open_mainfile(filepath=IN_BLEND)
    eng = pick_eevee()
    print(f"[engine] {eng}")

    mesh = find_soph_mesh()
    print(f"[mesh] {mesh.name} ({len(mesh.data.vertices)} verts)")

    # Limpa lixo da cena (icospheres, cameras antigas, lights antigas)
    clean_scene_junk(mesh)

    # Adicionar cloth + bake
    add_cloth_modifier(mesh)
    print(f"[cloth] modifier adicionado, pin_group='cloth_pin', gravity=-3.0, sem collision")
    bake_cloth(mesh)

    # Calcular cameras DEPOIS do bake (bb pode ter mudado se a sim deformou)
    bb = [mesh.matrix_world @ mu.Vector(c) for c in mesh.bound_box]
    cx = sum(v.x for v in bb) / 8.0
    cy = sum(v.y for v in bb) / 8.0
    cz = sum(v.z for v in bb) / 8.0
    center = (cx, cy, cz)
    print(f"[bbox] dims={tuple(round(d,2) for d in mesh.dimensions)} center={tuple(round(v,2) for v in center)}")
    el_rad = math.radians(EL_DEG)

    # Adiciona sun light pra render nao sair preto (material original tem PBR)
    add_sun_light(center)

    cams = {
        "front": setup_camera("cam_front",
                              (cx, cy - CAM_DIST, cz + CAM_DIST * math.tan(el_rad)),
                              center),
        "3q":    setup_camera("cam_3q",
                              (cx + CAM_DIST * 0.7, cy - CAM_DIST * 0.7,
                               cz + CAM_DIST * math.tan(el_rad)),
                              center),
    }

    # Renderizar frames-chave em cada vista
    for frame in RENDER_FRAMES:
        for view_name, cam in cams.items():
            out_png = os.path.join(OUT_DIR, f"cloth_test_f{frame:02d}_{view_name}.png")
            render_frame(cam, frame, out_png)
            print(f"[render] frame {frame:02d} {view_name} -> {out_png}")

    # Salvar .blend com cache
    blend_out = os.path.join(OUT_DIR, "soph_cloth_test.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    print(f"[blend] {blend_out}")

    print("\n" + "=" * 60)
    print("PRONTO — compara cloth_test_f01 (T-pose) com cloth_test_f60 (assentado)")
    print("  Se a robe desceu/relaxou e o resto ficou fixo = sim funcionou")
    print("  Se a robe atravessou o corpo na silhueta visivel = ligar collision")
    print("  Se a robe explodiu/voou = baixar gravidade ou aumentar pin")
    print("=" * 60)


if __name__ == "__main__":
    main()
