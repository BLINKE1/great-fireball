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
# Acentos de design (luz de cima-esquerda, focal no rosto/orbe)
CAPE_L   = (70,  90,  150, 255)   # rim-light frio (luz da lua) na borda da capa
CAPE_GLOW= (45,  70,  130, 255)   # glow azul do orbe lambendo a capa (luz motivada)
LINING   = (120, 55,  140, 255)   # forro roxo (acento complementar do quase-preto)
LINING_D = (78,  34,  95,  255)
SUIT_SH  = (10,  8,   18,  255)   # sombra de forma no bodysuit (lado direito)
BROW     = (45,  60,  120, 255)   # sobrancelha azulada suave
BLUSH    = (232, 158, 150, 255)
MOUTH    = (170, 95,  85,  255)
SCLERA   = (250, 250, 255, 255)   # branco dos olhos
SCLERA_D = (175, 178, 200, 255)   # branco apagado (mana baixa)


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
def draw_hair(img, mana=5, bob=0, sway=0):
    """sway: deslocamento horizontal da PONTA do cabelo (pêndulo, p/ animação)."""
    b = bob
    s = sway                                            # ponta (y>=33) desloca s
    h = sway // 2 if sway else 0                        # meio (y26-32) desloca metade
    # ── Topo / franja (fixos) ──
    _mrect(img,  7,  0 + b, 21,  2 + b, HAIR,   mana)
    _mrect(img,  6,  1 + b, 22,  4 + b, HAIR,   mana)
    _mrect(img, 18,  0 + b, 23,  7 + b, HAIR,   mana)   # franja frontal (direita)
    _mrect(img,  4,  2 + b,  9, 10 + b, HAIR,   mana)
    _mrect(img,  4, 10 + b,  8, 26 + b, HAIR,   mana)
    # ── Cauda baixa (com sway) ──
    _mrect(img,  4 + h, 26 + b,  7 + h, 32 + b, HAIR,   mana)
    _mrect(img,  4 + s, 32 + b,  6 + s, 40 + b, HAIR_D, mana)   # ponta escura
    _mvline(img, 4,  2 + b, 25 + b, HAIR_D, mana)
    _mvline(img, 4 + h, 26 + b, 32 + b, HAIR_D, mana)
    _mvline(img, 4 + s, 33 + b, 40 + b, HAIR_D, mana)
    _mvline(img, 5,  2 + b, 25 + b, HAIR_D, mana)
    _mvline(img, 5 + h, 26 + b, 35 + b, HAIR_D, mana)
    _mhline(img, 9, 18,  1 + b, HAIR_H, mana)           # reflexo no topo
    _mvline(img, 7,  5 + b, 25 + b, HAIR_H, mana)       # mecha de brilho (alto)
    _mvline(img, 7 + h, 26 + b, 30 + b, HAIR_H, mana)   # mecha (baixo, com sway)
    _mhline(img, 19, 22, 3 + b, HAIR_H, mana)           # brilho na franja frontal
    px(img, 5 + s, 39 + b, hair_c(39 + b, HAIR_D, mana))   # fios soltos na ponta
    px(img, 6 + s, 41 + b, hair_c(40, HAIR_D, mana))
    # ── Outline ──
    hline(img,  7, 21,  0 + b, OUTLINE)
    px(img,  6,  1 + b, OUTLINE); px(img,  5,  2 + b, OUTLINE)
    px(img,  3,  5 + b, OUTLINE); px(img,  3, 10 + b, OUTLINE)
    px(img,  3 + h, 26 + b, OUTLINE); px(img,  3 + s, 33 + b, OUTLINE)
    px(img, 22,  0 + b, OUTLINE); px(img, 23,  1 + b, OUTLINE)
    px(img, 24,  3 + b, OUTLINE)


