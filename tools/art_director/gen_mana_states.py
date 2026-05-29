#!/usr/bin/env python3
"""
gen_mana_states.py — 5 variações de idle da Soph por nível de mana.
O cabelo azul escurece das pontas para a raiz conforme a mana diminui.

  soph_mana_5.png — mana cheia  (100% azul)
  soph_mana_4.png — pontas pretas
  soph_mana_3.png — metade preta (metade a metade)
  soph_mana_2.png — quase toda preta (só raiz azul)
  soph_mana_1.png — mana zero   (100% preto)
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H  = 32, 64
ZOOM  = 8
HERE  = Path(__file__).parent
DEST  = HERE.parent.parent / "assets" / "sprites" / "player"
STRIP = HERE / "iterations" / "mana_states_strip.png"

T       = (0,   0,   0,   0)
OUTLINE = (20,  10,  35, 255)
SKIN    = (235, 195, 155, 255)
SKIN_S  = (200, 155, 115, 255)
HAIR    = (65,  125, 220, 255)
HAIR_D  = (35,  80,  175, 255)
HAIR_H  = (130, 185, 255, 255)
HAIR_BK = (22,  18,  25,  255)  # cabelo morto (preto-escuro, não puro)
HAIR_BK_D=(14,  11,  16,  255)  # versão mais escura (profundidade)
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


# ── Lógica de cor do cabelo por mana ─────────────────────────────────────────
# O cabelo tem y=0 (raiz, topo) até y=40 (ponta, baixo).
# O preto avança das PONTAS (y alto) para a RAIZ (y baixo).
#
# Limites onde o preto começa (cutoff_y) por nível:
#   mana 5 → cutoff_y = 41   (tudo azul)
#   mana 4 → cutoff_y = 30   (y>=30 preto = só as pontas)
#   mana 3 → cutoff_y = 20   (y>=20 preto = metade a metade)
#   mana 2 → cutoff_y = 8    (y>=8  preto = quase tudo)
#   mana 1 → cutoff_y = 0    (tudo preto)

CUTOFFS = {5: 41, 4: 30, 3: 20, 2: 8, 1: 0}
# Zona de transição (gradiente de 4px na fronteira)
FADE_WIDTH = 4


def hair_c(y: int, base: tuple, mana: int) -> tuple:
    """Retorna a cor do cabelo na linha y para o nível de mana dado."""
    cutoff = CUTOFFS[mana]
    fade_start = cutoff - FADE_WIDTH

    if y < fade_start:
        return base  # azul normal
    if y >= cutoff:
        # mapeia HAIR→HAIR_BK e HAIR_D→HAIR_BK_D
        if base == HAIR_D or base == HAIR_H:
            return HAIR_BK_D
        return HAIR_BK
    # zona de transição — mistura linear
    t = (y - fade_start) / FADE_WIDTH
    if base == HAIR_H:
        b_from, b_to = HAIR_H, HAIR_BK_D
    elif base == HAIR_D:
        b_from, b_to = HAIR_D, HAIR_BK_D
    else:
        b_from, b_to = HAIR, HAIR_BK
    r = int(b_from[0] * (1-t) + b_to[0] * t)
    g = int(b_from[1] * (1-t) + b_to[1] * t)
    b = int(b_from[2] * (1-t) + b_to[2] * t)
    return (r, g, b, 255)


def mana_rect(img, x0, y0, x1, y1, base, mana):
    for y in range(y0, y1+1):
        c = hair_c(y, base, mana)
        for x in range(x0, x1+1):
            px(img, x, y, c)

def mana_vline(img, x, y0, y1, base, mana):
    for y in range(y0, y1+1):
        px(img, x, y, hair_c(y, base, mana))

def mana_hline(img, x0, x1, y, base, mana):
    c = hair_c(y, base, mana)
    for x in range(x0, x1+1): px(img, x, y, c)


# ── Desenha o sprite completo ────────────────────────────────────────────────

def generate(mana: int) -> Image.Image:
    img = Image.new("RGBA", (W, H), T)

    # ── Cabelo (cores dependentes do mana) ───────────────────────────────────
    mana_rect(img,  7,  0, 21,  2, HAIR,   mana)
    mana_rect(img,  6,  1, 22,  4, HAIR,   mana)
    mana_rect(img, 18,  0, 23,  7, HAIR,   mana)    # franja frontal
    mana_rect(img,  4,  2,  9, 10, HAIR,   mana)
    mana_rect(img,  4, 10,  8, 22, HAIR,   mana)
    mana_rect(img,  4, 22,  7, 32, HAIR,   mana)
    mana_rect(img,  4, 32,  6, 40, HAIR_D, mana)    # ponta escura
    mana_vline(img, 4,  2, 40, HAIR_D, mana)
    mana_vline(img, 5,  2, 35, HAIR_D, mana)
    mana_hline(img, 9, 18,  1, HAIR_H, mana)        # reflexo

    # Outline do cabelo (fixo — o contorno não muda com mana)
    hline(img,  7, 21,  0, OUTLINE)
    px(img,  6,  1, OUTLINE); px(img,  5,  2, OUTLINE)
    px(img,  3,  5, OUTLINE); px(img,  3, 10, OUTLINE)
    px(img,  3, 22, OUTLINE); px(img,  3, 32, OUTLINE)
    px(img, 22,  0, OUTLINE); px(img, 23,  1, OUTLINE)
    px(img, 24,  3, OUTLINE)

    # ── Rosto ────────────────────────────────────────────────────────────────
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE); hline(img, 11, 21, 16, OUTLINE)
    vline(img, 10,  5, 15, OUTLINE); vline(img, 22,  5, 15, OUTLINE)
    px(img, 11,  5, SKIN); px(img, 21,  5, SKIN)
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    hline(img, 12, 20, 15, SKIN_S)
    hline(img, 12, 14,  8, OUTLINE); hline(img, 17, 19,  8, OUTLINE)

    # Olhos — ficam mais apagados com mana baixa
    eye_c = EYE if mana >= 3 else (
        (20, 15, 30, 255) if mana == 2 else (12, 10, 18, 255)
    )
    rect(img, 12, 10, 13, 12, eye_c)
    rect(img, 17, 10, 18, 12, eye_c)
    if mana >= 3:  # reflexo nos olhos some ao perder mana
        px(img, 12, 10, HAIR_H); px(img, 17, 10, HAIR_H)

    # ── Óculos ───────────────────────────────────────────────────────────────
    hline(img, 11, 14,  9, GLASS); hline(img, 11, 14, 13, GLASS)
    vline(img, 11,  9, 13, GLASS); vline(img, 14,  9, 13, GLASS)
    hline(img, 16, 19,  9, GLASS); hline(img, 16, 19, 13, GLASS)
    vline(img, 16,  9, 13, GLASS); vline(img, 19,  9, 13, GLASS)
    px(img, 15, 11, GLASS)
    px(img, 20, 10, GLASS); px(img, 21, 10, GLASS)

    # ── Pescoço ───────────────────────────────────────────────────────────────
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE); vline(img, 18, 17, 19, OUTLINE)

    # ── Capa ─────────────────────────────────────────────────────────────────
    rect(img,  7, 19, 24, 22, CAPE)
    hline(img,  7, 24, 19, OUTLINE)
    vline(img,  3, 19, 56, OUTLINE)
    vline(img, 25, 19, 36, OUTLINE)
    rect(img,  4, 22, 13, 56, CAPE)
    rect(img,  4, 22,  6, 56, CAPE_D)
    for i in range(10):
        px(img, 4+i, 56+i//2, OUTLINE)
    rect(img, 18, 22, 24, 36, CAPE)
    vline(img, 25, 22, 36, OUTLINE)
    hline(img, 18, 25, 36, OUTLINE)

    # ── Bodysuit ─────────────────────────────────────────────────────────────
    rect(img, 13, 20, 19, 42, SUIT)
    vline(img, 15, 23, 40, SUIT_H); vline(img, 16, 23, 40, SUIT_H)
    hline(img, 13, 19, 20, OUTLINE)

    # ── Braços ────────────────────────────────────────────────────────────────
    rect(img,  8, 22, 11, 36, SUIT)
    vline(img,  7, 22, 36, OUTLINE); vline(img, 12, 22, 36, OUTLINE)
    rect(img,  8, 37, 11, 39, SKIN); hline(img,  8, 11, 39, OUTLINE)
    rect(img, 20, 22, 23, 36, SUIT)
    vline(img, 24, 22, 36, OUTLINE); vline(img, 19, 22, 36, OUTLINE)
    rect(img, 20, 37, 23, 39, SKIN); hline(img, 20, 23, 39, OUTLINE)

    # ── Cinturão ──────────────────────────────────────────────────────────────
    hline(img, 12, 20, 41, GOLD); hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)

    # ── Pernas ────────────────────────────────────────────────────────────────
    rect(img, 11, 43, 15, 52, SUIT)
    rect(img, 16, 43, 21, 52, SUIT)
    vline(img, 10, 43, 52, OUTLINE); vline(img, 22, 43, 52, OUTLINE)

    # ── Botas de cano alto ────────────────────────────────────────────────────
    rect(img, 10, 50, 15, 63, BOOT)
    hline(img, 10, 15, 50, BOOT_D); hline(img, 10, 15, 63, OUTLINE)
    vline(img,  9, 50, 63, OUTLINE); vline(img, 16, 50, 63, OUTLINE)
    rect(img, 16, 50, 22, 63, BOOT)
    hline(img, 16, 22, 50, BOOT_D); hline(img, 16, 22, 63, OUTLINE)
    vline(img, 23, 50, 63, OUTLINE)
    vline(img, 15, 50, 63, OUTLINE)

    # ── Cajado ────────────────────────────────────────────────────────────────
    # O orbe muda de cor conforme a mana
    orb_c = ORB if mana >= 3 else (
        (20, 80, 160, 255) if mana == 2 else (12, 40, 90, 255)
    )
    orb_h = ORB_H if mana >= 4 else (
        (80, 160, 220, 255) if mana == 3 else
        (40, 100, 160, 255) if mana == 2 else (20, 50, 90, 255)
    )
    line(img,  6, 44, 25, 22, STAFF_C, hi=STAFF_H)
    line(img,  6, 45, 25, 23, STAFF_C)
    rect(img, 24, 19, 29, 25, orb_c)
    hline(img, 24, 29, 19, OUTLINE); hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE); vline(img, 30, 19, 25, OUTLINE)
    px(img, 25, 20, orb_h); px(img, 26, 20, orb_h); px(img, 25, 21, orb_h)
    if mana >= 3:  # raios de energia somem com mana baixa
        px(img, 30, 18, orb_h); px(img, 31, 17, orb_c)
        px(img, 30, 26, orb_h); px(img, 23, 26, orb_h)

    return img


def label(img, text):
    s = img.resize((W*ZOOM, H*ZOOM), Image.NEAREST)
    out = Image.new("RGBA", (s.width, s.height+20), (15, 12, 20, 255))
    out.paste(s, (0, 0))
    ImageDraw.Draw(out).text((4, s.height+4), text, fill=(180, 180, 220, 255))
    return out


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    previews = []
    for mana in range(5, 0, -1):
        img = generate(mana)
        name = f"soph_mana_{mana}.png"
        img.save(DEST / name)
        print(f"  {name}")
        previews.append(label(img, f"mana {mana}/5"))

    w, h = previews[0].size
    strip = Image.new("RGBA", (w * len(previews), h), (15, 12, 20, 255))
    for i, p in enumerate(previews):
        strip.paste(p, (i*w, 0))
    STRIP.parent.mkdir(parents=True, exist_ok=True)
    strip.save(STRIP)
    print(f"\n  Strip → {STRIP}")


if __name__ == "__main__":
    main()
