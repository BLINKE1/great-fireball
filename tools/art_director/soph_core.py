#!/usr/bin/env python3
"""
soph_core.py — Fonte única de verdade para o sprite da Soph (redesign).

Todos os geradores de frame (idle, walk, run, jump, fall, hurt, mana states)
importam este módulo. Isto elimina a duplicação que fazia os geradores
divergirem (facing trocado, óculos diferentes, etc.).

Convenção de facing: a personagem é desenhada VIRADA PARA A DIREITA
(cauda do cabelo à esquerda, cajado/orbe à direita). O jogo espelha por
código (sprite.flip_h = facing < 0) ao andar para a esquerda.

Design (do rascunho do usuário):
  - Cabelo azul longo fluindo pelas costas (escurece com mana baixa)
  - Óculos REDONDOS (lente clara + aro fino), não um visor
  - Bodysuit escuro estilo Raven + capa quase preta
  - Cajado diagonal com orbe azul
  - Botas de cano alto marrom-escuras
"""
from PIL import Image

W, H = 32, 64

# ── Paleta ──────────────────────────────────────────────────────────────────
T        = (0,   0,   0,   0)
OUTLINE  = (20,  10,  35, 255)
SKIN     = (235, 195, 155, 255)
SKIN_S   = (200, 155, 115, 255)
HAIR     = (65,  125, 220, 255)
HAIR_D   = (35,  80,  175, 255)
HAIR_H   = (130, 185, 255, 255)
HAIR_BK  = (22,  18,  25,  255)   # cabelo "morto" (mana zero)
HAIR_BK_D= (14,  11,  16,  255)
EYE      = (30,  20,  55,  255)
CAPE     = (25,  20,  45,  255)
CAPE_D   = (12,  10,  25,  255)
SUIT     = (18,  14,  30,  255)
SUIT_H   = (40,  30,  60,  255)
GOLD     = (210, 165, 30,  255)
GOLD_D   = (155, 115, 10,  255)
BOOT     = (70,  45,  25,  255)
BOOT_D   = (45,  25,  10,  255)
STAFF_C  = (95,  65,  35,  255)
STAFF_H  = (145, 105, 55,  255)
ORB      = (40,  120, 220, 255)
ORB_H    = (140, 210, 255, 255)
ORB_D    = (20,  60,  140, 255)
GLASS    = (60,  55,  80,  255)
LENS     = (205, 222, 240, 255)   # vidro claro dos óculos
WHITE    = (255, 255, 255, 255)


# ── Primitivas ────────────────────────────────────────────────────────────────
def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)

def hline(img, x0, x1, y, c):
    for x in range(x0, x1 + 1): px(img, x, y, c)

def vline(img, x, y0, y1, c):
    for y in range(y0, y1 + 1): px(img, x, y, c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1): px(img, x, y, c)

def line(img, x0, y0, x1, y1, c, hi=None):
    dx, dy = abs(x1 - x0), abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        px(img, x0, y0, c)
        if hi: px(img, x0, y0 - 1, hi)
        if x0 == x1 and y0 == y1: break
        e2 = 2 * err
        if e2 > -dy: err -= dy; x0 += sx
        if e2 <  dx: err += dx; y0 += sy


# ── Cabelo dependente de mana ──────────────────────────────────────────────────
# y=0 (raiz) … y=40 (ponta). O preto avança das pontas para a raiz.
CUTOFFS    = {5: 41, 4: 30, 3: 20, 2: 8, 1: 0}
FADE_WIDTH = 4

def hair_c(y, base, mana):
    cutoff = CUTOFFS[mana]
    fade_start = cutoff - FADE_WIDTH
    if y < fade_start:
        return base
    if y >= cutoff:
        return HAIR_BK_D if base in (HAIR_D, HAIR_H) else HAIR_BK
    t = (y - fade_start) / FADE_WIDTH
    if base == HAIR_H:   b_from, b_to = HAIR_H, HAIR_BK_D
    elif base == HAIR_D: b_from, b_to = HAIR_D, HAIR_BK_D
    else:                b_from, b_to = HAIR, HAIR_BK
    return tuple(int(b_from[i] * (1 - t) + b_to[i] * t) for i in range(3)) + (255,)

def _mrect(img, x0, y0, x1, y1, base, mana):
    for y in range(y0, y1 + 1):
        c = hair_c(y, base, mana)
        for x in range(x0, x1 + 1): px(img, x, y, c)

def _mvline(img, x, y0, y1, base, mana):
    for y in range(y0, y1 + 1): px(img, x, y, hair_c(y, base, mana))

def _mhline(img, x0, x1, y, base, mana):
    c = hair_c(y, base, mana)
    for x in range(x0, x1 + 1): px(img, x, y, c)


