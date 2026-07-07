#!/usr/bin/env python3
"""bake_player_anim.py — bake dos renders 3D (tools/rig3d/out/player_sheet/<anim>/f*.png,
transparentes, camera FIXA) -> sprites soph_hd_<anim>_<i>.png 100x192.

Registro FIXO (nao usa bbox por-frame): escala S e offset medidos do idle contra
o sprite ja commitado -> mesma escala/ancoragem de pes em TODAS as anims (nao
"pula" ao trocar de animacao). Paleta COMPARTILHADA extraida dos sprites atuais
(soph_hd_run_*) -> zero flicker e identidade travada entre frames/anims.

  python tools/rig3d/bake_player_anim.py walk 31
  python tools/rig3d/bake_player_anim.py walk 31 --dry   # so mede, nao grava
"""
from __future__ import annotations
import sys, glob, argparse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHEET = ROOT / "tools" / "rig3d" / "out" / "player_sheet"
DST = ROOT / "assets" / "sprites" / "player"
CANVAS = (100, 192)
S = 0.863          # canvas-px por render-px (medido: idle render vs sprite)
OFF = (-117, 1)    # onde colar o render escalado no canvas 100x192

def shared_palette() -> Image.Image:
    """Paleta (<=256) unida dos soph_hd atuais -> cores identicas p/ a nova anim."""
    cols: list = []
    seen = set()
    for f in sorted(glob.glob(str(DST / "soph_hd_run_*.png"))) + \
             sorted(glob.glob(str(DST / "soph_hd_idle_*.png"))):
        im = Image.open(f).convert("RGBA")
        for r, g, b, a in im.getdata():
            if a > 128 and (r, g, b) not in seen:
                seen.add((r, g, b)); cols.append((r, g, b))
    cols = cols[:256] or [(0, 0, 0)]
    flat: list = []
    for c in cols:
        flat += list(c)
    flat += flat[:3] * (256 - len(cols))   # pad
    pal = Image.new("P", (1, 1)); pal.putpalette(flat)
    return pal

def bake_frame(render: Image.Image, pal: Image.Image) -> Image.Image:
    sw, sh = render.size
    scaled = render.resize((max(1, round(sw * S)), max(1, round(sh * S))), Image.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.paste(scaled, OFF, scaled)   # paste aceita offset negativo (recorta)
    rgb = canvas.convert("RGB")
    a = canvas.split()[3].point(lambda v: 255 if v > 128 else 0)
    q = rgb.quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    return Image.merge("RGBA", (*q.split(), a))

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("anim"); ap.add_argument("n", type=int)
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--prefix", default=None, help="nome do sprite (default = anim)")
    a = ap.parse_args()
    src = SHEET / a.anim
    files = sorted(glob.glob(str(src / "f*.png")))[: a.n]
    if len(files) < a.n:
        print(f"ERRO: achei {len(files)} frames em {src}, esperava {a.n}"); sys.exit(1)
    pal = shared_palette()
    prefix = a.prefix or a.anim
    for i, f in enumerate(files):
        out = bake_frame(Image.open(f).convert("RGBA"), pal)
        dst = DST / f"soph_hd_{prefix}_{i}.png"
        if a.dry:
            print(f"[dry] {f} -> {dst.name}  bbox={out.split()[3].getbbox()}")
        else:
            out.save(dst); print(f"ok -> {dst.name} {out.size} bbox={out.split()[3].getbbox()}")

if __name__ == "__main__":
    main()
