#!/usr/bin/env python3
"""
art_director.py — Óculos do Claude: loop de feedback visual para sprites.

Fluxo:
  1. Executa generator.py  → PIL Image 32×64
  2. Envia imagem + código para o motor escolhido (Gemini/Claude/Ollama)
  3. Recebe: crítica + código melhorado
  4. Salva iteração e substitui generator.py
  5. Repete até score >= meta ou --iterations atingido

Uso:
    python art_director.py --engine gemini --api-key AIza...  # FREE
    python art_director.py --engine anthropic --api-key sk-ant-...
    python art_director.py --engine ollama                    # local grátis
    python art_director.py --dry-run                          # sem API

Requer:
    pip install pillow
    pip install google-generativeai   # se --engine gemini
    pip install anthropic             # se --engine anthropic
    pip install ollama                # se --engine ollama
"""

import argparse
import json
import os
import re
import shutil
import sys
from datetime import datetime
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("pip install pillow")

from engines import build_engine, engine_help, ENGINE_KEYS, Engine

# ── Caminhos ──────────────────────────────────────────────────────────────────

HERE     = Path(__file__).parent
GEN_FILE = HERE / "generator.py"
OUT_DIR  = HERE / "iterations"
FINAL_DIR = HERE.parent.parent / "assets" / "sprites" / "player"
ZOOM     = 6

# ── Lore e prompt ─────────────────────────────────────────────────────────────

GOAL = """\
PERSONAGEM: Soph — protagonista de um RPG plataformer 2D de fantasia.

APARÊNCIA CANÔNICA:
- Jovem maga (aparenta ~17-20 anos), estatura média-baixa, feminina
- Cabelo AZUL médio, levemente ondulado, cai até o pescoço/ombros
  (o cabelo azul é a marca visual mais importante — deve ser inconfundível)
- Robe de maga: roxo escuro com detalhes dourados na faixa/cinto
  O robe é midi (vai até metade da canela), levemente acinturado
- Botas de couro marrom escuro, simples
- Olhos grandes e expressivos (traço de anime/chibi)
- Expressão curiosa/determinada

REQUISITOS TÉCNICOS:
- Canvas: 32×64 pixels, RGBA, fundo 100% transparente
- Vista lateral para plataformer (virada para a DIREITA)
- Pose idle natural — peso levemente numa perna
- Pixel art — sem anti-aliasing, paleta limitada (~12-16 cores)
- Outline escuro (1px) em toda a silhueta
- Cabeça ~16px de altura (proporção levemente chibi)
- Cabelo azul deve ocupar espaço visível no topo"""

