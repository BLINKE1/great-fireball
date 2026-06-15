#!/usr/bin/env python3
"""
bake_frames.py — Renderiza poses do rig 2D da Soph (Pillow puro) e salva
PNGs 100x192 prontos pra substituir soph_hd_*.png. Substitui o pipeline
do kontext: 100% consistente (mesma textura, mesmos pivots, varia so
rotacao das bones).

Saidas em assets/sprites/player/_bake_preview/ por padrao.
  --apply -> grava direto em assets/sprites/player/_pending_regen/
  --apply-final -> copia pros oficiais (via gen_hd_from_idle).

uso:
  python tools/rig/bake_frames.py --pose rest --apply
  python tools/rig/bake_frames.py --all --apply
"""
from __future__ import annotations
import argparse, json, math, sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
RIG_DIR = ROOT / "assets" / "rig" / "soph_tpose"
PARTS_JSON = json.loads((RIG_DIR / "parts.json").read_text(encoding="utf-8"))
KP_JSON = json.loads((RIG_DIR / "keypoints.json").read_text(encoding="utf-8"))
OUT_DIR_PREVIEW = ROOT / "assets" / "sprites" / "player" / "_bake_preview"
OUT_DIR_STAGE = ROOT / "assets" / "sprites" / "player" / "_pending_regen"

SRC_W, SRC_H = PARTS_JSON["image_size"]   # 1024x1024
DST_W, DST_H = 100, 192                   # canvas final


def P(name): return (KP_JSON[name]["x"], KP_JSON[name]["y"])


# Hierarquia (mesma de build_rig_scene)
BONES = {
    "pelvis":     (None,         P("_pelvis")),
    "spine":      ("pelvis",     P("_spine_mid")),
    "neck":       ("spine",      P("_neck")),
    "L_shoulder": ("neck",       P("L_shoulder")),
    "L_elbow":    ("L_shoulder", P("L_elbow")),
    "L_wrist":    ("L_elbow",    P("L_wrist")),
    "R_shoulder": ("neck",       P("R_shoulder")),
    "R_elbow":    ("R_shoulder", P("R_elbow")),
    "R_wrist":    ("R_elbow",    P("R_wrist")),
    "L_hip":      ("pelvis",     P("L_hip")),
    "L_knee":     ("L_hip",      P("L_knee")),
    "L_ankle":    ("L_knee",     P("L_ankle")),
    "R_hip":      ("pelvis",     P("R_hip")),
    "R_knee":     ("R_hip",      P("R_knee")),
    "R_ankle":    ("R_knee",     P("R_ankle")),
}

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


def compute_bone_transforms(pose: dict, root_offset=(0, 0)):
    """pose: dict bone_name -> angle_deg (rotacao local em rest -> nova).
    Retorna dict bone_name -> {"pos": (x, y) global, "rot": rad global}."""
    transforms: dict = {}
    for bone, (parent, rest_pos) in BONES.items():
        local_rad = math.radians(pose.get(bone, 0))
        if parent is None:
            transforms[bone] = {
                "pos": (rest_pos[0] + root_offset[0], rest_pos[1] + root_offset[1]),
                "rot": local_rad,
            }
            continue
        parent_t = transforms[parent]
        parent_rest = BONES[parent][1]
        # offset local em rest = filho - parent (em coords do mundo, em rest)
        off_x = rest_pos[0] - parent_rest[0]
        off_y = rest_pos[1] - parent_rest[1]
        # rotaciona esse offset pela rotacao global do parent
        cos_p = math.cos(parent_t["rot"])
        sin_p = math.sin(parent_t["rot"])
        rx = off_x * cos_p - off_y * sin_p
        ry = off_x * sin_p + off_y * cos_p
        transforms[bone] = {
            "pos": (parent_t["pos"][0] + rx, parent_t["pos"][1] + ry),
            "rot": parent_t["rot"] + local_rad,
        }
    return transforms