def draw_face(img, mana=5):
    full = True                                          # olhos SEMPRE vivos (sem olho-vazio)
    # ── Pele + formato (cantos arredondados, luz de cima-esquerda) ────────────
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE); hline(img, 11, 21, 16, OUTLINE)
    vline(img, 10,  5, 15, OUTLINE); vline(img, 22,  5, 15, OUTLINE)
    px(img, 11, 5, SKIN); px(img, 21, 5, SKIN)           # cantos arredondados
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    px(img, 15, 15, SKIN_S); px(img, 16, 15, SKIN_S)     # leve sombra do queixo (simétrica)
    px(img, 16, 12, SKIN_S)                              # narizinho discreto

    # ── Olhos expressivos (pupila + íris azul + brilho) ───────────────────────
    iris = HAIR if full else HAIR_D
    pup  = EYE if full else (12, 10, 18, 255)
    # olho esquerdo (x12-13, y10-11) e direito (x18-19, y10-11)
    for ex in (12, 18):
        px(img, ex, 10, iris); px(img, ex + 1, 10, pup)
        px(img, ex, 11, pup);  px(img, ex + 1, 11, iris)
        if full:
            px(img, ex, 10, WHITE)                       # catchlight no canto sup-esq
    # ── Óculos REDONDOS delicados: aro fino contornando cada olho ─────────────
    # lente esquerda — anel ao redor de (12-13,10-11)
    px(img, 12, 9, GLASS);  px(img, 13, 9, GLASS)        # topo
    px(img, 11, 10, GLASS); px(img, 14, 10, GLASS)       # laterais
    px(img, 11, 11, GLASS); px(img, 14, 11, GLASS)
    px(img, 12, 12, GLASS); px(img, 13, 12, GLASS)       # base
    # lente direita — anel ao redor de (18-19,10-11)
    px(img, 18, 9, GLASS);  px(img, 19, 9, GLASS)
    px(img, 17, 10, GLASS); px(img, 20, 10, GLASS)
    px(img, 17, 11, GLASS); px(img, 20, 11, GLASS)
    px(img, 18, 12, GLASS); px(img, 19, 12, GLASS)
    px(img, 15, 10, GLASS); px(img, 16, 10, GLASS)       # ponte
    px(img,  9, 10, GLASS)                               # haste para a orelha

    # ── Sorrisinho suave + blush nas bochechas ────────────────────────────────
    px(img, 15, 14, MOUTH); px(img, 16, 14, MOUTH)
    px(img, 14, 14, SKIN_S); px(img, 17, 14, SKIN_S)     # cantos do sorriso (subindo)
    px(img, 10, 13, BLUSH); px(img, 21, 13, BLUSH)


def draw_neck(img):
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE); vline(img, 18, 17, 19, OUTLINE)


def draw_bangs(img, mana=5, bob=0):
    """Franja sobre a testa (pontas irregulares) emoldurando o rosto. Desenhada
    DEPOIS do rosto p/ cair sobre a testa. Usa a cor de cabelo dependente de mana."""
    b = bob
    # Franja cheia/pesada: três linhas sólidas cobrindo a testa.
    _mhline(img, 10, 21, 4 + b, HAIR, mana)
    _mhline(img, 10, 21, 5 + b, HAIR, mana)
    _mhline(img, 10, 21, 6 + b, HAIR, mana)
    _mhline(img, 11, 16, 4 + b, HAIR_H, mana)            # brilho no topo
    # pontas descendo sobre a testa (deixa os olhos livres em y9+)
    for x in (10, 12, 14, 17, 19, 21):
        px(img, x, 7 + b, hair_c(7 + b, HAIR, mana))
    # mechas mais longas nas laterais (emolduram), centro mais curto
    px(img, 10, 8 + b, hair_c(8 + b, HAIR_D, mana))
    px(img, 11, 8 + b, hair_c(8 + b, HAIR_D, mana))
    px(img, 20, 8 + b, hair_c(8 + b, HAIR_D, mana))
    px(img, 21, 8 + b, hair_c(8 + b, HAIR_D, mana))
    px(img, 13, 7 + b, HAIR_H if mana >= 4 else hair_c(7 + b, HAIR, mana))
    px(img, 15, 6 + b, SKIN); px(img, 16, 6 + b, SKIN)   # repartido leve no meio


def _bell_edges(y, lower_y):
    """Bordas (x0,x1) do sino fechado na altura y. Estreito nos ombros → largo na barra."""
    t = (y - 23) / max(1, (lower_y - 23))
    x0 = int(round(7.0 - t * 2.0))      # alarga p/ a esquerda
    x1 = int(round(24.0 + t * 2.0))     # alarga p/ a direita
    return x0, x1