# ── Partes do corpo ─────────────────────────────────────────────────────────--
def draw_hair(img, mana=5, bob=0):
    b = bob
    _mrect(img,  7,  0 + b, 21,  2 + b, HAIR,   mana)
    _mrect(img,  6,  1 + b, 22,  4 + b, HAIR,   mana)
    _mrect(img, 18,  0 + b, 23,  7 + b, HAIR,   mana)   # franja frontal (direita)
    _mrect(img,  4,  2 + b,  9, 10 + b, HAIR,   mana)
    _mrect(img,  4, 10 + b,  8, 22 + b, HAIR,   mana)
    _mrect(img,  4, 22 + b,  7, 32 + b, HAIR,   mana)
    _mrect(img,  4, 32 + b,  6, 40 + b, HAIR_D, mana)   # ponta escura
    _mvline(img, 4,  2 + b, 40 + b, HAIR_D, mana)
    _mvline(img, 5,  2 + b, 35 + b, HAIR_D, mana)
    _mhline(img, 9, 18,  1 + b, HAIR_H, mana)           # reflexo no topo
    # outline (fixo)
    hline(img,  7, 21,  0 + b, OUTLINE)
    px(img,  6,  1 + b, OUTLINE); px(img,  5,  2 + b, OUTLINE)
    px(img,  3,  5 + b, OUTLINE); px(img,  3, 10 + b, OUTLINE)
    px(img,  3, 22 + b, OUTLINE); px(img,  3, 32 + b, OUTLINE)
    px(img, 22,  0 + b, OUTLINE); px(img, 23,  1 + b, OUTLINE)
    px(img, 24,  3 + b, OUTLINE)


def draw_face(img, mana=5):
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE); hline(img, 11, 21, 16, OUTLINE)
    vline(img, 10,  5, 15, OUTLINE); vline(img, 22,  5, 15, OUTLINE)
    px(img, 11, 5, SKIN); px(img, 21, 5, SKIN)
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    hline(img, 12, 20, 15, SKIN_S)                      # sombra do queixo
    hline(img, 12, 14,  8, OUTLINE); hline(img, 17, 19,  8, OUTLINE)  # sobrancelhas

    # Olhos (apagam com mana baixa)
    eye_c = EYE if mana >= 3 else ((20, 15, 30, 255) if mana == 2 else (12, 10, 18, 255))
    px(img, 11, 11, eye_c); px(img, 12, 11, eye_c)
    px(img, 19, 11, eye_c); px(img, 20, 11, eye_c)

    # Óculos REDONDOS: aro GLASS + lente clara, com os olhos visíveis atrás
    _lens(img, 10, 9, 13, 12)
    _lens(img, 18, 9, 21, 12)
    hline(img, 14, 17, 10, GLASS)                       # ponte
    px(img,  9, 10, GLASS)                              # haste
    if mana >= 3:                                       # brilho da lente
        px(img, 11, 10, WHITE); px(img, 19, 10, WHITE)
    # boca pequena (olhar sereno, levemente p/ baixo)
    px(img, 15, 14, SKIN_S); px(img, 16, 14, SKIN_S)


def _lens(img, x0, y0, x1, y1):
    """Aro do óculos (GLASS) preservando os olhos já desenhados no interior."""
    # preenche vidro claro só onde não há olho (EYE-ish)
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            cur = img.getpixel((xx, yy))
            is_eye = cur[2] > cur[0] and cur[2] < 80 and cur[3] == 255 and cur[1] < 60
            if not is_eye:
                px(img, xx, yy, LENS)
    hline(img, x0, x1, y0, GLASS); hline(img, x0, x1, y1, GLASS)
    vline(img, x0, y0, y1, GLASS); vline(img, x1, y0, y1, GLASS)


def draw_neck(img):
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE); vline(img, 18, 17, 19, OUTLINE)


def draw_cape(img, lower_y=56):
    rect(img,  7, 19, 24, 22, CAPE)
    hline(img,  7, 24, 19, OUTLINE)
    vline(img,  3, 19, lower_y, OUTLINE)
    vline(img, 25, 19, 36, OUTLINE)
    rect(img,  4, 22, 13, lower_y, CAPE)
    rect(img,  4, 22,  6, lower_y, CAPE_D)
    for i in range(10):
        px(img, 4 + i, lower_y + i // 2, OUTLINE)        # hem diagonal
    rect(img, 18, 22, 24, 36, CAPE)
    vline(img, 25, 22, 36, OUTLINE)
    hline(img, 18, 25, 36, OUTLINE)


def draw_bodysuit(img):
    rect(img, 13, 20, 19, 42, SUIT)
    vline(img, 15, 23, 40, SUIT_H); vline(img, 16, 23, 40, SUIT_H)
    hline(img, 13, 19, 20, OUTLINE)


def draw_belt(img):
    hline(img, 12, 20, 41, GOLD); hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)


def _arm(img, x0, x1, y0, y1):
    rect(img, x0, y0, x1, y1, SUIT)
    vline(img, x0 - 1, y0, y1, OUTLINE); vline(img, x1 + 1, y0, y1, OUTLINE)
    rect(img, x0, y1 + 1, x1, y1 + 3, SKIN)              # mão
    hline(img, x0, x1, y1 + 3, OUTLINE)


