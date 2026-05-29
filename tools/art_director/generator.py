"""
Semente de geração da Soph — art_director.py substitui este arquivo a cada iteração.
Define obrigatoriamente: generate() -> PIL.Image  (32×64, RGBA, fundo transparente)

Personagem: Soph, maga jovem, cabelo azul, robe roxo escuro com faixa dourada,
botas marrons. Vista lateral direita. Pose idle.
"""
from PIL import Image

W, H = 32, 64

# ── Paleta canônica da Soph ───────────────────────────────────────────────────
T       = (0,   0,   0,   0)    # transparente
OUTLINE = (20,  10,  35, 255)   # outline escuro roxo
SKIN    = (235, 195, 155, 255)  # pele
SKIN_S  = (200, 155, 115, 255)  # pele sombra
HAIR    = (65,  125, 220, 255)  # cabelo azul
HAIR_D  = (35,  80,  175, 255)  # cabelo azul escuro
HAIR_H  = (130, 185, 255, 255)  # cabelo azul claro (reflexo)
EYE     = (30,  20,  55,  255)  # olhos
ROBE    = (80,  40,  140, 255)  # robe roxo
ROBE_D  = (45,  20,  85,  255)  # robe roxo escuro (sombra)
ROBE_L  = (120, 70,  185, 255)  # robe roxo claro (luz)
GOLD    = (210, 165, 30,  255)  # detalhe dourado
GOLD_D  = (155, 115, 10,  255)  # dourado sombra
BOOT    = (75,  50,  30,  255)  # botas marrom
BOOT_D  = (50,  30,  15,  255)  # botas sombra


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), c)


def hline(img, x0, x1, y, c):
    for x in range(x0, x1 + 1):
        px(img, x, y, c)


