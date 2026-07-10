#!/usr/bin/env python3
"""gen_forest_ground.py — tileset pintado (estilo John Avon/MTG) pro chao da
floresta, substituindo os tiles procedurais via override do SpriteSetup.

Pipeline: Pollinations flux gera 2 texturas (grama/musgo luminoso + terra com
raizes) -> seamless por offset+blend -> downscale+quantize (pixel-bake) ->
compoe os tiles na MESMA estrutura dos procedurais (faixa de grama no topo,
sombra, terra embaixo, laminas pendendo):
  assets/tilesets/grass_floor.png     32x32
  assets/tilesets/grass_platform.png  32x16
  assets/tilesets/moss_wall.png       32x32 (parede musgada)

⚠️ tile TEM que ser 32px: a grade ancora no centro do sprite (region_rect em
level_visuals._visit), e 32 e' o divisor que alinha a grama com o topo do chao.

  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_forest_ground.py
  ... --skip-gen   # reusa os brutos ja baixados (so' recompoe os tiles)
"""
from __future__ import annotations
import os, sys, urllib.request, urllib.parse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools" / "art_director" / "iterations" / "forest_ground"
DEST = ROOT / "assets" / "tilesets"

TOKEN = os.environ.get("POLLINATIONS_TOKEN", "")

PROMPTS = {
    # topo do chao: grama/musgo esmeralda luminoso, o "verde Avon"
    "grass": ("seamless texture of lush luminous emerald moss and short grass, "
              "top-down view, Magic the Gathering John Avon forest style, deep "
              "green with teal glow, painterly, soft god-ray light, no objects, "
              "no text, uniform density", 4207),
    # corpo do chao: terra escura com raizes e pedrinhas
    "dirt": ("seamless texture of dark forest soil with thin roots and small "
             "stones, earthy brown umber with deep green moss patches, John Avon "
             "Magic the Gathering style, painterly, top-down, no objects, no text",
             918),
    # parede: rocha musgada
    "rock": ("seamless texture of mossy dark rock wall, cracks with glowing "
             "green moss, John Avon Magic the Gathering forest style, painterly, "
             "no objects, no text", 3311),
}


def gen(name: str, prompt: str, seedv: int) -> Path:
    out = RAW / f"{name}.jpg"
    q = urllib.parse.quote(prompt)
    url = (f"https://gen.pollinations.ai/image/{q}?width=512&height=512"
           f"&model=flux&nologo=true&seed={seedv}")
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {TOKEN}",
        "User-Agent": "great-fireball-art-director",   # proxy barra o UA default do urllib
    })
    data = urllib.request.urlopen(req, timeout=180).read()
    out.write_bytes(data)
    print(f"gen ok -> {out.name} ({len(data)//1024}KB)")
    return out


def make_seamless(im: Image.Image) -> Image.Image:
    """Offset de meia imagem + blend em cruz nas emendas -> tileable nos 2 eixos."""
    w, h = im.size
    off = Image.new("RGB", (w, h))
    off.paste(im.crop((w // 2, h // 2, w, h)), (0, 0))
    off.paste(im.crop((0, h // 2, w // 2, h)), (w // 2, 0))
    off.paste(im.crop((w // 2, 0, w, h // 2)), (0, h // 2))
    off.paste(im.crop((0, 0, w // 2, h // 2)), (w // 2, h // 2))
    # blend suave da imagem original por cima do centro (esconde a cruz)
    mask = Image.new("L", (w, h), 0)
    from PIL import ImageDraw, ImageFilter
    d = ImageDraw.Draw(mask)
    d.ellipse((w * 0.12, h * 0.12, w * 0.88, h * 0.88), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(w * 0.08))
    off.paste(im, (0, 0), mask)
    return off


def bake(im: Image.Image, size: tuple, colors: int) -> Image.Image:
    small = im.resize(size, Image.LANCZOS)
    return small.quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")


def compose_floor(grass: Image.Image, dirt: Image.Image) -> Image.Image:
    """Mesma anatomia do procedural: grama rows 0-4, sombra row 4-5, terra, laminas."""
    tile = Image.new("RGB", (32, 32))
    tile.paste(bake(dirt, (32, 32), 14), (0, 0))
    g = bake(grass, (32, 8), 10)
    tile.paste(g.crop((0, 0, 32, 5)), (0, 0))
    px = tile.load()
    gpx = g.load()
    # sombra sob a grama (escurece a linha 5)
    for x in range(32):
        r, gg, b = px[x, 5]
        px[x, 5] = (int(r * 0.55), int(gg * 0.55), int(b * 0.55))
    # laminas de grama pendendo (borda irregular, mesmas colunas do procedural)
    import random
    random.seed(99)
    for bx in (1, 4, 7, 11, 14, 18, 21, 25, 28, 31):
        bh = random.randint(2, 5)
        for y in range(5, min(5 + bh, 32)):
            px[bx, y] = gpx[bx, 3]
    return tile


def compose_platform(grass: Image.Image, dirt: Image.Image) -> Image.Image:
    tile = Image.new("RGB", (32, 16))
    tile.paste(bake(dirt, (32, 16), 12), (0, 0))
    g = bake(grass, (32, 6), 10)
    tile.paste(g.crop((0, 0, 32, 4)), (0, 0))
    px = tile.load()
    gpx = g.load()
    for x in range(32):
        r, gg, b = px[x, 4]
        px[x, 4] = (int(r * 0.55), int(gg * 0.55), int(b * 0.55))
    import random
    random.seed(55)
    for bx in (2, 6, 10, 15, 19, 24, 29):
        bh = random.randint(1, 3)
        for y in range(4, min(4 + bh, 16)):
            px[bx, y] = gpx[bx, 2]
    return tile


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    skip = "--skip-gen" in sys.argv
    for name, (prompt, seedv) in PROMPTS.items():
        if skip and (RAW / f"{name}.jpg").exists():
            print(f"skip gen: {name}")
            continue
        gen(name, prompt, seedv)

    grass = make_seamless(Image.open(RAW / "grass.jpg").convert("RGB"))
    dirt = make_seamless(Image.open(RAW / "dirt.jpg").convert("RGB"))
    rock = make_seamless(Image.open(RAW / "rock.jpg").convert("RGB"))

    compose_floor(grass, dirt).save(DEST / "grass_floor.png")
    compose_platform(grass, dirt).save(DEST / "grass_platform.png")
    bake(rock, (32, 32), 14).save(DEST / "moss_wall.png")
    print("tiles -> assets/tilesets/{grass_floor,grass_platform,moss_wall}.png")


if __name__ == "__main__":
    main()
