#!/usr/bin/env python3
"""
run_all.py — Orquestrador autônomo completo de sprites da Soph.

Fases (sem intervenção humana):
  1. Refina soph_idle_0 até score ≥ TARGET  (loop de visão)
  2. Extrai paleta e proporções do frame aprovado  (style lock)
  3. Gera cada frame de animação com estilo travado
  4. Salva todos em assets/sprites/player/
  5. Gera preview strip completa
  6. Auto-commit no git  (opcional: --no-commit para pular)

Uso:
    python run_all.py [--score N] [--base-iter N] [--pose-iter N] [--no-commit]

Requer:
    ANTHROPIC_API_KEY no ambiente ou tools/art_director/.env
    pip install anthropic pillow gitpython
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime
from io import BytesIO
from pathlib import Path

from engines import build_engine, engine_help, ENGINE_KEYS, Engine

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("pip install pillow")

# ── Caminhos ──────────────────────────────────────────────────────────────────

HERE       = Path(__file__).parent
GEN_FILE   = HERE / "generator.py"
OUT_DIR    = HERE / "iterations"
REPO_ROOT  = HERE.parent.parent
SPRITE_DIR = REPO_ROOT / "assets" / "sprites" / "player"
ZOOM       = 6

# ── Definição de todos os frames ─────────────────────────────────────────────

FRAMES = [
    # (nome_base, índice, descrição da pose)
    ("idle",  0, "Idle frame 0: postura natural em pé, peso levemente na perna direita"),
    ("idle",  1, "Idle frame 1: exatamente igual ao idle_0 mas +1px mais alta (respiração)"),
    ("walk",  0, "Walk frame 0: pernas na posição neutra, braços ao lado"),
    ("walk",  1, "Walk frame 1: perna direita avançada, braço esquerdo avançado (oposto)"),
    ("walk",  2, "Walk frame 2: posição neutra passagem, leve bob para baixo"),
    ("walk",  3, "Walk frame 3: perna esquerda avançada, braço direito avançado"),
    ("walk",  4, "Walk frame 4: posição neutra passagem, leve bob para baixo"),
    ("walk",  5, "Walk frame 5: igual walk_0 mas corpo levemente inclinado para frente"),
    ("run",   0, "Run frame 0: neutro, corpo inclinado +3px para frente"),
    ("run",   1, "Run frame 1: perna direita muito avançada, braço esquerdo alto"),
    ("run",   2, "Run frame 2: neutro inclinado"),
    ("run",   3, "Run frame 3: perna esquerda muito avançada, braço direito alto"),
    ("jump",  0, "Jump: braços levantados acima da cabeça, joelhos dobrados para frente"),
    ("fall",  0, "Fall: braços abertos em V para baixo, pernas estendidas e abertas"),
    ("hurt",  0, "Hurt: corpo inclinado para trás, um braço bloqueando o rosto, expressão de dor"),
]

# ── Prompt de geração de pose ─────────────────────────────────────────────────

POSE_PROMPT = """\
Você é um pixel artist gerando frames de animação para o sprite da Soph.

══ STYLE LOCK — USE EXATAMENTE ESTAS CORES ════════════════════════
{palette_block}
════════════════════════════════════════════════════════════════════

FRAME BASE APROVADO (idle_0, score {base_score}/10):
```python
{base_code}
```

FRAME A GERAR: {frame_key}
DESCRIÇÃO DA POSE: {pose_desc}

REGRAS:
- Canvas: 32×64 px, RGBA, fundo transparente
- Mantenha EXATAMENTE as cores do style lock acima
- Modifique APENAS as posições de braços, pernas e corpo para a pose descrita
- Mantenha cabeça, cabelo, robe e botas idênticos ao frame base
- Outline 1px escuro em toda a silhueta
- Retorne JSON puro (sem markdown):
{{
  "code": "<código Python completo com generate() -> PIL.Image>"
}}"""

REFINE_PROMPT = """\
Você é um art director de pixel art revisando o frame {frame_key} da Soph.

POSE ESPERADA: {pose_desc}

STYLE LOCK — cores obrigatórias:
{palette_block}

