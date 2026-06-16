#!/usr/bin/env python3
"""
gen_soph_svg_sprites.py — pipeline da Soph NOVA (cairosvg cel) -> sprites do jogo.

Renderiza a estrutura SVG determinística (soph_svg) em alta-res sobre fundo
VERDE, faz chroma key e encaixa no canvas do sprite (feet na base). É a versão
"pixel melhorada" (cel-shading) substituindo o design antigo do soph_core.

    python gen_soph_svg_sprites.py            # preview em iterations/svg_sprites/
    python gen_soph_svg_sprites.py --apply    # escreve os overrides em assets/

Hoje só temos o IDLE autorado em SVG (front). walk/run/etc. seguem o pixel
antigo até serem autorados em SVG — ver soph_svg.build_svg_* p/ novas poses.
"""
from __future__ import annotations
import sys
from pathlib import Path

import cairosvg
from PIL import Image

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import soph_svg                               # noqa: E402
from gen_hd_sheet import key_bg_to_alpha      # noqa: E402

ASSETS = HERE.parent.parent / "assets" / "sprites" / "player"
PREV = HERE / "iterations" / "svg_sprites"
GREEN = "#27c24c"
PIXEL_W, PIXEL_H = 32, 64        # canvas do pixel path (soph_idle_0.png ...)


def fit_canvas(im: Image.Image, cw: int, ch: int, pad: int = 1) -> Image.Image:
    """recorta no bbox alfa, escala pra caber em (cw,ch) preservando aspecto,
    cola centralizado em x com os PÉS na base."""
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    scale = min((cw - pad * 2) / im.width, (ch - pad * 2) / im.height)
    nw, nh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    im = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((cw - nw) // 2, ch - nh - pad))
    return canvas


def render_sprite(builder, cw: int, ch: int) -> Image.Image:
    tmp = PREV / "_raw.png"
    PREV.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=builder().encode(), write_to=str(tmp),
                     output_width=660, output_height=1320, background_color=GREEN)
    keyed = key_bg_to_alpha(Image.open(tmp).convert("RGB"), "green")
    return fit_canvas(keyed, cw, ch)


def breathe(im: Image.Image, n: int = 1) -> Image.Image:
    """frame de respiro: desce 1px (idle_1)."""
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.alpha_composite(im, (0, n))
    return out


def main() -> int:
    apply = "--apply" in sys.argv
    PREV.mkdir(parents=True, exist_ok=True)

    idle0 = render_sprite(soph_svg.build_svg, PIXEL_W, PIXEL_H)
    idle1 = breathe(idle0, 1)
    frames = {"soph_idle_0": idle0, "soph_idle_1": idle1}

    for key, img in frames.items():
        img.save(PREV / (key + ".png"))
        img.resize((PIXEL_W * 6, PIXEL_H * 6), Image.NEAREST).save(
            PREV / (key + "_x6.png"))
        if apply:
            img.save(ASSETS / (key + ".png"))
    print(("aplicado em assets/" if apply else "preview em ") + str(PREV))
    print("frames:", list(frames))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
