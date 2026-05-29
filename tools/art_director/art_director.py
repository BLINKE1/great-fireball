#!/usr/bin/env python3
"""
art_director.py — Óculos do Claude: loop de feedback visual para geração de sprites.

Fluxo:
  1. Executa generator.py  → PIL Image 32×64
  2. Envia imagem + código para Claude API (visão)
  3. Recebe: crítica textual + código melhorado
  4. Salva iteração e substitui generator.py
  5. Repete até score >= TARGET_SCORE ou --iterations atingido

Uso:
    python art_director.py [--iterations N] [--score S] [--out pasta]

Requer:
    ANTHROPIC_API_KEY no ambiente
    pip install anthropic pillow
"""

import anthropic
import argparse
import base64
import importlib.util
import json
import os
import re
import shutil
import sys
import textwrap
from datetime import datetime
from io import BytesIO
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Instale Pillow: pip install pillow")

# ── Configuração ──────────────────────────────────────────────────────────────

HERE        = Path(__file__).parent
GEN_FILE    = HERE / "generator.py"
OUT_DIR     = HERE / "iterations"
FINAL_DIR   = Path(__file__).parent.parent.parent / "assets" / "sprites" / "player"
MODEL       = "claude-sonnet-4-6"
ZOOM        = 6   # zoom para revisão visual

GOAL = """\
PERSONAGEM: Soph — protagonista de um RPG plataformer 2D de fantasia.

APARÊNCIA CANÔNICA:
- Jovem maga (aparenta ~17-20 anos), estatura média-baixa, feminina
- Cabelo AZUL médio, levemente ondulado, cai até o pescoço/ombros
  (o cabelo azul é a marca visual mais importante — deve ser inconfundível)
- Robe de maga: roxo escuro (#3C1A6E) com detalhes dourados na faixa/cinto
  O robe é midi (vai até metade da canela), levemente acinturado
- Botas de couro marrom escuro, simples
- Olhos grandes e expressivos (traço de anime/chibi)
- Expressão curiosa/determinada, não agressiva

NARRATIVA (influencia o visual):
  Soph NUNCA aprenderá Fireball — essa é a magia proibida do jogo.
  Ela é irmã mais nova de dois guerreiros (cavaleiro e ladino) mas escolheu a magia.
  Começa presa numa Torre e escapa com Air Hike (salto duplo mágico).
  É admiradora do Mago Graduado misterioso que usa a Grande Bola de Fogo.
  Personalidade: corajosa mas ainda aprendendo, levemente ingênua, curioso.

REQUISITOS TÉCNICOS:
- Canvas: 32×64 pixels, RGBA, fundo 100% transparente
- Vista lateral para plataformer (virada para a DIREITA)
- Pose: idle em pé, natural — pé direito levemente avançado ou peso numa perna
- Pixel art — sem anti-aliasing nas bordas, paleta limitada (~12-16 cores)
- Outline escuro (1px) em toda a silhueta para legibilidade
- Cabeça ~16px de altura (proporção levemente chibi), corpo ~48px
- O cabelo azul deve ocupar espaço visível e ter destaque real no topo"""

