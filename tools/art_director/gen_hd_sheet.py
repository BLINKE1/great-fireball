#!/usr/bin/env python3
"""
gen_hd_sheet.py — Gera UM model sheet (grade) com o MAXIMO de poses da Soph HD
numa UNICA chamada Pollinations kontext e depois fatia em frames.

Por que sheet unica? Cada chamada nova ao modelo e' um "sorteio" de identidade
(a ancora nao ancora 100%). Tudo o que sai NA MESMA imagem compartilha a MESMA
Soph -> coerencia de identidade entre todas as poses. Modo exploratorio:
geramos tudo que da, depois garimpamos o que presta.

Pipeline:
  1. monta 1 prompt com N poses numeradas em grade (rows x cols), fundo branco;
  2. fetch (1 chamada) -> sheet RGB;
  3. whiten_to_alpha no sheet inteiro;
  4. segmenta em celulas por deteccao de calhas brancas (com fallback p/ split
     uniforme se a contagem detectada destoar do esperado);
  5. normaliza cada celula pro canvas do jogo (100x192, pes na base);
  6. salva celulas + um "contact.png" rotulado pra garimpo manual.

Pre-req p/ geracao real:
  - POLLINATIONS_TOKEN no env (ou --token sk_...)
  - repo publico (a ANCHOR_URL precisa resolver).

Uso:
  python tools/art_director/gen_hd_sheet.py --selftest        # prova o fatiador (offline)
  python tools/art_director/gen_hd_sheet.py --dry             # mostra o prompt
  python tools/art_director/gen_hd_sheet.py --gen             # 1 chamada -> sheet + celulas
  python tools/art_director/gen_hd_sheet.py --slice <png>     # re-fatia um sheet ja baixado

Saidas (em assets/sprites/player/_preview/sheet_<nome>/):
  _raw_sheet.png      sheet cru do modelo
  sheet_alpha.png     sheet whitened (fundo transparente)
  cells/cell_NN.png   celulas normalizadas (canvas do jogo)
  contact.png         montagem rotulada pra eyeball
"""
from __future__ import annotations
import argparse, io, os, sys, time, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
# reaproveita o pipeline ja validado do gerador frame-a-frame
from gen_hd_from_idle import (  # noqa: E402
    whiten_to_alpha, normalize_to_canvas, fetch,
    CANVAS_W, CANVAS_H, ANCHOR_URL, ENDPOINT, MODEL,
)

ASSETS = HERE.parent.parent / "assets" / "sprites" / "player"

# Sheet largo: cabe uma grade. Pollinations as vezes ignora w/h em kontext,
# mas mandamos mesmo assim pra empurrar o aspecto.
SHEET_W, SHEET_H = 1536, 1024
BASE_SEED = 11
OPAQUE_A = 24            # alpha > isso = pixel "de conteudo"

# Descricao curta do personagem (repetida no prompt do sheet).
CHAR_SHORT = (
    "anime mage girl: pointed red wizard hat, long blue hair, round "
    "black-framed glasses, red robe with dark lining, brown boots, blue "
    "glowing crystal staff"
)

# Lista COMPLETA de poses pra estressar o modelo. Ordem = leitura
# (esq->dir, cima->baixo). Cada item: (chave, descricao curta da pose).
POSES: list[tuple[str, str]] = [
    ("idle",    "idle standing, staff at side, facing right"),
    ("walk_0",  "walking right, right foot forward contact"),
    ("walk_1",  "walking right, passing pose mid-stride"),
    ("walk_2",  "walking right, left foot forward contact"),
    ("run_0",   "running right, full sprint stride, hair streaming"),
    ("run_1",   "running right, mid-air passing, both feet off ground"),
    ("jump",    "jumping up, legs tucked, robe billowing"),
    ("fall",    "falling, legs extended, robe blown upward"),
    ("hurt",    "hit reaction, recoiling backward, pained"),
    ("crouch",  "crouching low, knees bent, staff braced"),
    ("cast_0",  "casting, raising staff overhead, orb glowing"),
    ("cast_1",  "casting, staff aimed forward, beam of magic"),
    ("slash_0", "staff swing windup, drawn back over shoulder"),
    ("slash_1", "staff swing release, swung forward-down"),
    ("victory", "victory pose, staff raised high, cheerful"),
    ("dash",    "dashing forward, leaning into motion, speed lines"),
]


