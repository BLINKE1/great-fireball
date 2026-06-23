#!/usr/bin/env python3
"""
gen_soph_multiview.py — gera vistas LADO + COSTAS da Soph T-pose vestida,
ancoradas na FRENTE oficial (docs/concept_art/soph_tpose_robe.png), pra
alimentar geradores 3D MULTIVIEW (ex.: Tencent Hunyuan 3D).

A frente a gente ja tem. Aqui saem as outras vistas, MESMO personagem/roupa,
mesma T-pose, fundo branco — pra montar o set multiview (front/side/back).

IMPORTANTE: Soph e MAGA/sorceress, nunca "bruxa"/"witch". Chapeu de maga.

Uso:
  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_soph_multiview.py [--seeds 7,42] [--views side,back]
"""
from __future__ import annotations
import os, sys, json, base64, argparse, urllib.request, urllib.error
from pathlib import Path

ROOT    = Path(__file__).parent.parent.parent
CONCEPT = ROOT / "docs" / "concept_art"
OUT     = ROOT / "tools" / "art_director" / "iterations" / "robe_tpose" / "multiview"
EDITS   = "https://gen.pollinations.ai/v1/images/edits"
FRONT   = CONCEPT / "soph_tpose_robe.png"

KEEP = (
    "IDENTICAL character and outfit as the reference image: same young SORCERESS "
    "/ MAGE (never a witch), same slim TALL proportions, same dark purple-trimmed "
    "open mage robe over black bodysuit, same pointed MAGE hat, same round glasses, "
    "same long black hair with glowing blue-teal mana tips, same brown boots. "
    "Perfect symmetric T-POSE: both arms straight out horizontally forming a T. "
    "FULL BODY head to feet, isolated on PURE FLAT WHITE background, no shadow, no "
    "gradient, clean orthographic reference-sheet cutout for 3D, anime flat cel shading."
)

VIEWS = {
    "side": (
        "SIDE PROFILE view of the character, facing to the RIGHT (90-degree side "
        "view), seen exactly from the side. " + KEEP
    ),
    "back": (
        "BACK view of the character, seen directly from BEHIND (back of the head, "
        "back of the mage hat, back of the robe and the long hair down the back). "
        "Face NOT visible. " + KEEP
    ),
}


def _part(name: str, value: str) -> bytes:
    return (b"--B\r\n" +
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode() +
            f"{value}\r\n".encode())


def _file_part(name: str, path: Path) -> bytes:
    return (b"--B\r\n" +
            f'Content-Disposition: form-data; name="{name}"; filename="{path.name}"\r\n'.encode() +
            b"Content-Type: image/png\r\n\r\n" + path.read_bytes() + b"\r\n")


def edit(prompt: str, out: Path, token: str, model: str, seed: int) -> bool:
    body = _part("prompt", prompt) + _part("model", model) + _part("seed", str(seed))
    body += _file_part("image", FRONT) + b"--B--\r\n"
    req = urllib.request.Request(EDITS, data=body, method="POST", headers={
        "Content-Type": "multipart/form-data; boundary=B",
        "Authorization": f"Bearer {token}",
        "User-Agent": "great-fireball-art-director",
    })
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
    except urllib.error.HTTPError as e:
        print(f"  x HTTP {e.code}: {e.read().decode('utf-8','ignore')[:200]}"); return False
    except Exception as e:
        print(f"  x rede: {type(e).__name__}: {e}"); return False
    if data[:4] == b"\x89PNG":
        out.write_bytes(data)
    else:
        try:
            j = json.loads(data.decode()); b64 = j["data"][0].get("b64_json")
            out.write_bytes(base64.b64decode(b64))
        except Exception as e:
            print(f"  x resposta invalida ({type(e).__name__}): {data[:160]!r}"); return False
    print(f"  ok {out.name} ({out.stat().st_size} bytes)"); return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", default="7,42")
    ap.add_argument("--views", default="side,back")
    ap.add_argument("--model", default="gptimage")
    ap.add_argument("--token", default=None)
    args = ap.parse_args()
    token = args.token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("x defina POLLINATIONS_TOKEN"); return 1
    if not FRONT.exists():
        print(f"x falta a frente: {FRONT}"); return 1
    OUT.mkdir(parents=True, exist_ok=True)
    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]
    views = [v.strip() for v in args.views.split(",") if v.strip() in VIEWS]
    ok = 0
    for v in views:
        for seed in seeds:
            out = OUT / f"soph_tpose_robe_{v}_s{seed}.png"
            print(f"-> {v}  seed={seed}  model={args.model}")
            if edit(VIEWS[v], out, token, args.model, seed):
                ok += 1
    print(f"\n{ok} vista(s) geradas em {OUT}/")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
