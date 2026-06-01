#!/usr/bin/env python3
"""
feel_bench.py — "a jogabilidade está em nível comercial?"

Audita as constantes de movimento/combate do player (scripts/player/player.gd)
contra ALVOS de referência do gênero (metroidvania de ação tipo HK/Celeste/
Ori). NÃO copia código de ninguém — usa faixas-alvo públicas e bem
estabelecidas de game design (coyote time, jump buffer, pulo variável, etc).

Lê os valores reais do player.gd por regex (fonte da verdade) e aponta:
  ✅ dentro do alvo   ⚠️ fora do alvo (com sugestão)   ❓ ausente (feature que
  best-sellers têm e o jogo ainda não)

Uso:
    python tools/feel_bench.py
"""
from __future__ import annotations
import re, sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
PLAYER = ROOT / "scripts" / "player" / "player.gd"

# ── Alvos de referência do gênero (faixas públicas de game design) ───────────
# (rótulo, regex p/ extrair, low, high, unidade, por que importa)
CONST_TARGETS = [
    ("Coyote time", r"COYOTE_TIME\s*=\s*([\d.]+)", 0.08, 0.15, "s",
     "janela p/ pular após sair da plataforma — perdoa o jogador"),
    ("Jump buffer", r"JUMP_BUFFER_TIME\s*=\s*([\d.]+)", 0.08, 0.15, "s",
     "lembra o pulo apertado pouco antes de tocar o chão"),
    ("Iframes ao tomar dano", r"IFRAME_DURATION\s*=\s*([\d.]+)", 0.5, 1.2, "s",
     "tempo de invencibilidade — evita morte injusta em cadeia"),
    ("Dash duration", r"DASH_DURATION\s*=\s*([\d.]+)", 0.10, 0.22, "s",
     "dash curto e nítido dá sensação de precisão"),
    ("Dash cooldown", r"DASH_COOLDOWN\s*=\s*([\d.]+)", 0.3, 0.8, "s",
     "curto p/ fluidez, mas não infinito"),
]

# Features de game feel que best-sellers têm — presença detectada por padrão.
# (rótulo, regex de presença, por que importa)
FEATURE_CHECKS = [
    ("Pulo variável (altura por tempo de botão)",
     r"just_released\(\s*\"ui_accept\"|is_action_just_released\(\s*\"(ui_accept|jump)",
     "soltar o botão cedo = pulo baixo. AUSÊNCIA = pulo 'robótico'. "
     "Fix: ao soltar com velocity.y<0, cortar velocity.y *= 0.4~0.5"),
    ("Gravidade de queda assimétrica (cai mais rápido que sobe)",
     r"(FALL_GRAVITY|fall_multiplier|GRAVITY_FALL|gravity.*\*.*1\.[2-9])",
     "queda mais pesada que a subida = pulo 'gostoso' (Mario/Celeste). "
     "AUSÊNCIA = pulo flutuante. Fix: na descida, GRAVITY * 1.3~1.6"),
    ("Hitstop / freeze-frame no impacto",
     r"start_hitstop|hitstop|freeze_frame|Engine\.time_scale",
     "micro-congelamento ao acertar dá PESO ao golpe — assinatura de juice"),
    ("Screen shake",
     r"func shake|_shake_intensity|add_trauma|screen_shake",
     "tremor de tela proporcional ao impacto = feedback visceral"),
    ("Squash & stretch",
     r"_squash|squash|stretch",
     "deformar no pulo/pouso dá vida e elasticidade ao corpo"),
    ("Apex hang (flutuar leve no topo do pulo)",
     r"apex_hang|hang_time|APEX_GRAVITY|APEX_THRESHOLD|apex.*gravity|float.*apex",
     "reduzir gravidade no topo do pulo dá controle aéreo — sensação premium"),
]


def read_player():
    if not PLAYER.exists():
        print(f"ERRO: não achei {PLAYER}")
        sys.exit(1)
    return PLAYER.read_text()


def main():
    src = read_player()
    print("═" * 64)
    print(" FEEL BENCH — jogabilidade vs. alvos do gênero (tier-HK)")
    print("═" * 64)

    score = 0.0
    maxscore = 0.0

    print("\n▼ CONSTANTES DE MOVIMENTO/COMBATE")
    for label, rx, lo, hi, unit, why in CONST_TARGETS:
        maxscore += 1
        m = re.search(rx, src)
        if not m:
            print(f"  ❓ {label}: não encontrado")
            print(f"      ↳ {why}")
            continue
        val = float(m.group(1))
        ok = lo <= val <= hi
        score += 1 if ok else 0.3
        mark = "✅" if ok else "⚠️"
        rng = f"[alvo {lo}–{hi}{unit}]"
        print(f"  {mark} {label}: {val}{unit}  {rng}")
        if not ok:
            print(f"      ↳ fora do alvo — {why}")

    print("\n▼ FEATURES DE GAME FEEL (presença)")
    for label, rx, why in FEATURE_CHECKS:
        maxscore += 1
        present = re.search(rx, src) is not None
        score += 1 if present else 0
        mark = "✅" if present else "❓"
        print(f"  {mark} {label}")
        if not present:
            print(f"      ↳ FALTA — {why}")

    pct = score / maxscore * 10
    print("\n" + "─" * 64)
    print(f" NOTA DE GAME FEEL: {pct:.1f}/10  "
          f"({score:.1f}/{maxscore:.0f} critérios)")
    print("─" * 64)
    print(" Lembrete: best-sellers do gênero vivem em 8–9. Os ❓ acima são as")
    print(" maiores alavancas — features baratas de adicionar, efeito enorme.")


if __name__ == "__main__":
    main()
