"""Empacota os frames renderizados (f####.png) numa sprite sheet/strip.

  python tools/rig3d/pack_sheet.py --in tools/rig3d/out/idle --cols 8
    -> tools/rig3d/out/idle_sheet.png  (+ imprime grade p/ o SpriteFrames)

--cols 0  => strip horizontal de 1 linha. Recorta cada frame pelo bbox alfa
comum (mantem registro/alinhamento entre frames).
"""
import sys, os, glob
from PIL import Image

def opt(name, default=None):
    a = sys.argv
    return a[a.index(name) + 1] if name in a else default

def main():
    in_dir = opt("--in", "tools/rig3d/out/idle")
    cols   = int(opt("--cols", "8"))
    in_dir = os.path.abspath(in_dir)
    files = sorted(glob.glob(os.path.join(in_dir, "f*.png")))
    if not files:
        print("ERRO: nenhum f*.png em", in_dir); return
    imgs = [Image.open(f).convert("RGBA") for f in files]
    n = len(imgs)

    # bbox alfa COMUM (uniao) -> recorte uniforme, preserva alinhamento
    union = None
    for im in imgs:
        bb = im.getbbox()
        if bb is None:
            continue
        union = bb if union is None else (
            min(union[0], bb[0]), min(union[1], bb[1]),
            max(union[2], bb[2]), max(union[3], bb[3]))
    if union:
        imgs = [im.crop(union) for im in imgs]
    fw, fh = imgs[0].size

    if cols <= 0:
        cols = n
    rows = (n + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
    for i, im in enumerate(imgs):
        r, c = divmod(i, cols)
        sheet.paste(im, (c * fw, r * fh))

    out = os.path.abspath(os.path.join(in_dir, "..",
          os.path.basename(in_dir) + "_sheet.png"))
    sheet.save(out)
    print("sheet -> %s" % out)
    print("frames=%d  grade=%dx%d  frame=%dx%d" % (n, cols, rows, fw, fh))

main()
