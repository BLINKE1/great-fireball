#!/usr/bin/env python3
"""
compare.py — Banco de auto-avaliação visual pro sprite da Soph (soph_px64).

Gera uma folha de diagnóstico com truques que expõem erros que o olho
acostumado não pega:
  • FLIP horizontal (vira a tela — deformação salta aos olhos)
  • SILHUETA (alpha) — testa se a pose/forma lê sem cor
  • HEAD crop normal + flipado lado a lado
  • grade de pixels (checa alinhamento)
Opcional: empilha snapshots de versões anteriores salvos em iterations/snaps/.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import soph_px64 as S

HERE = Path(__file__).parent
OUT = HERE / "iterations"
SNAPS = OUT / "snaps"


def _label(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, len(text) * 6 + 6, 12), fill=(0, 0, 0, 220))
    d.text((3, 2), text, fill=(255, 255, 255, 255))
    return img


def _sil(frame):
    sil = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    fp = frame.load(); sp = sil.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if fp[x, y][3] > 40:
                sp[x, y] = (240, 240, 255, 255)
    return sil


def _grid(img, step=8):
    d = ImageDraw.Draw(img)
    for x in range(0, img.width, step):
        d.line([(x, 0), (x, img.height)], fill=(255, 255, 255, 24))
    for y in range(0, img.height, step):
        d.line([(0, y), (img.width, y)], fill=(255, 255, 255, 24))
    return img


def build():
    f0 = S.compose(0)
    sc = 6
    bg = (34, 32, 46, 255)

    def up(im, s=sc, nearest=True):
        return im.resize((im.width * s, im.height * s),
                         Image.NEAREST if nearest else Image.LANCZOS)

    orig = up(f0)
    flip = up(f0.transpose(Image.FLIP_LEFT_RIGHT))
    sil = up(_sil(f0))
    for im, t in ((orig, "ORIGINAL"), (flip, "FLIP-H (teste de deformacao)"), (sil, "SILHUETA")):
        base = Image.new("RGBA", im.size, bg); base.alpha_composite(im)
        im.paste(base, (0, 0)); _label(im, t)

    # cabeça: normal vs flip, ampliado, com grade
    hc_box = (10, 28, 56, 62)
    hc = f0.crop(hc_box)
    hsc = 9
    hcn = hc.resize((hc.width * hsc, hc.height * hsc), Image.NEAREST)
    hcf = hc.transpose(Image.FLIP_LEFT_RIGHT).resize((hc.width * hsc, hc.height * hsc), Image.NEAREST)
    for im, t in ((hcn, "ROSTO"), (hcf, "ROSTO FLIP")):
        base = Image.new("RGBA", im.size, bg); base.alpha_composite(im)
        im.paste(base, (0, 0)); _grid(im, hsc); _label(im, t)

    # snapshots anteriores (se houver)
    snap_ims = []
    if SNAPS.exists():
        for p in sorted(SNAPS.glob("*.png")):
            s = Image.open(p).convert("RGBA")
            s = s.resize((s.width * 5, s.height * 5), Image.NEAREST)
            b = Image.new("RGBA", s.size, bg); b.alpha_composite(s); s.paste(b, (0, 0))
            _label(s, p.stem)
            snap_ims.append(s)

    pad = 10
    row1 = [orig, flip, sil]
    row2 = [hcn, hcf]
    w1 = sum(i.width for i in row1) + pad * (len(row1) + 1)
    h1 = max(i.height for i in row1)
    w2 = sum(i.width for i in row2) + pad * (len(row2) + 1)
    h2 = max(i.height for i in row2)
    wsn = (sum(i.width for i in snap_ims) + pad * (len(snap_ims) + 1)) if snap_ims else 0
    hsn = max((i.height for i in snap_ims), default=0)
    W = max(w1, w2, wsn)
    Htot = h1 + h2 + hsn + pad * 4

    sheet = Image.new("RGBA", (W, Htot), (22, 20, 32, 255))
    y = pad
    for row, hh in ((row1, h1), (row2, h2), (snap_ims, hsn)):
        if not row:
            continue
        x = pad
        for im in row:
            sheet.alpha_composite(im, (x, y + (hh - im.height) // 2))
            x += im.width + pad
        y += hh + pad

    sheet.convert("RGB").save(OUT / "soph_px64_compare.png")
    print("compare → iterations/soph_px64_compare.png  (snaps:%d)" % len(snap_ims))


def snapshot(name):
    """Salva o estado atual como snapshot versionado p/ comparar depois."""
    SNAPS.mkdir(parents=True, exist_ok=True)
    S.compose(0).save(SNAPS / f"{name}.png")
    print("snapshot:", name)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "snap":
        snapshot(sys.argv[2] if len(sys.argv) > 2 else "snap")
    else:
        build()
