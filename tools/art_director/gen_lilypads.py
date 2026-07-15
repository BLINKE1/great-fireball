#!/usr/bin/env python3
"""Vitorias-regias (lily pads) pro lago da floresta. PIL puro, reproduzivel.

Elipse foreshortened (vista em angulo raso, mais larga que alta) com a fenda
em V classica, veios radiais, rim de luz na borda de tras e — em algumas — uma
florzinha. Alpha por transparencia. Carregadas cruas pelo level_visuals.
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

DEST = Path(__file__).resolve().parents[2] / "assets/sprites/backgrounds"

PAD = (26, 64, 42)       # verde do topo
PAD_HI = (86, 150, 96)   # rim / veios iluminados
PAD_SH = (12, 34, 26)    # sombra perto da fenda


def make_pad(name: str, w: int, h: int, seed: int, flower: bool) -> None:
    random.seed(seed)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    cx, cy = w * 0.5, h * 0.5
    rx, ry = w * 0.46, h * 0.42
    # corpo da folha
    dr.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=PAD + (255,))
    # sombra interna sutil (da' volume)
    dr.ellipse([cx - rx * 0.6, cy - ry * 0.2, cx + rx * 0.6, cy + ry * 0.95],
               fill=PAD_SH + (90,))
    # veios radiais
    nveins = 9
    for i in range(nveins):
        a = math.pi * (0.15 + 0.7 * i / (nveins - 1))   # leque pra frente/lados
        ex = cx + math.cos(a) * rx * 0.92
        ey = cy + math.sin(a) * ry * 0.92
        dr.line([(cx, cy), (ex, ey)], fill=PAD_HI + (70,), width=1)
    # fenda em V (recorte pra transparencia)
    notch = random.uniform(-0.35, 0.35)
    va = math.pi * 0.5 + notch     # aponta pra baixo-ish
    spread = 0.22
    p1 = (cx + math.cos(va - spread) * rx * 1.1, cy + math.sin(va - spread) * ry * 1.1)
    p2 = (cx + math.cos(va + spread) * rx * 1.1, cy + math.sin(va + spread) * ry * 1.1)
    dr.polygon([(cx, cy - ry * 0.05), p1, p2], fill=(0, 0, 0, 0))
    # rim de luz na borda de TRAS (topo da elipse)
    rim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.arc([cx - rx, cy - ry, cx + rx, cy + ry], start=200, end=340,
           fill=PAD_HI + (200,), width=max(2, int(h * 0.06)))
    rim = rim.filter(ImageFilter.GaussianBlur(1.2))
    img = Image.alpha_composite(img, rim)
    # florzinha
    if flower:
        fx, fy = cx + random.uniform(-rx * 0.2, rx * 0.2), cy - ry * 0.1
        petal = random.choice([(236, 224, 240), (240, 196, 214)])
        for k in range(7):
            pa = math.tau * k / 7
            px, py = fx + math.cos(pa) * w * 0.06, fy + math.sin(pa) * h * 0.10
            dr2 = ImageDraw.Draw(img)
            dr2.ellipse([px - w * 0.035, py - h * 0.05, px + w * 0.035, py + h * 0.05],
                        fill=petal + (255,))
        ImageDraw.Draw(img).ellipse(
            [fx - w * 0.03, fy - h * 0.045, fx + w * 0.03, fy + h * 0.045],
            fill=(244, 214, 96, 255))
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    DEST.mkdir(parents=True, exist_ok=True)
    img.save(DEST / f"{name}.png")
    print(f"  {name}.png {w}x{h} flower={flower}")


def main() -> None:
    print("gerando vitorias-regias:")
    make_pad("lilypad_a", 150, 74, 3, False)
    make_pad("lilypad_b", 128, 66, 8, True)
    make_pad("lilypad_c", 168, 80, 14, False)
    make_pad("lilypad_d", 116, 60, 21, True)
    print("ok")


if __name__ == "__main__":
    main()
