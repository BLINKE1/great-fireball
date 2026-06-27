"""Idle cycle — Soph parada respirando, bracos baixados ao lado do corpo,
chapeu/cabelo/robe assentando com sim de cloth.

Loop 48 frames @ 24fps = 2s. Estrutura:
  - Pose-base: bracos rotacionados pra baixo (sai da T-pose Mixamo)
  - Breathing: Spine1/Spine2 inflar (rot X sutil), Hips bob vertical (~1.5cm)
  - Sway: Hips rota Z muito sutil (~1°)
  - Head: micro-look (rot Z ±2°)

Entrada:
  tools/rig3d/out/dream_rig/soph_cloth_test.blend (T-pose com cloth bakeado)

Saidas:
  tools/rig3d/out/dream_rig/idle_test/idle_full_fXX.png (48 frames)
  tools/rig3d/out/dream_rig/soph_idle_test.blend
  tools/rig3d/out/dream_rig/idle_test/soph_idle_cycle.gif (montado por script PIL depois)

Como rodar:
  blender --background --python tools/rig3d/make_idle_loop.py
"""

import bpy, os, math


REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IN_BLEND = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", "soph_cloth_test.blend")
OUT_DIR = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig")
OUT_IDLE = os.path.join(OUT_DIR, "idle_test")
os.makedirs(OUT_IDLE, exist_ok=True)

FRAMES = 48
FPS = 24

# Pose-base — bracos baixados. Mixamo rig em T-pose tem bracos perpendiculares,
# rotacao Z local "fecha" eles ao lado do corpo (esq +, dir -).
ARM_DROP_Z = 72.0   # graus pra baixar bracos (testar e ajustar)
FOREARM_DROP_Z = 10.0  # antebraco leve flex

# Animacao
BREATHE_AMP_X = 1.8   # graus de rot X no spine (peito inflando)
HIP_BOB = 0.015       # m, bob vertical sutil
HIP_SWAY = 1.0        # graus, sway lateral leve
HEAD_TURN = 1.5       # graus, micro head turn


def get_bone(arm, name):
    pb = arm.pose.bones
    for cand in (name, f"mixamorig:{name}"):
        b = pb.get(cand)
        if b:
            return b
    return None


def kf_rot(bone, frame, rx=0.0, ry=0.0, rz=0.0):
    bone.rotation_mode = 'XYZ'
    bone.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
    bone.keyframe_insert(data_path='rotation_euler', frame=frame)


def kf_loc(bone, frame, dx=0.0, dy=0.0, dz=0.0):
    bone.location = (dx, dy, dz)
    bone.keyframe_insert(data_path='location', frame=frame)