# ----------------------------------------------------------------------------
# Prompt do sheet
# ----------------------------------------------------------------------------
def grid_dims(n: int, cols: int) -> tuple[int, int]:
    rows = (n + cols - 1) // cols
    return rows, cols


def build_sheet_prompt(poses: list[tuple[str, str]], cols: int) -> str:
    rows, cols = grid_dims(len(poses), cols)
    numbered = "; ".join(f"{i+1}) {d}" for i, (_, d) in enumerate(poses))
    return (
        f"character model sheet / sprite sheet of the SAME character: "
        f"{CHAR_SHORT}. {len(poses)} full-body poses arranged in a clean "
        f"{rows} by {cols} grid, reading order left-to-right top-to-bottom, "
        f"every pose EQUAL SIZE and same scale, each pose centered in its own "
        f"cell with generous WHITE GUTTERS between cells, all poses full "
        f"character head-to-feet, side view facing right, consistent design "
        f"across all poses, PURE FLAT WHITE BACKGROUND, no scenery, no shadow, "
        f"no gradient, no text labels, game sprite cutout style. Poses: {numbered}."
    )


def build_sheet_url(prompt: str, seed: int) -> str:
    enc = urllib.parse.quote(prompt, safe="")
    params = urllib.parse.urlencode({
        "model": MODEL, "image": ANCHOR_URL,
        "width": SHEET_W, "height": SHEET_H,
        "seed": seed, "nologo": "true", "private": "true",
    })
    return f"{ENDPOINT}{enc}?{params}"


# ----------------------------------------------------------------------------
# Fatiador: deteccao de calhas (gutters) brancas com fallback uniforme
# ----------------------------------------------------------------------------
def _runs(profile: list[int], thresh: int, min_gap: int, min_run: int):
    """Acha runs contiguos onde profile>thresh, ignorando lacunas < min_gap."""
    runs, start = [], None
    gap = 0
    for i, v in enumerate(profile):
        if v > thresh:
            if start is None:
                start = i
            gap = 0
        else:
            if start is not None:
                gap += 1
                if gap >= min_gap:
                    end = i - gap + 1
                    if end - start >= min_run:
                        runs.append((start, end))
                    start = None
                    gap = 0
    if start is not None:
        end = len(profile) - gap
        if end - start >= min_run:
            runs.append((start, end))
    return runs


