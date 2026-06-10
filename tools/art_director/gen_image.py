#!/usr/bin/env python3
"""
gen_image.py — GERA imagem com o Gemini (Nano Banana) a partir de um rascunho.

Diferente do art_director (que CRITICA), este MÃO: manda rascunho + prompt e
recebe uma imagem nova. Usa a GEMINI_API_KEY do .env.

Uso:
    python tools/art_director/gen_image.py <rascunho> <saida.png> "<prompt>"
"""
from __future__ import annotations
import sys, os, base64, json
from pathlib import Path
import requests

HERE = Path(__file__).parent

def load_key() -> str:
    env = HERE / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            if line.startswith("GEMINI_API_KEY"):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ.get("GEMINI_API_KEY", "")

# Modelos de geração de imagem a tentar, em ordem (o 1º que funcionar vence).
MODELS = [
    "gemini-2.5-flash-image",
    "gemini-3.1-flash-image",
    "gemini-3-pro-image-preview",
]

def _retry_delay(data: dict, default: float = 24.0) -> float:
    for v in data.get("error", {}).get("details", []):
        if "RetryInfo" in v.get("@type", ""):
            s = str(v.get("retryDelay", "")).rstrip("s")
            try:
                return float(s) + 2.0
            except ValueError:
                pass
    return default

def main() -> int:
    ref_path, out_path, prompt = sys.argv[1], sys.argv[2], sys.argv[3]
    key = load_key()
    if not key:
        print("✗ sem GEMINI_API_KEY"); return 1

    ref_b64 = base64.standard_b64encode(Path(ref_path).read_bytes()).decode()
    mime = "image/jpeg" if ref_path.lower().endswith((".jpg", ".jpeg")) else "image/png"
    body = {
        "contents": [{"parts": [
            {"text": prompt},
            {"inline_data": {"mime_type": mime, "data": ref_b64}},
        ]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }

    import time
    for model in MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        for attempt in range(3):
            try:
                r = requests.post(url, params={"key": key}, json=body, timeout=120)
            except requests.RequestException as e:
                print(f"  [{model}] rede: {e}"); break
            if r.status_code == 404:
                print(f"  [{model}] 404 (indisponível) — próximo"); break
            if r.status_code == 429:
                wait = _retry_delay(r.json()) if r.headers.get("content-type","").startswith("application/json") else 26.0
                if attempt < 2:
                    print(f"  [{model}] 429 (cota/min) — aguardando {wait:.0f}s e re-tentando…")
                    time.sleep(wait)
                    continue
                print(f"  [{model}] 429 persistente — próximo modelo")
                break
            if r.status_code != 200:
                print(f"  [{model}] HTTP {r.status_code}: {r.text[:200]}"); break
            data = r.json()
            cands = data.get("candidates") or []
            if not cands:
                print(f"  [{model}] sem candidatos: {json.dumps(data)[:200]}"); break
            parts = cands[0].get("content", {}).get("parts", [])
            saved = False
            for p in parts:
                blob = p.get("inlineData") or p.get("inline_data")
                if blob and blob.get("data"):
                    Path(out_path).write_bytes(base64.standard_b64decode(blob["data"]))
                    print(f"✓ imagem salva: {out_path}  (modelo {model})")
                    saved = True
                elif p.get("text"):
                    print(f"  nota do modelo: {p['text'][:200]}")
            if saved:
                return 0
            print(f"  [{model}] resposta sem imagem (finish={cands[0].get('finishReason')})")
            break
    print("✗ nenhum modelo de imagem funcionou")
    return 1

if __name__ == "__main__":
    sys.exit(main())
