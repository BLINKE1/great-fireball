#!/usr/bin/env python3
"""
soph_idle.py — SOPH IDLE 2.0 (redesign do zero).

Decisão de direção: vista **3/4 voltada à direita** (não de frente, não perfil).
É o ponto-ótimo p/ side-scroller — lê direção (quando ela anda, é "de lado"),
mas mantém o rosto/carisma à mostra. Flipa horizontal p/ o outro lado.

Fração 1 (este arquivo, agora): a POSE BASE perfeita — robe FECHADA (coluna
A-line), cajado plantado, chapéu de mago, franja, óculos. Silhueta limpa.
Fração 2 (depois): respiração (já parametrizada via `br`).
Fração 3 (depois): capa/cabelo/sombra dinâmicos.

Mesmo truque do soph_dream: desenha grande, shading por blur de máscaras,
glow real, downscale LANCZOS. Reaproveita a paleta do soph_dream.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter, ImageChops

from soph_dream import (
    WK, HK_,
    SKIN, SKIN_S, SKIN_H, HAIR, HAIR_D, HAIR_H, HAIR_DD,
    CAPE, CAPE_D, CAPE_H, LINING, LINING_D, SUIT, SUIT_H,
    GOLD, GOLD_D, GOLD_H, BOOT, BOOT_D, BOOT_H,
    STAFF, STAFF_D, STAFF_H, ORB, ORB_C, ORB_D, GLASS, OUT,
)

HERE = Path(__file__).parent


# ════════════════════════════════════════════════════════════════════════════
#  BASE (line-art em 3/4 virada à direita)
# ════════════════════════════════════════════════════════════════════════════
def _draw_base_idle(im, br=0.0):
    """Desenha a base. `br` (0..~4) = respiração: sobe ombros/cabeça levemente."""
    d = ImageDraw.Draw(im)
    sx = -round(br * 0.7)        # ombros sobem um tico
    hy = -round(br)             # cabeça sobe um tico mais

    # ───── CABELO ATRÁS (cauda flui pelas costas = lado ESQUERDO) ──────────────
    d.polygon([(214,300),(160,360),(126,520),(132,724),(176,816),(220,802),
               (222,640),(210,470),(238,360)], fill=HAIR)
    d.polygon([(206,344),(168,504),(172,706),(204,790),(222,690),(214,504)], fill=HAIR_D)
    d.polygon([(190,430),(164,566),(180,712),(198,650),(192,524)], fill=HAIR_DD)

    # ───── ROBE FECHADA (coluna A-line, leve sweep p/ direita) ─────────────────
    robe = [(218,356+sx),(192,478),(168,656),(150,832),(168,902),
            (340,902),(348,800),(330,648),(312,486),(300,356+sx)]
    d.polygon(robe, fill=CAPE)
    # lado afastado (esquerdo) em sombra
    d.polygon([(218,356+sx),(192,478),(168,656),(150,832),(168,902),
               (240,902),(236,704),(228,506),(232,366+sx)], fill=CAPE_D)
    # costura central (robe fechada → V suave no colo descendo reto)
    d.line([(258,372+sx),(256,520),(258,720),(256,892)], fill=CAPE_H, width=3)
    # dobras de volume
    d.line([(302,486),(326,842)], fill=CAPE_H, width=3)
    d.line([(210,510),(184,824)], fill=CAPE_D, width=4)
    d.line([(284,430),(290,864)], fill=CAPE_H, width=2)
    # barra/hem com forro
    d.line([(168,898),(340,898)], fill=LINING_D, width=6)

    # ───── BOTAS espiando na barra (leve 3/4: pé perto à frente) ───────────────
    d.rounded_rectangle((256,876,306,907), 10, fill=BOOT)
    d.rectangle((256,876,306,890), fill=BOOT_H)
    d.rounded_rectangle((210,886,256,908), 10, fill=BOOT_D)

    # ───── OMBROS / GOLA ALTA fechada (3/4: ombro perto+baixo, longe+alto) ─────
    d.polygon([(214,362+sx),(298,350+sx),(334,402),(306,380),(222,384),(196,400)], fill=CAPE)
    d.polygon([(248,330+sx),(296,330+sx),(300,362),(244,362)], fill=CAPE)   # gola (deslocada p/ dir)
    d.line([(248,346+sx),(298,344+sx)], fill=CAPE_H, width=3)

    # ───── BRAÇO PERTO (direito) trazendo a mão ao cajado ──────────────────────
    d.polygon([(300,362+sx),(332,376),(358,462),(332,490),(300,424)], fill=CAPE)
    d.line([(318,384),(348,470)], fill=CAPE_H, width=3)

    # ───── BROCHE dourado no colo ──────────────────────────────────────────────
    d.ellipse((252,396+sx,284,430+sx), fill=ORB, outline=GOLD, width=4)
    d.ellipse((260,404+sx,276,422+sx), fill=ORB_C)

    # ───── PESCOÇO + CABEÇA (3/4 à direita) ────────────────────────────────────
    d.polygon([(250,324+hy),(290,324+hy),(292,348+hy),(248,348+hy)], fill=SKIN)
    d.line([(250,342+hy),(292,342+hy)], fill=SKIN_S, width=3)
    d.ellipse((184,134+hy,348,334+hy), fill=SKIN)                 # cabeça (centro x266)
    d.ellipse((334,230+hy,354,262+hy), fill=SKIN)                # orelha perto (direita)
    d.ellipse((340,238+hy,350,254+hy), fill=SKIN_S)

    # ───── SIDEBURNS (emolduram o rosto à ESQUERDA = lado de longe → firma o 3/4)
    d.polygon([(196,168+hy),(190,300+hy),(212,332+hy),(234,302+hy),(230,206+hy),(216,162+hy)], fill=HAIR)
    d.polygon([(200,200+hy),(198,294+hy),(214,316+hy),(226,296+hy),(222,222+hy)], fill=HAIR_D)
    d.polygon([(340,184+hy),(346,278+hy),(332,300+hy),(326,212+hy)], fill=HAIR)   # costeleta perto (fina)
    # ───── FRANJA (curtain 3/4, partição deslocada p/ direita ~x292) ───────────
    d.polygon([(188,152+hy),(200,256+hy),(262,214+hy),(292,150+hy),(220,118+hy)], fill=HAIR)
    d.polygon([(350,176+hy),(342,260+hy),(312,216+hy),(300,150+hy),(338,122+hy)], fill=HAIR)
    d.polygon([(220,118+hy),(300,118+hy),(292,182+hy),(262,150+hy),(238,172+hy)], fill=HAIR)
    d.polygon([(196,150+hy),(292,156+hy),(290,180+hy),(266,206+hy),(224,206+hy),(198,188+hy)], fill=HAIR)
    d.polygon([(350,158+hy),(292,156+hy),(290,176+hy),(306,196+hy),(332,192+hy),(348,178+hy)], fill=HAIR)
    # textura da franja
    d.line([(232,158+hy),(224,202+hy)], fill=HAIR_D, width=3)
    d.line([(289,162+hy),(285,200+hy)], fill=HAIR_D, width=3)
    d.line([(295,162+hy),(301,196+hy)], fill=HAIR_D, width=3)
    d.line([(326,162+hy),(318,196+hy)], fill=HAIR_D, width=3)
    d.arc((218,118+hy,326,196+hy), 205, 335, fill=HAIR_H, width=6)   # shine

    # ───── CHAPÉU DE MAGO (cone pendendo p/ trás-esquerda) ─────────────────────
    # aba (elipse achatada, perspectiva 3/4 — frente um tico mais baixa)
    d.ellipse((156,104+hy,378,162+hy), fill=CAPE)
    d.ellipse((156,104+hy,378,146+hy), fill=CAPE_H)               # topo da aba (luz)
    # cone leaning up-left, com ponta dobrada
    d.polygon([(200,132+hy),(312,132+hy),(214,46+hy),(154,28+hy),(184,66+hy)], fill=CAPE)
    d.polygon([(200,132+hy),(256,132+hy),(210,58+hy),(184,66+hy)], fill=CAPE_H)
    d.line([(200,134+hy),(312,134+hy)], fill=GOLD, width=8)        # band dourada
    d.line([(200,134+hy),(312,134+hy)], fill=GOLD_H, width=3)
    d.ellipse((246,124+hy,270,150+hy), fill=ORB, outline=GOLD_H, width=2)  # gema na band
    d.ellipse((146,20+hy,170,44+hy), fill=GOLD_H)                # pompom na ponta
    # aba frontal por cima do cone (chord) → assenta o chapéu
    d.chord((156,104+hy,378,162+hy), 0, 180, fill=CAPE)
    d.arc((156,104+hy,378,162+hy), 0, 180, fill=CAPE_H, width=4)

    return d


# ════════════════════════════════════════════════════════════════════════════
#  SHADING (mesmo pipeline do soph_dream, luz vinda de cima-DIREITA)
# ════════════════════════════════════════════════════════════════════════════
def _overlay(im, fn):
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(layer))
    return Image.alpha_composite(im, layer)


def _shaded_idle(br=0.0):
    im = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    _draw_base_idle(im, br)
    alpha = im.split()[3]
    mask = alpha.point(lambda a: 255 if a > 60 else 0)

    # sombra de forma (vem de baixo-ESQUERDA, lado afastado)
    sh = Image.new("L", (WK, HK_), 0)
    sd = ImageDraw.Draw(sh)
    sd.ellipse((20, 320, 250, 900), fill=140)
    sd.ellipse((120, 640, 380, 980), fill=110)
    sh = sh.filter(ImageFilter.GaussianBlur(40))
    shadow = Image.composite(Image.new("RGBA", (WK, HK_), (0, 0, 30, 150)),
                             Image.new("RGBA", (WK, HK_), (0, 0, 0, 0)), sh)
    shadow.putalpha(ImageChops.multiply(shadow.split()[3], mask))
    im = Image.alpha_composite(im, shadow)

    # luz (cima-direita, lado do rosto)
    hl = Image.new("L", (WK, HK_), 0)
    hd = ImageDraw.Draw(hl)
    hd.ellipse((230, 110, 460, 520), fill=120)
    hd.ellipse((252, 470, 430, 884), fill=72)        # brilho na frente da robe → volume cilíndrico
    hl = hl.filter(ImageFilter.GaussianBlur(46))
    light = Image.composite(Image.new("RGBA", (WK, HK_), (255, 250, 235, 90)),
                            Image.new("RGBA", (WK, HK_), (0, 0, 0, 0)), hl)
    light.putalpha(ImageChops.multiply(light.split()[3], mask))
    im = Image.alpha_composite(im, light)

    # rim-light frio na borda
    dil = mask.filter(ImageFilter.MaxFilter(9))
    ring = ImageChops.subtract(dil, mask).filter(ImageFilter.GaussianBlur(2))
    rim = Image.composite(Image.new("RGBA", (WK, HK_), (120, 170, 255, 255)),
                          Image.new("RGBA", (WK, HK_), (0, 0, 0, 0)), ring)
    im = Image.alpha_composite(im, rim)

    # contorno escuro
    edge = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(5)), mask)
    outl = Image.composite(Image.new("RGBA", (WK, HK_), OUT + (255,)),
                           Image.new("RGBA", (WK, HK_), (0, 0, 0, 0)), edge)
    im = Image.alpha_composite(outl, im)

    # rosto + cajado/orbe (nítidos por cima)
    im = _draw_face_idle(im, br)
    im = _draw_staff_idle(im, br)
    return im


# ════════════════════════════════════════════════════════════════════════════
#  ROSTO (3/4: features deslocadas p/ direita, olho de longe menor)
# ════════════════════════════════════════════════════════════════════════════
def _draw_face_idle(im, br=0.0):
    hy = -round(br)
    d = ImageDraw.Draw(im)
    # olhos: perto (direito) maior; longe (esquerdo) menor/comprimido
    def eye(x0, x1, top, bot, near):
        cx = (x0 + x1) // 2
        d.ellipse((x0, top, x1, bot), fill=(255, 255, 255))
        rr = (x1 - x0) // 2 - 2
        d.ellipse((cx-rr, top+10, cx+rr, bot), fill=HAIR_D)
        d.ellipse((cx-rr+2, top+16, cx+rr-2, bot), fill=HAIR)
        d.ellipse((cx-rr+2, top+26, cx+rr-2, bot), fill=(120, 185, 255))
        pr = max(4, rr-9)
        d.ellipse((cx-pr, top+20, cx+pr, bot-8), fill=(20, 14, 40))            # pupila
        d.ellipse((cx-rr+1, top+4, cx-rr+pr+2, top+20), fill=(255, 255, 255))  # brilho
        d.arc((x0, top-6, x1, bot+8), 192, 348, fill=OUT, width=5 if near else 4)
    eye(250, 284, 214+hy, 260+hy, near=False)    # longe (menor)
    eye(300, 352, 208+hy, 268+hy, near=True)     # perto (maior)
    # sobrancelhas
    d.line([(252, 204+hy), (286, 200+hy)], fill=(46, 70, 150), width=4)
    d.line([(302, 200+hy), (348, 204+hy)], fill=(46, 70, 150), width=5)
    # blush (bochecha perto maior)
    im = _overlay(im, lambda o: (
        o.ellipse((244, 250+hy, 280, 284+hy), fill=(242, 148, 150, 100)),
        o.ellipse((312, 252+hy, 354, 288+hy), fill=(242, 148, 150, 120))))
    d = ImageDraw.Draw(im)
    # nariz (no lado PERTO) + boca doce deslocada p/ direita
    d.line([(342, 244+hy), (350, 262+hy), (338, 266+hy)], fill=SKIN_S, width=3)
    d.arc((300, 280+hy, 348, 312+hy), 18, 150, fill=(176, 94, 94), width=5)
    # ÓCULOS (lente perto maior; longe menor/angulada) — vidro bem transparente
    im = _overlay(im, lambda o: (
        o.ellipse((246, 206+hy, 288, 274+hy), fill=(210, 235, 252, 30)),
        o.ellipse((298, 202+hy, 356, 278+hy), fill=(210, 235, 252, 34)),
        o.arc((250, 210+hy, 284, 270+hy), 205, 245, fill=(255, 255, 255, 110), width=4),
        o.arc((302, 206+hy, 352, 274+hy), 205, 245, fill=(255, 255, 255, 120), width=4)))
    d = ImageDraw.Draw(im)
    d.ellipse((246, 206+hy, 288, 274+hy), outline=GLASS, width=4)
    d.ellipse((298, 202+hy, 356, 278+hy), outline=GLASS, width=5)
    d.line([(288, 234+hy), (298, 232+hy)], fill=GLASS, width=4)   # ponte
    d.line([(356, 232+hy), (372, 224+hy)], fill=GLASS, width=4)   # haste (lado perto → cue 3/4)
    return im


# ════════════════════════════════════════════════════════════════════════════
#  CAJADO PLANTADO + ORBE (glow real), à direita, mão perto segurando
# ════════════════════════════════════════════════════════════════════════════
def _draw_staff_idle(im, br=0.0):
    d = ImageDraw.Draw(im)
    # haste vertical plantada no chão (leve lean), x~352
    top, bot = 196, 902
    d.line([(356, top), (350, bot)], fill=STAFF, width=13)
    d.line([(356, top), (350, bot)], fill=STAFF_H, width=4)
    # remate/garras segurando o orbe
    d.line([(352, top+8), (336, top-26)], fill=STAFF, width=8)
    d.line([(360, top+8), (380, top-26)], fill=STAFF, width=8)
    # GLOW real do orbe
    ocx, ocy = 358, 168
    glow = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((ocx-58, ocy-58, ocx+58, ocy+58), fill=(70, 150, 250, 255))
    glow = glow.filter(ImageFilter.GaussianBlur(34))
    im = ImageChops.add(im, glow)
    d = ImageDraw.Draw(im)
    # orbe nítido
    d.ellipse((ocx-36, ocy-36, ocx+36, ocy+36), fill=ORB, outline=OUT, width=3)
    d.ellipse((ocx-26, ocy-26, ocx+18, ocy+18), fill=(150, 210, 255))
    d.ellipse((ocx-22, ocy-22, ocx-2, ocy-2), fill=ORB_C)
    d.ellipse((ocx+14, ocy+14, ocx+30, ocy+30), fill=ORB_D)
    # mão perto (direita) segurando a haste
    hx, hy_ = 350, 468
    d.ellipse((hx-20, hy_-18, hx+20, hy_+18), fill=SKIN, outline=OUT, width=3)
    d.pieslice((hx-20, hy_-18, hx+20, hy_+18), 200, 340, fill=SKIN_H)
    for off in (-8, 0, 8):
        d.line([(hx+off, hy_-12), (hx+off, hy_+12)], fill=SKIN_S, width=2)
    # haste reaparece por cima da palma → leitura de "segurando"
    d.line([(356, hy_-22), (351, hy_+30)], fill=STAFF, width=7)
    d.line([(356, hy_-22), (351, hy_+30)], fill=STAFF_H, width=2)

    # partículas de aura subindo ao redor do orbe
    import random
    rng = random.Random(11)
    spark = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    sd = ImageDraw.Draw(spark)
    for _ in range(22):
        ang = rng.uniform(0, 2*math.pi); dist = rng.uniform(30, 88)
        px = ocx + math.cos(ang)*dist
        py = ocy + math.sin(ang)*dist - dist*0.4
        r = rng.uniform(1.5, 4.5); a = max(40, int(180*(1 - dist/100)))
        col = (190, 230, 255, a) if rng.random() > 0.4 else (110, 180, 255, a)
        sd.ellipse((px-r, py-r, px+r, py+r), fill=col)
    im = ImageChops.add(im, spark.filter(ImageFilter.GaussianBlur(3)))
    im = Image.alpha_composite(im, spark)
    return im


# ════════════════════════════════════════════════════════════════════════════
#  RENDER / PREVIEW
# ════════════════════════════════════════════════════════════════════════════
def render_idle(target_h=None, br=0.0):
    im = _shaded_idle(br)
    if target_h:
        w = round(WK * target_h / HK_)
        im = im.resize((w, target_h), Image.LANCZOS)
    return im


def render_beauty():
    char = _shaded_idle(0.0)
    bg = Image.new("RGBA", (WK, HK_), (20, 20, 34, 255))
    grad = Image.new("L", (WK, HK_), 0)
    ImageDraw.Draw(grad).ellipse((-120, -40, WK+120, HK_*0.7), fill=70)
    grad = grad.filter(ImageFilter.GaussianBlur(120))
    amb = Image.composite(Image.new("RGBA", (WK, HK_), (50, 70, 130, 255)), bg, grad)
    bg = Image.alpha_composite(bg, amb)
    og = Image.new("RGBA", (WK, HK_), (0, 0, 0, 0))
    ImageDraw.Draw(og).ellipse((300, 110, 470, 280), fill=(60, 130, 230, 255))
    bg = ImageChops.add(bg, og.filter(ImageFilter.GaussianBlur(70)))
    vig = Image.new("L", (WK, HK_), 0)
    ImageDraw.Draw(vig).ellipse((-60, -60, WK+60, HK_+60), fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(90))
    bg = Image.composite(bg, Image.new("RGBA", (WK, HK_), (8, 8, 16, 255)), vig)
    return Image.alpha_composite(bg, char)


def _contact_sheet():
    """Folha de contato: beauty grande + tamanhos de jogo lado a lado, p/ avaliar."""
    beauty = render_beauty().resize((300, 575), Image.LANCZOS)
    sizes = [192, 128, 96, 64]
    sheet_w = 300 + 20 + max(sizes) + 40
    sheet = Image.new("RGBA", (sheet_w, 620), (26, 24, 38, 255))
    sheet.paste(beauty, (16, 22), beauty)
    x = 300 + 36
    y = 22
    chk = Image.new("RGBA", (max(sizes), 600), (40, 40, 54, 255))
    for s in sizes:
        im = render_idle(target_h=s)
        bg = Image.new("RGBA", im.size, (40, 40, 54, 255))
        comp = Image.alpha_composite(bg, im)
        sheet.paste(comp, (x, y), comp)
        y += s + 16
    return sheet


def main():
    out = HERE / "iterations"
    out.mkdir(parents=True, exist_ok=True)
    render_idle().save(out / "idle2_big.png")
    for h in (256, 128, 64):
        render_idle(h).save(out / f"idle2_{h}.png")
    render_beauty().save(out / "idle2_beauty.png")
    _contact_sheet().save(out / "idle2_sheet.png")
    # respiração: 3 frames (preview do que vem na fração 2)
    frames = [render_idle(target_h=256, br=b) for b in (0.0, 2.0, 3.5, 2.0)]
    bg = Image.new("RGBA", frames[0].size, (24, 22, 36, 255))
    gif = [Image.alpha_composite(bg, f).convert("P", palette=Image.ADAPTIVE) for f in frames]
    gif[0].save(out / "idle2_breath.gif", save_all=True, append_images=gif[1:],
                duration=700, loop=0, disposal=2)
    print("  idle2 → big + beauty + sheet + 256/128/64 + breath.gif")


if __name__ == "__main__":
    main()
