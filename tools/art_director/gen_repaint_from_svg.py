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

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import soph_svg                              # noqa: E402  (meu "lápis" SVG)
from gen_continuous_animation import img2img_edit  # noqa: E402  (POST multipart)

OUT = HERE / "iterations" / "repaint"

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
    OUT.mkdir(parents=True, exist_ok=True)

    # 1) estrutura: renderiza meu SVG (a menos que venha --input)
    if inp is None:
        svg = soph_svg.build_svg()
        inp = str(OUT / "_structure.png")
        cairosvg.svg2png(bytestring=svg.encode(), write_to=inp,
                         output_width=768, output_height=1536)
        print("estrutura (lápis SVG) ->", inp)

    if not token:
        print("sem token: estrutura pronta. rode com --token pra repintar (gasta pollen).")
        return 0

    # 2) repintura via img2img
    out_file = str(OUT / "soph_repaint.png")
    print(f"repintando ({model}) a partir de {inp} ...")
    return img2img_edit(inp, PROMPT, out_file, token, model=model)


if __name__ == "__main__":
    raise SystemExit(main())
