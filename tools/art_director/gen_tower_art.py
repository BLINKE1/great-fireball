#!/usr/bin/env python3
"""gen_tower_art.py — processa a arte da torre (Pollinations flux) pros assets do
jogo. Tema ARCANO: pedra de tijolo + runas purpura, catedral de mago.

  backdrop.jpg -> assets/sprites/backgrounds/tower_backdrop.png (1280x720)
  wall.jpg     -> assets/tilesets/tower_wall.png  (seamless, graduado)
              -> assets/tilesets/tower_floor.png  (tijolo + topo desgastado)
              -> assets/tilesets/tower_platform.png (tijolo + sombra embaixo)
  door.jpg     -> assets/sprites/tower_door.png (key-out do fundo preto, alpha)

Uso: python tools/art_director/gen_tower_art.py
"""
from __future__ import annotations
from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools" / "art_director" / "iterations" / "tower"
BG = ROOT / "assets" / "sprites" / "backgrounds"
TS = ROOT / "assets" / "tilesets"
SPR = ROOT / "assets" / "sprites"


def make_seamless(im: Image.Image) -> Image.Image:
    w, h = im.size
    off = Image.new("RGB", (w, h))
    off.paste(im.crop((w // 2, h // 2, w, h)), (0, 0))
    off.paste(im.crop((0, h // 2, w // 2, h)), (w // 2, 0))
    off.paste(im.crop((w // 2, 0, w, h // 2)), (0, h // 2))
    off.paste(im.crop((0, 0, w // 2, h // 2)), (w // 2, h // 2))
    from PIL import ImageDraw
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((w * 0.12, h * 0.12, w * 0.88, h * 0.88), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(w * 0.08))
    off.paste(im, (0, 0), mask)
    return off


def grade_arcane(img: Image.Image) -> Image.Image:
    """Assenta o tijolo na paleta arcana: dessatura leve, esfria a sombra pro
    azul-purpura, segura o highlight, levanta o preto pra um cinza-frio."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    a = lum[..., None] * 0.12 + a * 0.88          # dessatura 12%
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    sh = np.clip(1.0 - lum / 90.0, 0.0, 1.0)[..., None]   # sombras
    cool = np.array([18.0, 16.0, 34.0], np.float32)        # azul-purpura
    rgb = np.stack([r, g, b], -1)
    rgb = rgb * (1.0 - sh * 0.35) + cool * (sh * 0.35)
    hi = np.clip((lum - 165.0) / 90.0, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - hi * 0.15)
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def keyout(im: Image.Image, dark=20) -> Image.Image:
    rgb = im.convert("RGB"); W, H = rgb.size; px = rgb.load()
    darkm = [[max(px[x, y]) <= dark for x in range(W)] for y in range(H)]
    out = [[False] * W for _ in range(H)]; q = deque()
    for x in range(W):
        for y in (0, H - 1):
            if darkm[y][x]: out[y][x] = True; q.append((x, y))
    for y in range(H):
        for x in (0, W - 1):
            if darkm[y][x] and not out[y][x]: out[y][x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            if 0 <= nx < W and 0 <= ny < H and darkm[ny][nx] and not out[ny][nx]:
                out[ny][nx] = True; q.append((nx, ny))
    alpha = Image.new("L", (W, H), 255); ap = alpha.load()
    for y in range(H):
        for x in range(W):
            if out[y][x]: ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.8))
    res = rgb.copy().convert("RGBA"); res.putalpha(alpha)
    bb = res.split()[3].getbbox()
    return res.crop(bb) if bb else res


def top_cap(tile: Image.Image, lighten: float) -> Image.Image:
    """Clareia levemente a fileira de cima (superficie desgastada/pisada)."""
    a = np.asarray(tile.convert("RGB")).astype(np.float32)
    H = a.shape[0]; band = max(3, int(H * 0.10))
    w = np.zeros(H, np.float32); w[:band] = np.linspace(lighten, 0.0, band)
    a = a * (1.0 + w[:, None, None] * 0.5)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def main() -> None:
    TS.mkdir(parents=True, exist_ok=True); SPR.mkdir(parents=True, exist_ok=True)
    # backdrop
    bd = Image.open(RAW / "backdrop.jpg").convert("RGB").resize((1280, 720), Image.LANCZOS)
    bd.save(BG / "tower_backdrop.png"); print("ok tower_backdrop.png")
    # tijolo -> wall/floor/platform (512 tile)
    brick = grade_arcane(make_seamless(Image.open(RAW / "wall.jpg").convert("RGB")).resize((512, 512), Image.LANCZOS))
    brick.save(TS / "tower_wall.png"); print("ok tower_wall.png")
    top_cap(brick, 0.6).save(TS / "tower_floor.png"); print("ok tower_floor.png")
    plat = top_cap(brick.crop((0, 0, 512, 96)), 0.6)
    plat.save(TS / "tower_platform.png"); print("ok tower_platform.png")
    # porta arcana
    keyout(Image.open(RAW / "door.jpg")).save(SPR / "tower_door.png"); print("ok tower_door.png")


if __name__ == "__main__":
    main()
