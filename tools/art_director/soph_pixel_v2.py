#!/usr/bin/env python3
"""
soph_pixel_v2.py — Soph pixel-art autoral, mirando a master anchor v2
(robe vermelha FECHADA, chapeu vermelho integro, cabelo azul-mana, oculos
redondos, botas marrom; SEM arma — arma so na acao).

Deterministico => zero drift. Iterado com o "oculos" (render -> ver -> ajustar).
Facing: DIREITA (front-3/4). O jogo espelha por flip_h.

    python soph_pixel_v2.py        # salva idle 64x128 + upscale 6x p/ eyeball
"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H = 64, 128

# ── paleta (casa com a anchor v2) ────────────────────────────────────────────
T        = (0, 0, 0, 0)
OUT      = (28, 14, 34, 255)        # outline
ROBE     = (168, 33, 41, 255)
ROBE_D   = (120, 20, 30, 255)
ROBE_H   = (202, 62, 60, 255)
HAT      = (174, 37, 45, 255)
HAT_D    = (124, 22, 31, 255)
HAT_H    = (206, 68, 66, 255)
HAIR     = (58, 110, 198, 255)
HAIR_D   = (34, 66, 142, 255)
HAIR_ROOT= (28, 40, 92, 255)        # navy na raiz (look "pintado"/mana)
HAIR_H   = (112, 172, 242, 255)
SKIN     = (242, 202, 168, 255)
SKIN_D   = (210, 162, 124, 255)
LENS     = (214, 230, 244, 255)
FRAME    = (32, 24, 42, 255)
EYE      = (40, 30, 64, 255)
BOOT     = (94, 57, 31, 255)
BOOT_D   = (60, 36, 18, 255)
SUIT     = (26, 24, 46, 255)        # bodysuit escuro (gola + vao das pernas)
MOUTH    = (150, 70, 70, 255)
BLUSH    = (236, 170, 160, 255)


def _poly(d, pts, fill):
    d.polygon(pts, fill=fill)


def build_idle() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)

    # ── 1) cabelo de TRAS (massa volumosa dos dois lados) ──
    # esquerda (cauda atras), direita (frente do ombro)
    _poly(d, [(24, 38), (12, 58), (8, 84), (14, 108), (22, 116),
              (27, 96), (24, 70), (28, 50)], HAIR_D)
    _poly(d, [(40, 38), (52, 56), (56, 84), (50, 110), (42, 116),
              (38, 92), (41, 66), (36, 50)], HAIR_D)
    # miolo atras dos ombros
    d.rectangle([26, 48, 38, 74], fill=HAIR_D)
    # gradiente vertical suave (scan por COR, sem emendas retangulares):
    # raiz/topo = HAIR_D, meio = HAIR, pontas = HAIR_H
    px = img.load()
    for x in range(W):
        for y in range(H):
            if px[x, y] == HAIR_D:
                if y >= 104:
                    px[x, y] = HAIR_H
                elif y >= 80:
                    px[x, y] = HAIR

    # ── 2) corpo: robe vermelha FECHADA A-line ──
    _poly(d, [(26, 51), (40, 51), (45, 84), (49, 115),
              (15, 115), (19, 84), (24, 60)], ROBE)
    # mangas sino
    _poly(d, [(25, 55), (17, 84), (25, 90), (29, 62)], ROBE)
    _poly(d, [(39, 55), (47, 84), (39, 90), (35, 62)], ROBE)
    # maos (pele) na ponta das mangas
    d.ellipse([18, 85, 24, 92], fill=SKIN)
    d.ellipse([40, 85, 46, 92], fill=SKIN)
    # sombra de forma no lado direito da robe + costura central
    _poly(d, [(33, 57), (45, 84), (49, 115), (33, 115)], ROBE_D)
    d.line([(33, 58), (33, 113)], fill=ROBE_D)
    # rim-light fria na borda esquerda
    d.line([(20, 70), (17, 100)], fill=ROBE_H)

    # gola: bodysuit escuro
    _poly(d, [(30, 50), (36, 50), (34, 58), (32, 58)], SUIT)
    # vao das pernas (mostra suit + pernas) — barra um pouco mais curta
    _poly(d, [(28, 104), (38, 104), (37, 116), (29, 116)], SUIT)

    # ── 3) botas marrom (duas, ponta p/ a direita) ──
    d.rectangle([24, 116, 31, 126], fill=BOOT)            # pe de tras
    _poly(d, [(32, 116), (44, 116), (45, 126), (32, 126)], BOOT)  # frente c/ ponta
    img.putpixel((30, 119), BOOT_D)                       # vinco entre as botas
    d.rectangle([24, 125, 45, 127], fill=BOOT_D)          # solas

    # ── 4) cabeca + rosto ──
    d.ellipse([26, 33, 43, 53], fill=SKIN)
    # sombra do queixo/lado direito
    _poly(d, [(38, 40), (43, 44), (40, 52), (36, 52)], SKIN_D)
    # blush
    img.putpixel((30, 48), BLUSH); img.putpixel((39, 48), BLUSH)

    # ── 5) cabelo da FRENTE (mechas emoldurando) + raiz navy ──
    _poly(d, [(25, 34), (22, 52), (27, 50), (28, 38)], HAIR_ROOT)   # mecha esq
    _poly(d, [(44, 34), (47, 50), (41, 48), (41, 38)], HAIR_ROOT)   # mecha dir
    # franja sob a aba
    _poly(d, [(27, 35), (42, 35), (40, 40), (34, 38), (29, 40)], HAIR_ROOT)

    # ── 6) oculos redondos + olhos ──
    d.ellipse([27, 40, 33, 46], fill=LENS)
    d.ellipse([36, 40, 42, 46], fill=LENS)
    d.ellipse([27, 40, 33, 46], outline=FRAME)
    d.ellipse([36, 40, 42, 46], outline=FRAME)
    d.line([(33, 42), (36, 42)], fill=FRAME)      # ponte
    img.putpixel((30, 43), EYE); img.putpixel((39, 43), EYE)
    # nariz + boca (sorriso aberto leve)
    img.putpixel((34, 47), SKIN_D)
    d.line([(32, 50), (36, 50)], fill=MOUTH)
    img.putpixel((34, 51), MOUTH)

    # ── 7) chapeu vermelho (cone + aba), por cima ──
    d.ellipse([12, 30, 56, 40], fill=HAT)         # aba larga
    _poly(d, [(28, 4), (47, 33), (22, 33)], HAT)  # cone (tip leve p/ esq)
    d.rectangle([24, 30, 44, 34], fill=HAT_D)     # faixa na base
    # luz/sombra no chapeu (sombra CONTIDA no cone, sem virar 2o pico)
    d.line([(29, 7), (24, 31)], fill=HAT_H)       # rim-light esq do cone
    _poly(d, [(35, 20), (44, 32), (37, 32)], HAT_D)  # sombra dir, baixa
    d.ellipse([12, 30, 56, 40], outline=HAT_D)    # define a aba

    # ── 8) outline externo automatico (1px) ──
    img = _add_outline(img, OUT)
    return img


def _add_outline(img: Image.Image, col) -> Image.Image:
    px = img.load()
    out = img.copy()
    o = out.load()
    for x in range(W):
        for y in range(H):
            if px[x, y][3] <= 40:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                               (1, 1), (1, -1), (-1, 1), (-1, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and px[nx, ny][3] > 40:
                        o[x, y] = col
                        break
    return out


def main():
    out_dir = Path(__file__).parent / "iterations" / "pixel_v2"
    out_dir.mkdir(parents=True, exist_ok=True)
    idle = build_idle()
    idle.save(out_dir / "idle.png")
    idle.resize((W * 6, H * 6), Image.NEAREST).save(out_dir / "idle_x6.png")
    print("salvo", out_dir / "idle.png", idle.size)


if __name__ == "__main__":
    main()
