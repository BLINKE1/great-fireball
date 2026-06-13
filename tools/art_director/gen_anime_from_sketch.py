#!/usr/bin/env python3
"""
gen_anime_from_sketch.py — Rascunho local -> anime HD via Pollinations kontext.

Fluxo:
  1. Voce salva o rascunho em docs/sketches/<nome>.png (ou .jpg)
  2. Esse PNG ja fica acessivel via raw.githubusercontent.com (repo publico)
     APOS um commit + push.
  3. Esse script:
     - Confirma que o sketch existe e ja foi pushado (raw retorna 200)
     - Chama Pollinations kontext com o sketch como ancora + prompt anime
     - Pos-processa (transparencia opcional, normaliza bbox)
     - Salva em assets/cutscenes/<nome>_anime.png

Pre-req:
  - POLLINATIONS_TOKEN no env
  - Sketch JA commitado e empurrado pro master do repo great-fireball

Uso:
  # 1. salva o sketch
  cp ~/Desktop/meu_rascunho.png docs/sketches/boss_intro.png

  # 2. commit + push (importante! kontext precisa de URL publica)
  git add docs/sketches/boss_intro.png
  git commit -m "sketch: boss intro" && git push

  # 3. gera o anime
  python tools/art_director/gen_anime_from_sketch.py \\
      docs/sketches/boss_intro.png \\
      --style "anime cutscene, dramatic lighting, full color"

  # 4. resultado: assets/cutscenes/boss_intro_anime.png

Tipos de cena uteis pro Great Fireball:
  --type cutscene  (default) - still pra cutscene in-game (16:9)
  --type portrait                - retrato/close (1:1)
  --type teaser                  - cena pro AMV (vertical 9:16 ou 16:9 cinematica)
  --type concept                 - concept art de personagem/boss (vertical retrato)
"""
from __future__ import annotations
import argparse, io, os, sys, time, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image

HERE   = Path(__file__).parent
ROOT   = HERE.parent.parent
RAW_BASE = "https://raw.githubusercontent.com/BLINKE1/great-fireball/master/"
ENDPOINT = "https://gen.pollinations.ai/image/"
MODEL    = "kontext"

# Presets por tipo de cena (resolucao, prompt base, pasta de saida).
PRESETS = {
    "cutscene": {
        "w": 1024, "h": 576,                # 16:9
        "out": ROOT / "assets" / "cutscenes",
        "style_base": (
            "anime cutscene still, beautiful detailed background, "
            "cinematic composition, soft lighting, full color, "
            "studio anime quality, 2D animation key frame"
        ),
    },
    "portrait": {
        "w": 1024, "h": 1024,                # 1:1
        "out": ROOT / "assets" / "cutscenes" / "portraits",
        "style_base": (
            "anime portrait close-up, expressive face, "
            "detailed eyes, soft shading, character focus, "
            "studio anime quality"
        ),
    },
    "teaser": {
        "w": 1024, "h": 1820,                # 9:16 vertical (Reels/Shorts)
        "out": ROOT / "assets" / "teaser_scenes",
        "style_base": (
            "anime AMV style, cinematic vertical composition, "
            "dynamic action pose, motion blur, vivid colors, "
            "studio anime quality"
        ),
    },
    "concept": {
        "w": 768, "h": 1024,                 # 3:4 retrato
        "out": ROOT / "docs" / "concept_art",
        "style_base": (
            "anime character concept art, full body, neutral pose, "
            "transparent background, isolated character, "
            "game asset, sprite reference"
        ),
    },
}


