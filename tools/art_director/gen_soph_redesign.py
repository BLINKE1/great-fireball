#!/usr/bin/env python3
"""
gen_soph_redesign.py — Soph redesenhada conforme rascunho do usuário:
  - Cabelo azul longo fluindo pelas costas
  - Óculos redondos
  - Bodysuit escuro estilo Raven + capa
  - Cajado diagonal com orbe roxo
  - Botas de cano alto
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H  = 32, 64
ZOOM  = 8
HERE  = Path(__file__).parent
DEST  = HERE.parent.parent / "assets" / "sprites" / "player"
PREV  = HERE / "iterations" / "soph_redesign_preview.png"

# ── Paleta ────────────────────────────────────────────────────────────────────
T       = (0,   0,   0,   0)
OUTLINE = (20,  10,  35, 255)
SKIN    = (235, 195, 155, 255)
SKIN_S  = (200, 155, 115, 255)
HAIR    = (65,  125, 220, 255)   # azul médio
HAIR_D  = (35,  80,  175, 255)   # azul escuro (profundidade)
HAIR_H  = (130, 185, 255, 255)   # azul claro (reflexo)
EYE     = (30,  20,  55,  255)
CAPE    = (80,  40,  140, 255)   # capa: roxo médio
CAPE_D  = (45,  20,  85,  255)   # capa: sombra
CAPE_L  = (110, 60,  170, 255)   # capa: luz
SUIT    = (30,  12,  55,  255)   # bodysuit escuro (Raven)
SUIT_H  = (55,  25,  90,  255)   # bodysuit highlight
GOLD    = (210, 165, 30,  255)
GOLD_D  = (155, 115, 10,  255)
BOOT    = (70,  45,  25,  255)   # bota marrom escura
BOOT_D  = (45,  25,  10,  255)
STAFF_C = (95,  65,  35,  255)   # cabo do cajado (madeira escura)
STAFF_H = (145, 105, 55,  255)   # reflexo do cabo
ORB     = (110, 50,  210, 255)   # orbe roxo brilhante
ORB_H   = (190, 140, 255, 255)   # orbe highlight
ORB_D   = (60,  20,  120, 255)   # orbe sombra
GLASS   = (80,  70,  100, 255)   # armação dos óculos


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

def line(img, x0, y0, x1, y1, c, highlight=None):
    """Linha fina com pixel de highlight opcional."""
    dx, dy = abs(x1-x0), abs(y1-y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx - dy
    while True:
        px(img, x0, y0, c)
        if highlight:
            px(img, x0, y0-1, highlight)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 > -dy: err -= dy; x0 += sx
        if e2 <  dx: err += dx; y0 += sy


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)

    # ── Cabelo longo (flui pelas costas = lado esquerdo do sprite) ────────────
    # Massa principal do topo
    rect(img,  7,  0, 21,  2, HAIR)
    rect(img,  6,  1, 22,  4, HAIR)
    # Franja frontal (lado direito = frente da personagem)
    rect(img, 18,  0, 23,  7, HAIR)
    px(img, 24, 2, HAIR); px(img, 24, 3, HAIR)
    # Cauda longa fluindo pelas costas
    rect(img,  4,  2,  9, 10, HAIR)     # início da cauda
    rect(img,  4, 10,  8, 22, HAIR)     # cauda média
    rect(img,  4, 22,  7, 32, HAIR)     # cauda baixa
    rect(img,  4, 32,  6, 40, HAIR_D)   # ponta da cauda (mais escura)
    # Profundidade / camadas de cabelo
    vline(img,  4,  2, 40, HAIR_D)
    vline(img,  5,  2, 35, HAIR_D)
    # Reflexo no topo
    hline(img,  9, 18,  1, HAIR_H)
    # Outline da cabeça do cabelo
    hline(img,  7, 21,  0, OUTLINE)
    px(img,  6,  1, OUTLINE); px(img,  5,  2, OUTLINE)
    px(img,  3,  5, OUTLINE); px(img,  3, 10, OUTLINE)
    px(img,  3, 22, OUTLINE); px(img,  3, 32, OUTLINE)
    px(img, 22,  0, OUTLINE); px(img, 23,  1, OUTLINE)
    px(img, 24,  3, OUTLINE); px(img, 25,  5, OUTLINE)

    # ── Rosto ────────────────────────────────────────────────────────────────
    rect(img, 10,  4, 22, 16, SKIN)
    hline(img, 11, 21,  4, OUTLINE)     # topo
    hline(img, 11, 21, 16, OUTLINE)     # queixo
    vline(img, 10,  5, 15, OUTLINE)     # esq
    vline(img, 22,  5, 15, OUTLINE)     # dir
    px(img, 11,  5, SKIN); px(img, 21,  5, SKIN)
    px(img, 11, 15, SKIN); px(img, 21, 15, SKIN)
    hline(img, 12, 20, 15, SKIN_S)      # sombra queixo
    # Sobrancelhas
    hline(img, 12, 14,  8, OUTLINE)
    hline(img, 17, 19,  8, OUTLINE)

    # ── Óculos (dois quadradinhos com armação) ────────────────────────────────
    # Vidro esquerdo (x=11-14, y=9-13)
    hline(img, 11, 14,  9, GLASS)
    hline(img, 11, 14, 13, GLASS)
    vline(img, 11,  9, 13, GLASS)
    vline(img, 14,  9, 13, GLASS)
    # Vidro direito (x=16-19, y=9-13)
    hline(img, 16, 19,  9, GLASS)
    hline(img, 16, 19, 13, GLASS)
    vline(img, 16,  9, 13, GLASS)
    vline(img, 19,  9, 13, GLASS)
    # Ponte entre os vidros
    px(img, 15, 11, GLASS)
    # Haste direita (vai até a orelha)
    px(img, 20, 10, GLASS); px(img, 21, 10, GLASS)
    # Olhos (atrás dos óculos)
    rect(img, 12, 10, 13, 12, EYE)
    rect(img, 17, 10, 18, 12, EYE)
    px(img, 12, 10, HAIR_H)             # reflexo olho esq
    px(img, 17, 10, HAIR_H)             # reflexo olho dir
    # Sorriso leve (olhando levemente pra baixo como no rascunho)
    px(img, 16, 14, SKIN_S)
    px(img, 17, 14, SKIN_S)

    # ── Pescoço ───────────────────────────────────────────────────────────────
    rect(img, 14, 17, 17, 19, SKIN)
    vline(img, 13, 17, 19, OUTLINE)
    vline(img, 18, 17, 19, OUTLINE)

    # ── Capa (o grande elemento visual — flui pelas costas) ───────────────────
    # Colarinho / ombros
    rect(img,  7, 19, 24, 22, CAPE)
    hline(img,  7, 24, 19, OUTLINE)
    # Asa esquerda da capa (costas — maior, mais dramática)
    rect(img,  4, 22, 13, 56, CAPE)
    rect(img,  4, 22,  6, 56, CAPE_D)   # borda escura (dobra)
    vline(img,  3, 19, 56, OUTLINE)     # outline externo esq
    # Hem diagonal da capa (varre pra trás e pra baixo)
    for i in range(10):
        px(img, 4+i, 56+i//2, OUTLINE)
    # Asa direita da capa (frente — menor, fica na frente do corpo)
    rect(img, 18, 22, 24, 36, CAPE)
    vline(img, 25, 19, 36, OUTLINE)
    hline(img, 18, 25, 36, OUTLINE)

    # ── Bodysuit (escuro, Raven-style, visível entre as asas da capa) ─────────
    rect(img, 13, 20, 19, 42, SUIT)
    # Highlight central
    vline(img, 15, 23, 40, SUIT_H)
    vline(img, 16, 23, 40, SUIT_H)
    # Decote / borda superior
    hline(img, 13, 19, 20, OUTLINE)

    # ── Braço esquerdo (visível saindo da capa, segura o cajado) ─────────────
    rect(img,  8, 22, 11, 36, SUIT)
    vline(img,  7, 22, 36, OUTLINE)
    vline(img, 12, 22, 36, OUTLINE)
    # Mão esq
    rect(img,  8, 37, 11, 39, SKIN)
    hline(img,  8, 11, 39, OUTLINE)

    # ── Braço direito (frente, mão no cajado) ─────────────────────────────────
    rect(img, 20, 22, 23, 36, SUIT)
    vline(img, 24, 22, 36, OUTLINE)
    # Mão dir
    rect(img, 20, 37, 23, 39, SKIN)
    hline(img, 20, 23, 39, OUTLINE)

    # ── Cinturão / faixa decorativa ───────────────────────────────────────────
    hline(img, 12, 20, 41, GOLD)
    hline(img, 12, 20, 42, GOLD_D)
    px(img, 15, 41, GOLD_D); px(img, 16, 41, GOLD_D)  # fivela

    # ── Pernas (visíveis abaixo da capa) ─────────────────────────────────────
    rect(img, 11, 43, 15, 52, SUIT)     # perna esq
    rect(img, 16, 43, 21, 52, SUIT)     # perna dir
    vline(img, 10, 43, 52, OUTLINE)
    vline(img, 22, 43, 52, OUTLINE)

    # ── Botas de cano alto ───────────────────────────────────────────────────
    # Bota esquerda
    rect(img, 10, 50, 15, 63, BOOT)
    hline(img, 10, 15, 50, BOOT_D)      # dobra do cano
    hline(img, 10, 15, 63, OUTLINE)     # sola
    vline(img,  9, 50, 63, OUTLINE)
    vline(img, 16, 50, 63, OUTLINE)
    # Bota direita
    rect(img, 16, 50, 22, 63, BOOT)
    hline(img, 16, 22, 50, BOOT_D)
    hline(img, 16, 22, 63, OUTLINE)
    vline(img, 23, 50, 63, OUTLINE)
    # Divisor entre botas
    vline(img, 15, 50, 63, OUTLINE)

    # ── Cajado diagonal ───────────────────────────────────────────────────────
    # Linha do cabo: de (6,44) até (25,22) — diagonal suave
    line(img,  6, 44, 25, 22, STAFF_C, highlight=STAFF_H)
    # Espessura: segunda linha paralela
    line(img,  6, 45, 25, 23, STAFF_C)

    # Orbe na ponta do cajado (x=24-29, y=19-25)
    rect(img, 24, 19, 29, 25, ORB)
    # Outline do orbe
    hline(img, 24, 29, 19, OUTLINE)
    hline(img, 24, 29, 25, OUTLINE)
    vline(img, 23, 19, 25, OUTLINE)
    vline(img, 30, 19, 25, OUTLINE)
    # Highlight e profundidade do orbe
    px(img, 25, 20, ORB_H); px(img, 26, 20, ORB_H)
    px(img, 25, 21, ORB_H)
    rect(img, 27, 23, 29, 25, ORB_D)   # sombra no canto
    # Raios de energia (pequenos pixels saindo do orbe)
    px(img, 30, 18, ORB_H); px(img, 31, 17, ORB)
    px(img, 30, 26, ORB_H); px(img, 31, 27, ORB_D)
    px(img, 23, 26, ORB_H)

    return img


def main():
    img = generate()

    # Salva sprite
    DEST.mkdir(parents=True, exist_ok=True)
    sprite_path = DEST / "soph_idle_0.png"
    img.save(sprite_path)
    print(f"  Sprite → {sprite_path}")

    # Preview com zoom
    scaled = img.resize((W * ZOOM, H * ZOOM), Image.NEAREST)
    out = Image.new("RGBA", (scaled.width, scaled.height + 20), (20, 20, 30, 255))
    out.paste(scaled, (0, 0))
    ImageDraw.Draw(out).text((4, scaled.height + 4), "Soph redesign — idle_0", fill=(180, 180, 220, 255))
    PREV.parent.mkdir(parents=True, exist_ok=True)
    out.save(PREV)
    print(f"  Preview → {PREV}")


if __name__ == "__main__":
    main()
