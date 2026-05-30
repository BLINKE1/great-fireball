#!/usr/bin/env python3
"""
gen_walk.py — Gera 6 frames do ciclo de caminhada da Soph (32×64 RGBA).
Baseado na paleta canônica do generator_seed.py.
Salva em assets/sprites/player/soph_walk_0..5.png
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H   = 32, 64
ZOOM   = 6
DEST   = Path(__file__).parent.parent.parent / "assets" / "sprites" / "player"
STRIP  = Path(__file__).parent / "iterations" / "walk_strip.png"

# Paleta canônica
T       = (0,   0,   0,   0)
OUTLINE = (20,  10,  35, 255)
SKIN    = (235, 195, 155, 255)
SKIN_S  = (200, 155, 115, 255)
HAIR    = (65,  125, 220, 255)
HAIR_D  = (35,  80,  175, 255)
HAIR_H  = (130, 185, 255, 255)
EYE     = (30,  20,  55,  255)
ROBE    = (80,  40,  140, 255)
ROBE_D  = (45,  20,  85,  255)
ROBE_L  = (120, 70,  185, 255)
GOLD    = (210, 165, 30,  255)
GOLD_D  = (155, 115, 10,  255)
BOOT    = (75,  50,  30,  255)
BOOT_D  = (50,  30,  15,  255)


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)

def hline(img, x0, x1, y, c):
    for x in range(x0, x1+1): px(img, x, y, c)

def vline(img, x, y0, y1, c):
    for y in range(y0, y1+1): px(img, x, y, c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1+1):
        for x in range(x0, x1+1): px(img, x, y, c)


# ── Upper body (same in all frames except arm swing) ─────────────────────────

def draw_upper(img, arm_l_dy: int = 0, arm_r_dy: int = 0) -> None:
    """
    Desenha: cabelo, rosto, pescoço, ombros, braços, tronco do robe.
    arm_l_dy / arm_r_dy: deslocamento vertical do braço esq/dir
                         negativo = braço mais alto (swing forward)
                         positivo = braço mais baixo (swing back)
    """
    # ── Cabelo ───────────────────────────────────────────────────────────────
    rect(img,  8, 0, 23,  2, HAIR)
    rect(img,  6, 3, 25,  5, HAIR)
    rect(img,  5, 6, 25,  9, HAIR)
    rect(img,  4, 6,  6, 12, HAIR)
    rect(img, 22, 6, 25, 12, HAIR)
    vline(img,  4,  6, 12, HAIR_D)
    vline(img, 25,  6, 12, HAIR_D)
    hline(img, 10, 19,  1, HAIR_H)
    # outline cabelo
    hline(img,  8, 23,  0, OUTLINE)
    px(img,  7,  1, OUTLINE); px(img,  5,  3, OUTLINE)
    px(img,  4,  6, OUTLINE); px(img,  3,  9, OUTLINE)
    px(img, 24,  0, OUTLINE); px(img, 26,  3, OUTLINE)
    px(img, 26,  6, OUTLINE); px(img, 26,  9, OUTLINE)

    # ── Rosto ────────────────────────────────────────────────────────────────
    rect(img,  9,  8, 22, 17, SKIN)
    hline(img, 10, 21,  8, OUTLINE)
    hline(img, 10, 21, 17, OUTLINE)
    vline(img,  9,  9, 16, OUTLINE)
    vline(img, 22,  9, 16, OUTLINE)
    px(img, 10,  9, SKIN); px(img, 21,  9, SKIN)
    px(img, 10, 16, SKIN); px(img, 21, 16, SKIN)
    hline(img, 11, 20, 16, SKIN_S)
    # Olhos
    rect(img, 11, 11, 13, 13, EYE)
    rect(img, 17, 11, 19, 13, EYE)
    px(img, 12, 11, HAIR_H)
    px(img, 18, 11, HAIR_H)
    hline(img, 11, 13, 10, OUTLINE)
    hline(img, 17, 19, 10, OUTLINE)

    # ── Pescoço ──────────────────────────────────────────────────────────────
    rect(img, 14, 18, 17, 20, SKIN)
    vline(img, 13, 18, 20, OUTLINE)
    vline(img, 18, 18, 20, OUTLINE)

    # ── Ombros ───────────────────────────────────────────────────────────────
    rect(img,  7, 20, 24, 24, ROBE)
    hline(img,  7, 24, 20, OUTLINE)
    vline(img,  6, 20, 45, OUTLINE)
    vline(img, 25, 20, 45, OUTLINE)

    # ── Braço esquerdo (costas, mais escuro) ─────────────────────────────────
    la0 = 21 + arm_l_dy
    la1 = 35 + arm_l_dy
    rect(img,  4, la0,  6, la1, ROBE_D)
    vline(img,  3, la0, la1, OUTLINE)
    vline(img,  7, la0, la1, OUTLINE)
    # Mão
    rect(img,  4, la1+1,  6, la1+2, SKIN)
    hline(img,  4,  6, la1+2, OUTLINE)

    # ── Braço direito (frente) ────────────────────────────────────────────────
    ra0 = 21 + arm_r_dy
    ra1 = 35 + arm_r_dy
    rect(img, 25, ra0, 27, ra1, ROBE)
    vline(img, 28, ra0, ra1, OUTLINE)
    vline(img, 24, ra0, ra1, OUTLINE)
    # Mão
    rect(img, 25, ra1+1, 27, ra1+2, SKIN)
    hline(img, 25, 27, ra1+2, OUTLINE)

    # ── Tronco do robe ────────────────────────────────────────────────────────
    rect(img,  7, 24, 24, 45, ROBE)
    rect(img, 13, 24, 18, 40, ROBE_L)
    vline(img,  7, 24, 45, ROBE_D)
    vline(img,  8, 24, 45, ROBE_D)
    vline(img, 24, 24, 45, ROBE_D)
    vline(img, 23, 24, 45, ROBE_D)
    # Faixa dourada
    rect(img,  7, 30, 24, 33, GOLD)
    hline(img,  7, 24, 30, GOLD_D)
    hline(img,  7, 24, 33, GOLD_D)
    rect(img, 14, 30, 17, 33, GOLD_D)


# ── Lower body (variable per frame) ──────────────────────────────────────────

def draw_legs(img,
              back_x0: int, back_x1: int, back_y_off: int,
              front_x0: int, front_x1: int) -> None:
    """
    Desenha o hem do robe + botas.
    back_* = perna de trás (mais escura, opcional y_off para perspectiva)
    front_* = perna da frente (mais clara, no chão)
    Ordem: back primeiro, front por cima.
    """
    # Hem traseiro
    rect(img, back_x0, 46, back_x1, 53 + back_y_off, ROBE_D)
    hline(img, back_x0, back_x1, 53 + back_y_off, OUTLINE)
    # Bota traseira
    rect(img, back_x0, 54 + back_y_off, back_x1, 63, BOOT)
    hline(img, back_x0, back_x1, 54 + back_y_off, BOOT_D)
    hline(img, back_x0, back_x1, 63, OUTLINE)
    vline(img, back_x0-1, 54 + back_y_off, 63, OUTLINE)
    vline(img, back_x1+1, 54 + back_y_off, 63, OUTLINE)

    # Hem dianteiro
    rect(img, front_x0, 46, front_x1, 53, ROBE)
    hline(img, front_x0, front_x1, 53, OUTLINE)
    # Bota dianteira
    rect(img, front_x0, 54, front_x1, 63, BOOT)
    hline(img, front_x0, front_x1, 54, BOOT_D)
    hline(img, front_x0, front_x1, 63, OUTLINE)
    vline(img, front_x0-1, 54, 63, OUTLINE)
    vline(img, front_x1+1, 54, 63, OUTLINE)


# ── 6-frame walk cycle ────────────────────────────────────────────────────────
#
#  A perna "da frente" no sprite (x maior) representa o passo à frente.
#  A perna "de trás"  (x menor) representa o passo atrás.
#  Os braços balançam ao contrário das pernas (biomecânica).
#
#  Ciclo de 6 quadros (vista lateral direita):
#   0 — pé direito avança (contato)   braço esq sobe
#   1 — passagem (pés cruzando)       braços neutros, levemente subidos
#   2 — pé esquerdo avança (contato)  braço dir sobe
#   3 — passagem                      braços neutros
#   4 — repetição de 0 (fecha o loop sem frame extra)
#   5 — repetição de 1

FRAMES = [
    # (back_x0, back_x1, back_y_off, front_x0, front_x1, arm_l_dy, arm_r_dy)
    # Frame 0 — pé direito avança (pé direito = perna dianteira da sprite)
    (  6, 12, -1,  17, 24,  -2,  +1 ),
    # Frame 1 — passagem (pés cruzando, body no ponto alto)
    (  9, 15,  0,  14, 21,  -1,  -1 ),
    # Frame 2 — pé esquerdo avança
    (  6, 12, -1,  17, 24,  +1,  -2 ),
    # Frame 3 — passagem
    (  9, 15,  0,  14, 21,  -1,  -1 ),
    # Frame 4 — repetição de frame 0 (6 frames = 2 ciclos de 3)
    (  6, 12, -1,  17, 24,  -2,  +1 ),
    # Frame 5 — repetição de frame 1
    (  9, 15,  0,  14, 21,  -1,  -1 ),
]


def make_frame(params: tuple) -> Image.Image:
    back_x0, back_x1, back_y_off, front_x0, front_x1, arm_l_dy, arm_r_dy = params
    img = Image.new("RGBA", (W, H), T)
    draw_upper(img, arm_l_dy=arm_l_dy, arm_r_dy=arm_r_dy)
    draw_legs(img, back_x0, back_x1, back_y_off, front_x0, front_x1)
    return img


def zoom_label(img: Image.Image, label: str) -> Image.Image:
    scaled = img.resize((W * ZOOM, H * ZOOM), Image.NEAREST)
    out = Image.new("RGBA", (scaled.width, scaled.height + 16), (25, 25, 25, 255))
    out.paste(scaled, (0, 0))
    ImageDraw.Draw(out).text((4, scaled.height + 2), label, fill=(200, 200, 200, 255))
    return out


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    previews = []
    for i, params in enumerate(FRAMES):
        img = make_frame(params)
        path = DEST / f"soph_walk_{i}.png"
        img.save(path)
        print(f"  soph_walk_{i}.png → {path}")
        previews.append(zoom_label(img, f"walk_{i}"))

    # Strip de preview
    W_s = previews[0].width
    H_s = previews[0].height
    strip = Image.new("RGBA", (W_s * len(previews), H_s), (25, 25, 25, 255))
    for i, p in enumerate(previews):
        strip.paste(p, (i * W_s, 0))
    STRIP.parent.mkdir(parents=True, exist_ok=True)
    strip.save(STRIP)
    print(f"\n  Preview strip → {STRIP}")


if __name__ == "__main__":
    main()
