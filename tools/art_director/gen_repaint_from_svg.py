#!/usr/bin/env python3
"""
gen_repaint_from_svg.py — "ControlNet-lite" no Pollinations.

Eu DESENHO a estrutura em SVG (determinístico, meu "lápis") e mando como imagem
de entrada do img2img (/v1/images/edits) pra a diffusion REPINTAR por cima —
pintura anime que segue minha pose/composição/identidade.

Refino (2026-06-15): fundo VERDE (chroma key limpo, sem halo/slivers), cabelo
maçudo, botas visíveis, olhos abre/fecha (idle + blink). Pós-processa sozinho:
key verde -> normaliza pro canvas = sprite pronto pro jogo.

    python gen_repaint_from_svg.py --pose 34 --eyes open  --token sk_...
    python gen_repaint_from_svg.py --pose 34 --eyes closed --token sk_...
"""
from __future__ import annotations
import os
import sys
from pathlib import Path

import cairosvg
from PIL import Image, ImageFilter

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import soph_svg                                       # noqa: E402
from gen_continuous_animation import img2img_edit     # noqa: E402
from gen_hd_sheet import key_bg_to_alpha              # noqa: E402
from gen_hd_from_idle import normalize_to_canvas      # noqa: E402

OUT = HERE / "iterations" / "repaint"
GREEN = "#27c24c"   # fundo da estrutura (chroma key)


def prompt_for(eyes: str) -> str:
    eye = ("eyes OPEN looking ahead, gentle calm expression" if eyes == "open"
           else "eyes gently closed, serene")
    return (
        "Repaint this exact character as polished detailed hand-painted anime "
        "key art. KEEP the same pose, composition, proportions and identity. "
        "Character: anime mage girl, pointed red wizard hat (FULL intact tip), "
        "round black-framed glasses, THICK VOLUMINOUS long blue hair as one "
        "solid flowing mass with NO gaps between strands (navy roots to bright "
        "blue tips), CLOSED long red robe with soft natural folds, brown boots, "
        f"empty hands no weapon. {eye}. Soft volumetric shading, crisp clean "
        "line art, painterly. FULL BODY from head to feet, the entire feet and "
        "brown boots fully visible at the bottom, zoomed out with empty margin "
        "above the hat and below the feet, do NOT crop the figure. SOLID FLAT "
        "CHROMA KEY GREEN SCREEN BACKGROUND, single character, no text, no shadow."
    )


def _arg(args, name, default=None):
    if name in args:
        i = args.index(name)
        v = args[i + 1]
        del args[i:i + 2]
        return v
    return default


def render_structure(pose: str, path: str) -> str:
    svg = soph_svg.build_svg_34() if pose == "34" else soph_svg.build_svg()
    # figura MENOR centrada com folga verde (head/footroom) p/ o modelo nao
    # cortar os pes ao reenquadrar.
    fig = OUT / "_fig.png"
    cairosvg.svg2png(bytestring=svg.encode(), write_to=str(fig),
                     output_width=560, output_height=1120, background_color=GREEN)
    g = tuple(int(GREEN[i:i + 2], 16) for i in (1, 3, 5))
    canvas = Image.new("RGB", (768, 1536), g)
    f = Image.open(fig).convert("RGB")
    canvas.paste(f, ((768 - 560) // 2, (1536 - 1120) // 2))
    canvas.save(path)
    return path


def postprocess(raw_path: str, out_path: str) -> None:
    """key verde -> erode 1px (mata halo) -> normaliza pro canvas do jogo."""
    keyed = key_bg_to_alpha(Image.open(raw_path).convert("RGB"), "green")
    a = keyed.split()[3].filter(ImageFilter.MinFilter(3))   # erode alpha 1px
    keyed.putalpha(a)
    game = normalize_to_canvas(keyed)
    game.save(out_path)
    game.resize((game.width * 3, game.height * 3), Image.NEAREST).save(
        out_path.replace(".png", "_view.png"))


def main() -> int:
    args = sys.argv[1:]
    token = _arg(args, "--token") or os.environ.get("POLLINATIONS_TOKEN")
    pose = _arg(args, "--pose", "34")
    eyes = _arg(args, "--eyes", "open")
    model = _arg(args, "--model", "gptimage")
    OUT.mkdir(parents=True, exist_ok=True)

    structure = render_structure(pose, str(OUT / f"_struct_{pose}.png"))
    print(f"estrutura {pose} (verde) -> {structure}")
    if not token:
        print("sem token: estrutura pronta. rode com --token pra repintar.")
        return 0

    raw = str(OUT / f"raw_{pose}_{eyes}.png")
    print(f"repintando ({model}, eyes={eyes}) ...")
    if img2img_edit(structure, prompt_for(eyes), raw, token, model=model) != 0:
        return 1
    game = str(OUT / f"idle_{eyes}.png")
    postprocess(raw, game)
    print("sprite pronto ->", game)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