def draw_cape(img, lower_y=52, hem_sway=0):
    """Manto FECHADO estilo Hollow Knight: sino sólido cobrindo o corpo todo,
    sem abertura frontal, braços/bodysuit escondidos por baixo."""
    hs = hem_sway
    # ── Gola/ombros (trapézio do pescoço aos ombros) ──
    rect(img, 11, 19, 20, 19, CAPE)
    rect(img,  9, 20, 22, 20, CAPE)
    rect(img,  8, 21, 23, 22, CAPE)

    # ── Corpo do manto: sino fechado e sólido ──
    for y in range(23, lower_y + 1):
        x0, x1 = _bell_edges(y, lower_y)
        rect(img, x0, y, x1, y, CAPE)
    # Barra (hem) flarada com leve balanço
    x0b, x1b = _bell_edges(lower_y, lower_y)
    rect(img, x0b + hs, lower_y + 1, x1b + hs, lower_y + 2, CAPE)
    rect(img, x0b + 2 + hs, lower_y + 3, x1b - 2 + hs, lower_y + 3, CAPE_D)

    # ── Costura/forro central (acento roxo, sugere o fecho do manto) ──
    vline(img, 15, 25, lower_y - 3, LINING_D)
    vline(img, 16, 25, lower_y - 3, LINING)
    # ── Rim-light frio na borda esquerda (luz da lua) + sombra de forma à direita ─
    for y in range(23, lower_y + 1):
        x0, x1 = _bell_edges(y, lower_y)
        px(img, x0, y, CAPE_L)
        if y >= 27: px(img, x1, y, CAPE_D)
        if y >= 30: px(img, x1 - 1, y, CAPE_D)

    # ── Broche-gema mágico no peito (acento focal azul + engaste dourado) ──
    px(img, 15, 22, GOLD); px(img, 16, 22, GOLD_D)
    px(img, 15, 23, ORB_D); px(img, 16, 23, ORB)
    px(img, 15, 24, ORB);   px(img, 16, 24, ORB_H)
    px(img, 14, 23, CAPE_GLOW); px(img, 17, 23, CAPE_GLOW)   # glow da gema na capa

    # ── Outline do sino ──
    for y in range(22, lower_y + 1):
        x0, x1 = _bell_edges(y, lower_y)
        px(img, x0 - 1, y, OUTLINE); px(img, x1 + 1, y, OUTLINE)
    hline(img, x0b - 1 + hs, x1b + 1 + hs, lower_y + 3, OUTLINE)
    px(img, x0b - 1 + hs, lower_y + 1, OUTLINE); px(img, x1b + 1 + hs, lower_y + 1, OUTLINE)
    px(img, x0b + hs, lower_y + 3, OUTLINE); px(img, x1b + hs, lower_y + 3, OUTLINE)


def draw_bodysuit(img):
    rect(img, 13, 20, 19, 42, SUIT)
    vline(img, 14, 23, 40, SUIT_H)                       # highlight (lado da luz)
    vline(img, 18, 24, 40, SUIT_SH)                      # sombra de forma (direita)
    hline(img, 13, 19, 20, OUTLINE)
    px(img, 13, 38, SUIT_SH); px(img, 19, 38, SUIT_SH)   # leve cintura
    # Broche-gema mágica no peito (acento focal azul + engaste dourado)
    px(img, 15, 21, GOLD)
    px(img, 15, 22, ORB_D); px(img, 16, 22, ORB)
    px(img, 15, 23, ORB);   px(img, 16, 23, ORB_H)


def draw_belt(img):
    hline(img, 12, 20, 41, GOLD); hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)


def _arm(img, x0, x1, y0, y1):
    rect(img, x0, y0, x1, y1, SUIT)
    vline(img, x0 - 1, y0, y1, OUTLINE); vline(img, x1 + 1, y0, y1, OUTLINE)
    rect(img, x0, y1 + 1, x1, y1 + 3, SKIN)              # mão
    hline(img, x0, x1, y1 + 3, OUTLINE)


