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

# Fundos suportados. Verde = chroma key (recorte limpo: nao come brilho/branco
# da Soph). Branco = fallback por brilho (arriscado em destaques claros).
BG_PROMPT = {
    "green": ("PURE FLAT CHROMA KEY GREEN SCREEN BACKGROUND, solid bright "
              "green #00b140, uniform green backdrop"),
    "white": "PURE FLAT WHITE BACKGROUND, solid white",
}


def key_bg_to_alpha(im: Image.Image, bg: str) -> Image.Image:
    """RGB -> RGBA com fundo removido. green=chroma key + despill; white=brilho."""
    if bg == "white":
        return whiten_to_alpha(im)
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # verde dominante e' fundo -> transparente
            if g > 80 and g > r * 1.2 and g > b * 1.2:
                px[x, y] = (r, g, b, 0)
            elif g > max(r, b):
                # despill: derruba o vazamento verde nas bordas
                ng = (max(r, b) + g) // 2
                px[x, y] = (r, ng, b, a)
    return im

# Descricao curta do personagem (repetida no prompt do sheet).
CHAR_SHORT = (
    "anime mage girl: pointed red wizard hat, long blue hair, round "
    "black-framed glasses, red robe with dark lining, brown boots"
)
# A arma (cajado/lamina) NAO faz parte da descricao base — segue o principio HK:
# locomocao sem arma, arma so na acao. Sets de acao reintroduzem a arma na pose.
WEAPON = "blue glowing crystal staff"

# Poses em CONJUNTOS TEMATICOS. Estrategia (vide HK): nao cabe tudo numa sheet
# sem perder identidade — o sweet spot e' ~12-16 poses/sheet. P/ cobrir muitas
# poses, gera-se varios sheets TEMATICOS ancorados na MESMA referencia (ou,
# melhor, no 1o sheet aprovado via --anchor). Ordem = leitura (esq->dir, cima->baixo).
# Sets de LOCOMOCAO sao sem arma (maos vazias). Sets de ACAO (em WEAPON_SETS)
# reintroduzem a arma na descricao da pose. Vide principio HK em CLAUDE.md.
WEAPON_SETS = {"combat", "attack_phys", "cast_special", "core16"}

