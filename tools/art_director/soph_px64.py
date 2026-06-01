#!/usr/bin/env python3
"""
soph_px64.py — Soph em PIXEL ART nativo 64×128 (2× o sprite antigo 32×64).

Pivot: voltamos ao pixel art (estilo da ref TALEGAMES / Foto 4), agora com
resolução suficiente pra carregar as feições reais da Soph:
  - virada à DIREITA (3/4): olho PERTO (tela-esquerda) maior; LONGE menor
  - franja RETA/blunt, olhos VERDES, lábios berry, óculos de aro fino dourado
  - chapéu de mago AZUL/navy com banda dourada
  - cabelo azul longo (pontas roxas) fluindo pelas costas (esquerda)
  - robe escura, silhueta esguia com cintura

Pixel art genuíno: paleta enxuta, contorno 1px, sem anti-alias. Preview em
nearest-neighbor. O jogo usa flip_h por código ao andar p/ a esquerda.
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
W, H = 64, 128

# ── Paleta ──────────────────────────────────────────────────────────────────
T        = (0, 0, 0, 0)
OUT      = (18, 12, 28, 255)
OUT_S    = (30, 22, 44, 255)     # contorno interno mais suave

SKIN     = (236, 196, 158, 255)
SKIN_S   = (198, 150, 116, 255)
SKIN_H   = (252, 224, 192, 255)

HAIR     = (74, 140, 232, 255)
HAIR_D   = (40, 86, 184, 255)
HAIR_DD  = (24, 52, 122, 255)
HAIR_H   = (150, 200, 255, 255)
HAIR_PU  = (104, 78, 162, 255)   # pontas roxas
HAIR_PUD = (70, 52, 118, 255)

HAT      = (40, 42, 82, 255)     # navy
HAT_D    = (24, 26, 54, 255)
HAT_H    = (62, 66, 116, 255)
HAT_RIM  = (84, 110, 170, 255)   # rim frio na borda do chapéu

ROBE     = (32, 30, 56, 255)
ROBE_D   = (18, 16, 36, 255)
ROBE_H   = (52, 50, 86, 255)
ROBE_RIM = (74, 96, 158, 255)    # luar frio na borda esquerda
LINING   = (120, 55, 140, 255)   # forro roxo (acento)
LINING_D = (80, 36, 96, 255)

GOLD     = (214, 176, 72, 255)
GOLD_D   = (150, 112, 34, 255)
GOLD_H   = (255, 228, 150, 255)

EYEW     = (248, 248, 252, 255)
IRIS_D   = (32, 70, 46, 255)     # verde escuro
IRIS     = (70, 124, 74, 255)
IRIS_L   = (142, 196, 116, 255)  # verde claro
PUP      = (16, 12, 26, 255)
GLASS    = (150, 132, 100, 255)  # aro fino dourado/wire

BERRY    = (170, 54, 76, 255)
BERRY_D  = (120, 32, 50, 255)
BERRY_H  = (208, 100, 120, 255)
BLUSH    = (232, 150, 150, 255)

BOOT     = (72, 48, 28, 255)
BOOT_D   = (44, 26, 12, 255)


# ── Primitivas ──────────────────────────────────────────────────────────────
def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((int(x), int(y)), c)

def hline(img, x0, x1, y, c):
    if x1 < x0: x0, x1 = x1, x0
    for x in range(int(x0), int(x1) + 1): px(img, x, y, c)

def vline(img, x, y0, y1, c):
    if y1 < y0: y0, y1 = y1, y0
    for y in range(int(y0), int(y1) + 1): px(img, x, y, c)

def rect(img, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        hline(img, x0, x1, y, c)

def rows(img, spec, c):
    """spec: lista de (y, xl, xr) — preenche cada linha."""
    for y, xl, xr in spec:
        hline(img, xl, xr, y, c)


# ── Cabelo de trás (cascata pela esquerda) ──────────────────────────────────
def draw_back_hair(img, b=0):
    # massa longa fluindo pelas costas (lado esquerdo), ondulada
    spec = [
        (60, 16, 30), (64, 13, 30), (70, 11, 29), (78, 10, 28),
        (88, 10, 27), (98, 11, 26), (108, 13, 26), (116, 16, 27),
        (122, 19, 28),
    ]
    # preenche o corpo da cascata por interpolação simples entre âncoras
    anchors = [(54, 18, 31), (60, 15, 31), (70, 11, 30), (82, 9, 28),
               (94, 10, 27), (106, 12, 26), (116, 16, 27), (124, 20, 28)]
    for i in range(len(anchors) - 1):
        y0, l0, r0 = anchors[i]; y1, l1, r1 = anchors[i + 1]
        for y in range(y0, y1):
            t = (y - y0) / (y1 - y0)
            xl = round(l0 + (l1 - l0) * t); xr = round(r0 + (r1 - r0) * t)
            hline(img, xl, xr, y, HAIR)
            vline(img, xl, y, y, HAIR_D)            # borda interna sombreada
            px(img, xl + 1, y, HAIR_H if y < 92 else HAIR)   # mecha de brilho
    # pontas roxas (baixo da cascata)
    for y in range(104, 125):
        t = (y - 104) / 20
        xl = round(12 + 8 * t); xr = round(26 + 2 * t)
        hline(img, xl, xr, y, HAIR_PU if (y + xl) % 3 else HAIR_PUD)
    # contorno externo
    for y, xl, xr in anchors:
        px(img, xl - 1, y, OUT)


# ── Robe / corpo (coluna esguia com cintura) ────────────────────────────────
def draw_robe(img, b=0):
    sx = b
    # ombros (trapézio) y60-66
    rows(img, [(60, 26, 42), (61, 24, 44), (62, 22, 46), (63, 21, 47)], ROBE)
    # coluna do corpo: estreita na cintura (~y84), alarga embaixo (A-line)
    anchors = [(64, 21, 47), (74, 22, 46), (84, 23, 45), (96, 21, 47),
               (108, 18, 50), (118, 16, 52), (124, 15, 53)]
    for i in range(len(anchors) - 1):
        y0, l0, r0 = anchors[i]; y1, l1, r1 = anchors[i + 1]
        for y in range(y0, y1 + 1):
            t = (y - y0) / (y1 - y0)
            xl = round(l0 + (l1 - l0) * t); xr = round(r0 + (r1 - r0) * t)
            hline(img, xl, xr, y, ROBE)
            vline(img, xr - 1, y, y, ROBE_D)        # sombra de forma (direita)
            px(img, xl + 1, y, ROBE_H if y < 100 else ROBE)  # leve luz (esquerda)
            px(img, xl, y, ROBE_RIM)                # rim luar na borda esquerda
            px(img, xl - 1, y, OUT); px(img, xr + 1, y, OUT)
    # forro roxo na abertura frontal (acento)
    vline(img, 40, 66, 104, LINING); vline(img, 41, 68, 100, LINING_D)
    # broche-gema dourado no colo
    px(img, 33, 66, GOLD); px(img, 34, 66, GOLD_H)
    px(img, 33, 67, GOLD_D); px(img, 34, 67, GOLD)
    # gola alta (turtleneck) sob o queixo
    rows(img, [(58, 30, 40), (59, 29, 41)], ROBE)
    hline(img, 29, 41, 60, OUT_S)
    # bainha embaixo + contorno
    hline(img, 15, 53, 125, OUT)


def draw_boots(img):
    rect(img, 24, 122, 31, 126, BOOT)
    rect(img, 34, 122, 41, 126, BOOT)
    hline(img, 24, 31, 122, BOOT_D); hline(img, 34, 41, 122, BOOT_D)
    hline(img, 24, 41, 127, OUT)


# ── Cabeça + rosto (3/4 à direita) ──────────────────────────────────────────
def draw_head(img, b=0):
    hy = -b
    # crânio/face oval, x22-47, y32-58 (centro x≈34)
    spec = [
        (32, 27, 43), (33, 25, 45), (34, 24, 46), (36, 23, 47),
        (40, 22, 47), (46, 22, 47), (50, 23, 47), (53, 24, 46),
        (55, 26, 45), (57, 28, 43), (58, 31, 41),
    ]
    anchors = spec
    for i in range(len(anchors) - 1):
        y0, l0, r0 = anchors[i]; y1, l1, r1 = anchors[i + 1]
        for y in range(y0, y1):
            t = (y - y0) / (y1 - y0)
            xl = round(l0 + (l1 - l0) * t); xr = round(r0 + (r1 - r0) * t)
            hline(img, xl, xr, y + hy, SKIN)
    # nariz: bump no perfil (borda direita)
    px(img, 47, 47 + hy, SKIN); px(img, 48, 48 + hy, SKIN); px(img, 47, 49 + hy, SKIN_S)
    # sombra de forma (lado direito/afastado) + sob o queixo
    vline(img, 45, 40 + hy, 52 + hy, SKIN_S)
    hline(img, 30, 40, 56 + hy, SKIN_S)
    # orelha (lado de trás = esquerda), parcialmente sob a franja
    px(img, 23, 45 + hy, SKIN); px(img, 23, 46 + hy, SKIN_S)
    # contorno do rosto
    for i in range(len(anchors) - 1):
        y0, l0, r0 = anchors[i]; y1, l1, r1 = anchors[i + 1]
        for y in range(y0, y1):
            t = (y - y0) / (y1 - y0)
            xl = round(l0 + (l1 - l0) * t); xr = round(r0 + (r1 - r0) * t)
            px(img, xl - 1, y + hy, OUT); px(img, xr + 1, y + hy, OUT)


def draw_face(img, b=0):
    hy = -b
    # ── OLHOS verdes (perto-esquerda MAIOR; longe-direita menor) ──
    # near (esquerda): branco x26-32, y43-49
    rect(img, 27, 44, 32, 48, EYEW)
    rect(img, 28, 45, 31, 48, IRIS_D)
    rect(img, 28, 46, 31, 48, IRIS)
    hline(img, 28, 31, 48, IRIS_L)            # verde claro embaixo
    px(img, 29, 46, PUP); px(img, 30, 46, PUP); px(img, 29, 47, PUP); px(img, 30, 47, PUP)
    px(img, 28, 45, EYEW)                     # catchlight
    # far (direita): branco x38-41, y44-48 (menor, comprimido junto ao nariz)
    rect(img, 38, 45, 41, 48, EYEW)
    rect(img, 39, 46, 41, 48, IRIS_D)
    px(img, 39, 47, IRIS); px(img, 40, 47, IRIS_L)
    px(img, 40, 46, PUP)
    # ── ÓCULOS redondos de aro fino dourado ──
    # lente perto (maior)
    rows(img, [(43, 27, 32)], GLASS)          # topo
    rows(img, [(49, 27, 32)], GLASS)          # base
    vline(img, 26, 44, 48, GLASS); vline(img, 33, 44, 48, GLASS)
    # lente longe (menor)
    rows(img, [(44, 38, 41)], GLASS); rows(img, [(49, 38, 41)], GLASS)
    vline(img, 37, 45, 48, GLASS); vline(img, 42, 45, 48, GLASS)
    # ponte + haste p/ a orelha (esquerda)
    hline(img, 34, 36, 46, GLASS)
    px(img, 25, 45, GLASS); px(img, 24, 45, GLASS)
    # ── LÁBIOS berry (sorriso suave, deslocado p/ o lado perto) ──
    hline(img, 33, 39, 52, BERRY_D)
    hline(img, 34, 38, 53, BERRY)
    px(img, 35, 53, BERRY_H); px(img, 36, 53, BERRY_H)
    # ── blush ──
    px(img, 26, 50, BLUSH); px(img, 27, 50, BLUSH)
    px(img, 41, 50, BLUSH)


# ── Franja reta (blunt bangs) + molduras laterais ───────────────────────────
def draw_bangs(img, b=0):
    hy = -b
    # franja cheia cobrindo a testa, base reta logo acima dos olhos (~y42)
    rows(img, [
        (33, 26, 44), (34, 24, 46), (35, 23, 47), (36, 22, 47),
        (37, 22, 47), (38, 22, 47), (39, 22, 47), (40, 22, 47), (41, 22, 47),
    ], [(y, a, c) for (y, a, c) in []] and HAIR or HAIR)
    # base com leves pontas (wisps)
    wisp = [(42, 23, 24), (42, 28, 29), (42, 33, 34), (42, 38, 39), (42, 44, 45)]
    for y, a, c in wisp: hline(img, a, c, y + hy, HAIR)
    # mechas (textura vertical) + sombra
    for x in (25, 29, 33, 37, 41, 45):
        vline(img, x, 33, 41, HAIR_D)
    vline(img, 31, 33, 41, HAIR_DD); vline(img, 39, 34, 41, HAIR_DD)
    # brilho no topo
    hline(img, 28, 42, 34, HAIR_H)
    # mechas laterais emoldurando o rosto (perto: esquerda desce mais)
    vline(img, 22, 36, 52, HAIR); vline(img, 23, 38, 50, HAIR_D)
    px(img, 22, 53, HAIR); px(img, 23, 52, HAIR)
    vline(img, 47, 36, 48, HAIR); vline(img, 46, 38, 46, HAIR_D)   # lado longe (curto)
    # contorno superior da franja
    rows(img, [(32, 26, 44), (33, 24, 25), (33, 45, 46)], OUT)


# ── Chapéu de mago navy ─────────────────────────────────────────────────────
def draw_hat(img, b=0):
    hy = -b
    # CONE com inclinação de bruxa (tombando p/ trás-esquerda) + ponta dobrada.
    # centerline curva: reto subindo e pendendo à esquerda perto do topo.
    base_y, base_cx = 31, 31
    tip_y = 7
    for y in range(tip_y, base_y + 1):
        t = (y - tip_y) / (base_y - tip_y)
        # curva (ease) — perto do topo puxa mais p/ esquerda
        cx = round(base_cx - (base_cx - 22) * (t * t * 0.4 + (1 - t) * 1.0))
        cx = round(base_cx + (22 - base_cx) * (1 - t) ** 1.4)
        half = round(1 + 14 * t)
        xl, xr = cx - half, cx + half
        hline(img, xl, xr, y + hy, HAT)
        px(img, xl, y + hy, HAT_H)                  # luz na borda esquerda
        px(img, xl + 1, y + hy, HAT_H if y % 3 else HAT)
        px(img, xr, y + hy, HAT_D)                  # sombra na borda direita
        px(img, xl - 1, y + hy, OUT); px(img, xr + 1, y + hy, OUT)
    # PONTA DOBRADA flopando p/ esquerda-baixo + pompom dourado
    fold = [(20, 6), (18, 7), (17, 9), (17, 11)]
    for fx, fy in fold:
        px(img, fx, fy + hy, HAT); px(img, fx - 1, fy + hy, OUT)
        px(img, fx + 1, fy + hy, HAT_H)
    px(img, 16, 12 + hy, GOLD); px(img, 16, 13 + hy, GOLD_H)   # pompom
    px(img, 15, 12 + hy, OUT); px(img, 17, 12 + hy, OUT)
    # BANDA dourada na base do cone
    hline(img, 17, 45, 30 + hy, GOLD); hline(img, 17, 45, 31 + hy, GOLD_D)
    px(img, 30, 30 + hy, GOLD_H); px(img, 31, 30 + hy, GOLD_H)
    # estrela/gema simples na banda
    px(img, 30, 29 + hy, GOLD_H); px(img, 31, 29 + hy, GOLD)
    # ABA (brim) elíptica, frente um tico mais baixa
    brim = [
        (32, 13, 49), (33, 11, 52), (34, 10, 53), (35, 10, 53),
        (36, 11, 52), (37, 13, 50), (38, 16, 47),
    ]
    for y, xl, xr in brim:
        hline(img, xl, xr, y + hy, HAT)
    # luz no topo da aba / sombra embaixo
    hline(img, 12, 50, 33 + hy, HAT_H)
    hline(img, 15, 47, 37 + hy, HAT_D)
    px(img, 10, 34 + hy, HAT_RIM); px(img, 11, 33 + hy, HAT_RIM)   # rim frio
    # contorno da aba
    rows(img, [(31, 14, 48)], OUT)
    for y, xl, xr in brim:
        px(img, xl - 1, y + hy, OUT); px(img, xr + 1, y + hy, OUT)
    hline(img, 12, 50, 39 + hy, OUT)


# ── Montagem ────────────────────────────────────────────────────────────────
def compose(breath=0):
    """breath: 0 ou 1 — leve subida da cabeça/chapéu p/ animação de respiração."""
    img = Image.new("RGBA", (W, H), T)
    draw_back_hair(img)
    draw_robe(img, b=0)
    draw_boots(img)
    draw_head(img, b=breath)
    draw_bangs(img, b=breath)
    draw_face(img, b=breath)
    draw_hat(img, b=breath)
    return img


def render_preview(scale=8):
    frames = [compose(0), compose(1)]
    # contact sheet 1× + preview ampliado nearest
    sheet = Image.new("RGBA", (W * 2 + 8, H), (40, 38, 52, 255))
    sheet.alpha_composite(frames[0], (0, 0))
    sheet.alpha_composite(frames[1], (W + 8, 0))
    big = frames[0].resize((W * scale, H * scale), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (40, 38, 52, 255))
    big = Image.alpha_composite(bg, big)
    out = HERE / "iterations"
    out.mkdir(exist_ok=True)
    frames[0].save(out / "soph_px64_idle0.png")
    frames[1].save(out / "soph_px64_idle1.png")
    big.convert("RGB").save(out / "soph_px64_big.png")
    sheet.convert("RGB").save(out / "soph_px64_sheet.png")
    print("soph_px64 → idle0/idle1 + big(%dx) + sheet" % scale)


if __name__ == "__main__":
    render_preview()
