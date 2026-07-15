#!/usr/bin/env python3
"""paint_mana_hair_hd.py — pinta os 5 niveis de mana no cabelo da Soph HD
(versao BAKED / pixel-bake do render 3D, soph_hd_idle_*.png), nao a pixel-art
procedural antiga (gen_mana_states.py, que so' cobre o set 32x64).

Mecanica (CLAUDE.md): cabelo = pool de mana. Gasto RAIZ -> PONTAS (escurece de
cima pra baixo). Meia mana = raiz escura + pontas azuis ("cabelo pintado").

v2 (2026-07-08): a 1a versao so' recolorizava a mecha lateral (cabelo ja
renderizado bem azul/brilhante — deteccao por cor). O Will mandou um markup
("Não seria mais próximo disso?") apontando que a FRANJA que emoldura o rosto
(hoje escura, quase identica ao tom do capuz) tambem e' cabelo e devia entrar
no sistema. Como esses pixels nao tem uma cor distinta do capuz no render
baked (sombra do chapeu, sem diferenca de matiz confiavel), a regiao extra foi
AUTORADA a partir do markup dele (`FRINGE_ROWS`, extraido/mapeado do desenho,
ver git log) em vez de detectada por cor. Uniao: franja autorada + mecha
detectada por cor (`is_hair`), excluindo pele/luva (pixels claros).

Todos os 5 niveis sao regenerados a cada rodada (a franja nova muda a
aparencia mesmo no nivel 3/50%, que antes ficava intocado).
  nivel 5 (100%) -> tudo azul     nivel 4 (75%) -> raiz escura no 1/4 de cima
  nivel 3 ( 50%) -> raiz escura na metade de cima, ponta azul na metade debaixo
  nivel 2 ( 25%) -> escuro nos 3/4 de cima, so' a ponta azul
  nivel 1 (  0%) -> tudo escuro (cabelo morto)

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
FADE_PX = 4   # zona de transicao suave (px)

DARK_FRAC = {5: 0.0, 4: 0.25, 3: 0.5, 2: 0.75, 1: 1.0}

BLUE_REF = (18, 145, 185)   # azul-mana vivo (ponta plena)
DEAD_REF = (10, 12, 16)     # cabelo morto (raiz vazia) — quase preto, leve tom frio

# Franja que emoldura o rosto — autorada a partir do markup do Will (mapeado do
# screenshot dele pra coordenadas do sprite 100x192). (y, x_min, x_max) por linha.
FRINGE_ROWS = [
    (54,38,47),(55,38,48),(56,37,48),(57,37,48),(58,37,48),(59,36,48),
    (60,35,48),(61,33,48),(62,31,48),(63,30,48),(64,30,58),(65,37,58),
    (66,37,58),(67,36,56),(68,37,57),(69,36,57),(70,36,57),(71,36,57),
    (72,35,57),(73,35,58),(74,35,58),(75,34,58),(76,34,59),(77,34,61),
    (78,33,62),(79,33,63),(80,32,63),(81,31,64),(82,30,64),(83,30,65),
    (84,29,65),(85,29,66),(86,28,66),(87,28,66),(88,27,65),(89,27,65),
    (90,26,50),(91,25,50),(92,25,50),(93,24,50),(94,23,50),(95,23,43),
    (96,22,34),(97,21,33),(98,21,33),(99,19,33),(100,19,32),(101,18,32),
    (102,18,32),(103,16,32),(104,16,32),(105,19,31),(106,23,30),
    (107,24,30),(108,26,29),(109,26,30),(110,27,30),
]


def is_hair_bright(c: tuple) -> bool:
    """Mecha lateral: ja renderizada com matiz azul-ciano distinta do capuz."""
    r, g, b, a = c
    return a > 128 and r < 40 and (b - r) >= 45 and b >= 55


def is_skin(c: tuple) -> bool:
    r, g, b, a = c
    return a > 128 and r > 150 and g > 150 and b > 150


def fringe_mask(W: int, H: int) -> set:
    m = set()
    for y, x0, x1 in FRINGE_ROWS:
        if y < H:
            for x in range(x0, min(x1, W - 1) + 1):
                m.add((x, y))
    return m


def lerp(a: tuple, b: tuple, t: float) -> tuple:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def paint_frame(im: Image.Image, level: int) -> Image.Image:
    W, H = im.size
    px = im.load()
    mask = set(fringe_mask(W, H))
    for y in range(H):
        for x in range(W):
            if is_hair_bright(px[x, y]):
                mask.add((x, y))
    mask = {(x, y) for x, y in mask if not is_skin(px[x, y])}
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
    for level in (5, 4, 3, 2, 1):
        for i in range(N_FRAMES):
            src = DIR / f"soph_hd_idle_{i}.png"
            im = Image.open(src).convert("RGBA")
            out = paint_frame(im, level)
            dst = DIR / (f"soph_hd_idle_{i}.png" if level == 3 else f"soph_hd_idle_m{level}_{i}.png")
            if dry:
                mask_n = sum(1 for p in out.getdata() if p[3] > 128)
                print(f"[dry] nivel {level} frame {i}: {mask_n} px opacos -> {dst.name}")
            else:
                out.save(dst)
                print(f"ok -> {dst.name}")


if __name__ == "__main__":
    main()
