#!/usr/bin/env python3
"""
cut_parts.py — Corta a T-pose limpa em camadas (cabeca, torso, bracos sup/inf,
pernas sup/inf) usando os keypoints como guia. Salva cada parte como PNG
recortado ao bbox + um parts.json com offsets globais (origem do canvas
original em 1024x1024) e o ponto de pivo da parte (junta ANCORA, onde o
Bone2D vai prender).

Saidas em assets/rig/soph_tpose/parts/:
  - head.png, torso.png
  - L_arm_upper.png, L_arm_lower.png, R_arm_upper.png, R_arm_lower.png
  - L_leg_upper.png, L_leg_lower.png, R_leg_upper.png, R_leg_lower.png
  - parts.json  (manifest com offset_x, offset_y, pivot_x, pivot_y por parte)
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image

HERE   = Path(__file__).parent
ROOT   = HERE.parent.parent
SRC    = ROOT / "assets" / "rig" / "soph_tpose" / "tpose_clean.png"
KP     = ROOT / "assets" / "rig" / "soph_tpose" / "keypoints.json"
OUTDIR = ROOT / "assets" / "rig" / "soph_tpose" / "parts"


def rect_mask(w: int, h: int, x0: int, y0: int, x1: int, y1: int) -> np.ndarray:
    m = np.zeros((h, w), dtype=np.uint8)
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    m[y0:y1, x0:x1] = 255
    return m


def main() -> int:
    OUTDIR.mkdir(parents=True, exist_ok=True)
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size
    rgba = np.array(src)
    kp = json.loads(KP.read_text(encoding="utf-8"))

    def P(name): return kp[name]["x"], kp[name]["y"]

    L_sh = P("L_shoulder"); R_sh = P("R_shoulder")
    L_el = P("L_elbow");    R_el = P("R_elbow")
    L_wr = P("L_wrist");    R_wr = P("R_wrist")
    L_hp = P("L_hip");      R_hp = P("R_hip")
    L_kn = P("L_knee");     R_kn = P("R_knee")
    L_an = P("L_ankle");    R_an = P("R_ankle")
    neck = (kp["_neck"]["x"], kp["_neck"]["y"])
    pelvis = (kp["_pelvis"]["x"], kp["_pelvis"]["y"])

    shoulder_w = abs(L_sh[0] - R_sh[0])  # ~175
    pad_arm = max(30, shoulder_w // 4)   # espessura lateral do braco
    pad_leg = max(30, shoulder_w // 3)   # coxa um pouco mais grossa

    # Faixa horizontal "estreita" do torso real (sem cabelo lateral). O cabelo
    # que desce do pescoco pro lado fica FORA dessa faixa -> vira hair_back.
    shoulder_left  = min(L_sh[0], R_sh[0])   # 427 (lado esq da imagem)
    shoulder_right = max(L_sh[0], R_sh[0])   # 602
    torso_pad_x = 25
    torso_narrow_x0 = shoulder_left  - torso_pad_x
    torso_narrow_x1 = shoulder_right + torso_pad_x

    # caixas (x0, y0, x1, y1) por parte. Generosas: garantem capturar cabelo
    # que desce nas laterais (cabelo vai junto da head; hair_back vira parte
    # propria atras dos bracos).
    BOXES = {
        # cabeca: do topo ate um pouco abaixo da linha do queixo (~shoulder_y - 5)
        "head": (0, 0, W, neck[1] + 10),

        # torso: ombro -> quadril, com largura FECHADA (sem cabelo lateral —
        # esse vai pra hair_back). cut_parts removes hair_back pixels do
        # PNG do torso depois pra evitar dupla renderizacao.
        "torso": (torso_narrow_x0, neck[1] - 5, torso_narrow_x1, pelvis[1] + 15),

        # hair_back: cabelo lateral que desce do pescoco ate abaixo do pelvis.
        # Mascara = dentro deste retangulo MAS fora do torso narrow (logica
        # custom aplicada depois do rect_mask).
        "hair_back": (0, neck[1] - 5, W, H),

        # bracos esquerdo (do ponto de vista do espectador, L na imagem = direita do personagem)
        # mas mediapipe ja inverte: L_shoulder esta na direita da imagem (x=602)
        "L_arm_upper": (
            min(L_sh[0], L_el[0]) - pad_arm,
            min(L_sh[1], L_el[1]) - pad_arm,
            max(L_sh[0], L_el[0]) + pad_arm,
            max(L_sh[1], L_el[1]) + pad_arm,
        ),
        "L_arm_lower": (
            min(L_el[0], L_wr[0]) - pad_arm,
            min(L_el[1], L_wr[1]) - pad_arm,
            max(L_el[0], L_wr[0]) + pad_arm + 20,  # +20 pra pegar a mao
            max(L_el[1], L_wr[1]) + pad_arm,
        ),
        "R_arm_upper": (
            min(R_sh[0], R_el[0]) - pad_arm,
            min(R_sh[1], R_el[1]) - pad_arm,
            max(R_sh[0], R_el[0]) + pad_arm,
            max(R_sh[1], R_el[1]) + pad_arm,
        ),
        "R_arm_lower": (
            min(R_el[0], R_wr[0]) - pad_arm - 20,  # -20 pra pegar a mao
            min(R_el[1], R_wr[1]) - pad_arm,
            max(R_el[0], R_wr[0]) + pad_arm,
            max(R_el[1], R_wr[1]) + pad_arm,
        ),

        # pernas (do quadril ao tornozelo + pe)
        "L_leg_upper": (
            min(L_hp[0], L_kn[0]) - pad_leg,
            L_hp[1] - 5,
            max(L_hp[0], L_kn[0]) + pad_leg,
            L_kn[1] + 10,
        ),
        "L_leg_lower": (
            min(L_kn[0], L_an[0]) - pad_leg,
            L_kn[1] - 10,
            max(L_kn[0], L_an[0]) + pad_leg,
            H,  # ate o fundo do canvas (pega o pe)
        ),
        "R_leg_upper": (
            min(R_hp[0], R_kn[0]) - pad_leg,
            R_hp[1] - 5,
            max(R_hp[0], R_kn[0]) + pad_leg,
            R_kn[1] + 10,
        ),
        "R_leg_lower": (
            min(R_kn[0], R_an[0]) - pad_leg,
            R_kn[1] - 10,
            max(R_kn[0], R_an[0]) + pad_leg,
            H,
        ),
    }

    # Ponto de pivo = junta ancora (onde o Bone2D vai prender no rig)
    PIVOTS = {
        "head":        ("_neck", neck),
        "torso":       ("_pelvis", pelvis),
        "hair_back":   ("_neck", neck),
        "L_arm_upper": ("L_shoulder", L_sh),
        "L_arm_lower": ("L_elbow",    L_el),
        "R_arm_upper": ("R_shoulder", R_sh),
        "R_arm_lower": ("R_elbow",    R_el),
        "L_leg_upper": ("L_hip",      L_hp),
        "L_leg_lower": ("L_knee",     L_kn),
        "R_leg_upper": ("R_hip",      R_hp),
        "R_leg_lower": ("R_knee",     R_kn),
    }

    # Pra evitar overlap MUITO grande: subtrai as bbox de bracos/pernas da bbox
    # do torso. Isso nao remove pixel — so impede o torso de "vazar" pro braco
    # depois (em runtime cada bone separa).
    # (v1 simples: nao mexer, deixar overlap; o rig usa z-order pra ocluir.)

    manifest = {"image_size": [W, H], "parts": {}}

    # Pre-calcula a mascara do hair_back: lateral do tronco MAS fora do
    # torso narrow E fora dos bboxes dos bracos e pernas (que sao pretos
    # como o cabelo e contaminariam o recorte). Limita Y pra nao pegar pe.
    hb_x0, hb_y0, hb_x1, hb_y1 = BOXES["hair_back"]
    hb_y1 = min(hb_y1, int(L_hp[1] + 250))  # final do cabelo abaixo do pelvis
    hair_back_rect = rect_mask(W, H, hb_x0, hb_y0, hb_x1, hb_y1)
    torso_narrow_rect = rect_mask(
        W, H, torso_narrow_x0, neck[1] - 5, torso_narrow_x1, pelvis[1] + 15
    )
    # Subtrai bboxes dos bracos (T-pose horizontal — bracos sao pretos como
    # o cabelo e estao FORA do torso narrow, virariam cabelo falso).
    arms_rect = np.zeros((H, W), dtype=np.uint8)
    for arm_name in ("L_arm_upper", "L_arm_lower", "R_arm_upper", "R_arm_lower"):
        ax0, ay0, ax1, ay1 = BOXES[arm_name]
        arms_rect = np.maximum(arms_rect, rect_mask(W, H, ax0, ay0, ax1, ay1))
    # Subtrai bboxes das pernas (calca preta tambem).
    legs_rect = np.zeros((H, W), dtype=np.uint8)
    for leg_name in ("L_leg_upper", "L_leg_lower", "R_leg_upper", "R_leg_lower"):
        lx0, ly0, lx1, ly1 = BOXES[leg_name]
        legs_rect = np.maximum(legs_rect, rect_mask(W, H, lx0, ly0, lx1, ly1))
    # hair_back = retangulo lateral - torso_narrow - arms - legs
    hair_back_mask = hair_back_rect.copy()
    hair_back_mask = np.where(torso_narrow_rect > 0, np.uint8(0), hair_back_mask)
    hair_back_mask = np.where(arms_rect > 0, np.uint8(0), hair_back_mask)
    hair_back_mask = np.where(legs_rect > 0, np.uint8(0), hair_back_mask)

    # ordem importa: gera as outras partes primeiro; hair_back usa mascara
    # custom; torso tem hair_back subtraido.
    for name, (x0, y0, x1, y1) in BOXES.items():
        if name == "hair_back":
            mask2d = hair_back_mask
        else:
            mask2d = rect_mask(W, H, x0, y0, x1, y1)
        # aplica mask: zera alpha fora do retangulo
        out = rgba.copy()
        out[:, :, 3] = np.minimum(out[:, :, 3], mask2d)
        if name == "torso":
            # zera alpha onde o hair_back ja pega — torso fica so com corpo/roupa
            out[:, :, 3] = np.where(hair_back_mask > 0, np.uint8(0), out[:, :, 3])
        # bbox do conteudo opaco
        alpha = out[:, :, 3]
        ys, xs = np.where(alpha > 0)
        if ys.size == 0:
            print(f"! parte vazia: {name}")
            continue
        ymin, ymax = int(ys.min()), int(ys.max()) + 1
        xmin, xmax = int(xs.min()), int(xs.max()) + 1
        crop = out[ymin:ymax, xmin:xmax]
        pivot_name, (px, py) = PIVOTS[name]
        out_path = OUTDIR / f"{name}.png"
        Image.fromarray(crop, mode="RGBA").save(out_path)
        manifest["parts"][name] = {
            "file": f"parts/{name}.png",
            "offset": [xmin, ymin],           # onde o crop comeca no canvas original
            "size":   [xmax - xmin, ymax - ymin],
            "pivot":  [px, py],               # coordenada global (canvas original)
            "pivot_local": [px - xmin, py - ymin],  # coordenada dentro do crop
            "pivot_name": pivot_name,
            "box": [x0, y0, x1, y1],
        }
        print(f"ok {name}  bbox=({xmin},{ymin})-({xmax},{ymax})  pivot={pivot_name}({px},{py})")

    (OUTDIR.parent / "parts.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"\nok parts.json salvo")

    # composto de inspecao: recompoe todas as partes em 1024x1024 pra verificar
    comp = np.zeros((H, W, 4), dtype=np.uint8)
    for name, meta in manifest["parts"].items():
        part = np.array(Image.open(OUTDIR / f"{name}.png").convert("RGBA"))
        ox, oy = meta["offset"]
        ph, pw = part.shape[:2]
        # alpha compositing simples
        bg = comp[oy:oy+ph, ox:ox+pw]
        a = part[:, :, 3:4].astype(np.float32) / 255.0
        comp_rgb = (part[:, :, :3].astype(np.float32) * a +
                    bg[:, :, :3].astype(np.float32) * (1 - a))
        comp[oy:oy+ph, ox:ox+pw, :3] = comp_rgb.astype(np.uint8)
        comp[oy:oy+ph, ox:ox+pw, 3]  = np.maximum(bg[:, :, 3], part[:, :, 3])
    Image.fromarray(comp, mode="RGBA").save(OUTDIR.parent / "composite_check.png")
    print("ok composite_check.png (recomposicao pra inspecao visual)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