def draw_arms(img, mode="down", l_dy=0, r_dy=0):
    if mode == "up":          # jump: braços erguidos para cima
        rect(img,  7, 12, 10, 22, SUIT)
        vline(img,  6, 12, 22, OUTLINE); vline(img, 11, 12, 22, OUTLINE)
        rect(img,  7,  9, 10, 11, SKIN); hline(img, 7, 10, 9, OUTLINE)
        rect(img, 21, 12, 24, 22, SUIT)
        vline(img, 20, 12, 22, OUTLINE); vline(img, 25, 12, 22, OUTLINE)
        rect(img, 21,  9, 24, 11, SKIN); hline(img, 21, 24, 9, OUTLINE)
    elif mode == "out":       # fall: braços abertos para os lados/baixo
        _arm(img,  6, 9, 24 + l_dy, 34 + l_dy)
        _arm(img, 22, 25, 24 + r_dy, 34 + r_dy)
    elif mode == "guard":     # hurt: braço da frente sobe protegendo o rosto
        _arm(img,  8, 11, 24 + l_dy, 38 + l_dy)          # braço de trás baixo
        rect(img, 19, 14, 22, 22, SUIT)                  # antebraço da frente subindo
        vline(img, 18, 14, 22, OUTLINE); vline(img, 23, 14, 22, OUTLINE)
        rect(img, 19, 12, 22, 13, SKIN); hline(img, 19, 22, 12, OUTLINE)
    else:                     # down: braços ao lado (idle/walk/run)
        _arm(img,  8, 11, 22 + l_dy, 36 + l_dy)
        _arm(img, 20, 23, 22 + r_dy, 36 + r_dy)


def draw_legs(img, back=(11, 15), front=(16, 21), top=43, knee_dy=0):
    bx0, bx1 = back; fx0, fx1 = front
    rect(img, bx0, top, bx1, 52 - knee_dy, SUIT)
    rect(img, fx0, top, fx1, 52, SUIT)
    vline(img, bx0 - 1, top, 52 - knee_dy, OUTLINE)
    vline(img, fx1 + 1, top, 52, OUTLINE)


def draw_boots(img, back=(10, 15), front=(16, 22), back_y=50, front_y=50):
    bx0, bx1 = back; fx0, fx1 = front
    # bota de trás
    rect(img, bx0, back_y, bx1, 63, BOOT)
    hline(img, bx0, bx1, back_y, BOOT_D); hline(img, bx0, bx1, 63, OUTLINE)
    vline(img, bx0 - 1, back_y, 63, OUTLINE); vline(img, bx1 + 1, back_y, 63, OUTLINE)
    # bota da frente
    rect(img, fx0, front_y, fx1, 63, BOOT)
    hline(img, fx0, fx1, front_y, BOOT_D); hline(img, fx0, fx1, 63, OUTLINE)
    vline(img, fx0 - 1, front_y, 63, OUTLINE); vline(img, fx1 + 1, front_y, 63, OUTLINE)


def draw_staff(img, mana=5):
    orb_c = ORB if mana >= 3 else ((20, 80, 160, 255) if mana == 2 else (12, 40, 90, 255))
    orb_h = (ORB_H if mana >= 4 else (80, 160, 220, 255) if mana == 3 else
             (40, 100, 160, 255) if mana == 2 else (20, 50, 90, 255))
    line(img,  6, 44, 25, 22, STAFF_C, hi=STAFF_H)
    line(img,  6, 45, 25, 23, STAFF_C)
    rect(img, 24, 19, 29, 25, orb_c)
    hline(img, 24, 29, 19, OUTLINE); hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE); vline(img, 30, 19, 25, OUTLINE)
    px(img, 25, 20, orb_h); px(img, 26, 20, orb_h); px(img, 25, 21, orb_h)
    rect(img, 27, 23, 29, 25, ORB_D)
    if mana >= 3:
        px(img, 30, 18, orb_h); px(img, 31, 17, orb_c)
        px(img, 30, 26, orb_h); px(img, 23, 26, orb_h)


def mirror_face(img):
    """Espelha a região do rosto para a personagem olhar para a DIREITA."""
    face = img.crop((10, 4, 23, 17))
    img.paste(face.transpose(Image.FLIP_LEFT_RIGHT), (10, 4))


# ── Montagem de um frame ────────────────────────────────────────────────────--
def compose(mana=5, hair_bob=0, arms="down", l_dy=0, r_dy=0,
            legs=None, boots=None, knee_dy=0, cape_lower=56,
            staff=True) -> Image.Image:
    img = Image.new("RGBA", (W, H), T)
    draw_hair(img, mana=mana, bob=hair_bob)
    draw_face(img, mana=mana)
    draw_neck(img)
    draw_cape(img, lower_y=cape_lower)
    draw_bodysuit(img)
    draw_arms(img, mode=arms, l_dy=l_dy, r_dy=r_dy)
    draw_belt(img)
    draw_legs(img, **(legs or {}), knee_dy=knee_dy)
    draw_boots(img, **(boots or {}))
    if staff:
        draw_staff(img, mana=mana)
    mirror_face(img)
    return img
