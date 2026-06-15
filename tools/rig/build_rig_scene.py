#!/usr/bin/env python3
"""
build_rig_scene.py — Gera scenes/characters/soph_rig.tscn com:
  - Skeleton2D root
  - hierarquia de Bone2D posicionada nos keypoints
  - Sprite2D por parte do corpo, parented na bone correta, com offset
    invertido pra alinhar o pivot da imagem ao origem da bone.
"""
from __future__ import annotations
import json, sys
from pathlib import Path

HERE   = Path(__file__).parent
ROOT   = HERE.parent.parent
KP_F   = ROOT / "assets" / "rig" / "soph_tpose" / "keypoints.json"
PARTS  = ROOT / "assets" / "rig" / "soph_tpose" / "parts.json"
OUT    = ROOT / "scenes" / "characters" / "soph_rig.tscn"


def main() -> int:
    kp = json.loads(KP_F.read_text(encoding="utf-8"))
    parts = json.loads(PARTS.read_text(encoding="utf-8"))["parts"]

    def P(name): return kp[name]["x"], kp[name]["y"]
    pelvis = P("_pelvis")
    spine_mid = P("_spine_mid")
    neck = P("_neck")

    # Mapa: nome do bone -> (parent_bone_or_None, posicao_global)
    BONES = [
        ("pelvis",     None,           pelvis),
        ("spine",      "pelvis",       spine_mid),
        ("neck",       "spine",        neck),
        ("L_shoulder", "neck",         P("L_shoulder")),
        ("L_elbow",    "L_shoulder",   P("L_elbow")),
        ("L_wrist",    "L_elbow",      P("L_wrist")),
        ("R_shoulder", "neck",         P("R_shoulder")),
        ("R_elbow",    "R_shoulder",   P("R_elbow")),
        ("R_wrist",    "R_elbow",      P("R_wrist")),
        ("L_hip",      "pelvis",       P("L_hip")),
        ("L_knee",     "L_hip",        P("L_knee")),
        ("L_ankle",    "L_knee",       P("L_ankle")),
        ("R_hip",      "pelvis",       P("R_hip")),
        ("R_knee",     "R_hip",        P("R_knee")),
        ("R_ankle",    "R_knee",       P("R_ankle")),
    ]
    bone_pos_global = {b: pos for b, _, pos in BONES}
    bone_parent = {b: par for b, par, _ in BONES}

    # Em qual bone cada sprite deve ficar parented (parent = bone cujo origem
    # = pivot da parte). Tomamos o pivot_name salvo no parts.json.
    SPRITE_PARENT = {
        "hair_back":   "neck",
        "head":        "neck",
        "torso":       "pelvis",
        "L_arm_upper": "L_shoulder",
        "L_arm_lower": "L_elbow",
        "R_arm_upper": "R_shoulder",
        "R_arm_lower": "R_elbow",
        "L_leg_upper": "L_hip",
        "L_leg_lower": "L_knee",
        "R_leg_upper": "R_hip",
        "R_leg_lower": "R_knee",
    }

    # z-order pra desenhar (menor primeiro = atras). Sprites de bones distantes
    # da camera (perna fundo, braco fundo) devem ficar atras. Como nao temos
    # depth real, usamos uma ordem fixa que da o look correto numa T-pose
    # frontal. hair_back fica atras de tudo — assim o braco que dobrar pra
    # frente passa por cima do cabelo das costas.
    Z_ORDER = {
        "hair_back":  -10,
        "R_arm_upper": -5,
        "R_arm_lower": -5,
        "R_leg_upper": -3,
        "R_leg_lower": -3,
        "torso":        0,
        "head":         1,
        "L_leg_upper": -2,
        "L_leg_lower": -2,
        "L_arm_upper":  2,
        "L_arm_lower":  2,
    }

    # gera externals (uma textura por parte)
    parts_ordered = list(SPRITE_PARENT.keys())
    ext_resources = []
    for i, name in enumerate(parts_ordered, start=1):
        rel = f"res://assets/rig/soph_tpose/parts/{name}.png"
        ext_resources.append(f'[ext_resource type="Texture2D" path="{rel}" id="{i}"]')
    tex_id = {name: i for i, name in enumerate(parts_ordered, start=1)}

    load_steps = len(ext_resources) + 1
    lines: list[str] = []
    lines.append(f'[gd_scene load_steps={load_steps} format=3]')
    lines.append("")
    lines.extend(ext_resources)
    lines.append("")

    # root
    lines.append('[node name="SophRig" type="Node2D"]')
    lines.append("")

    # Skeleton2D na origem
    lines.append('[node name="Skeleton2D" type="Skeleton2D" parent="."]')
    lines.append("")

    # Bones (com pos local relativa ao parent)
    bone_paths = {}
    for name, parent, (gx, gy) in BONES:
        if parent is None:
            parent_path = "Skeleton2D"
            local = (gx, gy)
        else:
            parent_path = bone_paths[parent]
            px, py = bone_pos_global[parent]
            local = (gx - px, gy - py)
        bone_paths[name] = f"{parent_path}/{name}"
        # rest = transform de descanso (Transform2D). Vamos zerar rotation e
        # passar apenas a translation. Bone2D no Godot 4 herda Node2D entao
        # tambem aceita "position".
        lines.append(f'[node name="{name}" type="Bone2D" parent="{parent_path}"]')
        lines.append(f"position = Vector2({local[0]}, {local[1]})")
        # rest precisa estar setado pro Skeleton2D inicializar correto
        lines.append(f"rest = Transform2D(1, 0, 0, 1, {local[0]}, {local[1]})")
        lines.append("")

    # Sprites parented na bone correta
    for name in parts_ordered:
        bone = SPRITE_PARENT[name]
        meta = parts[name]
        pivot_local = meta["pivot_local"]   # px do pivot DENTRO do crop
        # centered=false -> origem do sprite no canto sup-esq.
        # pos do sprite = -pivot_local -> faz o pixel pivot_local coincidir
        # com (0,0) local da bone (que e a articulacao).
        sprite_path = bone_paths[bone]
        lines.append(f'[node name="{name}_sprite" type="Sprite2D" parent="{sprite_path}"]')
        lines.append("centered = false")
        lines.append(f"position = Vector2({-pivot_local[0]}, {-pivot_local[1]})")
        lines.append(f"z_index = {Z_ORDER[name]}")
        lines.append(f'texture = ExtResource("{tex_id[name]}")')
        lines.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"ok cena gerada: {OUT.relative_to(ROOT)}")
    print(f"   {len(BONES)} bones, {len(parts_ordered)} sprites, "
          f"{len(ext_resources)} ext_resources, load_steps={load_steps}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
