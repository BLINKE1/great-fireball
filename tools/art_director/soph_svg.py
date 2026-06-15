#!/usr/bin/env python3
"""
soph_svg.py — Soph desenhada em SVG (Bezier + gradientes + blur), renderizada
por cairosvg. Vetor/cel-shading: curvas de verdade, mechas de cabelo fluidas,
dobras na robe. Deterministico => zero drift. Mira a master anchor v2.

    python soph_svg.py     # gera SVG -> PNG + upscale eyeball
"""
from pathlib import Path
import cairosvg

# paleta (anchor v2)
OUT   = "#1b0f22"
ROBE  = "#a8222b"; ROBE_D = "#761522"; ROBE_H = "#d2433f"
HAT   = "#b0262e"; HAT_D  = "#7a1722"; HAT_H  = "#d6493f"
H_ROOT= "#1b2a5e"; H_MID  = "#3a6ec8"; H_TIP  = "#7cb2f2"
SKIN  = "#f3cfa8"; SKIN_D = "#d4a37c"
LENS  = "#dbe9f6"; FRAME  = "#1f1726"
BOOT  = "#5f3b21"; BOOT_D = "#3a2410"
SUIT  = "#1b1b32"
MOUTH = "#8c4444"; BLUSH = "#ec9a92"


def lock(x0, y0, xt, yt, w, bulge):
    """mecha de cabelo: topo largo (2w em x0,y0) afinando ate a ponta (xt,yt),
    com curvatura lateral 'bulge' (fluidez/vento)."""
    my = (y0 + yt) / 2
    return (f"M{x0-w},{y0} "
            f"C{x0-w-bulge},{my} {xt-3},{yt-14} {xt},{yt} "
            f"C{xt+3},{yt-14} {x0+w-bulge},{my} {x0+w},{y0} Z")


