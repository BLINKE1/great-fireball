#!/usr/bin/env python3
"""
map_to_2d.py — Converte assets/mixamo/bones_world.json em poses 2D pro
nosso rig da Soph. Substitui o ALL_POSES do bake_frames.py.

Projecao usada: SIDE-VIEW (YZ do mundo Mixamo). Justificativa: walk/run do
Mixamo sao designed pra vista lateral; em vista frontal (XZ) perdiamos o
swing das pernas/bracos. Usar side-view "estilizado no rig frontal" mantem
a anatomia visivel mesmo que nao seja anatomicamente realista (e o tradeoff
de animar um sprite frontal com mocap 3D).

Saida: tools/rig/poses_from_mixamo.py — modulo com ALL_POSES, importavel
pelo bake_frames.py.
"""
from __future__ import annotations
import json
import math
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
BONES_WORLD = ROOT / "assets" / "mixamo" / "bones_world.json"
KP_JSON = ROOT / "assets" / "rig" / "soph_tpose" / "keypoints.json"
OUTPUT = HERE / "poses_from_mixamo.py"

# Hierarquia local (mesmo do bake_frames.py / build_rig_scene.py)
BONE_PARENT = {
    "pelvis":     None,
    "spine":      "pelvis",
    "neck":       "spine",
    "head":       "neck",
    "L_shoulder": "neck",
    "L_elbow":    "L_shoulder",
    "L_wrist":    "L_elbow",
    "R_shoulder": "neck",
    "R_elbow":    "R_shoulder",
    "R_wrist":    "R_elbow",
    "L_hip":      "pelvis",
    "L_knee":     "L_hip",
    "L_ankle":    "L_knee",
    "R_hip":      "pelvis",
    "R_knee":     "R_hip",
    "R_ankle":    "R_knee",
}

# Bones que de fato existem no bake_frames.py com rotation local definivel.
# Outras (head, wrist, ankle) sao terminais — nao tem filhos rotacionavies.
USED = [
    "pelvis", "spine", "neck",
    "L_shoulder", "L_elbow",
    "R_shoulder", "R_elbow",
    "L_hip", "L_knee",
    "R_hip", "R_knee",
]


def project_side(p):
    """3D Mixamo (X lateral, Y profundidade, Z altura) -> 2D side view.
    Mapeamento: x_img = -Y_mixamo (frente do personagem fica a direita da
    imagem), y_img = -Z_mixamo (Y-down image)."""
    return (-p[1], -p[2])


def bone_angle_2d(head_3d, tail_3d) -> float:
    """Angulo da bone (head -> tail) projetada em side view 2D, em radianos."""
    hx, hy = project_side(head_3d)
    tx, ty = project_side(tail_3d)
    return math.atan2(ty - hy, tx - hx)


# ----- nosso rig 2D em REST -----
def load_rest_angles():
    """Angulo global de cada bone do nosso rig na rest pose (T-pose).
    Usa keypoints.json — coords da imagem 1024x1024 (Y-down ja)."""
    kp = json.loads(KP_JSON.read_text())
    def P(n): return (kp[n]["x"], kp[n]["y"])
    # Bone vai do head ate o tail (proximo bone na cadeia ou ponto morto).
    # Adotamos um "tail virtual" pra bones sem filho claro (pelvis, neck).
    rest = {
        "pelvis":     (P("_pelvis"),     P("_spine_mid")),
        "spine":      (P("_spine_mid"),  P("_neck")),
        "neck":       (P("_neck"),       (kp["_neck"]["x"], kp["_neck"]["y"] - 30)),  # cabeca acima
        "L_shoulder": (P("L_shoulder"),  P("L_elbow")),
        "L_elbow":    (P("L_elbow"),     P("L_wrist")),
        "R_shoulder": (P("R_shoulder"),  P("R_elbow")),
        "R_elbow":    (P("R_elbow"),     P("R_wrist")),
        "L_hip":      (P("L_hip"),       P("L_knee")),
        "L_knee":     (P("L_knee"),      P("L_ankle")),
        "R_hip":      (P("R_hip"),       P("R_knee")),
        "R_knee":     (P("R_knee"),      P("R_ankle")),
    }
    out = {}
    for name, (h, t) in rest.items():
        out[name] = math.atan2(t[1] - h[1], t[0] - h[0])
    return out


def compute_pose(world_pose: dict, rest_angles: dict) -> dict:
    """Retorna {bone: angle_local_deg} pra cada bone em USED."""
    # Primeiro: calcula angulo global Mixamo de cada bone (side view)
    mix_global = {}
    for name in USED:
        if name not in world_pose:
            continue
        bw = world_pose[name]
        mix_global[name] = bone_angle_2d(bw["head"], bw["tail"])

    # Local = (mix_global - mix_global_parent) - (rest_global - rest_global_parent)
    # Equivalente a: local = (mix - rest) - (mix_parent - rest_parent)
    local = {}
    for name in USED:
        if name not in mix_global:
            continue
        delta_self = mix_global[name] - rest_angles[name]
        parent = BONE_PARENT[name]
        if parent is None or parent not in mix_global:
            delta_parent = 0.0
        else:
            delta_parent = mix_global[parent] - rest_angles[parent]
        local_rad = delta_self - delta_parent
        # normaliza pra [-pi, pi]
        while local_rad > math.pi: local_rad -= 2 * math.pi
        while local_rad < -math.pi: local_rad += 2 * math.pi
        local[name] = math.degrees(local_rad)
    return local


def main():
    bw = json.loads(BONES_WORLD.read_text())
    rest = load_rest_angles()
    print("Rest angles (deg):")
    for name in USED:
        print(f"  {name:12s} {math.degrees(rest[name]):7.2f}")

    poses_2d = {}
    for pose_name, world_pose in bw.items():
        poses_2d[pose_name] = compute_pose(world_pose, rest)

    # Imprime resumo
    print(f"\n=== {len(poses_2d)} poses 2D ===")
    for pn, p in poses_2d.items():
        print(f"  {pn}:")
        for b, ang in p.items():
            print(f"    {b:12s} {ang:7.2f}")

    # Salva como modulo python
    lines = [
        '# Auto-gerado por tools/rig/map_to_2d.py a partir de',
        '# assets/mixamo/bones_world.json. Nao edite manualmente — re-rode',
        '# `python tools/rig/map_to_2d.py` apos atualizar Mixamo.',
        'ALL_POSES = {',
    ]
    for pn, p in poses_2d.items():
        lines.append(f'    "{pn}": {{')
        for b, ang in p.items():
            lines.append(f'        "{b}": {ang:.2f},')
        lines.append('    },')
    lines.append('}')
    OUTPUT.write_text("\n".join(lines) + "\n")
    print(f"\nok salvo: {OUTPUT}")


if __name__ == "__main__":
    main()
