"""
Semente imutável da Soph v2 (design capa+bodysuit+cajado+óculos).
Nunca sobrescrita pelo art_director.
art_director.py usa este arquivo como ponto de partida se generator.py estiver corrompido.
"""
from PIL import Image

W, H = 32, 64

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
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)

def hline(img, x0, x1, y, c):
    for x in range(x0, x1+1): px(img, x, y, c)

def vline(img, x, y0, y1, c):
    for y in range(y0, y1+1): px(img, x, y, c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1+1):
        for x in range(x0, x1+1): px(img, x, y, c)

def line(img, x0, y0, x1, y1, c, hi=None):
    """Bresenham — hi pinta um pixel acima como highlight."""
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


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)

    # ── Cabelo longo azul (flui pelas costas) ─────────────────────────────────
    rect(img,  7,  0, 21,  2, HAIR)
    rect(img,  6,  1, 22,  4, HAIR)
    rect(img, 18,  0, 23,  7, HAIR)
    rect(img,  4,  2,  9, 10, HAIR)
    rect(img,  4, 10,  8, 22, HAIR)
    rect(img,  4, 22,  7, 30, HAIR)
    rect(img,  4, 30,  6, 38, HAIR_D)
    vline(img,  4,  2, 38, HAIR_D)
    hline(img,  9, 18,  1, HAIR_H)
    hline(img,  7, 21,  0, OUTLINE)
    px(img,  6,  1, OUTLINE); px(img,  5,  2, OUTLINE)
    px(img,  3,  5, OUTLINE); px(img,  3, 10, OUTLINE)
    px(img,  3, 22, OUTLINE); px(img,  3, 32, OUTLINE)
    px(img, 22,  0, OUTLINE); px(img, 23,  1, OUTLINE)
    px(img, 24,  3, OUTLINE)

    # ── Rosto ─────────────────────────────────────────────────────────────────
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE); hline(img, 11, 21, 16, OUTLINE)
    vline(img, 10,  5, 15, OUTLINE); vline(img, 22,  5, 15, OUTLINE)
    px(img, 11,  5, SKIN); px(img, 21,  5, SKIN)
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    hline(img, 12, 20, 15, SKIN_S)
    hline(img, 12, 14,  8, OUTLINE); hline(img, 17, 19,  8, OUTLINE)

    # ── Óculos (armação fina) ─────────────────────────────────────────────────
    hline(img, 11, 14,  9, GLASS); hline(img, 11, 14, 13, GLASS)
    vline(img, 11,  9, 13, GLASS); vline(img, 14,  9, 13, GLASS)
    hline(img, 16, 19,  9, GLASS); hline(img, 16, 19, 13, GLASS)
    vline(img, 16,  9, 13, GLASS); vline(img, 19,  9, 13, GLASS)
    px(img, 15, 11, GLASS)
    px(img, 20, 10, GLASS); px(img, 21, 10, GLASS)
    rect(img, 12, 10, 13, 12, EYE); rect(img, 17, 10, 18, 12, EYE)
    px(img, 12, 10, HAIR_H); px(img, 17, 10, HAIR_H)

    # ── Pescoço ───────────────────────────────────────────────────────────────
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE); vline(img, 18, 17, 19, OUTLINE)

    # ── Capa — ombros + asas ──────────────────────────────────────────────────
    rect(img,  7, 19, 24, 22, CAPE)
    hline(img,  7, 24, 19, OUTLINE)
    vline(img,  3, 19, 45, OUTLINE)
    vline(img, 25, 19, 36, OUTLINE)
    rect(img,  4, 22, 13, 52, CAPE)
    rect(img,  4, 22,  6, 52, CAPE_D)
    rect(img, 18, 22, 24, 34, CAPE)
    vline(img, 25, 22, 34, OUTLINE)
    hline(img, 18, 25, 34, OUTLINE)

    # ── Bodysuit (centro visível entre as asas) ───────────────────────────────
    rect(img, 13, 20, 19, 42, SUIT)
    vline(img, 15, 23, 40, SUIT_H); vline(img, 16, 23, 40, SUIT_H)
    hline(img, 13, 19, 20, OUTLINE)

    # ── Braços ────────────────────────────────────────────────────────────────
    rect(img,  8, 22, 11, 36, SUIT)
    vline(img,  7, 22, 36, OUTLINE); vline(img, 12, 22, 36, OUTLINE)
    rect(img,  8, 37, 11, 38, SKIN)
    hline(img,  8, 11, 38, OUTLINE)
    rect(img, 20, 22, 23, 36, SUIT)
    vline(img, 24, 22, 36, OUTLINE); vline(img, 19, 22, 36, OUTLINE)
    rect(img, 20, 37, 23, 38, SKIN)
    hline(img, 20, 23, 38, OUTLINE)

    # ── Cinturão dourado ──────────────────────────────────────────────────────
    hline(img, 12, 20, 41, GOLD); hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)

    # ── Capa + pernas ─────────────────────────────────────────────────────────
    rect(img,  5, 44, 13, 52, CAPE)
    rect(img,  5, 44,  6, 52, CAPE_D)
    hline(img,  5, 13, 52, OUTLINE)
    rect(img,  9, 43, 14, 52, SUIT)
    rect(img, 16, 43, 22, 52, SUIT)

    # ── Botas ─────────────────────────────────────────────────────────────────
    rect(img,  9, 50, 14, 63, BOOT)
    hline(img,  9, 14, 50, BOOT_D)
    hline(img,  9, 14, 63, OUTLINE)
    vline(img,  8, 50, 63, OUTLINE); vline(img, 15, 50, 63, OUTLINE)
    rect(img, 16, 50, 22, 63, BOOT)
    hline(img, 16, 22, 50, BOOT_D)
    hline(img, 16, 22, 63, OUTLINE)
    vline(img, 15, 50, 63, OUTLINE); vline(img, 23, 50, 63, OUTLINE)

    # ── Cajado diagonal + orbe azul ───────────────────────────────────────────
    line(img,  6, 44, 25, 22, STAFF_C, hi=STAFF_H)
    line(img,  6, 45, 25, 23, STAFF_C)
    rect(img, 24, 19, 29, 25, ORB)
    hline(img, 24, 29, 19, OUTLINE); hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE); vline(img, 30, 19, 25, OUTLINE)
    px(img, 25, 20, ORB_H); px(img, 26, 20, ORB_H); px(img, 25, 21, ORB_H)
    rect(img, 27, 23, 29, 25, ORB_D)
    px(img, 30, 18, ORB_H); px(img, 31, 17, ORB)

    return img.transpose(Image.FLIP_LEFT_RIGHT)
