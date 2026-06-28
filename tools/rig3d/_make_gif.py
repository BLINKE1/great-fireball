"""Monta GIF animado a partir de PNGs renderizados pelo Blender.

Uso:
  python tools/rig3d/_make_gif.py <subdir> <gif_basename> [pattern_glob]

Ex.:
  python tools/rig3d/_make_gif.py idle_test soph_idle_cycle
    le tools/rig3d/out/dream_rig/idle_test/idle_full_f*.png
    salva tools/rig3d/out/dream_rig/idle_test/soph_idle_cycle.gif
"""

import sys, os, glob
from PIL import Image

if len(sys.argv) < 3:
    print("uso: python _make_gif.py <subdir> <gif_basename> [pattern]")
    sys.exit(1)

subdir = sys.argv[1]
basename = sys.argv[2]
pattern = sys.argv[3] if len(sys.argv) > 3 else None

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
src = os.path.join(REPO, "tools", "rig3d", "out", "dream_rig", subdir)

if pattern is None:
    # Auto-detect: pega o pattern mais comum (idle_full_f*.png ou walk_full_f*.png)
    candidates = sorted(glob.glob(f"{src}/*full_f*.png"))
    if not candidates:
        candidates = sorted(glob.glob(f"{src}/*f*.png"))
    files = candidates
else:
    files = sorted(glob.glob(f"{src}/{pattern}"))

if not files:
    print(f"ERRO: nenhum PNG achado em {src}")
    sys.exit(1)

print(f"frames: {len(files)}")

imgs = []
for fp in files:
    im = Image.open(fp).convert("RGBA")
    bg = Image.new("RGBA", im.size, (220, 220, 220, 255))
    bg.alpha_composite(im)
    imgs.append(bg.convert("P", palette=Image.ADAPTIVE, colors=128))

out = os.path.join(src, f"{basename}.gif")
imgs[0].save(out, save_all=True, append_images=imgs[1:],
             duration=42, loop=0, disposal=2)
print(f"saved: {out}")
print(f"size: {os.path.getsize(out)/1024:.0f}KB")
