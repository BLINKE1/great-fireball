#!/usr/bin/env python3
"""
gen_pollinations.py — GERA imagem com a Pollinations.ai (GRÁTIS, sem chave).

É o "motor" do óculos para arte de fonte real. Só funciona se o host
'image.pollinations.ai' estiver na ALLOWLIST de rede do ambiente (Network
access: Custom/Full no claude.ai/code). Se não estiver, a Pollinations
responde 403 "Host not in allowlist".

Em ambiente cloud (IP de saída compartilhado) o tier anônimo responde 402
"Queue full for IP" — é preciso um token gratuito de https://enter.pollinations.ai,
exportado como POLLINATIONS_TOKEN (ou passado em --token).

Uso:
    python tools/art_director/gen_pollinations.py "<prompt>" <saida.jpg> \
        [largura] [altura] [seed] [modelo]

Ex.:
    python tools/art_director/gen_pollinations.py \
        "anime sorceress Soph, pointed mage hat, glasses, staff" /tmp/soph.jpg 768 1024
"""
from __future__ import annotations
import os, sys, urllib.parse, urllib.request
from pathlib import Path

BASE = "https://image.pollinations.ai/prompt/"

def generate(prompt: str, out: str, width: int = 768, height: int = 1024,
             seed: int = 7, model: str = "flux", token: str | None = None) -> int:
    enc = urllib.parse.quote(prompt, safe="")
    query = {
        "width": width, "height": height, "seed": seed,
        "model": model, "nologo": "true", "enhance": "true",
    }
    token = token or os.environ.get("POLLINATIONS_TOKEN")
    if token:
        query["token"] = token
    params = urllib.parse.urlencode(query)
    url = f"{BASE}{enc}?{params}"
    headers = {"User-Agent": "great-fireball-art-director"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
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
        if e.code == 402:
            print("  → Tier anônimo bloqueado pro IP compartilhado do ambiente. "
                  "Pegue um token grátis em https://enter.pollinations.ai e "
                  "defina POLLINATIONS_TOKEN no ambiente (env var) — sessão nova pra valer.")
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
        print("uso: gen_pollinations.py \"<prompt>\" <saida> [w] [h] [seed] [model] [--token T]")
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
