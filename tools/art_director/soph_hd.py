#!/usr/bin/env python3
"""
soph_hd.py — Protótipo da Soph em ALTA resolução (64×128).

Técnica: desenha as MASSAS só com preenchimento + shading de 3 tons
(base/sombra/luz), sem contorno por forma; depois aplica UM contorno único
ao redor da silhueta inteira (dilatação da máscara alpha). Curvas reais
(círculos nos óculos/orbe, polígonos na capa) p/ ar "pintado" estilo HK.

Vista 3/4 virada para a DIREITA. Luz vinda de cima-esquerda.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops, ImageFilter

W, H = 64, 128
HERE = Path(__file__).parent

# ── Paleta (3 tons por material) ───────────────────────────────────────────────
OUTLINE = (16, 11, 26, 255)
SKIN    = (240, 200, 162, 255); SKIN_S = (206, 158, 120, 255); SKIN_H = (252, 226, 196, 255)
HAIR    = (70, 132, 226, 255);  HAIR_D = (42, 88, 182, 255)
HAIR_DD = (28, 58, 134, 255);   HAIR_H = (150, 204, 255, 255)
CAPE    = (30, 26, 50, 255);    CAPE_D = (18, 15, 32, 255);  CAPE_DD = (10, 8, 20, 255)
CAPE_L  = (78, 102, 168, 255);  CAPE_GL= (48, 84, 158, 255)
LINING  = (126, 60, 146, 255);  LINING_D = (84, 38, 102, 255)
SUIT    = (24, 20, 38, 255);    SUIT_H = (48, 38, 72, 255);  SUIT_SH = (13, 10, 24, 255)
GOLD    = (216, 172, 62, 255);  GOLD_D = (150, 110, 32, 255); GOLD_H = (252, 226, 136, 255)
BOOT    = (80, 52, 30, 255);    BOOT_D = (52, 32, 16, 255);   BOOT_H = (116, 82, 50, 255)
STAFF   = (116, 80, 46, 255);   STAFF_D = (78, 50, 26, 255);  STAFF_H = (168, 124, 72, 255)
ORB     = (54, 134, 234, 255);  ORB_H = (176, 228, 255, 255); ORB_C = (230, 248, 255, 255)
ORB_D   = (28, 74, 154, 255)
GLASS   = (32, 28, 48, 255);    GLASS_H = (120, 126, 158, 255)
LENS    = (158, 206, 230, 70)
BLUSH   = (240, 152, 150, 255); MOUTH = (184, 98, 94, 255)
EYEPUP  = (30, 22, 54, 255);    WHITE = (255, 255, 255, 255)


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    P = lambda pts, c: d.polygon(pts, fill=c)
    E = lambda box, c: d.ellipse(box, fill=c)
    L = lambda pts, c, w=1: d.line(pts, fill=c, width=w)

    # ══ CABELO ATRÁS (cauda longa fluindo pelas costas — bem à esquerda) ═══════
    P([(21,24),(11,40),(6,62),(6,88),(12,104),(19,106),(21,86),(20,58),(24,40)], HAIR)
    P([(19,40),(13,60),(13,88),(18,100),(20,84),(20,58)], HAIR_D)
    P([(16,54),(11,74),(14,94),(17,84),(16,68)], HAIR_DD)
    L([(20,32),(14,58),(15,84)], HAIR_H, 2)

    # ══ CAPA — asa esquerda (costas), drape limpo com hem pontudo ══════════════
    P([(28,48),(18,76),(18,106),(27,120),(36,113),(34,86),(32,58)], CAPE)
    P([(28,54),(21,78),(21,104),(28,114),(32,98),(31,72)], CAPE_D)
    P([(23,86),(21,102),(27,113),(28,98)], CAPE_DD)
    L([(18,76),(18,94),(20,107)], CAPE_L, 1)               # rim-light frio

    # ══ PERNAS + BOTAS (desenhadas antes do corpo p/ ficarem atrás da capa) ════
    P([(26,86),(32,86),(32,108),(26,108)], SUIT)
    P([(34,86),(40,86),(40,108),(34,108)], SUIT)
    P([(24,104),(33,104),(33,126),(24,126)], BOOT)         # bota trás
    P([(34,104),(42,104),(42,126),(34,126)], BOOT)         # bota frente
    d.rectangle((24,104,33,107), fill=BOOT_D); d.rectangle((34,104,42,107), fill=BOOT_D)
    L([(26,109),(26,124)], BOOT_H, 1); L([(36,109),(36,124)], BOOT_H, 1)

    # ══ CAPA — painel frontal (direita) com forro roxo ═════════════════════════
    P([(38,50),(50,58),(52,94),(42,104),(35,90),(37,60)], CAPE)
    P([(40,56),(48,62),(49,92),(43,100),(39,82)], CAPE_D)
    L([(37,58),(36,88)], LINING, 1); L([(38,60),(37,86)], LINING_D, 1)
    L([(46,58),(48,66)], CAPE_GL, 1)                        # glow do orbe na capa

    # ══ OMBROS / GOLA (mais estreitos → menos atarracada) ══════════════════════
    P([(26,46),(38,46),(45,54),(19,54)], CAPE)

    # ══ BODYSUIT (torso esguio com cintura) ════════════════════════════════════
    P([(27,50),(37,50),(38,66),(35,78),(36,86),(28,86),(29,78),(26,66)], SUIT)
    P([(28,54),(31,54),(31,84),(29,84),(27,68)], SUIT_H)   # luz (esquerda)
    P([(35,56),(36,66),(34,82),(33,70)], SUIT_SH)          # sombra (direita)
    # broche-gema no peito
    E((30,55,35,60), ORB); d.point((31,56), fill=ORB_C); d.point((32,57), fill=ORB_H)
    L([(31,53),(33,54)], GOLD, 1)

    # ══ BRAÇOS (terminam em mão de pele, integradas) ═══════════════════════════
    P([(20,54),(26,56),(25,80),(19,80),(18,66)], SUIT)     # braço esq
    E((18,78,25,86), SKIN)                                 # mão esq
    P([(39,56),(45,54),(47,68),(45,82),(39,82)], SUIT)     # braço dir
    E((39,78,46,86), SKIN)                                 # mão dir

    # ══ CINTURÃO ═══════════════════════════════════════════════════════════════
    d.rectangle((26,82,38,87), fill=GOLD)
    L([(26,83),(38,83)], GOLD_H, 1)
    d.rectangle((30,83,33,87), fill=GOLD_D)

    # ══ CABEÇA / ROSTO ═════════════════════════════════════════════════════════
    E((19,14,43,44), SKIN)
    d.pieslice((19,14,43,44), 25, 115, fill=SKIN_H)        # luz cima-esq
    d.pieslice((19,14,43,44), 310, 360, fill=SKIN_S)       # sombra dir
    d.pieslice((19,14,43,44), 0, 20, fill=SKIN_S)
    E((19,14,43,44), None)  # no-op (mantém forma)

    # ── Olhos grandes ──
    for ex in (24, 34):
        E((ex,27,ex+6,34), WHITE)
        E((ex+1,28,ex+5,33), HAIR)
        E((ex+2,29,ex+5,33), EYEPUP)
        d.point((ex+2,29), fill=WHITE)
        L([(ex,26),(ex+5,26)], OUTLINE, 1)                 # cílio

    # ── Óculos REDONDOS (círculos reais) ──
    d.ellipse((22,25,31,35), fill=LENS, outline=GLASS)
    d.ellipse((33,25,42,35), fill=LENS, outline=GLASS)
    L([(31,30),(33,30)], GLASS, 1)                         # ponte
    L([(22,29),(18,28)], GLASS, 1)                         # haste
    d.point((24,27), fill=GLASS_H); d.point((35,27), fill=GLASS_H)

    # ── Nariz, boca, blush ──
    d.point((31,37), fill=SKIN_S)
    L([(29,40),(33,40)], MOUTH, 1); d.point((28,39), fill=SKIN_S); d.point((34,39), fill=SKIN_S)
    E((22,35,24,37), BLUSH); E((38,35,40,37), BLUSH)

    # ══ CABELO FRENTE (franja moldurando) ══════════════════════════════════════
    P([(18,18),(21,30),(25,22),(27,14),(20,11)], HAIR)     # mecha esquerda
    P([(44,22),(41,34),(37,24),(35,14),(43,11)], HAIR)     # franja direita
    P([(25,12),(39,12),(43,20),(34,16),(28,16),(22,20)], HAIR)  # topo
    L([(28,15),(37,15)], HAIR_H, 1)
    L([(40,22),(42,30)], HAIR_D, 1)

    # ══ CAJADO + ORBE ══════════════════════════════════════════════════════════
    L([(16,100),(50,46)], STAFF, 3)
    L([(16,100),(50,46)], STAFF_H, 1)
    L([(17,101),(50,47)], STAFF_D, 1)
    L([(47,49),(43,41)], STAFF, 1); L([(53,49),(57,41)], STAFF, 1)   # prongs
    E((44,34,56,46), ORB)
    d.ellipse((45,35,52,42), fill=ORB_H); d.ellipse((46,36,50,40), fill=ORB_C)
    d.ellipse((51,41,55,45), fill=ORB_D)
    for s,e in [((50,33),(51,30)),((57,40),(60,40)),((50,47),(51,50)),((43,39),(40,38))]:
        L([s,e], ORB_H, 1)

    # ══ CONTORNO ÚNICO (dilata a silhueta e pinta atrás) ═══════════════════════
    alpha = img.split()[3]
    mask  = alpha.point(lambda a: 255 if a > 40 else 0)
    dil   = mask.filter(ImageFilter.MaxFilter(3))
    ring  = ImageChops.subtract(dil, mask)
    outline_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    outline_layer.paste(OUTLINE, mask=ring)
    # contorno atrás do preenchimento (não cobre o interior)
    return Image.alpha_composite(outline_layer, img)


def main():
    out = HERE / "iterations" / "soph_hd_idle.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    generate().save(out)
    print(f"  HD idle → {out}")


if __name__ == "__main__":
    main()