POSE_SETS: dict[str, list[tuple[str, str]]] = {
    # so locomocao essencial num 3x3 — celulas grandes, max nitidez. SEM arma.
    "walkrun9": [
        ("idle",   "idle standing, empty hands, relaxed"),
        ("walk_0", "walking right, right foot forward contact"),
        ("walk_1", "walking right, passing pose mid-stride"),
        ("walk_2", "walking right, left foot forward contact"),
        ("walk_3", "walking right, recoil, foot lifting behind"),
        ("run_0",  "running right, full sprint, right foot extended"),
        ("run_1",  "running right, mid-air passing, both feet off ground"),
        ("run_2",  "running right, full sprint, left foot extended"),
        ("run_3",  "running right, mid-air passing opposite"),
    ],
    # locomocao completa, SEM arma (idle/walk/run/dash/jump/fall/hurt).
    "locomotion": [
        ("idle",   "idle standing, empty hands, relaxed"),
        ("walk_0", "walking right, right foot forward contact"),
        ("walk_1", "walking right, passing pose mid-stride"),
        ("walk_2", "walking right, left foot forward contact"),
        ("run_0",  "running right, full sprint, right foot extended"),
        ("run_1",  "running right, mid-air passing, both feet off ground"),
        ("dash",   "dashing forward, leaning hard, speed motion, empty hands"),
        ("jump",   "jumping up, legs tucked, robe billowing, empty hands"),
        ("fall",   "falling, legs extended, robe blown upward, empty hands"),
        ("hurt",   "hit reaction, recoiling backward, pained, empty hands"),
    ],
    # ATAQUE FISICO (frente): iaido draw-slash. O smear esconde o movimento
    # rapido e e' generoso p/ a geracao (um risco nao exige consistencia).
    "attack_phys": [
        ("ready",  "front view facing camera, battle ready stance, hand on "
                   "sword hilt at hip, anticipation crouch"),
        ("draw",   "front view, fast sword DRAW, blade is a motion-blur smear "
                   "streak across the body, dynamic"),
        ("cut",    "front view, clean finished slash, red-bladed sword extended "
                   "across, strong silhouette, sharp"),
        ("follow", "front view, slash follow-through, blade lowered, recovery"),
    ],
    # CAST ESPECIAL (3/4 -> costas, UMA mao): caro em mana, estilo Reigun.
    # Uma mao ergue o cajado; a outra escondida sob o manto.
    "cast_special": [
        ("turn",    "three-quarter back view turning away, cape swirl motion-"
                    "blur smear hiding the turn, dynamic"),
        ("charge",  "back view from behind, one hand raising the " + WEAPON +
                    " overhead, other hand hidden under cloak, long hair down "
                    "the back, mana gathering, charging"),
        ("release", "back view from behind, " + WEAPON + " raised high, powerful "
                    "magic beam launching upward, cape billowing"),
    ],
    # ~16 poses curadas: cobre o essencial num sheet so. Default.
    "core16": [
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
    ],
    # combate: cast + slash + variacoes de golpe (COM arma)
    "combat": [
        ("cast_0",   "casting windup, raising staff overhead, orb glowing"),
        ("cast_1",   "casting, staff aimed forward, beam of magic"),
        ("cast_2",   "casting, both hands channeling, magic swirl"),
        ("slash_0",  "staff swing windup, drawn back over shoulder"),
        ("slash_1",  "staff swing release, swung forward-down"),
        ("slash_2",  "staff swing follow-through, body extended low"),
        ("thrust",   "staff thrust forward, lunging stab"),
        ("uppercut", "upward staff swing, rising arc"),
        ("block",    "defensive guard, staff held across body"),
        ("parry",    "parry, staff knocking attack aside"),
    ],
    # TESTE paper doll: base "naked" (bodysuit) + vestida, MESMO corpo (1x2).
    "paperdoll": [
        ("base",    "base body layer"),
        ("dressed", "fully dressed over the base"),
    ],
    # reacoes e estados
    "reactions": [
        ("hurt_0",  "hit reaction, recoiling backward, pained"),
        ("hurt_1",  "heavy hit, knocked off balance"),
        ("death",   "defeated, collapsing to the ground"),
        ("crouch",  "crouching low, knees bent"),
        ("victory", "victory pose, both arms raised high, cheerful"),
        ("taunt",   "taunting, hand on hip, confident"),
        ("cheer",   "celebrating, both arms up"),
        ("think",   "thinking, hand on chin"),
    ],
}
# default exportado p/ selftest/compat
POSES: list[tuple[str, str]] = POSE_SETS["core16"]


# ----------------------------------------------------------------------------
# Prompt do sheet
# ----------------------------------------------------------------------------
def grid_dims(n: int, cols: int) -> tuple[int, int]:
    rows = (n + cols - 1) // cols
    return rows, cols


def build_sheet_prompt(poses: list[tuple[str, str]], cols: int,
                       bg: str = "green", weapon: bool = False) -> str:
    rows, cols = grid_dims(len(poses), cols)
    numbered = "; ".join(f"{i+1}) {d}" for i, (_, d) in enumerate(poses))
    bg_desc = BG_PROMPT.get(bg, BG_PROMPT["green"])
    gap = "GREEN" if bg == "green" else "WHITE"
    # Principio HK: locomocao SEM arma (maos vazias); a camera dela e' perfil.
    # Sets de acao trazem a arma e cada pose dita seu proprio angulo (frente/
    # costas), entao nao forcamos "side view".
    if weapon:
        view = "consistent design across all poses (camera per pose as described)"
    else:
        view = ("side view facing right, EMPTY HANDS, NO weapon, no staff, no "
                "sword, consistent design across all poses")
    # Isolamento AGGRESSIVO: a kontext tende a empacotar as poses coladas, o que
    # impede o auto-corte. Forcamos espaco vazio enorme e proibimos toque.
    return (
        f"character reference sheet of the SAME character: {CHAR_SHORT}. "
        f"{len(poses)} small full-body poses laid out on a {rows} by {cols} "
        f"grid. CRITICAL: each pose is SMALL and ISOLATED, fully separated from "
        f"the others by LARGE EMPTY {gap} MARGINS; the poses MUST NOT touch, "
        f"overlap, or connect; thick empty space between every pose on all "
        f"sides; each pose centered in its own cell, equal size and scale. "
        f"All poses full character head-to-feet, {view}. {bg_desc}, no panels, "
        f"no borders, no lines, no scenery, no shadow, no gradient, no text, no "
        f"labels, no signature. Game sprite cutout style. Poses: {numbered}."
    )


