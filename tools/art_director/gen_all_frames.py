#!/usr/bin/env python3
"""
gen_all_frames.py — Gera TODOS os sprites da Soph a partir de soph_core.

Frames: idle_0/1, walk_0-5, run_0-3, jump, fall, hurt, mana_1-5.
Tudo virado para a DIREITA (corrige o "bug do moonwalk").

Uso:
    python gen_all_frames.py            # gera em iterations/preview_frames/ (não toca nos assets)
    python gen_all_frames.py --apply    # escreve em assets/sprites/player/
"""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw
import soph_core as S

HERE = Path(__file__).parent
DEST = HERE.parent.parent / "assets" / "sprites" / "player"
PREV = HERE / "iterations" / "preview_frames"


def shift_up(img, n=1):
    out = Image.new("RGBA", img.size, S.T)
    out.paste(img.crop((0, n, S.W, S.H)), (0, 0))
    return out


def build():
    frames = {}

    # ── idle ──────────────────────────────────────────────────────────────────
    idle0 = S.compose(mana=5)
    frames["soph_idle_0"] = idle0
    frames["soph_idle_1"] = shift_up(idle0, 1)            # respiração (+1px)

    # ── walk (6 frames) — agora virada p/ direita ──────────────────────────────
    # (back, front, l_dy, r_dy, hair_bob, knee_dy, sway, hem_sway)
    # sway = pêndulo do cabelo/capa, defasado do passo (trailing)
    walk = [
        ((10, 14), (17, 21), -1, +2,  0, 0, +3, +2),   # 0 contato pé de trás
        ((12, 16), (15, 19), -2, -1, -2, 1, +4, +2),   # 1 passagem (alto)
        ((10, 14), (17, 21), +2, -1,  0, 0,  0,  0),   # 2 contato pé da frente
        ((12, 16), (15, 19), -1, -2, -2, 1, -4, -2),   # 3 passagem
        ((10, 14), (17, 21), -1, +2,  0, 0, -3, -2),   # 4 = 0
        ((12, 16), (15, 19), -2, -1, -2, 1,  0,  0),   # 5 ponte de volta
    ]
    for i, (bk, fr, l, r, hb, kd, sw, hsw) in enumerate(walk):
        frames[f"soph_walk_{i}"] = S.compose(
            mana=5, l_dy=l, r_dy=r, hair_bob=hb, knee_dy=kd, sway=sw, hem_sway=hsw,
            legs={"back": bk, "front": fr},
            boots={"back": (bk[0]-1, bk[1]), "front": (fr[0]-1, fr[1]+1),
                   "back_y": 50+kd, "front_y": 50},
        )

    # ── run (4 frames) — passada maior, leve inclinação ────────────────────────
    # 6 frames p/ uma corrida mais fluida (AAA): contato → recolhe → passagem alta
    run = [
        (( 9, 13), (18, 22), -3, +3,  0, 0, +5, +3),   # 0 contato (frente esticada)
        ((11, 15), (17, 21), -1, +1, -1, 1, +4, +2),   # 1 recolhe/absorve
        ((12, 16), (15, 19), -2, -2, -2, 3, +2,  0),   # 2 passagem alta (joelho sobe)
        (( 9, 13), (18, 22), +3, -3,  0, 0, -5, -3),   # 3 contato oposto
        ((11, 15), (17, 21), +1, -1, -1, 1, -4, -2),   # 4 recolhe/absorve
        ((12, 16), (15, 19), -2, -2, -2, 3, -2,  0),   # 5 passagem alta
    ]
    for i, (bk, fr, l, r, hb, kd, sw, hsw) in enumerate(run):
        frames[f"soph_run_{i}"] = S.compose(
            mana=5, l_dy=l, r_dy=r, hair_bob=hb, knee_dy=kd, sway=sw, hem_sway=hsw,
            legs={"back": bk, "front": fr},
            boots={"back": (bk[0]-1, bk[1]), "front": (fr[0]-1, fr[1]+1),
                   "back_y": 50+kd, "front_y": 50},
        )

    # ── jump / fall / hurt ──────────────────────────────────────────────────────
    # Salto: 2 frames (lançamento ↔ ápice). Capa balança e cabelo levanta no ápice.
    # knee_dy=-2 alonga as pernas até y54 p/ encostar nas botas (sem buraco).
    jump_legs  = {"back": (12, 16), "front": (15, 20)}
    jump_boots = {"back": (11, 16), "front": (15, 21), "back_y": 54, "front_y": 54}
    frames["soph_jump_0"] = S.compose(                    # lançamento
        mana=5, arms="up", knee_dy=-2, cape_lower=52,
        legs=jump_legs, boots=jump_boots, hem_sway=+1,
    )
    frames["soph_jump_1"] = S.compose(                    # ápice (cabelo levanta, hem balança)
        mana=5, arms="up", knee_dy=-2, cape_lower=51,
        legs=jump_legs, boots=jump_boots,
        hair_bob=-1, sway=-1, hem_sway=-1,
    )
    # Queda: 2 frames com capa esvoaçante (loop, sensação de flutuar).
    fall_legs  = {"back": (9, 13), "front": (18, 22)}
    fall_boots = {"back": (8, 13), "front": (18, 23)}
    frames["soph_fall_0"] = S.compose(
        mana=5, arms="out", legs=fall_legs, boots=fall_boots,
        hair_bob=-1, sway=+1, hem_sway=+1,
    )
    frames["soph_fall_1"] = S.compose(
        mana=5, arms="out", legs=fall_legs, boots=fall_boots,
        l_dy=-1, r_dy=-1, sway=-1, hem_sway=-1,
    )
    frames["soph_hurt"] = S.compose(
        mana=5, arms="guard",
        legs={"back": (10, 14), "front": (17, 21)},
        boots={"back": (9, 14), "front": (17, 22)},
    )

    # ── poses de ataque (arma exposta na altura do spawn) ───────────────────────
    # Cast/slash agora têm 2 fases (windup → release/impacto) E variam com mana:
    # cabelo escurece nas pontas conforme a Soph fica sem energia.
    for m in range(1, 6):
        frames[f"soph_cast_{m}_0"]  = S.compose(mana=m, arms="cast",  phase=0)
        frames[f"soph_cast_{m}_1"]  = S.compose(mana=m, arms="cast",  phase=1)
        frames[f"soph_slash_{m}_0"] = S.compose(mana=m, arms="slash", phase=0)
        frames[f"soph_slash_{m}_1"] = S.compose(mana=m, arms="slash", phase=1)

    # ── mana states (idle por nível) ────────────────────────────────────────────
    for m in range(1, 6):
        frames[f"soph_mana_{m}"] = S.compose(mana=m)

    return frames


def contact_sheet(frames):
    Z = 5
    cols = 7
    cw, ch = 32 * Z, 64 * Z + 16
    items = list(frames.items())
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (40, 40, 48, 255))
    d = ImageDraw.Draw(sheet)
    for i, (name, img) in enumerate(items):
        im = img.resize((32 * Z, 64 * Z), Image.NEAREST)
        cx, cy = (i % cols) * cw, (i // cols) * ch
        sheet.alpha_composite(im, (cx, cy))
        d.text((cx + 2, cy + 64 * Z + 2), name.replace("soph_", ""), fill=(220, 220, 220, 255))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="escreve em assets/sprites/player/")
    args = ap.parse_args()
    frames = build()
    out_dir = DEST if args.apply else PREV
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, img in frames.items():
        img.save(out_dir / f"{name}.png")
    sheet = contact_sheet(frames)
    (HERE / "iterations").mkdir(parents=True, exist_ok=True)
    sheet.save(HERE / "iterations" / "all_frames_sheet.png")
    print(f"{'APLICADO em assets' if args.apply else 'PREVIEW'}: {len(frames)} frames -> {out_dir}")
    print(f"Sheet -> {HERE / 'iterations' / 'all_frames_sheet.png'}")


if __name__ == "__main__":
    main()
