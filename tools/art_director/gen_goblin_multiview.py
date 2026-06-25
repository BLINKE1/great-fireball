#!/usr/bin/env python3
"""gen_goblin_multiview.py — vistas FRENTE (A-pose) + LADO + COSTAS do goblin
basal, ancoradas no concept oficial (docs/concept_art/goblin/goblin_base_ref.png),
pra alimentar gerador 3D MULTIVIEW (Hunyuan/Tripo). Mesmo motor da Soph.

O concept base esta numa pose 3/4 curvada; aqui a gente "endireita" pra uma
A-POSE simetrica de mãos vazias e tira as 3 vistas do MESMO bicho, fundo branco.

Uso:
  POLLINATIONS_TOKEN=sk_... python tools/art_director/gen_goblin_multiview.py \
      [--views front,side,back] [--seeds 7,42] [--model gptimage]
"""
from __future__ import annotations
import os, sys, json, base64, argparse, urllib.request, urllib.error
from pathlib import Path

ROOT    = Path(__file__).parent.parent.parent
ANCHOR  = ROOT / "docs" / "concept_art" / "goblin" / "goblin_base_ref.png"
OUT     = ROOT / "tools" / "art_director" / "iterations" / "goblin" / "multiview"
EDITS   = "https://gen.pollinations.ai/v1/images/edits"

KEEP = (
    "IDENTICAL creature as the reference image: same Magic-the-Gathering style "
    "goblin, same warm olive yellow-green skin with reddish-brown shadows, same "
    "large pointed ears, same manic fanged face, same big yellow eyes, same bony "
    "spikes on shoulders and back, same wiry lean-muscular scrawny build, same "
    "tattered leather straps and ragged cloth scraps, same big clawed hands and "
    "feet. EMPTY open hands, no weapon. FULL BODY head to clawed feet, isolated "
    "on PURE FLAT WHITE background, no shadow, no gradient, clean orthographic "
    "reference-sheet cutout for 3D, painterly Wayne Reynolds illustration."
)

VIEWS = {
    "front": (
        "FRONT view of the goblin, standing UPRIGHT and facing the viewer in a "
        "symmetric relaxed A-POSE: both arms held slightly away from the body, "
        "legs straight, looking straight ahead. Less hunched than the reference, "
        "calm neutral standing reference pose. " + KEEP
    ),
    "side": (
        "SIDE PROFILE view of the goblin, facing to the RIGHT (90-degree side "
        "view), standing upright in the same relaxed A-pose, feet pointing RIGHT "
        "in profile. " + KEEP
    ),
    # NOTA: o safety do Azure (gptimage) recusa "from BEHIND / back of the legs".
    # Esta redacao mais neutra ("turned around, shows its back") passa.
    "back": (
        "REAR view: the goblin has turned around and shows its back to us, the "
        "head is turned away looking forward, we see the back of the skull, the "
        "back of the two large pointed ears, the dark hair crest, the bony spikes "
        "running down the spine, the back of the tunic and the tail of cloth, "
        "standing upright in a calm symmetric A-pose. " + KEEP
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


def edit(prompt: str, out: Path, token: str, model: str, seed: int, anchor: Path) -> bool:
    body = _part("prompt", prompt) + _part("model", model) + _part("seed", str(seed))
    body += _file_part("image", anchor) + b"--B--\r\n"
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
    ap.add_argument("--views", default="front,side,back")
    ap.add_argument("--seeds", default="7,42")
    ap.add_argument("--model", default="gptimage")
    ap.add_argument("--anchor", default=None, help="imagem-ancora (default: concept base)")
    ap.add_argument("--token", default=None)
    args = ap.parse_args()
    token = args.token or os.environ.get("POLLINATIONS_TOKEN")
    if not token:
        print("x defina POLLINATIONS_TOKEN"); return 1
    anchor = Path(args.anchor) if args.anchor else ANCHOR
    if not anchor.exists():
        print(f"x falta a ancora: {anchor}"); return 1
    OUT.mkdir(parents=True, exist_ok=True)
    seeds = [int(s) for s in args.seeds.split(",") if s.strip()]
    views = [v.strip() for v in args.views.split(",") if v.strip() in VIEWS]
    ok = 0
    for v in views:
        for seed in seeds:
            out = OUT / f"goblin_{v}_s{seed}.png"
            print(f"-> {v}  seed={seed}  model={args.model}")
            if edit(VIEWS[v], out, token, args.model, seed, anchor):
                ok += 1
    print(f"\n{ok} vista(s) em {OUT}/")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
