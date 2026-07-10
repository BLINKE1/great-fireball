#!/usr/bin/env python3
"""gen_forest_tree.py — arvore John Avon com ALPHA substituindo a procedural.

Gera no flux (fundo PRETO puro -> key-out limpo; halo residual escuro se mistura
com o backdrop sombrio), recorta por flood-fill (so' a escuridao CONECTADA A
BORDA vira transparente — bolsões escuros dentro do tronco ficam opacos), trim
e resize. Sai como override do SpriteSetup:
  assets/sprites/forest_tree.png

  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_forest_tree.py
  ... --skip-gen   # reusa tools/art_director/iterations/forest_tree/tree_22.jpg
"""
from __future__ import annotations
import os, sys, urllib.request, urllib.parse
from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools" / "art_director" / "iterations" / "forest_tree"
DEST = ROOT / "assets" / "sprites" / "forest_tree.png"
TOKEN = os.environ.get("POLLINATIONS_TOKEN", "")
SEED = 22          # a escolhida (majestosa, sem feature unica que denuncia repeticao)
TARGET_H = 220     # altura final da textura (world: ~264-374px com scale 1.2-1.7)
DARK = 16          # luminancia <= DARK = candidato a fundo

PROMPT = ("single ancient fantasy forest tree, John Avon Magic the Gathering "
          "forest style, tall dark trunk, luminous deep emerald teal canopy with "
          "soft glow, painterly, full tree centered and isolated on solid pure "
          "black background, no ground, no other objects, no text, game asset")


def gen() -> Path:
    out = RAW / f"tree_{SEED}.jpg"
    q = urllib.parse.quote(PROMPT)
    url = (f"https://gen.pollinations.ai/image/{q}?width=768&height=1024"
           f"&model=flux&nologo=true&seed={SEED}")
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {TOKEN}",
        "User-Agent": "great-fireball-art-director",
    })
    out.write_bytes(urllib.request.urlopen(req, timeout=180).read())
    print(f"gen ok -> {out.name}")
    return out


def keyout(im: Image.Image) -> Image.Image:
    """Preto conectado a borda -> transparente (BFS); resto opaco."""
    rgb = im.convert("RGB")
    W, H = rgb.size
    px = rgb.load()
    dark = [[max(px[x, y]) <= DARK for x in range(W)] for y in range(H)]
    outside = [[False] * W for _ in range(H)]
    q: deque = deque()
    for x in range(W):
        for y in (0, H - 1):
            if dark[y][x] and not outside[y][x]:
                outside[y][x] = True; q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if dark[y][x] and not outside[y][x]:
                outside[y][x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < W and 0 <= ny < H and dark[ny][nx] and not outside[ny][nx]:
                outside[ny][nx] = True; q.append((nx, ny))
    alpha = Image.new("L", (W, H), 255)
    apx = alpha.load()
    for y in range(H):
        for x in range(W):
            if outside[y][x]:
                apx[x, y] = 0
    # borda suave: 1px de feather (mata o serrilhado do key)
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
    out = rgb.copy().convert("RGBA")
    out.putalpha(alpha)
    return out


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    src = RAW / f"tree_{SEED}.jpg"
    if "--skip-gen" not in sys.argv or not src.exists():
        gen()
    im = keyout(Image.open(src))
    bb = im.split()[3].getbbox()
    if bb:
        im = im.crop(bb)
    s = TARGET_H / im.height
    im = im.resize((max(1, round(im.width * s)), TARGET_H), Image.LANCZOS)
    im.save(DEST)
    print(f"ok -> {DEST.relative_to(ROOT)} {im.size}")


if __name__ == "__main__":
    main()