def fetch(url: str, token: str, retries: int = 2) -> bytes:
    for attempt in range(retries + 1):
        req = urllib.request.Request(url, headers={
            "User-Agent": "great-fireball-art-director",
            "Authorization": f"Bearer {token}",
        })
        try:
            with urllib.request.urlopen(req, timeout=240) as r:
                ct = r.headers.get("Content-Type", "")
                data = r.read()
            if "image" not in ct:
                raise RuntimeError(f"resposta nao-imagem ({ct}): {data[:160]!r}")
            return data
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "ignore")[:200]
            print(f"  HTTP {e.code} (tentativa {attempt+1}): {body}")
            if e.code in (401, 402, 403):
                raise RuntimeError(f"auth/saldo: {e.code}: {body}")
            if attempt < retries:
                time.sleep(3.0 * (attempt + 1)); continue
            raise


def confirm_public(sketch_rel: str) -> str:
    """Confirma que o sketch ja esta acessivel via raw URL (commit+push feito)."""
    url = RAW_BASE + sketch_rel.replace("\\", "/")
    try:
        with urllib.request.urlopen(
            urllib.request.Request(url, method="HEAD"), timeout=15) as r:
            if r.status == 200:
                return url
    except Exception as e:
        print(f"x sketch nao acessivel em {url}")
        print(f"  ({type(e).__name__}: {e})")
        print(f"  ja deu commit + push do sketch pro master?")
        sys.exit(2)
    raise RuntimeError("status nao-200")


def build_url(sketch_url: str, style_prompt: str, w: int, h: int, seed: int) -> str:
    enc = urllib.parse.quote(style_prompt, safe="")
    params = urllib.parse.urlencode({
        "model":  MODEL,
        "image":  sketch_url,
        "width":  w,
        "height": h,
        "seed":   seed,
        "nologo": "true",
        "private": "true",
    })
    return f"{ENDPOINT}{enc}?{params}"


def make_transparent(im: Image.Image, threshold: int = 240) -> Image.Image:
    """Branco -> alpha 0 (so pra type=concept onde queremos transparente)."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r >= threshold and g >= threshold and b >= threshold:
                px[x, y] = (r, g, b, 0)
    return im


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("sketch", help="caminho do sketch (relativo ao repo, ja commitado)")
    ap.add_argument("--type", choices=list(PRESETS.keys()), default="cutscene")
    ap.add_argument("--style", default="", help="extra style hints (adiciona ao preset)")
    ap.add_argument("--out", help="nome do arquivo de saida (sem extensao); default = <sketch_basename>_anime")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--token", help="POLLINATIONS_TOKEN (ou env)")
    args = ap.parse_args()

    token = args.token or os.environ.get("POLLINATIONS_TOKEN", "")
    if not token:
        print("x defina POLLINATIONS_TOKEN"); return 1

    sketch_path = Path(args.sketch)
    if not sketch_path.exists():
        print(f"x sketch nao existe: {sketch_path}"); return 1

    # Confirma que o sketch ja esta no github raw (publico)
    rel = sketch_path.as_posix()
    if rel.startswith(("D:", "C:", "/")):
        # tenta deduzir a parte relativa ao repo
        try:
            rel = sketch_path.relative_to(ROOT).as_posix()
        except ValueError:
            print(f"x sketch precisa estar dentro do repo: {ROOT}")
            return 1
    print(f"-> confirmando que {rel} esta no github raw...")
    sketch_url = confirm_public(rel)
    print(f"   ok {sketch_url}")

    preset = PRESETS[args.type]
    style_prompt = preset["style_base"]
    if args.style:
        style_prompt += ". " + args.style

    url = build_url(sketch_url, style_prompt, preset["w"], preset["h"], args.seed)
    print(f"-> gerando ({args.type}, {preset['w']}x{preset['h']}, seed={args.seed})")
    print(f"   prompt: {style_prompt[:120]}...")
    data = fetch(url, token)

    out_dir = preset["out"]
    out_dir.mkdir(parents=True, exist_ok=True)
    name = args.out or (sketch_path.stem + "_anime")
    out_path = out_dir / f"{name}.png"

    im = Image.open(io.BytesIO(data))
    if args.type == "concept":
        im = make_transparent(im)
    im.save(out_path)
    print(f"   ok {out_path}  ({im.size}, {im.mode})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
