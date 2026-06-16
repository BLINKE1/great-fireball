#!/usr/bin/env python3
"""gen_cycle_gif.py — monta um GIF com os melhores frames de movimento
da Soph HD extraidos das 3 sheets do Pollen. Sequencia curada p/ flow
visual: idle -> walk crescente -> run -> walk -> idle (loop suave).

    python gen_cycle_gif.py
"""
from pathlib import Path
from PIL import Image

HERE = Path(__file__).parent
PREV = HERE.parent.parent / "assets" / "sprites" / "player" / "_preview"
OUT = PREV / "soph_movement_cycle.gif"

# sequencia curada (caminho relativo -> dura em ms)
# escolhidos por: identidade consistente + intensidade de movimento crescente
FRAMES = [
    ("sheet_walkrun9/cells/cell_00_p00.png",     180),  # idle frontal
    ("sheet_walkrun9/cells/cell_02_p02.png",     140),  # leve passo
    ("sheet_walkrun9/cells/cell_03_p03.png",     140),  # walk 3/4 sorrindo
    ("sheet_locomotion16/cells/cell_07_p07.png", 130),  # walk 3/4 perna lev.
    ("sheet_walkrun9/cells/cell_04_p04.png",     120),  # walk energetico
    ("sheet_locomotion16/cells/cell_06_p06.png", 110),  # run side view
    ("sheet_walkrun9/cells/cell_05_p05.png",     110),  # run side view full
    ("sheet_locomotion16/cells/cell_09_p09.png", 110),  # run 3/4
    ("sheet_locomotion16/cells/cell_10_p10.png", 130),  # walk 3/4 outra perna
    ("sheet_locomotion16/cells/cell_11_p11.png", 160),  # idle 3/4
]

SCALE = 3  # 100x192 -> 300x576 p/ visibilidade


def main():
    imgs, durations = [], []
    bg_color = (40, 40, 50, 255)  # cinza-azul escuro p/ contrastar com Soph
    for rel, dur in FRAMES:
        path = PREV / rel
        if not path.exists():
            print(f"skip ausente: {rel}")
            continue
        im = Image.open(path).convert("RGBA")
        # upscale com nearest (mantém sharp) e composit em bg solido
        big = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
        bg = Image.new("RGBA", big.size, bg_color)
        bg.paste(big, (0, 0), big)
        imgs.append(bg.convert("P", palette=Image.ADAPTIVE))
        durations.append(dur)

    if not imgs:
        print("nenhum frame encontrado")
        return 1

    imgs[0].save(
        OUT,
        save_all=True,
        append_images=imgs[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )
    print(f"salvo {OUT}")
    print(f"  {len(imgs)} frames, total ~{sum(durations)}ms (~{sum(durations)/1000:.1f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
