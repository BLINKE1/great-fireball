"""
Semente imutável da Soph. Nunca sobrescrita pelo art_director.
art_director.py usa este arquivo como ponto de partida se generator.py estiver corrompido.
"""
from PIL import Image

W, H = 32, 64

T       = (0,   0,   0,   0)
OUTLINE = (20,  10,  35, 255)
SKIN    = (235, 195, 155, 255)
SKIN_S  = (200, 155, 115, 255)
HAIR    = (65,  125, 220, 255)
HAIR_D  = (35,  80,  175, 255)
HAIR_H  = (130, 185, 255, 255)
EYE     = (30,  20,  55,  255)
ROBE    = (80,  40,  140, 255)
ROBE_D  = (45,  20,  85,  255)
ROBE_L  = (120, 70,  185, 255)
GOLD    = (210, 165, 30,  255)
GOLD_D  = (155, 115, 10,  255)
BOOT    = (75,  50,  30,  255)
BOOT_D  = (50,  30,  15,  255)


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
    
    # --- Head and Hair (Proportions: Head ~16px height, y=0 to y=15) ---
    
    # Hair outline (medium blue, wavy, neck/shoulder length)
    # Top of head
    hline(img, 10, 21, 0, OUTLINE)
    px(img, 9, 1, OUTLINE)
    px(img, 22, 1, OUTLINE)
    px(img, 8, 2, OUTLINE)
    px(img, 23, 2, OUTLINE)
    px(img, 7, 3, OUTLINE)
    px(img, 24, 3, OUTLINE)
    px(img, 6, 4, OUTLINE)
    px(img, 25, 4, OUTLINE)
    px(img, 5, 5, OUTLINE)
    px(img, 26, 5, OUTLINE)
    px(img, 4, 6, OUTLINE)
    px(img, 27, 6, OUTLINE)
    px(img, 3, 7, OUTLINE)
    px(img, 28, 7, OUTLINE)
    px(img, 3, 8, OUTLINE) # Left side hair
    px(img, 28, 8, OUTLINE) # Right side hair
    
    # Continue
    return img
