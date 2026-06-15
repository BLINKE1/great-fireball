#!/usr/bin/env python3
"""
gen_repaint_from_svg.py — "ControlNet-lite" no Pollinations.

Eu DESENHO a estrutura em SVG (cel-shading determinístico, meu "lápis") e mando
ela como imagem de entrada do img2img (/v1/images/edits) pra a diffusion REPINTAR
por cima — pintura anime detalhada que segue a minha pose/composição/identidade.
Não é ControlNet de verdade (sem separação estrutura/cor), mas roda no pollen e
faz "eu desenho -> a IA pinta o meu desenho".

    # só prepara a estrutura (grátis, sem gerar):
    python gen_repaint_from_svg.py
    # repinta de verdade (gasta pollen):
    python gen_repaint_from_svg.py --token sk_...
    # usar outra imagem-estrutura (ex.: um lineart meu):
    python gen_repaint_from_svg.py --input alguma.png --token sk_...
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

import cairosvg
from PIL import Image, ImageFilter

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import soph_svg                              # noqa: E402  (meu "lápis" SVG)
from gen_continuous_animation import img2img_edit  # noqa: E402  (POST multipart)

OUT = HERE / "iterations" / "repaint"


def render_cel(path: str, w: int = 768, h: int = 1536, bg=None) -> str:
    cairosvg.svg2png(bytestring=soph_svg.build_svg().encode(), write_to=path,
                     output_width=w, output_height=h, background_color=bg)
    return path


def render_lineart(path: str, w: int = 768, h: int = 1536) -> str:
    """Traço puro (estrutura) por deteccao de borda do cel — guia melhor o
    img2img que a versao colorida (da' forma sem 'prender' a cor)."""
    tmp = str(OUT / "_cel.png")
    render_cel(tmp, w, h, bg="white")
    edges = Image.open(tmp).convert("RGB").filter(ImageFilter.FIND_EDGES)
    g = edges.convert("L").filter(ImageFilter.MaxFilter(3))
    line = g.point(lambda v: 0 if v > 28 else 255)
    Image.merge("RGB", (line, line, line)).save(path)
    return path

# Prompt de repintura: manter pose/identidade/composição, adicionar polimento.
PROMPT = (
    "Repaint this exact character as polished detailed hand-painted anime key "
    "art. KEEP the same pose, composition, proportions and identity. Character: "
    "anime mage girl, pointed red wizard hat, round black-framed glasses, long "
    "flowing blue hair (navy roots to bright blue tips), CLOSED long red robe, "
    "brown boots, EMPTY HANDS no weapon. Add soft volumetric shading, natural "
    "cloth folds on the robe, voluminous wavy hair with rim light, crisp clean "
    "line art, painterly rendering, sharp. Flat plain background, full body, "
    "single character, no text."
)


def _arg(args, name):
    if name in args:
        i = args.index(name)
        v = args[i + 1]
        del args[i:i + 2]
        return v
    return None


def main() -> int:
    args = sys.argv[1:]
    token = _arg(args, "--token") or os.environ.get("POLLINATIONS_TOKEN")
    inp = _arg(args, "--input")
    model = _arg(args, "--model") or "gptimage"
    lineart = "--lineart" in args
    if lineart:
        args.remove("--lineart")
    OUT.mkdir(parents=True, exist_ok=True)

    # 1) estrutura: lineart puro, cel colorido, ou --input
    tag = "input"
    if inp is None:
        if lineart:
            inp = render_lineart(str(OUT / "_lineart.png")); tag = "lineart"
        else:
            inp = render_cel(str(OUT / "_structure.png"), bg="white"); tag = "cel"
        print(f"estrutura ({tag}) ->", inp)

    if not token:
        print("sem token: estrutura pronta. rode com --token pra repintar (gasta pollen).")
        return 0

    # 2) repintura via img2img
    out_file = str(OUT / f"soph_repaint_{tag}.png")
    print(f"repintando ({model}) a partir de {tag} ...")
    return img2img_edit(inp, PROMPT, out_file, token, model=model)


if __name__ == "__main__":
    raise SystemExit(main())