def segment_cells(alpha_im: Image.Image, expected: int, cols: int):
    """Retorna lista de bboxes (x0,y0,x1,y1) das celulas em ordem de leitura.

    1) perfil por linha -> bandas (linhas com conteudo);
    2) dentro de cada banda, perfil por coluna -> celulas.
    Fallback p/ split uniforme se a contagem destoar muito do esperado.
    """
    w, h = alpha_im.size
    a = alpha_im.split()[3].load()
    # perfil de linhas
    row_prof = [sum(1 for x in range(w) if a[x, y] > OPAQUE_A) for y in range(h)]
    row_thresh = max(2, int(w * 0.004))
    bands = _runs(row_prof, row_thresh, min_gap=max(4, h // 60),
                  min_run=max(8, h // 30))
    cells = []
    for (y0, y1) in bands:
        col_prof = [sum(1 for y in range(y0, y1) if a[x, y] > OPAQUE_A)
                    for x in range(w)]
        col_thresh = max(1, int((y1 - y0) * 0.02))
        runs = _runs(col_prof, col_thresh, min_gap=max(4, w // 80),
                     min_run=max(6, w // 60))
        for (x0, x1) in runs:
            cells.append((x0, y0, x1, y1))
    rows, cols = grid_dims(expected, cols)
    # fallback: contagem muito fora do esperado -> grade uniforme
    if not cells or abs(len(cells) - expected) > max(2, expected // 3):
        print(f"   [seg] detectou {len(cells)} celulas; esperado ~{expected}. "
              f"fallback p/ grade uniforme {rows}x{cols}.")
        cells = []
        cw, ch = w // cols, h // rows
        for r in range(rows):
            for c in range(cols):
                cells.append((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
        cells = cells[:expected]
    else:
        print(f"   [seg] detectou {len(cells)} celulas (esperado ~{expected}).")
    return cells


# ----------------------------------------------------------------------------
# Saidas
# ----------------------------------------------------------------------------
def make_contact(cells_imgs: list[Image.Image], labels: list[str]) -> Image.Image:
    """Monta um contato rotulado das celulas normalizadas (p/ eyeball)."""
    if not cells_imgs:
        return Image.new("RGBA", (CANVAS_W, CANVAS_H), (40, 40, 40, 255))
    cols = min(6, len(cells_imgs))
    rows = (len(cells_imgs) + cols - 1) // cols
    pad, lab_h = 6, 14
    cw, ch = CANVAS_W, CANVAS_H + lab_h
    out = Image.new("RGBA", (cols * (cw + pad) + pad, rows * (ch + pad) + pad),
                    (30, 30, 30, 255))
    d = ImageDraw.Draw(out)
    for i, (im, lab) in enumerate(zip(cells_imgs, labels)):
        r, c = divmod(i, cols)
        x = pad + c * (cw + pad)
        y = pad + r * (ch + pad)
        # checker bg leve pra ver transparencia
        d.rectangle([x, y, x + cw, y + CANVAS_H], fill=(70, 70, 70, 255))
        out.paste(im, (x, y), im)
        d.text((x + 2, y + CANVAS_H + 2), f"{i:02d} {lab}", fill=(230, 230, 230, 255))
    return out


def slice_sheet(sheet_im: Image.Image, out_dir: Path,
                poses: list[tuple[str, str]], cols: int) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    cells_dir = out_dir / "cells"
    cells_dir.mkdir(exist_ok=True)
    alpha = whiten_to_alpha(sheet_im.convert("RGB"))
    alpha.save(out_dir / "sheet_alpha.png")
    boxes = segment_cells(alpha, expected=len(poses), cols=cols)
    norm_imgs, labels = [], []
    for i, box in enumerate(boxes):
        cell = alpha.crop(box)
        sprite = normalize_to_canvas(cell)
        key = poses[i][0] if i < len(poses) else f"extra_{i}"
        sprite.save(cells_dir / f"cell_{i:02d}_{key}.png")
        norm_imgs.append(sprite)
        labels.append(key)
    contact = make_contact(norm_imgs, labels)
    contact.save(out_dir / "contact.png")
    print(f"-> {len(boxes)} celulas -> {cells_dir}")
    print(f"   contato: {out_dir / 'contact.png'}")
    return 0


# ----------------------------------------------------------------------------
# Selftest offline: sintetiza um sheet e prova o fatiador
# ----------------------------------------------------------------------------
def make_synthetic_sheet(n: int, cols: int) -> Image.Image:
    """Grade de silhuetas variadas (larguras/alturas) sobre fundo branco, com
    calhas, p/ validar a segmentacao sem chamar a rede."""
    rows, cols = grid_dims(n, cols)
    cw, ch = 240, 320
    gut = 40
    W = cols * cw + (cols + 1) * gut
    H = rows * ch + (rows + 1) * gut
    im = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(im)
    for i in range(n):
        r, c = divmod(i, cols)
        x0 = gut + c * (cw + gut)
        y0 = gut + r * (ch + gut)
        # silhueta de largura/altura variavel dentro da celula
        bw = cw - 40 - (i % 4) * 30
        bh = ch - 30 - (i % 3) * 40
        bx = x0 + (cw - bw) // 2
        by = y0 + (ch - bh)        # "pes" na base da celula
        d.rectangle([bx, by, bx + bw, by + bh], fill=(40, 60, 180))
        d.ellipse([bx + bw // 4, by, bx + 3 * bw // 4, by + bw // 2],
                  fill=(200, 40, 40))  # "cabeca"
    return im


def selftest() -> int:
    n, cols = len(POSES), 4
    print(f"[selftest] sheet sintetico {n} poses, {cols} colunas")
    sheet = make_synthetic_sheet(n, cols)
    alpha = whiten_to_alpha(sheet)
    boxes = segment_cells(alpha, expected=n, cols=cols)
    ok = (len(boxes) == n)
    # cada celula tem conteudo opaco?
    nonempty = 0
    for box in boxes:
        if alpha.crop(box).getbbox():
            nonempty += 1
    print(f"[selftest] celulas detectadas: {len(boxes)} (esperado {n}) -> "
          f"{'OK' if ok else 'FALLBACK/FALHA'}")
    print(f"[selftest] celulas com conteudo: {nonempty}/{len(boxes)}")
    # prova normalizacao
    sample = normalize_to_canvas(alpha.crop(boxes[0]))
    print(f"[selftest] normalize_to_canvas -> {sample.size} (esperado "
          f"({CANVAS_W}, {CANVAS_H})) -> "
          f"{'OK' if sample.size == (CANVAS_W, CANVAS_H) else 'FALHA'}")
    # salva artefatos do selftest p/ inspecao
    out = ASSETS / "_preview" / "sheet_selftest"
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / "_raw_sheet.png")
    slice_sheet(sheet, out, POSES, cols)
    good = ok and nonempty == len(boxes) and sample.size == (CANVAS_W, CANVAS_H)
    print(f"[selftest] {'PASSOU' if good else 'REVISAR'} — artefatos em {out}")
    return 0 if good else 2


# ----------------------------------------------------------------------------
def parse_args() -> argparse.Namespace:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--selftest", action="store_true", help="prova o fatiador offline")
    g.add_argument("--dry", action="store_true", help="mostra o prompt do sheet")
    g.add_argument("--gen", action="store_true", help="1 chamada -> sheet + celulas")
    g.add_argument("--slice", metavar="PNG", help="re-fatia um sheet ja baixado")
    ap.add_argument("--cols", type=int, default=4, help="colunas da grade")
    ap.add_argument("--seed", type=int, default=BASE_SEED)
    ap.add_argument("--name", default="soph_hd", help="nome da pasta de saida")
    ap.add_argument("--token", help="POLLINATIONS_TOKEN (ou usa env)")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
    if args.selftest:
        return selftest()

    if args.dry:
        prompt = build_sheet_prompt(POSES, args.cols)
        rows, cols = grid_dims(len(POSES), args.cols)
        print(f"grade {rows}x{cols}, {len(POSES)} poses, seed={args.seed}")
        print(f"URL: {build_sheet_url(prompt, args.seed)[:160]}...")
        print(f"\nPROMPT:\n{prompt}")
        return 0

    out_dir = ASSETS / "_preview" / f"sheet_{args.name}"

    if args.slice:
        sheet = Image.open(args.slice)
        return slice_sheet(sheet, out_dir, POSES, args.cols)

    if args.gen:
        token = args.token or os.environ.get("POLLINATIONS_TOKEN", "")
        if not token:
            print("x defina POLLINATIONS_TOKEN ou passe --token")
            return 1
        prompt = build_sheet_prompt(POSES, args.cols)
        url = build_sheet_url(prompt, args.seed)
        print(f"-> gerando sheet ({len(POSES)} poses, seed={args.seed})")
        data = fetch(url, token)
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "_raw_sheet.png").write_bytes(data)
        sheet = Image.open(io.BytesIO(data))
        print(f"   sheet {sheet.size}, {len(data)}b")
        return slice_sheet(sheet, out_dir, POSES, args.cols)

    return 1


if __name__ == "__main__":
    sys.exit(main())
