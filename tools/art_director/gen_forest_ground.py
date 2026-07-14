#!/usr/bin/env python3
"""gen_forest_ground.py — tileset PREMIUM pintado (John Avon/MTG) pro chao da
floresta, via override do SpriteSetup.

v2 "premium" (feedback do Will: a v1 quantizada 32px ficou "Sega Mega Drive"):
tiles grandes (512px), SEM quantizacao, pra casar com o registro pintado do
backdrop. Ficou possivel porque a ancora do region_rect agora e' (0,0)
(level_visuals._visit) -> a textura alinha no topo do chao com QUALQUER
tamanho de tile, nao so' 32px. O level_visuals usa filtro LINEAR na floresta.

Pipeline: Pollinations flux gera 3 texturas (grama/musgo luminoso, terra com
raizes, rocha musgada) -> seamless por offset+blend -> composicao rica:
  assets/tilesets/grass_floor.png     512x256 (banda de grama c/ borda organica,
                                      terra escurecendo com a profundidade)
  assets/tilesets/grass_platform.png  512x64
  assets/tilesets/moss_wall.png       384x384

  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_forest_ground.py
  ... --skip-gen   # reusa os brutos ja baixados (so' recompoe os tiles)
"""
from __future__ import annotations
import math, os, random, sys, urllib.request, urllib.parse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools" / "art_director" / "iterations" / "forest_ground"
DEST = ROOT / "assets" / "tilesets"

TOKEN = os.environ.get("POLLINATIONS_TOKEN", "")