def setup_idle(arm):
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = FRAMES
    sc.render.fps = FPS

    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')

    if arm.animation_data:
        arm.animation_data_clear()

    # --- BRACOS BAIXADOS (pose-base, mantida nos FRAMES inteiros) ---
    la = get_bone(arm, "LeftArm")
    ra = get_bone(arm, "RightArm")
    lfa = get_bone(arm, "LeftForeArm")
    rfa = get_bone(arm, "RightForeArm")

    # Tentativa 2: ambos braços com sinal NEGATIVO em Z (Mixamo rest pose pode ter
    # mesma orientação local nos dois lados — tentamos isso primeiro)
    if la:
        for f in [1, FRAMES]:
            kf_rot(la, f, rz=-ARM_DROP_Z)
        print(f"[idle] LeftArm rz=-{ARM_DROP_Z}°")
    if ra:
        for f in [1, FRAMES]:
            kf_rot(ra, f, rz=-ARM_DROP_Z)
        print(f"[idle] RightArm rz=-{ARM_DROP_Z}° (sinal igual ao esquerdo)")
    if lfa:
        for f in [1, FRAMES]:
            kf_rot(lfa, f, rz=-FOREARM_DROP_Z)
    if rfa:
        for f in [1, FRAMES]:
            kf_rot(rfa, f, rz=-FOREARM_DROP_Z)

    # --- BREATHING + SWAY no torso ---
    # Loop suave: keyframes em 1, 12, 24, 36, 48 (5 pontos pra interpolacao smooth)
    hips = get_bone(arm, "Hips")
    spine1 = get_bone(arm, "Spine1")
    spine2 = get_bone(arm, "Spine2")
    head = get_bone(arm, "Head")

    # Hips: bob + sway sincronizados (cima na inspiracao, baixo na expiracao)
    if hips:
        keys = [
            (1,  0,        0),
            (12, HIP_BOB,   HIP_SWAY),
            (24, HIP_BOB,   0),
            (36, HIP_BOB*0.5, -HIP_SWAY),
            (48, 0,        0),
        ]
        for f, dz, sway in keys:
            kf_loc(hips, f, dz=dz)
            kf_rot(hips, f, rz=sway)
        print(f"[idle] Hips: bob {HIP_BOB}m + sway ±{HIP_SWAY}°")

    # Spine inflar/desinflar (peito sobe na inspiracao)
    if spine1:
        keys = [(1, 0), (12, BREATHE_AMP_X), (24, BREATHE_AMP_X), (36, 0), (48, 0)]
        for f, rx in keys:
            kf_rot(spine1, f, rx=-rx)  # negativo = peito pra cima/fora
        print(f"[idle] Spine1 breathe ±{BREATHE_AMP_X}°")
    if spine2:
        keys = [(1, 0), (12, BREATHE_AMP_X*0.6), (24, BREATHE_AMP_X*0.6), (36, 0), (48, 0)]
        for f, rx in keys:
            kf_rot(spine2, f, rx=-rx)

    # Head micro-turn (vivo, nao estatua)
    if head:
        keys = [(1, 0), (16, HEAD_TURN), (32, -HEAD_TURN), (48, 0)]
        for f, rz in keys:
            kf_rot(head, f, rz=rz)
        print(f"[idle] Head turn ±{HEAD_TURN}°")

    bpy.ops.object.mode_set(mode='OBJECT')


def rebake_cloth(mesh):
    cloth = next((m for m in mesh.modifiers if m.type == 'CLOTH'), None)
    if not cloth:
        print("[cloth] WARN sem cloth modifier")
        return

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

    print(f"[bake] re-bake {FRAMES} frames com idle...")
    override = bpy.context.copy()
    override['scene'] = bpy.context.scene
    override['active_object'] = mesh
    override['object'] = mesh
    with bpy.context.temp_override(**override):
        bpy.ops.ptcache.bake_all(bake=True)
    print("[bake] OK")


def render_all_frames(camera_name="cam_3q"):
    cam = bpy.data.objects.get(camera_name)
    if not cam:
        cams = [o for o in bpy.data.objects if o.type == 'CAMERA']
        cam = cams[0] if cams else None
    if not cam:
        raise RuntimeError("sem camera")

    sc = bpy.context.scene
    sc.camera = cam
    sc.render.resolution_x = 384
    sc.render.resolution_y = 576
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"

    for f in range(1, FRAMES + 1):
        sc.frame_set(f)
        out_png = os.path.join(OUT_IDLE, f"idle_full_f{f:02d}.png")
        sc.render.filepath = out_png
        bpy.ops.render.render(write_still=True)
        if f % 8 == 0 or f == 1 or f == FRAMES:
            print(f"[render] f{f:02d}")


def main():
    print("=" * 60)
    print(f"IDLE CYCLE — {FRAMES}f @ {FPS}fps, bracos baixados + breathing")
    print("=" * 60)

    if not os.path.exists(IN_BLEND):
        raise RuntimeError(f"input nao existe: {IN_BLEND}")

    bpy.ops.wm.open_mainfile(filepath=IN_BLEND)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    mesh = max([o for o in bpy.data.objects if o.type == 'MESH'],
               key=lambda o: len(o.data.vertices))

    print(f"[arm]  {arm.name} ({len(arm.data.bones)} bones)")
    print(f"[mesh] {mesh.name} ({len(mesh.data.vertices)} verts)")

    setup_idle(arm)
    rebake_cloth(mesh)
    render_all_frames()

    blend_out = os.path.join(OUT_DIR, "soph_idle_test.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    print(f"[blend] {blend_out}")
    print("PRONTO — monta o gif com:")
    print("  python tools/rig3d/_make_gif.py idle_test soph_idle_cycle")


if __name__ == "__main__":
    main()
