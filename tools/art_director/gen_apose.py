#!/usr/bin/env python3
"""
gen_apose.py — Gera Soph em A-pose (e opcional T-pose) ancorada na
soph_base_ref.png via Pollinations kontext, p/ servir de fonte cutout
do rig 2D futuro.

Saidas em docs/concept_art/:
  - soph_base_apose.png
  - soph_base_tpose.png (se --tpose)
"""
from __future__ import annotations
import argparse, io, os, sys, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image

HERE   = Path(__file__).parent
CONCEPT = HERE.parent.parent / "docs" / "concept_art"

ANCHOR_URL = "https://raw.githubusercontent.com/BLINKE1/great-fireball/master/docs/concept_art/soph_base_ref.png"
ENDPOINT   = "https://gen.pollinations.ai/image/"
MODEL      = "kontext"
W, H       = 768, 1024

CHAR = (
    "same anime girl character (long blue-tipped black hair, round black-framed "
    "glasses, full black bodysuit covering neck to ankles, barefoot, slight smile). "
    "FRONT VIEW, full body visible head to feet, isolated on PURE WHITE BACKGROUND, "
    "flat solid white background, no shadow, no gradient, sprite cutout style, "
    "T-pose reference sheet for game rigging"
)

POSES = {
    "apose": (
        "A-pose, arms angled down at 45 degrees away from body, hands open palms "
        "visible, legs slightly apart hip-width, feet flat, head straight forward, "
        "neutral expression, every limb fully separated from torso",
        4242
    ),
    "tpose": (
        "T-pose, arms straight out horizontally to the sides forming a perfect T, "
        "palms facing down, legs slightly apart hip-width, feet flat, head straight "
        "forward, neutral expression, every limb fully separated from torso",
        4343
    ),
}


def build_url(prompt: str, seed: int) -> str:
    full = f"{CHAR}. Pose: {prompt}."
    enc = urllib.parse.quote(full, safe="")
    params = urllib.parse.urlencode({
        "model":  MODEL,
        "image":  ANCHOR_URL,
        "width":  W,
        "height": H,
        "seed":   seed,
        "nologo": "true",
        "private": "true",
    })
    return f"{ENDPOINT}{enc}?{params}"


def fetch(url: str, token: str) -> bytes:
    req = urllib.request.Request(url, headers={
        "User-Agent": "great-fireball-art-director",
        "Authorization": f"Bearer {token}",
    })
    with urllib.request.urlopen(req, timeout=240) as r:
        ct = r.headers.get("Content-Type", "")
        data = r.read()
    if "image" not in ct:
        raise RuntimeError(f"resposta nao-imagem ({ct}): {data[:160]!r}")
    return data


def gen(pose_key: str, token: str) -> Path:
    prompt, seed = POSES[pose_key]
    url = build_url(prompt, seed)
    print(f"-> {pose_key}  seed={seed}")
    print(f"   {url[:120]}...")
    data = fetch(url, token)
    out = CONCEPT / f"soph_base_{pose_key}.png"
    out.write_bytes(data)
    # tambem salva uma versao convertida pra RGBA (sem alpha ainda — so pra padronizar)
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    im.save(out)
    print(f"   ok {out}  ({len(data)} bytes, {im.size})")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tpose", action="store_true", help="tambem gera T-pose")
    ap.add_argument("--only-tpose", action="store_true", help="gera so a T-pose")
    args = ap.parse_args()
    token = os.environ.get("POLLINATIONS_TOKEN", "")
    if not token:
        print("x defina POLLINATIONS_TOKEN"); return 1
    if args.only_tpose:
        gen("tpose", token); return 0
    gen("apose", token)
    if args.tpose:
        gen("tpose", token)
    return 0


if __name__ == "__main__":
    sys.exit(main())
