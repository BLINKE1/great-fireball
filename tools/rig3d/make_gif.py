#!/usr/bin/env python3
"""make_gif.py — monta GIF animado LIMPO (sem piscar) a partir de PNGs.

Substitui o _make_gif.py (que gerava GIFs corrompidos/piscando). A receita
anti-flicker:
  - cada frame e composto sobre fundo OPACO (RGB) -> sem transparencia,
  - todos os frames usam a MESMA paleta (shared) -> sem troca de paleta,
  - disposal=1 + optimize=False -> sem frames parciais/diff que fazem o fundo
    piscar entre quadros,
  - clamp de tamanho: frames com dimensao absurda sao ignorados (defende contra
    PNG corrompido).

Uso:
  python tools/rig3d/make_gif.py <frames_dir> <saida.gif> [--glob "*full_f*.png"] [--fps 24] [--bg 220,220,220]

Ex (lado PC, dream rig):
  python tools/rig3d/make_gif.py tools/rig3d/out/dream_rig/idle_pro out/soph_idle_pro.gif --glob "*f*.png" --fps 24
"""
import sys, os, glob, argparse
from PIL import Image

MAXDIM = 4096  # qualquer frame maior que isso = corrompido, ignora


def load_frames(frames_dir, pattern, bg):
    files = sorted(glob.glob(os.path.join(frames_dir, pattern)))
    if not files:
        print(f"ERRO: nenhum PNG em {frames_dir} (glob={pattern})")
        sys.exit(1)
    out, base = [], None
    for fp in files:
        try:
            im = Image.open(fp)
            im.load()
        except Exception as e:
            print(f"  pulei {os.path.basename(fp)} ({type(e).__name__})")
            continue
        if im.size[0] > MAXDIM or im.size[1] > MAXDIM:
            print(f"  pulei {os.path.basename(fp)} tamanho {im.size}")
            continue
        if base is None:
            base = im.size
        if im.size != base:
            im = im.resize(base, Image.LANCZOS)  # uniformiza
        im = im.convert("RGBA")
        canvas = Image.new("RGBA", base, tuple(bg) + (255,))
        canvas.alpha_composite(im)
        out.append(canvas.convert("RGB"))  # OPACO
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("frames_dir")
    ap.add_argument("out")
    ap.add_argument("--glob", default="*f*.png")
    ap.add_argument("--fps", type=float, default=24.0)
    ap.add_argument("--bg", default="220,220,220")
    a = ap.parse_args()
    bg = [int(x) for x in a.bg.split(",")]
    frames = load_frames(a.frames_dir, a.glob, bg)
    if not frames:
        print("ERRO: nenhum frame valido"); sys.exit(1)
    print(f"frames validos: {len(frames)}  size: {frames[0].size}")

    # paleta COMPARTILHADA: tira do primeiro frame e aplica em todos
    pal = frames[0].convert("P", palette=Image.ADAPTIVE, colors=256)
    fr_p = [f.quantize(palette=pal, dither=Image.FLOYDSTEINBERG) for f in frames]

    dur = int(round(1000.0 / a.fps))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    fr_p[0].save(a.out, save_all=True, append_images=fr_p[1:],
                 duration=dur, loop=0, disposal=1, optimize=False)
    print(f"saved: {a.out}  ({os.path.getsize(a.out)/1024:.0f}KB, {len(fr_p)}f @ {a.fps:g}fps)")


if __name__ == "__main__":
    main()
