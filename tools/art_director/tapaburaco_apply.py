#!/usr/bin/env python3
"""
tapaburaco_apply.py — Aplica os frames staged DISPONIVEIS em cima das
oficiais, sem exigir 19/19. Backup das atuais em _backup_tapaburaco/
pra reverter facil quando os 19 estiverem completos.

Comportamento:
  - Pra cada soph_hd_<anim>_<idx>.png em _pending_regen/:
    - Backup do oficial em _backup_tapaburaco/ (se ainda nao copiado)
    - Copia o staged por cima do oficial
  - Pra walk: se ha frames staged 0..N (N<5), duplica o ultimo staged
    como walk_5 (etc.) pra fechar o ciclo de 6 frames no estilo novo.
  - Imprime resumo do que mudou.

NAO mexe em player.gd nem reimporta — esses dois passos rodam separados.
"""
from __future__ import annotations
import shutil, sys
from pathlib import Path

ROOT    = Path(__file__).parent.parent.parent
ASSETS  = ROOT / "assets" / "sprites" / "player"
STAGING = ASSETS / "_pending_regen"
BACKUP  = ASSETS / "_backup_tapaburaco"

# Mesma estrutura do JOBS em gen_hd_from_idle.py
CYCLES = {
    "idle":  [0, 1],
    "walk":  [0, 1, 2, 3, 4, 5],
    "run":   [0, 1, 2, 3],
    "jump":  [0],
    "fall":  [0],
    "hurt":  [0],
    "cast":  [0, 1],
    "slash": [0, 1],
}


def main() -> int:
    BACKUP.mkdir(exist_ok=True)
    applied = []
    backed_up = []
    duplicated = []

    for anim, idxs in CYCLES.items():
        # quais frames desta anim ja tem staged?
        staged_idxs = [i for i in idxs if (STAGING / f"soph_hd_{anim}_{i}.png").exists()]
        if not staged_idxs:
            continue

        # backup das oficiais (so na primeira vez)
        for i in idxs:
            off = ASSETS / f"soph_hd_{anim}_{i}.png"
            bak = BACKUP / f"soph_hd_{anim}_{i}.png"
            if off.exists() and not bak.exists():
                shutil.copy2(off, bak)
                backed_up.append(off.name)

        # aplica os staged disponiveis
        for i in staged_idxs:
            src = STAGING / f"soph_hd_{anim}_{i}.png"
            dst = ASSETS / f"soph_hd_{anim}_{i}.png"
            shutil.copy2(src, dst)
            applied.append(dst.name)

        # se faltam frames (e o ciclo precisa de loop visual), duplica o
        # ultimo staged nas posicoes faltantes pra fechar a anim no estilo
        # novo. Isso e o "tapa-buraco" propriamente dito.
        missing = [i for i in idxs if i not in staged_idxs]
        if missing and anim in ("walk", "run"):
            # usa o ultimo frame staged como semente
            seed_idx = staged_idxs[-1]
            seed_src = STAGING / f"soph_hd_{anim}_{seed_idx}.png"
            for i in missing:
                dst = ASSETS / f"soph_hd_{anim}_{i}.png"
                shutil.copy2(seed_src, dst)
                duplicated.append(f"{dst.name} (<- {seed_src.name})")

    print(f"== TAPA-BURACO APLICADO ==")
    print(f"\nBackup feito ({len(backed_up)} oficiais salvos em _backup_tapaburaco/):")
    for n in backed_up:
        print(f"  - {n}")
    print(f"\nAplicados ({len(applied)} frames novos):")
    for n in applied:
        print(f"  + {n}")
    print(f"\nDuplicados pra fechar ciclo ({len(duplicated)}):")
    for n in duplicated:
        print(f"  ~ {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
