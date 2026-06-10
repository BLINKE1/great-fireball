#!/usr/bin/env python3
"""
pointillize.py — renderiza uma imagem-fonte em PONTILHISMO (estilo Seurat/Signac).

Não "inventa" realismo: lê os pixels da fonte e os reconstrói em milhares de
bolinhas, com mistura óptica de cor (jitter de matiz + pontos complementares) e
densidade maior nas bordas (detalhe). O realismo vem da fonte; o código dá o
estilo. 100% local, sem API.

Uso:
    python tools/art_director/pointillize.py <fonte> <saida.png> [largura] [dots_mil]
"""
from __future__ import annotations
import sys, random, math
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

def main() -> int:
    src = sys.argv[1]
    out = sys.argv[2]
    W   = int(sys.argv[3]) if len(sys.argv) > 3 else 1600
    dots_k = float(sys.argv[4]) if len(sys.argv) > 4 else 130.0

    img = Image.open(src).convert("RGB")
    H = int(W * img.height / img.width)
    img = img.resize((W, H), Image.LANCZOS)
    # leve desfoque p/ amostrar cor "de área" (não pixel cru)
    soft = img.filter(ImageFilter.GaussianBlur(radius=max(1, W // 400)))
    arr = np.asarray(soft, dtype=np.uint8)

    # mapa de bordas p/ densidade de detalhe
    gray = np.asarray(img.convert("L").filter(ImageFilter.FIND_EDGES), dtype=np.float32)
    edge = gray / (gray.max() + 1e-6)

    # cor de fundo = média escurecida (a tela "respira" entre os pontos)
    avg = arr.reshape(-1, 3).mean(0)
    bg = tuple(int(c * 0.45) for c in avg)
    canvas = Image.new("RGB", (W, H), bg)
    draw = ImageDraw.Draw(canvas, "RGBA")

    rng = random.Random(7)

    def jitter_color(r, g, b, hue=0.04, sv=0.14):
        h, s, v = _rgb_hsv(r, g, b)
        h = (h + rng.uniform(-hue, hue)) % 1.0
        s = min(1.0, max(0.0, s + rng.uniform(-sv, sv)))
        v = min(1.0, max(0.0, v + rng.uniform(-sv, sv)))
        return _hsv_rgb(h, s, v)

    base_r = max(2, W // 230)

    # ── Camada 1: base (grade com jitter cobre tudo) ──
    step = max(3, int(base_r * 1.6))
    for gy in range(0, H, step):
        for gx in range(0, W, step):
            x = gx + rng.randint(-step // 2, step // 2)
            y = gy + rng.randint(-step // 2, step // 2)
            if not (0 <= x < W and 0 <= y < H):
                continue
            r, g, b = arr[y, x]
            cr, cg, cb = jitter_color(int(r), int(g), int(b))
            rad = base_r + rng.randint(-1, 2)
            a = rng.randint(170, 230)
            draw.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(cr, cg, cb, a))

    # ── Camada 2: detalhe (mais pontos, menores, onde há borda) ──
    detail = int(dots_k * 1000)
    # amostragem ponderada por borda (achatada p/ não concentrar demais)
    prob = (edge ** 0.7) + 0.02
    prob /= prob.sum()
    flat = prob.ravel()
    idx = np.random.default_rng(7).choice(flat.size, size=detail, p=flat)
    ys, xs = np.divmod(idx, W)
    for x, y in zip(xs.tolist(), ys.tolist()):
        r, g, b = arr[y, x]
        cr, cg, cb = jitter_color(int(r), int(g), int(b), hue=0.05, sv=0.18)
        rad = rng.randint(1, max(2, base_r - 1))
        a = rng.randint(150, 220)
        draw.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(cr, cg, cb, a))
        # ponto complementar ocasional (vibração impressionista)
        if rng.random() < 0.10:
            hr, hg, hb = 255 - cr, 255 - cg, 255 - cb
            draw.ellipse([x, y, x + 1, y + 1], fill=(hr, hg, hb, 90))

    canvas.save(out)
    print(f"✓ pontilhismo salvo: {out} ({W}x{H}, ~{detail//1000}k pontos de detalhe + base)")
    return 0

def _rgb_hsv(r, g, b):
    import colorsys
    return colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)

def _hsv_rgb(h, s, v):
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return int(r * 255), int(g * 255), int(b * 255)

if __name__ == "__main__":
    sys.exit(main())
