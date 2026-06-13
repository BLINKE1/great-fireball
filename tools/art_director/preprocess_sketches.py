#!/usr/bin/env python3
"""
preprocess_sketches.py — Limpa rascunhos escaneados pra alimentar a kontext.

Pipeline por imagem:
  1. Rotaciona 90 graus se a pagina estiver em portrait mas o conteudo em
     landscape (heuristica: se altura > largura, rotaciona).
  2. White-balance: estica o canal pra que o fundo papel vire branco puro.
  3. Auto-crop: corta margens onde a tinta nao chega.
  4. Salva em assets/cutscenes/referencias-desenhos/processed/<nome>.png

Uso:
  python tools/art_director/preprocess_sketches.py
"""
from pathlib import Path
from PIL import Image, ImageOps

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
SRC  = ROOT / "assets" / "cutscenes" / "referencias-desenhos" / "pdf_pages"
DST  = ROOT / "assets" / "cutscenes" / "referencias-desenhos" / "processed"

# Mapeamento page_XX.png -> nome semantico
RENAME = {
    "page_01.png": "soph_concept_main.png",
    "page_02.png": "spoiler_multi_scenes.png",
    "page_03.png": "torre_cutscene_cenas_1_a_4.png",
    "page_04.png": "ability_time_stop.png",
    "page_05.png": "soph_dynamic_pose.png",
    "page_06.png": "soph_action_with_figure.png",
    "page_07.png": "soph_staff_action.png",
    "page_08.png": "juju_fairy_concept.png",
    "page_09.png": "di_elf_concept.png",
    "page_10.png": "will_giant_knight_concept.png",
    "page_11.png": "gus_rogue_concept.png",
    "page_12.png": "gui_fenhyr_wolf_knight_concept.png",
}


def autocrop_white(im: Image.Image, threshold: int = 245, padding: int = 40) -> Image.Image:
    """Crop em torno do conteudo nao-branco, com padding."""
    g = im.convert("L")
    # mascara: pixels escuros viram brancos, brancos viram pretos
    mask = g.point(lambda v: 0 if v >= threshold else 255)
    bbox = mask.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    W, H = im.size
    x0 = max(0, x0 - padding); y0 = max(0, y0 - padding)
    x1 = min(W, x1 + padding); y1 = min(H, y1 + padding)
    return im.crop((x0, y0, x1, y1))


def whiten_background(im: Image.Image, threshold: int = 220) -> Image.Image:
    """Pixels claros viram branco puro (limpa amarelado do papel)."""
    px = im.convert("RGB").load()
    out = Image.new("RGB", im.size, (255, 255, 255))
    op = out.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                op[x, y] = (255, 255, 255)
            else:
                op[x, y] = (r, g, b)
    return out


def maybe_rotate_landscape(im: Image.Image) -> Image.Image:
    """Se a pagina foi escaneada portrait mas o conteudo eh landscape
    (i.e., altura > largura), rotaciona 90 graus pra DIREITA (CW) — em PIL
    isso eh angulo negativo, pq positivo eh CCW."""
    w, h = im.size
    if h > w:
        return im.rotate(-90, expand=True, fillcolor=(255, 255, 255))
    return im


def main() -> int:
    DST.mkdir(parents=True, exist_ok=True)
    pages = sorted(SRC.glob("page_*.png"))
    if not pages:
        print(f"x nada em {SRC}"); return 1
    print(f"-> {len(pages)} paginas em {SRC}")
    for p in pages:
        target_name = RENAME.get(p.name, p.name)
        out = DST / target_name
        print(f"  {p.name} -> {target_name}")
        im = Image.open(p)
        im = maybe_rotate_landscape(im)
        im = whiten_background(im)
        im = autocrop_white(im)
        # downscale pra ~1024 wide (kontext nao se beneficia de 2500px)
        if im.width > 1280:
            ratio = 1280 / im.width
            im = im.resize((1280, int(im.height * ratio)), Image.LANCZOS)
        im.save(out, optimize=True)
    print(f"\nok {len(pages)} sketches limpos em {DST}")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
