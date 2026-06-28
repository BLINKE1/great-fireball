"""Walk cycle procedural — gera keyframes manualmente nos bones Mixamo do rig
da Soph, re-bake do cloth em cima, e renderiza alguns frames de 3/4 pra Will ver.

Loop in-place: 24 frames a 24fps = 1s. Personagem nao avanca no eixo X — anda
"correndo no lugar", como precisamos pro render 3/4 do sprite sheet.

Estrutura do ciclo:
  Frame 1  / 24 = pose neutra (contato direito)
  Frame 7        = perna esquerda pra frente (mid stride esq)
  Frame 13       = pose neutra (contato esquerdo)
  Frame 19       = perna direita pra frente (mid stride dir)

Entrada:
  tools/rig3d/out/dream_rig/soph_cloth_test.blend
  (ja tem mesh + armature + cloth modifier com pin map ok)

Saidas:
  tools/rig3d/out/dream_rig/walk_test/walk_f{01,07,13,19,24}_3q.png
  tools/rig3d/out/dream_rig/soph_walk_test.blend

Como rodar:
  blender --background --python tools/rig3d/make_walk_loop.py
"""

import bpy, os, math, mathutils as mu


REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN_BLEND = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_cloth_test.blend")
OUT_DIR = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig")
OUT_WALK = os.path.join(OUT_DIR, "walk_test")
os.makedirs(OUT_WALK, exist_ok=True)

FRAMES = 24
FPS = 24

# Parametros do ciclo (graus)
LEG_LIFT  = 28   # coxa pra frente (perna que pisa)
LEG_BACK  = -22  # coxa pra tras (perna apoio empurrando)
KNEE_BEND = 40   # canela dobra quando coxa levanta
KNEE_LITE = 5    # canela leve quando perna tras
ARM_SWING = 22   # braco oscila (oposto da perna)
HIP_SWAY  = 4    # rotacao Z dos quadris (sway lateral)
BOB_AMP   = 0.04 # amplitude do bob vertical de Hips (m)


def kf_rot(bone, frame, rx=0.0, ry=0.0, rz=0.0):
    """Set rotation_euler (XYZ graus -> rad) e insere keyframe."""
    bone.rotation_mode = 'XYZ'
    bone.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bone.keyframe_insert(data_path='rotation_euler', frame=frame)


def kf_loc(bone, frame, dx=0.0, dy=0.0, dz=0.0):
    """Set location DELTA (relativo ao rest) + keyframe."""
    bone.location = (dx, dy, dz)
    bone.keyframe_insert(data_path='location', frame=frame)


def get_bone(arm, name):
    """Bone pose. Tenta com prefixo 'mixamorig:' e sem."""
    pb = arm.pose.bones
    for candidate in (name, f"mixamorig:{name}", name.replace("mixamorig:", "")):
        b = pb.get(candidate)
        if b:
            return b
    return None


def setup_walk_cycle(arm):
    """Gera o walk cycle no armature. Assume nomes Mixamo."""
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = FRAMES
    sc.render.fps = FPS

    # Tem que estar em Pose mode pra editar pose bones
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')

    # Limpa qualquer animation_data antigo
    if arm.animation_data:
        arm.animation_data_clear()

    # --- HIPS: sway lateral (Z rot) + bob vertical (loc Z)
    hips = get_bone(arm, "Hips")
    if hips:
        # Sway: roda em torno do Z (quadril gira ao caminhar)
        kf_rot(hips, 1,  rz=0)
        kf_rot(hips, 7,  rz=HIP_SWAY)
        kf_rot(hips, 13, rz=0)
        kf_rot(hips, 19, rz=-HIP_SWAY)
        kf_rot(hips, 24, rz=0)
        # Bob: sobe nos contatos (1, 13), desce nos mid (7, 19)
        kf_loc(hips, 1,  dz=BOB_AMP)
        kf_loc(hips, 7,  dz=0)
        kf_loc(hips, 13, dz=BOB_AMP)
        kf_loc(hips, 19, dz=0)
        kf_loc(hips, 24, dz=BOB_AMP)
        print(f"[walk] Hips: sway {HIP_SWAY}° + bob {BOB_AMP}m")

    # --- PERNA ESQUERDA
    lup = get_bone(arm, "LeftUpLeg")
    llo = get_bone(arm, "LeftLeg")
    if lup:
        # F1: pousada atras, F7: pé adiante (lift), F13: passou pra tras, F19: empurrando
        kf_rot(lup, 1,  rx=LEG_BACK)
        kf_rot(lup, 7,  rx=LEG_LIFT)
        kf_rot(lup, 13, rx=0)
        kf_rot(lup, 19, rx=LEG_BACK * 0.5)
        kf_rot(lup, 24, rx=LEG_BACK)
    if llo:
        kf_rot(llo, 1,  rx=-KNEE_LITE)
        kf_rot(llo, 7,  rx=-KNEE_BEND)
        kf_rot(llo, 13, rx=-KNEE_LITE)
        kf_rot(llo, 19, rx=-KNEE_LITE)
        kf_rot(llo, 24, rx=-KNEE_LITE)
        print(f"[walk] LeftLeg: lift {LEG_LIFT}° + knee {KNEE_BEND}°")

    # --- PERNA DIREITA (oposta)
    rup = get_bone(arm, "RightUpLeg")
    rlo = get_bone(arm, "RightLeg")
    if rup:
        kf_rot(rup, 1,  rx=LEG_LIFT * 0.3)
        kf_rot(rup, 7,  rx=LEG_BACK)
        kf_rot(rup, 13, rx=LEG_BACK)
        kf_rot(rup, 19, rx=LEG_LIFT)
        kf_rot(rup, 24, rx=LEG_LIFT * 0.3)
    if rlo:
        kf_rot(rlo, 1,  rx=-KNEE_LITE)
        kf_rot(rlo, 7,  rx=-KNEE_LITE)
        kf_rot(rlo, 13, rx=-KNEE_LITE)
        kf_rot(rlo, 19, rx=-KNEE_BEND)
        kf_rot(rlo, 24, rx=-KNEE_LITE)
        print(f"[walk] RightLeg: lift {LEG_LIFT}° + knee {KNEE_BEND}°")

    # --- BRACOS (oposto das pernas — braco direito vai com perna esquerda)
    la = get_bone(arm, "LeftArm")
    ra = get_bone(arm, "RightArm")
    if la:
        kf_rot(la, 1,  rx=-ARM_SWING)   # braco esq atras (com perna dir atras)
        kf_rot(la, 7,  rx=ARM_SWING)    # braco esq frente
        kf_rot(la, 13, rx=0)
        kf_rot(la, 19, rx=-ARM_SWING)
        kf_rot(la, 24, rx=-ARM_SWING)
    if ra:
        kf_rot(ra, 1,  rx=ARM_SWING)
        kf_rot(ra, 7,  rx=-ARM_SWING)
        kf_rot(ra, 13, rx=0)
        kf_rot(ra, 19, rx=ARM_SWING)
        kf_rot(ra, 24, rx=ARM_SWING)
        print(f"[walk] Arms: swing {ARM_SWING}°")

    # Volta pra Object mode pro bake do cloth
    bpy.ops.object.mode_set(mode='OBJECT')


