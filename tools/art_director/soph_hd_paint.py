#!/usr/bin/env python3
"""
soph_hd_paint.py — TESTE: desenhar a Soph em ALTA RESOLUCAO por codigo
(shapes suaves + gradientes + sombreamento) e reduzir estilo Hollow Knight
(pintar grande -> downscale com anti-alias). Deterministico => zero drift.

Mira a master anchor v2 (robe fechada, chapeu integro, cabelo azul-mana,
oculos, botas; sem arma).

    python soph_hd_paint.py   # salva HD + downscale HK + comparativo
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

U = 12                         # supersample: grid 64x128 -> 768x1536
W, H = 64 * U, 128 * U

# ── paleta ───────────────────────────────────────────────────────────────────
OUT      = (26, 12, 32, 255)
ROBE     = (170, 34, 42, 255)
ROBE_D   = (112, 18, 28, 255)
ROBE_H   = (208, 70, 66, 255)
HAT      = (176, 38, 46, 255)
HAT_D    = (118, 20, 30, 255)
HAT_H    = (212, 74, 70, 255)
HAIR_ROOT= (26, 38, 88, 255)
HAIR     = (56, 110, 200, 255)
HAIR_H   = (120, 178, 246, 255)
SKIN     = (244, 206, 172, 255)
SKIN_D   = (212, 165, 126, 255)
LENS     = (216, 232, 246, 255)
FRAME    = (30, 22, 40, 255)
EYE      = (38, 28, 60, 255)
BOOT     = (96, 58, 32, 255)
BOOT_D   = (58, 34, 17, 255)
SUIT     = (28, 26, 50, 255)
SUIT_H   = (50, 46, 78, 255)
MOUTH    = (150, 70, 70, 255)
BLUSH    = (236, 168, 158, 255)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(4))


def vgrad(size, stops):
    """gradiente vertical multi-stop. stops=[(pos0..1, rgba), ...]"""
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    stops = sorted(stops)
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if t <= p1 or i == len(stops) - 2:
                lt = 0 if p1 == p0 else max(0, min(1, (t - p0) / (p1 - p0)))
                d.line([(0, y), (size[0], y)], fill=lerp(c0, c1, lt))
                break
    return g


def catmull(pts, n=16):
    """spline Catmull-Rom -> lista densa de pontos (contorno suave)."""
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t +
                       (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 +
                       (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t +
                       (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 +
                       (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    return out


def fill_grad(img, poly, stops):
    """preenche um poligono com gradiente vertical (via mascara)."""
    ys = [p[1] for p in poly]
    y0, y1 = int(min(ys)), int(max(ys)) + 1
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    g = vgrad(img.size, [(max(0, min(1, (p * (y1 - y0) + y0) / img.size[1])), c)
                         for p, c in stops])
    img.paste(g, (0, 0), mask)


def U_(x, y):
    return (x * U, y * U)


def scale(pts):
    return [U_(x, y) for x, y in pts]


def build_hd() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ── cabelo de tras: massa volumosa com contorno ondulado (Catmull) ──
    left_hair = catmull(scale([(26, 38), (16, 52), (8, 74), (6, 96), (12, 114),
                          (22, 120), (28, 104), (25, 80), (29, 56)]))
    right_hair = catmull(scale([(40, 38), (50, 52), (58, 74), (60, 98), (54, 116),
                          (43, 121), (38, 102), (41, 78), (37, 56)]))
    for poly in (left_hair, right_hair):
        d.polygon(poly, fill=HAIR)
    d.polygon(scale([(26, 48), (40, 48), (40, 76), (26, 76)]), fill=HAIR)
    # gradiente mana: navy raiz -> azul -> pontas claras (scan por cor)
    px = img.load()
    for x in range(W):
        for y in range(H):
            if px[x, y] == HAIR:
                t = y / H
                if t < 0.42:
                    px[x, y] = lerp(HAIR_ROOT, HAIR, (t - 0.30) / 0.12) if t > 0.30 else HAIR_ROOT
                elif t > 0.82:
                    px[x, y] = HAIR_H

    # ── robe vermelha FECHADA (A-line) com gradiente ──
    robe = scale([(26, 51), (40, 51), (45, 84), (50, 116),
                  (14, 116), (19, 84), (24, 60)])
    fill_grad(img, robe, [(0.0, ROBE_H), (0.25, ROBE), (1.0, ROBE_D)])
    # mangas sino
    d.polygon(scale([(25, 55), (16, 86), (25, 92), (29, 62)]), fill=ROBE)
    d.polygon(scale([(39, 55), (48, 86), (39, 92), (35, 62)]), fill=ROBE)
    # maos
    d.ellipse([*U_(17, 85), *U_(24, 93)], fill=SKIN)
    d.ellipse([*U_(40, 85), *U_(47, 93)], fill=SKIN)
    # sombra de forma (lado direito) + costura
    d.polygon(scale([(33, 58), (45, 84), (50, 116), (33, 116)]), fill=ROBE_D)
    d.line([U_(33, 58), U_(33, 114)], fill=ROBE_D, width=U // 2)

    # gola + vao das pernas (suit escuro)
    d.polygon(scale([(30, 50), (37, 50), (35, 59), (32, 59)]), fill=SUIT)
    d.polygon(scale([(28, 104), (38, 104), (37, 116), (29, 116)]), fill=SUIT)

    # ── botas ──
    d.rectangle([*U_(24, 116), *U_(31, 126)], fill=BOOT)
    d.polygon(scale([(32, 116), (45, 116), (46, 126), (32, 126)]), fill=BOOT)
    d.rectangle([*U_(24, 124), *U_(46, 127)], fill=BOOT_D)

    # ── cabeca + rosto ──
    d.ellipse([*U_(26, 33), *U_(43, 53)], fill=SKIN)
    d.polygon(scale([(38, 40), (43, 45), (40, 52), (36, 52)]), fill=SKIN_D)
    d.ellipse([*U_(29, 47), *U_(32, 50)], fill=BLUSH)
    d.ellipse([*U_(38, 47), *U_(41, 50)], fill=BLUSH)

    # mechas da frente (raiz navy emoldurando)
    d.polygon(scale([(25, 34), (21, 54), (27, 50), (28, 38)]), fill=HAIR_ROOT)
    d.polygon(scale([(44, 34), (48, 52), (41, 49), (41, 38)]), fill=HAIR_ROOT)
    d.polygon(scale([(27, 35), (43, 35), (40, 41), (34, 38), (29, 41)]), fill=HAIR_ROOT)

    # ── oculos + olhos + boca ──
    for cx in (30, 39):
        d.ellipse([*U_(cx - 3, 40), *U_(cx + 3, 46)], fill=LENS, outline=FRAME, width=max(1, U // 4))
    d.line([U_(33, 42), U_(36, 42)], fill=FRAME, width=max(1, U // 3))
    d.ellipse([*U_(29, 42), *U_(31, 45)], fill=EYE)
    d.ellipse([*U_(38, 42), *U_(40, 45)], fill=EYE)
    d.line([U_(32, 50), U_(36, 50)], fill=MOUTH, width=max(1, U // 3))

    # ── chapeu (cone + aba) com gradiente ──
    cone = scale([(29, 4), (33, 6), (47, 33), (22, 33)])
    fill_grad(img, cone, [(0.0, HAT_H), (0.5, HAT), (1.0, HAT_D)])
    d.ellipse([*U_(12, 30), *U_(56, 41)], fill=HAT)
    d.ellipse([*U_(12, 30), *U_(56, 41)], outline=HAT_D, width=max(1, U // 3))
    d.rectangle([*U_(24, 30), *U_(44, 34)], fill=HAT_D)
    d.line([U_(30, 8), U_(25, 31)], fill=HAT_H, width=U // 2)        # rim-light
    d.polygon(scale([(36, 18), (45, 32), (38, 32)]), fill=HAT_D)     # sombra dir

    # ── sombreamento suave global (volume): nucleo de sombra a' direita ──
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([*U_(34, 40), *U_(70, 120)], fill=(20, 10, 30, 90))
    shade = shade.filter(ImageFilter.GaussianBlur(U * 1.5))
    sil = img.split()[3].point(lambda a: 255 if a > 40 else 0)
    img.alpha_composite(Image.composite(shade, Image.new("RGBA", (W, H), (0, 0, 0, 0)), sil))

    # ── outline externo (dilatacao da silhueta) ──
    ow = max(1, U // 5)
    dil = sil.filter(ImageFilter.MaxFilter(ow * 2 + 1))
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    base.paste(OUT, mask=dil)
    base.alpha_composite(img)
    return base


def main():
    out = Path(__file__).parent / "iterations" / "hd_paint"
    out.mkdir(parents=True, exist_ok=True)
    hd = build_hd()
    # AA: render SS -> downscale pra "HD limpo"
    clean = hd.resize((W // 2, H // 2), Image.LANCZOS)
    clean.save(out / "soph_hd.png")
    # reduz estilo HK (pequeno) + reupscale nearest p/ eyeball
    hk = hd.resize((96, 192), Image.LANCZOS)
    hk.save(out / "soph_hk.png")
    hk.resize((96 * 4, 192 * 4), Image.NEAREST).save(out / "soph_hk_x4.png")
    print("salvo", out)


if __name__ == "__main__":
    main()
