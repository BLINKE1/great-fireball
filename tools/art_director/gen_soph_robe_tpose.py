#!/usr/bin/env python3
"""
gen_soph_robe_tpose.py — gera uma Soph T-POSE ESGUIA vestida com a robe de maga.

Objetivo: casar o CORPO esguio da T-pose que ja temos
(docs/concept_art/soph_base_tpose.png) com a ROBE/acessorios da referencia
(docs/concept_art/soph_robe_ref.png), mantendo T-pose limpa p/ virar mesh 3D.

Duas abordagens (gera as duas, pra comparar no olho):
  --mode dual       : ANCORA DUPLA -> manda T-pose + robe_ref como 2 imagens
                      (image[]) pro /v1/images/edits. A IA mistura: corpo da 1a,
                      roupa da 2a.
  --mode described  : ANCORA SIMPLES -> manda so a T-pose + EU descrevo a robe
                      no prompt (texto). Mais controle do estilo, menos "copia".
  --mode both       : as duas (default).

IMPORTANTE (regra do projeto): a Soph e MAGA / sorceress — NUNCA "bruxa"/"witch".
Chapeu de MAGA (pointed mage hat).

Uso:
  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_soph_robe_tpose.py [--mode both] [--seeds 7,42]
"""
from __future__ import annotations
import os, sys, json, base64, argparse, urllib.request, urllib.error
from pathlib import Path

ROOT    = Path(__file__).parent.parent.parent
CONCEPT = ROOT / "docs" / "concept_art"
OUT     = ROOT / "tools" / "art_director" / "iterations" / "robe_tpose"
EDITS   = "https://gen.pollinations.ai/v1/images/edits"

TPOSE = CONCEPT / "soph_base_tpose.png"
ROBE  = CONCEPT / "soph_robe_ref.png"

# --- pose/identidade que NAO pode mudar (vale pras duas versoes) ---
KEEP = (
    "Keep her EXACT slim TALL adult proportions and long legs (NOT chibi, not "
    "short, not stubby). Perfect symmetric T-POSE: both arms straight out "
    "horizontally to the sides forming a T, palms facing down, legs slightly "
    "apart at hip width, feet flat, head straight forward, neutral face. "
    "Long black hair with glowing blue-teal mana tips. Round black-framed "
    "glasses. She is a young SORCERESS / MAGE (never a witch). "
    "FULL BODY head to feet, front view, isolated on PURE FLAT WHITE background, "
    "no shadow, no gradient, clean sprite/reference-sheet cutout for game rigging."
)

# --- a robe/acessorios descritos por mim (modo described) ---
ROBE_DESC = (
    "Dress her in a sorceress outfit: a long dark charcoal-black open mage "
    "robe/coat with deep purple trim and faint glowing arcane purple line "
    "patterns along the hem, worn open over a fitted black bodysuit and black "
    "leggings; a small high collar with a purple amethyst gem brooch at the "
    "chest; a dark belt at the waist; a pointed MAGE hat (dark, with a purple "
    "band, a buckle, and a small hanging teardrop gem); brown leather lace-up "
    "boots. Anime style, clean flat cel shading."
)

DUAL_PROMPT = (
    "Redraw the slim girl from the FIRST image, but dressed in the mage outfit "
    "from the SECOND image (dark purple-trimmed sorceress robe, pointed mage "
    "hat, gem brooch, belt, brown boots). " + KEEP +
    " Use the body and pose of the first image; use ONLY the clothing/hat/"
    "accessories from the second image. Anime style, clean flat cel shading."
)

DESC_PROMPT = ROBE_DESC + " " + KEEP


def _part(name: str, value: str) -> bytes:
    b = b"--BOUNDARY\r\n"
    b += f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
    b += f"{value}\r\n".encode()
    return b


def _file_part(name: str, path: Path) -> bytes:
    b = b"--BOUNDARY\r\n"
    b += f'Content-Disposition: form-data; name="{name}"; filename="{path.name}"\r\n'.encode()
    b += b"Content-Type: image/png\r\n\r\n"
    b += path.read_bytes()
    b += b"\r\n"
    return b


def edit(images: list[Path], prompt: str, out: Path, token: str,
         model: str, seed: int) -> bool:
    body = b""
    body += _part("prompt", prompt)
    body += _part("model", model)
    body += _part("seed", str(seed))
    # uma so imagem -> "image"; varias -> "image[]" (estilo gpt-image-1)
    field = "image" if len(images) == 1 else "image[]"
    for p in images:
        body += _file_part(field, p)
    body += b"--BOUNDARY--\r\n"

    req = urllib.request.Request(EDITS, data=body, method="POST", headers={
        "Content-Type": "multipart/form-data; boundary=BOUNDARY",
        "Authorization": f"Bearer {token}",
        "User-Agent": "great-fireball-art-director",
    })
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        msg = e.read().decode("utf-8", "ignore")[:300]
        print(f"  x HTTP {e.code}: {msg}")
        return False
    except Exception as e:
        print(f"  x rede: {type(e).__name__}: {e}")
        return False

    # resposta: JSON {data:[{b64_json}]} ou PNG cru
    if data[:4] == b"\x89PNG":
        out.write_bytes(data)
    else:
        try:
            j = json.loads(data.decode())
            b64 = j["data"][0].get("b64_json")
            if not b64:
                url = j["data"][0].get("url")
                if url:
                    out.write_bytes(urllib.request.urlopen(url, timeout=120).read())
                    print(f"  ok {out.name} (via url)")
                    return True
                print(f"  x resposta sem imagem: {str(j)[:200]}")
                return False
            out.write_bytes(base64.b64decode(b64))
        except Exception as e:
            print(f"  x resposta invalida ({type(e).__name__}): {data[:160]!r}")
            return False
    print(f"  ok {out.name} ({out.stat().st_size} bytes)")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["dual", "described", "both"], default="both")
    ap.add_argument("--seeds", default="7,42")
    ap.add_argument("--model", default="gptimage")
    ap.add_argument("--token", default=None)
    args = ap.parse_args()

    token = args.token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("x defina POLLINATIONS_TOKEN ou passe --token"); return 1
    for p in (TPOSE, ROBE):
        if not p.exists():
            print(f"x falta referencia: {p}"); return 1
    OUT.mkdir(parents=True, exist_ok=True)
    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]

    jobs = []
    if args.mode in ("dual", "both"):
        jobs.append(("A_dual", [TPOSE, ROBE], DUAL_PROMPT))
    if args.mode in ("described", "both"):
        jobs.append(("B_described", [TPOSE], DESC_PROMPT))

    ok = 0
    for tag, imgs, prompt in jobs:
        for seed in seeds:
            out = OUT / f"soph_tpose_robe_{tag}_s{seed}.png"
            print(f"-> {tag}  seed={seed}  imgs={len(imgs)}  model={args.model}")
            if edit(imgs, prompt, out, token, args.model, seed):
                ok += 1
    print(f"\n{ok} imagem(ns) geradas em {OUT}/")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