def draw_arms(img, mode="down", l_dy=0, r_dy=0, phase=1):
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
    elif mode == "cast":      # magic missile: phase 0 = windup, phase 1 = release
        if phase == 0:                                    # windup: braço dobrado, mão no peito
            rect(img, 19, 21, 22, 25, SUIT)              # antebraço recolhido
            vline(img, 18, 21, 25, OUTLINE); vline(img, 23, 21, 25, OUTLINE)
            rect(img, 21, 19, 24, 21, SKIN)              # mão na altura do peito
            hline(img, 21, 24, 19, OUTLINE)
        else:                                             # release: braço estendido p/ frente
            rect(img, 20, 19, 24, 25, SUIT)
            vline(img, 19, 19, 25, OUTLINE); vline(img, 25, 19, 25, OUTLINE)
            rect(img, 23, 17, 26, 19, SKIN)
            hline(img, 23, 26, 17, OUTLINE)
    elif mode == "slash":     # golpe físico: phase 0 = windup, phase 1 = impacto
        if phase == 0:                                    # windup: braço recuado p/ trás-alto
            rect(img, 13, 17, 16, 23, SUIT)              # antebraço dobrado p/ trás
            vline(img, 12, 17, 23, OUTLINE); vline(img, 17, 17, 23, OUTLINE)
            rect(img, 11, 14, 14, 16, SKIN)              # punho atrás da cabeça
            hline(img, 11, 14, 14, OUTLINE)
        else:                                             # impacto: braço estendido p/ frente-cima
            rect(img, 20, 15, 23, 23, SUIT)
            vline(img, 19, 15, 23, OUTLINE); vline(img, 24, 15, 23, OUTLINE)
            rect(img, 22, 13, 25, 15, SKIN)
            hline(img, 22, 25, 13, OUTLINE)
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
    # Engaste/prongs de madeira segurando o orbe (como no rascunho)
    px(img, 23, 24, STAFF_C); px(img, 24, 25, STAFF_C); px(img, 22, 22, STAFF_C)
    px(img, 30, 24, STAFF_C); px(img, 29, 26, STAFF_C); px(img, 31, 22, STAFF_C)
    # Orbe
    rect(img, 24, 19, 29, 25, orb_c)
    hline(img, 24, 29, 19, OUTLINE); hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE); vline(img, 30, 19, 25, OUTLINE)
    rect(img, 27, 23, 29, 25, ORB_D)                     # sombra (canto inf-dir)
    px(img, 25, 20, orb_h); px(img, 26, 20, orb_h); px(img, 25, 21, orb_h)
    if mana >= 4:
        px(img, 26, 21, WHITE)                           # núcleo brilhante (mana cheia)
    if mana >= 3:                                        # raios/glow de energia
        px(img, 30, 18, orb_h); px(img, 31, 17, orb_c)
        px(img, 30, 26, orb_h); px(img, 23, 26, orb_h)
        px(img, 22, 20, orb_h); px(img, 32, 21, orb_c)


def draw_staff_cast(img, mana=5, phase=1):
    """Cajado EXPOSTO no cast.
    phase=0 windup: cajado vertical perto do peito, orbe carregando (glow tênue).
    phase=1 release: cajado erguido p/ frente, orbe no ponto de spawn do míssil (~y16)."""
    # Cor do orbe degrada com mana (preserva visual original do release)
    orb_c = ORB if mana >= 3 else ((20, 80, 160, 255) if mana == 2 else (12, 40, 90, 255))
    orb_h = (ORB_H if mana >= 4 else (80, 160, 220, 255) if mana == 3 else
             (40, 100, 160, 255) if mana == 2 else (20, 50, 90, 255))
    if phase == 0:
        # Cajado quase vertical, encostado no corpo
        line(img, 22, 26, 24, 18, STAFF_C, hi=STAFF_H)
        line(img, 23, 27, 25, 19, STAFF_C)
        # Orbe carregando junto ao peito (~y19-22)
        rect(img, 22, 17, 26, 21, orb_c)
        hline(img, 22, 26, 17, OUTLINE); hline(img, 22, 26, 21, OUTLINE)
        vline(img, 21, 17, 21, OUTLINE); vline(img, 27, 17, 21, OUTLINE)
        px(img, 23, 18, orb_h); px(img, 24, 18, orb_h)
        if mana >= 4:
            px(img, 25, 19, WHITE)                       # núcleo nascente
        if mana >= 3:
            px(img, 21, 19, orb_h); px(img, 27, 20, orb_h)  # faísca inicial
        return
    # phase 1 — release (visual original)
    line(img, 24, 26, 28, 16, STAFF_C, hi=STAFF_H)       # haste subindo p/ frente
    line(img, 25, 27, 29, 17, STAFF_C)
    rect(img, 26, 12, 30, 16, orb_c)
    hline(img, 26, 30, 12, OUTLINE); hline(img, 26, 30, 16, OUTLINE)
    vline(img, 25, 12, 16, OUTLINE); vline(img, 31, 12, 16, OUTLINE)
    px(img, 27, 13, orb_h); px(img, 28, 13, orb_h)
    if mana >= 4:
        px(img, 28, 14, WHITE)
    if mana >= 3:
        px(img, 31, 11, orb_h); px(img, 25, 11, orb_h)
        px(img, 31, 17, orb_h); px(img, 24, 16, orb_h); px(img, 24, 12, orb_h)