def render_pose(pose: dict, root_offset=(0, 0)) -> Image.Image:
    """Renderiza uma pose em canvas SRC_WxSRC_H (1024x1024) RGBA."""
    canvas = Image.new("RGBA", (SRC_W, SRC_H), (0, 0, 0, 0))
    transforms = compute_bone_transforms(pose, root_offset)
    order = sorted(SPRITE_PARENT.keys(), key=lambda n: Z_ORDER.get(n, 0))
    for name in order:
        meta = PARTS_JSON["parts"][name]
        bone = SPRITE_PARENT[name]
        t = transforms[bone]
        # cria um canvas temp com a parte colada na posicao de REST
        # (meta["offset"] e o canto sup-esq da parte na imagem 1024).
        part_im = Image.open(RIG_DIR / "parts" / f"{name}.png").convert("RGBA")
        scratch = Image.new("RGBA", (SRC_W, SRC_H), (0, 0, 0, 0))
        scratch.paste(part_im, tuple(meta["offset"]), part_im)
        # Transform: queremos mover o pivot global da parte (em rest) pra
        # t["pos"], girando pela rotacao global da bone.
        # Forward: x_dst = T(t.pos) * R(t.rot) * T(-pivot_global) * x_src
        # Inverse (necessaria pro Image.transform): I = T(pivot) * R(-rot) * T(-pos)
        rot = t["rot"]
        cos_r = math.cos(-rot)
        sin_r = math.sin(-rot)
        px, py = meta["pivot"]
        tx, ty = t["pos"]
        # I(x_dst, y_dst):
        #   u = x_dst - tx, v = y_dst - ty
        #   u' = cos*u - sin*v, v' = sin*u + cos*v
        #   x_src = u' + px, y_src = v' + py
        # Forma esperada por Pillow: (a, b, c, d, e, f) onde
        #   x_src = a*x_dst + b*y_dst + c
        #   y_src = d*x_dst + e*y_dst + f
        a = cos_r
        b = -sin_r
        c = px - (cos_r * tx - sin_r * ty)
        d = sin_r
        e = cos_r
        f = py - (sin_r * tx + cos_r * ty)
        transformed = scratch.transform(
            (SRC_W, SRC_H), Image.AFFINE, (a, b, c, d, e, f), resample=Image.BICUBIC
        )
        canvas.alpha_composite(transformed)
    return canvas


def to_sprite(canvas: Image.Image) -> Image.Image:
    """Recorta e escala pro canvas final 100x192, pes no fundo."""
    # bbox do conteudo opaco
    bbox = canvas.getbbox()
    if bbox is None:
        return Image.new("RGBA", (DST_W, DST_H), (0, 0, 0, 0))
    x0, y0, x1, y1 = bbox
    cropped = canvas.crop(bbox)
    # escala mantendo aspect ratio pra altura ~= 180 (bbox alvo do player.gd)
    target_h = 180
    src_h = y1 - y0
    src_w = x1 - x0
    scale = target_h / src_h
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = cropped.resize((new_w, new_h), Image.LANCZOS)
    out = Image.new("RGBA", (DST_W, DST_H), (0, 0, 0, 0))
    # centraliza horizontalmente, alinha pes no fundo
    px = (DST_W - new_w) // 2
    py = DST_H - new_h
    out.paste(resized, (px, py), resized)
    return out


# ---------- POSES ----------
# Cada pose: dict bone_name -> rotacao em GRAUS. Positivo = horario na tela
# (coords Y-down). Ausentes = 0 (mesmo angulo do rest = T-pose).
#
# Convencao (rest da T-pose):
#   L_shoulder aponta +X (rest ang ~+35deg p/ Y+); +55deg local desce o braco
#   R_shoulder aponta -X (rest ang ~+145deg);     -55deg local desce o braco
#   L/R_hip apontam +Y; rotacionar pra "frente/tras" do personagem que olha
#     +X: +X-frente = girar pernas -90 ate apontar pra +X.
# Sinais resultantes: shoulders OPOSTOS (L+, R-) pra simetria.

POSE_REST = {}                # T-pose pura (debug — bracos abertos)

