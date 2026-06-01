#!/usr/bin/env python3
"""
soph_portrait.py — RETRATO da Soph em alta resolução (busto 3/4 à direita).

Estratégia (com o Will): o sprite do jogo fica simples/pequeno; o rosto bonito e
detalhado vive AQUI, num retrato grande pra diálogo/menu, onde há pixels de sobra
pra o 3/4 ler. Formas suaves (supersample + LANCZOS) + sombreado por máscaras.
Feições reais da Soph: chapéu navy, cabelo azul franja reta, olhos verdes, óculos
redondos, lábios berry, pele clara.

Coordenadas no espaço de SAÍDA (300×360). Cabeça centrada em x≈148.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = Path(__file__).parent
SS = 3
OUTW, OUTH = 300, 360
W, H = OUTW * SS, OUTH * SS

OUT      = (16, 12, 26)
SKIN     = (240, 202, 166); SKIN_S = (203, 152, 120); SKIN_H = (252, 226, 196)
HAIR     = (74, 140, 232);  HAIR_D = (40, 86, 184);   HAIR_DD = (24, 52, 122)
HAIR_H   = (150, 200, 255);  HAIR_PU = (104, 78, 162)
HAT      = (44, 46, 88);     HAT_D = (26, 28, 58);    HAT_H = (66, 70, 122)
GOLD     = (216, 178, 74);   GOLD_H = (255, 230, 152)
ROBE     = (30, 28, 54);     ROBE_H = (50, 48, 84)
LINING   = (120, 55, 140)
IRIS_D   = (30, 70, 46);     IRIS = (72, 128, 78);    IRIS_L = (150, 202, 120)
PUP      = (16, 12, 26);     EYEW = (248, 248, 252)
GLASS    = (150, 132, 100)
BERRY    = (170, 54, 76);    BERRY_D = (120, 32, 50); BERRY_H = (210, 102, 122)
BLUSH    = (236, 150, 150)


def s(v): return round(v * SS)
def _poly(d, pts, fill): d.polygon([(s(x), s(y)) for x, y in pts], fill=fill)
def _line(d, pts, fill, w=1): d.line([(s(x), s(y)) for x, y in pts], fill=fill, width=max(1, s(w)))
def _ell(d, x0, y0, x1, y1, **k): d.ellipse((s(x0), s(y0), s(x1), s(y1)), **k)


# Silhueta do rosto 3/4 à direita (cx≈148). Checklist convergente aplicado:
# queixo arredondado, mandíbula LONGE (direita) curvando p/ dentro (sem cunha),
# nariz suave (sem bico), rosto menos alongado.
FACE = [
    (104, 130), (126, 104), (160, 96), (188, 108), (200, 134),
    (205, 162), (208, 188),                              # têmpora/sobrancelha (direita)
    (212, 206), (214, 220),                              # nariz: bump SUAVE (x214)
    (210, 232), (204, 246),                              # sob o nariz / longe recuando
    (196, 264), (184, 282),                              # mandíbula LONGE curvando p/ dentro
    (164, 294), (144, 292),                              # queixo arredondado (dir. do centro)
    (122, 280), (104, 258),                              # mandíbula PERTO (esquerda)
    (92, 222), (88, 186), (92, 152),                     # bochecha perto / nuca
]


def _draw_back(im):
    d = ImageDraw.Draw(im)
    # cabelo atrás (esquerda) + cascata ondulada sobre o ombro
    pts_l, pts_r = [], []
    for i in range(27):
        t = i / 26
        y = 150 + t * 200
        cx = 96 + 14 * math.sin(t * 3.0 + 0.4) - 6 * t
        half = 30 * (1 - 0.35 * t)
        pts_l.append((cx - half, y)); pts_r.append((cx + half, y))
    _poly(d, pts_l + pts_r[::-1], HAIR)
    for i in range(27):
        t = i / 26; y = 150 + t * 200
        cx = 96 + 14 * math.sin(t * 3.0 + 0.4) - 6 * t
        col = HAIR_PU if t > 0.72 else HAIR_H
        d.line([(s(cx - 10), s(y)), (s(cx - 10), s(y + 6))], fill=col, width=s(3))
        d.line([(s(cx + 22 * (1 - 0.35 * t)), s(y)), (s(cx + 22 * (1 - 0.35 * t)), s(y + 6))],
               fill=HAIR_D, width=s(2))


def _draw_body(d):
    # pescoço (mais curto/largo) + sombra sob o queixo
    _poly(d, [(160, 296), (192, 296), (196, 330), (156, 330)], SKIN)
    _poly(d, [(160, 296), (192, 296), (190, 307), (162, 307)], SKIN_S)
    # gola alta (turtleneck) limpa
    _poly(d, [(150, 322), (202, 322), (206, 342), (146, 342)], ROBE)
    _line(d, [(150, 330), (202, 332)], ROBE_H, 2)
    # ombros (slope limpo) + base
    _poly(d, [(0, 360), (28, 344), (96, 332), (150, 340), (206, 334),
              (280, 344), (300, 348), (300, 360)], ROBE)
    d.rectangle((s(0), s(348), s(300), s(360)), fill=ROBE)


def _draw_face_base(d):
    _poly(d, FACE, SKIN)


def _draw_hair_front(d):
    # FRANJA RETA (blunt) cobrindo a testa, base reta ~y172 com leves pontas
    _poly(d, [(90, 150), (122, 108), (180, 98), (206, 132), (210, 172),
              (196, 164), (182, 176), (166, 162), (150, 176), (134, 162),
              (118, 176), (102, 164), (92, 170)], HAIR)
    for x in (108, 126, 144, 162, 180, 196):
        _line(d, [(x, 112), (x - 3, 172)], HAIR_D, 2)
    d.arc((s(94), s(98), s(206), s(176)), 198, 326, fill=HAIR_H, width=s(4))
    # MECHA volumosa ondulada no lado PERTO (esquerda), descendo do chapéu até o
    # queixo, emoldurando a bochecha (marcação do Will).
    pts_l, pts_r = [], []
    for i in range(22):
        t = i / 21
        y = 160 + t * 150
        cx = 100 + 9 * math.sin(t * 3.4 + 0.2) - 5 * t
        half = 13 * (1 - 0.22 * t)
        pts_l.append((cx - half, y)); pts_r.append((cx + half, y))
    _poly(d, pts_l + pts_r[::-1], HAIR)
    for i in range(22):
        t = i / 21; y = 160 + t * 150
        cx = 100 + 9 * math.sin(t * 3.4 + 0.2) - 5 * t
        half = 13 * (1 - 0.22 * t)
        d.line([(s(cx - half + 3), s(y)), (s(cx - half + 3), s(y + 7))], fill=HAIR_H, width=s(2))
        d.line([(s(cx + half - 1), s(y)), (s(cx + half - 1), s(y + 7))], fill=HAIR_D, width=s(2))


def _eye(d, cx, cy, rw, rh, near):
    d.ellipse((s(cx-rw), s(cy-rh), s(cx+rw), s(cy+rh)), fill=EYEW)
    ir = rw * 0.8
    d.ellipse((s(cx-ir), s(cy-rh*0.6), s(cx+ir), s(cy+rh*1.4)), fill=IRIS_D)
    d.ellipse((s(cx-ir+2), s(cy-rh*0.3), s(cx+ir-2), s(cy+rh*1.4)), fill=IRIS)
    d.ellipse((s(cx-ir+2), s(cy+rh*0.2), s(cx+ir-2), s(cy+rh*1.4)), fill=IRIS_L)
    pr = ir * 0.58
    d.ellipse((s(cx-pr), s(cy-rh*0.1), s(cx+pr), s(cy+rh*1.05)), fill=PUP)
    d.ellipse((s(cx-ir*0.7), s(cy-rh*0.5), s(cx-ir*0.15), s(cy+rh*0.1)), fill=EYEW)
    d.arc((s(cx-rw), s(cy-rh-2), s(cx+rw), s(cy+rh)), 184, 356, fill=OUT, width=s(2 if near else 1))


def _draw_features(im):
    d = ImageDraw.Draw(im)
    # OLHOS ALINHADOS na mesma linha (cy=182); LONGE claramente menor (perspectiva)
    _eye(d, 134, 182, 20, 12, near=True)     # PERTO (esquerda) grande
    _eye(d, 194, 182, 11, 7, near=False)     # LONGE (direita) menor, mesma altura
    _line(d, [(116, 160), (154, 158)], HAIR_D, 4)     # sobrancelha perto
    _line(d, [(184, 164), (206, 166)], HAIR_D, 3)     # sobrancelha longe
    # NARIZ suave (sem bico/scar): sombra leve do lado longe + narina pequena
    _line(d, [(206, 212), (210, 226)], SKIN_S, 2)
    _poly(d, [(200, 226), (208, 228), (205, 233), (199, 232)], SKIN_S)
    # LÁBIOS berry (um pouco mais p/ cima; centro-frente; leve curva)
    d.line([(s(150), s(260)), (s(168), s(258)), (s(182), s(264))], fill=BERRY_D, width=s(3))
    _poly(d, [(154, 262), (180, 264), (172, 273), (158, 273)], BERRY)
    _line(d, [(160, 268), (176, 268)], BERRY_H, 2)
    # ÓCULOS redondos aro fino — lente LONGE mais estreita (perspectiva 3/4)
    _ell(d, 110, 160, 158, 204, outline=GLASS, width=s(2))
    _ell(d, 178, 166, 206, 200, outline=GLASS, width=s(2))
    _line(d, [(158, 180), (178, 182)], GLASS, 2)       # ponte
    _line(d, [(110, 178), (86, 172)], GLASS, 2)        # haste → orelha esquerda


def _shade(im):
    alpha = im.split()[3]
    mask = alpha.point(lambda a: 255 if a > 60 else 0)
    sh = Image.new("L", im.size, 0); sd = ImageDraw.Draw(sh)
    sd.ellipse((s(188), s(150), s(250), s(300)), fill=120)      # lado longe (direita)
    sd.ellipse((s(118), s(270), s(206), s(320)), fill=88)       # sob o queixo
    sh = sh.filter(ImageFilter.GaussianBlur(s(9)))
    shadow = Image.composite(Image.new("RGBA", im.size, (30, 18, 50, 105)),
                             Image.new("RGBA", im.size, (0, 0, 0, 0)), sh)
    shadow.putalpha(ImageChops.multiply(shadow.split()[3], mask))
    im = Image.alpha_composite(im, shadow)
    hl = Image.new("L", im.size, 0); hd = ImageDraw.Draw(hl)
    hd.ellipse((s(92), s(150), s(180), s(286)), fill=105)       # bochecha perto (esquerda)
    hl = hl.filter(ImageFilter.GaussianBlur(s(12)))
    light = Image.composite(Image.new("RGBA", im.size, (255, 250, 235, 66)),
                            Image.new("RGBA", im.size, (0, 0, 0, 0)), hl)
    light.putalpha(ImageChops.multiply(light.split()[3], mask))
    im = Image.alpha_composite(im, light)
    bl = Image.new("RGBA", im.size, (0, 0, 0, 0)); bd = ImageDraw.Draw(bl)
    bd.ellipse((s(110), s(224), s(144), s(248)), fill=(*BLUSH, 60))
    bd.ellipse((s(184), s(226), s(204), s(244)), fill=(*BLUSH, 40))
    im = Image.alpha_composite(im, bl.filter(ImageFilter.GaussianBlur(s(4))))
    k = s(3) | 1
    edge = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(k)), mask)
    outl = Image.composite(Image.new("RGBA", im.size, OUT + (255,)),
                           Image.new("RGBA", im.size, (0, 0, 0, 0)), edge)
    return Image.alpha_composite(outl, im)


def _draw_hat(d):
    # cone navy tombando p/ trás-esquerda + ponta + pompom
    _poly(d, [(150, 104), (212, 124), (132, 36), (96, 26), (120, 58)], HAT)
    _poly(d, [(150, 104), (180, 112), (134, 48), (120, 58)], HAT_H)
    _line(d, [(150, 106), (212, 124)], GOLD, 7)
    _line(d, [(150, 106), (212, 124)], GOLD_H, 3)
    _ell(d, 70, 92, 226, 140, fill=HAT)
    _ell(d, 70, 92, 226, 126, fill=HAT_H)
    d.chord((s(70), s(92), s(226), s(140)), 0, 180, fill=HAT)
    d.arc((s(70), s(92), s(226), s(140)), 0, 180, fill=HAT_H, width=s(3))
    _ell(d, 88, 18, 110, 40, fill=GOLD_H)              # pompom


def render():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    _draw_back(im)
    d = ImageDraw.Draw(im)
    _draw_body(d)
    _draw_face_base(d)
    _draw_hair_front(d)
    im = _shade(im)
    _draw_features(im)
    d = ImageDraw.Draw(im)
    _draw_hat(d)
    return im.resize((OUTW, OUTH), Image.LANCZOS)


def main():
    out = HERE / "iterations"; out.mkdir(exist_ok=True)
    img = render()
    img.save(out / "soph_portrait.png")
    big = img.resize((OUTW * 2, OUTH * 2), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (40, 38, 52, 255))
    Image.alpha_composite(bg, big).convert("RGB").save(out / "soph_portrait_big.png")
    print("soph_portrait → soph_portrait.png + _big.png")


if __name__ == "__main__":
    main()
