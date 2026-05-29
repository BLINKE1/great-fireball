"""
Código-semente de geração da Soph. Este arquivo é substituído pelo
art_director.py a cada iteração — é o "canvas" que o Claude melhora.

Define obrigatoriamente: generate() -> PIL.Image  (32×64, RGBA)
"""
from PIL import Image

W, H = 32, 64
T    = (0, 0, 0, 0)
SKIN = (235, 195, 155, 255)
HAIR = (70,  130, 220, 255)
HAIR_D = (40,  90, 170, 255)
ROBE   = (100,  55, 165, 255)
ROBE_D = (60,   30, 110, 255)
ROBE_L = (145,  95, 205, 255)
BOOT   = (65,   45,  35, 255)
EYE    = (25,   15,  45, 255)
BLUSH  = (245, 165, 155, 255)


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)
    px  = img.load()

    # ── Cabelo ──────────────────────────────────────────────────────────
    for dy in range(13):
        for dx in range(18):
            x, y = 7 + dx, dy
            nx = (dx - 8.5) / 9.0
            ny = (dy - 5.0) / 6.5
            if nx * nx + ny * ny < 1.05:
                px[x, y] = HAIR_D if (dx % 4 < 1 and dy % 5 < 2) else HAIR

    # ── Rosto ────────────────────────────────────────────────────────────
    for dy in range(10):
        for dx in range(12):
            x, y = 10 + dx, 10 + dy
            nx = (dx - 5.5) / 5.5
            ny = (dy - 4.5) / 4.5
            if nx * nx * 0.85 + ny * ny < 1.0:
                px[x, y] = SKIN
    px[13, 14] = EYE; px[13, 15] = EYE
    px[18, 14] = EYE; px[18, 15] = EYE
    px[12, 17] = BLUSH
    px[19, 17] = BLUSH

    # ── Robe (tronco) ────────────────────────────────────────────────────
    for dy in range(24):
        w = 14 + dy // 3
        x0 = (W - w) // 2
        for dx in range(w):
            x, y = x0 + dx, 20 + dy
            rel = dx / max(w - 1, 1)
            if dx == 0 or dx == w - 1:
                c = ROBE_D
            elif rel < 0.12 or rel > 0.88:
                c = ROBE
            elif dy < 5 and 0.35 < rel < 0.65:
                c = ROBE_L
            else:
                c = ROBE
            px[x, y] = c

    # ── Braços ───────────────────────────────────────────────────────────
    for dy in range(12):
        for side, ax in [(-1, W // 2 - 8), (1, W // 2 + 5)]:
            x, y = ax, 22 + dy
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = SKIN if dy < 4 else ROBE
                if 0 <= x + 1 < W:
                    px[x + 1, y] = ROBE_D

    # ── Pernas ───────────────────────────────────────────────────────────
    for side, bx in [(-1, W // 2 - 5), (1, W // 2 + 2)]:
        for dy in range(18):
            x, y = bx, 44 + dy
            if 0 <= x < W and 0 <= y < H:
                c = BOOT if dy > 10 else (ROBE_D if side == -1 else ROBE)
                px[x, y] = c
                if 0 <= x + 1 < W:
                    px[x + 1, y] = BOOT if dy > 10 else ROBE_D

    return img