def build_svg() -> str:
    s = []
    s.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 440" width="220" height="440">')
    # ── defs: gradientes + blur ──
    s.append('<defs>')
    s.append(f'<linearGradient id="hair" gradientUnits="userSpaceOnUse" x1="0" y1="120" x2="0" y2="400">'
             f'<stop offset="0" stop-color="{H_ROOT}"/><stop offset="0.45" stop-color="{H_MID}"/>'
             f'<stop offset="1" stop-color="{H_TIP}"/></linearGradient>')
    s.append(f'<linearGradient id="robe" gradientUnits="userSpaceOnUse" x1="60" y1="0" x2="170" y2="0">'
             f'<stop offset="0" stop-color="{ROBE_H}"/><stop offset="0.4" stop-color="{ROBE}"/>'
             f'<stop offset="1" stop-color="{ROBE_D}"/></linearGradient>')
    s.append(f'<linearGradient id="hat" gradientUnits="userSpaceOnUse" x1="70" y1="20" x2="150" y2="120">'
             f'<stop offset="0" stop-color="{HAT_H}"/><stop offset="0.5" stop-color="{HAT}"/>'
             f'<stop offset="1" stop-color="{HAT_D}"/></linearGradient>')
    s.append('<filter id="soft" x="-20%" y="-20%" width="140%" height="140%">'
             '<feGaussianBlur stdDeviation="4"/></filter>')
    s.append('</defs>')

    grp_out = f'stroke="{OUT}" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"'

    # ── sombra de chao ──
    s.append(f'<ellipse cx="110" cy="424" rx="60" ry="9" fill="#000" opacity="0.22" filter="url(#soft)"/>')

    # ── 1) CABELO de tras: leque de mechas fluidas (vento) ──
    s.append(f'<g fill="url(#hair)" {grp_out}>')
    back = [
        lock(86, 140, 40, 250, 18, 26), lock(92, 140, 52, 340, 16, 18),
        lock(100, 138, 78, 392, 15, 6), lock(120, 138, 150, 392, 15, -8),
        lock(128, 140, 168, 338, 16, -20), lock(134, 140, 182, 250, 17, -28),
    ]
    for p in back:
        s.append(f'<path d="{p}"/>')
    s.append('</g>')
    # brilhos de mecha (sem outline)
    s.append(f'<g fill="{H_TIP}" opacity="0.5">')
    for p in [lock(96, 150, 70, 360, 5, 8), lock(124, 150, 158, 360, 5, -8)]:
        s.append(f'<path d="{p}"/>')
    s.append('</g>')

    # ── 2) ROBE fechada A-line + mangas + dobras ──
    s.append(f'<g {grp_out}>')
    s.append('<path fill="url(#robe)" d="M88,150 C84,168 80,178 78,196 '
             'C70,250 58,330 60,392 L160,392 C162,330 150,250 142,196 '
             'C140,178 136,168 132,150 C124,142 96,142 88,150 Z"/>')
    # mangas sino
    s.append(f'<path fill="url(#robe)" d="M86,162 C72,196 64,250 60,300 '
             'C70,306 84,300 88,288 C84,240 86,196 92,170 Z"/>')
    s.append(f'<path fill="url(#robe)" d="M134,162 C148,196 156,250 160,300 '
             'C150,306 136,300 132,288 C136,240 134,196 128,170 Z"/>')
    s.append('</g>')
    # dobras (linhas escuras finas, sem outline grosso)
    s.append(f'<g stroke="{ROBE_D}" stroke-width="2" fill="none" stroke-linecap="round" opacity="0.8">')
    for d in ["M110,176 L110,384", "M96,210 C92,280 90,340 96,380",
              "M126,210 C132,280 134,340 128,380", "M78,210 C74,250 72,280 74,300"]:
        s.append(f'<path d="{d}"/>')
    s.append('</g>')
    # gola (suit) + vao das pernas
    s.append(f'<path fill="{SUIT}" d="M100,150 C104,162 116,162 120,150 '
             'C116,156 104,156 100,150 Z"/>')
    s.append(f'<path fill="{SUIT}" {grp_out} d="M100,360 L120,360 L118,392 L102,392 Z"/>')
    # maos
    s.append(f'<circle cx="70" cy="300" r="9" fill="{SKIN}" {grp_out}/>')
    s.append(f'<circle cx="150" cy="300" r="9" fill="{SKIN}" {grp_out}/>')

    # ── 3) BOTAS ──
    s.append(f'<g {grp_out}>')
    s.append(f'<path fill="{BOOT}" d="M84,388 L102,388 L102,418 L80,418 C80,400 82,392 84,388 Z"/>')
    s.append(f'<path fill="{BOOT}" d="M118,388 L138,388 C142,396 144,408 144,418 L118,418 Z"/>')
    s.append(f'<rect x="78" y="414" width="28" height="8" rx="2" fill="{BOOT_D}"/>')
    s.append(f'<rect x="116" y="414" width="30" height="8" rx="2" fill="{BOOT_D}"/>')
    s.append('</g>')

    # ── 4) CABECA + rosto ──
    s.append(f'<path fill="{SKIN}" {grp_out} d="M86,128 C86,108 134,108 134,128 '
             'C134,156 124,170 110,170 C96,170 86,156 86,128 Z"/>')
    s.append(f'<path fill="{SKIN_D}" opacity="0.6" d="M126,130 C130,140 128,156 118,166 '
             'C126,156 128,140 126,130 Z"/>')
    s.append(f'<circle cx="96" cy="150" r="5" fill="{BLUSH}" opacity="0.7"/>')
    s.append(f'<circle cx="124" cy="150" r="5" fill="{BLUSH}" opacity="0.7"/>')
    # franja + mechas frontais (navy)
    s.append(f'<g fill="{H_ROOT}" {grp_out}>')
    s.append('<path d="M84,126 C82,108 92,98 110,98 C128,98 138,108 136,126 '
             'C130,116 120,112 110,112 C100,112 90,116 84,126 Z"/>')
    s.append('<path d="M84,124 C78,150 80,168 86,180 C90,166 86,148 92,128 Z"/>')
    s.append('<path d="M136,124 C142,150 140,168 134,180 C130,166 134,148 128,128 Z"/>')
    s.append('</g>')
    # oculos redondos + olhos + boca
    s.append(f'<g fill="{LENS}" stroke="{FRAME}" stroke-width="2.4">')
    s.append('<circle cx="99" cy="138" r="9"/><circle cx="121" cy="138" r="9"/>')
    s.append('</g>')
    s.append(f'<path stroke="{FRAME}" stroke-width="2.4" d="M108,138 L112,138"/>')
    s.append(f'<circle cx="100" cy="140" r="3" fill="{FRAME}"/><circle cx="120" cy="140" r="3" fill="{FRAME}"/>')
    s.append(f'<circle cx="101" cy="139" r="1" fill="#fff"/><circle cx="121" cy="139" r="1" fill="#fff"/>')
    s.append(f'<path d="M104,158 C108,162 112,162 116,158" stroke="{MOUTH}" stroke-width="2" fill="none" stroke-linecap="round"/>')

    # ── 5) CHAPEU (cone + aba) ──
    s.append(f'<path fill="url(#hat)" {grp_out} d="M78,120 C84,70 92,40 98,26 '
             'C104,16 116,20 120,34 C128,64 140,96 150,120 C128,112 100,112 78,120 Z"/>')
    s.append(f'<ellipse cx="110" cy="120" rx="80" ry="19" fill="url(#hat)" {grp_out}/>')
    s.append(f'<path fill="url(#hat)" {grp_out} d="M78,120 C84,70 92,40 98,26 '
             'C104,16 116,20 120,34 C128,64 140,96 150,120 C128,112 100,112 78,120 Z"/>')
    s.append(f'<path d="M84,116 C88,116 96,116 110,116 C130,116 142,118 142,118" '
             f'stroke="{HAT_D}" stroke-width="3" fill="none" opacity="0.7"/>')  # faixa
    s.append(f'<path d="M100,30 C96,52 90,90 86,114" stroke="{HAT_H}" stroke-width="3" '
             f'fill="none" stroke-linecap="round" opacity="0.8"/>')  # rim-light

    s.append('</svg>')
    return "\n".join(s)


def main():
    out = Path(__file__).parent / "iterations" / "svg"
    out.mkdir(parents=True, exist_ok=True)
    svg = build_svg()
    (out / "soph.svg").write_text(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=str(out / "soph.png"),
                     output_width=220 * 3, output_height=440 * 3)
    print("salvo", out / "soph.png")


if __name__ == "__main__":
    main()
