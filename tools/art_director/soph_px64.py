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
    import math
    # Cascata ONDULADA pelas costas (lado esquerdo). Duas mechas que serpenteiam
    # (cabelo ondulado da Soph real), afunilando até as pontas roxas.
    top_y, bot_y = 46, 124
    for y in range(top_y, bot_y + 1):
        t = (y - top_y) / (bot_y - top_y)
        # eixo da cascata oscila (ondas longas) e infla na barriga
        cx = 19 + 3.6 * math.sin(t * 3.2 + 0.3) - 2 * t
        half = 9.5 * (1 - 0.42 * t) + 0.7 * math.sin(y * 0.42)
        xl = int(round(cx - half)); xr = int(round(cx + half))
        purple = t > 0.72
        base = HAIR_PU if purple else HAIR
        dk   = HAIR_PUD if purple else HAIR_D
        hi   = HAIR_PU if purple else HAIR_H
        hline(img, xl, xr, y, base)
        # ondulação interna: linhas de mecha clara/escura que serpenteiam
        s1 = xl + 2 + int(round(2 * math.sin(y * 0.55)))
        s2 = xl + int(round(half)) + int(round(2 * math.sin(y * 0.55 + 2)))
        px(img, s1, y, hi)
        px(img, s2, y, dk)
        px(img, xr, y, dk)                         # borda interna (sombra do corpo)
        px(img, xl, y, hi if y % 4 else base)      # leve luz na borda externa
        px(img, xl - 1, y, OUT)                    # contorno
        px(img, xr + 1, y, OUT) if xr + 1 < 22 else None
    # ponta afilada solta
    px(img, 18, bot_y + 1, HAIR_PUD); px(img, 19, bot_y + 1, HAIR_PU)
    px(img, 18, bot_y + 2, OUT)


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
    # gola alta (turtleneck) sob o novo queixo (~x38-42, y56)
    rows(img, [(57, 33, 44), (58, 31, 45), (59, 30, 46)], ROBE)
    hline(img, 30, 46, 60, OUT_S)
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
    # Cabeça ARREDONDADA com 3/4 SUTIL (sem bicos). As pistas de profundidade são
    # suaves: narizinho de 1px no perfil direito, bochecha perto iluminada,
    # plano longe levemente sombreado, queixo macio levemente à direita.
    # ASSIMÉTRICO de verdade: lado PERTO (esquerda) cheio até x21; lado LONGE
    # (direita) RECUA logo após o olho longe + nariz (pouca bochecha além dele).
    spec = [
        (38, 25, 43), (39, 23, 44), (40, 22, 44), (41, 21, 45), (42, 21, 45),
        (43, 21, 45), (44, 21, 44), (45, 21, 44), (46, 21, 45), (47, 21, 45),
        (48, 21, 43), (49, 22, 42), (50, 22, 41), (51, 23, 40), (52, 25, 40),
        (53, 27, 39), (54, 29, 38), (55, 31, 38), (56, 33, 37), (57, 35, 37),
    ]
    for y, xl, xr in spec:
        hline(img, xl, xr, y + hy, SKIN)
    # NARIZ (ponte+ponta) na borda do perfil direito (quebra o contorno)
    px(img, 40, 45 + hy, SKIN_H); px(img, 41, 46 + hy, SKIN_H)      # luz na ponte (lado perto)
    px(img, 43, 46 + hy, SKIN_S); px(img, 44, 47 + hy, SKIN_S)      # sombra da ponte (longe)
    px(img, 43, 48 + hy, SKIN_S)                                    # narina
    # plano LONGE (direita) sombreado na borda que recua
    for y in range(44, 49): px(img, 43, y + hy, SKIN_S)
    # bochecha PERTO (esquerda, cheia) iluminada
    for y in range(43, 50): px(img, 22, y + hy, SKIN_H)
    # sombra SOB o queixo (separa do pescoço)
    hline(img, 31, 38, 57 + hy, SKIN_S); hline(img, 33, 37, 58 + hy, SKIN_S)
    # ORELHA pequena e ARREDONDADA no lado de trás (esquerda) — sem bico
    px(img, 20, 46 + hy, SKIN); px(img, 21, 46 + hy, SKIN); px(img, 20, 47 + hy, SKIN_S)
    px(img, 19, 46 + hy, OUT); px(img, 19, 47 + hy, OUT); px(img, 20, 48 + hy, OUT)
    # contorno do rosto
    for y, xl, xr in spec:
        px(img, xl - 1, y + hy, OUT); px(img, xr + 1, y + hy, OUT)


