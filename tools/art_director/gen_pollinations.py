#!/usr/bin/env python3
"""
gen_pollinations.py — GERA imagem com a Pollinations.ai.

É o "motor" do óculos para arte de fonte real. Usa a API NOVA
(gen.pollinations.ai), que exige uma chave gratuita criada em
https://enter.pollinations.ai — exportada como POLLINATIONS_TOKEN (ou
passada em --token). O host antigo (image.pollinations.ai) virou "legacy"
e responde 402 em IP compartilhado de cloud, então não serve daqui.

Hosts necessários na allowlist de rede do ambiente (Network access:
Custom/Full no claude.ai/code): gen.pollinations.ai. A política de rede é
fixada no início da sessão — depois de mudar, iniciar sessão NOVA.

Uso:
    python tools/art_director/gen_pollinations.py "<prompt>" <saida.jpg> \
        [largura] [altura] [seed] [modelo] [--token sk_...]

Ex.:
    python tools/art_director/gen_pollinations.py \
        "anime sorceress Soph, pointed mage hat, glasses, staff" /tmp/soph.jpg 768 1024
"""
from __future__ import annotations
import os, sys, urllib.parse, urllib.request
from pathlib import Path

BASE = "https://gen.pollinations.ai/image/"

def generate(prompt: str, out: str, width: int = 768, height: int = 1024,
             seed: int = 7, model: str = "flux", token: str | None = None) -> int:
    token = token or os.environ.get("POLLINATIONS_TOKEN") \
                  or os.environ.get("POLLINATIONS_API_KEY")
    if not token:
        print("✗ falta a chave: defina POLLINATIONS_TOKEN (sk_... de "
              "https://enter.pollinations.ai) ou passe --token.")
        return 1
    enc = urllib.parse.quote(prompt, safe="")
    params = urllib.parse.urlencode({
        "width": width, "height": height, "seed": seed, "model": model,
    })
    url = f"{BASE}{enc}?{params}"
    req = urllib.request.Request(url, headers={
        "User-Agent": "great-fireball-art-director",
        "Authorization": f"Bearer {token}",
    })
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            ct = r.headers.get("Content-Type", "")
            data = r.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "ignore")[:200]
        print(f"✗ HTTP {e.code}: {body}")
        if e.code == 403 and "allowlist" in body:
            print("  → Libere 'gen.pollinations.ai' na allowlist do ambiente e "
                  "INICIE UMA SESSÃO NOVA (a política de rede é fixada no início).")
        if e.code in (401, 402):
            print("  → Chave ausente/ inválida? Crie uma sk_ grátis em "
                  "https://enter.pollinations.ai e defina POLLINATIONS_TOKEN.")
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
    args = sys.argv[1:]
    token = None
    if "--token" in args:
        i = args.index("--token")
        token = args[i + 1]
        del args[i:i + 2]
    if len(args) < 2:
        print("uso: gen_pollinations.py \"<prompt>\" <saida> [w] [h] [seed] [model] [--token sk_...]")
        return 2
    prompt = args[0]
    out = args[1]
    w = int(args[2]) if len(args) > 2 else 768
    h = int(args[3]) if len(args) > 3 else 1024
    seed = int(args[4]) if len(args) > 4 else 7
    model = args[5] if len(args) > 5 else "flux"
    return generate(prompt, out, w, h, seed, model, token)

if __name__ == "__main__":
    sys.exit(main())
