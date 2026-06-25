#!/usr/bin/env python3
"""gen_goblin_concept.py — GERA a 3/4 conceitual do goblin basal via img2img.

Âncora = recorte do goblin "prospector" (Wayne Reynolds / MTG) que o Will
escolheu. A IA redesenha como ficha de personagem corpo-inteiro, 3/4, MÃOS
VAZIAS (arma = mesh separado depois, regra da Soph). Mesmo motor /v1/images/edits
(modelo gptimage) que travou a identidade da Soph.

Uso:
    POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_goblin_concept.py \
        <anchor.png> <out_dir> [--seeds 7,42] [--model gptimage]
"""
from __future__ import annotations
import os, sys, json, base64, argparse, urllib.request, urllib.error
from pathlib import Path

EDITS = "https://gen.pollinations.ai/v1/images/edits"

PROMPT = (
    "Redraw this Magic the Gathering goblin as a clean full-body character "
    "concept. Three-quarter front view, the ENTIRE body visible from head to "
    "clawed feet, standing in a neutral relaxed pose with EMPTY HANDS — no "
    "weapon, no tool, no staff, open empty clawed hands. Keep the exact art "
    "style and identity of the reference: warm olive yellow-green skin, large "
    "pointed ears, bony spikes on shoulders and back, manic wild expression, "
    "big glowing yellow eyes, fanged open mouth, wiry hunched lean-muscular "
    "goblin, tattered leather straps and scraps of cloth. Painterly Wayne "
    "Reynolds fantasy illustration style, bold confident shapes. Plain neutral "
    "light grey studio background, soft even lighting, no scenery, no other "
    "characters, no text, no card border. Video game enemy character design."
)


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


def edit(image: Path, prompt: str, out: Path, token: str, model: str, seed: int) -> bool:
    body = b""
    body += _part("prompt", prompt)
    body += _part("model", model)
    body += _part("seed", str(seed))
    body += _file_part("image", image)
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
        print(f"  x HTTP {e.code}: {e.read().decode('utf-8','ignore')[:300]}")
        return False
    except Exception as e:
        print(f"  x rede: {type(e).__name__}: {e}")
        return False
    if data[:4] == b"\x89PNG":
        out.write_bytes(data)
    else:
        try:
            j = json.loads(data.decode())
            b64 = j["data"][0].get("b64_json")
            if b64:
                out.write_bytes(base64.b64decode(b64))
            else:
                url = j["data"][0].get("url")
                if not url:
                    print(f"  x resposta sem imagem: {str(j)[:200]}"); return False
                out.write_bytes(urllib.request.urlopen(url, timeout=120).read())
        except Exception as e:
            print(f"  x resposta invalida ({type(e).__name__}): {data[:160]!r}")
            return False
    print(f"  ok {out.name} ({out.stat().st_size} bytes)")
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("anchor")
    ap.add_argument("out_dir")
    ap.add_argument("--seeds", default="7,42")
    ap.add_argument("--model", default="gptimage")
    ap.add_argument("--token", default=None)
    args = ap.parse_args()
    token = args.token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("x defina POLLINATIONS_TOKEN ou passe --token"); return 1
    anchor = Path(args.anchor)
    if not anchor.exists():
        print(f"x falta a ancora: {anchor}"); return 1
    out_dir = Path(args.out_dir); out_dir.mkdir(parents=True, exist_ok=True)
    ok = 0
    for seed in [int(s) for s in args.seeds.split(",") if s.strip()]:
        out = out_dir / f"goblin_concept_s{seed}.png"
        print(f"-> seed={seed} model={args.model}")
        if edit(anchor, PROMPT, out, token, args.model, seed):
            ok += 1
    print(f"\n{ok} imagem(ns) em {out_dir}/")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