PROMPTS = {
    "grass": ("seamless texture of lush luminous emerald moss and short grass, "
              "top-down view, Magic the Gathering John Avon forest style, deep "
              "green with teal glow, painterly, soft god-ray light, no objects, "
              "no text, uniform density", 4207),
    "dirt": ("seamless texture of dark forest soil with thin roots and small "
             "stones, earthy brown umber with deep green moss patches, John Avon "
             "Magic the Gathering style, painterly, top-down, no objects, no text",
             918),
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
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((w * 0.12, h * 0.12, w * 0.88, h * 0.88), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(w * 0.08))
    off.paste(im, (0, 0), mask)
    return off


# ── v3 "rim-lit" (linguagem HK/Greenpath): terreno = massa ESCURA de terra +
# reborda fina LUMINOSA de musgo no topo, calibrada na paleta do backdrop
# (sombra do backdrop ~(33,83,45); reborda puxa o teal-esmeralda luminoso).
RIM_HI = (96, 205, 122)     # fio de luz na superficie (esmeralda vivo, nao "menta")
RIM_LO = (34, 118, 70)      # musgo esmeralda (corpo da reborda)
GLOW = (20, 74, 46)         # respingo de luz que sangra na terra
DIRT_FLAT = (26, 38, 30)    # tom base pra unificar a terra (tira pedras berrantes)


def _grade(im: Image.Image, mul: tuple) -> Image.Image:
    """Recolore multiplicando canais -> assenta a textura na paleta da cena."""
    r, g, b = im.split()
    return Image.merge("RGB", (
        r.point(lambda v: int(v * mul[0])),
        g.point(lambda v: int(v * mul[1])),
        b.point(lambda v: int(v * mul[2]))))


def _edge_curve(w: int, base: int, wobble: int, seed: int) -> list:
    """Borda organica periodica em x (senos de periodo inteiro = seamless)."""
    rng = random.Random(seed)
    ph = [rng.uniform(0, math.tau) for _ in range(3)]
    return [base + (math.sin(x / w * math.tau * 3 + ph[0]) * 0.45 +
                    math.sin(x / w * math.tau * 7 + ph[1]) * 0.35 +
                    math.sin(x / w * math.tau * 13 + ph[2]) * 0.20) * wobble
            for x in range(w)]


def _depth_darken(tile: Image.Image, y0: int, floor_f: float) -> None:
    px = tile.load()
    w, h = tile.size
    for y in range(y0, h):
        f = 1.0 - (1.0 - floor_f) * ((y - y0) / max(1, h - y0)) ** 1.25
        for x in range(w):
            r, g, b = px[x, y]
            px[x, y] = (int(r * f), int(g * f), int(b * f))


def _rim_lit(dirt: Image.Image, W: int, H: int, rim: int, wobble: int,
             depth_f: float, seed: int, dirt_y: int = 0) -> Image.Image:
    """Compoe um tile: terra sombria + reborda luminosa organica no topo."""
    graded = _grade(dirt.crop((0, dirt_y, W, dirt_y + H)), (0.42, 0.52, 0.46))
    # unifica a terra: blend com tom chapado (tira pedras/musgos berrantes da fonte)
    tile = Image.blend(Image.new("RGB", graded.size, DIRT_FLAT), graded, 0.55)
    _depth_darken(tile, rim, depth_f)
    px = tile.load()
    edge = _edge_curve(W, rim, wobble, seed)
    rng = random.Random(seed * 31)
    for x in range(W):
        e = edge[x]
        # reborda: fio claro FINO (2px) no topo -> musgo esmeralda no resto
        for y in range(int(e)):
            mix = min(1.0, y / 2.5)
            r = int(RIM_HI[0] + (RIM_LO[0] - RIM_HI[0]) * mix)
            g = int(RIM_HI[1] + (RIM_LO[1] - RIM_HI[1]) * mix)
            b = int(RIM_HI[2] + (RIM_LO[2] - RIM_HI[2]) * mix)
            n = rng.uniform(0.92, 1.06)   # ruido leve pra nao ficar banda chapada
            px[x, y] = (int(r * n), int(g * n), int(b * n))
        # glow aditivo curto sangrando na terra abaixo da reborda
        for y in range(int(e), min(int(e) + 8, H)):
            f = 1.0 - (y - e) / 8.0
            r, g, b = px[x, y]
            px[x, y] = (min(255, int(r + GLOW[0] * 0.25 * f)),
                        min(255, int(g + GLOW[1] * 0.25 * f)),
                        min(255, int(b + GLOW[2] * 0.25 * f)))
    return tile


# ── v4 "slice do terreno pintado": o flux pinta o terreno PRONTO (ilha 2.5D,
# prompt "2D platformer ground terrain cross-section, Hollow Knight Greenpath
# mood") e a gente fatia a FACE FRONTAL: detecta o musgo luminoso do topo
# coluna a coluna, endireita (topo plano), corta a faixa e faz seamless em x.
# A composicao procedural (v3, _rim_lit) fica como fallback --rim-lit.

def _is_moss(c: tuple) -> bool:
    r, g, b = c[:3]
    return g > 120 and g > r * 1.5 and g > b * 1.2


def slice_terrain(t: Image.Image, x0: int, x1: int, depth: int) -> Image.Image:
    """Fatia a FACE FRONTAL do terreno pintado: ancora no labio de musgo da
    frente (ULTIMA linha de musgo de cada coluna, nao a primeira — a primeira
    e' a borda de tras do "gramado" do topo da ilha). Topo alinhado em y=0."""
    px = t.load()
    W, H = t.size
    LIP = 8   # quantos px de musgo do labio entram no tile
    lips: list = []
    for x in range(x0, x1):
        lip = -1
        for y in range(H - 1, -1, -1):
            if _is_moss(px[x, y]):
                lip = y
                break
        lips.append(lip)
    for i, v in enumerate(lips):
        if v < 0:
            lips[i] = lips[i - 1] if i > 0 else next((v2 for v2 in lips if v2 >= 0), 0)
    # suaviza a curva do labio (media movel 7) -> sem estrias de coluna
    sm = []
    n = len(lips)
    for i in range(n):
        w = [lips[j] for j in range(max(0, i - 3), min(n, i + 4))]
        sm.append(sum(w) / len(w))
    strip = Image.new("RGB", (x1 - x0, depth))
    for i, x in enumerate(range(x0, x1)):
        top = max(0, int(sm[i]) - LIP)
        col = t.crop((x, top, x + 1, min(top + depth, H)))
        strip.paste(col, (i, 0))
        if col.height < depth:
            last = col.crop((0, col.height - 1, 1, col.height))
            for y in range(col.height, depth):
                strip.paste(last, (i, y))
    # abaixo da face frontal a fonte vira fundo desfocado -> escurece com a
    # profundidade (le como terra densa) e esconde a contaminacao
    spx = strip.load()
    for y in range(40, depth):
        f = max(0.18, 1.0 - (y - 40) / 110.0)
        for i in range(strip.width):
            r, g, b = spx[i, y]
            spx[i, y] = (int(r * f), int(g * f), int(b * f))
    return strip


def _seamless_x(im: Image.Image) -> Image.Image:
    """Seamless so' no eixo x (offset de meia largura + blend na emenda)."""
    w, h = im.size
    off = Image.new("RGB", (w, h))
    off.paste(im.crop((w // 2, 0, w, h)), (0, 0))
    off.paste(im.crop((0, 0, w // 2, h)), (w // 2, 0))
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle((w * 0.12, 0, w * 0.88, h), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(w * 0.06))
    off.paste(im, (0, 0), mask)
    return off


def compose_floor_from_terrain(terrain: Image.Image) -> Image.Image:
    strip = slice_terrain(terrain, 200, 860, 256)
    tile = _seamless_x(strip.resize((512, 256), Image.LANCZOS))
    # estende pra 512 de altura: abaixo dos 256 pintados a terra segue escura
    # (chao fisico chega a ~400px de fundura -> tile de 256 dava WRAP e a grama
    # reaparecia no meio da terra). Blend continua do fim pro breu.
    out = Image.new("RGB", (512, 512))
    out.paste(tile, (0, 0))
    last = tile.crop((0, 255, 512, 256))
    for y in range(256, 512):
        f = max(0.25, 1.0 - (y - 256) / 90.0)
        row = last.point(lambda v: int(v * f))
        out.paste(row, (0, y))
    return out


# ── Plataforma v2 (justifica o "flutuante"): bancada de terra suspensa ────────
# Musgo em cima (mesma cara do chao), corpo de rocha AFUNILANDO com borda
# organica e uma franja de RAIZES penduradas embaixo (alpha) — le como um
# barranco seguro por raizes, nao um tile pairando. As raizes ficam ABAIXO do
# collider (overhang visual, ver level_visuals._visit).
def compose_platform_from_terrain(floor_tile: Image.Image) -> Image.Image:
    import random as _r
    W, FULL_H, BODY_H, WOB = 512, 88, 26, 6
    tile = floor_tile.crop((0, 0, W, FULL_H)).convert("RGBA")
    px = tile.load()
    rng = _r.Random(41)
    ph = [rng.uniform(0, math.tau) for _ in range(3)]
    # borda inferior organica (periodica em x = seamless)
    edge = [BODY_H + (math.sin(x / W * math.tau * 4 + ph[0]) * 0.5 +
                      math.sin(x / W * math.tau * 9 + ph[1]) * 0.3 +
                      math.sin(x / W * math.tau * 15 + ph[2]) * 0.2) * WOB
            for x in range(W)]
    # raizes: colunas esparsas com fios que descem alem da borda
    root_until = [0.0] * W
    x = 0
    while x < W:
        if rng.random() < 0.42:
            length = rng.uniform(8.0, 26.0)
            width = rng.choice([2, 2, 3])
            for dx in range(width):
                root_until[(x + dx) % W] = max(root_until[(x + dx) % W],
                                               edge[(x + dx) % W] + length * rng.uniform(0.8, 1.0))
            x += width + rng.randint(6, 18)
        else:
            x += rng.randint(4, 10)
    ROOT_C = (74, 58, 40)      # marrom-raiz legivel contra o backdrop escuro
    TIP_C = (40, 118, 66)      # ponta com brilho de musgo (amarra na paleta)
    for xx in range(W):
        e = edge[xx]
        ru = root_until[xx]
        for y in range(FULL_H):
            if y <= e - 2:
                continue                      # corpo cheio
            r, g, b, _a = px[xx, y]
            if y <= e:                        # borda: escurece + fade curto
                px[xx, y] = (int(r * 0.7), int(g * 0.7), int(b * 0.7), 255)
            elif y <= ru:                     # fio de raiz -> ponta com musgo
                t = (y - e) / max(1.0, ru - e)
                a = int(255 * (1.0 - t * 0.35))
                if t > 0.78:                  # ponta: verde-musgo luminoso
                    px[xx, y] = (TIP_C[0], TIP_C[1], TIP_C[2], a)
                else:
                    px[xx, y] = (int(ROOT_C[0] * (1.0 - t * 0.3)),
                                 int(ROOT_C[1] * (1.0 - t * 0.3)),
                                 int(ROOT_C[2] * (1.0 - t * 0.3)), a)
            else:
                px[xx, y] = (0, 0, 0, 0)      # ar
    return tile


def compose_floor(_grass: Image.Image, dirt: Image.Image) -> Image.Image:
    return _rim_lit(dirt, 512, 256, rim=9, wobble=4, depth_f=0.40, seed=7)


def compose_platform(_grass: Image.Image, dirt: Image.Image) -> Image.Image:
    return _rim_lit(dirt, 512, 64, rim=7, wobble=3, depth_f=0.55, seed=13, dirt_y=128)


def compose_wall(rock: Image.Image) -> Image.Image:
    return _grade(rock.resize((384, 384), Image.LANCZOS), (0.50, 0.62, 0.56))


# ── COESAO (feedback do Will: "nao mescla"): grade pra paleta da cena ────────
# O tile saia com um LABIO de musgo verde-neon (pico ~0,112,25) sobre massa
# quase preta -> navalha que grita "tile colado". Aqui: dessatura, empurra o
# verde pro TEAL-esmeralda do backdrop, comprime o highlight neon, levanta o
# preto morto pra um carvao-teal (relaciona com a cena) e FEATHER-a o labio
# (blur vertical no musgo -> rim suave que sangra glow, nao navalha).
def _grade_scene(img: Image.Image) -> Image.Image:
    import numpy as np
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    # 1) dessatura 16%
    a = lum[..., None] * 0.16 + a * 0.84
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    # 2) teal-shift: sobe o azul nos verdes vivos (hue neon->esmeralda) e alivia
    #    o pico do verde
    green_dom = np.clip((g - np.maximum(r, b)) / 90.0, 0.0, 1.0)
    b = b + green_dom * (g - b) * 0.45
    g = g - green_dom * g * 0.12
    # 3) comprime highlight (o neon estourado assenta na cena)
    hi = np.clip((lum - 150.0) / 105.0, 0.0, 1.0)
    for ch in (0,):
        pass
    r = r * (1.0 - hi * 0.18); g = g * (1.0 - hi * 0.22); b = b * (1.0 - hi * 0.10)
    # 4) levanta o preto morto pra carvao-teal (nao preto puro)
    charc = np.array([7.0, 16.0, 15.0], np.float32)
    sh = np.clip(1.0 - lum / 46.0, 0.0, 1.0)[..., None]
    rgb = np.stack([r, g, b], -1)
    rgb = rgb * (1.0 - sh * 0.55) + charc * (sh * 0.55)
    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")
    return out


def _feather_moss(img: Image.Image) -> Image.Image:
    """Suaviza o labio: blur vertical so' na banda de musgo -> rim gradiente."""
    import numpy as np
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    soft = np.asarray(img.filter(ImageFilter.GaussianBlur(2.2))).astype(np.float32)
    H = a.shape[0]
    # peso: forte no topo (labio), some ate' ~18% da altura
    band = int(H * 0.20)
    w = np.zeros(H, np.float32)
    w[:band] = np.linspace(0.75, 0.0, band)
    mix = w[:, None, None]
    out = a * (1.0 - mix) + soft * mix
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    DEST.mkdir(parents=True, exist_ok=True)
    skip = "--skip-gen" in sys.argv
    for name, (prompt, seedv) in PROMPTS.items():
        if skip and (RAW / f"{name}.jpg").exists():
            print(f"skip gen: {name}")
            continue
        gen(name, prompt, seedv)

    rock = make_seamless(Image.open(RAW / "rock.jpg").convert("RGB"))
    terrain_p = RAW / "terrain_101.jpg"
    if terrain_p.exists() and "--rim-lit" not in sys.argv:
        floor = compose_floor_from_terrain(Image.open(terrain_p).convert("RGB"))
        floor = _feather_moss(_grade_scene(floor))   # coesao com a cena
        floor.save(DEST / "grass_floor.png")
        # plataforma herda o floor ja graduado (mesma paleta), depois raizes+alpha
        compose_platform_from_terrain(floor).save(DEST / "grass_platform.png")
        print("modo v4: fatiado do terreno pintado + grade de cena + raizes")
    else:
        grass = make_seamless(Image.open(RAW / "grass.jpg").convert("RGB"))
        dirt = make_seamless(Image.open(RAW / "dirt.jpg").convert("RGB"))
        compose_floor(grass, dirt).save(DEST / "grass_floor.png")
        compose_platform(grass, dirt).save(DEST / "grass_platform.png")
        print("modo fallback: composicao rim-lit procedural")
    _grade_scene(compose_wall(rock)).save(DEST / "moss_wall.png")
    print("tiles premium -> assets/tilesets/{grass_floor,grass_platform,moss_wall}.png")


if __name__ == "__main__":
    main()