def build_paperdoll_prompt(bg: str = "green") -> str:
    """Prompt dedicado do teste paper doll: MESMA garota, 2 vezes lado a lado —
    esquerda so' o corpo-base (bodysuit preto + oculos), direita vestida."""
    bg_desc = BG_PROMPT.get(bg, BG_PROMPT["green"])
    return (
        "character paper-doll reference: the SAME anime mage girl shown TWICE "
        "side by side, three-quarter view, identical face/body/proportions, "
        "long blue hair, round black-framed glasses. "
        "LEFT figure = BASE LAYER: wearing ONLY a plain skin-tight solid BLACK "
        "full-body bodysuit, NO hat, NO robe, NO cloak, bare base, glasses on. "
        "RIGHT figure = SAME girl fully dressed OVER that body: closed long red "
        "robe with dark lining, pointed red wizard hat, brown boots (boots "
        "hidden under the robe if not visible), empty hands. "
        "The two figures ISOLATED, separated by a LARGE EMPTY margin, MUST NOT "
        f"touch or overlap. {bg_desc}, no panels, no borders, no scenery, no "
        "shadow, no gradient, no text, no labels, no signature. Game art."
    )


def build_sheet_url(prompt: str, seed: int, anchor: str = ANCHOR_URL) -> str:
    enc = urllib.parse.quote(prompt, safe="")
    params = urllib.parse.urlencode({
        "model": MODEL, "image": anchor,
        "width": SHEET_W, "height": SHEET_H,
        "seed": seed, "nologo": "true", "private": "true",
    })
    return f"{ENDPOINT}{enc}?{params}"


# ----------------------------------------------------------------------------
# Fatiador: deteccao de BLOBS (connected components) — robusto a layout
# irregular (o kontext NAO desenha grade limpa). Cada pose e' uma silhueta
# conectada; achamos cada ilha de pixels, juntamos partes coladas (cajado
# solto), filtramos ruido (assinatura/textinho) e ordenamos em leitura.
# Python puro + downsample p/ velocidade (sem numpy/scipy no ambiente).
# ----------------------------------------------------------------------------
SEG_TARGET_W = 256      # largura do mask reduzido p/ a busca de blobs


def _components(mask: list[bool], w: int, h: int):
    """Rotula componentes 8-conexos; retorna lista de (x0,y0,x1,y1,area)."""
    from collections import deque
    labels = [0] * (w * h)
    boxes, cur = [], 0
    for i in range(w * h):
        if mask[i] and labels[i] == 0:
            cur += 1
            labels[i] = cur
            dq = deque([i])
            x0 = x1 = i % w
            y0 = y1 = i // w
            area = 0
            while dq:
                p = dq.popleft()
                px, py = p % w, p // w
                area += 1
                if px < x0: x0 = px
                if px > x1: x1 = px
                if py < y0: y0 = py
                if py > y1: y1 = py
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = px + dx, py + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            q = ny * w + nx
                            if mask[q] and labels[q] == 0:
                                labels[q] = cur
                                dq.append(q)
            boxes.append((x0, y0, x1 + 1, y1 + 1, area))
    return boxes


def _merge_close(boxes, margin):
    """Funde bboxes que se sobrepoem quando expandidos por `margin` (junta
    cajado/peca solta a' silhueta da mesma pose)."""
    changed = True
    boxes = [list(b) for b in boxes]
    while changed:
        changed = False
        out = []
        while boxes:
            a = boxes.pop()
            ax0, ay0, ax1, ay1 = a[0], a[1], a[2], a[3]
            merged = True
            while merged:
                merged = False
                rest = []
                for b in boxes:
                    if (ax0 - margin < b[2] and b[0] - margin < ax1 and
                            ay0 - margin < b[3] and b[1] - margin < ay1):
                        ax0, ay0 = min(ax0, b[0]), min(ay0, b[1])
                        ax1, ay1 = max(ax1, b[2]), max(ay1, b[3])
                        merged = changed = True
                    else:
                        rest.append(b)
                boxes = rest
            out.append([ax0, ay0, ax1, ay1])
        boxes = out
    return boxes


