#!/usr/bin/env python3
"""finalize_frames.py — downscala os frames renderizados por render_player_sheet.gd
(400x768 -> 100x192, /4) e fecha o loop com crossfade 2D nos ultimos frames de
volta pro frame 0 quando a fonte mocap nao tem ponto de loop natural.

Por que crossfade em vez de achar o "corte perfeito": pra walk (Mixamo
walking.fbx) uma busca automatica de periodo/fase por distancia de imagem
(comparando TODOS os pares de frames da anim inteira, nao so' os que a gente
usa) confirmou que NENHUM par fecha bem -- e' um "anda a partir do parado", o
inicio e' inercia e o fim nunca repete o inicio (a costura antiga em
soph_hd_walk_* nao tinha esse fechamento, so' pegava a janela com a MENOR
diferenca, que ainda era maior que o passo normal -> pop visivel). O crossfade
força fechamento exato (ultimo frame == frame 0, seam dist = 0.0 por
construcao) escondendo a diferenca residual como um "assentar" suave em vez de
um corte. run tem uma janela natural que ja repete sozinha (achada com o mesmo
metodo) -- so' leva um crossfade leve de seguranca.

Uso:
  python tools/rig3d/finalize_frames.py walk 0.1429 0.90 --blend-frac 0.16
  python tools/rig3d/finalize_frames.py run  0.0583 0.1417 --blend-frac 0.10

(rode render_player_sheet.gd -- <which> <n> <t0> <t1> ANTES, pra gerar
tools/rig3d/out/player_sheet/<which>/f*.png; t0/t1 aqui sao so' pra registrar
no nome/print, o script consome os PNGs ja renderizados)
"""
import argparse, glob, os, re
from PIL import Image

SRC = "tools/rig3d/out/player_sheet"
DST = "assets/sprites/player"
TARGET = (100, 192)


def load_seq(which):
    files = sorted(glob.glob(f"{SRC}/{which}/f*.png"),
                    key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0]))
    if not files:
        raise SystemExit(f"nenhum frame em {SRC}/{which}/ -- rode render_player_sheet.gd antes")
    return [Image.open(f).convert("RGBA") for f in files]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("which")
    ap.add_argument("t0", type=float, nargs="?", help="so' informativo (log)")
    ap.add_argument("t1", type=float, nargs="?", help="so' informativo (log)")
    ap.add_argument("--blend-frac", type=float, default=0.16,
                     help="fracao final dos frames que faz crossfade de volta pro frame 0")
    ap.add_argument("--out-prefix", default=None, help="default: soph_hd_<which>")
    args = ap.parse_args()

    prefix = args.out_prefix or f"soph_hd_{args.which}"
    imgs = [im.resize(TARGET, Image.LANCZOS) for im in load_seq(args.which)]
    n = len(imgs)
    blend_n = max(2, round(n * args.blend_frac))
    frame0 = imgs[0]
    out = []
    for i, im in enumerate(imgs):
        if i >= n - blend_n:
            prog = (i - (n - blend_n) + 1) / blend_n
            out.append(Image.blend(im, frame0, prog))
        else:
            out.append(im)
    for i, im in enumerate(out):
        im.save(f"{DST}/{prefix}_{i}.png")
    print(f"{args.which}: n={n} blend_n={blend_n} -> {DST}/{prefix}_0..{n-1}.png")


if __name__ == "__main__":
    main()