def vline(img, x, y0, y1, c):
    for y in range(y0, y1 + 1):
        px(img, x, y, c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(img, x, y, c)


def generate() -> Image.Image:
    img = Image.new("RGBA", (W, H), T)

    # ── Cabelo (topo, y=0..12) ────────────────────────────────────────────────
    # Massa principal do cabelo — deve ser claramente azul e volumosa
    rect(img,  8, 0, 23,  2, HAIR)       # topo da cabeça
    rect(img,  6, 3, 25,  5, HAIR)       # corpo do cabelo
    rect(img,  5, 6, 25,  9, HAIR)       # largura máxima
    rect(img,  4, 6,  6, 12, HAIR)       # mecha lateral esquerda (costas)
    rect(img, 22, 6, 25, 12, HAIR)       # mecha lateral direita (frente)
    # Escurecimento nas laterais
    vline(img,  4,  6, 12, HAIR_D)
    vline(img, 25,  6, 12, HAIR_D)
    # Reflexo no topo
    hline(img, 10, 19,  1, HAIR_H)

    # ── Outline do cabelo ────────────────────────────────────────────────────
    hline(img,  8, 23,  0, OUTLINE)
    px(img,  7,  1, OUTLINE); px(img,  5,  3, OUTLINE)
    px(img,  4,  6, OUTLINE); px(img,  3,  9, OUTLINE)
    px(img, 24,  0, OUTLINE); px(img, 26,  3, OUTLINE)
    px(img, 26,  6, OUTLINE); px(img, 26,  9, OUTLINE)

    # ── Rosto (y=8..18) ───────────────────────────────────────────────────────
    rect(img,  9,  8, 22, 17, SKIN)      # oval da cabeça
    # Outline do rosto
    hline(img, 10, 21,  8, OUTLINE)      # topo
    hline(img, 10, 21, 17, OUTLINE)      # base
    vline(img,  9,  9, 16, OUTLINE)      # esquerda
    vline(img, 22,  9, 16, OUTLINE)      # direita
    # Cantos arredondados
    px(img, 10,  9, SKIN); px(img, 21,  9, SKIN)
    px(img, 10, 16, SKIN); px(img, 21, 16, SKIN)
    # Sombra do queixo
    hline(img, 11, 20, 16, SKIN_S)

    # Olhos grandes (y=11..13)
    rect(img, 11, 11, 13, 13, EYE)       # olho esquerdo
    rect(img, 17, 11, 19, 13, EYE)       # olho direito
    px(img, 12, 11, HAIR_H)              # reflexo olho esq
    px(img, 18, 11, HAIR_H)              # reflexo olho dir
    # Sobrancelhas
    hline(img, 11, 13, 10, OUTLINE)
    hline(img, 17, 19, 10, OUTLINE)

    # ── Pescoço (y=18..20) ───────────────────────────────────────────────────
    rect(img, 14, 18, 17, 20, SKIN)
    vline(img, 13, 18, 20, OUTLINE)
    vline(img, 18, 18, 20, OUTLINE)

    # ── Ombros / topo do robe (y=20..24) ─────────────────────────────────────
    rect(img,  7, 20, 24, 24, ROBE)
    hline(img,  7, 24, 20, OUTLINE)
    vline(img,  6, 20, 35, OUTLINE)      # outline lateral esquerda
    vline(img, 25, 20, 35, OUTLINE)      # outline lateral direita

    # ── Braços (y=20..36) ────────────────────────────────────────────────────
    # Braço esquerdo (costas — mais escuro)
    rect(img,  4, 21,  6, 35, ROBE_D)
    vline(img,  3, 21, 35, OUTLINE)
    # Braço direito (frente)
    rect(img, 25, 21, 27, 35, ROBE)
    vline(img, 28, 21, 35, OUTLINE)
    # Mãos
    rect(img,  4, 35,  6, 37, SKIN)
    rect(img, 25, 35, 27, 37, SKIN)
    hline(img,  4,  6, 37, OUTLINE)
    hline(img, 25, 27, 37, OUTLINE)

    # ── Robe (tronco, y=24..46) ──────────────────────────────────────────────
    rect(img,  7, 24, 24, 46, ROBE)
    # Luz central
    rect(img, 13, 24, 18, 40, ROBE_L)
    # Sombra nas laterais
    vline(img,  7, 24, 46, ROBE_D)
    vline(img,  8, 24, 46, ROBE_D)
    vline(img, 24, 24, 46, ROBE_D)
    vline(img, 23, 24, 46, ROBE_D)
    # Faixa dourada (cinto, y=30..33)
    rect(img,  7, 30, 24, 33, GOLD)
    hline(img,  7, 24, 30, GOLD_D)
    hline(img,  7, 24, 33, GOLD_D)
    # Fivela central
    rect(img, 14, 30, 17, 33, GOLD_D)
    # Outline inferior do robe
    hline(img,  7, 24, 46, OUTLINE)

    # ── Pernas / bainhas (y=46..54) ───────────────────────────────────────────
    # O robe se abre levemente revelando as pernas
    rect(img,  8, 46, 14, 53, ROBE_D)   # perna esquerda (robe)
    rect(img, 16, 46, 23, 53, ROBE)     # perna direita (robe)
    hline(img,  8, 14, 53, OUTLINE)
    hline(img, 16, 23, 53, OUTLINE)

    # ── Botas (y=54..63) ─────────────────────────────────────────────────────
    rect(img,  8, 54, 14, 63, BOOT)
    rect(img, 16, 54, 23, 63, BOOT)
    # Detalhes das botas
    hline(img,  8, 14, 54, BOOT_D)      # dobra no topo
    hline(img, 16, 23, 54, BOOT_D)
    # Sola
    hline(img,  8, 14, 63, OUTLINE)
    hline(img, 16, 23, 63, OUTLINE)
    vline(img,  7, 54, 63, OUTLINE)
    vline(img, 15, 54, 63, OUTLINE)
    vline(img, 24, 54, 63, OUTLINE)

    return img
