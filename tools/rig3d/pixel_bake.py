#!/usr/bin/env python3
"""pixel_bake.py — bake DETERMINISTICO de um render 3D texturizado -> sprite 2D.
Zero IA, zero GPU, pose-perfect (e os pixels do render). Estilo Dead Cells.

Modos:
  pixel  -> pixel-art (downscale + paleta). --h altura, --colors paleta.
  hk     -> "redutor HK": posteriza cores + linhas internas (cel) + contorno
            preto externo (inverted-hull 2D). --colors, --grow (espessura).

Uso:
  python tools/rig3d/pixel_bake.py <in.png> <out.png> --mode pixel --h 140 --colors 32
  python tools/rig3d/pixel_bake.py <in.png> <out.png> --mode hk --colors 18 --grow 4
"""
import sys, argparse
from PIL import Image, ImageChops, ImageFilter

INK = (18, 14, 22)

def trim(im):
    bb = im.split()[3].getbbox()
    return im.crop(bb) if bb else im

def pixel_bake(im, target_h, ncolors):
    w, h = im.size
    tw = max(1, int(w * target_h / h))
    small = im.resize((tw, target_h), Image.LANCZOS)
    rgb = small.convert("RGB")
    a = small.split()[3].point(lambda v: 255 if v > 128 else 0)
    q = rgb.quantize(colors=ncolors, method=Image.MEDIANCUT).convert("RGB")
    return Image.merge("RGBA", (*q.split(), a))

def hk_bake(im, ncolors, grow):
    rgb = im.convert("RGB"); a = im.split()[3]
    mask = a.point(lambda v: 255 if v > 128 else 0)
    q = rgb.quantize(colors=ncolors, method=Image.MEDIANCUT).convert("RGB")
    edges = rgb.convert("L").filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 45 else 0)
    edges = ImageChops.multiply(edges, mask)
    cell = q.copy(); cell.paste(INK, mask=edges)
    char = Image.merge("RGBA", (*cell.split(), mask))
    big = mask.filter(ImageFilter.MaxFilter(grow * 2 + 1))
    ring = ImageChops.subtract(big, mask)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(INK + (255,), mask=ring)
    out.alpha_composite(char)
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp"); ap.add_argument("out")
    ap.add_argument("--mode", choices=["pixel", "hk"], default="pixel")
    ap.add_argument("--h", type=int, default=140)
    ap.add_argument("--colors", type=int, default=32)
    ap.add_argument("--grow", type=int, default=4)
    a = ap.parse_args()
    im = trim(Image.open(a.inp).convert("RGBA"))
    out = pixel_bake(im, a.h, a.colors) if a.mode == "pixel" else hk_bake(im, a.colors, a.grow)
    out.save(a.out)
    print("ok ->", a.out, out.size)

if __name__ == "__main__":
    main()
