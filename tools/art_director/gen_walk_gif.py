#!/usr/bin/env python3
"""gen_walk_gif.py — gera GIF de ciclo de walk da Soph lateral, 100% SVG
(zero Pollen). Usa soph_svg.build_svg_side variando posicao de pes + mao
em 4 fases. Body bob aplicado em PIL (translacao vertical no compose).

Renderizador: prefere cairosvg (qualidade alta, gradientes + filtros).
Fallback: svglib+reportlab (pure-python, sem deps C — gradientes OK,
filtros como blur sao ignorados, mas o gif continua legivel).

    python gen_walk_gif.py
"""
from pathlib import Path
import io
import re
import tempfile
from PIL import Image
from soph_svg import build_svg_side


def strip_unsupported_svg(svg: str) -> str:
    """svglib nao parseia bem <filter>/feGaussianBlur. Remove o filter def
    e o atributo filter=... das tags que usam. A sombra de chao some, mas
    o resto do desenho fica intacto."""
    svg = re.sub(r"<filter[^>]*>.*?</filter>", "", svg, flags=re.DOTALL)
    svg = re.sub(r'\s+filter="[^"]*"', "", svg)
    return svg

try:
    import cairosvg
    _BACKEND = "cairosvg"
except (ImportError, OSError):
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
    _BACKEND = "svglib"


def svg_to_png_bytes(svg: str, w: int, h: int) -> bytes:
    if _BACKEND == "cairosvg":
        return cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h)
    # svglib: precisa de arquivo, nao respeita width/height de override direto;
    # entao escrevemos um tmp e re-escalamos via PIL depois.
    svg = strip_unsupported_svg(svg)
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False, encoding="utf-8") as f:
        f.write(svg)
        tmp = f.name
    drawing = svg2rlg(tmp)
    Path(tmp).unlink(missing_ok=True)
    return renderPM.drawToString(drawing, fmt="PNG")

OUT = Path(__file__).parent / "iterations" / "svg"
OUT.mkdir(parents=True, exist_ok=True)

# 4 fases (walk to the right): contact -> passing -> contact mirror -> passing mirror
# ff = (dx, dy) pe da frente; fb = (dx, dy) pe de tras; hand_dx = balanco do braco
PHASES = [
    dict(foot_front=(10, 0),  foot_back=(-10, 0),  hand_dx=-6, bob=0),   # contact R
    dict(foot_front=(2, 0),   foot_back=(2, -14),  hand_dx=2,  bob=3),   # passing (back lifts)
    dict(foot_front=(-10, 0), foot_back=(10, 0),   hand_dx=6,  bob=0),   # contact L
    dict(foot_front=(2, -14), foot_back=(-2, 0),   hand_dx=-2, bob=3),   # passing mirror (front lifts)
]

SCALE = 2  # upscale do PNG p/ ficar mais nitido no GIF


def render_phase(p) -> Image.Image:
    svg = build_svg_side(
        foot_front=p["foot_front"],
        foot_back=p["foot_back"],
        hand_dx=p["hand_dx"],
    )
    png_bytes = svg_to_png_bytes(svg, 220 * SCALE, 440 * SCALE)
    img = Image.open(io.BytesIO(png_bytes)).convert("RGBA")
    # svglib renderiza na res nativa; upscale via PIL p/ casar SCALE
    target = (220 * SCALE, 440 * SCALE)
    if img.size != target:
        img = img.resize(target, Image.LANCZOS)

    # body bob: desloca tudo verticalmente (positivo = desce no passing)
    bob_px = p["bob"] * SCALE
    bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    bg.paste(img, (0, bob_px), img)
    return bg


def main():
    frames = [render_phase(p).convert("P", palette=Image.ADAPTIVE) for p in PHASES]
    out = OUT / "walk_cycle.gif"
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=140,
        loop=0,
        disposal=2,
        optimize=False,
    )
    print(f"salvo {out} ({len(frames)} frames, {SCALE}x, backend={_BACKEND})")


if __name__ == "__main__":
    main()