# Convencao de DOBRA (importante):
#   L_elbow NEGATIVO dobra o antebraco pra DENTRO do corpo (mao sobe).
#   R_elbow POSITIVO dobra pra dentro (espelhado).
#   L_knee POSITIVO dobra a perna pra TRAS (calcanhar pro bumbum).
#   R_knee POSITIVO dobra pra tras (mesmo lado: knee aponta +Y, +rot = +X-).

POSE_IDLE_0 = {
    "L_shoulder":  72, "L_elbow":  -30,    # braco solto, cotovelo dobrado
    "R_shoulder": -72, "R_elbow":   30,
    "neck":        -2,
}
POSE_IDLE_1 = {
    "L_shoulder":  70, "L_elbow":  -35,
    "R_shoulder": -70, "R_elbow":   35,
    "neck":         2,
    "pelvis":       1,
}

# Walk: braco oposto pra frente, cotovelo MUITO dobrado, joelho dobra.
POSE_WALK_0 = {
    "L_shoulder":  85, "L_elbow":  -65,   # braco esq pra TRAS, antebraco dobrado p/ DENTRO
    "R_shoulder": -45, "R_elbow":   80,   # braco dir pra FRENTE, antebraco p/ DENTRO
    "L_hip":      -20, "L_knee":   25,    # perna esq pra frente, joelho dobra
    "R_hip":       15, "R_knee":   40,    # perna dir pra tras, joelho dobra (apoio)
}
POSE_WALK_1 = {
    "L_shoulder":  72, "L_elbow":  -40,
    "R_shoulder": -72, "R_elbow":   40,
    "L_hip":       -5, "L_knee":   15,
    "R_hip":        5, "R_knee":   15,
}
POSE_WALK_2 = {
    "L_shoulder":  45, "L_elbow":  -80,
    "R_shoulder": -85, "R_elbow":   65,
    "L_hip":       15, "L_knee":   40,
    "R_hip":      -20, "R_knee":   25,
}
POSE_WALK_3 = POSE_WALK_1.copy()
POSE_WALK_4 = POSE_WALK_0.copy()
POSE_WALK_5 = POSE_WALK_2.copy()

# Run: passos maiores, tronco inclinado, cotovelos a 90, pernas explodindo.
POSE_RUN_0 = {
    "spine":      10,
    "L_shoulder": 110, "L_elbow":  -90,    # braco esq atras, cotovelo flexionado
    "R_shoulder": -30, "R_elbow":   95,    # braco dir frente
    "L_hip":      -40, "L_knee":   65,     # joelho esq sobe MUITO
    "R_hip":       35, "R_knee":   55,
}
POSE_RUN_1 = {
    "spine":      10,
    "L_shoulder":  72, "L_elbow":  -90,
    "R_shoulder": -72, "R_elbow":   90,
    "L_hip":       -5, "L_knee":   30,
    "R_hip":        5, "R_knee":   30,
}
POSE_RUN_2 = {
    "spine":      10,
    "L_shoulder":  30, "L_elbow":  -95,
    "R_shoulder":-110, "R_elbow":   90,
    "L_hip":       35, "L_knee":   55,
    "R_hip":      -40, "R_knee":   65,
}
POSE_RUN_3 = POSE_RUN_1.copy()