CRITIQUE_PROMPT = """\
Você é um art director sênior de pixel art para jogos 2D, especialista em sprites \
de personagens para plataformer. Está revisando um sprite iterativamente.

══ PERSONAGEM-ALVO ══════════════════════════════════════════════
{goal}
═════════════════════════════════════════════════════════════════

CANVAS REAL: 32×64 px, RGBA transparente. A imagem abaixo está {zoom}× aumentada.
IMPORTANTE: julgue o sprite considerando que será visto na tela no tamanho REAL (32×64).
Legibilidade em tamanho pequeno é mais importante do que detalhes finos.

CÓDIGO ATUAL (iteração {iteration}):
```python
{code}
```

CHECKLIST DE AVALIAÇÃO — analise cada ponto:
1. SILHUETA: reconhece imediatamente como "maga feminina" em 32×64?
2. CABELO AZUL: visível e distinto? É a marca visual #1 da Soph
3. ROBE: lê como roupa mágica/fantasia, não como vestido comum?
4. PROPORÇÕES: cabeça ~1/4 do corpo? Pernas visíveis abaixo do robe?
5. OUTLINE: bordas têm 1px escuro separando a figura do fundo?
6. PALETA: cores limpas, contraste suficiente entre regiões?
7. POSE: natural, em pé, virada para a direita?
8. PIXEL ART: sem gradientes difusos, pixels intencionais?

Responda com JSON puro (sem markdown, sem texto fora do JSON):
{{
  "critique": "análise específica e honesta de cada ponto do checklist",
  "issues": [
    "problema concreto com coordenadas ou cores específicas",
    "..."
  ],
  "score": <inteiro 0-10>,
  "score_breakdown": {{
    "silhueta": <0-10>,
    "cabelo_azul": <0-10>,
    "proporcoes": <0-10>,
    "outline": <0-10>,
    "leitura_fantasía": <0-10>
  }},
  "improved_code": "<código Python COMPLETO e executável, com todos os imports>"
}}

REGRAS PARA improved_code:
- Python completo com imports no topo
- Define generate() -> PIL.Image  (exatamente 32×64, RGBA, fundo transparente)
- Cada melhoria deve ser justificada pelas issues listadas
- Mantenha o que já está funcionando — não regride o que está bom
- Coordenadas precisas: desenhe na grade 32×64, cada pixel deliberado
- Outline: toda borda da silhueta com 1px escuro
- Cabelo azul: mínimo 4×10 px visíveis no topo/costas do crânio
- NÃO adicione detalhes que não leem bem em 32×64 real"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_generator() -> str:
    return GEN_FILE.read_text(encoding="utf-8")


def run_generator(code: str) -> Image.Image:
    """Executa o código de geração e retorna a PIL Image."""
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
    w, h = img.size
    return img.resize((w * scale, h * scale), Image.NEAREST)


def to_base64_png(img: Image.Image) -> str:
    buf = BytesIO()
    img.save(buf, format="PNG")
    return base64.standard_b64encode(buf.getvalue()).decode()


def add_label(img: Image.Image, text: str) -> Image.Image:
    """Adiciona legenda embaixo da imagem."""
    label_h = 18
    result = Image.new("RGBA", (img.width, img.height + label_h), (25, 25, 25, 255))
    result.paste(img, (0, 0))
    draw = ImageDraw.Draw(result)
    draw.text((4, img.height + 2), text, fill=(200, 200, 200, 255))
    return result


def save_iteration(img: Image.Image, iteration: int, score: int, critique: str) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    label = f"iter {iteration:02d}  score {score}/10"
    annotated = add_label(zoom_image(img), label)
    path = OUT_DIR / f"iter_{iteration:02d}_score{score}.png"
    annotated.save(path)
    return path


def make_progress_strip(images: list[Image.Image], scores: list[int]) -> Image.Image:
    """Cria tira horizontal com todas as iterações."""
    zoom = ZOOM
    w, h = 32 * zoom, 64 * zoom + 18
    strip = Image.new("RGBA", (w * len(images), h), (25, 25, 25, 255))
    for i, (img, score) in enumerate(zip(images, scores)):
        frame = add_label(zoom_image(img, zoom), f"#{i}  {score}/10")
        strip.paste(frame, (i * w, 0))
    return strip


def extract_json(text: str) -> dict:
    """Extrai JSON da resposta, tolerando markdown fences."""
    text = text.strip()
    # Remove fences
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return json.loads(text)


# ── Core ──────────────────────────────────────────────────────────────────────

def iterate(client: anthropic.Anthropic, code: str, img: Image.Image,
            iteration: int) -> dict:
    """Envia código + imagem para Claude e retorna o resultado da crítica."""
    prompt = CRITIQUE_PROMPT.format(
        goal=GOAL,
        zoom=ZOOM,
        code=code,
        iteration=iteration,
    )
    response = client.messages.create(
        model=MODEL,
        max_tokens=8192,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/png",
                        "data": to_base64_png(zoom_image(img)),
                    },
                },
                {"type": "text", "text": prompt},
            ],
        }],
    )
    return extract_json(response.content[0].text)


def export_final(img: Image.Image) -> None:
    """Salva o sprite final em assets/sprites/player/soph_idle_0.png"""
    FINAL_DIR.mkdir(parents=True, exist_ok=True)
    # Backup do original
    dest = FINAL_DIR / "soph_idle_0.png"
    if dest.exists():
        backup = FINAL_DIR / f"soph_idle_0_backup_{datetime.now():%H%M%S}.png"
        shutil.copy(dest, backup)
        print(f"  Backup salvo em {backup.name}")
    img.save(dest)
    print(f"  Sprite final → {dest}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="Art Director — feedback visual para sprites")
    parser.add_argument("--iterations", type=int, default=5,
                        help="Número máximo de iterações (padrão: 5)")
    parser.add_argument("--score",      type=int, default=8,
                        help="Score mínimo para parar (padrão: 8/10)")
    parser.add_argument("--api-key",    type=str, default=None,
                        help="Anthropic API key (ou use ANTHROPIC_API_KEY no env / .env)")
    parser.add_argument("--dry-run",    action="store_true",
                        help="Apenas gera a primeira imagem, sem chamar a API")
    args = parser.parse_args()

    # Tenta carregar .env local
    env_file = HERE / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("ANTHROPIC_API_KEY="):
                os.environ["ANTHROPIC_API_KEY"] = line.split("=", 1)[1].strip().strip('"')

    api_key = args.api_key or os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.dry_run:
        print("\nPrecisa de uma ANTHROPIC_API_KEY. Três opções:")
        print("  1. Argumento:  python art_director.py --api-key sk-ant-...")
        print("  2. Env var:    export ANTHROPIC_API_KEY=sk-ant-...")
        print(f"  3. Arquivo:    echo 'ANTHROPIC_API_KEY=sk-ant-...' > {env_file}")
        sys.exit(1)

    client = anthropic.Anthropic(api_key=api_key) if not args.dry_run else None

    print(f"\n{'='*60}")
    print("  Art Director — geração iterativa com feedback visual")
    print(f"  Modelo : {MODEL}")
    print(f"  Meta   : score >= {args.score}/10  |  máx {args.iterations} iterações")
    print(f"{'='*60}\n")

    code  = load_generator()
    all_images: list[Image.Image] = []
    all_scores: list[int]         = []

    for i in range(args.iterations):
        print(f"── Iteração {i} {'─'*40}")

        # Gera imagem atual
        try:
            img = run_generator(code)
        except Exception as e:
            print(f"  ERRO ao executar generator.py: {e}")
            break

        all_images.append(img.copy())

        if args.dry_run:
            path = OUT_DIR / "dry_run.png"
            OUT_DIR.mkdir(parents=True, exist_ok=True)
            zoom_image(img).save(path)
            print(f"  Dry-run: imagem salva em {path}")
            break

        # Critique via API
        print("  Enviando para Claude...")
        try:
            result = iterate(client, code, img, i)
        except json.JSONDecodeError as e:
            print(f"  JSON inválido na resposta: {e}")
            break
        except Exception as e:
            print(f"  Erro na API: {e}")
            break

        score    = int(result.get("score", 0))
        critique = result.get("critique", "")
        issues   = result.get("issues", [])
        new_code = result.get("improved_code", "")

        all_scores.append(score)

        # Log
        print(f"  Score   : {score}/10")
        print(f"  Crítica : {critique[:120]}...")
        if issues:
            for issue in issues[:4]:
                print(f"    • {issue}")

        # Salva iteração
        save_iteration(img, i, score, critique)
        print(f"  Salvo   : iterations/iter_{i:02d}_score{score}.png")

        # Atualiza generator.py
        if new_code.strip():
            GEN_FILE.write_text(new_code, encoding="utf-8")
            code = new_code
            print("  generator.py atualizado ✓")
        else:
            print("  Nenhum código novo recebido — mantendo anterior")

        # Para se score suficiente
        if score >= args.score:
            print(f"\n  Score {score} >= meta {args.score} — concluído! ✓")
            break

        print()

    # Salva tira de progresso
    if len(all_images) > 1:
        strip = make_progress_strip(all_images, all_scores or [0] * len(all_images))
        strip_path = OUT_DIR / "progress_strip.png"
        strip.save(strip_path)
        print(f"\n  Tira de progresso → {strip_path}")

    # Exporta sprite final
    if all_images and not args.dry_run:
        export_final(all_images[-1])

    print(f"\n{'='*60}")
    print("  Concluído.")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    main()