def rebake_cloth(mesh):
    """Free bake antigo e re-bake do cloth com a anim em movimento."""
    cloth = next((m for m in mesh.modifiers if m.type == 'CLOTH'), None)
    if not cloth:
        print("[cloth] WARN: mesh sem cloth modifier")
        return

    # Aumenta cache pro range da anim
    cloth.point_cache.frame_start = 1
    cloth.point_cache.frame_end = FRAMES

    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = FRAMES

    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh

    print("[bake] free cache antigo...")
    try:
        bpy.ops.ptcache.free_bake_all()
    except Exception as e:
        print(f"[bake] free falhou (ignorando): {e}")

    print(f"[bake] re-bake {FRAMES} frames com anim em movimento...")
    override = bpy.context.copy()
    override['scene'] = bpy.context.scene
    override['active_object'] = mesh
    override['object'] = mesh
    with bpy.context.temp_override(**override):
        bpy.ops.ptcache.bake_all(bake=True)
    print("[bake] OK")


def render_frames(camera_name="cam_3q"):
    """Renderiza frames-chave do walk cycle."""
    cam = bpy.data.objects.get(camera_name)
    if not cam:
        # Fallback: usa qualquer camera
        cams = [o for o in bpy.data.objects if o.type == 'CAMERA']
        if not cams:
            raise RuntimeError("nenhuma camera na cena")
        cam = cams[0]
        print(f"[render] WARN: {camera_name} nao achada, usando {cam.name}")

    sc = bpy.context.scene
    sc.camera = cam
    sc.render.resolution_x = 512
    sc.render.resolution_y = 768
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"

    key_frames = [1, 4, 7, 10, 13, 16, 19, 22, 24]
    for f in key_frames:
        sc.frame_set(f)
        out_png = os.path.join(OUT_WALK, f"walk_f{f:02d}_3q.png")
        sc.render.filepath = out_png
        bpy.ops.render.render(write_still=True)
        print(f"[render] frame {f:02d} -> {out_png}")


def main():
    print("=" * 60)
    print("WALK CYCLE — procedural in-place 24f @ 24fps")
    print("=" * 60)

    if not os.path.exists(IN_BLEND):
        raise RuntimeError(f"input nao existe: {IN_BLEND} — rode cloth_test.py primeiro")

    bpy.ops.wm.open_mainfile(filepath=IN_BLEND)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    if not arm:
        raise RuntimeError("sem armature na cena")
    mesh = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))

    print(f"[arm]  {arm.name} ({len(arm.data.bones)} bones)")
    print(f"[mesh] {mesh.name} ({len(mesh.data.vertices)} verts)")

    # Lista alguns bones pra confirmar nomes
    sample_bones = [b.name for b in arm.data.bones if any(k in b.name for k in ("Hips", "UpLeg", "Arm"))][:6]
    print(f"[arm]  bones-amostra: {sample_bones}")

    setup_walk_cycle(arm)
    rebake_cloth(mesh)
    render_frames()

    # Salva blend
    blend_out = os.path.join(OUT_DIR, "soph_walk_test.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    print(f"[blend] {blend_out}")

    print("\n" + "=" * 60)
    print("PRONTO — confere os 9 PNGs do walk em walk_test/")
    print("  Se a robe oscila + bracos balancam + pernas se movem = walk ok")
    print("  Se algum bone nao mexeu = nome Mixamo diferente, ajustar get_bone()")
    print("=" * 60)


if __name__ == "__main__":
    main()
