#!/usr/bin/env python3
"""
gen_walk_redesign.py — Ciclo de caminhada da Soph com o novo design
(capa, bodysuit escuro, cajado, óculos).  6 frames, 32×64 RGBA.
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H  = 32, 64
ZOOM  = 6
HERE  = Path(__file__).parent
DEST  = HERE.parent.parent / "assets" / "sprites" / "player"
STRIP = HERE / "iterations" / "walk_redesign_strip.png"

T       = (0,   0,   0,   0)
OUTLINE = (20,  10,  35, 255)
SKIN    = (235, 195, 155, 255)
SKIN_S  = (200, 155, 115, 255)
HAIR    = (65,  125, 220, 255)
HAIR_D  = (35,  80,  175, 255)
HAIR_H  = (130, 185, 255, 255)
EYE     = (30,  20,  55,  255)
CAPE    = (25,  20,  45,  255)
CAPE_D  = (12,  10,  25,  255)
SUIT    = (18,  14,  30,  255)
SUIT_H  = (40,  30,  60,  255)
GOLD    = (210, 165, 30,  255)
GOLD_D  = (155, 115, 10,  255)
BOOT    = (70,  45,  25,  255)
BOOT_D  = (45,  25,  10,  255)
STAFF_C = (95,  65,  35,  255)
STAFF_H = (145, 105, 55,  255)
ORB     = (40,  120, 220, 255)
ORB_H   = (140, 210, 255, 255)
ORB_D   = (20,  60,  140, 255)
GLASS   = (60,  55,  80,  255)


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H: img.putpixel((x, y), c)

def hline(img, x0, x1, y, c):
    for x in range(x0, x1+1): px(img, x, y, c)

def vline(img, x, y0, y1, c):
    for y in range(y0, y1+1): px(img, x, y, c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1+1):
        for x in range(x0, x1+1): px(img, x, y, c)

def line(img, x0, y0, x1, y1, c, hi=None):
    dx, dy = abs(x1-x0), abs(y1-y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        px(img, x0, y0, c)
        if hi: px(img, x0, y0-1, hi)
        if x0 == x1 and y0 == y1: break
        e2 = 2*err
        if e2 > -dy: err -= dy; x0 += sx
        if e2 <  dx: err += dx; y0 += sy


def draw_upper(img, arm_l_dy=0, arm_r_dy=0, hair_bob=0):
    """Upper body: cabelo, rosto, óculos, pescoço, capa-ombros, bodysuit, braços."""

    # Cabelo (cauda flui pelas costas — y_bob leve para efeito de caminhada)
    b = hair_bob
    rect(img,  7,  0+b, 21,  2+b, HAIR)
    rect(img,  6,  1+b, 22,  4+b, HAIR)
    rect(img, 18,  0+b, 23,  7+b, HAIR)   # franja frontal
    rect(img,  4,  2+b,  9, 10+b, HAIR)
    rect(img,  4, 10+b,  8, 22+b, HAIR)
    rect(img,  4, 22+b,  7, 30+b, HAIR)
    rect(img,  4, 30+b,  6, 38+b, HAIR_D)
    vline(img,  4,  2+b, 38+b, HAIR_D)
    hline(img,  9, 18,   1+b, HAIR_H)
    # outline cabelo
    hline(img,  7, 21,  0+b, OUTLINE)
    px(img,  6,  1+b, OUTLINE); px(img,  5,  2+b, OUTLINE)
    px(img,  3,  5+b, OUTLINE); px(img,  3, 10+b, OUTLINE)
    px(img,  3, 22+b, OUTLINE); px(img,  3, 32+b, OUTLINE)
    px(img, 22,  0+b, OUTLINE); px(img, 23,  1+b, OUTLINE)
    px(img, 24,  3+b, OUTLINE)

    # Rosto
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE); hline(img, 11, 21, 16, OUTLINE)
    vline(img, 10,  5, 15, OUTLINE); vline(img, 22,  5, 15, OUTLINE)
    px(img, 11, 5, SKIN); px(img, 21, 5, SKIN)
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    hline(img, 12, 20, 15, SKIN_S)
    hline(img, 12, 14,  8, OUTLINE); hline(img, 17, 19,  8, OUTLINE)

    # Óculos
    hline(img, 11, 14,  9, GLASS); hline(img, 11, 14, 13, GLASS)
    vline(img, 11,  9, 13, GLASS); vline(img, 14,  9, 13, GLASS)
    hline(img, 16, 19,  9, GLASS); hline(img, 16, 19, 13, GLASS)
    vline(img, 16,  9, 13, GLASS); vline(img, 19,  9, 13, GLASS)
    px(img, 15, 11, GLASS)
    px(img, 20, 10, GLASS); px(img, 21, 10, GLASS)
    rect(img, 12, 10, 13, 12, EYE); rect(img, 17, 10, 18, 12, EYE)
    px(img, 12, 10, HAIR_H); px(img, 17, 10, HAIR_H)

    # Pescoço
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE); vline(img, 18, 17, 19, OUTLINE)

    # Ombros / capa colarinho
    rect(img,  7, 19, 24, 22, CAPE)
    hline(img,  7, 24, 19, OUTLINE)
    vline(img,  3, 19, 45, OUTLINE)   # outline esq da capa
    vline(img, 25, 19, 36, OUTLINE)   # outline dir

    # Asa esquerda da capa (costas)
    rect(img,  4, 22, 13, 52, CAPE)
    rect(img,  4, 22,  6, 52, CAPE_D)

    # Asa direita da capa (frente)
    rect(img, 18, 22, 24, 34, CAPE)
    vline(img, 25, 22, 34, OUTLINE)
    hline(img, 18, 25, 34, OUTLINE)

    # Bodysuit (centro, visível entre as asas)
    rect(img, 13, 20, 19, 42, SUIT)
    vline(img, 15, 23, 40, SUIT_H); vline(img, 16, 23, 40, SUIT_H)
    hline(img, 13, 19, 20, OUTLINE)

    # Braço esquerdo
    la0 = 22 + arm_l_dy; la1 = 36 + arm_l_dy
    rect(img,  8, la0, 11, la1, SUIT)
    vline(img,  7, la0, la1, OUTLINE); vline(img, 12, la0, la1, OUTLINE)
    rect(img,  8, la1+1, 11, la1+2, SKIN)
    hline(img,  8, 11, la1+2, OUTLINE)

    # Braço direito
    ra0 = 22 + arm_r_dy; ra1 = 36 + arm_r_dy
    rect(img, 20, ra0, 23, ra1, SUIT)
    vline(img, 24, ra0, ra1, OUTLINE); vline(img, 19, ra0, ra1, OUTLINE)
    rect(img, 20, ra1+1, 23, ra1+2, SKIN)
    hline(img, 20, 23, ra1+2, OUTLINE)

    # Cinturão
    hline(img, 12, 20, 41, GOLD); hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)


def draw_legs(img, back_x0, back_x1, back_y_off, front_x0, front_x1,
              cape_edge_dx=0):
    """Pernas + botas + hem da capa."""
    # Capa cobre a transição superior das pernas
    rect(img,  4+cape_edge_dx, 44, 13, 52, CAPE)
    rect(img,  4+cape_edge_dx, 44,  6, 52, CAPE_D)
    hline(img,  4+cape_edge_dx, 13, 52, OUTLINE)  # hem da capa

    # Pernas visíveis abaixo da capa
    rect(img, back_x0,  43, back_x1,  52, SUIT)
    rect(img, front_x0, 43, front_x1, 52, SUIT)

    # Bota de trás
    by0 = 50 + back_y_off
    rect(img, back_x0, by0, back_x1, 63, BOOT)
    hline(img, back_x0, back_x1, by0,   BOOT_D)
    hline(img, back_x0, back_x1, 63,    OUTLINE)
    vline(img, back_x0-1, by0, 63, OUTLINE)
    vline(img, back_x1+1, by0, 63, OUTLINE)

    # Bota da frente
    rect(img, front_x0, 50, front_x1, 63, BOOT)
    hline(img, front_x0, front_x1, 50, BOOT_D)
    hline(img, front_x0, front_x1, 63, OUTLINE)
    vline(img, front_x0-1, 50, 63, OUTLINE)
    vline(img, front_x1+1, 50, 63, OUTLINE)


def draw_staff(img):
    """Cajado diagonal — fixo em todos os frames."""
    line(img,  6, 44, 25, 22, STAFF_C, hi=STAFF_H)
    line(img,  6, 45, 25, 23, STAFF_C)
    rect(img, 24, 19, 29, 25, ORB)
    hline(img, 24, 29, 19, OUTLINE); hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE); vline(img, 30, 19, 25, OUTLINE)
    px(img, 25, 20, ORB_H); px(img, 26, 20, ORB_H); px(img, 25, 21, ORB_H)
    rect(img, 27, 23, 29, 25, ORB_D)
    px(img, 30, 18, ORB_H); px(img, 31, 17, ORB)


# ── Parâmetros dos 6 frames ───────────────────────────────────────────────────
# (back_x0, back_x1, back_y_off, front_x0, front_x1,
#  arm_l_dy, arm_r_dy, hair_bob, cape_edge_dx)
FRAMES = [
    (  9, 14, -1,  16, 22,  -2,  +1,  0,  +1 ),  # 0 pé direito contato
    ( 11, 15,  0,  14, 20,  -1,  -1, -1,   0 ),  # 1 passagem (alto)
    (  9, 14, -1,  16, 22,  +1,  -2,  0,  +1 ),  # 2 pé esquerdo contato
    ( 11, 15,  0,  14, 20,  -1,  -1, -1,   0 ),  # 3 passagem
    (  9, 14, -1,  16, 22,  -2,  +1,  0,  +1 ),  # 4 = frame 0
    ( 11, 15,  0,  14, 20,  -1,  -1, -1,   0 ),  # 5 = frame 1
]


def make_frame(params):
    bx0, bx1, by_off, fx0, fx1, al, ar, hb, cdx = params
    img = Image.new("RGBA", (W, H), T)
    draw_upper(img, arm_l_dy=al, arm_r_dy=ar, hair_bob=hb)
    draw_legs(img, bx0, bx1, by_off, fx0, fx1, cape_edge_dx=cdx)
    draw_staff(img)
    return img


def label(img, text):
    s = img.resize((W*ZOOM, H*ZOOM), Image.NEAREST)
    out = Image.new("RGBA", (s.width, s.height+16), (20, 20, 30, 255))
    out.paste(s, (0, 0))
    ImageDraw.Draw(out).text((4, s.height+2), text, fill=(180, 180, 220, 255))
    return out


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    previews = []
    for i, p in enumerate(FRAMES):
        img = make_frame(p)
        img.save(DEST / f"soph_walk_{i}.png")
        print(f"  soph_walk_{i}.png")
        previews.append(label(img, f"walk_{i}"))
    w, h = previews[0].size
    strip = Image.new("RGBA", (w * len(previews), h), (20, 20, 30, 255))
    for i, p in enumerate(previews):
        strip.paste(p, (i*w, 0))
    STRIP.parent.mkdir(parents=True, exist_ok=True)
    strip.save(STRIP)
    print(f"\n  Strip → {STRIP}")


if __name__ == "__main__":
    main()