POSE_JUMP_0 = {
    "L_shoulder": 130, "L_elbow":  -30,    # bracos abertos pra fora-acima
    "R_shoulder":-130, "R_elbow":   30,
    "L_hip":      -45, "L_knee":   70,     # joelhos pra cima (recolhidos)
    "R_hip":       45, "R_knee":   70,
}
POSE_FALL_0 = {
    "L_shoulder": 140, "L_elbow":  -20,
    "R_shoulder":-140, "R_elbow":   20,
    "L_hip":       20, "L_knee":   10,     # pernas mais soltas, leve dobra
    "R_hip":      -20, "R_knee":   10,
}
POSE_HURT_0 = {
    "spine":      -15,
    "neck":         8,
    "L_shoulder":  95, "L_elbow":  -80,    # bracos encolhidos, dobrados
    "R_shoulder": -65, "R_elbow":   80,
    "L_hip":       15, "L_knee":   25,
    "R_hip":      -15, "R_knee":   25,
}
POSE_CAST_0 = {
    "L_shoulder":  72, "L_elbow":  -35,
    "R_shoulder": -30, "R_elbow":  -50,    # braco dir levantado, cotovelo flexionado p/ tras
    "neck":         -3,
}
POSE_CAST_1 = {
    "spine":       5,
    "L_shoulder":  72, "L_elbow":  -35,
    "R_shoulder":  20, "R_elbow":  -10,    # braco dir alto, antebraco ligeiramente curvado
    "neck":         -5,
}
POSE_SLASH_0 = {
    "spine":      -8,
    "L_shoulder":  72, "L_elbow":  -40,
    "R_shoulder":-110, "R_elbow":  -90,    # braco dir LEVANTADO atras (preparar golpe)
    "L_hip":       10, "L_knee":   15,
    "R_hip":      -10, "R_knee":   15,
}
POSE_SLASH_1 = {
    "spine":       12,
    "L_shoulder":  72, "L_elbow":  -40,
    "R_shoulder": -30, "R_elbow":   80,    # braco dir desceu (golpe completou)
    "L_hip":      -10, "L_knee":   15,
    "R_hip":       10, "R_knee":   15,
}

# Prioridade: se existir poses_from_mixamo.py (gerado por map_to_2d.py a
# partir do Mixamo), usa ele. Senao, cai pros chutes manuais acima.
try:
    from poses_from_mixamo import ALL_POSES as _MIXAMO
    ALL_POSES: list[tuple[str, dict]] = list(_MIXAMO.items())
    print(f"[bake] usando ALL_POSES do Mixamo ({len(ALL_POSES)} poses)")
except ImportError:
    ALL_POSES = [
        ("idle_0", POSE_IDLE_0),
        ("idle_1", POSE_IDLE_1),
        ("walk_0", POSE_WALK_0),
        ("walk_1", POSE_WALK_1),
        ("walk_2", POSE_WALK_2),
        ("walk_3", POSE_WALK_3),
        ("walk_4", POSE_WALK_4),
        ("walk_5", POSE_WALK_5),
        ("run_0",  POSE_RUN_0),
        ("run_1",  POSE_RUN_1),
        ("run_2",  POSE_RUN_2),
        ("run_3",  POSE_RUN_3),
        ("jump_0", POSE_JUMP_0),
        ("fall_0", POSE_FALL_0),
        ("hurt_0", POSE_HURT_0),
        ("cast_0", POSE_CAST_0),
        ("cast_1", POSE_CAST_1),
        ("slash_0", POSE_SLASH_0),
        ("slash_1", POSE_SLASH_1),
    ]
    print("[bake] usando ALL_POSES chutadas manualmente")


def bake_one(name: str, pose: dict, out_dir: Path) -> Path:
    canvas = render_pose(pose)
    sprite = to_sprite(canvas)
    out = out_dir / f"soph_hd_{name}.png"
    sprite.save(out)
    print(f"ok {out.name}  size={sprite.size}")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--pose", help="nome da pose: idle_0, walk_2, etc")
    g.add_argument("--all", action="store_true", help="todas as 19 poses")
    g.add_argument("--rest", action="store_true", help="T-pose pura (debug)")
    ap.add_argument("--apply", action="store_true",
                    help="grava em _pending_regen/ (vs _bake_preview/)")
    args = ap.parse_args()

    out_dir = OUT_DIR_STAGE if args.apply else OUT_DIR_PREVIEW
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.rest:
        canvas = render_pose({})
        out = out_dir / "soph_hd_rest_debug.png"
        canvas.save(out)
        print(f"ok rest -> {out}")
        return 0

    if args.pose:
        for nm, p in ALL_POSES:
            if nm == args.pose:
                bake_one(nm, p, out_dir)
                return 0
        print(f"x pose nao encontrada: {args.pose}")
        return 1

    if args.all:
        for nm, p in ALL_POSES:
            bake_one(nm, p, out_dir)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
