#!/usr/bin/env python3
"""
parse_mixamo.py — Roda DENTRO do Blender headless.

Le os FBX do Mixamo em assets/mixamo/, extrai POSICOES 3D world-space de
cada bone-chave nos frames pre-definidos de cada animacao, e salva tudo
em assets/mixamo/bones_world.json.

A projecao pro plano 2D (e calculo dos angulos do nosso rig) e feita em
um segundo script Python normal (map_to_2d.py) pra permitir iteracao sem
re-rodar o Blender.

Uso:
  blender --background --python tools/rig/parse_mixamo.py

Saida: assets/mixamo/bones_world.json
  {
    "idle_0": {
      "L_shoulder":  {"head": [x, y, z], "tail": [x, y, z]},
      "L_elbow":     ...
    },
    ...
  }
"""
import bpy
import json
import sys
from pathlib import Path

# Cwd vem do shell que invocou. O arquivo script tem __file__ confiavel no
# Blender 3+/4+.
SCRIPT_PATH = Path(__file__).resolve()
ROOT = SCRIPT_PATH.parent.parent.parent
MIXAMO_DIR = ROOT / "assets" / "mixamo"
OUTPUT = MIXAMO_DIR / "bones_world.json"

# Mapeamento Mixamo -> nosso rig (apenas as bones que importam pro rig 2D)
MIX2RIG = {
    "mixamorig:Hips":         "pelvis",
    "mixamorig:Spine1":       "spine",
    "mixamorig:Neck":         "neck",
    "mixamorig:Head":         "head",
    "mixamorig:LeftArm":      "L_shoulder",
    "mixamorig:LeftForeArm":  "L_elbow",
    "mixamorig:LeftHand":     "L_wrist",
    "mixamorig:RightArm":     "R_shoulder",
    "mixamorig:RightForeArm": "R_elbow",
    "mixamorig:RightHand":    "R_wrist",
    "mixamorig:LeftUpLeg":    "L_hip",
    "mixamorig:LeftLeg":      "L_knee",
    "mixamorig:LeftFoot":     "L_ankle",
    "mixamorig:RightUpLeg":   "R_hip",
    "mixamorig:RightLeg":     "R_knee",
    "mixamorig:RightFoot":    "R_ankle",
}

# Pra cada FBX, define quais frames extrair e como nomeia-los.
# t = posicao normalizada na timeline (0..1).
JOBS = [
    # "Female Start Walking" e uma TRANSICAO (parado -> andando). Os primeiros
    # ~40% da timeline ela ainda nao esta no walk cycle pleno. Amostragem
    # 0.45..0.95 pega o ciclo final completo.
    ("idle.fbx",    [("idle_0", 0.30), ("idle_1", 0.70)]),
    ("walking.fbx", [("walk_0", 0.45), ("walk_1", 0.55), ("walk_2", 0.65),
                     ("walk_3", 0.75), ("walk_4", 0.85), ("walk_5", 0.95)]),
    # "Treadmill Running" e ciclico no lugar — pode amostrar uniforme.
    ("running.fbx", [("run_0",  0.05), ("run_1",  0.30),
                     ("run_2",  0.55), ("run_3",  0.80)]),
    ("jump.fbx",    [("jump_0", 0.25), ("fall_0", 0.65)]),
    ("hurt.fbx",    [("hurt_0", 0.30)]),
    ("cast.fbx",    [("cast_0", 0.30), ("cast_1", 0.65)]),
    ("slash.fbx",   [("slash_0", 0.30), ("slash_1", 0.65)]),
]


def clear_scene():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for armature in list(bpy.data.armatures):
        bpy.data.armatures.remove(armature)


def import_fbx(path: Path):
    clear_scene()
    bpy.ops.import_scene.fbx(filepath=str(path))


def find_armature():
    for obj in bpy.data.objects:
        if obj.type == 'ARMATURE':
            return obj
    return None


def extract_pose(armature, frame: int) -> dict:
    """Retorna {rig_bone_name: {head: [x,y,z], tail: [x,y,z]}} world-space."""
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    out = {}
    obj_mat = armature.matrix_world
    for mix_name, rig_name in MIX2RIG.items():
        pb = armature.pose.bones.get(mix_name)
        if pb is None:
            continue
        head_w = obj_mat @ pb.head
        tail_w = obj_mat @ pb.tail
        out[rig_name] = {
            "head": [head_w.x, head_w.y, head_w.z],
            "tail": [tail_w.x, tail_w.y, tail_w.z],
        }
    return out


def main():
    print("=" * 60)
    print("parse_mixamo: extracting bone world positions to JSON")
    print("=" * 60)
    poses = {}

    for fbx_name, frames in JOBS:
        path = MIXAMO_DIR / fbx_name
        if not path.exists():
            print(f"x falta: {path}")
            continue
        print(f"\n-> {fbx_name}")
        import_fbx(path)
        arm = find_armature()
        if arm is None:
            print(f"  ! sem armature em {fbx_name}")
            continue
        action = arm.animation_data.action if arm.animation_data else None
        if action is None:
            print(f"  ! sem action em {fbx_name}")
            continue
        fs, fe = action.frame_range
        fs, fe = int(fs), int(fe)
        total = max(1, fe - fs)
        print(f"  bones={len(arm.pose.bones)}  frames=[{fs}..{fe}]  total={total}")
        for pose_name, t in frames:
            frame = fs + int(round(t * total))
            poses[pose_name] = extract_pose(arm, frame)
            print(f"  ok {pose_name} @ frame {frame}")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(poses, indent=2))
    print(f"\nok salvo: {OUTPUT}  ({len(poses)} poses)")


if __name__ == "__main__":
    main()