def _reading_order(boxes):
    """Ordena em leitura: agrupa por linhas (overlap vertical) e ordena x."""
    if not boxes:
        return boxes
    boxes = sorted(boxes, key=lambda b: b[1])
    med_h = sorted(b[3] - b[1] for b in boxes)[len(boxes) // 2]
    rows, cur = [], [boxes[0]]
    for b in boxes[1:]:
        if b[1] - cur[-1][1] < med_h * 0.5:
            cur.append(b)
        else:
            rows.append(cur); cur = [b]
    rows.append(cur)
    ordered = []
    for row in rows:
        ordered.extend(sorted(row, key=lambda b: b[0]))
    return ordered


def _profile(small, sw: int, sh: int, axis: str) -> list[int]:
    """Densidade de pixels opacos por coluna (axis='x') ou linha ('y')."""
    if axis == "x":
        return [sum(1 for y in range(sh) if small[x, y] > OPAQUE_A)
                for x in range(sw)]
    return [sum(1 for x in range(sw) if small[x, y] > OPAQUE_A)
            for y in range(sh)]


def _grid_cuts(profile: list[int], n: int, length: int) -> list[int]:
    """n-1 linhas de corte: ponto de MENOR densidade numa janela em torno de
    cada fronteira esperada i*length/n. Uma ponte fina (cajado) nao preenche o
    vao, entao o vale ainda e' achado."""
    cuts = [0]
    cell = length / n
    win = max(2, int(cell * 0.35))
    for i in range(1, n):
        c = int(i * cell)
        lo, hi = max(1, c - win), min(length - 1, c + win)
        cuts.append(min(range(lo, hi), key=lambda p: profile[p]))
    cuts.append(length)
    return cuts


def split_grid_gutters(small, sw: int, sh: int, rows: int, cols: int):
    """Corta grade rows x cols pelos vales de densidade. Retorna None se alguma
    celula vier quase vazia (layout irregular -> usar blobs)."""
    xc = _grid_cuts(_profile(small, sw, sh, "x"), cols, sw)
    yc = _grid_cuts(_profile(small, sw, sh, "y"), rows, sh)
    min_occ = (sw * sh) / (rows * cols) * 0.03
    cells = []
    for r in range(rows):
        for c in range(cols):
            x0, x1, y0, y1 = xc[c], xc[c + 1], yc[r], yc[r + 1]
            occ = sum(1 for y in range(y0, y1) for x in range(x0, x1)
                      if small[x, y] > OPAQUE_A)
            if occ < min_occ:
                return None
            cells.append((x0, y0, x1, y1))
    return cells


def segment_cells(alpha_im: Image.Image, expected: int, cols: int):
    """Retorna bboxes (x0,y0,x1,y1) das poses em ordem de leitura.
    1) corte por vaos numa grade rows x cols (regular); senao
    2) blobs (layout irregular); senao 3) split uniforme."""
    w, h = alpha_im.size
    s = max(1, w // SEG_TARGET_W)
    sw, sh = w // s, h // s
    small = alpha_im.resize((sw, sh), Image.NEAREST).split()[3].load()
    rows, gcols = grid_dims(expected, cols)
    # 1) grade regular por vaos (caso da Soph com prompt de isolamento)
    grid = split_grid_gutters(small, sw, sh, rows, gcols)
    if grid is not None:
        out = [(max(0, x0 * s), max(0, y0 * s), min(w, x1 * s), min(h, y1 * s))
               for (x0, y0, x1, y1) in grid]
        print(f"   [seg] grade {rows}x{gcols} por vaos -> {len(out)} celulas.")
        return out
    # 2) blobs (connected components)
    mask = [small[x, y] > OPAQUE_A for y in range(sh) for x in range(sw)]
    raw = _components(mask, sw, sh)
    # filtra ruido: area minima e dimensao minima (tira assinatura/textinho)
    min_area = max(20, int(sw * sh * 0.004))
    min_dim = max(4, sw // 40)
    blobs = [(b[0], b[1], b[2], b[3]) for b in raw
             if b[4] >= min_area and (b[2] - b[0]) >= min_dim
             and (b[3] - b[1]) >= min_dim]
    # merge minimo: so cola pecas quase encostadas (cajado solto), sem fundir
    # poses vizinhas (que no sheet ficam proximas).
    blobs = _merge_close(blobs, margin=1)
    blobs = _reading_order(blobs)
    if len(blobs) < 3:
        rows, cols = grid_dims(expected, cols)
        print(f"   [seg] blobs={len(blobs)} (<3); fallback grade {rows}x{cols}.")
        cw, ch = w // cols, h // rows
        return [(c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
                for r in range(rows) for c in range(cols)][:expected]
    # escala de volta p/ resolucao cheia + pad de seguranca
    pad = s
    out = []
    for (x0, y0, x1, y1) in blobs:
        out.append((max(0, x0 * s - pad), max(0, y0 * s - pad),
                    min(w, x1 * s + pad), min(h, y1 * s + pad)))
    print(f"   [seg] {len(out)} poses por blob (esperado ~{expected}).")
    return out


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
                poses: list[tuple[str, str]], cols: int, bg: str = "green") -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    cells_dir = out_dir / "cells"
    cells_dir.mkdir(exist_ok=True)
    alpha = key_bg_to_alpha(sheet_im.convert("RGB"), bg)
    alpha.save(out_dir / "sheet_alpha.png")
    boxes = segment_cells(alpha, expected=len(poses), cols=cols)
    # so casa nome-de-pose quando a contagem bate exatamente (ex.: selftest);
    # senao numera por indice (kontext nao garante ordem/contagem).
    exact = (len(boxes) == len(poses))
    norm_imgs, labels = [], []
    for i, box in enumerate(boxes):
        cell = alpha.crop(box)
        sprite = normalize_to_canvas(cell)
        key = poses[i][0] if exact else f"p{i:02d}"
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
    alpha = key_bg_to_alpha(sheet, "white")
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
    slice_sheet(sheet, out, POSES, cols, bg="white")
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
    ap.add_argument("--set", dest="pose_set", default="core16",
                    choices=sorted(POSE_SETS), help="conjunto de poses (tema)")
    ap.add_argument("--bg", default="green", choices=sorted(BG_PROMPT),
                    help="fundo: green (chroma key, recorte limpo) ou white")
    ap.add_argument("--cols", type=int, default=4, help="colunas da grade")
    ap.add_argument("--seed", type=int, default=BASE_SEED)
    ap.add_argument("--name", help="nome da pasta de saida (default = nome do set)")
    ap.add_argument("--anchor", help="URL de ancora alt. (ex.: 1o sheet aprovado)")
    ap.add_argument("--token", help="POLLINATIONS_TOKEN (ou usa env)")
    return ap.parse_args()


def main() -> int:
    args = parse_args()
    if args.selftest:
        return selftest()

    poses = POSE_SETS[args.pose_set]
    anchor = args.anchor or ANCHOR_URL
    weapon = args.pose_set in WEAPON_SETS
    paper = args.pose_set == "paperdoll"

    def _prompt() -> str:
        return (build_paperdoll_prompt(args.bg) if paper
                else build_sheet_prompt(poses, args.cols, args.bg, weapon))

    if args.dry:
        prompt = _prompt()
        rows, cols = grid_dims(len(poses), args.cols)
        print(f"set={args.pose_set} grade {rows}x{cols}, {len(poses)} poses, "
              f"bg={args.bg}, seed={args.seed}")
        print(f"URL: {build_sheet_url(prompt, args.seed, anchor)[:160]}...")
        print(f"\nPROMPT:\n{prompt}")
        return 0

    out_dir = ASSETS / "_preview" / f"sheet_{args.name or args.pose_set}"

    if args.slice:
        sheet = Image.open(args.slice)
        return slice_sheet(sheet, out_dir, poses, args.cols, args.bg)

    if args.gen:
        token = args.token or os.environ.get("POLLINATIONS_TOKEN", "")
        if not token:
            print("x defina POLLINATIONS_TOKEN ou passe --token")
            return 1
        prompt = _prompt()
        url = build_sheet_url(prompt, args.seed, anchor)
        print(f"-> gerando sheet set={args.pose_set} ({len(poses)} poses, "
              f"bg={args.bg}, seed={args.seed})")
        data = fetch(url, token)
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "_raw_sheet.png").write_bytes(data)
        sheet = Image.open(io.BytesIO(data))
        print(f"   sheet {sheet.size}, {len(data)}b")
        return slice_sheet(sheet, out_dir, poses, args.cols, args.bg)

    return 1


if __name__ == "__main__":
    sys.exit(main())
