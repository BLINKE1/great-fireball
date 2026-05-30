"""
Semente imutável da Soph. Nunca sobrescrita pelo art_director.
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
    for x in range(x0, x1 + 1):
        px(img, x, y, c)


def vline(img, x, y0, y1, c):
    for y in range(y0, y1 + 1):
        px(img, x, y, c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)

    rect(img,  8, 0, 23,  2, HAIR)
    rect(img,  6, 3, 25,  5, HAIR)
    rect(img,  5, 6, 25,  9, HAIR)
    rect(img,  4, 6,  6, 12, HAIR)
    rect(img, 22, 6, 25, 12, HAIR)
    vline(img,  4,  6, 12, HAIR_D)
    vline(img, 25,  6, 12, HAIR_D)
    hline(img, 10, 19,  1, HAIR_H)

    hline(img,  8, 23,  0, OUTLINE)
    px(img,  7,  1, OUTLINE); px(img,  5,  3, OUTLINE)
    px(img,  4,  6, OUTLINE); px(img,  3,  9, OUTLINE)
    px(img, 24,  0, OUTLINE); px(img, 26,  3, OUTLINE)
    px(img, 26,  6, OUTLINE); px(img, 26,  9, OUTLINE)

    rect(img,  9,  8, 22, 17, SKIN)
    hline(img, 10, 21,  8, OUTLINE)
    hline(img, 10, 21, 17, OUTLINE)
    vline(img,  9,  9, 16, OUTLINE)
    vline(img, 22,  9, 16, OUTLINE)
    px(img, 10,  9, SKIN); px(img, 21,  9, SKIN)
    px(img, 10, 16, SKIN); px(img, 21, 16, SKIN)
    hline(img, 11, 20, 16, SKIN_S)

    # ── Rosto expressivo (estilo anime) ──────────────────────────────────
    WHITE = (255, 255, 255, 255)
    BLUSH = (232, 158, 150, 255)
    MOUTH = (170, 95,  85,  255)

    # Cílio/sobrancelha suave (1px), não a barra grossa anterior
    hline(img, 11, 13, 10, OUTLINE)
    hline(img, 17, 19, 10, OUTLINE)

    # Olho esquerdo: íris azul-escura com brilho branco no canto
    px(img, 11, 11, EYE);   px(img, 12, 11, EYE);   px(img, 13, 11, WHITE)
    px(img, 11, 12, EYE);   px(img, 12, 12, EYE);   px(img, 13, 12, EYE)
    # Olho direito (brilho espelhado para o lado interno)
    px(img, 17, 11, WHITE); px(img, 18, 11, EYE);   px(img, 19, 11, EYE)
    px(img, 17, 12, EYE);   px(img, 18, 12, EYE);   px(img, 19, 12, EYE)

    # Boca pequena e suave (2px central) — expressão curiosa/serena
    px(img, 15, 15, MOUTH); px(img, 16, 15, MOUTH)

    # Blush nas bochechas, na altura da boca (não colado aos olhos)
    px(img, 10, 14, BLUSH); px(img, 11, 14, BLUSH)
    px(img, 20, 14, BLUSH); px(img, 21, 14, BLUSH)

    rect(img, 14, 18, 17, 20, SKIN)
    vline(img, 13, 18, 20, OUTLINE)
    vline(img, 18, 18, 20, OUTLINE)

    rect(img,  7, 20, 24, 24, ROBE)
    hline(img,  7, 24, 20, OUTLINE)
    vline(img,  6, 20, 35, OUTLINE)
    vline(img, 25, 20, 35, OUTLINE)

    rect(img,  4, 21,  6, 35, ROBE_D)
    vline(img,  3, 21, 35, OUTLINE)
    rect(img, 25, 21, 27, 35, ROBE)
    vline(img, 28, 21, 35, OUTLINE)
    rect(img,  4, 35,  6, 37, SKIN)
    rect(img, 25, 35, 27, 37, SKIN)
    hline(img,  4,  6, 37, OUTLINE)
    hline(img, 25, 27, 37, OUTLINE)

    rect(img,  7, 24, 24, 46, ROBE)
    rect(img, 13, 24, 18, 40, ROBE_L)
    vline(img,  7, 24, 46, ROBE_D)
    vline(img,  8, 24, 46, ROBE_D)
    vline(img, 24, 24, 46, ROBE_D)
    vline(img, 23, 24, 46, ROBE_D)
    rect(img,  7, 30, 24, 33, GOLD)
    hline(img,  7, 24, 30, GOLD_D)
    hline(img,  7, 24, 33, GOLD_D)
    rect(img, 14, 30, 17, 33, GOLD_D)
    hline(img,  7, 24, 46, OUTLINE)

    rect(img,  8, 46, 14, 53, ROBE_D)
    rect(img, 16, 46, 23, 53, ROBE)
    hline(img,  8, 14, 53, OUTLINE)
    hline(img, 16, 23, 53, OUTLINE)

    rect(img,  8, 54, 14, 63, BOOT)
    rect(img, 16, 54, 23, 63, BOOT)
    hline(img,  8, 14, 54, BOOT_D)
    hline(img, 16, 23, 54, BOOT_D)
    hline(img,  8, 14, 63, OUTLINE)
    hline(img, 16, 23, 63, OUTLINE)
    vline(img,  7, 54, 63, OUTLINE)
    vline(img, 15, 54, 63, OUTLINE)
    vline(img, 24, 54, 63, OUTLINE)

    return img