def draw_face(img, b=0):
    hy = -b
    # OLHOS verdes — afastados (Gemini). Perto (esq) MAIOR; longe (dir) menor,
    # colado na borda do perfil.
    rect(img, 27, 46, 31, 48, EYEW)
    hline(img, 27, 30, 47, IRIS); hline(img, 27, 30, 48, IRIS_L)
    px(img, 28, 47, PUP); px(img, 29, 47, PUP)
    px(img, 27, 46, EYEW)                                           # catchlight
    rect(img, 37, 46, 40, 48, EYEW)
    hline(img, 37, 39, 47, IRIS); px(img, 40, 47, IRIS_L)
    px(img, 38, 47, PUP); px(img, 39, 47, PUP)
    px(img, 37, 46, EYEW)
    # ÓCULOS redondos de aro fino (cantos arredondados, não quadrados)
    # lente perto (maior)
    hline(img, 28, 30, 45, GLASS); hline(img, 28, 30, 49, GLASS)
    px(img, 27, 46, GLASS); px(img, 26, 47, GLASS); px(img, 27, 48, GLASS)
    px(img, 31, 46, GLASS); px(img, 32, 47, GLASS); px(img, 31, 48, GLASS)
    # lente longe (menor)
    hline(img, 37, 39, 45, GLASS); hline(img, 37, 39, 49, GLASS)
    px(img, 36, 47, GLASS); px(img, 40, 46, GLASS); px(img, 41, 47, GLASS); px(img, 40, 48, GLASS)
    px(img, 33, 46, GLASS); px(img, 34, 46, GLASS); px(img, 35, 46, GLASS)   # ponte
    px(img, 25, 47, GLASS); px(img, 24, 47, GLASS)                  # haste → orelha
    # LÁBIOS berry com CURVA p/ a direita (pista da virada)
    px(img, 35, 53, BERRY_D); px(img, 36, 53, BERRY_D); px(img, 37, 53, BERRY_D)
    px(img, 38, 54, BERRY_D)
    px(img, 36, 54, BERRY); px(img, 37, 54, BERRY); px(img, 38, 55, BERRY_H)
    # blush (perto maior)
    px(img, 27, 51, BLUSH); px(img, 28, 51, BLUSH); px(img, 39, 50, BLUSH)


# ── Franja reta (blunt bangs) — hugando o rosto, sem bicos ───────────────────
def draw_bangs(img, b=0):
    hy = -b
    # franja reta cobrindo a testa, base ~y42 (deixa 1px de TESTA antes dos óculos)
    rows(img, [
        (38, 24, 43), (39, 23, 44), (40, 22, 44), (41, 22, 44), (42, 23, 43),
    ], HAIR)
    for a in (24, 30, 36, 42):                                      # base reta com leves pontas
        px(img, a, 42 + hy, HAIR); px(img, a + 1, 42 + hy, HAIR)
    vline(img, 33, 38, 41, HAIR_D); vline(img, 28, 39, 41, HAIR_D)  # mechas discretas
    rows(img, [(38, 26, 31), (39, 24, 28)], HAIR_H)                 # brilho topo
    # cabelo lateral curto hugando o lado PERTO (esquerda), ACIMA da orelha
    for y in range(40, 45):
        px(img, 21, y + hy, HAIR); px(img, 20, y + hy, HAIR_D); px(img, 19, y + hy, OUT)
    # contorno superior da franja (linha reta — blunt)
    rows(img, [(37, 24, 43)], OUT)


# ── Chapéu de mago navy ─────────────────────────────────────────────────────
def draw_hat(img, b=0):
    hy = -b
    # CONE de maga com inclinação (tombando p/ trás-esquerda) + ponta dobrada.
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