def draw_blade(img, phase=1):
    """Lâmina EXPOSTA no golpe físico.
    phase=0 windup: lâmina recuada por cima do ombro de trás.
    phase=1 impacto: lâmina apontada p/ frente na ALTURA do slash (~y16)."""
    BLADE   = (215, 225, 240, 255)
    BLADE_H = (255, 255, 255, 255)
    BLADE_D = (150, 160, 180, 255)
    if phase == 0:
        # Cabo na mão (~x12,y15) atrás do ombro
        rect(img, 12, 15, 13, 17, BOOT_D)
        hline(img,  9, 14, 14, GOLD)
        px(img,  9, 13, GOLD_D); px(img, 14, 13, GOLD_D)
        # Lâmina p/ trás-cima (ponta ~x2,y6)
        line(img, 11, 12,  5,  6, BLADE, hi=BLADE_H)
        line(img, 12, 13,  6,  7, BLADE_D)
        px(img,  5,  6, BLADE_H); px(img,  6,  7, BLADE_H)
        px(img,  9, 10, BLADE_H)
        return
    # phase 1 — impacto (visual original)
    rect(img, 23, 14, 24, 16, BOOT_D)
    hline(img, 22, 26, 13, GOLD)
    px(img, 22, 13, GOLD_D); px(img, 26, 13, GOLD_D)
    line(img, 25, 12, 31, 8, BLADE, hi=BLADE_H)
    line(img, 26, 13, 31, 9, BLADE_D)
    px(img, 31, 8, BLADE_H); px(img, 30, 9, BLADE_H)
    px(img, 27, 10, BLADE_H)                             # reflexo no fio


def mirror_face(img):
    """Espelha a região do rosto para a personagem olhar para a DIREITA."""
    face = img.crop((10, 4, 23, 17))
    img.paste(face.transpose(Image.FLIP_LEFT_RIGHT), (10, 4))


# ── Montagem de um frame ────────────────────────────────────────────────────--
def compose(mana=5, hair_bob=0, arms="down", l_dy=0, r_dy=0,
            legs=None, boots=None, knee_dy=0, cape_lower=52,
            staff=False, sway=0, hem_sway=0, phase=1) -> Image.Image:
    img = Image.new("RGBA", (W, H), T)
    draw_hair(img, mana=mana, bob=hair_bob, sway=sway)
    draw_face(img, mana=mana)
    draw_bangs(img, mana=mana, bob=hair_bob)
    draw_neck(img)
    draw_legs(img, **(legs or {}), knee_dy=knee_dy)      # pernas por baixo do manto
    draw_cape(img, lower_y=cape_lower, hem_sway=hem_sway) # manto FECHADO cobre o corpo
    # Braços só nas poses de ação (saem POR CIMA do manto); na idle ficam cobertos.
    if arms != "down":
        draw_arms(img, mode=arms, l_dy=l_dy, r_dy=r_dy, phase=phase)
    if arms == "cast":                                   # cajado exposto no cast
        draw_staff_cast(img, mana=mana, phase=phase)
    elif arms == "slash":                                # lâmina exposta no golpe
        draw_blade(img, phase=phase)
    draw_boots(img, **(boots or {}))                     # botas espiam sob a barra
    if staff:
        draw_staff(img, mana=mana)
    mirror_face(img)
    return img