CÓDIGO ATUAL:
```python
{code}
```

A imagem está {zoom}× aumentada. Responda JSON puro:
{{
  "score": <0-10>,
  "critique": "o que está certo e errado na pose",
  "issues": ["issue 1", ...],
  "improved_code": "<código completo corrigido>"
}}"""

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_env() -> str | None:
    env_file = HERE / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("ANTHROPIC_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"')
    return None


def to_b64(img: Image.Image, zoom: int = ZOOM) -> str:
    w, h = img.size
    zoomed = img.resize((w * zoom, h * zoom), Image.NEAREST)
    buf = BytesIO()
    zoomed.save(buf, format="PNG")
    return base64.standard_b64encode(buf.getvalue()).decode()


def run_code(code: str) -> Image.Image:
    ns: dict = {}
    exec(compile(code, "<gen>", "exec"), ns)  # noqa: S102
    img = ns["generate"]()
    assert isinstance(img, Image.Image) and img.size == (32, 64), \
        f"generate() deve retornar PIL.Image 32×64, recebeu {type(img)} {getattr(img,'size','?')}"
    return img


def extract_json(text: str) -> dict:
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    # Tenta direto, se falhar procura o primeiro { ... }
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", text, re.DOTALL)
        if m:
            return json.loads(m.group())
        raise


def extract_palette(img: Image.Image) -> dict:
    """Extrai as cores dominantes de regiões-chave do frame aprovado."""
    px = img.load()
    regions = {
        "hair":    [(x, y) for x in range(6, 26) for y in range(0, 10)],
        "skin":    [(x, y) for x in range(10, 22) for y in range(9, 18)],
        "robe":    [(x, y) for x in range(8, 24)  for y in range(24, 44)],
        "boot":    [(x, y) for x in range(8, 24)  for y in range(54, 64)],
        "outline": [(x, y) for x in range(0, 32)  for y in range(0, 64)],
    }
    palette = {}
    for name, coords in regions.items():
        colors = [px[x, y] for x, y in coords if px[x, y][3] > 200]
        if not colors:
            continue
        # Pega a cor mais frequente excluindo transparente
        counter = Counter(colors)
        top = counter.most_common(3)
        palette[name] = [f"rgba{c}" for c, _ in top if c[3] > 200]
    return palette


def palette_block(palette: dict) -> str:
    lines = []
    for region, colors in palette.items():
        lines.append(f"  {region.upper():8s}: {', '.join(colors[:2])}")
    return "\n".join(lines)


def save_sprite(img: Image.Image, name: str, idx: int) -> Path:
    SPRITE_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"soph_{name}_{idx}.png" if idx >= 0 else f"soph_{name}.png"
    path = SPRITE_DIR / filename
    img.save(path)
    return path


def make_strip(frames: list[tuple[str, Image.Image, int]]) -> Image.Image:
    zoom = 4
    fw, fh = 32 * zoom, 64 * zoom + 20
    strip = Image.new("RGBA", (fw * len(frames), fh), (20, 20, 20, 255))
    draw = ImageDraw.Draw(strip)
    for i, (label, img, score) in enumerate(frames):
        zoomed = img.resize((32 * zoom, 64 * zoom), Image.NEAREST)
        strip.paste(zoomed, (i * fw, 0))
        draw.text((i * fw + 2, 64 * zoom + 2), f"{label} {score}/10",
                  fill=(200, 200, 200, 255))
    return strip


def git_commit_sprites(files: list[Path], message: str) -> bool:
    try:
        rel = [str(f.relative_to(REPO_ROOT)) for f in files]
        subprocess.run(["git", "-C", str(REPO_ROOT), "add"] + rel, check=True)
        subprocess.run(["git", "-C", str(REPO_ROOT), "commit", "-m", message], check=True)
        subprocess.run(["git", "-C", str(REPO_ROOT), "push",
                        "-u", "origin", "claude/initial-setup-uxfZh"], check=True)
        return True
    except subprocess.CalledProcessError as e:
        print(f"  Git error: {e}")
        return False


# ── Fase 1: Refinar idle_0 ────────────────────────────────────────────────────

def refine_base(engine: Engine, target_score: int,
                max_iter: int) -> tuple[str, Image.Image, int]:
    """Itera sobre idle_0 até score >= target. Retorna (código, imagem, score)."""
    from art_director import GOAL, CRITIQUE_PROMPT, iterate, save_iteration

    print("\n━━ FASE 1: Refinando idle_0 (frame base) ━━━━━━━━━━━━━━━━━━━━━━━━━")
    code = GEN_FILE.read_text(encoding="utf-8")
    best_code, best_img, best_score = code, run_code(code), 0

    for i in range(max_iter):
        print(f"\n  Iteração {i} →", end=" ", flush=True)
        img = run_code(code)
        result = iterate(engine, code, img, i)
        score = int(result.get("score", 0))
        print(f"score {score}/10")

        critique = result.get("critique", "")[:100]
        print(f"  Crítica: {critique}...")
        for issue in result.get("issues", [])[:3]:
            print(f"    • {issue}")

        save_iteration(img, i, score, critique)

        if score > best_score:
            best_score = score
            best_code  = result.get("improved_code", code) or code
            best_img   = run_code(best_code)

        new_code = result.get("improved_code", "")
        if new_code.strip():
            code = new_code
            GEN_FILE.write_text(code, encoding="utf-8")

        if score >= target_score:
            print(f"\n  ✓ Score {score} ≥ meta {target_score} — base aprovada!")
            break

    return best_code, best_img, best_score


# ── Fase 2: Gerar cada frame com style lock ───────────────────────────────────

def generate_pose(engine: Engine, frame_name: str, frame_idx: int,
                  pose_desc: str, base_code: str, palette: dict,
                  max_iter: int = 2) -> tuple[Image.Image, int]:
    """Gera um frame específico com o estilo travado. Retorna (imagem, score)."""
    frame_key = f"soph_{frame_name}_{frame_idx}"
    pb = palette_block(palette)

    print(f"\n  Gerando {frame_key}...", end=" ", flush=True)

    # Pede o código inicial para esta pose
    prompt = POSE_PROMPT.format(
        palette_block=pb,
        base_score="?",
        base_code=base_code,
        frame_key=frame_key,
        pose_desc=pose_desc,
    )
    resp_text = engine.call(prompt)
    try:
        data = extract_json(resp_text)
        code = data.get("code", base_code)
        img  = run_code(code)
    except Exception as e:
        print(f"erro na geração inicial ({e}), usando base")
        code = base_code
        img  = run_code(code)

    # Refina a pose (1-2 iterações rápidas)
    score = 0
    for i in range(max_iter):
        refine_prompt = REFINE_PROMPT.format(
            frame_key=frame_key,
            pose_desc=pose_desc,
            palette_block=pb,
            code=code,
            zoom=ZOOM,
        )
        r2_text = engine.call(refine_prompt, img)
        try:
            rd = extract_json(r2_text)
            score    = int(rd.get("score", 0))
            new_code = rd.get("improved_code", "")
            if new_code.strip():
                code = new_code
                img  = run_code(code)
        except Exception:
            pass

    print(f"score {score}/10")
    return img, score


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Orquestrador autônomo de sprites da Soph",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=engine_help(),
    )
    parser.add_argument("--engine",     default="gemini",
                        choices=["gemini", "anthropic", "claude", "ollama"],
                        help="Motor de IA (padrão: gemini — grátis!)")
    parser.add_argument("--api-key",    default=None)
    parser.add_argument("--score",      type=int, default=7)
    parser.add_argument("--base-iter",  type=int, default=4)
    parser.add_argument("--pose-iter",  type=int, default=2)
    parser.add_argument("--no-commit",  action="store_true")
    parser.add_argument("--only",       type=str, default=None,
                        help="Gera só um frame (ex: --only walk_1)")
    args = parser.parse_args()

    # Carrega chave: argumento > .env > env var
    def _load_env(engine_name: str) -> str | None:
        ef = HERE / ".env"
        kn = ENGINE_KEYS.get(engine_name)
        if not ef.exists() or not kn:
            return None
        for line in ef.read_text().splitlines():
            if line.startswith(f"{kn}="):
                return line.split("=", 1)[1].strip().strip('"')
        return None

    api_key = (args.api_key
               or _load_env(args.engine)
               or os.environ.get(ENGINE_KEYS.get(args.engine, "") or ""))

    if not api_key and args.engine not in ("ollama",):
        key_var = ENGINE_KEYS.get(args.engine, "API_KEY")
        print(f"\nPrecisa de chave para '{args.engine}'.")
        print(engine_help())
        print(f"  echo '{key_var}=SUA_CHAVE' > {HERE / '.env'}")
        sys.exit(1)

    engine = build_engine(args.engine, api_key)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    start = datetime.now()
    print(f"\n{'═'*62}")
    print("  Orquestrador Autônomo — Sprites da Soph")
    print(f"  Motor   : {args.engine}  ({engine.model})")
    print(f"  Meta    : idle_0 score ≥ {args.score}  |  {args.base_iter} iter base + {args.pose_iter} iter/pose")
    print(f"  Frames  : {len(FRAMES)} no total")
    print(f"{'═'*62}")

    # ── Fase 1: Refinar idle_0 ────────────────────────────────────────────────
    base_code, base_img, base_score = refine_base(
        engine, args.score, args.base_iter
    )

    # Salva idle_0 aprovado
    idle_path = save_sprite(base_img, "idle", 0)
    print(f"\n  idle_0 salvo → {idle_path.name}")

    # ── Fase 2: Extrair paleta ────────────────────────────────────────────────
    palette = extract_palette(base_img)
    print("\n━━ FASE 2: Paleta extraída ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(palette_block(palette))

    # ── Fase 3: Gerar todos os frames ─────────────────────────────────────────
    print("\n━━ FASE 3: Gerando todos os frames ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    all_frames: list[tuple[str, Image.Image, int]] = [
        (f"idle_0  [{base_score}/10]", base_img, base_score)
    ]
    saved_files = [idle_path]

    for (name, idx, pose_desc) in FRAMES:
        frame_key = f"{name}_{idx}"
        if args.only and args.only != frame_key:
            continue
        if name == "idle" and idx == 0:
            continue  # já gerado na fase 1

        try:
            img, score = generate_pose(
                engine, name, idx, pose_desc,
                base_code, palette, args.pose_iter,
            )
            path = save_sprite(img, name, idx)
            saved_files.append(path)
            all_frames.append((f"{frame_key} [{score}/10]", img, score))
        except Exception as e:
            print(f"\n  ERRO em {frame_key}: {e}")

    # ── Fase 4: Preview strip ─────────────────────────────────────────────────
    print("\n━━ FASE 4: Gerando preview strip ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    strip = make_strip(all_frames)
    strip_path = OUT_DIR / f"final_strip_{datetime.now():%H%M%S}.png"
    strip.save(strip_path)
    print(f"  Strip → {strip_path}")

    # ── Fase 5: Git commit ────────────────────────────────────────────────────
    if not args.no_commit:
        print("\n━━ FASE 5: Commit automático ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        scores = [s for _, _, s in all_frames]
        avg    = sum(scores) / len(scores) if scores else 0
        msg = (
            f"Auto-generate Soph sprites via art_director loop\n\n"
            f"Base idle_0 score: {base_score}/10  |  Avg all frames: {avg:.1f}/10\n"
            f"Frames gerados: {len(saved_files)}\n"
            f"Modelo: {MODEL}\n\n"
            f"https://claude.ai/code/session_01G57VgqWyuu32miPAJbhE6J"
        )
        if git_commit_sprites(saved_files, msg):
            print("  ✓ Commit + push concluídos")
        else:
            print("  ✗ Git falhou — sprites salvos localmente")

    elapsed = (datetime.now() - start).seconds
    print(f"\n{'═'*62}")
    print(f"  Concluído em {elapsed // 60}m {elapsed % 60}s")
    print(f"  {len(saved_files)} sprites em {SPRITE_DIR}")
    print(f"{'═'*62}\n")


if __name__ == "__main__":
    main()
