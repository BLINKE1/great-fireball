#!/usr/bin/env python3
"""
gen_pollinations.py — GERA imagem com a Pollinations.ai (GRÁTIS, sem chave).

É o "motor" do óculos para arte de fonte real, sem API key nem cadastro. Só
funciona se o host 'image.pollinations.ai' estiver na ALLOWLIST de rede do
ambiente (Network access: Custom/Full no claude.ai/code). Se não estiver, a
Pollinations responde 403 "Host not in allowlist".

Uso:
    python tools/art_director/gen_pollinations.py "<prompt>" <saida.jpg> \
        [largura] [altura] [seed] [modelo]

Ex.:
    python tools/art_director/gen_pollinations.py \
        "anime sorceress Soph, pointed mage hat, glasses, staff" /tmp/soph.jpg 768 1024
"""
from __future__ import annotations
import sys, urllib.parse, urllib.request
from pathlib import Path

BASE = "https://image.pollinations.ai/prompt/"

def generate(prompt: str, out: str, width: int = 768, height: int = 1024,
             seed: int = 7, model: str = "flux") -> int:
    enc = urllib.parse.quote(prompt, safe="")
    params = urllib.parse.urlencode({
        "width": width, "height": height, "seed": seed,
        "model": model, "nologo": "true", "enhance": "true",
    })
    url = f"{BASE}{enc}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "great-fireball-art-director"})
    try:
        with urllib.request.urlopen(req, timeout=150) as r:
            ct = r.headers.get("Content-Type", "")
            data = r.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "ignore")[:200]
        print(f"✗ HTTP {e.code}: {body}")
        if e.code == 403 and "allowlist" in body:
            print("  → Libere 'image.pollinations.ai' na allowlist do ambiente e "
                  "INICIE UMA SESSÃO NOVA (a política de rede é fixada no início).")
        return 1
    except Exception as e:
        print(f"✗ rede: {type(e).__name__}: {e}")
        return 1
    if "image" not in ct:
        print(f"✗ resposta não-imagem ({ct}): {data[:160]!r}")
        return 1
    Path(out).write_bytes(data)
    print(f"✓ imagem salva: {out}  ({len(data)} bytes, {width}x{height}, modelo {model})")
    return 0

def main() -> int:
    if len(sys.argv) < 3:
        print("uso: gen_pollinations.py \"<prompt>\" <saida> [w] [h] [seed] [model]")
        return 2
    prompt = sys.argv[1]
    out = sys.argv[2]
    w = int(sys.argv[3]) if len(sys.argv) > 3 else 768
    h = int(sys.argv[4]) if len(sys.argv) > 4 else 1024
    seed = int(sys.argv[5]) if len(sys.argv) > 5 else 7
    model = sys.argv[6] if len(sys.argv) > 6 else "flux"
    return generate(prompt, out, w, h, seed, model)

if __name__ == "__main__":
    sys.exit(main())