CRITIQUE_PROMPT = """\
Você é um art director sênior de pixel art para jogos 2D.

══ PERSONAGEM-ALVO ══════════════════════
{goal}
═════════════════════════════════════════

CANVAS REAL: 32×64 px. A imagem está {zoom}× aumentada para revisão.
Julgue pensando no tamanho REAL — legibilidade é prioridade.

CÓDIGO ATUAL (iteração {iteration}):
```python
{code}
```

CHECKLIST:
1. SILHUETA: lê como "maga feminina" em 32×64?
2. CABELO AZUL: visível e distinto? (marca visual #1)
3. ROBE: parece roupa mágica/fantasia?
4. PROPORÇÕES: cabeça ~1/4 do total? Pernas visíveis?
5. OUTLINE: 1px escuro separa figura do fundo?
6. PALETA: contraste limpo entre regiões?
7. PIXEL ART: pixels intencionais, sem blur?

Responda SOMENTE JSON puro (sem markdown):
{{
  "critique": "análise de cada ponto do checklist",
  "issues": ["problema específico com coordenadas ou cores", "..."],
  "score": <0-10>,
  "score_breakdown": {{
    "silhueta": <0-10>,
    "cabelo_azul": <0-10>,
    "proporcoes": <0-10>,
    "outline": <0-10>,
    "leitura_fantasia": <0-10>
  }},
  "improved_code": "<código Python COMPLETO com generate() -> PIL.Image 32×64 RGBA>"
}}"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_env(engine_name: str) -> str | None:
    env_file = HERE / ".env"
    if not env_file.exists():
        return None
    key_name = ENGINE_KEYS.get(engine_name)
    if not key_name:
        return None
    for line in env_file.read_text().splitlines():
        if line.startswith(f"{key_name}="):
            return line.split("=", 1)[1].strip().strip('"')
    return None


def run_generator(code: str) -> Image.Image:
    ns: dict = {}
    exec(compile(code, "<generator>", "exec"), ns)  # noqa: S102
    fn = ns.get("generate")
    if not callable(fn):
        raise RuntimeError("generator.py não define generate()")
    img = fn()
    if not isinstance(img, Image.Image):
        raise RuntimeError("generate() não retornou PIL.Image")
    return img


def zoom_image(img: Image.Image, scale: int = ZOOM) -> Image.Image:
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def add_label(img: Image.Image, text: str) -> Image.Image:
    out = Image.new("RGBA", (img.width, img.height + 18), (25, 25, 25, 255))
    out.paste(img, (0, 0))
    ImageDraw.Draw(out).text((4, img.height + 2), text, fill=(200, 200, 200, 255))
    return out


def save_iteration(img: Image.Image, iteration: int, score: int) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    annotated = add_label(zoom_image(img), f"iter {iteration:02d}  score {score}/10")
    annotated.save(OUT_DIR / f"iter_{iteration:02d}_score{score}.png")


def make_strip(images: list[Image.Image], scores: list[int]) -> Image.Image:
    w, h = 32 * ZOOM, 64 * ZOOM + 18
    strip = Image.new("RGBA", (w * len(images), h), (25, 25, 25, 255))
    for i, (img, score) in enumerate(zip(images, scores)):
        strip.paste(add_label(zoom_image(img), f"#{i}  {score}/10"), (i * w, 0))
    return strip


def extract_json(text: str) -> dict:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$",          "", text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            return json.loads(m.group())
        raise


# ── Core ──────────────────────────────────────────────────────────────────────

def iterate(engine: Engine, code: str, img: Image.Image, iteration: int) -> dict:
    prompt = CRITIQUE_PROMPT.format(
        goal=GOAL, zoom=ZOOM, code=code, iteration=iteration
    )
    text = engine.call(prompt, zoom_image(img))
    return extract_json(text)


def export_final(img: Image.Image) -> None:
    FINAL_DIR.mkdir(parents=True, exist_ok=True)
    dest = FINAL_DIR / "soph_idle_0.png"
    if dest.exists():
        shutil.copy(dest, FINAL_DIR / f"soph_idle_0_bak_{datetime.now():%H%M%S}.png")
    img.save(dest)
    print(f"  Sprite final → {dest}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Art Director — feedback visual iterativo para sprites",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=engine_help(),
    )
    parser.add_argument("--engine",     default="gemini",
                        choices=["gemini", "anthropic", "claude", "ollama"],
                        help="Motor de IA (padrão: gemini — grátis!)")
    parser.add_argument("--api-key",    default=None,
                        help="Chave da API (ou use variável de ambiente / .env)")
    parser.add_argument("--model",      default=None,
                        help="Modelo específico (opcional)")
    parser.add_argument("--iterations", type=int, default=5)
    parser.add_argument("--score",      type=int, default=8,
                        help="Score mínimo para parar (padrão: 8/10)")
    parser.add_argument("--dry-run",    action="store_true",
                        help="Só gera a imagem, sem chamar a API")
    args = parser.parse_args()

    # Carrega chave: argumento > .env > variável de ambiente
    api_key = (args.api_key
               or load_env(args.engine)
               or os.environ.get(ENGINE_KEYS.get(args.engine, "") or ""))

    if not api_key and args.engine not in ("ollama",) and not args.dry_run:
        key_var = ENGINE_KEYS.get(args.engine, "API_KEY")
        env_file = HERE / ".env"
        print(f"\nPrecisa de uma chave para o motor '{args.engine}'.")
        print(engine_help())
        print(f"Coloque a chave em {env_file}:")
        print(f"  echo '{key_var}=SUA_CHAVE' > {env_file}")
        sys.exit(1)

    print(f"\n{'═'*58}")
    print(f"  Art Director  |  motor: {args.engine}  |  meta: {args.score}/10")
    print(f"{'═'*58}\n")

    engine = None if args.dry_run else build_engine(args.engine, api_key, args.model)

    code        = GEN_FILE.read_text(encoding="utf-8")
    all_images  : list[Image.Image] = []
    all_scores  : list[int]         = []

    for i in range(args.iterations):
        print(f"── Iteração {i} {'─'*38}")
        try:
            img = run_generator(code)
        except Exception as e:
            print(f"  ERRO no generator: {e}"); break

        all_images.append(img.copy())

        if args.dry_run:
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            zoom_image(img).save(OUT_DIR / "dry_run.png")
            print(f"  Dry-run → {OUT_DIR / 'dry_run.png'}"); break

        print(f"  Enviando para {args.engine}...", end=" ", flush=True)
        try:
            result = iterate(engine, code, img, i)
        except Exception as e:
            print(f"\n  Erro: {e}"); break

        score    = int(result.get("score", 0))
        critique = result.get("critique", "")
        new_code = result.get("improved_code", "")
        all_scores.append(score)

        print(f"score {score}/10")
        print(f"  {critique[:110]}...")
        for issue in result.get("issues", [])[:3]:
            print(f"    • {issue}")

        save_iteration(img, i, score)

        if new_code.strip():
            GEN_FILE.write_text(new_code, encoding="utf-8")
            code = new_code
            print("  generator.py atualizado ✓")

        if score >= args.score:
            print(f"\n  Score {score} ≥ {args.score} — concluído! ✓"); break
        print()

    if len(all_images) > 1:
        strip = make_strip(all_images, all_scores or [0] * len(all_images))
        strip.save(OUT_DIR / "progress_strip.png")
        print(f"\n  Progress strip → {OUT_DIR / 'progress_strip.png'}")

    if all_images and not args.dry_run:
        export_final(all_images[-1])

    print(f"\n{'═'*58}\n  Concluído.\n{'═'*58}\n")


if __name__ == "__main__":
    main()
