#!/usr/bin/env python3
"""
soph_dream.py — Soph "sem limites" (estilo Hollow Knight): arte desenhada
GRANDE e suave, depois exibida pequena.

Truque: desenha num canvas alto com SUPERSAMPLING (SSx), com shading por
blur de mascaras (luz/sombra suaves) e GLOW real (GaussianBlur). No fim
reduz com LANCZOS -> bordas com anti-aliasing, sem grade de pixels.

Saidas: render grande (beauty) + versoes pequenas (como apareceria no jogo).
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

HERE = Path(__file__).parent
# Canvas de trabalho (alto) — proporcao retrato. Reduzido no fim.
WK, HK_ = 480, 920
SS = 1  # ja trabalhamos grande; suavizacao vem do downscale final

# ── Paleta (tons ricos, vai receber gradiente/sombra por cima) ─────────────────
SKIN   = (242, 206, 170); SKIN_S = (198, 150, 116); SKIN_H = (255, 232, 205)
HAIR   = (74, 140, 232);  HAIR_D = (40, 86, 184);   HAIR_H = (158, 208, 255)
HAIR_DD= (24, 52, 122)
CAPE   = (30, 27, 52);    CAPE_D = (15, 13, 30);     CAPE_H = (62, 70, 120)
LINING = (120, 54, 140);  LINING_D = (78, 34, 96)
SUIT   = (26, 22, 42);    SUIT_H = (52, 46, 82)
GOLD   = (222, 178, 70);  GOLD_D = (150, 110, 34);   GOLD_H = (255, 230, 150)
BOOT   = (84, 56, 34);    BOOT_D = (52, 34, 18);     BOOT_H = (124, 90, 56)
STAFF  = (120, 84, 48);   STAFF_D = (80, 52, 28);    STAFF_H = (176, 132, 78)
ORB    = (66, 150, 244);  ORB_C = (236, 250, 255);   ORB_D = (28, 78, 162)
GLASS  = (28, 26, 44)
OUT    = (14, 10, 24)


def _draw_base(im):
    d = ImageDraw.Draw(im)
    cx = 240

    # ════ CABELO ATRÁS (cauda longa, fluida) ═════════════════════════════════
    d.polygon([(150,150),(96,250),(60,440),(70,650),(120,760),(168,770),
               (176,640),(168,430),(196,250)], fill=HAIR)
    d.polygon([(150,260),(112,440),(118,650),(150,740),(166,630),(160,430)], fill=HAIR_D)
    d.polygon([(132,360),(104,520),(126,680),(140,600),(134,470)], fill=HAIR_DD)

    # ════ CAPA — asa esquerda (costas), grande drape ═════════════════════════
    d.polygon([(196,340),(120,520),(118,720),(180,840),(286,810),(280,560),(252,400)],
              fill=CAPE)
    d.polygon([(196,360),(150,520),(150,710),(196,810),(250,720),(244,520)], fill=CAPE_D)

    # ════ PERNAS + BOTAS (atrás da capa frontal) ═════════════════════════════
    d.rectangle((196,610,236,770), fill=SUIT)
    d.rectangle((250,610,290,770), fill=SUIT)
    d.rounded_rectangle((184,748,244,900), 14, fill=BOOT)
    d.rounded_rectangle((250,748,310,900), 14, fill=BOOT)
    d.rectangle((184,748,244,772), fill=BOOT_D); d.rectangle((250,748,310,772), fill=BOOT_D)

    # ════ CAPA — painel frontal (direita) + forro roxo ═══════════════════════
    d.polygon([(286,350),(372,420),(384,700),(300,760),(258,640),(270,420)], fill=CAPE)
    d.polygon([(300,380),(360,430),(366,680),(300,730),(276,580)], fill=CAPE_D)
    d.line([(266,420),(258,640)], fill=LINING, width=6)
    d.line([(272,430),(266,620)], fill=LINING_D, width=3)

    # ════ OMBROS / GOLA ══════════════════════════════════════════════════════
    d.polygon([(186,330),(296,330),(350,400),(140,400)], fill=CAPE)

    # ════ BODYSUIT (torso, cintura) ══════════════════════════════════════════
    d.polygon([(196,360),(286,360),(294,500),(266,600),(272,650),(210,650),
               (216,600),(188,500)], fill=SUIT)
    # broche-gema
    d.ellipse((224,392,256,430), fill=ORB)

    # ════ BRAÇOS (segurando o cajado) ════════════════════════════════════════
    d.polygon([(160,400),(196,408),(206,560),(176,580),(150,470)], fill=SUIT)
    d.polygon([(286,408),(330,398),(344,486),(330,600),(288,600)], fill=SUIT)

    # ════ CINTURÃO ═══════════════════════════════════════════════════════════
    d.rounded_rectangle((196,604,290,640), 6, fill=GOLD)
    d.rectangle((228,606,250,638), fill=GOLD_D)

    # ════ CABEÇA / ROSTO ═════════════════════════════════════════════════════
    d.ellipse((140,120,340,360), fill=SKIN)

    # ════ FRANJA (cabelo da frente) ══════════════════════════════════════════
    d.polygon([(138,150),(150,250),(196,196),(214,120),(160,96)], fill=HAIR)
    d.polygon([(342,160),(330,270),(286,210),(268,120),(330,92)], fill=HAIR)
    d.polygon([(196,104),(286,104),(330,170),(252,132),(212,150)], fill=HAIR)

    # ════ BRILHO DO CABELO (shine de anime + mechas glossy) ══════════════════
    d.arc((176,112,300,184), 200, 340, fill=HAIR_H, width=7)        # shine no topo
    d.line([(150,168),(118,330),(126,520)], fill=HAIR_H, width=6)   # gloss cauda esq
    d.line([(176,520),(168,680)], fill=HAIR_H, width=4)
    d.line([(198,136),(206,206)], fill=HAIR_H, width=5)            # franja esq
    d.line([(300,150),(292,214)], fill=HAIR_H, width=5)            # franja dir
    d.line([(150,300),(146,520)], fill=HAIR_DD, width=4)           # sombra interna

    # ════ DOBRAS DE LUZ NA CAPA (volume) ═════════════════════════════════════
    d.line([(232,420),(244,600)], fill=CAPE_H, width=3)            # dobra central
    d.line([(300,440),(312,640)], fill=CAPE_H, width=3)            # dobra frontal-dir
    d.line([(150,520),(176,760)], fill=CAPE_H, width=2)           # dobra asa esq

    return d


def _shaded():
    """Desenha base + camadas suaves de sombra/luz/rim/glow (tudo grande)."""
    im = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    _draw_base(im)
    alpha = im.split()[3]
    mask = alpha.point(lambda a: 255 if a > 60 else 0)

    # ── Sombra de forma (vem de baixo-direita): blob escuro, blur, mascarado ──
    sh = Image.new("L", (WK, HK_), 0)
    sd = ImageDraw.Draw(sh)
    sd.ellipse((300,300,520,900), fill=140)        # lado direito
    sd.ellipse((180,640,420,980), fill=110)        # base
    sh = sh.filter(ImageFilter.GaussianBlur(40))
    shadow = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    shadow.putalpha(sh)
    shadow = Image.composite(Image.new("RGBA",(WK,HK_),(0,0,30,150)),
                             Image.new("RGBA",(WK,HK_),(0,0,0,0)), sh)
    shadow.putalpha(ImageChops.multiply(shadow.split()[3], mask))
    im = Image.alpha_composite(im, shadow)

    # ── Luz (cima-esquerda): clareia suave ──
    hl = Image.new("L", (WK, HK_), 0)
    hd = ImageDraw.Draw(hl)
    hd.ellipse((110,120,330,520), fill=120)
    hl = hl.filter(ImageFilter.GaussianBlur(46))
    light = Image.composite(Image.new("RGBA",(WK,HK_),(255,250,235,90)),
                            Image.new("RGBA",(WK,HK_),(0,0,0,0)), hl)
    light.putalpha(ImageChops.multiply(light.split()[3], mask))
    im = Image.alpha_composite(im, light)

    # ── Rim-light frio (borda, luz da lua) ──
    dil = mask.filter(ImageFilter.MaxFilter(9))
    ring = ImageChops.subtract(dil, mask).filter(ImageFilter.GaussianBlur(2))
    rim = Image.composite(Image.new("RGBA",(WK,HK_),(120,170,255,255)),
                          Image.new("RGBA",(WK,HK_),(0,0,0,0)), ring)
    im = Image.alpha_composite(im, rim)

    # ── Contorno escuro suave (define a silhueta) ──
    edge = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(5)), mask)
    outl = Image.composite(Image.new("RGBA",(WK,HK_),OUT+(255,)),
                           Image.new("RGBA",(WK,HK_),(0,0,0,0)), edge)
    im = Image.alpha_composite(outl, im)

    # ── ROSTO: olhos, óculos, boca (desenhados nítidos por cima) ──
    im = _draw_face(im)

    # ── CAJADO + ORBE com GLOW real ──
    im = _draw_staff_glow(im)
    return im


def _overlay(im, draw_fn):
    """Desenha numa camada separada e compõe com alpha (PIL nao faz blend em shapes)."""
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    return Image.alpha_composite(im, layer)


def _draw_face(im):
    d = ImageDraw.Draw(im)
    # ── Sobrancelhas suaves (azuladas) ── (opacas, ok desenhar direto)
    d.line([(176,196),(214,190)], fill=(46,70,150), width=5)
    d.line([(266,190),(304,196)], fill=(46,70,150), width=5)
    # ── Blush (semi-transparente → camada) ──
    im = _overlay(im, lambda o: (
        o.ellipse((160,250,206,288), fill=(242,148,150,120)),
        o.ellipse((274,250,320,288), fill=(242,148,150,120))))
    d = ImageDraw.Draw(im)
    # ── OLHOS grandes e brilhantes (opacos) ──
    for (ex0, ex1) in [(170,224), (256,310)]:
        cx = (ex0 + ex1) // 2
        d.ellipse((ex0,204,ex1,274), fill=(255,255,255))                   # esclera ampla
        d.ellipse((cx-17,218,cx+17,270), fill=HAIR_D)                      # íris (aro escuro)
        d.ellipse((cx-15,224,cx+15,270), fill=HAIR)                        # íris (corpo azul)
        d.ellipse((cx-13,238,cx+13,270), fill=(120,185,255))              # íris (base clara)
        d.ellipse((cx-8,234,cx+8,262), fill=(20,14,40))                   # pupila pequena
        d.ellipse((cx-13,220,cx+1,238), fill=(255,255,255))              # brilho grande
        d.ellipse((cx+5,252,cx+13,262), fill=(220,235,255))             # brilho pequeno
        d.arc((ex0,198,ex1,278), 192, 348, fill=OUT, width=6)             # cílio superior
        d.line([(ex0+2,210),(ex0-8,202)], fill=OUT, width=5)             # cílio do canto
    # ── Nariz + boca doce (opacos) ──
    d.line([(238,258),(244,270),(235,272)], fill=SKIN_S, width=3)
    d.arc((216,276,264,312), 15, 165, fill=(176,94,94), width=5)           # sorriso
    # ── ÓCULOS: lente bem transparente em camada (não apaga os olhos!) ──
    im = _overlay(im, lambda o: (
        o.ellipse((162,194,232,280), fill=(210,235,252,30)),
        o.ellipse((248,194,318,280), fill=(210,235,252,30)),
        o.arc((168,200,226,274), 205, 245, fill=(255,255,255,110), width=4),
        o.arc((254,200,312,274), 205, 245, fill=(255,255,255,110), width=4)))
    d = ImageDraw.Draw(im)
    # aros + ponte + haste (opacos, por cima)
    d.ellipse((162,194,232,280), outline=GLASS, width=4)
    d.ellipse((248,194,318,280), outline=GLASS, width=4)
    d.line([(232,224),(248,224)], fill=GLASS, width=4)                     # ponte
    d.line([(162,226),(144,216)], fill=GLASS, width=4)                     # haste
    return im


def _draw_staff_glow(im):
    # cabo
    d = ImageDraw.Draw(im)
    d.line([(150,720),(372,360)], fill=STAFF, width=12)
    d.line([(150,720),(372,360)], fill=STAFF_H, width=4)
    d.line([(360,372),(340,330)], fill=STAFF, width=8)    # prong
    d.line([(386,372),(406,330)], fill=STAFF, width=8)
    # glow layer (additive via lighter)
    glow = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((330,300,440,410), fill=(70,150,250,255))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    im = ImageChops.add(im, glow)
    # orbe nítido
    d = ImageDraw.Draw(im)
    d.ellipse((348,318,420,390), fill=ORB, outline=OUT, width=3)
    d.ellipse((356,326,398,368), fill=(150,210,255,255))
    d.ellipse((360,330,384,354), fill=ORB_C)
    d.ellipse((398,360,414,376), fill=ORB_D)
    # ── Mãos segurando o cajado (centradas na haste, com o cabo por cima) ──
    def hand(cx, cy):
        d.ellipse((cx-19, cy-17, cx+19, cy+17), fill=SKIN, outline=OUT, width=3)
        d.pieslice((cx-19, cy-17, cx+19, cy+17), 200, 340, fill=SKIN_H)  # luz
        # dedos (3 vincos)
        for off in (-8, 0, 8):
            d.line([(cx+off, cy-12), (cx+off, cy+12)], fill=SKIN_S, width=2)
    # pontos sobre a reta do cajado (150,720)->(372,360)
    hand(236, 588)     # mão de baixo
    hand(320, 452)     # mão de cima
    # cabo reaparece por cima das palmas → leitura de "segurando"
    d.line([(150,720),(372,360)], fill=STAFF, width=6)
    d.line([(150,720),(372,360)], fill=STAFF_H, width=2)

    # ── AURA MÁGICA: partículas de energia subindo/girando ao redor do orbe ──
    import math, random
    rng = random.Random(7)
    spark = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    ocx, ocy = 384, 354
    for i in range(26):
        ang = rng.uniform(0, 2 * math.pi)
        dist = rng.uniform(34, 96)
        px_ = ocx + math.cos(ang) * dist
        py_ = ocy + math.sin(ang) * dist - dist * 0.4    # tende a subir
        r = rng.uniform(1.5, 5.0)
        a = int(180 * (1 - dist / 110))
        col = (190, 230, 255, max(40, a)) if rng.random() > 0.4 else (110, 180, 255, max(40, a))
        sd.ellipse((px_-r, py_-r, px_+r, py_+r), fill=col)
    # leve trilha de brilho subindo
    glow2 = spark.filter(ImageFilter.GaussianBlur(3))
    im = ImageChops.add(im, glow2)
    im = Image.alpha_composite(im, spark)
    return im


def render(target_h=None):
    """Renderiza grande; se target_h dado, reduz mantendo proporcao (LANCZOS)."""
    im = _shaded()
    if target_h:
        w = round(WK * target_h / HK_)
        im = im.resize((w, target_h), Image.LANCZOS)
    return im


def render_beauty():
    """Render de apresentacao: personagem sobre fundo atmosferico (glow + vinheta)."""
    char = _shaded()
    # Fundo: degrade radial frio + glow azul atras do orbe + vinheta escura
    bg = Image.new("RGBA", (WK, HK_), (20, 20, 34, 255))
    grad = Image.new("L", (WK, HK_), 0)
    gd = ImageDraw.Draw(grad)
    gd.ellipse((-120, -40, WK + 120, HK_ * 0.7), fill=70)     # halo central alto
    grad = grad.filter(ImageFilter.GaussianBlur(120))
    amb = Image.composite(Image.new("RGBA", (WK, HK_), (50, 70, 130, 255)),
                          bg, grad)
    bg = Image.alpha_composite(bg, amb)
    # glow azul atras do orbe
    og = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    ImageDraw.Draw(og).ellipse((300, 270, 470, 440), fill=(60, 130, 230, 255))
    bg = ImageChops.add(bg, og.filter(ImageFilter.GaussianBlur(70)))
    # vinheta
    vig = Image.new("L", (WK, HK_), 0)
    ImageDraw.Draw(vig).ellipse((-60, -60, WK + 60, HK_ + 60), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(90))
    dark = Image.new("RGBA", (WK, HK_), (8, 8, 16, 255))
    bg = Image.composite(bg, dark, vig)
    return Image.alpha_composite(bg, char)


def main():
    out = HERE / "iterations"
    out.mkdir(parents=True, exist_ok=True)
    big = render()
    big.save(out / "soph_dream_big.png")
    for h in (256, 128, 64):
        render(h).save(out / f"soph_dream_{h}.png")
    render_beauty().save(out / "soph_dream_beauty.png")
    print("  dream → soph_dream_big.png + beauty + 256/128/64")


if __name__ == "__main__":
    main()
