#!/usr/bin/env python3
"""Folhagem de PRIMEIRO PLANO (perto da camera) pra floresta — estilo Ori/HK.

Por que procedural (PIL puro, sem numpy/Pollinations): a conta de geracao vive
caindo e isto precisa ser reproduzivel. Cada clump sai como silhueta teal quase
preta (massa fora de foco) com um RIM de musgo no contorno de cima (pega a luz,
casa com a paleta Greenpath) e ALPHA por transparencia. O BLUR e' de proposito:
objeto colado na lente le como desfocado -> o cerebro cravava "perto da minha
cara". Da ultima vez o foreground era nitido, chapado e lento -> parecia moldura.

Uso:
    python3 tools/art_director/gen_forest_foreground.py
Gera assets/sprites/backgrounds/fg_*.png (carregados crus pelo level_visuals,
sem precisar reimport).
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

DEST = Path(__file__).resolve().parents[2] / "assets/sprites/backgrounds"

BODY = (9, 21, 18)      # teal quase preto (massa da folhagem)
RIM  = (96, 194, 128)   # musgo do rim (topo iluminado) — pega a luz do alto


def _stamp(dr: ImageDraw.ImageDraw, x: float, y: float, r: float) -> None:
    dr.ellipse([x - r, y - r, x + r, y + r], fill=255)


def _blade(dr: ImageDraw.ImageDraw, x: float, y0: float, h: float,
           bend: float, base_w: float) -> None:
    """Lamina de capim/frond: poligono afinando da base ao topo, com curva."""
    pts_l, pts_r = [], []
    steps = 10
    for i in range(steps + 1):
        t = i / steps
        yy = y0 - h * t
        xx = x + bend * (t * t)              # curva acelera pro topo
        w = base_w * (1.0 - t) + 0.6         # afina
        pts_l.append((xx - w, yy))
        pts_r.append((xx + w, yy))
    dr.polygon(pts_l + pts_r[::-1], fill=255)


def _bush_mask(w: int, h: int) -> Image.Image:
    m = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(m)
    cx = w * 0.5
    base_y = h + 8
    dome_top = h * 0.30
    dome_w = w * 0.46
    # corpo: massa de folhas empilhadas numa cupula com borda irregular
    for _ in range(340):
        a = random.uniform(-math.pi, 0.0)            # metade de cima
        rr = random.uniform(0.0, 1.0) ** 0.5
        ex = cx + math.cos(a) * dome_w * rr
        ey = base_y - (base_y - dome_top) * (abs(math.sin(a)) * rr) - random.uniform(0, 30)
        _stamp(dr, ex, ey, random.uniform(10, 30))
    # preenche a base solida
    dr.rectangle([cx - dome_w, h * 0.62, cx + dome_w, base_y], fill=255)
    # sprigs: hastes com tufo no topo quebram a silhueta
    for _ in range(random.randint(7, 11)):
        sx = cx + random.uniform(-dome_w * 0.9, dome_w * 0.9)
        sh = random.uniform(h * 0.18, h * 0.42)
        top = dome_top - random.uniform(0, h * 0.12)
        _blade(dr, sx, h * 0.5, sh, random.uniform(-14, 14), 2.2)
        for _ in range(random.randint(3, 6)):
            _stamp(dr, sx + random.uniform(-16, 16), top + random.uniform(-6, 22),
                   random.uniform(6, 13))
    return m


def _fern_mask(w: int, h: int) -> Image.Image:
    m = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(m)
    cx = w * 0.5
    base = h + 6
    for _ in range(random.randint(9, 13)):
        ang = random.uniform(-1.15, 1.15)            # leque
        fh = random.uniform(h * 0.55, h * 0.95)
        bend = math.sin(ang) * fh * 0.55
        _blade(dr, cx + math.sin(ang) * 12, base, fh, bend, 3.0)
        # foliolos: pequenas folhas ao longo da frond
        steps = 7
        for i in range(1, steps):
            t = i / steps
            yy = base - fh * t
            xx = cx + math.sin(ang) * 12 + bend * (t * t)
            lr = (1.0 - t) * 8 + 3
            _stamp(dr, xx - lr, yy, lr * 0.8)
            _stamp(dr, xx + lr, yy, lr * 0.8)
    dr.ellipse([cx - w * 0.18, base - h * 0.10, cx + w * 0.18, base + 20], fill=255)
    return m


def _grass_mask(w: int, h: int) -> Image.Image:
    m = Image.new("L", (w, h), 0)
    dr = ImageDraw.Draw(m)
    base = h + 6
    n = random.randint(34, 48)
    for _ in range(n):
        x = random.uniform(w * 0.08, w * 0.92)
        bh = random.uniform(h * 0.4, h * 0.98)
        _blade(dr, x, base, bh, random.uniform(-w * 0.06, w * 0.06), random.uniform(3, 6))
    dr.rectangle([w * 0.05, h * 0.82, w * 0.95, base], fill=255)
    return m


def _compose(mask: Image.Image, blur: float, seed: int) -> Image.Image:
    """mask (L) -> RGBA: corpo escuro + rim de musgo no topo, fora de foco."""
    w, h = mask.size
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))   # organiza a silhueta
    mask = mask.point(lambda v: 255 if v > 90 else 0)   # re-binariza (bordas limpas)
    # rim: contorno de CIMA = mask menos a mask empurrada pra baixo (banda mais
    # grossa = rim mais presente sob o blur final)
    inner = ImageChops.offset(mask, 0, 10)
    inner = ImageChops.darker(inner, mask)              # so' dentro da silhueta
    rim = ImageChops.subtract(mask, inner)
    rim = rim.filter(ImageFilter.GaussianBlur(1.2))
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = Image.new("RGBA", (w, h), BODY + (255,))
    out.paste(body, (0, 0), mask)
    rimimg = Image.new("RGBA", (w, h), RIM + (255,))
    # rim mais forte no alto, some pra baixo
    grad = Image.new("L", (w, h), 0)
    gd = ImageDraw.Draw(grad)
    for y in range(h):
        gd.line([(0, y), (w, y)], fill=int(255 * max(0.0, 1.0 - y / (h * 0.6))))
    rim = ImageChops.multiply(rim, grad)
    out.paste(rimimg, (0, 0), rim)
    # FORA DE FOCO: o blur que vende "perto da lente"
    out = out.filter(ImageFilter.GaussianBlur(blur))
    # fade da BASE: some a borda chapada do clump (agora ha' agua/lago atras,
    # a base reta denunciava). Dissolve o ultimo ~22% da altura.
    alpha = out.getchannel("A")
    grad = Image.new("L", (w, h), 255)
    gd = ImageDraw.Draw(grad)
    fade = max(1, int(h * 0.32))
    for i in range(fade):
        gd.line([(0, h - 1 - i), (w, h - 1 - i)], fill=int(255 * (i / float(fade))))
    out.putalpha(ImageChops.multiply(alpha, grad))
    return out


def make(name: str, kind: str, w: int, h: int, blur: float, seed: int) -> None:
    random.seed(seed)
    if kind == "bush":
        mask = _bush_mask(w, h)
    elif kind == "fern":
        mask = _fern_mask(w, h)
    else:
        mask = _grass_mask(w, h)
    img = _compose(mask, blur, seed)
    DEST.mkdir(parents=True, exist_ok=True)
    img.save(DEST / f"{name}.png")
    print(f"  {name}.png  {w}x{h} ({kind}, blur {blur})")


def main() -> None:
    print("gerando foreground perto-da-camera:")
    # NEAR (camada rapida ~2.1x): grandes, bem borrados
    make("fg_bush_a",  "bush", 560, 320, 5.0, 11)
    make("fg_bush_b",  "bush", 620, 300, 5.5, 27)
    make("fg_fern_a",  "fern", 380, 360, 4.0, 33)
    make("fg_fern_b",  "fern", 340, 320, 4.5, 41)
    make("fg_grass_a", "grass", 320, 240, 3.5, 52)
    make("fg_grass_b", "grass", 360, 200, 3.5, 63)
    print("ok")


if __name__ == "__main__":
    main()
