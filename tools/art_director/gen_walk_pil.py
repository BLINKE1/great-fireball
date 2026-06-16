#!/usr/bin/env python3
"""gen_walk_pil.py — walk cycle lateral da Soph, 100% PIL.
Zero Pollen, zero Cairo, zero deps C. Determinístico.

Desenha Soph estilizada com primitives: chapeu cone, robe trapezoidal,
cabelo, óculos, botas. 4 fases de walk com bob + braço + pés alternados.

    python gen_walk_pil.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).parent / "iterations" / "svg" / "walk_pil.gif"
OUT.parent.mkdir(parents=True, exist_ok=True)

W, H = 220, 440          # canvas base
SCALE = 4                # supersampling p/ antialiasing
W4, H4 = W * SCALE, H * SCALE

# paleta (mesma do soph_svg.py)
BG     = (255, 255, 255, 255)
OUT_C  = (27, 15, 34, 255)
ROBE   = (168, 34, 43, 255)
ROBE_D = (118, 21, 34, 255)
ROBE_H = (210, 67, 63, 255)
HAT    = (176, 38, 46, 255)
HAT_D  = (122, 23, 34, 255)
H_ROOT = (27, 42, 94, 255)
H_MID  = (58, 110, 200, 255)
H_TIP  = (124, 178, 242, 255)
SKIN   = (243, 207, 168, 255)
LENS   = (219, 233, 246, 255)
FRAME  = (31, 23, 38, 255)
BOOT   = (95, 59, 33, 255)
BOOT_D = (58, 36, 16, 255)
SUIT   = (27, 27, 50, 255)
MOUTH  = (140, 68, 68, 255)
SHADOW = (0, 0, 0, 56)


def sp(pts):
    """Scale list of (x,y) tuples — para polygon/line."""
    return [(x * SCALE, y * SCALE) for x, y in pts]


def sb(x0, y0, x1, y1):
    """Scale bbox para ellipse/rectangle."""
    return (x0 * SCALE, y0 * SCALE, x1 * SCALE, y1 * SCALE)


def draw_frame(foot_front_dy, foot_back_dy, hand_swing, bob):
    """Desenha 1 frame do walk cycle.
    foot_front_dy/foot_back_dy: deslocamento Y dos pes (negativo = no ar)
    hand_swing: -1..1 (-1=mao atras, 1=mao frente)
    bob: deslocamento Y global do corpo (passing fica mais baixo)
    """
    img = Image.new("RGBA", (W4, H4), BG)
    d = ImageDraw.Draw(img)
    by = bob  # body bob offset

    w = SCALE * 2

    # sombra de chao
    d.ellipse(sb(40, 416, 170, 432), fill=SHADOW)

    # CABELO atras
    hair_pts = [
        (90, 130+by), (60, 150+by), (50, 230+by), (54, 320+by),
        (66, 380+by), (78, 392+by), (102, 392+by), (108, 350+by),
        (108, 250+by), (104, 160+by), (96, 140+by),
    ]
    d.polygon(sp(hair_pts), fill=H_MID, outline=OUT_C, width=w)
    for tip in [(58, 370), (74, 388), (88, 392)]:
        x, y = tip
        d.polygon(sp([(x-6, y-30+by), (x+6, y-30+by), (x+2, y+by), (x-2, y+by)]),
                  fill=H_TIP)

    # ROBE de perfil
    robe_pts = [
        (98, 160+by), (96, 200+by), (88, 280+by), (78, 360+by), (72, 392+by),
        (138, 392+by), (134, 320+by), (128, 240+by), (124, 180+by), (118, 158+by),
    ]
    d.polygon(sp(robe_pts), fill=ROBE, outline=OUT_C, width=w)
    d.line(sp([(116, 180+by), (130, 380+by)]), fill=ROBE_H, width=w)
    for pa, pb in [((108, 200), (100, 388)), ((124, 220), (128, 386))]:
        d.line(sp([(pa[0], pa[1]+by), (pb[0], pb[1]+by)]),
               fill=ROBE_D, width=w)

    # MANGA da frente
    sleeve = [
        (120, 168+by), (130, 220+by), (138, 280+by), (140, 300+by),
        (128, 304+by), (118, 290+by), (114, 230+by), (114, 174+by),
    ]
    d.polygon(sp(sleeve), fill=ROBE, outline=OUT_C, width=w)

    # MAO
    hx = 126 + int(hand_swing * 6)
    hy = 302 + by + abs(int(hand_swing * 4))
    d.ellipse(sb(hx-8, hy-8, hx+8, hy+8), fill=SKIN, outline=OUT_C, width=w)

    # BOTAS
    bb_y = 392 + foot_back_dy
    d.polygon(sp([(76, bb_y), (102, bb_y), (104, bb_y+26), (74, bb_y+26)]),
              fill=BOOT_D, outline=OUT_C, width=w)
    bf_y = 392 + foot_front_dy
    d.polygon(sp([(108, bf_y), (138, bf_y), (142, bf_y+26), (108, bf_y+26)]),
              fill=BOOT, outline=OUT_C, width=w)

    # CABECA de perfil
    head = [
        (96, 124+by), (108, 108+by), (124, 110+by), (132, 124+by),
        (135, 134+by), (140, 140+by), (138, 144+by), (134, 148+by),
        (132, 156+by), (124, 164+by), (110, 164+by), (98, 152+by),
        (94, 136+by),
    ]
    d.polygon(sp(head), fill=SKIN, outline=OUT_C, width=w)

    fringe = [(96, 122+by), (108, 106+by), (122, 108+by), (130, 122+by),
              (118, 116+by), (108, 116+by), (98, 122+by)]
    d.polygon(sp(fringe), fill=H_ROOT, outline=OUT_C, width=w)

    d.ellipse(sb(114, 130+by, 128, 144+by), fill=LENS, outline=FRAME, width=w)
    d.ellipse(sb(118, 134+by, 124, 140+by), fill=FRAME)
    d.line(sp([(114, 137+by), (98, 134+by)]), fill=FRAME, width=w)
    d.line(sp([(128, 156+by), (134, 158+by)]), fill=MOUTH, width=w)
    d.ellipse(sb(117, 146+by, 123, 152+by), fill=(236, 154, 146, 140))

    # CHAPEU
    d.ellipse(sb(44, 108+by, 168, 130+by), fill=HAT, outline=OUT_C, width=w)
    cone = [(78, 116+by), (110, 26+by), (124, 30+by), (132, 116+by)]
    d.polygon(sp(cone), fill=HAT, outline=OUT_C, width=w)
    d.line(sp([(80, 116+by), (130, 116+by)]), fill=HAT_D, width=w)

    # downscale com antialiasing
    return img.resize((W, H), Image.LANCZOS)


def main():
    # walk cycle: 4 fases
    # phase 0: contact R (front planted forward, back planted behind)
    # phase 1: passing (back lifts and swings)
    # phase 2: contact L (legs cross — visualmente front swung back)
    # phase 3: passing mirror (front lifts)
    phases = [
        # (foot_front_dy, foot_back_dy, hand_swing, bob)
        (0,    0,    -1.0, 0),    # contact R
        (0,   -16,   0.5, 4),     # passing — back lifts, hand crosses fwd
        (0,    0,    1.0, 0),     # contact L (hand swung max fwd)
        (-16,  0,   -0.5, 4),     # passing mirror — front lifts
    ]
    frames = []
    for p in phases:
        frame = draw_frame(*p).convert("P", palette=Image.ADAPTIVE)
        frames.append(frame)

    frames[0].save(
        OUT,
        save_all=True,
        append_images=frames[1:],
        duration=140,
        loop=0,
        disposal=2,
        optimize=False,
    )
    print(f"salvo {OUT} ({len(frames)} frames)")


if __name__ == "__main__":
    main()
