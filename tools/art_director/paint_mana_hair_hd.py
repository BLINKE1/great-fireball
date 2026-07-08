#!/usr/bin/env python3
"""paint_mana_hair_hd.py — pinta os 5 niveis de mana no cabelo da Soph HD
(versao BAKED / pixel-bake do render 3D, soph_hd_idle_*.png), nao a pixel-art
procedural antiga (gen_mana_states.py, que so' cobre o set 32x64).

Mecanica (CLAUDE.md): cabelo = pool de mana. Gasto RAIZ -> PONTAS (escurece de
cima pra baixo). Meia mana = raiz escura + pontas azuis ("cabelo pintado").

O nivel 3 (50%) = o idle JA COMMITADO (nao mexe, e' o "atual" citado pelo Will).
Gera so' os niveis 1,2,4,5 a partir dele:
  nivel 5 (100%) -> raiz tb fica azul (cabelo cheio)
  nivel 4 ( 75%) -> raiz escura so' no 1/4 de cima, resto (3/4) azul
  nivel 3 ( 50%) -> (baseline, nao regenerado)
  nivel 2 ( 25%) -> escuro nos 3/4 de cima, azul so' na ponta (1/4 de baixo)
  nivel 1 (  0%) -> tudo escuro (cabelo morto)

Deteccao do cabelo por cor (heuristica calibrada contra o idle real): a familia
azul-ciano do cabelo (r baixo, b bem > r) e' bem distinta do azul-marinho
desaturado da capa e do roxo do acabamento -> `is_hair()`.

  python tools/art_director/paint_mana_hair_hd.py           # gera + aplica
  python tools/art_director/paint_mana_hair_hd.py --dry     # so' mostra contagens
"""
from __future__ import annotations
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "assets" / "sprites" / "player"
N_FRAMES = 8
BASELINE_LEVEL = 3          # o idle ja commitado = 50% mana
FADE_PX = 4                 # zona de transicao suave (px), igual ao espirito do gen_mana_states.py antigo

# darkFrac por nivel: fracao do cabelo (da raiz/topo pra baixo) que fica escura.
DARK_FRAC = {5: 0.0, 4: 0.25, 3: 0.5, 2: 0.75, 1: 1.0}

BLUE_REF = (18, 145, 185)   # azul-mana vivo (ponta plena)
DEAD_REF = (10, 12, 16)     # cabelo morto (raiz vazia) — quase preto, leve tom frio


def is_hair(c: tuple) -> bool:
    r, g, b, a = c
    return a > 128 and r < 40 and (b - r) >= 45 and b >= 55


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def paint_frame(im: Image.Image, level: int) -> Image.Image:
    W, H = im.size
    px = im.load()
    mask = [(x, y) for y in range(H) for x in range(W) if is_hair(px[x, y])]
    if not mask:
        return im.copy()
    ys = [y for _, y in mask]
    y0, y1 = min(ys), max(ys)
    span = max(1, y1 - y0)
    out = im.copy()
    opx = out.load()
    dark_frac = DARK_FRAC[level]
    fade = FADE_PX / span
    for x, y in mask:
        t = (y - y0) / span   # 0=raiz (topo), 1=ponta (base)
        if t < dark_frac - fade:
            c = DEAD_REF
        elif t > dark_frac + fade:
            c = BLUE_REF
        else:
            blend_t = (t - (dark_frac - fade)) / (2 * fade) if fade > 0 else (1.0 if t > dark_frac else 0.0)
            c = lerp(DEAD_REF, BLUE_REF, blend_t)
        opx[x, y] = (*c, 255)
    return out


def main() -> None:
    dry = "--dry" in sys.argv
    for level in (5, 4, 2, 1):   # 3 = baseline, nao regenera
        for i in range(N_FRAMES):
            src = DIR / f"soph_hd_idle_{i}.png"
            im = Image.open(src).convert("RGBA")
            out = paint_frame(im, level)
            dst = DIR / f"soph_hd_idle_m{level}_{i}.png"
            if dry:
                mask_n = sum(1 for p in out.getdata() if p[3] > 128)
                print(f"[dry] nivel {level} frame {i}: {mask_n} px opacos -> {dst.name}")
            else:
                out.save(dst)
                print(f"ok -> {dst.name}")


if __name__ == "__main__":
    main()
